using Ryujinx.HLE.HOS.Kernel.Memory;
using System;

namespace Ryujinx.HLE.HOS.Kernel.Common
{
    static class KSystemControl
    {
        private const ulong KiB = 1024;
        private const ulong MiB = 1024 * KiB;
        private const ulong GiB = 1024 * MiB;

        private const ulong PageSize = 4 * KiB;

        private const ulong RequiredNonSecureSystemPoolSizeVi = 0x2238 * PageSize;
        private const ulong RequiredNonSecureSystemPoolSizeNvservices = 0x710 * PageSize;
        private const ulong RequiredNonSecureSystemPoolSizeOther = 0x80 * PageSize;

        private const ulong RequiredNonSecureSystemPoolSize =
            RequiredNonSecureSystemPoolSizeVi +
            RequiredNonSecureSystemPoolSizeNvservices +
            RequiredNonSecureSystemPoolSizeOther;

        public static ulong GetApplicationPoolSize(MemoryArrange arrange)
        {
            return arrange switch
            {
                MemoryArrange.MemoryArrange4GiB or
                MemoryArrange.MemoryArrange4GiBSystemDev or
                MemoryArrange.MemoryArrange6GiBAppletDev => 3285 * MiB,
                MemoryArrange.MemoryArrange4GiBAppletDev => 2048 * MiB,
                MemoryArrange.MemoryArrange6GiB => 4916 * MiB,
                MemoryArrange.MemoryArrange8GiB => 6964 * MiB,
                MemoryArrange.MemoryArrange12GiB => 11060 * MiB,
                // MeloNX addition: real 4GiB Application pool (3285 MiB) scaled down for a
                // low-RAM-tier total. Updated 2026-08-11 after a real-device log (iPad 9,
                // Super Mario 3D World + Bowser's Fury) showed the previous 2 GiB total still
                // ran out of address space at the game's first SetHeapSize call - pushed the
                // total down further to 1.5 GiB (ratio 0.375) to free more headroom for the
                // fixed overhead pieces (JIT cache, native page table, partition windows)
                // that don't scale with this value. Verified in isolation that the System/
                // service pool stays positive (~61 MiB) at these sizes.
                MemoryArrange.MemoryArrangeLowRAM => 1232 * MiB,
                _ => throw new ArgumentException($"Invalid memory arrange \"{arrange}\"."),
            };
        }

        public static ulong GetAppletPoolSize(MemoryArrange arrange)
        {
            return arrange switch
            {
                MemoryArrange.MemoryArrange4GiB => 507 * MiB,
                MemoryArrange.MemoryArrange4GiBAppletDev => 1554 * MiB,
                MemoryArrange.MemoryArrange4GiBSystemDev => 448 * MiB,
                MemoryArrange.MemoryArrange6GiB => 562 * MiB,
                MemoryArrange.MemoryArrange6GiBAppletDev => 2193 * MiB,
                MemoryArrange.MemoryArrange8GiB or
                MemoryArrange.MemoryArrange12GiB => 562 * MiB,
                // MeloNX addition: real 4GiB Applet pool (507 MiB) scaled down, see
                // GetApplicationPoolSize's MemoryArrangeLowRAM comment for the 2026-08-11 update.
                MemoryArrange.MemoryArrangeLowRAM => 190 * MiB,
                _ => throw new ArgumentException($"Invalid memory arrange \"{arrange}\"."),
            };
        }

        public static ulong GetMinimumNonSecureSystemPoolSize()
        {
            return RequiredNonSecureSystemPoolSize;
        }

        public static ulong GetDramEndAddress(MemorySize size)
        {
            return DramMemoryMap.DramBase + GetDramSize(size);
        }

        public static ulong GenerateRandom()
        {
            // TODO
            return 0;
        }

        public static ulong GetDramSize(MemorySize size)
        {
            return size switch
            {
                MemorySize.MemorySize4GiB => 4 * GiB,
                MemorySize.MemorySize6GiB => 6 * GiB,
                MemorySize.MemorySize8GiB => 8 * GiB,
                MemorySize.MemorySize12GiB => 12 * GiB,
                // MeloNX addition, see MemoryConfiguration.MemoryConfigurationLowRAM
                // (2026-08-11: reduced from 2 GiB to 1.5 GiB after a real crash log).
                MemorySize.MemorySizeLowRAM => 3 * GiB / 2,
                _ => throw new ArgumentException($"Invalid memory size \"{size}\"."),
            };
        }
    }
}
