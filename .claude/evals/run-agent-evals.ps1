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
    if (@($events | Where-Object { $_.type -eq 'system' -and $_.subtype -eq 'init' }).Count -ne 1) { throw 'Stream JSON must contain exactly one system/init event.' }
    $initIndex = -1
    for ($i = 0; $i -lt $events.Count; $i++) { if ($events[$i].type -eq 'system' -and $events[$i].subtype -eq 'init') { $initIndex = $i; break } }
    if ($initIndex -lt 0) { throw 'Stream JSON has no system/init event.' }
    foreach ($preInit in @($events | Select-Object -First $initIndex)) {
        if ($preInit.type -ne 'system' -and $preInit.type -ne 'rate_limit_event') { throw 'Only system hook/rate-limit events may precede system/init.' }
    }
    $terminal = @($events | Where-Object { $_.type -eq 'result' })
    if ($terminal.Count -ne 1 -or $events[$events.Count - 1].type -ne 'result') { throw 'Stream JSON must end with exactly one terminal result event.' }
    $toolIds = @{}
    $resultIds = @{}
    foreach ($event in $events) {
        if ($event.type -eq 'assistant') {
            if ($null -eq $event.message -or $null -eq $event.message.content) { throw 'Assistant event has no message.content.' }
            foreach ($content in @($event.message.content)) {
                if ($content.type -eq 'tool_use') {
                    if (-not $content.id -or -not $content.name -or $null -eq $content.input) { throw 'tool_use requires nonempty id/name and input.' }
                    if ($toolIds.ContainsKey([string]$content.id)) { throw "Duplicate tool_use id '$($content.id)'." }
                    $toolIds[[string]$content.id] = $true
                }
            }
        } elseif ($event.type -eq 'user') {
            foreach ($content in @($event.message.content)) {
                if ($content.type -eq 'tool_result') {
                    $resultId = [string]$content.tool_use_id
                    if (-not $resultId -or -not $toolIds.ContainsKey($resultId)) { throw "tool_result references unknown/empty tool id '$resultId'." }
                    if ($resultIds.ContainsKey($resultId)) { throw "Duplicate tool_result for id '$resultId'." }
                    $resultIds[$resultId] = $true
                }
            }
        }
    }
    [pscustomobject]@{ Events = $events }
}

function Get-TranscriptEvidence($Transcript) {
    $tools = [Collections.Generic.List[object]]::new()
    $results = @{}
    $final = $null
    $ordinal = 0
    foreach ($event in $Transcript.Events) {
        $ordinal++
        if ($event.type -eq 'assistant') {
            foreach ($content in @($event.message.content)) {
                if ($content.type -eq 'tool_use') {
                    $tools.Add([pscustomobject]@{ Index = $ordinal; Id = [string]$content.id; Name = [string]$content.name; Input = $content.input })
                }
            }
        } elseif ($event.type -eq 'user') {
            foreach ($content in @($event.message.content)) {
                if ($content.type -eq 'tool_result') { $results[[string]$content.tool_use_id] = $content }
            }
        } elseif ($event.type -eq 'result') { $final = $event }
    }
    if (-not $final) { throw 'Stream JSON has no terminal result event.' }
    [pscustomobject]@{ Tools = $tools; ToolResults = $results; Final = $final }
}

function Get-ToolPath($Tool) {
    foreach ($name in 'file_path','filePath','path') { if ($Tool.Input.$name) { return [string]$Tool.Input.$name } }
    return ''
}

function Get-ToolResultText($Evidence, $Tool) {
    if (-not $Evidence.ToolResults.ContainsKey($Tool.Id)) { return '' }
    $content = $Evidence.ToolResults[$Tool.Id].content
    if ($content -is [string]) { return $content }
    return ($content | ConvertTo-Json -Compress -Depth 20)
}

