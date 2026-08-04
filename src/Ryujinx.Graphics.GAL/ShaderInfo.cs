namespace Ryujinx.Graphics.GAL
{
    public struct ShaderInfo
    {
        public int FragmentOutputMap { get; }
        public ResourceLayout ResourceLayout { get; }
        public ProgramPipelineState? State { get; }
        public bool FromCache { get; set; }
        public bool EnableAsyncCompile { get; }
        public bool AllowAsyncCompileSkip { get; }

        public ShaderInfo(
            int fragmentOutputMap,
            ResourceLayout resourceLayout,
            ProgramPipelineState state,
            bool fromCache = false,
            bool enableAsyncCompile = true,
            bool allowAsyncCompileSkip = false)
        {
            FragmentOutputMap = fragmentOutputMap;
            ResourceLayout = resourceLayout;
            State = state;
            FromCache = fromCache;
            EnableAsyncCompile = enableAsyncCompile;
            AllowAsyncCompileSkip = allowAsyncCompileSkip;
        }

        public ShaderInfo(
            int fragmentOutputMap,
            ResourceLayout resourceLayout,
            bool fromCache = false,
            bool enableAsyncCompile = true,
            bool allowAsyncCompileSkip = false)
        {
            FragmentOutputMap = fragmentOutputMap;
            ResourceLayout = resourceLayout;
            State = null;
            FromCache = fromCache;
            EnableAsyncCompile = enableAsyncCompile;
            AllowAsyncCompileSkip = allowAsyncCompileSkip;
        }
    }
}
