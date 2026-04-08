Refactor code in this .NET codebase without changing behavior.

Read CLAUDE.md before starting. Every decision must comply with the conventions documented there.

## Input
$ARGUMENTS

## Execution

### Step 1 — Verify starting state
- Run `dotnet build` — must compile cleanly
- Run `dotnet test` — all tests must pass
- If tests don't exist for the code being refactored, write baseline tests FIRST (see Step 2)

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
Apply Boy Scout Rule improvements from CLAUDE.md to every file you touched.

### Step 5 — Verify final state
- Run full `dotnet build` — clean compilation
- Run full `dotnet test` — all tests pass (including any new baseline tests)
- Run `dotnet format --verify-no-changes` — style compliance
- No behavior should have changed

### Step 6 — Present
Before/after summary:
- What was refactored and why
- What patterns from CLAUDE.md were applied
- Test results confirming no behavior change
- Any TECH_DEBT.md items resolved
