using System;
using System.Collections.Generic;

namespace ProjectAi.Managers.Pooling;

public sealed class ObjectPool<T> where T : class
{
    private readonly Func<T> _create;
    private readonly Action<T>? _onGet;
    private readonly Action<T>? _onRelease;
    private readonly Stack<T> _items = new();

    public ObjectPool(Func<T> create, Action<T>? onGet = null, Action<T>? onRelease = null)
    {
        _create = create ?? throw new ArgumentNullException(nameof(create));
        _onGet = onGet;
        _onRelease = onRelease;
    }

    public int CountInactive => _items.Count;

    public T Get()
    {
        var item = _items.Count > 0 ? _items.Pop() : _create();
        _onGet?.Invoke(item);
        return item;
    }

    public void Release(T item)
    {
        ArgumentNullException.ThrowIfNull(item);
        _onRelease?.Invoke(item);
        _items.Push(item);
    }

    public void Clear(Action<T>? dispose = null)
    {
        while (_items.Count > 0)
        {
            dispose?.Invoke(_items.Pop());
        }
    }
}
