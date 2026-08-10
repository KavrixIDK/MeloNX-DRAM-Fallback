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
using Ryujinx.Memory;
using Ryujinx.HLE.Utilities;

namespace Ryujinx.Library 
{
    class Library
    {
        private static VirtualFileSystem _virtualFileSystem;
        private static ContentManager _contentManager;
        private static AccountManager _accountManager;
        private static LibHacHorizonManager _libHacHorizonManager;
        private static UserChannelPersistence _userChannelPersistence;
        private static InputManager _inputManager;
        private static Switch _emulationContext;
        private static WindowBase _window;
        private static WindowsMultimediaTimerResolution _windowsMultimediaTimerResolution;
        private static List<InputConfig> _inputConfiguration;
        private static bool _enableKeyboard;
        private static bool _enableMouse;
        private static nint nativeMetalLayer = nint.Zero;
        private static readonly Lock metalLayerLock = new();
        private static KeyboardConfigNative? _keyboardConfig = null;

        [UnmanagedCallersOnly(EntryPoint = "main_ryujinx_sdl")]
        public static unsafe int MainExternal(OptionsNative* nativeOptions)
        {
            try
            {
                Options managed = OptionsNativeHelper.FromNative(nativeOptions);
                OptionsNativeHelper.Free(nativeOptions);
                Load(managed);
            }
            catch (Exception e)
            {
                Console.WriteLine(e.ToString());
                return -1;
            }

            return 0;
        }


        [UnmanagedCallersOnly(EntryPoint = "initialize")]
        public static unsafe void Initialize()
        {
            AppDataManager.Initialize(Environment.GetFolderPath(Environment.SpecialFolder.MyDocuments));

            Silk.NET.Core.Loader.SearchPathContainer.Platform = Silk.NET.Core.Loader.UnderlyingPlatform.MacOS;

            if (_virtualFileSystem == null)
            {
                _virtualFileSystem = VirtualFileSystem.CreateInstance();
            }

            if (_libHacHorizonManager == null)
            {
                _libHacHorizonManager = new LibHacHorizonManager();
                _libHacHorizonManager.InitializeFsServer(_virtualFileSystem);
                _libHacHorizonManager.InitializeArpServer();
                _libHacHorizonManager.InitializeBcatServer();
                _libHacHorizonManager.InitializeSystemClients();
            }

            if (_contentManager == null)
            {
                _contentManager = new ContentManager(_virtualFileSystem);
            }
            
            if (_accountManager == null)
            {
                _accountManager = new AccountManager(_libHacHorizonManager.RyujinxClient);
            }

            // :3
            NativeLibrary.SetDllImportResolver(typeof(SDL3Type).Assembly, (_, assembly, path) => NativeLibrary.Load("@rpath/SDL3.framework/SDL3", assembly, path));

            _inputManager = new InputManager(new SDL3KeyboardDriver(), new NativeGamepadDriver());
            _inputConfiguration = new List<InputConfig>();
            _enableKeyboard = true;
            _enableMouse = false;
            
            AutoResetEvent invoked = new(false);

            SDL3Driver.MainThreadDispatcher = action =>
            {
                invoked.Reset();

                WindowBase.QueueMainThreadAction(() =>
                {
                    action();

                    invoked.Set();
                });

                invoked.WaitOne();
            };
        }

        [UnmanagedCallersOnly(EntryPoint = "set_native_window")]
        public static unsafe void SetNativeWindow(nint layer) {
            lock (metalLayerLock) 
            {
                nativeMetalLayer = layer;
            }
        }

        [UnmanagedCallersOnly(EntryPoint = "stop_emulation")]
        public static void StopEmulation()
        {
            if (_window != null)
            {
                _window.Exit();
            }
        }

        public static nint GetNativeMetalLayer()
        {
            lock (metalLayerLock)
            {
                return nativeMetalLayer;
            }
        }

        [UnmanagedCallersOnly(EntryPoint = "toggle_pause_emulation")]
        public static void TogglePauseEmulation(bool shouldPause)
        {
            if (_emulationContext != null && _emulationContext.System != null)
            {
                _emulationContext.System.TogglePauseEmulation(shouldPause);
            }
        }

        [UnmanagedCallersOnly(EntryPoint = "load_keyset")]
        public static void ReloadKeySet() 
        {
            _virtualFileSystem.ReloadKeySet();
        }

        [UnmanagedCallersOnly(EntryPoint = "installed_firmware_version")]
        public static nint GetInstalledFirmwareVersionNative()
        {
            var result = GetInstalledFirmwareVersion();
            return Marshal.StringToHGlobalAnsi(result);
        }

        [UnmanagedCallersOnly(EntryPoint = "free_firmware_version")]
        public static void FreeFirmwareVersion(nint versionPtr)
        {
            if (versionPtr != nint.Zero)
            {
                Marshal.FreeHGlobal(versionPtr);
            }
        }

        [UnmanagedCallersOnly(EntryPoint = "install_firmware")]
        public static unsafe nint? InstallFirmwareNative(nint pathPtr)
        {
            var firmwarePath = Marshal.PtrToStringAnsi(pathPtr);

            try 
            {
                _contentManager.InstallFirmware(firmwarePath);
            } 
            catch (Exception exception)
            {
                return Marshal.StringToHGlobalAnsi(exception.ToString());
            }

            return null;
        }

