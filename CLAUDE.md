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
| `src/core/` | Single-source shared content (the former 128 common files, with `<!-- @stack:NAME -->` markers where stacks diverge). |
| `src/stacks/{dotnet,angular,monorepo}/` | Per-dist `snippets/` (marker content) and `files/` (whole-file overrides + stack-only files). |
| `dist/{dotnet,angular,monorepo}/` | **Generated** golden output, committed, `linguist-generated`. Never hand-edit — CI rebuilds and diffs. |
| `scripts/` | PowerShell composer and gates: `build`, `validate-dist`, `context-footprint`; `fidelity-check.ps1` is a manual historical re-audit tool. |
| `install.ps1` | Thin root installer: detects the target's stack (auto-detects mixed → monorepo) and delegates to the chosen dist installer. |
| `meta/` | Maintainer layer: `BACKLOG.md`, `workspace-decisions.md` (ADR log), `LEARNINGS.md` (meta-dev log), `ci-handover.md`, `changelogs/legacy-*.md`. Never ships. |
| `.claude/` | Maintainer Claude Code config: `bom-fix` hook + meta test suite, `release.ps1`, plans. Never ships. |

There is deliberately **no root `docs/`**: that name belongs to the consumer (`dist/*/docs/`), and
having both invited exactly the confusion this layout removes. Root `CLAUDE.md`/`AGENTS.md` still
collide by name with their shipped counterparts because Claude Code must load them from the root —
hence the banner above.

The framework's "code" is mostly Markdown (skills, commands, agents, the `CLAUDE.md` templates) +
PowerShell hook and installer scripts. There is no application to compile — the
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
   `dist/<stack>/scripts/template-checks.ps1` (verbatim section diff + version stamps + Common Tasks skill inventory), run per dist by
   `validate-dist` and by CI. This repo's own root `CLAUDE.md` (this file) has a hand-maintained
   `AGENTS.md` mirror — regenerate it when you edit this file.
3. **PowerShell-only execution topology.** Framework-owned executable and hook-registration
   surfaces are PowerShell only. Native Windows is the supported platform; PowerShell 7 is primary
   and Windows PowerShell 5.1 is the fallback. The four shell files under `meta/canaries/` are inert
   historical fixtures, not executable framework surfaces. Textual history may mention Bash, and
   consumer-owned files may use it; active `src/`, `dist/`, root scripts, settings, and CI may not.
4. **UTF-8 BOM mandatory in every `.ps1`.** Windows PowerShell 5.1 mis-parses BOM-less UTF-8.
   This is binary and auto-fixed by the `bom-fix` hook (scoped to this repo) — but if you
   hand-create a `.ps1` outside the hook's reach, add the BOM yourself. The meta test suite and
   each dist's `template-checks` both sweep for it.
5. **Hook output semantics differ per surface.** Claude Code: `exit 2` + stderr to **block**, or
   stdout JSON `hookSpecificOutput.additionalContext` for a soft nudge / `{decision:block,reason}`
   on Stop. Copilot (CLI + VS Code): stdout JSON `permissionDecision: deny` to block. A hook that
   must enforce on both surfaces has to emit **both** shapes. Always test both. Copilot CLI
   `postToolUse` context consumption is version-dependent: it was absent in 1.0.68 and observed in
   1.0.80, so tests must not assume it universally.
6. **Don't-ship boundary — and it is now a machine check.** Only `dist/` contents reach consumers,
   via the dist installers (the root installer just delegates). Everything else — root
   `README`/`CHANGELOG`/`meta/`/`.claude/`/`scripts/`/`src/` — is authoring-repo-only and must never
   be copied by an installer or collide with a template file. The `.template-repo` marker inside each
   dist disables consumer CI for the template itself.
   **The boundary is enforced by `validate-dist` check 6 (`no-meta-leak`)**, which scans each
   composed dist against `scripts/meta-denylist.txt` — our development vocabulary (tracking ids
   `B-nn`/`WSD-nnn`, "lockstep", the two-repo past, maintainer-only tooling) must not appear in a
   shipped file. The denylist is one file read by the validator. If a legitimate
   consumer-facing word trips it, add a narrow `ALLOW` — do **not** weaken a `DENY` pattern.
   Prose alone never held this line: it was written down as an invariant here from the start and
   still shipped ~190 leaking lines to consumers (see `meta/LEARNINGS.md`, 2026-07-12).
