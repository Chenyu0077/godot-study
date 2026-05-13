using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace ProjectAi.Managers.Llm;

/// <summary>
/// LLM 客户端接口（纯 C#，逻辑层可安全依赖）
/// </summary>
public interface ILlmClient : IDisposable
{
    /// <summary>发送补全请求，返回完整响应</summary>
    Task<LlmResponse> CompleteAsync(LlmRequest request);

    /// <summary>流式补全，逐 token 返回</summary>
    IAsyncEnumerable<string> StreamCompleteAsync(LlmRequest request);
}

/// <summary>预算耗尽异常</summary>
public sealed class LlmBudgetExceededException : Exception
{
    public LlmBudgetExceededException(int used, int limit)
        : base($"LLM token budget exceeded: {used}/{limit}") { }
}
