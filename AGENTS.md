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

- `src/core/` — single-source shared content (`<!-- @stack:NAME -->` markers where stacks diverge).
- `src/stacks/{dotnet,angular,monorepo}/` — per-dist `snippets/` + `files/` (overrides, stack-only).
- `dist/{dotnet,angular,monorepo}/` — **generated** golden output, committed, never hand-edited.
- `scripts/` — composer + gates (`build`, `validate-dist`, `fidelity-check`), all `.ps1`/`.sh` twins.
- `install.ps1`/`.sh` — thin root installers; auto-detect the target stack (mixed → monorepo).
- `meta/` — maintainer layer: `BACKLOG.md`, `workspace-decisions.md` (ADR log), `LEARNINGS.md`
  (meta-dev log), `ci-handover.md`, `changelogs/legacy-*.md`. Never ships.
- `.claude/` — maintainer Claude Code config (bom-fix hook, meta tests, `release.ps1`, plans). Never ships.

There is deliberately **no root `docs/`** — that name belongs to the consumer (`dist/*/docs/`).
Root `CLAUDE.md`/`AGENTS.md` still collide by name with their shipped counterparts because Claude
Code must load them from the root; the banner above is the tie-breaker.

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
6. **Don't-ship boundary — a machine check, not a promise.** Only `dist/` contents reach consumers
   via the installers; the rest of the repo is authoring-only and must never collide with a template
   file. Enforced by `validate-dist` check 6 (`no-meta-leak`): each composed dist is scanned against
   `scripts/meta-denylist.txt`, so our development vocabulary (tracking ids `B-nn`/`WSD-nnn`,
   "lockstep", the two-repo past, maintainer-only tooling) cannot appear in a shipped file. One
   denylist file, read by both twins. If a legitimate consumer word trips it, add a narrow `ALLOW` —
   never weaken a `DENY`. Check 6 guards what shipped docs must not *say*; **check 7
   (`no-dead-instruction`)** guards that the commands they *give* actually resolve — every script a
   shipped doc tells someone to run must exist, resolved from the dist root.
7. **Versioning.** Shipped behavior change ⇒ root `CHANGELOG.md` entry, then release via
   `.claude/scripts/release.ps1` (stamps `src/`, rebuilds `dist/`, runs every gate, refuses on
   failure). `meta/LEARNINGS.md` is append-only. Write the **shipped** changelog in the consumer's
   voice; tracking ids and maintainer asides belong in the root `CHANGELOG.md`, which is *our* log.

## Workflows, done-ness, verification

Meta-workflows (artifact change, hook bug, large change, investigation), the per-artifact
Definition of done, and the evidence-based verification commands are defined in `CLAUDE.md` and
`DEVELOPING.md` — follow them there. Core loop: edit `src/` (+ twin + monorepo sibling) → rebuild
all three dists → `git status --porcelain dist/` empty → `validate-dist` ×3 → hook suites ×3 +
meta suite → CHANGELOG/version if shipped behavior changed → commit + push `master`.

Every gate above is a *parser* gate — it proves the artifacts are well-formed, not that they
work. The product is prose aimed at a model, so two gates in the meta suite cover the behavioral
surface instead: **`InstallerContract`** runs the shipped installer (both modes × both twins × all
three dists) and asserts its stdout states the whole agent-handoff contract, and **`DocTruth`**
asserts the authoring docs describe the repo that actually exists. Both were written after three
defects shipped straight through the parser gates — see `meta/LEARNINGS.md`.

The **Verification Rules**, **Leanness**, **SOLID**, **Boy Scout Rule**, and self-review
disciplines in `src/core/CLAUDE.md` bind meta-work too.

## Conventions

Plans → `.claude/plans/` · decisions → `meta/workspace-decisions.md` · meta learnings →
`meta/LEARNINGS.md` · work list → `meta/BACKLOG.md`. Commit to `master` and push when done — never
leave changes uncommitted.

## Migration status note

**The merge is COMPLETE — Phases 0–6 done; v0.26.0 shipped 2026-07-12** (commit `ad717c7`, tag
`v0.26.0`; WSD-018). Both legacy repos are **archived** on GitHub with pointer READMEs, frozen at
v0.25.5. The release folded the two deliberate shipped-content changes (`actions/checkout` v4→v5;
CI strict-fidelity legs retired), so the freeze tags are no longer a CI baseline. This repo is the
single home for framework development; **next: B-27 (team wiki memory) as v0.27.0**.

**v0.26.1 (2026-07-12)** sealed the meta/product boundary: shipped changelogs rewritten in the
consumer's voice, tracking ids stripped from shipped hooks/scripts/tests, the maintainer layer moved
to `meta/`, and `no-meta-leak` added so the boundary is enforced rather than asserted (WSD-019).
