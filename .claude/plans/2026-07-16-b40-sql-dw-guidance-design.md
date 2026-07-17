# B-40 design — SQL / data-warehouse guidance: two skills + DW-aware bootstrap and defaults (LOCKED 2026-07-17, WSD-021)

> **Status: DESIGN LOCKED, implemented same-day (v0.31.0).** Deviations need a new WSD entry.
> Trigger: maintainer request (2026-07-16) — the framework covers no SQL at all; most consumer
> solutions have a SQL backend, and data-warehouse repos need tech-lead guidance on following
> existing patterns and never loading the same data twice.
> The full pre-implementation plan (with the adversarial-review disposition) lives in the
> maintainer's session plan; this file records the locked design surface.

---

## 1. Problem

The framework had zero SQL/data-warehouse coverage — no mention of staging, dimensions, facts,
slowly changing dimensions, or partitioning anywhere in `src/`. Warehouse repos have concerns no
existing artifact addresses: layer structure (staging → warehouse → marts), fact/dim load
ordering, batch/watermark control, versioned runs, SCD strategy, partition alignment — and the
dominant tech-lead invariant, *never load the same data twice*.

## 2. Locked decisions

1. Ship to **dotnet + monorepo** dists only (dotnet-authored skills flow to dist/monorepo
   automatically; angular untouched except the every-version changelog entry).
2. Shape: **two skills** + bootstrap A2 detection + defaults.md blocks — integrated into the
   existing routing, no parallel infrastructure.
3. Dialect: **neutral principles, T-SQL only as evidence-gated illustration** — never assume
   SQL Server.
4. **B-35-consistent** (Verification Rule 10 already shipped): Step-0 STOP gates on grep-able
   evidence; evidence-keyed defaults blocks; derive from the consumer repo's existing pattern,
   ask when greenfield.

## 3. Design

- **`map-warehouse`** (process skill, perf-style): map layers incl. consumption views/marts,
  entities + grain, load flow/ordering, control & idempotency mechanics, SCD strategy,
  partitioning; report table + findings; offer `docs/warehouse-map.md`.
- **`add-warehouse-load`** (instance-shaped `add-X` skill, exemplar-pinned by bootstrap):
  find-the-pattern-to-copy, entity design (grain first), staging, **idempotent load**
  (watermark / batch-ID dedup / delete-window / merge+row-hash / versioned runs where a rerun
  IS a new version and the guard is "one current version"), SCD mechanics, orchestration
  ordering, partition alignment, deployment vehicle, sign-off checklist.
- **Evidence gate (both skills, two tiers):** SQL-repo tier (`.sql` tree / `.sqlproj` /
  `dbt_project.yml`) **AND ≥2 DW-tier signals grepped inside SQL artifacts only**
  (layer-schema prefixes, `Dim*`/`Fact*` naming, load procs, batch/watermark control tables,
  change-tracking columns, partition objects, ETL pipeline artifacts). Patterns
  word-boundary-hardened to avoid xUnit `FactAttribute`/prose false positives.
- **Bootstrap A2**: enumeration widened (SQL project / stored-procedure codebase), preamble
  widened to repo artifacts, two conditional analysis bullets. **Phase 3a**: three-way rule —
  DW signals → keep both + exemplar-pin; SQL-only → delete both; neither → delete both.
  `map-warehouse` joins the exempt process-skill list; `add-warehouse-load` joins the
  instance-shaped list (bootstrap + rebootstrap, both stacks).
- **defaults.md**: preamble widened to file-tree evidence; two new evidence-keyed blocks
  (raw SQL / stored procedures; data-warehouse signals).
- **Cross-routing**: `add-entity` DO-NOT-USE-FOR gains "warehouse fact/dimension tables (use
  add-warehouse-load)".

**Rejected:** a data-warehouse dist (wrong altitude — same reasoning as B-35's rejected
MongoDB dist); folding warehouse discovery into `/bootstrap` (it is a re-runnable dev-time
task, like `perf`); one mega-skill (discovery and change-recipe have different triggers and
context costs).

## 4. Files touched

- NEW: `src/stacks/dotnet/files/{.claude,.github}/skills/{map-warehouse,add-warehouse-load}/SKILL.md` (4, byte-identical pairs)
- Rosters: `src/stacks/{dotnet,monorepo}/snippets/CLAUDE.md/skills-list`, `src/stacks/{dotnet,monorepo}/files/AGENTS.md`, both READMEs, both `docs/ARCHITECTURE.md` (+ regenerated `architecture.html` via `build-architecture-html`), both `rebootstrap.md`
- `src/stacks/{dotnet,monorepo}/files/.claude/commands/bootstrap.md` (A2 + Phase 3a)
- `src/stacks/{dotnet,monorepo}/files/docs/defaults.md`
- `add-entity/SKILL.md` (`.claude` + `.github`)
- Changelogs: root + shipped ×3 (angular gets a "no changes" entry — version-stamp gate)

## 5. Acceptance criteria

1. No `dist/*` artifact instructs a SQL technology unconditionally; every warehouse recipe is
   gated behind repository evidence.
2. Both skills present and byte-identical (`.claude`/`.github`) in `dist/dotnet` and
   `dist/monorepo`; absent from `dist/angular`.
3. `validate-dist` ×3, hook suites ×3, meta suite green; Common Tasks CLAUDE↔AGENTS parity
   manually verified (not machine-gated).
4. An OLTP repo (EF Core, xUnit `[Fact]`s, a `staging` deployment folder) does not pass the
   Step-0 gate; an SSDT OLTP repo without warehouse signals gets the raw-SQL defaults block and
   loses both skills at bootstrap Phase 3a.

## 6. Out of scope

No angular content changes; no new hooks; no `src/core` edits; no SQL-Server assumption
anywhere unconditional; no query-tuning/BI-tool guidance; no new dist.
