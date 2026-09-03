param(
    [ValidateSet('', 'broken-contract', 'missing-claim', 'wrong-step-count',
        'unregistered-claim', 'vacuous-registry', 'vacuous-grammar')]
    [string]$RedTest = '',
    [string]$DistRoot = ''
)

# Guards exact shipped prose claims about command behavior. This is deliberately a literal
# registry, not an attempt to infer arbitrary prose semantics. Does not ship.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$utf8 = [Text.Encoding]::UTF8
$allDists = @('dotnet', 'angular', 'monorepo')

$contracts = @(
    [pscustomobject]@{ Claim = 'FRAMEWORK-CONTEXT.md'; Line = '"Detected Framework Packages" is also refreshed by `/docs-sync`'; Command = '.claude/commands/docs-sync.md'; Requires = 'Detected Framework Packages'; RequiresStepCount = $null; Dists = $allDists }
    [pscustomobject]@{ Claim = 'FRAMEWORK-CONTEXT.md'; Line = '"Known Hazard Areas" is re-confirmed by `/rebootstrap`'; Command = '.claude/commands/rebootstrap.md'; Requires = 'Known Hazard Areas'; RequiresStepCount = $null; Dists = $allDists }
    [pscustomobject]@{ Claim = 'README.md'; Line = '"Detected Framework Packages" is also refreshed by `/docs-sync`'; Command = '.claude/commands/docs-sync.md'; Requires = 'Detected Framework Packages'; RequiresStepCount = $null; Dists = $allDists }
    [pscustomobject]@{ Claim = 'README.md'; Line = '"Known Hazard Areas" by `/rebootstrap`'; Command = '.claude/commands/rebootstrap.md'; Requires = 'Known Hazard Areas'; RequiresStepCount = $null; Dists = $allDists }
    [pscustomobject]@{ Claim = '.claude/commands/rebootstrap.md'; Line = 'refresh conventions, hazards, and mined skills'; Command = '.claude/commands/rebootstrap.md'; Requires = 'Hazard'; RequiresStepCount = $null; Dists = $allDists }
    [pscustomobject]@{ Claim = '.github/prompts/docs-sync.prompt.md'; Line = 'all six steps'; Command = '.claude/commands/docs-sync.md'; Requires = $null; RequiresStepCount = 6; Dists = $allDists }
)

