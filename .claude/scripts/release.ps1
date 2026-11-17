# Meta release automation (maintainer-only, does NOT ship) — single-repo edition (WSD-012 D7,
# retargeted at B-25-EXEC Phase 5 from the dual-repo original, whose manual predecessor shipped
# stamp drift twice). Stamps, rebuilds, gates, commits, and pushes THIS repo, refusing to finish
# if any deterministic gate fails.
#
# Usage:  pwsh -NoProfile -File .claude/scripts/release.ps1 -Version 0.26.0 -Summary "one-line topic" [-NoPush]
# Precondition: the root CHANGELOG.md AND all three src/stacks/*/files/CHANGELOG.md already carry a
# "## <Version>" head entry (writing the entries is authoring work, not automation; a trailing
# "Unreleased" on any of them is stamped with the release date -- B-54: all four are mandatory, not
# just root) and the working tree contains exactly the release changes.
#
# Gates (in order): compose all three dists -> validate-dist ×3 + context footprint -> the three meta
# test files whose subject the release commit changes (B-245). The full root meta suite and the shipped
# hook suites run in CI: before a normal tag, CI must observe the
# three-dist hook matrices under PowerShell 7.
#
# PowerShell-only by decision (see meta/workspace-decisions.md): release/eval automation requires
# PowerShell 7, as every framework script does.
#Requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Summary,
    [switch]$NoPush,
    # Accepted and ignored: B-511 deleted the post-success eval prompt it suppressed, which never
    # fired. AGENTS.md "Ship" still passes it; B-521 gives it a meaning again.
    [switch]$NoEvals,
    # Escape hatch for the branch precondition below. Deliberately named for what it risks, not for
    # what it enables -- releasing off master is how v0.34.0 lost its release commit.
    [switch]$AllowNonMasterHead,
    # The review evidence AGENTS.md "Ship" asks for, "<tier>; reviewer user|fresh session|none; <range>",
    # recorded verbatim in meta/review-ledger.md. The script can expose presence or absence, not judge
    # evidence quality.
    # NOT [Parameter(Mandatory)] -- that prompts, and a prompt hangs a non-interactive release. The
    # precondition below refuses instead.
    [string]$ReviewEvidence,
    # Escape hatch for the staged-set precondition at step 5 (B-80), named for what it risks: the
    # release commit will carry files that are not part of a release. There is deliberately NO
    # escape hatch for a staged gitlink -- see that check for why.
    [switch]$AllowExtraStagedPaths,
    # Escape hatch for the CI watch at step 5c (B-88), named for what it risks: the release will be
    # tagged without anyone having observed CI. This is a WAIVER, deliberately not the same fact as
    # CANT-VERIFY -- it is recorded in the tag's own annotation so the waiver travels with the
    # artifact whose meaning it changes.
    [switch]$AllowUnverifiedCi
)
$ErrorActionPreference = 'Stop'

$repo  = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$dists = @('dotnet', 'angular', 'monorepo')
$today = Get-Date -Format 'yyyy-MM-dd'
$fatal = $false
function Gate($ok, $what) { if ($ok) { Write-Host "GATE ok:   $what" } else { Write-Host "GATE FAIL: $what"; $script:fatal = $true } }

function Test-ReleaseReviewRecord {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Version
    )
    return [regex]::IsMatch($Text, "(?m)^\| v$([regex]::Escape($Version)) \|")
}

# Stage timing is printed for the maintainer to read; no stage time refuses a release.
function Measure-Stage([string]$Name, [scriptblock]$Body) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try { & $Body } finally {
        $sw.Stop()
        Write-Host ("TIME  {0,-18} {1,7:N1}s" -f $Name, $sw.Elapsed.TotalSeconds)
    }
}

