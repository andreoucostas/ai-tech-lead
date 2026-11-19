<#
.SYNOPSIS
  B-536: drive the real Claude Code and Copilot CLI programs over an installed dist, against a scripted
  model on 127.0.0.1, and check that the framework's hooks fire. No key, no access, no model cost.
.DESCRIPTION
  Installs dist/<Dist> into a scratch repository with the shipped installer (or uses -Repo), then per
  host plays four scripted turns from _scripted-endpoint.ps1: change directory into sub\, write a
  harmless file, write a file holding a planted key-shaped string, end. Each host starts at the
  repository root: Claude Code started in a subfolder loads no project hooks, so it starts at the root
  and moves. Legs, each read from traces the hosts and hooks already leave:
    session-hooks   the session-start hook's state file was written during the run
    moved-directory the shell step ran in sub\ (Claude Code keeps that directory for later tool calls)
    harmless-write  the file landed and the audit-trail hook logged it in .claude\ai-audit.log
    planted-write   the guard refused the write: the file is absent and the tool call failed
    inventory       Claude Code's init event lists the framework's commands; Copilot's skill list
    hook-count      Copilot loaded .github/hooks/hooks.json entries + .claude/settings.json entries
  Every host launch drops inherited CLAUDE*/ANTHROPIC*/COPILOT*/GITHUB_TOKEN/GH_TOKEN/OTEL* variables
  and points the host's model endpoint at the local listener with a dummy key; a run whose recorded
  cost is not 0, or whose host sent no request to the listener, is "could not examine".
  NOT COVERED: agent behaviour (what a real model chooses to do, e.g. 7db19ed4's uncommitted
  install). The model here is a script; this checks host mechanics only.
.OUTPUTS
  One "LEG <host> <leg> PASS|FAIL|CANNOT - <detail>" line per leg, then one HOST-SMOKE line.
  Exit 0 pass; 1 a host misbehaved (the failed legs are named); 2 could not examine.
