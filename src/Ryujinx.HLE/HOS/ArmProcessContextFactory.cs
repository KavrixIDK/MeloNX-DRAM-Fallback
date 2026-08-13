using Ryujinx.Common.Configuration;
using Ryujinx.Common.Logging;
using Ryujinx.Cpu;
using Ryujinx.Cpu.AppleHv;
using Ryujinx.Cpu.Jit;
using Ryujinx.Cpu.LightningJit;
using Ryujinx.Graphics.Gpu;
using Ryujinx.HLE.HOS.Kernel;
using Ryujinx.HLE.HOS.Kernel.Process;
using Ryujinx.Memory;
using System;
using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS
{
    class ArmProcessContextFactory : IProcessContextFactory
    {
        private readonly ITickSource _tickSource;
        private readonly GpuContext _gpu;
        private readonly string _titleIdText;
        private readonly string _displayVersion;
        private readonly bool _diskCacheEnabled;
        private readonly string _diskCacheSelector;
        private readonly ulong _codeAddress;
        private readonly ulong _codeSize;

        public IDiskCacheLoadState DiskCacheLoadState { get; private set; }

        public ArmProcessContextFactory(
            ITickSource tickSource,
            GpuContext gpu,
            string titleIdText,
            string displayVersion,
            bool diskCacheEnabled,
            string diskCacheSelector,
            ulong codeAddress,
            ulong codeSize)
        {
            _tickSource = tickSource;
            _gpu = gpu;
            _titleIdText = titleIdText;
            _displayVersion = displayVersion;
            _diskCacheEnabled = diskCacheEnabled;
            _diskCacheSelector = diskCacheSelector;
            _codeAddress = codeAddress;
            _codeSize = codeSize;
        }

        public IProcessContext Create(KernelContext context, ulong pid, ulong addressSpaceSize, InvalidAccessHandler invalidAccessHandler, bool for64Bit)
        {
            IArmProcessContext processContext;

            bool isArm64Host = RuntimeInformation.ProcessArchitecture == Architecture.Arm64;

            if (OperatingSystem.IsMacOS() && isArm64Host && for64Bit && context.Device.Configuration.UseHypervisor)
            {
                HvEngine cpuEngine = new(_tickSource);
                HvMemoryManager memoryManager = new(context.Memory, addressSpaceSize, invalidAccessHandler);
                processContext = new ArmProcessContext<HvMemoryManager>(pid, cpuEngine, _gpu, memoryManager, addressSpaceSize, for64Bit);
            }
            else
            {
                MemoryManagerMode mode = context.Device.Configuration.MemoryManagerMode;

                if (!MemoryBlock.SupportsFlags(MemoryAllocationFlags.ViewCompatible))
                {
                    Logger.Warning?.Print(LogClass.Cpu, "Host system doesn't support views, falling back to software page table");

                    mode = MemoryManagerMode.SoftwarePageTable;
                }

                ICpuEngine cpuEngine = isArm64Host && (mode == MemoryManagerMode.HostMapped || mode == MemoryManagerMode.HostMappedUnsafe) && !context.Device.Configuration.EnableGdbStub
                    ? new LightningJitEngine(_tickSource)
                    : new JitEngine(_tickSource);

                AddressSpace addressSpace = null;

                // We want to use host tracked mode if the host page size is > 4KB.
                if ((mode == MemoryManagerMode.HostMapped || mode == MemoryManagerMode.HostMappedUnsafe) && MemoryBlock.GetPageSize() <= 0x1000)
                {
                    if (!AddressSpace.TryCreate(context.Memory, addressSpaceSize, out addressSpace))
                    {
                        Logger.Warning?.Print(LogClass.Cpu, "Address space creation failed, falling back to software page table");

                        mode = MemoryManagerMode.SoftwarePageTable;
                    }
                }

                switch (mode)
                {
                    case MemoryManagerMode.SoftwarePageTable:
                        MemoryManager memoryManager = new(context.Memory, addressSpaceSize, invalidAccessHandler);
                        processContext = new ArmProcessContext<MemoryManager>(pid, cpuEngine, _gpu, memoryManager, addressSpaceSize, for64Bit);
                        break;

                    case MemoryManagerMode.HostMapped:
                    case MemoryManagerMode.HostMappedUnsafe:
                        if (addressSpace == null)
                        {
                            // MeloNX addition: on very-low-memory iOS devices, cap the address
                            // space size passed to MemoryManagerHostTracked (and, critically,
                            // to KPageTableBase via ArmProcessContext.AddressSpaceSize below -
                            // that becomes KPageTableBase's _reservedAddressSpaceSize). This
                            // does two things at once, consistently:
                            //  1) Ryujinx.Cpu.Jit.HostTracked.NativePageTable's reservation
                            //     (one of the single largest fixed VA costs in the whole app)
                            //     scales with this same value, so a 39-bit/512GiB game goes
                            //     from a ~1 GiB table down to ~128 MiB at 36-bit/64GiB - and a
                            //     32-bit or already-36-bit game is untouched by the Math.Min.
                            //  2) KPageTableBase.CreateUserAddressSpace already has a fallback
                            //     for exactly this situation (host can't back the full nominal
                            //     address space) - when _reservedAddressSpaceSize < addrSpaceEnd
                            //     it recomputes the Alias/Stack/TlsIo region sizes proportional
                            //     to the smaller width using Nintendo/Ryujinx's own formula
                            //     (bit-shifts off log2 of the reserved size), not a number this
                            //     fork invented. That path exists for other hosts that can't
                            //     get the full reservation either; iOS just never triggered it
                            //     before because addressSpaceSize was always passed through
                            //     unchanged here. Using it keeps the guest kernel's own
                            //     reported address-space size consistent with what actually
                            //     gets reserved, which a plain NativePageTable-only cap did NOT
                            //     do (see that file's history comment) - that inconsistency is
                            //     exactly what let one title's SDK-chosen shared memory address
                            //     land past the cap and crash. Only applies to the 39-bit case
                            //     (32-bit is 4GiB, 36-bit is 64GiB - both already <= the cap).
                            ulong effectiveAddressSpaceSize = DeviceMemoryInfo.IsVeryLowMemoryDevice
                                ? Math.Min(addressSpaceSize, 1UL << 36)
                                : addressSpaceSize;

                            MemoryManagerHostTracked memoryManagerHostTracked = new(context.Memory, effectiveAddressSpaceSize, mode == MemoryManagerMode.HostMappedUnsafe, invalidAccessHandler);
                            processContext = new ArmProcessContext<MemoryManagerHostTracked>(pid, cpuEngine, _gpu, memoryManagerHostTracked, effectiveAddressSpaceSize, for64Bit);
                        }
                        else
                        {
                            if (addressSpaceSize != addressSpace.AddressSpaceSize)
                            {
                                Logger.Warning?.Print(LogClass.Emulation, $"Allocated address space (0x{addressSpace.AddressSpaceSize:X}) is smaller than guest application requirements (0x{addressSpaceSize:X})");
                            }

                            MemoryManagerHostMapped memoryManagerHostMapped = new(addressSpace, mode == MemoryManagerMode.HostMappedUnsafe, invalidAccessHandler);
                            processContext = new ArmProcessContext<MemoryManagerHostMapped>(pid, cpuEngine, _gpu, memoryManagerHostMapped, addressSpace.AddressSpaceSize, for64Bit);
                        }

                        break;

                    default:
                        throw new InvalidOperationException($"{nameof(mode)} contains an invalid value: {mode}");
                }
            }

            DiskCacheLoadState = processContext.Initialize(_titleIdText, _displayVersion, _diskCacheEnabled, _codeAddress, _codeSize, _diskCacheSelector ?? "default");

            return processContext;
        }
    }
}