# ---- 0. Reject a path-expanded -Summary (B-73) -----------------------------------------------
# A leading slash-command was once rewritten to a filesystem path before PowerShell received it;
# v0.40.0 shipped that path in its commit subject. Keep the input invariant even though the
# originating shell is no longer a supported framework execution path.
# Every slash-command this framework documents (/bootstrap, /adopt, /review, /fix, /feature,
# /design, /debt, /map-warehouse) triggers it. Neither the Git install path nor the repo path can
# legitimately appear in a release summary, so treat either as proof of conversion and refuse.
. (Join-Path $PSScriptRoot '_commit-subject.ps1')
if ((Test-MsysMangledSubject $Summary) -or $Summary -like "*$repo*") {
    [Console]::Error.WriteLine(@"
FATAL: -Summary contains a filesystem path that cannot be intentional:
  $Summary
Invoke release.ps1 from PowerShell directly and pass a plain-language summary; lead any referenced
slash command with a non-slash word.
"@)
    exit 2
}

# ---- 0a1. Require review evidence (B-45) ----
# AGENTS.md "Ship": the release records the tier, the reviewer (user, fresh session, or none) and the
# range. This gate cannot judge independence or evidence quality; it makes only the ABSENCE of an
# answer impossible to ship silently.
$hasEvidence = -not [string]::IsNullOrWhiteSpace($ReviewEvidence)
if (-not $hasEvidence) {
    [Console]::Error.WriteLine(@"
FATAL: no review evidence. Nothing has been stamped or committed.

AGENTS.md "Ship": re-run with
  -ReviewEvidence "<tier>; reviewer user|fresh session|none; <range>"
It is recorded verbatim in meta/review-ledger.md; "reviewer none" is a legitimate answer, recorded
as given.
"@)
    exit 2
}

# ---- 0a2. HEAD must be on master (B-53) ----
# Two real failures come from releasing while HEAD is not master's tip, and neither is theoretical:
#
#   * DETACHED HEAD (B-53, four occurrences). The commit lands on the detached HEAD, `push origin
#     master` then pushes the *unchanged* master ref, exits 0, and the script prints
#     "Release complete" having shipped nothing. The usual cause is a Claude Code scratchpad
#     worktree holding the master branch, which forces this working directory to detach.
#   * A FEATURE/PR BRANCH. v0.34.0 was released on a branch that was then squash-merged; GitHub
#     replaced the release commit's subject with the PR title ("... (meta-only) (#5)") and the
#     release commit ceased to exist as such. That release has no release commit on master to this
#     day -- found only when the B-51 tag backfill went looking for it.
#
# Refuse before anything is stamped, so a refusal costs nothing and leaves no half-released tree.
$branch = (git -C $repo rev-parse --abbrev-ref HEAD 2>$null)
if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine('FATAL: not a git repository.'); exit 2 }
$branch = "$branch".Trim()
if ($branch -ne 'master') {
    if ($AllowNonMasterHead) {
        Write-Host "WARNING: HEAD is '$branch', not master. Proceeding because -AllowNonMasterHead was passed."
        Write-Host '         If this branch is later squash-merged, the release commit will not survive as such.'
    } else {
        [Console]::Error.WriteLine("FATAL: HEAD is '$branch', not master -- refusing to release.")
        if ($branch -eq 'HEAD') {
            [Console]::Error.WriteLine('HEAD is DETACHED. The usual cause is another worktree holding the master branch:')
            git -C $repo worktree list | ForEach-Object { [Console]::Error.WriteLine("  $_") }
            [Console]::Error.WriteLine('Free it non-destructively (do NOT delete the worktree), then re-attach here:')
            [Console]::Error.WriteLine('  git -C <that-worktree> checkout --detach')
            [Console]::Error.WriteLine('  git checkout master && git merge --ff-only <this-sha>')
        } else {
            [Console]::Error.WriteLine('Release from master. Releasing on a branch that is later squash-merged destroys')
            [Console]::Error.WriteLine('the release commit (this is what happened to v0.34.0). Merge first, then release.')
        }
        [Console]::Error.WriteLine('Override only if you understand the above: -AllowNonMasterHead')
        exit 2
    }
}

# ---- 0b. State the runtime up front (B-73) ----
# The first v0.40.0 attempt was killed at a 10-minute caller timeout mid-gates, which is
# indistinguishable from a gate failure and leaves a stamped, rebuilt tree that looks like a botched
# release. Say what runs before the operator starts waiting; dist-gates dominates the wait.
# Runtime is dominated by process creation, not CPU: the hook suites spawn a fresh PowerShell
# process per assertion. The attempted representative sequential suite
# was functionally green (20 files, 0 failures) but took 924.1s and made dist-gates 1004.0s, so it
# is not a useful local gate. Since B-245 the local meta suite is the release-subject files
# (13.2s serial for four, 2026-09-19); CI owns the full meta suite and all shipped-hook coverage on the
# release commit before the tag. Re-measure before changing this banner.
Write-Host "Releasing $Version. Local gates: compose x3 -> validate-dist x3 + context footprint -> release-subject meta files (DocTruth, ReleaseChangelogStamp, WorkspaceBom)."
Write-Host "Before a normal tag, CI must pass all four Windows contexts: root plus three shipped-hook matrices under PowerShell 7."
# The interruption promise used to be "nothing has been committed", full stop. After the push that is
# simply false, and B-88 makes the window longer by adding a multi-minute wait to it. State the three
# durable states instead; all three are safe to re-run the same command from (step 5 now falls
# through to the publish phase rather than exiting when there is nothing left to stage).
Write-Host "If interrupted, you are in exactly one of three states, and re-running the same command as-is is safe in all of them:"
Write-Host "  before 'Staged manifest'         -> nothing committed."
Write-Host "  after  'origin/master confirmed' -> the release is on master but UNTAGGED (CI unverified)."
Write-Host "  after  'Tag ... confirmed'       -> released; a re-run is a no-op."

# ---- 1. Root + authored consumer CHANGELOG heads must already exist ----
# These helpers are deliberately side-effect bounded. ReleaseChangelogStamp.Tests extracts their
# AST extents and drives them against scratch trees, so the red/green instrument exercises the
# release implementation without running a release.
function Get-ReleaseChangelogPaths {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Dists,
        [switch]$IncludeDist
    )
    [pscustomobject]@{ Label = 'root'; Path = (Join-Path $Root 'CHANGELOG.md') }
    foreach ($distName in $Dists) {
        [pscustomobject]@{
            Label = "source/$distName"
            Path  = (Join-Path $Root "src/stacks/$distName/files/CHANGELOG.md")
        }
    }
    if ($IncludeDist) {
        foreach ($distName in $Dists) {
            [pscustomobject]@{
                Label = "dist/$distName"
                Path  = (Join-Path $Root "dist/$distName/CHANGELOG.md")
            }
        }
    }
}

function Get-ReleaseChangelogHead {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{ Valid = $false; Problem = "missing changelog: $Path"; Path = $Path }
    }
    try {
        $text = [IO.File]::ReadAllText($Path)
    } catch {
        return [pscustomobject]@{ Valid = $false; Problem = "cannot read changelog: $Path ($($_.Exception.Message))"; Path = $Path }
    }

    # The first H2 is the release head. Require the whole line, rather than accepting a semver
    # prefix followed by arbitrary text or replacing every duplicate copy of the line in the file.
    $heading = [regex]::Match($text, '(?m)^## [^\r\n]*')
    if (-not $heading.Success) {
        return [pscustomobject]@{ Valid = $false; Problem = "malformed changelog head: $Path (no H2 heading)"; Path = $Path }
    }
    if ($heading.Value -notmatch '^## ([0-9]+\.[0-9]+\.[0-9]+) — (Unreleased|[0-9]{4}-[0-9]{2}-[0-9]{2})$') {
        return [pscustomobject]@{ Valid = $false; Problem = "malformed changelog head: $Path ('$($heading.Value)')"; Path = $Path }
    }
    return [pscustomobject]@{
        Valid       = $true
        Problem     = $null
        Path        = $Path
        Text        = $text
        MatchIndex  = $heading.Index
        MatchLength = $heading.Length
        Version     = $Matches[1]
        Status      = $Matches[2]
    }
}

