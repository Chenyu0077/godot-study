using System.Threading.Tasks;
using Godot;
using ProjectAi.Managers.Core;
using ProjectAi.Managers.Ui;

namespace ProjectAi.Managers.Scene;

/// <summary>
/// 场景管理服务 — 异步加载场景 + 可选加载界面
/// </summary>
public partial class SceneService : Node
{
    [Export] public PackedScene? LoadingScreenScene { get; set; }

    private float _loadProgress;
    private bool _isLoading;

    /// <summary>当前加载进度 [0, 1]</summary>
    public float LoadProgress => _loadProgress;

    /// <summary>是否正在加载场景</summary>
    public bool IsLoading => _isLoading;

    public override void _EnterTree()
    {
        GameServices.Scene = this;
    }

    /// <summary>异步切换场景（不卡主线程）</summary>
    public async Task ChangeSceneAsync(string scenePath)
    {
        if (_isLoading)
        {
            GD.PushWarning("SceneService: 已有场景正在加载中");
            return;
        }

        _isLoading = true;
        _loadProgress = 0f;

        // 可选：显示加载界面
        Node? loadingScreen = null;
        if (LoadingScreenScene is not null && GameServices.UI is not null)
        {
            loadingScreen = LoadingScreenScene.Instantiate();
            GameServices.UI.AddNode(loadingScreen, UILayer.Loading);
        }

        // 发起异步加载
        var error = ResourceLoader.LoadThreadedRequest(scenePath);
        if (error != Error.Ok)
        {
            GD.PushError($"SceneService: 异步加载请求失败 {scenePath}, error={error}");
            Cleanup(loadingScreen);
            return;
        }

        // 轮询加载进度
        var progress = new Godot.Collections.Array();
        while (true)
        {
            var status = ResourceLoader.LoadThreadedGetStatus(scenePath, progress);

            if (status == ResourceLoader.ThreadLoadStatus.Loaded)
            {
                _loadProgress = 1f;
                break;
            }

            if (status == ResourceLoader.ThreadLoadStatus.Failed
                || status == ResourceLoader.ThreadLoadStatus.InvalidResource)
            {
                GD.PushError($"SceneService: 加载失败 {scenePath}, status={status}");
                Cleanup(loadingScreen);
                return;
            }

            // 更新进度
            if (progress.Count > 0)
                _loadProgress = (float)progress[0];

            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }

        // 切换场景
        var scene = ResourceLoader.LoadThreadedGet(scenePath) as PackedScene;
        if (scene is not null)
            GetTree().ChangeSceneToPacked(scene);

        Cleanup(loadingScreen);
    }

    private void Cleanup(Node? loadingScreen)
    {
        GodotObjectTools.QueueFreeIfAlive(loadingScreen);
        _isLoading = false;
    }
}
