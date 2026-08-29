# B-194 — installer Git-preflight classifier

**Date:** 2026-08-29  
**Filed against:** v0.78.3  
**Status:** LOCKED 2026-08-29 — two independent adversarial audits approved the amended cross-twin design

## Value decision

Do B-194 now, but not as the originally proposed PowerShell-only exception. Native Windows
PowerShell 5.1 currently aborts a supported non-Git update and brownfield install before mutation
because expected Git stderr becomes a terminating `NativeCommandError`. That is a current, reachable
host defect.

The review also reproduced a more serious shared false green: a target with corrupt `.git` metadata
is treated as non-Git by PowerShell 7 and Bash, so both print `Done (update)` and mutate without
proving the worktree is clean. An ambient alternate index can likewise make a genuinely dirty target
look clean. The dirty-tree preflight is a data-preservation boundary; twin behavior is therefore
contract-relevant and the item is P1/M rather than the original P2/S.

Historic wording required every broken-Git probe to refuse. That is too broad. Git is optional for
a target with no repository evidence, so a broken optional executable must not become a new
prerequisite. Refuse when repository state exists or is redirected but cannot be verified; permit a
plain non-Git target when no such evidence exists. This revision is evidence-driven, not a blanket
preference for newer behavior.

## Frozen behavioral contract

The classifier runs only before a mutating update or brownfield install. Greenfield and `-WhatIf` /
`--dry-run` behavior is unchanged.

1. Treat these non-empty ambient variables as untrusted Git routing and refuse immediately with
   `CANT-VERIFY`, exit 4: `GIT_DIR`, `GIT_WORK_TREE`, `GIT_COMMON_DIR`, and `GIT_INDEX_FILE`. Do not
   let ambient state redirect the target's repository or index. One review constructed a dirty
   target whose alternate `GIT_INDEX_FILE` made porcelain status empty.
2. Inspect repository evidence without following it away: any `.git` directory entry from target
   through ancestors counts, including a file, directory, reparse point, symlink, or dangling link.
   Inability to inspect an ancestor is `CANT-VERIFY`, not absence. A bare signature at the target is
   `HEAD` as a leaf plus `objects/` and `refs/` as directories. Do not widen the signature to any
   two-of-three heuristic.
3. Resolve Git as an application. If Git is absent and repository evidence exists, refuse exit 4;
   if Git is absent and evidence does not exist, the target is non-Git and may proceed.
4. If Git exists, always run `git -C <target> rev-parse --is-inside-work-tree` through a bounded
   native-command helper. Keep stdout separate from stderr. In PowerShell, suppress expected native
   stderr under function-local `ErrorActionPreference=Continue`, restore the prior preference in
   `finally`, and return whether the process started, its exit, and normalized stdout. No global
   preference change, stderr parsing, `Start-Process`, location change, or host-specific
   `$PSNativeCommandUseErrorActionPreference` dependency.
5. Exit 0 with stdout exactly `true` identifies a worktree. Exit 0 with `false`, empty, or any other
   stdout is `CANT-VERIFY` (including a bare repository). A nonzero/launch failure with repository
   evidence is `CANT-VERIFY`; the same result with no evidence is ordinary non-Git. Thus unusual
   topologies Git can authoritatively identify still work, while broken metadata cannot disappear.
6. For an identified worktree, run `git -C <target> status --porcelain=v1 --untracked-files=all`
   through the same host-safe path. Status stderr never joins porcelain stdout. A failed/unstarted
   status is the existing actionable `CANT-VERIFY`, exit 4. Empty stdout is clean; non-empty stdout
   retains the existing refusal and explicit `AllowDirtyTree`/`--allow-dirty-tree` override.
7. Every classifier refusal occurs before target mutation, omits installer completion, and leaves a
   whole-tree fingerprint unchanged. Preserve Git-optional plain targets, clean worktrees, dirty
   refusal/override, ownership/archive behavior, exit codes, and success banners.
