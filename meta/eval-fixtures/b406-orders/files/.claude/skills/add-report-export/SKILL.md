---
name: add-report-export
description: >
  DRAFT, pending PR review: add a CSV report export to Orders, covering the rpt SQL view, the
  ReportReader grant, the export class, the ReportCatalog entry, the feature flag and the test.
  USE FOR: a new report served at api/reports/{key}.
  DO NOT USE FOR: changing CSV formatting (DEBT-009) or the reader's connection setup.
origin: discovered
---

# Add a report export (draft)

**Status: candidate, draft pending PR review. This is a lead, not authority. `AGENTS.md > Conventions` wins on any conflict.**

Derived from the three current first-party exports (`MonthlySales`, `OpenOrders`, `OverdueInvoices`). Scope: `src/Orders.Reporting`, `db/`, `config/`. Counterevidence and unresolved steps are in [references/project-pattern.md](./references/project-pattern.md).

0. Check whether an existing export or view already provides the data before adding one.
1. Add `db/views/rpt.vw<Name>.sql` with `CREATE OR ALTER VIEW rpt.vw<Name>`.
2. Add `GRANT SELECT ON rpt.vw<Name> TO ReportReader;` to `db/security/reporting-grants.sql`. The reader signs in as `ReportReader`, so a missing grant fails only at request time.
3. Add `src/Orders.Reporting/Exports/<Name>Export.cs`: a `sealed` class implementing `IReportExport` with a kebab-case `Key` and the `ViewName`.
4. Add `new Exports.<Name>Export()` to `ReportCatalog.All`. The list is manual.
5. Add `"reports.export.<Key>": true` to `config/feature-flags.json`. A missing flag hides the report (`ReportCatalog.cs:13`).
6. Add `[InlineData("<key>")]` to `tests/Orders.Tests/ReportCatalogTests.cs`.

Refresh trigger: any change to `ReportCatalog`, `SqlReportReader`, or the `db/` files. Last result: instances reread on 2026-10-17; no runtime check made.

## After review

Add one line to `AGENTS.md > Common Tasks`: ``- `add-report-export` — add a CSV report: rpt view, grant, export class, catalog entry, flag, test``. Then delete the `DRAFT, pending PR review:` wording from the description and the status line above.
