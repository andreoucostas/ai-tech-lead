# B-523 pre-registration: does a write-side skill for warehouse reporting views beat the framework as shipped today? (2026-11-15, frozen by the commit that holds it, before any paid run)

**Status:** frozen before any paid run. Maintainer direction 2026-11-14 ("Skill for views/procs", WSD-127, superseding WSD-121):
ship a write-side recipe for reporting views and stored procedures, built on the warehouse map's proven joins, only if a
measurement on a warehouse fixture, pre-registered first, supports it. Power BI is out of scope. No fixed spend stop, but the
account's weekly allowance is about 75% used, so a pilot runs first as a ceiling check. Basis: master at 18714141, `dist/dotnet`
stamp 0.98.6, root CHANGELOG head 0.99.0 Unreleased. Claude Code only; Copilot is out of scope for the measurement.

## The candidate skill

`add-warehouse-report`, drafted at `src/stacks/dotnet/files/.claude/skills/add-warehouse-report/SKILL.md` (5,133 bytes, sha256
`37e74bc36ea4…`), left uncommitted during the runs so that `dist/` and every committed tree stay as they are; the monorepo dist
would inherit it through the build. Scope: a reporting view or reporting procedure in a SQL warehouse repo, or a change to one;
not an ad-hoc query (map-warehouse's Querying rules), not a load (`add-warehouse-load`), not BI-tool authoring. Steps: 0 the shared
applicability gate; 1 joins from `docs/warehouse-map.md` (edge list, Findings, Querying), a scoped `map-warehouse` pass where it is
missing, stale or silent, and only `Declared`/`In use`/`Load-derived` edges; 2 a report contract before SQL (fact, output grain,
owning dimension per attribute, measure additivity, version resolution per edge, time buckets, reconciliation target); 3 SQL under
the Querying rules; 4 deploy like the closest siblings (name and folder, create form, the role and file of their `GRANT`s,
any project, manifest or catalog registration), inventing none; 5 the evidenced build or validation command, and a report that
names the grain, edges and known gaps; 6 the object recorded in the map's consumption surface where a stamped map exists
(WSD-122's rule, as `add-warehouse-load` step 11). `map-warehouse` is not changed. The draft was written after reading this
fixture and its generated map; every graded item below is named in it in generic terms.

## Question and prediction

Q: on a deployable reporting-view task, does the framework plus the candidate skill write a READY view (below) more often than
the framework as shipped today? Prediction, before any run: today's framework is READY in 2 of 2 pilot runs, because its map names
every edge, the dead fact columns and the `Unknown` placeholder, and B-514 saw every arm, bare included, copy a security-folder
`GRANT` it found (P2, 3 of 3 per arm). So the pilot reads CEILING and the rule reads NO-SHIP.

## Fixture and arms

- Tree: the runner's `New-EvalRepo warehouse-scale-s` (B-466's 14-file tree, digest `64fd8589eb0f…`, checked per run), then
  `install.ps1 -Stack dotnet` from the checked-out `dist/dotnet`, then B-466's generation-2 overlay `meta/eval-fixtures/warehouse-scale-s`
  (digest `a6aa94bd136c…`, now checked per run; its map's KNOWLEDGE was recorded CORRECT) with the scenario's `overlayPatch` applied
  inside the overlay's one commit, as B-514's arms were (`Initialize-GeneratedOverlay`).
- `meta/eval-fixtures/b523-reporting/control.patch` (sha256 `264195f79892…`): `Security/ReportReader.sql` creates the role and
  `Security/rpt.Permissions.sql` grants SELECT on each of the three `rpt` views to it. This is the deploy step a real reporting
  layer shows beyond naming. S's `warehouse.sqlproj` is SDK-style (`Microsoft.Build.Sql`), which builds every `.sql` file, so there
  is no deploy list to register in and none is invented.
- `skill.patch` (sha256 `4346d36646f6…`): the same layer, the draft's exact bytes at `.claude/skills/add-warehouse-report/SKILL.md`,
  and one Common Tasks line after `add-warehouse-load`'s, the line the skills-list snippet would gain if it ships.
- Arms: **C**, the framework as shipped today (`warehouse-report-write`); **K**, the framework plus the skill
  (`warehouse-report-write-skill`). No bare arm: it does not enter the rule, and B-466 already has the bare agent at 0 of 6 on this
  tree's read-side task.
- Disclosed bias: the overlay was generated before the layer existed, so `AGENTS.md > Conventions` does not name the grants, where a
  `/bootstrap` on the layered tree might (B-514's did name its `GRANT`). This weighs against C on `grant` only. The pilot can stop
  only on C reaching the ceiling, which the bias makes harder, so a pilot NO-SHIP stands. A full run regenerates the overlay first.

## Prompt, exact (both arms)

"Finance want monthly net revenue by customer region and customer segment. Add it to this warehouse as a reporting view, ready to
deploy. I approve this change in advance: implement it now in this session, then report what you built."

## Runs

- Host Claude Code 2.1.312 (recorded per row), `--model sonnet`. Each run is one invocation, from a shell with every `CLAUDE*` and
  `ANTHROPIC*` variable removed and `DISABLE_AUTOUPDATER=1`: `pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -Live
  -Scenario <id> -Model sonnet -Trials 1 -TimeoutSeconds 1500 -AllowedTools <list>`. The list is B-466's 57-rule run list (tag
  `f01b98a1d7ac`: B-514's 37-rule measured list, then `Bash(pwsh -NoProfile -File scripts/<name>.ps1:*)` for the ten shipped check
  scripts, then `PowerShell(& ./scripts/<name>.ps1:*)` for the same ten). Cap: the scenario's `budgetUsd` 3.00. Each row records
  cost, `system/init` model, host version and `durationMs`.
- Pilot: n = 2 per arm, in the order C, K, C, K.
- Valid: the row is not ERROR (agent exit 0, no timeout, no host failure; a budget cut exits 1 and is ERROR), the terminal result
  is `success`, and the run wrote a `.sql` file (else INCONCLUSIVE, "no .sql write"). An invalid run is repeated once after the
  fourth; a second invalid one is reported by its reason, not scored.
- Before each run, `git status` shows only the uncommitted draft beside this commit. The first quota or rate-limit refusal stops
  the series (the weekly window's hard stop included; its `allowed_warning` status is not a stop); what ran is committed and reported.

## Grading (`assertion: reportWrite`, arm-neutral; files, and the final message for the gap only)

A view is a `CREATE [OR ALTER] VIEW` in a `.sql` file new or changed since the setup commit; the best-scoring one is graded.
Comments are stripped first, except where the gap and the month assumption are read.
- **GOOD** = `fact` (reads `fact.FactSales`, sums `NetAmount`), `path` (`DimCustomer` on `CustomerKey`, `DimRegion` on
  `DimCustomer.RegionKey`, `RegionName` from `DimRegion`, `SegmentName` from `DimCustomer`, no read of the fact's never-populated
  `RegionName`, `SegmentName` or `CategoryName`), `pinned` (no `IsCurrent`, `EffectiveFrom` or `EffectiveTo`: the map marks the
  customer edge Pinned at load) and `gap` (a comment in the file or a sentence of the final message ties region, segment or
  customer to the `Unknown`/`-1` placeholder every customer resolves to today, the map's Findings).
- **DEPLOYED** = `named` (`rpt.vw<Name>` in `Views/rpt.vw<Name>.sql`, as the three siblings) and `grant` (an uncommented
  `GRANT SELECT ON <view> TO ReportReader` in any `.sql` file; whether it is in `Security/rpt.Permissions.sql` is reported).
- **READY** = GOOD and DEPLOYED: the measure the rule reads.
- Reported, not scored: a year-safe month bucket (or the `CalendarMonth` assumption stated in a comment: the DDL does not say
  whether it carries the year), the map row (`docs/warehouse-map.md` changed and naming the view), the Skill call to
  `add-warehouse-report`, a read of the map, denied calls, cost, duration, model.
- The grader decides; every row is hand-checked against the file and the stream, and a disagreement is reported beside the
  grader's value. Seen red before any run: with no grader the self-test failed "Unknown scenario 'warehouse-report-write'"; with
  it, hand-made outputs read `ready=False` for the fact's dead columns (`path=False dead=True`), `IsCurrent` on the customer join
  (`pinned=False`), no or a commented-out `GRANT` (`grant=False`), a view outside `rpt` and `Views/` (`named=False`) and no gap
  named (`gap=False`); a run with no `.sql` write and a budget cut are not examined.

## Readings and decision rule

- **Pilot.** CEILING if C is READY in 2 of 2 valid runs: the rule reads NO-SHIP and the full runs are not spent. Otherwise FULL.
- **Full** (only on FULL). First the S overlay is regenerated on the layered tree by the B-466 amendment's generation procedure
  (same caps), frozen in an amendment here; then n = 6 per arm, alternating C and K; pilot rows are not pooled. SHIP if K's READY
  count is at least C's plus 2, no scored item (`fact`, `path`, `pinned`, `gap`, `named`, `grant`) is lower in K than in C by 2 or
  more, and K's median cost is at most 1.5 times C's. Otherwise NO-SHIP. A difference of 1 is noise at this n.
- Any K run that called the skill and still missed an item the skill states is reported by name.
- A quota stop before the rule reads leaves B-523 open with the partial counts.
- NO-SHIP: the draft is removed from `src/`; the rows, this plan and the patches stay; B-523's status says so; WSD-127's Reopen
  trigger (the measurement does not support shipping; the maintainer re-decides) is named in the commit. SHIP: the guarded change
  B-523 names (the skill in the dotnet stack, its wiring, `dist/` rebuilt, CHANGELOGs).

## Not shown

Copilot CLI and VS Code; a reporting procedure (the skill covers both; the task is a view); B-466's M and L trees; other models;
interactive use; a real warehouse; a repository whose reporting objects evidence a deploy list or a report catalog.

## Second measurement: amendment, frozen before any counted run (2026-11-15, after 85931434)

The pilot above read CEILING and NO-SHIP (`meta/eval-results.md`, "B-523 results, pilot"). The maintainer re-decided under WSD-127
(in chat, 2026-11-15, relayed by the coordinator): "Test on a harder warehouse". That ceiling came from a 14-file, one-fact tree the
agent read whole and a task the map already answered. The question is unchanged; the rule below replaces the pilot's for this run.

- **Candidate v2**, frozen at aed28b20 before this fixture or task was designed: `meta/eval-fixtures/b523-reporting/candidate-v2/SKILL.md`
  (7,455 bytes, sha256 `d35160bc3896…`), written from generic dimensional-modelling rules: role-playing dates, additivity,
  as-of joins to history-keeping dimensions, bridges and weights, drill-across (fan and chasm), a procedure variant, and deploy
  steps found by searching every file for a sibling's name. It sits under `meta/`, so `dist/` and arm C stay as shipped.
- **Fixture** `warehouse-report-m`: the runner's `New-EvalRepo warehouse-report-m`, seeded (tree `d331b4d5e7d6…`, 497 files,
  495 SQL, checked per run). A banking core: `fact.FactTransaction` (one row per transaction line; `TransactionDateKey` and
  `PostingDateKey` both reach `dim.DimDate`) and `fact.FactAccountBalanceMonthly` (one row per account per month end;
  `ClosingBalance`), sharing `DimAccount` and `DimDate`; `dim.DimCustomer` keeps history (`ValidFrom`/`ValidTo`, half-open,
  plus `IsCurrent`); `bridge.BridgeAccountHolder` (`AccountKey`, `CustomerId`, `HolderWeight` = 1/n); `DimAccount` → `DimBranch`
  → `DimRegion`, with `DimBranch.RegionName` declared and never loaded. Then B-466's 41 seeded subject areas in their order, as at
  its size M. House pattern: 85 `rpt` views and one `rpt` procedure (`rpt.usp_BranchBalanceAsAt`, in
  `StoredProcedures/rpt.usp_*.sql`), each granted in `Security/rpt.Permissions.sql` (`GRANT SELECT`, `GRANT EXECUTE`) and listed
  in `Deploy/reporting.manifest`, which nothing in the tree references. Disclosed: B-466's generator also gives the padding
  views month groups without the year and sums of snapshot-named measures; the generated map flags both.
- **Overlay** `meta/eval-fixtures/warehouse-report-m` (digest `6bea207662f7…`, checked before any spend), generated as B-466's
  amendment did at size M: `/bootstrap` (2 calls, 1.21 USD) then `/map-warehouse` (2 calls, 0.71 USD), Claude Code 2.1.312,
  `claude-sonnet-5-5`, the 71-rule generation list (`57774189cbd6`), every call `success` with rate-limit status
  `allowed_warning`; the three Writes the host denied under `.claude/` applied byte for byte, the two read-only checks run by hand
  (`provenance.json`). `/bootstrap` drafted a project skill, `add-reporting-view` (DRAFT, `origin: discovered`), naming the
  manifest line and the `GRANT` for a view. Both arms carry it: it is what today's framework leaves in this repository.
- **KNOWLEDGE per trap**, read by hand in the generated `docs/warehouse-map.md` and `AGENTS.md` before any counted run:

  | trap | captured? | where |
  |---|---|---|
  | role-playing date | yes | edge list (transaction date, posting date roles); Dimensional semantics |
  | semi-additive balance | yes | "`ClosingBalance` is semi-additive: it sums across accounts for one month-end but not across months" |
  | drill-across (chasm) | yes | Querying, chasm trap, with these two facts through `DimAccount` as its example |
  | bridge weight (fan) | yes | fan trap: "`BridgeAccountHolder` is the one-to-many to watch: join it only with weights or after aggregating" |
  | as-of segment | partly, and leans wrong | edge `BridgeAccountHolder.CustomerId` → `DimCustomer` is `Deferred to query`, "`IsCurrent = 1` or an as-of rule is required", and its example rule is `vwAccountHolders`' `IsCurrent = 1`; no `ValidFrom`/`ValidTo` rule is stated |
  | snowflaked region | yes | Finding: `DimBranch.RegionName` never populated, take it from `DimRegion`; Querying rule 2 |
  | deploy (grant, manifest) | for a view | `AGENTS.md > Conventions`: a new `rpt` view needs its file, a manifest line and a `GRANT SELECT`; the draft says the same; nothing states the procedure's `GRANT EXECUTE` |

- **Arms.** C, the framework as shipped today: scenario `warehouse-report-proc` (the overlay as generated). K, the framework
  plus the candidate: `warehouse-report-proc-skill`, `skill-v2.patch` (sha256 `a2b360f8872b…`: candidate v2 byte for byte at
  `.claude/skills/add-warehouse-report/SKILL.md`, and one Common Tasks line after `add-warehouse-load`'s). No bare arm: it is not
  in the rule, and its runs would not change the decision.
- **Prompt, exact (both arms):** "Finance want a quarterly report: for a given quarter, by customer segment and by the region of
  the account's branch, the amount posted to accounts during the quarter and the accounts' closing balance at the end of the
  quarter, taking each customer's segment as it stood at the end of the quarter. Add it to this warehouse as a reporting
  procedure, ready to deploy. I approve this change in advance: implement it now in this session, then report what you built."
- **Runs** as the first measurement registered them (host, `--model sonnet`, B-466's 57-rule run list `f01b98a1d7ac`, cap 3.00
  USD, timeout 1500 s, the validity rule, an invalid run repeated once, the quota stop), from a driver that refuses to start unless
  the tree is this commit. Pilot: n = 2 per arm, C, K, C, K. Full: four more per arm, C, K alternating, pooled with the pilot,
  since nothing changes between them.
- **Grading** (`assertion: reportProc`, arm-neutral, files only; every new or changed `CREATE VIEW/PROCEDURE/FUNCTION` read
  together, comments and brackets stripped). Each trap item is True when the trap was avoided: **role** (`PostingDateKey`, never
  `TransactionDateKey`); **semi** (the balance fact restricted to one month end: an equality on `MonthEndDateKey` or on a date
  joined to it, or a `MAX`/`ROW_NUMBER`/`LAST_VALUE` pick); **drill** (no query block reads both facts row to row; a derived
  table or CTE that does not aggregate counts as its outer block); **bridge** (the bridge joined and `HolderWeight` multiplied into
  at least two measures); **asof** (`DimCustomer` restricted by `ValidFrom` and `ValidTo`, and no `IsCurrent` anywhere); **region**
  (`DimBranch` on `DimAccount.BranchKey`, `DimRegion` on `DimBranch.RegionKey`, the region read from `DimRegion`, never
  `DimBranch.RegionName`). Deploy items: **named** (`rpt.usp*` in `StoredProcedures/rpt.usp*.sql`), **grant** (`GRANT EXECUTE`
  on it to `ReportReader` in a `.sql` file), **manifest** (a line of `Deploy/reporting.manifest` names it). GOOD is all six traps,
  DEPLOYED all three, READY both. Reported only: Skill calls (`add-warehouse-report`, `add-reporting-view`), a map read, the map
  row, denied calls, cost, duration, model, version. Every row is hand-checked against the files and the stream; a disagreement
  is reported beside the grader's value. Seen red before any run: with no grader the self-test failed "Unknown scenario
  'warehouse-report-proc'"; with it, a hand-made procedure that avoids every trap reads `traps=6/6` READY, and one hand-made
  procedure per trap reads that trap False and the others True (`role`: transaction date; `semi`: three month-end balances summed;
  `drill`: lines joined row to row to the snapshot; `bridge`: the balance unweighted; `asof`: `IsCurrent = 1`; `region`:
  `DimBranch.RegionName`), as do a missing `GRANT EXECUTE`, a missing manifest line and a procedure outside `rpt` and
  `StoredProcedures/`.
- **Decision rule.** Pilot: CEILING if C avoids all six traps in 2 of 2 valid runs; the rule reads NO-SHIP and the full runs are
  not spent. Otherwise FULL. Full, n = 6 per arm: **SHIP** if K's trap passes (the six trap items summed over its six runs, 0 to
  36) are at least C's plus 6, no item of the nine is lower in K than in C by 2 or more runs, and K's median cost is at most 1.5
  times C's. Otherwise **NO-SHIP**. READY counts are reported beside. A quota stop before the rule reads leaves B-523 open with
  the partial counts.
- **Read-side finding.** A trap C misses although the generated map or `map-warehouse`'s Querying rules cover it is reported as a
  read-side finding, not fixed under B-523.
- **Prediction**, before any counted run: C avoids role, semi and region in most runs, since the map names each; as-of is its
  likeliest miss, since the map's example rule for that edge is `IsCurrent = 1`; drill and bridge are uncertain. K avoids as-of
  more often. So the pilot reads FULL, and SHIP is possible but not expected: one trap moving by about one run in six would not
  reach the plus-6 bar.
- **Grader fix after pilot runs 1 and 2, before the pilot's reading (2026-11-15).** Both runs weighted both measures as
  `<measure> * COALESCE(h.HolderWeight, 1)`, which the registered pattern (a `*` directly beside `HolderWeight`) read as
  `weights=0 bridge=False`: a false red the hand check found. The pattern now reads an Amount or Balance term multiplied by
  an expression holding `HolderWeight`, in either order; what `bridge` means is unchanged. Seen red first: a self-test case in
  run 1's form read `weights=0 bridge=False` on the old pattern, and reads `weights=2 bridge=True` now. Every row, these two
  included, is regraded with the fixed grader for the reading; the rows the runner wrote keep their old values.
- **Second widening, after pilot run 3, before the pilot's reading (2026-11-15).** Run 3 renormalised the weight into a derived
  `Share` (`HolderWeight / SUM(HolderWeight) OVER (PARTITION BY AccountKey)`) and multiplied both measures by it, which the
  first fix still read as `weights=0`. `weights` now counts Amount or Balance terms multiplied by any factor, and only when
  `HolderWeight` is read at all; one weighted measure still reads `bridge=False`. Seen red first on a self-test case in run 3's
  form. The hand check, not the pattern, is the backstop for a factor that is not the weight.
