# ai-tech-lead — Changelog

> This file starts at the merge (v0.26.0). Earlier framework history — everything before
> `ai-tech-lead-dotnet` and `ai-tech-lead-angular` combined into this repo — lives in the two
> preserved legacy changelogs: [`docs/changelogs/legacy-dotnet.md`](docs/changelogs/legacy-dotnet.md)
> and [`docs/changelogs/legacy-angular.md`](docs/changelogs/legacy-angular.md).

## 0.26.0 — 2026-07-11

> The single biggest structural change in the framework's history: two independently-versioned
> template repos (`ai-tech-lead-dotnet`, `ai-tech-lead-angular`) become one authoring repo,
> `ai-tech-lead`, that composes three installable distributions. The decision, rationale, and
> execution record live in `docs/workspace-decisions.md` (WSD-012 and its Phase 0–5 execution
> deltas, plus WSD-015, WSD-016, and WSD-018 — the Phase 6 completion record); this entry is the
> consumer-facing summary. Phase 6 validation ran the full gate matrix green — including a final
> fidelity pass, 138/138 byte-match per legacy stack — before this release deliberately changed
> shipped content. The legacy repos freeze at v0.25.5 and are archived with pointers here as
> this release publishes.

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
- **Zero-behaviour-change migration, proven by a strict fidelity gate.** Every one of the 138
  tracked files in each legacy repo (dotnet, Angular) reproduced byte-for-byte (EOL-normalized)
  from the new `src/` composition — `scripts/fidelity-check.ps1/.sh` diffed the rebuilt
  `dist/dotnet` and `dist/angular` against the `freeze-v0.25.5` tags taken on both legacy repos
  before any restructuring began, with an **empty allowlist** (no version-stamp or
  stack-flavoured exclusions needed). This was the migration's central acceptance criterion, and
  it held from Phase 2 through the final Phase 6 validation run: a consumer already running
  v0.25.5 of either template gets an update, not a behavior change, when they move to a dist
  built from this repo — apart from the one deliberate change below.
- **Shipped workflows: `actions/checkout` v4 → v5** in `template-ci.yml` and
  `docs-sync-check.yml` (all three dists, composed from `src/core/.github/workflows/`) —
  GitHub's Node 20 deprecation. Queued since 2026-07-09 behind the fidelity freeze; folded into
  this release as planned (the only shipped-content change relative to v0.25.5).
- **The workspace meta-development layer moved into this repo (D7, WSD-016).** The maintainer
  workflow for developing the framework itself — previously governed by a separate, untracked
  workspace root one level up — now lives here: root `CLAUDE.md`/`AGENTS.md`/`DEVELOPING.md`
  (rewritten for single-repo composition instead of dual-repo lockstep), the `bom-fix` hook +
  its meta test suite, `docs/BACKLOG.md` and `docs/workspace-decisions.md` (this repo's ADR
  log), and the maintainer's `.claude/plans/`. The two-repo-specific `check-lockstep.ps1` gate is
  retired — its job is now structural (one source, three composed dists) rather than a
  cross-repo diff.

### Removed
- **The migration-era fidelity gate is retired** (WSD-018): the CI fidelity legs and the
  `scripts/fidelity-check.ps1/.sh` twins are deleted, after Phase 6 validation recorded their
  final pass (138/138, both stacks) and this release deliberately changed shipped content.
  Ongoing byte-integrity is the golden-dist freshness gate — `dist/` is committed and CI fails
  any rebuild diff. The `pre-restructure` tag and the deleted twins remain in git history.

### Notes
- Phase 6 of `MERGE-MIGRATION-PLAN.md` completes with this release: validation green (full gate
  matrix + final fidelity pass) in this commit; publishing it archives the two legacy repos —
  `ai-tech-lead-dotnet` and `ai-tech-lead-angular` — at v0.25.5 with pointers to this repo and
  pushes the `v0.26.0` tag (the maintainer publish steps recorded in WSD-018).
- Legacy framework history predating the merge: [`docs/changelogs/legacy-dotnet.md`](docs/changelogs/legacy-dotnet.md),
  [`docs/changelogs/legacy-angular.md`](docs/changelogs/legacy-angular.md).

---

## How to update this changelog

- One section per release (or per "Unreleased" working window). Date the heading once released.
- Group entries by **Added / Changed / Fixed / Removed / Decided**.
- One line per change. Reference the file or workflow touched, not the implementation detail.
- Framework-level decisions (the merge, composition rules, hook semantics) go in
  `docs/workspace-decisions.md`; this file is the consumer-facing summary of what shipped.
