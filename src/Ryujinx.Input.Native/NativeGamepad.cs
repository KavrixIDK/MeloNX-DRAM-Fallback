using Ryujinx.Common.Configuration.Hid;
using Ryujinx.Common.Configuration.Hid.Controller;
using Ryujinx.Common.Callbacks;
using System.Collections.Generic;
using System;
using System.Numerics;
using System.Runtime.InteropServices;

namespace Ryujinx.Input.Native
{
    public class NativeGamepad : IGamepad, IHighDefinitionRumbleGamepad
    {
        private readonly object _stateLock = new object();
        private readonly bool[] _buttonStates;
        private readonly float[] _stickStates; 
        private readonly Vector3[] _motionStates; 

        private static readonly GamepadButtonInputId[] ButtonMapping = new GamepadButtonInputId[17]
        {
            GamepadButtonInputId.A,             // 0
            GamepadButtonInputId.B,             // 1
            GamepadButtonInputId.X,             // 2
            GamepadButtonInputId.Y,             // 3
            GamepadButtonInputId.Back,          // 4
            GamepadButtonInputId.Guide,         // 5
            GamepadButtonInputId.Start,         // 6
            GamepadButtonInputId.LeftStick,     // 7
            GamepadButtonInputId.RightStick,    // 8
            GamepadButtonInputId.LeftShoulder,  // 9
            GamepadButtonInputId.RightShoulder, // 10
            GamepadButtonInputId.DpadUp,        // 11
            GamepadButtonInputId.DpadDown,      // 12
            GamepadButtonInputId.DpadLeft,      // 13
            GamepadButtonInputId.DpadRight,     // 14
            GamepadButtonInputId.LeftTrigger,   // 15
            GamepadButtonInputId.RightTrigger   // 16
        };

        private StandardControllerInputConfig _configuration;
        private float _triggerThreshold;

        public string Id { get; }
        public string Name { get; }
        public bool IsConnected { get; private set; }
        public GamepadFeaturesFlag Features { get; }

        public NativeGamepad(string name, string id)
        {
            Name = name;
            Id = id;
            IsConnected = true;
            Features = GamepadFeaturesFlag.Rumble | GamepadFeaturesFlag.Motion;

            _buttonStates = new bool[(int)GamepadButtonInputId.Count];
            _stickStates = new float[4];
            _motionStates = new Vector3[2];
            _triggerThreshold = 0.0f;
        }

        internal bool SetButtonStateInternal(int buttonId2, bool pressed)
        {
            if (buttonId2 >= 0 && buttonId2 < ButtonMapping.Length)
            {
                int mappedId = (int)ButtonMapping[buttonId2];
                lock (_stateLock)
                {
                    if (_buttonStates[mappedId] == pressed)
                    {
                        return false;
                    }

                    _buttonStates[mappedId] = pressed;

                    return true;
                }
            }

            return false;
        }

        internal bool SetStickAxisInternal(int stickId, float x, float y)
        {
            lock (_stateLock)
            {
                if (stickId == 1) // Left Stick
                {
                    return SetStickAxis(0, 1, x, y);
                }

                if (stickId == 2) // Right Stick
                {
                    return SetStickAxis(2, 3, x, y);
                }
            }

            return false;
        }

        private bool SetStickAxis(int xIndex, int yIndex, float x, float y)
        {
            float clampedX = Math.Clamp(x, -1.0f, 1.0f);
            float clampedY = Math.Clamp(y, -1.0f, 1.0f);

            if (_stickStates[xIndex] == clampedX && _stickStates[yIndex] == clampedY)
            {
                return false;
            }

            _stickStates[xIndex] = clampedX;
            _stickStates[yIndex] = clampedY;

            return true;
        }

        internal bool SetMotionDataInternal(int motionType, float x, float y, float z)
        {
            lock (_stateLock)
            {
                Vector3 value = new Vector3(x, y, z);

                if (motionType == (int)MotionInputId.Accelerometer)
                {
                    if (_motionStates[0] == value)
                    {
                        return false;
                    }

                    _motionStates[0] = value;
                    return true;
                }
                else if (motionType == (int)MotionInputId.Gyroscope)
                {
                    if (_motionStates[1] == value)
                    {
                        return false;
                    }

                    _motionStates[1] = value;
                    return true;
                }
            }

            return false;
        }

