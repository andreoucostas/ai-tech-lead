using System.Globalization;

namespace StockSync.Api.Sync;

/// <summary>Reads stock changes from the supplier's feed API.</summary>
public sealed class SupplierFeedClient(HttpClient http)
{
    public async Task<IReadOnlyList<StockChange>> GetChangesAsync(DateTimeOffset since, CancellationToken ct)
    {
        var url = $"v2/stock-changes?since={Uri.EscapeDataString(since.ToString("O", CultureInfo.InvariantCulture))}";
        var changes = await http.GetFromJsonAsync<List<StockChange>>(url, ct);
        return changes ?? [];
    }
}

public sealed record StockChange(string ChangeId, string Sku, int Quantity, DateTimeOffset ChangedAt);
