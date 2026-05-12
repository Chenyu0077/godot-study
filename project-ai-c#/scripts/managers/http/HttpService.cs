using System;
using System.Threading.Tasks;
using Godot;
using ProjectAi.Managers.Core;

namespace ProjectAi.Managers.Http;

public partial class HttpService : Node
{
    [Export]
    public bool UseThreads { get; set; } = true;

    public override void _EnterTree()
    {
        GameServices.Http = this;
    }

    public Task<HttpResult> GetAsync(string url, string[]? headers = null)
    {
        return SendAsync(url, HttpClient.Method.Get, headers);
    }

    public Task<HttpResult> PostJsonAsync(string url, string jsonBody, string[]? headers = null)
    {
        var requestHeaders = MergeHeaders(headers, "Content-Type: application/json");
        return SendAsync(url, HttpClient.Method.Post, requestHeaders, jsonBody);
    }

    public Task<HttpResult> SendAsync(
        string url,
        HttpClient.Method method,
        string[]? headers = null,
        string body = "")
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(url);

        var request = new HttpRequest
        {
            Name = "HttpRequest",
            UseThreads = UseThreads,
        };
        AddChild(request);

        var completion = new TaskCompletionSource<HttpResult>();

        void OnCompleted(long result, long responseCode, string[] responseHeaders, byte[] responseBody)
        {
            request.RequestCompleted -= OnCompleted;
            request.QueueFree();
            completion.TrySetResult(new HttpResult(result, responseCode, responseHeaders, responseBody));
        }

        request.RequestCompleted += OnCompleted;
        var error = request.Request(url, headers ?? Array.Empty<string>(), method, body);
        if (error != Error.Ok)
        {
            request.RequestCompleted -= OnCompleted;
            request.QueueFree();
            completion.TrySetException(new InvalidOperationException($"HTTP request failed to start: {error}"));
        }

        return completion.Task;
    }

    private static string[] MergeHeaders(string[]? headers, string requiredHeader)
    {
        if (headers is null || headers.Length == 0)
        {
            return new[] { requiredHeader };
        }

        var merged = new string[headers.Length + 1];
        headers.CopyTo(merged, 0);
        merged[^1] = requiredHeader;
        return merged;
    }
}
