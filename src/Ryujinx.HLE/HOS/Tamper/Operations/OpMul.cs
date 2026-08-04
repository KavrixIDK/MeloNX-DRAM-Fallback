namespace Ryujinx.HLE.HOS.Tamper.Operations
{
    class OpMul<T> : IOperation where T : unmanaged, System.Numerics.IBinaryInteger<T>
    {
        readonly IOperand _destination;
        readonly IOperand _lhs;
        readonly IOperand _rhs;

        public OpMul(IOperand destination, IOperand lhs, IOperand rhs)
        {
            _destination = destination;
            _lhs = lhs;
            _rhs = rhs;
        }

        public void Execute()
        {
            _destination.Set(_lhs.Get<T>() * _rhs.Get<T>());
        }
    }
}
