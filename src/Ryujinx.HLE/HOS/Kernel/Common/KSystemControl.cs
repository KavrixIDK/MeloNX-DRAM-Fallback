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
                // low-RAM-tier total. History: 2 GiB (1642 here) -> 1.5 GiB (1232) after a
                // Mario crash log -> back to 2 GiB after Mii Maker then failed SetHeapSize
                // outright (1232 was not enough; 1642 confirmed enough). But at 2 GiB total,
                // Mario regressed to failing at SetHeapSize too (a real device log showed it
                // getting much further at 1.5 GiB) - the extra 512 MiB DRAM cost outweighed
                // NativePageTable being capped at the time. NativePageTable's cap has since
                // been reverted entirely (proved unsafe - see that file), which makes the
                // overall budget tighter again, not looser. Landed on 1.75 GiB (1437 here) as
                // a middle ground: more than the 1232 that failed Mii Maker, less than the
                // 1642 that cost Mario its progress. Not verified against a real device at
                // this exact value - if Mii Maker fails again, raise towards 1642; if Mario
                // still can't get through SetHeapSize, this needs to come down instead and the
                // real fix is elsewhere (NativePageTable is the only other GiB-scale piece,
                // and it can't safely shrink - see that file's history comment).
                MemoryArrange.MemoryArrangeLowRAM => 1437 * MiB,
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
                MemoryArrange.MemoryArrangeLowRAM => 221 * MiB,
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
                MemorySize.MemorySizeLowRAM => 7 * GiB / 4,
                _ => throw new ArgumentException($"Invalid memory size \"{size}\"."),
            };
        }
    }
}