$completionHosts = @(
    [pscustomobject]@{ Label = 'Windows PowerShell 5.1'; Command = 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts/docs-sync-check.ps1' }
    [pscustomobject]@{ Label = 'PowerShell 7'; Command = 'pwsh -NoProfile -File scripts/docs-sync-check.ps1' }
    [pscustomobject]@{ Label = 'Bash'; Command = 'bash scripts/docs-sync-check.sh' }
)
$completionResultContract = @(
    'PASS requires exit code 0'
    'All AI Tech Lead framework checks passed.'
)

# A quoted/backticked subject, then a maintenance verb and /command within the same clause.
# Clause boundaries are intentionally strict so provenance/routing phrases do not become claims.
$claimGrammar = '(?im)(?:"[^"\r\n]+"|`[^`\r\n]+`)[^.;\r\n]*(?:\b(?:is|are)\s+)?(?:also\s+)?(?:refreshed|re-confirmed|reconfirmed|regenerated|repopulated|maintained|updated)\s+by\s+`?/[A-Za-z0-9-]+`?'

function Read-Utf8Text {
    param([string]$Path)
    return [IO.File]::ReadAllText([IO.Path]::GetFullPath($Path), $utf8)
}

function Get-MarkdownBody {
    param([string]$Text)
    if ($Text -notmatch '\A---\r?\n') { return $Text }
    $offset = $Matches[0].Length
    $closing = [regex]::Match($Text.Substring($offset), '(?m)^---\s*$')
    if (-not $closing.Success) { return $Text }
    return $Text.Substring($offset + $closing.Index + $closing.Length).TrimStart("`r", "`n")
}

function Get-LevelTwoSection {
    param([string]$Text, [string]$Heading, [string]$Label)
    $escaped = [regex]::Escape($Heading)
    $match = [regex]::Match($Text, "(?ms)^## $escaped\s*`$.*?(?=^##\s|\z)")
    if (-not $match.Success) { throw "$Label has no '## $Heading' section" }
    return $match.Value
}

function Assert-CompletionHostMatrix {
    param([string]$Section, [string]$Label)
    $labelMatches = @()
    $commandMatches = @()
    foreach ($hostContract in $completionHosts) {
        $labelPattern = '(?m)^' + [regex]::Escape($hostContract.Label) + '[^\r\n]*:\s*$'
        $hostLabelMatches = @([regex]::Matches($Section, $labelPattern))
        if ($hostLabelMatches.Count -eq 0) {
            throw "$Label omits supported host label '$($hostContract.Label)'"
        }
        if ($hostLabelMatches.Count -ne 1) {
            throw "$Label repeats supported host label '$($hostContract.Label)'"
        }

        $commandPattern = '(?m)^' + [regex]::Escape($hostContract.Command) + '\s*$'
        $hostCommandMatches = @([regex]::Matches($Section, $commandPattern))
        if ($hostCommandMatches.Count -eq 0) {
            throw "$Label omits supported host invocation '$($hostContract.Command)'"
        }
        if ($hostCommandMatches.Count -ne 1) {
            throw "$Label repeats supported host invocation '$($hostContract.Command)'"
        }

        $labelMatches += $hostLabelMatches[0]
        $commandMatches += $hostCommandMatches[0]
    }
    for ($index = 0; $index -lt $completionHosts.Count; $index++) {
        $blockEnd = $Section.Length
        foreach ($otherLabel in $labelMatches) {
            if ($otherLabel.Index -gt $labelMatches[$index].Index -and $otherLabel.Index -lt $blockEnd) {
                $blockEnd = $otherLabel.Index
            }
        }
        if ($commandMatches[$index].Index -le $labelMatches[$index].Index -or
            $commandMatches[$index].Index -ge $blockEnd) {
            throw "$Label does not pair supported host label '$($completionHosts[$index].Label)' with invocation '$($completionHosts[$index].Command)'"
        }
    }
    foreach ($required in $completionResultContract) {
        if ($Section.IndexOf($required, [StringComparison]::Ordinal) -lt 0) {
            throw "$Label weakens the completion result contract: missing '$required'"
        }
    }
}

function Assert-Contracts {
    param([object[]]$Registry, [object[]]$DistEntries)
    if (@($Registry).Count -eq 0) { throw 'claim contract registry is empty -- contract check is vacuous' }
    foreach ($row in $Registry) {
        foreach ($dist in @($DistEntries | Where-Object { $row.Dists -contains $_.Name })) {
            $claimPath = Join-Path $dist.Root ($row.Claim -replace '/', [IO.Path]::DirectorySeparatorChar)
            if (-not (Test-Path -LiteralPath $claimPath -PathType Leaf)) { throw "claim file is missing in $($dist.Name): $($row.Claim)" }
            $claimText = Read-Utf8Text $claimPath
            if ($claimText.IndexOf($row.Line, [StringComparison]::Ordinal) -lt 0) {
                throw "claim text is missing in $($dist.Name)/$($row.Claim): $($row.Line)"
            }
            $commandPath = Join-Path $dist.Root ($row.Command -replace '/', [IO.Path]::DirectorySeparatorChar)
            if (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) { throw "command file is missing in $($dist.Name): $($row.Command)" }
            $commandText = Read-Utf8Text $commandPath
            $commandBody = Get-MarkdownBody $commandText
            if ($row.Requires -and $commandBody.IndexOf($row.Requires, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                throw "broken claim contract in $($dist.Name)/$($row.Claim): $($row.Command) lacks '$($row.Requires)'"
            }
            if ($null -ne $row.RequiresStepCount) {
                $steps = @([regex]::Matches($commandBody, '(?m)^### Step [0-9]+\b'))
                if ($steps.Count -ne [int]$row.RequiresStepCount) {
                    throw "wrong top-level step count in $($dist.Name)/$($row.Command): expected $($row.RequiresStepCount), found $($steps.Count)"
                }
            }
        }
    }
}

function Get-ClaimHits {
    param([object[]]$DistEntries)
    $hits = @()
    foreach ($dist in $DistEntries) {
        $files = @(Get-ChildItem -LiteralPath $dist.Root -Recurse -Force -File -Filter *.md |
            Where-Object { $_.Name -ne 'CHANGELOG.md' })
        foreach ($file in $files) {
            $text = Read-Utf8Text $file.FullName
            foreach ($match in [regex]::Matches($text, $claimGrammar)) {
                $relative = $file.FullName.Substring($dist.Root.Length).TrimStart('\', '/') -replace '\\', '/'
                $line = 1 + ([regex]::Matches($text.Substring(0, $match.Index), "`n")).Count
                $hits += [pscustomobject]@{ Dist = $dist.Name; Claim = $relative; Line = $line; Text = $match.Value }
            }
        }
    }
    return $hits
}

function Assert-Completeness {
    param([object[]]$Registry, [object[]]$Hits)
    if (@($Hits).Count -eq 0) { throw 'shipped Markdown yielded zero attribution claims -- completeness grammar is vacuous' }
    foreach ($hit in $Hits) {
        $registered = @($Registry | Where-Object {
            $_.Dists -contains $hit.Dist -and $_.Claim -ceq $hit.Claim -and
            $_.Line.IndexOf($hit.Text, [StringComparison]::Ordinal) -ge 0
        })
        if ($registered.Count -eq 0) {
            throw "unregistered command-maintenance claim in $($hit.Dist)/$($hit.Claim):$($hit.Line): $($hit.Text)"
        }
    }
}

function Assert-NoInvalidImpactArm {
    param([object[]]$DistEntries)
    foreach ($dist in $DistEntries) {
        $adoptPath = Join-Path $dist.Root '.claude/commands/adopt.md'
        if (-not (Test-Path -LiteralPath $adoptPath -PathType Leaf)) { throw "adoption command is missing in $($dist.Name): .claude/commands/adopt.md" }
        $adoptText = Read-Utf8Text $adoptPath
        # The installer is already present when /adopt begins. A tag made here cannot describe an
        # old-framework arm, regardless of the task/model controls claimed around it.
        if ($adoptText -match '(?is)pre-adoption.{0,240}(?:old\s+framework\s+arm|behavioral\s+A/B|only\s+the\s+framework\s+differs)') {
            throw "invalid post-install impact arm in $($dist.Name)/.claude/commands/adopt.md: a pre-adoption tag captured during /adopt is not an old-framework comparison arm"
        }
    }
}

function Assert-NoDebtDerivedBoyScout {
    param([object[]]$DistEntries)
    foreach ($dist in $DistEntries) {
        foreach ($relative in @('.claude/commands/bootstrap.md', '.claude/commands/rebootstrap.md')) {
            $path = Join-Path $dist.Root $relative
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "workflow is missing in $($dist.Name): $relative" }
            $text = Read-Utf8Text $path
            if ($text -match '(?i)Boy Scout Rule.{0,120}(?:actual debt|newly found debt|priority list)') {
                throw "debt-derived Boy Scout instruction remains in $($dist.Name)/$relative"
            }
        }
    }
}

function Assert-OnboardingMemoryContracts {
    param([object[]]$DistEntries)
    foreach ($dist in $DistEntries) {
        $checks = @(
            @{ Path = 'TECH_DEBT.md'; Required = @('## Dismissed proposals', 'Affected paths / symbols', 'Evidence reviewed', 'do not re-propose without materially changed evidence') },
            @{ Path = '.claude/commands/debt.md'; Required = @('Dismiss as not debt', 'materially changed evidence', 'Evidence delta') },
            @{ Path = '.claude/commands/bootstrap.md'; Required = @('framework-ownership.json', 'framework-owned/overwritten', '## Dismissed proposals', 'Evidence delta') },
            @{ Path = '.claude/commands/rebootstrap.md'; Required = @('framework-ownership.json', 'framework-owned/overwritten', '## Dismissed proposals', 'Evidence delta') },
            @{ Path = '.claude/commands/docs-sync.md'; Required = @('## Dismissed proposals', 'materially changed evidence', 'evidence delta') }
        )
        foreach ($check in $checks) {
            $path = Join-Path $dist.Root $check.Path
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "onboarding carrier is missing in $($dist.Name): $($check.Path)" }
            $text = Read-Utf8Text $path
            foreach ($required in $check.Required) {
                if ($text.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                    throw "onboarding carrier $($dist.Name)/$($check.Path) omits '$required'"
                }
            }
        }
    }
}

function Assert-VerificationOwnershipContracts {
    param([object[]]$DistEntries)
    foreach ($dist in $DistEntries) {
        foreach ($relative in @(
            '.github/instructions/framework-rules.instructions.md',
            'AGENTS.md',
            '.claude/commands/bootstrap.md',
            '.claude/commands/rebootstrap.md'
        )) {
            $path = Join-Path $dist.Root $relative
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "verification ownership carrier is missing in $($dist.Name): $relative" }
            $text = Read-Utf8Text $path
            foreach ($required in @('framework-owned/overwritten', 'framework-retirements.json', 'application-command evidence', 'report framework checks separately')) {
                if ($text.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                    throw "verification ownership carrier $($dist.Name)/$relative omits '$required'"
                }
            }
            if ($relative -match 'bootstrap\.md$') {
                foreach ($required in @('normalize', 'quoted', 'direct leaf', 'do not run')) {
                    if ($text.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                        throw "verification ownership workflow $($dist.Name)/$relative omits '$required'"
                    }
                }
            }
        }
    }
}