        [UnmanagedCallersOnly(EntryPoint = "create_account")]
        public static void CreateAccount(IntPtr namePtr, IntPtr imagePtr, int imageLength)
        {
            string name = Marshal.PtrToStringAnsi(namePtr);
            byte[] image = null;

            if (imagePtr != IntPtr.Zero && imageLength > 0)
            {
                image = new byte[imageLength];

                Marshal.Copy(imagePtr, image, 0, imageLength);
            }

            _accountManager.AddUser(name, image);
        }

        [UnmanagedCallersOnly(EntryPoint = "delete_account")]
        public static void DeleteAccount(IntPtr userId)
        {
            string name = Marshal.PtrToStringAnsi(userId);

            HLE.HOS.Services.Account.Acc.UserId userIdObj = new HLE.HOS.Services.Account.Acc.UserId(name);
            _accountManager.DeleteUser(userIdObj);
        }

        [UnmanagedCallersOnly(EntryPoint = "open_user")]
        public static void OpenUser(IntPtr userId)
        {
            string name = Marshal.PtrToStringAnsi(userId);

            HLE.HOS.Services.Account.Acc.UserId userIdObj = new HLE.HOS.Services.Account.Acc.UserId(name);
            _accountManager.OpenUser(userIdObj);
        }

        [UnmanagedCallersOnly(EntryPoint = "close_user")]
        public static void CloseUser(IntPtr userId)
        {
            string name = Marshal.PtrToStringAnsi(userId);

            HLE.HOS.Services.Account.Acc.UserId userIdObj = new HLE.HOS.Services.Account.Acc.UserId(name);
            _accountManager.OpenUser(userIdObj);
        }

        [UnmanagedCallersOnly(EntryPoint = "free_avatars")]
        public static unsafe void FreeAvatars(AvatarArray avatarArray)
        {
            if (avatarArray.Avatars != null)
            {
                for (int i = 0; i < avatarArray.Count; i++)
                {
                    if (avatarArray.Avatars[i].ImageData != null)
                        Marshal.FreeHGlobal((IntPtr)avatarArray.Avatars[i].ImageData);
                    
                    if (avatarArray.Avatars[i].FileName != null)
                        Marshal.FreeHGlobal((IntPtr)avatarArray.Avatars[i].FileName);
                }

                Marshal.FreeHGlobal((IntPtr)avatarArray.Avatars);
            }
        }


        [UnmanagedCallersOnly(EntryPoint = "get_avatars")]
        public static unsafe AvatarArray GetAvatars()
        {
            var avatars = AvatarLoader.LoadAvatars(_contentManager, _virtualFileSystem);
            int count = avatars.Count;

            AvatarInfo* avatarInfos = (AvatarInfo*)Marshal.AllocHGlobal(sizeof(AvatarInfo) * count);

            int index = 0;
            foreach (var kvp in avatars)
            {
                string fileName = kvp.Key;
                byte[] imageData = kvp.Value;

                byte* imagePtr = (byte*)Marshal.AllocHGlobal(imageData.Length);
                Marshal.Copy(imageData, 0, (IntPtr)imagePtr, imageData.Length);

                byte[] utf8FileName = Encoding.UTF8.GetBytes(fileName);
                sbyte* fileNamePtr = (sbyte*)Marshal.AllocHGlobal(utf8FileName.Length + 1);
                for (int i = 0; i < utf8FileName.Length; i++)
                {
                    fileNamePtr[i] = (sbyte)utf8FileName[i];
                }
                fileNamePtr[utf8FileName.Length] = 0; 

                avatarInfos[index] = new AvatarInfo
                {
                    ImageData = imagePtr,
                    ImageSize = imageData.Length,
                    FileName = fileNamePtr
                };

                index++;
            }

            return new AvatarArray
            {
                Count = count,
                Avatars = avatarInfos
            };
        }

        [UnmanagedCallersOnly(EntryPoint = "refresh_account_manager")]
        public static void RefreshAccountManager()
        {
            _accountManager.Refresh();
        }

