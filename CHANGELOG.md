# ai-tech-lead — Changelog

> **This is the *maintainer's* changelog — the engineering log for the authoring repo.** It may
> reference tracking ids, decisions (`WSD-nnn`), and internal tooling. The **consumer-facing**
> release notes are the ones that ship inside each dist (`dist/*/CHANGELOG.md`, authored at
> `src/stacks/*/files/CHANGELOG.md`); those are written in the consumer's voice and are gated by
> `no-meta-leak` [#6]. Do not blur the two.
>
> This file starts at the merge (v0.26.0). Earlier framework history — everything before
> `ai-tech-lead-dotnet` and `ai-tech-lead-angular` combined into this repo — lives in the two
> preserved legacy changelogs: [`meta/changelogs/legacy-dotnet.md`](meta/changelogs/legacy-dotnet.md)
> and [`meta/changelogs/legacy-angular.md`](meta/changelogs/legacy-angular.md).

## 0.44.0 — 2026-08-02

Two instruments that could not fail, and one that was never built. B-74, B-62 and B-80.

**The test harness can now prove it reports failure (B-74).** The v0.41.0 RCA found that
`Write-TestSummary` returned `$null` under Windows PowerShell 5.1, so `exit (Write-TestSummary …)`
became `exit 0` while the summary printed `[FAIL]`. The bug was fixed then; nothing was added that
would have *caught* it. `tests/hooks/HarnessIntegrity.Tests.ps1` now plants a fixture with exactly
one failing test — one, because two or more returned a real integer and were always caught — and
asserts both the file's exit code and the runner's.

Two findings while building it, both the same class it exists to close:

1. **The first cut ran its fixtures under the wrong host.** It used the harness's `Get-PsExe`, which
   prefers pwsh 7 whenever it resolves, so every fixture ran under pwsh 7 even when the suite ran
   under 5.1 — the one host where the defect exists was never the host under test. With the `@()`
   fix reverted, the file passed. It now runs fixtures under `(Get-Process -Id $PID).Path`.
2. **It was scored by the component it tests.** With the defect planted it correctly printed
   `[FAIL]` and then exited **0**, because the summary it used to score itself was the broken one.
   It now computes its own exit code from the recorded results. Every other suite file can trust
   the harness; this one provably cannot.

Verified red-then-green on both hosts: defect planted → 5.1 EXIT=1, restored → EXIT=0. Under pwsh 7
the file is green either way, which is a documented blind spot, not a pass — pwsh returns 1 for the
expression that returns `$null` on 5.1.

**`validate-dist` check 8: hook registrations (B-62).** Nothing read the registration files at all —
check 2 proved they were valid JSON, check 7 scanned only `*.md` — so a registration naming a script
absent from the dist would ship silently, and the consumer-side symptom is a hook that never runs
and never complains. Check 8 resolves every reference in `.claude/settings.json`,
`.claude/settings.windows.json` and `.github/hooks/hooks.json`, requires the opposite-language twin
[#3], and rejects an unsanctioned interpreter. 26 registrations per dist.

**B-62's written premise was wrong, and is corrected rather than executed.** The entry said to fail
on a *bare interpreter name*. That contradicts v0.38.1, which deliberately reverted absolute-path
pinning because `.claude/settings.json` is committed team configuration and a machine-specific path
breaks every teammate. A bare name is the intended shipped value; whether it *resolves* is a runtime
property no build-time check can see, and v0.39.0's `Hook liveness` doctor row already reports that
from the consumer's machine. Check 8 does the build-time half only. **Band judgement: the delivered
check is P2-shaped, not P1** — the P1 severity came from silent dead hooks, which v0.39.0 covers.

Red-tested on both twins against a scratch dist across three defect classes (renamed hook in
`settings.json`; missing target in `hooks.json`; a hook stripped of its `.sh` twin). Both legs
produced byte-identical findings. Extraction is textual and identical in both twins deliberately:
the bash leg's JSON parser is python3-or-jq depending on the box, so parsing there would leave
whichever branch a machine lacks untested. A normalization bug surfaced during the red-test —
translating each backslash separately turned `.claude\\hooks\\x.ps1` into `.claude//hooks//x.ps1`,
which resolves on both platforms and so hid the sloppiness; runs of backslashes now collapse to one.

**`release.ps1` no longer commits whatever is in the tree (B-80).** The blanket `git add -A` is
deliberate — the stamps, the rebuilt `dist/` and the footprint baseline must land together — but it
also swept in anything else present, and the script printed no manifest. v0.42.0 and v0.43.0 each
shipped a stray worktree gitlink that way. The staged set is now classified before commit: a
mode-`160000` gitlink is a **hard refusal with no escape hatch** (this repo has no submodules), and
a path outside where the repo keeps files refuses unless `-AllowExtraStagedPaths` is passed. The
manifest prints either way, and a refusal `git reset`s so the index is left as found.

Classification happens *after* staging because that is the only point mode `160000` exists — an
unadded worktree is merely untracked (verified against `90f331d`).

**The allowlist's first cut would have refused every release from v0.39.0 to v0.43.0.** Written from
B-80's own wording (`src/`, `dist/`, `CHANGELOG.md`, the stamps) it produced 10 false positives when
replayed over the last 8 tags — each release touches `README.md`, and v0.41.0 touched
`.claude/hooks/tests/`. It now asks "is this file somewhere this repo keeps files at all?", which is
the actual hazard. `.claude/hooks/tests/ReleaseStagingGuard.Tests.ps1` replays those tags on every
release so the allowlist cannot silently narrow again; it extracts the guard verbatim from
`release.ps1` rather than re-typing it. Red-tested by mutation: narrowing the allowlist and making
the gitlink check inert each turned the suite red.

## 0.43.0 — 2026-08-01

Release-time profiling, prompted by the banner claiming "roughly 30 minutes".

**The banner was the defect.** A measured release is **7.4 minutes** (v0.42.0: 12:52:26 → 12:59:48),
about a quarter of what the script announced. That figure had never been measured. It is now
`5-7 minutes` with a comment requiring re-measurement rather than padding — an estimate that wrong
is what makes a release feel unaffordable and invites skipping it.

**What the profiling found.** The gates are bound by *process creation*, not CPU. Every assertion
spawns a fresh interpreter, deliberately, so each one is a real hook invocation with a real exit
code — roughly 1350 spawns across three dists. Measured on the maintainer box: `pwsh` 265 ms,
`bash` 55 ms, `powershell.exe` 5.1 143 ms. `validate-dist` is 2.3 s and was never worth touching.

Two plausible fixes were measured and **discarded**:

- *More lanes.* A throttle sweep on one dist suite: 160.7 s (4) / 152.6 s (6) / 150.3 s (8) /
  151.4 s (12). It plateaus — process creation serialises, and raw spawn throughput only improves
  ~1.9x from 8-way parallelism.
- *Splitting the 101 s `TwinParity.Tests.ps1`.* Rejected once the sweep landed: splitting moves
  spawns between files without reducing them, so it would have bought approximately nothing. This
  was the plan of record until the data killed it.

**What shipped instead**, all measured:

- Guard's `.ps1`/`.sh` parity moved into `Guard.Tests.ps1`, so each case runs once per twin instead
  of three times total (the `.ps1` leg was executed by both files against the same fixture).
  One dist suite: **150.3 s → 132.3 s**. Red-tested both ways — neutering `guard.sh` and neutering
  `guard.ps1` each produce 44 failures, clean on restore.
- `context-footprint -Update` (~39 s) now runs alongside the three dist legs instead of serially
  ahead of them. It writes `meta/context-footprint.json`, which no gate reads, so there is no race.
- Each dist suite is handed `cores / 3` lanes instead of all three assuming they own the machine.
- Shipped runner lane count is core-aware rather than a hardcoded 4.

Gate phase: **385.3 s → 284.7 s (26%)**, all gates green.

*Correction recorded for honesty:* the merge was initially justified as closing a coverage hole —
the claim that `guard.sh` was never checked against an expected decision. That was wrong. The old
split asserted `ps == expected` and `sh == ps` including exit and streams, so `sh == expected` held
transitively and a fault shared by both twins would still have failed `Guard.Tests`. The merge is an
efficiency and diagnosability change, not a correctness fix.

*What else is exposed:* **B-79** — the maintainer box has only the MSIX/Store build of PowerShell 7,
which starts at 265 ms against native 5.1's 143 ms. PowerShell 7 starting 1.85x slower than 5.1 is
backwards and points at MSIX per-launch overhead. An MSI install is the largest remaining win and
needs no code change. Defender real-time scanning taxes every spawn too; left alone by decision.

## 0.42.0 — 2026-08-01

Started as "does `/docs-sync` keep `docs/warehouse-map.md` up to date?" (it does not — `grep -rn
warehouse src/core/` returned zero). Answering that surfaced three defects of one class: **a
documented maintenance duty with no implementation behind it.**

- **`/rebootstrap` gained Phase 3c, re-confirming `FRAMEWORK-CONTEXT.md > Known Hazard Areas`** —
  making its own frontmatter `description` ("refresh conventions, **hazards**, and mined skills")
  true for the first time. `grep -i hazard` over its body previously returned only that description
  line, in all three stacks. 3c reuses `/bootstrap` 3d-bis verbatim in shape (single-message
  confirmation, the (a)/(b)/(c) status mapping, the skip-all escape, never self-upgrading an
  `[UNVERIFIED]` row) and adds a **referential-drift pass that nothing previously owned**:
  `session-start` parses the `Reviewed` date only, so a `[VERIFIED]` row pointing at a deleted file
  stayed fresh-looking indefinitely.
- **Struck the false `/docs-sync` hazard claim** from `FRAMEWORK-CONTEXT.md:6` and `README.md` in all
  three stacks. The "Detected Framework Packages" half of that sentence was true (Step 4's
  `fwctx-packages` marker), which is why it survived to v0.41.0.
- **Warehouse-map freshness caveat in `add-warehouse-load` step 1**, where the map is read and where
  the damage happens — plus a one-bullet staleness pointer in `/docs-sync` Step 1 via a new
  dotnet-only `docs-sync-warehouse` marker. Angular resolves it to nothing; monorepo gets it through
  the per-marker-name concat fallback with **no monorepo sibling** (verified in the composed output,
  not just traced).
- **`.github/prompts/docs-sync.prompt.md` enumerated four of six steps**, omitting Step 4 and the
  AGENTS.md/rails half of Step 2 — a `src/core` file, so all three dists shipped Copilot a narrower
  workflow than Claude Code ran.

Design record: WSD-027 (site a maintenance duty on the surface whose invocation model matches it).

An adversarial review pass rejected the first draft of this work, which added a full
`/docs-sync` warehouse cross-check step. Four reasons, all recorded in WSD-027: it re-derives grain
and load ordering (warehouse discovery, which WSD-021 declined to automate); `docs-sync.md` carries
no `disable-model-invocation: true`, so a full SQL-tree scan would be model-triggerable against a
command advertised as "read-mostly, safe to run anytime"; it would be the first `/docs-sync` target
with no shipped template or schema; and its own recommended action was "re-run `map-warehouse`",
making the developer pay the scan twice. The shipped fix is roughly a tenth of that diff.

*Why did no gate catch it:* `no-dead-instruction` matches script invocations only; `DocTruth` covers
authoring-repo facts. Nothing checks *"this prose describes that command"* — filed as **B-76**, which
must cover three shapes (third-party attribution, frontmatter self-description, step enumeration),
since a check aimed at only the first would have caught one of the three.

*What else is exposed to the same class:* the deterministic half of hazard-row checking is filed as
**B-77** (`hazard-check.{ps1,sh}`, modelled on `wiki-check`); the four warehouse-map populations that
no signal reaches are filed as **B-78**. Other `checked by /X` / `asserted by /X` phrasings across
`dist/*` were **not** swept — only the exact `refreshed by /docs-sync` string was.

## 0.41.0 — 2026-08-01

Closes B-61: behavioural twin parity covered `.claude/hooks/` but almost none of the shipped
`scripts/`. The gap was found the hard way — `framework-doctor.ps1` and `.sh` once returned opposite
verdicts on the same machine at the same moment and no gate noticed, because running either twin
alone looked healthy.

Writing the harness immediately surfaced three divergences that were **already shipping**, which is
the point of the item rather than a surprise:

- **`metrics.sh` was missing its test-integrity counters**, and by a different amount per stack:
  dotnet lacked `tests_skipped` and `tautological_assert`; angular lacked `tests_skipped_focused`
  and `tautological_expect`; monorepo lacked all four. The PowerShell twins had them throughout, so
  the two twins emitted different JSON key sets. (An earlier draft of this work asserted three keys
  common to all stacks — that was wrong, caught by a second adversarial review pass.)
- **`docs-sync-check` twins printed different prose**: four ASCII-vs-em-dash advisory suffixes plus
  two genuinely different sentences (the CLAUDE.md size NOTE and the README NOTE, which also used a
  different separator).
- **The shipped test harness could not go red.** Under Windows PowerShell 5.1,
  `(… | Where-Object …).Count` on a pipeline yielding exactly ONE object returns `$null`, so
  `Write-TestSummary` returned `$null`, `exit $null` became exit 0, and a test file with exactly one
  failing test scored green while printing `[FAIL]`. Two or more failures returned an int and were
  caught, so this hid precisely the lone-regression case. pwsh 7 returns 1 for the same expression,
  which is why CI and the maintainer box never saw it. Fixed in both the shipped and meta harnesses
  and red-tested under 5.1 (exit 0 before, exit 1 after).

New `tests/hooks/ScriptTwinParity.Tests.ps1` (ships) runs both twins of `template-checks`,
`docs-sync-check`, `sync-agent-files` and `metrics` against one fixture and compares them.
`framework-doctor` gained two non-pending cases, so `Stack toolchain`, `Mirror and version
integrity` and `Audit trail substrate` are twin-compared for the first time — the failing-mirror
case is the one that matters, because the passing branch is trivially identical.
A maintainer-only `ScriptTwinCoverage.Tests.ps1` makes an unclassified twin pair fail, so a newly
added script cannot silently escape coverage.

Contract notes, deliberately narrow: comparison is of the **ordered** `OK:`/`FAIL:` sequence, not a
set — a set would hide ordering and duplication defects. Exactly two normalizations exist, both
commented: `template-checks`' by-design check 6 asymmetry (`.ps1` parses `.ps1` files, `.sh` parses
`.sh` files), and a script naming its own sibling twin. A static assertion fails if the check-6
exemption ever widens. The fixture also asserts which checks it *reached*, after an early version of
it silently exercised only 5 of 7 checks and a planted defect in check 5 failed to go red.

Known limitation, stated rather than papered over: the metrics corpus uses canonically-cased source.
`Select-String` is case-insensitive and `grep -E` is not, so case parity is not asserted — that
belongs to B-59(b), which owns the case-sensitivity policy. Also unexercised: the `Stack toolchain`
row's regex-vs-glob branch, noted in the test.

Housekeeping: the three shipped changelogs still headed `0.40.0 — Unreleased` for a version released
2026-07-31, because `release.ps1` stamps only the root changelog. Dated here; the automation half
remains open as B-54.

## 0.40.0 (2026-07-31)

Closes the delivery half of B-66: the Angular stack shipped **no forms guidance at all**. A
case-sensitive grep for `ControlValueAccessor`, `NgControl`, `FormControl`, `FormGroup`,
`FormBuilder`, `Validators`, `ngModel`, `NG_VALUE_ACCESSOR`, `formControlName` and
`ReactiveFormsModule` returned zero hits across `src/stacks/angular/`, `src/core/` **and**
`dist/angular/`. Forms are the largest surface of a line-of-business Angular app, and this is the
standing defect behind field report #2 (`meta/field-reports.md`), where a developer reported the
model using `@Input()` on a custom form control instead of participating in the forms API.

`/bootstrap` and `/adopt` now carry a `Forms` subsection in the Conventions structure they author,
and `/bootstrap`'s A3 pass probes for it (reactive vs template-driven, where validators live,
whether any component is a custom form control and how it participates). `docs/defaults.md` gains a
matching detect-only `### Forms` section — HTML comments in the house style of `### SSR / Hydration`,
telling the analysis what to observe rather than prescribing a greenfield default. Two shipped
surfaces that asserted the opposite were carved out: `copilot-instructions.md` said dumb components
use `@Input`/`@Output` **only**, and `defaults.md` § Component Design said the same less forcefully.

