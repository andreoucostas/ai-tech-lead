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
