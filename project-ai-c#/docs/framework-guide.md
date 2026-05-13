# Godot C# 轻量级 Core 框架 — 使用指南

## 架构概览

```
三层结构
┌─────────────────────────────────────────────────┐
│  纯 C# 逻辑层（无引擎依赖）                       │
│  CombatManager, AgentAI, CardModel, Hook...     │
│  依赖接口: IAudioService, ILlmClient, IGameEvent │
├─────────────────────────────────────────────────┤
│  Godot Node 层（partial class）                   │
│  NCard, NCreature, NCombatUi...                 │
│  框架管理器: AudioManager, SaveService...        │
├─────────────────────────────────────────────────┤
│  Godot 场景文件（.tscn）                          │
│  节点层级 + 初始属性配置                           │
└─────────────────────────────────────────────────┘
```

所有管理器通过 `GameServices` 静态类访问，`GameRoot` 节点负责自动初始化。

---

## 1. 快速开始

### 1.1 场景搭建

在主场景根节点挂载 `GameRoot` 脚本即可，框架会自动创建所有子管理器：

```
MainScene (Node)
└── GameRoot (GameRoot.cs)     ← 挂上脚本，其他自动创建
    ├── UI          (自动)
    ├── Resources   (自动)
    ├── Audio       (自动)
    ├── Http        (自动)
    ├── Scene       (自动)
    └── Save        (自动)
```

如果想在编辑器里手动排列子节点（比如配置 Export 属性），把 `CreateDefaultManagers` 设为 `false`，
框架会从子节点中查找已有的管理器。

### 1.2 在任意脚本中使用

```csharp
using ProjectAi.Managers.Core;

// 所有服务通过 GameServices 静态访问，无需依赖注入
GameServices.Audio?.PlaySfx("res://assets/audio/hit.ogg");
GameServices.Events.Publish(new DayStartedEvent(Day: 3, SunriseTime: 6.0f));
```

---

## 2. 事件系统（EventBus）

用于**跨系统的世界级广播**，如日夜切换、Agent 死亡等。

### 2.1 定义事件

```csharp
using ProjectAi.Managers.Core;

// 事件必须实现 IGameEvent，推荐用 sealed record
public sealed record AgentHungryEvent(AgentId AgentId, float HungerLevel) : IGameEvent;
public sealed record WeatherChangedEvent(string Weather) : IGameEvent;
```

### 2.2 订阅事件

```csharp
public partial class WeatherUI : Control
{
    private EventSubscription? _subscription;

    public override void _EnterTree()
    {
        // Subscribe 返回 IDisposable，用于取消订阅
        _subscription = GameServices.Events.Subscribe<WeatherChangedEvent>(OnWeatherChanged);
    }

    public override void _ExitTree()
    {
        // 必须取消订阅，否则节点销毁后回调会访问已释放对象
        _subscription?.Dispose();
    }

    private void OnWeatherChanged(WeatherChangedEvent e)
    {
        GD.Print($"天气变为: {e.Weather}");
    }
}
```

### 2.3 发布事件

```csharp
GameServices.Events.Publish(new WeatherChangedEvent("Rain"));
```

### 2.4 三种事件模式（何时用什么）

| 场景 | 方式 | 示例 |
|------|------|------|
| 对象自身状态变化 | C# 原生 `event` | `Agent.HungerChanged += ...` |
| 跨系统世界广播 | `EventBus` | `DayStartedEvent`, `AgentDiedEvent` |
| UI 输入事件 | Godot Signal | `Button.Pressed`, 点击 Agent |

---

## 3. 音频系统（AudioManager）

### 3.1 播放音效

```csharp
// 播放空间音效（有 2D 定位）
GameServices.Audio?.PlaySfx("res://assets/audio/footstep.ogg",
    new System.Numerics.Vector2(100, 200));

// 播放全局音效（无定位）
GameServices.Audio?.PlaySfx("res://assets/audio/levelup.ogg");

// 播放 UI 音效（不受游戏暂停影响）
GameServices.Audio?.PlayUiSound("res://assets/audio/click.ogg");
```

