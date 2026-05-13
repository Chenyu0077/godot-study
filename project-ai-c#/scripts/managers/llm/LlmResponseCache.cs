using System.Collections.Generic;
using System.Linq;

namespace ProjectAi.Managers.Llm;

/// <summary>
/// LLM 响应内存缓存（prompt hash → response），容量上限自动淘汰最早条目
/// </summary>
public sealed class LlmResponseCache
{
    private readonly int _maxEntries;
    private readonly Dictionary<int, LlmResponse> _cache = new();
    private readonly LinkedList<int> _accessOrder = new();

    public LlmResponseCache(int maxEntries = 200)
    {
        _maxEntries = maxEntries;
    }

    public int Count => _cache.Count;

    /// <summary>查询缓存，命中则返回带 FromCache=true 的响应</summary>
    public LlmResponse? Get(string prompt)
    {
        var key = prompt.GetHashCode();
        if (!_cache.TryGetValue(key, out var response)) return null;

        // 移到最近访问
        _accessOrder.Remove(key);
        _accessOrder.AddLast(key);

        return response with { FromCache = true };
    }

    /// <summary>写入缓存</summary>
    public void Set(string prompt, LlmResponse response)
    {
        var key = prompt.GetHashCode();

        if (_cache.ContainsKey(key))
        {
            _cache[key] = response;
            _accessOrder.Remove(key);
            _accessOrder.AddLast(key);
            return;
        }

        // 淘汰最早条目
        while (_cache.Count >= _maxEntries && _accessOrder.First is not null)
        {
            var oldest = _accessOrder.First.Value;
            _accessOrder.RemoveFirst();
            _cache.Remove(oldest);
        }

        _cache[key] = response;
        _accessOrder.AddLast(key);
    }

    public void Clear()
    {
        _cache.Clear();
        _accessOrder.Clear();
    }
}
