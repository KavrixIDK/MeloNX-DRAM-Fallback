using Ryujinx.HLE.Exceptions;
using Ryujinx.HLE.HOS.Tamper.Operations;

namespace Ryujinx.HLE.HOS.Tamper.CodeEmitters
{
    /// <summary>
    /// Code type 9 allows performing arithmetic on registers.
    /// </summary>
    class Arithmetic
    {
        private const int OperationWidthIndex = 1;
        private const int OperationTypeIndex = 2;
        private const int DestinationRegisterIndex = 3;
        private const int LeftHandSideRegisterIndex = 4;
        private const int UseImmediateAsRhsIndex = 5;
        private const int RightHandSideRegisterIndex = 6;
        private const int RightHandSideImmediateIndex = 8;

        private const int RightHandSideImmediate8 = 8;
        private const int RightHandSideImmediate16 = 16;

        private const byte Add = 0; // lhs + rhs
        private const byte Sub = 1; // lhs - rhs
        private const byte Mul = 2; // lhs * rhs
        private const byte Lsh = 3; // lhs << rhs
        private const byte Rsh = 4; // lhs >> rhs
        private const byte And = 5; // lhs & rhs
        private const byte Or = 6; // lhs | rhs
        private const byte Not = 7; // ~lhs (discards right-hand operand)
        private const byte Xor = 8; // lhs ^ rhs
        private const byte Mov = 9; // lhs (discards right-hand operand)

        public static void Emit(byte[] instruction, CompilationContext context)
        {
            // 9TCRS0s0
            // T: Width of arithmetic operation(1, 2, 4, or 8 bytes).
            // C: Arithmetic operation to apply, see below.
            // R: Register to store result in.
            // S: Register to use as left - hand operand.
            // s: Register to use as right - hand operand.

            // 9TCRS100 VVVVVVVV (VVVVVVVV)
            // T: Width of arithmetic operation(1, 2, 4, or 8 bytes).
            // C: Arithmetic operation to apply, see below.
            // R: Register to store result in.
            // S: Register to use as left - hand operand.
            // V: Value to use as right - hand operand.

            byte operationWidth = instruction[OperationWidthIndex];
            byte operation = instruction[OperationTypeIndex];
            Register destinationRegister = context.GetRegister(instruction[DestinationRegisterIndex]);
            Register leftHandSideRegister = context.GetRegister(instruction[LeftHandSideRegisterIndex]);
            byte rightHandSideIsImmediate = instruction[UseImmediateAsRhsIndex];
            IOperand rightHandSideOperand;

            switch (rightHandSideIsImmediate)
            {
                case 0:
                    // Use a register as right-hand side.
                    rightHandSideOperand = context.GetRegister(instruction[RightHandSideRegisterIndex]);
                    break;
                case 1:
                    // Use an immediate as right-hand side.
                    int immediateSize = operationWidth <= 4 ? RightHandSideImmediate8 : RightHandSideImmediate16;
                    ulong immediate = InstructionHelper.GetImmediate(instruction, RightHandSideImmediateIndex, immediateSize);
                    rightHandSideOperand = new Value<ulong>(immediate);
                    break;
                default:
                    throw new TamperCompilationException($"Invalid right-hand side switch {rightHandSideIsImmediate} in Atmosphere cheat");
            }

            switch (operation)
            {
                case Add:
                    InstructionHelper.Emit(InstructionHelper.Operation.Add, operationWidth, context, destinationRegister, leftHandSideRegister, rightHandSideOperand);
                    break;
                case Sub:
                    InstructionHelper.Emit(InstructionHelper.Operation.Sub, operationWidth, context, destinationRegister, leftHandSideRegister, rightHandSideOperand);
                    break;
                case Mul:
                    InstructionHelper.Emit(InstructionHelper.Operation.Mul, operationWidth, context, destinationRegister, leftHandSideRegister, rightHandSideOperand);
                    break;
                case Lsh:
                    InstructionHelper.Emit(InstructionHelper.Operation.Lsh, operationWidth, context, destinationRegister, leftHandSideRegister, rightHandSideOperand);
                    break;
                case Rsh:
                    InstructionHelper.Emit(InstructionHelper.Operation.Rsh, operationWidth, context, destinationRegister, leftHandSideRegister, rightHandSideOperand);
                    break;
                case And:
                    InstructionHelper.Emit(InstructionHelper.Operation.And, operationWidth, context, destinationRegister, leftHandSideRegister, rightHandSideOperand);
                    break;
                case Or:
                    InstructionHelper.Emit(InstructionHelper.Operation.Or, operationWidth, context, destinationRegister, leftHandSideRegister, rightHandSideOperand);
                    break;
                case Not:
                    InstructionHelper.Emit(InstructionHelper.Operation.Not, operationWidth, context, destinationRegister, leftHandSideRegister);
                    break;
                case Xor:
                    InstructionHelper.Emit(InstructionHelper.Operation.Xor, operationWidth, context, destinationRegister, leftHandSideRegister, rightHandSideOperand);
                    break;
                case Mov:
                    InstructionHelper.Emit(InstructionHelper.Operation.Mov, operationWidth, context, destinationRegister, leftHandSideRegister);
                    break;
                default:
                    throw new TamperCompilationException($"Invalid arithmetic operation {operation} in Atmosphere cheat");
            }
        }
    }
}
