namespace ProjectAi.Managers.Http;

public sealed record HttpResult(long Result, long ResponseCode, string[] Headers, byte[] Body)
{
    public string BodyAsUtf8 => System.Text.Encoding.UTF8.GetString(Body);

    public bool IsSuccessStatusCode => ResponseCode is >= 200 and <= 299;
}
