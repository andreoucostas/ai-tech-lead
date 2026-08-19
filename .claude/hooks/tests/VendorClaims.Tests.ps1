param(
    [ValidateSet('', 'superseded-agentstop', 'superseded-stdout', 'superseded-reason',
        'vacuous-scan', 'vacuous-denylist', 'unpaired-reason', 'uncompilable-regex',
        'unproved-pattern', 'historical-section-swallows-live-prose')]
    [string]$RedTest = '',
    [string]$DistRoot = ''
)

# B-55. Fails when a composed dist restates a vendor-behavior claim we already know is dead, and
# says WHY it is dead. Deliberately a literal denylist of superseded claims, not an attempt to infer
# prose semantics -- the recurring harm is a claim that BECAME false when the vendor changed and
# stayed shipped, which a denylist catches and a canonical-source refactor would not.
# Patterns live in vendor-claims-denylist.txt. Meta-only; neither the list nor this gate ships.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$utf8 = [Text.Encoding]::UTF8
$allDists = @('dotnet', 'angular', 'monorepo')
$denyFile = Join-Path $PSScriptRoot 'vendor-claims-denylist.txt'

# Every DENY pattern must appear here, with the real text it has to catch and the live prose it must
# not. This is what stops a pattern being added that never matched the historical spelling -- the
# vacuity class this gate exists to prevent, applied to the gate itself. Historical strings are
# recovered verbatim from `git grep <phrase> 3ea42f8^ -- src dist` (the parent of the v0.35.0 commit
# that corrected them), not paraphrased.
$provenance = @(
    [pscustomobject]@{
        Pattern = '(?i)Copilot[^.\r\n]{0,60}\bno equivalent event\b'
        Matches = @(
            'soft-warns the model. Copilot has no equivalent event. |'
            '| `Stop` | End of every turn (Claude Code only) | Scans modified `.ts` files for the always-apply Boy Scout patterns; soft-warns the model. Copilot has no equivalent event. |'
        )
        Rejects = @(
            '   - **If NUnit:** there is no equivalent analyzer. NUnit1xxx rules are structural, NUnit2xxx are'
            'Claude Code uses `Stop`. Copilot CLI >= 1.0.72 scans at `agentStop` and delivers the queued nudge at the next prompt; the VS Code `Stop` path remains unverified and requires Preview agent-hooks.'
        )
    }
    [pscustomobject]@{
        Pattern = '(?i)Copilot[^.\r\n]{0,60}does not consume hook stdout'
        Matches = @(
            '**Copilot does not consume hook stdout for this event** ([hooks reference](https://docs.github.com/en/copilot/reference/hooks-configuration)), so in Copilot the equivalent vocabulary is shipped via the `SessionStart` primer and the model self-classifies.'
        )
        Rejects = @(
            'Per the [GitHub Copilot hooks reference](https://docs.github.com/en/copilot/reference/hooks-configuration), the `userPromptSubmitted` event is fire-and-forget - stdout is discarded, so `route-prompt.sh|ps1` could not inject workflow rails on the Copilot side regardless of schema correctness.'
            'Copilot CLI >= 1.0.65 consumes `userPromptSubmitted` stdout as additionalContext.'
        )
    }
    [pscustomobject]@{
        Pattern = '(?i)\breason[^\w\r\n]{0,3}(?:is|was)\s+shown only to the user'
        Matches = @(
            '# is NOT a stricter variant of this -- `reason` is shown only to the user, never fed to the model.'
            '# is NOT a stricter variant - `reason` is shown only to the user, never fed to the model.'
        )
        Rejects = @(
            '# is shown to Claude as a system reminder (unlike top-level stopReason). This advisory nudge still'
            'The top-level `stopReason` is shown only to the user, unlike the Stop hook `reason`.'
        )
    }
)

function Read-Utf8Text {
    param([string]$Path)
    return [IO.File]::ReadAllText([IO.Path]::GetFullPath($Path), $utf8)
}

