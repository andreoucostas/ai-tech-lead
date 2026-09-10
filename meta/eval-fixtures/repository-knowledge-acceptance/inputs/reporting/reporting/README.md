# Report procedures

First-party SQL for the region-revenue report. `dbo.RunRegionRevenue` is the entry point;
`dbo.RenderRegionRevenue` and `dbo.NetLineAmount` are its dependencies. Adjustment emission is
handled by `dbo.EmitExternalAdjustments`, which is maintained outside this repository.

These files are read as source. No database engine is provisioned here.
