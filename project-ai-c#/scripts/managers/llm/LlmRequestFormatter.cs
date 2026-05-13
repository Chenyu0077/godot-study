using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace ProjectAi.Managers.Llm;

/// <summary>LLM 请求/响应格式化接口</summary>
public interface ILlmRequestFormatter
{
    HttpRequestMessage FormatRequest(LlmRequest request, LlmClientConfig config);
    LlmResponse ParseResponse(string json);
    string ParseStreamToken(string sseData);
}

/// <summary>OpenAI Chat Completions 格式（同时兼容 Ollama）</summary>
public sealed class OpenAiFormatter : ILlmRequestFormatter
{
    public HttpRequestMessage FormatRequest(LlmRequest request, LlmClientConfig config)
    {
        var messages = new JsonArray();

        if (request.SystemPrompt is not null)
        {
            messages.Add(new JsonObject
            {
                ["role"] = "system",
                ["content"] = request.SystemPrompt,
            });
        }

        messages.Add(new JsonObject
        {
            ["role"] = "user",
            ["content"] = request.Prompt,
        });

        var body = new JsonObject
        {
            ["model"] = config.Model,
            ["messages"] = messages,
            ["max_tokens"] = request.MaxTokens,
            ["temperature"] = request.Temperature,
        };

        var httpRequest = new HttpRequestMessage(HttpMethod.Post, $"{config.Endpoint}/chat/completions")
        {
            Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json"),
        };
        httpRequest.Headers.Add("Authorization", $"Bearer {config.ApiKey}");

        return httpRequest;
    }

    public LlmResponse ParseResponse(string json)
    {
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        var text = root.GetProperty("choices")[0]
            .GetProperty("message")
            .GetProperty("content")
            .GetString() ?? "";

        var usage = root.GetProperty("usage");
        var promptTokens = usage.GetProperty("prompt_tokens").GetInt32();
        var completionTokens = usage.GetProperty("completion_tokens").GetInt32();

        return new LlmResponse(text, promptTokens, completionTokens, FromCache: false);
    }

    public string ParseStreamToken(string sseData)
    {
        if (sseData == "[DONE]") return "";

        var doc = JsonDocument.Parse(sseData);
        var delta = doc.RootElement
            .GetProperty("choices")[0]
            .GetProperty("delta");

        return delta.TryGetProperty("content", out var content)
            ? content.GetString() ?? ""
            : "";
    }
}

/// <summary>Anthropic Messages API 格式</summary>
public sealed class AnthropicFormatter : ILlmRequestFormatter
{
    public HttpRequestMessage FormatRequest(LlmRequest request, LlmClientConfig config)
    {
        var messages = new JsonArray
        {
            new JsonObject
            {
                ["role"] = "user",
                ["content"] = request.Prompt,
            },
        };

        var body = new JsonObject
        {
            ["model"] = config.Model,
            ["messages"] = messages,
            ["max_tokens"] = request.MaxTokens,
            ["temperature"] = request.Temperature,
        };

        if (request.SystemPrompt is not null)
            body["system"] = request.SystemPrompt;

        var httpRequest = new HttpRequestMessage(HttpMethod.Post, $"{config.Endpoint}/messages")
        {
            Content = new StringContent(body.ToJsonString(), Encoding.UTF8, "application/json"),
        };
        httpRequest.Headers.Add("x-api-key", config.ApiKey);
        httpRequest.Headers.Add("anthropic-version", "2023-06-01");

        return httpRequest;
    }

    public LlmResponse ParseResponse(string json)
    {
        var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        var text = "";
        foreach (var block in root.GetProperty("content").EnumerateArray())
        {
            if (block.GetProperty("type").GetString() == "text")
                text += block.GetProperty("text").GetString();
        }

        var usage = root.GetProperty("usage");
        var promptTokens = usage.GetProperty("input_tokens").GetInt32();
        var completionTokens = usage.GetProperty("output_tokens").GetInt32();

        return new LlmResponse(text, promptTokens, completionTokens, FromCache: false);
    }

    public string ParseStreamToken(string sseData)
    {
        var doc = JsonDocument.Parse(sseData);
        var root = doc.RootElement;

        if (root.GetProperty("type").GetString() != "content_block_delta")
            return "";

        return root.GetProperty("delta")
            .GetProperty("text")
            .GetString() ?? "";
    }
}

/// <summary>格式化器工厂</summary>
public static class LlmFormatterFactory
{
    public static ILlmRequestFormatter Create(LlmProvider provider) => provider switch
    {
        LlmProvider.OpenAi => new OpenAiFormatter(),
        LlmProvider.Anthropic => new AnthropicFormatter(),
        _ => new OpenAiFormatter(),
    };
}
