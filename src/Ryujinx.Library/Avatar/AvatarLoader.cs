using LibHac.Common;
using LibHac.Fs;
using LibHac.Fs.Fsa;
using LibHac.FsSystem;
using LibHac.Ncm;
using LibHac.Tools.FsSystem.NcaUtils;
using LibHac.Tools.FsSystem;
using Ryujinx.Common.Memory;
using System;
using System.Collections.Generic;
using System.IO;
using System.Buffers.Binary;
using System.Runtime.InteropServices;
using Ryujinx.HLE.FileSystem;

namespace Ryujinx.Library
{
    public static class AvatarLoader
    {
        public static Dictionary<string, byte[]> LoadAvatars(ContentManager contentManager, VirtualFileSystem virtualFileSystem)
        {
            var avatarDict = new Dictionary<string, byte[]>();

            string contentPath = contentManager.GetInstalledContentPath(0x010000000000080A, StorageId.BuiltInSystem, NcaContentType.Data);
            string avatarPath = VirtualFileSystem.SwitchPathToSystemPath(contentPath);

            if (string.IsNullOrWhiteSpace(avatarPath))
            {
                throw new Exception("Avatar content path not found.");
            }

            using IStorage ncaFileStream = new LocalStorage(avatarPath, FileAccess.Read, FileMode.Open);
            
            Nca nca = new(virtualFileSystem.KeySet, ncaFileStream);
            IFileSystem romfs = nca.OpenFileSystem(NcaSectionType.Data, IntegrityCheckLevel.ErrorOnInvalid);

            foreach (var item in romfs.EnumerateEntries())
            {
                if (item.Type == DirectoryEntryType.File && item.FullPath.Contains("chara") && item.FullPath.Contains("szs"))
                {
                    using var file = new UniqueRef<IFile>();
                    romfs.OpenFile(ref file.Ref, ("/" + item.FullPath).ToU8Span(), OpenMode.Read).ThrowIfFailure();

                    using MemoryStream compressedStream = MemoryStreamManager.Shared.GetStream();
                    file.Get.AsStream().CopyTo(compressedStream);
                    compressedStream.Position = 0;

                    byte[] decompressedData = DecompressYaz0(compressedStream);

                    avatarDict.Add(item.FullPath, decompressedData);
                }
            }

            return avatarDict;
        }

        private static byte[] DecompressYaz0(Stream stream)
        {
            using var reader = new BinaryReader(stream);

            reader.ReadInt32();
            uint decodedLength = BinaryPrimitives.ReverseEndianness(reader.ReadUInt32());
            reader.ReadInt64();

            byte[] input = new byte[stream.Length - stream.Position];
            stream.ReadExactly(input, 0, input.Length);

            long inputOffset = 0;
            byte[] output = new byte[decodedLength];
            long outputOffset = 0;

            ushort mask = 0;
            byte header = 0;

            while (outputOffset < decodedLength)
            {
                if ((mask >>= 1) == 0)
                {
                    header = input[inputOffset++];
                    mask = 0x80;
                }

                if ((header & mask) > 0)
                {
                    if (outputOffset == output.Length)
                        break;
                    output[outputOffset++] = input[inputOffset++];
                }
                else
                {
                    byte byte1 = input[inputOffset++];
                    byte byte2 = input[inputOffset++];

                    int dist = ((byte1 & 0xF) << 8) | byte2;
                    int position = (int)outputOffset - (dist + 1);

                    int length = byte1 >> 4;
                    if (length == 0)
                    {
                        length = input[inputOffset++] + 0x12;
                    }
                    else
                    {
                        length += 2;
                    }

                    while (length-- > 0)
                    {
                        output[outputOffset++] = output[position++];
                    }
                }
            }

            return output;
        }
    }
}
