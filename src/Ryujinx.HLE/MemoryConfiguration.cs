using Ryujinx.HLE.HOS.Kernel.Common;
using System;

namespace Ryujinx.HLE
{
    public enum MemoryConfiguration
    {
        MemoryConfiguration4GiB = 0,
        MemoryConfiguration6GiB = 1,
        MemoryConfiguration8GiB = 2,
        MemoryConfiguration12GiB = 3,
        MemoryConfiguration4GiBAppletDev = 4,
        MemoryConfiguration4GiBSystemDev = 5,
        MemoryConfiguration6GiBAppletDev = 6,
        // MeloNX addition (not a real Nintendo hardware arrangement): a reduced-size
        // configuration for iOS devices with very little physical RAM and no Extended
        // Virtual Addressing entitlement (e.g. iPad 9th gen, 3 GB RAM), where the usual
        // 4 GiB DRAM reservation alone can exceed the entire usable virtual address space
        // ceiling (~3.3-3.4 GiB on such devices). Pool split below is Nintendo's real 4GiB
        // split (KSystemControl.cs) scaled down proportionally (Application/Applet at 50%,
        // NvServices kept at its fixed real size, System/service pool gets the remainder -
        // verified non-negative). See DeviceMemoryInfo.IsVeryLowMemoryDevice for the gate.
        MemoryConfigurationLowRAM = 7,
    }

    static class MemoryConfigurationExtensions
    {
        private const ulong GiB = 1024 * 1024 * 1024;

        extension(MemoryConfiguration configuration)
        {
            public MemoryArrange KernelMemoryArrange => configuration switch
            {
#pragma warning disable IDE0055 // Disable formatting
                MemoryConfiguration.MemoryConfiguration4GiB          => MemoryArrange.MemoryArrange4GiB,
                MemoryConfiguration.MemoryConfiguration4GiBAppletDev => MemoryArrange.MemoryArrange4GiBAppletDev,
                MemoryConfiguration.MemoryConfiguration4GiBSystemDev => MemoryArrange.MemoryArrange4GiBSystemDev,
                MemoryConfiguration.MemoryConfiguration6GiB          => MemoryArrange.MemoryArrange6GiB,
                MemoryConfiguration.MemoryConfiguration6GiBAppletDev => MemoryArrange.MemoryArrange6GiBAppletDev,
                MemoryConfiguration.MemoryConfiguration8GiB          => MemoryArrange.MemoryArrange8GiB,
                MemoryConfiguration.MemoryConfiguration12GiB         => MemoryArrange.MemoryArrange12GiB,
                MemoryConfiguration.MemoryConfigurationLowRAM        => MemoryArrange.MemoryArrangeLowRAM,
                _ => throw new AggregateException($"Invalid memory configuration \"{configuration}\"."),
#pragma warning restore IDE0055
            };
            
            public MemorySize KernelMemorySize => configuration switch
            {
#pragma warning disable IDE0055 // Disable formatting
                MemoryConfiguration.MemoryConfiguration4GiB or
                    MemoryConfiguration.MemoryConfiguration4GiBAppletDev or
                    MemoryConfiguration.MemoryConfiguration4GiBSystemDev => MemorySize.MemorySize4GiB,
                MemoryConfiguration.MemoryConfiguration6GiB or
                    MemoryConfiguration.MemoryConfiguration6GiBAppletDev => MemorySize.MemorySize6GiB,
                MemoryConfiguration.MemoryConfiguration8GiB              => MemorySize.MemorySize8GiB,
                MemoryConfiguration.MemoryConfiguration12GiB             => MemorySize.MemorySize12GiB,
                MemoryConfiguration.MemoryConfigurationLowRAM            => MemorySize.MemorySizeLowRAM,
                _ => throw new AggregateException($"Invalid memory configuration \"{configuration}\"."),
#pragma warning restore IDE0055
            };
            
            public ulong DramSize => configuration switch
            {
#pragma warning disable IDE0055 // Disable formatting
                MemoryConfiguration.MemoryConfiguration4GiB or
                    MemoryConfiguration.MemoryConfiguration4GiBAppletDev or
                    MemoryConfiguration.MemoryConfiguration4GiBSystemDev => 4 * GiB,
                MemoryConfiguration.MemoryConfiguration6GiB or
                    MemoryConfiguration.MemoryConfiguration6GiBAppletDev => 6 * GiB,
                MemoryConfiguration.MemoryConfiguration8GiB          => 8 * GiB,
                MemoryConfiguration.MemoryConfiguration12GiB         => 12 * GiB,
                MemoryConfiguration.MemoryConfigurationLowRAM        => 2 * GiB,
                _ => throw new AggregateException($"Invalid memory configuration \"{configuration}\"."),
#pragma warning restore IDE0055
            };
        }
    }
}
