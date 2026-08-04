using Ryujinx.Common.Logging;
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

        /// <summary>
        /// The actual size of the guest virtual address space this page table
        /// can service. Equal to the <c>asSize</c> passed to the constructor,
        /// unless the full size could not be reserved (see <see cref="ReserveTable"/>),
        /// in which case it reflects the smaller size that was actually granted.
        /// Callers that size other address-space-derived structures (bounds
        /// checks, page bitmaps, etc.) MUST use this value instead of the
        /// originally requested size once the page table has been constructed -
        /// otherwise an address that passes a bounds check against the original
        /// (larger) size could still be out of range for this page table's
        /// internal commitment bitmap, causing an unhandled crash instead of a
        /// clean, catchable memory access error.
        /// </summary>
        public ulong EffectiveAddressSpaceSize { get; }

        private static readonly int[] ReserveRetryDelaysMs = { 25, 75, 200, 500 };

        // Smallest real Nintendo Switch address space size (the "32-bit"
        // address space type). We stop reducing here because going smaller
        // does not correspond to any address space layout Horizon OS actually
        // uses on real hardware.
        private const ulong MinAddressSpaceSize = 4UL * 1024 * 1024 * 1024;

        /// <summary>
        /// Reserves the native page table, which tracks the guest CPU's
        /// virtual address space bookkeeping (NOT physical RAM - this is a
        /// separate reservation from the DRAM fix in Switch.cs). First
        /// retries the full requested size with a short backoff, in case iOS
        /// just needs a moment to free up address space. If it still refuses,
        /// falls back to halving the size (down to a 4 GiB floor) instead of
        /// crashing - this is for devices that cannot enable Extended Virtual
        /// Addressing and genuinely cannot get the full size no matter how
        /// long we wait.
        ///
        /// IMPORTANT CAVEAT: unlike the DRAM fallback, a smaller table is NOT
        /// guaranteed to let a title run further. It only covers guest
        /// virtual addresses up to the reduced size - if the title's actual
        /// code, heap, TLS, or stack end up at addresses beyond that (which
        /// depends on how Horizon OS lays out that specific title, not how
        /// much RAM it uses), access to them will still fail. The failure is
        /// still a clean, catchable exception rather than a crash with no
        /// information, but this fix may end up helping only some titles.
        ///
        /// The actual size used is returned via <paramref name="effectiveAsSize"/>
        /// so the caller can size its own address-tracking bitmap to match -
        /// the two must always agree, or later accesses could throw for
        /// addresses that should have been valid.
        /// </summary>
        private static MemoryBlock ReserveTable(ulong asSize, ulong hostPageSize, out ulong effectiveAsSize)
        {
            ulong size = asSize;

            while (true)
            {
                ulong tableSize = (size / PageSize) * PteSize + hostPageSize;

                for (int attempt = 0; ; attempt++)
                {
                    try
                    {
                        MemoryBlock block = new(tableSize, MemoryAllocationFlags.Reserve);

                        if (size != asSize)
                        {
                            Logger.Warning?.Print(LogClass.Cpu,
                                $"Could not reserve the native page table for a {asSize}-byte address space, continuing with {size} bytes instead. " +
                                "Titles using addresses beyond this range will fail with a memory access error instead of running.");
                        }

                        effectiveAsSize = size;
                        return block;
                    }
                    catch (SystemException)
                    {
                        if (attempt < ReserveRetryDelaysMs.Length)
                        {
                            System.Threading.Thread.Sleep(ReserveRetryDelaysMs[attempt]);
                            continue;
                        }

                        if (size <= MinAddressSpaceSize)
                        {
                            // Nothing worked, not even the smallest fallback -
                            // let the original error surface.
                            throw;
                        }

                        break;
                    }
                }

                size /= 2;
            }
        }

        public NativePageTable(ulong asSize)
        {
            ulong hostPageSize = MemoryBlock.GetPageSize();

            _entriesPerPtPage = (int)(hostPageSize / sizeof(ulong));
            _bitsPerPtPage = BitOperations.Log2((uint)_entriesPerPtPage);
            _pageCommitmentBits = PageBits + _bitsPerPtPage;

            _hostPageSize = hostPageSize;
            _pageTable = new PageTable<ulong>();
            _nativePageTable = ReserveTable(asSize, _hostPageSize, out ulong effectiveAsSize);
            EffectiveAddressSpaceSize = effectiveAsSize;
            _pageCommitmentBitmap = new ulong[(effectiveAsSize >> _pageCommitmentBits) / (sizeof(ulong) * 8)];

            ulong ptStart = (ulong)_nativePageTable.Pointer;
            ulong ptEnd = ptStart + _nativePageTable.Size;

            _trackingEvent = VirtualMemoryEvent;

            bool added = NativeSignalHandler.AddTrackedRegion((nuint)ptStart, (nuint)ptEnd, Marshal.GetFunctionPointerForDelegate(_trackingEvent));

            if (!added)
            {
                throw new InvalidOperationException("Number of allowed tracked regions exceeded.");
            }
        }

        public void Map(ulong va, ulong pa, ulong size, AddressSpacePartitioned addressSpace, MemoryBlock backingMemory, bool privateMap)
        {
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
                _nativePageTable.Write((va / PageSize) * PteSize, GetPte(va, guardPagePtr));

                va += PageSize;
                size -= PageSize;
            }
        }

        public ulong Read(ulong va)
        {
            ulong pte = _nativePageTable.Read<ulong>((va / PageSize) * PteSize);

            pte += va & ~(ulong)PageMask;

            return pte + (va & PageMask);
        }

        public void Update(ulong va, nint ptr, ulong size)
        {
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