8. PowerShell and Bash implement the same state machine. Keep Bash 3.2-compatible syntax and
   PowerShell 5.1 compatibility; add no dependency or shared abstraction.

## Bounded implementation

Change only authored `src/core/scripts/install.ps1`, `install.sh`, and
`.claude/hooks/tests/UpdateDelivery.Tests.ps1`, then compose the three generated installer copies.
Local helpers may detect evidence, invoke Git, and emit the one Git-preflight refusal. Do not change
root stack selection, setup-git-hooks, greenfield behavior, ownership manifests, copy/archive logic,
or the dirty override.

The same-class sweep found `setup-git-hooks.ps1` can surface a raw native error on an optional
`-GitHooks` non-Git path under PowerShell 5.1. It already refuses without mutation and no consumer
incident is known. Do not expand B-194 or create permanent tests/backlog ceremony for a diagnostic-
only fail-safe today. Record it in B-194's closure; revisit on an incident or when that subsystem is
otherwise changed.

## Red-first, test-value-bounded matrix

Add exactly three grouped `It` results to the existing UpdateDelivery suite. Each group captures all
child results before its first assertion. Do not create a new suite or duplicate the existing clean
and dirty controls.

1. **Plain non-Git remains supported.** Capture native absolute Windows PowerShell 5.1 update and
   brownfield installs with real Git on child `PATH` and `pwsh` absent. Require exit 0, completion,
   exact protected/update carrier/settings-fallback behavior, and exact brownfield archive/adoption
   behavior. In the same group, a PATH-prepended Git stub that records invocation and exits nonzero
   must still allow a no-evidence update through both twins; assert the out-of-target invocation
   sentinel so real Git cannot make the control vacuous.
2. **Evidence or routing that cannot be trusted refuses.** Capture corrupt `.git` metadata with real
   Git under PowerShell 7, native PowerShell 5.1, and Bash; repository evidence with Git absent under
   both twins; and a genuinely dirty repository whose ambient `GIT_INDEX_FILE` hides the change
   under PowerShell 7 and Bash. Each exits 4 with `CANT-VERIFY`, no completion, and an unchanged
   target fingerprint.
3. **Classification success does not excuse unreadable status.** Capture a real worktree with a
   corrupt index under PowerShell 7, native PowerShell 5.1, and Bash. `rev-parse` succeeds but status
   fails; require the same exit-4/no-completion/unchanged-tree contract.

These branches are not redundant: group 1 is the supported-host regression and the deliberately
reversed broken-Git/no-evidence decision; group 2 covers failed classification with evidence,
missing Git, and an observed ambient false-clean; group 3 covers post-classification examination.
Re-run, rather than duplicate, the committed clean-Git brownfield control in
`RootInstallerWarehouse.Tests.ps1` and the existing dirty update/brownfield refusal/override cases.

Before implementation, the unchanged candidate must make the new matrix red while every child
surface is observed. After green, weaken the PowerShell native invocation and Bash evidence/refusal
branches independently in scratch; each mutation must turn its discriminating case red, restore
byte-identically, and return clean.

## Verification and release boundary

- `UpdateDelivery.Tests.ps1` under PowerShell 7 and native Windows PowerShell 5.1/CP437, with Bash
  observed and the expected case count/cardinality recorded.
- Existing `RootInstallerWarehouse`, `InstallerContract`, and `InstallerConvergence` suites; add no
  duplicate clean/dirty installer tests.
- Compose dotnet, Angular, and monorepo with PowerShell; validate all three; prove installer source/
  dist hashes and BOM/syntax. Compare whole trees after login-shell Bash composition.
- Independent immutable-range hostile review under WSD-057. Because both installer twins and a
  data-preservation preflight change, Windows and native Linux candidate CI are mandatory before
  release. Git Bash is not Linux/macOS or Bash 3.2 runtime evidence.

