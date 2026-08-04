using Ryujinx.Common.Logging;
using Ryujinx.Graphics.GAL;
using Silk.NET.Vulkan;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace Ryujinx.Graphics.Vulkan
{
    class ShaderCollection : IProgram
    {
        private readonly PipelineShaderStageCreateInfo[] _infos;
        private readonly Shader[] _shaders;

        private readonly PipelineLayoutCacheEntry _plce;

        public PipelineLayout PipelineLayout => _plce.PipelineLayout;
        public bool CanBindWhileIncomplete => CompilesInBackground && AllowAsyncCompileSkip;

        public bool HasMinimalLayout { get; }
        public bool UsePushDescriptors { get; }
        public bool IsCompute { get; }
        public bool HasTessellationControlShader => (Stages & (1u << 3)) != 0;

        public bool UpdateTexturesWithoutTemplate { get; }

        public uint Stages { get; }
        public bool CompilesInBackground { get; }
        public bool AllowAsyncCompileSkip { get; }

        public PipelineStageFlags IncoherentBufferWriteStages { get; }
        public PipelineStageFlags IncoherentTextureWriteStages { get; }

        public ResourceBindingSegment[][] ClearSegments { get; }
        public ResourceBindingSegment[][] BindingSegments { get; }
        public DescriptorSetTemplate[] Templates { get; }

        public ProgramLinkStatus LinkStatus { get; private set; }

        public readonly SpecDescription[] SpecDescriptions;

        public bool IsLinked
        {
            get
            {
                if (LinkStatus == ProgramLinkStatus.Incomplete)
                {
                    CheckProgramLink(true);
                }

                return LinkStatus == ProgramLinkStatus.Success;
            }
        }

        private HashTableSlim<PipelineUid, Auto<DisposablePipeline>> _graphicsPipelineCache;
        private HashTableSlim<SpecData, Auto<DisposablePipeline>> _computePipelineCache;
        private HashTableSlim<PipelineUid, Task> _graphicsPipelineBackgroundQueue;
        private HashTableSlim<SpecData, Task> _computePipelineBackgroundQueue;
        private HashTableSlim<PipelineUid, byte> _graphicsPipelineBackgroundFailures;
        private HashTableSlim<SpecData, byte> _computePipelineBackgroundFailures;

        private readonly VulkanRenderer _gd;
        private Device _device;
        private bool _initialized;

        private ProgramPipelineState _state;
        private DisposableRenderPass _dummyRenderPass;
        private Task _compileTask;
        private bool _firstBackgroundUse;
        private readonly object _initializeLock;
        private readonly object _pipelineCacheLock;
        private bool _disposed;
        private bool _failLinkOnBackgroundPipelineFailure;

        public ShaderCollection(
            VulkanRenderer gd,
            Device device,
            ShaderSource[] shaders,
            ResourceLayout resourceLayout,
            SpecDescription[] specDescription = null,
            bool isMinimal = false,
            bool compileInBackground = true,
            bool allowAsyncCompileSkip = false,
            bool highPriorityBackgroundCompilation = false,
            bool startBackgroundTask = true)
        {
            _gd = gd;
            _device = device;
            CompilesInBackground = compileInBackground;
            AllowAsyncCompileSkip = allowAsyncCompileSkip;
            _initializeLock = new object();
            _pipelineCacheLock = new object();

            if (specDescription != null && specDescription.Length != shaders.Length)
            {
                throw new ArgumentException($"{nameof(specDescription)} array length must match {nameof(shaders)} array if provided");
            }

            gd.Shaders.Add(this);

            Shader[] internalShaders = new Shader[shaders.Length];

            _infos = new PipelineShaderStageCreateInfo[shaders.Length];

            SpecDescriptions = specDescription;

            LinkStatus = ProgramLinkStatus.Incomplete;

            uint stages = 0;

            for (int i = 0; i < shaders.Length; i++)
            {
                Shader shader = compileInBackground
                    ? new Shader(gd, device, shaders[i], compileAsync: true, highPriorityBackgroundCompilation)
                    : new Shader(gd.Api, device, shaders[i]);

                stages |= 1u << shader.StageFlags switch
                {
                    ShaderStageFlags.FragmentBit => 1,
                    ShaderStageFlags.GeometryBit => 2,
                    ShaderStageFlags.TessellationControlBit => 3,
                    ShaderStageFlags.TessellationEvaluationBit => 4,
                    _ => 0,
                };

                if (shader.StageFlags == ShaderStageFlags.ComputeBit)
                {
                    IsCompute = true;
                }

                internalShaders[i] = shader;
            }

            _shaders = internalShaders;

            bool usePushDescriptors = !isMinimal &&
                VulkanConfiguration.UsePushDescriptors &&
                _gd.Capabilities.SupportsPushDescriptors &&
                !IsCompute &&
                !HasPushDescriptorsBug(gd) &&
                CanUsePushDescriptors(gd, resourceLayout, IsCompute);

            ReadOnlyCollection<ResourceDescriptorCollection> sets = usePushDescriptors ?
                BuildPushDescriptorSets(gd, resourceLayout.Sets) : resourceLayout.Sets;

            _plce = gd.PipelineLayoutCache.GetOrCreate(gd, device, sets, usePushDescriptors);

            HasMinimalLayout = isMinimal;
            UsePushDescriptors = usePushDescriptors;

            Stages = stages;

            ClearSegments = BuildClearSegments(sets);
            BindingSegments = BuildBindingSegments(resourceLayout.SetUsages, out bool usesBufferTextures);
            Templates = BuildTemplates(usePushDescriptors);
            (IncoherentBufferWriteStages, IncoherentTextureWriteStages) = BuildIncoherentStages(resourceLayout.SetUsages);

            // Updating buffer texture bindings using template updates crashes the Adreno driver on Windows.
            UpdateTexturesWithoutTemplate = gd.IsQualcommProprietary && usesBufferTextures;

            _compileTask = compileInBackground && startBackgroundTask
                ? BackgroundShaderModuleCompilation()
                : Task.CompletedTask;
            _firstBackgroundUse = false;
        }

        public ShaderCollection(
            VulkanRenderer gd,
            Device device,
            ShaderSource[] sources,
            ResourceLayout resourceLayout,
            ProgramPipelineState state,
            bool fromCache,
            bool compileInBackground,
            bool allowAsyncCompileSkip,
            bool highPriorityBackgroundCompilation) : this(
                gd,
                device,
                sources,
                resourceLayout,
                compileInBackground: compileInBackground,
                allowAsyncCompileSkip: allowAsyncCompileSkip,
                highPriorityBackgroundCompilation: highPriorityBackgroundCompilation,
                startBackgroundTask: false)
        {
            _state = state;

            if (!compileInBackground)
            {
                _compileTask = BackgroundCompilation();
                _firstBackgroundUse = !fromCache;
                return;
            }

            _failLinkOnBackgroundPipelineFailure = fromCache;

            bool warmUpInitialPipeline = compileInBackground && (!allowAsyncCompileSkip || fromCache);

            _compileTask = compileInBackground
                ? warmUpInitialPipeline
                    ? BackgroundCompilation()
                    : BackgroundShaderModuleCompilation()
                : Task.CompletedTask;

            if (warmUpInitialPipeline)
            {
                RegisterInitialBackgroundPipelineTask(_compileTask);
            }

            _firstBackgroundUse = !fromCache;
        }

        private static bool HasPushDescriptorsBug(VulkanRenderer gd)
        {
            // Those GPUs/drivers do not work properly with push descriptors, so we must force disable them.
            return gd.IsNvidiaPreTuring || (gd.IsIntelArc && (gd.IsIntelWindows || gd.IsIntelLinux));
        }

        private static bool CanUsePushDescriptors(VulkanRenderer gd, ResourceLayout layout, bool isCompute)
        {
            // If binding 3 is immediately used, use an alternate set of reserved bindings.
            ReadOnlyCollection<ResourceUsage> uniformUsage = layout.SetUsages[0].Usages;
            bool hasBinding3 = uniformUsage.Any(x => x.Binding == 3);
            int[] reserved = isCompute ? [] : gd.GetPushDescriptorReservedBindings(hasBinding3);

            // Can't use any of the reserved usages.
            for (int i = 0; i < uniformUsage.Count; i++)
            {
                int binding = uniformUsage[i].Binding;

                if (reserved.Contains(binding) ||
                    binding >= Constants.MaxPushDescriptorBinding ||
                    binding >= gd.Capabilities.MaxPushDescriptors + reserved.Count(id => id < binding))
                {
                    return false;
                }
            }

            //Prevent the sum of descriptors from exceeding MaxPushDescriptors
            int totalDescriptors = 0;
            foreach (ResourceDescriptor desc in layout.Sets.First().Descriptors)
            {
                if (!reserved.Contains(desc.Binding))
                    totalDescriptors += desc.Count;
            }

            if (totalDescriptors > gd.Capabilities.MaxPushDescriptors)
                return false;

            return true;
        }

        private static ReadOnlyCollection<ResourceDescriptorCollection> BuildPushDescriptorSets(
            VulkanRenderer gd,
            ReadOnlyCollection<ResourceDescriptorCollection> sets)
        {
            // The reserved bindings were selected when determining if push descriptors could be used.
            int[] reserved = gd.GetPushDescriptorReservedBindings(false);

            ResourceDescriptorCollection[] result = new ResourceDescriptorCollection[sets.Count];

            for (int i = 0; i < sets.Count; i++)
            {
                if (i == 0)
                {
                    // Push descriptors apply here. Remove reserved bindings.
                    ResourceDescriptorCollection original = sets[i];

                    ResourceDescriptor[] pdUniforms = new ResourceDescriptor[original.Descriptors.Count];
                    int j = 0;

                    foreach (ResourceDescriptor descriptor in original.Descriptors)
                    {
                        if (reserved.Contains(descriptor.Binding))
                        {
                            // If the binding is reserved, set its descriptor count to 0.
                            pdUniforms[j++] = new ResourceDescriptor(
                                descriptor.Binding,
                                0,
                                descriptor.Type,
                                descriptor.Stages);
                        }
                        else
                        {
                            pdUniforms[j++] = descriptor;
                        }
                    }

                    result[i] = new ResourceDescriptorCollection(new(pdUniforms));
                }
                else
                {
                    result[i] = sets[i];
                }
            }

            return new(result);
        }

        private static ResourceBindingSegment[][] BuildClearSegments(ReadOnlyCollection<ResourceDescriptorCollection> sets)
        {
            ResourceBindingSegment[][] segments = new ResourceBindingSegment[sets.Count][];

            for (int setIndex = 0; setIndex < sets.Count; setIndex++)
            {
                List<ResourceBindingSegment> currentSegments = [];

                ResourceDescriptor currentDescriptor = default;
                int currentCount = 0;

                for (int index = 0; index < sets[setIndex].Descriptors.Count; index++)
                {
                    ResourceDescriptor descriptor = sets[setIndex].Descriptors[index];

                    if (currentDescriptor.Binding + currentCount != descriptor.Binding ||
                        currentDescriptor.Type != descriptor.Type ||
                        currentDescriptor.Stages != descriptor.Stages ||
                        currentDescriptor.Count > 1 ||
                        descriptor.Count > 1)
                    {
                        if (currentCount != 0)
                        {
                            currentSegments.Add(new ResourceBindingSegment(
                                currentDescriptor.Binding,
                                currentCount,
                                currentDescriptor.Type,
                                currentDescriptor.Stages,
                                currentDescriptor.Count > 1));
                        }

                        currentDescriptor = descriptor;
                        currentCount = descriptor.Count;
                    }
                    else
                    {
                        currentCount += descriptor.Count;
                    }
                }

                if (currentCount != 0)
                {
                    currentSegments.Add(new ResourceBindingSegment(
                        currentDescriptor.Binding,
                        currentCount,
                        currentDescriptor.Type,
                        currentDescriptor.Stages,
                        currentDescriptor.Count > 1));
                }

                segments[setIndex] = currentSegments.ToArray();
            }

            return segments;
        }

        private static ResourceBindingSegment[][] BuildBindingSegments(ReadOnlyCollection<ResourceUsageCollection> setUsages, out bool usesBufferTextures)
        {
            usesBufferTextures = false;

            ResourceBindingSegment[][] segments = new ResourceBindingSegment[setUsages.Count][];

            for (int setIndex = 0; setIndex < setUsages.Count; setIndex++)
            {
                List<ResourceBindingSegment> currentSegments = [];

                ResourceUsage currentUsage = default;
                int currentCount = 0;

                for (int index = 0; index < setUsages[setIndex].Usages.Count; index++)
                {
                    ResourceUsage usage = setUsages[setIndex].Usages[index];

                    if (usage.Type == ResourceType.BufferTexture)
                    {
                        usesBufferTextures = true;
                    }

                    if (currentUsage.Binding + currentCount != usage.Binding ||
                        currentUsage.Type != usage.Type ||
                        currentUsage.Stages != usage.Stages ||
                        currentUsage.ArrayLength > 1 ||
                        usage.ArrayLength > 1)
                    {
                        if (currentCount != 0)
                        {
                            currentSegments.Add(new ResourceBindingSegment(
                                currentUsage.Binding,
                                currentCount,
                                currentUsage.Type,
                                currentUsage.Stages,
                                currentUsage.ArrayLength > 1));
                        }

                        currentUsage = usage;
                        currentCount = usage.ArrayLength;
                    }
                    else
                    {
                        currentCount++;
                    }
                }

                if (currentCount != 0)
                {
                    currentSegments.Add(new ResourceBindingSegment(
                        currentUsage.Binding,
                        currentCount,
                        currentUsage.Type,
                        currentUsage.Stages,
                        currentUsage.ArrayLength > 1));
                }

                segments[setIndex] = currentSegments.ToArray();
            }

            return segments;
        }

        private DescriptorSetTemplate[] BuildTemplates(bool usePushDescriptors)
        {
            DescriptorSetTemplate[] templates = new DescriptorSetTemplate[BindingSegments.Length];

            for (int setIndex = 0; setIndex < BindingSegments.Length; setIndex++)
            {
                if (usePushDescriptors && setIndex == 0)
                {
                    // Push descriptors get updated using templates owned by the pipeline layout.
                    continue;
                }

                ResourceBindingSegment[] segments = BindingSegments[setIndex];

                if (segments != null && segments.Length > 0)
                {
                    templates[setIndex] = new DescriptorSetTemplate(
                        _gd,
                        _device,
                        segments,
                        _plce,
                        IsCompute ? PipelineBindPoint.Compute : PipelineBindPoint.Graphics,
                        setIndex);
                }
            }

            return templates;
        }

        private static PipelineStageFlags GetPipelineStages(ResourceStages stages)
        {
            PipelineStageFlags result = 0;

            if ((stages & ResourceStages.Compute) != 0)
            {
                result |= PipelineStageFlags.ComputeShaderBit;
            }

            if ((stages & ResourceStages.Vertex) != 0)
            {
                result |= PipelineStageFlags.VertexShaderBit;
            }

            if ((stages & ResourceStages.Fragment) != 0)
            {
                result |= PipelineStageFlags.FragmentShaderBit;
            }

            if ((stages & ResourceStages.Geometry) != 0)
            {
                result |= PipelineStageFlags.GeometryShaderBit;
            }

            if ((stages & ResourceStages.TessellationControl) != 0)
            {
                result |= PipelineStageFlags.TessellationControlShaderBit;
            }

            if ((stages & ResourceStages.TessellationEvaluation) != 0)
            {
                result |= PipelineStageFlags.TessellationEvaluationShaderBit;
            }

            return result;
        }

        private static (PipelineStageFlags Buffer, PipelineStageFlags Texture) BuildIncoherentStages(ReadOnlyCollection<ResourceUsageCollection> setUsages)
        {
            PipelineStageFlags buffer = PipelineStageFlags.None;
            PipelineStageFlags texture = PipelineStageFlags.None;

            foreach (ResourceUsageCollection set in setUsages)
            {
                foreach (ResourceUsage range in set.Usages)
                {
                    if (range.Write)
                    {
                        PipelineStageFlags stages = GetPipelineStages(range.Stages);

                        switch (range.Type)
                        {
                            case ResourceType.Image:
                                texture |= stages;
                                break;
                            case ResourceType.StorageBuffer:
                            case ResourceType.BufferImage:
                                buffer |= stages;
                                break;
                        }
                    }
                }
            }

            return (buffer, texture);
        }

        private async Task BackgroundShaderModuleCompilation()
        {
            await WaitForShaderModuleCompilation();
        }

        private async Task BackgroundCompilation()
        {
            if (!CompilesInBackground)
            {
                await Task.WhenAll(_shaders.Select(shader => shader.CompileTask));

                if (Array.Exists(_shaders, shader => shader.CompileStatus == ProgramLinkStatus.Failure))
                {
                    LinkStatus = ProgramLinkStatus.Failure;

                    return;
                }

                try
                {
                    if (IsCompute)
                    {
                        CreateBackgroundComputePipeline();
                    }
                    else
                    {
                        CreateBackgroundGraphicsPipeline();
                    }
                }
                catch (VulkanException e)
                {
                    Logger.Error?.PrintMsg(LogClass.Gpu, $"Background Compilation failed: {e.Message}");

                    LinkStatus = ProgramLinkStatus.Failure;
                }

                return;
            }

            try
            {
                if (!await WaitForShaderModuleCompilation())
                {
                    return;
                }

                await RunBackgroundPipelineCompile(() =>
                {
                    if (IsCompute)
                    {
                        CreateBackgroundComputePipeline();
                    }
                    else
                    {
                        CreateBackgroundGraphicsPipeline();
                    }
                }, highPriority: false);
            }
            catch (VulkanException e)
            {
                LogBackgroundPipelineFailure(e);
            }
            catch (Exception e)
            {
                LogBackgroundPipelineFailure(e);
            }
            finally
            {
                ClearInitialBackgroundPipelineTask();
            }
        }

        private void RegisterInitialBackgroundPipelineTask(Task task)
        {
            lock (_pipelineCacheLock)
            {
                if (IsCompute)
                {
                    SpecData key = GetInitialComputePipelineKey();

                    _computePipelineBackgroundQueue ??= new();

                    if (!_computePipelineBackgroundQueue.TryGetValue(ref key, out _))
                    {
                        _computePipelineBackgroundQueue.Add(ref key, task);
                    }
                }
                else
                {
                    PipelineUid key = GetInitialGraphicsPipelineKey();

                    _graphicsPipelineBackgroundQueue ??= new();

                    if (!_graphicsPipelineBackgroundQueue.TryGetValue(ref key, out _))
                    {
                        _graphicsPipelineBackgroundQueue.Add(ref key, task);
                    }
                }
            }
        }

        private void ClearInitialBackgroundPipelineTask()
        {
            lock (_pipelineCacheLock)
            {
                if (IsCompute)
                {
                    SpecData key = GetInitialComputePipelineKey();
                    _computePipelineBackgroundQueue?.Remove(ref key);
                }
                else
                {
                    PipelineUid key = GetInitialGraphicsPipelineKey();
                    _graphicsPipelineBackgroundQueue?.Remove(ref key);
                }
            }
        }

        private static SpecData GetInitialComputePipelineKey()
        {
            return new(ReadOnlySpan<byte>.Empty);
        }

        private PipelineUid GetInitialGraphicsPipelineKey()
        {
            PipelineState pipeline = _state.ToVulkanPipelineState(_gd);

            try
            {
                return pipeline.Internal;
            }
            finally
            {
                pipeline.Dispose();
            }
        }

        private Task RunBackgroundPipelineCompile(Action compileAction, bool highPriority)
        {
            return _gd.BackgroundCompilationScheduler.SchedulePipelineCompile(compileAction, highPriority);
        }

        private void LogBackgroundPipelineFailure(Exception exception)
        {
            string message = $"Background shader pipeline warm-up failed: {exception.Message}";

            if (_failLinkOnBackgroundPipelineFailure)
            {
                Logger.Error?.PrintMsg(LogClass.Gpu, message);
                LinkStatus = ProgramLinkStatus.Failure;
            }
            else
            {
                Logger.Warning?.PrintMsg(LogClass.Gpu, message);
            }
        }

        private async Task<bool> WaitForShaderModuleCompilation()
        {
            try
            {
                await Task.WhenAll(_shaders.Select(shader => shader.CompileTask));
            }
            catch (Exception e)
            {
                Logger.Error?.PrintMsg(LogClass.Gpu, $"Shader module background compilation failed: {e.Message}");
                LinkStatus = ProgramLinkStatus.Failure;

                return false;
            }

            return EnsureShadersReady(blocking: true);
        }

        private void EnsureShadersReadyLegacy()
        {
            if (!_initialized)
            {
                CheckProgramLink(true);

                ProgramLinkStatus resultStatus = ProgramLinkStatus.Success;

                for (int i = 0; i < _shaders.Length; i++)
                {
                    Shader shader = _shaders[i];

                    if (shader.CompileStatus != ProgramLinkStatus.Success)
                    {
                        resultStatus = ProgramLinkStatus.Failure;
                    }

                    _infos[i] = shader.GetInfo();
                }

                if (LinkStatus != ProgramLinkStatus.Failure)
                {
                    LinkStatus = resultStatus;
                }

                _initialized = true;
            }
        }

        private bool EnsureShadersReady(bool blocking)
        {
            if (_initialized)
            {
                return LinkStatus == ProgramLinkStatus.Success;
            }

            if (LinkStatus == ProgramLinkStatus.Failure)
            {
                return false;
            }

            if (!blocking && _shaders.Any(shader => shader.CompileStatus == ProgramLinkStatus.Incomplete))
            {
                return false;
            }

            lock (_initializeLock)
            {
                if (_initialized)
                {
                    return LinkStatus == ProgramLinkStatus.Success;
                }

                ProgramLinkStatus resultStatus = ProgramLinkStatus.Success;

                for (int i = 0; i < _shaders.Length; i++)
                {
                    Shader shader = _shaders[i];

                    if (shader.CompileStatus == ProgramLinkStatus.Incomplete)
                    {
                        if (!blocking)
                        {
                            return false;
                        }

                        shader.WaitForCompile();
                    }

                    if (shader.CompileStatus != ProgramLinkStatus.Success)
                    {
                        resultStatus = ProgramLinkStatus.Failure;
                    }
                }

                if (resultStatus == ProgramLinkStatus.Success)
                {
                    for (int i = 0; i < _shaders.Length; i++)
                    {
                        _infos[i] = _shaders[i].GetInfo();
                    }
                }

                LinkStatus = resultStatus;
                _initialized = true;

                return resultStatus == ProgramLinkStatus.Success;
            }
        }

        public bool TryGetInfos(out PipelineShaderStageCreateInfo[] infos, bool blocking)
        {
            if (EnsureShadersReady(blocking))
            {
                infos = _infos;
                return true;
            }

            infos = null;
            return false;
        }

        public PipelineShaderStageCreateInfo[] GetInfos()
        {
            if (!CompilesInBackground)
            {
                EnsureShadersReadyLegacy();

                return _infos;
            }

            TryGetInfos(out PipelineShaderStageCreateInfo[] infos, blocking: true);

            return infos;
        }

        protected DisposableRenderPass CreateDummyRenderPass()
        {
            if (_dummyRenderPass.Value.Handle != 0)
            {
                return _dummyRenderPass;
            }

            return _dummyRenderPass = _state.ToRenderPass(_gd, _device);
        }

        public void CreateBackgroundComputePipeline()
        {
            PipelineState pipeline = new();
            pipeline.Initialize();

            pipeline.Stages[0] = _shaders[0].GetInfo();
            pipeline.StagesCount = 1;
            pipeline.PipelineLayout = PipelineLayout;

            if (CompilesInBackground)
            {
                pipeline.CreateComputePipeline(
                    _gd,
                    _device,
                    this,
                    (_gd.Pipeline as PipelineBase).PipelineCache,
                    throwOnError: _failLinkOnBackgroundPipelineFailure,
                    cachePipelineFailure: false);
            }
            else
            {
                pipeline.CreateComputePipeline(_gd, _device, this, (_gd.Pipeline as PipelineBase).PipelineCache);
            }
            pipeline.Dispose();
        }

        public void CreateBackgroundGraphicsPipeline()
        {
            // To compile shaders in the background in Vulkan, we need to create valid pipelines using the shader modules.
            // The GPU provides pipeline state via the GAL that can be converted into our internal Vulkan pipeline state.
            // This should match the pipeline state at the time of the first draw. If it doesn't, then it'll likely be
            // close enough that the GPU driver will reuse the compiled shader for the different state.

            // First, we need to create a render pass object compatible with the one that will be used at runtime.
            // The active attachment formats have been provided by the abstraction layer.
            DisposableRenderPass renderPass = CreateDummyRenderPass();

            PipelineState pipeline = _state.ToVulkanPipelineState(_gd);

            // Copy the shader stage info to the pipeline.
            Span<PipelineShaderStageCreateInfo> stages = pipeline.Stages.AsSpan();

            for (int i = 0; i < _shaders.Length; i++)
            {
                stages[i] = _shaders[i].GetInfo();
            }

            pipeline.HasTessellationControlShader = HasTessellationControlShader;
            pipeline.StagesCount = (uint)_shaders.Length;
            pipeline.PipelineLayout = PipelineLayout;

            if (CompilesInBackground)
            {
                pipeline.CreateGraphicsPipeline(
                    _gd,
                    _device,
                    this,
                    (_gd.Pipeline as PipelineBase).PipelineCache,
                    renderPass.Value,
                    throwOnError: _failLinkOnBackgroundPipelineFailure,
                    cachePipelineFailure: false);
            }
            else
            {
                pipeline.CreateGraphicsPipeline(_gd, _device, this, (_gd.Pipeline as PipelineBase).PipelineCache, renderPass.Value, throwOnError: true);
            }
            pipeline.Dispose();
        }

        public ProgramLinkStatus CheckProgramLink(bool blocking)
        {
            if (!CompilesInBackground)
            {
                if (LinkStatus == ProgramLinkStatus.Incomplete)
                {
                    ProgramLinkStatus resultStatus = ProgramLinkStatus.Success;

                    foreach (Shader shader in _shaders)
                    {
                        if (shader.CompileStatus == ProgramLinkStatus.Incomplete)
                        {
                            if (blocking)
                            {
                                shader.WaitForCompile();

                                if (shader.CompileStatus != ProgramLinkStatus.Success)
                                {
                                    resultStatus = ProgramLinkStatus.Failure;
                                }
                            }
                            else
                            {
                                return ProgramLinkStatus.Incomplete;
                            }
                        }
                    }

                    if (!_compileTask.IsCompleted)
                    {
                        if (blocking)
                        {
                            _compileTask.Wait();

                            if (LinkStatus == ProgramLinkStatus.Failure)
                            {
                                return ProgramLinkStatus.Failure;
                            }
                        }
                        else
                        {
                            return ProgramLinkStatus.Incomplete;
                        }
                    }

                    return resultStatus;
                }

                return LinkStatus;
            }

            if (!EnsureShadersReady(blocking))
            {
                return LinkStatus == ProgramLinkStatus.Failure ? ProgramLinkStatus.Failure : ProgramLinkStatus.Incomplete;
            }

            if (!_compileTask.IsCompleted)
            {
                if (blocking)
                {
                    _compileTask.Wait();

                    if (LinkStatus == ProgramLinkStatus.Failure)
                    {
                        return ProgramLinkStatus.Failure;
                    }
                }
                else
                {
                    return ProgramLinkStatus.Incomplete;
                }
            }

            return LinkStatus;
        }

        public byte[] GetBinary()
        {
            return null;
        }

        public DescriptorSetTemplate GetPushDescriptorTemplate(long updateMask)
        {
            return _plce.GetPushDescriptorTemplate(IsCompute ? PipelineBindPoint.Compute : PipelineBindPoint.Graphics, updateMask);
        }

        public Auto<DisposablePipeline> AddComputePipeline(ref SpecData key, Auto<DisposablePipeline> pipeline)
        {
            lock (_pipelineCacheLock)
            {
                _computePipelineBackgroundFailures?.Remove(ref key);
                _computePipelineCache ??= new();

                if (_computePipelineCache.TryGetValue(ref key, out Auto<DisposablePipeline> existing))
                {
                    if (existing != pipeline)
                    {
                        pipeline?.Dispose();
                    }

                    return existing;
                }

                _computePipelineCache.Add(ref key, pipeline);

                return pipeline;
            }
        }

        public Auto<DisposablePipeline> AddGraphicsPipeline(ref PipelineUid key, Auto<DisposablePipeline> pipeline)
        {
            lock (_pipelineCacheLock)
            {
                _graphicsPipelineBackgroundFailures?.Remove(ref key);
                _graphicsPipelineCache ??= new();

                if (_graphicsPipelineCache.TryGetValue(ref key, out Auto<DisposablePipeline> existing))
                {
                    if (existing != pipeline)
                    {
                        pipeline?.Dispose();
                    }

                    return existing;
                }

                _graphicsPipelineCache.Add(ref key, pipeline);

                return pipeline;
            }
        }

        public bool TryGetComputePipeline(ref SpecData key, out Auto<DisposablePipeline> pipeline)
        {
            lock (_pipelineCacheLock)
            {
                if (_computePipelineCache == null)
                {
                    pipeline = default;
                    return false;
                }

                return _computePipelineCache.TryGetValue(ref key, out pipeline);
            }
        }

        public bool TryGetGraphicsPipeline(ref PipelineUid key, out Auto<DisposablePipeline> pipeline)
        {
            lock (_pipelineCacheLock)
            {
                if (_graphicsPipelineCache == null)
                {
                    pipeline = default;
                    return false;
                }

                if (!_graphicsPipelineCache.TryGetValue(ref key, out pipeline))
                {
                    if (!CompilesInBackground && _firstBackgroundUse)
                    {
                        Logger.Warning?.Print(LogClass.Gpu, "Background pipeline compile missed on draw - incorrect pipeline state?");
                        _firstBackgroundUse = false;
                    }

                    return false;
                }

                if (!CompilesInBackground)
                {
                    _firstBackgroundUse = false;
                }

                return true;
            }
        }

        public bool QueueBackgroundComputePipeline(ref PipelineState state, PipelineCache cache)
        {
            if (!CompilesInBackground || !AllowAsyncCompileSkip)
            {
                return false;
            }

            SpecData key = state.SpecializationData;
            Task task;

            lock (_pipelineCacheLock)
            {
                if (_disposed ||
                    (_computePipelineCache != null && _computePipelineCache.TryGetValue(ref key, out _)) ||
                    (_computePipelineBackgroundFailures != null && _computePipelineBackgroundFailures.TryGetValue(ref key, out _)))
                {
                    return false;
                }

                if (_computePipelineBackgroundQueue != null &&
                    _computePipelineBackgroundQueue.TryGetValue(ref key, out _))
                {
                    return true;
                }

                task = CompileQueuedComputePipeline(state.Clone(), cache, key);
                (_computePipelineBackgroundQueue ??= new()).Add(ref key, task);
            }

            return true;
        }

        private async Task CompileQueuedComputePipeline(PipelineState state, PipelineCache cache, SpecData key)
        {
            Auto<DisposablePipeline> pipeline = null;

            try
            {
                await RunBackgroundPipelineCompile(() =>
                {
                    pipeline = state.CreateComputePipeline(
                        _gd,
                        _device,
                        this,
                        cache,
                        throwOnError: false,
                        cachePipelineFailure: false);
                }, highPriority: true);

                if (pipeline == null)
                {
                    AddBackgroundComputePipelineFailure(ref key);
                }
            }
            catch (Exception e)
            {
                Logger.Debug?.PrintMsg(LogClass.Gpu, $"Background compute pipeline compilation failed: {e.Message}");
                AddBackgroundComputePipelineFailure(ref key);
            }
            finally
            {
                state.Dispose();

                lock (_pipelineCacheLock)
                {
                    _computePipelineBackgroundQueue?.Remove(ref key);
                }
            }
        }

        private void AddBackgroundComputePipelineFailure(ref SpecData key)
        {
            lock (_pipelineCacheLock)
            {
                if (_computePipelineCache == null || !_computePipelineCache.TryGetValue(ref key, out _))
                {
                    _computePipelineBackgroundFailures ??= new();

                    if (!_computePipelineBackgroundFailures.TryGetValue(ref key, out _))
                    {
                        _computePipelineBackgroundFailures.Add(ref key, 0);
                    }
                }
            }
        }

        public bool QueueBackgroundGraphicsPipeline(
            ref PipelineState state,
            PipelineCache cache,
            Auto<DisposableRenderPass> renderPass)
        {
            if (!CompilesInBackground || !AllowAsyncCompileSkip)
            {
                return false;
            }

            PipelineUid key = state.Internal;
            Task task;

            lock (_pipelineCacheLock)
            {
                if (_disposed ||
                    (_graphicsPipelineCache != null && _graphicsPipelineCache.TryGetValue(ref key, out _)) ||
                    (_graphicsPipelineBackgroundFailures != null && _graphicsPipelineBackgroundFailures.TryGetValue(ref key, out _)))
                {
                    return false;
                }

                if (_graphicsPipelineBackgroundQueue != null &&
                    _graphicsPipelineBackgroundQueue.TryGetValue(ref key, out _))
                {
                    return true;
                }

                if (!renderPass.TryIncrementReferenceCount())
                {
                    return false;
                }

                task = CompileQueuedGraphicsPipeline(state.Clone(), cache, renderPass, key);
                (_graphicsPipelineBackgroundQueue ??= new()).Add(ref key, task);
            }

            return true;
        }

        private async Task CompileQueuedGraphicsPipeline(
            PipelineState state,
            PipelineCache cache,
            Auto<DisposableRenderPass> renderPass,
            PipelineUid key)
        {
            Auto<DisposablePipeline> pipeline = null;

            try
            {
                await RunBackgroundPipelineCompile(() =>
                {
                    pipeline = state.CreateGraphicsPipeline(
                        _gd,
                        _device,
                        this,
                        cache,
                        renderPass.GetUnsafe().Value,
                        throwOnError: false,
                        cachePipelineFailure: false);
                }, highPriority: true);

                if (pipeline == null)
                {
                    AddBackgroundGraphicsPipelineFailure(ref key);
                }
            }
            catch (Exception e)
            {
                Logger.Debug?.PrintMsg(LogClass.Gpu, $"Background graphics pipeline compilation failed: {e.Message}");
                AddBackgroundGraphicsPipelineFailure(ref key);
            }
            finally
            {
                state.Dispose();
                renderPass.DecrementReferenceCount();

                lock (_pipelineCacheLock)
                {
                    _graphicsPipelineBackgroundQueue?.Remove(ref key);
                }
            }
        }

        private void AddBackgroundGraphicsPipelineFailure(ref PipelineUid key)
        {
            lock (_pipelineCacheLock)
            {
                if (_graphicsPipelineCache == null || !_graphicsPipelineCache.TryGetValue(ref key, out _))
                {
                    _graphicsPipelineBackgroundFailures ??= new();

                    if (!_graphicsPipelineBackgroundFailures.TryGetValue(ref key, out _))
                    {
                        _graphicsPipelineBackgroundFailures.Add(ref key, 0);
                    }
                }
            }
        }

        public void WaitForBackgroundCompilation()
        {
            try
            {
                _compileTask.Wait();
                WaitForBackgroundPipelineQueue();
            }
            catch (AggregateException e)
            {
                Logger.Warning?.PrintMsg(LogClass.Gpu, $"Background shader compilation failed: {e.InnerException?.Message ?? e.Message}");
            }
        }

        private void WaitForBackgroundPipelineQueue()
        {
            Task[] tasks;

            lock (_pipelineCacheLock)
            {
                Task[] graphicsTasks = _graphicsPipelineBackgroundQueue?.Values.ToArray() ?? [];
                Task[] computeTasks = _computePipelineBackgroundQueue?.Values.ToArray() ?? [];

                tasks = new Task[graphicsTasks.Length + computeTasks.Length];
                graphicsTasks.CopyTo(tasks, 0);
                computeTasks.CopyTo(tasks, graphicsTasks.Length);
            }

            if (tasks.Length != 0)
            {
                Task.WaitAll(tasks);
            }
        }

        public void UpdateDescriptorCacheCommandBufferIndex(int commandBufferIndex)
        {
            _plce.UpdateCommandBufferIndex(commandBufferIndex);
        }

        public Auto<DescriptorSetCollection> GetNewDescriptorSetCollection(int setIndex, out bool isNew)
        {
            return _plce.GetNewDescriptorSetCollection(setIndex, out isNew);
        }

        public Auto<DescriptorSetCollection> GetNewManualDescriptorSetCollection(CommandBufferScoped cbs, int setIndex, out int cacheIndex)
        {
            return _plce.GetNewManualDescriptorSetCollection(cbs, setIndex, out cacheIndex);
        }

        public void UpdateManualDescriptorSetCollectionOwnership(CommandBufferScoped cbs, int setIndex, int cacheIndex)
        {
            _plce.UpdateManualDescriptorSetCollectionOwnership(cbs, setIndex, cacheIndex);
        }

        public void ReleaseManualDescriptorSetCollection(int setIndex, int cacheIndex)
        {
            _plce.ReleaseManualDescriptorSetCollection(setIndex, cacheIndex);
        }

        public bool HasSameLayout(ShaderCollection other)
        {
            return other != null && _plce == other._plce;
        }

        protected virtual void Dispose(bool disposing)
        {
            if (disposing)
            {
                if (_disposed)
                {
                    return;
                }

                _disposed = true;

                if (!_gd.Shaders.Remove(this))
                {
                    return;
                }

                try
                {
                    _compileTask.Wait();
                    WaitForBackgroundPipelineQueue();
                }
                catch (AggregateException e)
                {
                    Logger.Warning?.PrintMsg(LogClass.Gpu, $"Background shader compilation failed during disposal: {e.InnerException?.Message ?? e.Message}");
                }

                for (int i = 0; i < _shaders.Length; i++)
                {
                    _shaders[i].Dispose();
                }

                lock (_pipelineCacheLock)
                {
                    if (_graphicsPipelineCache != null)
                    {
                        foreach (Auto<DisposablePipeline> pipeline in _graphicsPipelineCache.Values)
                        {
                            pipeline?.Dispose();
                        }
                    }

                    if (_computePipelineCache != null)
                    {
                        foreach (Auto<DisposablePipeline> pipeline in _computePipelineCache.Values)
                        {
                            pipeline?.Dispose();
                        }
                    }
                }

                for (int i = 0; i < Templates.Length; i++)
                {
                    Templates[i]?.Dispose();
                }

                if (_dummyRenderPass.Value.Handle != 0)
                {
                    _dummyRenderPass.Dispose();
                }
            }
        }

        public void Dispose()
        {
            Dispose(true);
        }
    }
}
