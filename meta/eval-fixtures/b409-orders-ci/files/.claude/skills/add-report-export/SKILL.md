---
name: add-report-export
description: >
  DRAFT, pending PR review: add a CSV report export to the Orders service (SQL view, grant,
  IReportExport class, ReportCatalog entry, feature flag). Use when adding a new report under api/reports.
origin: discovered
---

# Add a report export (DRAFT)

**Status:** candidate skill derived from three current first-party instances (`monthly-sales`,
`open-orders`, `overdue-invoices`). It is a lead, not authority; `AGENTS.md > Conventions` wins on any
conflict. Draft pending PR review; not team-approved policy.

**Provenance:** discovered by `/bootstrap` (A8) on 2026-10-18 from the files listed in
[references/project-pattern.md](./references/project-pattern.md). Confidence: `observed`.

## Steps

1. Check whether an existing export or view already provides the data (`src/Orders.Reporting/Exports/`, `db/views/`).
2. Add `db/views/rpt.vw<Name>.sql` using `CREATE OR ALTER VIEW rpt.vw<Name>` over `dbo.*` tables.
3. Add `GRANT SELECT ON rpt.vw<Name> TO ReportReader;` to `db/security/reporting-grants.sql`. The reader signs in as `ReportReader`, so a missing grant only fails at runtime.
4. Add `src/Orders.Reporting/Exports/<Name>Export.cs` implementing `IReportExport` (`Key` is kebab-case, `ViewName` is `rpt.vw<Name>`, `ExportCsvAsync` delegates to `reader.ReadCsvAsync(ViewName, ...)`).
5. Add `new Exports.<Name>Export()` to `ReportCatalog.All`.
6. Add `"reports.export.<Key>": true` to `config/feature-flags.json`. `ReportCatalog.Visible` hides any export whose flag is missing or false, with no error.
7. Add the key to the `[InlineData]` list in `tests/Orders.Tests/ReportCatalogTests.cs`.

## Unresolved

How views and grants are deployed (no migration/deploy tooling is in the repo), and whether `config/feature-flags.json` reaches the API at runtime (`ReportsController` reads it from `ContentRootPath/config`, and `Orders.Api.csproj` does not copy it; see TECH_DEBT DEBT-006).

## After review

Add to `AGENTS.md > Common Tasks`: ``- `add-report-export` — add a CSV report: SQL view, grant, IReportExport, ReportCatalog entry, feature flag``. Then delete the DRAFT wording from this file's description and body.