**Deliberately trimmed, and this is the interesting part.** The plan originally shipped prescriptive
greenfield forms guidance — reactive-over-template-driven, typed forms, and a `NG_VALUE_ACCESSOR`
vs `NgControl` trade-off table — plus an `add-component` skill branch. That was cut after the
`angular-form-control` baseline **passed with no forms guidance shipped** (`meta/eval-results.md`).
The agent self-injected `NgControl`, set `valueAccessor = this`, used `setDisabledState` rather than
an `@Input() disabled`, and commented that this avoids the circular-DI `forwardRef` that
`NG_VALUE_ACCESSOR` would need — the exact hazard the guidance was going to teach. Writing
prescriptive guidance against a probe that is green before the fix would have been shipping on
faith. What ships here is only the part justified independently of the probe: making the framework
*capture* a repo's forms conventions, which it previously could not do at all.

**No eval validates this release.** B-72 records why: the probe's prompt telegraphs the mechanism,
so it cannot reproduce its own field report; and its `cva` signal conflates the correct `NgControl`
pattern with the double-registration circular-DI bug. The grader was also found **defeatable by the
idiom the cut guidance recommended** — `@Input() set disabled(v)` and `disabled = input.required<boolean>()`
both scored PASS while being exactly the reported defect. Fixed and red-tested in `790e42c` before
the baseline ran, which is the only reason the baseline result can be trusted at all.

