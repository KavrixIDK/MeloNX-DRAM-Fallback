namespace Ryujinx.HLE.HOS.Tamper.Operations
{
    interface IOperand
    {
        public T Get<T>() where T : unmanaged, System.Numerics.IBinaryInteger<T>;
        public void Set<T>(T value) where T : unmanaged, System.Numerics.IBinaryInteger<T>;
    }
}
