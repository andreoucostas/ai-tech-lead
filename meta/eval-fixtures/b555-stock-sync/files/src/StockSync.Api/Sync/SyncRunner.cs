using StockSync.Api.Export;
using StockSync.Api.Stock;

namespace StockSync.Api.Sync;

public sealed class SyncRunner(SupplierFeedClient feed, StockStore store, ExportWriter export, SyncRunLog runs)
{
    public async Task<SyncRun> RunAsync(string trigger, CancellationToken ct)
    {
        var run = runs.Start(trigger);
        try
        {
            var changes = await feed.GetChangesAsync(store.Watermark, ct);
            var applied = 0;
            foreach (var change in changes)
            {
                if (store.TryApply(change))
                {
                    applied++;
                }
            }

            var completed = runs.Complete(run.Id, applied);
            await export.WriteAsync(store.Snapshot(run.StartedAt), ct);
            return completed;
        }
        catch
        {
            runs.Fail(run.Id);
            throw;
        }
    }
}
