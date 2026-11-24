# Project pattern: report exports (draft, pending PR review)

**Provenance:** requested `/bootstrap` discovery, 2026-11-25. **Confidence:** observed. Draft pending PR review; not team-approved policy.

## Instances (all consumer-authored)

| Key | Export class | View | Flag |
|-----|--------------|------|------|
| monthly-sales | `src/Orders.Reporting/Exports/MonthlySalesExport.cs` | `db/views/rpt.vwMonthlySales.sql` | `reports.export.monthly-sales` |
| open-orders | `src/Orders.Reporting/Exports/OpenOrdersExport.cs` | `db/views/rpt.vwOpenOrders.sql` | `reports.export.open-orders` |
| overdue-invoices | `src/Orders.Reporting/Exports/OverdueInvoicesExport.cs` | `db/views/rpt.vwOverdueInvoices.sql` | `reports.export.overdue-invoices` |

Shared: `src/Orders.Reporting/ReportCatalog.cs`, `db/security/reporting-grants.sql`, `config/feature-flags.json`, `tests/Orders.Tests/ReportCatalogTests.cs`; served by `src/Orders.Api/Controllers/ReportsController.cs`.

**Exemplar (cleanest):** `open-orders`.

## Divergence and counterevidence

- Instances do not diverge in structure; the three export classes differ only in `Key` and `ViewName`.
- `orders.checkout.v2` in the flags file is a non-report flag; do not copy its naming.
- CSV output has no escaping and uses `SELECT *` (DEBT-009).

## Unresolved

Deployment of the view scripts is not evidenced (DEBT-010).
