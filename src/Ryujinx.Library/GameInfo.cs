#nullable enable
using LibHac.Common;
using LibHac.Fs;
using LibHac.Fs.Fsa;
using LibHac.FsSystem;
using LibHac.Ns;
using LibHac.Tools.Fs;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using Ryujinx.Common.Logging;
using Ryujinx.HLE.FileSystem;
using Ryujinx.HLE.HOS.SystemState;
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using Ryujinx.Common.Configuration;
using Ryujinx.Common.Utilities;
using System.Globalization;
using Path = System.IO.Path;
using Ryujinx.Library.SystemNative;
using MissingKeyException = LibHac.Common.Keys.MissingKeyException;

namespace Ryujinx.Library
{
    public class GameInfo
    {
        public double FileSize;
        public string? TitleName;
        public string? TitleId;
        public string? Developer;
        public string? Version;
        public byte[]? Icon;
    }

    public unsafe struct GameInfoNative
    {
        public ulong FileSize;
        public fixed byte TitleName[512];
        public fixed byte TitleId[32];
        public fixed byte Developer[256];
        public fixed byte Version[16];
        public byte* ImageData;
        public uint ImageSize;

        public GameInfoNative(ulong fileSize, string titleName, string titleId, string developer, string version, byte[] imageData)
        {
            FileSize = fileSize;

            fixed (byte* titleNamePtr = TitleName)
            fixed (byte* titleIdPtr = TitleId)
            fixed (byte* developerPtr = Developer)
            fixed (byte* versionPtr = Version)
            {
                CopyStringToFixedArray(titleName, titleNamePtr, 512);
                CopyStringToFixedArray(titleId, titleIdPtr, 32);
                CopyStringToFixedArray(developer, developerPtr, 256);
                CopyStringToFixedArray(version, versionPtr, 16);
            }

            if (imageData == null || imageData.Length > 4096 * 4096)
            {
                ImageSize = 0;
                ImageData = null;
            }
            else
            {
                ImageSize = (uint)imageData.Length;
                ImageData = (byte*)Marshal.AllocHGlobal(imageData.Length);
                Marshal.Copy(imageData, 0, (IntPtr)ImageData, imageData.Length);
            }
        }

        public void Dispose()
        {
            if (ImageData != null)
            {
                Marshal.FreeHGlobal((IntPtr)ImageData);
                ImageData = null;
            }
        }

        private static unsafe void CopyStringToFixedArray(string source, byte* destination, int length)
        {
            var span = new Span<byte>(destination, length);
            span.Clear();
            Encoding.UTF8.GetBytes(source, span);
        }
    }

    public static class GameInfoLoader
    {
        public static unsafe void CopyStringToFixedArray(string source, byte* destination, int length)
        {
            var span = new Span<byte>(destination, length);
            span.Clear();
            Encoding.UTF8.GetBytes(source, span);
        }

        private static readonly TitleUpdateMetadataJsonSerializerContext _titleSerializerContext =
            new(JsonHelper.GetDefaultSerializerOptions());

        private const Language TitleLanguage = Language.AmericanEnglish;

        [UnmanagedCallersOnly(EntryPoint = "free_game_info")]
        public static unsafe void FreeGameInfo(GameInfoNative* gameInfoPtr)
        {
            if (gameInfoPtr == null)
                return;
                
            if (gameInfoPtr->ImageData != null)
            {
                Marshal.FreeHGlobal((IntPtr)gameInfoPtr->ImageData);
                gameInfoPtr->ImageData = null;
            }
            gameInfoPtr->ImageSize = 0;
        }

        public static GameInfoNative GetGameInfoNative(VirtualFileSystem virtualFileSystem, Stream gameStream, string extension)
        {
            var gameInfo = GetGameInfo(virtualFileSystem, gameStream, extension);

            if (gameInfo == null)
                return new GameInfoNative(0, "", "", "", "", Array.Empty<byte>());

            return new GameInfoNative(
                (ulong)gameInfo.FileSize,
                gameInfo.TitleName + "\0",
                gameInfo.TitleId + "\0",
                gameInfo.Developer + "\0",
                gameInfo.Version + "\0",
                gameInfo.Icon
            );
        }