# Parse the denylist. DENY must be immediately followed by its REASON: a pattern whose finding
# carries no reason teaches the reader nothing, so an unpaired DENY is a parse error, not a warning.
function Read-Denylist {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "denylist is missing: $Path" }
    $rules = @()
    $allow = @()
    $pending = $null
    foreach ($line in [IO.File]::ReadAllLines($Path, $utf8)) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        if ($t -match '^DENY\s+(.+)$') {
            if ($pending) { throw "DENY has no REASON on the next directive line: $($pending)" }
            $pending = $Matches[1].Trim()
            continue
        }
        if ($t -match '^REASON\s+(.+)$') {
            if (-not $pending) { throw "REASON with no preceding DENY: $($Matches[1].Trim())" }
            $rules += [pscustomobject]@{ Pattern = $pending; Reason = $Matches[1].Trim() }
            $pending = $null
            continue
        }
        if ($t -match '^ALLOW\s+(.+)$') { $allow += $Matches[1].Trim(); continue }
        throw "unrecognized directive in $([IO.Path]::GetFileName($Path)): $t"
    }
    if ($pending) { throw "DENY has no REASON on the next directive line: $pending" }
    if (@($rules).Count -eq 0) { throw 'vendor-claims denylist defines no DENY patterns -- the claim check is vacuous' }
    foreach ($rule in $rules) {
        try { [void][regex]::new($rule.Pattern) }
        catch { throw "denylist pattern does not compile: $($rule.Pattern) -- $($_.Exception.Message)" }
    }
    return [pscustomobject]@{ Rules = $rules; Allow = $allow }
}

# Blank out dated version sections so historical narration does not trip a live-claim check. A
# shipped README carries a `## Changelog` excerpt whose `### 0.7.2` section correctly quotes the
# pre-1.0.65 Copilot stdout behavior in the past tense -- excluding files named CHANGELOG.md is not
# enough. Blanking (rather than removing) keeps line numbers honest. Markdown only: '#' starts a
# comment in .ps1/.sh, where the boy-scout-check headers this gate must actually read live.
function Remove-HistoricalSections {
    param([string]$Text, [string]$Extension)
    if ($Extension -ne '.md') { return $Text }
    $lines = $Text -split "`n"
    $inFence = $false
    $historicalLevel = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $bare = $lines[$i].TrimEnd("`r")
        if ($bare.TrimStart() -match '^(?:```|~~~)') { $inFence = -not $inFence; continue }
        if ($inFence) {
            if ($historicalLevel -gt 0) { $lines[$i] = '' }
            continue
        }
        if ($bare -match '^(#{1,6})\s') {
            $level = $Matches[1].Length
            $isVersionHeading = $bare -match '^#{2,6}\s*\[?v?[0-9]+\.[0-9]+\.[0-9]+'
            if ($isVersionHeading) { $historicalLevel = $level; $lines[$i] = ''; continue }
            if ($historicalLevel -gt 0 -and $level -le $historicalLevel) { $historicalLevel = 0; continue }
        }
        if ($historicalLevel -gt 0) { $lines[$i] = '' }
    }
    return ($lines -join "`n")
}

