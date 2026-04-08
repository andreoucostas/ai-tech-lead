Find and fix tech debt in a specific area of this .NET codebase.

Read CLAUDE.md and TECH_DEBT.md before starting.

## Input
$ARGUMENTS

If no area specified, show a summary of TECH_DEBT.md grouped by area and ask which to tackle.

If TECH_DEBT.md is empty or contains only the template placeholder, run a fresh scan of the specified area (or the most actively changed area if none specified) and populate the register before proceeding.

## Execution

### Step 1 — Assess
- Read TECH_DEBT.md and find all items in the specified area
- Read the affected files to confirm the debt still exists (it may have been fixed already)
- For each item, recommend: **fix now** (bundleable into current work) or **defer** (needs dedicated effort)
- Present the assessment before proceeding

### Step 2 — Fix
For each item marked "fix now":
- Verify existing tests pass before touching anything
- Apply the fix
- Run `dotnet build`, `dotnet test`, and `dotnet format --verify-no-changes` after each fix
- If no tests exist for the affected code, write baseline tests first

### Step 3 — Update the register
- Remove resolved items from TECH_DEBT.md
- Update the "Trojan Horse Opportunities" section if feature area groupings changed
- If you discovered new debt during the fix, add it to the register

### Step 4 — Boy Scout
Apply Boy Scout Rule from CLAUDE.md to every file touched during the fix.

### Step 5 — Report
- What was fixed and what was deferred (with reason)
- Test results
- Updated TECH_DEBT.md diff
- Any CLAUDE.md convention updates needed
