# Planted-defect tests for release.ps1's staged-set guard (B-80). Does NOT ship.
#
# The guard refuses a release whose index contains a gitlink (mode 160000) or a path outside where
# this repo keeps files. It sits at step 5, AFTER ~285s of gates, so exercising it by running a real
# release is impractical -- which is precisely how it would rot untested. Instead this extracts the
# guard region VERBATIM from release.ps1 and drives it against scratch git repos with the defect
# planted. A retyped copy would prove something about the copy; extraction means the code under test
# is the code that ships in the release path.
#
# What this proves: classification, refusal, exit code, index reset, and that the allowlist does not
# refuse real releases. What it does NOT prove: that step 5 binds $repo/$staged as expected -- only
# an end-to-end release does that, and one was run when this landed (see meta/BACKLOG.md, B-80).
#
# Wired into release.ps1 via Invoke-HookTests.ps1 auto-discovery, so the guard is re-verified at
# every release -- including the release that would be blocked by a regression in it.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path   # the ai-tech-lead repo root
$release  = Join-Path $repoRoot '.claude/scripts/release.ps1'

Reset-Tests

$text = [IO.File]::ReadAllText($release)

# --- extract the guard region ---------------------------------------------------------------------
# Bounded at BOTH ends and asserted in both directions. The first cut ended the region at the
# "# ---- 6." marker, which swept in step 5's commit+push: the green cases really committed and then
# failed to push to a nonexistent origin, and the marker check passed throughout because a too-LARGE
# region still contains every marker. An inert fixture and an over-broad one look identical from the
# summary line (B-75).
$start = $text.IndexOf('# ---- 5a.')
# Bounded at the step-5b marker, not at the commit line itself. When the CI watch (B-88) made the
# commit conditional (`if (-not $nothingToCommit) { ... }`), an end-bound on the commit line sliced
# the region mid-block and every case died with a ParserError -- a real failure, but one that reads
# like the guard broke rather than the bound. A step marker is the stable seam.
$end   = $text.IndexOf('# ---- 5b.')
$guard = $null
if ($start -ge 0 -and $end -gt $start) { $guard = $text.Substring($start, $end - $start) }

It 'the guard region can be extracted from release.ps1, and is neither too small nor too large' {
    Assert ($start -ge 0) 'no "# ---- 5a." marker in release.ps1 -- the guard was renamed or removed'
    Assert ($end -gt $start) 'no commit line found after the guard -- cannot bound the region'
    foreach ($needle in @('160000', 'AllowExtraStagedPaths', 'git -C $repo reset --quiet', 'Staged manifest')) {
        Assert ($guard -match [regex]::Escape($needle)) "extracted region is missing '$needle' -- would test nothing"
    }
    foreach ($forbidden in @('git -C $repo commit', 'git -C $repo push')) {
        Assert ($guard -notmatch [regex]::Escape($forbidden)) "extracted region wrongly includes '$forbidden' -- would test the commit, not the guard"
    }
}

function New-ScratchRepo {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("relguard-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    git -C $dir init -q
    git -C $dir config user.email 'test@example.invalid'
    git -C $dir config user.name  'test'
    New-Item -ItemType Directory -Path (Join-Path $dir 'src') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $dir 'src/thing.txt') -Value 'baseline'
    git -C $dir add -A; git -C $dir commit -qm init
    return $dir
}

# Run the extracted guard in a child host so `exit` is observable as an exit code rather than
# killing this suite.
function Invoke-Guard {
    param([string]$Repo, [switch]$AllowExtra)
    $body = @"
`$ErrorActionPreference = 'Stop'
`$repo = '$Repo'
`$AllowExtraStagedPaths = `$$($AllowExtra.IsPresent)
git -C `$repo add -A
`$staged = git -C `$repo diff --cached --name-only
if (-not `$staged) { Write-Host 'Nothing to commit.'; exit 0 }
# The region now reads `$nothingToCommit (it gates the staged manifest print). Bound it here: these
# cases all stage something, which is the only state in which the guard has anything to classify.
`$nothingToCommit = `$false
$guard
Write-Host 'GUARD PASSED'
exit 0
"@
    $f = Join-Path ([IO.Path]::GetTempPath()) ("relguard-run-" + [guid]::NewGuid().ToString('N') + '.ps1')
    [IO.File]::WriteAllText($f, $body, [Text.UTF8Encoding]::new($true))   # BOM: invariant #4
    try {
        $out  = & (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File $f 2>&1
        $code = $LASTEXITCODE
        return [pscustomobject]@{ Exit = $code; Out = ($out | Out-String) }
    } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
}

