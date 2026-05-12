using ProjectAi.Managers.Audio;
using ProjectAi.Managers.Http;
using ProjectAi.Managers.Resources;
using ProjectAi.Managers.Ui;

namespace ProjectAi.Managers.Core;

public static class GameServices
{
    public static EventBus Events { get; } = new();

    public static GameRoot? Root { get; internal set; }
    public static UILayerManager? UI { get; internal set; }
    public static ResourceService? Resources { get; internal set; }
    public static AudioManager? Audio { get; internal set; }
    public static HttpService? Http { get; internal set; }

    public static void Reset()
    {
        Events.Clear();
        Root = null;
        UI = null;
        Resources = null;
        Audio = null;
        Http = null;
    }
}
