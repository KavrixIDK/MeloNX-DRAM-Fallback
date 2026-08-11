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
                // low-RAM-tier total. History: started at 2 GiB (1642 MiB here), dropped to
                // 1.5 GiB (1232 MiB) after a Mario 3D World crash log showed a later-stage
                // allocator (AddressSpacePartitionAllocator, GPU buffer reprotection) running
                // out of room. That went too far the other way: Mii Maker's SetHeapSize then
                // failed outright (retried for 33s, "KernelSvc: SetHeapSize(...) = OutOfMemory"
                // in the log, then a guest Fatal error) at 1232 MiB - some system applets need
                // more heap than they look like they should. Back to 1642 MiB; compensated for
                // Mario's later failure by shrinking AddressSpacePartitionAllocator's window
                // block further instead (see that file) rather than cutting this again.
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
                // MeloNX addition: real 4GiB Applet pool (507 MiB) scaled down, see
                // GetApplicationPoolSize's MemoryArrangeLowRAM comment for the 2026-08-11 update.
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
                // MeloNX addition, see MemoryConfiguration.MemoryConfigurationLowRAM
                // (2026-08-11: reduced from 2 GiB to 1.5 GiB after a real crash log).
                MemorySize.MemorySizeLowRAM => 2 * GiB,
                _ => throw new ArgumentException($"Invalid memory size \"{size}\"."),
            };
        }
    }
}
