# Additive-safety canary for the composed dist/monorepo route-prompt twins (LEARNINGS
# 2026-07-10): the monorepo sensitive-keyword overlay must be the UNION of both stacks'
# regexes. The regression this pins: expressing the union as two sequential ASSIGNMENTS in
# the .ps1 makes the second overwrite the first, silently disabling dotnet-only keywords
# while the .sh twin (two ifs, each setting sensitive=1) stays green — caught in Phase 4
# only by a one-off per-marker audit; fixed with an authored `-or` monorepo snippet. Keywords
# chosen to be genuinely one-sided (verified 2026-07-11: dist/dotnet does NOT flag
# 'bypasssecuritytrust', dist/angular does NOT flag 'ledger'). Tests the COMPOSED dist copy
# (what ships), meta-side because dist tests are shipped content and frozen until v0.26.0 —
# promote into the dist suites at/after the release (B-33). Does NOT ship.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$rpPs = Join-Path $repoRoot 'dist/monorepo/.claude/hooks/route-prompt.ps1'
$rpSh = Join-Path $repoRoot 'dist/monorepo/.claude/hooks/route-prompt.sh'

function New-ClaudePrompt { param($Prompt) (@{ hook_event_name = 'UserPromptSubmit'; prompt = $Prompt } | ConvertTo-Json -Compress) }

# One-sided by construction: 'ledger'/'reconcil' appear only in the dotnet sensitive regex,
# 'bypasssecuritytrust'/'xss' only in the angular one (see src/stacks/*/snippets/.claude/
# hooks/route-prompt.*/sensitive-*). Both carry a routed intent so the rails render at all.
$dotnetOnly  = New-ClaudePrompt 'implement ledger reconciliation for transfers'
$angularOnly = New-ClaudePrompt 'fix the bypasssecuritytrust usage flagged for xss'
$neutral     = New-ClaudePrompt 'refactor the date formatting helper names'
$Marker      = 'Security-sensitive'

Reset-Tests

It 'monorepo route-prompt.ps1 flags a dotnet-only keyword (union, first regex)' {
    $r = Invoke-Hook $rpPs $dotnetOnly
    Assert ($r.Exit -eq 0) "exit $($r.Exit)"
    Assert ($r.Out -match $Marker) 'dotnet-only keyword missed — union broken on the .ps1 (overwrite-assignment regression?)'
}
It 'monorepo route-prompt.ps1 flags an angular-only keyword (union, second regex)' {
    $r = Invoke-Hook $rpPs $angularOnly
    Assert ($r.Exit -eq 0) "exit $($r.Exit)"
    Assert ($r.Out -match $Marker) 'angular-only keyword missed — union broken on the .ps1'
}
It 'monorepo route-prompt.ps1 stays quiet on a non-sensitive prompt (negative control)' {
    $r = Invoke-Hook $rpPs $neutral
    Assert ($r.Exit -eq 0) "exit $($r.Exit)"
    Assert ($r.Out -notmatch $Marker) 'overlay fired on a neutral prompt — canary keywords are not the trigger'
}

if (Get-BashPath) {
    It 'monorepo route-prompt.sh flags a dotnet-only keyword (twin agreement)' {
        $r = Invoke-Hook $rpSh $dotnetOnly
        Assert ($r.Exit -eq 0) "exit $($r.Exit)"
        Assert ($r.Out -match $Marker) 'dotnet-only keyword missed by the .sh twin'
    }
    It 'monorepo route-prompt.sh flags an angular-only keyword (twin agreement)' {
        $r = Invoke-Hook $rpSh $angularOnly
        Assert ($r.Exit -eq 0) "exit $($r.Exit)"
        Assert ($r.Out -match $Marker) 'angular-only keyword missed by the .sh twin'
    }
    It 'monorepo route-prompt.sh stays quiet on a non-sensitive prompt (negative control)' {
        $r = Invoke-Hook $rpSh $neutral
        Assert ($r.Exit -eq 0) "exit $($r.Exit)"
        Assert ($r.Out -notmatch $Marker) 'overlay fired on a neutral prompt (.sh twin)'
    }
} else {
    Skip 'route-prompt.sh union tests' 'bash not found on this host'
}

exit (Write-TestSummary 'RoutePromptUnion.Tests (monorepo sensitive-union canary)')
