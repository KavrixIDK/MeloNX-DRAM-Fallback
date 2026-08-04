using Ryujinx.Common.Configuration;
using Ryujinx.Common.Configuration.Hid;
using Ryujinx.Common.Logging;
using Ryujinx.Common.Callbacks;
using Ryujinx.Graphics.GAL;
using Ryujinx.Graphics.GAL.Multithreading;
using Ryujinx.Graphics.Gpu;
using Ryujinx.HLE.HOS.Applets;
using Ryujinx.HLE.HOS.Services.Account.Acc;
using Ryujinx.HLE.HOS.Services.Am.AppletOE.ApplicationProxyService.ApplicationProxy.Types;
using Ryujinx.HLE.UI;
using Ryujinx.Input;
using Ryujinx.Input.HLE;
using Ryujinx.Input.Native;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using AntiAliasing = Ryujinx.Common.Configuration.AntiAliasing;
using ScalingFilter = Ryujinx.Common.Configuration.ScalingFilter;
using Switch = Ryujinx.HLE.Switch;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Channels;
using System.Threading.Tasks;
using System.Buffers.Binary;
// using Ryujinx.Ava.UI.Models;


namespace Ryujinx.Library
{
    abstract partial class WindowBase: IHostUIHandler, IDisposable
    {
        protected const int DefaultWidth = 1280;
        protected const int DefaultHeight = 720;
        private const int TargetFps = 60;

        private static readonly ConcurrentQueue<Action> _mainThreadActions = new();

        public static void QueueMainThreadAction(Action action)
        {
            _mainThreadActions.Enqueue(action);
        }

        public bool _isPaused;
        public ManualResetEvent _pauseEvent;

        public NpadManager NpadManager;
        public TouchScreenManager TouchScreenManager;
        public Switch Device;
        public IRenderer Renderer;

        public IntPtr WindowHandle;

        public IHostUITheme HostUITheme { get; }
        public static int Width { get; private set; }
        public static int Height { get; private set; }
        public int DisplayId { get; set; }
        public bool IsFullscreen { get; set; }
        public bool IsExclusiveFullscreen { get; set; }
        public int ExclusiveFullscreenWidth { get; set; }
        public int ExclusiveFullscreenHeight { get; set; }
        public AntiAliasing AntiAliasing { get; set; }
        public ScalingFilter ScalingFilter { get; set; }
        public int ScalingFilterLevel { get; set; }

        public NativeTouchDriver MouseDriver;
        private readonly InputManager _inputManager;
        private readonly IKeyboard _keyboardInterface;
        private readonly GraphicsDebugLevel _glLogLevel;
        private readonly Stopwatch _chrono;
        private readonly long _ticksPerFrame;
        private readonly CancellationTokenSource _gpuCancellationTokenSource;
        public ManualResetEvent _exitEvent;
        public ManualResetEvent _gpuDoneEvent;
        private readonly AutoResetEvent _inputUpdatedEvent;
        private volatile StatisticsRequest? _latestStatistics;
        private CancellationTokenSource? _statisticsCts;


        private long _ticks;
        public bool _isActive;
        private bool _isStopped;

        public bool _ranFirstFrame;

        private string _gpuDriverName;

        public AspectRatio _aspectRatio;
        private readonly bool _enableMouse;