7. **Versioning.** When *shipped* behavior changes: write an entry in the **root** `CHANGELOG.md`
   and add a matching `## <version> — Unreleased` head (with content, however minimal) to all three
   `src/stacks/*/files/CHANGELOG.md` — `release.ps1` requires all four heads to already carry the
   target version before it will stamp and release (B-54); it does not create them. Then release via
   `.claude/scripts/release.ps1` — it stamps `src/core/CLAUDE.md` + the three `framework-version.json`
   files, stamps all four changelog heads' dates, rebuilds `dist/`, runs every gate, and refuses to
   commit on failure. `meta/LEARNINGS.md` is append-only. (Manual stamping shipped drift twice; don't
   go back to it.)
   **Write the shipped changelog in the consumer's voice** — what changed in *their* repo and what
   they must do. Tracking ids, our two-repo past, and maintainer asides belong in the root
   `CHANGELOG.md` (which is *our* log), not in `src/stacks/*/files/CHANGELOG.md` (which is *theirs*).

---

## How to approach a change (meta-workflows)

These replace the shipped consumer workflows for meta-work.

- **Artifact change** (skill / command / agent / hook / `CLAUDE.md` template):
  edit `src/core` — or the stack snippet/file *plus its monorepo sibling* [#1] → sync
  PowerShell surfaces [#3] → rebuild all three dists and check freshness → `validate-dist` ×3
  (covers the AGENTS.md mirror [#2]) → bump version + CHANGELOG + LEARNINGS if shipped behavior
  changed [#7] → verify (see Definition of done) → commit + push.
- **Hook / script bug:** reproduce by piping a crafted JSON fixture to the hook (see
  `DEVELOPING.md` → "Run/test a hook") → fix in `src/` → re-run the fixture to confirm → review the
  monorepo sibling → rebuild → verify on **both agent surfaces** [#5] and both PowerShell hosts.
- **New version / large change:** plan first; persist the plan to `.claude/plans/`. The adversarial
  critique pass is not optional here — see Maintenance model #1 for when it is required, and #6 for
  the proportionality case that critique must include before the design locks. Gate before touching
  code.
- **Investigation / design:** write no code; weigh ≥2 approaches with trade-offs; record the
  outcome in `meta/workspace-decisions.md` (see Conventions).

---

## Maintenance model (who implements, who reviews, what "green" means)

The shipping quality of this framework has depended on a second, independent reviewer, and the
record proves it: B-37's post-ship review of a lower-tier implementation found **six real defects**
including a false "gates green"; every externally-implemented item (B-32, B-21, B-35, B-36, B-27)
had 2–5 real findings caught **before** ship. That discipline was tribal — these seven rules make it
binding. For rules 2–4, `release.ps1` makes supplied evidence or its absence visible; it cannot judge
review independence, quality, or truth, which remain evidence-review obligations.

1. **Locked design + adversarial critique before implementation, for every M+ item.**
   **Re-validate the premise of any entry filed more than ~5 minor versions ago, before implementing
   it.** Every open backlog entry now carries a `**Filed against:** vN (date)` stamp, so the amount of
   history to check is stated rather than guessed. The critique pass is the natural home for this — it
   is already licensed to reject the premise. This is not hypothetical: in a single campaign, B-79's
   MSIX hypothesis was refuted by measurement (the predicted 45% win was 0%), B-138 named the wrong
   optimisation target twice, and both halves of B-130 turned out stale — one no longer reproduced at
   all, and the diagnostic it asked for already existed. An entry is written against the tree as it
   was on its filing date; the longer it waits, the likelier its premise has rotted, and P1s wait
   longest because they look expensive.
 The critique
   is licensed to reject the item's *premise*, not merely tighten the approach — twice it has
   killed an already-approved plan, and both times that was the right outcome. But **a reviewer's
   corrections are input, not verdict**: a second pass once caught a factual error in the first
   pass's own remediation. Re-verify what a reviewer tells you before acting on it.
   **Historic decisions are evidence-bearing defaults, not doctrine.** A material change in models,
   hosts, tools, cost, or observed outcomes licenses a premise re-audit. Preserve the old record;
   amend or supersede it explicitly, and start a new result series when the measurement contract
   changes. Re-open only when the changed condition could alter the outcome and the expected decision
   value exceeds the audit cost. “Models are better now” is a reason to re-test, not by itself
   evidence to reverse.
2. **Independent review is evidence-bound, not rank-bound.** The reviewer uses a separate session
   and did not participate in implementation. The reviewer starts from the frozen contract and
   immutable range before reading the implementer's narrative, forms an independent adversarial
   threat model, and records its model/agent, environment, at least one release-specific hostile case
   or applied mutation observed red, a clean rerun, and coverage gaps. Prefer another model family,
   host, or toolchain where available, but model rank alone neither qualifies nor disqualifies a review.
   Changes capable of data loss, security bypass, or false-green release/enforcement behavior require
   a second orthogonal reviewer or execution vantage; otherwise record incomplete coverage and file
   review debt rather than treating one correlated pass as sufficient. Review scope as well as
   correctness: for every changed function, ask whether the frozen contract requires it; justify or
   revert extra surface. Windows is the sole platform leg. Direct PowerShell 7 and Windows
   PowerShell 5.1 runs are separate required host legs; neither may silently relaunch the other.
   Orthogonal review or execution evidence is still required for data-loss, security-bypass, and
   false-green release/enforcement changes.
3. **Nothing enters the record as observed unless you observed it.** This covers implementer
   self-reports, a spec's claims about file layout, the assumption a plan rests on, and any number
   you quote. Verify it **in the environment that matters** — a sandbox whose `PATH` differed from
   the real one produced a false pass twice — or attribute it ("the script claims…") instead of
   asserting it as fact.
4. **A green result counts only from an instrument you have seen go red** on the unfixed tree, in
   the host and code page that matter. This is the dominant recent failure class here: B-64, B-72,
   B-74 and B-75 were all instruments that could not fail, reporting success. Record the failing
   observation next to the check.
   **And the other direction — name the world in which the measure would register success.** For any
   outcome measure, state the concrete, constructible state under which it *would* report the desired
   result. If no such state can be named, the measure is **unreachable** and the experiment is void
   before it runs. "Shown to fail" alone is satisfied trivially by a measure that always fails, which
   then produces a false negative wearing the costume of a principled result — see B-112, where all
   three behavioural instruments built here were broken on first draft, in three different
   directions, and every one was caught by *reading what it pointed at* rather than by running it.
   Inspect the four known semantic-inertness shapes: a literal or syntactically inert assertion; an
   exit-domain collision; empty or absent data conflated with inability to examine; and a
   normalization or comparison path that stops comparing. Release-specific red evidence is the
   proportionate control; these shapes do not justify a generic mutation framework.
5. **Close every delivery with an RCA** filed into `meta/BACKLOG.md`, answering two questions:
   *why did no gate catch it*, and *what else is exposed to the same class?* Sweep for the second —
   the answer is rarely "nothing".
6. **Before rule 1 locks a design, state the proportionality case, not just the correctness case.**
   Rules 1–5 all govern whether an already-chosen fix is *right*; none of them asks whether its
   *cost matches the harm*. Name the concrete, already-observed harm — not a hypothetical one — and
   check whether a materially smaller fix would remove most of it before locking the larger one.
   B-108 is the caught example: the defect class is real and already severe (B-104 was a P1 — the
   exact grammar mismatch this item exists to prevent took the whole bash-leg NL-routing subsystem
   silently offline on Windows), so "should we fix resolver drift" was never in question — but the
   first locked design answered only that question, and stopped, without asking whether a bespoke
   lexical parser (a probe-shaped-line grammar with CRLF normalization, comment/quote scanning, and
   continuation-line handling) was proportionate to seven low-churn files, when the DENY-pattern
   infrastructure B-109 had just built might close most of the same gap far more cheaply. This check
   belongs *inside* the adversarial critique in rule 1 — it is not a second pass, and stating it in
   two sentences in the plan document is enough. Do not let the proportionality check itself become
   the thing that needs a proportionality check.

7. **A gate must distinguish "the artifact is wrong" from "I could not examine the artifact",
   whatever the mechanism.** Reporting the second as the first hands a confident, false, actionable
   diagnosis to whoever is least able to dismiss it — usually a consumer whose machine is already in
   trouble, which is exactly when they run the doctor. This rule is written down because four
   separate entries each fixed one mechanism and none stated the principle: **B-85** (interpreter
   could not be resolved → reported as a dist defect), **B-130** (a bare interpreter name failed to
   resolve → *"CLAUDE.md and AGENTS.md have drifted. Fix: run /generate-copilot"*, false and
   specific), **B-155** (`grep -q`'s exit conflating "absent" with "could not run"), **B-156** (the
   same conflation in extractors, where the swallowed path was also the *passing* path). A fifth
   instance then refused v0.67.0 through a mechanism none of them enumerated — a **file lock** on
   `context-footprint.ps1`'s own output — in a script none of them listed. Enumerating sites has not
   converged, so the obligation sits on the gate author: if your check exits non-zero, it must be
   able to say which of the two things happened. Note the symmetry, learned the hard way in v0.64.0:
   `grep` exits 2 for a *missing file* as well as for a failure to run, so a content fact reported as
   a host problem is the same defect inverted. B-164 established that this remains guidance backed
   by bounded advisory triage, not an enforced gate; per WSD-028/WSD-057, mechanise only what tooling
   can honestly distinguish and keep unjudgeable quality as an explicit evidence obligation. Meta
   gates are hermetic: derive their decisions from repository content and explicit lifecycle inputs.
   If a gate needs lifecycle position, pass it as an input rather than discovering it from ambient
   release state. This remains evidence guidance because no generic gate can honestly distinguish
   every deliberate lifecycle input from ambient discovery.

Evidence trail for all seven: `meta/LEARNINGS.md`. Working hazards that are *not* principles (e.g.
never run the gate suites concurrently with an implementer round) live in `DEVELOPING.md`.

## Definition of done per artifact type

This is what replaces "write a failing test first" when the artifact has no xUnit. Do not
fabricate a test, and do not skip verification — pick the right evidence for the artifact:

- **Hook / PowerShell script** — parses under PS7 and PS5.1 **and** behavior is demonstrated by
  piping a JSON fixture and observing `EXIT=` + stdout/stderr on **both agent surfaces** [#5]. Show it.
  Test against the **dist** copy (what ships), not just the src fragment.
- **Skill / command / agent / template (Markdown)** — renders the intended instruction in every
  dist that carries it (check `dist/monorepo` when a sibling was involved [#1]), and
  `validate-dist` passes ×3. "Test" = an install smoke run into a temp dir, not a unit test.
- **Installer / sync script** — greenfield **and** brownfield smoke install into temp dirs both
  succeed with the expected file layout; for the root installer, all three detection paths.
- **Composer / gate script** — red-test it: plant the defect class it exists to catch and show
  the non-zero exit, then the clean pass.
- **Any change carrying a new or modified test** [#3] — the case is demonstrated **running** (not
  merely passing) on every CI context that will execute it, and **the change is not done until its
  first CI run is green**. CI runs the root and all three shipped suites directly under PS7 and
  native PS5.1. A runner must report its executable and nonzero case count; a nominal PS5 job that
  relaunches under PS7 is a false green. Where a required host cannot execute, that host has no
  evidence. A focused provider leg remains permitted under WSD-061 only when neither required host
  can execute a shipped compatibility contract; it does not replace the Windows host evidence.

## Verification (evidence-based — name the command, show the result)

Never claim "it works." Show the command and its observed output. Before calling a run green, apply
Maintenance model #4: the instrument must have been seen to go red, and at least one suite must have
been re-run under a hostile code page and under both PowerShell hosts — a 5.1-vs-7 divergence hid a
harness defect for an unknown number of releases. Standard commands:

- **Compose + freshness:** `pwsh -NoProfile -File scripts/build.ps1 <dist>` ×3, then
  `git status --porcelain dist/` must be empty.
- **Dist validity:** `pwsh -NoProfile -File scripts/validate-dist.ps1 <dist>` ×3 (markers, JSON,
  PowerShell-only topology, PS-AST, per-dist `template-checks`, `no-meta-leak` [#6], **`no-dead-instruction`**
  — every script a shipped doc tells someone to *run* must exist, resolved from the dist root — and
  **`hook-registration`** (check 8): exactly 18 PowerShell command registrations exist (six Claude
  PS7, six Claude PS5.1, six Copilot), every target resolves case-exactly, and the required
  PowerShell-tool/default-shell/per-hook-shell settings are present [#3]. Check 8 does **not** reject
  a bare interpreter name: that is the intended shipped value (v0.38.1 reverted
  absolute-path pinning because `settings.json` is committed team config), and whether it *resolves*
  is a runtime fact reported by the doctor's `Hook liveness` row, not a build-time one; and
  **`step-references`** (check 12): top-level ordered-list runs are contiguous and numbered prose
  step references resolve within their shipped workflow file.
- **Hook suites:** `pwsh -NoProfile -File dist/<d>/tests/hooks/Invoke-HookTests.ps1` ×3; meta
  suite `.claude/hooks/tests/Invoke-HookTests.ps1` — which also carries the two gates that cover
  the *behavioral* surface no parser can: **`InstallerContract`** (runs the shipped installer in
  both modes × all three dists and asserts its stdout states the whole agent-handoff
  contract) and **`DocTruth`** (the authoring docs describe the repo that actually exists —
  version stamps, marker syntax, no dead paths).
- **Hook behavior:** pipe a fixture JSON event to the hook; assert `EXIT=` + output.
- **Install smoke:** run `install.ps1` into temp greenfield + brownfield dirs under PS7 and PS5.1.
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
(CI enforces freshness). Use `.claude/scripts/push-and-check.ps1` for ordinary pushes and
`.claude/scripts/release.ps1` for releases; both inspect every outgoing commit before pushing.

## Conventions

- **Plans** → `.claude/plans/`.
- **Framework-level decisions** → `meta/workspace-decisions.md` (lightweight ADR log: the merge,
  mirror strategy, hook semantics, composition rules).
- **Meta-dev learnings** → `meta/LEARNINGS.md` (distinct from the shipped `src/core/LEARNINGS.md`,
  which is an empty template the consumer's team fills in — do not confuse the two).
- **Work list** → `meta/BACKLOG.md` — **open work only**. Finished entries move to
  `meta/BACKLOG-DONE.md`; an entry is in exactly one of the two, never both (the double
  convention is what produced a 41%-wrong index, see the 2026-08-16 heading audit).
  `PARTIALLY DONE` is a legitimate open state — do not archive a partially-done entry.
- **Standing constraints** → `meta/decisions-index.md`. **Read it before locking any design.**
  Decisions get made inside individual backlog entries and are then invisible to anyone not
  reading that entry; a whole design was drafted in this repo that violated one such decision
  because nothing surfaced it. Citations name an entry id, never a line number.

## Status

Version authority is the machine-readable `dist/*/.claude/framework-version.json` stamps; release
history is `CHANGELOG.md` plus tags. The current work list is `meta/BACKLOG.md`, not a status summary
here, because a summary rots.

Gotcha: `scripts/fidelity-check.ps1` still exists but is **no longer wired to CI** — it is a
manual re-audit tool against the `pre-restructure` tag, not a gate.
