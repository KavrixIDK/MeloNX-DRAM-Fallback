using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Ryujinx.Graphics.Vulkan
{
    sealed class BackgroundCompilationScheduler : IDisposable
    {
        private readonly WorkerQueue _shaderQueue;
        private readonly WorkerQueue _pipelineQueue;

        public BackgroundCompilationScheduler()
        {
            _shaderQueue = new("Shader", GetBackgroundShaderCompileThreadCount());
            _pipelineQueue = new("Pipeline", 1);
        }

        private static int GetBackgroundShaderCompileThreadCount()
        {
            return Math.Max(1, Math.Min(2, Environment.ProcessorCount / 4));
        }

        public Task ScheduleShaderCompile(Action action, bool highPriority = false)
        {
            return _shaderQueue.Schedule(action, highPriority);
        }

        public Task SchedulePipelineCompile(Action action, bool highPriority = false)
        {
            return _pipelineQueue.Schedule(action, highPriority);
        }

        public void Dispose()
        {
            _shaderQueue.Dispose();
            _pipelineQueue.Dispose();
        }

        private sealed class WorkerQueue : IDisposable
        {
            private sealed class WorkItem
            {
                private readonly Action _action;

                public TaskCompletionSource<bool> Completion { get; }

                public WorkItem(Action action)
                {
                    _action = action;
                    Completion = new(TaskCreationOptions.RunContinuationsAsynchronously);
                }

                public void Execute()
                {
                    try
                    {
                        _action();
                        Completion.TrySetResult(true);
                    }
                    catch (Exception ex)
                    {
                        Completion.TrySetException(ex);
                    }
                }

                public void Cancel(ObjectDisposedException exception)
                {
                    Completion.TrySetException(exception);
                }
            }

            private readonly Lock _queueLock = new();
            private readonly Queue<WorkItem> _highPriorityQueue = [];
            private readonly Queue<WorkItem> _lowPriorityQueue = [];
            private readonly SemaphoreSlim _signal = new(0);
            private readonly Thread[] _workers;
            private readonly string _name;

            private bool _stopping;

            public WorkerQueue(string name, int workerCount)
            {
                _name = name;
                _workers = new Thread[workerCount];

                for (int index = 0; index < workerCount; index++)
                {
                    Thread worker = new(WorkerLoop)
                    {
                        IsBackground = true,
                        Name = $"Vulkan {name} Compile {index}",
                        Priority = ThreadPriority.BelowNormal,
                    };

                    _workers[index] = worker;
                    worker.Start();
                }
            }

            public Task Schedule(Action action, bool highPriority)
            {
                WorkItem item = new(action);

                lock (_queueLock)
                {
                    ObjectDisposedException.ThrowIf(_stopping, typeof(WorkerQueue));

                    if (highPriority)
                    {
                        _highPriorityQueue.Enqueue(item);
                    }
                    else
                    {
                        _lowPriorityQueue.Enqueue(item);
                    }
                }

                _signal.Release();

                return item.Completion.Task;
            }

            private void WorkerLoop()
            {
                while (true)
                {
                    _signal.Wait();

                    WorkItem item;

                    lock (_queueLock)
                    {
                        if (_highPriorityQueue.Count != 0)
                        {
                            item = _highPriorityQueue.Dequeue();
                        }
                        else if (_lowPriorityQueue.Count != 0)
                        {
                            item = _lowPriorityQueue.Dequeue();
                        }
                        else if (_stopping)
                        {
                            return;
                        }
                        else
                        {
                            continue;
                        }
                    }

                    item.Execute();
                }
            }

            public void Dispose()
            {
                List<WorkItem> pending = [];

                lock (_queueLock)
                {
                    _stopping = true;

                    while (_highPriorityQueue.TryDequeue(out WorkItem highItem))
                    {
                        pending.Add(highItem);
                    }

                    while (_lowPriorityQueue.TryDequeue(out WorkItem lowItem))
                    {
                        pending.Add(lowItem);
                    }
                }

                if (pending.Count != 0)
                {
                    ObjectDisposedException exception = new($"{_name} background compilation queue");

                    foreach (WorkItem item in pending)
                    {
                        item.Cancel(exception);
                    }
                }

                _signal.Release(_workers.Length);

                foreach (Thread worker in _workers)
                {
                    worker.Join();
                }

                _signal.Dispose();
            }
        }
    }
}
