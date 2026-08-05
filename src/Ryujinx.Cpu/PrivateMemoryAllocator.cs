using Ryujinx.Common;
using Ryujinx.Common.Logging;
using Ryujinx.Memory;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Threading;

namespace Ryujinx.Cpu
{
    class PrivateMemoryAllocator : PrivateMemoryAllocatorImpl<PrivateMemoryAllocator.Block>
    {
        public const ulong InvalidOffset = ulong.MaxValue;

        public class Block : IComparable<Block>
        {
            public MemoryBlock Memory { get; private set; }
            public ulong Size { get; }

            private readonly struct Range : IComparable<Range>
            {
                public ulong Offset { get; }
                public ulong Size { get; }

                public Range(ulong offset, ulong size)
                {
                    Offset = offset;
                    Size = size;
                }

                public int CompareTo(Range other)
                {
                    return Offset.CompareTo(other.Offset);
                }
            }

            private readonly List<Range> _freeRanges;

            public Block(MemoryBlock memory, ulong size)
            {
                Memory = memory;
                Size = size;
                _freeRanges =
                [
                    new(0, size)
                ];
            }

            public ulong Allocate(ulong size, ulong alignment)
            {
                for (int i = 0; i < _freeRanges.Count; i++)
                {
                    Range range = _freeRanges[i];

                    ulong alignedOffset = BitUtils.AlignUp(range.Offset, alignment);
                    ulong sizeDelta = alignedOffset - range.Offset;
                    ulong usableSize = range.Size - sizeDelta;

                    if (sizeDelta < range.Size && usableSize >= size)
                    {
                        _freeRanges.RemoveAt(i);

                        if (sizeDelta != 0)
                        {
                            InsertFreeRange(range.Offset, sizeDelta);
                        }

                        ulong endOffset = range.Offset + range.Size;
                        ulong remainingSize = endOffset - (alignedOffset + size);
                        if (remainingSize != 0)
                        {
                            InsertFreeRange(endOffset - remainingSize, remainingSize);
                        }

                        return alignedOffset;
                    }
                }

                return InvalidOffset;
            }

            public void Free(ulong offset, ulong size)
            {
                InsertFreeRangeComingled(offset, size);
            }

            private void InsertFreeRange(ulong offset, ulong size)
            {
                Range range = new(offset, size);
                int index = _freeRanges.BinarySearch(range);
                if (index < 0)
                {
                    index = ~index;
                }

                _freeRanges.Insert(index, range);
            }

            private void InsertFreeRangeComingled(ulong offset, ulong size)
            {
                ulong endOffset = offset + size;
                Range range = new(offset, size);
                int index = _freeRanges.BinarySearch(range);
                if (index < 0)
                {
                    index = ~index;
                }

                if (index < _freeRanges.Count && _freeRanges[index].Offset == endOffset)
                {
                    endOffset = _freeRanges[index].Offset + _freeRanges[index].Size;
                    _freeRanges.RemoveAt(index);
                }

                if (index > 0 && _freeRanges[index - 1].Offset + _freeRanges[index - 1].Size == offset)
                {
                    offset = _freeRanges[index - 1].Offset;
                    _freeRanges.RemoveAt(--index);
                }

                range = new Range(offset, endOffset - offset);

                _freeRanges.Insert(index, range);
            }

            public bool IsTotallyFree()
            {
                if (_freeRanges.Count == 1 && _freeRanges[0].Size == Size)
                {
                    Debug.Assert(_freeRanges[0].Offset == 0);
                    return true;
                }

                return false;
            }

            public int CompareTo(Block other)
            {
                return Size.CompareTo(other.Size);
            }

            public virtual void Destroy()
            {
                Memory.Dispose();
            }
        }

        public PrivateMemoryAllocator(ulong blockAlignment, MemoryAllocationFlags allocationFlags) : base(blockAlignment, allocationFlags)
        {
        }

        public PrivateMemoryAllocation Allocate(ulong size, ulong alignment)
        {
            Allocation allocation = Allocate(size, alignment, CreateBlock);

            return new PrivateMemoryAllocation(this, allocation.Block, allocation.Offset, allocation.Size);
        }

        private Block CreateBlock(MemoryBlock memory, ulong size)
        {
            return new Block(memory, size);
        }
    }

    class PrivateMemoryAllocatorImpl<T> : IDisposable where T : PrivateMemoryAllocator.Block
    {
        private const ulong InvalidOffset = ulong.MaxValue;

        public readonly struct Allocation
        {
            public T Block { get; }
            public ulong Offset { get; }
            public ulong Size { get; }

            public Allocation(T block, ulong offset, ulong size)
            {
                Block = block;
                Offset = offset;
                Size = size;
            }
        }

        private readonly List<T> _blocks;

        private readonly ulong _blockAlignment;
        private readonly MemoryAllocationFlags _allocationFlags;

        private static readonly int[] BlockReserveRetryDelaysMs = { 25, 75, 200, 500 };

