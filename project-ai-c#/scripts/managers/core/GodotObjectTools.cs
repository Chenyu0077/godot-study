using Godot;

namespace ProjectAi.Managers.Core;

public static class GodotObjectTools
{
    public static bool IsAlive(GodotObject? instance)
    {
        return instance is not null && GodotObject.IsInstanceValid(instance);
    }

    public static void QueueFreeIfAlive(Node? node)
    {
        if (IsAlive(node) && !node!.IsQueuedForDeletion())
        {
            node.QueueFree();
        }
    }

    public static void DisposeIfAlive(GodotObject? instance)
    {
        if (IsAlive(instance))
        {
            instance!.Dispose();
        }
    }
}
