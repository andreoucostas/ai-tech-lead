# Dependency-free hook test harness (no Pester required).
# Why not Pester: corporate Windows boxes ship only Pester 3.x, and mandating a Pester 5 install
# breaks the framework's air-gapped/on-prem stance (the same reason we roll our own elsewhere).
# This harness runs a hook by piping a JSON event to its stdin and capturing exit code + stdout +
# stderr -- and it drives BOTH twins: .ps1 directly via pwsh, .sh via Git's bin\bash.exe wrapper.
#
# CRITICAL fidelity note: a .sh hook MUST be run through a bash whose PATH includes /usr/bin
# (cat/grep/sed/jq). The raw usr\bin\bash.exe launched from Windows lacks /usr/bin, so `input=$(cat)`
# yields nothing and the hook degrades-safe to exit 0 -- a FALSE PASS. Git's bin\bash.exe wrapper
# sets the full MSYS environment, matching how the hook runs in production on Unix. We resolve that.

$script:HarnessBash = '__unset__'
$script:PsExe = $null

# Resolve a PowerShell host: prefer pwsh (7+), fall back to Windows PowerShell 5.1 (powershell.exe).
# The framework explicitly supports 5.1-only boxes (settings.windows.json), so we must not assume
# pwsh is installed. 5.1-safe: plain if/else, no ternary / null-coalescing.
function Get-PsExe {
    if ($script:PsExe) { return $script:PsExe }
    if (Get-Command pwsh -ErrorAction SilentlyContinue) { $script:PsExe = 'pwsh' } else { $script:PsExe = 'powershell' }
    return $script:PsExe
}

function Get-BashPath {
    if ($script:HarnessBash -ne '__unset__') { return $script:HarnessBash }
    $cands = @(
        (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe')
    )
    # Last resort: a `bash` on PATH (Linux/macOS CI, or a user who put Git's bin on PATH).
    $onPath = (Get-Command bash -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if ($onPath) { $cands += $onPath }
    foreach ($p in $cands) { if ($p -and (Test-Path -LiteralPath $p)) { $script:HarnessBash = $p; return $p } }
    $script:HarnessBash = $null
    return $null
}

# Run a hook with $Json on stdin. Returns @{Exit;Out;Err} -- or $null for a .sh when no bash exists
# (caller treats $null as "skip", never as pass/fail).
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

# Normalise a hook result to a decision: BLOCK (Claude exit 2), DENY (Copilot JSON), ALLOW (exit 0,
# no deny), SKIP (no bash), or EXITn for anything unexpected.
function Get-Decision {
    param($Result)
    if ($null -eq $Result) { return 'SKIP' }
    if ($Result.Exit -eq 2) { return 'BLOCK' }
    if ($Result.Exit -eq 0 -and $Result.Out -match '"permissionDecision"\s*:\s*"deny"') { return 'DENY' }
    if ($Result.Exit -eq 0) { return 'ALLOW' }
    return "EXIT$($Result.Exit)"
}

# Event-shape builders: same logical write, expressed in each surface's field names. Used to feed
# identical content to both twins and to exercise the Claude (PascalCase) vs Copilot (camelCase) paths.
function New-ClaudeEvent  { param($File,$Content) (@{ tool_name='Write'; tool_input=@{ file_path=$File; content=$Content } } | ConvertTo-Json -Compress -Depth 6) }
function New-CopilotEvent { param($File,$Content) (@{ toolName='create'; toolArgs=@{ path=$File; file_text=$Content } } | ConvertTo-Json -Compress -Depth 6) }

# --- tiny test registry / assertions (no external framework) ---
$script:Tests = [System.Collections.Generic.List[object]]::new()
function It      { param([string]$Name,[scriptblock]$Body)
    try { & $Body; $script:Tests.Add([pscustomobject]@{ Name=$Name; State='PASS'; Msg='' }) }
    catch { $script:Tests.Add([pscustomobject]@{ Name=$Name; State='FAIL'; Msg=$_.Exception.Message }) } }
function Skip    { param([string]$Name,[string]$Why) $script:Tests.Add([pscustomobject]@{ Name=$Name; State='SKIP'; Msg=$Why }) }
function Assert  { param([bool]$Cond,[string]$Msg) if (-not $Cond) { throw $Msg } }
function Assert-Decision { param($Result,[string]$Expected,[string]$Ctx)
    $got = Get-Decision $Result
    if ($got -ne $Expected) { throw "$Ctx : expected $Expected, got $got (exit=$($Result.Exit))" } }

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
