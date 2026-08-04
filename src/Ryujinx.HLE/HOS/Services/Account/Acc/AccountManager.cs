using LibHac;
using LibHac.Common;
using LibHac.Fs;
using LibHac.Fs.Shim;
using Ryujinx.Common;
using Ryujinx.Common.Logging;
using Ryujinx.Horizon.Sdk.Account;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;

namespace Ryujinx.HLE.HOS.Services.Account.Acc
{
    public class AccountManager : IEmulatorAccountManager
    {
        public static readonly UserId DefaultUserId = new("00000000000000010000000000000000");

        private AccountSaveDataManager _accountSaveDataManager;

        // Todo: The account service doesn't have the permissions to delete save data. Qlaunch takes care of deleting
        // save data, so we're currently passing a client with full permissions. Consider moving save data deletion
        // outside of the AccountManager.
        private readonly HorizonClient _horizonClient;

        private ConcurrentDictionary<string, UserProfile> _profiles;
        private UserProfile[] _storedOpenedUsers;

        public static readonly byte[] DefaultUserImage = Convert.FromBase64String("/9j/4Q/+RXhpZgAATU0AKgAAAAgACAESAAMAAAABAAEAAAEaAAUAAAABAAAAbgEbAAUAAAABAAAAdgEoAAMAAAABAAIAAAExAAIAAAAiAAAAfgEyAAIAAAAUAAAAoAITAAMAAAABAAEAAIdpAAQAAAABAAAAtAAAAAAAAABIAAAAAQAAAEgAAAABQWRvYmUgUGhvdG9zaG9wIENDIDIwMTggKFdpbmRvd3MpADIwMTg6MDk6MjEgMDY6MDY6MjQAAAeQAAAHAAAABDAyMjGRAQAHAAAABAECAwCgAAAHAAAABDAxMDCgAQADAAAAAf//AACgAgAEAAAAAQAAAQCgAwAEAAAAAQAAAQCkBgADAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA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");


        public UserProfile LastOpenedUser { get; private set; }

        public AccountManager(HorizonClient horizonClient, string initialProfileName = null)
        {
            _horizonClient = horizonClient;

            _profiles = new ConcurrentDictionary<string, UserProfile>();
            _storedOpenedUsers = [];

            _accountSaveDataManager = new AccountSaveDataManager(_profiles);

            if (!_profiles.TryGetValue(DefaultUserId.ToString(), out _))
            {
                AddUser("MeloNX", DefaultUserImage, DefaultUserId);

                OpenUser(DefaultUserId);
            }
            else
            {
                UserId commandLineUserProfileOverride = default;
                if (!string.IsNullOrEmpty(initialProfileName))
                {
                    commandLineUserProfileOverride = _profiles.Values.FirstOrDefault(x => x.Name == initialProfileName)?.UserId ?? default;
                    if (commandLineUserProfileOverride.IsNull)
                    {
                        Logger.Warning?.Print(LogClass.Application, $"The command line specified profile named '{initialProfileName}' was not found");
                    }
                }

                OpenUser(commandLineUserProfileOverride.IsNull ? _accountSaveDataManager.LastOpened : commandLineUserProfileOverride);
            }
        }

        public void Refresh()
        {
            _profiles = new ConcurrentDictionary<string, UserProfile>();
            _accountSaveDataManager = new AccountSaveDataManager(_profiles);

            if (!_profiles.TryGetValue(DefaultUserId.ToString(), out _) && _profiles.Count == 0)
            {
                AddUser("MeloNX", DefaultUserImage, DefaultUserId);

                OpenUser(DefaultUserId);
            }
        }


        public void AddUser(string name, byte[] image, UserId userId = new())
        {
            if (userId.IsNull)
            {
                userId = new UserId(Guid.NewGuid().ToString().Replace("-", string.Empty));
            }

            UserProfile profile = new(userId, name, image);

            _profiles.AddOrUpdate(userId.ToString(), profile, (key, old) => profile);

            _accountSaveDataManager.Save(_profiles);
        }

        public void OpenUser(UserId userId)
        {
            if (_profiles.TryGetValue(userId.ToString(), out UserProfile profile))
            {
                // TODO: Support multiple open users ?
                foreach (UserProfile userProfile in GetAllUsers())
                {
                    if (userProfile == LastOpenedUser)
                    {
                        userProfile.AccountState = AccountState.Closed;

                        break;
                    }
                }

                (LastOpenedUser = profile).AccountState = AccountState.Open;

                _accountSaveDataManager.LastOpened = userId;
            }

            _accountSaveDataManager.Save(_profiles);
        }

