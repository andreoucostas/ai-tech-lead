# Planted-defect tests for the release CI watch (B-88). Does NOT ship.
#
# Subject: .claude/scripts/watch-ci.ps1 (does the release learn that CI went red?) and
# .claude/scripts/_ci-decision.ps1 (does it then withhold the tag and exit non-zero?).
#
# WHAT THIS PROVES AND WHAT IT DOES NOT.
#   Proved here: the watcher's exit contract (0 green / 1 red / 3 CANT-VERIFY) across the state
#   machine, run selection (event filtering, re-run attempts, per-workflow latest), the job-level
#   leg check, and the publish decision mapping -- by CALLING Get-CiPublishDecision, not by reading
#   release.ps1 as text.
#   NOT proved here: that release.ps1 binds those pieces correctly in a live release. No release is
#   run. ReleaseStagingGuard.Tests.ps1:10-12 makes the same admission about extraction and had a
#   real end-to-end release to supply the missing evidence; this one does not, so the first release
#   to use this path is part of the change (B-70's discipline). What IS asserted structurally is
#   ORDERING -- that the watch sits after the verified master push and before the tag -- because
#   that ordering is the whole reframing of B-88 and an ordering fact can honestly be checked as one.
#
# The gh stub is driven by payloads copied from REAL `gh` output captured while building this
# (run 30745279068 success / 30742855756 failure), not invented shapes, and every case asserts the
# exact argument vector the watcher sent -- not merely that some process ran. A fixture that does not
# reach the branch it targets agrees about nothing, which is indistinguishable from agreement (B-75).
#
# RED-TESTING: this file carries its own mutation harness. Run it with -SelfTest and it copies
# watch-ci.ps1, plants each recorded defect, and asserts the named case goes red. That makes "seen to
# go red" re-verifiable by running it rather than by trusting a comment. It is deliberately a
# suite-local version of what B-84 asks for -- B-84 (a shared mutation helper for all gates) REMAINS
# OPEN and this does not close it.
#
#   pwsh -NoProfile -File .claude/hooks/tests/ReleaseCiWatch.Tests.ps1
#   pwsh -NoProfile -File .claude/hooks/tests/ReleaseCiWatch.Tests.ps1 -SelfTest
param([switch]$SelfTest)

. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot  = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$watchCi   = Join-Path $repoRoot '.claude/scripts/watch-ci.ps1'
$decision  = Join-Path $repoRoot '.claude/scripts/_ci-decision.ps1'
$release   = Join-Path $repoRoot '.claude/scripts/release.ps1'

Reset-Tests

$SHA = 'a41ab8d090bc7d2927290cf99a8f6c0cab1810b6'   # a real sha from this repo's history
$scratch = @()

