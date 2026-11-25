using System.Globalization;
using System.Text;
using StockSync.Api.Stock;

namespace StockSync.Api.Export;

public sealed class ExportWriter(IConfiguration configuration)
{
    public async Task<string> WriteAsync(StockSnapshot snapshot, CancellationToken ct)
    {
        var folder = configuration["Export:DropPath"]
            ?? throw new InvalidOperationException("Export:DropPath is not configured.");
        Directory.CreateDirectory(folder);

        var name = $"stock-{snapshot.TakenAt.ToString("yyyyMMdd", CultureInfo.InvariantCulture)}.csv";
        var path = Path.GetFullPath(Path.Combine(folder, name));

        var text = new StringBuilder();
        text.Append("sku,quantity,updated_at\n");
        foreach (var item in snapshot.Items)
        {
            text.Append(item.Sku).Append(',')
                .Append(item.Quantity.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(item.UpdatedAt.ToString("O", CultureInfo.InvariantCulture)).Append('\n');
        }

        await File.WriteAllTextAsync(path, text.ToString(), new UTF8Encoding(false), ct);
        return path;
    }
}
