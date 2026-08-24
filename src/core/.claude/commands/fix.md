---
description: "Bug-fix workflow: diagnose and reproduce first, use a red regression test when an evidenced harness exists, apply the minimal fix, and Boy Scout the blast radius only. Invoke for bugs, crashes, failing tests, and regressions."
argument-hint: "[bug description or failing test]"
---

<!-- @stack:intro -->

## Input
$ARGUMENTS

## Execution

### Step 1 — Diagnose
- Read the relevant code and any existing tests
- Identify the root cause — not just the symptom
- Determine the blast radius (what other code could be affected?)
- State the root cause and your fix strategy before writing code

### Step 2 — Reproduce before fixing
Before touching production code, derive the repository's applicable test harness and validation commands from CLAUDE.md, committed CI, scripts, manifests, and configuration.
- When an applicable harness exists, write a regression test that reproduces the bug and confirm it fails for the right reason before the fix. This test becomes the proof that the fix works.
- When no applicable harness or test command exists, reproduce the bug with the strongest evidenced validation, report tests as **not available**, and do not introduce a foreign harness solely for this fix.

### Step 3 — Fix
- Apply the minimal fix that addresses the root cause
- Do not refactor unrelated code in the same change (that's what `/refactor` is for)

### Step 4 — Verify
<!-- @stack:verify-cmds -->

### Step 5 — Boy Scout (blast radius only)
Apply Boy Scout Rule (CLAUDE.md > Boy Scout Rule) to files within the blast radius only. Do not boy-scout unrelated files in a bug fix.

### Step 6 — Wrap up
@.claude/workflow.md

### Step 7 — Report
- Root cause: what was wrong and why
- Fix: what you changed
- Regression test or strongest validation: what reproduced the bug and what verifies the fix (or why tests are **not available**)
- Blast radius: what else was affected
