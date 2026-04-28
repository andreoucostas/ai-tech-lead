Review code as a senior tech lead. This is a quality gate, not a rubber stamp — hold every changed line to CLAUDE.md > Conventions.

## Input
$ARGUMENTS

If no specific files or PR given, review the most recent uncommitted changes (both staged and unstaged).

## Execution

### Check 1 — Correctness & Convention Compliance
For each changed file:
- Does the code do what it claims to do?
- Does it follow every convention in CLAUDE.md?
- Are there edge cases or failure modes not handled?
- Is the error handling appropriate?
- Are there security concerns (injection, data exposure, auth bypass)?

### Check 2 — Test Quality & Coverage
- Do tests exist for the changed behavior?
- Do the tests verify behavior, not implementation details?
- Are test names descriptive (MethodName_Scenario_ExpectedResult)?
- Would the tests catch a regression if the code was changed?
- Are there missing test cases (edge cases, error paths, boundary conditions)?

### Check 3 — Verify
Run the test suite yourself to verify the code passes:
- Run `dotnet build` — must compile cleanly
- Run `dotnet test` — all tests must pass
- Do not trust that the code being reviewed already passes. Verify it.

### Check 4 — Architecture & Debt Trajectory
- Does this change move the codebase toward or away from the target architecture in CLAUDE.md?
- Does it introduce new tech debt? If so, flag it for TECH_DEBT.md.
- Does it resolve existing tech debt? If so, flag the TECH_DEBT.md entry for removal.
- Was the Boy Scout Rule applied to touched files?

## Output Format

```
## Review: [scope]

### Verdict: APPROVE | REQUEST CHANGES

### Issues
| # | Severity | File | Line(s) | Issue | Suggestion |
|---|----------|------|---------|-------|------------|

### Test Coverage
- Covered: ...
- Missing: ...

### Architecture Notes
- Debt trajectory: improving / neutral / degrading
- Boy Scout applied: yes / no

### Convention Violations
List any deviations from CLAUDE.md conventions.
```

Be direct. Do not praise code for meeting baseline expectations. Only call out what's good if it's genuinely above the bar.
