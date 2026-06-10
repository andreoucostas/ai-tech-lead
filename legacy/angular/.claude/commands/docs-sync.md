Cross-check all documentation against the codebase and between instruction files. Identify drift, contradictions, and stale entries.

## Input
$ARGUMENTS

## Execution

### Step 1 — Check CLAUDE.md against codebase
For each section in CLAUDE.md:
- **Codebase Context**: does it still accurately describe what the app does?
- **Repository Structure**: do the folders, modules, and dependencies match reality?
- **Conventions**: for each convention, verify it's actually followed. Check for conventions the codebase follows that aren't documented.
- **Architecture Decisions**: are the decisions still current? Any new ones since last sync?
- **Common Tasks**: do the step-by-step patterns match the current code?
- **Boy Scout Rule**: are the priorities still relevant or has debt shifted?

### Step 2 — Check the generated derived files against CLAUDE.md
Two files are generated from CLAUDE.md by `/generate-copilot` and must not drift:

**`.github/copilot-instructions.md`** (slim, inline completions):
- Every Conventions / always-apply Boy Scout rule in CLAUDE.md should appear here.
- Every rule here should trace back to CLAUDE.md. No contradictions. Flag rules in one but not the other.
- Still ≤ 80 lines.

**`AGENTS.md`** (full mirror for AGENTS.md-native tools):
- The Verification Rules, Leanness, Boy Scout, and Agentic Workflow sections should match CLAUDE.md **verbatim**. Flag any section that has diverged.
- The Conventions section should mirror `CLAUDE.md > Conventions` (once bootstrapped).
- It must still begin with the `GENERATED FILE — do not edit by hand` banner. If someone hand-edited AGENTS.md, flag it and recommend re-running `/generate-copilot`.

If either file has drifted, recommend `/generate-copilot` to regenerate both.

### Step 3 — Check LEARNINGS.md
- Does it still only say "No entries yet"? If so, prompt the team to add observations.
- Are existing entries still relevant?
- Are there learnings from recent work that should be captured?

### Step 4 — Check FRAMEWORK-CONTEXT.md drift
- **Detected Framework Packages**: re-scan `package.json` (and `package-lock.json` for resolved versions). Flag packages newly added, removed, or version-bumped since the last sync. Propose updated table.
- **Shared Libraries**: for each entry, flag if the consuming repo no longer references it. Do not flag the converse — a package present in the repo but missing from `Shared Libraries` is expected for non-framework dependencies.
- **Per-section drift**: re-check Production Architecture, Multi-Tenancy, Dashboard Integration, and Cross-Service Communication against their code signals (the per-section evidence lists in `/bootstrap` Phase 3d-ter). Flag staleness and propose updated text in the report — never rewrite in place; auto-drafted sections may have been maintainer-refined since, and maintainer-written cross-repo context must survive.

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

### Derived files vs CLAUDE.md (copilot-instructions.md + AGENTS.md)
| File | Rule / Section | Status | Issue |
|------|----------------|--------|-------|
(Status: in-sync / missing-from-derived / missing-from-claude / contradicts / hand-edited)

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
