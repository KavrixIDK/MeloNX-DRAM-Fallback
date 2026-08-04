using Ryujinx.HLE.Exceptions;
using Ryujinx.HLE.HOS.Tamper.Conditions;
using Ryujinx.HLE.HOS.Tamper.Operations;
using System;
using System.Globalization;

namespace Ryujinx.HLE.HOS.Tamper
{
    class InstructionHelper
    {
        private const int CodeTypeIndex = 0;

        public enum Operation
        {
            Add,
            And,
            Log,
            Lsh,
            Mov,
            Mul,
            Not,
            Or,
            Rsh,
            Sub,
            Xor,
        }

        public static void Emit(IOperation operation, CompilationContext context)
        {
            context.CurrentOperations.Add(operation);
        }

        public static void Emit(Operation operation, byte width, CompilationContext context, IOperand destination, IOperand source)
        {
            Emit(Create(operation, width, destination, source), context);
        }

        public static void Emit(Operation operation, byte width, CompilationContext context, IOperand destination, IOperand lhs, IOperand rhs)
        {
            Emit(Create(operation, width, destination, lhs, rhs), context);
        }

        public static void EmitLog(byte width, CompilationContext context, int logId, IOperand source)
        {
            Emit(CreateLog(width, logId, source), context);
        }

        public static void EmitMov(byte width, CompilationContext context, IOperand destination, IOperand source)
        {
            Emit(Operation.Mov, width, context, destination, source);
        }

        public static ICondition CreateCondition(Comparison comparison, byte width, IOperand lhs, IOperand rhs)
        {
            return width switch
            {
                1 => CreateCondition<byte>(comparison, lhs, rhs),
                2 => CreateCondition<ushort>(comparison, lhs, rhs),
                4 => CreateCondition<uint>(comparison, lhs, rhs),
                8 => CreateCondition<ulong>(comparison, lhs, rhs),
                _ => throw new TamperCompilationException($"Invalid instruction width {width} in Atmosphere cheat"),
            };
        }

        private static ICondition CreateCondition<T>(Comparison comparison, IOperand lhs, IOperand rhs) where T : unmanaged, System.Numerics.IBinaryInteger<T>
        {
            return comparison switch
            {
                Comparison.Greater => new CondGT<T>(lhs, rhs),
                Comparison.GreaterOrEqual => new CondGE<T>(lhs, rhs),
                Comparison.Less => new CondLT<T>(lhs, rhs),
                Comparison.LessOrEqual => new CondLE<T>(lhs, rhs),
                Comparison.Equal => new CondEQ<T>(lhs, rhs),
                Comparison.NotEqual => new CondNE<T>(lhs, rhs),
                _ => throw new TamperCompilationException($"Invalid comparison {comparison} in Atmosphere cheat"),
            };
        }

        private static IOperation Create(Operation operation, byte width, IOperand destination, IOperand source)
        {
            return width switch
            {
                1 => Create<byte>(operation, destination, source),
                2 => Create<ushort>(operation, destination, source),
                4 => Create<uint>(operation, destination, source),
                8 => Create<ulong>(operation, destination, source),
                _ => throw new TamperCompilationException($"Invalid instruction width {width} in Atmosphere cheat"),
            };
        }

        private static IOperation Create(Operation operation, byte width, IOperand destination, IOperand lhs, IOperand rhs)
        {
            return width switch
            {
                1 => Create<byte>(operation, destination, lhs, rhs),
                2 => Create<ushort>(operation, destination, lhs, rhs),
                4 => Create<uint>(operation, destination, lhs, rhs),
                8 => Create<ulong>(operation, destination, lhs, rhs),
                _ => throw new TamperCompilationException($"Invalid instruction width {width} in Atmosphere cheat"),
            };
        }

        private static IOperation CreateLog(byte width, int logId, IOperand source)
        {
            return width switch
            {
                1 => new OpLog<byte>(logId, source),
                2 => new OpLog<ushort>(logId, source),
                4 => new OpLog<uint>(logId, source),
                8 => new OpLog<ulong>(logId, source),
                _ => throw new TamperCompilationException($"Invalid instruction width {width} in Atmosphere cheat"),
            };
        }

        private static IOperation Create<T>(Operation operation, IOperand destination, IOperand source) where T : unmanaged, System.Numerics.IBinaryInteger<T>
        {
            return operation switch
            {
                Operation.Mov => new OpMov<T>(destination, source),
                Operation.Not => new OpNot<T>(destination, source),
                _ => throw new TamperCompilationException($"Unsupported unary operation {operation} in Atmosphere cheat"),
            };
        }

        private static IOperation Create<T>(Operation operation, IOperand destination, IOperand lhs, IOperand rhs) where T : unmanaged, System.Numerics.IBinaryInteger<T>
        {
            return operation switch
            {
                Operation.Add => new OpAdd<T>(destination, lhs, rhs),
                Operation.And => new OpAnd<T>(destination, lhs, rhs),
                Operation.Lsh => new OpLsh<T>(destination, lhs, rhs),
                Operation.Mul => new OpMul<T>(destination, lhs, rhs),
                Operation.Or => new OpOr<T>(destination, lhs, rhs),
                Operation.Rsh => new OpRsh<T>(destination, lhs, rhs),
                Operation.Sub => new OpSub<T>(destination, lhs, rhs),
                Operation.Xor => new OpXor<T>(destination, lhs, rhs),
                _ => throw new TamperCompilationException($"Unsupported binary operation {operation} in Atmosphere cheat"),
            };
        }

        public static ulong GetImmediate(byte[] instruction, int index, int nybbleCount)
        {
            ulong value = 0;

            for (int i = 0; i < nybbleCount; i++)
            {
                value <<= 4;
                value |= instruction[index + i];
            }

            return value;
        }

        public static CodeType GetCodeType(byte[] instruction)
        {
            int codeType = instruction[CodeTypeIndex];

            if (codeType >= 0xC)
            {
                byte extension = instruction[CodeTypeIndex + 1];
                codeType = (codeType << 4) | extension;

                if (extension == 0xF)
                {
                    extension = instruction[CodeTypeIndex + 2];
                    codeType = (codeType << 4) | extension;
                }
            }

            return (CodeType)codeType;
        }

        public static byte[] ParseRawInstruction(string rawInstruction)
        {
            const int WordSize = 2 * sizeof(uint);

            // Instructions are multi-word, with 32bit words. Split the raw instruction
            // and parse each word into individual nybbles of bits.

            string[] words = rawInstruction.Split((char[])null, StringSplitOptions.RemoveEmptyEntries);

            byte[] instruction = new byte[WordSize * words.Length];

            if (words.Length == 0)
            {
                throw new TamperCompilationException("Empty instruction in Atmosphere cheat");
            }

            for (int wordIndex = 0; wordIndex < words.Length; wordIndex++)
            {
                string word = words[wordIndex];

                if (word.Length != WordSize)
                {
                    throw new TamperCompilationException($"Invalid word length for {word} in Atmosphere cheat");
                }

                for (int nybbleIndex = 0; nybbleIndex < WordSize; nybbleIndex++)
                {
                    int index = wordIndex * WordSize + nybbleIndex;

                    instruction[index] = byte.Parse(word.AsSpan(nybbleIndex, 1), NumberStyles.HexNumber, CultureInfo.InvariantCulture);
                }
            }

            return instruction;
        }
    }
}
