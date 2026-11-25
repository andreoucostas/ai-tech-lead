using StockSync.Api.Sync;

namespace StockSync.Api.Stock;

public sealed class StockStore
{
    private readonly object gate = new();
    private readonly Dictionary<string, StockItem> items = new(StringComparer.Ordinal);
    private readonly HashSet<string> appliedChangeIds = new(StringComparer.Ordinal);
    private DateTimeOffset watermark = DateTimeOffset.MinValue;

    public DateTimeOffset Watermark
    {
        get
        {
            lock (gate)
            {
                return watermark;
            }
        }
    }

    public bool TryApply(StockChange change)
    {
        lock (gate)
        {
            if (!appliedChangeIds.Add(change.ChangeId))
            {
                return false;
            }

            items[change.Sku] = new StockItem(change.Sku, change.Quantity, change.ChangedAt);
            if (change.ChangedAt > watermark)
            {
                watermark = change.ChangedAt;
            }

            return true;
        }
    }

    public StockSnapshot Snapshot(DateTimeOffset takenAt)
    {
        lock (gate)
        {
            var ordered = items.Values.OrderBy(i => i.Sku, StringComparer.Ordinal).ToList();
            return new StockSnapshot(takenAt, ordered);
        }
    }
}
