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
    [string]$Model = 'haiku',
    [int]$TimeoutSeconds = 180
)
$ErrorActionPreference = 'Stop'

$sentinel = 'ZORBLAX-7Q4M'
$root = Join-Path ([IO.Path]::GetTempPath()) ("b97-canary1-" + [IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path (Join-Path $root '.claude') -Force | Out-Null

# The sentinel appears ONLY here.
@"
# Framework rules (imported)

The project codeword is $sentinel. It designates the imported-rules delivery path.
"@ | Set-Content -Path (Join-Path $root '.claude/framework-rules.md') -Encoding utf8NoBOM

# Root CLAUDE.md carries the import and NOT the sentinel.
@'
# Canary project

This file is the project instruction file.

@.claude/framework-rules.md

End of instructions.
'@ | Set-Content -Path (Join-Path $root 'CLAUDE.md') -Encoding utf8NoBOM

Write-Host "Fixture: $root"
Write-Host "Sentinel '$sentinel' present only in .claude/framework-rules.md"
Write-Host "Control: sentinel occurrences in CLAUDE.md = $((Select-String -Path (Join-Path $root 'CLAUDE.md') -Pattern $sentinel -AllMatches).Count)"

$prompt = @"
What is the project codeword? Answer with the codeword only.
Use ONLY what is already in your context from project instructions.
Do NOT read, search, glob, or grep any file. If it is not already in your context, reply exactly: NOT-IN-CONTEXT
"@

$transcript = Join-Path $root 'transcript.jsonl'
$args = @('-p', $prompt, '--model', $Model, '--output-format', 'stream-json', '--verbose',
          '--dangerously-skip-permissions', '--no-session-persistence', '--max-budget-usd', '0.30')

Push-Location $root
try {
    $out = & claude @args 2>&1
    $out | Set-Content -Path $transcript -Encoding utf8NoBOM
} finally { Pop-Location }

$raw = ($out | Out-String)

$sawSentinel = $raw -match [regex]::Escape($sentinel)
$sawNotInCtx = $raw -match 'NOT-IN-CONTEXT'
# Any file-access tool invalidates a positive: the model may have found the sentinel by reading.
$sawFileRead = $raw -match '"name"\s*:\s*"(Read|Glob|Grep|Bash|NotebookRead)"'

Write-Host ''
Write-Host '=== RESULT ==='
Write-Host "  sentinel echoed : $sawSentinel"
Write-Host "  NOT-IN-CONTEXT  : $sawNotInCtx"
Write-Host "  file tool used  : $sawFileRead"
Write-Host ''
if ($sawFileRead -and $sawSentinel) {
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
