---
description: "Documentation drift check: cross-checks AGENTS.md, FRAMEWORK-CONTEXT.md, registers, and skills against the codebase and each other; reports drift, contradictions, and stale entries with proposed fixes. Read-mostly; safe to run anytime."
---

Cross-check all documentation against the codebase and between instruction files. Identify drift, contradictions, and stale entries.

## Input
$ARGUMENTS

## Execution

### Step 1 — Check AGENTS.md against codebase
For each section in AGENTS.md:
- **Codebase Context**: does it still accurately describe what the repository/system does, its consumers, and its domain?
<!-- @stack:repo-structure -->
- **Conventions**: for each convention, verify it's actually followed. Check for conventions the codebase follows that aren't documented.
<!-- @stack:docs-sync-warehouse -->
- **Architecture Decisions**: are the decisions still current? Any new ones since last sync?
- **Common Tasks**: do the step-by-step patterns match the current code?
- **Boy Scout Rule**: are the priorities still relevant or has debt shifted?

### Step 2 — Check the `route-prompt` rails against the framework rules
**`route-prompt.ps1` rails** (registered, capability-specific salience copy of §1):
- The six per-workflow rail blocks (`$railsFix`/`$railsFeature`/…) are a *bound salience copy* of the canonical file-based framework rules (`.github/instructions/framework-rules.instructions.md` › Agentic Workflow) §1, not an independent source. When invoked, the hook emits the selected copy; registration and emission do not prove host firing or consumption, and current VS Code prompt-hook lifecycles are unverified. Dated local-host evidence lives in `docs/enforcement-surfaces.md`. Cross-check each rail against the matching §1 workflow: flag any **non-negotiable present in §1 but missing from the rail** (e.g. "red regression test before production code when an applicable harness exists; strongest evidenced reproduction otherwise", "applicable validation green before and during refactor", "net LOC delta", "new behavioral tests seen red before green"), or any rail instruction that **contradicts** §1. They need not be word-identical (§1 is prose, the rails are terse), but they must not diverge in substance.

If any rail has drifted, recommend a manual rail/§1 reconciliation.

### Step 3 — Check LEARNINGS.md
- Does it still only say "No entries yet"? If so, prompt the team to add observations.
- Are existing entries still relevant?
- Are there learnings from recent work that should be captured?
- Does any durable LEARNINGS.md entry deserve promotion to a wiki entry (`docs/wiki/`) via `remember-for-team`?

### Step 4 — Check FRAMEWORK-CONTEXT.md drift
<!-- @stack:fwctx-packages -->
- **Per-section drift**: re-check Production Architecture, Multi-Tenancy, Dashboard Integration, and Cross-Service Communication against their code signals (the per-section evidence lists in `/bootstrap` Phase 3d-ter). Flag staleness and propose updated text in the report — never rewrite in place; auto-drafted sections may have been maintainer-refined since, and maintainer-written cross-repo context must survive.

### Step 5 — Check TECH_DEBT.md against codebase
- Are resolved items still in the register? Flag for removal.
- Are there obvious debt patterns in the code not captured in the active register? Before flagging
  one for addition, compare it with `## Dismissed proposals`; suppress a matching claim unless
  materially changed evidence is named, and report that evidence delta without deleting the prior
  dismissal.
- Are effort estimates still accurate?
- Is the Trojan Horse Opportunities grouping still correct?

### Step 6 — Report
Do NOT apply changes automatically. Present a structured report:

```
## Documentation Sync Report

### AGENTS.md Drift
| Section | Issue | Suggested Update |
|---------|-------|-----------------|

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

The developer reviews this report and decides what to update. After approval, they can ask you to apply the changes.
