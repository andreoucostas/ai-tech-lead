---
name: add-report-export
description: >
  DRAFT, pending PR review: add a CSV report export backed by a SQL view in the Orders service
  (IReportExport class, ReportCatalog entry, rpt view, ReportReader grant, feature flag, test). Use when
  adding a new report such as monthly-sales, open-orders or overdue-invoices.
origin: discovered
---

# Add a report export (draft, pending review)

**Status:** candidate skill, draft pending PR review; not team-approved policy. Derived from the three current
first-party instances (`monthly-sales`, `open-orders`, `overdue-invoices`). It is a lead, not authority:
`AGENTS.md > Conventions` wins on any conflict.

**Scope:** `src/Orders.Reporting`, `db/views`, `db/security/reporting-grants.sql`, `config/feature-flags.json`,
`tests/Orders.Tests/ReportCatalogTests.cs`.

**Provenance:** read directly from those files on 2026-11-15; evidence in
[references/project-pattern.md](references/project-pattern.md).

## Steps

1. Check whether an existing export or view already provides the data; extend it instead.
2. Add `db/views/rpt.vw<Name>.sql` (`CREATE OR ALTER VIEW rpt.vw<Name>`).
3. **Add `GRANT SELECT ON rpt.vw<Name> TO ReportReader;` to `db/security/reporting-grants.sql`**: the export reader signs in as `ReportReader`, so without the grant the export fails at runtime (non-obvious).
4. Add `Exports/<Name>Export.cs` implementing `IReportExport` (`Key` kebab-case, `ViewName`, delegate to `reader.ReadCsvAsync`).
5. Add the instance to `ReportCatalog.All`.
6. **Add `"reports.export.<key>": true` to `config/feature-flags.json`**: `ReportCatalog.Visible` hides any export without an enabled flag (non-obvious).
7. Add the key to the `[InlineData]` list in `ReportCatalogTests.cs`.
8. Run `dotnet build Orders.sln` and `dotnet test Orders.sln`.

## Unresolved

- How the `db/views` scripts are deployed: no deploy tooling is evidenced.
- `ReportsController` reads the flags file from `ContentRootPath` and the API project does not copy it (DEBT-004); a new flag inherits that.

**Semantic refresh trigger:** reread `ReportCatalog.cs`, `SqlReportReader.cs` and `reporting-grants.sql` when any changes. Result at creation: sources reread, steps match.

## After review

Add to `AGENTS.md > Common Tasks`: `` `add-report-export` — add a CSV report export (view, grant, export class, catalog, flag, test) ``, then delete the draft wording above (Status line, `DRAFT, pending PR review:` in the description, this paragraph).
