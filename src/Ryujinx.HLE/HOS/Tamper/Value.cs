using Ryujinx.HLE.HOS.Tamper.Operations;

namespace Ryujinx.HLE.HOS.Tamper
{
    class Value<TP> : IOperand where TP : unmanaged, System.Numerics.IBinaryInteger<TP>
    {
        private TP _value;

        public Value(TP value)
        {
            _value = value;
        }

        public T Get<T>() where T : unmanaged, System.Numerics.IBinaryInteger<T>
        {
            return T.CreateTruncating(_value);
        }

        public void Set<T>(T value) where T : unmanaged, System.Numerics.IBinaryInteger<T>
        {
            _value = TP.CreateTruncating(value);
        }
    }
}
