using Ryujinx.Cpu.Signal;
using Ryujinx.Memory;
using System;
using System.Diagnostics;
using System.Numerics;
using System.Runtime.InteropServices;

namespace Ryujinx.Cpu.Jit.HostTracked
{
    sealed class NativePageTable : IDisposable
    {
        private delegate ulong TrackingEventDelegate(ulong address, ulong size, bool write);

        private const int PageBits = 12;
        private const int PageSize = 1 << PageBits;
        private const int PageMask = PageSize - 1;

        private const int PteSize = 8;

        private readonly int _bitsPerPtPage;
        private readonly int _entriesPerPtPage;
        private readonly int _pageCommitmentBits;

        private readonly PageTable<ulong> _pageTable;
        private readonly MemoryBlock _nativePageTable;
        private readonly ulong[] _pageCommitmentBitmap;
        private readonly ulong _hostPageSize;

        private readonly TrackingEventDelegate _trackingEvent;

        private bool _disposed;

        public nint PageTablePointer => _nativePageTable.Pointer;

        private readonly ulong _effectiveTableBytes;

        public NativePageTable(ulong asSize)
        {
            ulong hostPageSize = MemoryBlock.GetPageSize();

            _entriesPerPtPage = (int)(hostPageSize / sizeof(ulong));
            _bitsPerPtPage = BitOperations.Log2((uint)_entriesPerPtPage);
            _pageCommitmentBits = PageBits + _bitsPerPtPage;

            // MeloNX addition, history: originally capped this table to 160 GiB on
            // very-low-memory devices (up to ~1 GiB -> ~320 MiB), reasoning that with ASLR
            // forced off (see KPageTableBase.cs) the Code/Alias/Heap/Stack/TlsIo regions stay
            // within a predictable, much smaller range. That held for Alias/Heap/Stack/TlsIo,
            // but two real-device logs then showed a DIFFERENT, unrelated mechanism blowing
            // past the cap: KSharedMemory mappings (svcMapSharedMemory) take an address chosen
            // by the guest game/SDK itself (Syscall.cs MapSharedMemory's `address` parameter -
            // not something Ryujinx picks), and the kernel only rejects it if it overlaps the
            // Heap or Alias regions (KPageTableBase.MapSharedMemory: IsInvalidRegion /
            // InsideHeapRegion / InsideAliasRegion) - it's free to land anywhere else in the
            // nominal address space. One title placed it at ~296 GiB, comfortably past the 160
            // GiB cap. The bounds check below (CheckInEffectiveRange) did exactly its job -
            // clean InvalidMemoryRegionException instead of silent corruption - but chasing a
            // safe cap number here is effectively unbounded (whatever the guest SDK's own
            // allocation heuristic is, MeloNX/Ryujinx doesn't control it and a different title
            // could place it even higher). Reverted to no cap: correctness over the ~700 MiB
            // this would have saved. Left the machinery (DeviceMemoryInfo-gated, bounds-checked)
            // in place in case a real, provably-safe bound is found later - as written it's a
            // no-op since effectiveAsSize == asSize whenever the multiplier below is 1.
            ulong effectiveAsSize = DeviceMemoryInfo.IsVeryLowMemoryDevice
                ? Math.Min(asSize, ulong.MaxValue)
                : asSize;

            _hostPageSize = hostPageSize;
            _pageTable = new PageTable<ulong>();
            _nativePageTable = new MemoryBlock((effectiveAsSize / PageSize) * PteSize + _hostPageSize, MemoryAllocationFlags.Reserve);
            _pageCommitmentBitmap = new ulong[(effectiveAsSize >> _pageCommitmentBits) / (sizeof(ulong) * 8)];
            _effectiveTableBytes = effectiveAsSize;

            ulong ptStart = (ulong)_nativePageTable.Pointer;
            ulong ptEnd = ptStart + _nativePageTable.Size;

            _trackingEvent = VirtualMemoryEvent;

            bool added = NativeSignalHandler.AddTrackedRegion((nuint)ptStart, (nuint)ptEnd, Marshal.GetFunctionPointerForDelegate(_trackingEvent));

            if (!added)
            {
                throw new InvalidOperationException("Number of allowed tracked regions exceeded.");
            }
        }

        private void CheckInEffectiveRange(ulong va)
        {
            if (va >= _effectiveTableBytes)
            {
                throw new InvalidMemoryRegionException(
                    $"Guest address 0x{va:x} is outside the range NativePageTable reserved " +
                    $"(0x{_effectiveTableBytes:x}). This device is using the low-memory address " +
                    "space cap (see DeviceMemoryInfo.IsVeryLowMemoryDevice) - if this exception " +
                    "is happening, that cap needs to be raised for this title.");
            }
        }

