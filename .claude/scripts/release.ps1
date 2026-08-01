# Meta release automation (maintainer-only, does NOT ship) — single-repo edition (WSD-012 D7,
# retargeted at B-25-EXEC Phase 5 from the dual-repo original, whose manual predecessor shipped
# stamp drift twice). Stamps, rebuilds, gates, commits, and pushes THIS repo, refusing to finish
# if any deterministic gate fails.
#
# Usage:  pwsh -NoProfile -File .claude/scripts/release.ps1 -Version 0.26.0 -Summary "one-line topic" [-NoPush]
# Precondition: the ROOT CHANGELOG.md already carries a "## <Version>" head entry (writing the
# entry is authoring work, not automation; a trailing "Unreleased" on that line is stamped with
# today's date) and the working tree contains exactly the release changes.
#
# Gates (in order): compose all three dists -> validate-dist ×3 -> hook suites ×3 -> meta suite.
# fidelity-check is deliberately NOT run here: it is the migration-era gate pinned to the
# freeze-v0.25.5 tags, and the first release that changes shipped content must consciously
# retire/re-baseline it (and the CI fidelity legs) in the same change — see WSD-016.
#
# PowerShell-only by decision (see meta/workspace-decisions.md): meta scripts run only on the
# maintainer's box; invariant #3 twin parity applies to shipped hooks/scripts and scripts/.
param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Summary,
    [switch]$NoPush,
    # Escape hatch for the branch precondition below. Deliberately named for what it risks, not for
    # what it enables -- releasing off master is how v0.34.0 lost its release commit.
    [switch]$AllowNonMasterHead,
    # The reviewer's evidence: the gate/red-test they re-ran INDEPENDENTLY, its observed exit code,
    # and who implemented vs who reviewed. Recorded verbatim in meta/review-ledger.md.
    # NOT [Parameter(Mandatory)] -- that prompts, and a prompt hangs a non-interactive release. The
    # precondition below refuses instead.
    [string]$ReviewEvidence,
    # Escape hatch for that precondition, named for what it risks. Releasing without an independent
    # review is allowed -- it is sometimes the right call -- but it is never silent: the ledger
    # records that none happened and a post-ship review item is filed automatically.
    [switch]$NoIndependentReview
)
$ErrorActionPreference = 'Stop'

$repo  = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$dists = @('dotnet', 'angular', 'monorepo')
$today = Get-Date -Format 'yyyy-MM-dd'
$fatal = $false
function Gate($ok, $what) { if ($ok) { Write-Host "GATE ok:   $what" } else { Write-Host "GATE FAIL: $what"; $script:fatal = $true } }

