[CmdletBinding()]
param([ValidateSet('', 'absolute', 'regulatory', 'backstop')][string]$RedTest = '')

# Curated live claims only. This is intentionally not a prose linter: history, changelogs, plans,
# meta evidence, and generated dists are excluded because they may accurately quote retired claims.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$activePaths = @(
    'README.md', 'CLAUDE.md', 'AGENTS.md',
    'install.ps1',
    'src/core/docs/enforcement-surfaces.md',
    'src/core/docs/presentation/TALKING-POINTS.md',
    'src/core/docs/presentation/framework-briefing.html',
    'src/core/docs/presentation/framework-technical.html',
    'src/core/docs/presentation/framework-system-map.html',
    'src/core/.claude/hooks/audit-trail.ps1',
    'src/core/scripts/framework-doctor.ps1',
    'src/core/scripts/install.ps1',
    'src/core/.github/instructions/framework-rules.instructions.md',
    'src/stacks/dotnet/files/README.md', 'src/stacks/angular/files/README.md', 'src/stacks/monorepo/files/README.md',
    'src/stacks/dotnet/files/AGENTS.md', 'src/stacks/angular/files/AGENTS.md', 'src/stacks/monorepo/files/AGENTS.md',
    'src/stacks/dotnet/snippets/CLAUDE.md/enforce-skills', 'src/stacks/angular/snippets/CLAUDE.md/enforce-skills', 'src/stacks/monorepo/snippets/CLAUDE.md/enforce-skills',
    'src/stacks/dotnet/snippets/.github/instructions/framework-rules.instructions.md/solid-backstop',
    'src/stacks/angular/snippets/.github/instructions/framework-rules.instructions.md/solid-backstop',
    'src/stacks/monorepo/snippets/.github/instructions/framework-rules.instructions.md/solid-backstop',
    'src/stacks/dotnet/files/docs/ARCHITECTURE.md', 'src/stacks/angular/files/docs/ARCHITECTURE.md', 'src/stacks/monorepo/files/docs/ARCHITECTURE.md',
    'src/stacks/dotnet/files/docs/architecture.html', 'src/stacks/angular/files/docs/architecture.html', 'src/stacks/monorepo/files/docs/architecture.html',
    'src/stacks/dotnet/files/docs/REVIEW-GUIDE.md', 'src/stacks/angular/files/docs/REVIEW-GUIDE.md', 'src/stacks/monorepo/files/docs/REVIEW-GUIDE.md',
    'src/stacks/dotnet/files/scripts/metrics.ps1',
    'src/stacks/angular/files/scripts/metrics.ps1',
    'src/stacks/monorepo/files/scripts/metrics.ps1'
)
$rules = @(
    [pscustomobject]@{ Name = 'absolute write guarantee'; Pattern = '(?i)literally cannot(?:\s+write)?|hard-blocks\s+any\s+write|every\s+AI-assisted(?:\s+file)?\s+(?:change|write)|audit[- ]trail.{0,120}\bappends?\s+AI\s+file[- ]changes' },
    [pscustomobject]@{ Name = 'regulatory audit assurance'; Pattern = '(?i)satisfies\s+SR\s*11-7|SR\s*11-7\s*/\s*DORA|DORA\s+audit[- ]?(?:trail|log|line)' },
    [pscustomobject]@{ Name = 'unwired architecture enforcement'; Pattern = '(?is)(?:(?:NetArchTest|dependency-cruiser).{0,120}\b(?:is|are)\s+enforced\s+in\s+CI\b|dependency\s+\*?direction\*?\s+is\s+enforced\s+in\s+CI\b|deterministic\s+(?:dependency-direction\s+|DIP\s+)?backstop\s+is.{0,100}\bin\s+CI\b)' }
)

function Get-ClaimViolations([string]$Text) {
    @($rules | Where-Object { $Text -match $_.Pattern } | ForEach-Object Name)
}

