using ARMeilleure.Memory;
using Ryujinx.Common;
using Ryujinx.Memory;
using System;
using System.Collections.Generic;
using System.Runtime.Versioning;
using System.Diagnostics;
using System.Threading;

namespace Ryujinx.Cpu.LightningJit.Cache
{
    [SupportedOSPlatform("macos")]
    [SupportedOSPlatform("ios")]
    class DualMappedNoWxCache : IDisposable
    {
        private const int CodeAlignment = 4; // Bytes.

        // NOTE: because this cache is always dual-mapped (RW + RX views of the same pages,
        // see DualMappedJitAllocator), the *actual* virtual address space cost of these two
        // fields combined is 2x(SharedCacheSize + LocalCacheSize), not 1x. At the original
        // fixed sizes that is up to ~2.5 GiB on non-TXM devices, reserved unconditionally,
        // which alone can exceed the entire usable VA budget on a low-RAM iOS device without
        // the Extended Virtual Addressing entitlement (~3.3 GiB on a 3 GB device). Values
        // below are heuristic - smaller than default but still large enough to hold many
        // translated functions. Note that filling this cache still throws an uncaught
        // OutOfMemoryException today (nothing in this codebase catches it, verified by
        // grepping the whole repo) - shrinking it trades a near-certain crash at startup
        // (the 2.5 GiB mmap/vm_remap itself failing with "Cannot allocate memory") for a
        // much less frequent one later in a play session for unusually code-heavy games.
        // Adding a catch around Translator's cache Map() calls to fail a single translation
        // instead of the whole process would be a good follow-up, independent of this change.
        // Tune the sizes below after on-device testing against real games.
        //
        // 2026-08-11 update: real-device log (iPad 9, Super Mario 3D World + Bowser's Fury)
        // confirmed this cache size (192+48 -> 480 MiB doubled) DOES fit - the crash moved
        // past this point, to KPageTableBase.SetHeapSize failing with KERN_NO_SPACE (Mach
        // error 3) inside AddressSpacePartition's private storage allocator. That means the
        // very-low-memory tier still needs more headroom overall; halving this (pure emulator
        // overhead, doesn't reduce the game's own heap budget) is one of the two safe levers
        // pushed further in response, alongside AddressSpacePartitionAllocator's block size.
        private static ulong SharedCacheSize =
            DeviceMemoryInfo.IsVeryLowMemoryDevice ? (ulong)96 * 1024 * 1024
            : DeviceMemoryInfo.IsLowMemoryDevice ? (ulong)320 * 1024 * 1024
            : DualMappedJitAllocator.hasTXM ? (ulong)512 * 1024 * 1024 : 1024 * 1024 * 1024;
        private static ulong LocalCacheSize =
            DeviceMemoryInfo.IsVeryLowMemoryDevice ? (ulong)24 * 1024 * 1024
            : DeviceMemoryInfo.IsLowMemoryDevice ? (ulong)96 * 1024 * 1024
            : 256 * 1024 * 1024;

        // How many calls to the same function we allow until we pad the shared cache to force the function to become available there
        // and allow the guest to take the fast path.
        private const int MinCallsForPad = 8;

        private class MemoryCache : IDisposable
        {
            private readonly DualMappedJitAllocator _allocator;
            private readonly CacheMemoryAllocator _cacheAllocator;
            public DualMappedJitAllocator Allocator => _allocator;
            public IntPtr RwPointer => _allocator.RwPtr;
            public IntPtr RxPointer => _allocator.RxPtr;

            public CacheMemoryAllocator CacheAllocator => _cacheAllocator;
            public IntPtr Pointer => _allocator.RwPtr; 

            public MemoryCache(DualMappedJitAllocator alloc, ulong size)
            {
                _allocator = alloc;
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

                return allocOffset;
            }

            public void Free(int offset, int size)
            {
                _cacheAllocator.Free(offset, size);
            }

