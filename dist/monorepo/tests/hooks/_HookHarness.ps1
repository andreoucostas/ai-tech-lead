# Dependency-free PowerShell hook test harness (no Pester required).
# Corporate Windows hosts may provide only Pester 3.x, so the shipped suite keeps its tiny local
# registry and invokes each subject under the exact PowerShell executable that launched the suite.

$script:PsExe = $null

function Get-PsExe {
    if ($script:PsExe) { return $script:PsExe }
    $script:PsExe = (Get-Process -Id $PID).Path
    return $script:PsExe
}

# Read redirected streams at the process boundary. Windows PowerShell 5.1 otherwise converts native
# stderr into decorated ErrorRecords, obscuring the subject's actual output.
function Invoke-RawProcess {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$Stdin = ''
    )
    foreach ($arg in $Arguments) {
        if ($arg -match '"') { throw "Cannot invoke a harness argument containing a quote: $arg" }
    }
    $stdinFile = [IO.Path]::GetTempFileName()
    $stdoutFile = [IO.Path]::GetTempFileName()
    $stderrFile = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($stdinFile, $Stdin, (New-Object System.Text.UTF8Encoding($false)))
        $argumentString = (($Arguments | ForEach-Object { '"' + $_ + '"' }) -join ' ')
        $process = Start-Process -FilePath $FileName -ArgumentList $argumentString -NoNewWindow -Wait -PassThru `
            -RedirectStandardInput $stdinFile -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
        return [pscustomobject]@{
            Exit = [int]$process.ExitCode
            Out = [IO.File]::ReadAllText($stdoutFile).Replace("`r`n", "`n").TrimEnd("`n")
            Err = [IO.File]::ReadAllText($stderrFile).Replace("`r`n", "`n")
        }
    } finally {
        foreach ($tempFile in $stdinFile,$stdoutFile,$stderrFile) {
            if (Test-Path -LiteralPath $tempFile) { [IO.File]::Delete($tempFile) }
        }
    }
}

function Assert-PowerShellSubject([string]$Path) {
    if (-not $Path.EndsWith('.ps1', [StringComparison]::OrdinalIgnoreCase)) {
        throw "PowerShell-only harness received unsupported subject: $Path"
    }
}

function Invoke-Hook {
    param([Parameter(Mandatory)][string]$Path, [string]$Json = '')
    Assert-PowerShellSubject $Path
    $previous = [Console]::OutputEncoding
    $changed = $false
    try {
        try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false); $changed = $true } catch { }
        return Invoke-RawProcess -FileName (Get-PsExe) `
            -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Path) -Stdin $Json
    } finally {
        if ($changed) { try { [Console]::OutputEncoding = $previous } catch { } }
    }
}

function RunArg {
    param([Parameter(Mandatory)][string]$Path, [string[]]$Arguments = @())
    Assert-PowerShellSubject $Path
    $stderrFile = [IO.Path]::GetTempFileName()
    $previous = [Console]::OutputEncoding
    $changed = $false
    try {
        try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false); $changed = $true } catch { }
        $out = & (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>$stderrFile
        return [pscustomobject]@{ Exit=[int]$LASTEXITCODE; Out=($out -join "`n"); Err=[IO.File]::ReadAllText($stderrFile) }
    } finally {
        if ($changed) { try { [Console]::OutputEncoding = $previous } catch { } }
        if (Test-Path -LiteralPath $stderrFile) { [IO.File]::Delete($stderrFile) }
    }
}

function Get-Decision {
    param($Result)
    if ($Result.Exit -eq 2) { return 'BLOCK' }
    if ($Result.Exit -eq 0 -and $Result.Out -match '"permissionDecision"\s*:\s*"deny"') { return 'DENY' }
    if ($Result.Exit -eq 0) { return 'ALLOW' }
    return "EXIT$($Result.Exit)"
}

function New-ClaudeEvent  { param($File,$Content) (@{ tool_name='Write'; tool_input=@{ file_path=$File; content=$Content } } | ConvertTo-Json -Compress -Depth 6) }
function New-CopilotEvent { param($File,$Content) (@{ toolName='create'; toolArgs=@{ path=$File; file_text=$Content } } | ConvertTo-Json -Compress -Depth 6) }

$script:Tests = [System.Collections.Generic.List[object]]::new()
function It {
    param([string]$Name,[scriptblock]$Body)
    try { & $Body; $script:Tests.Add([pscustomobject]@{ Name=$Name; State='PASS'; Msg=''; Invariant=$false }) }
    catch { $script:Tests.Add([pscustomobject]@{ Name=$Name; State='FAIL'; Msg=$_.Exception.Message; Invariant=$false }) }
}
function Skip {
    param([string]$Name,[string]$Why,[switch]$Invariant)
    $script:Tests.Add([pscustomobject]@{ Name=$Name; State='SKIP'; Msg=$Why; Invariant=[bool]$Invariant })
}
function Assert { param([bool]$Cond,[string]$Msg) if (-not $Cond) { throw $Msg } }
function Assert-Decision {
    param($Result,[string]$Expected,[string]$Ctx)
    $got = Get-Decision $Result
    if ($got -ne $Expected) { throw "$Ctx : expected $Expected, got $got (exit=$($Result.Exit))" }
}
function Reset-Tests { $script:Tests.Clear() }
function Write-TestSummary {
    param([string]$Title)
    $pass = @($script:Tests | Where-Object State -eq 'PASS').Count
    $fail = @($script:Tests | Where-Object State -eq 'FAIL').Count
    $skip = @($script:Tests | Where-Object State -eq 'SKIP').Count
    if (($pass + $fail + $skip) -eq 0) {
        $fail = 1
        $script:Tests.Add([pscustomobject]@{ Name='suite cardinality'; State='FAIL'; Msg='suite registered zero tests'; Invariant=$false })
    }
    foreach ($test in $script:Tests) {
        $mark = switch ($test.State) { 'PASS' {'[ok]'} 'FAIL' {'[FAIL]'} 'SKIP' {'[skip]'} }
        Write-Host ("{0} {1}{2}" -f $mark, $test.Name, $(if ($test.Msg) { " -- $($test.Msg)" } else { '' }))
    }
    # Skips are deliberately excluded. CI compares this executed-case count between PS7 and PS5.1;
    # counting a skipped Windows case would let the fallback host look equivalent without running it.
    if ($global:AtlEmitCaseCount) { Write-Host ("CASE_COUNT {0}" -f ($pass + $fail)) }
    Write-Host ("{0}: {1} passed, {2} failed, {3} skipped" -f $Title, $pass, $fail, $skip)
    $invariantSkips = @($script:Tests | Where-Object { $_.State -eq 'SKIP' -and $_.Invariant })
    if ($invariantSkips.Count -gt 0) {
        Write-Host ("INVARIANT-GUARDING SKIPS ({0}) -- not passing coverage:" -f $invariantSkips.Count)
        foreach ($item in $invariantSkips) { Write-Host ("  - {0}: {1}" -f $item.Name, $item.Msg) }
    }
    return $fail
}
