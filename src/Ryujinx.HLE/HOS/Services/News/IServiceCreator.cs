namespace Ryujinx.HLE.HOS.Services.News
{
    [Service("news:a")]
    [Service("news:c")]
    [Service("news:m")]
    [Service("news:p")]
    [Service("news:v")]
    partial class IServiceCreator : IpcService
    {
        public IServiceCreator(ServiceCtx context) { }
    }
}
