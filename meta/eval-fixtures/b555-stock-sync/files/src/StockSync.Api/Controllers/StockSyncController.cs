using Microsoft.AspNetCore.Mvc;
using StockSync.Api.Sync;

namespace StockSync.Api.Controllers;

[ApiController]
[Route("api/stock-sync")]
public sealed class StockSyncController(SyncRunner runner, SyncRunLog runs) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> Start(CancellationToken ct)
    {
        var run = await runner.RunAsync("manual", ct);
        return Accepted($"/api/stock-sync/{run.Id}", new { runId = run.Id });
    }

    [HttpGet("{runId:guid}")]
    public IActionResult Get(Guid runId)
    {
        var run = runs.Find(runId);
        if (run is null)
        {
            return NotFound();
        }

        return Ok(run);
    }
}
