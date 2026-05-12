using System;
using System.Collections.Generic;
using System.Linq;

namespace ProjectAi.Managers.Core;

public sealed class EventBus
{
    private readonly Dictionary<Type, List<Delegate>> _handlers = new();

    public EventSubscription Subscribe<T>(Action<T> handler) where T : IGameEvent
    {
        ArgumentNullException.ThrowIfNull(handler);

        var eventType = typeof(T);
        if (!_handlers.TryGetValue(eventType, out var handlers))
        {
            handlers = new List<Delegate>();
            _handlers[eventType] = handlers;
        }

        handlers.Add(handler);
        return new EventSubscription(() => Unsubscribe(handler));
    }

    public void Unsubscribe<T>(Action<T> handler) where T : IGameEvent
    {
        ArgumentNullException.ThrowIfNull(handler);

        var eventType = typeof(T);
        if (!_handlers.TryGetValue(eventType, out var handlers))
        {
            return;
        }

        handlers.Remove(handler);
        if (handlers.Count == 0)
        {
            _handlers.Remove(eventType);
        }
    }

    public void Publish<T>(T gameEvent) where T : IGameEvent
    {
        ArgumentNullException.ThrowIfNull(gameEvent);

        if (!_handlers.TryGetValue(typeof(T), out var handlers))
        {
            return;
        }

        foreach (var handler in handlers.ToList())
        {
            ((Action<T>)handler).Invoke(gameEvent);
        }
    }

    public void Clear()
    {
        _handlers.Clear();
    }
}
