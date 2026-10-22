# Security-review minimisation contract. Synthetic sentinels are deliberately segmented and fake.
if (-not (Get-Command Reset-Tests -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$register = [IO.File]::ReadAllText((Join-Path $root 'SECURITY_FINDINGS.md'))
$command = [IO.File]::ReadAllText((Join-Path $root '.claude\commands\security-gate.md'))
$auditor = [IO.File]::ReadAllText((Join-Path $root '.claude\agents\security-auditor.md'))
$copilotAgent = [IO.File]::ReadAllText((Join-Path $root '.github\agents\security-auditor.agent.md'))
$copilotSkill = [IO.File]::ReadAllText((Join-Path $root '.agents\skills\security-gate\SKILL.md'))
# The commands wrap prose across lines; assert on the flattened text so a re-wrap cannot redden a case.
$flat = $command -replace '\s+', ' '
$flatAgent = $copilotAgent -replace '\s+', ' '

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

It 'Copilot agent and skill carry their own compact no-echo rule' {
    foreach ($required in @('partial or masked', 'secret-derived fingerprints', 'certificate or package')) {
        Assert ($copilotAgent.Contains($required)) "Copilot agent missing: $required"
    }
    Assert ($copilotSkill -match 'do not echo protected incident detail') 'Copilot skill no-echo rule missing'
    Assert ($copilotSkill -match 'restricted human handling') 'Copilot skill restricted-handling response missing'
}

It 'credential response and legacy-register paths are non-durable and fail closed' {
    foreach ($required in @('do not echo protected incident detail', 'minimum immediate action class',
        'do not modify the register', 'human with incident authority', 'Never ingest or restate legacy')) {
        Assert ($command.Contains($required)) "command missing: $required"
    }
    Assert ($command -match 'make no automatic Git mutation') 'credential no-mutation rule missing'
}

It 'every stack appends only minimised, ordinary repository-safe findings, and none says it does not append' {
    foreach ($surface in @(@('command', $command), @('Copilot skill', $copilotSkill), @('Copilot agent', $copilotAgent))) {
        Assert (($surface[1] -replace '\s+', ' ') -notmatch '(?i)\b(?:does|do) not append(?: any)? findings') "$($surface[0]) still says it does not append findings"
    }
    Assert ($flat -match 'Step 6 \S+ Update SECURITY_FINDINGS\.md') 'Step 6 (append to the register) missing'
    Assert ($flat -match 'ordinary repository-safe finding rated `critical` or `high`') 'safe append rule missing'
    Assert ($flat -match 'Never paste auditor/chat/tool output') 'raw-output paste prohibition missing'
}

It 'an ordinary finding gets its repository-relative file:line unless the path or summary would itself name a protected class' {
    Assert ($flat.Contains('the verdict table names the repository-relative `file:line`')) 'locator floor sentence missing'
    Assert (-not $flat.Contains('only when both the locator and target are safe')) 'opt-in locator sentence remains'
    Assert ($flat.Contains('Redact only when that path')) 'redact-only-when rule missing'
    Assert ($flat.Contains('`redacted (<class>)`')) 'redacted (<class>) marker missing'
    Assert ($flat.Contains('stayed in this chat with the person who ran the gate')) 'redacted-detail pointer missing'
}

It 'the register row names the path without a line, the symbol when ambiguous, and one defect-and-fix sentence' {
    foreach ($required in @('the repository-relative path with no line number',
        'the symbol, route or type when the path alone is ambiguous',
        'one sentence saying the defect class and the fix class')) {
        Assert ($flat.Contains($required)) "register row rule missing: $required"
    }
}

It 'row IDs are SF-<n>, one above the highest SF- in the register or its archive, so a resolved ID is never reused' {
    foreach ($required in @('Read `SECURITY_FINDINGS.md` before appending', '`ID` is `SF-<n>`',
        'one above the highest `SF-` number anywhere in that file or in `docs/security-archive.md`',
        'a resolved or archived row keeps its ID', '`SF-1` when neither holds one')) {
        Assert ($flat.Contains($required)) "ID rule missing: $required"
    }
    Assert (-not $flat.Contains('one above the highest `SF-` number in that table')) 'active-table-only ID rule remains'
}

It 'the verdict ends with a Recorded line naming the rows written or the one reason none was' {
    Assert ($flat -match 'Recorded: SF-\d+(?:, SF-\d+)* in SECURITY_FINDINGS\.md') 'Recorded: SF-n line example missing'
    Assert ($flat.Contains('`Recorded: none (<reason>)`')) 'Recorded: none (<reason>) form missing'
    foreach ($reason in @('`APPROVE`', '`severity below high`', '`credential finding`', '`duplicate of SF-<n>`', '`legacy schema`')) {
        Assert ($flat.Contains($reason)) "Recorded reason missing: $reason"
    }
    Assert ($flat.Contains('`; not recorded (<reason>)` per finding without one')) 'mixed-outcome Recorded form missing'
}

It 'the Copilot auditor tells the agent that only /security-gate writes the register, once' {
    Assert ($flatAgent.Contains('may be synthesised into')) 'Copilot agent findings-note missing'
    Assert ($flatAgent.Contains('by `/security-gate`, never by you')) 'Copilot agent findings-note drifted'
    $count = ([regex]::Matches($copilotAgent, 'never by you')).Count
    Assert ($count -eq 1) "Copilot agent findings-note appears $count times (expected exactly one)"
}

exit (Write-TestSummary 'SecurityReviewContract.Tests')
