# Security-review minimisation contract. Synthetic sentinels are deliberately segmented and fake.
if (-not (Get-Command Reset-Tests -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$register = [IO.File]::ReadAllText((Join-Path $root 'SECURITY_FINDINGS.md'))
$command = [IO.File]::ReadAllText((Join-Path $root '.claude\commands\security-review.md'))
$auditor = [IO.File]::ReadAllText((Join-Path $root '.claude\agents\security-auditor.md'))
$copilotAgent = [IO.File]::ReadAllText((Join-Path $root '.github\agents\security-auditor.agent.md'))
$copilotPrompt = [IO.File]::ReadAllText((Join-Path $root '.github\prompts\security-review.prompt.md'))
$isAngular = $command -match 'It does not append findings'

function Find-UnsafeHistoricalSentinel([string]$Markdown) {
    return $Markdown -match 'SENTINEL[_-](FAKE[_-])?(ACCOUNT|HOST|HOME|SECRET|TRANSCRIPT|DERIVATIVE)'
}

Reset-Tests

It 'register minimises active, accepted-risk, resolved, and archived history' {
    foreach ($required in @(
        'Affected area (redacted when sensitive)', 'Repository-safe summary',
        'Owner role/team (optional)', 'Internal reference (optional)',
        'Accepted risks', 'same minimisation rules as the active table',
        'Resolved findings', 'docs/security-archive.md', 'never ingest and restate legacy rows automatically'
    )) { Assert ($register.Contains($required)) "register missing: $required" }
    Assert ($register -notmatch '\| File:line \| Description \|') 'legacy findings header remains'
}

It 'historical-table sentinel grader is proven red then green with benign near-matches' {
    $unsafe = $register + "`n| X | High | SENTINEL_FAKE_ACCOUNT | SENTINEL_FAKE_TRANSCRIPT |`n"
    Assert (Find-UnsafeHistoricalSentinel $unsafe) 'planted unsafe historical row did not redden grader'
    $benign = $register + "`n| X | High | src/security/CertificateLoader.cs | Replace expired certificate; checksum verified |`n"
    Assert (-not (Find-UnsafeHistoricalSentinel $benign)) 'benign repository location/checksum was over-redacted'
}

It 'Claude auditor withholds secret material, masked fragments, and secret-derived fingerprints' {
    foreach ($required in @('partial or masked secret fragments', 'secret-derived fingerprints',
        'does not suppress certificate or package checksums', 'Restricted human handling required')) {
        Assert ($auditor.Contains($required)) "auditor missing: $required"
    }
}

It 'Copilot agent and prompt carry their own compact no-echo rule' {
    foreach ($required in @('partial or masked', 'secret-derived fingerprints', 'certificate or package')) {
        Assert ($copilotAgent.Contains($required)) "Copilot agent missing: $required"
    }
    Assert ($copilotPrompt -match 'do not echo protected incident detail') 'Copilot prompt no-echo rule missing'
    Assert ($copilotPrompt -match 'restricted human handling') 'Copilot prompt restricted-handling response missing'
}

It 'credential response and legacy-register paths are non-durable and fail closed' {
    foreach ($required in @('do not echo protected incident detail', 'minimum immediate action class',
        'do not modify the register', 'human with incident authority', 'Never ingest or restate legacy')) {
        Assert ($command.Contains($required)) "command missing: $required"
    }
    Assert ($command -match 'make no automatic Git mutation|Do not append findings') 'credential no-mutation rule missing'
}

if ($isAngular) {
    It 'Angular retains no-append behavior and corrects the former append claim' {
        Assert ($command -match 'It does not append findings') 'Angular description does not state no append'
        Assert ($command -notmatch 'For every ordinary repository-safe finding rated') 'Angular gained an append step'
    }
} else {
    It 'appending stacks retain ordinary safe locations and append only minimised findings' {
        Assert ($command -match 'ordinary repository-safe finding rated `critical` or `high`') 'safe append rule missing'
        Assert ($command -match 'repository-relative `file:line`') 'ordinary safe locator exception missing'
        Assert ($command -match 'Never paste auditor/chat/tool output') 'raw-output paste prohibition missing'
    }
}

exit (Write-TestSummary 'SecurityReviewContract.Tests')
