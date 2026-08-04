using System.Collections.Generic;
using System.Drawing;
using System.Linq;
using System.Numerics;
using System;

namespace Ryujinx.Input
{
    /// <summary>
    /// Represent an emulated touch screen.
    /// </summary>
    public interface ITouchScreen : IGamepad
    {
#pragma warning disable IDE0051 // Remove unused private member
        private const int SwitchPanelWidth = 1280;
#pragma warning restore IDE0051
        private const int SwitchPanelHeight = 720;

        /// <summary>
        /// Get the position of touches in the client.
        /// </summary>
        Vector2[] GetPositions();

        /// <summary>
        /// Get the client size.
        /// </summary>
        Size ClientSize { get; }

        /// <summary>
        /// Get a snaphost of the state of a mouse.
        /// </summary>
        /// <param name="mouse">The mouse to do a snapshot of</param>
        /// <returns>A snaphost of the state of the mouse.</returns>
        public static MouseStateSnapshot GetMouseStateSnapshot(IMouse mouse)
        {
            bool[] buttons = new bool[(int)MouseButton.Count];

            mouse.Buttons.CopyTo(buttons, 0);

            return new MouseStateSnapshot(buttons, mouse.GetPosition(), mouse.GetScroll());
        }

        /// <summary>
        /// Get the position of a touch on screen relative to the app's view
        /// </summary>
        /// <param name="mousePosition">The position of the mouse in the client</param>
        /// <param name="clientSize">The size of the client</param>
        /// <param name="aspectRatio">The aspect ratio of the view</param>
        /// <returns>A snaphost of the state of the mouse.</returns>
        public static Vector2[] GetScreenPositionTouch(IReadOnlyList<Vector2> mousePosition, Size clientSize)
        {
            return mousePosition.Select(vector => GetTouchPosition(vector, clientSize)).ToArray();
        }

        public static Vector2 GetTouchPosition(Vector2 mousePosition, Size clientSize)
        {
            float mouseX = mousePosition.X;
            float mouseY = mousePosition.Y;

            if (mouseX < 0 || mouseX >= clientSize.Width ||
                mouseY < 0 || mouseY >= clientSize.Height)
            {
                return new();
            }

            float scaledX = (mouseX / clientSize.Width) * SwitchPanelWidth;
            float scaledY = (mouseY / clientSize.Height) * SwitchPanelHeight;

            scaledX = Math.Max(0, Math.Min(SwitchPanelWidth - 1, scaledX));
            scaledY = Math.Max(0, Math.Min(SwitchPanelHeight - 1, scaledY));

            return new(scaledX, scaledY);
        }

        static int GCD(int a, int b)
        {
            while (b != 0)
            {
                int temp = b;
                b = a % b;
                a = temp;
            }
            return a;
        }

        static (int arW, int arH) GetAspectRatioInts(int width, int height)
        {
            int gcd = GCD(width, height);
            return (width / gcd, height / gcd);
        }

        /// <summary>
        /// Get the position of a mouse on screen relative to the app's view
        /// </summary>
        /// <param name="mousePosition">The position of the mouse in the client</param>
        /// <param name="clientSize">The size of the client</param>
        /// <param name="aspectRatio">The aspect ratio of the view</param>
        /// <returns>A snaphost of the state of the mouse.</returns>
        public static Vector2 GetScreenPosition(Vector2 mousePosition, Size clientSize)
        {
            var (arw, arH) = GetAspectRatioInts(clientSize.Width, clientSize.Height);

            float aspectRatio = arw / arH;
            float mouseX = mousePosition.X;
            float mouseY = mousePosition.Y;

            float aspectWidth = SwitchPanelHeight * aspectRatio;

            int screenWidth = clientSize.Width;
            int screenHeight = clientSize.Height;

            if (clientSize.Width > clientSize.Height * aspectWidth / SwitchPanelHeight)
            {
                screenWidth = (int)(clientSize.Height * aspectWidth) / SwitchPanelHeight;
            }
            else
            {
                screenHeight = (clientSize.Width * SwitchPanelHeight) / (int)aspectWidth;
            }

            int startX = (clientSize.Width - screenWidth) >> 1;
            int startY = (clientSize.Height - screenHeight) >> 1;

            int endX = startX + screenWidth;
            int endY = startY + screenHeight;

            if (mouseX >= startX &&
                mouseY >= startY &&
                mouseX < endX &&
                mouseY < endY)
            {
                int screenMouseX = (int)mouseX - startX;
                int screenMouseY = (int)mouseY - startY;

                mouseX = (screenMouseX * (int)aspectWidth) / screenWidth;
                mouseY = (screenMouseY * SwitchPanelHeight) / screenHeight;

                return new Vector2(mouseX, mouseY);
            }

            return new Vector2();
        }
    }
}
