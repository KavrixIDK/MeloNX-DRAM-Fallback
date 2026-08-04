namespace Ryujinx.HLE.HOS.Tamper.Operations
{
    class OpNot<T> : IOperation where T : unmanaged, System.Numerics.IBinaryInteger<T>
    {
        readonly IOperand _destination;
        readonly IOperand _source;

        public OpNot(IOperand destination, IOperand source)
        {
            _destination = destination;
            _source = source;
        }

        public void Execute()
        {
            _destination.Set(~_source.Get<T>());
        }
    }
}