### 3.2 音乐系统

```csharp
// 先注册各状态对应的音乐资源（通常在游戏初始化时）
var audioManager = GameServices.Audio as AudioManager;
audioManager?.Music.RegisterTrack(MusicState.Day, "res://assets/audio/music_day.ogg");
audioManager?.Music.RegisterTrack(MusicState.Night, "res://assets/audio/music_night.ogg");
audioManager?.Music.RegisterTrack(MusicState.Combat, "res://assets/audio/music_combat.ogg");

// 切换音乐状态（自动 1.5s 渐变过渡）
GameServices.Audio?.SetMusicState(MusicState.Day);

// 进入战斗
GameServices.Audio?.SetMusicState(MusicState.Combat);

// 静音
GameServices.Audio?.SetMusicState(MusicState.Silence);
```

### 3.3 并发限制

同一个 soundId 最多同时播放 3 个实例（可通过 `MaxSameSoundConcurrent` Export 属性调整）。
超出时静默忽略，不会报错。适用于脚步声、碰撞音等高频音效。

### 3.4 逻辑层使用（纯 C#）

逻辑层通过 `IAudioService` 接口依赖音频，不需要知道 Godot 存在：

```csharp
// 纯 C# 逻辑类
public class CombatManager
{
    private readonly IAudioService _audio;

    public CombatManager(IAudioService audio)
    {
        _audio = audio;
    }

    public void OnAttackHit(System.Numerics.Vector2 position)
    {
        _audio.PlaySfx("res://assets/audio/hit.ogg", position);
    }
}
```

---

## 4. 资源管理（ResourceService）

### 4.1 同步加载

```csharp
var texture = GameServices.Resources?.Load<Texture2D>("res://assets/images/player.png");
```

### 4.2 异步加载（不卡帧）

```csharp
var texture = await GameServices.Resources?.LoadAsync<Texture2D>("res://assets/images/boss.png");
```

### 4.3 缓存策略

- 内部使用 `WeakReference<Resource>` — 资源没有其他引用时 GC 自动回收
- 换场景时主动清理缓存：

```csharp
GameServices.Resources?.ClearCache(trimDeadOnly: false);
GC.Collect();  // 大场景切换时可主动触发一次
```

---

## 5. UI 层级管理（UILayerManager）

### 5.1 层级结构

```
UILayerManager (CanvasLayer)
├── Background  (z=0)   ← 背景
├── Hud         (z=10)  ← 游戏内 HUD
├── Window      (z=20)  ← 全屏界面（菜单、背包）
├── Popup       (z=30)  ← 弹窗 / Tooltip
├── Toast       (z=40)  ← 通知消息
└── Loading     (z=50)  ← 加载界面（最顶层）
```

### 5.2 添加 UI

```csharp
// 从 PackedScene 实例化并添加到指定层
var inventoryScene = GD.Load<PackedScene>("res://scenes/ui/Inventory.tscn");
var inventory = GameServices.UI?.AddScene<Control>(inventoryScene, UILayer.Window);

// 添加已有节点
var tooltip = new Label { Text = "提示信息" };
GameServices.UI?.AddNode(tooltip, UILayer.Popup);

// 置顶
GameServices.UI?.BringToFront(inventory);

// 清空某层
GameServices.UI?.ClearLayer(UILayer.Popup);
```

---

## 6. 对象池（NodePool / ObjectPool）

### 6.1 Node 池（用于高频创建/销毁的 Godot 节点）

```csharp
var bulletScene = GD.Load<PackedScene>("res://scenes/entities/Bullet.tscn");
var bulletPool = new NodePool<Bullet>(bulletScene, parentNode);

// 获取
var bullet = bulletPool.Get();   // 自动设 Visible=true, ProcessMode=Inherit
bullet.GlobalPosition = spawnPos;

// 归还
bulletPool.Release(bullet);      // 自动设 Visible=false, ProcessMode=Disabled

// 清理（场景切换时）
bulletPool.Clear();              // QueueFree 所有池中节点
```

