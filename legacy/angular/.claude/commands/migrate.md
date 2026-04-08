Migrate this project from AI Tech Lead Framework v3 to v4. This is a one-time migration that consolidates multiple documents into 3, fixes command/hook formats, and preserves all existing work.

## Input
$ARGUMENTS

## CRITICAL: Do not delete or overwrite any existing content. This migration PRESERVES everything.

## Execution

### Step 1 — Pre-flight checks

Before doing anything:

1. **Check for uncommitted changes** — run `git status`. If there are uncommitted changes, STOP and tell the user to commit or stash first. Migration touches many files and must be reversible.
2. **Recommend a branch** — tell the user: "I recommend running this on a new branch: `git checkout -b migrate-to-v4`. That way you can review everything and merge when you're satisfied." Wait for confirmation before proceeding.
3. **Verify v3 artifacts exist** — check for at least 2 of these files. If fewer than 2 exist, this project may not have v3 set up — warn the user and confirm before proceeding:
   - `CLAUDE.md`
   - `CODEMAP.md`
   - `docs/CONVENTIONS.md`
   - `docs/TESTING.md`
   - `docs/adr/*.md`
4. **Locate the project root** — find `angular.json` (or `nx.json`/`project.json` for Nx). All paths are relative to this root.

### Step 2 — Inventory existing v3 artifacts

Read and catalogue what exists. Check for each of these files and note which are present and populated:

- `CLAUDE.md` — the main instruction file
- `.github/copilot-instructions.md` — Copilot rules
- `CODEMAP.md` — navigation guide with mermaid diagrams
- `docs/adr/*.md` — Architecture Decision Records
- `docs/CONVENTIONS.md` — do/don't examples
- `docs/TESTING.md` — testing strategy
- `docs/exemplars/` — example test files
- `TECH_DEBT.md` — debt register
- `.husky/` or `.lintstagedrc` — pre-commit hooks
- `docs/prompts/*.md` — Copilot Chat prompt templates
- `.claude/skills/` — v3 skills (wrong format)
- `.claude/commands/` — v3 commands (may exist)
- `.claude/hooks.json` — v3 hooks (wrong format)

Report what was found before proceeding. Include file sizes for any file over 200 lines — this affects the merge strategy in Phase 2.

---

## Phase 1 — Automated file operations (safe, reversible)

These steps move files and install new configuration. No content is merged or modified.

### Step 3 — Archive v3 documents

Move these files to `docs/v3-archive/` (do NOT delete them):
- `CODEMAP.md` → `docs/v3-archive/CODEMAP.md`
- `docs/CONVENTIONS.md` → `docs/v3-archive/CONVENTIONS.md`
- `docs/adr/*.md` → `docs/v3-archive/adr/`
- `docs/TESTING.md` → `docs/v3-archive/TESTING.md`
- `docs/exemplars/` → `docs/v3-archive/exemplars/`
- `docs/prompts/` → `docs/v3-archive/prompts/`
- `.claude/hooks.json` → `docs/v3-archive/hooks.json` (if exists)

If `.claude/skills/` exists, move to `docs/v3-archive/skills/`.

Only move files that actually exist. Skip missing files silently.

### Step 4 — Install v4 commands

The new `.claude/commands/` files should already be in place (copied from the template). Verify these commands exist in `.claude/commands/`:
- bootstrap.md, feature.md, fix.md, review.md, refactor.md, test.md, design.md, debt.md, docs-sync.md, generate-copilot.md, migrate.md

If any v3 commands or skills have project-specific customisations, note them for the user — they may want to port those customisations into the v4 commands manually.

### Step 5 — Install v4 hooks

