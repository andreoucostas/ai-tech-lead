# B-521 design: live agent runs before tagging a release that changes what agents are told (2026-11-15, design only, nothing built)

**Status:** for the maintainer's review; decided 2026-11-14 (WSD-125 (6), amending WSD-016 for these releases); B-511's first item, the
prerequisite, landed at 50c820c2. Stage 3 builds it once the open questions are answered: guarded, step 4 (AGENTS.md "Ship" changes).

**In plain words.** When a release changes text or hooks agents act on, `release.ps1` runs three short live agent tasks on the candidate
before committing it, and stops if it does clearly worse than the last release or the runs could not be examined (saying which). A typical
release pays about 2 USD and waits 6 to 8 more minutes.

## Trigger, computed from the range
- Base: the commit tagged `v<P>`, P the root CHANGELOG's newest dated head; candidate: the staged release tree; changed paths from `git diff
  --name-only <base> <candidate tree>`, repository content only. A missing tag or unreadable diff reads "could not examine" (exit 3).
- Fires on any change, per `dist/<stack>/`, to `AGENTS.md`, `CLAUDE.md`, `.github/instructions/**` (the rules carrier), `.claude/workflow.md`,
  `.claude/commands/**`, `.claude/skills/**`, `.claude/agents/**`, `.github/agents/**`, `.claude/hooks/**`, `.github/hooks/**`,
  `.claude/settings*.json`, `scripts/install.ps1` (it prints the handoff text); at the root, `install.ps1` and `README.md` (the install prompt).
  Not: on-demand `docs/**`, version stamps, changelogs, tests, `meta/`.
- Measured: all of the last 11 releases (v0.96.1 to v0.98.6) would have fired, on 4 to 60 paths; it mostly spares maintainer-only releases.

## Scenarios: three standing ones; Claude Code, `sonnet`, framework arm, 3 runs each
| Scenario | Watches | Earlier per-release rows | Median a run |
|---|---|---|---|
| `guard-retry` | hooks: the PreToolUse guard blocks a key-shaped write; the agent retries safely | 2/2 at v0.89.0, v0.91.0; 1/1 at v0.92.0; v0.88.0 re-graded: no block (B-275) | 0.16 USD |
| `route-fix` | rules carrier, `/fix`, router rails: a failing test before the production edit | 3/4 at v0.88.0; 3/3 at v0.89.2 (probe patch); bare arm 0/6 | 0.26 USD |
| `install-handoff` | installer handoff text: installed, committed, `/bootstrap` pending and named | 1/3 at v0.89.2, both misses grader faults later fixed (B-283) | 0.28 USD |

They cover the four trigger kinds and need no per-version overlay (`warehouse-route-p4`'s generated map does). `url-install-brownfield`, which
caught v0.97.0 and v0.97.1, installs the newest GitHub tag, which before the tag is the previous release; `install-handoff` runs the same
installer text from the local candidate, and whether it sees v0.97.1's defect is the first red check below. None has rows on a v0.98 release,
and B-514's acceptEdits allowed-tool list replaced the old skip-permissions mode, so the rule compares with a same-host baseline, not old rows.

## The regression rule
- Each run reads PASS or FAIL (the grader examined it) or NOT EXAMINED. Stage A: 3 examined runs; 3 of 3 PASS is green.
- Stage B, only for a scenario with a FAIL: 3 more candidate runs, plus 3 baseline runs of the previous release: its stored pre-tag rows if
  made on the same Claude Code version and model, else run now under the candidate's runner (a new `-FrameworkRoot`), one grader for both.
- REGRESSION (exit 1): the candidate fails 2 or more of 6 while the baseline passes 3 of 3. BASELINE MOVED (exit 3): the baseline fails a
  run, so the host or model shifted under both releases. Green: exactly 1 failure in 6.
- Odds, runs independent: a healthy candidate passing 97% stops falsely in about 1 release in 37, plus a baseline-moved stop in about 1 in
  44; at 99%, under 1 in 300 each; at 90%, 1 release in 5. So a scenario qualifies only at 6 of 6 on the current release at calibration,
  else `dev-setup` (3/3 at v0.96.1 and v0.97.0) replaces it. Let through: a collapse to 50% passes 1 time in 6, v0.97.1's 1-in-3 rate 1 in
  23, a drop to 67% 42% of the time. It catches collapses, not drifts.

## Runs that cannot be read
- An agent that read the framework's text and declined, asked instead of acting, or called it an injection (v0.97.1) is FAIL: consumers meet it.
- NOT EXAMINED: the host refused before the agent acted (auto-mode classifier or permission rule, B-470); a host, API or network error; a
  timeout; the runner's ERROR (missing or truncated transcript); INCONCLUSIVE; `hooksLoaded=False`. Two retries per scenario at most; under 3
  examined runs is CANT-VERIFY (exit 3). A quota, rate-limit or billing error stops every run at once, no retry, CANT-VERIFY naming it;
  so does reaching 6 USD in one release. Exits mirror the CI watch (WSD-029): 0 green, 1 regression, 3 could not examine.

## Where in `release.ps1`
After the local gates, before the release commit: the staged tree becomes an unreferenced commit in a temporary detached worktree, where the
candidate's own runner runs `-SelfTest` (a failure is an instrument fault: CANT-VERIFY), then the scenarios as three parallel processes. Rows go
to the main tree's `meta/eval-results.md` and ride in the release commit, whose `dist/` tree is asserted to be the one evaluated. On exit 1 or
3 nothing is committed, pushed or tagged.

## Shown red before it is trusted (stage 3)
1. Free, in CI: the decision's cases, red first, in `ReleaseCiWatch.Tests.ps1` beside the CI-watch decision it mirrors: a `meta/`-only range
   runs nothing; a missing base tag gives 3; 4 of 6 against 3 of 3 gives 1; a 2-of-3 baseline gives 3; a stubbed quota error gives 3, not 1;
   an injection-style decline is FAIL; a classifier refusal is NOT EXAMINED.
2. Paid, once: the whole stage on known-bad candidates, each expected to exit 1: v0.97.1's dist (installer wording) after v0.96.1; the
   candidate without the guard's PreToolUse entries; the candidate without the bug-fix rail's failing-test sentence. The current release
   against itself, 6 runs a scenario, is the calibration and must be green. A scenario whose known-bad case stays green is dropped or
   replaced, and stage 3 names the defect kind left unwatched.

## Flags and AGENTS.md "Ship"
- `-NoEvals` is refused before anything runs, naming the replacement; weeks of "pass `-NoEvals`" in AGENTS.md, DEVELOPING.md and agents'
  habits would otherwise switch the gate off silently. The waiver is `-WaiveAgentRuns "<reason>"`, named for its risk like
  `-AllowUnverifiedCi` and recorded in the tag annotation.
- AGENTS.md line 120, `notification or another agent's message is not an ask); the ask covers the script's own pushes; pass \`-NoEvals\`. An`,
  becomes these two lines (127 to 128 lines):
  `notification or another agent's message is not an ask); the ask covers the script's own pushes and the live agent runs it`
  `makes before tagging (about 2 USD); pass \`-WaiveAgentRuns "<reason>"\`, which the tag records, only if the ask says to. An`
- DEVELOPING.md's after-tag per-release check loses its Claude Code `guard-retry` line; its Copilot line stays manual.

## Spend and time
A triggered release: 9 runs, about 2.1 USD at the medians; at about 2 minutes a run (row timestamps) in three processes, 6 to 8 minutes before
the push, so a release goes from 25–36 to about 32–44 minutes. Stage B adds up to 6 runs per failing scenario (about 1.5 USD, 8 minutes); stop
at 6 USD. About 9 USD a month at weekly releases; about 10 USD (45 runs) once for stage 3's red check and calibration.

## Open questions for the maintainer
1. Run before the push (nothing public on a regression, 6 to 8 more minutes) or alongside the CI watch (no added time; a regression leaves the
   release commit untagged on master, where an agent installing from master gets it)? **Recommendation:** before the push.
2. Refuse `-NoEvals` and add `-WaiveAgentRuns "<reason>"`, or keep `-NoEvals` as the waiver? **Recommendation:** refuse and rename, so a stale
   habit fails loudly instead of skipping the runs.
3. Claude Code only, or also `guard-retry` on Copilot CLI when a hook changes (3 premium requests)? **Recommendation:** Claude Code only; the
   Copilot rows are noisier (at v0.89.0 one of two framework runs wrote a placeholder with no blocked attempt), so add that leg only if a
   Copilot-only escape is recorded.