        [UnmanagedCallersOnly(EntryPoint = "get_dlc_nca_list")]
        public static unsafe DlcNcaList GetDlcNcaList(nint titleIdPtr, nint pathPtr) 
        {
            var titleId = Marshal.PtrToStringAnsi(titleIdPtr);
            var containerPath = Marshal.PtrToStringAnsi(pathPtr);

            if (string.IsNullOrWhiteSpace(titleId) ||
                string.IsNullOrWhiteSpace(containerPath) ||
                !File.Exists(containerPath) ||
                !ulong.TryParse(titleId, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out ulong titleIdBase))
            {
                return new DlcNcaList { success = false };
            }

            titleIdBase &= ~0x1FFFUL;

            try
            {
                _virtualFileSystem ??= VirtualFileSystem.CreateInstance();

                using IFileSystem pfs = PartitionFileSystemUtils.OpenApplicationFileSystem(containerPath, _virtualFileSystem);
                _virtualFileSystem.ImportTickets(pfs);

                List<DlcNcaListItem> listItems = new();

                foreach (DirectoryEntryEx fileEntry in pfs.EnumerateEntries("/", "*.nca"))
                {
                    using var ncaFile = new UniqueRef<IFile>();

                    pfs.OpenFile(ref ncaFile.Ref, fileEntry.FullPath.ToU8Span(), OpenMode.Read).ThrowIfFailure();

                    Nca nca = TryCreateNca(ncaFile.Get.AsStorage(), containerPath);

                    if (nca == null ||
                        nca.Header.ContentType != NcaContentType.PublicData ||
                        (nca.Header.TitleId & ~0x1FFFUL) != titleIdBase)
                    {
                        continue;
                    }

                    DlcNcaListItem item = new();
                    GameInfoLoader.CopyStringToFixedArray(fileEntry.FullPath, item.Path, 256);
                    item.TitleId = nca.Header.TitleId;
                    listItems.Add(item);
                }

                if (listItems.Count == 0)
                {
                    Console.WriteLine("The specified file does not contain DLC for the selected title!");
                    return new DlcNcaList { success = false };
                }

                return CreateDlcNcaList(listItems);
            }
            catch (MissingKeyException exception)
            {
                Logger.Warning?.Print(LogClass.Application, $"Your key set is missing a key with the name: {exception.Name}");
            }
            catch (InvalidDataException)
            {
                Logger.Warning?.Print(LogClass.Application, $"The header key is incorrect or missing and therefore the NCA header content type check has failed. Errored File: {containerPath}");
            }
            catch (Exception exception)
            {
                Logger.Warning?.Print(LogClass.Application, exception.Message);
            }
            
            return new DlcNcaList { success = false };
        }

        [UnmanagedCallersOnly(EntryPoint = "free_dlc_nca_list")]
        public static unsafe void FreeDlcNcaList(DlcNcaList list)
        {
            if (list.items != null)
            {
                NativeMemory.Free(list.items);
            }
        }

        private static unsafe DlcNcaList CreateDlcNcaList(List<DlcNcaListItem> listItems)
        {
            DlcNcaListItem* items = (DlcNcaListItem*)NativeMemory.AllocZeroed(
                (nuint)listItems.Count,
                (nuint)sizeof(DlcNcaListItem));

            for (int index = 0; index < listItems.Count; index++)
            {
                items[index] = listItems[index];
            }

            return new DlcNcaList
            {
                success = true,
                size = (uint)listItems.Count,
                items = items,
            };
        }

        private static Nca TryCreateNca(IStorage ncaStorage, string containerPath)
        {
            try
            {
                return new Nca(_virtualFileSystem.KeySet, ncaStorage);
            }
            catch (Exception)
            {
                // ignored
            }

            return null;
        }

        public static string GetInstalledFirmwareVersion()
        {
            try
            {
                var version = _contentManager.GetCurrentFirmwareVersion();

                if (version != null)
                {
                    return version.VersionString;
                }

                return String.Empty;
            } catch
            {
                return String.Empty;
            }
        }

        [UnmanagedCallersOnly(EntryPoint = "set_keyboard_config")]
        public static void SetKeyboardConfig(KeyboardConfigNative config) 
        {
            _keyboardConfig = config;
        }
        
        [UnmanagedCallersOnly(EntryPoint = "attach_gamepad")]
        public static nint AttachGamepad(nint namePtr, nint idPtr, int playerIndex, ControllerType controllerType)
        {
            if (namePtr == nint.Zero)
                return nint.Zero;
            
            string name = Marshal.PtrToStringAnsi(namePtr);
            string inputId = idPtr.ToInt64().ToString("X");

            nint result = 0;
            if (idPtr != nint.Zero)
            {
                result = NativeGamepadDriver.AttachGamepad(name, idPtr);
                if (result == nint.Zero)
                    return nint.Zero;
            }

            if (playerIndex < 0 || playerIndex > 7)
            {
                Logger.Warning?.Print(LogClass.Application, $"AttachGamepad: invalid playerIndex {playerIndex} for \"{inputId}\"");
                return result;
            }

            var assignedIndex = (PlayerIndex)playerIndex;
            InputConfig config = HandlePlayerConfiguration(inputId, assignedIndex, controllerType);
            
            if (config != null)
            {
                _inputConfiguration ??= new List<InputConfig>();
                _inputConfiguration.RemoveAll(c => c.PlayerIndex == assignedIndex || c.Id == inputId);
                _inputConfiguration.Add(config);
                
                Logger.Info?.Print(LogClass.Application,
                    $"AttachGamepad: assigned \"{inputId}\" to {assignedIndex} as {controllerType}. " +
                    $"Total configs: {_inputConfiguration.Count}");

                EnsureKeyboardFallback();
                
                _window?.NpadManager.ReloadConfiguration(_inputConfiguration, _enableKeyboard, _enableMouse);
            }

            return result;
        }

