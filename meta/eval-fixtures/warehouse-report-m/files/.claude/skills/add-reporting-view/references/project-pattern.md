# Project pattern: reporting views

**Provenance:** discovered by `/bootstrap` on 2026-11-15 from first-party files; not team-approved policy. **Draft status:** draft pending PR review.

## Instances (85 views)

Every file in `Views/` (`rpt.vw*.sql`, 85 files) has a line in `Deploy/reporting.manifest` (85 `Views/` lines) and a `GRANT SELECT` in `Security/rpt.Permissions.sql` (lines 1-85). Files actually read: `Views/rpt.vwTransactionDetail.sql` (cleanest exemplar), `Views/rpt.vwBrokerageRepaymentDetail.sql`, `Views/rpt.vwAccountHolders.sql`, `Deploy/reporting.manifest`, `Security/rpt.Permissions.sql`. The rest were counted by glob/grep only.

## Divergence

- `rpt.vwAccountHolders` joins `dim.DimCustomer` on `CustomerId` with `IsCurrent = 1` (SCD2 dim); the other views read join on surrogate keys.
- `rpt.usp_BranchBalanceAsAt` is a report procedure, not a view: it is in the manifest (last line) and has `GRANT EXECUTE`, not `SELECT`.

## Unresolved

Release-pipeline use of the manifest; whether views must be created before the grants in the sqlproj build.