function Get-ClaimViolations {
    param([object[]]$DistEntries, [object]$Denylist)
    $violations = @()
    $filesScanned = 0
    foreach ($dist in $DistEntries) {
        foreach ($file in @(Get-ChildItem -LiteralPath $dist.Root -Recurse -Force -File)) {
            $relative = $file.FullName.Substring($dist.Root.Length).TrimStart('\', '/') -replace '\\', '/'
            if ($file.Name -eq 'CHANGELOG.md') { continue }
            $skip = $false
            foreach ($a in $Denylist.Allow) { if ($relative -like "*$a*") { $skip = $true; break } }
            if ($skip) { continue }
            $filesScanned++
            $text = Remove-HistoricalSections -Text (Read-Utf8Text $file.FullName) -Extension $file.Extension
            foreach ($rule in $Denylist.Rules) {
                foreach ($match in [regex]::Matches($text, $rule.Pattern)) {
                    $line = 1 + ([regex]::Matches($text.Substring(0, $match.Index), "`n")).Count
                    $violations += [pscustomobject]@{
                        Dist = $dist.Name; File = $relative; Line = $line
                        Text = $match.Value; Reason = $rule.Reason
                    }
                }
            }
        }
    }
    return [pscustomobject]@{ Violations = $violations; FilesScanned = $filesScanned }
}

function Assert-NoSupersededClaims {
    param([object[]]$DistEntries, [object]$Denylist)
    $result = Get-ClaimViolations -DistEntries $DistEntries -Denylist $Denylist
    if ($result.FilesScanned -eq 0) { throw 'zero files scanned -- the superseded-claim check is vacuous' }
    if (@($result.Violations).Count -gt 0) {
        $lines = @($result.Violations | ForEach-Object {
            "  $($_.Dist)/$($_.File):$($_.Line): '$($_.Text.Trim())'`n      superseded: $($_.Reason)"
        })
        throw ("shipped content restates a superseded vendor claim:`n" + ($lines -join "`n"))
    }
}

# Each pattern must catch its own historical text and spare the prose that replaced it. A pattern
# proved in only one direction is half-proved: one that matches nothing is inert, one that
# over-matches blocks correct writing, and both fail silently.
function Assert-PatternsProved {
    param([object]$Denylist, [object[]]$Provenance)
    if (@($Provenance).Count -eq 0) { throw 'provenance registry is empty -- pattern proof is vacuous' }
    foreach ($rule in $Denylist.Rules) {
        $proof = @($Provenance | Where-Object { $_.Pattern -ceq $rule.Pattern })
        if ($proof.Count -ne 1) {
            throw "denylist pattern has no provenance entry (add its historical text and its must-not-match prose): $($rule.Pattern)"
        }
        if (@($proof[0].Matches).Count -eq 0) { throw "provenance entry lists no historical text: $($rule.Pattern)" }
        if (@($proof[0].Rejects).Count -eq 0) { throw "provenance entry lists no must-not-match prose: $($rule.Pattern)" }
        foreach ($historical in $proof[0].Matches) {
            if (-not [regex]::IsMatch($historical, $rule.Pattern)) {
                throw "pattern is INERT -- it does not match the historical text it exists to catch:`n  pattern: $($rule.Pattern)`n  text:    $historical"
            }
        }
        foreach ($live in $proof[0].Rejects) {
            if ([regex]::IsMatch($live, $rule.Pattern)) {
                throw "pattern OVER-MATCHES legitimate prose:`n  pattern: $($rule.Pattern)`n  text:    $live"
            }
        }
    }
}

function New-Fixture {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('vendor-claims-' + [guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($root) | Out-Null
    [IO.File]::WriteAllText((Join-Path $root 'README.md'), @"
# Fixture

## Hook compatibility

| ``Stop`` / ``agentStop`` | End of a write turn | Claude Code uses ``Stop``. Copilot CLI >= 1.0.72 scans at ``agentStop``. |

## Changelog

### 0.7.2 - 2026-05-16 (Copilot routing parity)

- **Copilot does not consume hook stdout for this event** was the claim then, and it was true then.

## Keeping it alive

- Nothing superseded here.
"@, $utf8)
    return $root
}

if ($RedTest) {
    $fixtureRoot = New-Fixture
    try {
        $fixtureDist = @([pscustomobject]@{ Name = 'fixture'; Root = $fixtureRoot })
        $denylist = Read-Denylist $denyFile
        $readmePath = Join-Path $fixtureRoot 'README.md'
        try {
            switch ($RedTest) {
                'superseded-agentstop' {
                    # Plants BEFORE the dated section; the sibling case below plants after it.
                    $before = Read-Utf8Text $readmePath
                    $after = $before.Replace('scans at `agentStop`.', 'scans at `agentStop`. Copilot has no equivalent event.')
                    Assert ($after -cne $before) 'superseded-agentstop mutation did not change its file'
                    [IO.File]::WriteAllText($readmePath, $after, $utf8)
                    Assert-NoSupersededClaims -DistEntries $fixtureDist -Denylist $denylist
                }
                'superseded-stdout' {
                    $before = Read-Utf8Text $readmePath
                    $after = $before.Replace('Nothing superseded here.', '**Copilot does not consume hook stdout for this event** ([hooks reference](https://docs.github.com/en/copilot/reference/hooks-configuration)).')
                    Assert ($after -cne $before) 'superseded-stdout mutation did not change its file'
                    [IO.File]::WriteAllText($readmePath, $after, $utf8)
                    Assert-NoSupersededClaims -DistEntries $fixtureDist -Denylist $denylist
                }
                'superseded-reason' {
                    $path = Join-Path $fixtureRoot 'boy-scout-check.ps1'
                    Assert (-not (Test-Path -LiteralPath $path)) 'superseded-reason fixture already exists'
                    [IO.File]::WriteAllText($path, "# is NOT a stricter variant of this -- ``reason`` is shown only to the user, never fed to the model.`n", $utf8)
                    Assert (Test-Path -LiteralPath $path) 'superseded-reason mutation did not create its file'
                    Assert-NoSupersededClaims -DistEntries $fixtureDist -Denylist $denylist
                }
                'historical-section-swallows-live-prose' {
                    # The section skipper must END a historical span at the next same-level heading.
                    # If it ran to end-of-file, a real superseded claim in a later live section would
                    # be silently exempt -- an inert gate wearing a green tick.
                    $before = Read-Utf8Text $readmePath
                    $after = $before.Replace('Nothing superseded here.', 'Copilot has no equivalent event.')
                    Assert ($after -cne $before) 'historical-section mutation did not change its file'
                    [IO.File]::WriteAllText($readmePath, $after, $utf8)
                    Assert-NoSupersededClaims -DistEntries $fixtureDist -Denylist $denylist
                }
                'vacuous-scan' {
                    Get-ChildItem -LiteralPath $fixtureRoot -Recurse -Force -File | Remove-Item -Force
                    Assert (@(Get-ChildItem -LiteralPath $fixtureRoot -Recurse -Force -File).Count -eq 0) 'vacuous-scan mutation left files behind'
                    Assert-NoSupersededClaims -DistEntries $fixtureDist -Denylist $denylist
                }
                'vacuous-denylist' {
                    $path = Join-Path $fixtureRoot 'empty-denylist.txt'
                    [IO.File]::WriteAllText($path, "# only comments here`n", $utf8)
                    [void](Read-Denylist $path)
                }
                'unpaired-reason' {
                    $path = Join-Path $fixtureRoot 'unpaired-denylist.txt'
                    [IO.File]::WriteAllText($path, "DENY foo`nDENY bar`nREASON both`n", $utf8)
                    [void](Read-Denylist $path)
                }
                'uncompilable-regex' {
                    $path = Join-Path $fixtureRoot 'bad-denylist.txt'
                    [IO.File]::WriteAllText($path, "DENY (unclosed`nREASON nothing`n", $utf8)
                    [void](Read-Denylist $path)
                }
                'unproved-pattern' {
                    $unproved = [pscustomobject]@{
                        Rules = @([pscustomobject]@{ Pattern = 'never proved anywhere'; Reason = 'x' })
                        Allow = @()
                    }
                    Assert-PatternsProved -Denylist $unproved -Provenance $provenance
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

$denylist = $null
It 'the superseded-claim denylist parses and every pattern compiles' {
    $script:denylist = Read-Denylist $denyFile
    Assert (@($script:denylist.Rules).Count -ge 3) 'denylist lost its seeded entries'
}

It 'every denylist pattern catches its historical text and spares the prose that replaced it' {
    Assert-PatternsProved -Denylist $script:denylist -Provenance $provenance
}

It 'no composed distribution restates a superseded vendor claim' {
    Assert-NoSupersededClaims -DistEntries $distEntries -Denylist $script:denylist
}

It 'a dated version section may quote a superseded claim without failing' {
    # The other direction of the same rule, on a real file rather than a string: the fixture's
    # `### 0.7.2` section quotes claim 2 verbatim, exactly as a shipped README does today.
    $root = New-Fixture
    try {
        Assert-NoSupersededClaims -DistEntries @([pscustomobject]@{ Name = 'fixture'; Root = $root }) -Denylist $script:denylist
    } finally { Remove-Item -LiteralPath $root -Recurse -Force }
}

It 'the historical-section skipper still exposes live prose in the same file' {
    $sample = "# T`n`n## Changelog`n`n### 0.7.2 - 2026-05-16`n`nCopilot has no equivalent event.`n`n## Live`n`nCopilot has no equivalent event.`n"
    $filtered = Remove-HistoricalSections -Text $sample -Extension '.md'
    $hits = @([regex]::Matches($filtered, '(?i)Copilot[^.\r\n]{0,60}\bno equivalent event\b'))
    Assert ($hits.Count -eq 1) "expected the dated section skipped and the live one kept, got $($hits.Count) hit(s)"
}

exit (Write-TestSummary 'VendorClaims.Tests')