        public static GameInfo? GetGameInfo(VirtualFileSystem virtualFileSystem, Stream gameStream, string extension)
        {
            var gameInfo = new GameInfo
            {
                FileSize = gameStream.CanSeek ? gameStream.Length * 0.000000000931 : 0,
                TitleName = "Unknown",
                TitleId = "0000000000000000",
                Developer = "Unknown",
                Version = "0",
                Icon = null
            };

            BlitStruct<ApplicationControlProperty> controlHolder = new(1);

            try
            {
                try
                {
                    if (extension == "nsp" || extension == "pfs0" || extension == "xci")
                    {
                        IFileSystem pfs;
                        bool isExeFs = false;

                        if (extension == "xci")
                        {
                            Xci xci = new(virtualFileSystem.KeySet, gameStream.AsStorage());
                            pfs = xci.OpenPartition(XciPartitionType.Secure);
                        }
                        else
                        {
                            var pfsTemp = new PartitionFileSystem();
                            pfsTemp.Initialize(gameStream.AsStorage()).ThrowIfFailure();
                            pfs = pfsTemp;

                            bool hasMainNca = false;

                            foreach (DirectoryEntryEx fileEntry in pfs.EnumerateEntries("/", "*"))
                            {
                                if (Path.GetExtension(fileEntry.FullPath).ToLower() == ".nca")
                                {
                                    using UniqueRef<IFile> ncaFile = new();
                                    pfs.OpenFile(ref ncaFile.Ref, fileEntry.FullPath.ToU8Span(), OpenMode.Read).ThrowIfFailure();

                                    Nca nca = new(virtualFileSystem.KeySet, ncaFile.Get.AsStorage());
                                    int dataIndex = Nca.GetSectionIndexFromType(NcaSectionType.Data, NcaContentType.Program);

                                    if (nca.Header.ContentType == NcaContentType.Program &&
                                        !(nca.SectionExists(NcaSectionType.Data) && nca.Header.GetFsHeader(dataIndex).IsPatchSection()))
                                    {
                                        hasMainNca = true;
                                        break;
                                    }
                                }
                                else if (Path.GetFileNameWithoutExtension(fileEntry.FullPath) == "main")
                                {
                                    isExeFs = true;
                                }
                            }

                            if (!hasMainNca && !isExeFs)
                                return null;
                        }

                        if (isExeFs)
                        {
                            using UniqueRef<IFile> npdmFile = new();
                            LibHac.Result result = pfs.OpenFile(ref npdmFile.Ref, "/main.npdm".ToU8Span(), OpenMode.Read);

                            // Fix: original had inverted logic — only read npdm when PathNotFound is NOT the result
                            if (!LibHac.Fs.ResultFs.PathNotFound.Includes(result))
                            {
                                Ryujinx.HLE.Loaders.Npdm.Npdm npdm = new(npdmFile.Get.AsStream());
                                gameInfo.TitleName = npdm.TitleName;
                                gameInfo.TitleId = npdm.Aci0.TitleId.ToString("x16");
                            }
                        }
                        else
                        {
                            GetControlFsAndTitleId(virtualFileSystem, pfs, out IFileSystem? controlFs, out string? id);
                            gameInfo.TitleId = id;

                            if (controlFs == null)
                            {
                                Logger.Error?.Print(LogClass.Application, $"No control FS was returned. Unable to process game any further: {gameInfo.TitleName}");
                                return null;
                            }

                            if (IsUpdateApplied(virtualFileSystem, gameInfo.TitleId, out IFileSystem? updatedControlFs))
                                controlFs = updatedControlFs;

                            ReadControlData(controlFs, controlHolder.ByteSpan);
                            GetGameInformation(ref controlHolder.Value, out gameInfo.TitleName, out gameInfo.TitleId, out gameInfo.Developer, out gameInfo.Version);

                            try
                            {
                                using UniqueRef<IFile> icon = new();
                                controlFs?.OpenFile(ref icon.Ref, $"/icon_{TitleLanguage}.dat".ToU8Span(), OpenMode.Read).ThrowIfFailure();

                                using MemoryStream stream = new();
                                icon.Get.AsStream().CopyTo(stream);
                                gameInfo.Icon = stream.ToArray();
                            }
                            catch (HorizonResultException)
                            {
                                foreach (DirectoryEntryEx entry in controlFs.EnumerateEntries("/", "*"))
                                {
                                    if (entry.Name == "control.nacp" || entry.Type == DirectoryEntryType.Directory)
                                        continue;

                                    using var icon = new UniqueRef<IFile>();
                                    controlFs?.OpenFile(ref icon.Ref, entry.FullPath.ToU8Span(), OpenMode.Read).ThrowIfFailure();

                                    using MemoryStream stream = new();
                                    icon.Get.AsStream().CopyTo(stream);
                                    gameInfo.Icon = stream.ToArray();

                                    if (gameInfo.Icon != null)
                                        break;
                                }
                            }
                        }
                    }
                    else if (extension == "nro")
                    {
                        BinaryReader reader = new(gameStream);

                        byte[] Read(long position, int size)
                        {
                            gameStream.Seek(position, SeekOrigin.Begin);
                            return reader.ReadBytes(size);
                        }

                        gameStream.Seek(24, SeekOrigin.Begin);
                        int assetOffset = reader.ReadInt32();

                        if (Encoding.ASCII.GetString(Read(assetOffset, 4)) == "ASET")
                        {
                            byte[] iconSectionInfo = Read(assetOffset + 8, 0x10);
                            long iconOffset = BitConverter.ToInt64(iconSectionInfo, 0);
                            long iconSize = BitConverter.ToInt64(iconSectionInfo, 8);
                            ulong nacpOffset = reader.ReadUInt64();
                            ulong nacpSize = reader.ReadUInt64();

                            if (iconSize > 0)
                                gameInfo.Icon = Read(assetOffset + iconOffset, (int)iconSize);

                            Read(assetOffset + (int)nacpOffset, (int)nacpSize).AsSpan().CopyTo(controlHolder.ByteSpan);
                            GetGameInformation(ref controlHolder.Value, out gameInfo.TitleName, out gameInfo.TitleId, out gameInfo.Developer, out gameInfo.Version);
                        }
                    }
                }
                catch (MissingKeyException exception)
                {
                    Logger.Warning?.Print(LogClass.Application, $"Your key set is missing a key with the name: {exception.Name}");
                }
                catch (InvalidDataException exception)
                {
                    Logger.Warning?.Print(LogClass.Application, $"The header key is incorrect or missing and therefore the NCA header content type check has failed. {exception}");
                }
                catch (Exception exception)
                {
                    Logger.Warning?.Print(LogClass.Application, $"The gameStream encountered was not of a valid type. Error: {exception}");
                    return null;
                }
            }
            catch (IOException exception)
            {
                Logger.Warning?.Print(LogClass.Application, exception.Message);
            }

            return gameInfo;
        }

