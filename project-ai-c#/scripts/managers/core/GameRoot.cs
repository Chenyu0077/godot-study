using Godot;
using ProjectAi.Managers.Audio;
using ProjectAi.Managers.Http;
using ProjectAi.Managers.Resources;
using ProjectAi.Managers.Ui;

namespace ProjectAi.Managers.Core;

public partial class GameRoot : Node
{
    [Export]
    public bool CreateDefaultManagers { get; set; } = true;

    public override void _EnterTree()
    {
        GameServices.Root = this;
    }

    public override void _Ready()
    {
        if (!CreateDefaultManagers)
        {
            RegisterManagersFromChildren();
            return;
        }

        GameServices.UI ??= EnsureChild<UILayerManager>("UI");
        GameServices.Resources ??= EnsureChild<ResourceService>("Resources");
        GameServices.Audio ??= EnsureChild<AudioManager>("Audio");
        GameServices.Http ??= EnsureChild<HttpService>("Http");
    }

    public override void _ExitTree()
    {
        if (GameServices.Root == this)
        {
            GameServices.Reset();
        }
    }

    private void RegisterManagersFromChildren()
    {
        GameServices.UI ??= GetNodeOrNull<UILayerManager>("UI");
        GameServices.Resources ??= GetNodeOrNull<ResourceService>("Resources");
        GameServices.Audio ??= GetNodeOrNull<AudioManager>("Audio");
        GameServices.Http ??= GetNodeOrNull<HttpService>("Http");
    }

    private T EnsureChild<T>(string nodeName) where T : Node, new()
    {
        var existing = GetNodeOrNull<T>(nodeName);
        if (existing is not null)
        {
            return existing;
        }

        var child = new T { Name = nodeName };
        AddChild(child);
        return child;
    }
}
