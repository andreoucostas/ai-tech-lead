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
    [pscustomobject]@{ Claim = '.claude/commands/rebootstrap.md'; Line = 'Re-run A7 using `bootstrap.md`'; Command = '.claude/commands/rebootstrap.md'; Requires = 'Bounded Repository-Knowledge Discovery'; RequiresStepCount = $null; Dists = @('angular') }
    [pscustomobject]@{ Claim = '.claude/commands/rebootstrap.md'; Line = 'Re-run shared A8 using `bootstrap.md`'; Command = '.claude/commands/rebootstrap.md'; Requires = 'Bounded Repository-Knowledge Discovery'; RequiresStepCount = $null; Dists = @('dotnet', 'monorepo') }
    [pscustomobject]@{ Claim = '.agents/skills/docs-sync/SKILL.md'; Line = 'all six steps'; Command = '.claude/commands/docs-sync.md'; Requires = $null; RequiresStepCount = 6; Dists = $allDists }
)

$completionHosts = @(
    [pscustomobject]@{ Label = 'PowerShell 7'; Command = 'pwsh -NoProfile -File scripts/docs-sync-check.ps1' }
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

# Field report #18: during /adopt a developer got a hazard question offering bare letters a, b, c, in the
# table's terms ("Existing row") and the agent's own labels, and could not answer it.
function Assert-HazardQuestionsStandAlone {
    param([object[]]$DistEntries)
    foreach ($dist in $DistEntries) {
        foreach ($relative in @('.claude/commands/bootstrap.md', '.claude/commands/rebootstrap.md')) {
            $path = Join-Path $dist.Root $relative
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "workflow is missing in $($dist.Name): $relative" }
            $text = Read-Utf8Text $path
            if ($text -match '(?i)offering \(a\), \(b\), \(c\)|Is this \(a\) a confirmed risk') {
                throw "$($dist.Name)/$relative offers hazard answers as bare letters"
            }
            foreach ($required in @('stands alone', '\*\*Real risk, track it\*\*', '\*\*Not a risk here\*\*', '\*\*Not sure\*\*', 'never (?:by|as) a bare letter', 'table term', "option's description", 'Risk 3/12', 'what could go wrong', 'what you saw')) {
                if ($text -notmatch "(?i)$required") { throw "$($dist.Name)/$relative hazard questions omit '$required'" }
            }
        }
    }
}

# B-553: the angular-eslint schematic lints only src/**, so a focused or skipped browser spec committed outside
# src/ (Playwright testDir, Cypress specPattern) passed the lint step the skill says binds every developer, agent and CI.
function Assert-EnforceStandardsReachesE2e {
    param([object[]]$DistEntries)
    foreach ($dist in @($DistEntries | Where-Object { $_.Name -in @('angular', 'monorepo') })) {
        $relative = '.claude/skills/enforce-standards/SKILL.md'
        $path = Join-Path $dist.Root $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "skill is missing in $($dist.Name): $relative" }
        $text = Read-Utf8Text $path
        foreach ($required in @('lintFilePatterns', 'src/**', 'testDir', 'specPattern', 'end-to-end')) {
            if (-not $text.Contains($required)) { throw "$($dist.Name)/$relative omits $required" }
        }
    }
}

