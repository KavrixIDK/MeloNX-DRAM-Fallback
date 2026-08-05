using LibHac.Common;
using LibHac.Ns;
using Ryujinx.Audio.Backends.CompatLayer;
using Ryujinx.Audio.Integration;
using Ryujinx.Common;
using Ryujinx.Common.Configuration;
using Ryujinx.Common.Logging;
using Ryujinx.Cpu;
using Ryujinx.Graphics.Gpu;
using Ryujinx.HLE.FileSystem;
using Ryujinx.HLE.HOS;
using Ryujinx.HLE.HOS.Services.Apm;
using Ryujinx.HLE.HOS.Services.Hid;
using Ryujinx.HLE.Loaders.Processes;
using Ryujinx.HLE.UI;
using Ryujinx.Memory;
using System;
using System.Threading;

namespace Ryujinx.HLE
{
    public class Switch : IDisposable
    {
        /// <summary>
        /// Currently running emulated Switch, if there is one.
        /// <para>
        /// Proper usage of this property null checks it before use, unless the caller is certain that the emulation is running.
        /// </para>
        /// <para>
        /// In case the emulation is running, there might be a way to directly pass the <see cref="Switch" /> instance, which is preferred.
        /// </para>
        /// <para>
        /// The instance is set to <c>this</c> on any <see cref="Switch" /> instantiation, and set to <c>null</c> on any <see cref="Switch" /> disposal.
        /// </para>
        /// </summary>
        public static Switch Shared { get; private set; }

        public HleConfiguration Configuration { get; }
        public IHardwareDeviceDriver AudioDeviceDriver { get; }
        public MemoryBlock Memory { get; }
        public GpuContext Gpu { get; }
        public VirtualFileSystem FileSystem { get; }
        public HOS.Horizon System { get; }

        public bool TurboMode = false;

        public long TickScalar
        {
            get => System?.TickSource?.TickScalar ?? ITickSource.RealityTickScalar;
            set => System.TickSource.TickScalar = value;
        }

        public ProcessLoader Processes { get; }
        public PerformanceStatistics Statistics { get; }
        public Hid Hid { get; }
        public TamperMachine TamperMachine { get; }
        public IHostUIHandler UIHandler { get; }
        public Debugger.Debugger Debugger { get; }

        public int CpuCoresCount = 4; // Switch has a quad-core Tegra X1 SoC

        public VSyncMode VSyncMode { get; set; }
        public bool CustomVSyncIntervalEnabled { get; set; }
        public int CustomVSyncInterval { get; set; }
        public long TargetVSyncInterval { get; set; } = 60;

        public bool IsFrameAvailable => Gpu.Window.IsFrameAvailable;

        public DirtyHacks DirtyHacks { get; }

        // If the OS refuses the very first reservation of guest DRAM (common on
        // memory-constrained iOS devices, where the request can be denied even
        // though the device would have granted it a moment later), retry a few
        // times with short pauses before giving up. This alone fixes most cases -
        // it is not that the device fundamentally lacks the address space, just
        // that iOS did not have a chance to react yet.
        private static readonly int[] DramReserveRetryDelaysMs = { 25, 75, 200, 500 };

        // Only used if every retry above still fails. Falls back to smaller DRAM
        // sizes so titles that do not actually need the full configured amount
        // can still boot instead of crashing outright. Kernel boot itself only
        // needs a small fraction of a GiB (see DramMemoryMap/KernelInit), so even
        // the smallest tier here still leaves the emulator usable - just with
        // less RAM than declared available to the title, which only matters for
        // titles that genuinely need more than that.
        private static readonly ulong[] DramFallbackSizes =
        {
            // 3 GiB was removed as a step here on purpose: on a 3 GiB device,
            // successfully reserving 3 GiB for DRAM alone leaves almost no
            // headroom for everything reserved afterwards in the same load
            // (native page table, JIT caches, private memory blocks, GPU
            // buffers) - even though the DRAM reservation itself succeeds,
            // those later reservations were observed to fail outright with
            // nothing left to fall back to. Starting the fallback at 2 GiB
            // trades some headroom in the title's own RAM for headroom in
            // the rest of the loading pipeline.
            2UL * 1024 * 1024 * 1024,
            (3UL * 1024 * 1024 * 1024) / 2,
            1UL * 1024 * 1024 * 1024,
        };

        /// <summary>
        /// Reserves guest DRAM, retrying with a short backoff first, and only
        /// falling back to a smaller size than <paramref name="requestedSize"/>
        /// if the OS still refuses to grant it afterwards. This exists because on
        /// memory constrained devices (mainly iOS) a single large reservation can
        /// otherwise turn into a hard crash before emulation even starts, even
        /// for titles that would end up using much less memory than that.
        /// </summary>
        private static MemoryBlock CreateGuestMemory(ulong requestedSize, MemoryAllocationFlags flags)
        {
            for (int attempt = 0; attempt < DramReserveRetryDelaysMs.Length; attempt++)
            {
                try
                {
                    return new MemoryBlock(requestedSize, flags);
                }
                catch (SystemException)
                {
                    Thread.Sleep(DramReserveRetryDelaysMs[attempt]);
                }
            }

            foreach (ulong fallbackSize in DramFallbackSizes)
            {
                if (fallbackSize >= requestedSize)
                {
                    continue;
                }

                try
                {
                    MemoryBlock block = new(fallbackSize, flags);

                    Logger.Warning?.Print(LogClass.Emulation,
                        $"Could not reserve {requestedSize} bytes of guest memory, continuing with {fallbackSize} bytes instead. " +
                        "Titles that need more RAM than this may fail to run.");

                    return block;
                }
                catch (SystemException)
                {
                    // Try the next, smaller size.
                }
            }

            // Nothing worked, not even the smallest fallback - let the original
            // error surface, there genuinely is not enough memory/address space
            // available right now.
            return new MemoryBlock(requestedSize, flags);
        }