function Assert-MatureArchitecturePreservation {
    param([object[]]$DistEntries)
    foreach ($dist in $DistEntries) {
        $path = Join-Path $dist.Root '.claude/commands/adopt.md'
        $text = Read-Utf8Text $path
        foreach ($required in @('Mature architecture corpus (screen in place)', 'path and bytes byte-for-byte', 'broken relative links', 'multiple indexes claim authority', 'Legacy installer collision recovery', 'restore the archived bytes')) {
            if ($text.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                throw "adoption carrier $($dist.Name)/.claude/commands/adopt.md omits '$required'"
            }
        }
        foreach ($forbidden in @('docs/pre-adoption/adr/0001-', 'Append the full ADR')) {
            if ($text.IndexOf($forbidden, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                throw "adoption carrier $($dist.Name)/.claude/commands/adopt.md still rehomes/re-derives mature docs via '$forbidden'"
            }
        }
    }
}

function Assert-OnboardingCompletionGates {
    param([object[]]$DistEntries)
    foreach ($dist in $DistEntries) {
        $checks = @(
            @{ Path = '.claude/commands/bootstrap.md'; Direct = $true; Required = @('## Deterministic completion gate', 'scripts/docs-sync-check.ps1', 'scripts/docs-sync-check.sh', 'CANT-VERIFY', 'Do not claim completion', 'bare text', 'repository-root-relative path', 'resolves') },
            @{ Path = '.claude/commands/rebootstrap.md'; Direct = $true; Required = @('## Deterministic completion gate', 'scripts/docs-sync-check.ps1', 'scripts/docs-sync-check.sh', 'CANT-VERIFY', 'Do not claim completion') },
            @{ Path = '.claude/commands/generate-copilot.md'; Direct = $true; Required = @('## Deterministic completion gate', 'scripts/docs-sync-check.ps1', 'scripts/docs-sync-check.sh', 'CANT-VERIFY', 'Do not claim completion') },
            @{ Path = '.claude/commands/adopt.md'; Direct = $false; Required = @("Phase-7 bootstrap's deterministic completion gate", 'PASS', 'Do not claim adoption complete') }
        )
        foreach ($check in $checks) {
            $path = Join-Path $dist.Root $check.Path
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "completion-gate carrier is missing in $($dist.Name): $($check.Path)" }
            $text = Read-Utf8Text $path
            foreach ($required in $check.Required) {
                if ($text.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                    throw "completion-gate carrier $($dist.Name)/$($check.Path) omits '$required'"
                }
            }
            if ($check.Direct) {
                $label = "completion-gate carrier $($dist.Name)/$($check.Path)"
                $section = Get-LevelTwoSection -Text $text -Heading 'Deterministic completion gate' -Label $label
                Assert-CompletionHostMatrix -Section $section -Label $label
            }
        }
    }
}