# Field report #18, second half: the end-of-run checklists asked "Is [specific risk] real in this codebase?" with
# no file, evidence or effect, unattended /adopt sends every hazard there past a ~10-entry cap, and /adopt's
# Phase 1 and Phase 5 said only "ask the user".
function Assert-SetupChecklistStandsAlone {
    param([object[]]$DistEntries)
    foreach ($dist in $DistEntries) {
        foreach ($relative in @('.claude/commands/adopt.md', '.claude/commands/bootstrap.md')) {
            $path = Join-Path $dist.Root $relative
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "workflow is missing in $($dist.Name): $relative" }
            $text = Read-Utf8Text $path
            foreach ($stale in @('Is \[specific risk\] real in this codebase', 'mark as unverified', 'ask user when unclear', 'ask the user explicitly')) {
                if ($text -match "(?i)$stale") { throw "$($dist.Name)/$relative still asks '$($Matches[0])', with no file, evidence or effect" }
            }
            $checklist = [regex]::Match($text, '(?ms)^(?:## Phase 8 — Final report|### Needs a human decision)\s*$.*?(?=^## |\z)').Value
            if (-not $checklist) { throw "$($dist.Name)/$relative has no end-of-run checklist" }
            foreach ($required in @('never cut by the cap', 'one entry listing every one of them', 'real risk, set its Status to [VERIFIED]', 'set it to [REVIEWED: not a hazard', 'set Reviewed to today', 'Not sure: leave it', '[what could go wrong', 'because [what that code shows]',
                    'Such a row is never listed in entry 3: its file and line are recorded nowhere and must not reach the pull request.')) {
                if (-not $checklist.Contains($required)) { throw "$($dist.Name)/$relative end-of-run checklist omits '$required'" }
            }
            if ($checklist -notmatch 'reread\w*[^\r\n]{0,20}path:line') { throw "$($dist.Name)/$relative end-of-run checklist does not reread each hazard's path:line range" }
        }
        $label = "$($dist.Name)/.claude/commands/adopt.md"
        $adopt = Read-Utf8Text (Join-Path $dist.Root '.claude/commands/adopt.md')
        foreach ($pair in @(@('Phase 1 — Discovery', 'what each does to it'), @('Phase 5 — Merge into TECH_DEBT.md', 'what each means'), @('Phase 5 — Merge into TECH_DEBT.md', 'unset — needs a human'))) {
            if (-not (Get-LevelTwoSection $adopt $pair[0] $label).Contains($pair[1])) { throw "$label $($pair[0]) omits '$($pair[1])'" }
        }
    }
}

