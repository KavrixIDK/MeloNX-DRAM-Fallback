using ARMeilleure.Memory;
using Ryujinx.Common;
using Ryujinx.Memory;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;

namespace Ryujinx.Cpu.LightningJit.Cache
{
    class NoWxCache : IDisposable
    {
        private const int CodeAlignment = 4; // Bytes.

        // See the identical comment in DualMappedNoWxCache.cs. This class is not on iOS's
        // default code path today (DUAL_MAPPED_JIT is forced on), but is kept consistent in
        // case that ever changes (e.g. future TXM/entitlement behaviour).
        private static readonly int SharedCacheSize =
            DeviceMemoryInfo.IsVeryLowMemoryDevice ? 96 * 1024 * 1024
            : DeviceMemoryInfo.IsLowMemoryDevice ? 320 * 1024 * 1024
            : 2047 * 1024 * 1024;
        private static readonly int LocalCacheSize =
            DeviceMemoryInfo.IsVeryLowMemoryDevice ? 24 * 1024 * 1024
            : DeviceMemoryInfo.IsLowMemoryDevice ? 96 * 1024 * 1024
            : 256 * 1024 * 1024;

        // How many calls to the same function we allow until we pad the shared cache to force the function to become available there
        // and allow the guest to take the fast path.
        private const int MinCallsForPad = 8;

        private class MemoryCache : IDisposable
        {
            private readonly ReservedRegion _region;
            private readonly CacheMemoryAllocator _cacheAllocator;

            public CacheMemoryAllocator Allocator => _cacheAllocator;
            public nint Pointer => _region.Block.Pointer;

            public MemoryCache(IJitMemoryAllocator allocator, ulong size)
            {
                _region = new(allocator, size);
                _cacheAllocator = new((int)size);
            }

            public int Allocate(int codeSize)
            {
                codeSize = AlignCodeSize(codeSize);

                int allocOffset = _cacheAllocator.Allocate(codeSize);

                if (allocOffset < 0)
                {
                    throw new OutOfMemoryException("JIT Cache exhausted.");
                }

                _region.ExpandIfNeeded((ulong)allocOffset + (ulong)codeSize);

                return allocOffset;
            }

            public void Free(int offset, int size)
            {
                _cacheAllocator.Free(offset, size);
            }

            public void ReprotectAsRw(int offset, int size)
            {
                Debug.Assert(offset >= 0 && (offset & (int)(MemoryBlock.GetPageSize() - 1)) == 0);
                Debug.Assert(size > 0 && (size & (int)(MemoryBlock.GetPageSize() - 1)) == 0);

                _region.Block.MapAsRw((ulong)offset, (ulong)size);
            }

            public void ReprotectAsRx(int offset, int size)
            {
                Debug.Assert(offset >= 0 && (offset & (int)(MemoryBlock.GetPageSize() - 1)) == 0);
                Debug.Assert(size > 0 && (size & (int)(MemoryBlock.GetPageSize() - 1)) == 0);

                _region.Block.MapAsRx((ulong)offset, (ulong)size);

                if (OperatingSystem.IsMacOS() || OperatingSystem.IsIOS())
                {
                    JitSupportDarwin.SysIcacheInvalidate(_region.Block.Pointer + offset, size);
                }
                else
                {
                    throw new PlatformNotSupportedException();
                }
            }

            private static int AlignCodeSize(int codeSize)
            {
                return checked(codeSize + (CodeAlignment - 1)) & ~(CodeAlignment - 1);
            }

            protected virtual void Dispose(bool disposing)
            {
                if (disposing)
                {
                    _region.Dispose();
                    _cacheAllocator.Clear();
                }
            }

            public void Dispose()
            {
                // Do not change this code. Put cleanup code in 'Dispose(bool disposing)' method
                Dispose(disposing: true);
                GC.SuppressFinalize(this);
            }
        }

        private readonly IStackWalker _stackWalker;
        private readonly Translator _translator;
        private readonly MemoryCache _sharedCache;
        private readonly MemoryCache _localCache;
        private readonly PageAlignedRangeList _pendingMap;
        private readonly Lock _lock = new();

        class ThreadLocalCacheEntry
        {
            public readonly int Offset;
            public readonly int Size;
            public readonly nint FuncPtr;
            private int _useCount;