function New-Fixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('doc-claims-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($root) | Out-Null
    [IO.Directory]::CreateDirectory((Join-Path $root '.claude/commands')) | Out-Null
    [IO.File]::WriteAllText((Join-Path $root 'claim.md'), '"Thing" is updated by `/demo`.', $utf8)
    [IO.File]::WriteAllText((Join-Path $root '.claude/commands/demo.md'), "### Step 1`nNeedle`n### Step 2`n", $utf8)
    return $root
}

if ($RedTest) {
    $fixtureRoot = New-Fixture
    try {
        $fixtureDist = @([pscustomobject]@{ Name = 'fixture'; Root = $fixtureRoot })
        $fixtureRegistry = @([pscustomobject]@{ Claim = 'claim.md'; Line = '"Thing" is updated by `/demo`'; Command = '.claude/commands/demo.md'; Requires = 'Needle'; RequiresStepCount = $null; Dists = @('fixture') })
        try {
            switch ($RedTest) {
                'broken-contract' {
                    $path = Join-Path $fixtureRoot '.claude/commands/demo.md'; $before = Read-Utf8Text $path
                    $after = $before.Replace('Needle', 'Absent'); Assert ($after -cne $before) 'broken-contract mutation did not change its file'
                    [IO.File]::WriteAllText($path, $after, $utf8); Assert-Contracts $fixtureRegistry $fixtureDist
                }
                'missing-claim' {
                    $path = Join-Path $fixtureRoot 'claim.md'; $before = Read-Utf8Text $path
                    $after = $before.Replace('updated', 'checked'); Assert ($after -cne $before) 'missing-claim mutation did not change its file'
                    [IO.File]::WriteAllText($path, $after, $utf8); Assert-Contracts $fixtureRegistry $fixtureDist
                }
                'wrong-step-count' {
                    $before = $fixtureRegistry[0]; $fixtureRegistry[0] = [pscustomobject]@{ Claim = $before.Claim; Line = $before.Line; Command = $before.Command; Requires = $null; RequiresStepCount = 3; Dists = $before.Dists }
                    Assert ($fixtureRegistry[0].RequiresStepCount -ne $before.RequiresStepCount) 'wrong-step-count mutation did not change its registry row'
                    Assert-Contracts $fixtureRegistry $fixtureDist
                }
                'unregistered-claim' {
                    $path = Join-Path $fixtureRoot 'extra.md'; Assert (-not (Test-Path -LiteralPath $path)) 'unregistered-claim fixture already exists'
                    [IO.File]::WriteAllText($path, '"Extra" is maintained by `/other`.', $utf8); Assert (Test-Path -LiteralPath $path) 'unregistered-claim mutation did not create its file'
                    $hits = @(Get-ClaimHits -DistEntries $fixtureDist)
                    Assert-Completeness -Registry $fixtureRegistry -Hits $hits
                }
                'vacuous-registry' {
                    $before = @($fixtureRegistry).Count; $fixtureRegistry = @(); Assert ($before -gt 0 -and @($fixtureRegistry).Count -eq 0) 'vacuous-registry mutation did not empty the registry'
                    Assert-Contracts $fixtureRegistry $fixtureDist
                }
                'vacuous-grammar' {
                    $path = Join-Path $fixtureRoot 'claim.md'; $before = Read-Utf8Text $path
                    $after = 'No maintenance attribution here.'; Assert ($after -cne $before) 'vacuous-grammar mutation did not change its file'
                    [IO.File]::WriteAllText($path, $after, $utf8)
                    $hits = @(Get-ClaimHits -DistEntries $fixtureDist)
                    Assert-Completeness -Registry $fixtureRegistry -Hits $hits
                }
            }
            Write-Error "red test '$RedTest' unexpectedly passed"
            exit 1
        } catch {
            [Console]::Error.WriteLine($_.Exception.Message)
            exit 1
        }
    } finally {
        if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
    }
}

