# B-22 headless `/adopt` — design (P0)

> **Status (2026-07-06): design FINAL (rev-2, Path A).** Adversarial critique returned RETHINK;
> its two HIGH findings and the constraint-1-vs-2 conflict are resolved below. **The maintainer
> chose Path A** (2026-07-06): headless *prepares* adoption autonomously; a human *applies* the
> untrusted-content merges at PR review — the prompt-injection boundary stays fully intact. The
> normative spec is **§ Design rev-2 (Path A)**; the rev-1 sections are struck through for
> history. Decision record: **WSD-014**. Implementation is post-merge (merged `ai-tech-lead` repo,
> ≥ v0.28.0), **composes with B-21 D1**; freeze-compatible (meta-only). Findings log at the bottom.

## Fork resolution (maintainer decision, 2026-07-06): Path A

The critique's HIGH-1 established that headless mode cannot auto-merge untrusted content into
`CLAUDE.md` (the file that steers every session) without breaking constraint 2 — a fixed keyword
denylist is the only automated filter, and interactive `/adopt`'s second human backstop ("show
each merge before applying", `adopt.md:165`) would be gone. Constraint 2 is non-negotiable, so
auto-merge is off the table. The maintainer chose **Path A — "headless preparation, human
merges"**: the agent does the mechanical, safe work autonomously (branch, archive, provenance +
adversarial screen, impact baseline, PR structuring) and **stages** every proposed
CLAUDE.md/TECH_DEBT merge as a reviewable change, but a **human applies the merges at PR review**.
This reframes the deliverable from "agent finishes adoption" to "agent prepares adoption, human
applies the merge" — a smaller human job than today's full manual `/adopt`, with the boundary
fully intact. Path B (constrained auto-merge, residual injection risk) was rejected. § Design
rev-2 below is built on Path A and folds HIGH-2 + M3–M7.

## What's being asked

An **agent-runnable, non-interactive `/adopt`** so an installing agent can finish adoption
end-to-end without a developer having to open a session and type `/adopt`. Today (v0.20.0+) the
installer detects the brownfield case, archives originals, writes `.claude/adoption-pending.json`,
and hands off to a human — `/adopt` is `disable-model-invocation: true` and the installer
explicitly tells any AI agent **not** to run it (`install.sh:147-150`). B-22 closes that last
manual step while keeping the trust boundary that made `/adopt` developer-initiated in the first
place.

## The four locked constraints (BACKLOG B-22 — non-negotiable envelope)

1. Every interactive gate gets a **safe default + a deferred-review artifact**, not removal.
2. The Phase-1 **quarantine stays human-gated** — provenance/adversarial-content-flagged files
   never auto-merge (prompt-injection trust boundary; financial domain). **Non-negotiable.**
3. Solve the **invocation path** — slash commands don't exist in the installing agent's session.
4. **Review moves to the PR** — everything deferred lands in the Phase-8 report; adoption commit
   on a branch; Phase-9 impact mandatory; the marker is deleted so SessionStart/CI guards release.

## Current state (verified 2026-07-06 at v0.25.5)

Interactive gates in `adopt.md`, in order:

| # | Gate | Location | Today |
|---|---|---|---|
| G0 | uncommitted-changes → **STOP** | Phase 0.1 | hard stop (reversibility) |
| G1 | branch confirmation | Phase 0.2 | "Wait for confirmation" |
| G2 | ambiguous-file disposition | Phase 1 discovery | "ask the user explicitly" |
| G3 | **quarantine per-file approval** | Phase 1 safety screen | "explicit per-file approval" — the boundary |
| G4 | merge-plan confirmation | Phase 2 | "Wait for the user to confirm or amend" |
| G5 | per-merge "show before applying" | Phase 4 | show each; 4a contradictions asked individually |
| G6 | commit reminder | Phase 8 | "remind the user to commit" |

