Refresh the AI Tech Lead framework configuration for this .NET codebase. Use when conventions have drifted, new patterns have emerged, or the team wants to re-align after months of evolution.

This is NOT a replacement for `/bootstrap`. It assumes CLAUDE.md is already populated and merges updates into it rather than overwriting.

## Input
$ARGUMENTS

---

## Pre-flight checks

Before doing anything else:

1. **Check CLAUDE.md is populated** — read CLAUDE.md. If it still contains the phrase `DEFAULTS BELOW`, abort immediately and tell the user:
   > "CLAUDE.md still contains template defaults. Run `/bootstrap` first to populate it from your codebase, then return to `/rebootstrap` once the framework is set up."

2. **Confirm git is available** — this command uses git history to focus analysis. If the repo has no commits, skip the git log step and proceed with a full scan.

---

## Pre-step — What changed since last time?

Run: `git log --since="3 months ago" --stat`

From this output, identify the **actively changed areas** — files and directories that have seen the most edits in the past 3 months. These are the highest-priority areas for re-analysis. List them before proceeding; they focus the analysis passes below.

---

## Phase 1 — Re-analysis

Perform the same six analysis passes as `/bootstrap` (A1–A6), but **scoped to the actively changed areas** identified above. For unchanged areas, carry forward existing CLAUDE.md content unless you spot an obvious contradiction.

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
- **Common Tasks**: update patterns to reflect current codebase reality
- **Boy Scout Rule**: update the priority list based on newly found debt
- **What We've Learned**: append any new lessons — do not overwrite existing entries

Do NOT touch the Codebase Context or Solution Structure sections unless a structural change was found (e.g., a new project layer, a renamed project, a migrated framework).

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
- **Recommended next step**: if new patterns were introduced, suggest running `/generate-copilot` to refresh copilot-instructions.md
