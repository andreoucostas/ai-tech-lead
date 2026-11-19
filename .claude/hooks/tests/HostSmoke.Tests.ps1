# B-536: host-smoke.ps1's own classification, against fake host programs that talk to the real
# scripted endpoint on 127.0.0.1. No real host and no model is started.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$smoke = Join-Path $repoRoot '.claude\scripts\host-smoke.ps1'
$pwshExe = (Get-Process -Id $PID).Path
Reset-Tests

# The fake host: records the CLAUDE/ANTHROPIC/COPILOT variable names it was started with, asks the endpoint
# for all four scripted turns, then acts them out as the behaviour says and leaves the traces a real host
# and the shipped hooks leave (state file, audit line, stream or events, usage file, log).
$fakeHost = @'
$kind = $args[0]; $behaviour = $args[1]; $rest = @($args | Select-Object -Skip 2)
$root = (Get-Location).Path
@(Get-ChildItem env: | Where-Object Name -match '^(CLAUDE|ANTHROPIC|COPILOT)' | ForEach-Object { "$($_.Name)=$(if ($_.Name -match 'BASE_URL') { $_.Value } else { 'set' })" }) |
    Set-Content -LiteralPath (Join-Path $PSScriptRoot "env-$kind.txt")
if ($kind -eq 'copilot' -and $rest[0] -eq 'skill') { '[{"name":"map-warehouse"}]'; exit 0 }
if ($behaviour -eq 'silent') { exit 0 }
$opt = @{}; for ($i = 0; $i -lt $rest.Count - 1; $i++) { if ($rest[$i] -like '--*') { $opt[$rest[$i]] = $rest[$i + 1] } }
$uri = if ($kind -eq 'claude') { "$env:ANTHROPIC_BASE_URL/v1/messages" } else { "$env:COPILOT_PROVIDER_BASE_URL/chat/completions" }
$steps = foreach ($n in 0..2) {
    $messages = @(@{ role = 'user'; content = 'go' })
    if ($n -gt 0) { $messages += @(1..$n | ForEach-Object { @{ role = 'assistant'; content = 'x' } }) }
    $body = @{ model = 'fake'; stream = $false; messages = $messages; tools = @(@{ name = 't'; type = 'function'; function = @{ name = 't' } }) } | ConvertTo-Json -Depth 6
    $r = Invoke-RestMethod -Method Post -Uri $uri -Body $body -ContentType 'application/json'
    if ($kind -eq 'claude') { $c = $r.content[0]; [pscustomobject]@{ Name = $c.name; Input = $c.input } }
    else { $c = $r.choices[0].message.tool_calls[0].function; [pscustomobject]@{ Name = $c.name; Input = ($c.arguments | ConvertFrom-Json) } }
}
$state = Join-Path $root '.claude\.state'; New-Item -ItemType Directory -Force $state | Out-Null
Set-Content -LiteralPath (Join-Path $state $(if ($kind -eq 'claude') { 'last-session-start' } else { 'last-session-start-copilot' })) -Value 'now'
$lines = @(); $i = 0
if ($kind -eq 'claude') { $lines += '{"type":"system","subtype":"init","slash_commands":["bootstrap"],"skills":[]}' }
foreach ($s in $steps) {
    $i++; $text = 'ok'; $failed = $false
    $path = if ($s.Input.file_path) { $s.Input.file_path } else { $s.Input.path }
    if ($s.Name -in @('PowerShell', 'powershell')) { $text = Join-Path $root 'sub' }
    elseif ($path -match 'harmless') {
        Set-Content -LiteralPath $path -Value 'harmless'
        if ($behaviour -ne 'noaudit') { Add-Content -LiteralPath (Join-Path $root '.claude\ai-audit.log') -Value ("now`tmain`t.\sub\" + (Split-Path $path -Leaf)) }
    } else {
        if ($behaviour -eq 'leak') { Set-Content -LiteralPath $path -Value 'planted' } else { $failed = $true; $text = 'Blocked by the guard' }
    }
    if ($kind -eq 'claude') {
        $lines += (@{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_use'; id = "t$i"; name = $s.Name; input = $s.Input }) } } | ConvertTo-Json -Compress -Depth 8)
        $lines += (@{ type = 'user'; message = @{ content = @(@{ type = 'tool_result'; tool_use_id = "t$i"; content = $text; is_error = $failed }) } } | ConvertTo-Json -Compress -Depth 8)
    } else {
        $lines += (@{ type = 'tool.execution_start'; data = @{ toolCallId = "c$i"; toolName = $s.Name; arguments = $s.Input } } | ConvertTo-Json -Compress -Depth 8)
        $lines += (@{ type = 'tool.execution_complete'; data = @{ toolCallId = "c$i"; success = (-not $failed); result = @{ content = $text } } } | ConvertTo-Json -Compress -Depth 8)
    }
}
$cost = if ($behaviour -eq 'cost') { 0.25 } else { 0 }
if ($kind -eq 'claude') { $lines += "{`"type`":`"result`",`"total_cost_usd`":$cost}" }
else {
    Set-Content -LiteralPath $opt['--usage-output-file'] -Value "{`"totalPremiumRequestCost`":$cost}"
    New-Item -ItemType Directory -Force $opt['--log-dir'] | Out-Null
    $count = if ($behaviour -eq 'hooks') { 1 } else { 2 }
    Set-Content -LiteralPath (Join-Path $opt['--log-dir'] 'process-1.log') -Value "x [DEBUG] loadDeferredRepoHooks(s): loaded repo hooks (hookCount=$count)"
}
$lines
exit 0
'@

function New-SmokeCase([string]$Kind, [string]$Behaviour) {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('b536-' + [guid]::NewGuid().ToString('N').Substring(0, 10))
    $repo = Join-Path $dir 'repo'
    New-Item -ItemType Directory -Force (Join-Path $repo '.claude'), (Join-Path $repo '.github\hooks') | Out-Null
    # Two hook entries: one in .claude/settings.json, one in .github/hooks/hooks.json.
    Set-Content -LiteralPath (Join-Path $repo '.claude\settings.json') -Value '{"hooks":{"PreToolUse":[{"matcher":"Write","hooks":[{"type":"command","command":"x"}]}]}}'
    Set-Content -LiteralPath (Join-Path $repo '.github\hooks\hooks.json') -Value '{"version":1,"hooks":{"preToolUse":[{"type":"command","powershell":"x"}]}}'
    Set-Content -LiteralPath (Join-Path $dir 'fake.ps1') -Value $fakeHost -Encoding utf8BOM
    $cmd = Join-Path $dir "$Kind.cmd"
    Set-Content -LiteralPath $cmd -Encoding Ascii -Value ("@echo off`r`n""$pwshExe"" -NoProfile -ExecutionPolicy Bypass -File ""$dir\fake.ps1"" $Kind $Behaviour %*`r`nexit /b %ERRORLEVEL%")
    [pscustomobject]@{ Dir = $dir; Repo = $repo; Cmd = $cmd }
}
function Invoke-Smoke($Case, [string]$Kind, [string[]]$Extra = @()) {
    $hostArg = if ($Kind -eq 'claude') { '-ClaudeCmd' } else { '-CopilotCmd' }
    $out = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File $smoke -Hosts $Kind $hostArg $Case.Cmd -Repo $Case.Repo `
        -WorkRoot (Join-Path $Case.Dir 'work') -TimeoutSeconds 60 @Extra 2>&1
    [pscustomobject]@{ Exit = $LASTEXITCODE; Out = ($out -join "`n") }
}

It 'passes when the fake Claude host plays every turn, the audit line lands and the guard refuses' {
    $c = New-SmokeCase 'claude' 'ok'
    try {
        $r = Invoke-Smoke $c 'claude'
        Assert ($r.Exit -eq 0 -and $r.Out -match 'HOST-SMOKE PASS') "expected exit 0 and PASS, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'LEG claude harmless-write PASS' -and $r.Out -match 'LEG claude planted-write PASS') "a leg did not pass: $($r.Out)"
    } finally { Remove-Item -LiteralPath $c.Dir -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'names planted-write and exits 1 when the planted key lands' {
    $c = New-SmokeCase 'claude' 'leak'
    try {
        $r = Invoke-Smoke $c 'claude'
        Assert ($r.Exit -eq 1 -and $r.Out -match 'HOST-SMOKE FAIL - claude planted-write') "expected exit 1 naming planted-write, got $($r.Exit): $($r.Out)"
    } finally { Remove-Item -LiteralPath $c.Dir -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'names harmless-write and exits 1 when the write lands with no audit line' {
    $c = New-SmokeCase 'claude' 'noaudit'
    try {
        $r = Invoke-Smoke $c 'claude'
        Assert ($r.Exit -eq 1 -and $r.Out -match 'LEG claude harmless-write FAIL - .*no \.claude\\ai-audit\.log line') "expected the audit failure, got $($r.Exit): $($r.Out)"
    } finally { Remove-Item -LiteralPath $c.Dir -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'could not examine (exit 2) when no request reached the endpoint' {
    $c = New-SmokeCase 'claude' 'silent'
    try {
        $r = Invoke-Smoke $c 'claude'
        Assert ($r.Exit -eq 2 -and $r.Out -match 'LEG claude run CANNOT - no model request reached the local endpoint') "expected exit 2 for a silent host, got $($r.Exit): $($r.Out)"
    } finally { Remove-Item -LiteralPath $c.Dir -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'could not examine (exit 2) when the recorded cost is not 0' {
    $c = New-SmokeCase 'claude' 'cost'
    try {
        $r = Invoke-Smoke $c 'claude'
        Assert ($r.Exit -eq 2 -and $r.Out -match 'LEG claude zero-cost CANNOT') "expected exit 2 for a non-zero cost, got $($r.Exit): $($r.Out)"
    } finally { Remove-Item -LiteralPath $c.Dir -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'could not examine (exit 2) when the host program is absent' {
    $c = New-SmokeCase 'claude' 'ok'
    try {
        $out = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File $smoke -Hosts claude -ClaudeCmd (Join-Path $c.Dir 'absent.exe') -Repo $c.Repo -WorkRoot (Join-Path $c.Dir 'work') 2>&1
        $code = $LASTEXITCODE
        Assert ($code -eq 2 -and ($out -join "`n") -match 'LEG claude run CANNOT - host program not found') "expected exit 2 for an absent host, got ${code}: $($out -join ' | ')"
    } finally { Remove-Item -LiteralPath $c.Dir -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'starts the host with no inherited CLAUDE or ANTHROPIC variable and a local base URL' {
    $c = New-SmokeCase 'claude' 'ok'
    $env:CLAUDE_B536_CANARY = 'inherited'; $env:ANTHROPIC_AUTH_TOKEN = 'inherited'
    try {
        $r = Invoke-Smoke $c 'claude'
        $seen = @(Get-Content -LiteralPath (Join-Path $c.Dir 'env-claude.txt'))
        Assert (-not ($seen -match '^(CLAUDE_B536_CANARY|ANTHROPIC_AUTH_TOKEN)=')) "an inherited variable reached the host: $($seen -join '; ')"
        Assert (@($seen -match '^ANTHROPIC_BASE_URL=http://127\.0\.0\.1:\d+$').Count -eq 1) "the base URL is not the local endpoint: $($seen -join '; ')"
    } finally {
        Remove-Item env:CLAUDE_B536_CANARY, env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $c.Dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'passes the fake Copilot host and names hook-count when the loaded count differs from hooks.json + settings.json' {
    $c = New-SmokeCase 'copilot' 'ok'
    $d = New-SmokeCase 'copilot' 'hooks'
    try {
        $r = Invoke-Smoke $c 'copilot'
        Assert ($r.Exit -eq 0 -and $r.Out -match 'LEG copilot hook-count PASS - loaded hookCount=2') "expected a Copilot pass with hookCount 2, got $($r.Exit): $($r.Out)"
        $r = Invoke-Smoke $d 'copilot'
        Assert ($r.Exit -eq 1 -and $r.Out -match 'HOST-SMOKE FAIL - copilot hook-count' -and $r.Out -match 'hookCount=1, expected 2') "expected exit 1 naming hook-count, got $($r.Exit): $($r.Out)"
    } finally {
        Remove-Item -LiteralPath $c.Dir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $d.Dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'HostSmoke.Tests (B-536 real-host smoke classification)')
