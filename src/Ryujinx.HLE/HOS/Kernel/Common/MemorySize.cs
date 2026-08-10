namespace Ryujinx.HLE.HOS.Kernel.Common
{
    enum MemorySize : byte
    {
        MemorySize4GiB = 0,
        MemorySize6GiB = 1,
        MemorySize8GiB = 2,
        MemorySize12GiB = 3,
        // MeloNX addition, see MemoryConfiguration.MemoryConfigurationLowRAM.
        MemorySizeLowRAM = 4,
    }
}