        public void Map(ulong va, ulong pa, ulong size, AddressSpacePartitioned addressSpace, MemoryBlock backingMemory, bool privateMap)
        {
            if (size != 0)
            {
                CheckInEffectiveRange(va + size - 1);
            }

            while (size != 0)
            {
                _pageTable.Map(va, pa);

                EnsureCommitment(va);

                if (privateMap)
                {
                    _nativePageTable.Write((va / PageSize) * PteSize, GetPte(va, addressSpace.GetPointer(va, PageSize)));
                }
                else
                {
                    _nativePageTable.Write((va / PageSize) * PteSize, GetPte(va, backingMemory.GetPointer(pa, PageSize)));
                }

                va += PageSize;
                pa += PageSize;
                size -= PageSize;
            }
        }

        public void Unmap(ulong va, ulong size)
        {
            nint guardPagePtr = GetGuardPagePointer();

            while (size != 0)
            {
                _pageTable.Unmap(va);

                if (va < _effectiveTableBytes)
                {
                    _nativePageTable.Write((va / PageSize) * PteSize, GetPte(va, guardPagePtr));
                }

                va += PageSize;
                size -= PageSize;
            }
        }

        public ulong Read(ulong va)
        {
            CheckInEffectiveRange(va);

            ulong pte = _nativePageTable.Read<ulong>((va / PageSize) * PteSize);

            pte += va & ~(ulong)PageMask;

            return pte + (va & PageMask);
        }

        public void Update(ulong va, nint ptr, ulong size)
        {
            if (size != 0)
            {
                CheckInEffectiveRange(va + size - 1);
            }

            ulong remainingSize = size;

            while (remainingSize != 0)
            {
                EnsureCommitment(va);

                _nativePageTable.Write((va / PageSize) * PteSize, GetPte(va, ptr));

                va += PageSize;
                ptr += PageSize;
                remainingSize -= PageSize;
            }
        }

        private void EnsureCommitment(ulong va)
        {
            ulong bit = va >> _pageCommitmentBits;

            int index = (int)(bit / (sizeof(ulong) * 8));
            int shift = (int)(bit % (sizeof(ulong) * 8));

            ulong mask = 1UL << shift;

            ulong oldMask = _pageCommitmentBitmap[index];

            if ((oldMask & mask) == 0)
            {
                lock (_pageCommitmentBitmap)
                {
                    oldMask = _pageCommitmentBitmap[index];

                    if ((oldMask & mask) != 0)
                    {
                        return;
                    }

                    _nativePageTable.Commit(bit * _hostPageSize, _hostPageSize);

                    Span<ulong> pageSpan = MemoryMarshal.Cast<byte, ulong>(_nativePageTable.GetSpan(bit * _hostPageSize, (int)_hostPageSize));

                    Debug.Assert(pageSpan.Length == _entriesPerPtPage);

                    nint guardPagePtr = GetGuardPagePointer();

                    for (int i = 0; i < pageSpan.Length; i++)
                    {
                        pageSpan[i] = GetPte((bit << _pageCommitmentBits) | ((ulong)i * PageSize), guardPagePtr);
                    }

                    _pageCommitmentBitmap[index] = oldMask | mask;
                }
            }
        }

        private nint GetGuardPagePointer()
        {
            return _nativePageTable.GetPointer(_nativePageTable.Size - _hostPageSize, _hostPageSize);
        }

        private static ulong GetPte(ulong va, nint ptr)
        {
            Debug.Assert((va & PageMask) == 0);

            return (ulong)ptr - va;
        }

        public ulong GetPhysicalAddress(ulong va)
        {
            return _pageTable.Read(va) + (va & PageMask);
        }

        private ulong VirtualMemoryEvent(ulong address, ulong size, bool write)
        {
            if (address < _nativePageTable.Size - _hostPageSize)
            {
                // Some prefetch instructions do not cause faults with invalid addresses.
                // Retry if we are hitting a case where the page table is unmapped, the next
                // run will execute the actual instruction.
                // The address loaded from the page table will be invalid, and it should hit the else case
                // if the instruction faults on unmapped or protected memory.

                ulong va = address * (PageSize / sizeof(ulong));

                EnsureCommitment(va);

                return (ulong)_nativePageTable.Pointer + address;
            }
            else
            {
                throw new InvalidMemoryRegionException();
            }
        }

        private void Dispose(bool disposing)
        {
            if (!_disposed)
            {
                if (disposing)
                {
                    NativeSignalHandler.RemoveTrackedRegion((nuint)_nativePageTable.Pointer);

                    _nativePageTable.Dispose();
                }

                _disposed = true;
            }
        }

        public void Dispose()
        {
            Dispose(disposing: true);
            GC.SuppressFinalize(this);
        }
    }
}