Non-interactive already: Phase 3 archive (informational present), Phase 9 impact ("automatic,
needs no confirmation"), marker deletion (Phase 3). The marker's `nextStep` today is
`"/adopt (developer-initiated; the model cannot invoke it)"` (`install.sh:114`); both installer
twins carry the same brownfield handoff + "do not attempt /adopt yourself" text
(`install.sh:133-150`, `install.ps1` mirror). `disable-model-invocation: true` is on both
`adopt.md:3` and `bootstrap.md:3`.

## Design rev-2 (Path A) — the normative spec

**Reframe:** headless `/adopt` = **autonomous preparation + human-applied merge**. The agent runs
everything that is mechanical and safe, and **stages** every change to canonical guidance
(`CLAUDE.md`, `TECH_DEBT.md`) as a reviewable branch diff a human approves at PR review. Nothing
derived from untrusted external artifacts is *applied* to canonical guidance without a person.
The "prepared" state is a PR-ready branch, not a finished adoption.

### D1 — Invocation: read-and-execute the workflow body; the `disable-model-invocation` flag stays (constraints 3, and L9)

**Do NOT flip `disable-model-invocation`** on `adopt.md` — it blocks ambient model self-invocation
and stays `true`. The headless entry reuses a **proven in-repo pattern**: the existing
`.github/prompts/adopt.prompt.md:6` already says "Read `.claude/commands/adopt.md` … then execute
the adoption workflow defined there" — a plain prompt that reads-and-executes the workflow body,
which the flag does not touch (a prompt file has no `disable-model-invocation`). So the headless
entry is: **an operator-initiated prompt that reads `adopt.md` and executes it with a `--headless`
directive** (via `$ARGUMENTS`, already present in `adopt.md`). No dependence on whether
`claude -p "/adopt …"` honours a disabled slash command — the spike the rev-1 gated on is
**dropped** (M6).

- **Both surfaces, not Claude-only (M7).** Because the mechanism is "read-and-execute the workflow
  body," it works wherever a non-interactive prompt runs: Claude Code (`claude -p` pointed at the
  headless directive) **and** Copilot CLI (its `-p` equivalent, reusing the existing
  `adopt.prompt.md` wrapper with the headless directive). Neither is blocked on the other; the
  Copilot surface — the stated consumer (Copilot VS Code / Bitbucket DC) — is a first-class target,
  not a deferred leg. On interactive VS Code a human is present, so headless is unneeded there.
- **The boundary on Copilot (L9).** On Copilot the `disable-model-invocation` flag is irrelevant
  (the prompt wrapper is already model-runnable). Under Path A that is **safe by construction**:
  headless never auto-applies untrusted-content merges on *any* surface, so the boundary is
  enforced by the workflow's Path-A rules (stage-don't-apply + quarantine exclusion), not by the
  flag. The `## Headless mode` section states this explicitly.