function Set-ReleaseChangelogHeads {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Date,
        [Parameter(Mandatory)][string[]]$Dists
    )
    $heads = @()
    $problems = @()
    foreach ($entry in @(Get-ReleaseChangelogPaths -Root $Root -Dists $Dists)) {
        $head = Get-ReleaseChangelogHead -Path $entry.Path
        if (-not $head.Valid) {
            $problems += $head.Problem
            continue
        }
        if ($head.Version -ne $Version) {
            $problems += "version mismatch: $($entry.Path) (expected $Version, found $($head.Version))"
            continue
        }
        $heads += $head
    }
    if ($problems.Count -gt 0) {
        return [pscustomobject]@{ Ok = $false; Problems = @($problems); Stamped = 0; ResolvedDate = $Date }
    }

    # A retry after a gate failure re-runs this exact function on a later invocation -- possibly a
    # later calendar day, since investigating a red gate is not bounded to minutes. Requiring an
    # already-stamped head to equal *today* broke the script's own documented "re-running the same
    # command as-is is safe" promise: a head correctly stamped yesterday would read as a mismatch and
    # refuse, telling the operator to "correct" a date that was already right. Instead, accept any
    # single already-agreeing stamped date as the resolved release date; only a genuine mix -- heads
    # disagreeing with each other, or some dated and others still Unreleased -- is a real
    # inconsistency (the atomic write below should make that mix unreachable in practice, but it is
    # not proof against an interrupted write, so it is still validated explicitly rather than assumed).
    $datedValues = @($heads | Where-Object { $_.Status -ne 'Unreleased' } | ForEach-Object { $_.Status } | Sort-Object -Unique)
    $unreleasedCount = @($heads | Where-Object { $_.Status -eq 'Unreleased' }).Count
    if ($datedValues.Count -gt 1) {
        return [pscustomobject]@{ Ok = $false; Problems = @("inconsistent stamped dates across changelog heads: $($datedValues -join ', ')"); Stamped = 0; ResolvedDate = $Date }
    }
    if ($datedValues.Count -eq 1 -and $unreleasedCount -gt 0) {
        return [pscustomobject]@{ Ok = $false; Problems = @("mixed changelog head state: some heads already dated $($datedValues[0]), others still Unreleased -- a prior stamp did not reach every file"); Stamped = 0; ResolvedDate = $Date }
    }
    $resolvedDate = if ($datedValues.Count -eq 1) { $datedValues[0] } else { $Date }

    # Validate the complete four-file set before writing any one file. A refusal must not leave a
    # half-dated release tree that looks as though it progressed further than it did.
    $stamped = 0
    foreach ($head in $heads) {
        if ($head.Status -eq 'Unreleased') {
            $datedHead = "## $Version — $resolvedDate"
            $updated = $head.Text.Remove($head.MatchIndex, $head.MatchLength).Insert($head.MatchIndex, $datedHead)
            [IO.File]::WriteAllText($head.Path, $updated)
            $stamped++
        }
    }
    return [pscustomobject]@{ Ok = $true; Problems = @(); Stamped = $stamped; ResolvedDate = $resolvedDate }
}

function Test-ReleaseChangelogHeads {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Version,
        [Parameter(Mandatory)][string]$Date,
        [Parameter(Mandatory)][string[]]$Dists,
        [switch]$IncludeDist
    )
    $problems = @()
    foreach ($entry in @(Get-ReleaseChangelogPaths -Root $Root -Dists $Dists -IncludeDist:$IncludeDist)) {
        $head = Get-ReleaseChangelogHead -Path $entry.Path
        if (-not $head.Valid) {
            $problems += $head.Problem
        } elseif ($head.Version -ne $Version) {
            $problems += "version mismatch: $($entry.Path) (expected $Version, found $($head.Version))"
        } elseif ($head.Status -ne $Date) {
            $problems += "date mismatch: $($entry.Path) (expected $Date, found $($head.Status))"
        }
    }
    return [pscustomobject]@{ Ok = ($problems.Count -eq 0); Problems = @($problems) }
}

$changelogStamp = Set-ReleaseChangelogHeads -Root $repo -Version $Version -Date $today -Dists $dists
$releaseDate = $changelogStamp.ResolvedDate
Gate $changelogStamp.Ok "root + three source consumer CHANGELOG heads are ## $Version — $releaseDate"
if (-not $changelogStamp.Ok) {
    foreach ($problem in $changelogStamp.Problems) { Write-Host "  $problem" }
}
if ($fatal) { Write-Host "`nWrite or correct every CHANGELOG head first, then re-run."; exit 1 }
if ($changelogStamp.Stamped -gt 0) {
    Write-Host "Stamped $($changelogStamp.Stamped) CHANGELOG head(s) Unreleased -> $releaseDate."
} else {
    Write-Host "All four authored CHANGELOG heads were already stamped $releaseDate (release retry)."
}

