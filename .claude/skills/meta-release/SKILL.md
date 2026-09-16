---
name: meta-release
description: Run the maintainer release procedure for a shipped change — preconditions, the -ReviewEvidence string (from a review packet or a prose-class cell), the exact release.ps1 command, and the CI-watch outcomes. User-invoked only; never triggered by the model.
disable-model-invocation: true
argument-hint: <version> "<one-line summary>"
allowed-tools: PowerShell(git *) PowerShell(gh run list *) PowerShell(Select-String *) Read
---

# Release a shipped change

`$ARGUMENTS` = `<version> "<one-line summary>"`. A release pushes to `master` and tags; it is
outward-facing and hard to reverse, so **present the assembled command to the user and run it only
on their explicit confirmation**.

## 1. Preconditions — each is a command, each must be observed

| Check | Command | Must show |
|---|---|---|
| On master | `git branch --show-current` | `master` |
| Clean tree | `git status --porcelain` | nothing |
| Tip stable | `git rev-parse HEAD` twice, a few seconds apart | same SHA |
| Four changelog heads | `Select-String -Path CHANGELOG.md,src/stacks/*/files/CHANGELOG.md -Pattern '^## <version> — Unreleased'` | four hits |
| Master CI green, no watch pending | `gh run list --workflow CI --limit 3` | HEAD's run `success`; no other release between push and tag (B-237) |
| Class of the batch | `git diff --name-only <last-tag>..HEAD` against the table in root `AGENTS.md` | highest member class; ≥5 prose items or two items touching one file is mechanism |

Stop at the first failed check and report which one failed.

## 2. Evidence string

- **mechanism / critical**: copy the completed skeleton from the review packet
  (`/meta-review-handoff`): `contract <path> SHA256 <hash>; range <a>..<b>; reviewer <agent/model>; independence <...>; hostile <case> RED; clean <command> EXIT=0; environment/gaps <facts>; implementer <who>`.
  Critical additionally names the orthogonal second reviewer or execution vantage.
- **prose** (WSD-089): `class prose per WSD-089; reviewer <user|fresh read-only session|none>; paths <list>; gates <commands> EXIT=0; no behavioural instrument for prose`.
  This is a disclosed non-review, recorded verbatim; it is not a claim that a review happened.
- `-NoIndependentReview` is allowed but auto-files a post-ship review item; prefer the honest
  evidence cell above.

## 3. The command (absolute path; capture the exit code; never pipe into a filter)

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File <repo-root>\.claude\scripts\release.ps1 -Version <version> -Summary "<summary>" -ReviewEvidence "<evidence>"
"RELEASE EXIT=$LASTEXITCODE"
```

| Exit | Meaning | Next |
|---|---|---|
| 0 | gates green, pushed, CI green, tagged | done; record the ledger row exists |
| 1 | CI red — commit is on master, tag withheld | fix forward with a normal commit, re-run the same command |
| 2 | refused before any mutation (evidence, branch, staged set, budget) | read the FATAL text; fix the precondition |
| 3 | CI unobservable — tag withheld, never reported as success | `watch-ci.ps1 -Sha <sha>` when observable |

Escape hatches are named for what they risk (`-AllowUnverifiedCi`, `-AllowFailingGate
'<File>=B-nnn'`, `-AllowExtraStagedPaths`, `-AllowNonMasterHead`) and travel in the tag annotation.
Use one only when the user names it.
