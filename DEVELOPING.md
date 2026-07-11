# DEVELOPING — operational runbook

Commands, not philosophy. The rules and the meta-invariant list live in `CLAUDE.md`; this file
**references** them by number and never restates them. Paths assume cwd = the repo root.

## Repo map

| Path | What | Notes |
|------|------|-------|
| `src/core/` | shared single-source content | `@@INCLUDE:NAME@@` markers where stacks diverge |
| `src/stacks/<dist>/snippets/<rel>/<NAME>` | marker content per dist | monorepo snippet wins; else dotnet+angular concat (WSD-015) |
| `src/stacks/<dist>/files/` | whole-file overrides + stack-only files | both-stacks collision without a monorepo override = build error |
| `dist/{dotnet,angular,monorepo}/` | generated golden output (committed) | **never hand-edit** [#1]; `linguist-generated` |
| `scripts/` | composer + gates, `.ps1`/`.sh` twins [#3] | `build`, `validate-dist` |
| `install.ps1` / `install.sh` | root installers | detect stack, auto-detect mixed → monorepo, delegate to dist installer |
| `.claude/hooks/` | meta-dev hook (`bom-fix.ps1`/`.sh` — auto-adds the UTF-8 BOM to written `.ps1`) | this repo only, does not ship |
| `.claude/hooks/_fixtures/` | JSON event fixtures for testing the hooks | see below |
| `.claude/scripts/release.ps1` | release automation [#7] | PowerShell-only by decision |
| `.claude/plans/` | plans [Conventions] | includes the locked B-21/B-22/B-27 design specs |
| `docs/` | `BACKLOG.md`, `workspace-decisions.md`, `changelogs/legacy-*.md` | |

## Compose the dists + freshness [#1]

```powershell
foreach ($d in 'dotnet','angular','monorepo') { pwsh -NoProfile -File scripts/build.ps1 $d }
git status --porcelain dist/   # MUST print nothing — otherwise commit the dist with your src change
```
```bash
for d in dotnet angular monorepo; do bash scripts/build.sh "$d"; done   # .sh twin (CI linux leg)
```

## Validate the dists (markers, JSON, bash -n, PS-AST, per-dist template-checks [#2])

```powershell
foreach ($d in 'dotnet','angular','monorepo') { pwsh -NoProfile -File scripts/validate-dist.ps1 $d; "exit=$LASTEXITCODE" }
```

> **Retired at v0.26.0 (WSD-018):** the migration-era fidelity gate (`scripts/fidelity-check.ps1/.sh`,
> strict byte-compare of `dist/{dotnet,angular}` against this repo's `pre-restructure` tag — the
> content-equal mirror of the legacy repos' Phase-0 `freeze-v0.25.5` baseline) was
> deleted once Phase 6 validation recorded its final 138/138 pass and the release deliberately
> changed shipped content. Ongoing byte-integrity is the freshness gate above (the golden dist is
> committed). The `pre-restructure` tag and the deleted twins remain in git history
> (`git show 'v0.26.0^:scripts/fidelity-check.sh'`) if a migration audit ever needs them.

## Run the hook test suites (automated — closes the "untested hook" gap [#5])

Dependency-free PowerShell harness (**no Pester** — corporate boxes ship only Pester 3.x). Each
test pipes a JSON event to a hook and asserts exit code + output shape; **twin** tests run the
`.ps1` and the `.sh` on the same input and assert the *same decision*.

```powershell
# shipped suites — run against the DIST copies (what ships), one per dist
pwsh -NoProfile -File dist/dotnet/tests/hooks/Invoke-HookTests.ps1
pwsh -NoProfile -File dist/angular/tests/hooks/Invoke-HookTests.ps1
pwsh -NoProfile -File dist/monorepo/tests/hooks/Invoke-HookTests.ps1
# repo meta suite (bom-fix + repo-wide BOM sweep; does NOT ship)
pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1
```

- **Exit code = number of failing tests** (0 = green).
- **`.sh` fidelity:** on Windows the harness drives `.sh` via Git's `bin\bash.exe` wrapper so
  `cat`/`grep`/`jq` resolve; `.sh` tests self-skip when no bash is found (pure-Windows safe).
- **Host:** prefers `pwsh` (7+); falls back to `powershell.exe` [#4 platform].
- **Speed:** slow by design — a process is spawned per hook invocation; a full dist suite takes
  ~1–2 min. Expected, not a hang.

**CI** — `.github/workflows/ci.yml` runs compose→freshness→validate→hook suites on every
push/PR (windows leg rebuilds with the `.ps1` composer, linux leg with the `.sh` twin — composer
twin divergence fails a leg), plus the meta suite.

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

**Phase 6 landed with v0.26.0** (WSD-018): the fidelity baseline was retired and the queued
`actions/checkout` v4→v5 bump folded into the shipped workflows in that release. Shipped-content
changes are no longer frozen — normal release discipline [#7] applies.
