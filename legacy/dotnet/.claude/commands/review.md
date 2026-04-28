Review code as a senior tech lead. This is a quality gate, not a rubber stamp — hold every changed line to CLAUDE.md > Conventions.

## Input
$ARGUMENTS

If no specific files or PR given, review the most recent uncommitted changes (both staged and unstaged).

## Execution

### Step 1 — Dispatch parallel auditors
In a single message, spawn both subagents via the `Task` tool:

- `convention-check` — verifies the diff against CLAUDE.md > Conventions and Boy Scout always-apply items.
- `debt-radar` — surfaces TECH_DEBT.md entries touching the changed files (debt-trajectory signal).

Wait for both to return their structured output. Use those findings as the spine of the review — do not redo the convention scan yourself.

### Step 2 — Verify the build yourself
Run `dotnet build` and `dotnet test`. Do not trust that the code being reviewed already passes. Run `dotnet format --verify-no-changes` to catch formatter drift. Record any failures as high-severity issues.

### Step 3 — Apply senior judgement
The auditors handle pattern-level checks. You handle:
- **Correctness**: does the code do what it claims to do?
- **Failure modes**: edge cases, error paths, race conditions, boundary conditions not covered.
- **Security**: injection, data exposure, auth bypass, sensitive data in logs — auditors do not check these.
- **Test quality**: does the test verify behavior or implementation? Would it catch a regression?
- **Architecture trajectory**: does this move toward or away from the target architecture in CLAUDE.md > Architecture Decisions?

### Step 4 — Synthesise

## Output Format

```
## Review: [scope]

### Verdict: APPROVE | REQUEST CHANGES

### Issues
| # | Severity | File:line | Issue | Suggestion |
|---|----------|-----------|-------|------------|

### Test Coverage
- Covered: ...
- Missing: ...

### Architecture Notes
- Debt trajectory: improving / neutral / degrading
- Boy Scout applied: yes / no
- TECH_DEBT entries resolved: <DEBT-IDs from debt-radar's "resolved" list>
- TECH_DEBT entries newly relevant: <DEBT-IDs from debt-radar that touch changed files>

### Convention Violations
Summarise convention-check findings (link IDs to issue rows above).
```

Be direct. Do not praise code for meeting baseline expectations. Only call out what's good if it's genuinely above the bar.
