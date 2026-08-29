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
   shipped doc tells someone to run must exist, resolved from the dist root; **check 8
   (`hook-registration`)** guards the same for hook wiring — every script named in
   `.claude/settings*.json` / `.github/hooks/hooks.json` exists in the dist, with its twin [#3]. It
   deliberately does not reject a bare interpreter name (v0.38.1 made that the intended shipped
   value); whether it resolves is a runtime fact, reported by the doctor's `Hook liveness` row.
7. **Versioning.** Shipped behavior change ⇒ root `CHANGELOG.md` entry **and** a matching
   `## <version> — Unreleased` head in all three `src/stacks/*/files/CHANGELOG.md` (mandatory,
   not optional — `release.ps1` refuses to release without all four, B-54), then release via
   `.claude/scripts/release.ps1` (stamps `src/`, rebuilds `dist/`, stamps all four changelog dates,
   runs every gate, refuses on failure). `meta/LEARNINGS.md` is append-only. Write the **shipped**
   changelog in the consumer's voice; tracking ids and maintainer asides belong in the root
   `CHANGELOG.md`, which is *our* log.

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

## Maintenance model

Canonical definitions live in `CLAUDE.md` > Maintenance model — same seven rules, condensed here.
For rules 2–4, `release.ps1` exposes supplied evidence or its absence; it cannot judge review
independence, quality, or truth.

1. **Locked design + adversarial critique before implementing any M+ item.** The critique may
   reject the item's *premise*, not just its approach. A reviewer's corrections are input, not
   verdict — re-verify them. **Re-validate the premise of any entry filed more than ~5 minor
   versions ago** — every open entry carries a `**Filed against:** vN (date)` stamp saying how much
   history to check. Premise rot is real and measured: B-79, B-138 and B-130 were all refuted or
   stale when finally read. Historic decisions are evidence-bearing defaults, not doctrine: changed
   models, hosts, tools, cost, or outcomes license a recorded re-audit when the change could alter
   the outcome and expected decision value exceeds audit cost—not silent history rewriting.
2. **Independent review is evidence-bound, not rank-bound.** Use a separate session whose reviewer
   did not participate in implementation, a frozen contract and immutable range, a blind-first
   threat model, a release-specific hostile case or applied mutation observed red, a clean rerun,
   and explicit environment/gaps. Prefer another
   model family, host, or toolchain, but rank alone neither qualifies nor disqualifies. Data-loss,
   security-bypass, and false-green release/enforcement changes also require an orthogonal reviewer
   or execution vantage; otherwise file the remaining debt.
3. **Nothing enters the record as observed unless you observed it** — self-reports, a spec's
   file-layout claims, a plan's assumptions, any number you quote. Verify in the environment that
   matters, or attribute the claim rather than asserting it.
4. **A green result counts only from an instrument you have seen go red** on the unfixed tree, in
   the host and code page that matter. **And the other direction: name the constructible state in
   which the measure would register success.** If none can be named the measure is unreachable and
   the experiment is void before it runs — "shown to fail" is satisfied trivially by a measure that
   always fails (B-112).
5. **Close every delivery with an RCA** in `meta/BACKLOG.md`: why did no gate catch it, and what
   else is exposed to the same class?
6. **Before rule 1 locks a design, state the proportionality case, not just the correctness case.**
   Name the concrete, already-observed harm and check whether a materially smaller fix would remove
   most of it before locking the larger one — rules 1–5 all assume the fix's *scope* is already
   right and only test whether it's *verified* right. B-108 is the caught example: the defect class
   was real (B-104, P1) but the first locked design never asked whether its bespoke lexical parser
   was proportionate to seven low-churn files when cheaper machinery (B-109's DENY-pattern gate)
   might close most of the same gap. Lives inside rule 1's critique, not a second pass.

7. **A gate must distinguish "the artifact is wrong" from "I could not examine the artifact",
   whatever the mechanism.** Reporting the second as the first hands a confident, false, actionable
   diagnosis to whoever is least able to dismiss it. Four entries each fixed one mechanism without
   stating the principle — B-85 (unresolvable interpreter reported as a dist defect), B-130 (a bare
   interpreter name producing a false *"CLAUDE.md and AGENTS.md have drifted"*), B-155 (`grep -q`
   conflating "absent" with "could not run"), B-156 (the same conflation in extractors, where the
   swallowed path was also the passing one) — and a fifth instance then refused v0.67.0 through a
   **file lock** on `context-footprint.ps1`'s own output, a mechanism none of them enumerated.
   Enumerating sites has not converged, so the obligation sits on the gate author: a non-zero exit
   must be able to say which of the two things happened. The symmetry matters too — `grep` exits 2
   for a *missing file* as well as a failure to run, so a content fact reported as a host problem is
   the same defect inverted. B-164 tracks whether this is mechanically enforceable or stays guidance;
   per WSD-028/WSD-057, mechanise only what tooling can honestly distinguish and keep unjudgeable
   quality as an explicit evidence obligation.

`release.ps1` refuses to release without either `-ReviewEvidence` (the supplied range, hostile/red
and clean evidence, environment/gaps, and identities) or `-NoIndependentReview`, which is allowed
but records `review evidence: none supplied` in `meta/review-ledger.md` and files the post-ship
review item automatically. The switch retains its legacy name; the script exposes supplied-evidence
presence or absence and does not infer whether a review occurred or certify the claim.

## Conventions

Plans → `.claude/plans/` · decisions → `meta/workspace-decisions.md` · meta learnings →
`meta/LEARNINGS.md` · review ledger → `meta/review-ledger.md`.
**Work list → `meta/BACKLOG.md` (open only); finished entries → `meta/BACKLOG-DONE.md`. An entry
is in exactly one of the two, never both; `PARTIALLY DONE` is a legitimate OPEN state.**
**Standing constraints → `meta/decisions-index.md` — read it before locking any design**, because
decisions get made inside individual backlog entries and are invisible to anyone not reading them.
Commit to `master` and push when done — never leave changes uncommitted.

## Status

Version authority is the machine-readable `dist/*/.claude/framework-version.json` stamps; release
history is `CHANGELOG.md` plus tags. Read `meta/BACKLOG.md` for current work rather than a status
summary here.

Gotcha: `scripts/fidelity-check.{ps1,sh}` still exist but are **no longer wired to CI** — they are
manual re-audit tools against the `pre-restructure` tag, not gates.
