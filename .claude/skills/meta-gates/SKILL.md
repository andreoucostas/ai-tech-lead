---
name: meta-gates
description: Run exactly the gate commands a maintainer change class requires (records, prose, or full), capturing every stage's exit code, and print the class computed from the changed paths for the commit subject. Use before committing a change in this authoring repo.
argument-hint: records|prose|full
allowed-tools: PowerShell(git *) PowerShell(Test-Path *) PowerShell(Start-Sleep *) PowerShell(pwsh -NoProfile -File scripts/*) PowerShell(pwsh -NoProfile -File .claude/hooks/tests/*)
---

# Gate ladder

Thin by design: this runs the commands root `AGENTS.md` already requires for the class, one stage at
a time, and records `$LASTEXITCODE` immediately after each. Never pipe a gate into a filter
(`DEVELOPING.md`, "Do not pipe a gate…"). Do not run while another session is editing this tree.

## 0. Compute the class (observed, not asserted)

```powershell
git status --porcelain
git diff --name-only HEAD          # unstaged + staged vs HEAD
git diff --name-only --cached      # staged only
```
Apply the "Change classes" table in root `AGENTS.md` to the union of paths; the class is the
**highest** kind any path matches. Print `class <name>: <paths>` — that line goes into the commit
subject. If `$ARGUMENTS` names a lower class than computed, say so and run the computed one; a class
may be raised, never lowered.

## 1. Tree stillness

`git rev-parse HEAD`, `Start-Sleep 3`, `git rev-parse HEAD` — both must match, or stop.

## 2. Stages by class

**records**
1. `pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 -File DocTruth.Tests.ps1`
2. `pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 -File RepositoryPrivacy.Tests.ps1`
3. if `meta/BACKLOG*` or `meta/decisions-index.md` changed: `… -File BacklogHygiene.Tests.ps1`
4. if `README.md` changed: `… -File ClaimTruth.Tests.ps1`
5. if any `.claude/settings.json` or `.claude/skills/**` changed: `… -File MetaHooks.Tests.ps1`

**prose**
1. WSD-015 sibling check: for every changed `src/stacks/<stack>/<rel>` path, `Test-Path
   src/stacks/monorepo/<rel>`; report each sibling that exists and whether it was also changed.
2. `pwsh -NoProfile -File scripts/build.ps1 dotnet` · `angular` · `monorepo`
3. `git status --porcelain dist/` — must print nothing; otherwise the dist change belongs in the commit
4. `pwsh -NoProfile -File scripts/validate-dist.ps1 <dist> --content-only` for each dist

**full** (mechanism / critical; the same ladder `release.ps1` runs locally)
1. stages 2–3 of prose, then `pwsh -NoProfile -File scripts/validate-dist.ps1 <dist>` (no narrowing) ×3
2. `pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1` (full meta suite, 3–15 min)
3. Shipped dist hook suites are **not** run locally (WSD-049); CI runs them on both hosts before a tag.

## 3. Report

A table `stage | command | EXIT` in run order, then the `class <name>: <paths>` line. Stop at the
first non-zero exit but still print the table. A non-zero exit is reported with the gate's own
message: say whether it reported the artifact as *wrong* or as *could not be examined* (Maintenance
model #7); do not translate one into the other.