        public GamepadStateSnapshot GetStateSnapshot()
        {
            return IGamepad.GetStateSnapshot(this);
        }

        public void SetLed(uint packedRgb) {}

        
        public GamepadStateSnapshot GetMappedStateSnapshot() => GetStateSnapshot();

        public bool IsPressed(GamepadButtonInputId inputId)
        {
            lock (_stateLock)
            {
                return (int)inputId >= 0 && (int)inputId < _buttonStates.Length && _buttonStates[(int)inputId];
            }
        }

        public (float, float) GetStick(StickInputId inputId)
        {
            lock (_stateLock)
            {
                return inputId == StickInputId.Left ? (_stickStates[0], _stickStates[1]) : (_stickStates[2], _stickStates[3]);
            }
        }

        public Vector3 GetMotionData(MotionInputId inputId)
        {
            lock (_stateLock)
            {
                return inputId == MotionInputId.Accelerometer ? _motionStates[0] : _motionStates[1];
            }
        }

        public void SetConfiguration(InputConfig configuration)
        {
            _configuration = (StandardControllerInputConfig)configuration;
            _triggerThreshold = _configuration.TriggerThreshold;
        }

        public void SetTriggerThreshold(float triggerThreshold) => _triggerThreshold = triggerThreshold;

        public void ResetStateInternal()
        {
            lock (_stateLock)
            {
                Array.Clear(_buttonStates, 0, _buttonStates.Length);
                Array.Clear(_stickStates, 0, _stickStates.Length);
                Array.Clear(_motionStates, 0, _motionStates.Length);
            }
        }

        public void Rumble(float lowFrequency, float highFrequency, uint durationMs)
        {
            Rumble(new RumbleData
            {
                LowFrequency = lowFrequency,
                HighFrequency = highFrequency,
                DurationMs = durationMs,
                LeftAmplitudeLow = lowFrequency,
                LeftFrequencyLow = 160f,
                LeftAmplitudeHigh = highFrequency,
                LeftFrequencyHigh = 320f,
                RightAmplitudeLow = lowFrequency,
                RightFrequencyLow = 160f,
                RightAmplitudeHigh = highFrequency,
                RightFrequencyHigh = 320f,
            });
        }

        public void Rumble(GamepadVibrationValue leftVibration, GamepadVibrationValue rightVibration, uint durationMs)
        {
            float low = Math.Clamp(
                rightVibration.AmplitudeLow * 0.85f + rightVibration.AmplitudeHigh * 0.15f,
                0f,
                1f);
            float high = Math.Clamp(
                leftVibration.AmplitudeLow * 0.15f + leftVibration.AmplitudeHigh * 0.85f,
                0f,
                1f);

            Rumble(new RumbleData
            {
                LowFrequency = low,
                HighFrequency = high,
                DurationMs = durationMs,
                LeftAmplitudeLow = leftVibration.AmplitudeLow,
                LeftFrequencyLow = leftVibration.FrequencyLow,
                LeftAmplitudeHigh = leftVibration.AmplitudeHigh,
                LeftFrequencyHigh = leftVibration.FrequencyHigh,
                RightAmplitudeLow = rightVibration.AmplitudeLow,
                RightFrequencyLow = rightVibration.FrequencyLow,
                RightAmplitudeHigh = rightVibration.AmplitudeHigh,
                RightFrequencyHigh = rightVibration.FrequencyHigh,
            });
        }

        private void Rumble(RumbleData rumbleData)
        {
            unsafe 
            {
                int size = Marshal.SizeOf(typeof(RumbleData));
                nint ptr = Marshal.AllocHGlobal(size);
                try 
                {
                    Marshal.StructureToPtr(rumbleData, ptr, false);
                    CallbackRegistry.Invoke($"rumble-{Id}", (byte*)ptr, size);
                } 
                finally
                {
                    Marshal.FreeHGlobal(ptr);
                }
            }
        }

        public void Dispose() => IsConnected = false;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    public struct RumbleData
    {
        public float LowFrequency;
        public float HighFrequency;
        public uint DurationMs;
        public float LeftAmplitudeLow;
        public float LeftFrequencyLow;
        public float LeftAmplitudeHigh;
        public float LeftFrequencyHigh;
        public float RightAmplitudeLow;
        public float RightFrequencyLow;
        public float RightAmplitudeHigh;
        public float RightFrequencyHigh;
    }
}
