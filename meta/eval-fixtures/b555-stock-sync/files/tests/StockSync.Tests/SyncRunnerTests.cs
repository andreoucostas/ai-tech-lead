using System.Globalization;
using System.Net;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using StockSync.Api.Export;
using StockSync.Api.Stock;
using StockSync.Api.Sync;
using Xunit;

namespace StockSync.Tests;

public sealed class SyncRunnerTests : IDisposable
{
    private static readonly DateTimeOffset T1 = new(2026, 11, 24, 10, 0, 0, TimeSpan.Zero);
    private static readonly DateTimeOffset T2 = new(2026, 11, 24, 11, 0, 0, TimeSpan.Zero);
    private static readonly DateTimeOffset T3 = new(2026, 11, 24, 12, 0, 0, TimeSpan.Zero);

    private readonly string folder = Path.Combine(Path.GetTempPath(), "stocksync-tests-" + Guid.NewGuid().ToString("N"));
    private readonly StubHandler handler = new();
    private readonly StockStore store = new();
    private readonly SyncRunner runner;

    public SyncRunnerTests()
    {
        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?> { ["Export:DropPath"] = folder })
            .Build();
        var http = new HttpClient(handler) { BaseAddress = new Uri("http://supplier.test/") };
        runner = new SyncRunner(new SupplierFeedClient(http), store, new ExportWriter(config), new SyncRunLog());
    }

    public void Dispose()
    {
        if (Directory.Exists(folder))
        {
            Directory.Delete(folder, true);
        }
    }

    [Fact]
    public async Task RunAsync_FeedHasChanges_AppliesEveryChange()
    {
        handler.Enqueue(new StockChange("c1", "SKU-1", 5, T1), new StockChange("c2", "SKU-2", 7, T2));

        var run = await runner.RunAsync("manual", CancellationToken.None);

        var items = store.Snapshot(T3).Items;
        Assert.Equal(2, items.Count);
        Assert.Equal(5, items[0].Quantity);
        Assert.Equal(7, items[1].Quantity);
        Assert.Equal(2, run.AppliedCount);
        Assert.Equal("Completed", run.Status);
    }

    [Fact]
    public async Task RunAsync_FeedRepeatsAppliedChange_SkipsIt()
    {
        handler.Enqueue(new StockChange("c1", "SKU-1", 5, T1));
        handler.Enqueue(new StockChange("c1", "SKU-1", 5, T1), new StockChange("c2", "SKU-2", 7, T2));

        await runner.RunAsync("manual", CancellationToken.None);
        var second = await runner.RunAsync("manual", CancellationToken.None);

        Assert.Equal(1, second.AppliedCount);
        Assert.Equal(2, store.Snapshot(T3).Items.Count);
    }

    [Fact]
    public async Task RunAsync_SecondRun_AsksForChangesSinceLatestChangedAt()
    {
        handler.Enqueue(new StockChange("c1", "SKU-1", 5, T1), new StockChange("c2", "SKU-2", 7, T2));
        handler.Enqueue();

        await runner.RunAsync("manual", CancellationToken.None);
        await runner.RunAsync("manual", CancellationToken.None);

        var query = handler.Requests[1].Query;
        var raw = query[(query.IndexOf("since=", StringComparison.Ordinal) + "since=".Length)..];
        var since = DateTimeOffset.Parse(Uri.UnescapeDataString(raw), CultureInfo.InvariantCulture);
        Assert.Equal(T2, since);
    }

    private sealed class StubHandler : HttpMessageHandler
    {
        private readonly Queue<string> responses = new();

        public List<Uri> Requests { get; } = [];

        public void Enqueue(params StockChange[] changes) =>
            responses.Enqueue(JsonSerializer.Serialize(changes, new JsonSerializerOptions(JsonSerializerDefaults.Web)));

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests.Add(request.RequestUri!);
            var json = responses.Count > 0 ? responses.Dequeue() : "[]";
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent(json, Encoding.UTF8, "application/json"),
            });
        }
    }
}
