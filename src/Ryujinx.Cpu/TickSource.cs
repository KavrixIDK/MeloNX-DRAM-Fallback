using System;
using System.Diagnostics;
using System.Threading;

namespace Ryujinx.Cpu
{
    public class TickSource : ITickSource
    {
        private sealed class TickSnapshot
        {
            public long HostTicks { get; }
            public long ElapsedTicks { get; }
            public long TickScalar { get; }

            public TickSnapshot(long hostTicks, long elapsedTicks, long tickScalar)
            {
                HostTicks = hostTicks;
                ElapsedTicks = elapsedTicks;
                TickScalar = tickScalar;
            }

            public long GetElapsedTicks(long hostTicks)
            {
                return ElapsedTicks + (hostTicks - HostTicks) * TickScalar / ITickSource.RealityTickScalar;
            }
        }

        private readonly Stopwatch _tickCounter;
        private readonly double _hostTickFreq;
        private readonly object _tickScalarLock = new();
        private TickSnapshot _snapshot;

        /// <inheritdoc/>
        public ulong Frequency { get; }

        /// <inheritdoc/>
        public ulong Counter => (ulong)(ElapsedSeconds * Frequency);


        public long TickScalar
        {
            get => Volatile.Read(ref _snapshot).TickScalar;
            set
            {
                lock (_tickScalarLock)
                {
                    long hostTicks = _tickCounter.ElapsedTicks;
                    TickSnapshot snapshot = Volatile.Read(ref _snapshot);

                    Volatile.Write(ref _snapshot, new TickSnapshot(hostTicks, snapshot.GetElapsedTicks(hostTicks), value));
                }
            }
        }

        private long ElapsedTicks
        {
            get
            {
                TickSnapshot snapshot = Volatile.Read(ref _snapshot);

                return snapshot.GetElapsedTicks(_tickCounter.ElapsedTicks);
            }
        }

        /// <inheritdoc/>

        public TimeSpan ElapsedTime => Stopwatch.GetElapsedTime(0, ElapsedTicks);

        /// <inheritdoc/>
        public double ElapsedSeconds => ElapsedTicks * _hostTickFreq;

        public TickSource(ulong frequency)
        {
            Frequency = frequency;
            _hostTickFreq = 1.0 / Stopwatch.Frequency;
            _snapshot = new TickSnapshot(0, 0, ITickSource.RealityTickScalar);

            _tickCounter = new Stopwatch();
            _tickCounter.Start();
        }

        /// <inheritdoc/>
        public void Suspend()
        {
            _tickCounter.Stop();
        }

        /// <inheritdoc/>
        public void Resume()
        {
            _tickCounter.Start();
        }
    }
}