$distEntries = if ($DistRoot) {
    $resolved = (Resolve-Path -LiteralPath $DistRoot).Path
    @([pscustomobject]@{ Name = 'dotnet'; Root = $resolved })
} else {
    @($allDists | ForEach-Object { [pscustomobject]@{ Name = $_; Root = (Resolve-Path (Join-Path $repoRoot "dist/$_")).Path } })
}

Reset-Tests

It 'every registered doc claim still exists and is true of its command' {
    Assert-Contracts $contracts $distEntries
}

It 'every narrow command-maintenance claim is registered' {
    $hits = @(Get-ClaimHits -DistEntries $distEntries)
    Assert-Completeness -Registry $contracts -Hits $hits
}

It 'adoption never presents its post-install tag as an old-framework A/B arm' {
    Assert-NoInvalidImpactArm -DistEntries $distEntries
}

It 'bootstrap workflows do not turn finite debt into the Boy Scout list' {
    Assert-NoDebtDerivedBoyScout -DistEntries $distEntries
}

It 'onboarding preserves debt dismissals and excludes framework-owned skill evidence' {
    Assert-OnboardingMemoryContracts -DistEntries $distEntries
}

It 'verification discovery excludes framework-owned and retired command evidence' {
    Assert-VerificationOwnershipContracts -DistEntries $distEntries
}

