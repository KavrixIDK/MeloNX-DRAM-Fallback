using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Threading;
using Ryujinx.Common.Logging;
using static Ryujinx.Memory.MemoryManagerUnixHelper;
using System.Runtime.Versioning;

namespace Ryujinx.Memory
{
    /// <summary>
    /// Class for JIT memory allocation on iOS.
    /// Intended to allocate memory with both r/x and r/w permissions,
    /// as a workaround for stricter W^X (Write XOR Execute) enforcement introduced in iOS 26.
    /// 
    /// Specifically targets iOS 26, where the traditional method of reprotecting
    /// memory from writable to executable (RX) no longer works for JIT code.
    /// </summary>
    ///     
    [SupportedOSPlatform("macos")]
    [SupportedOSPlatform("ios")]
    public class DualMappedJitAllocator : IDisposable
    {

        public nint RwPtr { get; private set; }
        public nint RxPtr { get; private set; }
        public ulong Size { get; private set; }

        [DllImport("BreakpointJIT.framework/BreakpointJIT", EntryPoint = "BreakGetJITMapping")]
        public static extern unsafe byte* BreakGetJITMappingPub(byte* addr, nuint bytes);

        [DllImport("BreakpointJIT.framework/BreakpointJIT", EntryPoint = "BreakMarkJITMapping")]
        public static extern unsafe byte* BreakMarkJITMapping(nuint bytes);

        [DllImport("BreakpointJIT.framework/BreakpointJIT", EntryPoint = "BreakJITDetach")]
        public static extern unsafe void BreakJITDetach();

        static public bool hasTXM => Environment.GetEnvironmentVariable("HAS_TXM") == "1"; 

        static public bool dualMappingEnabled => Environment.GetEnvironmentVariable("DUAL_MAPPED_JIT") == "1"; 

        static private bool usingNewMapping = false;

        private static readonly int[] AllocRetryDelaysMs = { 25, 75, 200, 500 };

        // Below this size the dual-mapped JIT cache would be too small to be
        // useful for basically any title, so there is no point shrinking
        // further - if even this can not be allocated, we let the original
        // failure surface instead of pretending we can still run.
        private const ulong MinJitCacheSize = 16UL * 1024 * 1024;

        public DualMappedJitAllocator(ulong size)
        {
            var stackTrace = new StackTrace(1, false);
            var callingMethod = stackTrace.GetFrame(0)?.GetMethod();

            Logger.Info?.Print(LogClass.Cpu,
                $"Allocating dual-mapped JIT memory of size {size} bytes, called by {callingMethod?.DeclaringType?.FullName}.{callingMethod?.Name} with {hasTXM}, {dualMappingEnabled}");
            Size = size;
            AllocateDualMapping();
        }

        nint? BreakGetJITMapping(nuint bytes)
        {
            unsafe
            {
                byte* ptr = usingNewMapping ? (byte*)0 : (byte*)BreakMarkJITMapping(bytes);
                Logger.Info?.Print(LogClass.Cpu, $"testing for BreakGetJITMapping, got {(ulong)ptr}");
                if (ptr == null || ptr == (byte*)0 || ptr == (byte*)-1 || ptr == (byte*)14757395257293275360 || ptr == (byte*)1761607904)
                {
                    ptr = BreakGetJITMappingPub(null, bytes);
                    Logger.Info?.Print(LogClass.Cpu, $"testing for BreakGetJITMapping Again, got {(ulong)ptr}");
                    if (ptr == null || ptr == (byte*)0 || ptr == (byte*)-1)
                    {
                        Logger.Info?.Print(LogClass.Cpu, "Failed to get JIT mapping from BreakGetJITMapping.");
                        return null;
                    } else { usingNewMapping = true; }
                }

                return (nint)ptr;
            }
        }

