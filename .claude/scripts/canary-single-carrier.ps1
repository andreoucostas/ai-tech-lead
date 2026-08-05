#requires -Version 7.0
<#
  B-97 canary 5 — can ONE physical file serve both delivery legs?

  Canary 1 proved `@.claude/framework-rules.md` resolves from a root CLAUDE.md. Canaries 2-4 proved
  `.github/instructions/*.instructions.md` reaches Copilot CLI and VS Code agent mode. Both carriers
  are unprotected, so both deliver. But they are two files with the same content, and keeping two
  authored copies in src/ collides with meta-invariant #1 (single-source composition).

  If Claude Code resolves an @import that points AT the Copilot instructions file, there is exactly
  ONE carrier, no duplication, and no parity gate is needed at all.

  Arms (each a fresh repo, distinct sentinel, identical prompt):
    control — CLAUDE.md imports @.claude/framework-rules.md          (canary 1's known-positive)
    subject — CLAUDE.md imports @.github/instructions/framework-rules.instructions.md,
              WITH the `applyTo: "**"` YAML frontmatter the Copilot leg requires

  Reading:
    control hit, subject hit  -> single-carrier viable; collapse the two carriers into one
    control hit, subject miss -> keep two carriers; the import is path-sensitive or frontmatter breaks it
    control miss              -> INVALID run (the instrument is broken, not the design); do not read subject

  Model choice follows canary 1: this measures the HOST's context assembly, not model capability.
  A file-access tool in the transcript invalidates a positive -- the model may have simply read it.
#>
[CmdletBinding()]
param(
    [string]$Model = 'haiku',
    [int]$TimeoutSeconds = 180
)
$ErrorActionPreference = 'Stop'

$prompt = @"
What is the project codeword? Answer with the codeword only.
Use ONLY what is already in your context from project instructions.
Do NOT read, search, glob, or grep any file. If it is not already in your context, reply exactly: NOT-IN-CONTEXT
"@

$arms = @(
    @{ Name = 'control'; Sentinel = 'ZORBLAX-7Q4M'; Rel = '.claude/framework-rules.md'; Frontmatter = $false }
    @{ Name = 'subject'; Sentinel = 'QUILVANE-3T8P'; Rel = '.github/instructions/framework-rules.instructions.md'; Frontmatter = $true }
)

$results = @{}
foreach ($arm in $arms) {
    $root = Join-Path ([IO.Path]::GetTempPath()) ("b97-canary5-$($arm.Name)-" + [IO.Path]::GetRandomFileName())
    $target = Join-Path $root $arm.Rel
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null

    $head = if ($arm.Frontmatter) { "---`napplyTo: `"**`"`n---`n`n" } else { '' }
    ($head + "# Framework rules (imported)`n`nThe project codeword is $($arm.Sentinel). It designates the imported-rules delivery path.`n") |
        Set-Content -Path $target -Encoding utf8NoBOM

    # Root CLAUDE.md carries the import and NOT the sentinel.
    "# Canary project`n`nThis file is the project instruction file.`n`n@$($arm.Rel)`n`nEnd of instructions.`n" |
        Set-Content -Path (Join-Path $root 'CLAUDE.md') -Encoding utf8NoBOM

    $leak = (Select-String -Path (Join-Path $root 'CLAUDE.md') -Pattern $arm.Sentinel -AllMatches).Count
    Write-Host "[$($arm.Name)] fixture: $root  (sentinel occurrences in CLAUDE.md = $leak)"
    if ($leak -ne 0) { throw "Fixture leak: sentinel present in CLAUDE.md for arm $($arm.Name)." }

    $claudeArgs = @('-p', $prompt, '--model', $Model, '--output-format', 'stream-json', '--verbose',
                    '--dangerously-skip-permissions', '--no-session-persistence', '--max-budget-usd', '0.30')
    Push-Location $root
    try { $out = & 'C:\Users\Costas\.local\bin\claude.exe' @claudeArgs 2>&1 } finally { Pop-Location }
    $out | Set-Content -Path (Join-Path $root 'transcript.jsonl') -Encoding utf8NoBOM
    $raw = ($out | Out-String)

    $results[$arm.Name] = @{
        Sentinel = [bool]($raw -match [regex]::Escape($arm.Sentinel))
        NotInCtx = [bool]($raw -match 'NOT-IN-CONTEXT')
        FileTool = [bool]($raw -match '"name"\s*:\s*"(Read|Glob|Grep|Bash|NotebookRead)"')
        Root     = $root
    }
    Write-Host "[$($arm.Name)] sentinel=$($results[$arm.Name].Sentinel) notInCtx=$($results[$arm.Name].NotInCtx) fileTool=$($results[$arm.Name].FileTool)"
}

Write-Host ''
Write-Host '=== RESULT ==='
foreach ($k in 'control', 'subject') {
    $r = $results[$k]
    Write-Host ("  {0,-8} sentinel={1,-5} notInCtx={2,-5} fileTool={3,-5}  {4}" -f $k, $r.Sentinel, $r.NotInCtx, $r.FileTool, $r.Root)
}
Write-Host ''

$c = $results['control']; $s = $results['subject']
if ($c.FileTool -or -not $c.Sentinel) {
    Write-Host 'VERDICT: INVALID - the control arm did not reproduce canary 1. The instrument is broken; do not read the subject arm.'
    exit 2
} elseif ($s.FileTool -and $s.Sentinel) {
    Write-Host 'VERDICT: INCONCLUSIVE - subject reached the sentinel via a file tool; single-carrier not proven.'
    exit 2
} elseif ($s.Sentinel) {
    Write-Host 'VERDICT: POSITIVE - Claude Code resolves an @import into .github/instructions/. ONE carrier serves both legs.'
    exit 0
} elseif ($s.NotInCtx) {
    Write-Host 'VERDICT: NEGATIVE - the import did not resolve from .github/instructions/. Keep two carriers + a parity gate.'
    exit 1
} else {
    Write-Host 'VERDICT: INCONCLUSIVE - neither sentinel nor the refusal token appeared in the subject arm.'
    exit 2
}
