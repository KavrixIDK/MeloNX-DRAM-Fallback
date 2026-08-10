using System;

namespace Ryujinx.Memory
{
    /// <summary>
    /// Exposes the physical RAM of the host device, as reported by the native app shell
    /// (MeloNX on iOS) via the "MELONX_DEVICE_RAM_MB" environment variable.
    ///
    /// This is intentionally separate from any guest-declared MemoryConfiguration/DramSize:
    /// that value reflects what the *game* asks for, not what the host device actually has.
    /// Several call sites in the memory manager and JIT caches used to size fixed reservations
    /// based on assumptions that hold on desktop hardware (or simply used the guest DRAM size
    /// as a stand-in for host RAM), which is unsafe on iOS devices without the "Extended
    /// Virtual Addressing" entitlement, where total usable virtual address space can be as
    /// low as ~3.3 GiB on a 3 GB RAM device (e.g. iPad 9th generation).
    ///
    /// When the environment variable is not present (desktop Ryujinx, or any host that does
    /// not set it), every value here defaults to "unknown", and every call site that reads
    /// this class falls back to its original, unmodified behaviour.
    /// </summary>
    public static class DeviceMemoryInfo
    {
        private const string EnvVarName = "MELONX_DEVICE_RAM_MB";

        /// <summary>
        /// Physical RAM of the host device in bytes, or 0 if unknown (the app shell did not
        /// report it, e.g. on desktop platforms).
        /// </summary>
        public static readonly ulong PhysicalRamBytes = GetPhysicalRamBytes();

        /// <summary>
        /// True when the host device is known to have a low amount of physical RAM
        /// (&lt;= 4 GiB). Used to scale down otherwise-fixed reservations that would
        /// otherwise risk exhausting the small usable virtual address space such devices
        /// have available without the Extended Virtual Addressing entitlement.
        /// </summary>
        public static readonly bool IsLowMemoryDevice = PhysicalRamBytes > 0 && PhysicalRamBytes <= 4UL * 1024 * 1024 * 1024;

        /// <summary>
        /// True for the most constrained tier we specifically special-case: ~3 GB class
        /// devices such as the iPad (9th generation) / iPad mini 5 / iPad Air 3 (3 GB RAM,
        /// no Extended Virtual Addressing available). Slightly more aggressive reductions
        /// apply here than the general <see cref="IsLowMemoryDevice"/> tier.
        /// </summary>
        public static readonly bool IsVeryLowMemoryDevice = PhysicalRamBytes > 0 && PhysicalRamBytes <= 7UL * 1024 * 1024 * 1024 / 2; // 3.5 GiB

        private static ulong GetPhysicalRamBytes()
        {
            string value = Environment.GetEnvironmentVariable(EnvVarName);

            if (!string.IsNullOrEmpty(value) && ulong.TryParse(value, out ulong ramMb) && ramMb > 0)
            {
                return ramMb * 1024UL * 1024UL;
            }

            return 0;
        }
    }
}
