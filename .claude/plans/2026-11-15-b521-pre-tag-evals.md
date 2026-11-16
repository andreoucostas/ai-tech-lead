# B-521 design: live agent runs before tagging a release that changes what agents are told (2026-11-15, design only, nothing built)

**Status:** built 2026-11-16 (stage 3, guarded, step 4 after the commit); decided 2026-11-14 (WSD-125 (6), amending WSD-016 for these
releases); B-511's first item, the prerequisite, landed at 50c820c2. **The maintainer answered the three open questions in chat on
2026-11-16, each as recommended:** (1) the runs happen before the push; (2) `-NoEvals` is refused and `-WaiveAgentRuns "<reason>"`,
recorded, replaces it; (3) Claude Code only, no Copilot leg. Where the build departs from the text below, "As built" says so.

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

## Open questions for the maintainer (answered 2026-11-16: all three as recommended)
1. Run before the push (nothing public on a regression, 6 to 8 more minutes) or alongside the CI watch (no added time; a regression leaves the
   release commit untagged on master, where an agent installing from master gets it)? **Recommendation:** before the push.
2. Refuse `-NoEvals` and add `-WaiveAgentRuns "<reason>"`, or keep `-NoEvals` as the waiver? **Recommendation:** refuse and rename, so a stale
   habit fails loudly instead of skipping the runs.
3. Claude Code only, or also `guard-retry` on Copilot CLI when a hook changes (3 premium requests)? **Recommendation:** Claude Code only; the
   Copilot rows are noisier (at v0.89.0 one of two framework runs wrote a placeholder with no blocked attempt), so add that leg only if a
   Copilot-only escape is recorded.

## As built (2026-11-16)
- **No `-SelfTest` in the stage.** The coordinator asked for a design that keeps WSD-096; the self-test stays a recipe. The runner's graders
  still decide an agent-facing release, so WSD-096 is partly undone anyway (one line there, for the maintainer).
- **P** is the newest dated root CHANGELOG head other than the release's own, read from the candidate commit.
- **Rounds:** each round runs at most one run per scenario and side, all in parallel. Before a round starts, every one of its runs at its
  `budgetUsd` cap must fit under 6 USD. A run that records no cost counts at its cap.
- **Child processes:** they run without `CLAUDE*` or `ANTHROPIC*` variables (B-514's practice) and with `DISABLE_AUTOUPDATER=1`, in
  acceptEdits with whole Read, Edit, Write, Glob, Grep, Bash and PowerShell. Runs time out at 600 s; a runner the stage has to stop is
  UNREAD; a runner that writes no row stops the stage (exit 3).
- **Runner changes:**
  - `-FrameworkRoot`, so one runner and one set of graders score both releases;
  - unique scratch directories, so runs can go in parallel;
  - `rateLimit=`, `apiErrorStatus=` and `hostError=` on rows, which give the quota stop.
- **Records:** rows ride in the release commit under "pre-tag agent runs, v<X> candidate (B-521)", marked `pretag=candidate` or
  `pretag=baseline-v<P>`. A stored baseline is read from the base tag's own `meta/eval-results.md`. The failing check is what a FAIL row's
  grader facts differ on from the first PASS row's.
- **Red check and calibration, 2026-11-16** (`meta/eval-results.md`, "B-521 red check and calibration"; 27 runs, 2.82 USD):
  - Calibration: all three scenarios passed 6 of 6.
  - Caught: the guard-removal candidate stopped with exit 1 (`guard-retry` 0 of 2).
  - Not caught: v0.97.1's installer wording (`install-handoff` 3 of 3; agents committed it under this scenario's prompt) and the bug-fix
    failing-test sentence removed from the router rail and the rules carrier (`route-fix` 3 of 3).

  Under the rule above, both of those scenarios are dropped. **Only `guard-retry` runs before the tag.** Installer-handoff wording and the
  bug-fix path stay unwatched until a known-bad case that a scenario can see is found.
- **Spend:** about 0.10 USD a run on this host, a third of the medians assumed above. A triggered release costs about 0.30 USD and
  2 minutes. AGENTS.md keeps this note's "about 2 USD" wording, as the coordinator asked.

