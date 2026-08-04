namespace Ryujinx.HLE.HOS.Tamper.Operations
{
    class OpLsh<T> : IOperation where T : unmanaged, System.Numerics.IBinaryInteger<T>
    {
        readonly IOperand _destination;
        readonly IOperand _lhs;
        readonly IOperand _rhs;

        public OpLsh(IOperand destination, IOperand lhs, IOperand rhs)
        {
            _destination = destination;
            _lhs = lhs;
            _rhs = rhs;
        }

        public void Execute()
        {
            _destination.Set(_lhs.Get<T>() << int.CreateTruncating(_rhs.Get<T>()));
        }
    }
}
