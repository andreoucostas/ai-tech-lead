---
name: add-report-export
description: >
  DRAFT, pending PR review: add a new CSV report export backed by an rpt SQL view (export
  class, catalog entry, view script, GRANT to ReportReader, feature flag, test row). Use for
  "add a report", "new export", or a new rpt view.
origin: discovered
---

# Add a report export (draft, pending review)

**Status:** candidate recipe derived from the three current first-party instances (`monthly-sales`, `open-orders`, `overdue-invoices`). It is a lead, not authority; `AGENTS.md > Conventions` wins on any conflict. Draft pending PR review; not team-approved policy.

**Scope:** `src/Orders.Reporting`, `db/views`, `db/security`, `config/feature-flags.json`, `tests/Orders.Tests`.

Details, instance paths and counterevidence: [references/project-pattern.md](./references/project-pattern.md).

## Steps

1. Check whether an existing export or view already covers the report; extend it instead.
2. Add `db/views/rpt.vw<Name>.sql` (`CREATE OR ALTER VIEW rpt.vw<Name>` over `dbo.*`).
3. Add `GRANT SELECT ON rpt.vw<Name> TO ReportReader;` to `db/security/reporting-grants.sql`. Non-obvious: `SqlReportReader` signs in as `ReportReader` via the `Reporting` connection string, so a missing grant fails only at runtime.
4. Add `src/Orders.Reporting/Exports/<Name>Export.cs` implementing `IReportExport` (`Key` kebab-case, `ViewName`).
5. Add it to `ReportCatalog.All`.
6. Add `"reports.export.<key>": true` to `config/feature-flags.json`. Non-obvious: `ReportCatalog.Visible` hides any export whose flag is absent or false.
7. Add an `[InlineData("<key>")]` row to `tests/Orders.Tests/ReportCatalogTests.cs`.
8. Verify with `dotnet build Orders.sln` and `dotnet test Orders.sln`. The view, grant and runtime read are not covered by tests.

## Unresolved

- How `db/` scripts are deployed is not recorded (DEBT-010). `ReportsController` may fail to find the flags file at runtime (DEBT-001).
- Semantic refresh trigger: changes to `ReportCatalog.cs`, `IReportReader.cs` or `reporting-grants.sql`. Result: decisive sources reread 2026-11-25; no runtime proof.

## After review

Add one Common Tasks line to `AGENTS.md` (`add-report-export` — add a report export end to end), then delete the `DRAFT, pending PR review:` wording, this status paragraph and the Unresolved note in this skill and its reference file.
