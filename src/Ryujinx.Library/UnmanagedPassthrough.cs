using CommandLine;
using LibHac.Tools.FsSystem;
using Ryujinx.Audio.Backends.SDL3;
using Ryujinx.Audio.Backends.Apple;
using Ryujinx.Common.Configuration;
using Ryujinx.Common.Configuration.Hid;
using Ryujinx.Common.Configuration.Hid.Controller;
using Ryujinx.Common.Configuration.Hid.Controller.Motion;
using Ryujinx.Common.Configuration.Hid.Keyboard;
using Ryujinx.Common.GraphicsDriver;
using Ryujinx.Common.Logging;
using Ryujinx.Common.Logging.Targets;
using Ryujinx.Common.SystemInterop;
using Ryujinx.Common.Utilities;
using Ryujinx.Cpu;
using Ryujinx.Graphics.GAL;
using Ryujinx.Graphics.GAL.Multithreading;
using Ryujinx.Graphics.Gpu;
using Ryujinx.Graphics.Gpu.Shader;
using Ryujinx.Graphics.OpenGL;
using Ryujinx.Graphics.Vulkan;
using Ryujinx.Graphics.Vulkan.MoltenVK;
using Ryujinx.HLE;
using Ryujinx.HLE.FileSystem;
using Ryujinx.HLE.HOS;
using Ryujinx.HLE.HOS.Services.Account.Acc;
using Ryujinx.Input;
using Ryujinx.Input.HLE;
using Ryujinx.Input.SDL3;
using SDL;
using static SDL.SDL3;
using SDL3Type = SDL.SDL3;
using Ryujinx.SDL3.Common;
using Silk.NET.Vulkan;
using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.CompilerServices;
using System.Text.Json;
using System.Threading;
using ConfigGamepadInputId = Ryujinx.Common.Configuration.Hid.Controller.GamepadInputId;
using ConfigStickInputId = Ryujinx.Common.Configuration.Hid.Controller.StickInputId;
using Key = Ryujinx.Common.Configuration.Hid.Key;
using Ryujinx.HLE.HOS.SystemState;
using LibHac.Common.Keys;
using LibHac.Common;
using LibHac.Ns;
using LibHac.Tools.Fs;
using LibHac.Tools.FsSystem.NcaUtils;
using LibHac.Fs.Fsa;
using LibHac.FsSystem;
using LibHac.Fs;
using Path = System.IO.Path;
using Ryujinx.Common.Configuration.Multiplayer;
using Ryujinx.HLE.Loaders.Npdm;
using System.Globalization;
using System.Text;
using LibHac.Ncm;
using Microsoft.Win32.SafeHandles;
using System.Text.RegularExpressions;
using System.Runtime;
using System.Linq;
using System.Threading.Tasks;
using Ryujinx.Common.Callbacks;
using Ryujinx.Input.Native;
using Ryujinx.Cpu.LightningJit;

namespace Ryujinx.Library 
{

    class UnmanagedPassthrough
    {
        [UnmanagedCallersOnly(EntryPoint = "RegisterCallback")]
        public static void RegisterCallback(nint namePtr, nint callbackPtr, nint userData)
        {
            CallbackRegistry.RegisterCallback(namePtr, callbackPtr, userData);
        }
        
        [UnmanagedCallersOnly(EntryPoint = "UnregisterCallback")]
        public static void UnregisterCallback(nint namePtr)
        {
            CallbackRegistry.UnregisterCallback(namePtr);
        }

        [UnmanagedCallersOnly(EntryPoint = "InvokeCallback")]
        public static byte InvokeCallback(nint namePtr, nint dataPtr, int dataLen)
        {
            return CallbackRegistry.InvokeCallback(namePtr, dataPtr, dataLen);
        }

        [UnmanagedCallersOnly(EntryPoint = "init_dualmapping")]
        public static bool InitializeDualMapping() 
        {
            return DualMappedMemory.InitMemoryCache();
        }

        [UnmanagedCallersOnly(EntryPoint = "execute_function_pointer")]
        public static unsafe ulong ExecuteFunctionPointer(nint functionPtr)
        {
            delegate* unmanaged<ulong> function = (delegate* unmanaged<ulong>)functionPtr;

            return function();
        }

        [UnmanagedCallersOnly(EntryPoint = "execute_guest_function_pointer")]
        public static unsafe ulong ExecuteGuestFunctionPointer(nint functionPtr, nint nativeContextPtr)
        {
            delegate* unmanaged<nint, ulong> function = (delegate* unmanaged<nint, ulong>)functionPtr;

            return function(nativeContextPtr);
        }

        [UnmanagedCallersOnly(EntryPoint = "set_gamepad_button_state")] 
        public static void SetButtonState(IntPtr idPtr, int buttonId, byte pressed)
        {
            NativeGamepadDriver.SetButtonState(idPtr, buttonId, pressed);
        }

        [UnmanagedCallersOnly(EntryPoint = "set_gamepad_stick_axis")] 
        public static void SetStickAxis(IntPtr idPtr, int stickId, float x, float y)
        {
            NativeGamepadDriver.SetStickAxis(idPtr, stickId, x, y);
        }

        [UnmanagedCallersOnly(EntryPoint = "set_gamepad_motion_axis")] 
        static void SetMotionData(IntPtr idPtr, int motionType, float x, float y, float z)
        {
            NativeGamepadDriver.SetMotionData(idPtr, motionType, x, y, z);
        }
    }
    
}
