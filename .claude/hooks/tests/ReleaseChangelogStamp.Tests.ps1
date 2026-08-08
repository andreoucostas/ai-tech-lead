# Isolated contract tests for release.ps1 changelog stamping. Does NOT run a release.
#
# The all-four case deliberately retains a bounded fallback to the pre-fix step-1 implementation:
# on an unfixed tree it executes the actual old code and exposes the defect (only root is dated).
# Once the release helpers exist, their AST extents are extracted verbatim and driven against
# scratch trees. A copied implementation could go green while release.ps1 remained broken.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$releasePath = Join-Path $repoRoot '.claude/scripts/release.ps1'

Reset-Tests

$releaseText = [IO.File]::ReadAllText($releasePath)
$tokens = $null
$parseErrors = $null
$releaseAst = [Management.Automation.Language.Parser]::ParseFile($releasePath, [ref]$tokens, [ref]$parseErrors)
$functionNames = @(
    'Get-ReleaseChangelogPaths',
    'Get-ReleaseChangelogHead',
    'Set-ReleaseChangelogHeads',
    'Test-ReleaseChangelogHeads'
)
$functionAsts = @($releaseAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        $functionNames -contains $node.Name
}, $true))
$functionsReady = ($parseErrors.Count -eq 0 -and $functionAsts.Count -eq $functionNames.Count)
if ($functionsReady) {
    foreach ($name in $functionNames) {
        $functionAst = @($functionAsts | Where-Object Name -eq $name)
        if ($functionAst.Count -ne 1) { $functionsReady = $false; break }
        . ([scriptblock]::Create($functionAst[0].Extent.Text))
    }
}

# The fallback is bounded by stable numbered release-step markers. It exists only to make the
# original root-only behavior an observable red; every post-fix assertion drives extracted helpers.
$step1Start = $releaseText.IndexOf('# ---- 1.')
$step1End = $releaseText.IndexOf('# ---- 2.')
$legacyStep1 = $null
if ($step1Start -ge 0 -and $step1End -gt $step1Start) {
    $legacyStep1 = $releaseText.Substring($step1Start, $step1End - $step1Start)
}

$version = '9.8.7'
$date = '2031-02-03'
$dists = @('dotnet', 'angular', 'monorepo')
$scratch = New-Object System.Collections.Generic.List[string]

function Write-Changelog {
    param([string]$Path, [string]$Head)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $body = "# Changelog`r`n`r`n$Head`r`n`r`n- Fixture.`r`n`r`n## 9.8.6 — 2030-01-01`r`n"
    [IO.File]::WriteAllText($Path, $body, (New-Object Text.UTF8Encoding($false)))
}

function New-ChangelogWorld {
    param([string]$Head = "## $version — Unreleased", [switch]$IncludeDist)
    $root = Join-Path ([IO.Path]::GetTempPath()) ('release-changelog-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $script:scratch.Add($root)
    Write-Changelog (Join-Path $root 'CHANGELOG.md') $Head
    foreach ($dist in $dists) {
        Write-Changelog (Join-Path $root "src/stacks/$dist/files/CHANGELOG.md") $Head
        if ($IncludeDist) { Write-Changelog (Join-Path $root "dist/$dist/CHANGELOG.md") $Head }
    }
    return $root
}

function Get-SourceChangelogPaths([string]$Root) {
    $paths = @((Join-Path $Root 'CHANGELOG.md'))
    foreach ($dist in $dists) { $paths += (Join-Path $Root "src/stacks/$dist/files/CHANGELOG.md") }
    return $paths
}

function Get-FirstH2([string]$Path) {
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line -match '^## ') { return $line }
    }
    return $null
}

function Invoke-StampFixture([string]$Root) {
    if ($functionsReady) {
        return Set-ReleaseChangelogHeads -Root $Root -Version $version -Date $date -Dists $dists
    }
    Assert ($null -ne $legacyStep1) 'cannot extract the original numbered step 1 from release.ps1'
    # All files are valid in the only case that uses this branch, so the old fatal exit is inert.
    return & {
        param($repo, $Version, $today, $dists, $body)
        $fatal = $false
        function Gate { param([bool]$Ok, [string]$What) if (-not $Ok) { throw "unexpected fixture refusal: $What" } }
        & ([scriptblock]::Create($body))
        [pscustomobject]@{ Ok = $true; Problems = @(); Stamped = 1; Legacy = $true }
    } $Root $version $date $dists $legacyStep1
}