            public ThreadLocalCacheEntry(int offset, int size, nint funcPtr)
            {
                Offset = offset;
                Size = size;
                FuncPtr = funcPtr;
                _useCount = 0;
            }

            public int IncrementUseCount()
            {
                return ++_useCount;
            }
        }

        [ThreadStatic]
        private static Dictionary<ulong, ThreadLocalCacheEntry> _threadLocalCache;

        [ThreadStatic]
        private static List<ulong> _threadCallStack;

        [ThreadStatic]
        private static List<(ulong Address, ThreadLocalCacheEntry Entry)> _threadLocalEntriesToDelete;

        public NoWxCache(IJitMemoryAllocator allocator, IStackWalker stackWalker, Translator translator)
        {
            _stackWalker = stackWalker;
            _translator = translator;
            _sharedCache = new(allocator, (ulong)SharedCacheSize);
            _localCache = new(allocator, (ulong)LocalCacheSize);
            _pendingMap = new(_sharedCache.ReprotectAsRx, RegisterFunction);
        }

        public unsafe nint Map(nint framePointer, ReadOnlySpan<byte> code, ulong guestAddress, ulong guestSize)
        {
            if (TryGetCachedFunction(guestAddress, out nint funcPtr))
            {
                return funcPtr;
            }

            lock (_lock)
            {
                if (TryGetSharedFunction(guestAddress, out funcPtr))
                {
                    return funcPtr;
                }

                if (!_pendingMap.Has(guestAddress))
                {
                    int funcOffset = _sharedCache.Allocate(code.Length);

                    funcPtr = _sharedCache.Pointer + funcOffset;
                    code.CopyTo(new Span<byte>((void*)funcPtr, code.Length));

                    TranslatedFunction function = new(funcPtr, guestSize);

                    _pendingMap.Add(funcOffset, code.Length, guestAddress, function);
                }

                ClearThreadLocalCache(framePointer);

                return AddThreadLocalFunction(code, guestAddress);
            }
        }

        public unsafe nint MapPageAligned(ReadOnlySpan<byte> code)
        {
            lock (_lock)
            {
                // Ensure we will get an aligned offset from the allocator.
                _pendingMap.Pad(_sharedCache.Allocator);

                int sizeAligned = BitUtils.AlignUp(code.Length, (int)MemoryBlock.GetPageSize());
                int funcOffset = _sharedCache.Allocate(sizeAligned);

                Debug.Assert((funcOffset & ((int)MemoryBlock.GetPageSize() - 1)) == 0);

                nint funcPtr = _sharedCache.Pointer + funcOffset;
                code.CopyTo(new Span<byte>((void*)funcPtr, code.Length));

                _sharedCache.ReprotectAsRx(funcOffset, sizeAligned);

                return funcPtr;
            }
        }

        internal bool TryGetCachedFunction(ulong guestAddress, out nint funcPtr)
        {
            if (TryGetThreadLocalFunction(guestAddress, out funcPtr))
            {
                return true;
            }

            return TryGetSharedFunction(guestAddress, out funcPtr);
        }

        private bool TryGetSharedFunction(ulong guestAddress, out nint funcPtr)
        {
            if (_translator.Functions.TryGetValue(guestAddress, out TranslatedFunction function))
            {
                funcPtr = function.FuncPointer;

                return true;
            }

            funcPtr = nint.Zero;

            return false;
        }

        private bool TryGetThreadLocalFunction(ulong guestAddress, out nint funcPtr)
        {
            Dictionary<ulong, ThreadLocalCacheEntry> threadLocalCache = _threadLocalCache;

            if (threadLocalCache != null && threadLocalCache.TryGetValue(guestAddress, out ThreadLocalCacheEntry entry))
            {
                if (entry.IncrementUseCount() == MinCallsForPad)
                {
                    // Function is being called often, let's make it available in the shared cache so that the guest code
                    // can take the fast path and stop calling the emulator to get the function from the thread local cache.
                    // To do that we pad all "pending" function until they complete a page of memory, allowing us to reprotect them as RX.

                    lock (_lock)
                    {
                        _pendingMap.Pad(_sharedCache.Allocator);
                    }
                }

                funcPtr = entry.FuncPtr;

                return true;
            }

            funcPtr = nint.Zero;

            return false;
        }

