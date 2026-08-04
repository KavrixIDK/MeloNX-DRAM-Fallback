using LibHac.Common;
using LibHac.Common.Keys;
using LibHac.Fs;
using LibHac.Fs.Fsa;
using LibHac.FsSystem;
using LibHac.Ncm;
using LibHac.Tools.Fs;
using LibHac.Tools.FsSystem;
using LibHac.Tools.FsSystem.NcaUtils;
using LibHac.Tools.Ncm;
using Ryujinx.Common.Configuration;
using Ryujinx.Common.Logging;
using Ryujinx.Common.Utilities;
using Ryujinx.HLE.FileSystem;
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using ContentType = LibHac.Ncm.ContentType;

namespace Ryujinx.HLE.Loaders.Processes.Extensions
{
    public static class PartitionFileSystemExtensions
    {
        private static readonly DownloadableContentJsonSerializerContext _contentSerializerContext = new(JsonHelper.GetDefaultSerializerOptions());

        public static Dictionary<ulong, ContentMetaData> GetContentData(this IFileSystem partitionFileSystem,
            ContentMetaType contentType, VirtualFileSystem fileSystem, IntegrityCheckLevel checkLevel)
        {
            fileSystem.ImportTickets(partitionFileSystem);

            Dictionary<ulong, ContentMetaData> programs = new();

            foreach (DirectoryEntryEx fileEntry in partitionFileSystem.EnumerateEntries("/", "*.cnmt.nca"))
            {
                Cnmt cnmt = partitionFileSystem.GetNca(fileSystem.KeySet, fileEntry.FullPath).GetCnmt(checkLevel, contentType);

                if (cnmt == null)
                {
                    continue;
                }

                ContentMetaData content = new(partitionFileSystem, cnmt);

                if (content.Type != contentType)
                {
                    continue;
                }

                programs.TryAdd(content.ApplicationId, content);
            }

            return programs;
        }

        internal static (bool, ProcessResult) TryLoad<TMetaData, TFormat, THeader, TEntry>(this PartitionFileSystemCore<TMetaData, TFormat, THeader, TEntry> partitionFileSystem, Switch device, string path, ulong applicationId, out string errorMessage)
            where TMetaData : PartitionFileSystemMetaCore<TFormat, THeader, TEntry>, new()
            where TFormat : IPartitionFileSystemFormat
            where THeader : unmanaged, IPartitionFileSystemHeader
            where TEntry : unmanaged, IPartitionFileSystemEntry
        {
            errorMessage = null;

            // Load required NCAs.
            Nca mainNca = null;
            Nca patchNca = null;
            Nca controlNca = null;

            try
            {
                Dictionary<ulong, ContentMetaData> applications = partitionFileSystem.GetContentData(ContentMetaType.Application, device.FileSystem, device.System.FsIntegrityCheckLevel);

                if (applicationId == 0)
                {
                    foreach ((ulong _, ContentMetaData content) in applications)
                    {
                        mainNca = content.GetNcaByType(device.FileSystem.KeySet, ContentType.Program, device.Configuration.UserChannelPersistence.Index);
                        controlNca = content.GetNcaByType(device.FileSystem.KeySet, ContentType.Control, device.Configuration.UserChannelPersistence.Index);
                        break;
                    }
                }
                else if (applications.TryGetValue(applicationId, out ContentMetaData content))
                {
                    mainNca = content.GetNcaByType(device.FileSystem.KeySet, ContentType.Program, device.Configuration.UserChannelPersistence.Index);
                    controlNca = content.GetNcaByType(device.FileSystem.KeySet, ContentType.Control, device.Configuration.UserChannelPersistence.Index);
                }

                ProcessLoaderHelper.RegisterProgramMapInfo(device, partitionFileSystem).ThrowIfFailure();
            }
            catch (Exception ex)
            {
                errorMessage = $"Unable to load: {ex.Message}";

                return (false, ProcessResult.Failed);
            }

            if (mainNca != null)
            {
                if (mainNca.Header.ContentType != NcaContentType.Program)
                {
                    errorMessage = "Selected NCA file is not a \"Program\" NCA";

                    return (false, ProcessResult.Failed);
                }

                (Nca updatePatchNca, Nca updateControlNca) = mainNca.GetUpdateData(device.FileSystem, device.System.FsIntegrityCheckLevel, device.Configuration.UserChannelPersistence.Index, out string updatePath);

                if (updatePatchNca != null)
                {
                    patchNca = updatePatchNca;
                    if (updatePath != null) 
                        Logger.Notice.PrintMsg(LogClass.Application, $"Loading update NCA from '{updatePath}'.");
                }
                else if (TryGetBundledUpdateData(partitionFileSystem, device, mainNca.ProgramIdBase, out Nca bundledPatchNca, out Nca bundledControlNca))
                {
                    patchNca = bundledPatchNca;
                    updateControlNca = bundledControlNca;

                    Logger.Notice.PrintMsg(LogClass.Application, $"Loading bundled update NCA from '{path}'.");
                }

                if (updateControlNca != null)
                {
                    controlNca = updateControlNca;
                }

                // TODO: If we want to support multi-processes in future, we shouldn't clear AddOnContent data here.
                device.Configuration.ContentManager.ClearAocData();

                // Load DownloadableContents.
                string addOnContentMetadataPath = System.IO.Path.Combine(AppDataManager.GamesDirPath, mainNca.ProgramIdBase.ToString("x16"), "dlc.json");
                if (File.Exists(addOnContentMetadataPath))
                {
                    List<DownloadableContentContainer> dlcContainerList = JsonHelper.DeserializeFromFile(addOnContentMetadataPath, _contentSerializerContext.ListDownloadableContentContainer);

                    foreach (DownloadableContentContainer downloadableContentContainer in dlcContainerList)
                    {
                        string containerPath = ResolveDlcContainerPath(downloadableContentContainer.ContainerPath);

                        if (!File.Exists(containerPath))
                        {
                            Logger.Warning?.Print(LogClass.Application, $"Cannot find AddOnContent file {downloadableContentContainer.ContainerPath}. It may have been moved or renamed.");
                            continue;
                        }

                        foreach (DownloadableContentNca downloadableContentNca in downloadableContentContainer.DownloadableContentNcaList)
                        {
                            if (downloadableContentNca.Enabled)
                            {
                                device.Configuration.ContentManager.AddAocItem(downloadableContentNca.TitleId, containerPath, downloadableContentNca.FullPath);
                            }
                        }
                    }
                }

                LoadBundledDownloadableContents(partitionFileSystem, device, path, mainNca.ProgramIdBase);

                return (true, mainNca.Load(device, patchNca, controlNca));
            }

            errorMessage = $"Unable to load: Could not find Main NCA for title \"{applicationId:X16}\"";

            return (false, ProcessResult.Failed);
        }

