namespace Ryujinx.HLE.HOS.Services.Account.Acc
{
    [Service("acc:aa", AccountServiceFlag.BaasAccessTokenAccessor)] // Max Sessions: 4
    partial class IBaasAccessTokenAccessor : IpcService
    {
        public IBaasAccessTokenAccessor(ServiceCtx context, AccountServiceFlag serviceFlag) { }
    }
}
