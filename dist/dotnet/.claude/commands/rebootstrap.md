---
description: "Re-align the framework after drift: refresh conventions, hazards, and mined skills against the current codebase; respects declined-recipe history in LEARNINGS.md. Developer-initiated only."
disable-model-invocation: true
---

Refresh the AI Tech Lead framework configuration for this repository's currently evidenced .NET and/or warehouse-SQL profiles. Use when conventions have drifted, new patterns have emerged, or the team wants to re-align after months of evolution.

This is NOT a replacement for `/bootstrap`. It assumes CLAUDE.md is already populated and merges updates into it rather than overwriting.

## Input
$ARGUMENTS

---

## Pre-flight checks

Before doing anything else:

1. **Check CLAUDE.md is populated** — read CLAUDE.md. If it still contains the marker `BOOTSTRAP_PENDING`, abort immediately and tell the user:
   > "CLAUDE.md has not been bootstrapped (BOOTSTRAP_PENDING marker still present). Run `/bootstrap` first to populate it from your codebase, then return to `/rebootstrap` once the framework is set up."

2. **Confirm git is available** — this command uses git history to focus analysis. If the repo has no commits, skip the git log step and proceed with a full scan.

3. **Re-select profiles from the Git root** — apply `/bootstrap`'s current shared evidence rules
   again; do not carry a profile forward merely because this distribution is installed. A
   warehouse-only repository is valid. Refresh the six-row Verification Commands inventory only
   from current evidence, preserving explicit `not available` rows.

4. **Establish ownership and dismissal boundaries** — require a valid root `framework-ownership.json` `paths` inventory and exclude every `framework-owned/overwritten` path from shared A8 evidence. A `mixed` path may contribute only consumer-authored evidence corroborated outside framework-owned paths. Read and freeze every row under `TECH_DEBT.md > ## Dismissed proposals` before analysis.

---

## Pre-step — What changed since last time?

Run: `git log --since="3 months ago" --stat`

From this output, identify the **actively changed areas** — files and directories that have seen the most edits in the past 3 months. These are the highest-priority areas for re-analysis. List them before proceeding; they focus the analysis passes below.

---

## Phase 1 — Re-analysis

Perform only the current `/bootstrap` passes for the re-selected profiles: .NET A1–A7 when .NET is
present, warehouse-SQL W1–W3 when warehouse evidence is present, and `shared A8` once when at least
one profile exists. Scope them to the actively changed areas identified above. Never dispatch an
absent application profile. For unchanged areas, carry forward existing CLAUDE.md content unless
you spot an obvious contradiction.

### .NET passes (only when the .NET profile is selected)

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

### Warehouse-SQL passes (only when the warehouse-SQL profile is selected)

Re-run W1–W3 using their current definitions in `/bootstrap`: structure/dependency mapping, load
semantics/idempotency, and validation/deployment evidence. Do not translate them into application
layers or commands.

