using System;
using Godot;
using ProjectAi.Managers.Core;

namespace ProjectAi.Managers.Pooling;

public sealed class NodePool<T> where T : Node
{
    private readonly Node _parent;
    private readonly ObjectPool<T> _pool;

    public NodePool(PackedScene scene, Node parent)
    {
        ArgumentNullException.ThrowIfNull(scene);
        _parent = parent ?? throw new ArgumentNullException(nameof(parent));
        _pool = new ObjectPool<T>(() => scene.Instantiate<T>(), OnGet, OnRelease);
    }

    public T Get()
    {
        return _pool.Get();
    }

    public void Release(T node)
    {
        _pool.Release(node);
    }

    public void Clear()
    {
        _pool.Clear(GodotObjectTools.QueueFreeIfAlive);
    }

    private void OnGet(T node)
    {
        if (node.GetParent() is null)
        {
            _parent.AddChild(node);
        }

        node.ProcessMode = Node.ProcessModeEnum.Inherit;
        if (node is CanvasItem canvasItem)
        {
            canvasItem.Visible = true;
        }
    }

    private static void OnRelease(T node)
    {
        if (node is CanvasItem canvasItem)
        {
            canvasItem.Visible = false;
        }

        node.ProcessMode = Node.ProcessModeEnum.Disabled;
    }
}