        public Switch(HleConfiguration configuration)
        {
            ArgumentNullException.ThrowIfNull(configuration.GpuRenderer);
            ArgumentNullException.ThrowIfNull(configuration.AudioDeviceDriver);
            ArgumentNullException.ThrowIfNull(configuration.UserChannelPersistence);

            Configuration = configuration;
            FileSystem = Configuration.VirtualFileSystem;
            UIHandler = Configuration.HostUIHandler;

            MemoryAllocationFlags memoryAllocationFlags = configuration.MemoryManagerMode == MemoryManagerMode.SoftwarePageTable
                ? MemoryAllocationFlags.Reserve
                : MemoryAllocationFlags.Reserve;

#pragma warning disable IDE0055 // Disable formatting
            DirtyHacks        = new DirtyHacks(Configuration.Hacks);
            AudioDeviceDriver = new CompatLayerHardwareDeviceDriver(Configuration.AudioDeviceDriver);
            Memory            = CreateGuestMemory(Configuration.MemoryConfiguration.DramSize, memoryAllocationFlags);
            Gpu               = new GpuContext(Configuration.GpuRenderer, DirtyHacks);
            Debugger          = Configuration.EnableGdbStub ? new Debugger.Debugger(this, Configuration.GdbStubPort) : null;
            System            = new HOS.Horizon(this);
            Statistics        = new PerformanceStatistics(this);
            Hid               = new Hid(this, System.HidStorage);
            Processes         = new ProcessLoader(this);
            TamperMachine     = new TamperMachine();

            System.InitializeServices();
            System.State.SetLanguage(Configuration.SystemLanguage);
            System.State.SetRegion(Configuration.Region);

            VSyncMode                               = Configuration.VSyncMode;
            CustomVSyncInterval                     = Configuration.CustomVSyncInterval;
            TickScalar                              = TurboMode ? Configuration.TickScalar : ITickSource.RealityTickScalar;
            System.State.DockedMode                 = Configuration.EnableDockedMode;
            System.PerformanceState.PerformanceMode = System.State.DockedMode ? PerformanceMode.Boost : PerformanceMode.Default;
            System.EnablePtc                        = Configuration.EnablePtc;
            System.FsIntegrityCheckLevel            = Configuration.FsIntegrityCheckLevel;
            System.GlobalAccessLogMode              = Configuration.FsGlobalAccessLogMode;
            
            UpdateVSyncInterval();
#pragma warning restore IDE0055

            Shared = this;
        }

        public void ProcessFrame()
        {
            Gpu.ProcessShaderCacheQueue();
            Gpu.Renderer.PreFrame();
            Gpu.GPFifo.DispatchCalls();
        }

        public int IncrementCustomVSyncInterval()
        {
            CustomVSyncInterval += 1;
            UpdateVSyncInterval();

            return CustomVSyncInterval;
        }

        public int DecrementCustomVSyncInterval()
        {
            CustomVSyncInterval -= 1;
            UpdateVSyncInterval();

            return CustomVSyncInterval;
        }

        public void UpdateVSyncInterval()
        {
            switch (VSyncMode)
            {
                case VSyncMode.Custom:
                    TargetVSyncInterval = CustomVSyncInterval;
                    break;
                case VSyncMode.Switch:
                    TargetVSyncInterval = 60;
                    break;
                case VSyncMode.Unbounded:
                    TargetVSyncInterval = 1;
                    break;
            }
        }

        public void ToggleTurbo()
        {
            TurboMode = !TurboMode;
            TickScalar = TurboMode ? Configuration.TickScalar : ITickSource.RealityTickScalar;
        }

        public bool LoadCart(string exeFsDir, string romFsFile = null) => Processes.LoadUnpackedNca(exeFsDir, romFsFile);
        public bool LoadXci(string xciFile, ulong applicationId = 0) => Processes.LoadXci(xciFile, applicationId);
        public bool LoadNca(string ncaFile, BlitStruct<ApplicationControlProperty>? customNacpData = null) => Processes.LoadNca(ncaFile, customNacpData);
        public bool LoadNsp(string nspFile, ulong applicationId = 0) => Processes.LoadNsp(nspFile, applicationId);
        public bool LoadProgram(string fileName) => Processes.LoadNxo(fileName);

        public void SetVolume(float volume) => AudioDeviceDriver.Volume = Math.Clamp(volume, 0f, 1f);
        public float GetVolume() => AudioDeviceDriver.Volume;
        public bool IsAudioMuted() => AudioDeviceDriver.Volume == 0;

        public void EnableCheats() => ModLoader.EnableCheats(Processes.ActiveApplication.ProgramId, TamperMachine);

        public bool WaitFifo() => Gpu.GPFifo.WaitForCommands();
        public bool ConsumeFrameAvailable() => Gpu.Window.ConsumeFrameAvailable();
        public void PresentFrame(Action swapBuffersCallback) => Gpu.Window.Present(swapBuffersCallback);
        public void DisposeGpu() => Gpu.Dispose();

        public void Dispose()
        {
            GC.SuppressFinalize(this);
            Dispose(true);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (disposing)
            {
                System.Dispose();
                AudioDeviceDriver.Dispose();
                FileSystem.Dispose();
                Memory.Dispose();
                Debugger?.Dispose();

                TitleIDs.CurrentApplication.Value = null;
                Shared = null;
            }
        }
    }
}
