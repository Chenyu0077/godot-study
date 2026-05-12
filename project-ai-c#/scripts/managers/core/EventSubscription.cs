using System;

namespace ProjectAi.Managers.Core;

public sealed class EventSubscription : IDisposable
{
    private Action? _dispose;

    internal EventSubscription(Action dispose)
    {
        _dispose = dispose;
    }

    public void Dispose()
    {
        _dispose?.Invoke();
        _dispose = null;
    }
}