## 0.39.0 (2026-07-31)

Adds the framework's first observed-behaviour diagnostic. Every check before this release inspected
configuration, but configuration cannot prove that a hook runs. Two real installations exposed that
gap in succession: first a bare `bash` did not resolve, then a bare `pwsh` did not resolve. In both
cases the registrations looked correct while the write guard, build feedback, and audit trail were
inactive.

`session-start` now makes a best-effort write of an ISO-8601 UTC timestamp to
`.claude/.state/last-session-start` whenever it runs. Failure to write the record can never affect
the session preload, and `.claude/.state/` remains gitignored. Both `framework-doctor` twins gained
a `Hook liveness` row: a present record is `[OK]` evidence that the hook wiring is alive and reports
the most recent timestamp; an absent record is `[CANT-VERIFY]` with guidance to check the wired
interpreter and `docs/enforcement-surfaces.md` if a Claude Code session has already been started in
the repo.

This proves only that a hook actually started, not that enforcement works: a live hook can still
fail later at runtime. Absence is deliberately `CANT-VERIFY`, not `MISSING`, because a fresh install
where nobody has started a session is indistinguishable from dead wiring. That preserves WSD-023's
`Exit = 1 iff any MISSING` contract; the new row does not change the doctor's exit code or CI
behaviour.

Instrumentation is deliberately limited to `session-start`. It fires unconditionally, so after a
session its silence is unambiguous. The other hooks depend on user actions; reporting that one of
them had “never fired” would create false alarms when no matching action had occurred.

## 0.38.1 (2026-07-31)

Reverts v0.38.0's installer pinning of hook interpreters to absolute paths. `.claude/settings.json`
is committed team configuration, so recording the installing developer's machine-specific path made
hooks fail for teammates on another OS or user profile. The installers again retain their existing
`pwsh` / Windows PowerShell 5.1 / `bash` selection but write the selected interpreter's bare name.

A pin in `settings.local.json` is not a safe alternative: Claude Code merges hook entries additively
across settings levels and deduplicates only exact command-string matches. A bare registration and a
pinned registration would therefore both fire, running every hook twice.

Corrects `enforcement-surfaces.md`: an interpreter resolution failure kills the controls carried by
the hook and is invisible to the model and framework checks, but Claude Code does show the developer
a non-blocking hook-error notice in the transcript. This is the second field-reported occurrence of
the same class: a bare `bash` silently no-opped, was replaced by a bare `pwsh`, which silently
no-opped. Detection, not a better default, is the actual fix; that work comes next.

## 0.38.0 (2026-07-31)

Fixes a silent failure that disabled every Claude Code hook on a Windows maintainer machine. Hook
registrations invoked the bare name `pwsh`; Claude Code launches them through Git Bash, whose PATH on
that machine ended in a literal unexpanded `${PATH}` token and no longer contained PowerShell.
Every invocation failed command-not-found with exit 127 before the hook could emit anything: no write
guard, post-write type-check, Boy Scout nudge, routing context, or audit trail.

`framework-doctor.ps1` made the failure more dangerous by reporting `[OK] Wired hook shell —
available: pwsh.` and exiting 0. It asked `Get-Command` from inside the already-running PowerShell
process, while the `.sh` twin correctly reported `[MISSING]` from bash on the same machine. This is
the second vantage-point defect in the doctor after the earlier `jq` probe checked PowerShell's view
of a dependency consumed by bash.

The installer now resolves and writes an absolute PowerShell interpreter path into hook
registrations. It prefers `%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe`, the stable app-execution
alias, over the versioned `Program Files\WindowsApps\Microsoft.PowerShell_<ver>_…` executable whose
path changes on upgrade. Existing consumers must rerun the installer to replace bare registrations.

The doctor now reports absolute interpreter paths as `OK` or `MISSING`, and reports a bare name as
`CANT-VERIFY`. It deliberately does not “probe harder from bash”: a bash spawned by the doctor
inherits the doctor's PATH, not the host shell's PATH, and measurement showed it could resolve
`pwsh` even when host-launched bash could not. A diagnostic cannot observe the environment of a
process it does not launch (WSD-026). The remaining `Invoke-BashProbe` use for the Guard JSON parser
row is documented as unsuitable for predicting host-launched resolution.

## 0.37.0 (2026-07-31)

The enforcement half of B-57, split from 0.36.0 because a regex in the write-time guard can hard-block
ordinary C# and that risk should not ride along with prose changes.

The guard blocked xUnit's `[Fact(Skip=…)]` but let NUnit's and MSTest's `[Ignore]` through, so an
NUnit repo got a strictly weaker floor than an xUnit one while the framework advertised a
deterministic backstop. Both twins now also block `[Ignore]`, including NUnit's per-case
`[TestCase(…, Ignore = "…")]` — the direct structural analogue of `[Fact(Skip=…)]` and the pattern most
likely to be reached for.

The pattern is anchored to an attribute-list line rather than matching `Ignore` anywhere, and this
matters: the `.cs` branch is not scoped to test files, so an unanchored pattern hard-blocks
`public enum Mode { None, Ignore, All }` — ordinary production C#. Four properties are load-bearing and
were each verified by execution on both engines before shipping:

1. **Line-anchored** (`^\s*\[`), or the enum above blocks on both twins.
2. **`-cmatch`, not `-match`.** PowerShell's default is case-insensitive and bash's `grep -E` is not,
   so `Handle(evt, ignore, ctx);` would block on Windows and pass on Linux. Twin parity is asserted
   byte-for-byte, so that divergence fails the release.
3. **POSIX bracket syntax in the bash twin**: `]` first in the class (`[](,=]`), and `[[:space:]]`
   rather than `\s`, which BSD grep does not support. An earlier draft used `[\](,]` and `\s`, which
   makes `grep` exit 2 — and because the check is `grep -Eq … && reasons+=(…)`, that silently disables
   the check on the `.sh` twin while `.ps1` blocks.
4. **`=` in the trailing class**, without which `[TestCase(1, Ignore = "flaky")]` is missed.

`[Explicit]` is deliberately **not** blocked. It is a legitimate NUnit marker for opt-in
long-running or manual tests and xUnit has no blocked equivalent; blocking it would make the framework
stricter on NUnit than on xUnit — the mirror image of the complaint that started this. Known limitation,
shared with the existing `[Fact(Skip=)]` check and not papered over: both engines are line-oriented, so
a multi-line attribute list is not caught.

Seven fixture cases were added to the shared table that feeds both `Guard.Tests` and `TwinParity.Tests`,
so they run across both twins and both surfaces. Four are `block=$false` — `[JsonIgnore]`, the enum, a
lowercase `ignore` argument, and `[Explicit]` — because the false positives are the failure mode that
would actually hurt a consumer. Red-tested before the fix (all three skip forms exited 0, with
`[Fact(Skip=)]` exiting 2 as a control) and after (8/8 Claude surface, 9/9 bash twin, Copilot surface
emitting `permissionDecision: deny`).

`enforce-standards` no longer claims the guard blocks only `[Fact(Skip=…)]`, which this change would
otherwise have made false on exactly the NUnit repos it now protects.

## 0.36.0 (2026-07-31)

Stops the framework asserting xUnit at repos that already use something else. A field report from a
brownfield .NET install on NUnit: the reviewer's complaint was that the framework kept pushing xUnit
instead of following the suite already in place. It was right. Verification Rule #10
("Derive, don't assume") already names *test framework* as a category requiring evidence, and
`/bootstrap` Phase 3a already forbids naming an unevidenced technology — but six shipped surfaces
bypassed both and stated xUnit as fact. Brownfield is where it bit hardest: the installer detects
pre-existing AI tooling, `/bootstrap` hard-stops and redirects to `/adopt`, so there is a real window
where `Conventions` is unpopulated and those surfaces are the only thing reaching the model.