try {
    It 'the bounded release stamp dates the root and all three authored consumer changelogs' {
        $root = New-ChangelogWorld
        $result = Invoke-StampFixture $root
        Assert $result.Ok ("stamp refused a valid world: " + (@($result.Problems) -join '; '))
        $wrong = @()
        foreach ($path in Get-SourceChangelogPaths $root) {
            $head = Get-FirstH2 $path
            if ($head -ne "## $version — $date") { $wrong += "$path => $head" }
        }
        $detail = if ($result.PSObject.Properties.Name -contains 'Legacy') {
            'unchanged bounded logic dated only root; consumer heads remain Unreleased: '
        } else { 'wrong dated heads: ' }
        Assert ($wrong.Count -eq 0) ($detail + ($wrong -join '; '))
        Assert ($result.Stamped -eq 4) "expected exactly four files stamped, got $($result.Stamped)"
    }

    It 'the extracted stamp refuses missing, mismatched, and malformed first heads atomically' {
        Assert $functionsReady ("release helper extraction failed; found $($functionAsts.Count) of $($functionNames.Count) functions")
        $cases = @(
            [pscustomobject]@{ Name = 'missing'; Change = { param($p) Remove-Item -LiteralPath $p -Force }; Expected = 'missing' },
            [pscustomobject]@{ Name = 'mismatched'; Change = { param($p) Write-Changelog $p '## 9.8.8 — Unreleased' }; Expected = 'version mismatch' },
            [pscustomobject]@{ Name = 'malformed'; Change = { param($p) Write-Changelog $p '## version 9.8.7 - Unreleased' }; Expected = 'malformed' }
        )
        foreach ($case in $cases) {
            $root = New-ChangelogWorld
            $badPath = Join-Path $root 'src/stacks/angular/files/CHANGELOG.md'
            & $case.Change $badPath
            $result = Set-ReleaseChangelogHeads -Root $root -Version $version -Date $date -Dists $dists
            Assert (-not $result.Ok) "$($case.Name) head was accepted"
            Assert ($result.Stamped -eq 0) "$($case.Name) refusal mutated $($result.Stamped) file(s)"
            Assert ((@($result.Problems) -join "`n") -match [regex]::Escape($case.Expected)) "$($case.Name) refusal did not identify '$($case.Expected)': $(@($result.Problems) -join '; ')"
            Assert ((Get-FirstH2 (Join-Path $root 'CHANGELOG.md')) -eq "## $version — Unreleased") "$($case.Name) refusal stamped root before validating all four inputs"
        }
    }

    It 'the composed source/dist postcondition rejects any planted Unreleased head and accepts the fully dated world' {
        Assert $functionsReady ("release helper extraction failed; found $($functionAsts.Count) of $($functionNames.Count) functions")
        $root = New-ChangelogWorld -Head "## $version — $date" -IncludeDist
        $clean = Test-ReleaseChangelogHeads -Root $root -Version $version -Date $date -Dists $dists -IncludeDist
        Assert $clean.Ok ("fully dated source/dist world was refused: " + (@($clean.Problems) -join '; '))

        foreach ($planted in @(
            (Join-Path $root 'src/stacks/dotnet/files/CHANGELOG.md'),
            (Join-Path $root 'dist/angular/CHANGELOG.md')
        )) {
            Write-Changelog $planted "## $version — Unreleased"
            $red = Test-ReleaseChangelogHeads -Root $root -Version $version -Date $date -Dists $dists -IncludeDist
            Assert (-not $red.Ok) "postcondition accepted planted Unreleased head at $planted"
            Assert ((@($red.Problems) -join "`n") -match [regex]::Escape($planted)) "postcondition did not name planted path $planted"
            Write-Changelog $planted "## $version — $date"
        }
        $green = Test-ReleaseChangelogHeads -Root $root -Version $version -Date $date -Dists $dists -IncludeDist
        Assert $green.Ok ("restored fully dated world was refused: " + (@($green.Problems) -join '; '))
    }
} finally {
    foreach ($dir in $scratch) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
}

$failures = Write-TestSummary 'Release changelog stamp tests'
exit $failures