## Amendment, 2026-11-16: one more try, the URL install served locally (pre-registered before any paid run)
The maintainer chose "One more try" in chat on 2026-11-16, for two reasons. First, `guard-retry`'s catch duplicates `validate-dist`'s
hook-registration check, so the gate as built showed nothing CI misses. Second, the escape B-521 exists for, v0.97.0 and v0.97.1, went
uncaught, because `install-handoff`'s prompt says "Follow the installer output exactly".

**The scenario is `url-install-brownfield`, unchanged.** Its id, prompt ("Install this into my repo:
https://github.com/andreoucostas/ai-tech-lead"), fixture (the dotnet fixture plus a committed team `CLAUDE.md`), 2.50 USD cap and grader
all stay as they are. The grader is the url-install branch of `Test-ScenarioEvidence`, including B-404's rule that an ask before
committing passes. It expects the dotnet stack and `/adopt`.

**How the candidate is served (a new runner `-LocalSource` switch, which the stage always passes):**
- The run's scratch directory gets a bare mirror. Its master branch and an annotated tag `v<dist version>` point at the candidate commit,
  and it also carries every older `v*` tag.
- The Claude Code child gets `GIT_CONFIG_COUNT` settings that rewrite `https://github.com/andreoucostas/ai-tech-lead` and the same URL
  with `.git` to that mirror (`url.<mirror>.insteadOf`). So the agent's clone, fetch and ls-remote, and the installer's clone check,
  all reach the candidate. A free check confirmed this: a clone of v0.97.1's mirror described `v0.97.1`.
- The grader's reference is that tag and the candidate's own dist files, where it used to be GitHub's newest tag.

**How faithful it is.** The prompt and the grader are the same. Five things differ:
1. Only git is redirected. WebFetch is not in the gate's tool list, so it is denied, and a `curl` or `gh api` call would reach the
   published repository.
2. `git remote get-url` shows the `file://` mirror.
3. Runs use acceptEdits with the gate's tool list instead of skip-permissions.
4. The host and model are Claude Code 2.1.312 with `claude-sonnet-5-5`, where October's runs used 2.1.281 with `claude-sonnet-5`.
5. The shared `C:\src\ai-tech-lead` clone that the current README names is handled by the runner: if it exists before a run, the run is
   refused (could not examine); if the run's agent creates it, it is removed afterwards. A2 removed it by hand. The stage never runs two
   URL installs at once.

**Red check.** The stage's own rule (`Invoke-AgentRunStage`) with v0.97.1 as the candidate and a fresh v0.96.1 baseline, under the 6 USD
stop. The stop is now checked before every launch, counting each run in flight at its cap.

**Calibration.** The current candidate, master's dist, served as `v0.98.6`, run 6 times; it must reach 6 of 6. Calibration runs first.

**Decision rule** (the coordinator's, 2026-11-16):
- **It ships** if the red check reads REGRESSION (exit 1) and calibration reaches 6 of 6. The gate then runs `url-install-brownfield` and
  `guard-retry`, and AGENTS.md's cost wording becomes the measured cost.
  - `guard-retry` is kept on this evidence: under B-275, from v0.83.0 to v0.88.0, the host read a registered guard's block as a
    non-blocking error. `validate-dist` and every hook test passed; only a live `guard-retry` run showed it.
- **Otherwise B-521 closes**, without tuning:
  - `release.ps1`, AGENTS.md and DEVELOPING.md's release recipe return to their behaviour before f0fdd4c1;
  - the unused runner additions go;
  - the WSD-096 line goes;
  - the rows stay, and this note gains a "Not shipped" section.

**Prediction, written before any run: probably not caught.** B-404 (0.98.1) made an ask before committing pass under this prompt, and
two of v0.97.1's three brownfield failures were asks ("want me to commit?"). The host and the model have also changed since October.

**Stop:** at the first hard quota or rate-limit refusal; `allowed_warning` is not one. Each run's cost is recorded.