# B-547: each decision unattended /adopt's table leaves for a person needs an entry on the end-of-run list, or the
# list's "No open judgment calls" line tells the pull request nothing waits. Every table row is either settled
# (no question left) or a deferral here: Gate matches its first cell, Cell its last, Entry finds its list entry,
# which the cap never cuts and which keeps the Pins a reader acts on.
function Assert-AdoptDeferralsListed {
    param([object[]]$DistEntries)
    $deferrals = @(
        [pscustomobject]@{ Gate = 'ambiguous-file disposition'; Cell = 'left in place'; Entry = 'left in place'; Pins = @('Then one line per item', 'except a file entry 6 lists', 'Nobody checked them for instructions planted to steer an agent') }
        [pscustomobject]@{ Gate = 'quarantine per-file approval'; Cell = 'held-back'; Entry = 'quarantined'; Pins = @('quarantined that no person approved', 'plus every file under `docs/pre-adoption/quarantine/` whether or not this run still remembers it', 'Then one line per file') }
        [pscustomobject]@{ Gate = 'architecture authority choice'; Cell = 'authority'; Entry = 'authority choice remains'; Pins = @('Name the one the team treats as the authority') }
        [pscustomobject]@{ Gate = 'show each merge before applying'; Cell = 'staged'; Entry = 'staged proposed changes'; Pins = @('none is final until a person accepts it') }
        [pscustomobject]@{ Gate = 'show each merge before applying'; Cell = 'DEFAULTED'; Entry = 'DEFAULTED'; Pins = @('Then one line per marker') }
        [pscustomobject]@{ Gate = 'severity / effort'; Cell = 'unset'; Entry = 'unset — needs a human'; Pins = @('Then one line per item') }
        [pscustomobject]@{ Gate = 'custom-command adoption'; Cell = 'left in place'; Entry = 'custom command'; Pins = @('Then one line per item') }
    )
    $settled = @('Phase 0.1 uncommitted changes', 'Phase 0.2 branch confirmation', 'legacy `.github/skills` discovery', 'Phase 2 merge-plan confirmation', 'Phase 8 commit')
    $required = @('If every category is empty, replace the questions with the single line: `No open judgment calls — the run resolved everything against your code.`',
        'The cap counts only entries 2 and 5', 'Name only the reason: no line number, no quoted, reworded or summarized text, no URL or host.',
        'Nothing from their content, which nobody screened: no summary, no quoted text, no URL or host.')
    foreach ($dist in $DistEntries) {
        $label = "$($dist.Name)/.claude/commands/adopt.md"
        $adopt = Read-Utf8Text (Join-Path $dist.Root '.claude/commands/adopt.md')
        $rows = @([regex]::Matches((Get-LevelTwoSection $adopt 'Headless mode' $label), '(?m)^\|([^|\r\n]+)\|[^\r\n]*\|([^|\r\n]+)\|[ \t]*\r?$') |
            ForEach-Object { [pscustomobject]@{ Gate = $_.Groups[1].Value.Trim(); Deferred = $_.Groups[2].Value.Trim() } } |
            Where-Object { $_.Gate -ne 'Interactive gate' -and $_.Gate -notmatch '^-+$' })
        $phase8 = Get-LevelTwoSection $adopt 'Phase 8 — Final report' $label
        $list = [regex]::Match($phase8, '(?ms)prioritized checklist.*?(?=^Emit the result)').Value
        if (-not $list) { throw "$label has no end-of-run checklist" }
        $entries = @([regex]::Matches($list, '(?ms)^\d+\. .*?(?=^\d+\. |\z)') | ForEach-Object { $_.Value })
        foreach ($spec in $deferrals) {
            $row = @($rows | Where-Object { $_.Gate.Contains($spec.Gate) })
            if ($row.Count -ne 1) { throw "$label headless table has $($row.Count) rows for '$($spec.Gate)', expected 1" }
            $found = @($entries | Where-Object { $_.Contains($spec.Entry) })
            if ($found.Count -eq 0) { throw "$label defers '$($row[0].Gate)' to the end-of-run checklist, which has no entry for it" }
            if (-not ($row[0].Deferred.Contains('checklist') -and $row[0].Deferred.Contains($spec.Cell))) { throw "$label headless row '$($row[0].Gate)' no longer sends '$($spec.Cell)' to the end-of-run checklist" }
            foreach ($pin in @('never cut by the cap') + $spec.Pins) {
                if (-not @($found | Where-Object { $_.Contains($pin) })) { throw "$label end-of-run entry for '$($row[0].Gate)' omits '$pin'" }
            }
        }
        foreach ($row in $rows) {
            $known = @(@($deferrals.Gate) + $settled | Where-Object { $row.Gate.Contains($_) })
            if ($known.Count -eq 0) { throw "$label headless row '$($row.Gate)' leaves '$($row.Deferred)' with no end-of-run entry this case knows of" }
        }
        foreach ($clause in $required) {
            if (-not $phase8.Contains($clause)) { throw "$label Phase 8 omits '$clause'" }
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
            '.claude/commands/bootstrap.md',
            '.claude/commands/rebootstrap.md'
        )) {
            $path = Join-Path $dist.Root $relative
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "verification ownership carrier is missing in $($dist.Name): $relative" }
            $text = Read-Utf8Text $path
            $normalized = [regex]::Replace($text, '\s+', ' ')
            $requiredOwnership = if ($relative -eq '.github/instructions/framework-rules.instructions.md') {
                @('framework-owned/overwritten', 'framework-retirements.json', 'application-command, evidence', 'report separately from application verification')
            } else {
                @('framework-owned/overwritten', 'framework-retirements.json', 'application-command evidence', 'report framework checks separately')
            }
            foreach ($required in $requiredOwnership) {
                if ($normalized.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
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
            @{ Path = '.claude/commands/bootstrap.md'; Direct = $true; Required = @('## Deterministic completion gate', 'scripts/docs-sync-check.ps1', 'CANT-VERIFY', 'Do not claim completion', 'bare text', 'repository-root-relative path', 'resolves') },
            @{ Path = '.claude/commands/rebootstrap.md'; Direct = $true; Required = @('## Deterministic completion gate', 'scripts/docs-sync-check.ps1', 'CANT-VERIFY', 'Do not claim completion') },
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

function Assert-RepositoryKnowledgeDiscoveryContracts {
    param([object[]]$DistEntries)

    $carriers = @(
        @{ Path = '.claude/commands/bootstrap.md'; Required = @(
            'Bounded Repository-Knowledge Discovery',
            'A profile label is neither an inventory boundary nor permission to cross an access boundary.',
            'Never capture secrets.',
            'Quiet, atypical, unique, helper-derived, and conflicting-scope evidence qualifies; recurrence and naming are leads, not gates.',
            'eligibility, debt routing, and the Conventions-line alternative are 3a-bis''s decisions, not this pass''s.',
            'Read at most 40 distinct content files and follow at most two additional dependency hops per selected seed.',
            'Inventory does not consume the content-read budget.',
            'record actual reads',
            'bounded continuation',
            'Do not run provider trials or spend provider credits to validate discovery.',
            'native worker delegation',
            'same finite passes sequentially.',
            'Do not assume Claude `Task`',
            'Copilot host.'
        ) }
        @{ Path = '.claude/commands/rebootstrap.md'; Required = @(
            'Bounded Repository-Knowledge Discovery',
            'including quiet callers',
            'previously uncovered areas',
            'The pass remains read-only:',
            'do not capture or route its output here.',
            'native worker delegation',
            'same finite passes sequentially.',
            'Do not assume Claude `Task`',
            'Copilot host.'
        ) }
        # B-398: Copilot CLI 1.0.95 refuses 'model: sonnet' (a Claude Code alias) and the worker never starts.
        @{ Path = '.claude/agents/bootstrap-pass.md'; Required = @(
            'model: inherit',
            'Bounded Repository-Knowledge Discovery',
            'at most 40 distinct content files',
            'at most two additional dependency hops',
            'Inventory does not consume the content-read budget.',
            'do not prove intended policy or correctness',
            'is not independent corroboration',
            'Count repeated operations.',
            'a type, the line that registers it, its configuration, and its test',
            '**Claim / operation**',
            '**Selection reason**',
            '### Knowledge findings',
            'never capture secrets.',
            '**Actual content reads**',
            '**Next bounded continuation**',
            'do not run provider trials or spend provider credits to validate discovery'
        ) }
    )
    $forbidden = @(
        'Project-Specific Skill Discovery',
        'Recurs — the same multi-step operation appears 3+ times',
        'Read in full only the single cleanest instance',
        'Low count by design',
        'Knowledge findings ('
    )

    foreach ($dist in $DistEntries) {
        foreach ($carrier in $carriers) {
            $path = Join-Path $dist.Root $carrier.Path
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "repository-knowledge carrier is missing in $($dist.Name): $($carrier.Path)"
            }
            $text = Read-Utf8Text $path
            $normalized = [regex]::Replace($text, '\s+', ' ')
            foreach ($required in $carrier.Required) {
                if ($normalized.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                    throw "repository-knowledge carrier $($dist.Name)/$($carrier.Path) omits '$required'"
                }
            }
            foreach ($oldLimit in $forbidden) {
                if ($text.IndexOf($oldLimit, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    throw "repository-knowledge carrier $($dist.Name)/$($carrier.Path) retains forbidden old limit '$oldLimit'"
                }
            }
        }
    }

    foreach ($dist in @($DistEntries | Where-Object { $_.Name -in @('dotnet', 'monorepo') })) {
        $path = Join-Path $dist.Root '.claude/skills/map-warehouse/SKILL.md'
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "warehouse discovery carrier is missing in $($dist.Name): .claude/skills/map-warehouse/SKILL.md"
        }
        $text = Read-Utf8Text $path
        foreach ($required in @('Bounded discovery exception.', '40-content-file, two-additional-hop budget', 'standalone `/map-warehouse` run, which remains request-only.')) {
            if ($text.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                throw "warehouse discovery carrier $($dist.Name)/.claude/skills/map-warehouse/SKILL.md omits '$required'"
            }
        }
    }
}

# B-427: Copilot CLI 1.0.98 runs these reviewers' model-less wrappers, so their 'model: haiku' never applied there
# (B-399), and it refuses a Claude Code alias (B-398). /review passes Haiku per call instead, as /bootstrap does (WSD-115).
function Assert-ReviewerModelContracts {
    param([object[]]$DistEntries)
    $rule = @(
        '**Reviewer model.**',
        'pass Haiku as the model of each `convention-check`, `debt-radar` and `bloat-radar` call',
        '`haiku` in Claude Code, and in Copilot CLI the newest `claude-haiku-*` id its `task` tool lists.',
        'On any other session model pass none'
    )
    foreach ($dist in $DistEntries) {
        foreach ($agent in 'convention-check', 'debt-radar', 'bloat-radar') {
            $path = Join-Path $dist.Root ".claude/agents/$agent.md"
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "reviewer is missing in $($dist.Name): .claude/agents/$agent.md" }
            if ((Read-Utf8Text $path) -notmatch '(?m)\A---\r?\n(?:(?!---).*\r?\n)*?model: inherit\r?\n') {
                throw "reviewer $($dist.Name)/.claude/agents/$agent.md does not say 'model: inherit' in its frontmatter"
            }
        }
        $review = Join-Path $dist.Root '.claude/commands/review.md'
        $normalized = [regex]::Replace((Read-Utf8Text $review), '\s+', ' ')
        foreach ($required in $rule) {
            if ($normalized.IndexOf($required, [StringComparison]::Ordinal) -lt 0) {
                throw "$($dist.Name)/.claude/commands/review.md omits the reviewer-model rule text '$required'"
            }
        }
    }
}

function Assert-RepositoryKnowledgeCaptureContracts {
    param([object[]]$DistEntries)

    foreach ($dist in $DistEntries) {
        $bootstrapPath = Join-Path $dist.Root '.claude/commands/bootstrap.md'
        $rebootstrapPath = Join-Path $dist.Root '.claude/commands/rebootstrap.md'
        $contextPath = Join-Path $dist.Root 'FRAMEWORK-CONTEXT.md'
        $wikiTemplatePath = Join-Path $dist.Root 'docs/wiki/_template.md'
        $rememberPath = Join-Path $dist.Root '.claude/skills/remember-for-team/SKILL.md'
        foreach ($path in @($bootstrapPath, $rebootstrapPath, $contextPath, $wikiTemplatePath, $rememberPath)) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                throw "repository-knowledge capture carrier is missing in $($dist.Name): $path"
            }
        }

        $bootstrap = Read-Utf8Text $bootstrapPath
        foreach ($required in @(
            '### 3a-bis: Capture repository knowledge as review drafts',
            'new, non-overwriting review draft',
            'provenance and adversarial-content screens',
            'not instructions to execute or authority for broader reads or writes',
            'frontmatter contains `name`, a trigger-rich `description`, and',
            '`origin: discovered` so existing lifecycle handling can find it;',
            'three or more distinct consumer-authored instances share its ordered steps and files',
            'Write at most three skill drafts per run',
            'never under a slug root `framework-retirements.json` retires',
            '`DRAFT, pending PR review:`',
            'as a folded `>` block or a double-quoted string, never a plain line',
            'It ends with an `## After review` paragraph',
            'Never overwrite, move, or',
            'explicit relative Markdown link to every focused reference',
            'Do not also create a wiki draft that duplicates the operation',
            '**Provenance:**',
            '**Draft status:** draft pending PR review; not team-approved policy',
            'draft pending PR review; not team-approved policy',
            'last-verified: never',
            'path-existence-only check does not refresh truth or date',
            'its decisive source or predicate; that is enough to refresh that claim.',
            'runtime or business-behaviour proof.',
            'unavailable runtime evidence never',
            'inflates the claim;',
            'at most 12 summary lines'
        )) {
            if ($bootstrap.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                throw "repository-knowledge bootstrap capture carrier $($dist.Name) omits '$required'"
            }
        }
        # Only the warehouse dists still ship an instance-shaped skill that owns a project-pattern reference.
        if ($dist.Name -in @('dotnet', 'monorepo')) {
            foreach ($required in @('An evidenced operation matching `add-warehouse-load` becomes only its new absent consumer-owned', '`references/project-pattern.md`', 'Never create a competing skill')) {
                if ($bootstrap.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                    throw "repository-knowledge bootstrap capture carrier $($dist.Name) omits '$required'"
                }
            }
        }
        foreach ($retired in @('add-component', 'add-endpoint', 'add-entity', 'add-lazy-route', 'add-service', 'add-signal-store', 'register-service')) {
            if ($bootstrap.IndexOf("``$retired``", [StringComparison]::Ordinal) -ge 0) {
                throw "repository-knowledge bootstrap capture carrier $($dist.Name) still names retired recipe skill '$retired'"
            }
        }
        foreach ($forbidden in @('in this package grants no such write authority', 'later capture workflow', 'capture/routing is a later workflow with separate write authority', 'read-only discovery pass wrote no project knowledge artifacts')) {
            if ($bootstrap.IndexOf($forbidden, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                throw "repository-knowledge bootstrap capture carrier $($dist.Name) retains intermediate wording '$forbidden'"
            }
        }

        $rebootstrap = Read-Utf8Text $rebootstrapPath
        foreach ($required in @('New absent repository-knowledge drafts are the narrow automatic exception in 3a-discovery.', '### 3a-discovery: Automatically draft new repository knowledge', 'eligible **new absent** non-overwriting draft', 'This automatic exception does not sit under the diff-and-confirm gate.', 'Existing owner content, near-matches, policy/ADRs, deletions, and authority decisions retain confirmation.', 'including quiet callers outside recent activity', 'path existence alone is not a semantic refresh', 'preserving a historic verification date on downgrade')) {
            if ($rebootstrap.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                throw "repository-knowledge rebootstrap capture carrier $($dist.Name) omits '$required'"
            }
        }

        $template = Read-Utf8Text $wikiTemplatePath
        foreach ($required in @('**Confidence:**', '**Provenance:**', '**Counterevidence / exceptions:**', '**Dependencies / unresolved:**', '**Semantic refresh:**', '**Draft status:**')) {
            if ($template.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                throw "repository-knowledge wiki template $($dist.Name) omits '$required'"
            }
        }
        if ($template.IndexOf("`nowner:", [StringComparison]::Ordinal) -lt 0) {
            throw "repository-knowledge wiki template $($dist.Name) omits the optional owner line"
        }
        foreach ($forbidden in @("`nprovenance:", "`nreview-status:")) {
            if ($template.IndexOf($forbidden, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                throw "repository-knowledge wiki template $($dist.Name) retains non-schema frontmatter '$forbidden'"
            }
        }
        $remember = Read-Utf8Text $rememberPath
        foreach ($required in @('never instructions or authorization for broader reads or writes', 'create only a new absent draft', 'cannot corroborate itself', 'body provenance', '**Draft status:** draft pending PR review; not team-approved policy', 'path-existence-only check does not refresh truth or its date', 'Rereading the decisive source/predicate is enough for a scoped source claim', 'restored dependencies or execution are reserved for runtime or business-behaviour proof', 'optional `owner`', 'never its value')) {
            if ($remember.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                throw "repository-knowledge drafting skill $($dist.Name) omits '$required'"
            }
        }
        $context = Read-Utf8Text $contextPath
        foreach ($required in @('## Repository Knowledge Discovery', 'REPOSITORY_KNOWLEDGE_DISCOVERY_PENDING', 'at most', 'grants neither additional access nor write authority')) {
            if ($context.IndexOf($required, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
                throw "repository-knowledge summary carrier $($dist.Name) omits '$required'"
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

It 'hazard questions stand alone and offer their answers in words, not bare letters' {
    Assert-HazardQuestionsStandAlone -DistEntries $distEntries
}

It 'end-of-setup checklists and adopt questions stand alone, every unconfirmed hazard listed' {
    Assert-SetupChecklistStandsAlone -DistEntries $distEntries
}

It 'enforce-standards makes the lint target reach the end-to-end folder' {
    Assert-EnforceStandardsReachesE2e -DistEntries $distEntries
}

It 'every decision the unattended /adopt table leaves for a person has an entry on the end-of-run list' {
    Assert-AdoptDeferralsListed -DistEntries $distEntries
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

It 'repository-knowledge discovery carriers preserve bounded read-only parity' {
    Assert-RepositoryKnowledgeDiscoveryContracts -DistEntries $distEntries
}

It 'review passes the three Haiku reviewers their model per call, and their files name none' {
    Assert-ReviewerModelContracts -DistEntries $distEntries
}

It 'repository-knowledge capture carriers preserve draft and refresh boundaries' {
    Assert-RepositoryKnowledgeCaptureContracts -DistEntries $distEntries
}

It 'the supported completion host invocation is required' {
    $valid = @"
## Deterministic completion gate

PowerShell 7 (``pwsh``; Windows PowerShell 5.1 is not supported):
$($completionHosts[0].Command)

PASS requires exit code 0 and the final line ``All AI Tech Lead framework checks passed.``
"@
    Assert-CompletionHostMatrix -Section $valid -Label 'negative-control baseline'
    $mutated = $valid.Replace($completionHosts[0].Command, '<removed invocation>')
    Assert ($mutated -cne $valid) 'negative control did not remove the PowerShell 7 invocation'
    $caught = $null
    try { Assert-CompletionHostMatrix -Section $mutated -Label 'negative-control mutation' }
    catch { $caught = $_.Exception.Message }
    Assert ($caught -like "*omits supported host invocation*$($completionHosts[0].Command)*") `
        "removing the PowerShell 7 invocation was not rejected precisely: $caught"
}

exit (Write-TestSummary 'DocClaims.Tests')