        public WindowBase(
            InputManager inputManager,
            GraphicsDebugLevel glLogLevel,
            AspectRatio aspectRatio,
            bool enableMouse,
            HideCursorMode hideCursorMode)
        {
            MouseDriver = new NativeTouchDriver(hideCursorMode);
            _inputManager = inputManager;
            _inputManager.SetMouseDriver(MouseDriver);
            NpadManager = _inputManager.CreateNpadManager();
            TouchScreenManager = _inputManager.CreateTouchScreenManager();
            _keyboardInterface = (IKeyboard)_inputManager.KeyboardDriver.GetGamepad("0");
            _glLogLevel = glLogLevel;
            _chrono = new Stopwatch();
            _ticksPerFrame = Stopwatch.Frequency / TargetFps;
            _gpuCancellationTokenSource = new CancellationTokenSource();
            _exitEvent = new ManualResetEvent(false);
            _gpuDoneEvent = new ManualResetEvent(false);
            _inputUpdatedEvent = new AutoResetEvent(false);
            _pauseEvent = new ManualResetEvent(true);
            _aspectRatio = aspectRatio;
            _enableMouse = enableMouse;
            HostUITheme = new NativeHostUiTheme();
            NativeGamepadDriver.OnInputUpdated += SignalInputUpdated;

            Width = DefaultWidth;
            Height = DefaultHeight;
        }

        private void SignalInputUpdated()
        {
            _inputUpdatedEvent.Set();
        }

        public void Initialize(Switch device, List<InputConfig> inputConfigs, bool enableKeyboard, bool enableMouse)
        {
            Device = device;

            IRenderer renderer = Device.Gpu.Renderer;

            if (renderer is ThreadedRenderer tr)
            {
                renderer = tr.BaseRenderer;
            }

            Renderer = renderer;

            NpadManager.Initialize(device, inputConfigs, enableKeyboard, enableMouse);
            TouchScreenManager.Initialize(device);
        }

        [UnmanagedCallersOnly(EntryPoint = "set_view_size")]
        static unsafe void set_view_size(int width, int height)
        {
            Width = width;
            Height = height;


        }

        private void InitializeWindow()
        {
            Width = ExclusiveFullscreenWidth;
            Height = ExclusiveFullscreenHeight;

            MouseDriver.SetClientSize(Width, Height);
        }

        protected abstract void InitializeWindowRenderer();

        protected abstract void InitializeRenderer();

        protected abstract void FinalizeWindowRenderer();

        protected abstract void SwapBuffers();

        private string GetGpuDriverName()
        {
            return Renderer.GetHardwareInfo().GpuDriver;
        }

        private void SetAntiAliasing()
        {
            Renderer?.Window.SetAntiAliasing(AntiAliasing);
        }

        private void SetScalingFilter()
        {
            Renderer?.Window.SetScalingFilter(ScalingFilter);
            Renderer?.Window.SetScalingFilterLevel(ScalingFilterLevel);
        }

        public void Render()
        {
            InitializeWindowRenderer();

            Device.Gpu.Renderer.Initialize(_glLogLevel);

            InitializeRenderer();

            SetAntiAliasing();

            SetScalingFilter();

            _gpuDriverName = GetGpuDriverName();

            _ranFirstFrame = false;

            Device.Gpu.Renderer.RunLoop(() =>
            {
                Device.Gpu.SetGpuThread();
                Device.Gpu.InitializeShaderCache(_gpuCancellationTokenSource.Token);

                while (_isActive)
                {
                    if (_isStopped)
                    {
                        return;
                    }

                    _pauseEvent.WaitOne();

                    _ticks += _chrono.ElapsedTicks;

                    _chrono.Restart();

                    if (Device.WaitFifo())
                    {
                        Device.Statistics.RecordFifoStart();
                        Device.ProcessFrame();
                        Device.Statistics.RecordFifoEnd();
                    }

                    while (Device.ConsumeFrameAvailable())
                    {
                        Device.PresentFrame(SwapBuffers);

                        if (!_ranFirstFrame)
                        { 
                            _ranFirstFrame = true;
                            SendStatistics(false);
                         }
                        
                    }

                    if (_ticks >= _ticksPerFrame)
                    {
                        string dockedMode = Device.System.State.DockedMode ? "Docked" : "Handheld";
                        float scale = GraphicsConfig.ResScale;
                        if (scale != 1)
                        {
                            dockedMode += $" ({scale}x)";
                        }

                        
                        SendStatistics();

                        /*
                            Device.EnableDeviceVsync,
                            dockedMode,
                            Device.Configuration.AspectRatio.ToText(),
                            $"Game: {Device.Statistics.GetGameFrameRate():00.00} FPS ({Device.Statistics.GetGameFrameTime():00.00} ms)",
                            $"FIFO: {Device.Statistics.GetFifoPercent():0.00} %",
                            $"GPU: {_gpuDriverName}"));
                        */
                        
                        _ticks = Math.Min(_ticks - _ticksPerFrame, _ticksPerFrame);
                    }
                }

                if (Device.Gpu.Renderer is ThreadedRenderer threaded)
                {
                    threaded.FlushThreadedCommands();
                }

                _gpuDoneEvent.Set();
            });

            FinalizeWindowRenderer();
        }

