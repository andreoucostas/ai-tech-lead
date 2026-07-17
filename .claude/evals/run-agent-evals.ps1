# B-41 maintainer-only live agent eval harness. This intentionally has no bash twin: meta tooling
# is PowerShell-only by WSD-012. It never runs in CI and spends API/subscription budget only with
# the explicit -Live switch.
[CmdletBinding(DefaultParameterSetName = 'Explain')]
param(
    [Parameter(ParameterSetName = 'Live', Mandatory)][switch]$Live,
    [Parameter(ParameterSetName = 'SelfTest', Mandatory)][switch]$SelfTest,
    [Parameter(ParameterSetName = 'Live')][string[]]$Scenario,
    [Parameter(ParameterSetName = 'Live')][string]$Model = 'sonnet',
    [Parameter(ParameterSetName = 'Live')][ValidateRange(30, 1800)][int]$TimeoutSeconds = 300,
    [Parameter(ParameterSetName = 'Live')][bool]$KeepScratch = $true,
    [Parameter(ParameterSetName = 'Live')][string]$ResultsPath
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$scenarioPath = Join-Path $PSScriptRoot 'scenarios.json'
if (-not $ResultsPath) { $ResultsPath = Join-Path $repo 'meta/eval-results.md' }

function Assert-Bom([string]$Path) {
    $bytes = [IO.File]::ReadAllBytes($Path)
    return $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
}

function New-EvalRepo([string]$Path) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    @'
<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>
'@ | Set-Content -LiteralPath (Join-Path $Path 'EvalFixture.csproj') -Encoding utf8NoBOM
    New-Item -ItemType Directory -Path (Join-Path $Path 'src'), (Join-Path $Path 'tests') | Out-Null
    @'
namespace EvalFixture;
public static class Calculator
{
    public static bool IsWithinInclusiveRange(int value, int min, int max) => value >= min && value < max;
}
'@ | Set-Content -LiteralPath (Join-Path $Path 'src/Calculator.cs') -Encoding utf8NoBOM
    @'
$source = Get-Content -Raw "$PSScriptRoot/../src/Calculator.cs"
if ($source -notmatch 'value <= max') { throw 'inclusive upper bound is broken' }
Write-Output 'PASS: inclusive range'
'@ | Set-Content -LiteralPath (Join-Path $Path 'tests/Test-Calculator.ps1') -Encoding utf8NoBOM
    git -C $Path init --quiet
    git -C $Path config user.email 'agent-evals@invalid.local'
    git -C $Path config user.name 'Agent Evals'
    git -C $Path add -A
    git -C $Path commit --quiet -m 'fixture baseline'
}

function Install-Framework([string]$Path) {
    $output = & pwsh -NoProfile -File (Join-Path $repo 'install.ps1') -Stack dotnet $Path 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "Fixture framework install failed:`n$output" }
    return $output
}

function Read-Transcript([string]$Path) {
    $events = [Collections.Generic.List[object]]::new()
    foreach ($line in Get-Content -LiteralPath $Path) {
        if (-not $line.Trim()) { continue }
        try { $events.Add(($line | ConvertFrom-Json -Depth 100)) } catch { throw "Invalid stream JSON: $($_.Exception.Message)" }
    }
    if ($events.Count -eq 0) { throw 'Transcript contained no JSON events.' }
    [pscustomobject]@{ Events = $events; Raw = [IO.File]::ReadAllText($Path) }
}