### 6.2 纯 C# 对象池

```csharp
var pool = new ObjectPool<DamageInfo>(
    create: () => new DamageInfo(),
    onGet: info => info.Reset(),
    onRelease: null
);

var info = pool.Get();
info.Amount = 50;
// ... 使用 ...
pool.Release(info);
```

### 6.3 什么需要池化

| 需要池化 | 不需要池化 |
|----------|------------|
| 高频创建+销毁的 Godot Node（子弹、对话气泡、伤害数字） | 纯 C# 对象 → 交给 GC |
| 粒子特效实例 | 生命周期稳定的节点（常驻 UI） |

---

## 7. 场景管理（SceneService）

### 7.1 异步切换场景

```csharp
await GameServices.Scene?.ChangeSceneAsync("res://scenes/levels/Level2.tscn");
```

### 7.2 带加载界面

在编辑器中给 `SceneService` 节点设置 `LoadingScreenScene` 属性，
切换时会自动显示加载界面到 `UILayer.Loading` 层。

```csharp
// 也可以代码设置
var sceneService = GameServices.Scene;
sceneService.LoadingScreenScene = GD.Load<PackedScene>("res://scenes/ui/LoadingScreen.tscn");

await sceneService.ChangeSceneAsync("res://scenes/levels/Level3.tscn");
```

### 7.3 加载进度

```csharp
// 在 LoadingScreen 的 _Process 中读取进度
public override void _Process(double delta)
{
    if (GameServices.Scene is not null)
        _progressBar.Value = GameServices.Scene.LoadProgress;
}
```

---

## 8. 存档系统（SaveService）

### 8.1 保存 / 加载

```csharp
// 定义存档数据结构（推荐用 record 或 class）
public record GameSaveData
{
    public int Day { get; init; }
    public float PlayTime { get; init; }
    public List<AgentSaveData> Agents { get; init; } = new();
}

// 保存
var data = new GameSaveData { Day = 5, PlayTime = 3600f };
GameServices.Save?.Save("slot1", data);
// 文件写入 user://saves/slot1.json

// 加载
var loaded = GameServices.Save?.Load<GameSaveData>("slot1");
if (loaded is not null)
    GD.Print($"读档: 第 {loaded.Day} 天");
```

### 8.2 其他操作

```csharp
// 检查存档是否存在
if (GameServices.Save?.HasSave("slot1") == true) { ... }

// 列出所有槽位
string[] slots = GameServices.Save?.ListSlots() ?? Array.Empty<string>();

// 删除存档
GameServices.Save?.Delete("slot1");
```

### 8.3 序列化说明

- 使用 `System.Text.Json`（.NET 8 内置），默认 camelCase 属性名
- 文件 I/O 通过 Godot `FileAccess`（支持 `user://` 跨平台路径）
- 支持 `record`、可空类型、嵌套对象、List/Dictionary 等

---

## 9. LLM 客户端（LlmClient）

### 9.1 配置

在 `user://llm_config.json` 创建配置文件（不进版本控制）：

```json
{
  "endpoint": "https://api.openai.com/v1",
  "apiKey": "sk-xxx",
  "model": "gpt-4o",
  "provider": "OpenAi",
  "maxConcurrent": 2,
  "budgetMaxTokens": 100000,
  "maxRetries": 3
}
```

`GameRoot` 启动时自动读取并初始化 `GameServices.Llm`。
配置文件不存在时 LLM 服务为 null，不影响其他系统运行。

### 9.2 支持的 Provider

| Provider | endpoint 示例 | 说明 |
|----------|---------------|------|
| `OpenAi` | `https://api.openai.com/v1` | 也兼容 Ollama 等 OpenAI 兼容 API |
| `Anthropic` | `https://api.anthropic.com/v1` | Anthropic Messages API |

