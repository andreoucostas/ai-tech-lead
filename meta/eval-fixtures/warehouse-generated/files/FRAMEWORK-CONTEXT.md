# Framework Context

> Cross-repo context that AI agents need but cannot derive from this single repo.
> Covers: shared library APIs, multi-tenancy conventions, dashboard contracts, and cross-service patterns.
>
> **Maintenance**: Every section is drafted by `/bootstrap` from this repo's code. Drafted sections open with an auto-draft comment and cover only what this repo's code shows — the cross-repo half (why a convention exists org-wide, what other services consume, a library's full surface) still needs a maintainer. Edit any section freely; `/bootstrap` never overwrites maintainer-written content. "Detected Framework Packages" is also refreshed by `/docs-sync`. "Known Hazard Areas" is re-confirmed by `/rebootstrap`, and the session-start hook flags rows left unreviewed for 90 days. `docs-sync-check` also fails when a row's Status, Reviewed date, or named paths are invalid.
>
> **Precedence**: If `FRAMEWORK-CONTEXT.md` and `AGENTS.md` disagree on a convention, **`AGENTS.md` (this repo's authoritative source) wins** — but the agent must flag the contradiction. Framework-level conventions are baseline; per-repo conventions can diverge with rationale.
>
> **Versioning caveat**: Auto-drafted "Shared Libraries" entries document the **consumed** API surface at the version this repo pins; maintainer-written entries may document the **latest** surface. Either way — see "Detected Framework Packages" below — before recommending a shared-library API, verify it exists in the version this repo actually references. If unsure, say so.

---

## Production Architecture

<!-- Auto-drafted by /bootstrap on 2026-10-14 from this repo's code. Describes what THIS repo shows; a maintainer should add the cross-repo context the code cannot prove. -->

This repository is a SQL Server data warehouse delivered as a SQL Server Database Project (`warehouse.sqlproj`, `Microsoft.Build.Sql` SDK) — there is no application/API host. It consumes staged sales-order data (`stg.StgSalesOrder`) and produces a star-schema fact table (`fact.FactSales`) joined to four dimensions (`dim.DimCustomer`, `dim.DimProduct`, `dim.DimDate`, `dim.DimRegion`), exposed through three reporting views (`rpt.vwExecutiveSummary`, `rpt.vwFinanceExtract`, `rpt.vwOrderDetail`). How staging data arrives (an upstream ETL stage, a message feed, or a direct load) and how/when the schema is actually deployed are not evidenced in this repository — no CI workflow, scheduler, or orchestration file is committed here.

---

## Shared Libraries

<!-- Auto-drafted by /bootstrap on 2026-10-14 from this repo's code. Describes what THIS repo shows; a maintainer should add the cross-repo context the code cannot prove. -->

_No framework packages detected in this repo. This is a warehouse-only repository (no `.csproj` files, no NuGet references) — the only evidenced tooling is the `Microsoft.Build.Sql` SDK (version `0.2.0`) referenced by `warehouse.sqlproj`, which builds/packages the schema as a database project. It is not a shared application library, so it is not entered as one below._

Template entry (kept for reference — fill in if an application profile is added later):

```markdown
### Acme.Framework.Auth

- **Source**: https://github.com/<org>/Acme.Framework.Auth
- **Purpose**: Tenant-aware authentication primitives, JWT bearer middleware, OIDC handlers.
- **Latest version**: 4.2.0
- **Public API surface (latest)**:
  - `services.AddAcmeAuthentication(options => ...)` — registers JWT bearer + OIDC + tenant resolver
  - `services.AddAcmeAuthorization()` — registers default policy + role handlers
  - `[RequireTenant]` attribute — enforces tenant claim on the action
- **Common pitfalls**: Do not call `AddAuthentication()` directly after `AddAcmeAuthentication()` — it overwrites the scheme registration.
```

---

## Multi-Tenancy Conventions

<!-- Auto-drafted by /bootstrap on 2026-10-14 from this repo's code. Describes what THIS repo shows; a maintainer should add the cross-repo context the code cannot prove. -->

_No multi-tenancy signals found in this repo (no `TenantId` columns, tenant claims, or tenant-scoped query filters, as of 2026-10-14 — checked every table and view). If this warehouse is multi-tenant at another layer (e.g., row-level security applied outside this project, or one database per tenant), a maintainer should document it here._

---

## Dashboard Integration Contracts

<!-- Auto-drafted by /bootstrap on 2026-10-14 from this repo's code. Describes what THIS repo shows; a maintainer should add the cross-repo context the code cannot prove. -->

_No dashboard/control-plane integration signals found in this repo (no health-check endpoints, heartbeat calls, or registration metadata — this repository contains only warehouse schema/load/view objects, with no application host to register one). If this warehouse registers with a control plane through an external deployment pipeline, a maintainer should document it here._

---

## Cross-Service Communication

<!-- Auto-drafted by /bootstrap on 2026-10-14 from this repo's code. Describes what THIS repo shows; a maintainer should add the cross-repo context the code cannot prove. -->

_No cross-service communication signals found in this repo (no HTTP client registrations, message-bus packages, or correlation-ID propagation — this repository contains only warehouse schema/load/view objects, with no application host). If staging data (`stg.StgSalesOrder`) arrives via an external integration or message bus, a maintainer should document that feed here._

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
     Confirm or re-confirm any row older than ~90 days — a stale hazard map causes false confidence. -->

**Legend:** `[VERIFIED]` = a person confirmed it. `[SUSPECTED]` = a person thinks so. `[UNVERIFIED]` = only the tooling flagged it — treat it as an open question, not a finding. `Reviewed` = the day the row was added, or a person last confirmed or dismissed it; nothing else changes it.

Merging the PR does not confirm these — an item is confirmed only when a person answers its question and updates its status.

| Area / file(s) | Hazard | Status | Reviewed |
|----------------|--------|--------|----------|
| `StoredProcedures/usp_LoadDimCustomer.sql`, `Tables/dim.DimCustomer.sql` | `usp_LoadDimCustomer.sql:1`'s `MERGE ... WHEN NOT MATCHED THEN INSERT` always inserts the literal `CustomerKey = -1`; `dim.DimCustomer.sql:2` declares `CustomerKey` as the table's `PRIMARY KEY`, so a staging batch with more than one distinct new customer would violate that PK on the second insert. | [UNVERIFIED] | 2026-10-14 |
| `StoredProcedures/usp_LoadDimRegion.sql`, `Tables/dim.DimRegion.sql` | `usp_LoadDimRegion.sql:1` is a plain `INSERT` with no existence guard, always inserting the literal `RegionKey = -1`; re-running the load a second time would violate `dim.DimRegion.sql:1`'s `PRIMARY KEY` on `RegionKey` — the load is not safely re-runnable. | [UNVERIFIED] | 2026-10-14 |
| `StoredProcedures/usp_LoadFactSales.sql`, `Tables/ctl.LoadRun.sql` | `usp_LoadFactSales.sql:1-7` has no watermark or batch guard and never reads or writes `ctl.LoadRun.sql:1`'s `Watermark`/`LoadRunId` columns (confirmed dead — no procedure in the repo references `ctl.LoadRun`); re-running it over the same staging batch would violate `fact.FactSales`'s `PRIMARY KEY` on `SalesKey`. | [UNVERIFIED] | 2026-10-14 |
| `Tables/dim.DimProduct.sql`, `StoredProcedures/usp_LoadFactSales.sql` | No `usp_LoadDimProduct` or equivalent exists anywhere in the repo, yet `usp_LoadFactSales.sql:6` inner-joins `dim.DimProduct`; confirmed by globbing `StoredProcedures/**` (only 3 files, none for Product or Date) — the join silently returns zero fact rows until the table is populated by an unevidenced external mechanism. | [UNVERIFIED] | 2026-10-14 |

---

## Repository Knowledge Discovery

_A8 pass (2026-10-14): 21 files read (every `.sql` source file, `warehouse.sqlproj`, and all existing
registers/docs); 2 dependency hops from `Tables/**` → `StoredProcedures/**` → `Views/**`, no cycles.
All findings routed to `TECH_DEBT.md`/`FRAMEWORK-CONTEXT.md > Known Hazard Areas` (schema columns/
tables with no producer or consumer, confirmed absences) rather than the wiki, since each duplicates
an existing debt/hazard owner — no new wiki draft or project skill was created (the hardcoded-key
pattern has only 2 instances, below the 3-instance skill threshold). Unresolved: whether
`dim.DimProduct`/`dim.DimDate`/`ctl.LoadRun` are populated or read by an external, uncommitted
orchestrator — no such evidence exists in this repository. `SECURITY_FINDINGS.md` was not opened
(inventory-only; low priority, sibling registers confirmed template-only). Next bounded continuation:
re-grep the full repo if a future commit adds `Scripts/`, a publish profile, or test assets; re-check
if an external orchestrator definition is ever committed here._

---

## Detected Framework Packages

_No application framework packages applicable to this warehouse-SQL repo (no `.csproj` files)._

**Warehouse tooling**

| Tool | Version | Source |
|------|---------|--------|
| `Microsoft.Build.Sql` (SDK) | 0.2.0 | `warehouse.sqlproj` |
