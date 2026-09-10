# Repository-knowledge semantic acceptance fixture

This maintainer-only fixture supports the bounded B-222/B-223 acceptance plan dated 2026-09-08,
and the B-235-consolidated reporting acceptance slice carried by B-222/B-223/B-224 per the
2026-09-10 plan `.claude/plans/2026-09-10-reporting-knowledge-coverage.md`. It contains
synthetic consumer inputs and no secrets. It is not a consumer template and does not ship in any
distribution.

`inputs/base/` combines the 15 committed PK-2 inputs from Git commit
`f53c3564b22d534e15a6c09ca15547032c6b2c79` with new, explicitly labelled semantic cases. The
recovered files are preserved byte-for-byte. Stored `*.ps1.fixture` files materialize without the
`.fixture` suffix so the authoring repository's mandatory-BOM rule does not alter historical bytes.
`gitignore.fixture` materializes as `.gitignore`, keeping ignored decoys committed here but ignored
inside the actor repository.

`inputs/reporting/` is an optional overlay on `inputs/base/`. It adds three first-party SQL
report sources under `reporting/` — `RunRegionRevenue.sql` (entry point, which also declares the
minimal `dbo.InvoiceLine` schema the report reads), `RenderRegionRevenue.sql` (wrapper) and
`NetLineAmount.sql` (a scalar function) — plus a short `reporting/README.md`. The `.sql` files
carry only sparse neutral headers and one bare note that `dbo.EmitExternalAdjustments` is
maintained outside this repository; every graded fact is recoverable from the executable SQL
alone. Materialization layers these files onto a base tree; the materializer emits valid
ownership metadata covering them as first-party consumer source. It introduces no new framework
command, skill, harness, `src/`/`dist/` change, version bump, or ownership field, and it reuses
the base owner wiki content (`docs/wiki/INDEX.md`, `docs/wiki/release-ownership.md`) for
capture-preservation checks. No database engine is used or required: the slice exercises source
interpretation only and makes no SQL-execution or warehouse-equivalence claim.
`prompts/reporting-capture.md` has one session act as coordinator, running the read-only
shared-A8 discovery inline (sequential fallback, no separate Agent tool) and then the parent
Phase 3a-bis scoped-fact capture over this overlay; a separate calibration step contributes one
ordinary allowed write to establish the write route. `prompts/reporting-retrieve.md` is one
fresh read-only review of a proposed change that swaps `dbo.RunRegionRevenue` for a direct
`dbo.RenderRegionRevenue` call in one region. The reporting section of `grading/answer-key.md`
grades source-derived meaning against matched successful Read or content-bearing Grep events (not
filename-only searches or header-only reads) citing the post-materialization `reporting/*.sql`
paths, capture envelope and owner preservation from the post-state file oracle, and ordinary
retrieval — including whether a captured wiki body was actually read and reused — separately from
source-only correctness; the already-recorded generic R refresh miss is not replayed, and the
existing R cases retain that evidence.

`inputs/refresh/` holds the canonical R-only owner claim. `inputs/budget/` is a separate corpus with
exactly 45 eligible first-party content files: five root prerequisites and eight files in each of
five areas. Framework workflow files, ownership/control metadata, calibration inputs, and report
handoffs are added during external materialization and are inventoried separately.

Materialization copies only the selected input tree and the current composed monorepo workflow
files into a new external Git root. The hidden grading key, this maintainer README, plans, prior
outputs, and reviewer narrative must never enter an actor root or its Git history. Every run records
stored/materialized paths, SHA-256, byte length, provenance, classification, and case membership.

Historical PK-2 source archive: Git commit `f53c3564b22d534e15a6c09ca15547032c6b2c79`.
Historical generated output is deliberately absent from the fixture.

The committed `inputs/base/src/intake/RetryPolicy.cs` is the corrected semantic fixture: the caller
reads `config/retry.json` and passes its `maxAttempts` value to `RetryBoundary.Allows`. The first
execution attempt used an earlier unbound version and is retained only in the external evidence
record; it is not a valid D2 input. Dynamic C/R/B-continuation roots and bulky actor streams are not
committed because they contain prior outputs and run-specific Git revisions. Their exact hashes,
construction corrections and adjudicated results are recorded in
`meta/repository-knowledge-semantic-acceptance.md`.