Ollama 本地部署示例：
```json
{
  "endpoint": "http://localhost:11434/v1",
  "apiKey": "ollama",
  "model": "llama3",
  "provider": "OpenAi",
  "maxConcurrent": 1,
  "budgetMaxTokens": 0
}
```

### 9.3 补全请求

```csharp
var response = await GameServices.Llm!.CompleteAsync(new LlmRequest(
    Prompt: "用一句话描述今天的天气",
    MaxTokens: 100,
    Temperature: 0.8f,
    SystemPrompt: "你是一个 AI 小镇里的天气播报员"
));

GD.Print(response.Text);
GD.Print($"Token 用量: {response.PromptTokens} + {response.CompletionTokens}");
GD.Print($"来自缓存: {response.FromCache}");
```

### 9.4 流式输出

```csharp
var request = new LlmRequest(
    Prompt: "给 Agent Alice 写一段内心独白",
    MaxTokens: 200
);

await foreach (var token in GameServices.Llm!.StreamCompleteAsync(request))
{
    // 逐 token 到达，适合打字机效果
    _dialogLabel.Text += token;
}
```

### 9.5 优先级与预算

```csharp
// 高优先级请求（如玩家主动对话）优先通过并发限制
var urgent = new LlmRequest(
    Prompt: "玩家问: 你好吗?",
    Priority: LlmPriority.Critical,
    MaxTokens: 100
);

// 低优先级请求（如后台 Agent 自言自语）
var background = new LlmRequest(
    Prompt: "Alice 在想什么...",
    Priority: LlmPriority.Low,
    MaxTokens: 50
);

// 预算耗尽时抛出 LlmBudgetExceededException
try
{
    await GameServices.Llm!.CompleteAsync(request);
}
catch (LlmBudgetExceededException e)
{
    GD.Print($"Token 预算耗尽: {e.Message}");
}
```

### 9.6 取消请求

```csharp
var cts = new CancellationTokenSource();

// 在另一处取消（如玩家跳过对话）
cts.Cancel();

var request = new LlmRequest(
    Prompt: "...",
    CancellationToken: cts.Token
);

try
{
    await GameServices.Llm!.CompleteAsync(request);
}
catch (TaskCanceledException)
{
    GD.Print("请求已取消");
}
```

---

## 10. HTTP 服务（HttpService）

用于通用 HTTP 请求（非 LLM 场景，如排行榜、资产下载等）：

```csharp
// GET
var result = await GameServices.Http!.GetAsync("https://api.example.com/leaderboard");
if (result.IsSuccessStatusCode)
    GD.Print(result.BodyAsUtf8);

// POST JSON
var json = """{"name": "Player1", "score": 9999}""";
var result = await GameServices.Http!.PostJsonAsync("https://api.example.com/score", json);
```

---

## 11. Godot 对象生命周期安全

### 11.1 核心问题

Godot Node 有双重生命周期：C++ 引擎侧 + C# 包装器。
`QueueFree()` 后 C++ 侧释放，但 C# 引用还在 — 访问会崩溃。

### 11.2 安全工具

```csharp
using ProjectAi.Managers.Core;

// 检查对象是否还有效
if (GodotObjectTools.IsAlive(someNode))
    someNode.Position = Vector2.Zero;

// 安全释放
GodotObjectTools.QueueFreeIfAlive(someNode);
GodotObjectTools.DisposeIfAlive(someObject);
```

### 11.3 信号/事件订阅的黄金法则

```csharp
public partial class MyNode : Node2D
{
    private EventSubscription? _sub;

    public override void _EnterTree()
    {
        // 订阅
        _sub = GameServices.Events.Subscribe<DayStartedEvent>(OnDayStarted);
        SomeManager.Instance.StateChanged += OnStateChanged;
    }

    public override void _ExitTree()
    {
        // 必须取消订阅 — 最常见的内存泄漏源
        _sub?.Dispose();
        SomeManager.Instance.StateChanged -= OnStateChanged;
    }
}
```

