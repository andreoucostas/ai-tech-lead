# Discovery Notes

> Written by `/bootstrap`'s shared A8 pass (bounded repository-knowledge discovery). Holds detail
> that didn't fit `FRAMEWORK-CONTEXT.md > Repository Knowledge Discovery`'s 12-line cap. Read-only
> findings — not team-approved policy, not an instruction to execute.

## Run: 2026-09-22

**Budget used**: 25 of 40 allowed content reads; 3 of the per-seed dependency-hop budget used (limit is 2 hops per seed — hops were spread across different seeds, none exceeded its own limit); no cycles encountered.

**Actual reads**: `warehouse.sqlproj`; all 7 files under `Tables/`; all 3 files under `StoredProcedures/`; all 3 files under `Views/`; `docs/ARCHITECTURE.md`, `docs/architecture-decisions.md`, `docs/wiki/INDEX.md`, `LEARNINGS.md`, `TECH_DEBT.md`, `SECURITY_FINDINGS.md`, `FRAMEWORK-CONTEXT.md`; `scripts/warehouse-signals.tsv`; `.claude/ai-audit.log`; `framework-ownership.json` and `.claude/commands/bootstrap.md` (read for pass mechanics, not as application evidence).

**Excluded (framework-owned/overwritten per `framework-ownership.json`)**: `.claude/` (agents, commands, hooks, skills), `.github/` (agents, prompts, hooks, workflows), most of `scripts/`, `docs/playbook.md`, `docs/defaults.md`, `docs/ci-integration.md`, `docs/enforcement-surfaces.md`, `docs/REVIEW-GUIDE.md`, `docs/upgrade-checklist.md`, `docs/presentation/*`, `tests/evals/*`, `specs/README.md`. These were inventory-only or read solely to confirm framework-ownership, never as a source for an application/warehouse finding.

**Unresolved / inaccessible**:
- How `dim.DimProduct`/`dim.DimDate` are actually populated in practice — the developer confirmed "externally populated" during `/bootstrap` Phase 2b, but no seed script, post-deployment script, or orchestration artifact exists in this repo to show the mechanism. Next useful source: a maintainer-named external tool or a future `usp_LoadDimProduct`/`usp_LoadDimDate` procedure, if one is ever added here.
- Whether `ctl.LoadRun` is populated by an out-of-repo scheduler today, ahead of the planned in-repo wiring (`docs/architecture-decisions.md#adr-003`). Next useful source: a deployment/orchestration config, if one is added to this repo.
- The real region/segment attribute source for `DimCustomer`/`DimRegion` — `stg.StgSalesOrder` carries no region column. Next useful source: an upstream feed definition, not present in this repo.
- `docs/ARCHITECTURE.md` describes the AI Tech Lead framework's own architecture (tiers, hooks, subagents), not this warehouse's domain, despite being consumer-owned/protected with no `*_PENDING` marker. This repo's `/bootstrap` run does not have a defined write target for that file (it is not one of the sections this workflow populates), so it was left untouched and is flagged here for a maintainer to decide whether it should describe the warehouse instead.

**Bounded continuation**: Warehouse-source coverage (`Tables/`, `Views/`, `StoredProcedures/`) is complete — every object in the repo was read. Remaining unread budget (15 of 40 reads, most of the 2-hop-per-seed allowance) would only extend into framework-owned/mixed configuration (e.g. `.claude/settings.json`), which is low-value for further application/warehouse findings. A future `/bootstrap` or `/rebootstrap` run should re-open this file if new SQL objects, an orchestrator, or a seed/reference-data mechanism are added.
