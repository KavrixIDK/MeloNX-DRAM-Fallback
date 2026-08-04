using Ryujinx.HLE.HOS.Tamper.Operations;

namespace Ryujinx.HLE.HOS.Tamper.Conditions
{
    class CondLE<T> : ICondition where T : unmanaged, System.Numerics.IBinaryInteger<T>
    {
        private readonly IOperand _lhs;
        private readonly IOperand _rhs;

        public CondLE(IOperand lhs, IOperand rhs)
        {
            _lhs = lhs;
            _rhs = rhs;
        }

        public bool Evaluate()
        {
            return _lhs.Get<T>() <= _rhs.Get<T>();
        }
    }
}
