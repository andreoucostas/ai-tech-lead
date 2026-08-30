# B-210 — root meta-test hashing independent of inherited module paths

**Date:** 2026-08-30  
**Filed against:** unreleased v0.79.0 candidate `58a3d4231a25de2f077fed99a733e55e196b3cf7`  
**Planned:** v0.79.0  
**Status:** DESIGN LOCKED — implementation and exact-candidate CI pending

## Premise, value, and proportionality

Do this before release. A fresh whole-range review launched the existing Windows PowerShell 5.1
evidence through the maintainer's real hostile path: PowerShell 7 → `cmd.exe`, code page 437 →
`powershell.exe -NoProfile`. That child inherits a PowerShell-7-first `PSModulePath`. Windows
PowerShell then resolves an incompatible `Microsoft.PowerShell.Utility` module and cannot find
`Get-FileHash`. The unchanged root suites return UpdateDelivery 41/10,
InstallerConvergence 2/10, and RootInstallerWarehouse 4/8. In the last file both mutation checks
also go red for the infrastructure failure rather than their intended warehouse sentinels.

The same commands with only `PSModulePath` absent, allowing Windows PowerShell to reconstruct its
native roots, return 51/0, 12/0, and 12/0. Direct native Windows PowerShell is likewise green. This
separates a maintainer-harness dependency defect from product behavior, but the defect is still a
release blocker: the hostile CP437 verification path is repeatable, and the current record states
the 5.1 result without this launcher boundary.

Fixing is proportionate. Merely qualifying the invocation would preserve a recurring false red in
the exact path maintainers use to collect legacy-host evidence. The same-class census is only five
calls in three root suites, all of which already dot-source one root-only harness. One dependency-
free helper plus five substitutions removes the observed harm without adding a suite, result,
fixture, execution lane, product dependency, or shipped byte. Do not broaden this into a hashing
library, modify source/composed consumer harnesses, or add a permanent regression result.

Two independent read-only design reviews reproduced the boundary and approved this disposition.
Generic `Import-Module`, module-qualified invocation, and caller preloading are rejected: under the
poisoned environment they can select the incompatible PowerShell 7 module while appearing to
import successfully. Sanitising `PSModulePath` inside each suite is also rejected because it
mutates unrelated module resolution and treats the launcher symptom rather than the five-call
dependency.

## Locked implementation

1. Add `Get-TestFileSha256 -LiteralPath <path>` to the root-only
   `.claude/hooks/tests/_HookHarness.ps1`.
   - Open the literal path with `[IO.File]::OpenRead` and stream it through a fixed
     `[Security.Cryptography.SHA256]::Create()` instance.
   - Return exactly 64 uppercase hexadecimal characters with no separators.
   - Dispose both stream and hasher through `try`/`finally`. A missing, unreadable, locked, or
     otherwise unhashable file must throw; do not convert inability to examine into a digest or an
     empty value.
   - Use Windows PowerShell 5.1-compatible syntax and preserve the mandatory UTF-8 BOM.
2. Replace the complete same-class root-meta census:
   - `UpdateDelivery.Tests.ps1`: retain local `Get-Hash` as a delegating alias for minimal churn,
     and route its direct tree-fingerprint call through the shared helper (two substitutions).
   - `InstallerConvergence.Tests.ps1`: route both fingerprint calls through the shared helper.
   - `RootInstallerWarehouse.Tests.ps1`: route its one fingerprint call through the shared helper.
3. Correct the stale comment in `.claude/scripts/watch-ci.ps1`: describe WSD-061's unique provider
   as historical and WSD-064 as having withdrawn active macOS provider coverage. Change no watcher
   behavior.
4. Change no file under `src/` or `dist/`, no product code, no test body/cardinality, and no CI
   topology. This is a root maintainer-harness correction only.

## Adversarial verification contract

The already observed poisoned pre-fix runs are the primary red instrument:

- UpdateDelivery: 41 passed / 10 failed;
- InstallerConvergence: 2 passed / 10 failed;
- RootInstallerWarehouse: 4 passed / 8 failed, with both mutation oracles unusable for the wrong
  hash-provider reason.

After implementation, require all three existing suites to retain their clean cardinalities under:

1. the exact poisoned PowerShell-7 → `cmd.exe` CP437 → Windows PowerShell 5.1 launcher;
2. the same child command with `PSModulePath` absent as the native-root control;
3. PowerShell 7.

The helper itself must hash exact bytes `00 01 02 7F 80 FF` to
`DA2CB6AD175BC966DE5E79C6E16777F8A98B610C2424A894132DF2815BE50677` under poisoned Windows
PowerShell 5.1 and PowerShell 7. A second `abc` oracle must return
`BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD`; missing and exclusively
locked inputs must throw, and a successfully hashed file must be immediately reopenable and
deletable. A disposable helper-removal or one-call reversion may be used only if implementation
review needs additional discrimination; do not add a permanent case when the three captured
old-red suites already prove the boundary.

Require zero remaining `Get-FileHash` calls in the three affected suites, unchanged `It`
cardinality, BOM and AST integrity for every changed PowerShell file, and `git diff --check`. Because
the common root harness changes, run the full root meta suite locally and require the first exact
candidate Windows/Linux CI to pass. Obtain a fresh independent adversarial implementation review
of an immutable range, then have the whole-release reviewer re-audit the corrected evidence and
record before closing B-210.

## RCA boundary

No gate caught this because ordinary Windows PowerShell runs reconstruct native module roots and
ordinary CI uses PowerShell 7. The special CP437 child path was treated as a code-page probe, but
its inherited module-resolution state was neither controlled nor recorded. The result therefore
depended on the reviewer's parent shell.

The bounded same-class census found exactly five root-meta `Get-FileHash` uses across these three
suites and no separate implementation outside the shared harness. All five are in scope. Shipped
PowerShell scripts are not exposed by this observation: they do not use this root test harness, and
the supported consumer contract does not require launching Windows PowerShell 5.1 beneath a
PowerShell-7-poisoned module path. Reopen that boundary only on product evidence, not by analogy.
