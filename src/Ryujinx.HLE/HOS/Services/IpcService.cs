using Ryujinx.Common.Logging;
using Ryujinx.HLE.Exceptions;
using Ryujinx.HLE.HOS.Ipc;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;

namespace Ryujinx.HLE.HOS.Services
{
    abstract class IpcService
    {
        public ServerBase Server { get; private set; }

        private IpcService _parent;
        private readonly IdDictionary _domainObjects;
        private int _selfId;
        private bool _isDomain;

        public IpcService(ServerBase server = null, bool registerTipc = false)
        {
            Server = server;

            _parent = this;
            _domainObjects = new IdDictionary();
            _selfId = -1;
        }

        public int ConvertToDomain()
        {
            if (_selfId == -1)
            {
                _selfId = _domainObjects.Add(this);
            }

            _isDomain = true;

            return _selfId;
        }

        public void ConvertToSession()
        {
            _isDomain = false;
        }

        protected virtual ResultCode InvokeCmifMethod(int id, ServiceCtx context)
        {
            if (!context.Device.Configuration.IgnoreMissingServices)
            {
                string dbgMessage = $"{this.GetType().FullName}: {id}";

                throw new ServiceNotImplementedException(this, context, dbgMessage);
            }

            string serviceName = (this is not DummyService dummyService)
                ? this.GetType().FullName
                : dummyService.ServiceName;

            Logger.Warning?.Print(LogClass.KernelIpc, $"Missing service {serviceName}: {id} ignored");

            return ResultCode.Success;
        }

        public virtual int CmifCommandIdByMethodName(string name) => -1;
        
        protected virtual ResultCode InvokeTipcMethod(int id, ServiceCtx context)
        {
            if (!context.Device.Configuration.IgnoreMissingServices)
            {
                string dbgMessage = $"{this.GetType().FullName}: {id}";

                throw new ServiceNotImplementedException(this, context, dbgMessage);
            }

            string serviceName = (this is not DummyService dummyService)
                ? this.GetType().FullName
                : dummyService.ServiceName;

            Logger.Warning?.Print(LogClass.KernelIpc, $"Missing service {serviceName}: {id} ignored");

            return ResultCode.Success;
        }

        public virtual int TipcCommandIdByMethodName(string name) => -1;

        protected void LogInvoke(string name)
            => Logger.Trace?.Print(LogClass.KernelIpc, $"{this.GetType().Name}: {name}");

        public void CallCmifMethod(ServiceCtx context)
        {
            IpcService service = this;

            if (_isDomain)
            {
                int domainWord0 = context.RequestData.ReadInt32();
                int domainObjId = context.RequestData.ReadInt32();

                int domainCmd = (domainWord0 >> 0) & 0xff;
                int inputObjCount = (domainWord0 >> 8) & 0xff;
                int dataPayloadSize = (domainWord0 >> 16) & 0xffff;

                context.RequestData.BaseStream.Seek(0x10 + dataPayloadSize, SeekOrigin.Begin);

                context.Request.ObjectIds.EnsureCapacity(inputObjCount);

                for (int index = 0; index < inputObjCount; index++)
                {
                    context.Request.ObjectIds.Add(context.RequestData.ReadInt32());
                }

                context.RequestData.BaseStream.Seek(0x10, SeekOrigin.Begin);

                if (domainCmd == 1)
                {
                    service = GetObject(domainObjId);

                    context.ResponseData.Write(0L);
                    context.ResponseData.Write(0L);
                }
                else if (domainCmd == 2)
                {
                    Delete(domainObjId);

                    context.ResponseData.Write(0L);

                    return;
                }
                else
                {
                    throw new NotImplementedException($"Domain command: {domainCmd}");
                }
            }

#pragma warning disable IDE0059 // Remove unnecessary value assignment
            long sfciMagic = context.RequestData.ReadInt64();
#pragma warning restore IDE0059
            int commandId = (int)context.RequestData.ReadInt64();

            context.ResponseData.BaseStream.Seek(_isDomain ? 0x20 : 0x10, SeekOrigin.Begin);

            ResultCode result = service.InvokeCmifMethod(commandId, context);

            if (_isDomain)
            {
                foreach (int id in context.Response.ObjectIds)
                {
                    context.ResponseData.Write(id);
                }

                context.ResponseData.BaseStream.Seek(0, SeekOrigin.Begin);

                context.ResponseData.Write(context.Response.ObjectIds.Count);
            }

            context.ResponseData.BaseStream.Seek(_isDomain ? 0x10 : 0, SeekOrigin.Begin);

            context.ResponseData.Write(IpcMagic.Sfco);
            context.ResponseData.Write((long)result);
        }

        public void CallTipcMethod(ServiceCtx context)
        {
            int commandId = (int)context.Request.Type - 0x10;

            context.ResponseData.BaseStream.Seek(0x4, SeekOrigin.Begin);

            ResultCode result = InvokeTipcMethod(commandId, context);

            context.ResponseData.BaseStream.Seek(0, SeekOrigin.Begin);

            context.ResponseData.Write((uint)result);
        }

        protected void MakeObject(ServiceCtx context, IpcService obj)
        {
            obj.TrySetServer(_parent.Server);

            if (_parent._isDomain)
            {
                obj._parent = _parent;

                context.Response.ObjectIds.Add(_parent.Add(obj));
            }
            else
            {
                context.Device.System.KernelContext.Syscall.CreateSession(out int serverSessionHandle, out int clientSessionHandle, false, 0);

                obj.Server.AddSessionObj(serverSessionHandle, obj);

                context.Response.HandleDesc = IpcHandleDesc.MakeMove(clientSessionHandle);
            }
        }

        protected T GetObject<T>(ServiceCtx context, int index) where T : IpcService
        {
            int objId = context.Request.ObjectIds[index];

            IpcService obj = _parent.GetObject(objId);

            return obj is T t ? t : null;
        }

        public bool TrySetServer(ServerBase newServer)
        {
            if (Server == null)
            {
                Server = newServer;

                return true;
            }

            return false;
        }

        private int Add(IpcService obj)
        {
            return _domainObjects.Add(obj);
        }

        private bool Delete(int id)
        {
            object obj = _domainObjects.Delete(id);

            if (obj is IDisposable disposableObj)
            {
                disposableObj.Dispose();
            }

            return obj != null;
        }

        private IpcService GetObject(int id)
        {
            return _domainObjects.GetData<IpcService>(id);
        }

        public void SetParent(IpcService parent)
        {
            _parent = parent._parent;
        }

        public virtual void DestroyAtExit()
        {
            foreach (object domainObject in _domainObjects.Values)
            {
                if (domainObject != this && domainObject is IDisposable disposableObj)
                {
                    disposableObj.Dispose();
                }
            }

            _domainObjects.Clear();
        }
    }
}