$scratch = @()
try {
    It 'a release touching only tracked locations passes, and prints a manifest' {
        $d = New-ScratchRepo; $script:scratch += $d
        Set-Content -LiteralPath (Join-Path $d 'src/thing.txt') -Value 'release change'
        $r = Invoke-Guard -Repo $d
        Assert ($r.Exit -eq 0) "expected EXIT=0, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'Staged manifest') 'no staged manifest printed'
    }

    It 'a stray untracked file is refused, the index is reset, and the worktree is untouched' {
        $d = New-ScratchRepo; $script:scratch += $d
        Set-Content -LiteralPath (Join-Path $d 'src/thing.txt') -Value 'release change'
        git -C $d add src/thing.txt
        $preStaged = (@(git -C $d diff --cached --name-only) -join ',')
        Assert ($preStaged -eq 'src/thing.txt') "pre-staged fixture is not in the index: '$preStaged'"
        Set-Content -LiteralPath (Join-Path $d 'scratch-notes.txt') -Value 'oops'
        $r = Invoke-Guard -Repo $d
        Assert ($r.Exit -eq 2) "expected EXIT=2, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'scratch-notes\.txt') 'the offending path is not named in the refusal'
        $idx = (@(git -C $d diff --cached --name-only) -join ',')
        Assert ([string]::IsNullOrWhiteSpace($idx)) "index not reset after refusal: '$idx'"
        $worktree = [IO.File]::ReadAllText((Join-Path $d 'src/thing.txt')).Trim()
        Assert ($worktree -eq 'release change') "pre-staged worktree content was lost: '$worktree'"
    }

    It 'a staged non-ASCII path under meta is classified as expected' {
        $d = New-ScratchRepo; $script:scratch += $d
        New-Item -ItemType Directory -Path (Join-Path $d 'meta') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $d 'meta/café.txt') -Value 'release evidence'
        $r = Invoke-Guard -Repo $d
        Assert ($r.Exit -eq 0) "expected EXIT=0, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'GUARD PASSED') 'legitimate non-ASCII path did not pass the guard'
    }

    It '-AllowExtraStagedPaths proceeds on a stray file, but still warns' {
        $d = New-ScratchRepo; $script:scratch += $d
        Set-Content -LiteralPath (Join-Path $d 'src/thing.txt') -Value 'release change'
        Set-Content -LiteralPath (Join-Path $d 'scratch-notes.txt') -Value 'oops'
        $r = Invoke-Guard -Repo $d -AllowExtra
        Assert ($r.Exit -eq 0) "expected EXIT=0, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'WARNING') 'proceeded silently -- the extra paths must still be announced'
    }

    # The defect v0.42.0 and v0.43.0 both shipped: a worktree under .claude/worktrees/ recorded as a
    # mode-160000 pointer to a directory that ceased to exist when the worktree was removed.
    It 'a worktree gitlink is refused, and -AllowExtraStagedPaths does NOT bypass it' {
        $d = New-ScratchRepo; $script:scratch += $d
        Set-Content -LiteralPath (Join-Path $d 'src/thing.txt') -Value 'release change'
        New-Item -ItemType Directory -Path (Join-Path $d '.claude') -Force | Out-Null
        git -C $d worktree add -q -b scratch-branch (Join-Path $d '.claude/worktrees/scratch') 2>&1 | Out-Null
        Assert (Test-Path -LiteralPath (Join-Path $d '.claude/worktrees/scratch')) 'worktree fixture was not created -- the case would pass vacuously'

        $r = Invoke-Guard -Repo $d
        Assert ($r.Exit -eq 2) "expected EXIT=2, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'gitlink') 'the refusal does not identify the entry as a gitlink'
        $idx = (@(git -C $d diff --cached --name-only) -join ',')
        Assert ([string]::IsNullOrWhiteSpace($idx)) "index not reset after refusal: '$idx'"

        $r2 = Invoke-Guard -Repo $d -AllowExtra
        Assert ($r2.Exit -eq 2) "the escape hatch bypassed the gitlink refusal (EXIT=$($r2.Exit)) -- it must not"
    }

    # --- the false-positive regression ------------------------------------------------------------
    # The check that matters most, and the one the guard's FIRST cut failed. Written from B-80's own
    # wording (src/, dist/, CHANGELOG.md, meta/context-footprint.json, the stamps), the allowlist
    # would have refused every release from v0.39.0 to v0.43.0 -- each touches README.md, and v0.41.0
    # also touched .claude/hooks/tests/. Verified: that pattern produces 10 false positives over the
    # same 266 paths this test replays. A guard that refuses correct releases gets its escape hatch
    # passed every time, and then it guards nothing.
    It 'the allowlist refuses none of a sufficient sample of real releases' {
        # @() is load-bearing twice over. Without it a single matching line is a bare [string] and
        # [0] yields its first CHARACTER, so the regex below extracts an EMPTY pattern -- and
        # `-notmatch ''` is never true, so this test reports zero false positives having classified
        # nothing. That is exactly what the first run of it did (the v0.41.0 RCA's class, one level up).
        $patternLine = @($text -split "`n" | Where-Object { $_ -match '^\$expectedPathPattern\s*=' })
        Assert (@($patternLine).Count -eq 1) "expected exactly one `$expectedPathPattern assignment, found $(@($patternLine).Count)"
        $pattern = [regex]::Match($patternLine[0], "'(.+)'").Groups[1].Value

        # Prove the pattern is real and discriminating BEFORE trusting a zero result from it.
        Assert (-not [string]::IsNullOrWhiteSpace($pattern)) 'extracted an EMPTY allowlist pattern -- every path would classify as expected'
        Assert ('src/core/CLAUDE.md' -match $pattern)   "extracted pattern rejects a known-good path: $pattern"
        Assert ('scratch-notes.txt' -notmatch $pattern) "extracted pattern accepts a known-bad path: $pattern"

        # Needs a clone WITH TAGS. `actions/checkout` defaults to `--depth=1 --no-tags`, so the
        # first CI run of this test failed on both legs while passing locally -- the test observed a
        # full clone and CI observed a shallow one. Kept as a hard failure rather than a skip: a
        # silent skip here means the allowlist regression check quietly stops running, which is the
        # exact thing it exists to prevent. The message has to name the cause, or the next person
        # reads "5 passed, 1 failed" and goes looking in release.ps1.
        # Walk tags newest-first and stop once the sample is big enough, rather than fixing the
        # window at 8 tags. The assertion below cares about PATHS -- it wants the allowlist exercised
        # against enough real release content to mean something -- and a fixed tag count is a proxy
        # for that which breaks the moment release granularity changes. It did: on 2026-08-21 seven
        # small releases shipped in one day, and the last 8 tags yielded 83 paths against a threshold
        # of 100, failing a release for a property nothing was actually wrong with. Cap the walk so a
        # repository with tiny tags cannot turn this into a full-history scan.
        $tagOutput = @(git -C $repoRoot tag --sort=-v:refname)
        $tagExit = $LASTEXITCODE
        Assert ($null -ne $tagExit -and $tagExit -eq 0) 'could not enumerate release tags for historical staging replay'
        $allTags = @($tagOutput | Select-Object -First 25)
        $releases = @(); $sampled = 0; $sampledInstallSh = $false
        for ($tagIndex = 0; $tagIndex -lt ($allTags.Count - 1); $tagIndex++) {
            $candidate = $allTags[$tagIndex]
            $previous = $allTags[$tagIndex + 1]
            # release.ps1 stages the complete snapshot delta since the preceding release. `git
            # show $candidate` inspects only the tagged commit and silently omits preparatory
            # commits, which made the supposedly permanent install.sh exception unreachable.
            $pathOutput = @(git -C $repoRoot diff --name-only $previous $candidate --)
            $diffExit = $LASTEXITCODE
            Assert ($null -ne $diffExit -and $diffExit -eq 0) "could not enumerate historical release range $previous..$candidate"
            $paths = @($pathOutput | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $releases += [pscustomobject]@{ Tag = $candidate; Base = $previous; Paths = $paths }
            $sampled += $paths.Count
            if ($paths -ccontains 'install.sh') { $sampledInstallSh = $true }
            if ($sampled -ge 100 -and @($releases).Count -ge 8 -and $sampledInstallSh) { break }
        }
        # The rolling sample proves breadth, while this immutable release range permanently proves
        # the install.sh exception. Without the fixed anchor, each new tag eventually pushes the
        # relevant release outside the 25-tag window and turns environment sampling into a false
        # product failure.
        if (-not $sampledInstallSh) {
            $anchorBase = 'v0.76.0'; $anchorTag = 'v0.77.0'
            $pathOutput = @(git -C $repoRoot diff --name-only $anchorBase $anchorTag --)
            $diffExit = $LASTEXITCODE
            Assert ($null -ne $diffExit -and $diffExit -eq 0) "could not enumerate immutable install.sh anchor $anchorBase..$anchorTag"
            $paths = @($pathOutput | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            $releases += [pscustomobject]@{ Tag = $anchorTag; Base = $anchorBase; Paths = $paths }
            $sampled += $paths.Count
            $sampledInstallSh = $paths -ccontains 'install.sh'
        }
        # Single-quoted on purpose: in a double-quoted PowerShell string a backtick starts an escape,
        # so "`fetch-depth" renders as a FORM FEED plus "etch-depth". The first cut of this message
        # said "etch-depth: 0" -- an error message about a misconfiguration, itself misconfigured.
        Assert (@($releases).Count -ge 5) (
            "only $(@($releases).Count) release range(s) resolved -- refusing to run a vacuous replay. " +
            'This needs a clone with tags: in CI set actions/checkout fetch-depth: 0 and ' +
            'fetch-tags: true; locally run "git fetch --tags". Nothing is wrong with release.ps1.')
        $falsePositives = @(); $historicalPaths = @(); $seen = 0; $historicalInstallSh = 0
        foreach ($releaseRange in $releases) {
            foreach ($f in $releaseRange.Paths) {
                $seen++
                $historicalPaths += $f
                if ($f -ceq 'install.sh') { $historicalInstallSh++ }
                if ($f -like '.claude/worktrees/*') { continue }               # the B-80 defect itself
                if ($f -notmatch $pattern) { $falsePositives += "$($releaseRange.Base)..$($releaseRange.Tag) : $f" }
            }
        }
        Assert ($seen -ge 100) "only $seen path(s) classified -- the replay is not exercising anything"
        Assert ($historicalInstallSh -gt 0) 'historical replay and immutable v0.76.0..v0.77.0 anchor did not reach install.sh; its permanent staging exception would be untested'
        $withoutInstallSh = $pattern.Replace('|install\.sh', '')
        Assert ($withoutInstallSh -cne $pattern) 'could not plant the install.sh allowlist-removal mutation'
        $mutantFalsePositives = @($historicalPaths | Where-Object { $_ -notmatch $withoutInstallSh })
        Assert (@($mutantFalsePositives | Where-Object { $_ -ceq 'install.sh' }).Count -gt 0) `
            'removing install.sh from the allowlist did not make the historical replay go red'
        Assert (@($falsePositives).Count -eq 0) ("the allowlist would have refused $(@($falsePositives).Count) real release path(s): " + (($falsePositives | Select-Object -Unique -First 8) -join '; '))
    }
} finally {
    foreach ($d in $scratch) {
        git -C $d worktree remove --force (Join-Path $d '.claude/worktrees/scratch') 2>&1 | Out-Null
        Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'ReleaseStagingGuard.Tests (B-80 staged-set guard)')