---

## 12. 完整 API 速查

```csharp
// ── 事件 ──
GameServices.Events.Subscribe<T>(handler)   → EventSubscription (IDisposable)
GameServices.Events.Publish(event)
GameServices.Events.Unsubscribe<T>(handler)

// ── 音频 ──
GameServices.Audio.PlaySfx(soundId, position?)
GameServices.Audio.PlayUiSound(soundId)
GameServices.Audio.SetMusicState(MusicState)
GameServices.Audio.StopAll()

// ── 资源 ──
GameServices.Resources.Load<T>(path)          → T
GameServices.Resources.LoadAsync<T>(path)     → Task<T>
GameServices.Resources.ClearCache(trimDeadOnly)

// ── UI ──
GameServices.UI.AddScene<T>(scene, layer)     → T
GameServices.UI.AddNode(node, layer)
GameServices.UI.GetLayer(layer)               → Control
GameServices.UI.BringToFront(node)
GameServices.UI.ClearLayer(layer)

// ── 场景 ──
GameServices.Scene.ChangeSceneAsync(path)     → Task
GameServices.Scene.LoadProgress               → float [0,1]
GameServices.Scene.IsLoading                  → bool

// ── 存档 ──
GameServices.Save.Save<T>(slot, data)         → bool
GameServices.Save.Load<T>(slot)               → T?
GameServices.Save.HasSave(slot)               → bool
GameServices.Save.Delete(slot)
GameServices.Save.ListSlots()                 → string[]

// ── LLM ──
GameServices.Llm.CompleteAsync(request)       → Task<LlmResponse>
GameServices.Llm.StreamCompleteAsync(request) → IAsyncEnumerable<string>

// ── HTTP ──
GameServices.Http.GetAsync(url, headers?)     → Task<HttpResult>
GameServices.Http.PostJsonAsync(url, body)    → Task<HttpResult>
```

---

## 13. 文件结构一览

```
scripts/managers/
├── core/
│   ├── GameRoot.cs            游戏根节点，自动创建/发现所有管理器
│   ├── GameServices.cs        全局服务定位器
│   ├── EventBus.cs            类型安全事件总线
│   ├── EventSubscription.cs   可释放的订阅句柄
│   ├── IGameEvent.cs          事件标记接口
│   ├── GameEvents.cs          预定义事件 + ID 类型
│   └── GodotObjectTools.cs    Godot 对象生命周期工具
├── audio/
│   ├── IAudioService.cs       纯 C# 音频接口
│   ├── AudioManager.cs        空间SFX池 + UI池 + 并发限制
│   ├── AudioTypes.cs          SoundId, MusicState
│   └── MusicController.cs     多轨 Tween 音乐渐变
├── http/
│   ├── HttpService.cs         Godot HttpRequest 异步封装
│   └── HttpResult.cs          HTTP 响应结果
├── resources/
│   └── ResourceService.cs     WeakReference 资源缓存 + 异步加载
├── ui/
│   ├── UILayerManager.cs      枚举式 UI 层级容器
│   └── UILayer.cs             层级枚举定义
├── pooling/
│   ├── ObjectPool.cs          通用对象池
│   └── NodePool.cs            Godot Node 专用池
├── scene/
│   └── SceneService.cs        异步场景加载 + 加载界面
├── save/
│   └── SaveService.cs         JSON 存档（System.Text.Json + FileAccess）
└── llm/
    ├── ILlmClient.cs          LLM 客户端接口
    ├── LlmModels.cs           请求/响应/配置数据类型
    ├── LlmClient.cs           核心实现（HttpClient + 队列 + 预算 + 缓存）
    ├── LlmResponseCache.cs    LRU 内存缓存
    └── LlmRequestFormatter.cs OpenAI + Anthropic 格式化器
```