### Shared A8: Project-Specific Skill Discovery
Re-run the discovery pass (same definition as `bootstrap.md`'s `### A8:`), scoped to the actively changed areas and any new naming clusters that appeared in the git log period. Apply its `framework-ownership.json` boundary before inspecting candidate evidence: no `framework-owned/overwritten` path may establish recurrence, tribal knowledge, or an exemplar. **Before proposing candidates**, check `LEARNINGS.md` for `## Declined recipe:` entries and skip anything that matches — the team removed those deliberately.

---

## Phase 2 — Delta synthesis

Compare findings against the current CLAUDE.md:

1. **New conventions** — patterns that now exist in the codebase but aren't documented
2. **Stale conventions** — documented rules that the codebase no longer follows (removed, replaced, or contradicted)
3. **New debt** — issues found that are neither active nor represented under `## Dismissed proposals` in TECH_DEBT.md
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
- **Conventions**: add new conventions, update stale ones, remove obsolete ones; keep the fixed
  build/test/format/lint/migration/deploy/data-validation command inventory aligned to exact current
  evidence, recompute its execution-policy column, retain `not available` for every unsupported
  category, and keep migration/deploy `manual/CI-only` unless the exact invocation is evidenced as
  non-mutating validation/dry-run; any other execution requires explicit developer authorization
  against a known target
- **Architecture Decisions**: add new decisions; mark old decisions as superseded if applicable
- **Common Tasks**: update patterns to reflect current codebase reality. The two changes below are proposed through the **same diff-and-confirm gate** as every other Phase-3 change — show the before/after and wait for the user, do not apply silently:
  - **Exemplar re-pinning**: for any instance-shaped skill (`add-endpoint`, `add-entity`, `register-service`, `add-warehouse-load`, any mined `add-X`) whose pinned exemplar file no longer exists or a clearly cleaner instance now exists — propose updating the exemplar prose line. Confirm the new path resolves (Verification Rule #1).
  - **New A8 candidates**: if the discovery pass returned new candidates this run, apply the same quality-gate and exemplar-grounding rules from `/bootstrap` Phase 3a, and propose each as a diff.
  - **Resurrection guard** (bookkeeping side-effect, not a diff chunk): if any skill with `origin: discovered` in its frontmatter has been deleted from `.claude/skills/` since the last run, append a declined-recipe block to `LEARNINGS.md` so the discovery pass stops re-proposing it. This append is automatic but **must be listed in the Phase-4 report** (see "Declined recipes recorded"). Use this exact form:

    ```
    ## Declined recipe: <name>
    The team removed this auto-mined skill. Do not re-propose it.
    ```
  - **Disabled shipped skills:** move a deliberately removed shipped skill to `.claude/disabled-skills/<name>` and record `## Disabled framework skill: <name>` plus `Disabled: <date>` and `Reason: <why>` in `LEARNINGS.md`. Do not merely delete it: update refreshes the inactive copy without reactivating it, and rebootstrap may explicitly propose restoring it.
- **LEARNINGS.md** (root file, no longer in CLAUDE.md): append any new lessons — never overwrite existing entries

Do NOT touch the Codebase Context or Repository Structure sections unless a structural change was found (e.g., a new project layer, a renamed project, a migrated framework).

### 3b: Update TECH_DEBT.md

For each resolved item found in Phase 2, propose deletion of its `## DEBT-NNN` block.
For each new item found, derive stable key `<area>::<claim-slug>` and compare its problem, consequence, and path/symbol scope with `## Dismissed proposals`. Suppress a matching dismissal. Reopen only for materially changed evidence, preserving the prior row and adding `Reopens dismissal: <key>` plus `Evidence delta: <specific change>` to the proposed active block.
For each item whose recommended fix has changed, propose an update to the Recommended fix section.

If the developer rejects a proposed new item, distinguish **Reject this run** from **Dismiss as not debt**. Only the latter, with a developer-supplied reason, appends a dismissal row (key, affected paths/symbols, evidence reviewed, date, reason). Never turn defer or silence into a dismissal, and never delete prior dismissal rows.

Reminder: items are per-block — to remove a resolved item, delete its `## DEBT-NNN` block. To add a new item, follow the template at the top of TECH_DEBT.md.

### 3c: Re-confirm Known Hazard Areas

`FRAMEWORK-CONTEXT.md > Known Hazard Areas` is the list the agent consults for blast radius before planning any change in a listed area — so a row that is wrong is worse than a row that is missing. Re-align it in three passes, then propose the result through the **same diff-and-confirm gate** as 3a and 3b.

1. **Referential drift** — for every existing row, check that the paths named in `Area / file(s)` still resolve. A row pointing at a deleted, renamed, or extracted file is stale no matter how recently it was reviewed, and nothing else catches this: the session-start staleness warning reads only the `Reviewed` date. List each unresolved row and ask whether to re-point it at the current path or retire it.
2. **New candidates** — from this run's Tier-1 architectural risks and any domain-invariant or security findings, identify hazards not already listed. Ask about each in the same form `/bootstrap` Phase 3d-bis uses:
   > "I found a potential hazard in [Area / file]: [one plain sentence describing the specific risk]. Is this (a) a confirmed risk to track, (b) not actually a risk in this codebase, or (c) you're not sure?"
3. **Ageing rows** — list rows whose `Reviewed` date is more than ~90 days old and ask the developer to re-confirm each.

Ask all three passes' questions in a **single message** (not dripped), with a "skip all — leave every row as it is" escape at the end. Map the answers to the same statuses `/bootstrap` writes:

- **(a) confirmed** → `Status = [VERIFIED]`, `Reviewed` = today in ISO `YYYY-MM-DD`
- **(b) not a risk** → `Status = [REVIEWED: not a hazard — YYYY-MM-DD]` (keep the row — it is kept for auditability, not dropped)
- **(c) unsure / skip all** → leave an existing row's status and date exactly as they are; a *new* candidate is written `[UNVERIFIED]`

When writing or changing a row, keep the Status cell as bare text with no Markdown code delimiters,
and require `Area / file(s)` to include at least one repository-root-relative path that resolves.

**Do not upgrade an `[UNVERIFIED]` row yourself** — only the developer can, and only by answering its question. Never re-date a row the developer did not answer: a fresh `Reviewed` date on an unconfirmed row manufactures precisely the false confidence this table exists to prevent. Keep the table tight (≤ ~12 rows); deeper items belong in TECH_DEBT.md.

If this command is ever run with no developer present to answer, take the "skip all" path — change nothing, and report the unanswered rows.

---

If any skill was added, removed, or updated, run `/generate-copilot` now, before the gate below, so
the skills mirror and `AGENTS.md` Common Tasks list are part of the checked artifact set.

## Deterministic completion gate

Run exactly one host-native framework check from the repository root:

Windows PowerShell 5.1 (Windows without `pwsh`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/docs-sync-check.ps1
```

PowerShell 7 (`pwsh`):

```powershell
pwsh -NoProfile -File scripts/docs-sync-check.ps1
```

Bash (Linux or Windows Git Bash):

```bash
bash scripts/docs-sync-check.sh
```

PASS requires exit code 0 and the final line `All AI Tech Lead framework checks passed.`. Repair
only artifacts this workflow changed, then rerun. If a remaining failure is outside this workflow's
scope, report it and **do not claim completion**. If neither checker can execute or its result cannot
be examined, report `CANT-VERIFY` with the reason and **do not claim completion**.

---

## Phase 4 — Final report

After all accepted changes are applied, output:

- **Sections updated in CLAUDE.md**: list each section and what changed (added / removed / updated)
- **Conventions added**: list with one-line summary each
- **Conventions removed or changed**: list with brief reason
- **TECH_DEBT items resolved**: list by ID and title
- **TECH_DEBT items added**: list by ID and title
- **Hazard areas re-confirmed**: rows verified, re-pointed, retired, or left unanswered this run (or "none")
- **Areas not re-analysed**: explicit list with reason (e.g., "no changes in last 3 months")
- **Declined recipes recorded**: list any `## Declined recipe:` blocks appended to `LEARNINGS.md` this run by the resurrection guard (or "none")
- **Deterministic completion gate**: command run and PASS, failure, or CANT-VERIFY result; when the skill set changed, confirm `/generate-copilot` ran before this gate.