function Remove-HistoricalMarkdownSections([string]$Text, [string]$Extension) {
    if ($Extension -ne '.md') { return $Text }
    $lines = $Text -split "`n"
    $inFence = $false
    $historicalLevel = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].TrimEnd("`r")
        if ($line.TrimStart() -match '^(?:```|~~~)') { $inFence = -not $inFence; continue }
        if (-not $inFence -and $line -match '^(#{2,6})\s+\[?v?[0-9]+\.[0-9]+\.[0-9]+') {
            $historicalLevel = $Matches[1].Length; $lines[$i] = ''; continue
        }
        if (-not $inFence -and $historicalLevel -gt 0 -and $line -match '^(#{1,6})\s+' -and $Matches[1].Length -le $historicalLevel) {
            $historicalLevel = 0
        }
        if ($historicalLevel -gt 0) { $lines[$i] = '' }
    }
    return ($lines -join "`n")
}

function Get-ActiveClaimOffenders([string]$InjectedPath = '', [string]$InjectedText = '') {
    foreach ($path in $activePaths) {
        $fullPath = Join-Path $repo $path
        $text = Remove-HistoricalMarkdownSections ([IO.File]::ReadAllText($fullPath, [Text.Encoding]::UTF8)) ([IO.Path]::GetExtension($fullPath))
        if ($path -eq $InjectedPath) { $text += "`n$InjectedText" }
        foreach ($hit in (Get-ClaimViolations $text)) { "${path}: $hit" }
    }
}

Reset-Tests
It 'claim gate has a non-empty curated active surface and high-risk rule set' {
    Assert ($activePaths.Count -ge 20) 'active claim allowlist became too small or empty'
    Assert ($rules.Count -eq 3) 'high-risk rule families changed; update their red fixtures deliberately'
    foreach ($path in $activePaths) { Assert (Test-Path (Join-Path $repo $path)) "active claim carrier is missing: $path" }
}

It 'each deny family catches its synthetic bad claim and preserves qualified canonical wording' {
    $bad = @(
        'The AI literally cannot write secrets.', 'The guard hard-blocks any write.', 'Every AI-assisted file change is appended.',
        'The audit-trail appends AI file-changes.',
        'This satisfies SR 11-7.', 'An SR 11-7 / DORA audit line is appended.',
        'NetArchTest is enforced in CI.', 'Dependency direction is enforced in CI by dependency-cruiser.',
        'The deterministic backstop is NetArchTest in CI.', 'Dependency *direction* is enforced in CI by architecture tests (NetArchTest).'
    )
    foreach ($sample in $bad) { Assert ((Get-ClaimViolations $sample).Count -eq 1) "synthetic bad fixture was not caught exactly once: $sample" }
    $qualified = 'The editor/file-write guard is hook-dependent; shell writes are blind spots. NetArchTest is scaffoldable and enforces only after the consumer wires it into CI.'
    Assert ((Get-ClaimViolations $qualified).Count -eq 0) 'qualified scope wording was falsely rejected'
}

if ($RedTest) {
    $sample = switch ($RedTest) {
        'absolute' { 'The audit-trail appends AI file-changes as a Guaranteed side-effect.' }
        'regulatory' { 'The audit log satisfies SR 11-7.' }
        'backstop' { 'dependency-cruiser is enforced in CI.' }
    }
    It "red fixture $RedTest is rejected through active-carrier traversal" {
        $offenders = @(Get-ActiveClaimOffenders -InjectedPath 'src/core/docs/enforcement-surfaces.md' -InjectedText $sample)
        Assert ($offenders.Count -eq 0) "red fixture '$RedTest' was correctly rejected through $($offenders -join '; ')"
    }
} else {
    It 'curated active authored claim carriers contain no high-risk false assurance' {
        $offenders = @(Get-ActiveClaimOffenders)
        Assert (@($offenders).Count -eq 0) ("high-risk active claim(s): " + ($offenders -join '; '))
    }
}

exit (Write-TestSummary 'ClaimTruth.Tests')
