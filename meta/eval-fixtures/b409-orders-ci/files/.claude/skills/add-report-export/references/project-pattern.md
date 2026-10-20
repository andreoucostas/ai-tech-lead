# Report export: instances (draft, pending PR review)

Exemplar (cleanest): `monthly-sales`.

| Export | Class | View | Grant | Flag |
|---|---|---|---|---|
| monthly-sales | `src/Orders.Reporting/Exports/MonthlySalesExport.cs` | `db/views/rpt.vwMonthlySales.sql` | `db/security/reporting-grants.sql:2` | `config/feature-flags.json:2` |
| open-orders | `src/Orders.Reporting/Exports/OpenOrdersExport.cs` | `db/views/rpt.vwOpenOrders.sql` | `db/security/reporting-grants.sql:3` | `config/feature-flags.json:3` |
| overdue-invoices | `src/Orders.Reporting/Exports/OverdueInvoicesExport.cs` | `db/views/rpt.vwOverdueInvoices.sql` | `db/security/reporting-grants.sql:4` | `config/feature-flags.json:4` |

Shared files: `src/Orders.Reporting/ReportCatalog.cs`, `tests/Orders.Tests/ReportCatalogTests.cs`.

Counterevidence: no test checks the SQL views or grants.