#>
[CmdletBinding()]
param(
    [ValidateSet('claude', 'copilot')][string[]]$Hosts = @('claude', 'copilot'),
    [string]$ClaudeCmd = (Join-Path $env:USERPROFILE '.local\bin\claude.exe'),
    [string]$CopilotCmd = (Join-Path ([string]$env:APPDATA) 'npm\copilot.cmd'),
    [ValidateSet('dotnet', 'angular', 'monorepo')][string]$Dist = 'dotnet',
    [string]$Repo,
    [string]$WorkRoot,
    [int]$TimeoutSeconds = 240
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$endpoint = Join-Path $PSScriptRoot '_scripted-endpoint.ps1'
$pwshExe = (Get-Process -Id $PID).Path
$utf8 = [Text.UTF8Encoding]::new($false)
$results = [Collections.Generic.List[object]]::new()

function Add-Leg([string]$HostName, [string]$Leg, [string]$Status, [string]$Detail) {
    $results.Add([pscustomobject]@{ Host = $HostName; Leg = $Leg; Status = $Status; Detail = $Detail })
    [Console]::Out.WriteLine("LEG $HostName $Leg $Status - $Detail")
}
function Read-JsonLines([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return @() }
    @(Get-Content -LiteralPath $Path -Encoding utf8 | ForEach-Object { try { $_ | ConvertFrom-Json -Depth 50 } catch { } } | Where-Object { $_ })
}
function Write-Done([int]$Code, [string]$Line) { [Console]::Out.WriteLine($Line); exit $Code }

function Invoke-HostProcess([string]$File, [string[]]$Arguments, [hashtable]$Environment, [string]$Directory, [string]$OutPath, [string]$ErrPath) {
    $psi = [Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $File
    $psi.WorkingDirectory = $Directory
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = $true
    foreach ($k in @($psi.Environment.Keys)) {
        if ($k -match '^(CLAUDE|ANTHROPIC|COPILOT|OTEL)' -or $k -in @('GITHUB_TOKEN', 'GH_TOKEN', 'GH_HOST')) { [void]$psi.Environment.Remove($k) }
    }
    foreach ($k in $Environment.Keys) { $psi.Environment[$k] = [string]$Environment[$k] }
    foreach ($a in $Arguments) { [void]$psi.ArgumentList.Add($a) }
    $p = [Diagnostics.Process]::Start($psi)
    $p.StandardInput.Close()
    $o = $p.StandardOutput.ReadToEndAsync(); $e = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
        try { $p.Kill($true) } catch { }
        [void]$p.WaitForExit(10000)
        return [pscustomobject]@{ Exit = $null; TimedOut = $true }
    }
    [IO.File]::WriteAllText($OutPath, $o.GetAwaiter().GetResult(), $utf8)
    [IO.File]::WriteAllText($ErrPath, $e.GetAwaiter().GetResult(), $utf8)
    [pscustomobject]@{ Exit = $p.ExitCode; TimedOut = $false }
}

function Start-Endpoint([string]$Dir, [object[]]$Turns) {
    $script = Join-Path $Dir 'script.json'
    [IO.File]::WriteAllText($script, (@{ turns = $Turns } | ConvertTo-Json -Depth 10), $utf8)
    $ready = Join-Path $Dir 'ready.txt'
    $proc = Start-Process -FilePath $pwshExe -PassThru -WindowStyle Hidden -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', "`"$endpoint`"", '-ScriptFile', "`"$script`"", '-LogFile', "`"$(Join-Path $Dir 'endpoint.jsonl')`"",
        '-ReadyFile', "`"$ready`"", '-MaxSeconds', [string]($TimeoutSeconds + 60))
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while (-not (Test-Path -LiteralPath $ready) -and $clock.Elapsed.TotalSeconds -lt 20 -and -not $proc.HasExited) { Start-Sleep -Milliseconds 100 }
    if (-not (Test-Path -LiteralPath $ready)) { try { $proc.Kill() } catch { }; return $null }
    [pscustomobject]@{ Process = $proc; Port = [int]((Get-Content -LiteralPath $ready -Raw).Trim() -replace '^LISTENING ', '') }
}

function Get-ExpectedHookCount([string]$Root) {
    $n = 0
    $copilot = Join-Path $Root '.github\hooks\hooks.json'
    if (Test-Path -LiteralPath $copilot) {
        $h = (Get-Content -LiteralPath $copilot -Raw | ConvertFrom-Json).hooks
        foreach ($p in $h.PSObject.Properties) { $n += @($p.Value).Count }
    }
    $claude = Join-Path $Root '.claude\settings.json'
    if (Test-Path -LiteralPath $claude) {
        $h = (Get-Content -LiteralPath $claude -Raw | ConvertFrom-Json).hooks
        foreach ($p in $h.PSObject.Properties) { foreach ($group in @($p.Value)) { $n += @($group.hooks).Count } }
    }
    $n
}

# Legs shared by both hosts, from the repository and the endpoint log.
function Test-CommonLegs([string]$HostName, [string]$Root, [string]$Dir, [datetime]$Since, [string]$StateFile,
    [string]$Harmless, [string]$Planted, [bool]$PlantedToolFailed, [string]$MoveOutput) {
    $state = Join-Path $Root ".claude\.state\$StateFile"
    if ((Test-Path -LiteralPath $state) -and (Get-Item -LiteralPath $state).LastWriteTimeUtc -ge $Since) {
        Add-Leg $HostName 'session-hooks' 'PASS' ".claude\.state\$StateFile written during the run"
    } else { Add-Leg $HostName 'session-hooks' 'FAIL' ".claude\.state\$StateFile not written during the run: the session-start hook did not run" }
    if ($MoveOutput -match '[\\/]sub\s*$' -or $MoveOutput -match '[\\/]sub[\r\n]') {
        Add-Leg $HostName 'moved-directory' 'PASS' 'the shell step printed a location in sub\'
    } else { Add-Leg $HostName 'moved-directory' 'CANNOT' 'the shell step did not report a location in sub\, so the move is not shown' }
    $name = Split-Path $Harmless -Leaf
    $audit = Join-Path $Root '.claude\ai-audit.log'
    # The run id makes the name unique to this run, so a matching audit line is this run's; both files
    # must also have been written since the run started (a reused -Repo keeps earlier runs' traces).
    $logged = (Test-Path -LiteralPath $audit -PathType Leaf) -and (Get-Item -LiteralPath $audit).LastWriteTimeUtc -ge $Since -and
        @(Get-Content -LiteralPath $audit | Where-Object { $_ -match ("\t\.[\\/]sub[\\/]" + [regex]::Escape($name) + '$') }).Count -gt 0
    if (-not (Test-Path -LiteralPath $Harmless -PathType Leaf) -or (Get-Item -LiteralPath $Harmless).LastWriteTimeUtc -lt $Since) {
        Add-Leg $HostName 'harmless-write' 'FAIL' "sub\$name was not written during the run"
    }
    elseif (-not $logged) { Add-Leg $HostName 'harmless-write' 'FAIL' "sub\$name landed with no .claude\ai-audit.log line: the audit-trail hook did not run" }
    else { Add-Leg $HostName 'harmless-write' 'PASS' "sub\$name landed with its audit line" }
    $pname = Split-Path $Planted -Leaf
    if (Test-Path -LiteralPath $Planted) { Add-Leg $HostName 'planted-write' 'FAIL' "sub\$pname holds the planted key: the guard did not refuse it" }
    elseif (-not $PlantedToolFailed) { Add-Leg $HostName 'planted-write' 'CANNOT' "sub\$pname is absent but the host reported no failed write for it" }
    else { Add-Leg $HostName 'planted-write' 'PASS' "the guard refused sub\$pname" }
}

# Was the run examinable at all: requests reached the listener and the whole script was served.
function Test-Examinable([string]$HostName, [string]$Dir, [object]$Run, [int]$LastTurn) {
    if ($Run.TimedOut) { Add-Leg $HostName 'run' 'CANNOT' "the host did not finish within $TimeoutSeconds s"; return $false }
    $log = @(Read-JsonLines (Join-Path $Dir 'endpoint.jsonl'))
    $model = @($log | Where-Object { $_.shape -in @('anthropic', 'chat') })
    if ($model.Count -eq 0) { Add-Leg $HostName 'run' 'CANNOT' "no model request reached the local endpoint (host exit $($Run.Exit)); it may refuse the offline setting"; return $false }
    $served = @($model | Where-Object { $_.turn -ge 0 } | ForEach-Object { [int]$_.turn } | Sort-Object -Descending)
    $paths = (@($log | ForEach-Object { "$($_.method) $($_.path)" }) | Sort-Object -Unique) -join ', '
    if ($served.Count -eq 0 -or $served[0] -lt $LastTurn) {
        Add-Leg $HostName 'run' 'CANNOT' "the host stopped before the scripted planted write (last turn served: $(if ($served) { $served[0] } else { 'none' }); requests: $paths)"
        return $false
    }
    Add-Leg $HostName 'run' 'PASS' "the turn script was played to the end; $($log.Count) requests reached the local listener: $paths"
    return $true
}

function Invoke-ClaudeLegs([string]$Root, [string]$Dir, [string]$RunId) {
    $harmless = Join-Path $Root "sub\smoke-claude-$RunId-harmless.txt"
    $planted = Join-Path $Root "sub\smoke-claude-$RunId-planted.txt"
    $turns = @(
        @{ tool = 'PowerShell'; input = @{ command = 'Set-Location -LiteralPath sub; (Get-Location).Path'; description = 'Move into sub' } }
        @{ tool = 'Write'; input = @{ file_path = $harmless; content = "harmless smoke write`n" } }
        @{ tool = 'Write'; input = @{ file_path = $planted; content = "key = $('AKIA' + '1234567890ABCDEF')`n" } }
        @{ text = 'Smoke done.' })
    $ep = Start-Endpoint $Dir $turns
    if (-not $ep) { Add-Leg 'claude' 'run' 'CANNOT' 'the local endpoint did not start'; return }
    $since = [DateTime]::UtcNow
    $envs = @{
        ANTHROPIC_BASE_URL = "http://127.0.0.1:$($ep.Port)"; ANTHROPIC_API_KEY = 'dummy-local-test'
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '1'; DISABLE_TELEMETRY = '1'; DISABLE_ERROR_REPORTING = '1'
        DISABLE_AUTOUPDATER = '1'; CLAUDE_CONFIG_DIR = (Join-Path $Dir 'config')
    }
    New-Item -ItemType Directory -Force -Path $envs.CLAUDE_CONFIG_DIR | Out-Null
    $out = Join-Path $Dir 'stream.jsonl'
    try {
        $run = Invoke-HostProcess $ClaudeCmd @('-p', 'Run the scripted host smoke.', '--output-format', 'stream-json', '--verbose',
            '--setting-sources', 'project,local', '--permission-mode', 'acceptEdits', '--allowedTools', 'PowerShell,Write') $envs $Root $out (Join-Path $Dir 'stderr.txt')
    } finally { try { $ep.Process.Kill() } catch { } }
    if (-not (Test-Examinable 'claude' $Dir $run 2)) { return }
    $events = @(Read-JsonLines $out)
    $result = @($events | Where-Object { $_.type -eq 'result' } | Select-Object -Last 1)
    if (-not $result -or $null -eq $result[0].total_cost_usd -or [double]$result[0].total_cost_usd -ne 0) {
        Add-Leg 'claude' 'zero-cost' 'CANNOT' "the result event does not record total_cost_usd 0 ($(if ($result) { $result[0].total_cost_usd } else { 'no result event' }))"; return
    }
    Add-Leg 'claude' 'zero-cost' 'PASS' 'result event total_cost_usd 0'
    $uses = @{}; $results2 = @{}
    foreach ($ev in $events) {
        foreach ($c in @($ev.message.content)) {
            if ($c.type -eq 'tool_use') { $uses[[string]$c.id] = $c }
            if ($c.type -eq 'tool_result') { $results2[[string]$c.tool_use_id] = $c }
        }
    }
    $moveOut = ''; $plantedFailed = $false
    foreach ($id in $uses.Keys) {
        $u = $uses[$id]; $r = $results2[$id]
        $text = if ($r) { (@($r.content) | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.text } }) -join "`n" } else { '' }
        if ($u.name -eq 'PowerShell') { $moveOut = $text }
        if ($u.name -eq 'Write' -and [string]$u.input.file_path -eq $planted -and $r -and $r.is_error) { $plantedFailed = $true }
    }
    Test-CommonLegs 'claude' $Root $Dir $since 'last-session-start' $harmless $planted $plantedFailed $moveOut
    $init = @($events | Where-Object { $_.type -eq 'system' -and $_.subtype -eq 'init' } | Select-Object -First 1)
    $commands = @($init | ForEach-Object { $_.slash_commands })
    $skills = @($init | ForEach-Object { $_.skills })
    if ($commands -contains 'bootstrap') { Add-Leg 'claude' 'inventory' 'PASS' "init lists $($commands.Count) commands (bootstrap among them) and $($skills.Count) skills" }
    else { Add-Leg 'claude' 'inventory' 'FAIL' "init lists $($commands.Count) commands, without bootstrap, and $($skills.Count) skills" }
}

