# B-219 — Windows-only, PowerShell-only framework consolidation

**Status:** IMPLEMENTED; final immutable-range review and v0.83.0 release pending.
**Base:** v0.82.0 (`5b918fb`), released and CI-green before this work begins.

## Decision

The framework supports native Windows execution only. PowerShell 7 is primary; Windows PowerShell
5.1 remains the fallback for installation, composition, validation, shipped hooks, the context
measurement, and their deterministic tests. Maintainer release and live-eval tooling may require
PowerShell 7. Linux, WSL, macOS, BSD, and Copilot cloud hook execution are unsupported and untested,
but the framework does not reject consumer source files or manual tools merely because they use
Bash.

Remove every active framework-owned Bash implementation and registration, while retaining frozen
historical canaries and textual history. New installations contain no active shell script. Updates
delete only previously owned bytes whose path-specific digest is known; consumer-owned, modified,
unsafe, and unverifiable remnants are preserved and diagnosed.

## Public contract

- `install.ps1` is the only installer. Document `pwsh -NoProfile -File install.ps1` and the
  `powershell.exe` fallback.
- Claude Code 2.1.141+ is the supported client. Project settings enable the PowerShell tool, set
  `defaultShell` to PowerShell, and mark every command hook `shell: powershell`; agent frontmatter
  exposes PowerShell rather than Bash.
- Copilot hooks retain only explicit Windows `powershell` entries which invoke `pwsh`; Copilot
  cloud hook enforcement is withdrawn because that host ignores the PowerShell leg.
- The optional consumer Git-hook installer is retired. v0.83 accepts `-GitHooks` only to refuse
  before mutation with an actionable exit-2 migration message; v0.84 removes the parameter.

## Implementation contract

1. Fix every dual-host aggregate/child boundary to preserve the current PowerShell executable and
   repair `$IsWindows`-style coverage loss before adding native 5.1 CI. The final workflow exposes
   eight required contexts: root plus three dist matrices under PS7, and the same four under PS5.1.
2. Make `install.ps1` the sole ownership-policy source. Pin its extracted policy to explicit
   expected sets. Migrate the context-footprint baseline to schema v2 with PowerShell as the engine,
   after proving its measured values equal the twin-derived v0.82 baseline.
3. Delete all active `.sh` files and the two extensionless maintainer Git-hook launchers. Preserve
   the four `meta/canaries` shell fixtures and root `.gitattributes` rule. Retain
   `fidelity-check.ps1`, `settings.windows.json`, BOM/code-page/parser/error-domain/containment/
   reparse/case/order/retirement controls, and PowerShell semantic tests.
4. Replace maintainer Git hooks with `check-outgoing-commits.ps1`, called before every push path in
   `push-and-check.ps1` and `release.ps1`. It checks all commits absent from the destination remote,
   every commit subject, and every ACMR blob against the BOM and canonical guard rules; merge
   commits are compared with every parent. Inability to enumerate is exit 3 before push.
5. Convert supported CI examples to explicit Windows/PowerShell. Delete the Linux-container
   Bitbucket Cloud example and retire its installed bytes.
6. Add cumulative v0.83 retirements for all installed Bash paths, `setup-git-hooks.ps1`, and the
   Bitbucket sample, harvesting every released composed-dist digest through v0.82. Deletion still
   requires valid immediately previous framework ownership plus a known current digest.
7. Never auto-delete `.git/hooks/pre-commit`. Safely inspect only a contained default Git dir. If
   either historical generated body or a retired-helper reference remains, preserve the whole
   `{setup-git-hooks.<ext>, guard.<ext>}` dependency closure and emit a durable degraded-state
   warning plus doctor row. Brownfield, custom, linked, external, reparse, unreadable, and
   `core.hooksPath` cases are report-only.
8. Report exact obsolete framework commands in protected consumer docs/settings/CI without
   overwriting them. Keep `-WhatIf` and apply classifications identical.
9. Replace twin/Bash gates with structural active-root checks, require exactly 18 registrations
   (six Claude PS7, six Claude PS5.1, six Copilot PowerShell), and retain stale Bash-command
   recognition in the dead-instruction checker. Refactor tests by assertion, retaining all unique
   PowerShell behavior with positive cardinality.
10. Keep `install.sh` in the historical release staging allowlist. Record the lost installer,
    hook-render, and composer differential oracles and their compensating controls.

## Verification contract

Calibrate each new instrument red before accepting green. Required hostile cases cover PowerShell
host leakage, skipped Windows cases, planted active shell surfaces, wrong-case registrations,
policy drift, missing historic hashes, the retained `install.sh` history pattern, outgoing commit
subjects/content/merges/unreachable remotes, every legacy-hook and retirement classification,
protected dead references, repeated update, and `-WhatIf` parity. Run composition, validation,
footprint, meta tests, and all three shipped suites directly under PS7 and PS5.1, including hostile
code page and BOM/AST sweeps. Run live Windows Claude and Copilot positive/no-hook/side-effect/
ancestry canaries. Rebuild all dists from `src`, require a clean generated diff, all eight Windows
CI contexts, and independent immutable-range review before the v0.83 tag.

