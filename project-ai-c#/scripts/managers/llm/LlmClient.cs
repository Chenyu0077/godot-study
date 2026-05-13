using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Runtime.CompilerServices;
using System.Threading;
using System.Threading.Tasks;

namespace ProjectAi.Managers.Llm;

/// <summary>
/// LLM 客户端实现 — 纯 C#，使用 System.Net.Http.HttpClient
/// <para>内置：并发控制（SemaphoreSlim）、Token 预算、响应缓存、指数退避重试</para>
/// </summary>
public sealed class LlmClient : ILlmClient
{
    private static readonly HttpClient SharedHttp = new() { Timeout = TimeSpan.FromSeconds(120) };

    private readonly LlmClientConfig _config;
    private readonly ILlmRequestFormatter _formatter;
    private readonly LlmResponseCache _cache;
    private readonly SemaphoreSlim _concurrencyGate;

    // Token 预算（Interlocked 线程安全）
    private long _totalTokensUsed;

    public LlmClient(LlmClientConfig config, LlmResponseCache? cache = null)
    {
        _config = config ?? throw new ArgumentNullException(nameof(config));
        _formatter = LlmFormatterFactory.Create(config.Provider);
        _cache = cache ?? new LlmResponseCache();
        _concurrencyGate = new SemaphoreSlim(config.MaxConcurrent, config.MaxConcurrent);
    }

    public long TotalTokensUsed => Interlocked.Read(ref _totalTokensUsed);

    // ── ILlmClient 实现 ────────────────────────────────────

    public async Task<LlmResponse> CompleteAsync(LlmRequest request)
    {
        // 1. 查缓存
        var cached = _cache.Get(request.Prompt);
        if (cached is not null) return cached;

        // 2. 检查预算
        CheckBudget(request.MaxTokens);

        // 3. 排队等并发
        await _concurrencyGate.WaitAsync(request.CancellationToken);
        try
        {
            var json = await SendWithRetryAsync(request);
            var response = _formatter.ParseResponse(json);

            // 4. 记录用量
            RecordUsage(response.PromptTokens + response.CompletionTokens);

            // 5. 写缓存
            _cache.Set(request.Prompt, response);

            return response;
        }
        finally
        {
            _concurrencyGate.Release();
        }
    }

    public async IAsyncEnumerable<string> StreamCompleteAsync(
        LlmRequest request,
        [EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        CheckBudget(request.MaxTokens);

        await _concurrencyGate.WaitAsync(cancellationToken);
        try
        {
            var httpRequest = _formatter.FormatRequest(request, _config);

            // 追加 stream 参数
            var content = await httpRequest.Content!.ReadAsStringAsync(cancellationToken);
            var streamBody = content.TrimEnd('}') + ",\"stream\":true}";
            httpRequest.Content = new StringContent(streamBody, System.Text.Encoding.UTF8, "application/json");

            using var httpResponse = await SharedHttp.SendAsync(
                httpRequest,
                HttpCompletionOption.ResponseHeadersRead,
                cancellationToken);

            httpResponse.EnsureSuccessStatusCode();

            using var stream = await httpResponse.Content.ReadAsStreamAsync(cancellationToken);
            using var reader = new StreamReader(stream);

            while (!reader.EndOfStream)
            {
                var line = await reader.ReadLineAsync(cancellationToken);
                if (line is null) break;
                if (!line.StartsWith("data: ")) continue;

                var sseData = line["data: ".Length..];
                if (sseData is "[DONE]" or "") continue;

                var token = _formatter.ParseStreamToken(sseData);
                if (!string.IsNullOrEmpty(token))
                    yield return token;
            }
        }
        finally
        {
            _concurrencyGate.Release();
        }
    }

    // ── 重试逻辑 ────────────────────────────────────────────

    private async Task<string> SendWithRetryAsync(LlmRequest request)
    {
        Exception? lastException = null;

        for (var attempt = 0; attempt <= _config.MaxRetries; attempt++)
        {
            if (attempt > 0)
            {
                var delay = TimeSpan.FromMilliseconds(Math.Pow(2, attempt) * 500);
                await Task.Delay(delay, request.CancellationToken);
            }

            try
            {
                var httpRequest = _formatter.FormatRequest(request, _config);
                using var httpResponse = await SharedHttp.SendAsync(httpRequest, request.CancellationToken);

                if (httpResponse.IsSuccessStatusCode)
                    return await httpResponse.Content.ReadAsStringAsync(request.CancellationToken);

                // 仅对可重试的状态码重试
                if (!IsRetryable(httpResponse.StatusCode))
                {
                    var errorBody = await httpResponse.Content.ReadAsStringAsync(request.CancellationToken);
                    throw new HttpRequestException(
                        $"LLM API error {(int)httpResponse.StatusCode}: {errorBody}");
                }

                lastException = new HttpRequestException(
                    $"LLM API returned {(int)httpResponse.StatusCode}, retrying...");
            }
            catch (TaskCanceledException) { throw; }
            catch (HttpRequestException e) when (attempt < _config.MaxRetries)
            {
                lastException = e;
            }
        }

        throw lastException ?? new HttpRequestException("LLM request failed after retries");
    }

    private static bool IsRetryable(HttpStatusCode code) =>
        code is HttpStatusCode.TooManyRequests
            or HttpStatusCode.InternalServerError
            or HttpStatusCode.BadGateway
            or HttpStatusCode.ServiceUnavailable
            or HttpStatusCode.GatewayTimeout;

    // ── 预算控制 ────────────────────────────────────────────

    private void CheckBudget(int estimatedTokens)
    {
        if (_config.BudgetMaxTokens <= 0) return;

        var current = Interlocked.Read(ref _totalTokensUsed);
        if (current + estimatedTokens > _config.BudgetMaxTokens)
            throw new LlmBudgetExceededException((int)current, _config.BudgetMaxTokens);
    }

    private void RecordUsage(int tokens)
    {
        Interlocked.Add(ref _totalTokensUsed, tokens);
    }

    // ── IDisposable ─────────────────────────────────────────

    public void Dispose()
    {
        _concurrencyGate.Dispose();
    }
}