# ---- 2. Stamp src: core AGENTS.md header + the three framework-version.json overlays ----
$cl  = Join-Path $repo 'src/core/AGENTS.md'
$txt = [System.IO.File]::ReadAllText($cl)
$txt = [regex]::Replace($txt, '(?m)^(\s*version:\s*)\S+', "`${1}$Version", 1)
$txt = [regex]::Replace($txt, '(?m)^(\s*applied:\s*)\S+', "`${1}$releaseDate", 1)
[System.IO.File]::WriteAllText($cl, $txt)
foreach ($d in $dists) {
    $fv = Join-Path $repo "src/stacks/$d/files/.claude/framework-version.json"
    $jt = [System.IO.File]::ReadAllText($fv)
    $jt = [regex]::Replace($jt, '"version"\s*:\s*"[^"]*"', "`"version`": `"$Version`"")
    $jt = [regex]::Replace($jt, '"applied"\s*:\s*"[^"]*"', "`"applied`": `"$releaseDate`"")
    [System.IO.File]::WriteAllText($fv, $jt)
}
# The root README states the shipped version in prose. It was hand-maintained, so it drifted (it
# claimed v0.26.1 against a shipped v0.26.2). DocTruth.Tests now fails the release on that drift --
# which would make every release trip a gate the maintainer then hand-fixes. Stamp it here instead:
# the only durable fix for a stamp that drifts is to stop maintaining it by hand.
$rm = Join-Path $repo 'README.md'
$rt = [System.IO.File]::ReadAllText($rm)
$versionLinePattern = '(Current shipped version is \*\*v)([0-9]+\.[0-9]+\.[0-9]+)(\*\*)'
$versionLine = [regex]::Match($rt, $versionLinePattern)
if (-not $versionLine.Success) {
    [Console]::Error.WriteLine("FATAL: README.md has no 'Current shipped version is **vX.Y.Z**' line to stamp -- it was reworded, so the stamp (and DocTruth's check of it) is now blind. Restore the line or update both.")
    exit 2
}
if ($versionLine.Groups[2].Value -eq $Version) {
    Write-Host "README already stamped $Version (retry after a refused release)."
} else {
    $stamped = [regex]::Replace($rt, $versionLinePattern, "`${1}$Version`${3}", 1)
    [System.IO.File]::WriteAllText($rm, $stamped)
    Write-Host "Stamped src + root README -> $Version ($releaseDate)."
}

# ---- 3. Rebuild all three dists (the stamp must flow src -> dist in this same commit) ----
Measure-Stage 'compose' {
    # The append-only retirement check is anchored to the previous release, named here, not found by the composer.
    # HEAD is the untagged commit being released (the tag is created after CI), so describing from HEAD yields the previous release; CI describes from HEAD^ because its HEAD can carry a tag.
    $previousRelease = (git -C $repo describe --tags --abbrev=0 --match 'v[0-9]*' HEAD)
    Gate ($LASTEXITCODE -eq 0 -and [bool]$previousRelease) 'a v[0-9]* release tag is reachable from HEAD (retirement baseline)'
    foreach ($d in $dists) {
        if (-not $previousRelease) { break }
        & pwsh -NoProfile -File (Join-Path $repo 'scripts/build.ps1') $d -RetirementBaselineRef $previousRelease
        Gate ($LASTEXITCODE -eq 0) "compose dist/$d"
    }
}
if ($fatal) {
    Write-Host "`nRelease REFUSED: the composer failed. Nothing was committed."
    Write-Host 'Fix the failing gate, then re-run the same release command as-is.'
    exit 1
}

# The release boundary is the composed tree, not merely its authored inputs. Refuse before any gate
# or commit if the exact target head did not flow to every generated consumer CHANGELOG.
$changelogPostcondition = Test-ReleaseChangelogHeads -Root $repo -Version $Version -Date $releaseDate -Dists $dists -IncludeDist
Gate $changelogPostcondition.Ok "root + source + composed CHANGELOG heads are ## $Version — $releaseDate"
if (-not $changelogPostcondition.Ok) {
    foreach ($problem in $changelogPostcondition.Problems) { Write-Host "  $problem" }
}
if ($fatal) {
    Write-Host "`nRelease REFUSED: the composed CHANGELOG postcondition failed. Nothing was committed."
    Write-Host 'Fix the changelog source/composition defect, then re-run the same release command as-is.'
    exit 1
}

# ---- 4. Deterministic gates: validate-dist per dist and the context-footprint baseline, then the
# three meta test files whose subject the release commit changes.
#
# The footprint re-measure (which must run after the version stamps have flowed into dist, and whose
# baseline lands in the release commit) is independent of the validators: it writes
# meta/context-footprint.json, which no gate reads, so it rides alongside the three bounded validator
# jobs. Shipped hook suites are deliberately absent from this local stage: a measured sequential
# monorepo attempt was green but cost 924.1s (1004.0s for dist-gates). CI is the all-dist/all-host
# proof required before tag, and it runs the full root meta suite on the release commit.
Measure-Stage 'dist-gates' {
$footprintLog = $null
$footprintJob = $null
$distGateJobs = @()
try {
    $footprintLog = [System.IO.Path]::GetTempFileName()
    $footprintJob = Start-Job -ArgumentList $repo, $footprintLog -ScriptBlock {
        param($repo, $log)
        & pwsh -NoProfile -File (Join-Path $repo 'scripts/context-footprint.ps1') -Update *> $log
        $LASTEXITCODE
    }
    $distGateJobs = foreach ($d in $dists) {
        $log = [System.IO.Path]::GetTempFileName()
        $job = Start-Job -ArgumentList $repo, $d, $log -ScriptBlock {
            param($repo, $dist, $log)
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            & pwsh -NoProfile -File (Join-Path $repo 'scripts/validate-dist.ps1') $dist *> $log
            $validateExit = $LASTEXITCODE
            $validateSeconds = $sw.Elapsed.TotalSeconds
            $sw.Stop()
            [pscustomobject]@{
                ValidateExit    = $validateExit
                ValidateSeconds = $validateSeconds
            }
        }
        [pscustomobject]@{ Dist = $d; Log = $log; Job = $job }
    }
    $distGateJobs.Job | Wait-Job | Out-Null
    foreach ($distGateJob in $distGateJobs) {
        $result = Receive-Job $distGateJob.Job
        Write-Host -NoNewline ([System.IO.File]::ReadAllText($distGateJob.Log))
        $d = $distGateJob.Dist
        # Keep timing on its own line: RESULT parsing is anchored at both ends (B-151).
        # The job wall clock is what the stage spends, while the inner measurement isolates
        # the validator. They will not be equal: job scheduling and pwsh startup sit outside the
        # stopwatch, and that gap is evidence rather than arithmetic to hide.
        $jobSeconds = if ($distGateJob.Job.PSEndTime -and $distGateJob.Job.PSBeginTime) {
            ($distGateJob.Job.PSEndTime - $distGateJob.Job.PSBeginTime).TotalSeconds
        } else { 0 }
        # F1 in the invariant culture: N1 groups thousands, `-f` uses the current culture (B-510).
        Write-Host ([string]::Format([cultureinfo]::InvariantCulture, 'TIMING {0} {1:F1}', $d, $jobSeconds))
        Write-Host ([string]::Format([cultureinfo]::InvariantCulture, 'TIMING {0}/validate-dist {1:F1}', $d, [double]$result.ValidateSeconds))
        Gate ($result.ValidateExit -eq 0) "validate-dist $d"
    }
    $footprintJob | Wait-Job | Out-Null
    $footprintExit = Receive-Job $footprintJob
    Write-Host -NoNewline ([System.IO.File]::ReadAllText($footprintLog))
    $footprintSeconds = if ($footprintJob.PSEndTime -and $footprintJob.PSBeginTime) {
        ($footprintJob.PSEndTime - $footprintJob.PSBeginTime).TotalSeconds
    } else { 0 }
    Write-Host ([string]::Format([cultureinfo]::InvariantCulture, 'TIMING context-footprint {0:F1}', $footprintSeconds))
    Gate ($footprintExit -eq 0) 'update context-footprint baseline'
} finally {
    if ($distGateJobs) {
        $distGateJobs.Job | Remove-Job -Force
        $distGateJobs.Log | Remove-Item -Force
    }
    if ($footprintJob) { $footprintJob | Remove-Job -Force }
    if ($footprintLog) { Remove-Item -LiteralPath $footprintLog -Force -ErrorAction SilentlyContinue }
}
}
Measure-Stage 'meta-suite' {
$metaLog = [System.IO.Path]::GetTempFileName()
try {
    # B-245: locally, only the files whose subject the release commit itself changes -- version
    # stamps and changelog heads, new .ps1 bytes. CI runs the whole suite on the
    # release commit, and the tag still waits for that run. -File is single-valued, so one run each.
    $localMetaFiles = @('DocTruth.Tests.ps1', 'ReleaseChangelogStamp.Tests.ps1', 'WorkspaceBom.Tests.ps1')
    $metaExit = 0; $metaText = ''
    foreach ($metaFile in $localMetaFiles) {
        & pwsh -NoProfile -File (Join-Path $repo '.claude/hooks/tests/Invoke-HookTests.ps1') -File $metaFile *> $metaLog
        $metaExit += [int]$LASTEXITCODE
        $metaText += [System.IO.File]::ReadAllText($metaLog)
    }
    Write-Host -NoNewline $metaText
    Gate ($metaExit -eq 0) 'meta-hook test suite'
} finally {
    Remove-Item -LiteralPath $metaLog -Force -ErrorAction SilentlyContinue
}
}

if ($fatal) {
    Write-Host "`nRelease REFUSED: fix the failing gate(s) and re-run. Nothing was committed."
    Write-Host 'Once fixed, re-run the same release command as-is.'
    exit 1
}

# ---- 4b. Record the supplied review evidence (B-45) ----
# Written after the gates pass and before `git add -A`, so the ledger row lands in the release
# commit itself -- a claim about a release that is not in that release's commit is not evidence.
$ledger = Join-Path $repo 'meta/review-ledger.md'
if (-not (Test-Path -LiteralPath $ledger -PathType Leaf)) {
    Write-Host "`nRelease REFUSED: meta/review-ledger.md is missing; restore it from Git. Nothing was committed."
    exit 1
}
# Collapse to one line and escape the cell delimiter so the row cannot break the table.
$evidenceCell = $ReviewEvidence -replace '\r?\n', ' ' -replace '\|', '\|'
$ledgerText = [IO.File]::ReadAllText($ledger)
if (Test-ReleaseReviewRecord -Text $ledgerText -Version $Version) {
    Write-Host "Review ledger: existing v$Version row retained (release retry)."
} else {
    Add-Content -LiteralPath $ledger -Value "| v$Version | $releaseDate | $evidenceCell |" -Encoding utf8
    Write-Host "Review ledger: $evidenceCell"
}

# ---- 5. Commit + push ----
# An index entry flagged assume-unchanged (`ls-files -v` tag h) or skip-worktree (S) tells git the file
# equals the index, so `add -A` and `status --porcelain` never see a change to it: it is left out of
# the release commit, or, with nothing else staged, the resume path below reads "tree equals HEAD" and
# tags the commit before the release (B-464). Any flagged path is refused, not only one whose bytes
# differ: proving a difference past the flag means re-hashing around filters, modes and deletions, and
# the gates ran on working-tree bytes the flag lets differ from what is committed.
$lsFiles = @(git -C $repo -c core.quotepath=false ls-files -v)
$lsExit = $LASTEXITCODE
if ($lsExit -ne 0) {
    [Console]::Error.WriteLine("FATAL: git ls-files -v failed (exit $lsExit); cannot tell whether an index flag hides a tracked change; nothing was committed.")
    exit 2
}
$flagged = @($lsFiles | Where-Object { $_ -cmatch '^[a-zS] ' })
if ($flagged.Count -gt 0) {
    $more = if ($flagged.Count -gt 10) { " ... and $($flagged.Count - 10) more" } else { '' }
    [Console]::Error.WriteLine("FATAL: $($flagged.Count) tracked path(s) carry an index flag that hides working-tree changes from git add and git status; nothing was committed. Flagged (tag path): $(($flagged | Select-Object -First 10) -join '; ')$more")
    [Console]::Error.WriteLine("Clear each, then re-run the same command: git update-index --no-assume-unchanged -- <path> (tag h), git update-index --no-skip-worktree -- <path> (tag S); a path can carry both flags, so run both.")
    exit 2
}
git -C $repo add -A
$addExit = $LASTEXITCODE
$staged = git -C $repo diff --cached --name-only
$diffExit = $LASTEXITCODE
# A failed add (a held .git/index.lock) stages nothing, which the resume path below would read as
# "the release commit already exists" and tag the commit BEFORE the release (B-464 A1).
if ($addExit -ne 0 -or $diffExit -ne 0) {
    [Console]::Error.WriteLine("FATAL: git add -A or git diff --cached failed (exit $addExit / $diffExit); nothing was committed. Clear any .git/index.lock and re-run the same command.")
    exit 2
}
# This used to `exit 0` here. With a CI watch in the publish phase (step 5c) that stranded every
# recovery: CI goes red -> the maintainer fixes it in a separate commit -> re-runs the release ->
# nothing left to stage -> exit 0, never tagged, printed as if it had released. So it falls THROUGH
# to push -> watch -> tag instead. Every downstream step is already idempotent: the push is a no-op
# plus a verified postcondition, the watch re-reads a terminal run in seconds, and the tag block was
# built idempotent by design (see step 5b).
$nothingToCommit = -not $staged
if ($nothingToCommit) {
    # Nothing staged only means "already committed" when the tree equals HEAD.
    $dirty = @(git -C $repo status --porcelain)
    if ($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0) {
        [Console]::Error.WriteLine("FATAL: nothing was staged but the working tree differs from HEAD (or git status failed); nothing was committed. Refusing to resume the publish phase for a commit that lacks this release's changes.")
        exit 2
    }
    Write-Host 'Nothing new to stage -- resuming the publish phase for HEAD (push -> CI watch -> tag).'
}

# ---- 5a. Inspect what `git add -A` actually staged (B-80) ----
# The blanket `add -A` above is deliberate: the release commit must carry the stamps, the rebuilt
# dist/, and the footprint baseline together, and enumerating them would rot. The cost is that it
# also sweeps in whatever else happens to be sitting in the tree, and until now the script printed
# no manifest, so nothing surfaced it. v0.42.0 and v0.43.0 each shipped a stray worktree gitlink
# that way; it was noticed only when removing the worktrees showed two tracked deletions.
#
# Classification has to happen HERE, after staging, not before: a worktree directory that has not
# been added is merely untracked, and mode 160000 only exists once it is in the index (verified
# against commit 90f331d, where both strays present as ":160000 000000 ... D"). On any refusal we
# `git reset`, leaving the index empty while preserving every worktree change.
#
# `git diff --cached --raw` emits ":<srcmode> <dstmode> <srcsha> <dstsha> <status>\t<path>", and for
# a rename/copy a SECOND tab-separated path follows. Split on tab and take the LAST field so the
# destination path is what gets classified.
$rawStaged = @(git -C $repo -c core.quotepath=false diff --cached --raw)
$gitlinks  = @()
$unexpected = @()
# Where this repo legitimately keeps files -- the six tracked top-level directories and the ten
# tracked root files, as they actually exist, not as a stamped-file list would have it.
#
# The first cut of this check used B-80's own wording (src/, dist/, CHANGELOG.md,
# meta/context-footprint.json, the version stamps) and was WRONG: replayed against the real history
# it would have refused every release from v0.39.0 to v0.43.0. Each touches README.md; v0.41.0 also
# touched .claude/hooks/tests/. A release commit carries the whole session's work -- gate scripts,
# root docs, meta hooks -- not just the stamped set. A guard that refuses correct releases gets
# disabled, and then it guards nothing.
#
# So the question this asks is not "is this file part of a release?" (unanswerable) but "is this
# file somewhere this repo keeps files at all?" -- which is exactly the scratch-file/temp-output
# hazard B-80 describes. Keep it in sync if the repo grows a top-level directory; a legitimate new
# one failing here once is the cheap direction of that error.
$expectedPathPattern = '^(?:(?:\.claude|\.github|dist|meta|scripts|src)/|(?:\.gitattributes|\.gitignore|AGENTS\.md|CHANGELOG\.md|CLAUDE\.md|DEVELOPING\.md|LICENSE|README\.md|install\.ps1|install\.sh)$)'
foreach ($line in $rawStaged) {
    if ($line -notmatch '^:') { continue }
    $fields = $line -split "`t"
    $path   = $fields[-1]
    # Field 0 is ":<srcmode> <dstmode> <srcsha> <dstsha> <status>". A deletion has dstmode 000000,
    # so check srcmode too -- an untracked-then-deleted gitlink is still a gitlink we staged.
    $modes = ($fields[0].TrimStart(':') -split '\s+')
    if ($modes[0] -eq '160000' -or $modes[1] -eq '160000') { $gitlinks += $path; continue }
    if ($path -notmatch $expectedPathPattern) { $unexpected += $path }
}
# @() is load-bearing here for the same reason it is in the shipped test harness: under Windows
# PowerShell 5.1 a pipeline yielding exactly ONE object has no .Count and returns $null. One stray
# file is the single most likely shape of this defect, so a bare .Count would go silent on precisely
# the case worth catching. (The v0.41.0 RCA; B-82 repeats the warning.)
if (-not $nothingToCommit) {
    Write-Host ''
    Write-Host ("Staged manifest ({0} path(s)):" -f @($staged).Count)
    foreach ($p in @($staged)) { Write-Host "  $p" }
}
if (@($gitlinks).Count -gt 0) {
    # No escape hatch, by design. This repo has no submodules, so a mode-160000 entry is ALWAYS a
    # mistake -- there is no legitimate release in which one appears, and the two that shipped were
    # pointers to directories that ceased to exist the moment the worktree was removed.
    git -C $repo reset --quiet
    [Console]::Error.WriteLine(@"
FATAL: the index contains $(@($gitlinks).Count) gitlink(s) (mode 160000) -- refusing to release.
$($gitlinks | ForEach-Object { "  $_" } | Out-String)
This repo has no submodules, so a gitlink is always a mistake -- almost always a git worktree left
under the tree when `git add -A` ran. v0.42.0 and v0.43.0 both shipped one. There is no override:
remove the worktree (git worktree remove <path>, or git worktree prune) and re-run the same command.
The index has been reset; nothing was committed.
"@)
    exit 2
}
if (@($unexpected).Count -gt 0) {
    if ($AllowExtraStagedPaths) {
        Write-Host ("WARNING: {0} staged path(s) are outside what a release touches. Proceeding because -AllowExtraStagedPaths was passed:" -f @($unexpected).Count)
        foreach ($p in $unexpected) { Write-Host "         $p" }
    } else {
        git -C $repo reset --quiet
        [Console]::Error.WriteLine(@"
FATAL: $(@($unexpected).Count) staged path(s) are outside where this repo keeps files -- refusing.
$($unexpected | ForEach-Object { "  $_" } | Out-String)
Tracked content lives in .claude/ .github/ dist/ meta/ scripts/ src/ or one of the ten tracked root
files. `git add -A` sweeps in anything else present -- scratch files, editor backups, temp output.

Either remove/ignore them and re-run the same command, or, if they genuinely belong in this
release, re-run with -AllowExtraStagedPaths.
The index has been reset; nothing was committed.
"@)
        exit 2
    }
}
# ---- 5b. Commit -- skipped when resuming a release whose commit already exists ----
if (-not $nothingToCommit) {
    Write-Host ''
    # "all gates green" must stop being said the moment it stops being true; the commit body names
    # exactly what this release did and did not prove.
    $gateNote = 'Released via .claude/scripts/release.ps1 — all local deterministic gates green (compose ×3, validate-dist ×3 + context footprint, the three release-subject meta test files). No shipped dist hook suite runs locally; normal tagging waits for CI''s PowerShell 7 three-dist hook matrices.'
    git -C $repo commit -m "v${Version}: $Summary" -m $gateNote
    if ($LASTEXITCODE -ne 0) { Write-Host 'Commit FAILED.'; exit 1 }
}
# Bound OUTSIDE the -NoPush branch below: step 5c needs it in every mode, and a variable that
# exists only on one path is how a message ends up printing an empty sha.
$releaseCommit = (git -C $repo rev-parse HEAD).Trim()
if (-not $NoPush) {
    $outgoingCheck = Join-Path $repo '.claude/scripts/check-outgoing-commits.ps1'
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $outgoingCheck `
        -RepoRoot $repo -Remote origin -Revision $releaseCommit
    if ($LASTEXITCODE -ne 0) { Write-Host "Push REFUSED: outgoing-commit check exited $LASTEXITCODE."; exit $LASTEXITCODE }
    # Push the COMMIT, not the branch name (B-53). `push origin master` pushes whatever the local
    # master ref points at -- which, on a detached HEAD, is not the commit just created. That is how
    # a release exited 0 and printed "complete" having shipped nothing.
    git -C $repo push origin "${releaseCommit}:refs/heads/master"
    if ($LASTEXITCODE -ne 0) { Write-Host 'Push FAILED.'; exit 1 }
    # Postcondition: prove origin actually advanced. An exit code of 0 from push is not proof --
    # the whole of B-53 is that the one thing this script exists to guarantee went unverified.
    $remoteMaster = (git -C $repo ls-remote origin refs/heads/master | ForEach-Object { ($_ -split '\s+')[0] })
    if ("$remoteMaster".Trim() -ne $releaseCommit) {
        Write-Host "Push POSTCONDITION FAILED: origin/master is $remoteMaster, expected $releaseCommit."
        Write-Host 'The release is committed locally but did NOT reach origin. Do not treat this as shipped.'
        exit 1
    }
    Write-Host "origin/master confirmed at $($releaseCommit.Substring(0,7))."
}

# ---- 5c. Watch CI for the release commit, and let it decide whether we tag (B-88) ----
# v0.44.0 was released, tagged, pushed and reported green while CI went RED on both legs -- and so
# did the three commits after it. Four consecutive red runs on master, unnoticed for over an hour,
# and only because the maintainer asked. Every local gate had passed: "Release complete" was a
# statement about this box, not about the repo.
#
# WHY THE WATCH SITS HERE, and not after the tag as the backlog entry originally said. Step 5b's own
# comment claims "a tag always means a green release". Watching after the tag push would make that
# sentence false -- a red release would still carry a release tag, and the quarterly drill protocol
# checks out the latest tag. So the tag becomes the PROMOTION step: it is created only once CI has
# been observed green. The commit still lands and still gets pushed exactly as before (the freshness
# gate needs the commit to exist); it is the TAG that now waits.
#
# What this does NOT do, stated plainly: it does not PREVENT a red commit reaching master. This
# script pushes directly to master by decision -- releasing on a branch is what destroyed v0.34.0's
# release commit -- so a red release is detected and left untagged, not stopped. It also narrows,
# but does not close, the "a test never exercised on a CI leg" gap.
. (Join-Path $repo '.claude/scripts/_ci-decision.ps1')
if ($NoPush) {
    $ciDecision = Get-CiPublishDecision -Mode NoPush
} elseif ($AllowUnverifiedCi) {
    $ciDecision = Get-CiPublishDecision -Mode Override
} else {
    & pwsh -NoProfile -File (Join-Path $repo '.claude/scripts/watch-ci.ps1') -Sha $releaseCommit
    $ciDecision = Get-CiPublishDecision -Mode Watched -WatchExit $LASTEXITCODE
}
Write-Host ''
Write-Host "CI: $($ciDecision.Status) -- $($ciDecision.Message)"
if (-not $ciDecision.Tag) {
    Write-Host ''
    Write-Host "Release $Version is ON MASTER but NOT TAGGED."
    Write-Host "  The commit is pushed and public; only the release tag is withheld."
    Write-Host "  Fix the break, then re-run the SAME command -- it will re-watch and tag if CI is green:"
    Write-Host "    pwsh -NoProfile -File .claude/scripts/release.ps1 -Version $Version -Summary `"$Summary`" ..."
    Write-Host "  Or watch it yourself:  pwsh -NoProfile -File .claude/scripts/watch-ci.ps1 -Sha $($releaseCommit.Substring(0,7))"
    Write-Host "  Tag anyway, recording the waiver in the tag itself:  -AllowUnverifiedCi"
    exit $ciDecision.ReleaseExit
}

# ---- 5d. Tag the release (B-51) ----
# Renumbered from 5b when the CI watch landed: the step markers now run in the order the steps
# actually execute (5a guard -> 5b commit -> push -> 5c watch -> 5d tag), because a marker order that
# contradicts the execution order is a trap for the next reader of a script this consequential.
# Tags stopped at v0.26.0 and 14 releases shipped untagged, so the B-49 drill protocol -- which
# requires a clean checkout of the latest released tag -- had to fall back to a raw SHA. The tag is
# created only after every gate and the commit have succeeded, so a tag always means a green release.
# Idempotent by design: a re-run after a partial failure must not fail on an existing correct tag,
# but a tag pointing somewhere else is a real conflict and is never silently moved.
$tagName     = "v$Version"
# The commit step 5c watched, never a re-read of HEAD (B-237). The watch takes minutes and the
# checkout is shared: at v0.86.5 another task committed during it, HEAD moved, and the unwatched
# follow-up was published as the CI-verified release.
$releaseSha  = $releaseCommit
# NOTE the ^{commit} peel: for an ANNOTATED tag, `rev-parse refs/tags/x` returns the tag OBJECT's
# sha, not the commit's. Without peeling, the equality below never matches, every retry takes the
# "tag exists elsewhere" branch, and a re-run after an interrupted release is refused outright --
# which is exactly the situation this release path has already hit once. Caught by the red test.
$existingSha = (git -C $repo rev-parse -q --verify "refs/tags/$tagName^{commit}" 2>$null)
if ($existingSha) {
    $existingSha = $existingSha.Trim()
    if ($existingSha -eq $releaseSha) {
        Write-Host "Tag $tagName already present at the release commit (retry) -- not recreated."
    } else {
        Write-Host "Tag FAILED: $tagName already exists at $($existingSha.Substring(0,7)) but the release commit is $($releaseSha.Substring(0,7))."
        Write-Host 'Refusing to move an existing release tag. Resolve by hand, then re-run.'
        exit 1
    }
} else {
    # The annotation carries the CI verdict (B-88). A normal tag means CI observed green, including
    # its complete PowerShell 7 × three-dist hook matrices. The two exception paths -- an operator
    # waiver or a -NoPush local tag -- must say that those matrices were not verified on the artifact.
    $ciMatrixNote = if ($ciDecision.Status -eq 'GREEN') {
        ' — CI verified root meta suites plus shipped hook suites for dotnet, angular, and monorepo under PowerShell 7 before tag'
    } else {
        ' — CI full hook matrix not verified (see CI waiver/status)'
    }
    git -C $repo tag -a $tagName -m "ai-tech-lead $tagName$($ciDecision.TagNote)$ciMatrixNote" $releaseSha
    if ($LASTEXITCODE -ne 0) { Write-Host "Tag FAILED: could not create $tagName."; exit 1 }
    Write-Host "Tagged $tagName at $($releaseSha.Substring(0,7))."
}
if (-not $NoPush) {
    & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File `
        (Join-Path $repo '.claude/scripts/check-outgoing-commits.ps1') `
        -RepoRoot $repo -Remote origin -Revision $releaseSha -AlwaysInspectRevision
    if ($LASTEXITCODE -ne 0) { Write-Host "Tag push REFUSED: outgoing-commit check exited $LASTEXITCODE."; exit $LASTEXITCODE }
    git -C $repo push origin "refs/tags/$tagName"
    if ($LASTEXITCODE -ne 0) { Write-Host "Tag push FAILED: $tagName exists locally but not on origin."; exit 1 }
    # A tag that exists only locally is the failure this entry is about, so verify rather than assume.
    $remoteTag = (git -C $repo ls-remote --tags origin "refs/tags/$tagName")
    if (-not $remoteTag) { Write-Host "Tag push reported success but origin has no $tagName."; exit 1 }
    Write-Host "Tag $tagName confirmed on origin."
}

Write-Host "`nRelease $Version complete$(if ($NoPush) { ' (not pushed: -NoPush)' })."
exit 0
