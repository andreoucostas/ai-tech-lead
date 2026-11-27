#requires -Version 7.0
<#
  B-97 canary 2 — does an UNPROTECTED .github/instructions/ file reach Copilot?

  Why it decides the design: the installer protects CLAUDE.md, AGENTS.md and
  .github/copilot-instructions.md, so none of them reaches an already-installed consumer. It does
  NOT protect .github/instructions/ (install.ps1:31 vs :37). If a framework-rules instruction file
  is delivered there and actually reaches the model, Option A (split framework blocks into an
  unprotected file) gains a native Copilot leg and becomes the answer for both hosts.

  TWO ARMS, because a bare null result is uninterpretable:
    A (subject) — sentinel only in .github/instructions/framework-rules.instructions.md
    B (control) — sentinel only in .github/copilot-instructions.md, a known-supported surface

    A hit,  B hit   -> both surfaces reach; Option A viable on Copilot
    A miss, B hit    -> .github/instructions/ does NOT reach this host; Option A needs another leg
    A miss, B miss   -> INCONCLUSIVE; the method is wrong, not the finding
    A hit,  B miss   -> anomalous; investigate before believing either

  Tools are deliberately NOT permitted: if the model could read files it might reach the sentinel
  without the instruction surface delivering it, which would be a false positive.
#>
[CmdletBinding()]
param(
    [string]$CopilotCmd = '',
    [string]$NodeDir    = 'C:\Program Files\nodejs',
    [int]$TimeoutSeconds = 180,
    [switch]$ResolveOnly,
    # Layout mode: how MANY TIMES each sentinel is placed in the context Copilot CLI sends, for the
    # instruction-file layout a client repository carries. It counts occurrences in the session's
    # events.jsonl (every event except the model's own `assistant.*` ones). Chosen over
    # canary-single-carrier.ps1 because that script drives Claude Code; this one drives Copilot CLI and
    # already builds git-initialised `.github/instructions` fixtures.
    [ValidateSet('agents-only', 'agents-plus-claude-stub', 'agents-import', 'rules-both-folders')]
    [string]$Layout,
    # Layout mode only: Copilot CLI's session-state directory (default: $COPILOT_HOME or ~/.copilot, /session-state).
    [string]$SessionStateRoot = '',
    [string]$Model = 'claude-haiku-5.5',
    [string[]]$ExtraArgs = @(),
    # Layout mode only: directory the temp fixture is created in (default: the system temp directory).
    [string]$FixtureParent = ''
)
$ErrorActionPreference = 'Stop'

