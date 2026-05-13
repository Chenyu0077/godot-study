using System.Text.Json;
using Godot;
using ProjectAi.Managers.Core;

namespace ProjectAi.Managers.Save;

/// <summary>
/// 存档服务 — 使用 System.Text.Json 序列化 + Godot FileAccess I/O
/// <para>存档路径：user://saves/{slotName}.json</para>
/// </summary>
public partial class SaveService : Node
{
    private const string SaveDir = "user://saves";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    public override void _EnterTree()
    {
        GameServices.Save = this;
    }

    public override void _Ready()
    {
        EnsureSaveDirectory();
    }

    /// <summary>保存数据到指定槽位</summary>
    public bool Save<T>(string slotName, T data) where T : class
    {
        var path = GetSlotPath(slotName);

        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Write);
        if (file is null)
        {
            GD.PushError($"SaveService: 无法写入存档 {path}, error={FileAccess.GetOpenError()}");
            return false;
        }

        var json = JsonSerializer.Serialize(data, JsonOptions);
        file.StoreString(json);
        return true;
    }

    /// <summary>从指定槽位加载数据</summary>
    public T? Load<T>(string slotName) where T : class
    {
        var path = GetSlotPath(slotName);

        if (!FileAccess.FileExists(path))
            return null;

        using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
        if (file is null)
        {
            GD.PushError($"SaveService: 无法读取存档 {path}, error={FileAccess.GetOpenError()}");
            return null;
        }

        var json = file.GetAsText();
        try
        {
            return JsonSerializer.Deserialize<T>(json, JsonOptions);
        }
        catch (JsonException e)
        {
            GD.PushError($"SaveService: 反序列化失败 {path}: {e.Message}");
            return null;
        }
    }

    /// <summary>检查槽位是否存在存档</summary>
    public bool HasSave(string slotName)
    {
        return FileAccess.FileExists(GetSlotPath(slotName));
    }

    /// <summary>删除指定槽位的存档</summary>
    public void Delete(string slotName)
    {
        var path = GetSlotPath(slotName);
        if (FileAccess.FileExists(path))
            DirAccess.RemoveAbsolute(path);
    }

    /// <summary>列出所有存档槽位名称</summary>
    public string[] ListSlots()
    {
        using var dir = DirAccess.Open(SaveDir);
        if (dir is null) return System.Array.Empty<string>();

        var slots = new System.Collections.Generic.List<string>();
        dir.ListDirBegin();

        var fileName = dir.GetNext();
        while (!string.IsNullOrEmpty(fileName))
        {
            if (!dir.CurrentIsDir() && fileName.EndsWith(".json"))
                slots.Add(fileName.Replace(".json", ""));
            fileName = dir.GetNext();
        }

        dir.ListDirEnd();
        return slots.ToArray();
    }

    private static string GetSlotPath(string slotName) => $"{SaveDir}/{slotName}.json";

    private static void EnsureSaveDirectory()
    {
        if (!DirAccess.DirExistsAbsolute(SaveDir))
            DirAccess.MakeDirAbsolute(SaveDir);
    }
}
