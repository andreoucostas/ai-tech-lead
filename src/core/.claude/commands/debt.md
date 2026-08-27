---
description: "Tech-debt workflow: match TECH_DEBT.md entries for an area, confirm each still exists in code, fix or defer with rationale, update the register. Invoke for debt-cleanup requests."
argument-hint: "[area or DEBT-ID]"
---

<!-- @stack:intro -->

## Input
$ARGUMENTS

If no area specified, show a summary of TECH_DEBT.md grouped by area and ask which to tackle.

If TECH_DEBT.md is empty or contains only the template placeholder, run a fresh scan of the specified area (or the most actively changed area if none specified) and populate the register before proceeding.

## Execution

### Step 1 — Assess
- Read TECH_DEBT.md, including `## Dismissed proposals`, and find all active items in the specified area. Dismissed rows are decision memory, not active debt.
- Read the affected files to confirm the debt still exists (it may have been fixed already)
- For each active item, recommend: **fix now** (bundleable into current work), **defer** (needs dedicated effort), or **Dismiss as not debt** (a false-positive claim). The last choice requires developer confirmation plus the evidence reviewed and a reason; never equate defer/decline-for-now with dismissal.
- Present the assessment before proceeding

### Step 2 — Fix
For each item marked "fix now":
- Derive applicable test and other validation commands from repository evidence: CLAUDE.md, committed CI, scripts, manifests, and configuration. If a test harness exists, establish its green baseline; otherwise report tests as **not available** and identify the strongest evidenced validation. Do not introduce a foreign harness solely for debt cleanup.
- Apply the fix
<!-- @stack:verify-cmds -->
- If an applicable test harness exists but the affected code lacks coverage, add characterization coverage only when it is proportionate to the debt item.

### Step 3 — Update the register
- Remove resolved items from TECH_DEBT.md — items are per-block: to remove a resolved item, delete its `## DEBT-NNN` block. To add a new item, follow the template at the top of TECH_DEBT.md.
- For an item the developer confirms is not debt, remove its active block and append a row under `## Dismissed proposals` with stable key `<area>::<claim-slug>`, affected paths/symbols, evidence reviewed, today's date, and the developer's reason. Preserve every earlier dismissal row.
- Before adding newly discovered debt, compare its problem, consequence, and path/symbol scope with the dismissal registry. Suppress a match. Reopen only for materially changed evidence, and put `Reopens dismissal: <key>` plus `Evidence delta: <specific change>` in the new active block without deleting the prior row.
- Update the "Trojan Horse Opportunities" section if feature area groupings changed
- If you discovered new debt during the fix, add it to the register using the per-block format

### Step 4 — Boy Scout
Apply Boy Scout Rule (CLAUDE.md > Boy Scout Rule) to every file touched during the fix.

### Step 5 — Wrap up
@.claude/workflow.md

### Step 6 — Report
- What was fixed and what was deferred (with reason)
- Test results or strongest validation, including any category that is **not available**
- Updated TECH_DEBT.md diff
