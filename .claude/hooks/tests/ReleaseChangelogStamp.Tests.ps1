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

$reviewFunctionAst = @($releaseAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
        $node.Name -eq 'Test-ReleaseReviewRecord'
}, $true))
$reviewFunctionReady = ($parseErrors.Count -eq 0 -and $reviewFunctionAst.Count -eq 1)
if ($reviewFunctionReady) {
    . ([scriptblock]::Create($reviewFunctionAst[0].Extent.Text))
}

# B-522: the pure delivery-number functions, extracted verbatim from release.ps1 like the helpers above.
$deliveryNames = @('Get-EscapedDefectCount', 'Get-ReleasesPerWeek', 'Get-ReleaseDeliveryNumbers', 'Format-ReleaseDeliveryLines')
$deliveryAsts = @($releaseAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $deliveryNames -contains $node.Name
}, $true))
$deliveryReady = ($parseErrors.Count -eq 0 -and $deliveryAsts.Count -eq $deliveryNames.Count)
if ($deliveryReady) { foreach ($a in $deliveryAsts) { . ([scriptblock]::Create($a.Extent.Text)) } }

# WSD-142: the host-smoke line, extracted verbatim and driven with fake check scripts.
$smokeAst = @($releaseAst.FindAll({
    param($node)
    $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-HostSmokeLine'
}, $true))
$smokeReady = ($parseErrors.Count -eq 0 -and $smokeAst.Count -eq 1)
if ($smokeReady) { . ([scriptblock]::Create($smokeAst[0].Extent.Text)) }

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
    It 'release retry recognizes existing review records without substring collisions' {
        Assert $reviewFunctionReady "release helper Test-ReleaseReviewRecord is missing or ambiguous (found $($reviewFunctionAst.Count))"
        $ledger = "| v0.78.0 | 2026-08-27 | reviewer: none |`n"
        Assert (Test-ReleaseReviewRecord -Text $ledger -Version '0.78.0') 'existing ledger row was not recognized'
        Assert (-not (Test-ReleaseReviewRecord -Text $ledger -Version '0.7')) 'ledger matcher accepted a version substring'
    }

    It 'the release commit subject carries the tier and is refused, not cut, past 72 characters' {
        $subjectAst = @($releaseAst.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Get-ReleaseCommitSubject' }, $true))
        Assert ($subjectAst.Count -eq 1) "release helper Get-ReleaseCommitSubject is missing or ambiguous (found $($subjectAst.Count))"
        . ([scriptblock]::Create($subjectAst[0].Extent.Text))
        $ok = Get-ReleaseCommitSubject -Version '1.2.3' -Summary 'short topic' -ReviewEvidence 'Guarded; reviewer none; a..b'
        Assert ($ok -ceq 'guarded: v1.2.3: short topic') "subject was '$ok'"
        $threw = $false
        try { Get-ReleaseCommitSubject -Version '1.2.3' -Summary 'x' -ReviewEvidence 'reviewer none; a..b' | Out-Null } catch { $threw = $true }
        Assert $threw 'a ReviewEvidence without a tier first field was accepted'
        $long = 'a' * 80
        $msg = ''
        try { Get-ReleaseCommitSubject -Version '1.2.3' -Summary $long -ReviewEvidence 'ordinary; reviewer none; a..b' | Out-Null } catch { $msg = $_.Exception.Message }
        Assert ($msg -match 'over the 72 limit') "an over-long subject was not refused: '$msg'"
        $edge = Get-ReleaseCommitSubject -Version '1.2.3' -Summary ('a' * (72 - 'ordinary: v1.2.3: '.Length)) -ReviewEvidence 'ordinary; none; r'
        Assert ($edge.Length -eq 72) 'a 72-character subject was refused'
        Assert ($releaseText -match [regex]::Escape('commit -m $releaseSubject')) 'the release commit does not use the checked subject'
    }

    It 'the release asks only for -ReviewEvidence, in the format AGENTS.md "Ship" names' {
        # AGENTS.md records absent review as "reviewer none" inside -ReviewEvidence; the old switch filed
        # a stub under a backlog heading that no longer exists.
        Assert ($releaseText -notmatch 'NoIndependentReview') 'release still offers -NoIndependentReview'
        Assert ($releaseText -match [regex]::Escape('-ReviewEvidence "<tier>; reviewer user|fresh session|none; <range>"')) 'the refusal does not give the AGENTS.md evidence format'
    }

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

    It 'a retry on a later calendar day accepts an already-consistently-stamped world without rewriting the date' {
        Assert $functionsReady ("release helper extraction failed; found $($functionAsts.Count) of $($functionNames.Count) functions")
        # Independent review (Opus) found this: the script's own banner promises "re-running the
        # same command as-is is safe", but requiring an already-stamped head to equal *today* broke
        # that for any retry crossing midnight -- a head correctly stamped yesterday read as a
        # "date mismatch" and refused, telling the operator to rewrite an already-published date.
        $laterDate = '2031-02-04'
        Assert ($laterDate -ne $date) 'fixture setup: retry date must differ from the original stamp date'

        # A prior successful run already stamped every head to $date; simulate the process being
        # re-invoked later with $today now $laterDate.
        $root = New-ChangelogWorld -Head "## $version — $date"
        $retry = Set-ReleaseChangelogHeads -Root $root -Version $version -Date $laterDate -Dists $dists
        Assert $retry.Ok ("retry on a later day refused an already-consistent world: " + (@($retry.Problems) -join '; '))
        Assert ($retry.Stamped -eq 0) "retry rewrote $($retry.Stamped) already-stamped file(s)"
        Assert ($retry.ResolvedDate -eq $date) "retry resolved to '$($retry.ResolvedDate)', expected the original stamp date '$date' to be preserved, not '$laterDate'"
        foreach ($path in Get-SourceChangelogPaths $root) {
            $head = Get-FirstH2 $path
            Assert ($head -eq "## $version — $date") "retry silently changed $path to '$head'"
        }

        # A genuine inconsistency -- not a clean retry -- must still be refused: two heads stamped to
        # different dates from each other.
        $mismatchRoot = New-ChangelogWorld -Head "## $version — $date"
        Write-Changelog (Join-Path $mismatchRoot 'src/stacks/angular/files/CHANGELOG.md') "## $version — $laterDate"
        $inconsistent = Set-ReleaseChangelogHeads -Root $mismatchRoot -Version $version -Date $laterDate -Dists $dists
        Assert (-not $inconsistent.Ok) 'two heads stamped to different dates from each other were accepted'
        Assert ((@($inconsistent.Problems) -join "`n") -match 'inconsistent stamped dates') "inconsistent-dates refusal did not name the defect: $(@($inconsistent.Problems) -join '; ')"

        # A genuine partial stamp -- some heads dated, one still Unreleased -- must also be refused,
        # not silently "completed" with a possibly-wrong date.
        $mixedRoot = New-ChangelogWorld -Head "## $version — $date"
        Write-Changelog (Join-Path $mixedRoot 'src/stacks/angular/files/CHANGELOG.md') "## $version — Unreleased"
        $mixed = Set-ReleaseChangelogHeads -Root $mixedRoot -Version $version -Date $laterDate -Dists $dists
        Assert (-not $mixed.Ok) 'a mix of dated and still-Unreleased heads was accepted'
        Assert ((@($mixed.Problems) -join "`n") -match 'mixed changelog head state') "mixed-state refusal did not name the defect: $(@($mixed.Problems) -join '; ')"
    }

    It 'the review-ledger row carries the resolved CHANGELOG date, not today, on a later-day retry' {
        Assert $reviewFunctionReady "release helper Test-ReleaseReviewRecord is missing or ambiguous (found $($reviewFunctionAst.Count))"
        $ledgerStart = $releaseText.IndexOf('# ---- 4b.')
        $ledgerEnd = $releaseText.IndexOf('# ---- 5. Commit')
        Assert ($ledgerStart -ge 0 -and $ledgerEnd -gt $ledgerStart) 'cannot extract release.ps1 step 4b'
        $region = $releaseText.Substring($ledgerStart, $ledgerEnd - $ledgerStart)
        $root = Join-Path ([IO.Path]::GetTempPath()) ('release-ledger-' + [guid]::NewGuid().ToString('N'))
        $scratch.Add($root)
        New-Item -ItemType Directory -Path (Join-Path $root 'meta') -Force | Out-Null
        $ledgerPath = Join-Path $root 'meta/review-ledger.md'
        [IO.File]::WriteAllText($ledgerPath, "| Release | Date | Evidence |`n|---|---|---|`n")
        & {
            param($repo, $Version, $ReviewEvidence, $today, $releaseDate, $body)
            & ([scriptblock]::Create($body)) 6>&1 | Out-Null
        } $root $version 'ordinary; reviewer none; a..b' '2031-02-04' $date $region
        $row = @([IO.File]::ReadAllLines($ledgerPath) | Where-Object { $_ -match "^\| v$([regex]::Escape($version)) \|" })
        Assert ($row.Count -eq 1) "expected one ledger row for v$version, got $($row.Count)"
        Assert ($row[0] -match "^\| v$([regex]::Escape($version)) \| $date \|") "ledger row is not dated the resolved CHANGELOG date ${date}: $($row[0])"
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

    It 'delivery numbers: the four values and the previous release come from tag dates, bodies and run timings' {
        Assert $deliveryReady "delivery helpers missing or ambiguous (found $($deliveryAsts.Count) of $($deliveryNames.Count))"
        $d = { param($s) [DateTimeOffset]::Parse($s, [Globalization.CultureInfo]::InvariantCulture) }
        $tags = @((& $d '2031-01-01T00:00:00Z'), (& $d '2031-01-10T00:00:00Z'), (& $d '2031-01-20T00:00:00Z'), (& $d '2031-02-03T00:00:00Z'), (& $d '2030-11-01T00:00:00Z'))
        $bodies = @("guarded: a`n`nEscaped defect: cause x.", "ordinary: b`n`nno defect here", "ordinary: c`n`nThe escaped defect word is mid-line only", "ordinary: d`n`nescaped defect. Cause y.")
        $now = Get-ReleaseDeliveryNumbers -In @{
            RunStart = (& $d '2031-02-03T10:00:00Z'); RunEnd = (& $d '2031-02-03T10:28:30Z')
            FirstChange = (& $d '2031-01-30T12:00:00Z'); TagDate = (& $d '2031-02-03T00:00:00Z')
            Bodies = $bodies; TagDates = $tags; Why = @{}
        }
        $text = @($now.Values | ForEach-Object { $_.Text })
        Assert ($text[0] -eq '28.5') "test-run minutes: $($text[0])"
        Assert ($text[1] -eq '3.5') "days to tag: $($text[1])"
        Assert ($text[2] -eq '2') "escaped defects (line-start marker only): $($text[2])"
        Assert ($text[3] -eq '0.75') "releases a week (3 tags in 28 days / 4): $($text[3])"
        $lines = @(Format-ReleaseDeliveryLines -Current $now -Previous $now -PreviousName 'v9.9.9')
        Assert ($lines.Count -eq 4 -and $lines[0] -match 'v9\.9\.9: 28\.5') "formatted lines: $($lines -join ' | ')"
    }

    It 'delivery numbers: a missing input prints unknown with its reason, never zero, and an empty body list is a real zero' {
        Assert $deliveryReady "delivery helpers missing or ambiguous (found $($deliveryAsts.Count) of $($deliveryNames.Count))"
        $r = Get-ReleaseDeliveryNumbers -In @{ Bodies = $null; TagDates = $null; Why = @{ Run = 'gh not installed'; Escaped = 'git log failed' } }
        $text = @($r.Values | ForEach-Object { $_.Text })
        Assert ($text[0] -eq 'unknown (gh not installed)') "run: $($text[0])"
        Assert ($text[1] -eq 'unknown (input missing)') "days: $($text[1])"
        Assert ($text[2] -eq 'unknown (git log failed)') "escaped: $($text[2])"
        Assert ($text[3] -like 'unknown*') "cadence: $($text[3])"
        Assert ($null -eq @($r.Values)[0].Value) 'an unknown value must be null, not 0'
        $zero = Get-ReleaseDeliveryNumbers -In @{ Bodies = @(); Why = @{} }
        Assert (@($zero.Values)[2].Text -eq '0') 'an empty body list must count as 0 escaped defects'
    }

    # Each fake records the -WorkRoot it was given, creates it, then ends as the case says.
    $smokeDir = Join-Path ([IO.Path]::GetTempPath()) ('host-smoke-line-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force -Path $smokeDir | Out-Null
    $scratch.Add($smokeDir)
    $newFake = {
        param([string]$Name, [string]$Ending)
        $path = Join-Path $smokeDir "$Name.ps1"
        $record = Join-Path $smokeDir "$Name.workroot"
        $body = "param([string]`$Dist, [string]`$WorkRoot)`r`n" +
            "New-Item -ItemType Directory -Force -Path `$WorkRoot | Out-Null`r`n" +
            "[IO.File]::WriteAllText('$record', `"`$Dist|`$WorkRoot`")`r`n" + $Ending
        [IO.File]::WriteAllText($path, $body, [Text.UTF8Encoding]::new($true))
        return [pscustomobject]@{ Path = $path; Record = $record }
    }
    $smokeCases = @(
        @{ Name = 'exit0'; Ending = "'LEG claude run PASS - x'; 'HOST-SMOKE PASS - claude, copilot'; exit 0"; Expect = 'pass'; Detail = 'claude, copilot' },
        @{ Name = 'exit1'; Ending = "'HOST-SMOKE FAIL - copilot planted-write'; exit 1"; Expect = 'host fault'; Detail = 'copilot planted-write' },
        @{ Name = 'exit2'; Ending = "'HOST-SMOKE CANNOT_EXAMINE - claude run'; exit 2"; Expect = 'could not examine'; Detail = 'claude run' },
        @{ Name = 'exit7'; Ending = "'HOST-SMOKE PASS - claude'; exit 7"; Expect = 'could not examine'; Detail = 'exit 7' },
        @{ Name = 'throws'; Ending = "throw 'smoke script blew up'"; Expect = 'could not examine'; Detail = 'no HOST-SMOKE line' }
    )

    foreach ($c in $smokeCases) {
        It "host smoke line: a check that ends '$($c.Name)' prints one '$($c.Expect)' line and cleans its work folder" {
            Assert $smokeReady "Invoke-HostSmokeLine missing or ambiguous in release.ps1 (found $($smokeAst.Count))"
            $fake = & $newFake $c.Name $c.Ending
            $line = @(Invoke-HostSmokeLine -ScriptPath $fake.Path)
            Assert ($line.Count -eq 1) "expected one line, got $($line.Count): $($line -join ' | ')"
            Assert ($line[0] -like "HOST-SMOKE $($c.Expect) (report only*") "line: $($line[0])"
            Assert ($line[0] -like "*$($c.Detail)*") "line does not carry '$($c.Detail)': $($line[0])"
            Assert (Test-Path -LiteralPath $fake.Record) 'the fake check was not run'
            $given = ([IO.File]::ReadAllText($fake.Record)) -split '\|', 2
            Assert ($given[0] -eq 'dotnet') "the check was not asked for dist/dotnet: '$($given[0])'"
            Assert ($given[1] -and -not (Test-Path -LiteralPath $given[1])) "the -WorkRoot was left behind: $($given[1])"
        }
    }

    It 'host smoke line: a check that prints more than one summary line reads as could not examine' {
        Assert $smokeReady "Invoke-HostSmokeLine missing or ambiguous in release.ps1 (found $($smokeAst.Count))"
        $fake = & $newFake 'twolines' "'HOST-SMOKE FAIL - copilot planted-write'; 'HOST-SMOKE PASS - claude, copilot'; exit 0"
        $line = @(Invoke-HostSmokeLine -ScriptPath $fake.Path)
        Assert ($line.Count -eq 1 -and $line[0] -like 'HOST-SMOKE could not examine (report only*2 HOST-SMOKE summary lines*') "two summaries: $($line -join ' | ')"
    }

    It 'host smoke line: a check that outlives the wait limit is killed and reads as could not examine, timed out' {
        Assert $smokeReady "Invoke-HostSmokeLine missing or ambiguous in release.ps1 (found $($smokeAst.Count))"
        $pidFile = Join-Path $smokeDir 'hang.pid'
        $fake = & $newFake 'hang' "[IO.File]::WriteAllText('$pidFile', [string]`$PID); Start-Sleep -Seconds 60; 'HOST-SMOKE PASS - claude, copilot'; exit 0"
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $line = @(Invoke-HostSmokeLine -ScriptPath $fake.Path -TimeoutSeconds 4)
        $took = $clock.Elapsed.TotalSeconds
        Assert ($line.Count -eq 1 -and $line[0] -like 'HOST-SMOKE could not examine (report only*timed out after 4 s*') "hang: $($line -join ' | ')"
        Assert ($took -lt 25) "the release waited $([int]$took) s on a check limited to 4 s"
        $hung = [int]([IO.File]::ReadAllText($pidFile))
        Assert (-not (Get-Process -Id $hung -ErrorAction SilentlyContinue)) "the timed-out check (pid $hung) is still running"
        $given = ([IO.File]::ReadAllText($fake.Record)) -split '\|', 2
        Assert ($given[1] -and -not (Test-Path -LiteralPath $given[1])) "the -WorkRoot was left behind: $($given[1])"
    }

    It 'host smoke line: a timed-out check dies with the process it started, and a pipe that process holds is not waited on' {
        Assert $smokeReady "Invoke-HostSmokeLine missing or ambiguous in release.ps1 (found $($smokeAst.Count))"
        # The fake starts a grandchild that inherits its output pipe and sleeps, then ends as the leg says.
        $spawn = {
            param([string]$PidFile)
            "`$gp = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id `$PID).Path); `$gp.UseShellExecute = `$false; " +
            "foreach (`$a in @('-NoProfile', '-Command', 'Start-Sleep -Seconds 60')) { [void]`$gp.ArgumentList.Add(`$a) }; " +
            "[IO.File]::WriteAllText('$PidFile', [string]([Diagnostics.Process]::Start(`$gp).Id)); "
        }
        $grandchildren = @()
        try {
            # Leg 1: the check hangs past the limit; the kill must take the grandchild with it.
            $treePid = Join-Path $smokeDir 'tree.pid'
            $fake = & $newFake 'tree' ((& $spawn $treePid) + "Start-Sleep -Seconds 60; exit 0")
            $clock = [Diagnostics.Stopwatch]::StartNew()
            $line = @(Invoke-HostSmokeLine -ScriptPath $fake.Path -TimeoutSeconds 6)
            $took = $clock.Elapsed.TotalSeconds
            $grandchildren += [int]([IO.File]::ReadAllText($treePid))
            Assert ($line.Count -eq 1 -and $line[0] -like 'HOST-SMOKE could not examine (report only*timed out after 6 s*') "tree: $($line -join ' | ')"
            Assert ($took -lt 25) "the release waited $([int]$took) s on a check limited to 6 s"
            $wait = [Diagnostics.Stopwatch]::StartNew()
            while ((Get-Process -Id $grandchildren[0] -ErrorAction SilentlyContinue) -and $wait.Elapsed.TotalSeconds -lt 5) { Start-Sleep -Milliseconds 200 }
            Assert (-not (Get-Process -Id $grandchildren[0] -ErrorAction SilentlyContinue)) "the process the timed-out check started (pid $($grandchildren[0])) is still running"
            # Leg 2: the check ends at once, but its grandchild keeps the output pipe open.
            $pipePid = Join-Path $smokeDir 'pipe.pid'
            $fake = & $newFake 'pipe' ((& $spawn $pipePid) + "'HOST-SMOKE PASS - claude, copilot'; exit 0")
            $clock = [Diagnostics.Stopwatch]::StartNew()
            $line = @(Invoke-HostSmokeLine -ScriptPath $fake.Path -OutputWaitSeconds 3)
            $took = $clock.Elapsed.TotalSeconds
            $grandchildren += [int]([IO.File]::ReadAllText($pipePid))
            Assert ($line.Count -eq 1 -and $line[0] -like "HOST-SMOKE could not examine (report only*output stayed open*") "pipe: $($line -join ' | ')"
            Assert ($took -lt 25) "the release waited $([int]$took) s on an output pipe capped at 3 s"
        } finally {
            foreach ($g in $grandchildren) { Stop-Process -Id $g -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'host smoke line: a missing check script or host program reads as could not examine, not a crash' {
        Assert $smokeReady "Invoke-HostSmokeLine missing or ambiguous in release.ps1 (found $($smokeAst.Count))"
        $missing = @(Invoke-HostSmokeLine -ScriptPath (Join-Path $smokeDir 'no-such-host-smoke.ps1'))
        Assert ($missing.Count -eq 1 -and $missing[0] -like 'HOST-SMOKE could not examine (report only*no check script*') "missing script: $($missing -join ' | ')"
        $fake = & $newFake 'nopwsh' "'HOST-SMOKE PASS - claude'; exit 0"
        $noHost = @(Invoke-HostSmokeLine -ScriptPath $fake.Path -PwshPath (Join-Path $smokeDir 'no-such-pwsh.exe'))
        Assert ($noHost.Count -eq 1 -and $noHost[0] -like 'HOST-SMOKE could not examine (report only*threw*') "missing program: $($noHost -join ' | ')"
    }

    It 'host smoke line: release.ps1 prints it after the local gates and before the commit and push, never exiting on it' {
        $gatesRefused = $releaseText.IndexOf('Release REFUSED: fix the failing gate(s)')
        $commitStep = $releaseText.IndexOf('# ---- 5. Commit + push')
        $call = [regex]::Matches($releaseText, '(?m)^Write-Host \(Invoke-HostSmokeLine -ScriptPath \(Join-Path \$repo ''\.claude/scripts/host-smoke\.ps1''\)\)\s*$')
        Assert ($call.Count -eq 1) "expected one top-level call printing the host-smoke line, found $($call.Count)"
        Assert ($gatesRefused -ge 0 -and $commitStep -gt $gatesRefused -and $call[0].Index -gt $gatesRefused -and $call[0].Index -lt $commitStep) 'the host-smoke line is not between the local gates and the commit/push step'
        Assert $smokeReady "Invoke-HostSmokeLine missing or ambiguous in release.ps1 (found $($smokeAst.Count))"
        $ends = @($smokeAst[0].FindAll({ param($n) $n -is [Management.Automation.Language.ExitStatementAst] -or $n -is [Management.Automation.Language.ThrowStatementAst] }, $true))
        Assert ($ends.Count -eq 0) "Invoke-HostSmokeLine has $($ends.Count) exit/throw statement(s), so it can change the release outcome"
    }
} finally {
    foreach ($dir in $scratch) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
}

$failures = Write-TestSummary 'Release changelog stamp tests'
exit $failures
