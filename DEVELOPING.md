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
| `scripts/` | PowerShell composer + gates [#3] | `build`, `validate-dist`, `context-footprint`; `fidelity-check` is manual |
| `install.ps1` | root installer | detect stack, auto-detect mixed → monorepo, delegate to dist installer |
| `.claude/hooks/` | meta-dev `bom-fix.ps1` hook | auto-adds the UTF-8 BOM to written `.ps1`; does not ship |
| `.claude/hooks/_fixtures/` | JSON event fixtures for testing the hooks | see below |
| `.claude/scripts/release.ps1` | release automation [#7] | maintainer-only; requires PowerShell 7 |
| `.claude/scripts/watch-ci.ps1` | watches GitHub Actions for a commit; 0 green / 1 red / 3 cannot-verify | used by `release.ps1` step 5c, runnable by hand |
| `.claude/scripts/_ci-decision.ps1` | the publish decision table (tag / exit code) as a callable function | dot-sourced by `release.ps1` and by its tests |
| `.claude/plans/` | plans [Conventions] | includes the locked B-21/B-22/B-27 design specs |
| `meta/` | `BACKLOG.md`, `workspace-decisions.md`, `LEARNINGS.md`, `ci-handover.md`, `changelogs/legacy-*.md` | maintainer layer; never ships. No root `docs/` — that name is the consumer's |
| `scripts/meta-denylist.txt` | the `no-meta-leak` patterns [#6] | one authority, read by `validate-dist.ps1` |

Every framework push goes through the outgoing-commit guard. The push and release wrappers invoke it
before mutation; it checks every not-yet-remote commit subject and every added, changed, or renamed
blob (including merge diffs against every parent):

```powershell
pwsh -NoProfile -File .claude/scripts/check-outgoing-commits.ps1
pwsh -NoProfile -File .claude/scripts/push-and-check.ps1
```

The guard exits 3 if it cannot enumerate the destination remote; it never treats CANT-VERIFY as a
policy failure or success. A direct `git push` remains mechanically possible, so the wrapper is the
maintainer contract rather than server-side enforcement.

### Verify reviewer-side probes before recording green

For an ad hoc review check, use the subject process exit to decide pass/fail and capture it before a
filter or following command can replace it; zero matching `FAIL` lines is not a pass oracle. Prove
every detection filter against both a known positive and a known negative. When the claim is
equality, compare bytes or hashes rather than rendered console text. These are review disciplines,
not authorization to build a checker-of-checkers.

## Compose the dists + freshness [#1]

```powershell
foreach ($d in 'dotnet','angular','monorepo') { pwsh -NoProfile -File scripts/build.ps1 $d }
git status --porcelain dist/   # MUST print nothing — otherwise commit the dist with your src change
```

## Validate the dists (markers, JSON, PS-AST, topology, per-dist template-checks [#2], no-meta-leak [#6], no-dead-instruction, hook-registration, step-references)

```powershell
foreach ($d in 'dotnet','angular','monorepo') { pwsh -NoProfile -File scripts/validate-dist.ps1 $d; "exit=$LASTEXITCODE" }
```

### Red-test the `no-meta-leak` gate [#6]

A gate you have never seen fail is not a gate. Plant a tracking id in a composed dist, confirm the
check names the exact `file:line`, then restore:

```powershell
$p = 'dist/dotnet/README.md'; $before = [IO.File]::ReadAllBytes($p)
try {
  [IO.File]::AppendAllText($p, "`nWSD-999 planted`n", [Text.UTF8Encoding]::new($false))
  pwsh -NoProfile -File scripts/validate-dist.ps1 dotnet # MUST exit 1 and name README.md + pattern
} finally { [IO.File]::WriteAllBytes($p, $before) }
pwsh -NoProfile -File scripts/validate-dist.ps1 dotnet   # back to 0
```

### Red-test the `no-dead-instruction` gate (check 7)

Check 6 proves shipped docs don't say the wrong *words*. Check 7 proves they don't give the wrong
*commands*: every framework script path in a shipped `.md` must exist, **resolved from the dist
root** (the framework documents every command as run from the repo root). `CHANGELOG.md` is skipped
— release notes quote commands that *were* wrong in order to say they're fixed.

The extractor deliberately still recognizes retired `bash … .sh` commands. That is a diagnostic
contract for protected consumer files, not a supported execution path.

It also reports scanned-document and inline-reference counts. Zero docs or zero extracted references
is a failure. Absolute paths in docs remain out-of-scope placeholder examples (and are listed); this
is deliberately unlike hook registrations. `ValidateDist.Tests.ps1` is the executable version of
these red-test recipes.

```powershell
$p = 'dist/monorepo/README.md'; $before = [IO.File]::ReadAllBytes($p)
try {
  $valid = 'pwsh -NoProfile -File scripts/' + 'install.ps1'
  $invalid = 'pwsh -NoProfile -File ' + 'install.ps1'
  $text = [IO.File]::ReadAllText($p).Replace($valid, $invalid)
  [IO.File]::WriteAllText($p, $text, [Text.UTF8Encoding]::new($false))
  pwsh -NoProfile -File scripts/validate-dist.ps1 monorepo # MUST exit 1, naming README.md
} finally { [IO.File]::WriteAllBytes($p, $before) }
```

### Red-test the `hook-registration` gate (check 8)

Check 7 covers commands a shipped **doc** gives a human. Check 8 covers wiring the **host** acts on.
Each dist must contain exactly 18 registrations: six Claude PowerShell 7 commands in
`.claude/settings.json`, six Windows PowerShell 5.1 commands in `.claude/settings.windows.json`, and
six Copilot `powershell` commands explicitly invoking `pwsh`. Every registration is relative,
case-exact, uses `-NoProfile -File`, resolves to a `.ps1`, and has the expected host selector.

```powershell
$parent = Join-Path ([IO.Path]::GetTempPath()) ('atl-validate-' + [guid]::NewGuid().ToString('N'))
$copyRoot = Join-Path $parent 'dc'; New-Item -ItemType Directory $copyRoot | Out-Null
try {
  Copy-Item dist/dotnet (Join-Path $copyRoot 'dotnet') -Recurse
  Remove-Item (Join-Path $copyRoot 'dotnet/.claude/hooks/audit-trail.ps1')
  pwsh -NoProfile -File scripts/validate-dist.ps1 dotnet $copyRoot # MUST exit 1
} finally { Remove-Item -LiteralPath $parent -Recurse -Force }
```

### Red-test the `step-references` gate (check 12)

Check 12 scans top-level ordered-list labels and numbered prose step references in shipped skills,
commands and agents. It blanks fenced code before both scans, accepts runs starting at `0.` or `1.`,
and resolves each prose reference against a list label or `Step N` heading in the same file.

```powershell
$parent = Join-Path ([IO.Path]::GetTempPath()) ('atl-steps-' + [guid]::NewGuid().ToString('N'))
$copyRoot = Join-Path $parent 'dc'; New-Item -ItemType Directory $copyRoot | Out-Null
try {
  Copy-Item dist/dotnet (Join-Path $copyRoot 'dotnet') -Recurse
  Add-Content (Join-Path $copyRoot 'dotnet/.claude/skills/create-adr/SKILL.md') "`n1. first`n3. planted`nSee step 1."
  pwsh -NoProfile -File scripts/validate-dist.ps1 dotnet $copyRoot -Check step-references # MUST exit 1
} finally { Remove-Item -LiteralPath $parent -Recurse -Force }
```

One narrowing argument exists for focused diagnostics and is never used by `release.ps1` or CI:

| Switch | Effect |
|---|---|
| `--content-only` | Skip checks 1–5 and run only 6, 7, 8 and 12. It prints a `NOTE:` so a partial run cannot resemble a full run. The suite's green anchors deliberately omit it. |

A registration naming a missing script is a hook that silently never runs. Check 8 deliberately
does not reject a bare interpreter name as a generic rule; it instead enforces the exact supported
host on each known registration surface.

This is the gate that would have caught the v0.26.3 defect: `dist/monorepo`'s README told installing
agents to run `pwsh install.ps1`, which exists nowhere in that dist. If you add a pattern to
`scripts/meta-denylist.txt`, red-test it and prefer a narrow `ALLOW <path-substring>` over weakening
a `DENY` when a legitimate consumer-facing word trips the check.

## Fidelity vs the frozen v0.25.5 baseline (manual re-audit only — no longer a CI gate)

Strict EOL-normalized byte-compare of `dist/{dotnet,angular}` against the Phase-0 freeze tags
(materialized from history — needs full clone depth). **Retired from CI at the v0.26.0 release**,
which deliberately changed shipped content; the freeze tags are no longer a live baseline. The
script remains for a manual re-audit against the `pre-restructure` tag (see CLAUDE.md → Migration
status note). `dist/monorepo` never had a baseline (new capability).

```powershell
pwsh -NoProfile -File scripts/fidelity-check.ps1 dotnet
pwsh -NoProfile -File scripts/fidelity-check.ps1 angular
```

## Run the hook test suites (automated — closes the "untested hook" gap [#5])

Dependency-free PowerShell harness (**no Pester** — corporate boxes ship only Pester 3.x). Each
test pipes a JSON event to a hook and asserts exit code + output shape. Aggregate runners reuse the
current process executable, so a suite launched under Windows PowerShell 5.1 cannot silently relaunch
its children under PowerShell 7.

```powershell
# shipped suites — run against the DIST copies (what ships), one per dist
pwsh -NoProfile -File dist/dotnet/tests/hooks/Invoke-HookTests.ps1
pwsh -NoProfile -File dist/angular/tests/hooks/Invoke-HookTests.ps1
pwsh -NoProfile -File dist/monorepo/tests/hooks/Invoke-HookTests.ps1
# repo meta suite (bom-fix, BOM sweep, + the two behavioral gates below; does NOT ship)
pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1
```

### The behavioral gates (meta suite — auto-discovered, no wiring needed)

Everything else in this repo is a **parser** gate: it proves the artifacts are well-formed, not that
they *work*. The product is prose aimed at a model, and three defects shipped straight through the
parser gates (v0.26.3). These two cover what a parser cannot. Drop a new `*.Tests.ps1` into
`.claude/hooks/tests/` and the runner picks it up.

| Gate | What it drives | The defect class it exists to catch |
|------|----------------|--------------------------------------|
| `InstallerContract.Tests.ps1` | **Runs the shipped PowerShell installer** for all three dists in greenfield and brownfield modes and asserts its **stdout** states the whole agent contract (commit the files; task NOT complete until handoff; don't hand-replicate `/bootstrap`\|`/adopt`; `docs-sync-check` is red by design). | A mode branch that quietly stops printing part of the contract. Greenfield had drifted weaker than brownfield and a real agent duly copied files and walked away without committing them. |
| `DocTruth.Tests.ps1` | The **authoring** docs vs the repo that exists: one version stamp everywhere, README's claimed version == what's shipped, no phantom marker syntax, every `scripts/…` path in a root doc resolves, every script `ci.yml` invokes exists. | Docs that lie to the *maintainer* — which is how the next defect gets authored. A marker syntax that the composer has never implemented was documented in four files at once. |

Red-test them the same way as any gate — plant the defect, watch it fail, restore:

```powershell
# InstallerContract: regress greenfield to its pre-v0.26.3 wording
$p = 'dist/dotnet/scripts/install.ps1'; $before = [IO.File]::ReadAllBytes($p)
try {
  $text = [IO.File]::ReadAllText($p).Replace('Do not attempt /bootstrap yourself or replicate it by hand.','Do not attempt /bootstrap yourself.')
  [IO.File]::WriteAllText($p, $text, [Text.UTF8Encoding]::new($true))
  pwsh -NoProfile -File .claude/hooks/tests/InstallerContract.Tests.ps1 # MUST fail dotnet/greenfield
} finally { [IO.File]::WriteAllBytes($p, $before) }
```

**What is still not covered by a gate:** whether the prose actually *steers* a model — that needs a
real agent driven end-to-end and API/subscription spend, so it is deliberately not wired into any
of the suites above. B-41's live harness below closes the evidence gap for the Claude host (not
the gate gap, and not yet the Copilot host — see `meta/BACKLOG.md`): it is maintainer-triggered,
not automatic, and its results are a trend log, not a pass/fail release condition.

- **Exit code = number of failing tests** (0 = green).
- **Host:** the aggregate runner preserves the host that launched it. Run it directly under both
  `pwsh` 7 and `powershell.exe` 5.1; each child prints and asserts its major version and the two
  runs must report equal, non-zero case counts.

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
> **When PowerShell 7 launches Windows PowerShell 5.1 through an intermediate `cmd.exe`, remove
> `PSModulePath` from that child environment.** PowerShell 7 corrects module paths when it starts
> `powershell.exe` directly, but the intermediate process inherits and forwards PowerShell 7's
> module roots. Windows PowerShell can then select incompatible modules and report built-in commands
> such as `Get-FileHash` as missing. This is a broken launcher, not product or test evidence.
> Microsoft documents the boundary and remedy in
> [`about_PSModulePath`](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_psmodulepath).
> For the required legacy-host hostile-code-page run, use this shape (substitute the focused suite):
>
> ```powershell
> cmd.exe /d /c "set PSModulePath=&& chcp 437 >nul && powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude\hooks\tests\<Suite>.Tests.ps1"
> ```
>
> Do not “fix” a resulting false red by hardening one command inside the subject. An unnormalised
> process can break any module-backed cmdlet and would leave the rest of that run untrustworthy.

| Tool | Absolute path |
|---|---|
| Claude Code | `$env:USERPROFILE\.local\bin\claude.exe` |
| Copilot CLI | `$env:APPDATA\npm\copilot.cmd` |
| GitHub CLI | `C:\Program Files\GitHub CLI\gh.exe` |
| pwsh 7 | `C:\Program Files\PowerShell\7\pwsh.exe` |
| node | `C:\Program Files\nodejs\node.exe` |

Each fails differently and none of the errors names `PATH`, which is why this table exists:

- `claude` → the harness's own `claude CLI is not installed or not on PATH` (accurate, but reads as
  "install it").
- **`copilot` → `'"node"' is not recognized`** — the npm shim shells out to `node`, so Copilot looks
  broken when the real gap is `C:\Program Files\nodejs`. Prepend **both** the nodejs directory and
  the npm directory before invoking Copilot.

### The live agent-behavior harness (B-41 — maintainer-triggered, spends budget, not a gate)

`.claude/evals/run-agent-evals.ps1` drives the installed `claude` CLI through fixture scenarios in
disposable temp repos and grades **typed, observable** evidence — matched `tool_use`/`tool_result`
events, git state, file bytes — never transcript prose alone. It never runs in CI and never gates
a release; see the locked design in `.claude/plans/2026-07-17-b41-agent-behavior-harness-design.md`
and results in `meta/eval-results.md`.

The agent-eval harness requires PowerShell 7. The repository-level obligation to run a
representative suite under both PowerShell hosts and a hostile code page still applies; use
`.claude/hooks/tests/ReleaseCiWatch.Tests.ps1 -SelfTest` for that cross-host leg. The canonical
agent-eval recurrence wrapper below also verifies that Windows PowerShell 5.1 fails immediately at
the declared version boundary rather than later at an unsupported encoding operation.

```powershell
# free, no network — proves the harness's own typed-evidence grading on synthetic/adversarial
# fixtures (malformed streams, keyword echoes, developer checkpoints, inverted tool-result
# semantics, ...). Evals are deliberately a separate suite from hooks, so run their canonical
# recurrence wrapper (release.ps1 runs this same command):
pwsh -NoProfile -File .claude/evals/tests/AgentEvals.Tests.ps1

# spends real budget — requires dist/ to match the checked-out release (version == root
# CHANGELOG head) with no local diff
pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -Live [-Scenario route-fix] [-Model sonnet]
```

`release.ps1` runs `-SelfTest` as a deterministic gate and, only after a successful release commit
(and push), offers an interactive prompt for an optional `-Live` run — never a hard fail — and
persists its evidence in a follow-up commit.
- **Speed:** slow by design — a process is spawned per hook invocation; a full dist suite takes
  ~1–2 min. Expected, not a hang.

**CI** — `.github/workflows/ci.yml` runs compose→freshness→validate→hook suites on every push/PR.
The required topology is eight native Windows contexts: `windows`, three `windows-hooks` matrix
contexts, `windows-ps51`, and three `windows-hooks-ps51` matrix contexts. Fidelity is not a CI step.

Manual one-off (debugging a single hook) — pipe a fixture straight in:

```powershell
(Get-Content .claude/hooks/_fixtures/write-bomless-ps1.json -Raw) | pwsh -NoProfile -File .claude/hooks/bom-fix.ps1
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
Also sweep agent-authored artifacts for tool-syntax leakage before committing:
`rg -n '</content>|</invoke>' src`.

## Install smoke test [Definition of done]

```powershell
$target = Join-Path ([IO.Path]::GetTempPath()) ('atl-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $target | Out-Null
[IO.File]::WriteAllText((Join-Path $target 'Smoke.csproj'), '<Project />', [Text.UTF8Encoding]::new($false))
pwsh -NoProfile -File install.ps1 $target                         # root auto-detects dotnet
pwsh -NoProfile -File dist/dotnet/scripts/install.ps1 $target     # or invoke a dist installer
# brownfield: pre-seed a colliding file, then install into the same kind of dir
# monorepo detection: combine .NET with Angular evidence (angular.json, exact-case "@angular/core" JSON property,
# or Angular Nx/project evidence), or combine Angular evidence with >=2 warehouse signal categories
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
failure, so a manual pre-pass mostly duplicates it while being more exposed to this exact race. The
independent reviewer still records the frozen contract/range, reviewer model, no implementation
participation, blind-first threat model, one release-specific hostile case or mutation observed red,
the clean rerun, environment, and gaps for `-ReviewEvidence`.

## Release process

When shipped behavior changed [#7] — **automated**; the manual checklist this replaces shipped
stamp drift twice:

1. Author the release: make the change in `src/` (+ monorepo siblings [#1]), write a
   `## <version>` entry in the **root** `CHANGELOG.md` (update the shipped changelog content in
   `src/` too if the notes should reach consumers).
2. Have a reviewer who did not participate in implementation use a **separate session**. Starting
   from the frozen contract and immutable range before the implementation narrative, record their
   model/agent, blind-first threat model, one release-specific hostile case or mutation observed
   red, the clean rerun, environment, and gaps (CLAUDE.md → Maintenance model #2/#3). Add an
   orthogonal reviewer or execution vantage for data-loss, security-bypass, or false-green changes.
3. From PowerShell 7, run `pwsh -NoProfile -File .claude/scripts/release.ps1 -Version <v> -Summary "<one line>"
   -ReviewEvidence "contract <path/hash>; range <commits>; reviewer <agent/model>; independence
   <no implementation participation; blind-first>; hostile <case> RED; clean <command> EXIT=0;
   environment/gaps <facts>; implementer <who>"`.
   It stamps `src/core/CLAUDE.md` + the three `framework-version.json` files, rebuilds all three
    dists, runs local gates (freshness, validate-dist ×3 plus the footprint update, and the full
    root meta suite on its default throttled runner), **refuses to commit on any failure**, appends
    the review row to `meta/review-ledger.md`, then commits to `master`, pushes, **waits for CI**,
    and tags. A normal tag requires all eight Windows CI contexts, including direct PowerShell 7
    and Windows PowerShell 5.1 runs. `-NoPush` provides a dry-ish run.

   It **refuses to start** without either `-ReviewEvidence` or `-NoIndependentReview`. The latter
   is allowed — sometimes qualifying evidence is unavailable — but never silent: it records
   `review evidence: none supplied` in the ledger and auto-files a post-ship review item in
   `meta/BACKLOG.md`. The switch keeps its legacy name; absence of supplied evidence does not prove
   that no review occurred.
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

**Cross-host test evidence (B-70) is a rule, not a watcher.** The watch tells you *that* CI went red;
it cannot tell you a new case was reached under both PowerShell hosts. Any test-carrying change must
be observed under native PowerShell 7 and native Windows PowerShell 5.1 with equal, non-zero case
counts. The aggregate runners preserve their caller executable; a 5.1 run may not delegate to 7.

**Do not run the gate suites while an implementer session is editing the tree.** A hook suite once
raced a concurrent run's writes and produced a transient failure that cost a diagnosis cycle. The
suites read the working tree directly; they assume it is still.

**Do not pipe a gate, release, or push command into an output filter and then read its exit
code.** A pipeline reports the *last* stage's status, so the real exit code is discarded and
every one of these scripts' carefully-designed non-zero contracts (`watch-ci.ps1`'s 0/1/3,
`push-and-check.ps1`'s propagation of it, `release.ps1`'s refusals) silently reads as success.
Observed 2026-08-16: a push wrapper was piped into a last-lines filter and run
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