## Review disposition

The fresh-context review prevented deletion of the unowned consumer hook, exposed false PS5 host
evidence and hidden semantic tests, and required durable residual diagnostics. Claude CLI Opus at
xhigh effort additionally found the historical `install.sh` release-allowlist dependency, the
`$IsWindows` coverage inversion, and the loss of maintainer controls. Those corrections are locked
above. Two reviewer suggestions were rejected after checking current vendor contracts: Claude's
`defaultShell` does not replace the PowerShell-tool opt-in or per-hook shell field, and retaining a
Linux-only Bitbucket recipe would contradict the selected support boundary.

## Cutover evidence

Before deleting either implementation, both v0.82 footprint engines independently reproduced
`meta/context-footprint.json` at SHA-256
`c63a76c20a5ea13d8cede4890026e0058da993153ea929d58d8eb3f7affea3b8`; each also exercised the
cross-engine hook-render equality check. The first schema-v2 PowerShell update then compared the
complete `ceilings`, `dists`, and `derived` trees against schema v1 and found them byte-for-byte
equal after JSON normalization. Only `schema-version`, `engine`, and `generated-by` changed at the
cutover. A direct native Windows PowerShell 5.1 check reproduced the same baseline and exposed one
host-only display-rounding split (3.73% versus 3.74%), which was corrected with decimal arithmetic.

## Live Windows host evidence

On 2026-09-04, isolated positive and no-hook controls ran against Claude Code 2.1.247 and the
locally reported Copilot CLI 1.0.80. Claude emitted successful `SessionStart` and
`UserPromptSubmit` hook events; marker ancestry was `pwsh -> pwsh -> claude.exe`, the restricted
native tool run advertised and used only `PowerShell`, and an interactive `!` command wrote a
marker from PowerShell 7.6.5. The equivalent no-hook control wrote no marker. Copilot executed both
minimal `powershell` registrations through PowerShell 7.6.5 with ancestry
`pwsh -> pwsh -> copilot.exe -> node.exe`; its no-hook control also wrote no marker. Copilot's
payload omits an event-name field, so the mapping from its two distinct payload shapes to the two
configured events is an inference, not a direct event-name observation. Its debug provenance also
contained conflicting internal version strings, so 1.0.80 is reported only as the CLI's own version
output. These canaries prove local Windows registration, execution, side effects, negative control,
and process ancestry; they do not establish Copilot cloud support, PS5.1 Copilot support, or the
semantics of all six production hooks. A BOM-prefixed Copilot hooks JSON was separately observed
red as invalid JSON, reinforcing the BOM-less JSON contract.

## Test-retirement classification and dual-host evidence

The PowerShell-only test cutover was classified at file/assertion level before the active shell
files were removed:

- **Bash-only, deleted:** `SetupGitHooks.Tests.ps1` and the B-197 Bash temporary-lifecycle case in
  `UpdateDelivery.Tests.ps1`. Bash execution arms were removed from `DocsSyncCheck.Tests.ps1`,
  `GuardPatternErrors.Tests.ps1`, `FrameworkDoctor.Tests.ps1`, `UpdateDelivery.Tests.ps1`, and the
  source hook/script suites. Historical Bash hook bodies and the 18 v0.83 paths remain only as
  migration/retirement input data.
- **Comparison-only, deleted or replaced:** root `ScriptTwinCoverage.Tests.ps1`; source
  `TwinParity.Tests.ps1` and `ScriptTwinParity.Tests.ps1`. The latter two were replaced by
  `PowerShellSemantics.Tests.ps1` and `ScriptBehavior.Tests.ps1`, which keep the independently useful
  PowerShell outcomes without treating agreement with a second implementation as the oracle.
- **Unique PowerShell behavior, retained:** `Composer.Tests.ps1` pins every installer-derived policy
  set; `UpdateDelivery.Tests.ps1` retains protected-byte, collision/archive, reparse, optional-Git,
  dirty-tree, PS5/no-pwsh, retirement, and refusal behavior; `FrameworkDoctor.Tests.ps1` retains
  strict JSON, liveness, protected-sync, stamp, marker, legacy-hook, and retired-residue states;
  `GuardPatternErrors.Tests.ps1` retains both PowerShell policy error domains. The per-hook source
  files retain every Claude/Copilot surface decision, route, throttle, state, and script-specific
  branch, with explicit nonzero manifests/cardinality in both aggregate runners.
- **PowerShell behavior formerly driven through Bash fixtures, retained natively:** post-write
  subprocess/routing fixtures now use Windows command fixtures; doctor and installer legacy Bash
  states are parsed as inert historical bytes rather than executed; optional-Git failure/routing
  uses a Windows `git.cmd` fixture and direct PS7/PS5 children; the hook harnesses use native Windows
  scratch/process handling.

