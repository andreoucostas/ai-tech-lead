# Project pattern: warehouse loads in this repo

**Provenance:** discovered by `/bootstrap` on 2026-11-15 from first-party files; not team-approved policy. `AGENTS.md > Conventions` wins on any conflict. **Draft status:** draft pending PR review.

## Scope

Applies to new `usp_Load*` procedures. Evidence read: `StoredProcedures/usp_LoadFactTransaction.sql`, `usp_LoadFactAccountBalanceMonthly.sql`, `usp_LoadDimCustomer.sql`, `usp_LoadDimAccount.sql`, `usp_LoadBridgeAccountHolder.sql`, `usp_LoadFactBrokerageRepaymentEvent.sql`, `usp_LoadFactBrokerageRepaymentMovement.sql`, `usp_LoadDimBrokerageRepayment.sql`, `usp_LoadDimCardFacility.sql`, `Jobs/NightlyCore.sql`, `Jobs/BrokerageRepaymentDaily.sql`, and the matching `Tables/*.sql`.

## Steps observed

1. `Tables/stg.Stg<Name>.sql` with a `BatchId BIGINT NOT NULL` column; dim, fact (with `LoadRunId`) and bridge tables in `Tables/`.
2. `StoredProcedures/usp_Load<Kind><Name>.sql` in `dbo`. Exemplar for facts: `usp_LoadFactTransaction.sql` (transaction, `MAX(BatchId)`, delete the batch, re-insert filtered by `BatchId`). Exemplar for SCD2: `usp_LoadDimCustomer.sql`. Type 1: `usp_LoadDimAccount.sql` (`MERGE`).
3. Add steps to a `Jobs/*.sql` file (one job per domain): dims first, then facts, `@step_name` equal to the procedure name; create the job with `sp_add_job` and finish with `sp_add_jobserver`.
4. If reports are needed, follow the `add-reporting-view` draft.

## Counterevidence

The 60 domain fact loads and 81 domain dim loads (for example `usp_LoadFactBrokerageRepaymentEvent.sql`, `usp_LoadDimBrokerageRepayment.sql`) skip the batch filter, and their dims insert surrogate key -1. They are recorded as DEBT-001 to DEBT-003, not as the pattern to copy. The idempotent pattern is the developer's default choice, not a reviewed decision.

## Unresolved

Staging truncation between runs; the upstream process that fills staging; whether `Jobs/` files are part of the sqlproj build.

Semantic refresh trigger: any change to `usp_LoadFactTransaction.sql`. Result at drafting: reread 2026-11-15, pattern as described.
