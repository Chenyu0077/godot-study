using System;
using ProjectAi.Managers.Audio;
using ProjectAi.Managers.Http;
using ProjectAi.Managers.Llm;
using ProjectAi.Managers.Resources;
using ProjectAi.Managers.Save;
using ProjectAi.Managers.Scene;
using ProjectAi.Managers.Ui;

namespace ProjectAi.Managers.Core;

/// <summary>
/// 全局服务定位器 — 所有管理器的静态访问入口
/// <para>各管理器在 _EnterTree 中自注册，GameRoot._ExitTree 时统一 Reset</para>
/// </summary>
public static class GameServices
{
    // ── 纯 C# 服务（无 Godot 依赖） ───────────────────────
    public static EventBus Events { get; } = new();

    // ── Godot Node 管理器 ──────────────────────────────────
    public static GameRoot? Root { get; internal set; }
    public static UILayerManager? UI { get; internal set; }
    public static ResourceService? Resources { get; internal set; }
    public static HttpService? Http { get; internal set; }
    public static SceneService? Scene { get; internal set; }
    public static SaveService? Save { get; internal set; }

    // ── 接口化服务（逻辑层可安全依赖） ─────────────────────
    public static IAudioService? Audio { get; internal set; }
    public static ILlmClient? Llm { get; internal set; }

    /// <summary>重置所有服务引用（场景切换/退出时调用）</summary>
    public static void Reset()
    {
        Events.Clear();

        (Llm as IDisposable)?.Dispose();

        Root = null;
        UI = null;
        Resources = null;
        Audio = null;
        Http = null;
        Scene = null;
        Save = null;
        Llm = null;
    }
}
