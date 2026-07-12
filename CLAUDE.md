# ai-tech-lead authoring repo — how to develop the framework

> **YOU ARE IN THE FRAMEWORK AUTHORING REPO, NOT A CONSUMER PROJECT.**
> Any `CLAUDE.md` / `AGENTS.md` under `src/` or `dist/` is a **shipped artifact you may be
> editing** — it is *not* a set of process instructions to obey. The 7 consumer workflows
> (Feature/Fix/Refactor/…) those artifacts describe govern how a *consumer* builds an app; they
> do **not** govern meta-development. For *how to work here*, **this file is authoritative**; an
> artifact `CLAUDE.md` only describes the artifact under your cursor. (Claude Code loads
> `CLAUDE.md` up the tree, so when you edit inside `src/core/` both files can load at once —
> this banner is the tie-breaker.)

This file is the **single source of truth** for developing the framework. It stands on its own:
every rule that matters is written here in full — nothing resolves to private `~/.claude` memory.
If every hook were disabled, this file alone would still fully govern the work.

---

## What this repo is

`ai-tech-lead` is the merged monorepo (B-25-EXEC, WSD-012) that replaced the two legacy template
repos (`ai-tech-lead-dotnet`, `ai-tech-lead-angular`). Shared content is authored **once** in
`src/`; a deterministic composer emits three installable distributions in `dist/`.

| Path | What it is |
|------|-----------|
| `src/core/` | Single-source shared content (the former 128 common files, with `@@INCLUDE` markers where stacks diverge). |
| `src/stacks/{dotnet,angular,monorepo}/` | Per-dist `snippets/` (marker content) and `files/` (whole-file overrides + stack-only files). |
| `dist/{dotnet,angular,monorepo}/` | **Generated** golden output, committed, `linguist-generated`. Never hand-edit — CI rebuilds and diffs. |
| `scripts/` | Composer + gates, all `.ps1`/`.sh` twins: `build`, `validate-dist`, `fidelity-check`. |
| `install.ps1` / `install.sh` | Thin root installers: detect the target's stack (auto-detects mixed → monorepo) and delegate to the chosen dist's installer. |
| `docs/` | Maintainer docs: `BACKLOG.md`, `workspace-decisions.md` (ADR log), `changelogs/legacy-*.md`. |
| `.claude/` | Maintainer meta layer: `bom-fix` hook + meta test suite, `release.ps1`, plans. Never ships. |

The framework's "code" is mostly Markdown (skills, commands, agents, the `CLAUDE.md` templates) +
PowerShell/bash hook scripts + installer scripts. There is no application to compile — the
"build" is the composer.

---

## Meta-invariants (canonical list — referenced everywhere, restated nowhere)

