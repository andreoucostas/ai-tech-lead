namespace StockSync.Api.Sync;

public sealed class NightlySyncWorker(IServiceScopeFactory scopes, ILogger<NightlySyncWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await Task.Delay(DelayUntilNextRun(DateTime.Now), stoppingToken);
                using var scope = scopes.CreateScope();
                var runner = scope.ServiceProvider.GetRequiredService<SyncRunner>();
                await runner.RunAsync("nightly", stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Nightly sync failed.");
            }
        }
    }

    internal static TimeSpan DelayUntilNextRun(DateTime now)
    {
        var next = now.Date.AddHours(2);
        if (next <= now)
        {
            next = next.AddDays(1);
        }

        return next - now;
    }
}
