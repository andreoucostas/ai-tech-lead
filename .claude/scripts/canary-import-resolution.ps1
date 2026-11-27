#requires -Version 7.0
<#
  B-97 canary 1 — does an @import in a ROOT CLAUDE.md resolve into context?

  The repo proves @path inclusion only for .claude/commands/*.md. Option A (split framework-owned
  blocks into an unprotected imported file) collapses if it does not resolve from CLAUDE.md itself.
  This cannot be answered by reading the repo, and reasoning it out from general knowledge of the
  host is exactly what got caught twice in review.

  Design: a sentinel token exists ONLY in the imported file. The prompt asks for it and forbids
  reading files. The transcript is then checked for file-access tools -- if the model read the file,
  the run proves nothing and is scored INCONCLUSIVE rather than positive.

  Model choice is deliberate: this measures the HOST's context assembly, not model capability, so
  the cheapest model is correct here. A weaker model is if anything a better instrument, being less
  able to confabulate a plausible answer.
#>
[CmdletBinding()]
param(
    # Relative path of the imported file; the fixture's root CLAUDE.md carries `@<ImportTarget>`.
    # Default is the B-97 shape. B-241 runs it with 'AGENTS.md' to certify the root-mirror import
    # (CLAUDE.md = @AGENTS.md) on the current host before relying on it.
    [string]$ImportTarget = '.claude/framework-rules.md',
    # Negative control: write the fixture CLAUDE.md WITHOUT the import line. The sentinel must then be
    # NOT-IN-CONTEXT; if it still echoes, the target reaches the model by another route (for example
    # native loading of the target file) and a treatment positive is not attributable to `@import`.
    [switch]$OmitImport,
    [string]$Model = 'haiku',
    [int]$TimeoutSeconds = 180,
    # Layout mode: which instruction-file layout a client repository carries, built fresh outside
    # the repository and removed afterwards. Prints one final machine-readable CANARY line.
    [ValidateSet('agents-only', 'agents-import', 'rules-folder', 'shadowed', 'shadowed-rules-folder', 'shadowed-rules-import')]
    [string]$Layout,
    # Layout mode only: add --bare to the one-shot call (expected result unknown; reported as OBSERVED).
    [switch]$Bare,
    # The claude executable. Empty means `claude` from PATH. Tests pass a stub here.
    [string]$ClaudeCmd = '',
    # Layout mode only: directory the temp fixture is created in (default: the system temp directory).
    [string]$FixtureParent = '',
    # Layout mode only: copy the stream-json transcript here before the fixture is removed.
    [string]$TranscriptPath = ''
)
$ErrorActionPreference = 'Stop'

if ($Layout) {
    # Exits: 0 AS-EXPECTED or OBSERVED, 1 UNEXPECTED, 2 INCONCLUSIVE or could not run.
    # Measures the TOOL's context assembly: the model must answer from context, with no file read.
    function New-Codeword {
        $l = -join (1..7 | ForEach-Object { [char](65 + (Get-Random -Maximum 26)) })
        $s = -join (1..4 | ForEach-Object { 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'[(Get-Random -Maximum 32)] })
        "$l-$s"
    }
    function Write-Canary {
        param([string]$A, [string]$R, [int]$Reads, [string]$Expected, [string]$Verdict, [string]$Tool)
        Write-Host "CANARY layout=$Layout bare=$($Bare.IsPresent.ToString().ToLower()) A=$A R=$R file_reads=$Reads expected=$Expected verdict=$Verdict tool=$Tool"
    }
    $spec = @{
        'agents-only'           = @{ Expect = @('IN', 'n/a') }
        'agents-import'         = @{ Expect = @('IN', 'IN') }
        'rules-folder'          = @{ Expect = @('IN', 'IN') }
        'shadowed'              = @{ Expect = @('OUT', 'n/a') }
        'shadowed-rules-folder' = @{ Expect = @('OUT', 'IN') }
        'shadowed-rules-import' = @{ Expect = $null }
    }[$Layout]
    $hasR = $Layout -notin 'agents-only', 'shadowed'
    $expect = if ($Bare -or $null -eq $spec.Expect) { $null } else { $spec.Expect }
    $expectedText = if ($expect) { ("A:$($expect[0])" + $(if ($hasR) { ",R:$($expect[1])" } else { '' })) } else { 'unknown' }

    $tool = $ClaudeCmd
    if ([string]::IsNullOrWhiteSpace($tool)) { $found = Get-Command claude -CommandType Application, ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1; $tool = if ($found) { $found.Source } else { '' } }
    if (-not $tool -or -not (Test-Path -LiteralPath $tool -PathType Leaf)) {
        Write-Host 'INCONCLUSIVE - the claude executable was not found; pass -ClaudeCmd. Nothing was examined.'
        Write-Canary 'n/a' 'n/a' 0 $expectedText 'INCONCLUSIVE' 'unavailable'
        exit 2
    }
    $tool = (Resolve-Path -LiteralPath $tool).Path
    $version = ((& $tool --version 2>&1 | Select-Object -First 1) | Out-String).Trim()

    $parent = if ($FixtureParent) { $FixtureParent } else { [IO.Path]::GetTempPath() }
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    # A CLAUDE.md in any directory above the fixture shadows a root AGENTS.md and would void the layout.
    for ($d = (Resolve-Path -LiteralPath $parent).Path; $d; $d = Split-Path -Parent $d) {
        $hit = @('CLAUDE.md', '.claude\CLAUDE.md', 'CLAUDE.local.md') | Where-Object { Test-Path -LiteralPath (Join-Path $d $_) -PathType Leaf }
        if ($hit) {
            Write-Host "INCONCLUSIVE - $($hit -join ', ') exists in $d, above the fixture; it would shadow AGENTS.md. Use another -FixtureParent."
            Write-Canary 'n/a' 'n/a' 0 $expectedText 'INCONCLUSIVE' $version
            exit 2
        }
    }

    $sentA = New-Codeword; $sentR = New-Codeword
    $root = Join-Path $parent ('layoutcanary-layout-' + [IO.Path]::GetRandomFileName())
    $code = 2
    try {
        function Add-FixtureFile([string]$Rel, [string]$Text) {
            $p = Join-Path $root $Rel
            New-Item -ItemType Directory -Path (Split-Path -Parent $p) -Force | Out-Null
            Set-Content -LiteralPath $p -Value $Text -Encoding utf8NoBOM
        }
        $rulesRel = '.github/instructions/framework-rules.instructions.md'
        $agents = "# Canary project`n`nThe project codeword is $sentA.`n"
        $rulesText = "# Framework rules`n`nThe framework rules codeword is $sentR.`n"
        if ($Layout -eq 'agents-import') { $agents += "`n@$rulesRel`n" }
        Add-FixtureFile 'AGENTS.md' $agents
        if ($Layout -in 'agents-import', 'shadowed-rules-import') { Add-FixtureFile $rulesRel $rulesText }
        if ($Layout -in 'rules-folder', 'shadowed-rules-folder') { Add-FixtureFile '.claude/rules/framework-rules.md' $rulesText }
        if ($Layout -eq 'shadowed-rules-import') { Add-FixtureFile '.claude/rules/framework.md' "@../../AGENTS.md`n@../../$rulesRel`n" }
        if ($Layout -like 'shadowed*') { Add-FixtureFile 'CLAUDE.local.md' "Local notes for this checkout only.`n" }

        Write-Host "Layout: $Layout$(if ($Bare) { ' (-Bare)' })"
        Write-Host 'Fixture files:'
        Get-ChildItem -LiteralPath $root -Recurse -File -Force | ForEach-Object { Write-Host ('  ' + $_.FullName.Substring($root.Length + 1).Replace('\', '/')) }

        $prompt = @"
List every project codeword you can see in your context from project instructions, one per line.
Use ONLY what is already in your context. Do NOT read, search, glob, or grep any file.
If you see none, answer exactly: NONE
"@
        $claudeArgs = @('-p', $prompt, '--model', $Model, '--output-format', 'stream-json', '--verbose',
                        '--dangerously-skip-permissions', '--no-session-persistence', '--max-budget-usd', '0.30')
        if ($Bare) { $claudeArgs += '--bare' }
        $job = Start-Job -ScriptBlock {
            param($cmd, $a, $wd)
            Set-Location $wd
            $env:CLAUDECODE = $null   # a nested session must not inherit the parent's marker
            & $cmd @a 2>&1 | ForEach-Object { [string]$_ }
        } -ArgumentList $tool, $claudeArgs, $root
        $done = Wait-Job $job -Timeout $TimeoutSeconds
        $out = if ($done) { @(Receive-Job $job) } else { @() }
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        if (-not $done) {
            Write-Host "INCONCLUSIVE - the CLI did not finish within $TimeoutSeconds s; nothing was examined."
            Write-Canary 'n/a' 'n/a' 0 $expectedText 'INCONCLUSIVE' $version
            $code = 2
        } else {
            if ($TranscriptPath) { $out | Set-Content -LiteralPath $TranscriptPath -Encoding utf8NoBOM }
            $answer = New-Object Text.StringBuilder
            $reads = 0; $isError = $false; $parsed = 0
            foreach ($line in $out) {
                $e = $null; try { $e = $line | ConvertFrom-Json -ErrorAction Stop } catch { continue }
                if ($e -isnot [pscustomobject]) { continue }
                $parsed++
                if ($e.type -eq 'assistant') {
                    foreach ($c in @($e.message.content)) {
                        if ($c.type -eq 'tool_use') { $reads++ } elseif ($c.type -eq 'text') { [void]$answer.AppendLine([string]$c.text) }
                    }
                } elseif ($e.type -eq 'result') {
                    if ($e.is_error) { $isError = $true }
                    if ($e.result -and $answer.Length -eq 0) { [void]$answer.AppendLine([string]$e.result) }
                }
            }
            $text = $answer.ToString()
            $aSeen = $text -match [regex]::Escape($sentA)
            $rSeen = $text -match [regex]::Escape($sentR)
            $aWord = if ($aSeen) { 'IN' } else { 'OUT' }
            $rWord = if (-not $hasR) { 'n/a' } elseif ($rSeen) { 'IN' } else { 'OUT' }
            Write-Host "Answer: $(($text -replace '\s+', ' ').Trim())"
            if ($reads -gt 0 -or $isError -or $parsed -eq 0 -or [string]::IsNullOrWhiteSpace($text)) {
                $why = if ($reads -gt 0) { "$reads file-access tool call(s) in the transcript" } elseif ($isError) { 'the tool reported an error' } else { 'no answer in the transcript' }
                Write-Host "INCONCLUSIVE - $why."
                Write-Canary $aWord $rWord $reads $expectedText 'INCONCLUSIVE' $version
                $code = 2
            } else {
                $verdict = 'OBSERVED'
                if ($expect) {
                    $match = ($aWord -eq $expect[0]) -and (-not $hasR -or $rWord -eq $expect[1])
                    $verdict = if ($match) { 'AS-EXPECTED' } else { 'UNEXPECTED' }
                }
                Write-Canary $aWord $rWord 0 $expectedText $verdict $version
                $code = if ($verdict -eq 'UNEXPECTED') { 1 } else { 0 }
            }
        }
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
    exit $code
}
if ($Bare) { Write-Host '-Bare needs -Layout.'; exit 2 }

$sentinel = 'ZORBLAX-7Q4M'
$root = Join-Path ([IO.Path]::GetTempPath()) ("b97-canary1-" + [IO.Path]::GetRandomFileName())
$importDir = Split-Path -Parent (Join-Path $root $ImportTarget)
New-Item -ItemType Directory -Path $importDir -Force | Out-Null

# The sentinel appears ONLY here.
@"
# Framework rules (imported)

The project codeword is $sentinel. It designates the imported-rules delivery path.
"@ | Set-Content -Path (Join-Path $root $ImportTarget) -Encoding utf8NoBOM

# Root CLAUDE.md carries the import (treatment) or no import at all (negative control) and NOT the
# sentinel either way.
$importLine = if ($OmitImport) { '(negative control: no import line)' } else { "@$ImportTarget" }
@"
# Canary project

This file is the project instruction file.

$importLine

End of instructions.
"@ | Set-Content -Path (Join-Path $root 'CLAUDE.md') -Encoding utf8NoBOM

Write-Host "Fixture: $root"
Write-Host ("Mode: " + $(if ($OmitImport) { 'NEGATIVE CONTROL (no import line)' } else { "TREATMENT (@$ImportTarget)" }))
Write-Host "Sentinel '$sentinel' present only in $ImportTarget"
Write-Host "Control: sentinel occurrences in CLAUDE.md = $((Select-String -Path (Join-Path $root 'CLAUDE.md') -Pattern $sentinel -AllMatches).Count)"

$prompt = @"
What is the project codeword? Answer with the codeword only.
Use ONLY what is already in your context from project instructions.
Do NOT read, search, glob, or grep any file. If it is not already in your context, reply exactly: NOT-IN-CONTEXT
"@

$transcript = Join-Path $root 'transcript.jsonl'
$claudeArgs = @('-p', $prompt, '--model', $Model, '--output-format', 'stream-json', '--verbose',
                '--dangerously-skip-permissions', '--no-session-persistence', '--max-budget-usd', '0.30')

# A job bounds the call; a hung CLI is "could not examine", never a verdict on the treatment.
$job = Start-Job -ScriptBlock {
    param($a, $wd, $cmd)
    Set-Location $wd
    & $cmd @a 2>&1 | ForEach-Object { [string]$_ }
} -ArgumentList $claudeArgs, $root, $(if ($ClaudeCmd) { $ClaudeCmd } else { 'claude' })
$done = Wait-Job $job -Timeout $TimeoutSeconds
$out = if ($done) { @(Receive-Job $job) } else { @() }
Remove-Job $job -Force -ErrorAction SilentlyContinue
if (-not $done) {
    Write-Host "VERDICT: INCONCLUSIVE - the CLI did not finish within $TimeoutSeconds s; nothing was examined."
    Write-Host "Fixture kept for inspection: $root"
    exit 2
}
$out | Set-Content -Path $transcript -Encoding utf8NoBOM

$raw = ($out | Out-String)

$sawSentinel = $raw -match [regex]::Escape($sentinel)
$sawNotInCtx = $raw -match 'NOT-IN-CONTEXT'
# Any file-access tool invalidates a positive: the model may have found the sentinel by reading.
$sawFileRead = $raw -match '"name"\s*:\s*"(Read|Glob|Grep|Bash|PowerShell|NotebookRead)"'

Write-Host ''
Write-Host '=== RESULT ==='
Write-Host "  sentinel echoed : $sawSentinel"
Write-Host "  NOT-IN-CONTEXT  : $sawNotInCtx"
Write-Host "  file tool used  : $sawFileRead"
Write-Host ''
if ($OmitImport) {
    if ($sawSentinel) {
        Write-Host 'CONTROL INVALID - the sentinel reached the model WITHOUT an import line: the target is loaded by another route, so a treatment positive is not attributable to @import.'
        $code = 1
    } elseif ($sawNotInCtx) {
        Write-Host 'CONTROL VALID - without the import line the sentinel is NOT-IN-CONTEXT; a treatment positive is attributable to @import.'
        $code = 0
    } else {
        Write-Host 'CONTROL INCONCLUSIVE - neither the sentinel nor the refusal token appeared.'
        $code = 2
    }
} elseif ($sawFileRead -and $sawSentinel) {
    Write-Host 'VERDICT: INCONCLUSIVE - model reached the sentinel via a file tool; import not proven.'
    $code = 2
} elseif ($sawSentinel) {
    Write-Host 'VERDICT: POSITIVE - root CLAUDE.md @import RESOLVED into context. Option A viable.'
    $code = 0
} elseif ($sawNotInCtx) {
    Write-Host 'VERDICT: NEGATIVE - import did NOT resolve from a root CLAUDE.md. Option A collapses.'
    $code = 1
} else {
    Write-Host 'VERDICT: INCONCLUSIVE - neither sentinel nor the refusal token appeared.'
    $code = 2
}
Write-Host "Transcript: $transcript"
Write-Host "Fixture kept for inspection: $root"
exit $code