Before the runner fix, a direct native `powershell.exe` aggregate run was observed resolving its
children through `pwsh`, so it could report green without executing the leaf suites on 5.1. The
final `RunnerHost.Tests.ps1` run was 9/0 under both PS7 and native PS5.1. Its nonempty matrix
observed both explicit host boundaries from either parent, including exact parent/child executable
matches and major-version assertions. The old prefer-pwsh assignment was then planted independently
in both runner copies: both mutations
went red at the host-preservation probe before any `CHILD_HOST` leaf marker, and the restored files
returned to the counts above.

The PowerShell-only `UpdateDelivery.Tests.ps1` matrix was directly observed at 30 passed, 0 failed,
1 skipped under both PS7 and native Windows PowerShell 5.1. The skipped hostile case is specifically
the dangling retired-path symlink/reparse branch: this Windows host does not grant the running
process the privilege needed to construct an unprivileged dangling file symbolic link. The test
reports that environment limitation explicitly; the production branch was not claimed green from
this host. The separate wrong-case ownership hostile case and all-18-path residual case did execute
and pass under both hosts.

After the final review corrections, the complete root suite ran directly under both hosts: 32 suite
files, 308 passing semantic cases, and zero suite failures on each. The two case-count manifests
were byte-identical at SHA-256
`79614ED45F6A0ABDFA2B349D6FD4AC3EE907397B7013B31E41E96327CB2929AD`. The aggregate output also
contained the expected red transcripts from the release-context, installer-contract,
warehouse-detection, and guard-pattern hostile mutations; their containing suites returned green
only after restoring the production artifacts.

## Fresh-context implementation review

A fresh Terra/high context independently reviewed immutable range `5b918fb..30e608e` with no
Critical, High, or actionable Medium findings. It directly observed `PowerShellTopology` 3/0,
native PS5.1 `RunnerHost` 9/0 (including both host-leak mutations), `OutgoingCommits` 12/0, and the
dotnet validator under both PS7 and PS5.1. It inspected retirement/deletion authority, reparse
containment, prior-manifest and digest gating, legacy-hook dependency preservation, `-WhatIf`
planning, permanent doctor diagnostics, every release/push guard call site, merge-parent blob
inspection, the eight-context workflow, and added-surface necessity.

The reviewer did not independently run the full root aggregate, all three shipped hook suites,
hosted GitHub Actions, live Claude/Copilot canaries, or every prose/generated change. Its bounded
PS5.1 `InstallerConvergence` attempt did not finish, so it was not counted as evidence. Those are
explicit reviewer gaps rather than inherited green claims; the direct aggregate/dist/live evidence
above came from the implementation session.

## Claude Opus/xhigh implementation review

Claude Code 2.1.260 with Opus/xhigh reviewed immutable candidate `5b918fb..e92f5c2` read-only. It
found one blocker: the new whole-blob outgoing guard rejected the framework's own synthetic guard
fixtures and a historical certification literal, so the mandated push path could not ship the
candidate. It also found the historical PowerShell hook digest had been calculated with a newline
that `WriteAllText` never emitted, helper-reference terminators differed between deletion and
diagnostic paths, caller refusal and new settings assertions lacked red calibration, the consumer
docs-sync workflow unnecessarily doubled, the historical staging replay had a sliding window,
binary blobs were misclassified as unreadable text, greenfield/brownfield carriers could receive a
false migration diagnosis, and the tag check inspected an empty already-pushed range.

The implementation now uses a separately reviewed path-and-SHA exception ledger: four exact
canonical fixture copies plus the exact pre-fix historical certification blob, with every applied
exception printed. Changed fixture bytes remain blocked. The hook digest and all terminator classes
are corrected in installer and doctor; executable caller refusal, `defaultShell`, per-hook shell,
semicolon reference, body digest, binary, and already-pushed revision cases are calibrated. The
consumer workflow remains one PS7 Windows job; authoring CI retains both hosts. The staging test
has an immutable `v0.76.0..v0.77.0` anchor, non-PowerShell binary blobs are explicitly skipped,
migration scans apply only to updates, and tag pushes use `-AlwaysInspectRevision`. The v0.84
parameter-removal follow-up is B-220 and WSD-073 carries an implementation amendment.

The review's suggestion to delete the installer metadata policy was rejected: the frozen contract
requires the composer to extract and independently pin protected, persistent, metadata, and
excluded sets from the installer as the single policy authority. The arrays are declarative
composer input rather than runtime installer branches, and their comments state that boundary.

A bounded Terra follow-up over `e92f5c2..6351dfe` found one High correction defect: the new binary
skip also accepted a BOM-prefixed `.ps1` containing NUL, bypassing strict decode and the guard. The
skip now applies only to non-PowerShell blobs; PowerShell NUL/binary content is a push refusal, with
an exact BOM+NUL hostile case. No other actionable finding was reported in that correction delta.

The first real outgoing-range scan after that correction went red on the hostile test source itself:
the test had embedded its blocked credential-shaped token literally. The fixture now assembles the
same token at runtime. Both supported hosts still observe the intended NUL refusal, while the source
requires no content exception. This is release-specific evidence that the outgoing guard examines
the immutable blobs it actually governs rather than only passing synthetic repository fixtures.
