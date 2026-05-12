using System;
using System.Collections.Generic;
using Godot;
using ProjectAi.Managers.Core;

namespace ProjectAi.Managers.Ui;

public partial class UILayerManager : CanvasLayer
{
    private readonly Dictionary<UILayer, Control> _containers = new();

    public override void _EnterTree()
    {
        GameServices.UI = this;
    }

    public override void _Ready()
    {
        BuildDefaultLayers();
    }

    public Control GetLayer(UILayer layer)
    {
        BuildDefaultLayers();
        return _containers[layer];
    }

    public T AddScene<T>(PackedScene scene, UILayer layer) where T : Node
    {
        ArgumentNullException.ThrowIfNull(scene);

        var instance = scene.Instantiate<T>();
        AddNode(instance, layer);
        return instance;
    }

    public void AddNode(Node node, UILayer layer)
    {
        ArgumentNullException.ThrowIfNull(node);
        GetLayer(layer).AddChild(node);
    }

    public void BringToFront(Node node)
    {
        ArgumentNullException.ThrowIfNull(node);

        var parent = node.GetParent();
        parent?.MoveChild(node, parent.GetChildCount() - 1);
    }

    public void ClearLayer(UILayer layer)
    {
        foreach (var child in GetLayer(layer).GetChildren())
        {
            if (child is Node node)
            {
                GodotObjectTools.QueueFreeIfAlive(node);
            }
        }
    }

    private void BuildDefaultLayers()
    {
        if (_containers.Count > 0)
        {
            return;
        }

        foreach (UILayer layer in Enum.GetValues<UILayer>())
        {
            var container = GetNodeOrNull<Control>(layer.ToString()) ?? CreateLayerContainer(layer);
            _containers[layer] = container;
        }
    }

    private Control CreateLayerContainer(UILayer layer)
    {
        var container = new Control
        {
            Name = layer.ToString(),
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };

        container.SetAnchorsPreset(Control.LayoutPreset.FullRect);
        AddChild(container);
        MoveChild(container, GetChildCount() - 1);
        return container;
    }
}