function Invoke-ClaudeProcess([string]$WorkingDirectory, [string]$Prompt, [string]$TranscriptPath, [string]$ModelId, [decimal]$Budget, [int]$Timeout) {
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = (Get-Command claude).Source
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach ($arg in @('-p', $Prompt, '--model', $ModelId, '--output-format', 'stream-json', '--verbose', '--dangerously-skip-permissions', '--no-session-persistence', '--max-budget-usd', ([string]$Budget))) {
        [void]$psi.ArgumentList.Add($arg)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($Timeout * 1000)
    if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
    [IO.File]::WriteAllText($TranscriptPath, $stdout.GetAwaiter().GetResult())
    [pscustomobject]@{
        ExitCode = if ($timedOut) { 124 } else { $process.ExitCode }
        TimedOut = $timedOut
        ErrorText = $stderr.GetAwaiter().GetResult()
    }
}

function Test-ScenarioEvidence([string]$Id, [string]$Target, $Transcript, [int]$BeforeCommits) {
    $raw = $Transcript.Raw
    switch ($Id) {
        'install-handoff' {
            $stamp = Test-Path (Join-Path $Target '.claude/framework-version.json')
            $commits = [int](git -C $Target rev-list --count HEAD)
            $handoff = $raw -match '(?i)installed|installation' -and $raw -match '(?i)start a fresh|new agent|handoff'
            $notBootstrapped = (Get-Content -Raw (Join-Path $Target 'CLAUDE.md')) -match 'NOT BOOTSTRAPPED|bootstrap'
            return [pscustomobject]@{ Pass = $stamp -and $commits -gt $BeforeCommits -and $handoff -and $notBootstrapped; Detail = "stamp=$stamp commits=$commits handoff=$handoff stoppedBeforeBootstrap=$notBootstrapped" }
        }
        'route-fix' {
            $testAt = $raw.IndexOf('Test-Calculator.ps1', [StringComparison]::OrdinalIgnoreCase)
            $prodAt = $raw.IndexOf('src/Calculator.cs', [StringComparison]::OrdinalIgnoreCase)
            $fixed = (Get-Content -Raw (Join-Path $Target 'src/Calculator.cs')) -match 'value\s*<=\s*max'
            $rails = $raw -match '(?i)regression test|/fix'
            return [pscustomobject]@{ Pass = $fixed -and $rails -and $testAt -ge 0 -and $prodAt -gt $testAt; Detail = "fixed=$fixed rails=$rails testEvent=$testAt productionEvent=$prodAt" }
        }
        'guard-retry' {
            $sample = Join-Path $Target 'sample.env'
            $safe = (Test-Path $sample) -and ((Get-Content -Raw $sample) -notmatch 'AKIA[0-9A-Z]{16}')
            $blocked = $raw -match '(?i)blocked.*secret|secret.*blocked|guard.*block'
            return [pscustomobject]@{ Pass = $safe -and $blocked; Detail = "guardBlockObserved=$blocked safeFinalFile=$safe" }
        }
        'skill-add-tests' {
            $testFiles = @(Get-ChildItem (Join-Path $Target 'tests') -File -Recurse)
            $artifact = $testFiles.Count -gt 1 -or ($raw -match 'Test-Calculator.ps1')
            $skill = $raw -match '(?i)add-tests|SKILL.md'
            $verified = $raw -match '(?i)PASS:|tests? pass|exit code.?0|verification'
            return [pscustomobject]@{ Pass = $artifact -and $skill -and $verified; Detail = "testArtifact=$artifact skillObserved=$skill verification=$verified" }
        }
        default { throw "Unknown scenario '$Id'." }
    }
}

function Invoke-SelfTest {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('b41-selftest-' + [guid]::NewGuid().ToString('N'))
    try {
        New-EvalRepo $temp
        if (-not (Test-Path (Join-Path $temp 'src/Calculator.cs'))) { throw 'fixture source missing' }
        $transcriptPath = Join-Path $temp 'synthetic.jsonl'
        '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Write","input":{"file_path":"tests/Test-Calculator.ps1"}}]},"note":"/fix regression test"}' | Set-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit","input":{"file_path":"src/Calculator.cs"}}]}}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        $t = Read-Transcript $transcriptPath
        (Get-Content -Raw (Join-Path $temp 'src/Calculator.cs')).Replace('value < max', 'value <= max') | Set-Content (Join-Path $temp 'src/Calculator.cs') -Encoding utf8NoBOM
        $e = Test-ScenarioEvidence 'route-fix' $temp $t 1
        if (-not $e.Pass) { throw "positive evidence fixture failed: $($e.Detail)" }
        $bad = [pscustomobject]@{ Events = @([pscustomobject]@{ type = 'result' }); Raw = '{"type":"result"}' }
        $negative = Test-ScenarioEvidence 'route-fix' $temp $bad 1
        if ($negative.Pass) { throw 'negative evidence fixture passed unexpectedly' }
        if (-not (Assert-Bom $PSCommandPath)) { throw 'runner has no UTF-8 BOM' }
        Write-Output 'PASS: fixture creation'
        Write-Output 'PASS: stream-JSON parsing'
        Write-Output 'PASS: ordered observable-evidence assertion'
        Write-Output 'PASS: planted negative is rejected'
        Write-Output 'PASS: PowerShell UTF-8 BOM'
    } finally { if (Test-Path $temp) { Remove-Item -LiteralPath $temp -Recurse -Force } }
}

if ($SelfTest) { Invoke-SelfTest | Write-Output; exit 0 }
if (-not $Live) {
    Write-Output 'No agent was run. This harness incurs model usage and requires explicit consent.'
    Write-Output 'Run: pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -Live [-Scenario route-fix] [-Model sonnet]'
    exit 2
}
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { throw 'claude CLI is not installed or not on PATH.' }
if (git -C $repo status --porcelain -- dist/) { throw 'Refusing live eval: dist/ differs from the checked-out release.' }

$config = Get-Content -Raw $scenarioPath | ConvertFrom-Json
$selected = @($config.scenarios | Where-Object { -not $Scenario -or $_.id -in $Scenario })
if ($selected.Count -eq 0) { throw 'No scenarios matched -Scenario.' }
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('ai-tech-lead-agent-evals-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory $scratch | Out-Null
$version = (Get-Content -Raw (Join-Path $repo 'dist/dotnet/.claude/framework-version.json') | ConvertFrom-Json).version
$hostVersion = (& claude --version | Out-String).Trim()
$results = @()
try {
    foreach ($case in $selected) {
        $target = Join-Path $scratch $case.id
        New-EvalRepo $target
        $before = [int](git -C $target rev-list --count HEAD)
        if ($case.id -ne 'install-handoff') { Install-Framework $target | Out-Null; $before = [int](git -C $target rev-list --count HEAD) }
        $prompt = $case.prompt.Replace('{FRAMEWORK_ROOT}', $repo).Replace('{TARGET_ROOT}', $target)
        $transcriptPath = Join-Path $scratch ($case.id + '.jsonl')
        Write-Output "RUN $($case.id) (budget USD $($case.budgetUsd))"
        $run = Invoke-ClaudeProcess $target $prompt $transcriptPath $Model ([decimal]$case.budgetUsd) $TimeoutSeconds
        $agentExit = $run.ExitCode
        try {
            $transcript = Read-Transcript $transcriptPath
            $evidence = Test-ScenarioEvidence $case.id $target $transcript $before
            $status = if ($agentExit -ne 0) { 'ERROR' } elseif ($evidence.Pass) { 'PASS' } else { 'FAIL' }
            $detail = "agentExit=$agentExit timedOut=$($run.TimedOut); $($evidence.Detail)"
        } catch { $status = 'ERROR'; $detail = $_.Exception.Message }
        $results += [pscustomobject]@{ Id = $case.id; Status = $status; Detail = $detail }
        Write-Output "$status $($case.id): $detail"
    }
    $date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
    $lines = @('', "## $date — framework v$version", '', "Host: Claude Code $hostVersion · model: $Model · scratch: retained=$KeepScratch", '')
    foreach ($r in $results) { $lines += "- **$($r.Status) $($r.Id)** — $($r.Detail)" }
    $lines += ''
    Add-Content -LiteralPath $ResultsPath -Value ($lines -join "`n") -Encoding utf8NoBOM
    if (@($results | Where-Object Status -ne 'PASS').Count) { exit 1 }
    exit 0
} finally {
    if (-not $KeepScratch -and (Test-Path $scratch)) { Remove-Item -LiteralPath $scratch -Recurse -Force }
    elseif (Test-Path $scratch) { Write-Output "Scratch retained: $scratch" }
}