        public void Exit()
        {
            TouchScreenManager?.Dispose();
            NpadManager?.Dispose();

            if (_isStopped)
            {
                return;
            }

            _gpuCancellationTokenSource.Cancel();

            _isStopped = true;
            _isActive = false;
            _inputUpdatedEvent.Set();

            _exitEvent.WaitOne();
            _exitEvent.Dispose();
            NativeGamepadDriver.OnInputUpdated -= SignalInputUpdated;
        }

        public static void ProcessMainThreadQueue()
        {
            while (_mainThreadActions.TryDequeue(out Action action))
            {
                action();
            }
        }

        public void MainLoop()
        {
            while (_isActive)
            {
                UpdateFrame();

                ProcessMainThreadQueue();

                _inputUpdatedEvent.WaitOne(1);
            }

            _exitEvent.Set();
        }

        private bool UpdateFrame()
        {
            if (!_isActive)
            {
                return true;
            }

            if (_isStopped)
            {
                return false;
            }

            NpadManager.Update();

            bool hasTouch;

            MouseDriver.SetClientSize(Width, Height);

            hasTouch = TouchScreenManager.UpdateMultiTouch(_inputManager.MouseDriver.GetGamepad("") as ITouchScreen, true);

            if (!hasTouch)
            {
                TouchScreenManager.Update(false);
            }

            Device.Hid.DebugPad.Update();

            MouseDriver.UpdatePosition();

            return true;
        }

        public void Execute()
        {
            _chrono.Restart();
            _isActive = true;

            InitializeWindow();

            Thread renderLoopThread = new(Render)
            {
                Name = "GUI.RenderLoop",
            };
            renderLoopThread.Start();

            MainLoop();

            _gpuDoneEvent.WaitOne();
            _gpuDoneEvent.Dispose();

            Exit();
        }

        public bool DisplayInputDialog(SoftwareKeyboardUIArgs args, out string userText)
        {
            userText = null;

            if (OperatingSystem.IsIOS())
            {
                string result = null;
                using ManualResetEventSlim inputReceived = new(false);

                AlertHelper.ShowAlertWithTextInput(args.HeaderText, args.SubtitleText, args.GuideText, inputText =>
                {
                    result = inputText;
                    inputReceived.Set();
                });

                inputReceived.Wait();
                userText = result;
            }

            return true;
        }

        public void SendStatistics(bool before = true)
        {
            static double Sanitize(double v) =>
                double.IsFinite(v) ? Math.Round(v, 2) : 0.0;

            Span<byte> bytes = stackalloc byte[33];

            double fps = before ? Sanitize(Device.Statistics.GetGameFrameRate()) : 0d;
            double frameTime = before ? Sanitize(Device.Statistics.GetGameFrameTime()) : 0d;
            double fifo = before ? Sanitize(Device.Statistics.GetFifoPercent())   : 0d;

            BinaryPrimitives.WriteDoubleLittleEndian(bytes[0..],  fps);
            BinaryPrimitives.WriteDoubleLittleEndian(bytes[8..],  frameTime);
            bytes[16] = (byte)(_ranFirstFrame ? 1 : 0);
            BinaryPrimitives.WriteDoubleLittleEndian(bytes[17..], fifo);

            unsafe {
                fixed (byte* ptr = bytes)
                {
                    CallbackRegistry.Invoke("push_statistics", ptr, bytes.Length);
                }
            }
        }

