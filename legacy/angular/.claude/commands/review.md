---
description: "Tech-lead quality gate on a diff: spawns convention-check, solid-check, debt-radar, bloat-radar, and test-critic subagents in parallel, runs build+tests itself, applies senior judgement, returns APPROVE or REQUEST CHANGES. Invoke when completed work needs the full gate, not for a quick inline question."
argument-hint: "[files or PR; empty = uncommitted changes]"
---

Review code as a senior tech lead. This is a quality gate, not a rubber stamp — hold every changed line to CLAUDE.md > Conventions.

## Input
$ARGUMENTS

If no specific files or PR given, review the most recent uncommitted changes (both staged and unstaged).

## Execution

### Step 1 — Dispatch parallel auditors
In a single message, spawn all four subagents via the `Task` tool:

- `convention-check` — verifies the diff against CLAUDE.md > Conventions and Boy Scout always-apply items.
- `solid-check` — audits the diff against CLAUDE.md > SOLID (the five principles; literal interface-per-injected-service).
- `debt-radar` — surfaces TECH_DEBT.md entries touching the changed files (debt-trajectory signal).
- `bloat-radar` — surfaces speculative abstractions, shallow wrappers, parallel implementations, and comment debris in the diff.
- `test-critic` — audits the spec changes for integrity: would each spec actually fail if the code broke? Catches over-mocking, tautological/weak expectations, missing paths, and nondeterminism.

Wait for all five to return their structured output. Use those findings as the spine of the review — do not redo the scans yourself.

### Step 2 — Verify the build yourself
Run `ng build` and `ng test --watch=false --browsers=ChromeHeadless`. Do not trust that the code being reviewed already passes. If lint is configured, run `ng lint` too. Record any failures as high-severity issues.

### Step 3 — Apply senior judgement
The auditors handle pattern-level checks. You handle:
- **Correctness**: does the code do what it claims to do?
- **Failure modes**: edge cases, error paths, race conditions, boundary conditions not covered.
- **Security**: XSS, data exposure, auth bypass, injection — auditors do not check these.
- **Test quality**: build on `test-critic`'s findings — confirm the new specs would fail if the code broke, and that error/edge paths are covered. Treat any "would pass against broken code" spec as a high-severity issue.
- **Architecture trajectory**: does this move toward or away from the target architecture in CLAUDE.md > Architecture Decisions?
- **Spec conformance**: if a `specs/<slug>.md` exists for this change, verify the implementation satisfies its acceptance criteria, that **every Task in its checklist is checked off** (flag any still `- [ ]` as incomplete work), and stays within its declared scope. Flag unmet criteria or scope creep as issues.

### Step 4 — Synthesise

## Output Format

```
## Review: [scope]

### Verdict: APPROVE | REQUEST CHANGES

### Issues
| # | Severity | File:line | Issue | Suggestion |
|---|----------|-----------|-------|------------|

### Test Quality & Coverage
- Would-fail-if-broken: <from test-critic — N would catch a regression, N would pass against broken code>
- Covered: ...
- Missing: ...

### Architecture Notes
- Debt trajectory: improving / neutral / degrading
- Boy Scout applied: yes / no
- TECH_DEBT entries resolved: <DEBT-IDs from debt-radar's "resolved" list>
- TECH_DEBT entries newly relevant: <DEBT-IDs from debt-radar that touch changed files>

### Convention Violations
Summarise convention-check findings (link IDs to issue rows above).

### Bloat
Summarise bloat-radar findings. For each high-severity finding (single-consumer abstraction, shallow wrapper, parallel implementation): does the developer have a documented second consumer or planned next change that justifies it? If not, REQUEST CHANGES to remove or inline.
```

Be direct. Do not praise code for meeting baseline expectations. Only call out what's good if it's genuinely above the bar.
