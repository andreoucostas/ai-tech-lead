namespace Catalog.Api;

public sealed class PriceCacheRefresher : BackgroundService
{
    private readonly PricingClient _pricing;
    private readonly ILogger<PriceCacheRefresher> _log;

    public PriceCacheRefresher(PricingClient pricing, ILogger<PriceCacheRefresher> log)
    {
        _pricing = pricing;
        _log = log;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try { await _pricing.GetPriceAsync("SKU-1", stoppingToken); }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException) { _log.LogWarning("price refresh skipped: {Message}", ex.Message); }
            await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
        }
    }
}
