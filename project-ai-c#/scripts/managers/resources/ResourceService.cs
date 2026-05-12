using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Godot;
using ProjectAi.Managers.Core;

namespace ProjectAi.Managers.Resources;

public partial class ResourceService : Node
{
    private readonly Dictionary<string, WeakReference<Resource>> _cache = new();

    public override void _EnterTree()
    {
        GameServices.Resources = this;
    }

    public T Load<T>(string path) where T : Resource
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(path);

        if (TryGetCached(path, out T? cached))
        {
            return cached;
        }

        var resource = ResourceLoader.Load<T>(path);
        if (resource is null)
        {
            throw new InvalidOperationException($"Failed to load resource: {path}");
        }

        _cache[path] = new WeakReference<Resource>(resource);
        return resource;
    }

    public async Task<T> LoadAsync<T>(string path) where T : Resource
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(path);

        if (TryGetCached(path, out T? cached))
        {
            return cached;
        }

        var requestError = ResourceLoader.LoadThreadedRequest(path, typeof(T).Name);
        if (requestError != Error.Ok && requestError != Error.Busy)
        {
            throw new InvalidOperationException($"Failed to request async load: {path}, error: {requestError}");
        }

        while (ResourceLoader.LoadThreadedGetStatus(path) == ResourceLoader.ThreadLoadStatus.InProgress)
        {
            await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        }

        if (ResourceLoader.LoadThreadedGetStatus(path) != ResourceLoader.ThreadLoadStatus.Loaded)
        {
            throw new InvalidOperationException($"Failed to async load resource: {path}");
        }

        var resource = ResourceLoader.LoadThreadedGet(path) as T;
        if (resource is null)
        {
            throw new InvalidOperationException($"Loaded resource type mismatch: {path}");
        }

        _cache[path] = new WeakReference<Resource>(resource);
        return resource;
    }

    public void ClearCache(bool trimDeadOnly = false)
    {
        if (!trimDeadOnly)
        {
            _cache.Clear();
            return;
        }

        var deadPaths = new List<string>();
        foreach (var (path, reference) in _cache)
        {
            if (!reference.TryGetTarget(out _))
            {
                deadPaths.Add(path);
            }
        }

        foreach (var path in deadPaths)
        {
            _cache.Remove(path);
        }
    }

    private bool TryGetCached<T>(string path, out T? resource) where T : Resource
    {
        resource = null;
        if (!_cache.TryGetValue(path, out var reference))
        {
            return false;
        }

        if (reference.TryGetTarget(out var cached) && cached is T typed)
        {
            resource = typed;
            return true;
        }

        _cache.Remove(path);
        return false;
    }
}
