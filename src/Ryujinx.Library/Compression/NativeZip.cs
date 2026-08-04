using System;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;

namespace Ryujinx.Library 
{
    public static unsafe class ZipNative
    {
        [ThreadStatic]
        private static string? _lastError;

        [UnmanagedCallersOnly(EntryPoint = "zip_extract")]
        public static int ExtractZip(byte* zipPathUtf8, byte* destPathUtf8, int overwrite)
        {
            try
            {
                string zipPath = PtrToString(zipPathUtf8);
                string destPath = PtrToString(destPathUtf8);

                if (!File.Exists(zipPath))
                {
                    _lastError = $"Zip file not found: {zipPath}";
                    return -1;
                }

                Directory.CreateDirectory(destPath);
                string destFull = Path.GetFullPath(destPath);

                using ZipArchive archive = ZipFile.OpenRead(zipPath);
                foreach (ZipArchiveEntry entry in archive.Entries)
                {
                    string entryDestPath = Path.GetFullPath(Path.Combine(destFull, entry.FullName));

                    if (!entryDestPath.StartsWith(destFull, StringComparison.Ordinal))
                    {
                        _lastError = $"Entry escapes destination directory: {entry.FullName}";
                        return -2;
                    }

                    if (string.IsNullOrEmpty(entry.Name))
                    {
                        Directory.CreateDirectory(entryDestPath);
                        continue;
                    }

                    Directory.CreateDirectory(Path.GetDirectoryName(entryDestPath)!);
                    entry.ExtractToFile(entryDestPath, overwrite != 0);
                }

                return 0;
            }
            catch (Exception ex)
            {
                _lastError = ex.Message;
                return -99;
            }
        }

        [UnmanagedCallersOnly(EntryPoint = "zip_entry_count")]
        public static int GetEntryCount(byte* zipPathUtf8)
        {
            try
            {
                string zipPath = PtrToString(zipPathUtf8);
                using ZipArchive archive = ZipFile.OpenRead(zipPath);
                return archive.Entries.Count;
            }
            catch (Exception ex)
            {
                _lastError = ex.Message;
                return -1;
            }
        }

        [UnmanagedCallersOnly(EntryPoint = "zip_get_last_error")]
        public static IntPtr GetLastError()
        {
            string msg = _lastError ?? "No error";
            return Marshal.StringToCoTaskMemUTF8(msg);
        }

        [UnmanagedCallersOnly(EntryPoint = "zip_free_string")]
        public static void FreeString(IntPtr ptr)
        {
            if (ptr != IntPtr.Zero)
                Marshal.FreeCoTaskMem(ptr);
        }

        private static string PtrToString(byte* ptr)
        {
            if (ptr == null) return string.Empty;
            return Marshal.PtrToStringUTF8((IntPtr)ptr) ?? string.Empty;
        }
    }
}