        /// <summary>
        /// Allocates the dual-mapped (RX + RW) JIT memory region, starting at
        /// <see cref="Size"/> bytes. On memory constrained devices (mainly
        /// iOS) the kernel can refuse this reservation even though the
        /// device would grant it a moment later, or even though a smaller
        /// cache would fit fine - this mirrors the retry-then-shrink
        /// approach used for guest DRAM (Switch.cs) and the native page
        /// table (NativePageTable.cs): first retry the requested size with a
        /// short backoff, and only if that keeps failing, fall back to a
        /// smaller cache instead of crashing. <see cref="Size"/> is updated
        /// to the size that was actually obtained, so callers sizing other
        /// structures from it (see DualMappedNoWxCache) stay consistent with
        /// what was really allocated.
        /// </summary>
        private void AllocateDualMapping()
        {
            ulong size = Size;

            while (true)
            {
                for (int attempt = 0; ; attempt++)
                {
                    if (TryAllocateDualMapping(size))
                    {
                        if (size != Size)
                        {
                            Logger.Warning?.Print(LogClass.Cpu,
                                $"Could not allocate {Size} bytes of dual-mapped JIT memory, continuing with {size} bytes instead. " +
                                "The JIT code cache will be smaller than configured and may fill up sooner for demanding titles.");
                        }

                        Size = size;
                        return;
                    }

                    if (attempt < AllocRetryDelaysMs.Length)
                    {
                        Thread.Sleep(AllocRetryDelaysMs[attempt]);
                        continue;
                    }

                    if (size <= MinJitCacheSize)
                    {
                        // Nothing worked, not even the smallest fallback - let
                        // the original failure surface.
                        throw new Exception("Failed to mmap memory");
                    }

                    break;
                }

                size /= 2;
            }
        }

        /// <summary>
        /// Attempts a single dual-mapping of <paramref name="size"/> bytes.
        /// Returns false (instead of throwing) on any failure, cleaning up
        /// any partial mapping it made along the way, so the caller can
        /// retry or fall back to a smaller size without leaking address
        /// space on every attempt.
        /// </summary>
        private bool TryAllocateDualMapping(ulong size)
        {
            nint? _mmapPtr = null;

            if (hasTXM)
            {
                _mmapPtr = BreakGetJITMapping((nuint)size);
            }
            else
            {
                _mmapPtr = Mmap(0, size, MmapProts.PROT_READ | MmapProts.PROT_EXEC, MmapFlags.MAP_ANONYMOUS | MmapFlags.MAP_PRIVATE, -1, 0);
            }

            if (_mmapPtr == null || _mmapPtr == MAP_FAILED)
            {
                return false;
            }

            var bufRX = (ulong)_mmapPtr;
            ulong bufRW = 0;
            uint curProt = 0, maxProt = 0;

            int remapResult = vm_remap(mach_task_self(), ref bufRW, size, 0, VM_FLAGS_ANYWHERE,
                                      mach_task_self(), bufRX, 0, ref curProt, ref maxProt, VM_INHERIT_NONE);

            if (remapResult != KERN_SUCCESS)
            {
                // Give back the RX mapping we already made before trying
                // again, otherwise every retry/fallback attempt would leak
                // address space.
                munmap((nint)bufRX, size);

                return false;
            }

            int protectRWResult = vm_protect(mach_task_self(), bufRW, size, 0, VM_PROT_READ | VM_PROT_WRITE);

            if (protectRWResult != KERN_SUCCESS)
            {
                munmap((nint)bufRW, size);
                munmap((nint)bufRX, size);

                return false;
            }

            RwPtr = (nint)bufRW;
            RxPtr = (nint)_mmapPtr;

            return true;
        }

        public void Dispose()
        {
            if (RxPtr != IntPtr.Zero)
            {
                munmap(RxPtr, Size);
                RxPtr = IntPtr.Zero;

                munmap(RwPtr, Size);
                RwPtr = IntPtr.Zero;
            }
        }

        private const int MAP_ANON = 0x1000;
        private const int MAP_PRIVATE = 0x2;

        private const int VM_FLAGS_ANYWHERE = 1 << 0;
        private const int VM_INHERIT_NONE = 2;
        private const int KERN_SUCCESS = 0;
        private const int VM_PROT_READ = 1;
        private const int VM_PROT_WRITE = 2;

        [DllImport("libc")]
        private static extern ulong mach_task_self();

        [DllImport("libc")]
        private static extern int vm_remap(
            ulong target_task,
            ref ulong target_address,
            ulong size,
            ulong mask,
            int anywhere,
            ulong src_task,
            ulong src_address,
            int copy,
            ref uint cur_protection,
            ref uint max_protection,
            int inheritance
        );

        [DllImport("libc")]
        private static extern int vm_protect(
            ulong task,
            ulong address,
            ulong size,
            int set_maximum,
            int new_protection
        );
    }
}
