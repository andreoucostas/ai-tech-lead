Refactor code in this Angular codebase without changing behavior. Every decision must comply with the conventions in CLAUDE.md.

## Input
$ARGUMENTS

## Execution

### Step 1 — Verify starting state
Run `ng build` and `ng test --watch=false --browsers=ChromeHeadless`. Both must pass before changing anything. If tests don't exist for the code being refactored, write baseline tests FIRST (see Step 2).

### Step 2 — Baseline / characterization tests (if needed)
If the code you're refactoring has no test coverage, pin its **current** behavior first — use the `add-tests` skill's **Characterization mode**:
- Generate the spec skeleton, run it once to capture the actual outputs, and assert those (never invent expected values); label them characterization, not correctness.
- Run them — they must pass against the current code. They are the safety net for the refactor.
- **Auth / security / money code: HALT and ask the developer to confirm the captured behavior is correct before trusting it** — a characterization spec can otherwise lock in an insecure or wrong behavior as "approved."

### Step 3 — Refactor
- Stay within the blast radius — only change what's needed
- Make changes incrementally, not all at once
- After each meaningful change, run `ng build` and `ng test --watch=false --browsers=ChromeHeadless`
- If tests fail, the refactor introduced a behavior change — fix it or revert

### Step 4 — Boy Scout
Apply Boy Scout Rule (CLAUDE.md > Boy Scout Rule) to every file you touched.

### Step 5 — Verify final state
Run `ng build`, `ng test --watch=false --browsers=ChromeHeadless`, and `ng lint` (if configured). All must pass. No behavior should have changed.

### Step 6 — Wrap up
@.claude/workflow.md

### Step 7 — Present
Before/after summary: what was refactored and why, what CLAUDE.md patterns were applied, **net LOC delta**, test results confirming no behavior change, any TECH_DEBT.md items resolved. Per CLAUDE.md > Leanness, a refactor that grows the codebase needs an explicit reason in the summary.
