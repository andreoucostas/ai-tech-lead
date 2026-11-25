using Microsoft.Extensions.Configuration;
using StockSync.Api.Export;
using StockSync.Api.Stock;
using Xunit;

namespace StockSync.Tests;

public sealed class ExportWriterTests : IDisposable
{
    private readonly string folder = Path.Combine(Path.GetTempPath(), "stocksync-tests-" + Guid.NewGuid().ToString("N"));

    public void Dispose()
    {
        if (Directory.Exists(folder))
        {
            Directory.Delete(folder, true);
        }
    }

    [Fact]
    public async Task WriteAsync_TwoItems_WritesDatedCsvWithHeaderAndOneLinePerItem()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["Export:DropPath"] = folder })
            .Build();
        var takenAt = new DateTimeOffset(2026, 11, 25, 2, 0, 0, TimeSpan.Zero);
        var snapshot = new StockSnapshot(takenAt,
        [
            new StockItem("SKU-1", 5, takenAt),
            new StockItem("SKU-2", 7, takenAt),
        ]);

        var path = await new ExportWriter(config).WriteAsync(snapshot, CancellationToken.None);

        Assert.Equal("stock-20261125.csv", Path.GetFileName(path));
        Assert.Equal(folder, Path.GetDirectoryName(path));
        var lines = await File.ReadAllLinesAsync(path);
        Assert.Equal("sku,quantity,updated_at", lines[0]);
        Assert.Equal(3, lines.Length);
    }
}
