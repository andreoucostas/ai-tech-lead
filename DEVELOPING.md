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

## Validate the dists (markers, JSON, bash -n, PS-AST, per-dist template-checks [#2], no-meta-leak [#6], no-dead-instruction)

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

```bash
sed -i 's|pwsh scripts/install.ps1|pwsh install.ps1|' dist/monorepo/README.md
bash scripts/validate-dist.sh monorepo; echo "exit=$?"   # MUST be 1, naming README.md:14
pwsh -NoProfile -File scripts/build.ps1 monorepo         # restore from src
```

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

## Release process

When shipped behavior changed [#7] — **automated**; the manual checklist this replaces shipped
stamp drift twice:

1. Author the release: make the change in `src/` (+ twins [#3] + monorepo siblings [#1]), write a
   `## <version>` entry in the **root** `CHANGELOG.md` (update the shipped changelog content in
   `src/` too if the notes should reach consumers).
2. Run `pwsh -NoProfile -File .claude/scripts/release.ps1 -Version <v> -Summary "<one line>"`.
   It stamps `src/core/CLAUDE.md` + the three `framework-version.json` files, rebuilds all three
   dists, runs every gate (freshness, validate-dist ×3, hook suites ×3, meta suite), **refuses to
   commit on any failure**, then commits to `master` and pushes. `-NoPush` for a dry-ish run.
3. Append to `LEARNINGS.md` if there's a lesson.

**Until Phase 6 lands** (see CLAUDE.md → Migration status note): shipped content is
fidelity-frozen; the first release is v0.26.0 and must consciously retire/move the CI fidelity
baseline in the same change, and fold in the queued `actions/checkout` v4→v5 bump in the shipped
workflows (`src/core/.github/workflows/`).