        private static bool TryGetBundledUpdateData<TMetaData, TFormat, THeader, TEntry>(
            PartitionFileSystemCore<TMetaData, TFormat, THeader, TEntry> partitionFileSystem,
            Switch device,
            ulong titleIdBase,
            out Nca patchNca,
            out Nca controlNca)
            where TMetaData : PartitionFileSystemMetaCore<TFormat, THeader, TEntry>, new()
            where TFormat : IPartitionFileSystemFormat
            where THeader : unmanaged, IPartitionFileSystemHeader
            where TEntry : unmanaged, IPartitionFileSystemEntry
        {
            patchNca = null;
            controlNca = null;

            ContentMetaData newestUpdate = null;

            foreach ((ulong applicationTitleId, ContentMetaData content) in partitionFileSystem.GetContentData(ContentMetaType.Patch, device.FileSystem, device.System.FsIntegrityCheckLevel))
            {
                if ((applicationTitleId & ~0x1FFFUL) != titleIdBase)
                {
                    continue;
                }

                if (newestUpdate == null || content.Version.Version > newestUpdate.Version.Version)
                {
                    newestUpdate = content;
                }
            }

            if (newestUpdate == null)
            {
                return false;
            }

            patchNca = newestUpdate.GetNcaByType(device.FileSystem.KeySet, ContentType.Program, device.Configuration.UserChannelPersistence.Index);
            controlNca = newestUpdate.GetNcaByType(device.FileSystem.KeySet, ContentType.Control, device.Configuration.UserChannelPersistence.Index);

            return patchNca != null;
        }

        private static void LoadBundledDownloadableContents<TMetaData, TFormat, THeader, TEntry>(
            PartitionFileSystemCore<TMetaData, TFormat, THeader, TEntry> partitionFileSystem,
            Switch device,
            string path,
            ulong titleIdBase)
            where TMetaData : PartitionFileSystemMetaCore<TFormat, THeader, TEntry>, new()
            where TFormat : IPartitionFileSystemFormat
            where THeader : unmanaged, IPartitionFileSystemHeader
            where TEntry : unmanaged, IPartitionFileSystemEntry
        {
            HashSet<ulong> loadedAocTitleIds = device.Configuration.ContentManager.GetAocTitleIds().ToHashSet();

            foreach (DirectoryEntryEx fileEntry in partitionFileSystem.EnumerateEntries("/", "*.nca"))
            {
                using UniqueRef<IFile> ncaFile = new();

                try
                {
                    partitionFileSystem.OpenFile(ref ncaFile.Ref, fileEntry.FullPath.ToU8Span(), OpenMode.Read).ThrowIfFailure();

                    Nca nca = new(device.FileSystem.KeySet, ncaFile.Get.AsStorage());

                    if (nca.Header.ContentType != NcaContentType.PublicData ||
                        (nca.Header.TitleId & ~0x1FFFUL) != titleIdBase ||
                        !loadedAocTitleIds.Add(nca.Header.TitleId))
                    {
                        continue;
                    }

                    device.Configuration.ContentManager.AddAocItem(nca.Header.TitleId, path, fileEntry.FullPath);
                }
                catch (Exception exception)
                {
                    Logger.Warning?.Print(LogClass.Application, $"Failed to load bundled AddOnContent '{fileEntry.FullPath}' from '{path}': {exception.Message}");
                }
            }
        }

        private static string ResolveDlcContainerPath(string containerPath)
        {
            if (string.IsNullOrWhiteSpace(containerPath) || File.Exists(containerPath) || System.IO.Path.IsPathRooted(containerPath))
            {
                return containerPath;
            }

            return System.IO.Path.Combine(AppDataManager.BaseDirPath, containerPath);
        }
    }
}
