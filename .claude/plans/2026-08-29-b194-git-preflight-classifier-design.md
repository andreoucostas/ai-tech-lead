# B-194 — installer Git-preflight classifier

**Date:** 2026-08-29  
**Filed against:** v0.78.3  
**Status:** RE-LOCKED 2026-08-30 — original implementation approved; modern Git-for-Windows host
identity amendment approved by two independent adversarial reviews; provider-red/current-green
evidence pending

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
   target whose alternate `GIT_INDEX_FILE` made porcelain status empty. On POSIX hosts, retain the
   platform's exact-case environment-name semantics. On MSYS Git Bash (`OSTYPE=msys*`), enumerate
   exported Bash names with the existing `compgen -e`, match these four names with explicit
   ASCII case patterns, and inspect the matching value through indirect expansion. Do not parse
   line-oriented `env` output, use locale-sensitive folding, enable shell-global case matching, add
   a dependency, or use Bash-4-only case conversion. Git for Windows consumes its Windows
   environment case-insensitively even though Bash variable lookup is case-sensitive. A non-empty
   casing variant such as `git_index_file` must therefore refuse too. Do not generalize the MSYS
   rule to Cygwin without equivalent host evidence.
2. Inspect repository evidence without following it away: any `.git` directory entry from target
   through ancestors counts, including a file, directory, reparse point, symlink, or dangling link.
   Inability to traverse an ancestor is `CANT-VERIFY`, not absence. Traversal/execute permission is
   sufficient to inspect a known child; do not require directory-list/read permission. A bare
   signature at the target is `HEAD` as a leaf plus `objects/` and `refs/` as directories. Do not
   widen the signature to any two-of-three heuristic. On MSYS Git Bash (`OSTYPE=msys*`), derive the
   scan cursor with its proven built-in `pwd -W`, validate the mixed drive or UNC shape, and stop
   after checking the actual `X:/` drive root or `//server/share` root. Never ascend into MSYS's
   virtual `/` or a non-traversable `//server` pseudo-parent; conversion failure or malformed output
   is `CANT-VERIFY`. Do not claim an unverified `pwd -W` contract for Cygwin; other POSIX scanning
   remains conservative through `/`.
3. Resolve Git as an application. If Git is absent and repository evidence exists, refuse exit 4;
   if Git is absent and evidence does not exist, the target is non-Git and may proceed.
4. If Git exists, always run `git -C <target> rev-parse --is-inside-work-tree` through a bounded
   native-command helper. Keep stdout separate from stderr. In PowerShell, suppress expected native
   stderr under function-local `ErrorActionPreference=Continue`, restore the prior preference in
   `finally`, and return whether the process started, its exit, normalized stdout, and captured
   stdout record count. No global preference change, stderr parsing, `Start-Process`, location
   change, or host-specific `$PSNativeCommandUseErrorActionPreference` dependency.
5. Exit 0 with normalized stdout exactly `true` identifies a worktree. PowerShell's line adapter
   normalizes a terminal CR, so twin parity accepts exactly four raw shapes: `true`, `true` plus CR,
   `true` plus LF, or `true` plus CRLF; reject all others rather than trimming general whitespace.
   Exit 0 with `false`, empty, or any other stdout is `CANT-VERIFY` (including a bare repository). A
   nonzero/launch failure with repository evidence is `CANT-VERIFY`; the same result with no
   evidence is ordinary non-Git. Thus unusual topologies Git can authoritatively identify still
   work, while broken metadata cannot disappear.
6. For an identified worktree, run
   `git --no-optional-locks -C <target> status --porcelain=v1 --untracked-files=all` through the same
   host-safe path. The global option is mandatory: ordinary `git status` may refresh index stat data
   before the installer refuses a dirty target. Status stderr never joins porcelain stdout. A
   failed/unstarted status is the existing actionable `CANT-VERIFY`, exit 4. Zero stdout records is
   clean; any stdout record/bytes, including a blank line, retains the existing refusal and explicit
   `AllowDirtyTree`/`--allow-dirty-tree` override.
7. Every classifier refusal occurs before target mutation, omits installer completion, and leaves a
   whole-tree fingerprint unchanged, including Git administrative files. Preserve Git-optional
   plain targets, clean worktrees, dirty refusal/override, ownership/archive behavior, exit codes,
   and success banners.
8. PowerShell and Bash implement the same state machine. Prefer the existing broadly portable Bash
   constructs and retain PowerShell 5.1 compatibility; add no unnecessary shell-version dependency
   or shared abstraction. This is not a stock-Bash-3.2 support guarantee after B-209/WSD-064.

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
   brownfield installs with real Git on the child `PATH` and `pwsh` absent from that `PATH`. Require
   exit 0, completion, exact protected/update carrier behavior, and exact brownfield archive/adoption
   behavior. The absolute `powershell.exe` subject is the host boundary. The Codex process launcher
   was observed prepending its toolchain after environment inheritance, so the fixture resets PATH
   inside the already-started child and proves Git/pwsh visibility there with `where.exe`. App Paths
   behavior may vary by host; do not mutate the registry or mock command discovery to widen this
   preflight test into the unrelated settings-fallback branch. In the same group, a PATH-prepended
   Git stub that records invocation and exits nonzero must still allow a no-evidence update through
   both twins; assert the out-of-target invocation sentinel so real Git cannot make the control
   vacuous. On native Linux, also run the Bash update beneath an execute-only/no-list ancestor to
   prove a traversable plain target is not falsely refused. Before the installer child, require a
   captured Bash prerequisite to observe `-x` true and `-r` false after `chmod 311`; a privileged or
   ACL-altered runner must fail the fixture instead of certifying the old read-permission check.