        public void CloseUser(UserId userId)
        {
            if (_profiles.TryGetValue(userId.ToString(), out UserProfile profile))
            {
                profile.AccountState = AccountState.Closed;
            }

            _accountSaveDataManager.Save(_profiles);
        }

        public void OpenUserOnlinePlay(Uid userId)
        {
            OpenUserOnlinePlay(new UserId((long)userId.Low, (long)userId.High));
        }

        public void OpenUserOnlinePlay(UserId userId)
        {
            if (_profiles.TryGetValue(userId.ToString(), out UserProfile profile))
            {
                // TODO: Support multiple open online users ?
                foreach (UserProfile userProfile in GetAllUsers())
                {
                    if (userProfile == LastOpenedUser)
                    {
                        userProfile.OnlinePlayState = AccountState.Closed;

                        break;
                    }
                }

                profile.OnlinePlayState = AccountState.Open;
            }

            _accountSaveDataManager.Save(_profiles);
        }

        public void CloseUserOnlinePlay(Uid userId)
        {
            CloseUserOnlinePlay(new UserId((long)userId.Low, (long)userId.High));
        }

        public void CloseUserOnlinePlay(UserId userId)
        {
            if (_profiles.TryGetValue(userId.ToString(), out UserProfile profile))
            {
                profile.OnlinePlayState = AccountState.Closed;
            }

            _accountSaveDataManager.Save(_profiles);
        }

        public void SetUserImage(UserId userId, byte[] image)
        {
            foreach (UserProfile userProfile in GetAllUsers())
            {
                if (userProfile.UserId == userId)
                {
                    userProfile.Image = image;

                    break;
                }
            }

            _accountSaveDataManager.Save(_profiles);
        }

        public void SetUserName(UserId userId, string name)
        {
            foreach (UserProfile userProfile in GetAllUsers())
            {
                if (userProfile.UserId == userId)
                {
                    userProfile.Name = name;

                    break;
                }
            }

            _accountSaveDataManager.Save(_profiles);
        }

        public void DeleteUser(UserId userId)
        {
            DeleteSaveData(userId);

            _profiles.Remove(userId.ToString(), out _);

            OpenUser(DefaultUserId);

            _accountSaveDataManager.Save(_profiles);
        }

        private void DeleteSaveData(UserId userId)
        {
            SaveDataFilter saveDataFilter = SaveDataFilter.Make(programId: default, saveType: default,
                new LibHac.Fs.UserId((ulong)userId.High, (ulong)userId.Low), saveDataId: default, index: default);

            using UniqueRef<SaveDataIterator> saveDataIterator = new();

            _horizonClient.Fs.OpenSaveDataIterator(ref saveDataIterator.Ref, SaveDataSpaceId.User, in saveDataFilter).ThrowIfFailure();

            Span<SaveDataInfo> saveDataInfo = stackalloc SaveDataInfo[10];

            while (true)
            {
                saveDataIterator.Get.ReadSaveDataInfo(out long readCount, saveDataInfo).ThrowIfFailure();

                if (readCount == 0)
                {
                    break;
                }

                for (int i = 0; i < readCount; i++)
                {
                    _horizonClient.Fs.DeleteSaveData(SaveDataSpaceId.User, saveDataInfo[i].SaveDataId).ThrowIfFailure();
                }
            }
        }

        internal int GetUserCount()
        {
            return _profiles.Count;
        }

        internal bool TryGetUser(UserId userId, out UserProfile profile)
        {
            return _profiles.TryGetValue(userId.ToString(), out profile);
        }

        public IEnumerable<UserProfile> GetAllUsers()
        {
            return _profiles.Values;
        }

        internal IEnumerable<UserProfile> GetOpenedUsers()
        {
            return _profiles.Values.Where(x => x.AccountState == AccountState.Open);
        }

        internal IEnumerable<UserProfile> GetStoredOpenedUsers()
        {
            return _storedOpenedUsers;
        }

        internal void StoreOpenedUsers()
        {
            _storedOpenedUsers = _profiles.Values.Where(x => x.AccountState == AccountState.Open).ToArray();
        }

        internal UserProfile GetFirst()
        {
            return _profiles.First().Value;
        }
    }
}
