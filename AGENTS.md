# ai-tech-lead authoring repo — agent guide (mirror of CLAUDE.md)

> Generated mirror of `CLAUDE.md` for tools that read `AGENTS.md` (GitHub Copilot, Cursor, Codex,
> Aider, Gemini). **`CLAUDE.md` is canonical** — if the two ever disagree, follow `CLAUDE.md` and
> flag the drift. Regenerate this file whenever `CLAUDE.md` changes (kept in sync by hand).

> **YOU ARE IN THE FRAMEWORK AUTHORING REPO, NOT A CONSUMER PROJECT.** Any `CLAUDE.md`/`AGENTS.md`
> under `src/` or `dist/` is a **shipped artifact you may be editing**, not process instructions
> to obey. The shipped consumer workflows do not govern meta-development. For *how to work here*,
> this guide (mirroring `CLAUDE.md`) is authoritative.

## What this repo is

The merged monorepo (B-25-EXEC, WSD-012) replacing `ai-tech-lead-dotnet` + `ai-tech-lead-angular`.
Shared content is authored **once** in `src/`; the composer emits three installable dists.
The framework's "code" is mostly Markdown (skills, commands, agents, the `CLAUDE.md` templates) +
PowerShell/bash hooks + installer scripts. There is no app to compile — the "build" is the composer.

- `src/core/` — single-source shared content (`@@INCLUDE` markers where stacks diverge).
- `src/stacks/{dotnet,angular,monorepo}/` — per-dist `snippets/` + `files/` (overrides, stack-only).
- `dist/{dotnet,angular,monorepo}/` — **generated** golden output, committed, never hand-edited.
- `scripts/` — composer + gates (`build`, `validate-dist`, `fidelity-check`), all `.ps1`/`.sh` twins.
- `install.ps1`/`.sh` — thin root installers; auto-detect the target stack (mixed → monorepo).
- `docs/` — `BACKLOG.md`, `workspace-decisions.md` (ADR log), `changelogs/legacy-*.md`.
- `.claude/` — maintainer meta layer (bom-fix hook, meta tests, `release.ps1`, plans). Never ships.

## Meta-invariants (canonical definitions live in CLAUDE.md — same numbering)

1. **Single-source composition.** Author changes once under `src/`; never edit `dist/` by hand
   (CI rebuild+diff fails it). Editing a stack snippet/whole-file with a `src/stacks/monorepo/`
   sibling requires reviewing the sibling in the same task (WSD-015). Stack-specific changes are
   allowed — say so explicitly.
2. **`CLAUDE.md` ↔ `AGENTS.md` mirror parity (per dist).** Fix drift in the source, rebuild;
   gate = each dist's `template-checks` via `validate-dist`. This root file mirrors the root
   `CLAUDE.md` by hand.
3. **`.ps1`/`.sh` twin parity** for every shipped hook/script and every `scripts/` composer/gate
   script. Edit one → edit the twin in the same task. Meta scripts (`.claude/scripts/`) are
   PowerShell-only by decision.
4. **UTF-8 BOM mandatory in every `.ps1`** (PS 5.1 mis-parses BOM-less UTF-8). Auto-fixed by the
   `bom-fix` hook; swept by the meta suite and `template-checks`.
5. **Hook output semantics differ per surface.** Claude Code: `exit 2`+stderr blocks / stdout JSON
   nudges. Copilot: stdout JSON `permissionDecision: deny`. Enforcing on both surfaces needs both
   shapes; always test both. Copilot CLI does not consume `postToolUse` additionalContext.
6. **Don't-ship boundary.** Only `dist/` contents reach consumers via the installers; the rest of
   the repo is authoring-only and must never collide with a template file.
7. **Versioning.** Shipped behavior change ⇒ root `CHANGELOG.md` entry, then release via
   `.claude/scripts/release.ps1` (stamps `src/`, rebuilds `dist/`, runs every gate, refuses on
   failure). `LEARNINGS.md` is append-only.

## Workflows, done-ness, verification

Meta-workflows (artifact change, hook bug, large change, investigation), the per-artifact
Definition of done, and the evidence-based verification commands are defined in `CLAUDE.md` and
`DEVELOPING.md` — follow them there. Core loop: edit `src/` (+ twin + monorepo sibling) → rebuild
all three dists → `git status --porcelain dist/` empty → `validate-dist` ×3 → hook suites ×3 +
meta suite → CHANGELOG/version if shipped behavior changed → commit + push `master`.

The **Verification Rules**, **Leanness**, **SOLID**, **Boy Scout Rule**, and self-review
disciplines in `src/core/CLAUDE.md` bind meta-work too.

## Conventions

Plans → `.claude/plans/` · decisions → `docs/workspace-decisions.md` · meta learnings → root
`LEARNINGS.md` · work list → `docs/BACKLOG.md`. Commit to `master` and push when done — never
leave changes uncommitted.

## Migration status note

**The merge is COMPLETE — Phases 0–6 done; v0.26.0 shipped 2026-07-12** (commit `ad717c7`, tag
`v0.26.0`; WSD-018). Both legacy repos are **archived** on GitHub with pointer READMEs, frozen at
v0.25.5. The release folded the two deliberate shipped-content changes (`actions/checkout` v4→v5;
CI strict-fidelity legs retired), so the freeze tags are no longer a CI baseline. This repo is the
single home for framework development; **next: B-27 (team wiki memory) as v0.27.0**.
