---
description: "Behavior-preserving refactor workflow: verify the baseline is green first, add baseline tests if missing, refactor incrementally with build+test after each step, report a before/after summary with net LOC delta."
argument-hint: "[target code and goal]"
---

<!-- @stack:intro -->

## Input
$ARGUMENTS

## Execution

### Step 1 — Verify starting state
<!-- @stack:verify-pre -->

### Step 2 — Baseline / characterization tests (if needed)
If the code you're refactoring has no test coverage, pin its **current** behavior first — use the `add-tests` skill's **Characterization mode**:
<!-- @stack:characterization -->
- Run them — they must pass against the current code. They are the safety net for the refactor.
<!-- @stack:halt-domain -->

### Step 3 — Refactor
- Stay within the blast radius — only change what's needed
- Make changes incrementally, not all at once
<!-- @stack:verify-each -->
- If tests fail, the refactor introduced a behavior change — fix it or revert

### Step 4 — Boy Scout
Apply Boy Scout Rule (CLAUDE.md > Boy Scout Rule) to every file you touched.

### Step 5 — Verify final state
<!-- @stack:verify-final -->

### Step 6 — Wrap up
@.claude/workflow.md

### Step 7 — Present
Before/after summary: what was refactored and why, what CLAUDE.md patterns were applied, **net LOC delta**, test results confirming no behavior change, any TECH_DEBT.md items resolved. Per CLAUDE.md > Leanness, a refactor that grows the codebase needs an explicit reason in the summary.
