---
name: meta-gates
description: Run exactly the verification recipes root AGENTS.md requires for the changed paths, capturing every stage's exit code, and print the tier (guarded or ordinary) computed from those paths for the commit subject. Use before committing a change in this authoring repo.
argument-hint: guarded|ordinary
allowed-tools: PowerShell(git *) PowerShell(Test-Path *) PowerShell(pwsh -NoProfile -File scripts/*) PowerShell(pwsh -NoProfile -File .claude/hooks/tests/*) PowerShell(pwsh -NoProfile -File dist/*/tests/hooks/*)
---

# Gate ladder

Thin by design: this runs the recipes root `AGENTS.md` ("Verification") already requires for the
paths this session changed, one stage at a time, and records `$LASTEXITCODE` immediately after each.
Never pipe a gate into a filter before capturing its exit code.

## 0. Your paths and the tier (observed, not asserted)

```powershell
git rev-parse --path-format=absolute --git-dir --git-common-dir   # absolute: the short form differs by folder
git rev-parse HEAD
git status --porcelain -uall           # staged, unstaged and every untracked file
git diff --name-only master...HEAD     # commits on a worktree branch; empty on master
```
Your paths are those you changed: your own edits, those of agents you started, and the files your
commands wrote. Apply the "Two tiers" list in root `AGENTS.md` to your paths only: any guarded path
makes the change **guarded**, otherwise it is **ordinary**. Print `<tier>: <paths>` — that line
starts the commit subject. If `$ARGUMENTS` names a lower tier than computed, say so and use the
computed one; a tier may be raised, never lowered.

## 1. Whose tree

The two `rev-parse` paths differ: this is your own worktree, and every path in step 0 is yours; go
on. They match: this is the shared checkout. If step 0 lists a path you did not write, run no stage
and report **could not examine**, not a failure of your change. Do not wait and do not ask; move out:
1. `git worktree add <folder outside the repository> -b <slug> master`.
2. Here, from the repository root: `git stash push -u -m <slug> -- <your paths>`. A path another
   session also changed is not yours to move: leave it out of `<your paths>`, undo only your own
   lines in it with the file-editing tool (never `git restore`, `git checkout` or `git stash` on that
   path: each takes their lines too), and make that edit again in the worktree. If you had staged
   your lines in it, report that: they stay in the shared index.
3. There: `git stash pop 'stash@{<n>}'`, the entry `git stash list` names `<slug>`. A stash carries
   the whole index, so staged paths outside `<your paths>` come along, shown as modified or added:
   before any edit there, `git restore --staged --worktree --` every path `git status --porcelain
   -uall` lists that is not in `<your paths>`.
4. Start again at step 0 there. The `bom-fix` hook acts only inside the checkout its copy lives in:
   check the UTF-8 BOM of a `.ps1` you write in the worktree by hand (invariant 4).

To land from a worktree: commit there, `git rebase master`, steps 0 to 3 on that commit, then in the
shared checkout `git merge --ff-only <slug>` and `push-and-check.ps1`. If the merge says it cannot
fast-forward, `master` moved: rebase and gate again. If `git rebase master` stops on a conflict,
resolve it there (in the shared records keep both sides' lines) and gate again. If the merge names a
file, another session changed it: report that file and stop. After landing, `git worktree remove
<folder>` and `git branch -d <slug>`.

After the last stage, run step 0's commands again: `HEAD` must equal step 0's and no path you did not
write may have appeared; otherwise report every stage as **could not examine**.

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
5. `pwsh -NoProfile -File scripts/context-footprint.ps1 -Check`. On a baseline difference, report it; the
   author reviews the change, runs `-Update`, and commits `meta/context-footprint.json` in the same commit.
   On a ceiling FAIL, stop and report: raising a ceiling or passing `-AllowCeilingBreach` is the maintainer's call.

**A hook or script**
1. Its test file, as a direct run under `pwsh`
   (`… Invoke-HookTests.ps1 -File <Name>.Tests.ps1`; for a shipped hook, the **dist** copy's runner).
2. When the change is guarded and a `.ps1` changed: one CP437 leg of the same test file under `pwsh`
   (`DEVELOPING.md`, "the hostile-code-page leg").
3. Report the red observation (a `Red-first:` trailer's `RED_FIRST PASS` line, or the failing line)
   unless the edit is text-only; then say it has no behaviour to show red.

**An installer**
1. Greenfield and brownfield smoke installs into temp directories (`DEVELOPING.md`, "Install smoke
   test").

CI runs every other suite after the push.

## 3. Report

A table `stage | command | EXIT` in run order, then the `<tier>: <paths>` line. Stage exactly those
paths by name (`git add -- <paths>`), never `git add -A` or `git commit -a`. Stop at the first
non-zero exit but still print the table. A non-zero exit is reported with the gate's own message: say
whether it reported the artifact as *wrong* or as *could not be examined*; do not translate one into
the other.
