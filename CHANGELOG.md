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
