---
name: meta-gates
description: Run exactly the verification recipes root AGENTS.md requires for the changed paths, capturing every stage's exit code, and print the tier (guarded or ordinary) computed from those paths for the commit subject. Use before committing a change in this authoring repo.
argument-hint: guarded|ordinary
allowed-tools: PowerShell(git *) PowerShell(Test-Path *) PowerShell(Start-Sleep *) PowerShell(pwsh -NoProfile -File scripts/*) PowerShell(pwsh -NoProfile -File .claude/hooks/tests/*) PowerShell(powershell.exe -NoProfile -File .claude/hooks/tests/*) PowerShell(pwsh -NoProfile -File dist/*/tests/hooks/*) PowerShell(powershell.exe -NoProfile -File dist/*/tests/hooks/*)
---

# Gate ladder

Thin by design: this runs the recipes root `AGENTS.md` ("Verification") already requires for the
changed paths, one stage at a time, and records `$LASTEXITCODE` immediately after each. Never pipe a
gate into a filter before capturing its exit code. Do not run while another session is editing this
tree.

## 0. Compute the tier (observed, not asserted)

```powershell
git status --porcelain
git diff --name-only HEAD          # unstaged + staged vs HEAD
git diff --name-only --cached      # staged only
```
Apply the "Two tiers" list in root `AGENTS.md` to the union of paths: any guarded path makes the
change **guarded**, otherwise it is **ordinary**. Print `<tier>: <paths>` — that line starts the
commit subject. If `$ARGUMENTS` names a lower tier than computed, say so and use the computed one; a
tier may be raised, never lowered.

## 1. Tree stillness

`git rev-parse HEAD`, `Start-Sleep 3`, `git rev-parse HEAD` — both must match, or stop.

## 2. Stages by changed path (run every row that matches)

**Top-level `meta/*.md`, `.claude/plans/**`**
1. `pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 -File DocTruth.Tests.ps1`
2. `pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 -File RepositoryPrivacy.Tests.ps1`
3. `pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 -File BacklogHygiene.Tests.ps1`

**`src/**`**
1. Monorepo sibling check: for every changed `src/stacks/<stack>/<rel>` path, `Test-Path
   src/stacks/monorepo/<rel>`; report each sibling that exists and whether it was also changed.
2. `pwsh -NoProfile -File scripts/build.ps1 dotnet` · `angular` · `monorepo`
3. `git status --porcelain dist/` — the resulting `dist/` change belongs in the same commit.
4. `pwsh -NoProfile -File scripts/validate-dist.ps1 <dist>` for each dist.

**A hook or script**
1. Its test file, as separate direct runs under `pwsh` and under `powershell.exe`
   (`… Invoke-HookTests.ps1 -File <Name>.Tests.ps1`; for a shipped hook, the **dist** copy's runner).
2. When the change is guarded and a `.ps1` changed: one CP437 leg of the same test file.
3. Report the red observation (a `Red-first:` trailer's `RED_FIRST PASS` line, or the failing line)
   unless the edit is text-only; then say it has no behaviour to show red.

**An installer**
1. Greenfield and brownfield smoke installs into temp directories (`DEVELOPING.md`, "Install smoke
   test").

CI runs every other suite on both hosts after the push.

## 3. Report

A table `stage | command | EXIT` in run order, then the `<tier>: <paths>` line. Stop at the first
non-zero exit but still print the table. A non-zero exit is reported with the gate's own message: say
whether it reported the artifact as *wrong* or as *could not be examined*; do not translate one into
the other.
