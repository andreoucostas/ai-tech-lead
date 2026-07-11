# Dependency-free hook test harness (no Pester required) -- root meta-dev copy.
# Kept as a deliberate copy (not a reference to a shipped repo) so the root meta-hook tests run even
# if a template repo is absent/moved. Mirror of dist/*/tests/hooks/_HookHarness.ps1.
# See that file's header for the bash-fidelity rationale (drive .sh via Git's bin\bash.exe).

$script:HarnessBash = '__unset__'
$script:PsExe = $null

# Resolve a PowerShell host: prefer pwsh (7+), fall back to Windows PowerShell 5.1. 5.1-safe if/else.
function Get-PsExe {
    if ($script:PsExe) { return $script:PsExe }
    if (Get-Command pwsh -ErrorAction SilentlyContinue) { $script:PsExe = 'pwsh' } else { $script:PsExe = 'powershell' }
    return $script:PsExe
}

function Get-BashPath {
    if ($script:HarnessBash -ne '__unset__') { return $script:HarnessBash }
    # Null-safe: $env:ProgramFiles / (x86) are null on non-Windows pwsh and Join-Path on null THROWS,
    # which would crash before the bash-on-PATH fallback. Only add a Git path when its env var is set.
    $cands = @()
    if ($env:ProgramFiles)        { $cands += (Join-Path $env:ProgramFiles 'Git\bin\bash.exe') }
    if (${env:ProgramFiles(x86)}) { $cands += (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe') }
    $onPath = (Get-Command bash -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if ($onPath) { $cands += $onPath }
    foreach ($p in $cands) { if ($p -and (Test-Path -LiteralPath $p)) { $script:HarnessBash = $p; return $p } }
    $script:HarnessBash = $null
    return $null
}

function Invoke-Hook {
    param([Parameter(Mandatory)][string]$Path, [string]$Json = '')
    $ef = [IO.Path]::GetTempFileName()
    try {
        if ($Path -match '\.ps1$') {
            $out = $Json | & (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File $Path 2>$ef
        } else {
            $bash = Get-BashPath
            if (-not $bash) { return $null }
            $out = $Json | & $bash $Path 2>$ef
        }
        $code = $LASTEXITCODE
        $err  = [IO.File]::ReadAllText($ef)
        return [pscustomobject]@{ Exit = $code; Out = ($out -join "`n"); Err = $err }
    } finally { if (Test-Path -LiteralPath $ef) { [IO.File]::Delete($ef) } }
}

function Get-Decision {
    param($Result)
    if ($null -eq $Result) { return 'SKIP' }
    if ($Result.Exit -eq 2) { return 'BLOCK' }
    if ($Result.Exit -eq 0 -and $Result.Out -match '"permissionDecision"\s*:\s*"deny"') { return 'DENY' }
    if ($Result.Exit -eq 0) { return 'ALLOW' }
    return "EXIT$($Result.Exit)"
}

# --- tiny test registry / assertions (no external framework) ---
$script:Tests = [System.Collections.Generic.List[object]]::new()
function It      { param([string]$Name,[scriptblock]$Body)
    try { & $Body; $script:Tests.Add([pscustomobject]@{ Name=$Name; State='PASS'; Msg='' }) }
    catch { $script:Tests.Add([pscustomobject]@{ Name=$Name; State='FAIL'; Msg=$_.Exception.Message }) } }
function Skip    { param([string]$Name,[string]$Why) $script:Tests.Add([pscustomobject]@{ Name=$Name; State='SKIP'; Msg=$Why }) }
function Assert  { param([bool]$Cond,[string]$Msg) if (-not $Cond) { throw $Msg } }

function Reset-Tests { $script:Tests.Clear() }
function Write-TestSummary {
    param([string]$Title)
    $pass = ($script:Tests | Where-Object State -eq 'PASS').Count
    $fail = ($script:Tests | Where-Object State -eq 'FAIL').Count
    $skip = ($script:Tests | Where-Object State -eq 'SKIP').Count
    foreach ($t in $script:Tests) {
        $mark = switch ($t.State) { 'PASS' {'[ok]'} 'FAIL' {'[FAIL]'} 'SKIP' {'[skip]'} }
        Write-Host ("{0} {1}{2}" -f $mark, $t.Name, $(if ($t.Msg) { " -- $($t.Msg)" } else { '' }))
    }
    Write-Host ("{0}: {1} passed, {2} failed, {3} skipped" -f $Title, $pass, $fail, $skip)
    return $fail
}
