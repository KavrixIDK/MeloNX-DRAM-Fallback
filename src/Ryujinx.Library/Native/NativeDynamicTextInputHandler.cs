using Ryujinx.HLE.UI;
using System.Threading;
using System.Threading.Tasks;

namespace Ryujinx.Library
{
    /// <summary>
    /// iOS text processing class
    /// </summary>
    internal class NativeDynamicTextInputHandler : IDynamicTextInputHandler
    {
        private bool _canProcessInput;
        private string _pendingPlaceholder = "";

        public event DynamicTextChangedHandler TextChangedEvent;
        public event KeyPressedHandler KeyPressedEvent { add { } remove { } }
        public event KeyReleasedHandler KeyReleasedEvent { add { } remove { } }

        public bool TextProcessingEnabled
        {
            get => Volatile.Read(ref _canProcessInput);

            set
            {
                Volatile.Write(ref _canProcessInput, value);

                if (!value)
                    return;

                AlertHelper.ShowAlertWithTextInput(
                    title: "Text Input",
                    message: "",
                    placeholder: _pendingPlaceholder,
                    onTextEntered: result =>
                    {
                        if (!Volatile.Read(ref _canProcessInput))
                            return;

                        var text = result ?? "";
                        int cursor = text.Length;
                        TextChangedEvent?.Invoke(text, cursor, cursor, false);
                    }
                );
            }
        }

        public NativeDynamicTextInputHandler()
        {
            _canProcessInput = true;
        }

        public void SetText(string text, int cursorBegin)
        {
            _pendingPlaceholder = text ?? "";
        }

        public void SetText(string text, int cursorBegin, int cursorEnd)
        {
            _pendingPlaceholder = text ?? "";
        }
        
        public void Dispose() { }
    }
}
