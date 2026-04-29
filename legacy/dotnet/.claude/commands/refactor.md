Refactor code in this .NET codebase without changing behavior. Every decision must comply with the conventions in CLAUDE.md.

## Input
$ARGUMENTS

## Execution

### Step 1 — Verify starting state
Run `dotnet build` and `dotnet test`. Both must pass before changing anything. If tests don't exist for the code being refactored, write baseline tests FIRST (see Step 2).

### Step 2 — Baseline tests (if needed)
If the code you're refactoring has no test coverage:
- Write tests that capture the current behavior before changing anything
- Run them — they must pass against the current code
- These tests become the safety net for the refactor

### Step 3 — Refactor
- Stay within the blast radius — only change what's needed
- Make changes incrementally, not all at once
- After each meaningful change, run `dotnet build` and `dotnet test`
- If tests fail, the refactor introduced a behavior change — fix it or revert

### Step 4 — Boy Scout
Apply Boy Scout Rule (CLAUDE.md > Boy Scout Rule) to every file you touched.

### Step 5 — Verify final state
Run `dotnet build`, `dotnet test`, and `dotnet format`. All must pass. No behavior should have changed.

### Step 6 — Wrap up
@.claude/workflow.md

### Step 7 — Present
Before/after summary: what was refactored and why, what CLAUDE.md patterns were applied, **net LOC delta**, test results confirming no behavior change, any TECH_DEBT.md items resolved. Per CLAUDE.md > Leanness, a refactor that grows the codebase needs an explicit reason in the summary.
