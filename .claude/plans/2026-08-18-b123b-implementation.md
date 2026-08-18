# B-123b implementation report — premise rejected

## Outcome

No code change. B-89's remedy does not fit this site because `.claude/scripts/build-block-manifest.ps1` begins with `#requires -Version 7.0`. Windows PowerShell 5.1 refuses the script before line 183 can execute, so its `Stop` plus native-stderr behavior is unreachable on the host where that behavior exists. Adding a temporary `Continue` wrapper would be redundant code for a path that only runs under pwsh 7.

## Evidence

Command:

```powershell
<windows>\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File .claude/scripts/build-block-manifest.ps1 -File NO-SUCH.md
```

Observed:

```text
The script 'build-block-manifest.ps1' cannot be run because it contained a "#requires" statement for Windows PowerShell 7.0.
FullyQualifiedErrorId : ScriptRequiresUnmatchedPSVersion
ACTUAL_PS51_EXIT=1
```

The underlying idiom was separately reconstructed under 5.1:

```powershell
$ErrorActionPreference='Stop'; try { & git show 'no-such-tag:no-such-path' 2>$null } catch { $_.FullyQualifiedErrorId }
```

Observed `NativeCommandError`, confirming B-89's general fact but not making it reachable in this script.

## Red-test finding

The requested before-fix failure cannot be constructed in the actual script: 5.1 stops at `#requires`, while pwsh 7 does not turn native stderr into a terminating error by default. Therefore no honest before/after exists and no assertion was changed.

## RCA

The closing grep that filed B-123b matched syntax without checking the script's declared runtime. Other syntax-only sweeps are exposed to the same false-positive class when reachability or host constraints are ignored.
