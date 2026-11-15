---
name: job-step-wiring-is-manual
description: Warehouse load procedures run only if hand-listed as steps in a Jobs/*.sql SQL Agent script; order is step order and nothing enforces dimensions-before-facts
type: gotcha
scope: Jobs/**, StoredProcedures/usp_Load*
status: unverified
last-verified: never
---
Each `Jobs/<Subject>Daily.sql` creates a SQL Agent job with `msdb.dbo.sp_add_job`, one `sp_add_jobstep` per `EXEC dbo.usp_Load*`, then `sp_add_jobserver`. Nothing in `warehouse.sqlproj` or the procedures discovers or orders loads, so a new procedure that is not added as a step never runs, and dimensions run before facts only because the author numbered the steps that way. The scripts contain no schedule, `@on_fail_action` or `@on_success_action`.
**Confidence:** observed for `Jobs/NightlyCore.sql`, `Jobs/PayrollOverdraftDaily.sql`, `Jobs/CardFacilityDaily.sql`; inferred for the other ~429 `*Daily.sql` files.
**Provenance:** requested `/bootstrap` discovery (pass A8/W2), 2026-11-15, HEAD `c7d65d0`.
**Evidence:** `Jobs/NightlyCore.sql:1-5`, `Jobs/PayrollOverdraftDaily.sql`, `Jobs/CardFacilityDaily.sql`
**Counterevidence / exceptions:** step counts and dimension sets vary by subject; whether jobs are deployed from these scripts or recreated elsewhere, and where schedules live, is not shown.
**Dependencies / unresolved:** deployment path of `Jobs/*.sql` (the SDK build may not include `msdb` scripts); the uniformity of unread jobs.
**Verify by:** list `EXEC dbo.usp_Load` steps per `Jobs/*.sql` and diff against `StoredProcedures/usp_Load*`; check each job lists `usp_LoadDim*` before `usp_LoadFact*`.
**Semantic refresh:** trigger: any change to `Jobs/*.sql` or a new `usp_Load*` procedure; result: three job scripts reread on 2026-11-15, the other jobs not yet rechecked.
**Draft status:** draft pending PR review; not team-approved policy
