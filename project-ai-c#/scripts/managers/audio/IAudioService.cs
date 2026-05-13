using SysVec2 = System.Numerics.Vector2;

namespace ProjectAi.Managers.Audio;

/// <summary>
/// 音频服务接口（纯 C#，逻辑层可安全依赖）
/// <para>soundId 统一使用资源路径，如 "res://assets/audio/hit.ogg"</para>
/// </summary>
public interface IAudioService
{
    /// <summary>播放空间音效（带世界坐标定位）</summary>
    void PlaySfx(string soundId, SysVec2 worldPosition);

    /// <summary>播放非空间音效（全局音量，无定位）</summary>
    void PlaySfx(string soundId);

    /// <summary>播放 UI 音效（不受游戏暂停影响）</summary>
    void PlayUiSound(string soundId);

    /// <summary>切换音乐状态（多轨渐变）</summary>
    void SetMusicState(MusicState state);

    /// <summary>停止所有音频（SFX + Music）</summary>
    void StopAll();
}
