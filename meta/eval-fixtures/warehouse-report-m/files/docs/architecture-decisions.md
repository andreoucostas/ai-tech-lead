# Architecture Decisions

Append-only ADR log. Entries are added by the `create-adr` skill (format: `## ADR-NNN: <title>` with Date / Status / Decision / Context / Alternatives considered / Consequences). The one-line index lives in `AGENTS.md > Architecture Decisions`.

## ADR-001: Batch-scoped delete-and-reload for fact loads

- **Date**: 2026-11-15
- **Status**: Accepted as the convention for new loads (developer chose the default at bootstrap); not yet followed by most existing loads.
- **Decision**: A fact load runs in one transaction, takes `MAX(BatchId)` from its staging table, deletes the target rows whose `LoadRunId` (or month-end key) belongs to that batch, then re-inserts from staging filtered by `BatchId`.
- **Context**: Evidence in `StoredProcedures/usp_LoadFactTransaction.sql` and `usp_LoadFactAccountBalanceMonthly.sql`. The 60 domain fact loads (for example `usp_LoadFactBrokerageRepaymentEvent.sql`) are a single unfiltered `INSERT` and do not follow it.
- **Alternatives considered**: Unfiltered insert (current domain pattern: not re-runnable); `MERGE` upsert (not used for facts anywhere).
- **Consequences**: A rerun of the same batch is safe. Only the latest staging batch is loaded per run, so a skipped batch is never loaded (see FRAMEWORK-CONTEXT.md hazards). Domain facts remain non-conforming until DEBT-001 is done.
- **Review notes**: Accepted by default when the developer said "proceed" at the Phase 2b question; confirm with the team.