        public bool DisplayMessageDialog(string title, string message)
        {
            if (OperatingSystem.IsIOS())
            {
                Console.WriteLine($"Alert: {title}, message: {message}");

                AlertHelper.ShowAlert(title, message, false);
            }

            return true;
        }
    
        public bool DisplayMessageDialog(ControllerAppletUIArgs args)
        {
            string playerCount = args.PlayerCountMin == args.PlayerCountMax
                ? $"exactly {args.PlayerCountMin}"
                : $"{args.PlayerCountMin}-{args.PlayerCountMax}";

            string message = $"Application requests {playerCount} player(s) with:\n\n"
                           + $"TYPES: {args.SupportedStyles}\n\n"
                           + $"PLAYERS: {string.Join(", ", args.SupportedPlayers)}\n\n"
                           + (args.IsDocked ? "Docked mode set. Handheld is also invalid.\n\n" : "")
                           + "Please reconfigure Input now and then press OK.";

            return DisplayMessageDialog("Controller Applet", message);
        }

        public bool DisplayCabinetDialog(out string userText)
        {
            userText = null;

            if (OperatingSystem.IsIOS())
            {
                string result = null;
                using ManualResetEventSlim inputReceived = new(false);

                AlertHelper.ShowAlertWithTextInput("Amiibo", "Enter a name for the Amiibo", string.Empty, inputText =>
                {
                    result = inputText;
                    inputReceived.Set();
                });

                inputReceived.Wait();
                userText = result;
            }

            return true;
        }

        public void DisplayCabinetMessageDialog()
        {
            DisplayMessageDialog("Amiibo", "Please scan your Amiibo now.");
        }

        public bool DisplayErrorAppletDialog(string title, string message, string[] buttonsText, (uint Module, uint Description)? errorCode = null)
        {
            string errorSuffix = errorCode.HasValue
                ? $"\n\nError Code: {errorCode.Value.Module:X4}-{errorCode.Value.Description:X4}"
                : string.Empty;

            Logger.Error?.Print(LogClass.Application, $"{title}: {message}{errorSuffix}");

            DisplayMessageDialog(title, message + errorSuffix);

            return false;
        }

        public IDynamicTextInputHandler CreateDynamicTextInputHandler()
        {
            return new NativeDynamicTextInputHandler();
        }

        public void ExecuteProgram(Switch device, ProgramSpecifyKind kind, ulong value)
        {
            device.Configuration.UserChannelPersistence.ExecuteProgram(kind, value);

            Exit();
        }

        public Ryujinx.HLE.HOS.Services.Account.Acc.UserProfile ShowPlayerSelectDialog()
        {
            Logger.Warning?.Print(LogClass.Application, "Player select dialog is not supported in headless mode. Using default profile.");

            return null;
        }

        public void TakeScreenshot()
        {
            Logger.Warning?.Print(LogClass.Application, "TakeScreenshot is not supported in headless mode.");
        }

        public void Dispose()
        {
            Dispose(true);
        }

        protected virtual void Dispose(bool disposing)
        {
            if (disposing)
            {
                _isActive = false;
                _inputUpdatedEvent.Set();
                NativeGamepadDriver.OnInputUpdated -= SignalInputUpdated;
                TouchScreenManager?.Dispose();
                NpadManager.Dispose();
            }
        }

        internal sealed class StatisticsRequest
        {
            public double FPS { get; set; } = 0d;
            public double FrameTime { get; set; } = 0d;
            public bool Started { get; set; } = false;
            public double FIFO { get; set; } = 0d;
        }
    }
}
