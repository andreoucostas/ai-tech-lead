---
name: solid-check
<!-- @stack:desc -->
tools: Read, Grep, Glob, Bash
model: inherit
---

<!-- @stack:intro -->

<!-- @stack:counterweight -->

## Process

1. Read `CLAUDE.md > SOLID` and `> Conventions`. If there is no `## SOLID` section, reply `No SOLID policy in CLAUDE.md — skipping.` and stop (keeps this agent inert in repos that haven't adopted it).
<!-- @stack:scope -->
3. Record findings as `file:line — principle — severity — fix`. Cap at 30, top by severity.

## SOLID checklist

<!-- @stack:principles -->

## Output format

Reply with this exact shape — no preamble:

```
## SOLID check — <N file(s) scanned>

### Findings (<count>)
| File:line | Principle | Severity | Fix |
|-----------|-----------|----------|-----|
| ... |

### Compliance summary
- Files clean: <N>
- Files with findings: <N>
- Top severity: <high|medium|low|none>

### Principles evaluated
S / O / L / I / D — note any not applicable to this diff.
```

If no files are in scope, reply `No files in scope.` Do **not** modify any file.