        [UnmanagedCallersOnly(EntryPoint = "detach_gamepad")]
        public static void DetachGamepad(nint idPtr)
        {
            NativeGamepadDriver.DetachGamepad(idPtr);

            if (idPtr == nint.Zero)
                return;
            
            string inputId = idPtr.ToInt64().ToString("X");
            if (inputId == null)
                return;

            int removed = _inputConfiguration?.RemoveAll(c => c.Id == inputId) ?? 0;

            if (removed > 0)
            {
                Logger.Info?.Print(LogClass.Application,
                    $"DetachGamepad: removed \"{inputId}\". " +
                    $"Remaining configs: {_inputConfiguration?.Count ?? 0}");

                EnsureKeyboardFallback();

                _window?.NpadManager.ReloadConfiguration(
                    _inputConfiguration ?? new List<InputConfig>(),
                    _enableKeyboard,
                    _enableMouse);
            }
        }
        

        public static Common.Configuration.Hid.Keyboard.StandardKeyboardInputConfig KeyboardInputConfig() 
        {
            return new StandardKeyboardInputConfig
            {
                Version        = InputConfig.CurrentVersion,
                Backend        = InputBackendType.WindowKeyboard,
                Id             = "0",
                PlayerIndex    = PlayerIndex.Player1,
                ControllerType = ControllerType.JoyconPair,
                LeftJoycon = new LeftJoyconCommonConfig<Key>
                {
                    DpadUp      = ((Key?)_keyboardConfig?.LeftJoycon.DpadUp)      ?? Key.Up,
                    DpadDown    = ((Key?)_keyboardConfig?.LeftJoycon.DpadDown)    ?? Key.Down,
                    DpadLeft    = ((Key?)_keyboardConfig?.LeftJoycon.DpadLeft)    ?? Key.Left,
                    DpadRight   = ((Key?)_keyboardConfig?.LeftJoycon.DpadRight)   ?? Key.Right,
                    ButtonMinus = ((Key?)_keyboardConfig?.LeftJoycon.ButtonMinus) ?? Key.Minus,
                    ButtonL     = ((Key?)_keyboardConfig?.LeftJoycon.ButtonL)     ?? Key.E,
                    ButtonZl    = ((Key?)_keyboardConfig?.LeftJoycon.ButtonZl)    ?? Key.Q,
                    ButtonSl    = ((Key?)_keyboardConfig?.LeftJoycon.ButtonSl)    ?? Key.Unbound,
                    ButtonSr    = ((Key?)_keyboardConfig?.LeftJoycon.ButtonSr)    ?? Key.Unbound,
                },
                LeftJoyconStick = new JoyconConfigKeyboardStick<Key>
                {
                    StickUp     = ((Key?)_keyboardConfig?.LeftJoyconStick.StickUp)     ?? Key.W,
                    StickDown   = ((Key?)_keyboardConfig?.LeftJoyconStick.StickDown)   ?? Key.S,
                    StickLeft   = ((Key?)_keyboardConfig?.LeftJoyconStick.StickLeft)   ?? Key.A,
                    StickRight  = ((Key?)_keyboardConfig?.LeftJoyconStick.StickRight)  ?? Key.D,
                    StickButton = ((Key?)_keyboardConfig?.LeftJoyconStick.StickButton) ?? Key.F,
                },
                RightJoycon = new RightJoyconCommonConfig<Key>
                {
                    ButtonA     = ((Key?)_keyboardConfig?.RightJoycon.ButtonA) ?? Key.Z,
                    ButtonB     = ((Key?)_keyboardConfig?.RightJoycon.ButtonB) ?? Key.X,
                    ButtonX     = ((Key?)_keyboardConfig?.RightJoycon.ButtonX) ?? Key.C,
                    ButtonY     = ((Key?)_keyboardConfig?.RightJoycon.ButtonY) ?? Key.V,
                    ButtonPlus  = ((Key?)_keyboardConfig?.RightJoycon.ButtonPlus) ?? Key.Plus,
                    ButtonR     = ((Key?)_keyboardConfig?.RightJoycon.ButtonR) ?? Key.U,
                    ButtonZr    = ((Key?)_keyboardConfig?.RightJoycon.ButtonZr)   ?? Key.O,
                    ButtonSl    = ((Key?)_keyboardConfig?.RightJoycon.ButtonSl)   ?? Key.Unbound,
                    ButtonSr    = ((Key?)_keyboardConfig?.RightJoycon.ButtonSr)   ?? Key.Unbound,
                },
                RightJoyconStick = new JoyconConfigKeyboardStick<Key>
                {
                    StickUp     = ((Key?)_keyboardConfig?.RightJoyconStick.StickUp)     ?? Key.I,
                    StickDown   = ((Key?)_keyboardConfig?.RightJoyconStick.StickDown)   ?? Key.K,
                    StickLeft   = ((Key?)_keyboardConfig?.RightJoyconStick.StickLeft)   ?? Key.J,
                    StickRight  = ((Key?)_keyboardConfig?.RightJoyconStick.StickRight)  ?? Key.L,
                    StickButton = ((Key?)_keyboardConfig?.RightJoyconStick.StickButton) ?? Key.H,
                },
            };
        }

