using Ryujinx.Common;
using Ryujinx.Graphics.GAL;
using System;
using System.Runtime.InteropServices;

namespace Ryujinx.Graphics.Gpu.Engine.MME
{
    /// <summary>
    /// Table with information about High-level implementations of GPU Macro code.
    /// </summary>
    static class MacroHLETable
    {
        /// <summary>
        /// Macro High-level implementation table entry.
        /// </summary>
        readonly struct TableEntry
        {
            /// <summary>
            /// Name of the Macro function.
            /// </summary>
            public MacroHLEFunctionName Name { get; }

            /// <summary>
            /// Hash of the original binary Macro function code.
            /// </summary>
            public Hash128 Hash { get; }

            /// <summary>
            /// Creates a new table entry.
            /// </summary>
            /// <param name="name">Name of the Macro function</param>
            /// <param name="hash">Hash of the original binary Macro function code</param>
            public TableEntry(MacroHLEFunctionName name, Hash128 hash)
            {
                Name = name;
                Hash = hash;
            }
        }

        /// <summary>
        /// Macro table entries with the same code length.
        /// </summary>
        readonly struct TableGroup
        {
            /// <summary>
            /// Size (in bytes) of the original binary Macro function code.
            /// </summary>
            public int Length { get; }

            /// <summary>
            /// Entries with the given length.
            /// </summary>
            public TableEntry[] Entries { get; }

            /// <summary>
            /// Creates a new table group.
            /// </summary>
            /// <param name="length">Size (in bytes) of the original binary Macro function code</param>
            /// <param name="entries">Entries with the given length</param>
            public TableGroup(int length, TableEntry[] entries)
            {
                Length = length;
                Entries = entries;
            }
        }

        private static readonly TableGroup[] _groups =
        [
            new(0x68,
            [
                new(MacroHLEFunctionName.BindShaderProgram, new Hash128(0x5d5efb912369f60b, 0x69131ed5019f08ef)),
            ]),
            new(0x28,
            [
                new(MacroHLEFunctionName.ClearColor, new Hash128(0xA9FB28D1DC43645A, 0xB177E5D2EAE67FB0)),
                new(MacroHLEFunctionName.UpdateBlendState, new Hash128(0x40F6D4E7B08D7640, 0x82167BEEAECB959F)),
            ]),
            new(0x24,
            [
                new(MacroHLEFunctionName.ClearDepthStencil, new Hash128(0x1B96CB77D4879F4F, 0x8557032FE0C965FB)),
                new(MacroHLEFunctionName.UpdateColorMasks, new Hash128(0x9EE32420B8441DFD, 0x6E7724759A57333E)),
            ]),
            new(0x48,
            [
                new(MacroHLEFunctionName.DrawArraysInstanced, new Hash128(0x197FB416269DBC26, 0x34288C01DDA82202)),
            ]),
            new(0x20,
            [
                new(MacroHLEFunctionName.DrawElements, new Hash128(0x3D7F32AE6C2702A7, 0x9353C9F41C1A244D)),
                new(MacroHLEFunctionName.UpdateUniformBufferState, new Hash128(0x8EE66706049CB0B0, 0x51C1CF906EC86F7C)),
            ]),
            new(0x5c,
            [
                new(MacroHLEFunctionName.DrawElementsInstanced, new Hash128(0x1A501FD3D54EC8E0, 0x6CF570CF79DA74D6)),
            ]),
            new(0x7c,
            [
                new(MacroHLEFunctionName.DrawElementsIndirect, new Hash128(0x86A3E8E903AF8F45, 0xD35BBA07C23860A4)),
            ]),
            new(0x19C,
            [
                new(MacroHLEFunctionName.MultiDrawElementsIndirectCount, new Hash128(0x890AF57ED3FB1C37, 0x35D0C95C61F5386F)),
            ]),
            new(0x18,
            [
                new(MacroHLEFunctionName.UpdateUniformBufferStateCbu, new Hash128(0xA4592676A3E581A0, 0xA39E77FE19FE04AC)),
                new(MacroHLEFunctionName.UpdateUniformBufferStateCbuV2, new Hash128(0x392FA750489983D4, 0x35BACE455155D2C3)),
            ]),
        ];

        /// <summary>
        /// Checks if the host supports all features required by the HLE macro.
        /// </summary>
        /// <param name="caps">Host capabilities</param>
        /// <param name="name">Name of the HLE macro to be checked</param>
        /// <returns>True if the host supports the HLE macro, false otherwise</returns>
        private static bool IsMacroHLESupported(Capabilities caps, MacroHLEFunctionName name)
        {
            if (name == MacroHLEFunctionName.MultiDrawElementsIndirectCount)
            {
                return caps.SupportsIndirectParameters;
            }
            else if (name != MacroHLEFunctionName.None)
            {
                return true;
            }

            return false;
        }

        /// <summary>
        /// Checks if there's a fast, High-level implementation of the specified Macro code available.
        /// </summary>
        /// <param name="code">Macro code to be checked</param>
        /// <param name="caps">Renderer capabilities to check for this macro HLE support</param>
        /// <param name="name">Name of the function if a implementation is available and supported, otherwise <see cref="MacroHLEFunctionName.None"/></param>
        /// <returns>True if there is a implementation available and supported, false otherwise</returns>
        public static bool TryGetMacroHLEFunction(ReadOnlySpan<int> code, Capabilities caps, out MacroHLEFunctionName name)
        {
            ReadOnlySpan<byte> mc = MemoryMarshal.Cast<int, byte>(code);

            for (int i = 0; i < _groups.Length; i++)
            {
                TableGroup group = _groups[i];

                if (mc.Length < group.Length)
                {
                    continue;
                }

                Hash128 hash = Hash128.ComputeHash(mc[..group.Length]);
                TableEntry[] entries = group.Entries;

                for (int j = 0; j < entries.Length; j++)
                {
                    ref TableEntry entry = ref entries[j];

                    if (hash == entry.Hash)
                    {
                        if (IsMacroHLESupported(caps, entry.Name))
                        {
                            name = entry.Name;
                            return true;
                        }

                        break;
                    }
                }
            }

            name = MacroHLEFunctionName.None;
            return false;
        }
    }
}
