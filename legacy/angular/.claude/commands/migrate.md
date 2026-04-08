Migrate this project from AI Tech Lead Framework v3 to v4. This is a one-time migration that consolidates 9 documents into 3, fixes command/hook formats, and preserves all existing work.

## Input
$ARGUMENTS

## CRITICAL: Do not delete or overwrite any existing content. This migration PRESERVES everything.

## Execution

### Step 1 — Inventory existing v3 artifacts

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

Report what was found before proceeding.

### Step 2 — Archive v3 documents that will be folded into CLAUDE.md

Move these files to `docs/v3-archive/` (do NOT delete them):
- `CODEMAP.md` → `docs/v3-archive/CODEMAP.md`
- `docs/CONVENTIONS.md` → `docs/v3-archive/CONVENTIONS.md`
- `docs/adr/*.md` → `docs/v3-archive/adr/`
- `docs/TESTING.md` → `docs/v3-archive/TESTING.md`
- `docs/exemplars/` → `docs/v3-archive/exemplars/`
- `docs/prompts/` → `docs/v3-archive/prompts/`
- `.claude/hooks.json` → `docs/v3-archive/hooks.json` (if exists)

If `.claude/skills/` exists, move to `docs/v3-archive/skills/`.

### Step 3 — Enrich CLAUDE.md with content from archived documents

Read the existing CLAUDE.md thoroughly. It already has populated content from the v3 bootstrap. Now MERGE (not replace) content from the archived documents:

**From CODEMAP.md → into CLAUDE.md "File Structure" section:**
- If CLAUDE.md already has a Solution/File Structure section, merge the CODEMAP content into it
- If not, create a "## File Structure" section and paste the CODEMAP content
- Preserve mermaid diagrams

**From docs/CONVENTIONS.md → into CLAUDE.md "Conventions" section:**
- For each convention in the CONVENTIONS doc, check if it already exists in CLAUDE.md
- Add any conventions that are missing, with their do/don't examples converted to rationale format
- Do not duplicate rules that already exist

**From docs/adr/*.md → into CLAUDE.md "Architecture Decisions" section:**
- If CLAUDE.md already has an Architecture Decisions section, merge new ADRs into it
- If not, create "## Architecture Decisions" section
- Preserve the full ADR content (Status, Context, Decision, Consequences, Review Notes)

**From docs/TESTING.md → into CLAUDE.md "Conventions > Testing" subsection:**
- Merge testing strategy into the Testing conventions
- Preserve any exemplar references as "see docs/v3-archive/exemplars/ for examples"

### Step 4 — Add v4 sections to CLAUDE.md

If these sections don't already exist in CLAUDE.md, add them:

**## Agentic Workflow** — add the full agentic workflow section:
```
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

**## What We've Learned** — add at the bottom if missing:
```
<!-- This section evolves over time. Add entries when you discover what works and what doesn't. -->
<!-- Format: [date] observation -->
```

### Step 5 — Install v4 commands

The new `.claude/commands/` files should already be in place (they were copied from the template). If any v3 commands or skills exist that have project-specific customisations, merge those customisations into the v4 command files.

Verify these commands exist in `.claude/commands/`:
- bootstrap.md, feature.md, fix.md, review.md, refactor.md, test.md, design.md, debt.md, docs-sync.md, generate-copilot.md, migrate.md

### Step 6 — Install v4 hooks

Create `.claude/settings.json` with the correct hooks format (replacing any v3 hooks.json):

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

### Step 7 — Preserve existing artifacts

These files should NOT be touched — they're already in v4 format:
- `TECH_DEBT.md` — keep as-is (same format in v3 and v4)
- `.github/copilot-instructions.md` — keep as-is (will be regenerated later via `/generate-copilot`)
- `.husky/` and lint-staged config — keep as-is (pre-commit hooks are separate from Claude Code hooks)
- `docs/exemplars/` — referenced from archive, still usable

### Step 8 — Regenerate copilot-instructions.md

Now that CLAUDE.md has been enriched, run the `/generate-copilot` workflow to produce an updated `.github/copilot-instructions.md` that reflects the consolidated CLAUDE.md.

### Step 9 — Report

Show the user:
- What files were archived (with paths)
- What content was merged into CLAUDE.md (section by section)
- What new sections were added to CLAUDE.md
- What commands are now available
- What hooks are configured
- Run `git diff --stat` to show all changes

Remind the user to:
1. Review the updated CLAUDE.md — especially merged sections
2. Review the regenerated copilot-instructions.md
3. Try `/feature` or `/fix` on a small task to verify the v4 workflow
4. Commit all changes in one commit: "Migrate to AI Tech Lead Framework v4"
