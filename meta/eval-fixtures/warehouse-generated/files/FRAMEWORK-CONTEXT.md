# Framework Context

> Cross-repo context that AI agents need but cannot derive from this single repo.
> Covers: shared library APIs, multi-tenancy conventions, dashboard contracts, and cross-service patterns.
>
> **Maintenance**: Every section is drafted by `/bootstrap` from this repo's code. Drafted sections open with an auto-draft comment and cover only what this repo's code shows — the cross-repo half (why a convention exists org-wide, what other services consume, a library's full surface) still needs a maintainer. Edit any section freely; `/bootstrap` never overwrites maintainer-written content. "Detected Framework Packages" is also refreshed by `/docs-sync`. "Known Hazard Areas" is re-confirmed by `/rebootstrap`, and the session-start hook flags rows left unreviewed for 90 days. `docs-sync-check` also fails when a row's Status, Reviewed date, or named paths are invalid.
>
> **Precedence**: If `FRAMEWORK-CONTEXT.md` and `CLAUDE.md` disagree on a convention, **`CLAUDE.md` (this repo's authoritative source) wins** — but the agent must flag the contradiction. Framework-level conventions are baseline; per-repo conventions can diverge with rationale.
>
> **Versioning caveat**: Auto-drafted "Shared Libraries" entries document the **consumed** API surface at the version this repo pins; maintainer-written entries may document the **latest** surface. Either way — see "Detected Framework Packages" below — before recommending a shared-library API, verify it exists in the version this repo actually references. If unsure, say so.

---

## Production Architecture

<!-- Auto-drafted by /bootstrap on 2026-09-22 from this repo's code. Describes what THIS repo shows; a maintainer should add the cross-repo context the code cannot prove. -->

This repo is a SQL data warehouse delivery unit, not an application or dashboard: a single SDK-style SQL project (`warehouse.sqlproj`, `Microsoft.Build.Sql/0.2.0`) containing a staging → dimensional-model → reporting-view pipeline (`stg`/`dim`/`fact`/`ctl` schemas feeding `rpt.*` views). It exposes only SQL objects (tables, views, stored procedures) — there is no API, message endpoint, or hosted process in this repo. What upstream system lands rows into `stg.StgSalesOrder`, and what downstream system/tool queries the `rpt.*` views, is not evidenced here — a maintainer should document the upstream feed and the reporting/BI consumers.

---

## Shared Libraries

<!-- Auto-drafted by /bootstrap on 2026-09-22 from this repo's code. Describes what THIS repo shows; a maintainer should add the cross-repo context the code cannot prove. -->

_No shared framework packages or NuGet references found in this repo (no `.csproj`/`Directory.Packages.props` exist — it is a warehouse-SQL-only repository). The only build-tooling reference is the SQL project SDK itself: `Microsoft.Build.Sql` version `0.2.0`, declared in `warehouse.sqlproj`, with no further configuration (no `SqlServerVersion`/target platform, no `SqlCmdVariables`). If the team maintains shared warehouse tooling (a shared dbt package, a common SQL project reference, a shared CI template), a maintainer should document it here._

---

## Multi-Tenancy Conventions

<!-- Auto-drafted by /bootstrap on 2026-09-22 from this repo's code. Describes what THIS repo shows; a maintainer should add the cross-repo context the code cannot prove. -->

_No multi-tenancy signals found in this repo (no tenant identifier columns, no tenant-scoped views or procedures, as of 2026-09-22). If the warehouse is multi-tenant at another layer (e.g. one warehouse per tenant, or a tenant filter applied upstream of `stg.StgSalesOrder`), a maintainer should document it here._

---

## Dashboard Integration Contracts

<!-- Auto-drafted by /bootstrap on 2026-09-22 from this repo's code. Describes what THIS repo shows; a maintainer should add the cross-repo context the code cannot prove. -->

_No dashboard/control-plane registration or health-check wiring found in this repo (no application host exists to register one — this is a pure SQL project). If load runs are monitored by an external orchestrator or dashboard, a maintainer should document that integration here, since it cannot be observed from this repo's code._

---

## Cross-Service Communication

<!-- Auto-drafted by /bootstrap on 2026-09-22 from this repo's code. Describes what THIS repo shows; a maintainer should add the cross-repo context the code cannot prove. -->

_No HTTP client, message-bus, or correlation-ID propagation evidence found in this repo (no application code exists to hold such wiring). Load ordering between `usp_LoadDimCustomer`/`usp_LoadDimRegion` and `usp_LoadFactSales` is currently an unenforced convention with no in-repo orchestrator (see `CLAUDE.md > Repository Structure`). If an external scheduler/orchestrator sequences these procedures, a maintainer should document it here — this repo has no evidence of one either way._

---

## Known Hazard Areas

<!-- Auto-drafted by /bootstrap (and /adopt) from the Phase-2 Tier-1 architectural-risk
     synthesis (plus any domain-invariant / security findings); refined by maintainers. These
     are the "here be dragons" of this repo: load-bearing workarounds, undocumented invariants,
     high-blast-radius modules, and places where the tests do not actually pin the behaviour.
     The agent reads this before planning any change in a listed area.

     Epistemic status is REQUIRED on every row and the agent must honour it:
       [VERIFIED]   a human confirmed the cause / why it must stay this way.
       [SUSPECTED]  a human believes so but is unsure.
       [UNVERIFIED] inferred by tooling only, no human confirmation — treat as a hypothesis, not
                    a finding; it must NOT raise your confidence.
     Re-confirm any row older than ~90 days — a stale hazard map causes false confidence. -->

**Legend:** `[VERIFIED]` = a person confirmed it. `[SUSPECTED]` = a person thinks so. `[UNVERIFIED]` = only the tooling flagged it — treat it as an open question, not a finding.

Merging the PR does not confirm these — an item is confirmed only when a person answers its question and updates its status.

| Area / file(s) | Hazard | Status | Reviewed |
|----------------|--------|--------|----------|
| `StoredProcedures/usp_LoadFactSales.sql`, `StoredProcedures/usp_LoadDimRegion.sql` | No MERGE/existence-check idempotency guard — rerunning either after a partial failure or as a manual retry hits a primary-key violation (`SalesKey`/`RegionKey` collide) and the whole statement aborts. | [VERIFIED] | 2026-09-22 |
| `StoredProcedures/usp_LoadDimCustomer.sql` | New-customer surrogate key is hardcoded to the literal `-1`. A batch with more than one new customer causes the `MERGE` to attempt inserting `-1` twice, failing the primary key and blocking the entire batch. | [VERIFIED] | 2026-09-22 |
| `StoredProcedures/usp_LoadFactSales.sql` | `INNER JOIN`s to `dim.DimProduct`/`dim.DimDate` with no reject table or row-count reconciliation — any staging row without a matching product or order date is silently dropped from the fact load. | [VERIFIED] | 2026-09-22 |
| `StoredProcedures/usp_LoadDimCustomer.sql`, `StoredProcedures/usp_LoadDimRegion.sql`, `StoredProcedures/usp_LoadFactSales.sql` | No transaction wraps the dimension loads and the fact load together — if the fact load fails after the dimension loads succeeded, there is no rollback/compensation, leaving dimensions and facts inconsistent. | [VERIFIED] | 2026-09-22 |
| `Tables/stg.StgSalesOrder.sql` | No primary key or unique constraint at all — duplicate staging rows for the same order/batch cannot be prevented or detected before they reach the fact load. | [VERIFIED] | 2026-09-22 |

---

## Repository Knowledge Discovery

Bounded discovery (`/bootstrap` shared A8 pass, 2026-09-22): 25 distinct files read, 3 dependency hops (all within budget; no cycles). Findings below were folded directly into `TECH_DEBT.md`/`docs/architecture-decisions.md`/`CLAUDE.md` (no new wiki drafts were needed — every scoped fact found a home in an owner-authored artifact written this same run):

- `fact.FactSales`'s `RegionName`/`CategoryName`/`SegmentName` columns are declared but never written by `usp_LoadFactSales` → folded into `TECH_DEBT.md > DEBT-010`.
- `usp_LoadDimCustomer`/`usp_LoadDimRegion` only ever insert a hardcoded placeholder and are not rerunnable → folded into `DEBT-001`, `DEBT-002`, `DEBT-012`, and `FRAMEWORK-CONTEXT.md > Known Hazard Areas`.
- `ctl.LoadRun` is declared but disconnected from every evidenced load → folded into `DEBT-009` and `docs/architecture-decisions.md#adr-003`.
- `dim.DimProduct`/`dim.DimDate` have no load procedure in this repo → confirmed externally populated by the developer (Phase 2b); documented in `CLAUDE.md > Repository Structure`, not tracked as debt.
- `docs/ARCHITECTURE.md` (consumer-owned/protected, no `*_PENDING` marker) reads as fully populated but its content describes the AI Tech Lead framework's own tiers/hooks, not this warehouse's domain — flagged for maintainer attention, not altered by this run (owner-authored content is left to its owner). See `docs/discovery-notes.md` for the unresolved continuation.

Coverage: `Tables/`, `Views/`, `StoredProcedures/`, `warehouse.sqlproj` fully read. `docs/`, `LEARNINGS.md`, `TECH_DEBT.md`, `SECURITY_FINDINGS.md`, `docs/wiki/INDEX.md` inspected and confirmed template-only prior to this run. Framework-owned paths (`.claude/`, `.github/` tooling, most of `scripts/`) were inventory-only per `framework-ownership.json` and excluded from the evidence corpus. See `docs/discovery-notes.md` for unresolved items and the bounded continuation.

---

## Detected Framework Packages

<!-- Auto-populated by /bootstrap and /docs-sync. -->

_No application framework packages applicable to this warehouse-SQL repo (no `.csproj`/`Directory.Packages.props` found)._

### Warehouse tooling

| Tool | Version | Source |
|------|---------|--------|
| Microsoft.Build.Sql (SDK-style SQL project) | 0.2.0 | `warehouse.sqlproj` |

No dbt, DACPAC publish tooling, migration-script framework, SQL linter/formatter, or data-quality tooling (e.g. tSQLt, Great Expectations) is referenced anywhere in the repo.
