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
                // MeloNX addition: real 4GiB Application pool (3285 MiB) scaled to 50% for
                // a 2 GiB total. Verified in isolation (see KernelInit.GetMemoryRegions
                // callers) that this leaves the System/service pool positive (~100 MiB).
                MemoryArrange.MemoryArrangeLowRAM => 1642 * MiB,
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
                // MeloNX addition: real 4GiB Applet pool (507 MiB) scaled to 50%.
                MemoryArrange.MemoryArrangeLowRAM => 253 * MiB,
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
                // MeloNX addition, see MemoryConfiguration.MemoryConfigurationLowRAM.
                MemorySize.MemorySizeLowRAM => 2 * GiB,
                _ => throw new ArgumentException($"Invalid memory size \"{size}\"."),
            };
        }
    }
}