        private static void EnsureKeyboardFallback()
        {
            if (_inputConfiguration != null && _inputConfiguration.Count > 0)
                return;

            _inputConfiguration ??= new List<InputConfig>();

            var keyboardConfig = KeyboardInputConfig();

            _inputConfiguration.Add(keyboardConfig);
            Logger.Info?.Print(LogClass.Application, "No input configs, fallback keyboard for Player1.");
        }

        private static InputConfig HandlePlayerConfiguration(
            string inputId,
            PlayerIndex index,
            ControllerType controllerType)
        {
            if (inputId == null)
            {
                Logger.Info?.Print(LogClass.Application, $"{index} not configured");
                return null;
            }

            IGamepad gamepad = _inputManager.KeyboardDriver.GetGamepad(inputId);
            bool isKeyboard = true;

            if (gamepad == null)
            {
                gamepad = _inputManager.GamepadDriver.GetGamepad(inputId);
                isKeyboard = false;

                if (gamepad == null)
                {
                    Logger.Error?.Print(LogClass.Application, $"{index} gamepad not found (\"{inputId}\")");

                    inputId = "0";
                    gamepad = _inputManager.KeyboardDriver.GetGamepad(inputId);
                    isKeyboard = true;
                }
            }

            gamepad.Dispose();

            InputConfig config;

            if (isKeyboard)
            {
                config = KeyboardInputConfig();
            }
            else
            {
                Console.WriteLine($"Configuring {inputId} as {controllerType} ({index})");

                config = new StandardControllerInputConfig
                {
                    Version          = InputConfig.CurrentVersion,
                    Backend          = InputBackendType.GamepadSDL2,
                    Id               = null,
                    ControllerType   = controllerType,
                    DeadzoneLeft     = 0.1f,
                    DeadzoneRight    = 0.1f,
                    RangeLeft        = 1.0f,
                    RangeRight       = 1.0f,
                    TriggerThreshold = 0.5f,
                    LeftJoycon = new LeftJoyconCommonConfig<ConfigGamepadInputId>
                    {
                        DpadUp      = ConfigGamepadInputId.DpadUp,
                        DpadDown    = ConfigGamepadInputId.DpadDown,
                        DpadLeft    = ConfigGamepadInputId.DpadLeft,
                        DpadRight   = ConfigGamepadInputId.DpadRight,
                        ButtonMinus = ConfigGamepadInputId.Minus,
                        ButtonL     = ConfigGamepadInputId.LeftShoulder,
                        ButtonZl    = ConfigGamepadInputId.LeftTrigger,
                        ButtonSl    = ConfigGamepadInputId.Unbound,
                        ButtonSr    = ConfigGamepadInputId.Unbound,
                    },
                    LeftJoyconStick = new JoyconConfigControllerStick<ConfigGamepadInputId, ConfigStickInputId>
                    {
                        Joystick      = ConfigStickInputId.Left,
                        StickButton   = ConfigGamepadInputId.LeftStick,
                        InvertStickX  = false,
                        InvertStickY  = false,
                        Rotate90CW    = false,
                    },
                    RightJoycon = new RightJoyconCommonConfig<ConfigGamepadInputId>
                    {
                        ButtonA     = ConfigGamepadInputId.A,
                        ButtonB     = ConfigGamepadInputId.B,
                        ButtonX     = ConfigGamepadInputId.X,
                        ButtonY     = ConfigGamepadInputId.Y,
                        ButtonPlus  = ConfigGamepadInputId.Plus,
                        ButtonR     = ConfigGamepadInputId.RightShoulder,
                        ButtonZr    = ConfigGamepadInputId.RightTrigger,
                        ButtonSl    = ConfigGamepadInputId.Unbound,
                        ButtonSr    = ConfigGamepadInputId.Unbound,
                    },
                    RightJoyconStick = new JoyconConfigControllerStick<ConfigGamepadInputId, ConfigStickInputId>
                    {
                        Joystick      = ConfigStickInputId.Right,
                        StickButton   = ConfigGamepadInputId.RightStick,
                        InvertStickX  = false,
                        InvertStickY  = false,
                        Rotate90CW    = false,
                    },
                    Motion = new StandardMotionConfigController
                    {
                        MotionBackend = MotionInputBackendType.GamepadDriver,
                        EnableMotion  = true,
                        Sensitivity   = 100,
                        GyroDeadzone  = 1,
                    },
                    Rumble = new RumbleConfigController
                    {
                        StrongRumble  = 1f,
                        WeakRumble    = 1f,
                        EnableRumble  = true,
                    },
                };
            }

            if (config is StandardControllerInputConfig controllerConfig)
            {
                if (controllerConfig.RangeLeft <= 0.0f && controllerConfig.RangeRight <= 0.0f)
                {
                    controllerConfig.RangeLeft  = 1.0f;
                    controllerConfig.RangeRight = 1.0f;

                    Logger.Info?.Print(LogClass.Application, $"{config.PlayerIndex} stick range reset. Save the profile now to update your configuration");
                }
            }
            
            config.Id = inputId;
            config.PlayerIndex = index;

            string inputTypeName = isKeyboard ? "Keyboard" : "Gamepad";
            Logger.Info?.Print(LogClass.Application, $"{config.PlayerIndex} configured with {inputTypeName} \"{config.Id}\"");

            return config;
        }
        