It 'adoption screens mature architecture docs in place without re-deriving them' {
    Assert-MatureArchitecturePreservation -DistEntries $distEntries
}

It 'onboarding and mirror workflows bind completion to deterministic docs sync' {
    Assert-OnboardingCompletionGates -DistEntries $distEntries
}

It 'each supported completion host invocation is independently required' {
    $valid = @"
## Deterministic completion gate

Windows PowerShell 5.1:
$($completionHosts[0].Command)

PowerShell 7:
$($completionHosts[1].Command)

Bash:
$($completionHosts[2].Command)

PASS requires exit code 0 and the final line ``All AI Tech Lead framework checks passed.``
"@
    Assert-CompletionHostMatrix -Section $valid -Label 'negative-control baseline'
    foreach ($hostContract in $completionHosts) {
        $mutated = $valid.Replace($hostContract.Command, '<removed invocation>')
        Assert ($mutated -cne $valid) "negative control did not remove $($hostContract.Label)"
        $caught = $null
        try { Assert-CompletionHostMatrix -Section $mutated -Label 'negative-control mutation' }
        catch { $caught = $_.Exception.Message }
        Assert ($caught -like "*omits supported host invocation*$($hostContract.Command)*") `
            "removing $($hostContract.Label) was not rejected precisely: $caught"
    }

    $swapMarker = '<swapped PowerShell invocation>'
    $swapped = $valid.Replace($completionHosts[0].Command, $swapMarker).
        Replace($completionHosts[1].Command, $completionHosts[0].Command).
        Replace($swapMarker, $completionHosts[1].Command)
    $caught = $null
    try { Assert-CompletionHostMatrix -Section $swapped -Label 'negative-control swapped matrix' }
    catch { $caught = $_.Exception.Message }
    Assert ($caught -like '*does not pair*') "swapping the PowerShell invocations was not rejected precisely: $caught"
}

exit (Write-TestSummary 'DocClaims.Tests')
