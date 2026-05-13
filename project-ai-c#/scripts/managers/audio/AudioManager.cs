using System;
using System.Collections.Generic;
using Godot;
using ProjectAi.Managers.Core;
using ProjectAi.Managers.Resources;
using SysVec2 = System.Numerics.Vector2;

namespace ProjectAi.Managers.Audio;

/// <summary>
/// 音频管理器 — 实现 IAudioService
/// <para>包含空间 SFX 池（AudioStreamPlayer2D）、UI 音效池（AudioStreamPlayer）、
/// 同类音效并发限制、以及 MusicController 子节点。</para>
/// </summary>
public partial class AudioManager : Node, IAudioService
{
    [Export] public int InitialSfxPlayers { get; set; } = 8;
    [Export] public int InitialUiPlayers { get; set; } = 4;
    [Export] public int MaxSameSoundConcurrent { get; set; } = 3;

    private readonly Queue<AudioStreamPlayer2D> _sfxPool = new();
    private readonly Queue<AudioStreamPlayer> _uiPool = new();
    private readonly Dictionary<string, int> _activeSoundCount = new();

    private MusicController? _music;

    public MusicController Music => _music!;

    public override void _EnterTree()
    {
        GameServices.Audio = this;
    }

    public override void _Ready()
    {
        _music = new MusicController { Name = "MusicController" };
        AddChild(_music);

        for (var i = 0; i < InitialSfxPlayers; i++)
            _sfxPool.Enqueue(CreateSfxPlayer());

        for (var i = 0; i < InitialUiPlayers; i++)
            _uiPool.Enqueue(CreateUiPlayer());
    }

    // ── IAudioService 实现 ──────────────────────────────────

    public void PlaySfx(string soundId, SysVec2 worldPosition)
    {
        if (!TryAcquireConcurrency(soundId)) return;

        var stream = LoadStream(soundId);
        if (stream is null) return;

        var player = GetSfxPlayer();
        player.Stream = stream;
        player.GlobalPosition = new Godot.Vector2(worldPosition.X, worldPosition.Y);
        player.Play();
    }

    public void PlaySfx(string soundId)
    {
        if (!TryAcquireConcurrency(soundId)) return;

        var stream = LoadStream(soundId);
        if (stream is null) return;

        var player = GetSfxPlayer();
        player.Stream = stream;
        player.GlobalPosition = Godot.Vector2.Zero;
        player.Play();
    }

    public void PlayUiSound(string soundId)
    {
        if (!TryAcquireConcurrency(soundId)) return;

        var stream = LoadStream(soundId);
        if (stream is null) return;

        var player = GetUiPlayer();
        player.Stream = stream;
        player.Play();
    }

    public void SetMusicState(MusicState state)
    {
        _music?.SetState(state);
    }

    public void StopAll()
    {
        // 停止所有 SFX
        foreach (var child in GetChildren())
        {
            switch (child)
            {
                case AudioStreamPlayer2D sfx when sfx.Playing:
                    sfx.Stop();
                    break;
                case AudioStreamPlayer ui when ui.Playing && child != _music:
                    ui.Stop();
                    break;
            }
        }

        _activeSoundCount.Clear();
        _music?.StopAll();
    }

    // ── 并发控制 ────────────────────────────────────────────

    private bool TryAcquireConcurrency(string soundId)
    {
        _activeSoundCount.TryGetValue(soundId, out var count);
        if (count >= MaxSameSoundConcurrent) return false;
        _activeSoundCount[soundId] = count + 1;
        return true;
    }

    private void ReleaseConcurrency(string soundId)
    {
        if (!_activeSoundCount.TryGetValue(soundId, out var count)) return;
        if (count <= 1)
            _activeSoundCount.Remove(soundId);
        else
            _activeSoundCount[soundId] = count - 1;
    }

    // ── SFX 池（AudioStreamPlayer2D — 空间音频）────────────

    private AudioStreamPlayer2D GetSfxPlayer()
    {
        return _sfxPool.Count > 0 ? _sfxPool.Dequeue() : CreateSfxPlayer();
    }

    private AudioStreamPlayer2D CreateSfxPlayer()
    {
        var player = new AudioStreamPlayer2D
        {
            Name = $"Sfx2D_{GetChildCount()}",
        };
        AddChild(player);
        player.Finished += () => RecycleSfxPlayer(player);
        return player;
    }

    private void RecycleSfxPlayer(AudioStreamPlayer2D player)
    {
        if (!GodotObjectTools.IsAlive(player)) return;

        var soundId = player.Stream?.ResourcePath;
        if (soundId is not null)
            ReleaseConcurrency(soundId);

        player.Stream = null;
        _sfxPool.Enqueue(player);
    }

    // ── UI 音效池（AudioStreamPlayer — 非空间）─────────────

    private AudioStreamPlayer GetUiPlayer()
    {
        return _uiPool.Count > 0 ? _uiPool.Dequeue() : CreateUiPlayer();
    }

    private AudioStreamPlayer CreateUiPlayer()
    {
        var player = new AudioStreamPlayer
        {
            Name = $"UiSfx_{GetChildCount()}",
            Bus = "UI",
        };
        AddChild(player);
        player.Finished += () => RecycleUiPlayer(player);
        return player;
    }

    private void RecycleUiPlayer(AudioStreamPlayer player)
    {
        if (!GodotObjectTools.IsAlive(player)) return;

        var soundId = player.Stream?.ResourcePath;
        if (soundId is not null)
            ReleaseConcurrency(soundId);

        player.Stream = null;
        _uiPool.Enqueue(player);
    }

    // ── 资源加载 ────────────────────────────────────────────

    private static AudioStream? LoadStream(string soundId)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(soundId);
        return GameServices.Resources?.Load<AudioStream>(soundId)
               ?? ResourceLoader.Load<AudioStream>(soundId);
    }
}