# ---- 0. Reject a -Summary mangled by MSYS path conversion (B-73) ----
# Invoked from Git Bash, an argument that begins with "/" is rewritten to a Windows path before
# pwsh ever sees it: -Summary "/bootstrap and /adopt ..." arrived as
# "C:/Program Files/Git/bootstrap and /adopt ...". v0.40.0 shipped with that in its commit subject.
# Only the FIRST such token is converted, so the result reads as a typo rather than a tooling bug.
# Every slash-command this framework documents (/bootstrap, /adopt, /review, /fix, /feature,
# /design, /debt, /map-warehouse) triggers it. Neither the Git install path nor the repo path can
# legitimately appear in a release summary, so treat either as proof of conversion and refuse.
$gitRootPattern = '(?i)(Program Files[\\/]+Git|Git[\\/]+usr[\\/]+bin|[A-Za-z]:[\\/]+.*[\\/]+(?:bootstrap|adopt|review|fix|feature|design|debt|map-warehouse)\b)'
if ($Summary -match $gitRootPattern -or $Summary -like "*$repo*") {
    [Console]::Error.WriteLine(@"
FATAL: -Summary looks MSYS-mangled -- it contains a filesystem path that cannot be intentional:
  $Summary
Git Bash rewrites a leading "/word" argument into a Windows path. Re-run with the conversion off:
  MSYS_NO_PATHCONV=1 pwsh -NoProfile -File .claude/scripts/release.ps1 -Version $Version -Summary "..."
or invoke from PowerShell directly, or lead the summary with a non-slash word.
"@)
    exit 2
}

# ---- 0a1. Require review evidence, or an explicit acknowledgement that there was none (B-45) ----
# Maintenance model #2/#3: the reviewer must be a different session and must have re-run something
# themselves. Prose could not hold this -- invariant #6 was written down from the start and still
# shipped ~190 leaking lines -- so it is enforced where every shipped change already passes.
# This gate does NOT judge whether the review was good; no gate here does (no-meta-leak does not
# prove good prose either). It makes the ABSENCE of a review impossible to ship silently.
$hasEvidence = -not [string]::IsNullOrWhiteSpace($ReviewEvidence)
if ($hasEvidence -and $NoIndependentReview) {
    [Console]::Error.WriteLine(
        "FATAL: pass -ReviewEvidence OR -NoIndependentReview, not both. They record opposite facts.")
    exit 2
}
if (-not $hasEvidence -and -not $NoIndependentReview) {
    [Console]::Error.WriteLine(@"
FATAL: no review evidence. Nothing has been stamped or committed.

Maintenance model #2/#3 (root CLAUDE.md): the implementer's self-report is not evidence -- it has
been a false pass twice, both times because the check ran in a sandbox whose PATH differed from the
real environment. A different session must have re-run at least one gate and one red-test.

Re-run with the reviewer's evidence:
  -ReviewEvidence "reviewer <who>; re-ran <command>; EXIT=<code>; implementer <who>"

Or acknowledge there was none -- allowed, never silent:
  -NoIndependentReview
which records "reviewer: none" in meta/review-ledger.md and files a post-ship review item.
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
# The gate sequence runs ~30 minutes; the first v0.40.0 attempt was killed at a 10-minute caller
# timeout mid-gates, which is indistinguishable from a gate failure and leaves a stamped, rebuilt
# tree that looks like a botched release. Say so before the operator starts waiting.
# Runtime is dominated by process creation, not CPU: the hook suites spawn a fresh pwsh (~265ms on
# the maintainer box) or bash (~55ms) per assertion. Measured end to end at v0.43.0: ~6 min total.
# This banner read "roughly 30 minutes" for a long time and had never been measured -- it was ~4x
# the truth. If you change the gates, re-measure and update this rather than padding it: an estimate
# this wrong is what makes a release feel unaffordable and invites skipping it.
Write-Host "Releasing $Version. Gates take roughly 5-7 minutes (compose x3 -> validate-dist x3 -> hook suites x3 -> meta suite -> eval self-test)."
Write-Host "If this is interrupted before 'Release $Version complete', nothing has been committed -- re-run the same command as-is."

# ---- 1. Root CHANGELOG head entry must already exist ----
$clPath = Join-Path $repo 'CHANGELOG.md'
$head = $null; $headLine = $null
foreach ($l in (Get-Content $clPath)) { if ($l -match '^## (\d+\.\d+\.\d+)') { $head = $Matches[1]; $headLine = $l; break } }
Gate ($head -eq $Version) "root CHANGELOG head entry is ## $Version (found: $head)"
if ($fatal) { Write-Host "`nWrite the CHANGELOG entry first, then re-run."; exit 1 }

if ($headLine -match 'Unreleased') {
    $txt = [System.IO.File]::ReadAllText($clPath)
    $txt = $txt.Replace($headLine, ($headLine -replace 'Unreleased', $today))
    [System.IO.File]::WriteAllText($clPath, $txt)
    Write-Host "Stamped CHANGELOG head entry Unreleased -> $today."
}

# ---- 2. Stamp src: core CLAUDE.md header + the three framework-version.json overlays ----
$cl  = Join-Path $repo 'src/core/CLAUDE.md'
$txt = [System.IO.File]::ReadAllText($cl)
$txt = [regex]::Replace($txt, '(?m)^(\s*version:\s*)\S+', "`${1}$Version", 1)
$txt = [regex]::Replace($txt, '(?m)^(\s*applied:\s*)\S+', "`${1}$today", 1)
[System.IO.File]::WriteAllText($cl, $txt)
foreach ($d in $dists) {
    $fv = Join-Path $repo "src/stacks/$d/files/.claude/framework-version.json"
    $jt = [System.IO.File]::ReadAllText($fv)
    $jt = [regex]::Replace($jt, '"version"\s*:\s*"[^"]*"', "`"version`": `"$Version`"")
    $jt = [regex]::Replace($jt, '"applied"\s*:\s*"[^"]*"', "`"applied`": `"$today`"")
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
    Write-Host "Stamped src + root README -> $Version ($today)."
}

# ---- 3. Rebuild all three dists (the stamp must flow src -> dist in this same commit) ----
foreach ($d in $dists) {
    & pwsh -NoProfile -File (Join-Path $repo 'scripts/build.ps1') $d
    Gate ($LASTEXITCODE -eq 0) "compose dist/$d"
}
if ($fatal) {
    Write-Host "`nRelease REFUSED: the composer failed. Nothing was committed."
    Write-Host 'Fix the failing gate, then re-run the same release command as-is.'
    exit 1
}

# ---- 4. Deterministic gates: validate-dist + hook suite per dist, the context-footprint baseline,
# then the meta suite.
#
# The footprint re-measure (which must run after the version stamps have flowed into dist, and whose
# baseline lands in the release commit) is independent of the dist gates: it writes
# meta/context-footprint.json, which no gate reads. It used to run serially ahead of them and cost
# its full ~39s of wall time; it now rides along with the dist legs.
#
# Each dist suite is handed a share of the machine rather than all three assuming they own it. The
# suites are bound by process creation, not CPU -- every assertion spawns a fresh pwsh or bash -- so
# three suites at the full default lane count oversubscribe and every lane gets slower.
try {
    $footprintLog = [System.IO.Path]::GetTempFileName()
    $footprintJob = Start-Job -ArgumentList $repo, $footprintLog -ScriptBlock {
        param($repo, $log)
        & pwsh -NoProfile -File (Join-Path $repo 'scripts/context-footprint.ps1') -Update *> $log
        $LASTEXITCODE
    }
    $lanes = [math]::Max(2, [int]([Environment]::ProcessorCount / $dists.Count))
    $distGateJobs = foreach ($d in $dists) {
        $log = [System.IO.Path]::GetTempFileName()
        $job = Start-Job -ArgumentList $repo, $d, $log, $lanes -ScriptBlock {
            param($repo, $dist, $log, $lanes)
            $env:HOOKTESTS_THROTTLE = "$lanes"
            & pwsh -NoProfile -File (Join-Path $repo 'scripts/validate-dist.ps1') $dist *> $log
            $validateExit = $LASTEXITCODE
            & pwsh -NoProfile -File (Join-Path $repo "dist/$dist/tests/hooks/Invoke-HookTests.ps1") *>> $log
            [pscustomobject]@{
                ValidateExit = $validateExit
                HookExit     = $LASTEXITCODE
            }
        }
        [pscustomobject]@{ Dist = $d; Log = $log; Job = $job }
    }
    $distGateJobs.Job | Wait-Job | Out-Null
    foreach ($distGateJob in $distGateJobs) {
        $result = Receive-Job $distGateJob.Job
        Write-Host -NoNewline ([System.IO.File]::ReadAllText($distGateJob.Log))
        $d = $distGateJob.Dist
        Gate ($result.ValidateExit -eq 0) "validate-dist $d"
        Gate ($result.HookExit -eq 0) "dist/$d hook test suite"
    }
    $footprintJob | Wait-Job | Out-Null
    $footprintExit = Receive-Job $footprintJob
    Write-Host -NoNewline ([System.IO.File]::ReadAllText($footprintLog))
    Gate ($footprintExit -eq 0) 'update context-footprint baseline'
} finally {
    if ($distGateJobs) {
        $distGateJobs.Job | Remove-Job -Force
        $distGateJobs.Log | Remove-Item -Force
    }
    if ($footprintJob) { $footprintJob | Remove-Job -Force }
    if ($footprintLog) { Remove-Item -LiteralPath $footprintLog -Force -ErrorAction SilentlyContinue }
}
& pwsh -NoProfile -File (Join-Path $repo '.claude/hooks/tests/Invoke-HookTests.ps1')
Gate ($LASTEXITCODE -eq 0) 'meta-hook test suite'
& pwsh -NoProfile -File (Join-Path $repo '.claude/evals/run-agent-evals.ps1') -SelfTest
Gate ($LASTEXITCODE -eq 0) 'agent-eval harness self-test (no network)'

if ($fatal) {
    Write-Host "`nRelease REFUSED: fix the failing gate(s) and re-run. Nothing was committed."
    Write-Host 'Once fixed, re-run the same release command as-is.'
    exit 1
}

# ---- 4b. Record the review in the ledger, and file the debt when there wasn't one (B-45) ----
# Written after the gates pass and before `git add -A`, so the ledger row lands in the release
# commit itself -- a claim about a release that is not in that release's commit is not evidence.
$ledger = Join-Path $repo 'meta/review-ledger.md'
if (-not (Test-Path -LiteralPath $ledger)) {
    [IO.File]::WriteAllText($ledger, @"
# Review ledger

One row per release, written by ``.claude/scripts/release.ps1`` and committed with the release it
describes. It records **whether** an independent review happened and what the reviewer re-ran --
never whether the review was any good, which no gate here can judge. A ``reviewer: none`` row is a
legitimate outcome, deliberately not a silent one: it files a post-ship review item in
``meta/BACKLOG.md``. See root ``CLAUDE.md`` > Maintenance model.

| version | date | evidence |
|---------|------|----------|

"@.TrimEnd("`r", "`n") + "`n", [Text.UTF8Encoding]::new($false))
}
$evidenceCell = if ($NoIndependentReview) {
    'reviewer: none -- post-ship review owed'
} else {
    # Collapse to one line and escape the cell delimiter so the row cannot break the table.
    $ReviewEvidence -replace '\r?\n', ' ' -replace '\|', '\|'
}
Add-Content -LiteralPath $ledger -Value "| v$Version | $today | $evidenceCell |" -Encoding utf8
Write-Host "Review ledger: $evidenceCell"

if ($NoIndependentReview) {
    # Maintenance model #2: when no independent review happened, the debt is filed automatically
    # rather than left to memory -- the B-37 pattern, which is how it was missed before.
    $backlog = Join-Path $repo 'meta/BACKLOG.md'
    $anchor  = '## Known deferred work'
    $text    = [IO.File]::ReadAllText($backlog)
    $nums    = [regex]::Matches($text, '(?m)^### B-(\d+)') | ForEach-Object { [int]$_.Groups[1].Value }
    $next    = (($nums | Measure-Object -Maximum).Maximum) + 1
    $stub    = @"
### B-$next · Post-ship review owed for v$Version
**Effort:** S · **Priority:** P2 · filed automatically by ``release.ps1`` on $today

**Why:** v$Version shipped with ``-NoIndependentReview``, so no second session re-ran a gate or a
red-test against it. Maintenance model #2 requires the review to be filed rather than assumed when
it did not happen. Summary of what shipped: $Summary

**Do:** review the v$Version diff as an independent session -- re-run at least one gate and one
red-test yourself, do not read the release output as evidence -- and file whatever it finds. Then
close this entry, recording what was re-run.

---

"@
    if (([regex]::Matches($text, [regex]::Escape($anchor))).Count -eq 1) {
        [IO.File]::WriteAllText($backlog, $text.Replace($anchor, $stub + $anchor), [Text.UTF8Encoding]::new($false))
        Write-Host "Filed B-$next (post-ship review owed for v$Version)."
    } else {
        Write-Host "WARNING: could not file the post-ship review stub -- '$anchor' anchor not unique in meta/BACKLOG.md. File it by hand."
    }
}

# ---- 5. Commit + push ----
git -C $repo add -A
$staged = git -C $repo diff --cached --name-only
if (-not $staged) { Write-Host 'Nothing to commit (already released?).'; exit 0 }
git -C $repo commit -m "v${Version}: $Summary" -m "Released via .claude/scripts/release.ps1 — all deterministic gates green (compose ×3, validate-dist ×3, hook suites ×3, meta suite)."
if ($LASTEXITCODE -ne 0) { Write-Host 'Commit FAILED.'; exit 1 }
if (-not $NoPush) {
    # Push the COMMIT, not the branch name (B-53). `push origin master` pushes whatever the local
    # master ref points at -- which, on a detached HEAD, is not the commit just created. That is how
    # a release exited 0 and printed "complete" having shipped nothing.
    $releaseCommit = (git -C $repo rev-parse HEAD).Trim()
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

# ---- 5b. Tag the release (B-51) ----
# Tags stopped at v0.26.0 and 14 releases shipped untagged, so the B-49 drill protocol -- which
# requires a clean checkout of the latest released tag -- had to fall back to a raw SHA. The tag is
# created only after every gate and the commit have succeeded, so a tag always means a green release.
# Idempotent by design: a re-run after a partial failure must not fail on an existing correct tag,
# but a tag pointing somewhere else is a real conflict and is never silently moved.
$tagName     = "v$Version"
$releaseSha  = (git -C $repo rev-parse HEAD).Trim()
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
    git -C $repo tag -a $tagName -m "ai-tech-lead $tagName" $releaseSha
    if ($LASTEXITCODE -ne 0) { Write-Host "Tag FAILED: could not create $tagName."; exit 1 }
    Write-Host "Tagged $tagName at $($releaseSha.Substring(0,7))."
}
if (-not $NoPush) {
    git -C $repo push origin "refs/tags/$tagName"
    if ($LASTEXITCODE -ne 0) { Write-Host "Tag push FAILED: $tagName exists locally but not on origin."; exit 1 }
    # A tag that exists only locally is the failure this entry is about, so verify rather than assume.
    $remoteTag = (git -C $repo ls-remote --tags origin "refs/tags/$tagName")
    if (-not $remoteTag) { Write-Host "Tag push reported success but origin has no $tagName."; exit 1 }
    Write-Host "Tag $tagName confirmed on origin."
}

# B-41 behavioral evals are stochastic and consume model budget, so they run only after the
# deterministic release succeeded and are never a release gate. At this point the runner sees the
# just-committed distribution, not the previous release or a dirty pre-gate build.
$agentEvalCommand = 'pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -Live'
if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
    $runAgentEvals = Read-Host "Release succeeded. Run optional B-41 live agent evals now? [y/N]"
    if ($runAgentEvals -match '^(?i)y(?:es)?$') {
        & pwsh -NoProfile -File (Join-Path $repo '.claude/evals/run-agent-evals.ps1') -Live
        Write-Host "Agent eval exit: $LASTEXITCODE (recorded, never changes release status)."
        $evalResultsPath = 'meta/eval-results.md'
        if (git -C $repo status --porcelain -- $evalResultsPath) {
            git -C $repo add $evalResultsPath
            git -C $repo commit -m "meta: record v${Version} agent eval results"
            if ($LASTEXITCODE -ne 0) { Write-Host 'Eval-results commit FAILED; release is shipped but evidence is not persisted.'; exit 1 }
            if (-not $NoPush) {
                # Same explicit-commit push + postcondition as the release push above (B-53 d).
                $evalCommit = (git -C $repo rev-parse HEAD).Trim()
                git -C $repo push origin "${evalCommit}:refs/heads/master"
                if ($LASTEXITCODE -ne 0) { Write-Host 'Eval-results push FAILED; release is shipped but evidence is only local.'; exit 1 }
                $remoteAfterEval = (git -C $repo ls-remote origin refs/heads/master | ForEach-Object { ($_ -split '\s+')[0] })
                if ("$remoteAfterEval".Trim() -ne $evalCommit) {
                    Write-Host "Eval-results push POSTCONDITION FAILED: origin/master is $remoteAfterEval, expected $evalCommit."
                    Write-Host 'Release is shipped; the eval evidence is only local.'
                    exit 1
                }
            }
            $persisted = if ($NoPush) { 'locally (-NoPush)' } else { 'and pushed' }
            Write-Host "Agent eval evidence committed $persisted."
        }
    } else { Write-Host "Agent evals skipped. Run later: $agentEvalCommand" }
} else { Write-Host "Agent eval reminder (non-interactive; not run): $agentEvalCommand" }
Write-Host "`nRelease $Version complete$(if ($NoPush) { ' (not pushed: -NoPush)' })."
exit 0
