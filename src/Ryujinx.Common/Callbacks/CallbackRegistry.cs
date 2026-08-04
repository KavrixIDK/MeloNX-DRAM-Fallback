using System;
using System.Collections.Concurrent;
using System.Runtime.InteropServices;

namespace Ryujinx.Common.Callbacks
{
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    public delegate void SwiftDataCallback(ref CallbackData data, nint userData);

    [StructLayout(LayoutKind.Sequential)]
    public struct CallbackData
    {
        public nint Ptr;
        public int  Len;

        public static CallbackData Empty => new() { Ptr = nint.Zero, Len = 0 };
    }

    public static class CallbackRegistry
    {
        private record Entry(SwiftDataCallback Callback, nint UserData);

        private static readonly ConcurrentDictionary<string, Entry> _callbacks = new();

        private static readonly ConcurrentDictionary<string, Action<byte[]>> _managedCallbacks = new();

        public static void RegisterCallback(nint namePtr, nint callbackPtr, nint userData)
        {
            var name = Marshal.PtrToStringUTF8(namePtr);
            if (name is null) return;

            var cb = Marshal.GetDelegateForFunctionPointer<SwiftDataCallback>(callbackPtr);
            _callbacks[name] = new Entry(cb, userData);
        }

        public static void UnregisterCallback(nint namePtr)
        {
            var name = Marshal.PtrToStringUTF8(namePtr);
            if (name is null) return;
            _callbacks.TryRemove(name, out _);
        }

        public static void RegisterManagedCallback(string name, Action<byte[]> cb)
            => _managedCallbacks[name] = cb;

        public static void UnregisterManagedCallback(string name)
            => _managedCallbacks.TryRemove(name, out _);

        public static bool Invoke(string name, ReadOnlySpan<byte> bytes)
        {
            if (_callbacks.TryGetValue(name, out var entry))
            {
                if (bytes.IsEmpty)
                {
                    var empty = CallbackData.Empty;
                    entry.Callback(ref empty, entry.UserData);
                    return true;
                }

                var arr = bytes.ToArray();
                var handle = GCHandle.Alloc(arr, GCHandleType.Pinned);
                try
                {
                    var cd = new CallbackData { Ptr = handle.AddrOfPinnedObject(), Len = arr.Length };
                    entry.Callback(ref cd, entry.UserData);
                }
                finally { handle.Free(); }

                return true;
            }

            if (_managedCallbacks.TryGetValue(name, out var managed))
            {
                managed(bytes.IsEmpty ? Array.Empty<byte>() : bytes.ToArray());
                return true;
            }

            return false;
        }

        public static bool Invoke(string name)
        {
            if (_callbacks.TryGetValue(name, out var entry))
            {
                var empty = CallbackData.Empty;
                entry.Callback(ref empty, entry.UserData);
                return true;
            }

            if (_managedCallbacks.TryGetValue(name, out var managed))
            {
                managed(Array.Empty<byte>());
                return true;
            }

            return false;
        }

        public static unsafe bool Invoke<T>(string name, T value) where T : unmanaged
        {
            var span = new ReadOnlySpan<byte>(&value, sizeof(T));
            return Invoke(name, span);
        }

        public static unsafe bool Invoke(string name, byte* ptr, int len)
        {
            if (_callbacks.TryGetValue(name, out var entry))
            {
                var cd = new CallbackData { Ptr = (nint)ptr, Len = len };
                entry.Callback(ref cd, entry.UserData);
                return true;
            }

            if (_managedCallbacks.TryGetValue(name, out var managed))
            {
                if (ptr == null || len == 0)
                {
                    managed(Array.Empty<byte>());
                }
                else
                {
                    var arr = new byte[len];
                    Marshal.Copy((nint)ptr, arr, 0, len);
                    managed(arr);
                }

                return true;
            }

            return false;
        }

        public static bool Invoke(string name, nint ptr, int len)
        {
            if (_callbacks.TryGetValue(name, out var entry))
            {
                var cd = new CallbackData { Ptr = ptr, Len = len };
                entry.Callback(ref cd, entry.UserData);
                return true;
            }

            if (_managedCallbacks.TryGetValue(name, out var managed))
            {
                if (ptr == nint.Zero || len == 0)
                {
                    managed(Array.Empty<byte>());
                }
                else
                {
                    var arr = new byte[len];
                    Marshal.Copy(ptr, arr, 0, len);
                    managed(arr);
                }

                return true;
            }

            return false;
        }

        public static void InvokeManaged(string name, ReadOnlySpan<byte> data)
        {
            if (_managedCallbacks.TryGetValue(name, out var cb))
                cb(data.ToArray());
        }

        public static byte InvokeCallback(nint namePtr, nint dataPtr, int dataLen)
        {
            var name = Marshal.PtrToStringUTF8(namePtr);
            if (name is null) return 0;

            if (dataPtr == nint.Zero || dataLen == 0)
                return Invoke(name) ? (byte)1 : (byte)0;

            unsafe
            {
                return Invoke(name, (byte*)dataPtr, dataLen) ? (byte)1 : (byte)0;
            }
        }
    }
}