        // Remembers the size of the last block we actually managed to
        // reserve. On a memory constrained device, retrying the full
        // idealSize (up to 4 GiB) from scratch on every single new block -
        // only to fall all the way back down again - costs several seconds
        // and several failed attempts each time (visible as multi-second
        // gaps between "ReserveBlockMemory" log lines). Starting near the
        // last known-good size instead skips most of that wasted cascade.
        // We still double it each time (capped at idealSize) rather than
        // reusing the exact same value forever, so this can grow back up if
        // conditions improve instead of staying stuck at the first small
        // size we ever fell back to.
        private ulong _lastSuccessfulBlockSize;

        public PrivateMemoryAllocatorImpl(ulong blockAlignment, MemoryAllocationFlags allocationFlags)
        {
            _blocks = [];
            _blockAlignment = blockAlignment;
            _allocationFlags = allocationFlags;
        }

        /// <summary>
        /// Reserves a new backing block, starting at <paramref name="idealSize"/>
        /// bytes (the requested size rounded up to <see cref="_blockAlignment"/>,
        /// which can be as large as 4GB for address space partitions) - or, if a
        /// previous call already had to fall back to a smaller size, starting
        /// closer to that instead (see <see cref="_lastSuccessfulBlockSize"/>).
        /// On memory constrained devices (mainly iOS) that reservation can be
        /// refused even though a smaller one would succeed, so this retries
        /// the starting size with a short backoff first, then falls back to
        /// progressively smaller blocks instead of crashing - but never below
        /// <paramref name="minSize"/>, which is the minimum needed to actually
        /// hold this specific allocation.
        /// </summary>
        private MemoryBlock ReserveBlockMemory(ulong idealSize, ulong minSize)
        {
            ulong size = _lastSuccessfulBlockSize == 0
                ? idealSize
                : Math.Clamp(_lastSuccessfulBlockSize * 2, minSize, idealSize);

            while (true)
            {
                for (int attempt = 0; ; attempt++)
                {
                    try
                    {
                        MemoryBlock block = new(size, _allocationFlags);

                        if (size != idealSize)
                        {
                            Logger.Warning?.Print(LogClass.Cpu,
                                $"Could not reserve a {idealSize}-byte private memory block, continuing with {size} bytes instead. " +
                                "This block will hold fewer future allocations than usual and may be replaced more often.");
                        }

                        _lastSuccessfulBlockSize = size;

                        return block;
                    }
                    catch (SystemException)
                    {
                        if (attempt < BlockReserveRetryDelaysMs.Length)
                        {
                            Thread.Sleep(BlockReserveRetryDelaysMs[attempt]);
                            continue;
                        }

                        if (size <= minSize)
                        {
                            // Nothing worked, not even the minimum size actually
                            // needed for this allocation - let the original
                            // failure surface.
                            throw;
                        }

                        break;
                    }
                }

                ulong halved = size / 2;
                size = halved > minSize ? halved : minSize;
            }
        }

        protected Allocation Allocate(ulong size, ulong alignment, Func<MemoryBlock, ulong, T> createBlock)
        {
            // Ensure we have a sane alignment value.
            if ((ulong)(int)alignment != alignment || (int)alignment <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(alignment), $"Invalid alignment 0x{alignment:X}.");
            }

            for (int i = 0; i < _blocks.Count; i++)
            {
                T block = _blocks[i];

                if (block.Size >= size)
                {
                    ulong offset = block.Allocate(size, alignment);
                    if (offset != InvalidOffset)
                    {
                        return new Allocation(block, offset, size);
                    }
                }
            }

            ulong blockAlignedSize = BitUtils.AlignUp(size, _blockAlignment);
            ulong minBlockSize = BitUtils.AlignUp(size, alignment);

            MemoryBlock memory = ReserveBlockMemory(blockAlignedSize, minBlockSize);
            T newBlock = createBlock(memory, memory.Size);

            InsertBlock(newBlock);

            ulong newBlockOffset = newBlock.Allocate(size, alignment);
            Debug.Assert(newBlockOffset != InvalidOffset);

            return new Allocation(newBlock, newBlockOffset, size);
        }

        public void Free(PrivateMemoryAllocator.Block block, ulong offset, ulong size)
        {
            block.Free(offset, size);

            if (block.IsTotallyFree())
            {
                for (int i = 0; i < _blocks.Count; i++)
                {
                    if (_blocks[i] == block)
                    {
                        _blocks.RemoveAt(i);
                        break;
                    }
                }

                block.Destroy();
            }
        }

        private void InsertBlock(T block)
        {
            int index = _blocks.BinarySearch(block);
            if (index < 0)
            {
                index = ~index;
            }

            _blocks.Insert(index, block);
        }

        public void Dispose()
        {
            for (int i = 0; i < _blocks.Count; i++)
            {
                _blocks[i].Destroy();
            }

            _blocks.Clear();
        }
    }
}