# --- fixture builders (shapes copied from real gh output) -----------------------------------------
function New-Row {
    param(
        [string]$Status = 'completed', [string]$Conclusion = 'success', [string]$Event = 'push',
        [long]$Id = 30745279068, [string]$Workflow = 'CI', [string]$HeadSha = $SHA
    )
    $c = if ($Conclusion -eq $null) { 'null' } else { '"' + $Conclusion + '"' }
    return ('{"conclusion":' + $c + ',"databaseId":' + $Id + ',"event":"' + $Event + '","headSha":"' +
            $HeadSha + '","status":"' + $Status + '","url":"https://github.com/owner/repo/actions/runs/' +
            $Id + '","workflowName":"' + $Workflow + '"}')
}
# The stub's job list is READ OUT OF watch-ci.ps1's own -ExpectedJobs default, never restated here.
#
# Why: it was restated here, and it drifted. B-113's 68cf0aa split the shipped hook suites onto six
# new runners and widened ExpectedJobs to match; these stubs kept registering only windows+linux, so
# the watcher correctly reported CANT-VERIFY and five cases that test WATCHER LOGIC -- pull_request
# runs not deciding a release, re-runs superseding, polling to terminal, query scoping -- failed for
# a reason none of them is about. That red then blocked every release, including a documentation-only
# one, which is what -AllowFailingGate now exists for.
#
# Deriving the list means the next person to widen ExpectedJobs cannot break these cases by omission.
# The naming shape itself ('<job> (<value>)' for matrix legs) is no longer an assumption: run
# 31168445026 produced exactly windows, linux, windows-hooks (dotnet|angular|monorepo) and
# linux-hooks (dotnet|angular|monorepo), which are the existing matrix job names.
function Get-ExpectedJobNames {
    $watchPath = Join-Path $repoRoot '.claude/scripts/watch-ci.ps1'
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($watchPath, [ref]$null, [ref]$errors)
    if ($errors.Count) { throw "watch-ci.ps1 does not parse: $($errors[0])" }
    $param = $ast.FindAll({ param($n)
        $n -is [System.Management.Automation.Language.ParameterAst] -and $n.Name.VariablePath.UserPath -eq 'ExpectedJobs'
    }, $true) | Select-Object -First 1
    if (-not $param) { throw 'watch-ci.ps1 no longer declares -ExpectedJobs -- these stubs can no longer be kept in step with it' }
    if (-not $param.DefaultValue) { throw '-ExpectedJobs has no default -- the stub cannot derive the leg list' }
    $names = @($param.DefaultValue.SafeGetValue())
    if ($names.Count -lt 2) { throw "-ExpectedJobs default yielded $($names.Count) name(s); expected the full leg list" }
    return $names
}
function New-Jobs {
    param([string]$Windows = 'success', [string]$Linux = 'success', [switch]$OmitLinux)
    $id = 91483264876
    $j = @()
    foreach ($name in (Get-ExpectedJobNames)) {
        if ($name -eq 'linux' -and $OmitLinux) { continue }
        # 'windows'/'linux' keep their per-case conclusions; the derived matrix legs default to
        # success so a case that says nothing about them is not silently testing a red leg.
        $conclusion = switch ($name) { 'windows' { $Windows } 'linux' { $Linux } default { 'success' } }
        $j += '{"name":"' + $name + '","conclusion":"' + $conclusion + '","status":"completed","databaseId":' + $id + '}'
        $id++
    }
    return '{"jobs":[' + ($j -join ',') + ']}'
}

