using Ryujinx.HLE;
using Ryujinx.HLE.HOS.Services.Hid;
using Ryujinx.HLE.HOS.Services.Hid.Types.SharedMemory.TouchScreen;
using System;
using System.Collections.Generic;
using System.Numerics;

namespace Ryujinx.Input.HLE
{
    public class TouchScreenManager : IDisposable
    {
        private readonly IMouse _mouse;
        private Switch _device;
        private bool _wasClicking;
        private Dictionary<int, Vector2> _previousTouchPositions = new();

        public TouchScreenManager(IMouse mouse)
        {
            _mouse = mouse;
        }

        public void Initialize(Switch device)
        {
            _device = device;
        }

        public bool Update(bool isFocused, bool isClicking = false, float aspectRatio = 0)
        {
            if (!isFocused || (!_wasClicking && !isClicking))
            {
                // In case we lost focus, send the end touch.
                if (_wasClicking && !isClicking)
                {
                    MouseStateSnapshot snapshot = IMouse.GetMouseStateSnapshot(_mouse);
                    Vector2 touchPosition = IMouse.GetScreenPosition(snapshot.Position, _mouse.ClientSize, aspectRatio);

                    TouchPoint currentPoint = new()
                    {
                        Attribute = TouchAttribute.End,

                        X = (uint)touchPosition.X,
                        Y = (uint)touchPosition.Y,

                        // Placeholder values till more data is acquired
                        DiameterX = 10,
                        DiameterY = 10,
                        Angle = 90,
                    };

                    _device.Hid.Touchscreen.Update(currentPoint);

                }

                _wasClicking = false;

                _device.Hid.Touchscreen.Update();

                return false;
            }

            if (aspectRatio > 0)
            {
                MouseStateSnapshot snapshot = IMouse.GetMouseStateSnapshot(_mouse);
                Vector2 touchPosition = IMouse.GetScreenPosition(snapshot.Position, _mouse.ClientSize, aspectRatio);

                TouchAttribute attribute = TouchAttribute.None;

                if (!_wasClicking && isClicking)
                {
                    attribute = TouchAttribute.Start;
                }
                else if (_wasClicking && !isClicking)
                {
                    attribute = TouchAttribute.End;
                }

                TouchPoint currentPoint = new()
                {
                    Attribute = attribute,

                    X = (uint)touchPosition.X,
                    Y = (uint)touchPosition.Y,

                    // Placeholder values till more data is acquired
                    DiameterX = 10,
                    DiameterY = 10,
                    Angle = 90,
                };

                _device.Hid.Touchscreen.Update(currentPoint);

                _wasClicking = isClicking;

                return true;
            }

            return false;
        }


        public bool UpdateMultiTouch(ITouchScreen touchScreen, bool isFocused)
        {
            if (!isFocused)
            {
                // Send end touch for all previous touche
                if (_previousTouchPositions.Count > 0)
                {
                    List<TouchPoint> endPoints = new();
                    foreach (var kvp in _previousTouchPositions)
                    {
                        endPoints.Add(new TouchPoint
                        {
                            Attribute = TouchAttribute.End,
                            X = (uint)kvp.Value.X,
                            Y = (uint)kvp.Value.Y,
                            DiameterX = 10,
                            DiameterY = 10,
                            Angle = 90,
                        });
                    }
                    _device.Hid.Touchscreen.Update(endPoints.ToArray());
                    _previousTouchPositions.Clear();
                }

                _device.Hid.Touchscreen.Update();
                return false;
            }

            Vector2[] positions = touchScreen.GetPositions();
            Vector2[] screenPositions = ITouchScreen.GetScreenPositionTouch(positions, touchScreen.ClientSize);


            if (positions.Length == 0)
            {
                if (_previousTouchPositions.Count > 0)
                {
                    List<TouchPoint> endPoints = new();
                    foreach (var kvp in _previousTouchPositions)
                    {
                        endPoints.Add(new TouchPoint
                        {
                            Attribute = TouchAttribute.End,
                            X = (uint)kvp.Value.X,
                            Y = (uint)kvp.Value.Y,
                            DiameterX = 10,
                            DiameterY = 10,
                            Angle = 90,
                        });
                    }
                    _device.Hid.Touchscreen.Update(endPoints.ToArray());
                    _previousTouchPositions.Clear();
                }

                _device.Hid.Touchscreen.Update();
                return false;
            }

            List<TouchPoint> touchPoints = new();
            HashSet<int> currentTouchIds = new();

            for (int i = 0; i < screenPositions.Length; i++)
            {
                Vector2 screenPos = screenPositions[i];
                TouchAttribute attribute;

                if (_previousTouchPositions.ContainsKey(i))
                {
                    attribute = TouchAttribute.None;
                }
                else
                {
                    attribute = TouchAttribute.Start;
                }

                touchPoints.Add(new TouchPoint
                {
                    Attribute = attribute,
                    X = (uint)screenPos.X,
                    Y = (uint)screenPos.Y,
                    DiameterX = 10,
                    DiameterY = 10,
                    Angle = 90,
                });

                currentTouchIds.Add(i);
                _previousTouchPositions[i] = screenPos;
            }

            List<int> endedTouches = new();
            foreach (var touchId in _previousTouchPositions.Keys)
            {
                if (!currentTouchIds.Contains(touchId))
                {
                    endedTouches.Add(touchId);
                    touchPoints.Add(new TouchPoint
                    {
                        Attribute = TouchAttribute.End,
                        X = (uint)_previousTouchPositions[touchId].X,
                        Y = (uint)_previousTouchPositions[touchId].Y,
                        DiameterX = 10,
                        DiameterY = 10,
                        Angle = 90,
                    });
                }
            }

            foreach (var touchId in endedTouches)
            {
                _previousTouchPositions.Remove(touchId);
            }

            _device.Hid.Touchscreen.Update(touchPoints.ToArray());

            return touchPoints.Count > 0;
        }


        public void Dispose()
        {
            GC.SuppressFinalize(this);
        }
    }
}
