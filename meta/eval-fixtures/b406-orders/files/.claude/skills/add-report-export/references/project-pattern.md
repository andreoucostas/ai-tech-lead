# Report export pattern (draft pending PR review; not team-approved policy)

**Provenance:** requested `/bootstrap` discovery on 2026-10-17, read from first-party source at HEAD `06a55f3`.
**Confidence:** observed for steps 1-6; inferred that the order is the intended one.

## Instances (all consumer-authored)

- `MonthlySales`: `src/Orders.Reporting/Exports/MonthlySalesExport.cs`, `db/views/rpt.vwMonthlySales.sql`
- `OpenOrders`: `src/Orders.Reporting/Exports/OpenOrdersExport.cs`, `db/views/rpt.vwOpenOrders.sql`
- `OverdueInvoices`: `src/Orders.Reporting/Exports/OverdueInvoicesExport.cs`, `db/views/rpt.vwOverdueInvoices.sql`
- Shared wiring: `db/security/reporting-grants.sql`, `src/Orders.Reporting/ReportCatalog.cs:5-13`, `config/feature-flags.json`, `tests/Orders.Tests/ReportCatalogTests.cs`

**Cleanest exemplar:** `OpenOrders`.

## Non-obvious, repo-specific steps

- `src/Orders.Reporting/IReportReader.cs:11` and the grants file state that the reader signs in as `ReportReader`, which holds SELECT only on the listed views.
- `ReportCatalog.Visible` hides any export without a `reports.export.<key>` flag set to true. `tests/Orders.Tests/Orders.Tests.csproj` links the flag file into test output.

## Counterevidence and unresolved

- How `db/` scripts are deployed (order, tooling, environments) is not evidenced in the repo.
- `SELECT *` over the view means column changes alter CSV shape. CSV is unescaped (DEBT-009).
- `config/feature-flags.json` also holds `orders.checkout.v2`, which no code reads.

**Semantic refresh:** trigger: changes to the files above; result: decisive lines reread on 2026-10-17, no execution.
**Draft status:** draft pending PR review; not team-approved policy.