function New-GhStub {
    param(
        [string[]]$ListResponses,
        [string]$JobsResponse,
        [string]$RepoResponse = '{"nameWithOwner":"owner/repo"}',
        [int]$ListExit = 0,
        [string]$ListStderr = ''
    )
    if (-not $JobsResponse) { $JobsResponse = (New-Jobs) }
    $dir = Join-Path ([IO.Path]::GetTempPath()) ("ciwatch-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:scratch += $dir
    for ($i = 0; $i -lt @($ListResponses).Count; $i++) {
        [IO.File]::WriteAllText((Join-Path $dir ('list-{0:d3}.json' -f $i)), $ListResponses[$i])
    }
    [IO.File]::WriteAllText((Join-Path $dir 'jobs.json'), $JobsResponse)
    [IO.File]::WriteAllText((Join-Path $dir 'repo.json'), $RepoResponse)

    # No param block, deliberately: a script with declared parameters would try to BIND gh's own
    # flags (-R prefix-matches a parameter named Rest, for instance) and the argument vector would
    # arrive mangled. With no param block every token lands in $args intact -- verified.
    $body = @'
$dir = '__DIR__'
$cmd = ($args -join ' ')
Add-Content -LiteralPath (Join-Path $dir 'calls.log') -Value $cmd
if ($cmd -like 'repo view*') { Write-Output ([IO.File]::ReadAllText((Join-Path $dir 'repo.json'))); exit 0 }
if ($cmd -like 'run view*')  { Write-Output ([IO.File]::ReadAllText((Join-Path $dir 'jobs.json'))); exit 0 }
$listLog = Join-Path $dir 'list.log'
Add-Content -LiteralPath $listLog -Value $cmd
$n = @(Get-Content -LiteralPath $listLog).Count
$files = @(Get-ChildItem -LiteralPath $dir -Filter 'list-*.json' | Sort-Object Name)
$idx = [Math]::Min($n, $files.Count) - 1
$err = '__STDERR__'
if ($err) { [Console]::Error.WriteLine($err) }
Write-Output ([IO.File]::ReadAllText($files[$idx].FullName))
exit __LISTEXIT__
'@
    $body = $body.Replace('__DIR__', $dir).Replace('__STDERR__', $ListStderr).Replace('__LISTEXIT__', "$ListExit")
    $stub = Join-Path $dir 'gh-stub.ps1'
    [IO.File]::WriteAllText($stub, $body, [Text.UTF8Encoding]::new($true))   # BOM: invariant #4
    return [pscustomobject]@{ Dir = $dir; Path = $stub; Log = (Join-Path $dir 'calls.log'); Responses = @($ListResponses) }
}

function Invoke-Watch {
    param(
        [Parameter(Mandatory)]$Stub, [string]$Watcher, [string]$GhPath,
        [int]$Timeout = 30, [int]$Appear = 5, [int]$Poll = 0
    )
    if (-not $Watcher) { $Watcher = $watchCi }
    if (-not $GhPath)  { $GhPath  = $Stub.Path }
    # The watcher runs under THIS suite's own host. The old Get-PsExe contract preferred pwsh 7
    # whenever it resolved, so running the suite under Windows PowerShell 5.1 would still have
    # exercised the subject under 7 -- the host where a 5.1-only defect cannot exist. That is
    # verbatim the trap the v0.41.0 RCA records (B-74), and its fix is this same expression.
    $ef = [IO.Path]::GetTempFileName()
    try {
        $out = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $Watcher `
            -Sha $SHA -GhPath $GhPath -RepoRoot $Stub.Dir `
            -TimeoutSeconds $Timeout -AppearSeconds $Appear -PollSeconds $Poll 2>$ef
        $code = $LASTEXITCODE
        $err  = [IO.File]::ReadAllText($ef)
        return [pscustomobject]@{ Exit = $code; Out = (($out -join "`n") + "`n" + $err) }
    } finally { if (Test-Path -LiteralPath $ef) { [IO.File]::Delete($ef) } }
}
function Get-Calls { param($Stub) if (Test-Path -LiteralPath $Stub.Log) { return @(Get-Content -LiteralPath $Stub.Log) } return @() }

# --- probes: shared by the normal run AND by -SelfTest --------------------------------------------
# Each probe returns nothing on success and throws on failure, so the same body proves the real
# watcher correct and proves a mutated watcher wrong. If these were separate code paths the
# self-test could pass while testing something the suite does not assert.
$probes = @{
    'red' = {
        param($w)
        $s = New-GhStub -ListResponses @('[' + (New-Row -Conclusion 'failure') + ']')
        $r = Invoke-Watch -Stub $s -Watcher $w
        Assert ($r.Exit -eq 1) "expected EXIT=1 on a failed run, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'failure') 'the refusal does not name the conclusion'
        Assert ($r.Out -match 'actions/runs/') 'the refusal does not print the run URL'
    }
    'legs' = {
        param($w)
        # The workflow says success; the linux leg did not run. Watching only the aggregate
        # conclusion cannot see this.
        $s = New-GhStub -ListResponses @('[' + (New-Row) + ']') -JobsResponse (New-Jobs -Linux 'skipped')
        $r = Invoke-Watch -Stub $s -Watcher $w
        Assert ($r.Exit -eq 1) "expected EXIT=1 when a leg is not success, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'linux=skipped') 'the refusal does not name the offending leg'
    }
    'unknown' = {
        param($w)
        $s = New-GhStub -ListResponses @('[' + (New-Row -Conclusion 'neutral') + ']')
        $r = Invoke-Watch -Stub $s -Watcher $w
        Assert ($r.Exit -eq 3) "an unrecognised conclusion must be CANT-VERIFY (3), got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'CANT-VERIFY') 'did not report CANT-VERIFY'
    }
    'event' = {
        param($w)
        # A pull_request run for the same sha failed, and it is the NEWER record. Only the push run
        # decides a release; without the event filter the PR verdict would win.
        $s = New-GhStub -ListResponses @('[' + (New-Row -Conclusion 'success' -Event 'push' -Id 100) + ',' +
                                               (New-Row -Conclusion 'failure' -Event 'pull_request' -Id 200) + ']')
        $r = Invoke-Watch -Stub $s -Watcher $w
        Assert ($r.Exit -eq 0) "a failed pull_request run must not decide the release, got EXIT=$($r.Exit): $($r.Out)"
    }
}

try {
    # ---- the exit contract ----------------------------------------------------------------------
    It 'a completed successful run with every required job green exits 0' {
        $s = New-GhStub -ListResponses @('[' + (New-Row) + ']')
        $r = Invoke-Watch -Stub $s
        Assert ($r.Exit -eq 0) "expected EXIT=0, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'CI GREEN') 'did not report CI GREEN'
    }

    It 'a failed run exits 1, naming the conclusion and the run URL' { & $probes['red'] $watchCi }

    It 'a workflow success with a leg that did not run exits 1' { & $probes['legs'] $watchCi }

    It 'an unrecognised conclusion is CANT-VERIFY, never green' { & $probes['unknown'] $watchCi }

    It 'a failed pull_request run for the same sha does not decide the release' { & $probes['event'] $watchCi }

    It 'it polls to a terminal state rather than sampling once' {
        # Each element MUST be parenthesised. In PowerShell `,` binds TIGHTER than `+`, so
        #   '[' + (New-Row) + ']', '[' + (New-Row) + ']'
        # parses as one big concatenation and yields a SINGLE 656-char string containing every
        # payload run together -- which then failed to parse as JSON in a way that read like a bug in
        # the watcher. A fixture that is not the shape it looks like is B-75's class, one level down.
        $s = New-GhStub -ListResponses @(
            ('[' + (New-Row -Status 'queued'      -Conclusion $null) + ']'),
            ('[' + (New-Row -Status 'in_progress' -Conclusion $null) + ']'),
            ('[' + (New-Row) + ']'))
        Assert (@($s.Responses).Count -eq 3) "the poll fixture collapsed to $(@($s.Responses).Count) response(s) -- it would not exercise polling at all"
        $r = Invoke-Watch -Stub $s
        Assert ($r.Exit -eq 0) "expected EXIT=0 after polling to completion, got $($r.Exit): $($r.Out)"
        $lists = @(Get-Calls $s | Where-Object { $_ -like 'run list*' })
        Assert (@($lists).Count -ge 3) "expected >=3 `run list` calls, saw $(@($lists).Count) -- it is not polling"
    }

    It 'a re-run that succeeded supersedes the earlier failed attempt' {
        $s = New-GhStub -ListResponses @('[' + (New-Row -Conclusion 'failure' -Id 100) + ',' +
                                               (New-Row -Conclusion 'success' -Id 300) + ']')
        $r = Invoke-Watch -Stub $s
        Assert ($r.Exit -eq 0) "latest attempt per workflow must win, got EXIT=$($r.Exit): $($r.Out)"
    }

    It 'a run that never completes is CANT-VERIFY at the timeout, not green' {
        $s = New-GhStub -ListResponses @('[' + (New-Row -Status 'in_progress' -Conclusion $null) + ']')
        $r = Invoke-Watch -Stub $s -Timeout 2 -Poll 1
        Assert ($r.Exit -eq 3) "expected EXIT=3 at the timeout, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'still running') 'did not say why it could not verify'
    }

    It 'a run that never appears is CANT-VERIFY, not green' {
        $s = New-GhStub -ListResponses @('[]')
        $r = Invoke-Watch -Stub $s -Appear 2 -Poll 1
        Assert ($r.Exit -eq 3) "expected EXIT=3 when no run registers, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'no push run appeared') 'did not say why it could not verify'
    }

    It 'a gh failure is CANT-VERIFY and surfaces what gh said' {
        $s = New-GhStub -ListResponses @('[]') -ListExit 1 -ListStderr 'gh: authentication required'
        $r = Invoke-Watch -Stub $s
        Assert ($r.Exit -eq 3) "expected EXIT=3 when gh fails, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'authentication required') "gh's own error was swallowed: $($r.Out)"
    }

    It 'unparseable gh output is CANT-VERIFY, never green' {
        $s = New-GhStub -ListResponses @('<!DOCTYPE html><html>rate limited</html>')
        $r = Invoke-Watch -Stub $s
        Assert ($r.Exit -eq 3) "a parse failure must not read as success, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'did not parse') 'did not report a parse failure'
    }

    It 'an expected leg that is absent is CANT-VERIFY, not a failure' {
        # ABSENT is not FAILED: a renamed job means this script's expectation is stale, which is a
        # different fact from a leg that ran and failed. B-71/B-85's shared lesson.
        $s = New-GhStub -ListResponses @('[' + (New-Row) + ']') -JobsResponse (New-Jobs -OmitLinux)
        $r = Invoke-Watch -Stub $s
        Assert ($r.Exit -eq 3) "an absent leg must be CANT-VERIFY (3), got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'not present') 'did not distinguish absent from failed'
    }

    It 'a missing gh is CANT-VERIFY and distinguishes absent-from-host vs absent-from-PATH' {
        $s = New-GhStub -ListResponses @('[' + (New-Row) + ']')
        $r = Invoke-Watch -Stub $s -GhPath (Join-Path $s.Dir 'no-such-gh.exe')
        Assert ($r.Exit -eq 3) "expected EXIT=3 with no gh, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'CANT-VERIFY') 'did not report CANT-VERIFY'
        Assert ($r.Out -match '(?s)installed at|No GitHub CLI found') 'does not distinguish "no gh on this host" from "not on PATH"'
    }

    # ---- the arguments actually sent -------------------------------------------------------------
    It 'the watcher scopes every query with an explicit repo, sha and field list' {
        $s = New-GhStub -ListResponses @('[' + (New-Row) + ']')
        $r = Invoke-Watch -Stub $s
        Assert ($r.Exit -eq 0) "setup failed: EXIT=$($r.Exit) $($r.Out)"
        $calls = @(Get-Calls $s)
        $list  = @($calls | Where-Object { $_ -like 'run list*' })
        Assert (@($list).Count -ge 1) 'no `run list` call was made at all'
        Assert ($list[0] -match '-R owner/repo')       "run list is not scoped with -R: $($list[0])"
        Assert ($list[0] -match "--commit $SHA")       "run list does not pin the sha: $($list[0])"
        foreach ($f in @('databaseId', 'status', 'conclusion', 'workflowName', 'event', 'headSha')) {
            Assert ($list[0] -match $f) "run list does not request the '$f' field: $($list[0])"
        }
        $view = @($calls | Where-Object { $_ -like 'run view*' })
        Assert (@($view).Count -ge 1) 'the job-level check never ran'
        Assert ($view[0] -match '-R owner/repo') "run view is not scoped with -R: $($view[0])"
        Assert ($view[0] -match 'jobs')          "run view does not request jobs: $($view[0])"
    }

    # ---- the publish decision, called for real ---------------------------------------------------
    It 'the publish decision tags only on a positive observation of green' {
        . $decision
        $green = Get-CiPublishDecision -Mode Watched -WatchExit 0
        $red   = Get-CiPublishDecision -Mode Watched -WatchExit 1
        $cant  = Get-CiPublishDecision -Mode Watched -WatchExit 3
        $weird = Get-CiPublishDecision -Mode Watched -WatchExit 99
        $nopush= Get-CiPublishDecision -Mode NoPush
        $over  = Get-CiPublishDecision -Mode Override

        Assert ($green.Tag -and $green.ReleaseExit -eq 0) 'a green CI must tag and exit 0'
        Assert (-not $red.Tag -and $red.ReleaseExit -eq 1) 'a red CI must NOT tag and must exit non-zero'
        Assert (-not $cant.Tag -and $cant.ReleaseExit -eq 3) 'CANT-VERIFY must NOT tag and must exit non-zero'
        Assert (-not $weird.Tag -and $weird.ReleaseExit -ne 0) 'an unknown watch exit must not fall through to green'
        Assert ($nopush.Tag -and $nopush.ReleaseExit -eq 0) '-NoPush must still tag locally'
        Assert ($over.Tag -and $over.ReleaseExit -eq 0) '-AllowUnverifiedCi must tag'
        Assert ($over.TagNote -match 'override') 'the override must be recorded in the tag annotation'
        Assert ($over.Status -ne $cant.Status) 'a waived check and an unverifiable one must not report the same status'
        Assert ($over.Message -notmatch 'CANT-VERIFY') 'an operator waiver must not be worded as CANT-VERIFY'
    }

    # ---- ordering inside release.ps1 (an ordering fact, checked as one) ---------------------------
    It 'release.ps1 watches CI after the verified push and before the tag' {
        $t = [IO.File]::ReadAllText($release)
        $iPush  = $t.IndexOf('origin/master confirmed at')
        $iWatch = $t.IndexOf('# ---- 5c.')
        $iTag   = $t.IndexOf('# ---- 5d.')
        Assert ($iPush -ge 0)  'no push postcondition found in release.ps1'
        Assert ($iWatch -ge 0) 'no "# ---- 5c." CI-watch step found in release.ps1'
        Assert ($iTag -ge 0)   'no "# ---- 5d." tag step found in release.ps1'
        Assert ($iWatch -gt $iPush) 'the CI watch runs before the push is verified'
        Assert ($iWatch -lt $iTag)  'the CI watch runs AFTER the tag -- a tag would then no longer mean CI-verified green'
        Assert ($t -match 'watch-ci\.ps1')       'release.ps1 never invokes watch-ci.ps1'
        Assert ($t -match 'Get-CiPublishDecision') 'release.ps1 does not use the publish decision function'
    }

    It 'release.ps1 no longer exits 0 when there is nothing to stage' {
        # With a watch in the publish phase, the old early exit stranded every recovery: CI red ->
        # fix in a separate commit -> re-run -> nothing staged -> exit 0, never tagged, printed as
        # if released.
        $t = [IO.File]::ReadAllText($release)
        Assert ($t -notmatch 'if \(-not \$staged\)[^\r\n]*exit 0') `
            'the publish phase still exits 0 when nothing is staged -- a release left untagged by a red CI could then never be tagged after the fix'
        $assign = @($t -split "`n" | Where-Object { $_ -match '^\s*\$nothingToCommit\s*=' })
        Assert (@($assign).Count -eq 1) "expected exactly one `$nothingToCommit assignment, found $(@($assign).Count)"
        Assert ($t -match '(?m)^\s*if \(-not \$nothingToCommit\) \{') 'the commit is not guarded on the resume path -- it would try to commit nothing'
    }

    # ---- the mutation harness --------------------------------------------------------------------
    # Recorded defects, kept as executable text rather than as a comment claiming a red-test happened.
    $mutations = @(
        @{ Case = 'red';     Find = '$bad     = @($watched | Where-Object { $KNOWN_BAD -contains $_.conclusion })'; Replace = '$bad = @()' }
        @{ Case = 'legs';    Find = 'if (@($failedJobs).Count -gt 0) {'; Replace = 'if ($false) {' }
        @{ Case = 'unknown'; Find = 'if (@($unknown).Count -gt 0) {';    Replace = 'if ($false) {' }
        @{ Case = 'event';   Find = "`$_.event -eq 'push' -and ";        Replace = '' }
    )

    if ($SelfTest) {
        $src = [IO.File]::ReadAllText($watchCi)
        foreach ($m in $mutations) {
            It "SELFTEST: planting a defect makes the '$($m.Case)' case fail" {
                Assert ($src.Contains($m.Find)) "mutation anchor not found -- the mutation would apply to NOTHING and this case would pass vacuously: $($m.Find)"
                $mutated = $src.Replace($m.Find, $m.Replace)
                Assert ($mutated -ne $src) 'the mutation changed nothing'
                $path = Join-Path ([IO.Path]::GetTempPath()) ("watch-ci-mutant-" + [guid]::NewGuid().ToString('N') + '.ps1')
                [IO.File]::WriteAllText($path, $mutated, [Text.UTF8Encoding]::new($true))
                $script:scratch += $path
                # Control first. Without this the whole self-test passes VACUOUSLY whenever the
                # watcher is broken for an unrelated reason: every probe fails, so "the mutant fails"
                # is satisfied by a subject that never worked. Observed for real -- running this file
                # under Windows PowerShell 5.1 showed 13 red cases and 4 green SELFTESTs, and the
                # green ones were meaningless. Asserting the probe PASSES on the unmutated watcher
                # first is what makes the mutation the reason it fails.
                & $probes[$m.Case] $watchCi
                $failed = $false
                try { & $probes[$m.Case] $path } catch { $failed = $true }
                Assert $failed "the '$($m.Case)' case PASSED against a watcher with its check removed -- that case cannot fail, so its green means nothing"
            }
        }
    } else {
        It 'the recorded mutations still apply to the current watch-ci.ps1' {
            # Cheap guard so the self-test cannot silently rot into vacuity between runs: if a
            # refactor renames an anchor, this fails here rather than making -SelfTest pass by
            # mutating nothing.
            $src = [IO.File]::ReadAllText($watchCi)
            foreach ($m in $mutations) {
                Assert ($src.Contains($m.Find)) "mutation anchor no longer present in watch-ci.ps1: $($m.Find)"
            }
        }
    }
} finally {
    foreach ($p in $scratch) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
}

exit (Write-TestSummary 'ReleaseCiWatch.Tests (B-88 CI watch)')