if ($Layout) {
    # Exits: 0 OBSERVED, 2 INCONCLUSIVE or could not run. The counts are the finding; there is no expectation.
    function Write-Canary {
        param([string]$A, [string]$R, [string]$R2, [string]$Verdict, [string]$Tool)
        Write-Host "CANARY layout=$Layout A_count=$A R_count=$R R2_count=$R2 verdict=$Verdict tool=$Tool"
    }
    function New-Codeword {
        $l = -join (1..7 | ForEach-Object { [char](65 + (Get-Random -Maximum 26)) })
        $s = -join (1..4 | ForEach-Object { 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[(Get-Random -Maximum 32)] })
        "$l-$s"
    }
    $hasR = $Layout -ne 'agents-only'
    $hasR2 = $Layout -eq 'rules-both-folders'
    $tool = $CopilotCmd
    if ([string]::IsNullOrWhiteSpace($tool) -and -not [string]::IsNullOrWhiteSpace($env:APPDATA)) { $tool = Join-Path $env:APPDATA 'npm\copilot.cmd' }
    if (-not $tool -or -not (Test-Path -LiteralPath $tool -PathType Leaf)) {
        Write-Host 'INCONCLUSIVE - the copilot executable was not found; pass -CopilotCmd. Nothing was examined.'
        Write-Canary 'n/a' 'n/a' 'n/a' 'INCONCLUSIVE' 'unavailable'
        exit 2
    }
    $tool = (Resolve-Path -LiteralPath $tool).Path
    $env:PATH = "$NodeDir;" + (Split-Path $tool) + ";$env:PATH"
    $version = ((& $tool --version 2>&1 | Select-Object -First 1) | Out-String).Trim()
    if (-not $SessionStateRoot) {
        $home2 = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $HOME '.copilot' }
        $SessionStateRoot = Join-Path $home2 'session-state'
    }
    $parent = if ($FixtureParent) { $FixtureParent } else { [IO.Path]::GetTempPath() }
    New-Item -ItemType Directory -Path $parent -Force | Out-Null

    $sentA = New-Codeword; $sentR = New-Codeword; $sentR2 = New-Codeword
    $root = Join-Path $parent ('layoutcanary-copilot-' + [IO.Path]::GetRandomFileName())
    $code = 2
    try {
        function Add-FixtureFile([string]$Rel, [string]$Text) {
            $p = Join-Path $root $Rel
            New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
            Set-Content -LiteralPath $p -Value $Text -Encoding utf8NoBOM
        }
        $rulesRel = '.github/instructions/framework-rules.instructions.md'
        $rulesFile = "---`napplyTo: `"**`"`n---`n# Framework rules`n`nThe framework rules codeword is $sentR.`n"
        $agents = "# Canary project`n`nThe project codeword is $sentA.`n"
        if ($Layout -eq 'agents-import') { $agents += "`n@$rulesRel`n" }
        Add-FixtureFile 'AGENTS.md' $agents
        if ($Layout -eq 'agents-plus-claude-stub') { Add-FixtureFile 'CLAUDE.md' "# Canary project`n`n@AGENTS.md`n@$rulesRel`n" }
        if ($hasR) { Add-FixtureFile $rulesRel $rulesFile }
        if ($hasR2) { Add-FixtureFile '.claude/rules/framework-rules.md' "# Framework rules, second carrier`n`nThe second rules codeword is $sentR2.`n" }

        Write-Host "Layout: $Layout"
        Write-Host 'Fixture files:'
        Get-ChildItem -LiteralPath $root -Recurse -File -Force | ForEach-Object { Write-Host ('  ' + $_.FullName.Substring($root.Length + 1).Replace('\', '/')) }
        Push-Location $root
        try { & git init --quiet 2>&1 | Out-Null; & git add -A 2>&1 | Out-Null } finally { Pop-Location }

        $prompt = @"
List every project codeword you can see in your context from repository instruction files, one per line.
Use ONLY what is already in your context. Do NOT read, search, or list any file.
If you see none, answer exactly: NONE
"@
        $copilotArgs = @('-p', $prompt, '--no-color', '--no-auto-update') + $(if ($Model) { @('--model', $Model) } else { @() }) + $ExtraArgs
        $since = [DateTime]::UtcNow.AddSeconds(-5)
        $job = Start-Job -ScriptBlock {
            param($cmd, $a, $wd)
            Set-Location $wd
            & $cmd @a 2>&1 | Out-String
        } -ArgumentList $tool, $copilotArgs, $root
        $done = Wait-Job $job -Timeout $TimeoutSeconds
        $null = if ($done) { Receive-Job $job }
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        if (-not $done) {
            Write-Host "INCONCLUSIVE - the CLI did not finish within $TimeoutSeconds s; nothing was examined."
            Write-Canary 'n/a' 'n/a' 'n/a' 'INCONCLUSIVE' $version
        } else {
            $leaf = Split-Path -Leaf $root
            $events = Get-ChildItem -LiteralPath $SessionStateRoot -Directory -ErrorAction SilentlyContinue |
                ForEach-Object { Join-Path $_.FullName 'events.jsonl' } |
                Where-Object { (Test-Path -LiteralPath $_ -PathType Leaf) -and (Get-Item -LiteralPath $_).LastWriteTimeUtc -ge $since } |
                Where-Object { (Get-Content -LiteralPath $_ -Raw) -match [regex]::Escape($leaf) } |
                Sort-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc } -Descending | Select-Object -First 1
            if (-not $events) {
                Write-Host "INCONCLUSIVE - no events.jsonl under $SessionStateRoot names this run's fixture; nothing was counted."
                Write-Canary 'n/a' 'n/a' 'n/a' 'INCONCLUSIVE' $version
            } else {
                $count = @{ A = 0; R = 0; R2 = 0 }; $byType = @{}; $reads = 0; $answer = ''
                foreach ($line in (Get-Content -LiteralPath $events)) {
                    $type = ''; try { $type = [string]($line | ConvertFrom-Json -ErrorAction Stop).type } catch { }
                    if ($type -like 'assistant.*') { $answer += $line; continue }
                    if ($type -like 'tool.execution_*') { $reads++ }
                    foreach ($pair in @(@('A', $sentA), @('R', $sentR), @('R2', $sentR2))) {
                        $n = [regex]::Matches($line, [regex]::Escape($pair[1])).Count
                        if ($n) { $count[$pair[0]] += $n; $byType["$($pair[0]) in $type"] = [int]$byType["$($pair[0]) in $type"] + $n }
                    }
                }
                Write-Host ("Events: $events")
                Write-Host ('Placed in: ' + $(if ($byType.Count) { (($byType.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join '; ') } else { 'nowhere' }))
                Write-Host ("Model answer named: A=$($answer -match [regex]::Escape($sentA)) R=$($answer -match [regex]::Escape($sentR)) R2=$($answer -match [regex]::Escape($sentR2))")
                if ($reads -gt 0) {
                    Write-Host "INCONCLUSIVE - $reads tool execution event(s) in the session; the run is not a pure context reading."
                    Write-Canary $count.A $(if ($hasR) { $count.R } else { 'n/a' }) $(if ($hasR2) { $count.R2 } else { 'n/a' }) 'INCONCLUSIVE' $version
                } else {
                    Write-Canary $count.A $(if ($hasR) { $count.R } else { 'n/a' }) $(if ($hasR2) { $count.R2 } else { 'n/a' }) 'OBSERVED' $version
                    $code = 0
                }
            }
        }
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
    exit $code
}

if ([string]::IsNullOrWhiteSpace($CopilotCmd)) {
    if ([string]::IsNullOrWhiteSpace($env:APPDATA)) { throw 'Copilot CLI not found; pass -CopilotCmd.' }
    $CopilotCmd = Join-Path $env:APPDATA 'npm\copilot.cmd'
}
if (-not (Test-Path -LiteralPath $CopilotCmd -PathType Leaf)) { throw 'Copilot CLI not found; pass -CopilotCmd.' }
$CopilotCmd = (Resolve-Path -LiteralPath $CopilotCmd).Path
if ($ResolveOnly) { Write-Output $CopilotCmd; exit 0 }
$env:PATH = "$NodeDir;" + (Split-Path $CopilotCmd) + ";$env:PATH"

$prompt = @"
What is the project codeword? Reply with the codeword only.
Use ONLY what is already in your context from repository instruction files.
Do NOT read, search, or list any file. If it is not already in your context, reply exactly: NOT-IN-CONTEXT
"@

function Invoke-Arm {
    param([string]$Name, [string]$Sentinel, [string]$RelPath)

    $dir = Join-Path ([IO.Path]::GetTempPath()) ("b97-canary2-$Name-" + [IO.Path]::GetRandomFileName())
    $full = Join-Path $dir $RelPath
    New-Item -ItemType Directory -Path (Split-Path $full) -Force | Out-Null

    $body = if ($RelPath -like '*instructions/*') {
@"
---
applyTo: "**"
---
# Framework rules

The project codeword is $Sentinel. It designates the instructions-file delivery path.
"@
    } else {
@"
# Repository instructions

The project codeword is $Sentinel. It designates the copilot-instructions delivery path.
"@
    }
    Set-Content -Path $full -Value $body -Encoding utf8NoBOM

    # A repo root makes the .github/ convention unambiguous for the host.
    Push-Location $dir
    try {
        & git init --quiet 2>&1 | Out-Null
        & git add -A 2>&1 | Out-Null

        $job = Start-Job -ScriptBlock {
            param($cmd, $p, $wd)
            Set-Location $wd
            & $cmd -p $p --no-color 2>&1 | Out-String
        } -ArgumentList $CopilotCmd, $prompt, $dir

        $done = Wait-Job $job -Timeout $TimeoutSeconds
        $out  = if ($done) { Receive-Job $job } else { '<TIMEOUT>' }
        Remove-Job $job -Force -ErrorAction SilentlyContinue
    } finally { Pop-Location }

    $raw = [string]$out
    [pscustomobject]@{
        Arm        = $Name
        Path       = $RelPath
        Sentinel   = $Sentinel
        Hit        = $raw -match [regex]::Escape($Sentinel)
        NotInCtx   = $raw -match 'NOT-IN-CONTEXT'
        ToolUsed   = $raw -match '(?i)\b(reading|read file|glob|grep|searching)\b'
        Dir        = $dir
        Output     = $raw
    }
}

Write-Host 'B-97 canary 2 — .github/instructions/ delivery to Copilot'
Write-Host "Copilot: $(& $CopilotCmd --version 2>&1 | Select-Object -First 1)"
Write-Host ''

$armA = Invoke-Arm -Name 'subject' -Sentinel 'QUVIRAX-3T8P' -RelPath '.github/instructions/framework-rules.instructions.md'
Write-Host "  A (.github/instructions/)      hit=$($armA.Hit) notInCtx=$($armA.NotInCtx)"
$armB = Invoke-Arm -Name 'control' -Sentinel 'MELDOVAR-9K2R' -RelPath '.github/copilot-instructions.md'
Write-Host "  B (.github/copilot-instructions) hit=$($armB.Hit) notInCtx=$($armB.NotInCtx)"

Write-Host ''
Write-Host '=== VERDICT ==='
if     (($armA.Hit -and $armA.ToolUsed) -or ($armB.Hit -and $armB.ToolUsed)) { Write-Host 'INCONCLUSIVE - a hit came with a file-tool use, so it is not attributable to the instruction surface.'; $code = 2 }
elseif ($armA.Hit -and $armB.Hit)       { Write-Host 'BOTH REACH — .github/instructions/ delivers; Option A gains a native Copilot leg.'; $code = 0 }
elseif (-not $armA.Hit -and $armB.Hit)  { Write-Host 'SUBJECT MISS, CONTROL HIT — .github/instructions/ does NOT reach this host. Option A needs another Copilot leg.'; $code = 1 }
elseif (-not $armA.Hit -and -not $armB.Hit) { Write-Host 'INCONCLUSIVE — control also failed, so the method is wrong, not the finding. Do not record either way.'; $code = 2 }
else   { Write-Host 'ANOMALOUS — subject hit while the known-good control missed. Investigate before believing either.'; $code = 3 }

Write-Host ''
Write-Host "  A output: $($armA.Dir)"
Write-Host "  B output: $($armB.Dir)"
exit $code
