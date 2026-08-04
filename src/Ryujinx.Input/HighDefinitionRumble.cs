namespace Ryujinx.Input
{
    public readonly struct GamepadVibrationValue
    {
        public float AmplitudeLow { get; }
        public float FrequencyLow { get; }
        public float AmplitudeHigh { get; }
        public float FrequencyHigh { get; }

        public GamepadVibrationValue(float amplitudeLow, float frequencyLow, float amplitudeHigh, float frequencyHigh)
        {
            AmplitudeLow = amplitudeLow;
            FrequencyLow = frequencyLow;
            AmplitudeHigh = amplitudeHigh;
            FrequencyHigh = frequencyHigh;
        }
    }

    public interface IHighDefinitionRumbleGamepad
    {
        void Rumble(GamepadVibrationValue leftVibration, GamepadVibrationValue rightVibration, uint durationMs);
    }
}
