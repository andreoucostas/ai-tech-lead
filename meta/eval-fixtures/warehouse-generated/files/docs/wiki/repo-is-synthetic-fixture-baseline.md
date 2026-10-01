---
name: repo-is-synthetic-fixture-baseline
description: This warehouse's SQL objects were all added in a single "fixture baseline" commit with no subsequent revisions — read load/schema gaps as a from-scratch snapshot, not years of production drift.
type: context
scope: Tables/**, StoredProcedures/**, Views/**, warehouse.sqlproj
status: unverified
last-verified: 2026-10-01
---
All 13 SQL files (`Tables/`, `StoredProcedures/`, `Views/`) and `warehouse.sqlproj` were introduced
together in a single commit (`44e911a fixture baseline`), with no subsequent revisions to any of
them. No project-authored documentation describes the warehouse's intended data model —
`docs/ARCHITECTURE.md` documents the AI Tech Lead framework's own instruction architecture, not
this warehouse's domain.
**Confidence:** observed
**Provenance:** `/bootstrap` shared A8 discovery pass, 2026-10-01
**Evidence:** `git log --oneline -- Tables StoredProcedures Views warehouse.sqlproj` (returns exactly one commit); `docs/ARCHITECTURE.md` (framework-meta content, not warehouse-domain)
**Counterevidence / exceptions:** none found
**Dependencies / unresolved:** none
**Verify by:** rerun `git log --oneline -- Tables StoredProcedures Views warehouse.sqlproj`; a growing commit count would mean the repo has moved past single-fixture status
**Semantic refresh:** trigger: a new commit touching `Tables/`, `StoredProcedures/`, `Views/`, or `warehouse.sqlproj`; result: not yet rechecked since 2026-10-01.
**Draft status:** draft pending PR review; not team-approved policy
