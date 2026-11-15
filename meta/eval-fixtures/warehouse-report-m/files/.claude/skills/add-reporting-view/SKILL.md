---
name: add-reporting-view
description: >
  DRAFT, pending PR review: add or change an rpt reporting view in this warehouse. Use when
  adding a new rpt.vw* view, renaming one, or retiring one: the view file, the deploy manifest
  line and the ReportReader grant must change together.
origin: discovered
---

# Add a reporting view (DRAFT, pending PR review)

**Status:** candidate derived from the current first-party instances (85 views). It is a lead, not authority; `AGENTS.md > Conventions` wins on any conflict. Provenance and evidence are in [references/project-pattern.md](./references/project-pattern.md).

## Steps

1. Check whether an existing `Views/rpt.vw*.sql` already owns the requested report; extend it rather than adding a near-duplicate.
2. Create `Views/rpt.vw<Name>.sql` containing one `CREATE VIEW rpt.vw<Name> AS SELECT …` over `fact`/`dim` objects, joining facts to dims on `<Name>Key` and to `dim.DimDate` on `DateKey` (example: `Views/rpt.vwTransactionDetail.sql`).
3. Add `Views/rpt.vw<Name>.sql` to `Deploy/reporting.manifest` (one path per line, alphabetical among the views, before the `StoredProcedures/` line).
4. Add `GRANT SELECT ON [rpt].[vw<Name>] TO [ReportReader];` to `Security/rpt.Permissions.sql`, in the same alphabetical position, before the `GRANT EXECUTE` line.
5. Re-count: views in `Views/`, manifest `Views/` lines and view grants must all be equal (85 each when this draft was written).

Steps 3 and 4 are the non-obvious ones: nothing in the repo checks them, so a view missing from either deploys without access or is not deployed.

## Counterevidence and unresolved

- No instance was found that omits the manifest or the grant, but only counts were compared, not names for all 85.
- Whether the sqlproj build or the release pipeline orders the manifest is unresolved (the pipeline is not in this repo).
- Semantic refresh trigger: any change to `Deploy/reporting.manifest` or `Security/rpt.Permissions.sql`. Result at drafting (2026-11-15): counts matched 85/85/85; the manifest tail and the first and last grants were reread.

## After review

Add this line to `AGENTS.md > Common Tasks`: `` `add-reporting-view` — add or change an `rpt` view with its manifest line and ReportReader grant ``. Then delete the `DRAFT, pending PR review:` wording from this skill's description and this draft-status text.