function Invoke-CopilotLegs([string]$Root, [string]$Dir, [string]$RunId) {
    $harmless = Join-Path $Root "sub\smoke-copilot-$RunId-harmless.txt"
    $planted = Join-Path $Root "sub\smoke-copilot-$RunId-planted.txt"
    $turns = @(
        @{ tool = 'powershell'; input = @{ command = 'Set-Location -LiteralPath sub; (Get-Location).Path'; description = 'Move into sub' } }
        @{ tool = 'create'; input = @{ path = $harmless; file_text = "harmless smoke write`n" } }
        @{ tool = 'create'; input = @{ path = $planted; file_text = "key = $('AKIA' + '1234567890ABCDEF')`n" } }
        @{ text = 'Smoke done.' })
    $ep = Start-Endpoint $Dir $turns
    if (-not $ep) { Add-Leg 'copilot' 'run' 'CANNOT' 'the local endpoint did not start'; return }
    $since = [DateTime]::UtcNow
    $home2 = Join-Path $Dir 'home'; $logs = Join-Path $Dir 'logs'; $usage = Join-Path $Dir 'usage.json'
    New-Item -ItemType Directory -Force -Path $home2 | Out-Null
    $envs = @{
        COPILOT_OFFLINE = 'true'; COPILOT_HOME = $home2; COPILOT_PROVIDER_BASE_URL = "http://127.0.0.1:$($ep.Port)/v1"
        COPILOT_PROVIDER_TYPE = 'openai'; COPILOT_PROVIDER_API_KEY = 'dummy-local-test'; COPILOT_MODEL = 'scripted-model'
        COPILOT_PROVIDER_MAX_PROMPT_TOKENS = '100000'; COPILOT_PROVIDER_MAX_OUTPUT_TOKENS = '4000'
        COPILOT_AUTO_UPDATE = 'false'; GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS = 'true'
    }
    $out = Join-Path $Dir 'stdout.jsonl'
    try {
        $run = Invoke-HostProcess $CopilotCmd @('-p', 'Run the scripted host smoke.', '-C', $Root, '--allow-all-tools', '--no-ask-user',
            '--no-remote', '--no-remote-export', '--no-color', '--no-auto-update', '--output-format', 'json', '--log-dir', $logs, '--log-level', 'debug',
            '--usage-output-file', $usage) $envs $Root $out (Join-Path $Dir 'stderr.txt')
    } finally { try { $ep.Process.Kill() } catch { } }
    if (-not (Test-Examinable 'copilot' $Dir $run 2)) { return }
    $cost = $null
    if (Test-Path -LiteralPath $usage -PathType Leaf) { try { $cost = (Get-Content -LiteralPath $usage -Raw | ConvertFrom-Json).totalPremiumRequestCost } catch { $cost = "unreadable: $($_.Exception.Message)" } }
    if ($null -eq $cost -or $cost -isnot [ValueType] -or [double]$cost -ne 0) { Add-Leg 'copilot' 'zero-cost' 'CANNOT' "the usage file does not record totalPremiumRequestCost 0 ($cost)"; return }
    Add-Leg 'copilot' 'zero-cost' 'PASS' 'usage file totalPremiumRequestCost 0'
    $events = @(Read-JsonLines $out)
    $starts = @{}; $moveOut = ''; $plantedFailed = $false
    foreach ($ev in $events) {
        if ($ev.type -eq 'tool.execution_start') { $starts[[string]$ev.data.toolCallId] = $ev.data }
        if ($ev.type -eq 'tool.execution_complete') {
            $s = $starts[[string]$ev.data.toolCallId]
            $targs = if ($s) { $s.arguments } else { $null }
            if ($s -and $s.toolName -eq 'powershell') { $moveOut = [string]$ev.data.result.content }
            if ($s -and $s.toolName -eq 'create' -and [string]$targs.path -eq $planted -and -not $ev.data.success) { $plantedFailed = $true }
        }
    }
    Test-CommonLegs 'copilot' $Root $Dir $since 'last-session-start-copilot' $harmless $planted $plantedFailed $moveOut
    try { $expected = Get-ExpectedHookCount $Root }
    catch { Add-Leg 'copilot' 'hook-count' 'CANNOT' "could not read .github/hooks/hooks.json or .claude/settings.json: $($_.Exception.Message)"; $expected = $null }
    $logText = (Get-ChildItem -LiteralPath $logs -Filter *.log -File -ErrorAction SilentlyContinue | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
    $m = [regex]::Matches($logText, 'hookCount=(\d+)')
    if ($null -eq $expected) { }
    elseif ($m.Count -eq 0) { Add-Leg 'copilot' 'hook-count' 'FAIL' "the log records no loaded repo hooks; expected $expected" }
    elseif ([int]$m[$m.Count - 1].Groups[1].Value -ne $expected) { Add-Leg 'copilot' 'hook-count' 'FAIL' "loaded hookCount=$($m[$m.Count - 1].Groups[1].Value), expected $expected (hooks.json + .claude/settings.json)" }
    else { Add-Leg 'copilot' 'hook-count' 'PASS' "loaded hookCount=$expected (hooks.json + .claude/settings.json)" }
    $skillOut = Join-Path $Dir 'skills.json'
    $sk = Invoke-HostProcess $CopilotCmd @('skill', 'list', '--json') $envs $Root $skillOut (Join-Path $Dir 'skills-stderr.txt')
    $names = @()
    if (-not $sk.TimedOut -and $sk.Exit -eq 0) {
        try { $names = @((Get-Content -LiteralPath $skillOut -Raw | ConvertFrom-Json) | ForEach-Object { if ($_.name) { $_.name } else { $_ } }) } catch { $names = @() }
    }
    if ($names.Count -eq 0) { Add-Leg 'copilot' 'inventory' 'CANNOT' "skill list --json gave no list (exit $($sk.Exit))" }
    elseif ($names -contains 'map-warehouse') { Add-Leg 'copilot' 'inventory' 'PASS' "skill list names $($names.Count) skills (map-warehouse among them)" }
    else { Add-Leg 'copilot' 'inventory' 'FAIL' "skill list names $($names.Count) skills, without map-warehouse" }
}

# Setup: anything that throws here is the script failing to set up, never a host fault, so it ends as
# "could not examine" (exit 2), not as the uncaught-error exit 1 that reads as a host misbehaving.
try {
if (-not $WorkRoot) { $WorkRoot = Join-Path ([IO.Path]::GetTempPath()) ('host-smoke-' + [guid]::NewGuid().ToString('N').Substring(0, 12)) }
New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null
# Unique per run, so a reused -Repo's earlier smoke files and audit lines cannot stand in for this run's.
$runId = [DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6)
if ($Repo -and -not (Test-Path -LiteralPath $Repo -PathType Container)) { Write-Done 2 "HOST-SMOKE CANNOT_EXAMINE - the repository $Repo is not a directory" }
if (-not $Repo) {
    $Repo = Join-Path $WorkRoot 'repo'
    New-Item -ItemType Directory -Force -Path $Repo | Out-Null
    [IO.File]::WriteAllText((Join-Path $Repo 'Smoke.csproj'), '<Project />', $utf8)
    git -C $Repo init -q 2>&1 | Out-Null
    git -C $Repo -c user.email=smoke@localhost -c user.name=smoke add -A 2>&1 | Out-Null
    git -C $Repo -c user.email=smoke@localhost -c user.name=smoke commit -qm init 2>&1 | Out-Null
    $installOut = & $pwshExe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "dist\$Dist\scripts\install.ps1") -Target $Repo 2>&1
    $installExit = $LASTEXITCODE
    [IO.File]::WriteAllLines((Join-Path $WorkRoot 'install.txt'), [string[]]@($installOut | ForEach-Object { [string]$_ }), $utf8)
    if ($installExit -ne 0) { Write-Done 2 "HOST-SMOKE CANNOT_EXAMINE - the dist/$Dist installer exited $installExit (see $WorkRoot\install.txt)" }
}
$Repo = (Resolve-Path -LiteralPath $Repo).Path
if (-not (Test-Path -LiteralPath (Join-Path $Repo '.claude\settings.json'))) { Write-Done 2 "HOST-SMOKE CANNOT_EXAMINE - $Repo has no .claude\settings.json" }
New-Item -ItemType Directory -Force -Path (Join-Path $Repo 'sub') | Out-Null
[Console]::Out.WriteLine("host-smoke: repository $Repo; work $WorkRoot")
} catch { Write-Done 2 "HOST-SMOKE CANNOT_EXAMINE - setup failed: $($_.Exception.Message)" }

