namespace Ryujinx.Graphics.Gpu.Engine.MME
{
    /// <summary>
    /// Small FIFO used by GPU macros for pushed arguments.
    /// </summary>
    sealed class MacroFifo
    {
        private const int DefaultCapacity = 16;

        private FifoWord[] _buffer;
        private int _head;
        private int _count;

        /// <summary>
        /// Creates a new macro FIFO.
        /// </summary>
        public MacroFifo()
        {
            _buffer = new FifoWord[DefaultCapacity];
        }

        /// <summary>
        /// Enqueues a new argument word.
        /// </summary>
        /// <param name="value">Argument word to enqueue</param>
        public void Enqueue(FifoWord value)
        {
            if (_count == _buffer.Length)
            {
                Grow();
            }

            _buffer[(_head + _count) & (_buffer.Length - 1)] = value;
            _count++;
        }

        /// <summary>
        /// Attempts to dequeue an argument word.
        /// </summary>
        /// <param name="value">Dequeued word, or default if the FIFO is empty</param>
        /// <returns>True if a word was dequeued, false otherwise</returns>
        public bool TryDequeue(out FifoWord value)
        {
            if (_count == 0)
            {
                value = default;
                return false;
            }

            value = _buffer[_head];
            _head = (_head + 1) & (_buffer.Length - 1);
            _count--;

            return true;
        }

        /// <summary>
        /// Clears all queued argument words.
        /// </summary>
        public void Clear()
        {
            _head = 0;
            _count = 0;
        }

        private void Grow()
        {
            FifoWord[] oldBuffer = _buffer;
            FifoWord[] newBuffer = new FifoWord[oldBuffer.Length << 1];
            int firstChunkLength = oldBuffer.Length - _head;

            if (_count <= firstChunkLength)
            {
                System.Array.Copy(oldBuffer, _head, newBuffer, 0, _count);
            }
            else
            {
                System.Array.Copy(oldBuffer, _head, newBuffer, 0, firstChunkLength);
                System.Array.Copy(oldBuffer, 0, newBuffer, firstChunkLength, _count - firstChunkLength);
            }

            _buffer = newBuffer;
            _head = 0;
        }
    }
}
