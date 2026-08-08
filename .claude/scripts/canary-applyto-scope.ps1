#requires -Version 7.0
<#
  B-97 canary 3 — does a NARROW `applyTo` still deliver on a prompt that names no file?

  Canary 2 proved .github/instructions/ reaches Copilot using `applyTo: "**"`. The shipped design
  needs to know whether that breadth is load-bearing, because framework rules must arrive on every
  task, not only when the model happens to open a matching file.

  Arms (each a fresh repo, each a distinct sentinel, identical prompt naming no file):
    star   — applyTo: "**"        (positive control; canary 2 already showed this delivers)
    narrow — applyTo: "**/*.cs"   (a real .cs file exists, but the prompt names nothing)
    none   — no frontmatter at all (what is the default?)

  Reading:
    star hit, narrow miss  -> breadth is load-bearing; framework rules need "**"
    star hit, narrow hit   -> applyTo does not gate a fileless prompt; narrower is safe
    star miss              -> INVALID run, do not interpret the others
#>
[CmdletBinding()]
param(
    [string]$CopilotCmd = '',
    [string]$NodeDir    = 'C:\Program Files\nodejs',
    [int]$TimeoutSeconds = 180,
    [switch]$ResolveOnly
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($CopilotCmd)) {
    if ([string]::IsNullOrWhiteSpace($env:APPDATA)) { throw 'Copilot CLI not found; pass -CopilotCmd.' }
    $CopilotCmd = Join-Path $env:APPDATA 'npm\copilot.cmd'
}
if (-not (Test-Path -LiteralPath $CopilotCmd -PathType Leaf)) { throw 'Copilot CLI not found; pass -CopilotCmd.' }
$CopilotCmd = (Resolve-Path -LiteralPath $CopilotCmd).Path
if ($ResolveOnly) { Write-Output $CopilotCmd; exit 0 }
$env:PATH = "$NodeDir;" + (Split-Path $CopilotCmd) + ";$env:PATH"

$prompt = 'What is the project codeword? Reply with the codeword only. Use ONLY what is already in ' +
          'your context from repository instruction files. Do NOT read, search, or list any file. ' +
          'If it is not already in your context, reply exactly: NOT-IN-CONTEXT'

$base = Join-Path ([IO.Path]::GetTempPath()) ('b97-canary3-' + [IO.Path]::GetRandomFileName())

$arms = @(
    @{ Name = 'star';   Sentinel = 'VANTORIX-5H1D'; ApplyTo = '"**"' }
    @{ Name = 'narrow'; Sentinel = 'PELGRAMO-8W2F'; ApplyTo = '"**/*.cs"' }
    @{ Name = 'none';   Sentinel = 'KRESSIDA-4B7N'; ApplyTo = $null }
)

$results = foreach ($a in $arms) {
    $dir = Join-Path $base $a.Name
    New-Item -ItemType Directory -Path (Join-Path $dir '.github/instructions') -Force | Out-Null

    # A real .cs file, so a **/*.cs glob has something to match in the workspace.
    Set-Content -Path (Join-Path $dir 'Program.cs') -Value 'public class Program { }' -Encoding utf8NoBOM

    $front = if ($a.ApplyTo) { "---`napplyTo: $($a.ApplyTo)`n---`n" } else { '' }
    Set-Content -Path (Join-Path $dir '.github/instructions/framework-rules.instructions.md') `
                -Value "$front# Framework rules`n`nThe project codeword is $($a.Sentinel).`n" -Encoding utf8NoBOM

    Push-Location $dir
    try {
        & git init --quiet 2>&1 | Out-Null
        $job = Start-Job -ScriptBlock {
            param($cmd, $p, $wd) Set-Location $wd; & $cmd -p $p --no-color 2>&1 | Out-String
        } -ArgumentList $CopilotCmd, $prompt, $dir
        $done = Wait-Job $job -Timeout $TimeoutSeconds
        $out  = if ($done) { [string](Receive-Job $job) } else { '<TIMEOUT>' }
        Remove-Job $job -Force -ErrorAction SilentlyContinue
    } finally { Pop-Location }

    Set-Content -Path (Join-Path $base "$($a.Name).txt") -Value $out -Encoding utf8NoBOM
    [pscustomobject]@{
        Arm      = $a.Name
        ApplyTo  = if ($a.ApplyTo) { $a.ApplyTo } else { '(none)' }
        Hit      = $out -match [regex]::Escape($a.Sentinel)
        NotInCtx = $out -match 'NOT-IN-CONTEXT'
    }
}

$results | Format-Table -AutoSize | Out-String | Write-Host

$star   = ($results | Where-Object Arm -eq 'star').Hit
$narrow = ($results | Where-Object Arm -eq 'narrow').Hit
$none   = ($results | Where-Object Arm -eq 'none').Hit

Write-Host '=== VERDICT ==='
if (-not $star) {
    Write-Host 'INVALID — the "**" control did not deliver; do not interpret the other arms.'; $code = 3
} elseif (-not $narrow) {
    Write-Host 'BREADTH IS LOAD-BEARING — a narrow applyTo does NOT deliver on a fileless prompt.'
    Write-Host '  Framework rules must ship with a broad applyTo. B-17''s narrow test-rule scoping is'
    Write-Host '  unaffected (different file, and gating on test files is what it wants).'
    $code = 0
} else {
    Write-Host 'applyTo DOES NOT GATE a fileless prompt — narrow scoping still delivers.'
    Write-Host '  Re-examine whether applyTo scoping does anything useful for delivery at all.'
    $code = 1
}
Write-Host "  no-frontmatter arm delivered: $none"
Write-Host "  outputs: $base"
exit $code