2. **Evidence or routing that cannot be trusted refuses.** Capture corrupt `.git` metadata with real
   Git under PowerShell 7, native PowerShell 5.1, and Bash; repository evidence with Git absent under
   both twins; and a genuinely dirty repository whose ambient `GIT_INDEX_FILE` hides the change
   under PowerShell 7 and Bash. On Windows, add one representative Git Bash child using lowercase
   `git_index_file` against its own real alternate index. First capture `OSTYPE=msys*` from the same
   resolved Bash as an expected-zero host prerequisite. Schedule the lowercase product child only
   when that prerequisite passes; retain a failed prerequisite as a missing-host-evidence failure
   rather than misreporting exact-case Cygwin/POSIX behavior as a product defect. Establish the
   lowercase spelling inside the already-started Bash process with uppercase `GIT_INDEX_FILE`
   explicitly unset; capture a prerequisite proving the lowercase value is the expected non-empty
   path and the uppercase name is absent before calibrating that ordinary status sees the dirty file
   while the redirected status is empty. Do not pass the spelling through PowerShell's
   case-insensitive environment hashtable and accidentally repeat the uppercase case. Capture every
   child before the group's first assertion. Keep this child inside the same grouped result rather
   than adding a fourth `It`. Each refusal exits 4 with `CANT-VERIFY`, no completion, and an
   unchanged target fingerprint.
3. **Classification success does not excuse unreadable status.** Capture a real worktree with a
   corrupt index under PowerShell 7, native PowerShell 5.1, and Bash. `rev-parse` succeeds but status
   fails; require the same exit-4/no-completion/unchanged-tree contract.

These branches are not redundant: group 1 is the supported-host regression and the deliberately
reversed broken-Git/no-evidence decision; group 2 covers failed classification with evidence,
missing Git, and an observed ambient false-clean; group 3 covers post-classification examination.
Re-run, rather than duplicate, the committed clean-Git brownfield control in
`RootInstallerWarehouse.Tests.ps1` and the existing dirty update/brownfield refusal/override cases.
Strengthen the existing dirty-update case (without adding another `It`) with one clean tracked file
whose mtime is advanced after commit and another dirty tracked file; fingerprint `.git/index` before
and after refusal. Force `GIT_OPTIONAL_LOCKS=1`, calibrate that ordinary status both sees the dirty
file and changes the saved index bytes, restore those bytes exactly, then require the installer's
refusal to preserve the whole-tree fingerprint. This is the discriminating proof that the product
disables optional locking rather than inheriting a convenient host default.

Do not add full-installer children for defensive wrapper-only byte shapes. In bounded scratch probes,
prove Bash accepts exact `true` with no terminator/CR/LF/CRLF and rejects extra CR, blank records,
and spaces; prove the PowerShell helper reports a blank status line as observed output under both
PowerShell 7 and 5.1. Also prove the Windows scan-parent transitions
`C:/a/b -> C:/a -> C:/` and `//server/share/a -> //server/share`; a live UNC share is not required
for this namespace-only boundary.

Before implementation, the unchanged candidate must make the new matrix red while every child
surface is observed. After green, weaken the PowerShell native invocation and Bash evidence/refusal
branches independently in scratch; separately remove `--no-optional-locks` from each twin and
restore Bash's read-permission check. Each mutation must turn its discriminating case red, restore
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
  completion and release. Git Bash is not native Linux evidence.

## 2026-08-30 modern Git-for-Windows provider amendment

The first candidate run, `33328114479`, used Git for Windows `2.55.0.windows.5`. Its Bash no longer
reported the plan's frozen `OSTYPE=msys*` prerequisite, so the existing result stopped before the
lowercase-routing product child. This is a real product boundary, not merely a stale fixture:
`install.sh` uses the same `msys*` selector both for case-insensitive ambient Git routing and for
Windows-namespace repository discovery. A modern Git Bash update can therefore bypass the former
and traverse the wrong virtual-root model in the latter.

Retain the existing result, child, real alternate-index calibration, and result/`It`/process
cardinality. Amend only its host probe first so it independently recognizes either legacy
`OSTYPE=msys*` or modern `OSTYPE=cygwin*` with `MSYSTEM` in the finite set `MINGW32`, `MINGW64`,
`UCRT64`, or `CLANGARM64`; requires `builtin pwd -W`; validates a drive or UNC shape; and emits the
raw `OSTYPE`, `MSYSTEM`, and Windows path as inspectable provider evidence. The unchanged product
must then be observed red on the modern provider before implementation.

For the product, classify once inside the existing mutating update/brownfield preflight and share
that decision between both existing functions. Legacy `msys*` is selected. `cygwin*` is selected
only with one of the four allowlisted `MSYSTEM` values. Plain `cygwin*` with an empty `MSYSTEM`
remains generic Cygwin/POSIX; an unknown non-empty `MSYSTEM` fails `CANT-VERIFY` rather than silently
falling through as a possible future Git-for-Windows false green. A selected host must resolve the
target through `cd "$tgt" && builtin pwd -W` and validate its drive/UNC shape before either
case-insensitive environment scanning or Windows-root traversal; failure is `CANT-VERIFY`.
`builtin` is required because an ordinary or exported `pwd` function can shadow bare `pwd -W`; an
independent review reproduced that shadow locally while `builtin pwd -W` retained the real path.
Do not add `uname`, `cygpath`, executable inspection, a new test, or a generic-Cygwin simulation.

After the provider-red observation, replace the two duplicated `OSTYPE=msys*` selectors with the
single precomputed flag/cursor, compose all three distributions, and require the same existing
result to pass on local legacy Git Bash and the modern Windows CI provider. Generic Cygwin remains
an explicit unexecuted boundary; the finite identity plus built-in namespace capability prevents
silently granting it Git-for-Windows semantics.
