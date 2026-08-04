using Ryujinx.Common.Logging;
using Ryujinx.HLE.HOS.Tamper.Operations;

namespace Ryujinx.HLE.HOS.Tamper
{
    class Register : IOperand
    {
        private ulong _register = 0;
        private readonly string _alias;

        public Register(string alias)
        {
            _alias = alias;
        }

        public T Get<T>() where T : unmanaged, System.Numerics.IBinaryInteger<T>
        {
            return T.CreateTruncating(_register);
        }

        public void Set<T>(T value) where T : unmanaged, System.Numerics.IBinaryInteger<T>
        {
            Logger.Debug?.Print(LogClass.TamperMachine, $"{_alias}: {value}");

            _register = ulong.CreateTruncating(value);
        }
    }
}