        private static void ReadControlData(IFileSystem? controlFs, Span<byte> outProperty)
        {
            using UniqueRef<IFile> controlFile = new();
            controlFs?.OpenFile(ref controlFile.Ref, "/control.nacp".ToU8Span(), OpenMode.Read).ThrowIfFailure();
            controlFile.Get.Read(out _, 0, outProperty, ReadOption.None).ThrowIfFailure();
        }

        private static void GetGameInformation(
            ref ApplicationControlProperty controlData,
            out string? titleName,
            out string titleId,
            out string? publisher,
            out string? version)
        {
            _ = Enum.TryParse(TitleLanguage.ToString(), out TitleLanguage desiredTitleLanguage);

            // Fix: use out parameters directly instead of non-existent 'data' object
            if (controlData.Title.Length > (int)desiredTitleLanguage)
            {
                titleName = controlData.Title[(int)desiredTitleLanguage].NameString.ToString();
                publisher = controlData.Title[(int)desiredTitleLanguage].PublisherString.ToString();
            }
            else
            {
                titleName = null;
                publisher = null;
            }

            if (string.IsNullOrWhiteSpace(titleName))
            {
                foreach (ApplicationControlProperty.ApplicationTitle controlTitle in controlData.Title)
                {
                    if (!controlTitle.NameString.IsEmpty())
                    {
                        titleName = controlTitle.NameString.ToString();
                        break;
                    }
                }
            }

            if (string.IsNullOrWhiteSpace(publisher))
            {
                foreach (ApplicationControlProperty.ApplicationTitle controlTitle in controlData.Title)
                {
                    if (!controlTitle.PublisherString.IsEmpty())
                    {
                        publisher = controlTitle.PublisherString.ToString();
                        break;
                    }
                }
            }

            if (controlData.PresenceGroupId != 0)
                titleId = controlData.PresenceGroupId.ToString("x16");
            else if (controlData.SaveDataOwnerId != 0)
                titleId = controlData.SaveDataOwnerId.ToString();
            else if (controlData.AddOnContentBaseId != 0)
                titleId = (controlData.AddOnContentBaseId - 0x1000).ToString("x16");
            else
                titleId = "0000000000000000";

            version = controlData.DisplayVersionString.ToString();
        }

        private static void GetControlFsAndTitleId(VirtualFileSystem virtualFileSystem, IFileSystem pfs, out IFileSystem? controlFs, out string? titleId)
        {
            (_, _, Nca? controlNca) = GetGameData(virtualFileSystem, pfs, 0);

            if (controlNca == null)
                Logger.Warning?.Print(LogClass.Application, "Control NCA is null. Unable to load control FS.");

            controlFs = controlNca?.OpenFileSystem(NcaSectionType.Data, IntegrityCheckLevel.None);
            titleId = controlNca?.Header.TitleId.ToString("x16");
        }

