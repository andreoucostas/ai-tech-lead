# The retired fidelity gate remains callable by maintainers even though it is no longer wired to CI.
# Its invalid-ref path must produce the same concise usage failure under both PowerShell hosts and
# the Bash twin, without leaking PowerShell 5.1's NativeCommandError rendering.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
Reset-Tests

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$fidelityPs = Join-Path $repoRoot 'scripts/fidelity-check.ps1'
$fidelitySh = Join-Path $repoRoot 'scripts/fidelity-check.sh'
$invalidRef = 'b89-invalid-fidelity-ref-does-not-exist'
$expectedError = "could not archive legacy/dotnet from $invalidRef"

function Quote-ProcessArgument([string]$Value) {
    if ($Value -notmatch '[\s"]') { return $Value }
    $escaped = [regex]::Replace($Value, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-CapturedProcess([string]$Exe,[string[]]$Arguments) {
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $Exe
    $start.Arguments = (($Arguments | ForEach-Object { Quote-ProcessArgument $_ }) -join ' ')
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $start
    try {
        Assert $process.Start() "could not start $Exe"
        $out = $process.StandardOutput.ReadToEnd().Trim()
        $err = $process.StandardError.ReadToEnd().Trim()
        $process.WaitForExit()
        [pscustomobject]@{ Exit=$process.ExitCode; Out=$out; Err=$err }
    } finally { $process.Dispose() }
}

function Invoke-PowerShellFidelity([string]$Exe) { Invoke-CapturedProcess $Exe @('-NoProfile','-ExecutionPolicy','Bypass','-File',$fidelityPs,'dotnet',$invalidRef) }
function Invoke-BashFidelity([string]$Exe) { Invoke-CapturedProcess $Exe @($fidelitySh,'dotnet',$invalidRef) }

function Assert-InvalidRefContract($Result,[string]$HostName) {
    Assert ($Result.Exit-eq 2) "$HostName invalid-ref exit=$($Result.Exit), expected 2; stderr=$($Result.Err)"
    Assert ([string]::IsNullOrEmpty($Result.Out)) "$HostName invalid-ref stdout was not empty: $($Result.Out)"
    Assert ($Result.Err-eq$expectedError) "$HostName invalid-ref stderr differs: $($Result.Err)"
    Assert ($Result.Err-notmatch'NativeCommandError') "$HostName leaked NativeCommandError: $($Result.Err)"
}

$null = & git -C $repoRoot rev-parse --verify "$invalidRef`^{commit}" 2>$null
Assert ($LASTEXITCODE-ne 0) "setup: invalid ref unexpectedly exists: $invalidRef"

$isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
if ($isWindowsHost) {
    It 'fidelity-check.ps1 returns the friendly invalid-ref contract under the current host' {
        Assert-InvalidRefContract (Invoke-PowerShellFidelity (Get-PsExe)) 'current PowerShell host'
    }

    $winPs = if ($env:SystemRoot) { Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' } else { $null }
    if ($winPs -and (Test-Path -LiteralPath $winPs -PathType Leaf)) {
        It 'fidelity-check.ps1 returns the friendly invalid-ref contract under Windows PowerShell 5.1' {
            Assert-InvalidRefContract (Invoke-PowerShellFidelity $winPs) 'Windows PowerShell 5.1'
        }
    } else { Skip 'fidelity-check.ps1 Windows PowerShell 5.1 invalid-ref contract' 'invariant: this Windows host does not provide Windows PowerShell 5.1' }
} else {
    Skip 'fidelity-check.ps1 current-host invalid-ref contract' 'invariant: the retired PowerShell fidelity script is Windows-only; its System32 tar.exe contract is not broadened by this test'
    Skip 'fidelity-check.ps1 Windows PowerShell 5.1 invalid-ref contract' 'invariant: Windows PowerShell 5.1 is unavailable on a non-Windows host'
}

$bash = Get-BashPath
if ($bash) {
    It 'fidelity-check.sh returns the same friendly invalid-ref contract' {
        Assert-InvalidRefContract (Invoke-BashFidelity $bash) 'Bash'
    }
} else { Skip 'fidelity-check.sh invalid-ref contract' 'Bash is unavailable' }

exit (Write-TestSummary 'FidelityCheck.Tests')
