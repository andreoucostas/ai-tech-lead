# No-network recurrence test for the B-41 live harness.
$ErrorActionPreference = 'Stop'
$runner = Join-Path (Split-Path -Parent $PSScriptRoot) 'run-agent-evals.ps1'
& pwsh -NoProfile -File $runner -SelfTest
if ($LASTEXITCODE -ne 0) { throw "Agent eval self-test failed with exit $LASTEXITCODE" }

if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path -LiteralPath $windowsPowerShell)) {
        throw 'Windows PowerShell 5.1 is unavailable; the agent-eval minimum-version boundary was not tested.'
    }
    # Windows PowerShell 5.1 promotes redirected native stderr to ErrorRecord. With this file's
    # Stop preference that would terminate here, before we could assert the declared #requires
    # failure. Capture that expected stderr under Continue, then restore the suite preference.
    $savedErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $legacyOutput = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $runner -SelfTest 2>&1
        $legacyExit = [int]$LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorActionPreference
    }
    $legacyText = $legacyOutput -join "`n"
    if ($legacyExit -eq 0) { throw 'Agent eval runner unexpectedly accepted Windows PowerShell 5.1.' }
    if ($legacyText -notmatch 'ScriptRequiresUnmatchedPSVersion|requires PowerShell 7\.0') {
        throw "Windows PowerShell 5.1 did not report the declared version prerequisite:`n$legacyText"
    }
    if ($legacyText -match 'CannotConvertArgumentNoMessage|utf8NoBOM') {
        throw "Windows PowerShell 5.1 reached the old encoding failure instead of failing at the version prerequisite:`n$legacyText"
    }
}
