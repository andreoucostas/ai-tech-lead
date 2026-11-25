# Copilot instructions — StockSync

## About this service
StockSync keeps our stock levels in step with the supplier's catalogue.
The supplier's system pushes stock changes to us: it calls `POST api/stock-sync` whenever its stock changes, and we apply each change to our store.
`stock-uat` is our second production node; treat it like production.
Each run writes the day's export to `exports/outbox` as `stock-yyyyMMdd.csv`.

## Conventions
- Controllers stay thin; sync logic lives in `Sync/`.
- Use the typed HttpClient for outbound calls.
- Async all the way down; pass the CancellationToken.
- Tests use xUnit, named Method_Scenario_Result.

## Commands
- Build: `dotnet build StockSync.sln`
- Test: `dotnet test StockSync.sln`