        static void Load(Options option)
        {
            _libHacHorizonManager = new LibHacHorizonManager();
            _libHacHorizonManager.InitializeFsServer(_virtualFileSystem);
            _libHacHorizonManager.InitializeArpServer();
            _libHacHorizonManager.InitializeBcatServer();
            _libHacHorizonManager.InitializeSystemClients();

            _accountManager = new AccountManager(_libHacHorizonManager.RyujinxClient, option.UserProfile);
            _userChannelPersistence = new UserChannelPersistence();

            GraphicsConfig.EnableMacroJit = false;
            GraphicsConfig.EnableShaderCache = !option.DisableShaderCache;
            GraphicsConfig.EnableAsyncShaderCompilation = option.EnableAsyncShaderCompilation;
            GraphicsConfig.EnableTextureRecompression = option.EnableTextureRecompression;
            GraphicsConfig.ResScale = option.ResScale;
            GraphicsConfig.MaxAnisotropy = option.MaxAnisotropy;
            GraphicsConfig.ShadersDumpPath = option.GraphicsShadersDumpPath;
            GraphicsConfig.EnableMacroHLE = !option.DisableMacroHLE;
            GraphicsConfig.EnableColorSpacePassthrough = true;

            EnsureKeyboardFallback();

            Logger.SetEnable(LogLevel.Debug, option.LoggingEnableDebug);
            Logger.SetEnable(LogLevel.Stub, !option.LoggingDisableStub);
            Logger.SetEnable(LogLevel.Info, !option.LoggingDisableInfo);
            Logger.SetEnable(LogLevel.Warning, !option.LoggingDisableWarning);
            Logger.SetEnable(LogLevel.Error, option.LoggingEnableError);
            Logger.SetEnable(LogLevel.Trace, option.LoggingEnableTrace);
            Logger.SetEnable(LogLevel.Guest, !option.LoggingDisableGuest);
            Logger.SetEnable(LogLevel.AccessLog, option.LoggingEnableFsAccessLog);


            AppDomain.CurrentDomain.UnhandledException += (sender, e) =>
            {
                var ex = e.ExceptionObject as Exception;
                var trace = new System.Diagnostics.StackTrace(ex, true);
                var frame = trace.GetFrame(0);
                var file = frame?.GetFileName();
                var line = frame?.GetFileLineNumber();

                Logger.Info?.Print(LogClass.Application,
                    $"Unhandled exception: {ex}\nFile: {file}\nLine: {line}");

            };

            if (OperatingSystem.IsMacOS() || OperatingSystem.IsIOS())
            {
                if (option.GraphicsBackend == GraphicsBackend.OpenGl)
                {
                    option.GraphicsBackend = GraphicsBackend.Vulkan;
                    Logger.Warning?.Print(LogClass.Application, "OpenGL is not supported on Apple platforms, switching to Vulkan!");
                }
            }

            DriverUtilities.InitDriverConfig(option.BackendThreading == BackendThreading.Off);
            _virtualFileSystem.ReloadKeySet();

            while (true)
            {
                LoadApplication(option);

                if (_userChannelPersistence.PreviousIndex == -1 || !_userChannelPersistence.ShouldRestart)
                    break;

                _userChannelPersistence.ShouldRestart = false;
            }

            _inputManager.Dispose();
        }
        
        private static WindowBase CreateWindow(Options options)
        {
            return new MoltenVKWindow(_inputManager, options.LoggingGraphicsDebugLevel, options.AspectRatio, options.EnableMouse, options.HideCursorMode);
        }
        
        private static IRenderer CreateRenderer(Options options, WindowBase window)
        {
            if (options.GraphicsBackend == GraphicsBackend.Vulkan)
            {
                string preferredGpuId = string.Empty;
                Vk api = Vk.GetApi();

                if (!string.IsNullOrEmpty(options.PreferredGPUVendor))
                {
                    string preferredGpuVendor = options.PreferredGPUVendor.ToLowerInvariant();
                    var devices = VulkanRenderer.GetPhysicalDevices(api);
                    foreach (var device in devices)
                    {
                        if (device.Vendor.ToLowerInvariant() == preferredGpuVendor)
                        {
                            preferredGpuId = device.Id;
                            break;
                        }
                    }
                }

                if (window is MoltenVKWindow mvulkanWindow)
                    return new VulkanRenderer(api,
                        (instance, vk) => new SurfaceKHR((ulong)(mvulkanWindow.CreateWindowSurface(instance.Handle))),
                        mvulkanWindow.GetRequiredInstanceExtensions, preferredGpuId);
            }

            return new OpenGLRenderer();
        }
        
