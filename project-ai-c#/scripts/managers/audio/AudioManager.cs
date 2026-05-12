using System;
using System.Collections.Generic;
using Godot;
using ProjectAi.Managers.Core;

namespace ProjectAi.Managers.Audio;

public partial class AudioManager : Node, IAudioService
{
    [Export]
    public int InitialSfxPlayers { get; set; } = 8;

    private readonly Queue<AudioStreamPlayer> _idleSfxPlayers = new();
    private AudioStreamPlayer? _musicPlayer;

    public override void _EnterTree()
    {
        GameServices.Audio = this;
    }

    public override void _Ready()
    {
        _musicPlayer = CreatePlayer("MusicPlayer");

        for (var i = 0; i < InitialSfxPlayers; i++)
        {
            _idleSfxPlayers.Enqueue(CreateSfxPlayer());
        }
    }

    public void PlaySfx(AudioStream stream, float volumeDb = 0f, float pitchScale = 1f)
    {
        ArgumentNullException.ThrowIfNull(stream);

        var player = GetSfxPlayer();
        player.Stream = stream;
        player.VolumeDb = volumeDb;
        player.PitchScale = pitchScale;
        player.Play();
    }

    public void PlaySfx(string resourcePath, float volumeDb = 0f, float pitchScale = 1f)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(resourcePath);
        var stream = GameServices.Resources?.Load<AudioStream>(resourcePath) ?? ResourceLoader.Load<AudioStream>(resourcePath);
        if (stream is not null)
        {
            PlaySfx(stream, volumeDb, pitchScale);
        }
    }

    public void PlayMusic(AudioStream stream, float volumeDb = 0f, bool loop = true)
    {
        ArgumentNullException.ThrowIfNull(stream);

        _musicPlayer ??= CreatePlayer("MusicPlayer");
        stream.Set("loop", loop);
        _musicPlayer.Stream = stream;
        _musicPlayer.VolumeDb = volumeDb;
        _musicPlayer.Play();
    }

    public void StopMusic()
    {
        _musicPlayer?.Stop();
    }

    private AudioStreamPlayer GetSfxPlayer()
    {
        return _idleSfxPlayers.Count > 0 ? _idleSfxPlayers.Dequeue() : CreateSfxPlayer();
    }

    private AudioStreamPlayer CreateSfxPlayer()
    {
        var player = CreatePlayer($"SfxPlayer{GetChildCount()}");
        player.Finished += () => RecycleSfxPlayer(player);
        return player;
    }

    private AudioStreamPlayer CreatePlayer(string nodeName)
    {
        var player = new AudioStreamPlayer { Name = nodeName };
        AddChild(player);
        return player;
    }

    private void RecycleSfxPlayer(AudioStreamPlayer player)
    {
        if (!GodotObjectTools.IsAlive(player))
        {
            return;
        }

        player.Stream = null;
        player.VolumeDb = 0f;
        player.PitchScale = 1f;
        _idleSfxPlayers.Enqueue(player);
    }
}
