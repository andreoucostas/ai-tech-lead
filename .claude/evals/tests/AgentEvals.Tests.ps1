# No-network recurrence test for the B-41 live harness.
$ErrorActionPreference = 'Stop'
$runner = Join-Path (Split-Path -Parent $PSScriptRoot) 'run-agent-evals.ps1'
& pwsh -NoProfile -File $runner -SelfTest
if ($LASTEXITCODE -ne 0) { throw "Agent eval self-test failed with exit $LASTEXITCODE" }

if ($IsWindows) {
    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path -LiteralPath $windowsPowerShell)) {
        throw 'Windows PowerShell 5.1 is unavailable; the agent-eval minimum-version boundary was not tested.'
    }
    $legacyOutput = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $runner -SelfTest 2>&1
    $legacyText = $legacyOutput -join "`n"
    if ($LASTEXITCODE -eq 0) { throw 'Agent eval runner unexpectedly accepted Windows PowerShell 5.1.' }
    if ($legacyText -notmatch 'ScriptRequiresUnmatchedPSVersion|requires PowerShell 7\.0') {
        throw "Windows PowerShell 5.1 did not report the declared version prerequisite:`n$legacyText"
    }
    if ($legacyText -match 'CannotConvertArgumentNoMessage|utf8NoBOM') {
        throw "Windows PowerShell 5.1 reached the old encoding failure instead of failing at the version prerequisite:`n$legacyText"
    }
}
