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

exit (Write-TestSummary 'DocClaims.Tests')