foreach ($h in $Hosts) {
    $cmd = if ($h -eq 'claude') { $ClaudeCmd } else { $CopilotCmd }
    if (-not $cmd -or -not (Test-Path -LiteralPath $cmd -PathType Leaf)) { Add-Leg $h 'run' 'CANNOT' "host program not found (no file): $cmd"; continue }
    # A throw inside one host's legs (the host will not start, a trace is unreadable) is that host's
    # "could not examine"; the other host's legs still run.
    try {
        $dir = Join-Path $WorkRoot $h
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        if ($h -eq 'claude') { Invoke-ClaudeLegs $Repo $dir $runId } else { Invoke-CopilotLegs $Repo $dir $runId }
    } catch { Add-Leg $h 'run' 'CANNOT' "the smoke could not complete for this host: $($_.Exception.Message)" }
}

$failed = @($results | Where-Object Status -eq 'FAIL' | ForEach-Object { "$($_.Host) $($_.Leg)" })
$cannot = @($results | Where-Object Status -eq 'CANNOT' | ForEach-Object { "$($_.Host) $($_.Leg)" })
if ($results.Count -eq 0) { Write-Done 2 'HOST-SMOKE CANNOT_EXAMINE - no leg was run' }
if ($failed) { Write-Done 1 "HOST-SMOKE FAIL - $($failed -join '; ')" }
if ($cannot) { Write-Done 2 "HOST-SMOKE CANNOT_EXAMINE - $($cannot -join '; ')" }
Write-Done 0 "HOST-SMOKE PASS - $(@($results | ForEach-Object Host | Sort-Object -Unique) -join ', ')"
