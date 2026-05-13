using Godot;
using ProjectAi.Managers.Audio;
using ProjectAi.Managers.Http;
using ProjectAi.Managers.Llm;
using ProjectAi.Managers.Resources;
using ProjectAi.Managers.Save;
using ProjectAi.Managers.Scene;
using ProjectAi.Managers.Ui;

namespace ProjectAi.Managers.Core;

/// <summary>
/// 游戏根节点 — 负责初始化和注册所有管理器
/// <para>挂载到场景根节点，自动创建或发现子管理器节点</para>
/// </summary>
public partial class GameRoot : Node
{
    [Export] public bool CreateDefaultManagers { get; set; } = true;

    /// <summary>LLM 配置文件路径（user:// 下，不进版本控制）</summary>
    [Export] public string LlmConfigPath { get; set; } = "user://llm_config.json";

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
        GameServices.Scene ??= EnsureChild<SceneService>("Scene");
        GameServices.Save ??= EnsureChild<SaveService>("Save");

        InitLlmClient();
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
        GameServices.Scene ??= GetNodeOrNull<SceneService>("Scene");
        GameServices.Save ??= GetNodeOrNull<SaveService>("Save");

        InitLlmClient();
    }

    /// <summary>从配置文件初始化 LLM 客户端（纯 C# 对象，非 Node）</summary>
    private void InitLlmClient()
    {
        if (GameServices.Llm is not null) return;

        var config = LoadLlmConfig();
        if (config is null) return;

        GameServices.Llm = new LlmClient(config);
    }

    private LlmClientConfig? LoadLlmConfig()
    {
        if (!FileAccess.FileExists(LlmConfigPath))
        {
            GD.Print($"GameRoot: LLM 配置文件不存在 ({LlmConfigPath})，跳过 LLM 初始化");
            return null;
        }

        using var file = FileAccess.Open(LlmConfigPath, FileAccess.ModeFlags.Read);
        if (file is null) return null;

        var json = file.GetAsText();
        try
        {
            return System.Text.Json.JsonSerializer.Deserialize<LlmClientConfig>(json);
        }
        catch (System.Text.Json.JsonException e)
        {
            GD.PushError($"GameRoot: LLM 配置解析失败: {e.Message}");
            return null;
        }
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
