using Godot;

namespace ProjectAi.Managers.Core;

public readonly record struct AgentId(long Value);

public readonly record struct BuildingId(long Value);

public enum BuildingType
{
    Unknown,
    Kitchen,
    Medicine,
    Shelter,
}

public sealed record DayStartedEvent(int Day, float SunriseTime) : IGameEvent;

public sealed record AgentDiedEvent(AgentId AgentId, string Cause) : IGameEvent;

public sealed record AgentSpokeEvent(AgentId Speaker, string Text, Vector2 Position) : IGameEvent;

public sealed record BuildingCompletedEvent(BuildingId Id, BuildingType Type) : IGameEvent;
