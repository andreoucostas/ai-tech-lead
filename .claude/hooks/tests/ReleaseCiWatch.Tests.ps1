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
# The naming shape itself ('<job> (<value>)' for matrix legs) is guarded by the real workflow
# topology test. This fixture derives the current eight expanded Windows host contexts.
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
    param(
        [string]$Pwsh = 'success', [string]$Hooks = 'success',
        [string]$Parity = 'success', [switch]$OmitHooks, [switch]$OmitParity
    )
    $id = 91483264876
    $j = @()
    foreach ($name in (Get-ExpectedJobNames)) {
        if ($name -eq 'windows-hooks (dotnet)' -and $OmitHooks) { continue }
        if ($name -eq 'windows-case-parity' -and $OmitParity) { continue }
        # The two root host jobs keep their per-case conclusions; derived matrix legs default to
        # success so a case that says nothing about them is not silently testing a red leg.
        $conclusion = switch ($name) {
            'windows' { $Pwsh }
            'windows-hooks (dotnet)' { $Hooks }
            'windows-case-parity' { $Parity }
            default { 'success' }
        }
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
        # The workflow says success; one shipped-hook leg did not run. Watching only the aggregate
        # conclusion cannot see this.
        $s = New-GhStub -ListResponses @('[' + (New-Row) + ']') -JobsResponse (New-Jobs -Hooks 'skipped')
        $r = Invoke-Watch -Stub $s -Watcher $w
        Assert ($r.Exit -eq 1) "expected EXIT=1 when a leg is not success, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'windows-hooks \(dotnet\)=skipped') 'the refusal does not name the offending leg'
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
    It 'the default contract names all seven execution contexts plus the case-count decision exactly' {
        $expected = @(
            'windows',
            'windows-meta (1)', 'windows-meta (2)', 'windows-meta (3)',
            'windows-hooks (dotnet)', 'windows-hooks (angular)', 'windows-hooks (monorepo)',
            'windows-case-parity'
        )
        $actual = @(Get-ExpectedJobNames)
        Assert (($actual -join '|') -eq ($expected -join '|')) "watcher default CI contexts drifted: $($actual -join ', ')"
    }

    It 'a completed successful run with every required job green exits 0' {
        $s = New-GhStub -ListResponses @('[' + (New-Row) + ']')
        $r = Invoke-Watch -Stub $s
        Assert ($r.Exit -eq 0) "expected EXIT=0, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'CI GREEN') 'did not report CI GREEN'
    }

    It 'a failed run exits 1, naming the conclusion and the run URL' { & $probes['red'] $watchCi }

    It 'a workflow success with a leg that did not run exits 1' { & $probes['legs'] $watchCi }

    It 'a workflow success with skipped parity exits 1' {
        $s = New-GhStub -ListResponses @('[' + (New-Row) + ']') -JobsResponse (New-Jobs -Parity 'skipped')
        $r = Invoke-Watch -Stub $s
        Assert ($r.Exit -eq 1) "expected EXIT=1 when parity is skipped, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'windows-case-parity=skipped') 'skipped-parity refusal does not name parity'
    }

    It 'a workflow success with failed parity exits 1' {
        $s = New-GhStub -ListResponses @('[' + (New-Row) + ']') -JobsResponse (New-Jobs -Parity 'failure')
        $r = Invoke-Watch -Stub $s
        Assert ($r.Exit -eq 1) "expected EXIT=1 when parity fails, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'windows-case-parity=failure') 'failed-parity refusal does not name parity'
    }

    It 'a workflow success with absent parity is CANT-VERIFY' {
        $s = New-GhStub -ListResponses @('[' + (New-Row) + ']') -JobsResponse (New-Jobs -OmitParity)
        $r = Invoke-Watch -Stub $s
        Assert ($r.Exit -eq 3) "expected CANT-VERIFY when parity is absent, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'expected CI leg.*windows-case-parity') 'absent-parity diagnostic does not name parity'
    }

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
        $s = New-GhStub -ListResponses @('[' + (New-Row) + ']') -JobsResponse (New-Jobs -OmitHooks)
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

    # Master CI runs took 1,264 to 1,623 s (2026-10-31), so v0.98.3's watch at the old 1,200 s default ended at
    # CANT-VERIFY with CI still running, and the release had to be re-run to tag.
    It 'the default watch outlasts a full CI run, the usage line names it, and release.ps1 takes it' {
        $timeoutParam = [System.Management.Automation.Language.Parser]::ParseFile($watchCi, [ref]$null, [ref]$null).ParamBlock.Parameters |
            Where-Object { $_.Name.VariablePath.UserPath -eq 'TimeoutSeconds' }
        Assert ($null -ne $timeoutParam -and $null -ne $timeoutParam.DefaultValue) 'watch-ci.ps1 declares no -TimeoutSeconds default'
        $default = [int]$timeoutParam.DefaultValue.Value
        Assert ($default -ge 2400) "the default watch is $default s; master CI runs took up to 1,623 s, so it must be at least 2,400 s"
        Assert ([IO.File]::ReadAllText($watchCi) -match "\[-TimeoutSeconds $default\]") "the usage line does not name the default ($default s)"
        $calls = @([IO.File]::ReadAllText($release) -split "`n" | Where-Object { $_ -match 'watch-ci\.ps1' -and $_ -match '-Sha' })
        Assert ($calls.Count -ge 2) "expected release.ps1's two watch-ci.ps1 runs, found $($calls.Count)"
        Assert (@($calls | Where-Object { $_ -match '-TimeoutSeconds' }).Count -eq 0) 'release.ps1 passes its own -TimeoutSeconds to watch-ci.ps1, so the default does not reach it'
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

    # ---- the tag lands on the commit CI verified (B-237) -------------------------------------------
    # v0.86.5: while step 5c watched one commit, another task committed in the same checkout, and
    # step 5d re-read HEAD and tagged the UNWATCHED commit as CI-verified. These cases extract step
    # 5d VERBATIM (the ReleaseStagingGuard pattern: a retyped copy would prove something about the
    # copy) and run it in a child host against a scratch repo, with HEAD moved after the "watch".
    $releaseText = [IO.File]::ReadAllText($release)
    $tagStart  = $releaseText.IndexOf('# ---- 5d.')
    $tagEnd    = $releaseText.IndexOf('Write-Host "`nRelease $Version complete')
    $tagRegion = if ($tagStart -ge 0 -and $tagEnd -gt $tagStart) { $releaseText.Substring($tagStart, $tagEnd - $tagStart) } else { $null }

    function New-TagScratchRepo {
        $dir = Join-Path ([IO.Path]::GetTempPath()) ("reltag-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $script:scratch += $dir
        git -C $dir init -q
        git -C $dir config user.email 'test@example.invalid'
        git -C $dir config user.name  'test'
        git -C $dir config commit.gpgsign false
        git -C $dir config tag.gpgsign false
        Set-Content -LiteralPath (Join-Path $dir 'f.txt') -Value 'release'
        git -C $dir add -A; git -C $dir commit -qm 'release commit (watched)'
        return $dir
    }
    function Add-FollowUpCommit {
        param([string]$Repo)
        Set-Content -LiteralPath (Join-Path $Repo 'f.txt') -Value 'follow-up committed during the CI watch'
        git -C $Repo commit -qam 'unwatched follow-up'
        return (git -C $Repo rev-parse HEAD).Trim()
    }
    # Binds exactly what step 5d reads from earlier steps. -NoPush keeps the region local: the tag
    # push and its outgoing check would otherwise reach for an origin the scratch repo does not have.
    function Invoke-TagStep {
        param([string]$Repo, [string]$ReleaseCommit)
        $body = @"
`$ErrorActionPreference = 'Stop'
`$repo = '$Repo'
`$Version = '9.9.9'
`$NoPush = `$true
`$releaseCommit = '$ReleaseCommit'
`$waiversApplied = @()
`$ciDecision = [pscustomobject]@{ Status = 'GREEN'; Tag = `$true; ReleaseExit = 0; TagNote = ' — CI verified green (test stub)' }
$tagRegion
exit 0
"@
        $f = Join-Path ([IO.Path]::GetTempPath()) ("reltag-run-" + [guid]::NewGuid().ToString('N') + '.ps1')
        [IO.File]::WriteAllText($f, $body, [Text.UTF8Encoding]::new($true))   # BOM: invariant #4
        try {
            $out  = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File $f 2>&1
            $code = $LASTEXITCODE
            return [pscustomobject]@{ Exit = $code; Out = ($out | Out-String) }
        } finally { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue }
    }
    function Get-TagCommit {
        param([string]$Repo)
        $sha = git -C $Repo rev-parse -q --verify 'refs/tags/v9.9.9^{commit}'
        if ($LASTEXITCODE -ne 0 -or -not $sha) { return $null }
        return "$sha".Trim()
    }

    It 'the tag step can be extracted from release.ps1, and is neither too small nor too large' {
        Assert ($null -ne $tagRegion) 'cannot bound step 5d between "# ---- 5d." and the "Release $Version complete" line'
        foreach ($needle in @('git -C $repo tag -a', 'refs/tags/$tagName^{commit}', 'Refusing to move an existing release tag')) {
            Assert ($tagRegion.Contains($needle)) "extracted tag step is missing '$needle' -- would test nothing"
        }
        foreach ($forbidden in @('watch-ci.ps1', 'Read-Host', 'git -C $repo commit')) {
            Assert (-not $tagRegion.Contains($forbidden)) "extracted tag step wrongly includes '$forbidden'"
        }
    }

    It 'control: with HEAD unchanged since the watch, the tag lands on the release commit' {
        $d = New-TagScratchRepo
        $a = (git -C $d rev-parse HEAD).Trim()
        $r = Invoke-TagStep -Repo $d -ReleaseCommit $a
        Assert ($r.Exit -eq 0) "expected EXIT=0, got $($r.Exit): $($r.Out)"
        $t = Get-TagCommit $d
        Assert ($t -eq $a) "tag peels to '$t', expected the release commit $a"
    }

    It 'a commit landing during the CI watch does not receive the release tag' {
        $d = New-TagScratchRepo
        $a = (git -C $d rev-parse HEAD).Trim()
        $b = Add-FollowUpCommit $d
        Assert ($a -ne $b) 'fixture did not advance HEAD -- the case would not distinguish watched from re-read'
        $r = Invoke-TagStep -Repo $d -ReleaseCommit $a
        Assert ($r.Exit -eq 0) "expected EXIT=0, got $($r.Exit): $($r.Out)"
        $t = Get-TagCommit $d
        Assert ($t -eq $a) "tag peels to '$t' -- the watched commit is $a, the unwatched HEAD is $b"
    }

    It 'a retry after HEAD advanced accepts the existing tag on the watched commit' {
        $d = New-TagScratchRepo
        $a = (git -C $d rev-parse HEAD).Trim()
        git -C $d tag -a v9.9.9 -m 'from the interrupted run' $a
        $b = Add-FollowUpCommit $d
        $r = Invoke-TagStep -Repo $d -ReleaseCommit $a
        Assert ($r.Exit -eq 0) "a correct existing tag was refused after HEAD moved to $b (EXIT=$($r.Exit)): $($r.Out)"
        Assert ($r.Out -match 'already present at the release commit') "retry not recognised: $($r.Out)"
        Assert ((Get-TagCommit $d) -eq $a) 'the existing tag moved'
    }

    # ---- B-521: the pre-tag agent runs ------------------------------------------------------------
    # Step 5b's functions are lifted out of release.ps1 by AST and called for real; the stage is driven
    # with a stub runner that writes the runner's row shape from a per-side, per-scenario plan, against a
    # scratch repository whose two commits stand for the previous release and the candidate. No model runs.
    $agentRunNames = @('Invoke-AgentRunGit', 'Get-AgentRunPreviousVersion', 'Test-AgentRunTriggerPath', 'Get-AgentRunRange',
        'ConvertFrom-AgentRunRow', 'Get-AgentRunDecision', 'Get-StoredAgentRunBaseline', 'Start-AgentRun', 'Invoke-AgentRunStage')
    $agentRunLiftError = $null
    try {
        $releaseAst = [System.Management.Automation.Language.Parser]::ParseFile($release, [ref]$null, [ref]$null)
        foreach ($name in $agentRunNames) {
            $fn = $releaseAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true) | Select-Object -First 1
            if ($null -eq $fn) { $agentRunLiftError = "release.ps1 defines no $name"; break }
            . ([scriptblock]::Create($fn.Extent.Text))
        }
        $runnerAst = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot '.claude/evals/run-agent-evals.ps1'), [ref]$null, [ref]$null)
        $fn = $runnerAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-RateLimitNote' }, $true) | Select-Object -First 1
        if ($null -eq $fn) { if (-not $agentRunLiftError) { $agentRunLiftError = 'run-agent-evals.ps1 defines no Get-RateLimitNote' } }
        else { . ([scriptblock]::Create($fn.Extent.Text)) }
    } catch { $agentRunLiftError = $_.Exception.Message }
    $emDash = [string][char]0x2014

    function New-AgentRunFixture {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('agentrun-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $script:scratch += $root
        $repoDir = Join-Path $root 'repo'
        New-Item -ItemType Directory -Path (Join-Path $repoDir 'dist/x'), (Join-Path $repoDir 'meta'), (Join-Path $root 'runner'), (Join-Path $root 'plan') -Force | Out-Null
        git -C $repoDir init -q
        git -C $repoDir config user.email 'test@example.invalid'
        git -C $repoDir config user.name 'test'
        git -C $repoDir config commit.gpgsign false
        git -C $repoDir config tag.gpgsign false
        $utf8 = [Text.UTF8Encoding]::new($false)
        $write = { param($rel, $text) [IO.File]::WriteAllText((Join-Path $repoDir $rel), $text, $utf8) }
        & $write 'CHANGELOG.md' "# Changelog`n`n## 1.0.0 $emDash 2026-01-01`n"
        & $write 'side.txt' 'baseline'
        & $write 'dist/x/AGENTS.md' 'one'
        & $write 'meta/notes.md' 'one'
        git -C $repoDir add -A; git -C $repoDir commit -qm 'v1.0.0'
        git -C $repoDir tag v1.0.0
        $base = (git -C $repoDir rev-parse HEAD).Trim()
        & $write 'CHANGELOG.md' "# Changelog`n`n## 1.1.0 $emDash 2026-01-02`n`n## 1.0.0 $emDash 2026-01-01`n"
        & $write 'meta/notes.md' 'two'
        git -C $repoDir add -A; git -C $repoDir commit -qm 'meta only'
        $metaOnly = (git -C $repoDir rev-parse HEAD).Trim()
        & $write 'side.txt' 'candidate'
        & $write 'dist/x/AGENTS.md' 'two'
        git -C $repoDir add -A; git -C $repoDir commit -qm 'candidate'
        $candidate = (git -C $repoDir rev-parse HEAD).Trim()
        $runner = Join-Path $root 'runner/run-agent-evals.ps1'
        [IO.File]::WriteAllText((Join-Path $root 'runner/scenarios.json'), '{"scenarios":[{"id":"alpha","budgetUsd":0.75},{"id":"beta","budgetUsd":0.75}]}', $utf8)
        $stub = @'
param([switch]$Live, [string[]]$Scenario, [string]$Model, [int]$Trials, [int]$TimeoutSeconds, [string]$FrameworkRoot, [string]$ResultsPath, [string[]]$AllowedTools)
$side = ([IO.File]::ReadAllText((Join-Path $FrameworkRoot 'side.txt'))).Trim()
$id = $Scenario[0]
$countFile = Join-Path $env:ATL_AGENTRUN_PLAN "$side-$id.count"
$n = if (Test-Path -LiteralPath $countFile) { [int][IO.File]::ReadAllText($countFile) } else { 0 }
[IO.File]::WriteAllText($countFile, [string]($n + 1))
$plan = @(([IO.File]::ReadAllText((Join-Path $env:ATL_AGENTRUN_PLAN "$side-$id.txt"))).Trim() -split ',')
$token = $plan[[Math]::Min($n, $plan.Count - 1)]
$d = [char]0x2014
$row = switch ($token) {
    'PASS'   { "- **PASS $id** (model=sonnet) $d agentExit=0 timedOut=False costUsd=0.10 tokensIn=1 tokensOut=1; ccVersion=9.9.9 initModel=stub-model outcome=True committed=True" }
    'FAIL'   { "- **FAIL $id** (model=sonnet) $d agentExit=0 timedOut=False costUsd=0.10 tokensIn=1 tokensOut=1; ccVersion=9.9.9 initModel=stub-model outcome=False committed=False" }
    'QUOTA'  { "- **ERROR $id** (model=sonnet) $d host failed before the agent acted: Claude AI usage limit reached rateLimit=rejected" }
    'UNREAD' { "- **ERROR $id** (model=sonnet) $d host failed before the agent acted: a permission rule refused the launch" }
}
Add-Content -LiteralPath $ResultsPath -Value @('', "## stub $d framework", '', $row, '') -Encoding utf8NoBOM
exit $(if ($token -eq 'PASS') { 0 } else { 1 })
'@
        [IO.File]::WriteAllText($runner, $stub, [Text.UTF8Encoding]::new($true))
        return [pscustomobject]@{ Repo = $repoDir; Base = $base; MetaOnly = $metaOnly; Candidate = $candidate; Runner = $runner; Plan = (Join-Path $root 'plan') }
    }
    function Invoke-AgentRunFixture {
        param($Fixture, [hashtable]$Plan, [decimal]$SpendStopUsd = 6, [string]$Stored = '', [string[]]$Scenarios = @('alpha'))
        foreach ($key in $Plan.Keys) { [IO.File]::WriteAllText((Join-Path $Fixture.Plan "$key.txt"), $Plan[$key]) }
        $saved = $env:ATL_AGENTRUN_PLAN
        $env:ATL_AGENTRUN_PLAN = $Fixture.Plan
        try {
            return Invoke-AgentRunStage -Repo $Fixture.Repo -CandidateSha $Fixture.Candidate -BaseSha $Fixture.Base -BaseVersion '1.0.0' `
                -Scenarios $Scenarios -StoredResultsText $Stored -RunnerPath $Fixture.Runner -SpendStopUsd $SpendStopUsd -RunTimeoutSeconds 60
        } finally { $env:ATL_AGENTRUN_PLAN = $saved }
    }
    function Get-AgentRunCount { param($Fixture, [string]$Key) $f = Join-Path $Fixture.Plan "$Key.count"; if (Test-Path -LiteralPath $f) { [int][IO.File]::ReadAllText($f) } else { 0 } }

    It 'B-521: a range touching only meta/ runs nothing; an agent-facing path triggers' {
        Assert ($null -eq $agentRunLiftError) $agentRunLiftError
        foreach ($quiet in 'meta/BACKLOG.md', 'meta/eval-results.md', 'src/core/AGENTS.md', 'dist/dotnet/.claude/framework-version.json', 'dist/dotnet/docs/playbook.md', 'CHANGELOG.md', 'dist/dotnet/CHANGELOG.md') {
            Assert (-not (Test-AgentRunTriggerPath $quiet)) "$quiet triggered the runs"
        }
        foreach ($loud in 'dist/dotnet/AGENTS.md', 'dist/angular/CLAUDE.md', 'dist/monorepo/.github/instructions/framework-rules.instructions.md', 'dist/dotnet/.claude/workflow.md',
            'dist/dotnet/.claude/commands/fix.md', 'dist/angular/.claude/skills/add-tests/SKILL.md', 'dist/dotnet/.claude/agents/test-critic.md', 'dist/dotnet/.github/agents/test-critic.agent.md',
            'dist/dotnet/.claude/hooks/guard.ps1', 'dist/dotnet/.github/hooks/hooks.json', 'dist/dotnet/.claude/settings.json', 'dist/dotnet/scripts/install.ps1', 'install.ps1', 'README.md') {
            Assert (Test-AgentRunTriggerPath $loud) "$loud did not trigger the runs"
        }
        $fx = New-AgentRunFixture
        $quietRange = Get-AgentRunRange -Repo $fx.Repo -Version '1.1.0' -CandidateSha $fx.MetaOnly
        Assert ($quietRange.Exit -eq 0 -and $quietRange.Previous -eq '1.0.0' -and $quietRange.Changed -eq 2 -and $quietRange.Trigger.Count -eq 0) "meta-only range: $($quietRange | ConvertTo-Json -Compress)"
        $loudRange = Get-AgentRunRange -Repo $fx.Repo -Version '1.1.0' -CandidateSha $fx.Candidate
        Assert ($loudRange.Exit -eq 0 -and $loudRange.BaseSha -eq $fx.Base -and @($loudRange.Trigger) -contains 'dist/x/AGENTS.md') "candidate range: $($loudRange | ConvertTo-Json -Compress)"
    }

    It 'B-521: a missing base tag reads could not examine (exit 3), never nothing to run' {
        Assert ($null -eq $agentRunLiftError) $agentRunLiftError
        $fx = New-AgentRunFixture
        git -C $fx.Repo tag -d v1.0.0 | Out-Null
        $range = Get-AgentRunRange -Repo $fx.Repo -Version '1.1.0' -CandidateSha $fx.Candidate
        Assert ($range.Exit -eq 3 -and $range.Message -match 'could not examine' -and $range.Message -match 'v1\.0\.0') "missing tag: $($range | ConvertTo-Json -Compress)"
        Assert ((Get-AgentRunPreviousVersion -ChangelogText "## 1.1.0 $emDash Unreleased" -Version '1.1.0') -eq $null) 'an undated head was taken for a previous release'
    }

    It 'B-521: 4 of 6 against a 3-of-3 baseline is REGRESSION (exit 1); a baseline that fails is could not examine (exit 3)' {
        Assert ($null -eq $agentRunLiftError) $agentRunLiftError
        $d = Get-AgentRunDecision -Candidate @('PASS', 'FAIL', 'PASS', 'PASS', 'FAIL', 'PASS') -Baseline @('PASS', 'PASS', 'PASS')
        Assert ($d.Done -and $d.Verdict -eq 'REGRESSION' -and $d.Exit -eq 1) "4 of 6 vs 3 of 3: $($d | ConvertTo-Json -Compress)"
        $d = Get-AgentRunDecision -Candidate @('PASS', 'FAIL', 'PASS', 'PASS', 'FAIL', 'PASS') -Baseline @('PASS', 'FAIL', 'PASS')
        Assert ($d.Done -and $d.Verdict -eq 'BASELINE_MOVED' -and $d.Exit -eq 3) "2-of-3 baseline: $($d | ConvertTo-Json -Compress)"
        $d = Get-AgentRunDecision -Candidate @('PASS', 'FAIL', 'PASS', 'PASS', 'PASS', 'PASS') -Baseline @('PASS', 'PASS', 'PASS')
        Assert ($d.Done -and $d.Verdict -eq 'GREEN' -and $d.Exit -eq 0) "1 of 6: $($d | ConvertTo-Json -Compress)"
        $d = Get-AgentRunDecision -Candidate @('PASS', 'PASS', 'PASS')
        Assert ($d.Done -and $d.Exit -eq 0) "3 of 3: $($d | ConvertTo-Json -Compress)"
        $d = Get-AgentRunDecision -Candidate @('PASS', 'FAIL', 'PASS')
        Assert (-not $d.Done -and $d.NeedCandidate -and $d.NeedBaseline) "one failure did not open stage B: $($d | ConvertTo-Json -Compress)"
        $d = Get-AgentRunDecision -Candidate @('UNREAD', 'PASS', 'UNREAD', 'UNREAD')
        Assert ($d.Done -and $d.Verdict -eq 'CANT_VERIFY' -and $d.Exit -eq 3) "three unread runs: $($d | ConvertTo-Json -Compress)"
    }

    It 'B-521: an injection-style decline is FAIL, a host refusal is not examined, a quota refusal stops; allowed_warning is no refusal' {
        Assert ($null -eq $agentRunLiftError) $agentRunLiftError
        $decline = ConvertFrom-AgentRunRow "- **FAIL install-handoff** (model=sonnet) $emDash agentExit=0 timedOut=False costUsd=0.25 tokensIn=1 tokensOut=1; ccVersion=2.1.312 initModel=claude-sonnet-5-5 stamp=True commits=1 installerTool=True bootstrapPending=True bootstrapTool=False finalNamesBootstrap=False"
        Assert ($decline.Class -eq 'FAIL' -and -not $decline.Quota -and $decline.CostUsd -eq 0.25 -and $decline.CcVersion -eq '2.1.312' -and $decline.Facts['commits'] -eq '1' -and -not $decline.Facts.Contains('ccVersion')) "decline: $($decline | ConvertTo-Json -Compress)"
        $refused = ConvertFrom-AgentRunRow "- **ERROR route-fix** (model=sonnet) $emDash host failed before the agent acted: the auto mode classifier blocked this action"
        Assert ($refused.Class -eq 'UNREAD' -and -not $refused.Quota) "host refusal: $($refused | ConvertTo-Json -Compress)"
        $quota = ConvertFrom-AgentRunRow "- **ERROR guard-retry** (model=sonnet) $emDash host failed before the agent acted: Claude AI usage limit reached rateLimit=rejected"
        Assert ($quota.Class -eq 'UNREAD' -and $quota.Quota) "quota: $($quota | ConvertTo-Json -Compress)"
        $transcript = Join-Path ([IO.Path]::GetTempPath()) ('ratelimit-' + [guid]::NewGuid().ToString('N') + '.jsonl')
        $script:scratch += $transcript
        [IO.File]::WriteAllText($transcript, '{"type":"rate_limit_event","rate_limit_info":{"status":"allowed_warning","utilization":0.98}}' + "`n")
        Assert ((Get-RateLimitNote $transcript) -eq '') 'an allowed_warning was noted as a refusal'
        [IO.File]::AppendAllText($transcript, '{"type":"rate_limit_event","rate_limit_info":{"status":"rejected"}}' + "`n")
        Assert ((Get-RateLimitNote $transcript) -eq ' rateLimit=rejected') 'a rejected status was not noted'
    }

    It 'B-521: the stage is green on 3 of 3 and stops a regression with exit 1 against a fresh baseline' {
        Assert ($null -eq $agentRunLiftError) $agentRunLiftError
        $fx = New-AgentRunFixture
        $green = Invoke-AgentRunFixture $fx @{ 'candidate-alpha' = 'PASS' }
        Assert ($green.Exit -eq 0 -and $green.Verdict -eq 'GREEN' -and @($green.RowLines).Count -eq 3 -and $green.SpentUsd -eq 0.30) "green: $($green | ConvertTo-Json -Compress)"
        Assert (@($green.RowLines | Where-Object { $_ -like '*pretag=candidate)*' }).Count -eq 3) "rows not tagged: $($green.RowLines -join ' | ')"
        $fx = New-AgentRunFixture
        $red = Invoke-AgentRunFixture $fx @{ 'candidate-alpha' = 'FAIL'; 'baseline-alpha' = 'PASS' }
        Assert ($red.Exit -eq 1 -and $red.Verdict -eq 'REGRESSION') "regression: $($red | ConvertTo-Json -Compress)"
        Assert ((Get-AgentRunCount $fx 'candidate-alpha') -eq 2 -and (Get-AgentRunCount $fx 'baseline-alpha') -eq 3) "runs: candidate $(Get-AgentRunCount $fx 'candidate-alpha'), baseline $(Get-AgentRunCount $fx 'baseline-alpha')"
        Assert (@($red.RowLines | Where-Object { $_ -like '*pretag=baseline-v1.0.0)*' }).Count -eq 3 -and ($red.Lines -join ' ') -match 'committed=False') "baseline rows or failing check missing: $($red.RowLines -join ' | ') / $($red.Lines -join ' ')"
        Assert (-not (git -C $fx.Repo worktree list --porcelain | Select-String -SimpleMatch 'atl-pretag-')) 'a stage worktree was left registered'
    }

    It 'B-521: stored same-host baseline rows replace the baseline runs' {
        Assert ($null -eq $agentRunLiftError) $agentRunLiftError
        $fx = New-AgentRunFixture
        $row = "- **PASS alpha** (model=sonnet; pretag=candidate) $emDash agentExit=0 timedOut=False costUsd=0.10 tokensIn=1 tokensOut=1; ccVersion=9.9.9 initModel=stub-model outcome=True committed=True"
        $stored = (@('', "## 2026-01-01 00:00:00 +00:00 $emDash pre-tag agent runs, v1.0.0 candidate (B-521)", '', $row, $row, $row, '') -join "`n")
        $red = Invoke-AgentRunFixture $fx @{ 'candidate-alpha' = 'FAIL' } -Stored $stored
        Assert ($red.Exit -eq 1 -and (Get-AgentRunCount $fx 'baseline-alpha') -eq 0 -and ($red.Lines -join ' ') -match 'stored') "stored baseline: $(Get-AgentRunCount $fx 'baseline-alpha') baseline runs; $($red | ConvertTo-Json -Compress)"
        Assert (($red.Lines -join ' ') -match 'failing: .*committed=False') "the failing check was not named against the stored PASS row: $($red.Lines -join ' ')"
    }

    It 'B-521: a quota refusal, three unread runs and the spend stop read could not examine (exit 3)' {
        Assert ($null -eq $agentRunLiftError) $agentRunLiftError
        $fx = New-AgentRunFixture
        $quota = Invoke-AgentRunFixture $fx @{ 'candidate-alpha' = 'QUOTA' }
        Assert ($quota.Exit -eq 3 -and $quota.Stop -match 'quota' -and (Get-AgentRunCount $fx 'candidate-alpha') -eq 1) "quota: $(Get-AgentRunCount $fx 'candidate-alpha') runs; $($quota | ConvertTo-Json -Compress)"
        $fx = New-AgentRunFixture
        $unread = Invoke-AgentRunFixture $fx @{ 'candidate-alpha' = 'UNREAD' }
        Assert ($unread.Exit -eq 3 -and (Get-AgentRunCount $fx 'candidate-alpha') -eq 3) "unread: $(Get-AgentRunCount $fx 'candidate-alpha') runs; $($unread | ConvertTo-Json -Compress)"
        $fx = New-AgentRunFixture
        $spend = Invoke-AgentRunFixture $fx @{ 'candidate-alpha' = 'PASS' } -SpendStopUsd 0.5
        Assert ($spend.Exit -eq 3 -and $spend.Stop -match 'USD stop' -and (Get-AgentRunCount $fx 'candidate-alpha') -eq 0) "spend stop: $($spend | ConvertTo-Json -Compress)"
    }

    It 'B-521: -NoEvals is refused before anything runs, naming -WaiveAgentRuns' {
        $r = & (Get-PsExe) -NoProfile -File $release -Version 9.9.9 -Summary 'probe' -NoEvals 2>&1
        $code = $LASTEXITCODE
        Assert ($code -eq 2 -and (($r | Out-String) -match '-WaiveAgentRuns')) "EXIT=$code; $($r | Out-String)"
    }

    It 'B-521: the tag records the pre-tag agent runs line of the release commit, a waiver included' {
        Assert ($null -ne $tagRegion) 'cannot bound step 5d'
        $d = New-TagScratchRepo
        git -C $d commit -q --amend -m 'v9.9.9: probe' -m 'gates' -m 'Pre-tag agent runs (B-521): WAIVED (-WaiveAgentRuns): host down'
        $a = (git -C $d rev-parse HEAD).Trim()
        $r = Invoke-TagStep -Repo $d -ReleaseCommit $a
        Assert ($r.Exit -eq 0) "EXIT=$($r.Exit): $($r.Out)"
        $annotation = (git -C $d tag -l --format='%(contents)' v9.9.9) -join ' '
        Assert ($annotation -match 'Pre-tag agent runs \(B-521\): WAIVED \(-WaiveAgentRuns\): host down') "annotation: $annotation"
        $releaseText5b = [IO.File]::ReadAllText($release)
        Assert ($releaseText5b.Contains('"Pre-tag agent runs (B-521): $agentRunNote"') -and $releaseText5b.Contains('$agentRunNote = "WAIVED (-WaiveAgentRuns): ')) 'step 5b no longer writes the waiver into the release commit'
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
