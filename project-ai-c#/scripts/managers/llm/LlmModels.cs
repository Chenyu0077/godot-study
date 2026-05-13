using System.Threading;

namespace ProjectAi.Managers.Llm;

/// <summary>LLM 请求优先级</summary>
public enum LlmPriority
{
    Low = 0,
    Normal = 1,
    High = 2,
    Critical = 3,
}

/// <summary>LLM 供应商</summary>
public enum LlmProvider
{
    /// <summary>OpenAI Chat Completions API（也兼容 Ollama）</summary>
    OpenAi,
    /// <summary>Anthropic Messages API</summary>
    Anthropic,
}

/// <summary>LLM 请求</summary>
public sealed record LlmRequest(
    string Prompt,
    LlmPriority Priority = LlmPriority.Normal,
    int MaxTokens = 512,
    float Temperature = 0.7f,
    string? SystemPrompt = null,
    CancellationToken CancellationToken = default);

/// <summary>LLM 响应</summary>
public sealed record LlmResponse(
    string Text,
    int PromptTokens,
    int CompletionTokens,
    bool FromCache);

/// <summary>LLM 客户端配置</summary>
public sealed record LlmClientConfig
{
    /// <summary>API 端点 URL（如 "https://api.openai.com/v1"）</summary>
    public required string Endpoint { get; init; }

    /// <summary>API 密钥</summary>
    public required string ApiKey { get; init; }

    /// <summary>模型名称（如 "gpt-4o", "claude-sonnet-4-20250514"）</summary>
    public required string Model { get; init; }

    /// <summary>供应商类型</summary>
    public LlmProvider Provider { get; init; } = LlmProvider.OpenAi;

    /// <summary>最大并发请求数</summary>
    public int MaxConcurrent { get; init; } = 2;

    /// <summary>Token 预算上限（0 = 不限制）</summary>
    public int BudgetMaxTokens { get; init; } = 0;

    /// <summary>最大重试次数</summary>
    public int MaxRetries { get; init; } = 3;
}