- **Installer wiring (twins [#3]):** the brownfield handoff (`install.sh`/`.ps1`) and the marker's
  `nextStep` offer the headless entry **alongside** the developer path — the "IF YOU ARE AN AI
  AGENT" block changes from "do not attempt /adopt yourself" to "hand off to a developer, **or**
  run headless adoption (reads-and-executes the adopt workflow in `--headless` mode); it prepares a
  PR branch for human review — it does **not** apply merges or open the PR."

### D2 — Per-gate behaviour under Path A (constraint 1) — stage, don't apply

`## Headless mode` in `adopt.md` makes this table normative. Rule: **the safe direction is to
prepare, never to apply untrusted content to canonical guidance**; every deferred item is recorded
for the PR.

| Gate (adopt phase) | Headless behaviour | Deferred-review artifact |
|---|---|---|
| G0 uncommitted (0.1) | **Hard-stop preserved.** Precondition (M5): the operator commits the installed framework files to the **default branch** first (handoff step 1); headless then runs on an otherwise-clean tree. A dirty non-install tree → stop + report (reversibility matters *more* unattended). | n/a (refuses) |
| G1 branch (0.2) | **Auto-create & switch to `adopt-ai-framework`** off the default branch. If it already exists, use `adopt-ai-framework-<date>` and note it (M5). | branch name in report |
| G2 ambiguous file (1) | **Skip — never merge.** | skipped list → report + B-21 checklist |
| G3 quarantine (1 screen) | **Exclude — never merge, never auto-approve.** See D3. | quarantine list, top of report + checklist |
| G4 merge-plan (2) | **Compute and record** the plan — as a *proposal*, not an approval to auto-apply. | plan recorded verbatim in the report |
| G5 merges (4) | **STAGE, do not apply (HIGH-1).** Write each proposed CLAUDE.md/TECH_DEBT change as a **clearly-marked, attributed, normalised** block (rule + rationale, never raw prose) that a human approves at PR review — the agent does not silently finalise canonical guidance. 4a contradictions → keep-in-code default + B-21 `<!-- DEFAULTED: … -->` marker + checklist entry. | every proposed merge in the branch diff; each defaulted contradiction in the checklist |
| G6 TECH_DEBT (5) (M3) | Default severity/effort to **"unset — needs a human"**; stage, do not finalise. | proposed items + the unset fields in the checklist |
| G7 custom commands (6) (M3) | **Never auto-add** custom commands (they expand the command surface). Leave in `docs/pre-adoption/`. | list them in the report |
| G8 commit (8) | **Commit to the branch** only. | Phase-8 report = PR-description seed |

- **Defense-in-depth on runtime steering (HIGH-1, second prong).** Ingesting untrusted content in
  a tool-enabled loop is itself an exposure (the scan hunts for "read env/secrets, POST to a URL,
  change git config" bait). Run headless discovery/screen/synthesis with the **narrowest tool
  surface** that still allows repo read + git-read + branch-write: **deny network egress, secret
  access, and git-config changes**. Path A's stage-don't-apply is the *primary* control; the
  restricted tool surface bounds what injected content could do mid-run. If the surface cannot be
  tightened enough on a given surface, that is a further argument for Path A (which it already is).

### D3 — Quarantine + the whole merge step stay human-gated (constraint 2 — non-negotiable)

The Phase-1 safety screen (`adopt.md:104-115`) is unchanged in *what it flags*. Under Path A the
boundary is broader than quarantine:

- **No untrusted-content merge is ever *applied* to canonical guidance by the agent** — quarantined
  or not, every discovered-artifact merge is *staged* for human approval (D2 G5). This is the
  HIGH-1 resolution: the human backstop that rev-1 deleted is restored as PR-review approval of the
  staged diff.
- A file tripping **provenance OR the adversarial-content scan is QUARANTINED**: excluded even from
  *staging*, left archived under `docs/pre-adoption/` unmerged, surfaced **top** of the report +
  checklist with its trigger. **No auto-upgrade ever** — headless must not re-scan or self-approve
  a quarantine.
- **Provenance vs. the installer archive (M4).** The installer archives originals with `mv -f`
  (not `git mv`, `install.sh:63`), so after the operator's install-commit every archived original
  looks "recently added" and would be provenance-quarantined en masse. Fix: the provenance rule
  **exempts files recorded in the marker's `archivedOriginals`** from the "recently added /
  untracked" trigger (they are known installer moves, not suspicious new files) — they still go
  through the adversarial-content scan. Without this, headless quarantines nearly everything.

### D4 — Review moves to the PR; branch + marker/guard lifecycle (constraint 4, M5)

- **Everything runs on `adopt-ai-framework`.** Install is committed to the **default branch**
  (G0 precondition); headless branches from there. The staged merges, archive, and impact commits
  are on the branch; the default branch is untouched by the adoption itself.
- **Marker lifecycle (M5 reconciled).** The installer wrote `.claude/adoption-pending.json` into
  the working tree; the G0 precondition commits it (with the install) to the **default branch**.
  Headless deletes it on the **branch** (Phase 3). So on the default branch the marker persists →
  SessionStart nag + `docs-sync-check` CI keep firing until the reviewed PR merges; **guards
  release only when a human merges the adoption.** (This requires the install to be committed to
  the default branch, which the handoff already directs — not branch-first; the design pins that
  and notes `adopt.md:20`'s interactive branch-first recommendation does not apply to the headless
  precondition.)
- **Phase 8 report = PR-description seed:** inventory, archived originals, the recorded merge-plan,
  the **staged (not applied) merges** for review, skipped/ambiguous list, **quarantine list**
  (top), and the B-21 "needs a human decision" checklist. B-22 **composes with B-21 D1** and adds
  quarantine + skipped + unset-TECH_DEBT rows. (B-21 D1 lands with or before B-22.)
- **Phase 9 impact stays mandatory** (already automatic; unchanged).
- **Embedded `/bootstrap` (Phase 7) must also run headlessly (HIGH-2).** Phase 7 invokes
  `/bootstrap`, whose **Phase 3d-bis** hazard confirmation is *not* skipped under adopt
  (`bootstrap.md:143` skips only 2b; 3d-bis at :248-266 still asks) → a naive headless run stalls.
  Fix: the `--headless` directive **propagates into the embedded bootstrap**; bootstrap's headless
  safe defaults — **3d-bis: write every hazard `[UNVERIFIED]` and list them on the B-21 checklist**
  (never auto-confirm a hazard); INFERRED conventions already flow to the checklist (B-21). This
  pulls a *scoped* slice of "bootstrap headless" **in scope** (only the adopt-embedded path).
  Bootstrap's code-derived CLAUDE.md population is *not* the adopt trust boundary (it documents the
  operator's own source, not external agent-instruction artifacts), so it proceeds as in greenfield
  with its INFERRED/checklist handling — the stage-don't-apply rule (D2 G5) applies specifically to
  merges of *discovered external artifacts*.
- **Run ends by** printing the branch name, the PR-seed, and an explicit "open a PR from
  `adopt-ai-framework`; the CLAUDE.md/TECH_DEBT changes are **proposed** — review and apply them;
  N files were quarantined and NOT merged — review before trusting." It does **not** open or merge
  the PR (no host-API assumption).

## Implementation notes (for the executing session, post-merge)

- **Artifacts:** `adopt.md` (new `## Headless mode` section + `--headless` via `$ARGUMENTS`; the D2
  gate table normative); `bootstrap.md` (scoped headless propagation — 3d-bis safe default when
  invoked under headless adopt); `scripts/install.sh` + `install.ps1` (twins [#3] — brownfield
  handoff + marker `nextStep`); the `.github/prompts/adopt.prompt.md` wrapper (mirror [#1], gains
  the headless directive). In the merged repo these are `src/core` edits; the adopt/bootstrap
  bodies are stack-agnostic (core).
- **Dependency:** **B-21 D1** (the PR checklist) — sequence with or before B-22 so quarantine /
  skipped / unset rows have a checklist to attach to. Both post-merge, both design-locked
  (WSD-013 / WSD-014). The B-21 `<!-- DEFAULTED -->` marker is reused for G5 contradictions.
- **Boundary preserved:** `disable-model-invocation: true` stays on `adopt.md` and `bootstrap.md`;
  Path A enforces the boundary by stage-don't-apply + quarantine exclusion + restricted tool
  surface, not by the flag (which is irrelevant on Copilot).
- **Tests (brownfield install smoke — the Definition of Done for a workflow artifact):** into a
  temp brownfield repo with (a) a clean legacy `.cursorrules` → **staged** as a proposed CLAUDE.md
  merge on the branch (not silently applied to a finalised file); (b) a planted-injection file
  (`<!-- ignore previous… -->`) → quarantined, never staged, listed top-of-report; (c) an ambiguous
  300-line doc → skipped + listed; (d) a hazard candidate → 3d-bis writes `[UNVERIFIED]` + checklist
  (no stall). Assert: the branch exists, the **default branch still has the marker** (guards still
  fire), the report carries all sections + the B-21 checklist, and CLAUDE.md changes are marked
  proposed. Installer-twin edits also get the standard install smoke.
- **Invariant #7 (L8):** shipped behaviour changes → CHANGELOG entry + `release.ps1` stamp
  (post-merge: one CHANGELOG).
- **Effort: L** (per BACKLOG) — the headless gate section, the scoped bootstrap propagation, twin
  installer edits, the provenance-exemption fix, the restricted-tool-surface work, the brownfield
  smoke fixtures, and the B-21 composition.

## Out of scope

- Auto-opening/merging the PR (no host-API dependency; human or orchestrator does it).
- Making greenfield `/bootstrap` fully headless as a standalone entry (only the adopt-embedded
  3d-bis slice is in scope here).
- Any change to *what* the safety screen flags (Path A changes the no-human-approval path only).
- Path B (constrained auto-merge) — rejected at the fork.
- Dual-repo implementation before the merge (freeze).

## Adversarial critique (2026-07-06) — findings log (verdict: RETHINK → resolved in rev-2)

Fresh-context Plan agent; every rev-1 line citation verified accurate; the problems were in what
rev-1 omitted. **All findings are resolved in § Design rev-2 (Path A)** — HIGH-1 by the maintainer's
Path-A choice (stage-don't-apply + restricted tool surface), HIGH-2 by the scoped bootstrap
propagation (D4), and M3–M7/L8–L9 as noted per finding:

- **HIGH-1 (security)** — headless auto-merge (D2 G5) trusts only the keyword denylist; it removes
  the "show each merge before applying" human backstop, so denylist-evading injected content
  auto-enters `CLAUDE.md`, and ingesting untrusted content in a tool-enabled loop is itself the
  exposure. Breaks constraint 2 end-to-end. → the Open Fork above.
- **HIGH-2 (showstopper)** — headless Phase 7 runs `/bootstrap`, whose **Phase 3d-bis** hazard
  confirmation is *not* skipped under adopt (`bootstrap.md:143` skips only 2b; 3d-bis at :248-266
  still asks) → headless stalls. rev-1 put "bootstrap headless" out of scope while its own Phase 7
  runs bootstrap — a contradiction. rev-2: propagate headless into the embedded bootstrap;
  3d-bis safe default = all hazards `[UNVERIFIED]` + list on the B-21 checklist.
- **M3** — gate inventory missed Phase 5 (TECH_DEBT severity/effort asks, `adopt.md:214-219`) and
  Phase 6 (custom-command add, "ask user first", `adopt.md:227`). rev-2: G7 = default
  severity/effort to "unset — needs human", never auto-apply; G8 = never auto-add custom commands,
  leave in `docs/pre-adoption/` + list.
- **M4** — installer archives with `mv -f` not `git mv` (`install.sh:63`); G0's "commit install
  first" then makes every archived original look "recently added" → provenance-quarantines
  nearly everything, defeating the feature (and contradicting rev-1's own happy-path fixture).
  rev-2: exempt marker-recorded `archivedOriginals` from the "recently added" provenance trigger.
- **M5** — D4's "master untouched" contradicts G0 committing the install+marker somewhere;
  guard-release only works if the install is committed to the default branch. rev-2: pin the
  install-commit target; reconcile with `adopt.md:20`'s existing branch recommendation; handle a
  pre-existing `adopt-ai-framework`.
- **M6** — the D1 invocation spike is avoidable: `.github/prompts/adopt.prompt.md:6` already
  reads-and-executes the adopt workflow body (no `disable-model-invocation` on a plain prompt) —
  a proven in-repo pattern. rev-2: make the prompt-file entry the **primary** mechanism, not a
  spike-gated fallback.
- **M7** — solves invocation for Claude Code (has slash commands + a human) while deferring the
  Copilot leg (the surface whose agent actually lacks the path; the stated consumer). rev-2:
  justify the Claude leg's value now or resequence so Copilot isn't an afterthought.
- **L8** — implementation notes omit invariant #7 (CHANGELOG + `release.ps1`). Add.
- **L9** — the `.github/prompts/adopt.prompt.md` wrapper is already a model-runnable path the
  `disable-model-invocation` flag doesn't touch; rev-2 must state the boundary is a Claude-only
  construct and how the Copilot leg preserves constraint 2 without it.