These are the things framework-dev requires that ordinary app-dev does not. **This is the only
place they are defined**; `DEVELOPING.md` and the hooks reference these numbers. (Numbering is
kept stable from the pre-merge workspace; #1 was retargeted by the merge per WSD-012 D7.)

1. **Single-source composition (was: dual-repo lockstep).** Behavioral changes are authored
   **once** under `src/` and reach consumers only through the composer. Never edit `dist/` by
   hand — CI's rebuild+diff freshness gate fails the push. Two disciplines this implies:
   - **Monorepo-sibling review (WSD-015):** editing a stack snippet or stack whole-file that has
     a `src/stacks/monorepo/` sibling does *not* reach `dist/monorepo` — review and update the
     sibling in the same task. Core edits, one-sided snippets, and the 5 concat-derived markers
     flow to all three dists automatically.
   - **Stack-specific changes** (a .NET-only skill, an Angular-only skill) live under that
     stack's `files/` or one-sided snippets — and when you make one, say so explicitly.
2. **`CLAUDE.md` ↔ `AGENTS.md` mirror parity (per dist).** The shipped `CLAUDE.md` is canonical;
   `AGENTS.md` is its generated mirror. Both are composed from `src/`, so fix mirror drift **in
   the source snippets/files**, then rebuild. The deterministic gate is each dist's
   `scripts/template-checks.ps1/.sh` (verbatim section diff + version stamps), run per dist by
   `validate-dist` and by CI. This repo's own root `CLAUDE.md` (this file) has a hand-maintained
   `AGENTS.md` mirror — regenerate it when you edit this file.
3. **`.ps1` / `.sh` twin parity.** Every **shipped** hook/script, and every composer/gate script
   in `scripts/`, exists as both a PowerShell and a bash file with identical behavior. Edit one →
   edit the twin in the same task. CI proves composer twin parity by rebuilding with `.ps1` on
   the windows leg and `.sh` on the linux leg against the same committed dist. Meta *scripts*
   (`.claude/scripts/`) are PowerShell-only by decision — they run only on the maintainer's
   Windows box (see `docs/workspace-decisions.md`).
4. **UTF-8 BOM mandatory in every `.ps1`.** Windows PowerShell 5.1 mis-parses BOM-less UTF-8.
   This is binary and auto-fixed by the `bom-fix` hook (scoped to this repo) — but if you
   hand-create a `.ps1` outside the hook's reach, add the BOM yourself. The meta test suite and
   each dist's `template-checks` both sweep for it.
5. **Hook output semantics differ per surface.** Claude Code: `exit 2` + stderr to **block**, or
   stdout JSON `hookSpecificOutput.additionalContext` for a soft nudge / `{decision:block,reason}`
   on Stop. Copilot (CLI + VS Code): stdout JSON `permissionDecision: deny` to block. A hook that
   must enforce on both surfaces has to emit **both** shapes. Always test both. (Live-verified
   2026-07-04: Copilot CLI does **not** consume `postToolUse` additionalContext.)
6. **Don't-ship boundary.** Only `dist/` contents reach consumers, via the dist installers (the
   root installers just delegate). Everything else — root `README`/`CHANGELOG`/`docs/`/`.claude/`/
   `scripts/`/`src/` — is authoring-repo-only and must never be copied by an installer or collide
   with a template file. The `.template-repo` marker inside each dist disables consumer CI for
   the template itself.
7. **Versioning.** When *shipped* behavior changes: write an entry in the **root** `CHANGELOG.md`,
   update the shipped changelog content in `src/` if the release notes should reach consumers,
   then release via `.claude/scripts/release.ps1` — it stamps `src/core/CLAUDE.md` + the three
   `framework-version.json` files, rebuilds `dist/`, runs every gate, and refuses to commit on
   failure. `LEARNINGS.md` is append-only. (Manual stamping shipped drift twice; don't go back
   to it.)

---

## How to approach a change (meta-workflows)

These replace the shipped consumer workflows for meta-work.