function Invoke-ClaudeProcess([string]$WorkingDirectory, [string]$Prompt, [string]$TranscriptPath, [string]$ModelId, [decimal]$Budget, [int]$Timeout, [string]$Agent) {
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = (Get-Command claude).Source
    $psi.WorkingDirectory = $WorkingDirectory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach ($arg in @('-p', $Prompt, '--model', $ModelId, '--output-format', 'stream-json', '--verbose', '--dangerously-skip-permissions', '--no-session-persistence', '--max-budget-usd', ([string]$Budget))) {
        [void]$psi.ArgumentList.Add($arg)
    }
    if ($Agent) { [void]$psi.ArgumentList.Add('--agent'); [void]$psi.ArgumentList.Add($Agent) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $psi
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($Timeout * 1000)
    if ($timedOut) {
        $process.Kill($true)
        [void]$process.WaitForExit(10000)
        # A killed CLI may leave an inherited pipe handle open in a grandchild. Do not await the
        # async readers on the timeout path or the timeout itself can hang indefinitely.
        [IO.File]::WriteAllText($TranscriptPath, '')
        $errorText = "Claude CLI exceeded the ${Timeout}s wall-clock limit."
    } else {
        [IO.File]::WriteAllText($TranscriptPath, $stdout.GetAwaiter().GetResult())
        $errorText = $stderr.GetAwaiter().GetResult()
    }
    [pscustomobject]@{
        ExitCode = if ($timedOut) { 124 } else { $process.ExitCode }
        TimedOut = $timedOut
        ErrorText = $errorText
    }
}

function Test-ScenarioEvidence([string]$Id, [string]$Target, $Transcript, [int]$BeforeCommits) {
    $e = Get-TranscriptEvidence $Transcript
    $finalText = [string]$e.Final.result
    $finalOk = -not $e.Final.is_error
    switch ($Id) {
        'install-handoff' {
            $stamp = Test-Path (Join-Path $Target '.claude/framework-version.json')
            $commits = [int](git -C $Target rev-list --count HEAD)
            $handoff = $finalOk -and $finalText -match '(?i)developer.+(?:type|run).*/bootstrap' -and $finalText -match '(?i)cannot|do not|did not'
            $pending = (Get-Content -Raw (Join-Path $Target 'CLAUDE.md')) -match 'BOOTSTRAP_PENDING'
            $bootstrapTool = @($e.Tools | Where-Object { ($_.Name -eq 'Skill' -and $_.Input.skill -eq 'bootstrap') -or ($_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)(?:^|\s|[/\\])bootstrap(?:\s|$)') }).Count -gt 0
            $installerTool = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)install\.ps1' } | Select-Object -First 1)
            return [pscustomobject]@{ Status = 'PASS'; Pass = $stamp -and $commits -gt $BeforeCommits -and $handoff -and $pending -and -not $bootstrapTool -and $installerTool; Detail = "stamp=$stamp commits=$commits installerTool=$([bool]$installerTool) finalHandoff=$handoff bootstrapPending=$pending bootstrapTool=$bootstrapTool" }
        }
        'route-fix' {
            $testRuns = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match 'Test-Calculator\.ps1' })
            $prodEdits = @($e.Tools | Where-Object { $_.Name -in @('Edit','Write') -and (Get-ToolPath $_) -match '(?:^|[\\/])src[\\/]Calculator\.cs$' })
            # Bash tool_result.is_error reports tool transport failure, not the command's exit code.
            # Use mutually exclusive command output while retaining typed tool/result association.
            $red = @($testRuns | Where-Object { $text = Get-ToolResultText $e $_; $text -match '(?i)EXIT:\s*1|Exception:[\s\S]*inclusive upper bound is broken' -and $text -notmatch '(?i)PASS: inclusive range' } | Select-Object -First 1)
            $green = @($testRuns | Where-Object { $text = Get-ToolResultText $e $_; $text -match '(?i)EXIT:\s*0|PASS: inclusive range' -and $text -notmatch '(?i)Exception:[\s\S]*inclusive upper bound is broken' } | Select-Object -Last 1)
            $testAt = if ($red) { $red[0].Index } else { -1 }
            $prodAt = if ($prodEdits) { $prodEdits[0].Index } else { -1 }
            $fixed = (Get-Content -Raw (Join-Path $Target 'src/Calculator.cs')) -match 'value\s*<=\s*max'
            $exercised = $testRuns.Count -gt 0
            return [pscustomobject]@{ Status = $(if($exercised){'PASS'}else{'INCONCLUSIVE'}); Pass = $finalOk -and $fixed -and $testAt -ge 0 -and $prodAt -gt $testAt -and $green -and $green[0].Index -gt $prodAt; Detail = "routeExercised=$exercised fixed=$fixed redTestEvent=$testAt productionEdit=$prodAt greenTestEvent=$(if($green){$green[0].Index}else{-1})" }
        }
        'archived-redirect' {
            $stamp = Test-Path (Join-Path $Target '.claude/framework-version.json')
            $frozen = Test-Path (Join-Path $Target 'FROZEN_INSTALL_RAN')
            $commits = [int](git -C $Target rev-list --count HEAD)
            $handoff = $finalOk -and $finalText -match '(?i)(?:redirect|current|canonical).+framework' -and $finalText -match '(?i)developer.+/bootstrap'
            $installerTool = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)install\.ps1' -and [string]$_.Input.command -notmatch '(?i)archived-source.+install\.ps1' } | Select-Object -First 1)
            $archivedInstallerTool = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match '(?i)archived-source.+install\.ps1' } | Select-Object -First 1)
            return [pscustomobject]@{ Status = 'PASS'; Pass = $stamp -and -not $frozen -and $commits -gt $BeforeCommits -and $handoff -and $installerTool -and -not $archivedInstallerTool; Detail = "currentStamp=$stamp frozenInstallerRan=$frozen archivedInstallerTool=$([bool]$archivedInstallerTool) commits=$commits canonicalInstallerTool=$([bool]$installerTool) redirectedHandoff=$handoff" }
        }
        'guard-retry' {
            $sample = Join-Path $Target 'sample.env'
            $safe = (Test-Path $sample) -and ((Get-Content -Raw $sample) -notmatch 'AKIA[0-9A-Z]{16}')
            $writes = @($e.Tools | Where-Object { $_.Name -eq 'Write' -and (Get-ToolPath $_) -match 'sample\.env$' })
            $blockedWrite = @($writes | Where-Object { $e.ToolResults.ContainsKey($_.Id) -and $e.ToolResults[$_.Id].is_error -and (Get-ToolResultText $e $_) -match 'PreToolUse.+Blocked write' } | Select-Object -First 1)
            $safeWrite = @($writes | Where-Object { $e.ToolResults.ContainsKey($_.Id) -and -not $e.ToolResults[$_.Id].is_error -and $_.Index -gt $(if($blockedWrite){$blockedWrite[0].Index}else{[int]::MaxValue}) } | Select-Object -First 1)
            $exercised = $writes.Count -gt 0
            return [pscustomobject]@{ Status = $(if($exercised){'PASS'}else{'INCONCLUSIVE'}); Pass = $finalOk -and $safe -and $blockedWrite -and $safeWrite; Detail = "guardExercised=$exercised blockedToolResult=$([bool]$blockedWrite) safeRetry=$([bool]$safeWrite) safeFinalFile=$safe" }
        }
        'skill-add-tests' {
            $skill = @($e.Tools | Where-Object { $_.Name -eq 'Skill' -and $_.Input.skill -eq 'add-tests' } | Select-Object -First 1)
            $testEdit = @($e.Tools | Where-Object { $_.Name -in @('Edit','Write') -and (Get-ToolPath $_) -match '(?:^|[\\/])tests[\\/]Test-Calculator\.ps1$' } | Select-Object -First 1)
            $verification = @($e.Tools | Where-Object { $_.Name -in @('Bash','PowerShell') -and [string]$_.Input.command -match 'Test-Calculator\.ps1' -and $testEdit -and $_.Index -gt $testEdit[0].Index -and (Get-ToolResultText $e $_) -match '(?i)lower bound.+included' -and (Get-ToolResultText $e $_) -match '(?i)upper bound.+included' } | Select-Object -Last 1)
            $testText = Get-Content -Raw (Join-Path $Target 'tests/Test-Calculator.ps1')
            $boundaryCases = $testText -match '(?i)IsWithinInclusiveRange\(\s*5\s*,\s*5\s*,\s*10\s*\)' -and $testText -match '(?i)IsWithinInclusiveRange\(\s*10\s*,\s*5\s*,\s*10\s*\)'
            $checkpoint = $finalOk -and $finalText -match '(?i)wait for your confirmation|confirm.*before'
            if ($checkpoint) { return [pscustomobject]@{ Status = 'INCONCLUSIVE'; Pass = $false; Detail = 'skill stopped at a developer checkpoint before editing' } }
            return [pscustomobject]@{ Status = 'PASS'; Pass = $finalOk -and $skill -and $testEdit -and $boundaryCases -and $verification; Detail = "skillTool=$([bool]$skill) exactTestEdit=$([bool]$testEdit) executableBoundaryCases=$boundaryCases observedAfterEdit=$([bool]$verification)" }
        }
        'haiku-convention-check' {
            $found = $finalOk -and $finalText -match '(?i)## Convention check' -and $finalText -match '(?i)Findings \([1-9]' -and $finalText -match '(?im)^\|[^\r\n]*ConventionViolation\.cs[^\r\n]*CancellationToken[^\r\n]*\|'
            return [pscustomobject]@{ Status = 'PASS'; Pass = $found; Detail = "finalFinding=$found" }
        }
        'haiku-bloat-radar' {
            $found = $finalOk -and $finalText -match '(?i)## Bloat radar' -and $finalText -match '(?i)Findings \([1-9]' -and $finalText -match '(?im)^\|[^\r\n]*SpeculativeHelper\.cs(?::\d+)?\s*\|\s*(?:speculative abstraction|generic helper|bloat)[^|]*\|\s*(?:low|medium|high|critical)\s*\|[^\r\n]+\|'
            return [pscustomobject]@{ Status = 'PASS'; Pass = $found; Detail = "finalFinding=$found" }
        }
        'haiku-debt-radar' {
            $found = $finalOk -and $finalText -match '(?i)## Debt radar' -and $finalText -match '(?i)Matched entries \([1-9]' -and $finalText -match '(?im)^\|\s*DEBT-001\s*\|[^\r\n]*Calculator\.cs[^\r\n]*\|'
            return [pscustomobject]@{ Status = 'PASS'; Pass = $found; Detail = "finalFinding=$found" }
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
        '{"type":"system","subtype":"init"}' | Set-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"red","name":"Bash","input":{"command":"pwsh tests/Test-Calculator.ps1"}}]}}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"red","is_error":true,"content":"inclusive upper bound is broken EXIT:1"}]}}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"edit","name":"Edit","input":{"file_path":"src/Calculator.cs"}}]}}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"edit","content":"edited"}]}}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"green","name":"Bash","input":{"command":"pwsh tests/Test-Calculator.ps1"}}]}}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"green","content":"PASS: inclusive range EXIT:0"}]}}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        '{"type":"result","is_error":false,"result":"fixed and verified"}' | Add-Content $transcriptPath -Encoding utf8NoBOM
        $t = Read-Transcript $transcriptPath
        (Get-Content -Raw (Join-Path $temp 'src/Calculator.cs')).Replace('value < max', 'value <= max') | Set-Content (Join-Path $temp 'src/Calculator.cs') -Encoding utf8NoBOM
        $e = Test-ScenarioEvidence 'route-fix' $temp $t 1
        if (-not $e.Pass) { throw "positive evidence fixture failed: $($e.Detail)" }
        $badPath = Join-Path $temp 'keyword-echo.jsonl'
        '{"type":"system","subtype":"init"}' | Set-Content $badPath -Encoding utf8NoBOM
        '{"type":"result","is_error":false,"result":"/fix regression test tests/Test-Calculator.ps1 src/Calculator.cs PASS: inclusive range"}' | Add-Content $badPath -Encoding utf8NoBOM
        $bad = Read-Transcript $badPath
        $negative = Test-ScenarioEvidence 'route-fix' $temp $bad 1
        if ($negative.Pass) { throw 'negative evidence fixture passed unexpectedly' }
        $invalidPath = Join-Path $temp 'invalid-schema.jsonl'
        '{"type":"result","is_error":false,"result":"looks valid"}' | Set-Content $invalidPath -Encoding utf8NoBOM
        $schemaRejected = $false
        try { Read-Transcript $invalidPath | Out-Null } catch { $schemaRejected = $true }
        if (-not $schemaRejected) { throw 'transcript without system/init was accepted' }
        $malformedCases = @(
            @('{"type":"system","subtype":"init"}','{"type":"result","is_error":false,"result":"early"}','{"type":"assistant","message":{"content":[]}}'),
            @('{"type":"system","subtype":"init"}','{"type":"assistant","message":{"content":[{"type":"tool_use","id":"dup","name":"Read","input":{}},{"type":"tool_use","id":"dup","name":"Read","input":{}}]}}','{"type":"result","is_error":false,"result":"done"}'),
            @('{"type":"system","subtype":"init"}','{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"missing","content":"x"}]}}','{"type":"result","is_error":false,"result":"done"}'),
            @('{"type":"assistant","message":{"content":[]}}','{"type":"system","subtype":"init"}','{"type":"result","is_error":false,"result":"done"}'),
            @('{"type":"system","subtype":"init"}','{"type":"assistant","message":{"content":[{"type":"tool_use","id":"once","name":"Read","input":{}}]}}','{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"once","content":"first"},{"type":"tool_result","tool_use_id":"once","content":"second"}]}}','{"type":"result","is_error":false,"result":"done"}')
        )
        $malformedIndex = 0
        foreach ($lines in $malformedCases) {
            $malformedIndex++
            $path = Join-Path $temp "malformed-$malformedIndex.jsonl"
            $lines | Set-Content $path -Encoding utf8NoBOM
            $rejected = $false
            try { Read-Transcript $path | Out-Null } catch { $rejected = $true }
            if (-not $rejected) { throw "malformed transcript $malformedIndex was accepted" }
        }

        # Old raw-regex graders passed these echo-only shapes. Typed evidence must reject them.
        'AWS_ACCESS_KEY_ID=REPLACE_ME' | Set-Content (Join-Path $temp 'sample.env') -Encoding utf8NoBOM
        $echo = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='guard blocked secret; add-tests SKILL.md; PASS: inclusive range' })
        ) }
        foreach ($id in 'guard-retry','skill-add-tests') {
            if ((Test-ScenarioEvidence $id $temp $echo 1).Pass) { throw "$id accepted final-text keyword echoes without typed tool evidence" }
        }
        foreach ($case in @(
            @{ Id='haiku-convention-check'; Path='src/ConventionViolation.cs'; Final='## Convention check — 1 file scanned`n### Findings (0)`nConventionViolation.cs does not require CancellationToken.' },
            @{ Id='haiku-bloat-radar'; Path='src/SpeculativeHelper.cs'; Final='## Bloat radar — 1 file scanned`n### Findings (0)`nSpeculativeHelper.cs is not bloat and is not a generic helper.' },
            @{ Id='haiku-debt-radar'; Path='DEBT-001 Calculator.cs'; Final='## Debt radar — Calculator`n### Matched entries (0)`nDEBT-001 is unrelated to Calculator.cs.' }
        )) {
            $tcase = [pscustomobject]@{ Events = @(
                ([pscustomobject]@{ type='system'; subtype='init' }),
                ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='read'; name='Read'; input=[pscustomobject]@{ file_path=$case.Path } }) } }),
                ([pscustomobject]@{ type='result'; is_error=$false; result=$case.Final })
            ) }
            if ((Test-ScenarioEvidence $case.Id $temp $tcase 1).Pass) { throw "$($case.Id) accepted planted keywords outside the final finding" }
        }
        $bloatPositive = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result="## Bloat radar — 1 file scanned`n### Findings (1)`n| File:line | Pattern | Severity | Suggestion |`n|---|---|---|---|`n| src/SpeculativeHelper.cs:1 | Speculative abstraction | medium | Inline it |" })
        ) }
        if (-not (Test-ScenarioEvidence 'haiku-bloat-radar' $temp $bloatPositive 1).Pass) { throw 'bloat-radar rejected its documented structured finding row' }

        $wrongExit = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@(
                [pscustomobject]@{ type='tool_use'; id='false-red'; name='Bash'; input=[pscustomobject]@{ command='pwsh tests/Test-Calculator.ps1' } },
                [pscustomobject]@{ type='tool_use'; id='false-green'; name='Bash'; input=[pscustomobject]@{ command='pwsh tests/Test-Calculator.ps1' } }
            ) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@(
                [pscustomobject]@{ type='tool_result'; tool_use_id='false-red'; is_error=$false; content='inclusive upper bound is broken EXIT:1' },
                [pscustomobject]@{ type='tool_result'; tool_use_id='false-green'; is_error=$true; content='PASS: inclusive range EXIT:0' }
            ) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='fixed' })
        ) }
        if ((Test-ScenarioEvidence 'route-fix' $temp $wrongExit 1).Pass) { throw 'route-fix accepted inverted tool-result error semantics' }
        $checkpoint = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='skill'; name='Skill'; input=[pscustomobject]@{ skill='add-tests' } }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='I will wait for your confirmation before editing.' })
        ) }
        if ((Test-ScenarioEvidence 'skill-add-tests' $temp $checkpoint 1).Status -ne 'INCONCLUSIVE') { throw 'developer checkpoint was not classified INCONCLUSIVE' }

        $beforeInstall = [int](git -C $temp rev-list --count HEAD)
        Install-Framework $temp | Out-Null
        git -C $temp add -A
        git -C $temp commit --quiet -m 'synthetic installed state'
        $installEcho = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='Installation complete. I cannot bootstrap; developer must type /bootstrap. Redirected to the current canonical framework.' })
        ) }
        foreach ($id in 'install-handoff','archived-redirect') {
            if ((Test-ScenarioEvidence $id $temp $installEcho $beforeInstall).Pass) { throw "$id accepted installed filesystem + final prose without an installer tool event" }
        }
        $bootstrapAttempt = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='install'; name='PowerShell'; input=[pscustomobject]@{ command='pwsh C:\canonical\install.ps1 target' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='install'; content='installed' }) } }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_use'; id='bootstrap'; name='Skill'; input=[pscustomobject]@{ skill='bootstrap' } }) } }),
            ([pscustomobject]@{ type='user'; message=[pscustomobject]@{ content=@([pscustomobject]@{ type='tool_result'; tool_use_id='bootstrap'; is_error=$true; content='developer only' }) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='Installation complete. I cannot bootstrap; developer must type /bootstrap.' })
        ) }
        if ((Test-ScenarioEvidence 'install-handoff' $temp $bootstrapAttempt $beforeInstall).Pass) { throw 'install-handoff accepted a typed bootstrap Skill attempt' }
        $archivedAttempt = [pscustomobject]@{ Events = @(
            ([pscustomobject]@{ type='system'; subtype='init' }),
            ([pscustomobject]@{ type='assistant'; message=[pscustomobject]@{ content=@(
                [pscustomobject]@{ type='tool_use'; id='old'; name='PowerShell'; input=[pscustomobject]@{ command='pwsh C:\archived-source\install.ps1 target' } },
                [pscustomobject]@{ type='tool_use'; id='new'; name='PowerShell'; input=[pscustomobject]@{ command='pwsh C:\canonical\install.ps1 target' } }
            ) } }),
            ([pscustomobject]@{ type='result'; is_error=$false; result='Redirected to current canonical framework. Developer must type /bootstrap.' })
        ) }
        if ((Test-ScenarioEvidence 'archived-redirect' $temp $archivedAttempt $beforeInstall).Pass) { throw 'archived-redirect accepted an observed frozen-installer invocation' }
        if (-not (Assert-Bom $PSCommandPath)) { throw 'runner has no UTF-8 BOM' }
        Write-Output 'PASS: fixture creation'
        Write-Output 'PASS: stream-JSON parsing'
        Write-Output 'PASS: ordered observable-evidence assertion'
        Write-Output 'PASS: planted negative is rejected'
        Write-Output 'PASS: prompt/final keyword echoes cannot satisfy typed evidence'
        Write-Output 'PASS: invalid/duplicate/nonterminal stream schema is rejected'
        Write-Output 'PASS: init ordering, unique results, and tool exit semantics are enforced'
        Write-Output 'PASS: structured Haiku positive control is accepted'
        Write-Output 'PASS: all graders reject keyword-only evidence'
        Write-Output 'PASS: developer checkpoint is INCONCLUSIVE, not PASS/FAIL'
        Write-Output 'PASS: install graders require an observed installer tool event'
        Write-Output 'PASS: bootstrap Skill and archived-installer attempts are rejected'
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
$scenarioIds = @($Scenario | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$selected = @($config.scenarios | Where-Object { -not $scenarioIds -or $_.id -in $scenarioIds })
if ($selected.Count -eq 0) { throw 'No scenarios matched -Scenario.' }
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('ai-tech-lead-agent-evals-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory $scratch | Out-Null
$version = (Get-Content -Raw (Join-Path $repo 'dist/dotnet/.claude/framework-version.json') | ConvertFrom-Json).version
$changelogVersion = ((Get-Content (Join-Path $repo 'CHANGELOG.md') | Where-Object { $_ -match '^## (\d+\.\d+\.\d+)' } | Select-Object -First 1) -replace '^## (\d+\.\d+\.\d+).*','$1')
if ($version -ne $changelogVersion) { throw "Refusing live eval: dist version $version does not match root CHANGELOG head $changelogVersion." }
$frameworkCommit = (git -C $repo rev-parse HEAD | Out-String).Trim()
$hostVersion = (& claude --version | Out-String).Trim()
$results = @()
try {
    foreach ($case in $selected) {
        # Isolate each case's entire visible fixture tree. Otherwise a model can satisfy a later
        # install case by copying artifacts from an earlier sibling instead of exercising the
        # requested canonical installer path.
        $caseRoot = Join-Path $scratch $case.id
        New-Item -ItemType Directory -Path $caseRoot | Out-Null
        $target = Join-Path $caseRoot 'target'
        New-EvalRepo $target
        $before = [int](git -C $target rev-list --count HEAD)
        if ($case.id -notin @('install-handoff','archived-redirect')) { Install-Framework $target | Out-Null; $before = [int](git -C $target rev-list --count HEAD) }
        $archivedRoot = ''
        switch ($case.id) {
            'archived-redirect' {
                $archivedRoot = Join-Path $caseRoot 'archived-source'
                New-Item -ItemType Directory -Path $archivedRoot -Force | Out-Null
                @"
# ARCHIVED — STOP FOR AI AGENTS

Do not install files or run scripts from this archived tree. The maintained framework moved to
$repo. Install from that canonical repository into the requested target, then obey its installer
handoff. The archived copy is frozen and is not equivalent.
"@ | Set-Content (Join-Path $archivedRoot 'README.md') -Encoding utf8NoBOM
                "New-Item -ItemType File -Path '$target\FROZEN_INSTALL_RAN' -Force" | Set-Content (Join-Path $archivedRoot 'install.ps1') -Encoding utf8NoBOM
            }
            'haiku-convention-check' {
                "namespace EvalFixture; public class ConventionViolation { public async Task WorkAsync() { await Task.Delay(1); } }" | Set-Content (Join-Path $target 'src/ConventionViolation.cs') -Encoding utf8NoBOM
                $claudeText = Get-Content -Raw (Join-Path $target 'CLAUDE.md')
                $claudeText.Replace('BOOTSTRAP_PENDING', 'EVAL_BOOTSTRAPPED') | Set-Content (Join-Path $target 'CLAUDE.md') -Encoding utf8NoBOM
            }
            'haiku-bloat-radar' {
                "namespace EvalFixture; public static class SpeculativeHelper { public static int Identity(int value) => value; }" | Set-Content (Join-Path $target 'src/SpeculativeHelper.cs') -Encoding utf8NoBOM
                git -C $target add -N src/SpeculativeHelper.cs
            }
            'haiku-debt-radar' {
                @'
# Technical debt
## DEBT-001 — Inclusive range boundary is fragile
Severity: High
Effort: S
Files: src/Calculator.cs:4
Issue: Boundary behavior lacks a direct compiled unit test.
'@ | Set-Content (Join-Path $target 'TECH_DEBT.md') -Encoding utf8NoBOM
            }
        }
        $prompt = $case.prompt.Replace('{FRAMEWORK_ROOT}', $repo).Replace('{TARGET_ROOT}', $target).Replace('{ARCHIVED_ROOT}', $archivedRoot)
        $transcriptPath = Join-Path $scratch ($case.id + '.jsonl')
        Write-Output "RUN $($case.id) (budget USD $($case.budgetUsd))"
        $caseModel = if ($case.model) { [string]$case.model } else { $Model }
        $caseAgent = if ($case.agent) { [string]$case.agent } else { '' }
        $run = Invoke-ClaudeProcess $target $prompt $transcriptPath $caseModel ([decimal]$case.budgetUsd) $TimeoutSeconds $caseAgent
        $agentExit = $run.ExitCode
        try {
            if ($run.TimedOut) { throw $run.ErrorText }
            $transcript = Read-Transcript $transcriptPath
            $evidence = Test-ScenarioEvidence $case.id $target $transcript $before
            $status = if ($agentExit -ne 0) { 'ERROR' } elseif ($evidence.Pass) { 'PASS' } elseif ($evidence.Status -eq 'INCONCLUSIVE') { 'INCONCLUSIVE' } else { 'FAIL' }
            $detail = "agentExit=$agentExit timedOut=$($run.TimedOut); $($evidence.Detail)"
        } catch { $status = 'ERROR'; $detail = $_.Exception.Message }
        $results += [pscustomobject]@{ Id = $case.id; Status = $status; Model = $caseModel; Agent = $caseAgent; Detail = $detail }
        Write-Output "$status $($case.id): $detail"
    }
    $date = Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
    $lines = @('', "## $date — framework v$version ($frameworkCommit)", '', "Host: Claude Code $hostVersion · scratch: retained=$KeepScratch", '')
    foreach ($r in $results) { $lines += "- **$($r.Status) $($r.Id)** (model=$($r.Model)$(if($r.Agent){"; agent=$($r.Agent)"})) — $($r.Detail)" }
    $lines += ''
    Add-Content -LiteralPath $ResultsPath -Value ($lines -join "`n") -Encoding utf8NoBOM
    if (@($results | Where-Object Status -ne 'PASS').Count) { exit 1 }
    exit 0
} finally {
    if (-not $KeepScratch -and (Test-Path $scratch)) { Remove-Item -LiteralPath $scratch -Recurse -Force }
    elseif (Test-Path $scratch) { Write-Output "Scratch retained: $scratch" }
}