This release fixes the guidance half (B-57). `docs/defaults.md` § Testing is restructured into
evidence-keyed blocks exactly as B-35 did for Data Access — a **Detect** step, an **existing suite →
mirror it** block, and a **greenfield only** block that is now the sole home of xUnit + NSubstitute
and of `MethodName_Scenario_ExpectedResult` (an xUnit house style that an NUnit repo has no reason to
adopt). `copilot-instructions.md` drops the unconditional `xUnit + NSubstitute` line for a mirror-first
pair within the file's 120-char-per-rule contract, and `generate-copilot` is told to emit the
*evidenced* framework. `add-tests` gains a Step-1 evidence gate naming Rule #10, and its suite-bootstrap
mode must now confirm the whole solution is test-free before proposing anything — the .NET branch had
hardcoded while the Angular branch already derived the runner from `angular.json`. `enforce-standards`
step 2 becomes evidence-keyed across xUnit (`xUnit1004`), MSTest (`MSTEST0015` — verified against
Microsoft's docs: ships in MSTest.Analyzers 3.3+, severity Info, opt-in from 3.8 and not enabled even
by `MSTestAnalysisMode=All`), and NUnit, which genuinely has no ignored-test analyzer and so gets a
build-failing CI grep instead. `ArchitectureTests.sample.cs` — copied verbatim into consumer repos —
now says how to translate off xUnit, since it would not otherwise compile on an NUnit repo.

The enforcement half ships separately in 0.37.0: the write-time guard blocks `[Fact(Skip=…)]` but lets
NUnit and MSTest skips through, so an NUnit repo currently gets a weaker floor than an xUnit one. It is
split out because a regex there can hard-block ordinary C#, and that risk should not ride along with
prose changes.

Deliberately unchanged: `tests/impact/tasks.json` names xUnit in its prompt, which is a direct
instruction to the agent (and the harness runs against a scratch repo with no suite, i.e. the
greenfield branch), plus the held-constant prompt is what makes A/B scoring meaningful.

Two gaps found while verifying and **not** fixed here. `template-checks` mirrors only Verification
Rules / Leanness / SOLID / Boy Scout — the `## Common Tasks` skills list is ungated and had already
drifted between `CLAUDE.md` and `AGENTS.md` in all three dists with every gate green. Adding a verbatim
section diff is the wrong fix: `AGENTS.md`'s Common Tasks is deliberately condensed. A skill-slug-set
comparison is the right one, logged as B-58. Also, this repo was on a detached HEAD with local `master`
two commits behind `origin/master` (an abandoned scratchpad worktree held the branch) — precisely the
B-53 condition. Resolved by detaching that worktree rather than deleting it.

## 0.35.0 (2026-07-30)

Fixes the Copilot Boy Scout nudge firing on the wrong event. It was originally registered on
`userPromptSubmitted` because Copilot had no known turn-end event and, since CLI v1.0.65 (hardened
in v1.0.76), that event injects `additionalContext` into the model-facing prompt. That meant the
hook ran before the prompt's work, including read-only turns, and could only report the previous
turn's diff. CLI v1.0.72 introduced `agentStop`, the true per-turn analogue of Claude Code's
unchanged `Stop` registration, but its documented output supports blocking rather than context
injection. WSD-024 therefore separates timing from delivery: `agentStop` scans and queues findings;
the next `userPromptSubmitted` delivers them without scanning.

We deliberately rejected `decision: "block"` at `agentStop`: the Boy Scout check is advisory, and
blocking would force extra turns on one surface while still terminating after Copilot's
eight-consecutive-block loop cap. VS Code agent mode remains unverified because agent hooks are
Preview/off by default and may spell the event `Stop`. The shipped hook headers also correct a
long-standing false claim: a Claude Stop hook's blocking `reason` is delivered to Claude as a
system reminder, not shown only to the user (that behavior belongs to the separate `stopReason`).

Fixes `framework-doctor` falsely reporting the guard JSON parser as MISSING on Windows when `jq`
is an extensionless binary, or is otherwise invisible to PATHEXT-based command resolution. The
PowerShell doctor consequently diverged from its bash twin and broke invariant #3 twin parity.
The parser probe now runs from bash's vantage point because `guard.sh` is the component that needs
the parser.

## 0.34.3 (2026-07-21)

Sharpens Leanness rule #7 ("no comments that restate code") with a concrete Bad/Good example in the
always-loaded `CLAUDE.md`/`AGENTS.md` rule set, so agents pattern-match against the rule rather than
an abstract imperative — comment-noise is one of the most persistent LLM habits. Authored once per
stack in `src/stacks/*/snippets/CLAUDE.md/lean-4-8` and its `files/AGENTS.md` mirror; the
`## Leanness` verbatim-mirror gate covers both. Docs-only; no behavioral surface changed.

This is the change developed in parallel on the `claude/lean-rule7-example` branch as a
same-numbered v0.34.1; replayed here as v0.34.3 to resolve the version collision with the
presentation (v0.34.1) and warehouse (v0.34.2) releases that shipped on `master`.

## 0.34.2 (2026-07-20)

Closes a discoverability gap for data-warehouse repos in `/bootstrap`. When A2 detects warehouse
signals and Phase 3a keeps the `map-warehouse` / `add-warehouse-load` skills, the Phase 4 report now
emits a one-line nudge pointing the developer at `/map-warehouse` for a full layer/grain/load-
ordering/idempotency map before their first warehouse change, and names `add-warehouse-load` as the
task-triggered recipe for the change itself. WSD-021 deliberately rejected *auto-running* warehouse
discovery inside bootstrap (it is a re-runnable perf-class task); this is the report-nudge middle
ground, gated on the same evidence that kept the skills, so non-warehouse repos see nothing. dotnet +
monorepo only (angular ships no warehouse skills; it gets a no-op changelog entry to satisfy the
version-stamp gate). Design-reviewed with an adversarial pass — the gate was hardened from
"A2 detected signals" to "Phase 3a kept the skills" (an observable artifact state, not agent memory).

## 0.34.1 (2026-07-20)

Rebuilds the technical presentation after team feedback that v0.34.0 was accurate but too abstract.
The deck now follows one CSV-export feature through the actual installer, bootstrap, session context,
prompt payload and routing output, plan gate, Feature contract, pre-write allow/deny path, post-write
build and audit, subtask tests, review, CI, knowledge updates, and human responsibilities. The
one-page architecture poster is replaced by a functional twelve-stage event trace and operational
failure guide.

## 0.34.0 (2026-07-20)

Adds the technical architecture presentation requested after an adversarial review of the existing
persuasive briefing: a 12-slide offline deck that separates instruction, context, advisory review,
hard local blocks, deterministic gates, and human authority; a printable one-page system map; and a
claim-to-evidence appendix tying strong claims to shipped implementations and tests. The three
distribution READMEs now distinguish the briefing deck from the technical companion.

## 0.33.0 (2026-07-17)

Closes five gaps found by a real onboarding review. Copilot CLI now receives the Boy Scout nudge
through its consumed per-prompt channel; the write guard recognizes fine-grained and all classic
GitHub PAT prefixes while allowing passwordless connection strings; credential-bearing keyed and
URI connection strings remain blocked. The framework-state check now fails an incomplete install
missing the enforcement matrix, and a Bamboo Specs example documents repository-specific wiring.

## 0.32.2 (2026-07-17)

Second CI-linux fix for the B-16 test harness. v0.32.1 fixed the doctor itself (builtin root
resolution — proven: the failing row moved past install-state), but the no-parser sandbox test
still failed on the linux runner: pwsh-created symlinks in the restricted-PATH bin resolved as
"command not found", so the sandbox was empty. The sandbox is now built inside bash (`ln -sf`
with full PATH; only the doctor invocation sees the restricted PATH); the Git-bash copy branch
is unchanged. Dead `UnixTool` helper removed with it.

## 0.32.1 (2026-07-17)

