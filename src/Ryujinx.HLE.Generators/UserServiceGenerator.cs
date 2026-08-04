using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;
using System;
using System.Collections.Generic;
using System.Linq;

namespace Ryujinx.HLE.Generators
{
    [Generator]
    public sealed class UserServiceGenerator : IIncrementalGenerator
    {
        private sealed class ServiceData : IEquatable<ServiceData>
        {
            public string FullName { get; }
            public IReadOnlyList<(string ServiceName, string ParameterValue)> Instances { get; }

            public ServiceData(
                string fullName,
                IReadOnlyList<(string ServiceName, string ParameterValue)> instances)
            {
                FullName = fullName ?? throw new ArgumentNullException(nameof(fullName));
                Instances = instances ?? throw new ArgumentNullException(nameof(instances));
            }

            public override bool Equals(object obj)
                => obj is ServiceData other && Equals(other);

            public bool Equals(ServiceData other)
            {
                if (other == null) return false;

                return FullName == other.FullName
                    && Instances.SequenceEqual(other.Instances);
            }

            public override int GetHashCode() => FullName.GetHashCode();
        }

        
        public void Initialize(IncrementalGeneratorInitializationContext context)
        {
            IncrementalValuesProvider<ServiceData> pipeline =
                context.SyntaxProvider.ForAttributeWithMetadataName(
                "Ryujinx.HLE.HOS.Services.ServiceAttribute",
                predicate: (node, _) =>
                    node is ClassDeclarationSyntax decl &&
                    !decl.Modifiers.Any(SyntaxKind.AbstractKeyword) &&
                    !decl.Modifiers.Any(SyntaxKind.PrivateKeyword),
                transform: (ctx, _) =>
                {
                    var target = (INamedTypeSymbol)ctx.TargetSymbol;

                    var instances = ctx.Attributes.Select(attr =>
                    {
                        string param = null;

                        if (attr.ConstructorArguments.Length > 1 &&
                            !attr.ConstructorArguments[1].IsNull)
                        {
                            param = attr.ConstructorArguments[1].ToCSharpString();
                        }

                        return ((string)attr.ConstructorArguments[0].Value, param);
                    }).ToList();

                    return new ServiceData(
                        target.ToDisplayString(SymbolDisplayFormat.FullyQualifiedFormat),
                        instances
                    );
                }
            );

            
            context.RegisterSourceOutput(pipeline.Collect(),
                (ctx, data) =>
                {
                    var generator = new CodeGenerator();
                    
                    generator.AppendLine("#nullable enable");
                    generator.AppendLine("using System;");
                    generator.EnterScope("namespace Ryujinx.HLE.HOS.Services.Sm");
                    generator.EnterScope("partial class IUserInterface");

                    generator.EnterScope("public IpcService? GetServiceInstance(string name, ServiceCtx context)");
                    
                    generator.EnterScope("return name switch");

                    foreach (ServiceData serviceImpl in data)
                    {
                        foreach ((string ServiceName, string ParameterValue) instance in serviceImpl.Instances)
                        {
                            if (instance.ParameterValue == null)
                            {
                                generator.AppendLine($"\"{instance.ServiceName}\" => new {serviceImpl.FullName}(context),");
                            }
                            else
                            {
                                generator.AppendLine($"\"{instance.ServiceName}\" => new {serviceImpl.FullName}(context, {instance.ParameterValue}),");
                            }
                        }
                    }
                    
                    generator.AppendLine("_ => null,");
                    
                    generator.LeaveScope(";");
                    
                    generator.LeaveScope();

                    generator.LeaveScope();
                    generator.LeaveScope();
                    
                    generator.AppendLine("#nullable disable");
                    
                    ctx.AddSource("IUserInterface.g.cs", generator.ToString());
                });
        }
    }
}
