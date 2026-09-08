# Repository-knowledge semantic acceptance fixture

This maintainer-only fixture supports the bounded B-222/B-223 acceptance plan dated 2026-09-08.
It contains synthetic consumer inputs and no secrets. It is not a consumer template and does not
ship in any distribution.

`inputs/base/` combines the 15 committed PK-2 inputs from Git commit
`f53c3564b22d534e15a6c09ca15547032c6b2c79` with new, explicitly labelled semantic cases. The
recovered files are preserved byte-for-byte. Stored `*.ps1.fixture` files materialize without the
`.fixture` suffix so the authoring repository's mandatory-BOM rule does not alter historical bytes.
`gitignore.fixture` materializes as `.gitignore`, keeping ignored decoys committed here but ignored
inside the actor repository.

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
