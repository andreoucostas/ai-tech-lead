# Asserts code-span parity in the AUTHORING repo's three stock Common Tasks inventories. Does NOT ship.
#
# This must never be promoted into template-checks: our stock CLAUDE.md and AGENTS.md files are
# hand-authored in lockstep, but a consumer's AGENTS.md is model-regenerated and is deliberately
# allowed to condense descriptions. Enforcing description parity from the consumer vantage point
# would reject a consumer for following /generate-copilot's contract.
#
# This deliberately compares only backtick-quoted code spans for slugs present on both sides. It
# does not catch plain-prose technology drift such as Jasmine/Karma, or NUnit vs xUnit around an
# identical code span. Covering those needs the curated vocabulary this design rejects.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

function Get-CommonTaskCodeSpans {
    param([string]$Path)
    # Normalize the same byte-level hazards handled by the shipped twins before parsing.
    $text = [IO.File]::ReadAllText($Path) -replace "`r`n", "`n"
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
    $inSection = $false
    $tasks = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    foreach ($line in ($text -split "`n")) {
        if ($line -eq '## Common Tasks') { $inSection = $true; continue }
        if ($inSection -and $line -match '^## ') { break }
        if (-not $inSection) { continue }
        if ($line -match '^- `(?<slug>[a-z0-9][a-z0-9-]*)` (?:—|-) (?<description>.*)$') {
            $spans = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
            foreach ($match in [regex]::Matches($Matches.description, '`([^`]+)`')) {
                $null = $spans.Add($match.Groups[1].Value)
            }
            $tasks[$Matches.slug] = $spans
        }
    }
    return $tasks
}

Reset-Tests

It 'stock Common Tasks descriptions keep code spans aligned per shared slug' {
    $drift = @()
    foreach ($dist in 'dotnet','angular','monorepo') {
        $claude = Get-CommonTaskCodeSpans (Join-Path $repoRoot "dist/$dist/CLAUDE.md")
        $agents = Get-CommonTaskCodeSpans (Join-Path $repoRoot "dist/$dist/AGENTS.md")
        Assert (@($claude.Keys).Count -gt 0) "$dist/CLAUDE.md yielded zero Common Tasks slugs; the parser is blind"
        Assert (@($agents.Keys).Count -gt 0) "$dist/AGENTS.md yielded zero Common Tasks slugs; the parser is blind"
        $shared = 0
        foreach ($slug in $claude.Keys) {
            if (-not $agents.ContainsKey($slug)) { continue }
            $shared++
            $claudeOnly = @($claude[$slug] | Where-Object { -not $agents[$slug].Contains($_) })
            $agentsOnly = @($agents[$slug] | Where-Object { -not $claude[$slug].Contains($_) })
            if ($claudeOnly.Count -gt 0 -or $agentsOnly.Count -gt 0) {
                $drift += "$dist/$slug (CLAUDE-only: $($claudeOnly -join ', '); AGENTS-only: $($agentsOnly -join ', '))"
            }
        }
        Assert ($shared -gt 0) "$dist Common Tasks inventories share zero slugs; no descriptions were compared"
    }
    Assert ($drift.Count -eq 0) ("Common Tasks code-span drift: " + ($drift -join '; '))
}

exit (Write-TestSummary 'SkillListParity.Tests (stock authoring mirrors only)')