            public void SysIcacheInvalidate(int offset, int size)
            {
                if (OperatingSystem.IsMacOS() || OperatingSystem.IsIOS())
                {
                    JitSupportDarwin.SysIcacheInvalidate(_allocator.RxPtr + offset, size);
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
                    _allocator.Dispose();
                    _cacheAllocator.Clear();
                }
            }

            public void Dispose()
            {
                Dispose(disposing: true);
                GC.SuppressFinalize(this);
            }
        }

        private readonly IStackWalker _stackWalker;
        private readonly Translator _translator;
        private MemoryCache _sharedCache;
        private MemoryCache _localCache;
        private static DualMappedJitAllocator _sharedCacheAlloc;
        private static DualMappedJitAllocator _localCacheAlloc;
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

        public DualMappedNoWxCache(IJitMemoryAllocator allocator, IStackWalker stackWalker, Translator translator)
        {
            _stackWalker = stackWalker;
            _translator = translator;
            _pendingMap = new PageAlignedRangeList(
                (offset, size) => _sharedCache.SysIcacheInvalidate(offset, size),
                (address, func) => RegisterFunction(address, func));

            _sharedCache = new(_sharedCacheAlloc, SharedCacheSize);
            _localCache = new(_localCacheAlloc, LocalCacheSize);
        }

        public static void InitMemoryCache() 
        {
            if (DualMappedJitAllocator.hasTXM && _sharedCacheAlloc != null && _localCacheAlloc != null)
                return;

            _sharedCacheAlloc = new(SharedCacheSize);
            _localCacheAlloc = new(LocalCacheSize);
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

                    funcPtr = _sharedCache.RwPointer + funcOffset;
                    code.CopyTo(new Span<byte>((void*)funcPtr, code.Length));

                    funcPtr = _sharedCache.RxPointer + funcOffset;
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
                _pendingMap.Pad(_sharedCache.CacheAllocator);

                int sizeAligned = BitUtils.AlignUp(code.Length, (int)MemoryBlock.GetPageSize());
                int funcOffset = _sharedCache.Allocate(sizeAligned);

                Debug.Assert((funcOffset & ((int)MemoryBlock.GetPageSize() - 1)) == 0);

                nint funcPtr = _sharedCache.RwPointer + funcOffset;
                code.CopyTo(new Span<byte>((void*)funcPtr, code.Length));
                funcPtr = _sharedCache.RxPointer + funcOffset;

                _sharedCache.SysIcacheInvalidate(funcOffset, sizeAligned);

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
                        _pendingMap.Pad(_sharedCache.CacheAllocator);
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
                _localCache.RxPointer,
                (int)LocalCacheSize,
                _sharedCache.RxPointer,
                (int)SharedCacheSize))
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
                // _localCache.ReprotectAsRw(entry.Offset, sizeAligned);
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
                // _localCache.ReprotectAsRw(entry.Offset, sizeAligned);
            }

            threadLocalCache.Clear();
            _threadLocalCache = null;
        }

        private unsafe nint AddThreadLocalFunction(ReadOnlySpan<byte> code, ulong guestAddress)
        {
            int alignedSize = BitUtils.AlignUp(code.Length, (int)MemoryBlock.GetPageSize());
            int funcOffset = _localCache.Allocate(alignedSize);

            Debug.Assert((funcOffset & (int)(MemoryBlock.GetPageSize() - 1)) == 0);

            nint funcPtr = _localCache.RwPointer + funcOffset;
            code.CopyTo(new Span<byte>((void*)funcPtr, code.Length));
            funcPtr = _localCache.RxPointer + funcOffset;
            (_threadLocalCache ??= new()).Add(guestAddress, new(funcOffset, code.Length, funcPtr));

            _localCache.SysIcacheInvalidate(funcOffset, alignedSize);

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
        }

        public void Dispose()
        {
            Dispose(disposing: true);
            GC.SuppressFinalize(this);
        }
    }
}
