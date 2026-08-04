using System;

namespace Ryujinx.Graphics.GAL
{
    public interface IProgram : IDisposable
    {
        bool CanBindWhileIncomplete { get; }

        ProgramLinkStatus CheckProgramLink(bool blocking);

        byte[] GetBinary();
    }
}
