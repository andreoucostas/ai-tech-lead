---
description: "Tech-debt workflow: match TECH_DEBT.md entries for an area, confirm each still exists in code, fix or defer with rationale, update the register. Invoke for debt-cleanup requests."
argument-hint: "[area or DEBT-ID]"
---

Find and fix tech debt in a specific area of this Angular codebase. Read TECH_DEBT.md before starting (CLAUDE.md is already loaded).

## Input
$ARGUMENTS

If no area specified, show a summary of TECH_DEBT.md grouped by area and ask which to tackle.

If TECH_DEBT.md is empty or contains only the template placeholder, run a fresh scan of the specified area (or the most actively changed area if none specified) and populate the register before proceeding.

## Execution

### Step 1 — Assess
- Read TECH_DEBT.md and find all items in the specified area
- Read the affected files to confirm the debt still exists (it may have been fixed already)
- For each item, recommend: **fix now** (bundleable into current work) or **defer** (needs dedicated effort)
- Present the assessment before proceeding

### Step 2 — Fix
For each item marked "fix now":
- Verify existing tests pass before touching anything
- Apply the fix
- Run `ng build`, `ng test --watch=false --browsers=ChromeHeadless`, and `ng lint` (if configured) after each fix
- If no tests exist for the affected code, write baseline tests first

### Step 3 — Update the register
- Remove resolved items from TECH_DEBT.md — items are per-block: to remove a resolved item, delete its `## DEBT-NNN` block. To add a new item, follow the template at the top of TECH_DEBT.md.
- Update the "Trojan Horse Opportunities" section if feature area groupings changed
- If you discovered new debt during the fix, add it to the register using the per-block format

### Step 4 — Boy Scout
Apply Boy Scout Rule (CLAUDE.md > Boy Scout Rule) to every file touched during the fix.

### Step 5 — Wrap up
@.claude/workflow.md

### Step 6 — Report
- What was fixed and what was deferred (with reason)
- Test results
- Updated TECH_DEBT.md diff
