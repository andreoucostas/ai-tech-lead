# Discovery notes (bootstrap, 2026-11-15)

Partial coverage; draft knowledge pending PR review.

- **Semantically inspected (about 35 files):** the core `usp_Load*` procedures, `rpt.usp_BranchBalanceAsAt.sql`, Brokerage Repayment tables/procs/job, `dim.DimCardFacility` and its load, `fact.FactTransaction`, `dim.DimCustomer`, `dim.DimAccount`, three views, `Security/*.sql`, `Deploy/reporting.manifest`, `Jobs/NightlyCore.sql`.
- **Inventory/grep only:** the other ~37 domains (Tables, Jobs, Views), counts of fact loads without `DELETE` (60 of 62), dim loads with `-1` key (81), dims with `IsCurrent` (26 including `DimCustomer`), job steps (149) versus load procs (149).
- **Excluded:** framework files (`.claude`, `.github`, `.agents`, `scripts`, `tests/evals`, framework docs).
- **Inaccessible/absent:** release pipeline, upstream staging process, any SQL test tooling.
- **Next bounded continuation:** read one more generated domain end to end to confirm the family is uniform; check `warehouse.sqlproj` globbing for `Jobs/` and `Deploy/`; then run `/map-warehouse`.