        private void ClearThreadLocalCache(nint framePointer)
        {
            // Try to delete functions that are already on the shared cache
            // and no longer being executed.

            Dictionary<ulong, ThreadLocalCacheEntry> threadLocalCache = _threadLocalCache;

            if (threadLocalCache == null || threadLocalCache.Count == 0)
            {
                return;
            }

            List<ulong> callStack = _threadCallStack ??= [];
            callStack.Clear();

            foreach (ulong funcAddress in _stackWalker.GetCallStack(
                framePointer,
                _localCache.Pointer,
                LocalCacheSize,
                _sharedCache.Pointer,
                SharedCacheSize))
            {
                callStack.Add(funcAddress);
            }

            List<(ulong Address, ThreadLocalCacheEntry Entry)> toDelete = _threadLocalEntriesToDelete ??= [];
            toDelete.Clear();

            foreach ((ulong address, ThreadLocalCacheEntry entry) in threadLocalCache)
            {
                // We only want to delete if the function is already on the shared cache,
                // otherwise we will keep translating the same function over and over again.
                bool canDelete = !_pendingMap.Has(address);
                if (!canDelete)
                {
                    continue;
                }

                // We can only delete if the function is not part of the current thread call stack,
                // otherwise we will crash the program when the thread returns to it.
                foreach (ulong funcAddress in callStack)
                {
                    if (funcAddress >= (ulong)entry.FuncPtr && funcAddress < (ulong)entry.FuncPtr + (ulong)entry.Size)
                    {
                        canDelete = false;
                        break;
                    }
                }

                if (canDelete)
                {
                    toDelete.Add((address, entry));
                }
            }

            int pageSize = (int)MemoryBlock.GetPageSize();

            foreach ((ulong address, ThreadLocalCacheEntry entry) in toDelete)
            {
                threadLocalCache.Remove(address);

                int sizeAligned = BitUtils.AlignUp(entry.Size, pageSize);

                _localCache.Free(entry.Offset, sizeAligned);
                _localCache.ReprotectAsRw(entry.Offset, sizeAligned);
            }

            toDelete.Clear();
            callStack.Clear();
        }

        public void ClearEntireThreadLocalCache()
        {
            // Thread is exiting, delete everything.

            Dictionary<ulong, ThreadLocalCacheEntry> threadLocalCache = _threadLocalCache;

            if (threadLocalCache == null)
            {
                return;
            }

            int pageSize = (int)MemoryBlock.GetPageSize();

            foreach ((_, ThreadLocalCacheEntry entry) in threadLocalCache)
            {
                int sizeAligned = BitUtils.AlignUp(entry.Size, pageSize);

                _localCache.Free(entry.Offset, sizeAligned);
                _localCache.ReprotectAsRw(entry.Offset, sizeAligned);
            }

            threadLocalCache.Clear();
            _threadLocalCache = null;
        }

        private unsafe nint AddThreadLocalFunction(ReadOnlySpan<byte> code, ulong guestAddress)
        {
            int alignedSize = BitUtils.AlignUp(code.Length, (int)MemoryBlock.GetPageSize());
            int funcOffset = _localCache.Allocate(alignedSize);

            Debug.Assert((funcOffset & (int)(MemoryBlock.GetPageSize() - 1)) == 0);

            nint funcPtr = _localCache.Pointer + funcOffset;
            code.CopyTo(new Span<byte>((void*)funcPtr, code.Length));

            (_threadLocalCache ??= new()).Add(guestAddress, new(funcOffset, code.Length, funcPtr));

            _localCache.ReprotectAsRx(funcOffset, alignedSize);

            return funcPtr;
        }

        private void RegisterFunction(ulong address, TranslatedFunction func)
        {
            TranslatedFunction oldFunc = _translator.Functions.GetOrAdd(address, func.GuestSize, func);

            Debug.Assert(oldFunc == func);

            _translator.RegisterFunction(address, func);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (disposing)
            {
                _localCache.Dispose();
                _sharedCache.Dispose();
            }
        }

        public void Dispose()
        {
            Dispose(disposing: true);
            GC.SuppressFinalize(this);
        }
    }
}