        private static (Nca? mainNca, Nca? patchNca, Nca? controlNca) GetGameData(VirtualFileSystem fileSystem, IFileSystem pfs, int programIndex)
        {
            Nca? mainNca = null;
            Nca? patchNca = null;
            Nca? controlNca = null;

            fileSystem.ImportTickets(pfs);

            foreach (DirectoryEntryEx fileEntry in pfs.EnumerateEntries("/", "*.nca"))
            {
                using var ncaFile = new UniqueRef<IFile>();
                pfs.OpenFile(ref ncaFile.Ref, fileEntry.FullPath.ToU8Span(), OpenMode.Read).ThrowIfFailure();

                Nca nca = new(fileSystem.KeySet, ncaFile.Release().AsStorage());
                int ncaProgramIndex = (int)(nca.Header.TitleId & 0xF);

                if (ncaProgramIndex != programIndex)
                    continue;

                if (nca.Header.ContentType == NcaContentType.Program)
                {
                    int dataIndex = Nca.GetSectionIndexFromType(NcaSectionType.Data, NcaContentType.Program);
                    if (nca.SectionExists(NcaSectionType.Data) && nca.Header.GetFsHeader(dataIndex).IsPatchSection())
                        patchNca = nca;
                    else
                        mainNca = nca;
                }
                else if (nca.Header.ContentType == NcaContentType.Control)
                {
                    controlNca = nca;
                }
            }

            return (mainNca, patchNca, controlNca);
        }

        private static bool IsUpdateApplied(VirtualFileSystem virtualFileSystem, string? titleId, out IFileSystem? updatedControlFs)
        {
            updatedControlFs = null;
            string? updatePath = "(unknown)";

            try
            {
                (Nca? patchNca, Nca? controlNca) = GetGameUpdateData(virtualFileSystem, titleId, 0, out updatePath);

                if (patchNca != null && controlNca != null)
                {
                    updatedControlFs = controlNca.OpenFileSystem(NcaSectionType.Data, IntegrityCheckLevel.None);
                    return true;
                }
            }
            catch (InvalidDataException)
            {
                Logger.Warning?.Print(LogClass.Application, $"The header key is incorrect or missing and therefore the NCA header content type check has failed. Errored File: {updatePath}");
            }
            catch (MissingKeyException exception)
            {
                Logger.Warning?.Print(LogClass.Application, $"Your key set is missing a key with the name: {exception.Name}. Errored File: {updatePath}");
            }

            return false;
        }

        private static (Nca? patch, Nca? control) GetGameUpdateData(VirtualFileSystem fileSystem, string? titleId, int programIndex, out string? updatePath)
        {
            updatePath = "";

            if (ulong.TryParse(titleId, NumberStyles.HexNumber, CultureInfo.InvariantCulture, out ulong titleIdBase))
            {
                titleIdBase &= ~0xFUL;

                string titleUpdateMetadataPath = Path.Combine(AppDataManager.GamesDirPath, titleIdBase.ToString("x16"), "updates.json");

                if (File.Exists(titleUpdateMetadataPath))
                {
                    updatePath = JsonHelper.DeserializeFromFile(titleUpdateMetadataPath, _titleSerializerContext.TitleUpdateMetadata).Selected;
                    if (OperatingSystem.IsIOS())
                        updatePath = Path.Combine(AppDataManager.BaseDirPath, updatePath);

                    if (File.Exists(updatePath))
                    {
                        FileStream file = new(updatePath, FileMode.Open, FileAccess.Read);
                        PartitionFileSystem nsp = new();
                        nsp.Initialize(file.AsStorage()).ThrowIfFailure();

                        return GetGameUpdateDataFromPartition(fileSystem, nsp, titleIdBase.ToString("x16"), programIndex);
                    }
                }
            }

            return (null, null);
        }

        private static (Nca? patchNca, Nca? controlNca) GetGameUpdateDataFromPartition(VirtualFileSystem fileSystem, PartitionFileSystem pfs, string titleId, int programIndex)
        {
            Nca? patchNca = null;
            Nca? controlNca = null;

            fileSystem.ImportTickets(pfs);

            foreach (DirectoryEntryEx fileEntry in pfs.EnumerateEntries("/", "*.nca"))
            {
                using var ncaFile = new UniqueRef<IFile>();
                pfs.OpenFile(ref ncaFile.Ref, fileEntry.FullPath.ToU8Span(), OpenMode.Read).ThrowIfFailure();

                Nca nca = new(fileSystem.KeySet, ncaFile.Release().AsStorage());
                int ncaProgramIndex = (int)(nca.Header.TitleId & 0xF);

                if (ncaProgramIndex != programIndex)
                    continue;

                if ($"{nca.Header.TitleId.ToString("x16")[..^3]}000" != titleId)
                    break;

                if (nca.Header.ContentType == NcaContentType.Program)
                    patchNca = nca;
                else if (nca.Header.ContentType == NcaContentType.Control)
                    controlNca = nca;
            }

            return (patchNca, controlNca);
        }
    }
}
