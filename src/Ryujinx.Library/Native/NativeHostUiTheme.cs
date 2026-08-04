using Ryujinx.HLE.UI;

namespace Ryujinx.Library
{
    internal class NativeHostUiTheme : IHostUITheme
    {
        public string FontFamily => "-apple-system";
        
        public ThemeColor DefaultBackgroundColor => new(1, 0, 0, 0);
        public ThemeColor DefaultForegroundColor => new(1, 1, 1, 1);
        public ThemeColor DefaultBorderColor => new(1, 1, 1, 1);
        public ThemeColor SelectionBackgroundColor => new(1, 1, 1, 1);
        public ThemeColor SelectionForegroundColor => new(1, 0, 0, 0);
    }
}