        private static Switch InitializeEmulationContext(WindowBase window, IRenderer renderer, Options options)
        {
            renderer = renderer.TryMakeThreaded(options.BackendThreading);

            bool appleHV;
            if (!OperatingSystem.IsIOSVersionAtLeast(16, 4) && options.UseHypervisor)
                appleHV = true;
            else if (OperatingSystem.IsIOS())
                appleHV = false;
            else
                appleHV = options.UseHypervisor;

            // Was unconditionally MemoryConfiguration4GiB (note this also means the
            // "Expand Guest RAM" UI toggle, options.ExpandRAM, was never actually read here -
            // that's a separate pre-existing bug, left alone since fixing it is orthogonal to
            // this change). On iOS devices with very little physical RAM and no Extended
            // Virtual Addressing entitlement, the standard 4 GiB DRAM reservation alone can
            // exceed the entire usable virtual address space ceiling (~3.3-3.4 GiB on a 3 GB
            // device such as the iPad 9th generation), which is very likely why "Cannot
            // allocate memory" appears before a game even starts. MemoryConfigurationLowRAM
            // is a MeloNX-specific 2 GiB arrangement (not a real Nintendo configuration - see
            // its definition in MemoryConfiguration.cs for how the pool split was derived) used
            // only on such devices; every other device keeps the original, unmodified behaviour.
            var memoryConfiguration = DeviceMemoryInfo.IsVeryLowMemoryDevice
                ? MemoryConfiguration.MemoryConfigurationLowRAM
                : MemoryConfiguration.MemoryConfiguration4GiB;

            var configuration = new HleConfiguration(
                memoryConfiguration,
                options.SystemLanguage,
                options.SystemRegion,
                Ryujinx.Common.Configuration.VSyncMode.Switch,
                !options.DisableDockedMode,
                !options.DisablePTC,
                ITickSource.RealityTickScalar,
                options.EnableInternetAccess,
                !options.DisableFsIntegrityChecks ? IntegrityCheckLevel.ErrorOnInvalid : IntegrityCheckLevel.None,
                options.FsGlobalAccessLogMode,
                options.SystemTimeOffset,
                options.SystemTimeZone,
                options.MemoryManagerMode,
                options.IgnoreMissingServices,
                options.AspectRatio,
                options.AudioVolume,
                appleHV,
                options.MultiplayerLanInterfaceId,
                options.ldnMitm ? MultiplayerMode.LdnMitm : MultiplayerMode.Disabled,
                false, // MultiplayerDisableP2p
                string.Empty, // Passphrase
                string.Empty, // Server
                false,
                0,
                false,
                0
            ).Configure(
                _virtualFileSystem,
                _libHacHorizonManager,
                _contentManager,
                _accountManager,
                _userChannelPersistence,
                renderer,
                new SDL3HardwareDeviceDriver(),
                window
            );

            return new Switch(configuration);
        }
        
        private static void SetupProgressHandler()
        {
            if (_emulationContext.Processes.ActiveApplication.DiskCacheLoadState != null)
            {
                _emulationContext.Processes.ActiveApplication.DiskCacheLoadState.StateChanged -= ProgressHandler;
                _emulationContext.Processes.ActiveApplication.DiskCacheLoadState.StateChanged += ProgressHandler;
            }

            _emulationContext.Gpu.ShaderCacheStateChanged -= ProgressHandler;
            _emulationContext.Gpu.ShaderCacheStateChanged += ProgressHandler;
        }
        
        private static void ProgressHandler<T>(T state, int current, int total) where T : Enum
        {
            string jsonData = state switch
            {
                LoadState => $"[\"PTC\",{current},{total}]",
                ShaderCacheState => $"[\"Shaders\",{current},{total}]",
                _ => throw new ArgumentException($"Unknown Progress Handler type {typeof(T)}"),
            };
            
            byte[] jsonBytes = Encoding.UTF8.GetBytes(jsonData);
            nint unmanagedPointer = Marshal.AllocHGlobal(jsonBytes.Length);

            try
            {
                Marshal.Copy(jsonBytes, 0, unmanagedPointer, jsonBytes.Length);
                
                CallbackRegistry.Invoke("ProgressWithPTCorShaderCache", unmanagedPointer, (int)jsonBytes.Length);
            }
            finally
            {
                Marshal.FreeHGlobal(unmanagedPointer);
            }
        }
        
        private static void ExecutionEntrypoint()
        {
            if (OperatingSystem.IsWindows())
                _windowsMultimediaTimerResolution = new WindowsMultimediaTimerResolution(1);

            DisplaySleep.Prevent();

            _window.Initialize(_emulationContext, _inputConfiguration, _enableKeyboard, _enableMouse);
            _window.Execute();

            _emulationContext.Dispose();
            _window.Dispose();

            if (OperatingSystem.IsWindows())
            {
                _windowsMultimediaTimerResolution?.Dispose();
                _windowsMultimediaTimerResolution = null;
            }
        }
        
