Diagnose and fix a bug in this .NET codebase.

Read CLAUDE.md before starting. Every decision must comply with the conventions and patterns documented there.

## Input
$ARGUMENTS

## Execution

### Step 1 — Diagnose
- Read the relevant code and any existing tests
- Identify the root cause — not just the symptom
- Determine the blast radius (what other code could be affected?)
- State the root cause and your fix strategy before writing code

### Step 2 — Write a failing regression test FIRST
Before touching any production code:
- Write a test that reproduces the bug
- Run it — confirm it fails for the right reason
- This test becomes the proof that the fix works

### Step 3 — Fix
- Apply the minimal fix that addresses the root cause
- Do not refactor unrelated code in the same change (that's what /refactor is for)

### Step 4 — Verify
- Run the regression test — it must now pass
- Run the full related test suite — nothing else should break
- Run `dotnet build` to confirm clean compilation

### Step 5 — Boy Scout
Apply Boy Scout Rule improvements (from CLAUDE.md) to files within the blast radius only. Do not boy-scout unrelated files in a bug fix.

### Step 6 — Report
- Root cause: what was wrong and why
- Fix: what you changed
- Regression test: what the new test covers
- Blast radius: what else was affected
- Flag any TECH_DEBT.md updates needed
