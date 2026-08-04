using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace Ryujinx.HLE.Generators
{
    [Generator]
    public sealed class TamperGenerator : IIncrementalGenerator
    {
        public void Initialize(IncrementalGeneratorInitializationContext context)
        {
            IncrementalValuesProvider<INamedTypeSymbol> tamperTypes =
                context.SyntaxProvider.CreateSyntaxProvider(
                    predicate: static (node, _) =>
                    {
                        return node is ClassDeclarationSyntax classDecl && classDecl.BaseList != null;
                    },
                    transform: static (ctx, _) =>
                    {
                        INamedTypeSymbol symbol = (INamedTypeSymbol)ctx.SemanticModel.GetDeclaredSymbol((ClassDeclarationSyntax)ctx.Node);

                        return symbol != null && IsTamperFactoryTarget(symbol) ? symbol : null;
                    }
                ).Where(symbol => symbol != null);

            context.RegisterSourceOutput(tamperTypes.Collect(),
                (ctx, tamperTypesData) =>
                {
                    var sourceBuilder = new StringBuilder();

                    sourceBuilder.AppendLine("#nullable enable");
                    sourceBuilder.AppendLine("using System;");
                    sourceBuilder.AppendLine("using Ryujinx.HLE.Exceptions;");
                    sourceBuilder.AppendLine("using Ryujinx.HLE.HOS.Tamper.Operations;");
                    sourceBuilder.AppendLine("using Ryujinx.HLE.HOS.Tamper.Conditions;");
                    sourceBuilder.AppendLine();
                    sourceBuilder.AppendLine("namespace Ryujinx.HLE.HOS.Tamper");
                    sourceBuilder.AppendLine("{");
                    sourceBuilder.AppendLine("    public static class TamperOperationFactory");
                    sourceBuilder.AppendLine("    {");

                    HashSet<string> generatedMethods = new HashSet<string>();

                    foreach (var tamperType in tamperTypesData)
                    {
                        string methodName = tamperType.Name;

                        if (generatedMethods.Contains(methodName))
                            continue;

                        if (tamperType.IsGenericType)
                        {
                            GenerateGenericFactoryMethod(sourceBuilder, tamperType);
                        }
                        else
                        {
                            GenerateNonGenericFactoryMethod(sourceBuilder, tamperType);
                        }

                        generatedMethods.Add(methodName);
                    }

                    GenerateMainFactoryMethod(sourceBuilder, tamperTypesData);

                    sourceBuilder.AppendLine("    }");
                    sourceBuilder.AppendLine("}");

                    ctx.AddSource("GeneratedOperations.g.cs", sourceBuilder.ToString());
                });
        }

        private static bool IsTamperFactoryTarget(INamedTypeSymbol symbol)
        {
            foreach (INamedTypeSymbol implementedInterface in symbol.AllInterfaces)
            {
                string containingNamespace = implementedInterface.ContainingNamespace.ToDisplayString();

                if (implementedInterface.Name == "IOperation" && containingNamespace == "Ryujinx.HLE.HOS.Tamper.Operations")
                {
                    return true;
                }

                if (implementedInterface.Name == "ICondition" && containingNamespace == "Ryujinx.HLE.HOS.Tamper.Conditions")
                {
                    return true;
                }
            }

            return false;
        }

        private void GenerateGenericFactoryMethod(StringBuilder sb, INamedTypeSymbol operationType)
        {
            string className = operationType.Name;
            
            var constructor = operationType.Constructors
                .Where(c => !c.IsStatic && c.DeclaredAccessibility == Accessibility.Public)
                .OrderBy(c => c.Parameters.Length > 0 && c.Parameters[c.Parameters.Length - 1].IsParams)
                .FirstOrDefault();

            if (constructor == null)
                return;

            var parameters = constructor.Parameters;
            
            sb.AppendLine($"        public static object Create{className}(byte width, params object[] operands)");
            sb.AppendLine("        {");
            
            var paramCasts = new List<string>();
            for (int i = 0; i < parameters.Length; i++)
            {
                string cast = GetParameterCast(parameters[i], i);
                paramCasts.Add(cast);
            }
            
            string paramList = string.Join(", ", paramCasts);
            
            sb.AppendLine("            return width switch");
            sb.AppendLine("            {");
            sb.AppendLine($"                1 => new {className}<byte>({paramList}),");
            sb.AppendLine($"                2 => new {className}<ushort>({paramList}),");
            sb.AppendLine($"                4 => new {className}<uint>({paramList}),");
            sb.AppendLine($"                8 => new {className}<ulong>({paramList}),");
            sb.AppendLine("                _ => throw new TamperCompilationException($\"Invalid instruction width {width} in Atmosphere cheat\")");
            sb.AppendLine("            };");
            sb.AppendLine("        }");
            sb.AppendLine();
        }

        private void GenerateNonGenericFactoryMethod(StringBuilder sb, INamedTypeSymbol operationType)
        {
            string className = operationType.Name;
            
            var constructor = operationType.Constructors
                .Where(c => !c.IsStatic && c.DeclaredAccessibility == Accessibility.Public)
                .OrderBy(c => c.Parameters.Length > 0 && c.Parameters[c.Parameters.Length - 1].IsParams)
                .FirstOrDefault();

            if (constructor == null)
                return;

            var parameters = constructor.Parameters;
            
            sb.AppendLine($"        public static object Create{className}(byte width, params object[] operands)");
            sb.AppendLine("        {");
            
            var paramCasts = new List<string>();
            for (int i = 0; i < parameters.Length; i++)
            {
                string cast = GetParameterCast(parameters[i], i);
                paramCasts.Add(cast);
            }
            
            string paramList = string.Join(", ", paramCasts);
            
            sb.AppendLine($"            return new {className}({paramList});");
            sb.AppendLine("        }");
            sb.AppendLine();
        }

        private string GetParameterCast(IParameterSymbol parameter, int index)
        {
            string typeName = parameter.Type.ToDisplayString();
            
            if (typeName.Contains("IOperand"))
            {
                return $"(IOperand)operands[{index}]";
            }
            else if (typeName.Contains("ICondition"))
            {
                return $"(ICondition)operands[{index}]";
            }
            else if (typeName.Contains("IEnumerable<") && typeName.Contains("IOperation"))
            {
                return $"(System.Collections.Generic.IEnumerable<IOperation>)operands[{index}]";
            }
            else if (typeName == "bool")
            {
                return $"(bool)operands[{index}]";
            }
            else if (typeName == "int")
            {
                return $"(int)operands[{index}]";
            }
            else if (typeName == "byte")
            {
                return $"(byte)operands[{index}]";
            }
            else if (typeName == "ulong")
            {
                return $"(ulong)operands[{index}]";
            }
            else if (typeName.Contains("Register"))
            {
                return $"(Register)operands[{index}]";
            }
            else if (typeName.Contains("ITamperedProcess"))
            {
                return $"(ITamperedProcess)operands[{index}]";
            }
            else
            {
                // fallback :3
                return $"({typeName})operands[{index}]";
            }
        }

        private void GenerateMainFactoryMethod(StringBuilder sb, IEnumerable<INamedTypeSymbol> tamperTypesData)
        {
            sb.AppendLine("        public static object Create(Type instruction, byte width, params object[] operands)");
            sb.AppendLine("        {");

            bool first = true;
            foreach (var tamperType in tamperTypesData)
            {
                string className = tamperType.Name;
                string conditional = first ? "if" : "else if";
                first = false;

                if (tamperType.IsGenericType)
                {
                    sb.AppendLine($"            {conditional} (instruction.IsGenericType && instruction.GetGenericTypeDefinition() == typeof({className}<>))");
                    sb.AppendLine("            {");
                    sb.AppendLine($"                return Create{className}(width, operands);");
                    sb.AppendLine("            }");
                }
                else
                {
                    sb.AppendLine($"            {conditional} (instruction == typeof({className}))");
                    sb.AppendLine("            {");
                    sb.AppendLine($"                return Create{className}(width, operands);");
                    sb.AppendLine("            }");
                }
            }

            sb.AppendLine("            else");
            sb.AppendLine("            {");
            sb.AppendLine("                throw new TamperCompilationException($\"Unsupported instruction type: {instruction.Name}\");");
            sb.AppendLine("            }");
            sb.AppendLine("        }");
        }
    }
}