        private static bool LoadApplication(Options options)
        {
            string path = options.InputPath;

            Logger.RestartTime();

            WindowBase window = CreateWindow(options);

            if (window is MoltenVKWindow mvulkanWindow)
                mvulkanWindow.SetNativeWindow(nativeMetalLayer);

            IRenderer renderer = CreateRenderer(options, window);

            _window = window;
            _window.IsFullscreen = options.IsFullscreen;
            _window.DisplayId = options.DisplayId;
            _window.IsExclusiveFullscreen = options.IsExclusiveFullscreen;
            _window.ExclusiveFullscreenWidth = options.ExclusiveFullscreenWidth;
            _window.ExclusiveFullscreenHeight = options.ExclusiveFullscreenHeight;
            _window.AntiAliasing = options.AntiAliasing;
            _window.ScalingFilter = options.ScalingFilter;
            _window.ScalingFilterLevel = options.ScalingFilterLevel;
            renderer.Window?.SetColorSpacePassthrough(true);

            _emulationContext = InitializeEmulationContext(window, renderer, options);

            SystemVersion firmwareVersion = _contentManager.GetCurrentFirmwareVersion();
            Logger.Notice.Print(LogClass.Application, $"Using Firmware Version: {firmwareVersion?.VersionString}");

            if (path.StartsWith("0x", StringComparison.OrdinalIgnoreCase))
            {
                ulong id = Convert.ToUInt64(path, 16);
                string contentPath = _contentManager.GetInstalledContentPath(id, StorageId.BuiltInSystem, NcaContentType.Program);
                path = contentPath;
            }

            bool isFirmwareTitle = false;
            if (path.StartsWith("@SystemContent"))
            {
                path = VirtualFileSystem.SwitchPathToSystemPath(path);
                isFirmwareTitle = true;
            }

            if (Directory.Exists(path))
            {
                string[] romFsFiles = Directory.GetFiles(path, "*.istorage");
                if (romFsFiles.Length == 0)
                    romFsFiles = Directory.GetFiles(path, "*.romfs");

                if (romFsFiles.Length > 0)
                {
                    Logger.Info?.Print(LogClass.Application, "Loading as cart with RomFS.");
                    if (!_emulationContext.LoadCart(path, romFsFiles[0])) { _emulationContext.Dispose(); return false; }
                }
                else
                {
                    Logger.Info?.Print(LogClass.Application, "Loading as cart WITHOUT RomFS.");
                    if (!_emulationContext.LoadCart(path)) { _emulationContext.Dispose(); return false; }
                }
            }
            else if (File.Exists(path))
            {
                switch (Path.GetExtension(path).ToLowerInvariant())
                {
                    case ".xci":
                        Logger.Info?.Print(LogClass.Application, "Loading as XCI.");
                        if (!_emulationContext.LoadXci(path)) { _emulationContext.Dispose(); return false; }
                        break;
                    case ".nca":
                        Logger.Info?.Print(LogClass.Application, "Loading as NCA.");
                        if (!_emulationContext.LoadNca(path)) { _emulationContext.Dispose(); return false; }
                        break;
                    case ".nsp":
                    case ".pfs0":
                        Logger.Info?.Print(LogClass.Application, "Loading as NSP.");
                        if (!_emulationContext.LoadNsp(path)) { _emulationContext.Dispose(); return false; }
                        break;
                    default:
                        if (isFirmwareTitle)
                        {
                            Logger.Info?.Print(LogClass.Application, "Loading as Firmware Title (NCA).");
                            if (!_emulationContext.LoadNca(path)) { _emulationContext.Dispose(); return false; }
                        }
                        else
                        {
                            Logger.Info?.Print(LogClass.Application, "Loading as Homebrew.");
                            try
                            {
                                if (!_emulationContext.LoadProgram(path)) { _emulationContext.Dispose(); return false; }
                            }
                            catch (ArgumentOutOfRangeException)
                            {
                                Logger.Error?.Print(LogClass.Application, "The specified file is not supported by Ryujinx.");
                                _emulationContext.Dispose();
                                return false;
                            }
                        }
                        break;
                }
            }
            else
            {
                Logger.Warning?.Print(LogClass.Application, $"Couldn't load '{options.InputPath}'. Please specify a valid XCI/NCA/NSP/PFS0/NRO file.");
                _emulationContext.Dispose();
                return false;
            }

            SetupProgressHandler();
            ExecutionEntrypoint();
            return true;
        }
        
        
        // GameInfo
        [UnmanagedCallersOnly(EntryPoint = "get_game_info")]
        public static GameInfoNative GetGameInfoNative(int descriptor, nint extensionPtr)
        {
            if (_virtualFileSystem == null)
                _virtualFileSystem = VirtualFileSystem.CreateInstance();

            var extension = Marshal.PtrToStringAnsi(extensionPtr);
            var stream = OpenFile(descriptor);

            return GameInfoLoader.GetGameInfoNative(_virtualFileSystem, stream, extension);
        }

        private static FileStream OpenFile(int descriptor)
        {
            var safeHandle = new SafeFileHandle(descriptor, false);

            return new FileStream(safeHandle, FileAccess.ReadWrite);
        }


        public unsafe struct DlcNcaListItem 
        {
            public fixed byte Path[256];
            public ulong TitleId;
        }

        public unsafe struct DlcNcaList
        {
            public bool success;
            public uint size;
            public unsafe DlcNcaListItem* items;
        }

        [StructLayout(LayoutKind.Sequential)]
        public unsafe struct AvatarInfo
        {
            public byte* ImageData;    
            public int ImageSize;     
            public sbyte* FileName;  
        }

        [StructLayout(LayoutKind.Sequential)]
        public unsafe struct AvatarArray
        {
            public int Count;          
            public AvatarInfo* Avatars; 
        }
    }
}
