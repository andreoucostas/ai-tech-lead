Cross-check all documentation against the codebase and between instruction files. Identify drift, contradictions, and stale entries.

## Input
$ARGUMENTS

## Execution

### Step 1 — Check CLAUDE.md against codebase
For each section in CLAUDE.md:
- **Codebase Context**: does it still accurately describe what the app does?
- **Repository Structure**: do the projects, layers, and dependencies match reality?
- **Conventions**: for each convention, verify it's actually followed. Check for conventions the codebase follows that aren't documented.
- **Architecture Decisions**: are the decisions still current? Any new ones since last sync?
- **Common Tasks**: do the step-by-step patterns match the current code?
- **Boy Scout Rule**: are the priorities still relevant or has debt shifted?

### Step 2 — Check copilot-instructions.md against CLAUDE.md
- Every rule in CLAUDE.md should appear in copilot-instructions.md
- Every rule in copilot-instructions.md should trace back to CLAUDE.md
- No contradictions between the two files
- Flag any rules that exist in one but not the other

### Step 3 — Check LEARNINGS.md
- Does it still only say "No entries yet"? If so, prompt the team to add observations.
- Are existing entries still relevant?
- Are there learnings from recent work that should be captured?

### Step 4 — Check FRAMEWORK-CONTEXT.md drift
- **Detected Framework Packages**: re-scan `*.csproj` and `Directory.Packages.props`. Flag packages newly added, removed, or version-bumped since the last sync. Propose updated table.
- **Shared Libraries**: for each entry, flag if the consuming repo no longer references it (the package is gone from csproj). Do not flag the converse — a package present in the repo but missing from `Shared Libraries` is expected for non-framework dependencies.
- **Per-section drift**: skim Production Architecture, Multi-Tenancy, Dashboard Integration, Cross-Service Communication. Do they still match observed code? Flag obvious staleness only — these are maintainer-curated, do not rewrite.

### Step 5 — Check TECH_DEBT.md against codebase
- Are resolved items still in the register? Flag for removal.
- Are there obvious debt patterns in the code not captured in the register? Flag for addition.
- Are effort estimates still accurate?
- Is the Trojan Horse Opportunities grouping still correct?

### Step 6 — Report
Do NOT apply changes automatically. Present a structured report:

```
## Documentation Sync Report

### CLAUDE.md Drift
| Section | Issue | Suggested Update |
|---------|-------|-----------------|

### copilot-instructions.md vs CLAUDE.md
| Rule | Status | Issue |
|------|--------|-------|
(Status: in-sync / missing-from-copilot / missing-from-claude / contradicts)

### FRAMEWORK-CONTEXT.md Drift
- Detected packages added: ...
- Detected packages removed: ...
- Detected packages version-bumped: ...
- Shared Libraries no longer referenced: ...
- Sections flagged stale: ...

### TECH_DEBT.md Staleness
- Items to remove (already fixed): ...
- Items to add (newly discovered): ...
- Items to re-estimate: ...

### Recommended Actions
1. ...
2. ...
```

The developer reviews this report and decides what to update. After approval, they can ask you to apply the changes or run `/generate-copilot` to regenerate copilot-instructions.md.