Post-release fix for B-16, caught by the CI linux leg (the Windows-only local runs were green —
MSYS bash tolerates what POSIX bash does not). `framework-doctor.sh` now resolves its own
location with shell builtins only (no `dirname`): under a hostile PATH its root resolution
failed and every subsequent row silently vanished — the exact failure mode a survival-
constrained diagnostic must not have. `FrameworkDoctor.Tests` fixtures now wire a hook shell
that exists on the test host (CI linux has `pwsh`, not `powershell` — the doctor was *correctly*
reporting the fixture's shell as missing), and the no-parser test now asserts install-state
resolution and carries stderr in its failure messages.

## 0.32.0 (2026-07-17)

### Added — B-16: honest developer-machine enforcement diagnostic

- Added `framework-doctor.{ps1,sh}` to report which enforcement prerequisites are verified on
  the current machine, which are missing, and which require a human-observed agent canary.
- The diagnostic reuses the installed pending-state signals and shipped `template-checks`, runs
  without agent machinery, and never claims full enforcement from script-visible facts alone.
- Installer handoff and consumer docs now tell each developer to run the doctor once locally.
  Design: WSD-023 and `.claude/plans/2026-07-17-b16-framework-doctor-design.md`.

## 0.31.0 (2026-07-17)

### Added — B-40: SQL / data-warehouse guidance

- Two new .NET-stack skills, `map-warehouse` (discovery: layers, fact/dim entities and grain,
  load orchestration, batch/watermark control, SCD strategy, partitioning) and
  `add-warehouse-load` (change recipe: follow the existing load pattern, idempotent re-runnable
  loads, no double-loading, SCD handling, partition alignment). Ship to dotnet + monorepo dists.
- `/bootstrap` A2 now detects SQL-project/stored-procedure codebases and data-warehouse signals
  (two-tier evidence, per B-35 doctrine); Phase 3a applies a three-way keep/delete rule for the
  warehouse skills and exemplar-pins `add-warehouse-load`.
- `docs/defaults.md` Data Access gains evidence-keyed raw-SQL and data-warehouse blocks; the
  section preamble widened to file-tree evidence. `add-entity` gained a cross-routing
  DO-NOT-USE-FOR clause for warehouse tables.
- Design locked in `.claude/plans/2026-07-16-b40-sql-dw-guidance-design.md` (WSD-021); plan was
  adversarially reviewed pre-implementation (11 findings folded in, incl. angular changelog
  version-stamp gate and generated architecture.html).

## 0.30.1 (2026-07-16)

### Fixed — B-34: rendered-output parity for hook twins

- Guard messages and Copilot deny JSON now render byte-identically from the PowerShell and bash
  twins. Audit-trail was confirmed to have no model-visible output; its PowerShell comments were
  aligned to the bash house style as a Boy Scout cleanup.

## 0.30.0 (2026-07-16)

### Changed — B-36/WSD-020: testing strategy for repos with no suite

- The testing strategy now handles zero-test repositories end to end: `add-tests` has an
  interactive suite-bootstrap mode, Feature rails name the test-level decision procedure, and
  `/bootstrap` reports suite absence, records a target test shape, and routes the repair as
  Severity-High debt.

### Changed — B-39 phase 2: parallelize shipped hook-test files

- The shipped hook-test runner now executes up to four isolated test-file child processes in
  parallel while retaining deterministic, per-file output and the existing aggregate exit-code
  contract. On the maintainer machine, the .NET suite fell from 136.611 s to 91.999 s (32.7%).

## 0.29.1 (2026-07-16)

### Fixed — B-35: derive persistence guidance from repository evidence

- Implements the locked WSD-020 design: technology-specific rules now require repository evidence;
  .NET data-access defaults, bootstrap analysis, `add-entity`, Copilot guidance, and the Boy Scout
  hook no longer assume EF Core. MongoDB-style async query methods no longer trigger EF-only
  `AsNoTracking()` advice.

## 0.29.0 (2026-07-16)

### Added — B-22: headless `/adopt` (Path A — prepare autonomously, human applies the merge)

Implements the LOCKED design `.claude/plans/2026-07-06-b22-headless-adopt-design.md` (WSD-014,
**Path A**), unblocked now that its hard dependency B-21 D1 (the PR judgment checklist) has shipped.
Closes the last manual step of adoption without breaking the prompt-injection trust boundary that
made `/adopt` developer-initiated. Authored as **three-stack whole-file edits** of `adopt.md` and
`bootstrap.md` (invariant #1 — they are stack whole-file overrides, only the prompt wrapper +
installers are core), plus the two core installer twins (invariant #3). Implemented this session by
principal-engineer direct edit after the intended codex (gpt-5.6-sol) implementer was blocked by the
bypass-authorization boundary (see `meta/LEARNINGS.md`).

- **`adopt.md` gains a normative `## Headless mode` section** (byte-identical across all three
  stacks). When `$ARGUMENTS` carries a `--headless` directive, the workflow **prepares** adoption
  autonomously — auto-branch `adopt-ai-framework`, archive, provenance + adversarial screen, impact
  baseline, PR structuring — and **stages** every proposed `CLAUDE.md`/`TECH_DEBT.md` merge as a
  clearly-marked, attributed, normalized block for a human to apply at PR review. A per-gate
  override table makes each interactive gate's headless behavior normative (skip ambiguous, exclude
  quarantine with no auto-upgrade, record-not-apply the plan, stage-don't-apply merges with the
  `<!-- DEFAULTED -->` marker on 4a contradictions, unset TECH_DEBT severity/effort, never auto-add
  custom commands, commit to the branch only). Everything deferred lands in the Phase-8 report +
  B-21 checklist.
- **The trust boundary is preserved by construction (constraint 2), not by the flag.** Nothing
  derived from an untrusted discovered file is ever *applied* to canonical guidance without a
  person; `disable-model-invocation: true` stays on `adopt.md`/`bootstrap.md`. Works on both Claude
  Code (`claude -p`) and Copilot CLI (its `-p` equivalent), reusing the read-and-execute prompt
  pattern — so the boundary holds even where the flag is irrelevant (Copilot). A restricted tool
  surface (deny network egress / secret access / git-config changes) bounds mid-run exposure.
- **Marker/guard lifecycle:** the install is committed to the **default branch** (precondition);
  headless deletes `.claude/adoption-pending.json` only on the adoption branch, so SessionStart +
  `docs-sync-check` keep firing on the default branch until a human merges the reviewed PR — guards
  release on human merge, not on the headless run.
- **Embedded Phase-7 `/bootstrap` runs headless too (HIGH-2 fix):** the `--headless` directive
  propagates in; `bootstrap.md` Phase 3d-bis no longer stalls — it takes the "skip all — mark as
  unverified" path automatically, writing every candidate hazard `[UNVERIFIED]` onto the checklist,
  never auto-confirming a hazard unattended.
- **Installer twins + marker `nextStep`** now offer the headless entry alongside the developer path
  (`src/core/scripts/install.{sh,ps1}`): the brownfield agent-handoff block tells an installing
  agent it may EITHER hand off to a developer OR run headless adoption (which prepares a PR branch
  for human review and does not auto-merge or open the PR). The `InstallerContract` gate confirms
  the full agent contract still prints in both modes × both twins × all three dists.

## 0.28.0 (2026-07-16)

### Added — B-21: reviewer-profile systemic fixes (judgment items stop scattering and expiring silently)

Implements the LOCKED design `.claude/plans/2026-07-06-b21-reviewer-profile-design.md` (WSD-013).
The reviewer profile (competent engineers, limited AI understanding): the pipeline makes every
AI-architecture call itself; reviewers only answer plain questions about their own code. The
residual gap the design named — judgment-needed items are created with good UX but then scatter
and expire silently — is closed by three deltas. Implemented via a codex (gpt-5.6-sol) implementer
under principal-engineer review (this session); shipped as **three-stack whole-file edits**, not
the single `src/core` edit the pre-merge spec assumed (`bootstrap.md`/`adopt.md`/`FRAMEWORK-CONTEXT.md`
are stack whole-file overrides — the spec's "one src/core edit per artifact" was stale; only the
`session-start` twins are core).

- **D1 — one "Needs a human decision" checklist emitted for the PR/commit.** `bootstrap.md`
  Phase 4 and `adopt.md` Phase 8 now emit a prioritized (~10-cap) fenced block titled
  *"Paste this into your PR (or commit message)"*, each item a plain yes/no question with a file
  pointer. Sources: `<!-- INFERRED -->` conventions, `(c) unsure`/tooling-only hazards,
  adopt-4a contradictions resolved by default, and `origin: discovered` skills. bootstrap
  **suppresses** its block under `/adopt` (Phase 8 is the sole emitter, reusing the existing
  Phase-2b adopt-context signal, M1); bootstrap gains a commit/PR nudge since it has no branch
  step of its own (H2a). adopt Phase 4a writes a durable `<!-- DEFAULTED: … -->` marker at
  resolution time so the choice survives the full `/bootstrap` pipeline that runs between 4a and
  8 (H2b); Phase 8 re-scans it. Empty categories are omitted; all-empty prints one line.
- **D2 — hazard staleness becomes a mechanism.** `session-start.{ps1,sh}` (core twins) parse
  `FRAMEWORK-CONTEXT.md > Known Hazard Areas` and resurface areas whose `Reviewed` date is >90
  days old — real interval math (`cutoff = today − 90d`, ISO-pinned, GNU-`date` guard on the sh
  side per H1; no `date -j`/epoch, avoiding the B-02 skew class). Open items (`[UNVERIFIED]`/
  `[SUSPECTED]`) get an open-question line; `[VERIFIED]` a lighter re-confirm nudge. Excludes
  `[REVIEWED: not a hazard]`, the `_` placeholder row, and files still carrying
  `KNOWN_HAZARD_AREAS_PENDING` (M4). Block lives inside `$body`/`emit_body` so the Copilot
  surface gets it via JSON `additionalContext` (M5). `bootstrap.md` 3d-bis now pins `Reviewed`
  and the not-a-hazard status to ISO `YYYY-MM-DD` (the parser keys on it). Header "keep fast"
  comment updated to include FRAMEWORK-CONTEXT.md + the ~12-row cap (L2).
- **D3 — rendered legend + "merge ≠ verified".** `FRAMEWORK-CONTEXT.md` gains a visible
  (non-comment) one-line ladder legend and the sentence *"Merging the PR does not confirm these
  …"* directly above the hazard table — the prior explanation lived inside an HTML comment that
  never renders in GitHub file view (M3). The `[VERIFIED]/[SUSPECTED]/[UNVERIFIED]` tokens stay
  (machine anchors for D2's parser and 3d-bis's writer).

**Verification:** new `src/core/tests/hooks/SessionStartHazard.Tests.ps1` (19 cases: resurface /
fresh-silent / unparseable-skip / REVIEWED-excluded / placeholder-skip / PENDING-silent /
confirmed-stale lighter nudge / suspected-resurface / twin-agreement / Copilot dual-shape on both
twins) — red-tested against the pre-D2 HEAD hook (no resurface line), green after. Cross-stack
sibling parity confirmed byte-identical (D1/D3 inserts). Gates green: build ×3 + dist freshness;
validate-dist ×3 (markers, template-checks/AGENTS mirror, no-meta-leak, no-dead-instruction);
dotnet dist hook suite 0 failures across 10 files (TwinParity 40/40). Full gate battery via
`release.ps1`.

## 0.27.1 (2026-07-16)

### Fixed — B-37: post-ship review findings on v0.27.0 (team wiki memory)

Post-ship review of `60dd04c` against the locked B-27 spec (WSD-010) found six defects, all
fixed here. Review/verification: Fable 5; implementers: Opus 4.8 (scripts + tests), Sonnet 5
(docs). Full evidence in `meta/BACKLOG.md` B-37.

- **F1 (P1)** `wiki-check.sh` used GNU-only `date -d` — the only occurrence in any shipped
  script — so on BSD/macOS every *valid* `last-verified` FAILed as "invalid last-verified",
  turning macOS consumer CI red via the `docs-sync-check` chain on the first wiki entry.
  Replaced with pure-shell calendar validation (rejects 2026-02-30 deterministically on every
  platform) + a feature-detected 90-day cutoff (GNU `date -d` → BSD `date -v` → skip the
  staleness WARN); the per-entry staleness check is a lexical YYYY-MM-DD compare.
- **F2** Both `wiki-check` twins read `$Root` from **stdin** when no argument was given, so an
  interactive `docs-sync-check` run blocked waiting for a keyboard line (CI survived only via
  /dev/null stdin). The stdin path is removed: root comes from the argument — `docs-sync-check`
  now passes it explicitly — or self-anchors to `scripts/..` like `template-checks`.
- **F3** The sorted-index check was locale-dependent (bare `sort` in .sh vs culture-sensitive
  `Sort-Object` in .ps1 — glibc UTF-8 locales collate hyphens differently, the B-02 skew
  class). Pinned to byte/ordinal order in both twins (`LC_ALL=C sort`;
  `[StringComparer]::Ordinal`); `remember-for-team` step 4 documents the order.
- **F4** Locked-spec omissions (D4/D9) shipped: the "What We've Learned" boundary sentence in
  `CLAUDE.md` and the LEARNINGS-vs-wiki boundary table in `docs/wiki/INDEX.md`.
- **F5** `SessionStartWiki.Tests` now cover the `.sh` hook's Copilot-JSON `additionalContext`
  delivery (jq/python3-gated, skip otherwise); red tests added for the F1 (non-calendar date)
  and F3 (hyphen adjacency) defect classes — both run both twins and assert verdict agreement.
- **F6 (pre-existing, found while verifying)** `_HookHarness.ps1` `Invoke-Hook` decoded child
  stdout with `[Console]::OutputEncoding`, so the em-dash summary-line assertions failed on any
  non-UTF-8 console (reproduced under ibm850) — v0.27.0's "hook suites green" was
  environment-dependent. The capture now pins UTF-8 and restores the prior encoding in
  `finally` — the harness-side leg of the v0.26.5 rendering fix.

Logged-not-fixed (locked design, revisit only on consumer evidence): the D6 injection-marker
list hard-FAILs benign prose descriptions containing `instead of` (observation in B-37).

## 0.27.0 (2026-07-16)

### Added — B-27 team wiki memory (WSD-010)
- New `docs/wiki/` per dist: `INDEX.md` (normative grammar, sorted by slug) + `_template.md`,
  a flat one-fact-per-file team wiki (gotcha/context/recipe/failed-approach) with frontmatter
  (`name`, `description`, `type`, `scope`, `status`, `last-verified`).
- `remember-for-team` skill (human-gated write path: triage/redirect, dedup-before-create, draft
  from template, sorted-insert into `INDEX.md`, honest "draft until PR review" close). Mirrored
  to `.github/skills/` for Copilot parity.
- `wiki-check.ps1/.sh` twins: structural validation (index↔file bijection, frontmatter schema,
  enum values, sort order) plus an injection screen — FAIL on INDEX-line/description-level
  matches, WARN (advisory only) on body-level matches. Wired into `docs-sync-check` (both twins).
- `session-start.ps1/.sh` preload the wiki index (inline when small, summarized above a size
  threshold, silent when absent), on both Claude Code and Copilot surfaces.
- `CLAUDE.md`/`AGENTS.md` companion-preamble line + Common Tasks/self-review pointers to the wiki.
- `install.ps1/.sh`: `docs/wiki/INDEX.md` is copy-if-absent (joins `$adoptionSignals`), everything
  else under `docs/wiki/` copies normally — a consumer's own wiki survives a framework update.
- `adopt.md` D7: `docs/wiki/**` is a **screen-in-place** candidate class — clean entries stay
  where they are (never archived/merged); flagged entries quarantine to
  `docs/pre-adoption/quarantine/` with their INDEX line intact, keeping `wiki-check` red until a
  human resolves them.

### Fixed (found during B-27 implementation review)
- `wiki-check.sh`'s injection-signal character class matched the INDEX grammar's own mandatory
  em-dash under real UTF-8 collation, failing every syntactically valid entry. Rewritten as
  `LC_ALL=C` byte-exact UTF-8 matching, mirroring the `.ps1` twin's codepoint ranges.
- `wiki-check.sh` failed to resolve a native Windows-style root path; now normalizes separators
  (and uses `cygpath` when available) before building `docs/wiki` paths.
- `install.ps1`'s D8 fix had diverged structurally from the `.sh` twin (a full per-file rewrite of
  the copy loop vs. the twin's surgical `docs/`-only special case) — restored to the same shape.
- The shipped `_template.md` carried a leading HTML comment that broke its own frontmatter
  contract the moment it was used literally; removed to match the locked design's D2 template.

## 0.26.5 (2026-07-15)

### Added — B-32 context-footprint gate (WSD-017)
- Added deterministic context measurement and a reviewed-baseline CI gate with advisory ceilings.
- Release automation re-measures the baseline after version stamping.

### Fixed
- Aligned PowerShell session-start and prompt-routing guidance with canonical bash rendering
  byte-for-byte. The new rendered-hook check exposed Unicode, blank-line, and whitespace drift.
- PowerShell hooks now emit UTF-8 whenever their output is captured, preventing Windows OEM
  output encoding from garbling the Unicode guidance.

## 0.26.4 — 2026-07-12

> **The gates that should have caught v0.26.3's defects.** Every gate this repo had was a *parser*
> gate — markers resolve, JSON parses, `bash -n`, PS-AST, twins agree, no meta vocabulary leaks. The
> product is prose aimed at a model, and **nothing tested whether the prose works.** Three defects
> walked straight through. Two of them were mechanically catchable and now are.
>
> Written before the cleanup, red-tested first, per `DEVELOPING.md`: *a gate you have never seen fail
> is not a gate.* Each one found a live defect on its first run.

### Added — `no-dead-instruction` (`validate-dist` check 7, both twins)
Every script a shipped doc tells someone to **run** must exist, resolved from the dist root.
Check 6 (`no-meta-leak`) proves shipped docs don't say the wrong *words*; nothing proved they don't
give the wrong *commands*.
**Found on first run:** a **second, un-noticed instance of the v0.26.3 defect** —
`dist/monorepo/README.md:137` (the update-mode section) still told consumers to run
`bash install.sh` / `pwsh install.ps1`, which do not exist in that dist. I fixed the §1 occurrence
this morning by hand and missed this one. The gate did not.

### Added — `InstallerContract.Tests.ps1` (meta suite)
Runs the **shipped installer for real** — 3 dists × greenfield/brownfield × `.ps1`/`.sh` = 12 installs
into temp targets — and asserts its **stdout** states the whole agent contract: commit the files;
your task is NOT complete until you hand off; do not hand-replicate `/bootstrap`|`/adopt`;
`docs-sync-check` is red **by design**. Asserted as *behavior*, not as prose in a source file — the
only way to catch a mode branch that quietly stops printing it, which is exactly what greenfield did.
Red-tested by regressing greenfield to its pre-v0.26.3 wording: fails on both twins, other dists stay
green.

### Added — `DocTruth.Tests.ps1` (meta suite)
The authoring docs must describe the repo that exists: one version stamp everywhere, README's claimed
version == what's shipped, no phantom marker syntax, every `scripts/…` path in a root doc resolves,
every script `ci.yml` invokes exists. Docs that lie to the *maintainer* are how the next defect gets
authored.
**Found on first run:** `CLAUDE.md:63` pointed at `scripts/template-checks.*` as if it were a root
script. It is per-dist (`dist/<stack>/scripts/`); no root one has ever existed. Flagged by the
adversarial review earlier today and still not fixed until a machine insisted.

### Fixed
- **`dist/monorepo/README.md:137`** — update-mode install command (see above). Shipped.
- **`CLAUDE.md:63`** — `template-checks` path now unambiguous.
- **Both new test files initially swallowed their own failures.** They ended with
  `Write-TestSummary`, not `exit (Write-TestSummary …)`, so the meta runner (which sums
  `$LASTEXITCODE`) saw 0 regardless. `DocTruth` reported *2 failed* while the suite reported *0
  failures* — a gate lying about itself, caught only because the numbers disagreed on screen. The
  established files had it right; the new ones didn't. Fixed and regression-tested: a planted failure
  now propagates to the suite exit code.

### Known blind spot (stated, not solved)
Whether the prose actually **steers a model** is still untested. That needs a real agent driven
end-to-end, which needs standing permission to spawn one non-interactively — a deliberate trade not
taken. The other two v0.26.3 defects (an installing agent mistaking this repo for its target; the
archived repos sending agents to install the frozen v0.25.5 template) were found *only* by driving
agents by hand, and no gate here would catch their like. Recorded in `DEVELOPING.md` so the next
maintainer doesn't mistake green gates for coverage.

## 0.26.3 — 2026-07-12

> Started as "did the merge drop the README's *For AI agents (LLMs)* section?" It did not — §1 is
> intact in all three dists and `git log -S` shows only additions. But the merge **moved the front
> door** (the legacy template repos → this authoring repo), and chasing that turned up a dead install
> command in `dist/monorepo` and an installer branch that under-instructs installing agents.
>
> **The diagnosis was baselined before anything was fixed**, and the baseline killed the original
> hypothesis — see `meta/LEARNINGS.md`.

### Fixed (shipped)
- **`dist/monorepo/README.md` §1 told installing agents to run a command that does not exist.** It
  said `pwsh install.ps1 <target>`; that dist contains only `scripts/install.ps1` (`dist/{dotnet,
  angular}` correctly said `scripts/install.ps1`). Root-installer wording had been copied into a dist
  README during Phase 4 monorepo authoring. Since the root README's blockquote routes readers straight
  into `dist/<stack>`, an agent following that trail hit `No such file or directory` — on the mixed
  .NET + Angular path, i.e. exactly the audience `dist/monorepo` exists for. Fixed in
  `src/stacks/monorepo/files/README.md`.
- **The greenfield branch of the shipped installer under-instructed AI agents relative to brownfield.**
  Brownfield printed a standalone *"IF YOU ARE AN AI AGENT … your task is NOT complete until you have
  done step 1 [commit] and then told the developer … Do not attempt /adopt yourself or replicate it by
  hand"* block. Greenfield printed only a weaker parenthetical: no "or replicate it by hand", and no
  warning that `docs-sync-check` fails **by design** until `/bootstrap` runs — so an agent would see
  red CI and try to fix it. Greenfield now prints the same contract, naming `/bootstrap`.
  Single-sourced in `src/core/scripts/install.{sh,ps1}` [#1], twins in lockstep [#3].
  **Observed, not theorised:** a baseline run (Opus 4.8, cwd = this repo, prompt *"install this
  framework into `<target>`"*) chose the right installer, detected greenfield, was **not** captured by
  this repo's maintainer `CLAUDE.md`, and correctly refused to run `/bootstrap` — but explicitly
  declined to **commit** the copied files in the target. Step 1 of the contract, silently dropped.

### Docs (authoring repo — not shipped)
- **`@@INCLUDE` was phantom syntax.** Documented in `README.md`, `CLAUDE.md`, `AGENTS.md` and
  `DEVELOPING.md`; implemented nowhere. The composer's marker is `<!-- @stack:NAME -->`
  (`scripts/build.ps1:6-7`). Corrected in all four. (The historical v0.26.0 entry below is left as
  written — it is a dated record, not live guidance.)
- **Root `README.md` had no acquisition step.** Every install instruction presumed a local clone the
  reader was never told to make (`grep -i clone README.md` → zero hits). `## Quick start` now opens
  with `git clone`.
- **`fidelity-check` was still described as a live CI gate** in `README.md` and `DEVELOPING.md`. It was
  retired from CI at v0.26.0 (`ci.yml:11-15`); it remains a manual re-audit tool. Corrected.
- Root `README.md` claimed shipped v0.26.1 against an actual stamp of v0.26.2.

### Not done (deliberately)
- **No rewrite of this repo's root `CLAUDE.md`/`AGENTS.md` banner.** The pre-fix hypothesis was that
  the always-loaded maintainer governance captures an installing agent and its unqualified *"commit to
  `master` and push"* would make it push to **this** repo. The baseline did not reproduce either. One
  sample (Opus 4.8, plan mode, .NET target) is not proof — but it is evidence against, and a prose
  change with no observed failure behind it is exactly what this repo's own record warns off.

## 0.26.2 — 2026-07-12

> Hotfix for a defect v0.26.1 introduced, plus the machine check that would have caught it.
> v0.26.1's CI went **red on the linux leg** — the two composers disagreed on
> `dist/{dotnet,angular}/.claude/hooks/post-write.sh`.

### Fixed
- **A lone `0xE2` byte in two `src/stacks/*/files/.claude/hooks/post-write.sh` files.** Introduced by
  a v0.26.1 `sed` whose character class contained an em-dash (`[-—]`). `sed` matches **bytewise**, so
  it stripped the em-dash's two continuation bytes (`80 94`) and left the lead byte stranded —
  invalid UTF-8. The two composers then disagreed by construction: `build.sh` copies the raw byte
  through, while `build.ps1` decodes and re-encodes it into `U+FFFD`. The committed dist matched
  whichever composer produced it, so the *other* CI leg failed the freshness diff. Comment text only;
  the hook's behavior was never affected.

### Added
- **A repo-wide valid-UTF-8 sweep in the meta test suite** (`WorkspaceBom.Tests.ps1`, alongside the
  BOM gate [#4]). Every file must decode under a **strict** UTF-8 decoder — one that throws rather
  than silently substituting `U+FFFD`, since a lenient decode would make the test vacuous. It carries
  a positive control that plants the exact byte sequence this release fixes. This closes a real hole:
  every local gate passed on v0.26.1, and **only** CI's cross-leg rebuild caught the divergence — a
  failure that surfaces far from its cause. It is now caught at the source, locally, before a push.

## 0.26.1 — 2026-07-12

> Seals the meta/product boundary. A sweep of the composed dists found **192 lines of maintainer
> vocabulary in shipped content** (81 dotnet / 83 angular / 28 monorepo), in two tiers. **22 lines
> genuinely installed into a consumer's repo:** tracking ids baked into live shipped hooks, scripts,
> and tests — including a pointer to the maintainer-only `release.ps1`, a script that does not exist
> in a consumer repo. **~170 lines product-visible but not installed:** almost all in the shipped
> changelogs, which were maintainer engineering logs (backlog ids, `WSD-nnn`, the "Fable-exit"
> codename, "lockstep with the .NET twin", links to the archived legacy repos, and a literal
> `_Maintainer-only (does not ship)_` note). The installer excludes `CHANGELOG.md` from the copy, so
> that tier never reached a working tree — but it is the surface a team reads when evaluating the
> framework. **The merge inherited this rather than causing it:** the legacy
> `ai-tech-lead-dotnet/CHANGELOG.md` carries the identical markers, and the v0.25.5 fidelity freeze
> copied them byte-for-byte. Full decision record: WSD-019.
>
> No behavior change — shipped *content* and repo layout only.

### Added
- **`no-meta-leak` — `validate-dist` check 6.** Scans each composed dist against the new
  `scripts/meta-denylist.txt` and fails if the framework's own development vocabulary appears in a
  shipped file. One denylist file, read by **both** the `.ps1` and `.sh` twins, so it cannot drift.
  It denies the *ID* forms (`B-nn`, `WSD-nnn`) rather than the words — `BACKLOG` and `twin` stay
  legal, because the product legitimately reads the consumer's own `BACKLOG.md` and the shipped
  `.ps1`/`.sh` twins are a real feature. The `ALLOW` list is consequently empty. CI already runs
  `validate-dist` per dist on both legs, so no workflow change was needed.

### Changed
- **The shipped changelogs are now written in the consumer's voice** — what changed in *their* repo
  and what they must do. Every version heading is preserved (37 / 38 / 2, unchanged); only the
  framing changed. Safe because the full engineering history is preserved verbatim in
  `meta/changelogs/legacy-*.md`.
- **Tracking ids stripped from shipped code comments** — `post-write.{ps1,sh}` (all three stacks),
  `template-checks.{ps1,sh}` (which also referenced the maintainer-only `release.ps1`),
  `build-architecture-html.ps1`, and four `tests/hooks/*.Tests.ps1`. Each comment now states the
  invariant the code holds rather than the ticket that produced it.
- **Stale pointers to the archived legacy repos removed** from the shipped `README.md`s and the
  monorepo changelog; the cross-stack advice now points at the monorepo distribution instead.
- **The maintainer layer moved to `meta/`** (`BACKLOG.md`, `workspace-decisions.md`, `LEARNINGS.md`,
  `ci-handover.md`, `changelogs/`), and **root `docs/` is gone** — that name belongs to the consumer
  (`dist/*/docs/`). `CLAUDE.md`/`AGENTS.md`/`.claude/` stay at the root because Claude Code loads
  them from there; their "you are in the authoring repo" banner remains the tie-breaker.

### Fixed
- **`validate-dist.ps1` resolved paths against the wrong root after check 5.** The dist's own
  `template-checks.ps1` does a `Set-Location` into the dist and never restores it, so any relative
  path used afterwards broke — on the PowerShell leg only, since the bash twin runs it in a subshell.
  Found by building the new gate before the cleanup. Paths are now resolved up front.

## 0.26.0 — 2026-07-12

> The single biggest structural change in the framework's history: two independently-versioned
> template repos (`ai-tech-lead-dotnet`, `ai-tech-lead-angular`) become one authoring repo,
> `ai-tech-lead`, that composes three installable distributions. The decision, rationale, and
> execution record live in `meta/workspace-decisions.md` (WSD-012 and its Phase 0–6 execution
> deltas, plus WSD-015, WSD-016, and WSD-018). Phase 6
> validation is green (real-toolchain install + `docs-sync-check` across all three dists, the
> monorepo security-overlay smoke, and the composer/validate/hook/meta gates — WSD-018); the two
> legacy repos are archived at this release with pointer READMEs, frozen at their last independent
> release, v0.25.5.

### Added
- **One authoring repo, three installable distributions.** Shared framework content — skills,
  commands, agents, hooks, `CLAUDE.md`/`AGENTS.md` templates, scripts — is now authored **once**
  under `src/`, and a deterministic composer emits `dist/dotnet`, `dist/angular`, and
  `dist/monorepo`, each a complete, installable, single-stack (or mixed-stack) copy of the
  framework. Composition is concat-by-default with authored overrides where stacks genuinely
  diverge (`@@INCLUDE` markers in `src/core`, per-stack snippets/whole-file overrides under
  `src/stacks/<stack>/`) and an explicit-collision-is-an-error rule for the monorepo dist — no
  silent last-wins when the same path exists in more than one stack (WSD-015).
- **`dist/monorepo` — a new distribution for mixed .NET + Angular repos.** Previously a consumer
  with both a .NET backend and an Angular frontend in one repo had no first-class option; this
  dist carries the union of both stacks' content, with 111 authored merged/sectioned snippets and
  38 authored whole-file overrides where union-by-default wasn't safe (WSD-015). 148 files total.
- **Root installers with stack auto-detection.** `install.ps1` / `install.sh` at the repo root
  are thin wrappers: they resolve the target's stack (explicit flag → an existing update stamp →
  auto-detection from `*.csproj`/`*.sln` vs `angular.json`, checked at the root and two levels
  down → both found routes to `dist/monorepo` → neither found exits with a clear ask for the
  flag) and then delegate to the chosen dist's own byte-frozen installer. No install logic is
  duplicated outside `dist/`.
- **Full git history preserved from both legacy repos.** The merge used `git filter-repo` to
  relocate each legacy repo's history under `legacy/{dotnet,angular}/` before merging with
  `--allow-unrelated-histories` (zero conflicts — the trees were disjoint at merge time); `git log
  --follow` on any long-lived file (e.g. `CLAUDE.md`) traces back through the merge to its
  original v4.0 commit in whichever legacy repo it came from.

### Changed
- **Zero shipped-behaviour change, proven by a strict fidelity gate.** Every one of the 138
  tracked files in each legacy repo (dotnet, Angular) reproduces byte-for-byte (EOL-normalized)
  from the new `src/` composition — `scripts/fidelity-check.ps1/.sh` diffs the rebuilt
  `dist/dotnet` and `dist/angular` against the `freeze-v0.25.5` tags taken on both legacy repos
  before any restructuring began, with an **empty allowlist** (no version-stamp or
  stack-flavoured exclusions needed). This is the migration's central acceptance criterion: a
  consumer already running v0.25.5 of either template gets an update, not a behavior change, when
  they eventually move to a dist built from this repo.
- **The workspace meta-development layer moved into this repo (D7, WSD-016).** The maintainer
  workflow for developing the framework itself — previously governed by a separate, untracked
  workspace root one level up — now lives here: root `CLAUDE.md`/`AGENTS.md`/`DEVELOPING.md`
  (rewritten for single-repo composition instead of dual-repo lockstep), the `bom-fix` hook +
  its meta test suite, `meta/BACKLOG.md` and `meta/workspace-decisions.md` (this repo's ADR
  log), and the maintainer's `.claude/plans/`. The two-repo-specific `check-lockstep.ps1` gate is
  retired — its job is now structural (one source, three composed dists) rather than a
  cross-repo diff.
- **Shipped CI workflows use `actions/checkout@v5`.** The `template-ci.yml` and
  `docs-sync-check.yml` workflows that install into consumer repos were bumped from
  `actions/checkout@v4` to `@v5` (GitHub's Node 20 runtime deprecation). This is the first
  release to deliberately change shipped content since the freeze, so it also retires the
  authoring repo's strict fidelity-check CI legs (dist == `freeze-v0.25.5`) — the freeze tags
  are no longer the baseline; `src/ → dist/` freshness (rebuild + diff) plus per-dist
  `validate-dist` and hook suites remain the CI guardrails.

### Notes
- Phase 6 (`MERGE-MIGRATION-PLAN.md`) validation completed green (WSD-018); the two legacy repos
  — `ai-tech-lead-dotnet` and `ai-tech-lead-angular` — are archived at this release with pointer
  READMEs directing consumers here. They remain readable, frozen at v0.25.5.
- Legacy framework history predating the merge: [`meta/changelogs/legacy-dotnet.md`](meta/changelogs/legacy-dotnet.md),
  [`meta/changelogs/legacy-angular.md`](meta/changelogs/legacy-angular.md).

---

## How to update this changelog

- One section per release (or per "Unreleased" working window). Date the heading once released.
- Group entries by **Added / Changed / Fixed / Removed / Decided**.
- One line per change. Reference the file or workflow touched, not the implementation detail.
- Framework-level decisions (the merge, composition rules, hook semantics) go in
  `meta/workspace-decisions.md`; this file is the consumer-facing summary of what shipped.
