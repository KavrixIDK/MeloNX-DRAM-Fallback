using Ryujinx.Common.Memory;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.Common;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.DebugMouse;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.DebugPad;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.Keyboard;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.Mouse;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.Npad;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.TouchScreen;
using System;
using System.Runtime.InteropServices;

namespace Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory
{
    /// <summary>
    /// Represent the shared memory shared between applications for input.
    /// </summary>
    [StructLayout(LayoutKind.Explicit, Size = 0x40000)]
    struct SharedMemory
    {
        /// <summary>
        /// Debug controller.
        /// </summary>
        [FieldOffset(0)]
        public RingLifo<DebugPadState> DebugPad;

        /// <summary>
        /// Touchscreen.
        /// </summary>
        [FieldOffset(0x400)]
        public RingLifo<TouchScreenState> TouchScreen;

        /// <summary>
        /// Mouse.
        /// </summary>
        [FieldOffset(0x3400)]
        public RingLifo<MouseState> Mouse;

        /// <summary>
        /// Keyboard.
        /// </summary>
        [FieldOffset(0x3800)]
        public RingLifo<KeyboardState> Keyboard;

        /// <summary>
        /// Nintendo Pads.
        /// </summary>
        [FieldOffset(0x9A00)]
        public Array10<NpadState> Npads;

        /// <summary>
        /// Debug mouse.
        /// </summary>
        [FieldOffset(0x3DC00)]
        public RingLifo<DebugMouseState> DebugMouse;
        
        /// <summary>
        /// Pad Condition.
        /// </summary>
        [FieldOffset(0x3e200)]
        public NpadCondition Condition;

        public static SharedMemory Create()
        {
            SharedMemory result = default;
            Initialize(ref result);
            return result;
        }

        public static void Initialize(ref SharedMemory mem)
        {
            mem.DebugPad    = RingLifo<DebugPadState>.Create();
            mem.TouchScreen = RingLifo<TouchScreenState>.Create();
            mem.Mouse       = RingLifo<MouseState>.Create();
            mem.Keyboard    = RingLifo<KeyboardState>.Create();
            mem.Condition   = NpadCondition.Create();

            Span<NpadState> npadsSpan = mem.Npads.AsSpan();
            for (int i = 0; i < npadsSpan.Length; i++)
            {
                npadsSpan[i] = NpadState.Create();
            }
        }
    }
}
