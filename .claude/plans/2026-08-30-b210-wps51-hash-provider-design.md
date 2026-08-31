# B-210 — Windows PowerShell 5.1 intermediate-launch module paths

**Date:** 2026-08-30–2026-08-31
**Filed against:** unreleased v0.79.0 candidate `58a3d4231a25de2f077fed99a733e55e196b3cf7`
**Status:** CLOSED — original code premise rejected; maintainer launcher corrected; no product or test change

## Final decision

Do not add a hash helper to the root test harness or to one shipped script. The observed failures
were caused by an invalid maintainer launcher, not by missing framework hashing code.

PowerShell 7 normally adjusts module paths when it starts Windows PowerShell directly. It cannot do
that when it starts an intermediate `cmd.exe`, which then forwards the unmodified PowerShell 7
`PSModulePath` to `powershell.exe`. Windows PowerShell resolves the incompatible PowerShell 7
`Microsoft.PowerShell.Utility` module first and loses module-backed commands including
`Get-FileHash`. Microsoft documents this exact boundary and requires the intermediate child
environment to remove `PSModulePath`:

```powershell
cmd.exe /d /c "set PSModulePath=&& chcp 437 >nul && powershell.exe -NoProfile -ExecutionPolicy Bypass -File <suite>"
```

The canonical maintainer command is now recorded in `DEVELOPING.md`. The independently true stale
comment in `.claude/scripts/watch-ci.ps1` is corrected to say WSD-061's unique provider is
historical and WSD-064 withdrew active macOS coverage. It changes no behavior and is not a hash
implementation.

## Evidence that rejected the original design

The original, unnormalised PowerShell 7 → `cmd.exe`/CP437 → Windows PowerShell 5.1 launch made the
unchanged suites return:

- UpdateDelivery 41/10;
- InstallerConvergence 2/10;
- RootInstallerWarehouse 4/8, with both mutation oracles failing for the wrong hash-provider
  reason.

An experimental root-only streaming SHA-256 helper replaced exactly five test-suite
`Get-FileHash` calls. Its fixed binary and `abc` digests, missing/locked-file throws, and handle
disposal were correct under both PowerShell hosts. It made UpdateDelivery 51/0 and
RootInstallerWarehouse 12/0, but InstallerConvergence only 10/2. The two remaining failures reached
the shipped PowerShell installer, whose own `Get-FileHash` was unavailable. The installer correctly
entered WSD-051's `CANT-VERIFY` path, planned preservation, changed no outside bytes, and retained
known retired files rather than deleting without a digest. This proved that hardening five root
calls could not repair the process environment and could mask it. The helper and all five
substitutions were therefore reverted exactly before commit.

The same unchanged suites, from the same parent process and at the same code page, were then run
with only the documented `PSModulePath` removal. Primary execution returned UpdateDelivery 51/0,
InstallerConvergence 12/0, and RootInstallerWarehouse 12/0. Both warehouse mutations went red for
their intended `mutated warehouse refusal` sentinel and restored `install.ps1`/`install.sh`
byte-identically. Independent reviewers had already reproduced the same three corrected-launch
counts. This is the required red/green discrimination: one child-environment variable, no code or
test-cardinality difference.

## Adversarial review disposition

Two initial design reviews approved the five-call helper before the product-reachable convergence
case ran. That approval is superseded rather than silently reused. Two fresh opposing reviews then
started from the 10/2 counterexample. One initially recommended a bounded shipped-installer helper;
the other rejected product expansion. A wider census found another shipped runtime dependency in
`docs-sync-check.ps1` plus shipped test dependencies, and Microsoft’s official launch contract
showed that an installer-only change would be partial support for an invalid environment. Both
reviewers independently converged on **REVERT / PROCEDURE FIX**.

Rejected alternatives:

1. **Keep the root helper.** It makes selected assertions green while the same process remains
   unable to load other standard modules; the full evidence surface stays untrustworthy.
2. **Fix only the installer.** It would improve one safe-degradation case while leaving
   `docs-sync-check.ps1`, shipped tests, and any other module-backed command exposed, falsely
   implying coherent poisoned-module support.
3. **Add a permanent regression result.** The defect is already discriminated by the exact
   unnormalised/normalised launch pair. Another result would add maintenance without a new decision.
4. **Declare product failure from the 10/2 run.** WSD-051 deliberately preserves unhashable
   retirement candidates with explicit `CANT-VERIFY`; the affected invocation is outside the
   published path (`pwsh` when present, native Windows PowerShell only when `pwsh` is absent).

Reopen product hardening only if a correctly launched supported Windows PowerShell process still
fails, or field evidence justifies supporting poisoned intermediate process trees. At that point,
sweep all shipped runtime module dependencies and lock one coherent compatibility design rather
than patching one call.

## RCA boundary

No canonical maintainer recipe documented the intermediate-process environment rule, so repeated
CP437 probes treated a known PowerShell launcher hazard as artifact evidence. The same class is any
PowerShell 7 → intermediate process → Windows PowerShell launch, not just hashing and not just these
three suites. The control belongs at the process boundary. `DEVELOPING.md` now states it once and
warns against command-by-command masking.
