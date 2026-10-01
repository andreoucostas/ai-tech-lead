# Repository Knowledge Discovery — detail

> Written by the `/bootstrap` shared A8 pass on 2026-10-01. See `FRAMEWORK-CONTEXT.md > Repository
> Knowledge Discovery` for the 12-line summary this file backs. Draft findings here are pending PR
> review, not team-approved policy — do not treat them as instructions.

## Coverage

- **Semantically inspected (23 files)**: `warehouse.sqlproj`; all 7 `Tables/*.sql`; all 3
  `StoredProcedures/*.sql`; all 3 `Views/*.sql`; `docs/ARCHITECTURE.md`,
  `docs/architecture-decisions.md`, `docs/wiki/INDEX.md`, `TECH_DEBT.md`, `FRAMEWORK-CONTEXT.md`,
  `LEARNINGS.md`, `framework-ownership.json`, `.claude/commands/bootstrap.md`,
  `.claude/agents/bootstrap-pass.md`.
- **Inventory-only, excluded (framework-owned/overwritten per `framework-ownership.json`)**:
  `docs/playbook.md`, `docs/defaults.md`, `docs/REVIEW-GUIDE.md`, `docs/upgrade-checklist.md`,
  `docs/ci-integration.md`, `docs/enforcement-surfaces.md`, `docs/architecture.html`,
  `specs/README.md`, `tests/evals/cases.yaml`, `tests/evals/README.md`, all of `.claude/**`,
  `.github/**`, `scripts/**` (agents, commands, hooks, prompts, skills, settings, workflows, CI).
- **Not read this pass (no warehouse-domain signal expected)**: `SECURITY_FINDINGS.md`,
  `LICENSES/ai-tech-lead-MIT.txt`, `NOTICE-ai-tech-lead.md`, `AGENTS.md`/`CLAUDE.md` (already in
  session context, not re-read independently).
- **Dependency hops**: 1–2 hops from the fact table and stored-procedure seeds into dependent
  tables/procedures and consuming views. The SQL object graph is a strict DAG (`stg` → `dim` →
  `fact` → `rpt`) — no cycles encountered.
- **Budget**: 23 of 40 content files read; 17 remain.

## Findings routed to TECH_DEBT.md (not duplicated here)

| Finding | Routed to |
|---|---|
| `fact.FactSales` denormalized columns (`RegionName`/`CategoryName`/`SegmentName`) declared, never populated by `usp_LoadFactSales` | DEBT-008 |
| `ctl.LoadRun` defined but never read or written by any load procedure | DEBT-004 |
| No load procedure exists for `dim.DimProduct` or `dim.DimDate` despite `usp_LoadFactSales` depending on both | DEBT-001 |
| `dim.DimCustomer` declares SCD2 columns (`EffectiveFrom`/`EffectiveTo`/`IsCurrent`) with no `WHEN MATCHED` logic in `usp_LoadDimCustomer` | DEBT-002 |

## Finding captured as a new wiki draft

- **Repository provenance** — all 13 SQL objects were added in a single `44e911a fixture baseline`
  commit, with no project-authored domain documentation. See
  [docs/wiki/repo-is-synthetic-fixture-baseline.md](./wiki/repo-is-synthetic-fixture-baseline.md).
  This qualifies (does not negate) every debt item above — a reviewer should know these gaps were
  observed in a from-scratch fixture, not inferred from years of drift.

## Candidates noted but not detailed this pass (batch cap, not a completeness cap)

- `usp_LoadDimRegion`'s hardcoded single-row `INSERT ... SELECT DISTINCT -1, 'Unknown'` — same
  stub shape as the `usp_LoadDimCustomer` finding (DEBT-003 already covers this at TECH_DEBT.md
  level; a fuller trace of the pattern was not done).
- Complete absence of any parameterization/idempotency guard in `usp_LoadFactSales` against
  reruns of the same `BatchId` (DEBT-005 already covers this at TECH_DEBT.md level).

## Unresolved / inaccessible

- How, or whether, `dim.DimProduct` and `dim.DimDate` are actually populated in any real run — no
  evidence in this repo; the next useful source would be a CI/orchestration script or seed-data
  file, neither of which exists under tracked paths.
- Whether `.claude/skills/add-warehouse-load/SKILL.md` and `.claude/skills/map-warehouse/SKILL.md`
  (both framework-owned, not opened as evidence this pass) already anticipate these exact gaps.

## Next bounded continuation

Remaining budget (17 files) could cover: `usp_LoadDimRegion`'s stub pattern in full detail, a
rerun/idempotency trace on `usp_LoadFactSales`, and a recheck of `SECURITY_FINDINGS.md` to confirm
it is still template-only before any future capture pass.
