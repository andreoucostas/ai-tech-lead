---
name: add-report-export
description: >
  DRAFT, pending PR review: add a CSV report export to the Orders service (SQL view, grant,
  IReportExport class, ReportCatalog entry, feature flag, test). Use when adding a report such
  as monthly-sales or open-orders.
origin: discovered
---
# Add a report export (draft)

**Status:** candidate, draft pending PR review. Derived from the three current first-party instances (`monthly-sales`, `open-orders`, `overdue-invoices`). It is a lead, not authority; `AGENTS.md > Conventions` wins on any conflict. Instances are in [references/project-pattern.md](./references/project-pattern.md).

1. Check whether an existing export or view already provides the data (`src/Orders.Reporting/Exports/`, `db/views/`).
2. Add `db/views/rpt.vw<Name>.sql` (`CREATE OR ALTER VIEW rpt.vw<Name>`).
3. **Add a `GRANT SELECT ... TO ReportReader` line in `db/security/reporting-grants.sql`**. Exports read through the `Reporting` connection string, which signs in as `ReportReader`; without the grant the export fails at run time.
4. Add `src/Orders.Reporting/Exports/<Name>Export.cs` implementing `IReportExport` (`Key` kebab-case, `ViewName` = `rpt.vw<Name>`).
5. Add `new Exports.<Name>Export()` to `ReportCatalog.All`.
6. **Add `"reports.export.<key>": true` to `config/feature-flags.json`**. `ReportCatalog.Visible` hides any export whose flag is missing or false (`ReportCatalog.cs:12-13`).
7. Add the key to `InlineData` in `tests/Orders.Tests/ReportCatalogTests.cs`.
8. Run `dotnet build Orders.sln` then `dotnet test Orders.sln --no-build`.

Unresolved: how the SQL in `db/` is deployed (no pipeline or project in the repo), and whether the flags file reaches the Api output (see wiki `reports-feature-flags-path`).

Semantic refresh: trigger is a change to `ReportCatalog`, `SqlReportReader` or `db/`; result at creation: instance files read and the visibility predicate reread.

## After review
Add to `AGENTS.md > Common Tasks`: ``- `add-report-export` — add a CSV report export (view, grant, export class, catalog entry, feature flag, test)``, then delete the `DRAFT, pending PR review:` wording and this section.
