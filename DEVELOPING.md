# DEVELOPING — operational runbook

Commands, not philosophy. The rules and the meta-invariant list live in `CLAUDE.md`; this file
**references** them by number and never restates them. Paths assume cwd = the repo root.

## Repo map

| Path | What | Notes |
|------|------|-------|
| `src/core/` | shared single-source content | `<!-- @stack:NAME -->` markers where stacks diverge |
| `src/stacks/<dist>/snippets/<rel>/<NAME>` | marker content per dist | monorepo snippet wins; else dotnet+angular concat (WSD-015) |
| `src/stacks/<dist>/files/` | whole-file overrides + stack-only files | both-stacks collision without a monorepo override = build error |
| `dist/{dotnet,angular,monorepo}/` | generated golden output (committed) | **never hand-edit** [#1]; `linguist-generated` |
| `scripts/` | composer + gates, `.ps1`/`.sh` twins [#3] | `build`, `validate-dist`, `fidelity-check` |
| `install.ps1` / `install.sh` | root installers | detect stack, auto-detect mixed → monorepo, delegate to dist installer |
| `.claude/hooks/` | meta-dev hook (`bom-fix.ps1`/`.sh` — auto-adds the UTF-8 BOM to written `.ps1`) | this repo only, does not ship |
| `.claude/hooks/_fixtures/` | JSON event fixtures for testing the hooks | see below |
| `.claude/scripts/release.ps1` | release automation [#7] | PowerShell-only by decision |
| `.claude/scripts/watch-ci.ps1` | watches GitHub Actions for a commit; 0 green / 1 red / 3 cannot-verify | used by `release.ps1` step 5c, runnable by hand |
| `.claude/scripts/_ci-decision.ps1` | the publish decision table (tag / exit code) as a callable function | dot-sourced by `release.ps1` and by its tests |
| `.claude/plans/` | plans [Conventions] | includes the locked B-21/B-22/B-27 design specs |
| `meta/` | `BACKLOG.md`, `workspace-decisions.md`, `LEARNINGS.md`, `ci-handover.md`, `changelogs/legacy-*.md` | maintainer layer; never ships. No root `docs/` — that name is the consumer's |
| `scripts/meta-denylist.txt` | the `no-meta-leak` patterns [#6] | one file, read by BOTH twins so it cannot drift |

## Compose the dists + freshness [#1]

```powershell
foreach ($d in 'dotnet','angular','monorepo') { pwsh -NoProfile -File scripts/build.ps1 $d }
git status --porcelain dist/   # MUST print nothing — otherwise commit the dist with your src change
```
```bash
for d in dotnet angular monorepo; do bash scripts/build.sh "$d"; done   # .sh twin (CI linux leg)
```

## Validate the dists (markers, JSON, bash -n, PS-AST, per-dist template-checks [#2, including Common Tasks skill inventory], no-meta-leak [#6], no-dead-instruction, hook-registration, step-references)

```powershell
foreach ($d in 'dotnet','angular','monorepo') { pwsh -NoProfile -File scripts/validate-dist.ps1 $d; "exit=$LASTEXITCODE" }
```
```bash
for d in dotnet angular monorepo; do bash scripts/validate-dist.sh "$d"; echo "exit=$?"; done   # .sh twin
```

### Red-test the `no-meta-leak` gate [#6]

A gate you have never seen fail is not a gate. Plant a tracking id in a composed dist, confirm the
check names the exact `file:line`, then restore:

```bash
echo 'WSD-999 planted' >> dist/dotnet/README.md
bash scripts/validate-dist.sh dotnet; echo "exit=$?"   # MUST be 1, naming README.md and the pattern
git checkout -- dist/dotnet/README.md
bash scripts/validate-dist.sh dotnet; echo "exit=$?"   # back to 0
```

### Red-test the `no-dead-instruction` gate (check 7)

Check 6 proves shipped docs don't say the wrong *words*. Check 7 proves they don't give the wrong
*commands*: every `pwsh`/`bash` script path in a shipped `.md` must exist, **resolved from the dist
root** (the framework documents every command as run from the repo root). `CHANGELOG.md` is skipped
— release notes quote commands that *were* wrong in order to say they're fixed.

It also reports its coverage: the current dists contain 88/84/96 scanned docs and 30/30/31 inline
script references. Zero docs or zero extracted references is a failure. Absolute paths in docs remain
out-of-scope placeholder examples (and are listed); this is deliberately unlike hook registrations.
`ValidateDist.Tests.ps1` is the executable version of these red-test recipes.

```bash
sed -i 's|pwsh scripts/install.ps1|pwsh install.ps1|' dist/monorepo/README.md
bash scripts/validate-dist.sh monorepo; echo "exit=$?"   # MUST be 1, naming README.md:14
pwsh -NoProfile -File scripts/build.ps1 monorepo         # restore from src
```

### Red-test the `hook-registration` gate (check 8)

Check 7 covers commands a shipped **doc** gives a human. Check 8 covers the wiring the **host** acts
on: every script named in `.claude/settings.json`, `.claude/settings.windows.json` and
`.github/hooks/hooks.json` must exist in the dist, and so must its opposite-language twin [#3].
26 registrations per dist. Work on a scratch copy — both twins take a dist-root argument, so you
never have to mutate `dist/`:

The derived shape is 6 + 6 + 14 registrations: settings.json 6, settings.windows.json 6, and seven
Copilot entries with both bash and powershell legs. Registration targets may never be absolute;
interpreter and `.ps1`/`.sh` suffix comparisons are case-insensitive. A deliberately single-leg
Copilot entry requires updating this check on purpose. `ValidateDist.Tests.ps1` runs these recipes
against real scratch copies.

```bash
S=$(mktemp -d)/dc; mkdir -p "$S"; cp -r dist/dotnet "$S/"
rm "$S/dotnet/.claude/hooks/audit-trail.sh"                       # a half-shipped hook
pwsh -NoProfile -File scripts/validate-dist.ps1 dotnet "$S"; echo "exit=$?"   # MUST be 1
bash scripts/validate-dist.sh dotnet "$S"; echo "exit=$?"                     # MUST be 1, same text
rm -rf "$(dirname "$S")"
```

### Red-test the `step-references` gate (check 12)

Check 12 scans top-level ordered-list labels and numbered prose step references in shipped skills,
commands and agents. It blanks fenced code before both scans, accepts runs starting at `0.` or `1.`,
and resolves each prose reference against a list label or `Step N` heading in the same file.

```bash
S=$(mktemp -d)/dc; mkdir -p "$S"; cp -r dist/dotnet "$S/"
printf '\n1. first\n3. planted\nSee step 1.\n' >> "$S/dotnet/.claude/skills/create-adr/SKILL.md"
bash scripts/validate-dist.sh dotnet "$S" -Check step-references; echo "exit=$?" # MUST be 1, naming the run at 3
rm -rf "$(dirname "$S")"
```

Two environment variables exist for `ValidateDist.Tests.ps1` and are **never set by `release.ps1` or
CI**:

| Switch | Effect |
|---|---|
| `--content-only` (**argument**, both twins) | Skip checks 1–5 and run only 6, 7, 8 and 12. Prints a `NOTE:` line saying so — a partial run must never read as a full one. The suite's green anchors deliberately omit it, so the skipped group stays exercised on both legs. It is an **argument and not an environment variable on purpose**: an ambient switch that narrows a gate's scope can be inherited by a shell that never asked for it, and `release.ps1` sends validator output to a log where the `NOTE:` would go unread. |
| `VALIDATE_DIST_JSON_TOOL=python3\|jq` (env, bash twin) | Pin the parser branch. Without it, whichever tool a box happens to have decides which branch is ever executed — which is how the two branches came to disagree. Naming an absent tool is FATAL, never a silent fallback: it cannot quietly downgrade a run. |

Run **both** legs: registrations are JSON-parsed. The bash branch frames each decoded value as
base64 in a tab-delimited record and the regression suite deliberately runs and compares its jq and
python3 streams when both are installed. A registration that names a missing script is a
hook that silently never runs — no guard, no post-write feedback, no audit trail, and no error
anyone reads. Check 8 deliberately does **not** reject a bare interpreter name; see the check's
comment for why (v0.38.1).

> **Hazard on this box:** `bash scripts/validate-dist.sh` exits FATAL at check 4 ("neither pwsh nor
> powershell is available") because the session `PATH` is corrupted and PowerShell's install
> directory is not visible to Git Bash. Prepend it before running the `.sh` leg:
> `export PATH="/c/Program Files/PowerShell/7:$PATH"`.
> That FATAL is a host problem, not a dist problem — see B-85.

This is the gate that would have caught the v0.26.3 defect: `dist/monorepo`'s README told installing
agents to run `pwsh install.ps1`, which exists nowhere in that dist. When you name a twin pair in
prose, write it as `` `build.{ps1,sh}` `` — the shorthand `` `build.ps1/.sh` `` reads as a *path*
and will trip the gate.

Both twins must agree. If you add a pattern to `scripts/meta-denylist.txt`, red-test it the same
way — and prefer a narrow `ALLOW <path-substring>` over weakening a `DENY` when a legitimate
consumer-facing word trips the check.

## Fidelity vs the frozen v0.25.5 baseline (manual re-audit only — no longer a CI gate)

Strict EOL-normalized byte-compare of `dist/{dotnet,angular}` against the Phase-0 freeze tags
(materialized from history — needs full clone depth). **Retired from CI at the v0.26.0 release**,
which deliberately changed shipped content; the freeze tags are no longer a live baseline. The
scripts remain for a manual re-audit against the `pre-restructure` tag (see CLAUDE.md → Migration
status note). `dist/monorepo` never had a baseline (new capability).

```powershell
pwsh -NoProfile -File scripts/fidelity-check.ps1 dotnet
pwsh -NoProfile -File scripts/fidelity-check.ps1 angular
```

## Run the hook test suites (automated — closes the "untested hook" gap [#5])

Dependency-free PowerShell harness (**no Pester** — corporate boxes ship only Pester 3.x). Each
test pipes a JSON event to a hook and asserts exit code + output shape; **twin** tests run the
`.ps1` and the `.sh` on the same input and assert the *same decision*.

```powershell
# shipped suites — run against the DIST copies (what ships), one per dist
pwsh -NoProfile -File dist/dotnet/tests/hooks/Invoke-HookTests.ps1
pwsh -NoProfile -File dist/angular/tests/hooks/Invoke-HookTests.ps1
pwsh -NoProfile -File dist/monorepo/tests/hooks/Invoke-HookTests.ps1
# repo meta suite (bom-fix, BOM sweep, + the two behavioral gates below; does NOT ship)
pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1
```

### Set `ATL_TEST_PYTHON` / `ATL_TEST_JQ` on this box, or you lose coverage silently

Several cases need a **real** JSON parser to exercise the no-`jq` fallback the shipped `.sh` hooks
depend on. They resolve one by execution over `python3`/`python`/`py` — and on this box **none of
those resolve**, because the session `PATH` is the known corrupted one. Without help those cases take
an invariant-guarding skip, which is honest but is *not* coverage:

```powershell
$env:ATL_TEST_PYTHON = 'C:\Python314\python.exe'   # a real python.org install (no python3.exe exists)
$env:ATL_TEST_JQ     = '<home>\bin\jq.exe'
```

These are **environment variables on purpose**. The same values were first written as hardcoded
fallbacks inside `src/core/tests/hooks/_HookHarness.ps1`, which composes into every dist — so a
consumer would have received a test harness reaching for this machine's username. `no-meta-leak`
does not catch that (see the backlog entry on machine-local paths); the review did. Keep host
specifics in your shell, never in a shipped file.

Skips from these cases are printed under an **`INVARIANT-GUARDING SKIPS`** heading in the suite
summary rather than as an inline `[skip]` line, because a skip that scrolls past inside a green
total reads as coverage — that is how a permanently-unexercised assertion hid a P1 for as long as it
existed. If you see that heading, the run did **not** cover those branches.

### The behavioral gates (meta suite — auto-discovered, no wiring needed)

Everything else in this repo is a **parser** gate: it proves the artifacts are well-formed, not that
they *work*. The product is prose aimed at a model, and three defects shipped straight through the
parser gates (v0.26.3). These two cover what a parser cannot. Drop a new `*.Tests.ps1` into
`.claude/hooks/tests/` and the runner picks it up.

| Gate | What it drives | The defect class it exists to catch |
|------|----------------|--------------------------------------|
| `InstallerContract.Tests.ps1` | **Runs the shipped installer** — 3 dists × greenfield/brownfield × `.ps1`/`.sh` = 12 real installs into temp targets — and asserts its **stdout** states the whole agent contract (commit the files; task NOT complete until handoff; don't hand-replicate `/bootstrap`\|`/adopt`; `docs-sync-check` is red by design). | A mode branch that quietly stops printing part of the contract. Greenfield had drifted weaker than brownfield and a real agent duly copied files and walked away without committing them. |
| `DocTruth.Tests.ps1` | The **authoring** docs vs the repo that exists: one version stamp everywhere, README's claimed version == what's shipped, no phantom marker syntax, every `scripts/…` path in a root doc resolves, every script `ci.yml` invokes exists. | Docs that lie to the *maintainer* — which is how the next defect gets authored. A marker syntax that the composer has never implemented was documented in four files at once. |

Red-test them the same way as any gate — plant the defect, watch it fail, restore:

```bash
# InstallerContract: regress greenfield to its pre-v0.26.3 wording
sed -i 's|Do not attempt /bootstrap yourself or replicate it by hand.|Do not attempt /bootstrap yourself.|' dist/dotnet/scripts/install.sh dist/dotnet/scripts/install.ps1
pwsh -NoProfile -File .claude/hooks/tests/InstallerContract.Tests.ps1   # MUST fail dotnet/greenfield on BOTH twins
pwsh -NoProfile -File scripts/build.ps1 dotnet                          # restore from src
```

**What is still not covered by a gate:** whether the prose actually *steers* a model — that needs a
real agent driven end-to-end and API/subscription spend, so it is deliberately not wired into any
of the suites above. B-41's live harness below closes the evidence gap for the Claude host (not
the gate gap, and not yet the Copilot host — see `meta/BACKLOG.md`): it is maintainer-triggered,
not automatic, and its results are a trend log, not a pass/fail release condition.

- **Exit code = number of failing tests** (0 = green).
- **`.sh` fidelity:** on Windows the harness drives `.sh` via Git's `bin\bash.exe` wrapper so
  `cat`/`grep`/`jq` resolve; `.sh` tests self-skip when no bash is found (pure-Windows safe).
- **Host:** prefers `pwsh` (7+); falls back to `powershell.exe` [#4 platform].

### Agent-host paths on this box — none of them resolve by bare name

The session `PATH` contains three entries and the third is the **literal unexpanded string
`${PATH}`**, so every agent host is invisible to a bare command name. This is a session artifact —
the registry is fine, and "fixing" it is a known dead end. Use absolute paths, or prepend the
directory for the child process.

> **Repair `PATH` before running any gate suite, or you are measuring a machine that does not
> exist.** `C:\Windows\System32` is *also* absent, so even `powershell` does not resolve
> (`(Get-Command powershell).Source` returns nothing). The shipped `framework-doctor.ps1` spawns a
> bare `powershell` when it runs under 5.1; with this `PATH` that spawn fails and the doctor reports
> mirror drift that does not exist, failing a **dist** hook suite — which `release.ps1` cannot waive
> by design. Measured on one unmodified tree, same command, only `PATH` changed:
> `29 passed, 1 failed, 1 skipped` → `31 passed, 0 failed, 0 skipped`. Note the skip: a broken
> `PATH` silently *removes* coverage as well as adding false failures. Prepend this first:
> `$env:PATH = "C:\Windows\System32;C:\Windows;C:\Windows\System32\WindowsPowerShell\v1.0;" + $env:PATH`
> Corollary: treat any 5.1-only failure here as `PATH`-suspect **before** diagnosing it as an
> encoding bug (see B-130 — that was its original hypothesis, and it was wrong for this case).
>
> **That repair is for PowerShell ONLY. Never prepend `C:\Windows\System32` inside Git Bash** —
> Windows ships `find.exe`, `sort.exe` and friends there, so prepending shadows the GNU coreutils
> every `.sh` gate depends on. Measured 2026-08-17: with it prepended, `which find` resolves to
> `/c/Windows/System32/find`, and `find … -type f -name '*.md'` answers
> `FIND: Parameter format not correct` — so `validate-dist.sh`'s step-reference scan saw **zero
> files** and failed, a broken shell wearing the costume of a broken dist. In bash add only the
> PowerShell directory: `export PATH="/c/Program Files/PowerShell/7:$PATH"`.
> That failure was loud only because the check carries a zero-files guard. Without one it would have
> been a silent green over an empty scan — which is the argument for those guards in one sentence.

| Tool | Absolute path |
|---|---|
| Claude Code | `$env:USERPROFILE\.local\bin\claude.exe` |
| Copilot CLI | `$env:APPDATA\npm\copilot.cmd` |
| GitHub CLI | `C:\Program Files\GitHub CLI\gh.exe` |
| pwsh 7 | `C:\Program Files\PowerShell\7\pwsh.exe` |
| node | `C:\Program Files\nodejs\node.exe` |

Each fails differently and none of the errors names `PATH`, which is why this table exists:

- `pwsh` from Git Bash → `No such file or directory`.
- `claude` → the harness's own `claude CLI is not installed or not on PATH` (accurate, but reads as
  "install it").
- **`copilot` → `'"node"' is not recognized`** — the npm shim shells out to `node`, so Copilot looks
  broken when the real gap is `C:\Program Files\nodejs`. Prepend **both** the nodejs directory and
  the npm directory before invoking Copilot.

Also beware `cmd 2>&1 | tail -n` in Bash: `$?` then reports `tail`'s status, so a total failure
prints `EXIT=0`. Capture the exit code before the pipe.

### The live agent-behavior harness (B-41 — maintainer-triggered, spends budget, not a gate)

`.claude/evals/run-agent-evals.ps1` drives the installed `claude` CLI through fixture scenarios in
disposable temp repos and grades **typed, observable** evidence — matched `tool_use`/`tool_result`
events, git state, file bytes — never transcript prose alone. It never runs in CI and never gates
a release; see the locked design in `.claude/plans/2026-07-17-b41-agent-behavior-harness-design.md`
and results in `meta/eval-results.md`.

```powershell
# free, no network — proves the harness's own typed-evidence grading on synthetic/adversarial
# fixtures (malformed streams, keyword echoes, developer checkpoints, inverted tool-result
# semantics, ...). .claude/evals/tests/AgentEvals.Tests.ps1 wraps this same check but is not
# auto-discovered by the hook runner above — evals are deliberately a separate suite from hooks,
# so run either the wrapper or the flag directly:
pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -SelfTest

# spends real budget — requires dist/ to match the checked-out release (version == root
# CHANGELOG head) with no local diff
pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -Live [-Scenario route-fix] [-Model sonnet]
```

`release.ps1` runs `-SelfTest` as a deterministic gate and, only after a successful release commit
(and push), offers an interactive prompt for an optional `-Live` run — never a hard fail — and
persists its evidence in a follow-up commit.
- **Speed:** slow by design — a process is spawned per hook invocation; a full dist suite takes
  ~1–2 min. Expected, not a hang.

**CI** — `.github/workflows/ci.yml` runs compose→freshness→validate→hook suites on every
push/PR (windows leg rebuilds with the `.ps1` composer, linux leg with the `.sh` twin — composer
twin divergence fails a leg), plus the meta suite. Fidelity is **not** a CI step (see above).

Manual one-off (debugging a single hook) — pipe a fixture straight in:

```powershell
(Get-Content .claude/hooks/_fixtures/write-bomless-ps1.json -Raw) | pwsh -NoProfile -File .claude/hooks/bom-fix.ps1
```
```bash
bash -n dist/dotnet/.claude/hooks/guard.sh   # bash twin syntax only
```

## Check PowerShell syntax (repo-wide)

```powershell
foreach ($f in (Get-ChildItem -Recurse -Filter *.ps1 -Path src,dist,scripts,.claude)) {
  $e=$null; [System.Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$null,[ref]$e) | Out-Null
  if ($e) { "FAIL $($f.FullName): $($e[0].Message)" } }
"ps-syntax-checked"
```

## Check BOM on every `.ps1` [#4]

```powershell
Get-ChildItem -Recurse -Filter *.ps1 -Path src,dist,scripts,.claude | ForEach-Object {
  $b=[System.IO.File]::ReadAllBytes($_.FullName)
  if (-not ($b.Length-ge3 -and $b[0]-eq0xEF -and $b[1]-eq0xBB -and $b[2]-eq0xBF)) { "NO-BOM: $($_.FullName)" } }
```

(The meta suite's `WorkspaceBom.Tests.ps1` runs the same sweep automatically on every release.)

## Monorepo-sibling discipline (WSD-015)

`dist/monorepo` composes: markers resolve to an authored `src/stacks/monorepo/snippets/<rel>/<NAME>`
**if one exists**, else to the dotnet+angular concatenation; whole-file collisions require a
`src/stacks/monorepo/files/` override (the build errors otherwise). Consequence: **editing a stack
snippet or stack whole-file that has a monorepo sibling does NOT reach `dist/monorepo` — review
and update the sibling in the same task.** Core edits, one-sided snippets, and the 5
concat-derived markers flow to all three dists automatically.
Two verification rules from the Phase-4 traps (see `LEARNINGS.md` 2026-07-10): judge
additive-safety **per twin** (a `.sh` line that unions by concatenation can be an overwriting
assignment in the `.ps1`), and sweep agent-authored artifacts for tool-syntax leakage
(`grep -rn '</content>\|</invoke>' src/`) before committing.

## Install smoke test [Definition of done]

```bash
rm -rf /c/temp/install-smoke-green && mkdir -p /c/temp/install-smoke-green
bash install.sh /c/temp/install-smoke-green            # root installer: prompts/detects the stack
bash dist/dotnet/scripts/install.sh /c/temp/install-smoke-green   # or a dist installer directly
# brownfield: pre-seed a colliding file, then install into the same kind of dir
# monorepo detection: seed both a .csproj and an angular.json in the target first
```

## Hazard: reviewing a branch that is still moving

When implementation runs concurrently with review (e.g. codex authoring on a branch while a
separate session reviews it), a clean `git status --porcelain` plus an existing commit is **not**
evidence the branch is settled — it can still be mid-amend or mid-rebase between two of your own
commands, and a full gate run started at that instant reads a half-rewritten working tree and
reports spurious failures. Caught three times in one sitting (2026-08-08): a merge that grabbed a
commit already superseded by a concurrent reset, a `grep` that read already-edited files and
concluded a real defect didn't exist, and a `validate-dist` run that failed mid-rebase for reasons
that had nothing to do with the change. **Before starting an expensive verification pass, confirm
the branch tip is unchanged across a short gap, not merely clean at one instant** — check the HEAD
hash, wait briefly, check it again. **Before the merge itself, re-read the branch tip one more
time** regardless of how long ago verification finished. Prefer verifying against a fixed commit
(`git show <hash>:<path>`, `git diff <a>..<b>`) over the live working tree whenever the two could
disagree. And for a shipped-behavior change specifically, prefer letting `release.ps1` below run the
authoritative full gate suite over re-running it all by hand first — it refuses to commit on
failure, so a manual pre-pass mostly duplicates it while being more exposed to this exact race; one
targeted red-test re-run is enough evidence for `-ReviewEvidence`.

## Release process

When shipped behavior changed [#7] — **automated**; the manual checklist this replaces shipped
stamp drift twice:

1. Author the release: make the change in `src/` (+ twins [#3] + monorepo siblings [#1]), write a
   `## <version>` entry in the **root** `CHANGELOG.md` (update the shipped changelog content in
   `src/` too if the notes should reach consumers).
2. Have a **different session** review it and re-run at least one gate and one red-test themselves
   (CLAUDE.md → Maintenance model #2/#3). Keep their command and its observed exit code.
3. Run `pwsh -NoProfile -File .claude/scripts/release.ps1 -Version <v> -Summary "<one line>"
   -ReviewEvidence "reviewer <who>; re-ran <command>; EXIT=<code>; implementer <who>"`.
   It stamps `src/core/CLAUDE.md` + the three `framework-version.json` files, rebuilds all three
   dists, runs every gate (freshness, validate-dist ×3, hook suites ×3, meta suite), **refuses to
   commit on any failure**, appends the review row to `meta/review-ledger.md`, then commits to
   `master`, pushes, **waits for CI**, and tags. Local gates take ~5–7 min; the CI wait adds
   ~7–8 min on recent history. `-NoPush` for a dry-ish run.

   It **refuses to start** without either `-ReviewEvidence` or `-NoIndependentReview`. The latter
   is allowed — sometimes there is no second session — but never silent: it records
   `reviewer: none` in the ledger and auto-files a post-ship review item in `meta/BACKLOG.md`.
4. Append to `LEARNINGS.md` if there's a lesson, and file the RCA (Maintenance model #5).

### The CI watch — a tag means CI-verified green (B-88, WSD-028)

v0.44.0 was released, tagged and reported green while CI went **red on both legs** — as did the three
commits after it. Four consecutive red runs on `master`, unnoticed for over an hour. Every local gate
had passed; the release simply ended before CI had an opinion.

So step 5c runs `.claude/scripts/watch-ci.ps1` between the verified `origin/master` push and the tag,
and **the tag is now the promotion step**:

| CI | outcome |
|---|---|
| green | tagged, `Release X complete`, exit 0 |
| red | **not tagged**, exit 1 — the commit is on master, the tag is withheld |
| unobservable | **not tagged**, exit 3 — CANT-VERIFY is never reported as success |

**Recovering from a red release:** fix the break (a normal commit), then re-run the *same* release
command. Step 5 no longer exits when there is nothing new to stage — it falls through to
push → watch → tag, and every one of those steps is idempotent.

**Prerequisites and escape hatch.** Needs the GitHub CLI, authenticated. `gh` is resolved from `PATH`
and then from the well-known install locations, because on this box `PATH` is the corrupted one and
`Get-Command gh` fails while `gh.exe` is installed — a `PATH` problem and an absent tool are reported
as the different facts they are. `-AllowUnverifiedCi` waives the check and tags anyway; it is a
*waiver*, not a CANT-VERIFY, and it is recorded in the tag's own annotation.

For ordinary non-release work, push through the wrapper so the command itself reports CI's verdict:

```powershell
pwsh -NoProfile -File .claude/scripts/push-and-check.ps1
```

It pushes the current branch, then delegates the CI reading to `watch-ci.ps1`. Watching applies only
to `-WatchedBranches` (default: `master`, kept in sync with `.github/workflows/ci.yml`'s `push`
trigger); a successful push to any other branch reports that watching was skipped and exits 0.

Watch any commit by hand (also how to finish an interrupted release):

```powershell
pwsh -NoProfile -File .claude/scripts/watch-ci.ps1 -Sha <sha>   # 0 green / 1 red / 3 cannot verify
```

**What it does not do:** it does not *prevent* a red commit reaching `master` — releases push
directly to master by decision (B-53: releasing on a branch destroyed v0.34.0's release commit), so a
red release is detected and left untagged, not stopped.

**Cross-leg test evidence (B-70) is a rule, not a watcher.** The watch above tells you *that* CI went
red; it cannot tell you a new test case was ever *reached* on the leg that matters. CI runs the `.ps1`
twin on Windows and the `.sh` twin on Linux, so a case authored on this box is proven on one leg and
assumed on the other — and where your environment cannot execute a leg at all (codex's sandbox has no
working `bash`; Git Bash here needs an absolute PowerShell path), that leg has **no** evidence, not
weak evidence. The Definition of done in `CLAUDE.md` therefore requires any test-carrying change to be
demonstrated *running* on every leg that will execute it, and treats the first green CI run as part of
the change rather than a post-hoc check. Run the bash twin yourself before reviewing such a diff.

**Do not run the gate suites while an implementer session is editing the tree.** A hook suite once
raced a concurrent run's writes and produced a transient failure that cost a diagnosis cycle. The
suites read the working tree directly; they assume it is still.

**Do not pipe a gate, release, or push command into `tail`/`head`/`grep` and then read its exit
code.** A shell pipeline reports the *last* stage's status, so the real exit code is discarded and
every one of these scripts' carefully-designed non-zero contracts (`watch-ci.ps1`'s 0/1/3,
`push-and-check.ps1`'s propagation of it, `release.ps1`'s refusals) silently reads as success.
Observed 2026-08-16: `pwsh -NoProfile -File .claude/scripts/push-and-check.ps1 … | tail -4` was run
from the wrong working directory, so `pwsh` never found the script and exited **64** — but the
pipeline reported **0** and the push was very nearly recorded as done with `master` still unpushed.
Note the second trap stacked on the first: a *relative* script path resolves against the caller's
cwd, and this box routinely has several worktrees plus the parent container repo in play. Invoke
these scripts by absolute path, capture the exit code before filtering (`$LASTEXITCODE`, or assign
the output to a variable and filter afterwards), and treat "the command printed a usage/help dump"
as the signature of a path that did not resolve.

**Launching an implementer session.** The maintenance model requires implementer and reviewer to be
different sessions. The recipe used to date is the `codex` CLI on Windows, with three traps worth
knowing: the session `PATH` can arrive with a literal unexpanded `${PATH}` (so invoke interpreters
by absolute path), the sandbox `PATH` differs from the real environment — which is why a
self-reported before/after has produced a false pass twice (Maintenance model #3) — and its own
"tests now pass" must be re-run by you rather than believed.
**Not re-verified since 2026-07; confirm it still works before relying on it.**
