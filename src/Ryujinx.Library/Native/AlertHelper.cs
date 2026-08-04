using System;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Ryujinx.Common.Callbacks;
using Ryujinx.Common;

namespace Ryujinx.Library
{
    [JsonSerializable(typeof(AlertHelper.TextInputRequest))]
    [JsonSerializable(typeof(AlertHelper.AlertRequest))]
    internal partial class AlertJsonContext : JsonSerializerContext
    {
    }
    
    public static class AlertHelper
    {
        public static void ShowAlertWithTextInput(
            string title,
            string message,
            string placeholder,
            Action<string?>? onTextEntered)
        {
            var callbackId = Guid.NewGuid().ToString("N");
            var resultCallback = $"show_text_input_result_{callbackId}";

            CallbackRegistry.RegisterManagedCallback(resultCallback, data =>
            {
                CallbackRegistry.UnregisterManagedCallback(resultCallback);

                string? result = data.Length > 0 ? Encoding.UTF8.GetString(data) : null;
                onTextEntered?.Invoke(result);
            });

            var request = new TextInputRequest
            {
                Title = title,
                Message = message,
                Placeholder = placeholder,
                CallbackId = callbackId
            };

            byte[] bytes = JsonSerializer.SerializeToUtf8Bytes(
                request,
                AlertJsonContext.Default.TextInputRequest
            );

            if (!CallbackRegistry.Invoke("show_text_input", bytes))
            {
                CallbackRegistry.UnregisterManagedCallback(resultCallback);
            }
        }

        public static void ShowAlert(string title, string message, bool cancel)
        {
            var request = new AlertRequest
            {
                Title = title,
                Message = message,
                Cancel = cancel
            };

            byte[] bytes = JsonSerializer.SerializeToUtf8Bytes(
                request,
                AlertJsonContext.Default.AlertRequest
            );

            CallbackRegistry.Invoke("show_alert", bytes);
        }
        
        internal sealed class TextInputRequest
        {
            public string Title { get; set; } = "";
            public string Message { get; set; } = "";
            public string Placeholder { get; set; } = "";
            public string CallbackId { get; set; } = "";
        }

        internal sealed class AlertRequest
        {
            public string Title { get; set; } = "";
            public string Message { get; set; } = "";
            public bool Cancel { get; set; }
        }
    }
}