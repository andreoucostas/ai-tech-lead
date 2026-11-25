using System.Collections.Concurrent;

namespace StockSync.Api.Sync;

public sealed record SyncRun(Guid Id, string Trigger, DateTimeOffset StartedAt, DateTimeOffset? FinishedAt, int AppliedCount, string Status);

public sealed class SyncRunLog
{
    private readonly ConcurrentDictionary<Guid, SyncRun> runs = new();

    public SyncRun Start(string trigger)
    {
        var run = new SyncRun(Guid.NewGuid(), trigger, DateTimeOffset.Now, null, 0, "Running");
        runs[run.Id] = run;
        return run;
    }

    public SyncRun Complete(Guid id, int appliedCount)
    {
        var run = runs[id] with { FinishedAt = DateTimeOffset.Now, AppliedCount = appliedCount, Status = "Completed" };
        runs[id] = run;
        return run;
    }

    public SyncRun Fail(Guid id)
    {
        var run = runs[id] with { FinishedAt = DateTimeOffset.Now, Status = "Failed" };
        runs[id] = run;
        return run;
    }

    public SyncRun? Find(Guid id) => runs.TryGetValue(id, out var run) ? run : null;
}
