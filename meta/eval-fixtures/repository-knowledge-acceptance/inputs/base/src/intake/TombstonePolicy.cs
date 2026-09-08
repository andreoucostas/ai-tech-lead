namespace Synthetic.Intake;

public static class TombstonePolicy
{
    public static bool ShouldReject(
        DateTimeOffset incomingTimestamp,
        DateTimeOffset tombstoneTimestamp) =>
        incomingTimestamp <= tombstoneTimestamp;
}

