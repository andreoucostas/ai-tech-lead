# Project pattern: report exports (DRAFT, pending PR review)

Evidence status: `observed`. Last semantic recheck 2026-10-18: reread each path below.

Instances (3, consumer-authored):

| Key | Export class | View | Flag |
|-----|--------------|------|------|
| monthly-sales | `src/Orders.Reporting/Exports/MonthlySalesExport.cs` | `db/views/rpt.vwMonthlySales.sql` | `reports.export.monthly-sales` |
| open-orders | `src/Orders.Reporting/Exports/OpenOrdersExport.cs` | `db/views/rpt.vwOpenOrders.sql` | `reports.export.open-orders` |
| overdue-invoices | `src/Orders.Reporting/Exports/OverdueInvoicesExport.cs` | `db/views/rpt.vwOverdueInvoices.sql` | `reports.export.overdue-invoices` |

Shared: `src/Orders.Reporting/ReportCatalog.cs`, `db/security/reporting-grants.sql`, `config/feature-flags.json`, `tests/Orders.Tests/ReportCatalogTests.cs`.

**Cleanest exemplar:** `OpenOrdersExport` + `rpt.vwOpenOrders`. Reproduce structure, not contents.

**Divergence:** none observed in structure. The views' status vocabulary (`'Placed','Picking'` in `rpt.vwOpenOrders`) is not fully produced by code (`Picking` is never set); unresolved.

**Counterevidence/limits:** `config/` is not copied to the API output (`src/Orders.Api/Orders.Api.csproj`); the test project copies it separately. Deployment of SQL is unobserved.

**Semantic refresh trigger:** any change to `ReportCatalog.cs`, `IReportReader.cs`, or `ReportsController.cs`. Result at creation: sources reread, no contradictions.
