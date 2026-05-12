using Godot;

namespace ProjectAi.Managers.Audio;

public interface IAudioService
{
    void PlaySfx(AudioStream stream, float volumeDb = 0f, float pitchScale = 1f);

    void PlaySfx(string resourcePath, float volumeDb = 0f, float pitchScale = 1f);

    void PlayMusic(AudioStream stream, float volumeDb = 0f, bool loop = true);

    void StopMusic();
}
