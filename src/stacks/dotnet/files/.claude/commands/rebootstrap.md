---
description: "Re-align the framework after drift: refresh conventions, hazards, and mined skills against the current codebase; respects declined-recipe history in LEARNINGS.md. Developer-initiated only."
disable-model-invocation: true
---

Refresh the AI Tech Lead framework configuration for this .NET codebase. Use when conventions have drifted, new patterns have emerged, or the team wants to re-align after months of evolution.

This is NOT a replacement for `/bootstrap`. It assumes CLAUDE.md is already populated and merges updates into it rather than overwriting.

## Input
$ARGUMENTS

---

## Pre-flight checks

Before doing anything else:

1. **Check CLAUDE.md is populated** — read CLAUDE.md. If it still contains the marker `BOOTSTRAP_PENDING`, abort immediately and tell the user:
   > "CLAUDE.md has not been bootstrapped (BOOTSTRAP_PENDING marker still present). Run `/bootstrap` first to populate it from your codebase, then return to `/rebootstrap` once the framework is set up."

2. **Confirm git is available** — this command uses git history to focus analysis. If the repo has no commits, skip the git log step and proceed with a full scan.

---

## Pre-step — What changed since last time?

Run: `git log --since="3 months ago" --stat`

From this output, identify the **actively changed areas** — files and directories that have seen the most edits in the past 3 months. These are the highest-priority areas for re-analysis. List them before proceeding; they focus the analysis passes below.

---

## Phase 1 — Re-analysis

Perform the same eight analysis passes as `/bootstrap` (A1–A8), but **scoped to the actively changed areas** identified above. For unchanged areas, carry forward existing CLAUDE.md content unless you spot an obvious contradiction.

### A1: Solution Architecture
Re-examine the project layout, layering strategy, dependency direction, entry points, and configuration approach. Note any new projects or removed projects since the last bootstrap.

### A2: Domain & Data Access
Re-examine entity structure, ORM usage, repository patterns, query patterns. Flag any new N+1 risks or patterns introduced since last time.

### A3: Dependency Injection & Services
Re-examine service registration, lifetimes, interface usage, and cross-cutting concerns. Note any new patterns (e.g., adoption of MediatR, new validators).

### A4: API Design & Middleware
Re-examine controller design, request/response models, validation, error handling, auth, and middleware pipeline. Note any new endpoints or breaking changes to existing patterns.

### A5: Testing
Re-examine test coverage, test quality, and gaps. Note what was tested vs what grew untested.

### A6: Code Quality & Dependencies
Re-examine async hygiene, null handling, exception handling, logging, NuGet dependencies. Flag outdated packages and any newly introduced anti-patterns.

### A7: Financial Domain Invariants
Only if the codebase shows financial-domain signals (see the `### A7:` gate in `bootstrap.md`). Re-examine monetary precision (`decimal` vs `double`/`float`), negative-amount guards, idempotency-key enforcement, check-then-act races on balances, regulatory-calculation isolation, rounding strategy, and audit trails on financial mutations — scoped to the changed areas. If no financial signals, note `A7: skipped — no financial domain signals` and move on.

### A8: Project-Specific Skill Discovery
Re-run the discovery pass (same definition as `bootstrap.md`'s `### A8:`), scoped to the actively changed areas and any new naming clusters that appeared in the git log period. **Before proposing candidates**, check `LEARNINGS.md` for `## Declined recipe:` entries and skip anything that matches — the team removed those deliberately.

---

## Phase 2 — Delta synthesis

Compare findings against the current CLAUDE.md:

1. **New conventions** — patterns that now exist in the codebase but aren't documented
2. **Stale conventions** — documented rules that the codebase no longer follows (removed, replaced, or contradicted)
3. **New debt** — issues found that aren't in TECH_DEBT.md
4. **Resolved debt** — TECH_DEBT.md items that appear to be fixed in the codebase
5. **Unchanged areas** — explicitly note what was not re-analysed and why

Present this delta to the user as a structured list before proceeding to Phase 3. This is the user's opportunity to correct misunderstandings before changes are applied.

---

## Phase 3 — Diff-aware merge

For each proposed change, show the user a diff (before/after) and ask for confirmation before applying. Do not silently overwrite any existing content.

Format each diff proposal as:

```
### Proposed change: <short title>

**Before:**
> [exact current text from CLAUDE.md or TECH_DEBT.md]

**After:**
> [proposed replacement]

**Reason:** [1 sentence]

Accept / Reject / Edit?
```

Wait for the user's response before applying each chunk. If the user says "edit", incorporate their change before applying.

### 3a: Update CLAUDE.md

Apply accepted changes section by section:
- **Conventions**: add new conventions, update stale ones, remove obsolete ones
- **Architecture Decisions**: add new decisions; mark old decisions as superseded if applicable
- **Common Tasks**: update patterns to reflect current codebase reality. The two changes below are proposed through the **same diff-and-confirm gate** as every other Phase-3 change — show the before/after and wait for the user, do not apply silently:
  - **Exemplar re-pinning**: for any instance-shaped skill (`add-endpoint`, `add-entity`, `register-service`, any mined `add-X`) whose pinned exemplar file no longer exists or a clearly cleaner instance now exists — propose updating the exemplar prose line. Confirm the new path resolves (Verification Rule #1).
  - **New A8 candidates**: if the discovery pass returned new candidates this run, apply the same quality-gate and exemplar-grounding rules from `/bootstrap` Phase 3a, and propose each as a diff.
  - **Resurrection guard** (bookkeeping side-effect, not a diff chunk): if any skill with `origin: discovered` in its frontmatter has been deleted from `.claude/skills/` since the last run, append a declined-recipe block to `LEARNINGS.md` so the discovery pass stops re-proposing it. This append is automatic but **must be listed in the Phase-4 report** (see "Declined recipes recorded"). Use this exact form:

    ```
    ## Declined recipe: <name>
    The team removed this auto-mined skill. Do not re-propose it.
    ```
- **Boy Scout Rule**: update the priority list based on newly found debt
- **LEARNINGS.md** (root file, no longer in CLAUDE.md): append any new lessons — never overwrite existing entries

Do NOT touch the Codebase Context or Repository Structure sections unless a structural change was found (e.g., a new project layer, a renamed project, a migrated framework).

### 3b: Update TECH_DEBT.md

For each resolved item found in Phase 2, propose deletion of its `## DEBT-NNN` block.
For each new item found, propose a new block using the standard per-item format.
For each item whose recommended fix has changed, propose an update to the Recommended fix section.

Reminder: items are per-block — to remove a resolved item, delete its `## DEBT-NNN` block. To add a new item, follow the template at the top of TECH_DEBT.md.

---

## Phase 4 — Final report

After all accepted changes are applied, output:

- **Sections updated in CLAUDE.md**: list each section and what changed (added / removed / updated)
- **Conventions added**: list with one-line summary each
- **Conventions removed or changed**: list with brief reason
- **TECH_DEBT items resolved**: list by ID and title
- **TECH_DEBT items added**: list by ID and title
- **Areas not re-analysed**: explicit list with reason (e.g., "no changes in last 3 months")
- **Declined recipes recorded**: list any `## Declined recipe:` blocks appended to `LEARNINGS.md` this run by the resurrection guard (or "none")
- **Required when skill set changed**: if any skill was added, removed, or updated during this rebootstrap, run `/generate-copilot` now — do not merely suggest it. This regenerates `.github/skills/` and `AGENTS.md`'s Common Tasks list so Copilot CLI and AGENTS.md-native tools stay in sync with the current skill set.