Create `.claude/settings.json` with the correct hooks format:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "command": "bash -c 'if [[ \"$CLAUDE_FILE_PATH\" == *.ts ]]; then npx tsc --noEmit 2>&1 | tail -20; fi'"
      }
    ]
  }
}
```

**Preserving existing hooks:**
- `.husky/` and lint-staged config are NOT touched — they're pre-commit hooks, separate from Claude Code hooks.
- If `.claude/hooks.json` existed (v3 format), it has been archived. Note what hooks it contained in the report so the user can verify nothing important was lost. The v4 hook (type-check on `.ts` file write) replaces the most common v3 hook pattern.

### Step 6 — Preserve untouched artifacts

These files are NOT modified:
- `TECH_DEBT.md` — keep as-is (same format in v3 and v4)
- `.github/copilot-instructions.md` — keep for now (will be regenerated after Phase 2)
- `.husky/` and lint-staged config — pre-commit hooks are separate from Claude Code hooks

### Step 7 — Phase 1 checkpoint

Run `git diff --stat` and show the user what Phase 1 changed. Tell them:

> "Phase 1 complete — files archived and v4 commands/hooks installed. Nothing has been merged yet. Your v3 content is safe in `docs/v3-archive/`.
>
> Phase 2 will merge your v3 document content into CLAUDE.md. I'll show you each section before merging so you can review. Ready to proceed?"

**Wait for the user to confirm before starting Phase 2.**

---

## Phase 2 — Content merge (interactive, developer reviews each section)

This phase reads each archived v3 document and merges its content into CLAUDE.md. Each merge is presented to the developer for review before being applied.

**Merge principles:**
- **Deduplicate** — if content already exists in CLAUDE.md (from v3 bootstrap), don't add it again
- **Summarise large content** — if a v3 document is over 200 lines, summarise key points rather than pasting verbatim. Reference the archive for full detail: "See `docs/v3-archive/[file]` for full detail."
- **Preserve structure** — maintain CLAUDE.md's section hierarchy. Merge into existing sections, don't create parallel structures
- **Keep CLAUDE.md scannable** — target under 300 lines total. If merging would exceed this, summarise more aggressively and reference archives

### Step 8 — Merge CODEMAP into File Structure

Read `docs/v3-archive/CODEMAP.md`. Present the key content to the user:

> "Here's what your CODEMAP contains: [summary]. I'll merge this into CLAUDE.md's **File Structure** section. Here's what the merged section will look like:
>
> [show proposed merged content]
>
> Does this look right? Any changes before I apply it?"

Apply after confirmation. Preserve mermaid diagrams. If the CODEMAP is large, include the diagram and key navigation notes, and add: "Full module inventory: see `docs/v3-archive/CODEMAP.md`."

### Step 9 — Merge CONVENTIONS into Conventions

Read `docs/v3-archive/CONVENTIONS.md`. For each convention in the v3 doc:
- Check if it already exists in CLAUDE.md's Conventions section
- Collect only the conventions that are **missing** from CLAUDE.md

Present to the user:

> "Your v3 CONVENTIONS.md has [N] conventions. [M] already exist in CLAUDE.md. Here are the [N-M] that would be added:
>
> [list each new convention with its do/don't converted to rationale format]
>
> Should I add all of these, or would you like to adjust any?"

Apply after confirmation.

### Step 10 — Merge ADRs into Architecture Decisions

Read `docs/v3-archive/adr/*.md`. For each ADR:
- Check if the decision is already recorded in CLAUDE.md
- Collect missing ADRs

Present to the user:

> "Found [N] ADRs in your v3 archive. Here's a summary of each:
>
> [for each ADR: title, decision, one-line consequence]
>
> I'll add the missing ones to CLAUDE.md's **Architecture Decisions** section. If any ADR is lengthy, I'll include the decision and key consequences, with a reference to the full ADR in `docs/v3-archive/adr/`.
>
> Look right?"

Apply after confirmation.

### Step 11 — Merge TESTING into Testing conventions

Read `docs/v3-archive/TESTING.md`. Compare with CLAUDE.md's Testing subsection under Conventions.

Present to the user:

> "Your v3 TESTING.md contains: [summary of testing strategy, frameworks, patterns].
>
> CLAUDE.md's Testing section already covers: [summary of what's there].
>
> Here's what I'd add: [list additions]
>
> If your v3 setup included test exemplars in `docs/exemplars/`, they're now at `docs/v3-archive/exemplars/` — I'll add a reference: 'See `docs/v3-archive/exemplars/` for example test files.'"

Apply after confirmation.

### Step 12 — Add v4 Agentic Workflow section

If CLAUDE.md doesn't already have an Agentic Workflow section, add it:

```
## Agentic Workflow

When given any task, follow this execution model:

### 1. Classify the intent
Determine what the developer is asking for:
- **Feature**: new functionality → follow the feature workflow
- **Bug fix**: something is broken → follow the fix workflow
- **Refactor**: restructure without changing behavior → follow the refactor workflow
- **Investigation/design**: need to think before coding → follow the design workflow
- **Test**: add or improve test coverage → follow the test workflow
- **Debt cleanup**: address known tech debt → follow the debt workflow

If the intent is ambiguous, ask before proceeding.

### 2. Plan before coding
For any non-trivial task:
- List the files you'll create or modify
- State the order of operations
- Identify what tests will verify success
- State the plan, then execute

### 3. Execute in verified subtasks
For features and complex changes, decompose into ordered subtasks:
1. Models/interfaces and service layer + tests
2. State management changes (store/signals/service) + tests
3. Component implementation + tests
4. E2E or integration verification

Each subtask must leave the codebase compilable and test-passing.
Run `ng build` and `ng test --watch=false --browsers=ChromeHeadless` after each subtask. Fix failures before moving on.

### 4. Boy Scout every touched file
Check the Boy Scout Rule list. Apply relevant improvements to every file you modify.

### 5. Self-review before presenting
Before presenting work as complete:
- Review your changes against the Conventions section
- Verify all tests pass
- Check if the change introduces a new pattern → flag that this file needs updating
- Check if the change resolves a TECH_DEBT.md item → flag for removal
- Check if the change contradicts any convention → ask whether to update the convention or change the implementation

### 6. Flag documentation drift
At the end of your response, note if:
- A new pattern was introduced that should be documented here
- A TECH_DEBT.md entry was resolved or a new one discovered
- copilot-instructions.md needs regeneration (run `/generate-copilot`)
```

### Step 13 — Add "What We've Learned" section

If missing from CLAUDE.md, add at the bottom:

```
## What We've Learned

<!-- This section evolves over time. Add entries when you discover what works and what doesn't. -->
<!-- Format: [date] observation -->
```

### Step 14 — Regenerate copilot-instructions.md

Now that CLAUDE.md has been enriched, run the `/generate-copilot` workflow to produce an updated `.github/copilot-instructions.md` that reflects the consolidated CLAUDE.md.

---

## Step 15 — Final report

Show the user:
- What files were archived (with paths)
- What content was merged into CLAUDE.md (section by section, with line counts)
- What new sections were added to CLAUDE.md
- What commands are now available
- What hooks are configured (and what v3 hooks were replaced, if any)
- Final CLAUDE.md line count
- Run `git diff --stat` to show all changes

Remind the user to:
1. Review the updated CLAUDE.md — especially merged sections
2. Review the regenerated copilot-instructions.md
3. Try `/feature` or `/fix` on a small task to verify the v4 workflow
4. Commit all changes: `git add -A && git commit -m "Migrate to AI Tech Lead Framework v4"`
5. If on a branch: merge to main when satisfied
