using Ryujinx.Common.Configuration.Hid;
using Ryujinx.Common.Configuration.Hid.Controller;
using Ryujinx.Common.Callbacks;
using System.Collections.Generic;
using System;
using System.Numerics;
using System.Runtime.InteropServices;
using Ryujinx.Input;


namespace Ryujinx.Input.Native
{
    public unsafe struct LeftJoyconCommonConfigNative 
    {
        public Key DpadUp;
        public Key DpadDown;
        public Key DpadLeft;
        public Key DpadRight;
        public Key ButtonMinus;
        public Key ButtonL;
        public Key ButtonZl;
        public Key ButtonSl;
        public Key ButtonSr;
    }

    public unsafe struct JoyconConfigKeyboardStickNative 
    {
        public Key StickUp;
        public Key StickDown;
        public Key StickLeft;
        public Key StickRight;
        public Key StickButton;
    }

    public unsafe struct RightJoyconCommonConfigNative 
    {
        public Key ButtonA;
        public Key ButtonB;
        public Key ButtonX;
        public Key ButtonY;
        public Key ButtonPlus;
        public Key ButtonR;
        public Key ButtonZr;
        public Key ButtonSl;
        public Key ButtonSr;
    }


    public unsafe struct KeyboardConfigNative
    {
        public LeftJoyconCommonConfigNative LeftJoycon;
        public JoyconConfigKeyboardStickNative LeftJoyconStick;
        
        public RightJoyconCommonConfigNative RightJoycon;
        public JoyconConfigKeyboardStickNative RightJoyconStick;
    }
}