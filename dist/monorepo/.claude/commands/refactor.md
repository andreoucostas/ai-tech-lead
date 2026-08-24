---
description: "Behavior-preserving refactor workflow: derive applicable verification from repository evidence, establish a green baseline, add characterization coverage where a harness exists, refactor incrementally, and report net LOC delta."
argument-hint: "[target code and goal]"
---

Refactor code in this repository without changing behavior. Select only the technologies evidenced in the target area; do not infer both application stacks from this framework distribution. Every decision must comply with the conventions in CLAUDE.md.

## Input
$ARGUMENTS

## Execution

### Step 1 — Verify starting state
Derive the exact **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation** commands for the target from CLAUDE.md, committed CI, scripts, manifests, and configuration. Run only applicable commands and establish a green baseline before changing anything; record every unsupported category as **not available**. Add baseline tests first only when the repository has an applicable harness (see Step 2).

### Step 2 — Baseline / characterization tests (if needed)
If the repository has an applicable test harness and the code you're refactoring has no coverage,
pin its **current** behavior first — use the `add-tests` skill's **Characterization mode**. If no
harness or test command is evidenced, report tests as **not available** and identify the strongest
existing validation you will use instead; do not introduce a foreign test stack just to refactor:
- Generate the test/spec skeleton, run it once to capture the actual outputs, and assert those (never invent expected values); label them characterization, not correctness.
- Run them — they must pass against the current code. They are the safety net for the refactor.
- **Money / ledger / idempotency / auth / security code: HALT and ask the developer to confirm the captured behavior is correct before trusting it** — a characterization test/spec can otherwise lock in a pre-existing financial bug or insecure behavior as "approved."

### Step 3 — Refactor
- Stay within the blast radius — only change what's needed
- Make changes incrementally, not all at once
- After each meaningful change, run the applicable repository-evidenced checks for the target; do not run commands for absent profiles
- If tests fail, the refactor introduced a behavior change — fix it or revert

### Step 4 — Boy Scout
Apply Boy Scout Rule (CLAUDE.md > Boy Scout Rule) to every file you touched.

### Step 5 — Verify final state
Run every applicable repository-evidenced **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation** command for the target. Applicable checks must pass; repeat **not available** for unsupported categories. No behavior should have changed.

### Step 6 — Wrap up
@.claude/workflow.md

### Step 7 — Present
Before/after summary: what was refactored and why, what CLAUDE.md patterns were applied, **net LOC delta**, test results or strongest evidenced validation confirming no behavior change (including why tests are **not available**), and any TECH_DEBT.md items resolved. Per the framework rules (`.github/instructions/framework-rules.instructions.md` › Leanness; `AGENTS.md` › Leanness on AGENTS.md-native tools), a refactor that grows the codebase needs an explicit reason in the summary.