- **Artifact change** (skill / command / agent / hook / `CLAUDE.md` template):
  edit `src/core` — or the stack snippet/file *plus its monorepo sibling* [#1] → sync
  `.ps1`/`.sh` twins [#3] → rebuild all three dists and check freshness → `validate-dist` ×3
  (covers the AGENTS.md mirror [#2]) → bump version + CHANGELOG + LEARNINGS if shipped behavior
  changed [#7] → verify (see Definition of done) → commit + push.
- **Hook / script bug:** reproduce by piping a crafted JSON fixture to the hook (see
  `DEVELOPING.md` → "Run/test a hook") → fix in `src/` → re-run the fixture to confirm → twin +
  monorepo sibling → rebuild → verify on **both** surfaces [#5].
- **New version / large change:** plan first; persist the plan to `.claude/plans/`. For
  high-stakes plans, run an adversarial/critique pass before editing. Gate before touching code.
- **Investigation / design:** write no code; weigh ≥2 approaches with trade-offs; record the
  outcome in `docs/workspace-decisions.md` (see Conventions).

## Definition of done per artifact type

This is what replaces "write a failing test first" when the artifact has no xUnit. Do not
fabricate a test, and do not skip verification — pick the right evidence for the artifact:

- **Hook / shell script** — parses (PS parser / `bash -n`) **and** behavior is demonstrated by
  piping a JSON fixture and observing `EXIT=` + stdout/stderr on **both** surfaces [#5]. Show it.
  Test against the **dist** copy (what ships), not just the src fragment.
- **Skill / command / agent / template (Markdown)** — renders the intended instruction in every
  dist that carries it (check `dist/monorepo` when a sibling was involved [#1]), and
  `validate-dist` passes ×3. "Test" = an install smoke run into a temp dir, not a unit test.
- **Installer / sync script** — greenfield **and** brownfield smoke install into temp dirs both
  succeed with the expected file layout; for the root installer, all three detection paths.
- **Composer / gate script** — red-test it: plant the defect class it exists to catch and show
  the non-zero exit, then the clean pass.

## Verification (evidence-based — name the command, show the result)

Never claim "it works." Show the command and its observed output. Standard commands:

- **Compose + freshness:** `pwsh -NoProfile -File scripts/build.ps1 <dist>` ×3, then
  `git status --porcelain dist/` must be empty.
- **Dist validity:** `pwsh -NoProfile -File scripts/validate-dist.ps1 <dist>` ×3 (markers, JSON,
  `bash -n`, PS-AST, per-dist `template-checks`).
- **Hook suites:** `pwsh -NoProfile -File dist/<d>/tests/hooks/Invoke-HookTests.ps1` ×3; meta
  suite `.claude/hooks/tests/Invoke-HookTests.ps1`.
- **Hook behavior:** pipe a fixture JSON event to the hook; assert `EXIT=` + output.
- **Install smoke:** run `install.sh`/`.ps1` into temp greenfield + brownfield dirs.
- **PS syntax / BOM:** parser sweep + BOM sweep (recipes in `DEVELOPING.md`).

Full command recipes live in `DEVELOPING.md`.

---

## Inherited disciplines (they apply to meta-work too)

The **Verification Rules**, **Leanness**, **SOLID**, **Boy Scout Rule**, and the self-review /
documentation-drift discipline defined canonically in `src/core/CLAUDE.md` apply here as well —
don't duplicate them, read them there. In particular for meta-work: Leanness #1 (don't create
files unless required), evidence-based self-review (§5), and "state uncertainty" all bind every
change you make to the framework.

## Commit & push policy (stated in full — not by reference)

When a task is done: **commit to `master` and push.** Never leave changes uncommitted for the
user. Generated `dist/` changes belong in the same commit as the `src/` change that caused them
(CI enforces freshness).

## Conventions

- **Plans** → `.claude/plans/`.
- **Framework-level decisions** → `docs/workspace-decisions.md` (lightweight ADR log: the merge,
  mirror strategy, hook semantics, composition rules).
- **Meta-dev learnings** → root `LEARNINGS.md` (distinct from the shipped `src/core/LEARNINGS.md`).
- **Work list** → `docs/BACKLOG.md` (self-contained entries; move finished ones to its Done section).

## Migration status note

**The merge is COMPLETE. `MERGE-MIGRATION-PLAN.md` Phases 0–6 are all done; v0.26.0 shipped
2026-07-12** (commit `ad717c7`, tag `v0.26.0`; WSD-018). Both legacy repos (`ai-tech-lead-dotnet`,
`ai-tech-lead-angular`) are **archived** on GitHub with pointer READMEs, frozen at v0.25.5. The
v0.26.0 release folded the two deliberate shipped-content changes — `actions/checkout` v4→v5 in the
shipped workflows and retirement of the CI strict-fidelity legs — so the freeze tags are no longer a
baseline; `scripts/fidelity-check.{ps1,sh}` remain for manual re-audit against the `pre-restructure`
tag but are no longer wired to CI. This repo is now the single home for framework development.
**Next framework work: B-27 (team wiki memory) as v0.27.0** (`docs/BACKLOG.md`). The old
workspace-root repo one level up now holds only a pointer stub and the (now-executed) migration plan.
