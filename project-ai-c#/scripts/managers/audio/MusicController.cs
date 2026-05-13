using System.Collections.Generic;
using Godot;
using ProjectAi.Managers.Core;
using ProjectAi.Managers.Resources;

namespace ProjectAi.Managers.Audio;

/// <summary>
/// 多轨音乐控制器，通过 Tween 实现状态间渐变切换
/// <para>作为 AudioManager 的子节点使用，不独立注册到 GameServices</para>
/// </summary>
public partial class MusicController : Node
{
    private const float FadeDuration = 1.5f;
    private const float SilenceDb = -80f;
    private const float DefaultVolumeDb = 0f;

    private readonly Dictionary<MusicState, string> _trackPaths = new();
    private readonly Dictionary<MusicState, AudioStreamPlayer> _players = new();

    private MusicState _currentState = MusicState.Silence;
    private Tween? _activeTween;

    public MusicState CurrentState => _currentState;

    /// <summary>注册音乐状态对应的资源路径（在游戏初始化时调用）</summary>
    public void RegisterTrack(MusicState state, string resourcePath)
    {
        _trackPaths[state] = resourcePath;
    }

    /// <summary>切换音乐状态，自动渐变</summary>
    public void SetState(MusicState newState)
    {
        if (newState == _currentState) return;

        _activeTween?.Kill();
        _activeTween = CreateTween();
        _activeTween.SetParallel();

        // 渐出当前轨
        if (_currentState != MusicState.Silence && _players.TryGetValue(_currentState, out var outgoing))
        {
            _activeTween.TweenProperty(outgoing, "volume_db", SilenceDb, FadeDuration);
            var capturedOutgoing = outgoing;
            _activeTween.Chain().TweenCallback(Callable.From(() =>
            {
                if (GodotObjectTools.IsAlive(capturedOutgoing))
                    capturedOutgoing.Stop();
            }));
        }

        // 渐入新轨
        if (newState != MusicState.Silence)
        {
            var incoming = GetOrCreatePlayer(newState);
            if (incoming is not null)
            {
                incoming.VolumeDb = SilenceDb;
                if (!incoming.Playing)
                    incoming.Play();
                _activeTween.TweenProperty(incoming, "volume_db", DefaultVolumeDb, FadeDuration);
            }
        }

        _currentState = newState;
    }

    /// <summary>立即停止所有音乐</summary>
    public void StopAll()
    {
        _activeTween?.Kill();
        _activeTween = null;

        foreach (var player in _players.Values)
        {
            if (GodotObjectTools.IsAlive(player))
            {
                player.Stop();
                player.VolumeDb = SilenceDb;
            }
        }

        _currentState = MusicState.Silence;
    }

    private AudioStreamPlayer? GetOrCreatePlayer(MusicState state)
    {
        if (_players.TryGetValue(state, out var existing) && GodotObjectTools.IsAlive(existing))
            return existing;

        if (!_trackPaths.TryGetValue(state, out var path))
            return null;

        var stream = GameServices.Resources?.Load<AudioStream>(path)
                     ?? ResourceLoader.Load<AudioStream>(path);

        if (stream is null)
        {
            GD.PushWarning($"MusicController: 无法加载音乐资源 {path}");
            return null;
        }

        var player = new AudioStreamPlayer
        {
            Name = $"Music_{state}",
            VolumeDb = SilenceDb,
            Bus = "Music",
        };

        AddChild(player);
        player.Stream = stream;
        _players[state] = player;
        return player;
    }
}
