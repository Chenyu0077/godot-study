namespace ProjectAi.Managers.Audio;

/// <summary>音频资源标识（值为资源路径，如 "res://assets/audio/hit.ogg"）</summary>
public readonly record struct SoundId(string Value)
{
    public static implicit operator SoundId(string value) => new(value);
    public static implicit operator string(SoundId id) => id.Value;
    public override string ToString() => Value;
}

/// <summary>音乐状态，用于多轨渐变切换</summary>
public enum MusicState
{
    Silence,
    Day,
    Night,
    Event,
    Combat,
}
