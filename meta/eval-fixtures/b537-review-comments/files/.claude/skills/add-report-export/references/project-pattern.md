# Project pattern: report exports (draft, pending PR review)

Not team-approved policy. Observed 2026-11-15; revision: `b28d35f`. Status: `observed`.

## Instances (all consumer-authored; exemplar: `open-orders`, the simplest view)

| Key | Export class | View | Grant | Flag |
|-----|--------------|------|-------|------|
| monthly-sales | `src/Orders.Reporting/Exports/MonthlySalesExport.cs` | `db/views/rpt.vwMonthlySales.sql` | `db/security/reporting-grants.sql` | `config/feature-flags.json` |
| open-orders (**exemplar**) | `.../OpenOrdersExport.cs` | `db/views/rpt.vwOpenOrders.sql` | same | same |
| overdue-invoices | `.../OverdueInvoicesExport.cs` | `db/views/rpt.vwOverdueInvoices.sql` | same | same |

Shared: `ReportCatalog.cs:5-10` lists each; `tests/Orders.Tests/ReportCatalogTests.cs` lists each key.

## Where instances diverge

Only the view SQL (aggregate vs filter). The three export classes are identical apart from `Key` and `ViewName`.

## Counterevidence / exceptions

- `SqlReportReader` interpolates `viewName` into SQL (`SqlReportReader.cs:29`); safe only while view names stay code constants.
- CSV output joins values with commas without escaping.

## Dependencies

`SqlReportReader.cs`, `ReportsController.cs:14-19` (flag loading), `ReportCatalog.cs:12-13`.
