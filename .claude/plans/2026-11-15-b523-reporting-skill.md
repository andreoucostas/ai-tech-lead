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
