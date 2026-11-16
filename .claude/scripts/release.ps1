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
# Gates (in order): compose all three dists -> validate-dist ×3 + context footprint -> the four meta
# test files whose subject the release commit changes (B-245) -> before the commit, live agent runs
# on the candidate when it changes what agents are told (B-521, step 5b). The full root meta suite
# and the shipped hook suites run in CI: before a normal tag, CI must observe the
# three-dist hook matrices under PowerShell 7.
#
# PowerShell-only by decision (see meta/workspace-decisions.md): release/eval automation requires
# PowerShell 7, as every framework script does.
#Requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Summary,
    [switch]$NoPush,
    # Refused (B-521): weeks of "pass -NoEvals" would otherwise switch the pre-tag agent runs off
    # silently. Declared only so the refusal below can name the replacement instead of a binding error.
    [switch]$NoEvals,
    # Waiver for the pre-tag agent runs at step 5b (B-521), named for what it risks: the release is
    # tagged without live agent runs on what it tells agents. The reason is written into the release
    # commit and the tag annotation, like -AllowUnverifiedCi.
    [string]$WaiveAgentRuns,
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
    [switch]$AllowUnverifiedCi,
    # Escape hatch for ONE named meta-suite file that is known-broken for a reason already filed.
    # Format: -AllowFailingGate 'DocTruth.Tests.ps1=B-113' (one or more, comma-separated).
    #
    # Why this exists: v0.49.0 was blocked by five stale stubs in the CI-watch tests while shipping a
    # documentation-only skill change. An all-or-nothing gate set means any red anywhere stops
    # everything, which is how a suite stops being a safety net and starts being a hostage.
    #
    # What it deliberately is NOT: a skip. The waived file still RUNS, still reports, and its output
    # still appears in the transcript -- only its power to block is suspended. And it is not silent:
    # the backlog id is mandatory (a bare filename is refused), and the waiver is written into the
    # release commit message AND the tag annotation, so it travels with the artifact whose meaning it
    # changes, exactly like -AllowUnverifiedCi.
    #
    # What it cannot do: waive a dist gate (validate-dist or a shipped hook suite). Those gate what
    # consumers receive. This covers the maintainer-only meta suite only, and only the files
    # release.ps1 runs locally; a file that runs in CI only is refused (B-245).
    [string[]]$AllowFailingGate
)
$ErrorActionPreference = 'Stop'
if ($NoEvals) {
    [Console]::Error.WriteLine('FATAL: -NoEvals was removed (B-521): the pre-tag agent runs are part of the release; to skip them pass -WaiveAgentRuns "<reason>", which the tag records. Nothing was stamped or committed.')
    exit 2
}

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

# ---- B-521 pre-tag agent runs: what step 5b calls ----------------------------------------------
# When the release changes what agents are told, the standing scenarios below run live against the
# exact candidate before it is committed (.claude/plans/2026-11-15-b521-pre-tag-evals.md; WSD-125 (6)).
# Exits mirror the CI watch (WSD-029): 0 green; 1 REGRESSION, the candidate is worse than the
# previous release; 3 could not examine (runs the host refused, errored or timed out on, a quota or
# rate-limit refusal, the 6 USD stop, a baseline that failed too). ReleaseCiWatch.Tests.ps1 lifts
# these functions by AST and calls them, Invoke-AgentRunStage with a stub runner.
# Only a scenario seen red on a known-bad candidate counts (meta/eval-results.md, "B-521 red check",
# 2026-11-16): guard-retry stopped the guard's removal (exit 1). route-fix stayed green with the bug-fix
# rail's failing-test sentence removed and install-handoff with v0.97.1's installer wording, each 3 of 3
# and 6 of 6 at calibration, so the design drops both until a known-bad they see is found.
$agentRunScenarios = @('guard-retry')
# acceptEdits with this list replaces --dangerously-skip-permissions, which this host's auto mode
# refused (B-470; B-514 measured in the same mode). The shell tools are whole: the scenarios run the
# installer, git and the fixture's tests, and a narrower list would score a denied command as FAIL.
$agentRunAllowedTools = @('Read', 'Edit', 'Write', 'Glob', 'Grep', 'Bash', 'PowerShell')
$agentRunSpendStopUsd = [decimal]6

# git with its output read as UTF-8 whatever the console code page (the CHANGELOG heads carry an em
# dash, and a CP437 console would garble it).
function Invoke-AgentRunGit {
    param([Parameter(Mandatory)][string]$Repo, [Parameter(Mandatory)][string[]]$Arguments)
    $psi = [Diagnostics.ProcessStartInfo]::new('git')
    foreach ($a in @('-C', $Repo) + $Arguments) { $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $p = [Diagnostics.Process]::Start($psi)
    $out = $p.StandardOutput.ReadToEndAsync()
    $err = $p.StandardError.ReadToEndAsync()
    $p.WaitForExit()
    return [pscustomobject]@{ Exit = $p.ExitCode; Out = $out.GetAwaiter().GetResult(); Err = $err.GetAwaiter().GetResult() }
}

# The previous release: the newest dated root CHANGELOG head that is not this one.
function Get-AgentRunPreviousVersion {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$ChangelogText, [Parameter(Mandatory)][string]$Version)
    $emDash = [string][char]0x2014
    foreach ($line in ($ChangelogText -split '\r?\n')) {
        $m = [regex]::Match($line, "^## (\d+\.\d+\.\d+) $emDash \d{4}-\d{2}-\d{2}\s*$")
        if ($m.Success -and $m.Groups[1].Value -ne $Version) { return $m.Groups[1].Value }
    }
    return $null
}

# What agents are told: the instruction files, the rules carrier, workflow, commands, skills, agents,
# hooks and their wiring, and the installer's handoff text; at the root, the installer and README.
function Test-AgentRunTriggerPath {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Path)
    return [regex]::IsMatch($Path, '^(?:install\.ps1|README\.md|dist/[^/]+/(?:AGENTS\.md|CLAUDE\.md|\.github/instructions/.+|\.claude/workflow\.md|\.claude/commands/.+|\.claude/skills/.+|\.claude/agents/.+|\.github/agents/.+|\.claude/hooks/.+|\.github/hooks/.+|\.claude/settings[^/]*\.json|scripts/install\.ps1))$')
}

# The range, from repository content only: the candidate's CHANGELOG names the previous release, its
# tag is the base, and the paths changed between them decide whether the runs happen. Anything that
# cannot be read is "could not examine" (exit 3), never "nothing to run".
function Get-AgentRunRange {
    param([Parameter(Mandatory)][string]$Repo, [Parameter(Mandatory)][string]$Version, [Parameter(Mandatory)][string]$CandidateSha)
    $changelog = Invoke-AgentRunGit -Repo $Repo -Arguments @('show', "${CandidateSha}:CHANGELOG.md")
    if ($changelog.Exit -ne 0) { return [pscustomobject]@{ Exit = 3; Message = 'could not examine: the candidate has no readable root CHANGELOG.md.' } }
    $previous = Get-AgentRunPreviousVersion -ChangelogText $changelog.Out -Version $Version
    if (-not $previous) { return [pscustomobject]@{ Exit = 3; Message = "could not examine: the root CHANGELOG has no dated head below $Version to compare with." } }
    $base = Invoke-AgentRunGit -Repo $Repo -Arguments @('rev-parse', '-q', '--verify', "refs/tags/v$previous^{commit}")
    if ($base.Exit -ne 0 -or -not $base.Out.Trim()) { return [pscustomobject]@{ Exit = 3; Message = "could not examine: tag v$previous, the previous release, is not in this clone (git fetch --tags)." } }
    $baseSha = $base.Out.Trim()
    $diff = Invoke-AgentRunGit -Repo $Repo -Arguments @('-c', 'core.quotepath=false', 'diff', '--name-only', '-z', $baseSha, $CandidateSha)
    if ($diff.Exit -ne 0) { return [pscustomobject]@{ Exit = 3; Message = "could not examine: git diff v$previous..candidate failed: $($diff.Err.Trim())" } }
    $paths = @($diff.Out -split [char]0 | Where-Object { $_ })
    return [pscustomobject]@{ Exit = 0; Message = ''; Previous = $previous; BaseSha = $baseSha; Changed = $paths.Count; Trigger = @($paths | Where-Object { Test-AgentRunTriggerPath $_ }) }
}

# One runner row. PASS and FAIL were examined by the grader: an agent that read the framework's text
# and declined, asked instead of acting or called it an injection is FAIL, what a consumer meets.
# Everything else is UNREAD (could not examine): the host refused before the agent acted, an API or
# host error, a timeout, a broken transcript, INCONCLUSIVE. Quota marks a quota or rate-limit refusal,
# which stops the stage; an allowed_warning rate-limit status is not one.
function ConvertFrom-AgentRunRow {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Line)
    $m = [regex]::Match($Line, "^- \*\*(?<status>[A-Z_]+) (?<id>[A-Za-z0-9-]+)\*\* \((?<meta>[^)]*)\) $([char]0x2014) (?<detail>.*)$")
    if (-not $m.Success) { return $null }
    $status = $m.Groups['status'].Value
    $detail = $m.Groups['detail'].Value
    $class = if ($status -eq 'PASS') { 'PASS' } elseif ($status -eq 'FAIL') { 'FAIL' } else { 'UNREAD' }
    $cost = [regex]::Match($detail, '(?:^|\s)costUsd=(\d+(?:\.\d+)?)')
    $quota = $class -eq 'UNREAD' -and ($detail -match 'rateLimit=rejected|apiErrorStatus=429' -or
        $detail -match '(?i)usage limit|hit your limit|rate[ _-]?limit|quota|credit balance|billing')
    # The grader's facts (after the first ';'), for naming what a FAIL row differs on from a PASS row.
    $facts = [ordered]@{}
    if ($detail.Contains(';')) {
        foreach ($f in [regex]::Matches(($detail -split ';', 2)[1], '(?:^|\s)(\w+)=(\S+)')) {
            if ($f.Groups[1].Value -notin @('ccVersion', 'initModel', 'durationMs', 'budgetUsd')) { $facts[$f.Groups[1].Value] = $f.Groups[2].Value }
        }
    }
    $side = [regex]::Match($m.Groups['meta'].Value, '(?:^|;\s*)pretag=([\w.-]+)')
    return [pscustomobject]@{
        Status    = $status
        Scenario  = $m.Groups['id'].Value
        Class     = $class
        CostUsd   = if ($cost.Success) { [decimal]$cost.Groups[1].Value } else { $null }
        Quota     = [bool]$quota
        CcVersion = [regex]::Match($detail, '\bccVersion=(\S+)').Groups[1].Value
        Model     = [regex]::Match($detail, '\binitModel=(\S+)').Groups[1].Value
        Facts     = $facts
        Side      = if ($side.Success) { $side.Groups[1].Value } else { '' }
    }
}

# The rule, per scenario, from the classes so far. Stage A: 3 examined candidate runs, all PASS is
# green. A FAIL opens stage B: up to 6 candidate runs and 3 baseline runs of the previous release.
# REGRESSION when the candidate fails 2 or more while the baseline passes 3 of 3; BASELINE_MOVED
# when the baseline fails a run (the host or model shifted under both); green on exactly 1 failure.
# A third UNREAD run on either side is CANT_VERIFY. Stops early once more runs cannot change it.
function Get-AgentRunDecision {
    param([string[]]$Candidate = @(), [string[]]$Baseline = @())
    $done = { param($Verdict, $Exit, $Message) [pscustomobject]@{ Done = $true; Verdict = $Verdict; Exit = $Exit; Message = $Message; NeedCandidate = $false; NeedBaseline = $false } }
    $need = { param($Candidate, $Baseline) [pscustomobject]@{ Done = $false; Verdict = ''; Exit = $null; Message = ''; NeedCandidate = [bool]$Candidate; NeedBaseline = [bool]$Baseline } }
    $cand = @($Candidate | Where-Object { $_ -in @('PASS', 'FAIL') })
    $base = @($Baseline | Where-Object { $_ -in @('PASS', 'FAIL') })
    $candUnread = @($Candidate | Where-Object { $_ -eq 'UNREAD' }).Count
    $baseUnread = @($Baseline | Where-Object { $_ -eq 'UNREAD' }).Count
    $fails = @($cand | Where-Object { $_ -eq 'FAIL' }).Count
    $baseFails = @($base | Where-Object { $_ -eq 'FAIL' }).Count
    if ($candUnread -gt 2) { return & $done 'CANT_VERIFY' 3 "could not examine: $candUnread candidate runs could not be read" }
    if ($fails -eq 0) {
        if ($cand.Count -ge 3) { return & $done 'GREEN' 0 "green: the candidate passed $($cand.Count) of $($cand.Count)" }
        return & $need $true $false
    }
    if ($baseUnread -gt 2) { return & $done 'CANT_VERIFY' 3 "could not examine: $baseUnread baseline runs could not be read" }
    if ($baseFails -gt 0) { return & $done 'BASELINE_MOVED' 3 "could not examine (baseline moved): the previous release also failed $baseFails of $($base.Count) here, so the host or model shifted under both" }
    $needBase = $base.Count -lt 3
    if ($fails -ge 2) {
        if (-not $needBase) { return & $done 'REGRESSION' 1 "REGRESSION: the candidate failed $fails of $($cand.Count) while the previous release passed 3 of 3" }
        return & $need $false $true
    }
    if ($cand.Count -lt 6 -or $needBase) { return & $need ($cand.Count -lt 6) $needBase }
    return & $done 'GREEN' 0 "green: the candidate failed 1 of 6 and the previous release passed 3 of 3"
}

# The previous release's own pre-tag rows, as its release commit stored them: usable as the baseline
# only when made on the same Claude Code version and model and all of at least three examined PASS.
function Get-StoredAgentRunBaseline {
    param([AllowEmptyString()][string]$ResultsText, [Parameter(Mandatory)][string]$Version, [Parameter(Mandatory)][string]$Scenario,
        [AllowEmptyString()][string]$CcVersion, [AllowEmptyString()][string]$Model)
    if (-not $ResultsText -or -not $CcVersion -or -not $Model) { return $null }
    $heading = "$([char]0x2014) pre-tag agent runs, v$Version candidate (B-521)"
    $inSection = $false
    $classes = @()
    foreach ($line in ($ResultsText -split '\r?\n')) {
        if ($line.StartsWith('## ')) { $inSection = $line.EndsWith($heading); continue }
        if (-not $inSection) { continue }
        $row = ConvertFrom-AgentRunRow $line
        if (-not $row -or $row.Scenario -ne $Scenario -or $row.Side -ne 'candidate' -or $row.Class -eq 'UNREAD') { continue }
        if ($row.CcVersion -ne $CcVersion -or $row.Model -ne $Model) { continue }
        $classes += $row.Class
    }
    if ($classes.Count -ge 3 -and @($classes | Where-Object { $_ -ne 'PASS' }).Count -eq 0) { return @('PASS', 'PASS', 'PASS') }
    return $null
}

# One live run, through the runner's own -Live path, in a child whose environment carries no CLAUDE*
# or ANTHROPIC* variable (a launching Claude Code session's would nest the child; B-514's practice).
function Start-AgentRun {
    param([Parameter(Mandatory)][string]$RunnerPath, [Parameter(Mandatory)][string]$Scenario, [Parameter(Mandatory)][string]$FrameworkRoot,
        [Parameter(Mandatory)][string]$ResultsPath, [string[]]$AllowedTools = @(), [int]$TimeoutSeconds = 600)
    $q = { param($s) "'" + ([string]$s).Replace("'", "''") + "'" }
    $tools = if (@($AllowedTools).Count) { ' -AllowedTools @(' + ((@($AllowedTools) | ForEach-Object { & $q $_ }) -join ',') + ')' } else { '' }
    $command = "& $(& $q $RunnerPath) -Live -Scenario $(& $q $Scenario) -Model sonnet -Trials 1 -TimeoutSeconds $TimeoutSeconds -FrameworkRoot $(& $q $FrameworkRoot) -ResultsPath $(& $q $ResultsPath)$tools; exit `$LASTEXITCODE"
    $psi = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
    foreach ($a in @('-NoProfile', '-NonInteractive', '-EncodedCommand', [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command)))) { $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    foreach ($name in @($psi.Environment.Keys)) { if ($name -match '^(?i:CLAUDE|ANTHROPIC)') { [void]$psi.Environment.Remove($name) } }
    $psi.Environment['DISABLE_AUTOUPDATER'] = '1'
    $p = [Diagnostics.Process]::Start($psi)
    return [pscustomobject]@{ Process = $p; Out = $p.StandardOutput.ReadToEndAsync(); Err = $p.StandardError.ReadToEndAsync() }
}

# The stage: rounds of single runs, one per scenario and side still needed, in parallel. Before each
# round the worst case (every run at its budget cap) must stay within the spend stop; a run with no
# recorded cost counts at its cap. A quota or rate-limit refusal ends the stage at once.
function Invoke-AgentRunStage {
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$CandidateSha,
        [Parameter(Mandatory)][string]$BaseSha,
        [Parameter(Mandatory)][string]$BaseVersion,
        [Parameter(Mandatory)][string[]]$Scenarios,
        [AllowEmptyString()][string]$StoredResultsText = '',
        # Default: the candidate's own runner, so its graders score the candidate and the baseline alike.
        [string]$RunnerPath,
        [decimal]$SpendStopUsd = 6,
        [string[]]$AllowedTools = @(),
        [int]$RunTimeoutSeconds = 600
    )
    $state = [ordered]@{}
    foreach ($s in $Scenarios) { $state[$s] = [pscustomobject]@{ Candidate = [Collections.Generic.List[string]]::new(); Baseline = [Collections.Generic.List[string]]::new(); Source = ''; Decision = $null; PassFacts = $null; FailFacts = [Collections.Generic.List[object]]::new(); CcVersion = ''; Model = '' } }
    $rowLines = [Collections.Generic.List[string]]::new()
    $spent = [decimal]0
    $stop = ''
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('atl-pretag-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $roots = @{}
    [void](New-Item -ItemType Directory -Path $temp)
    try {
        $add = Invoke-AgentRunGit -Repo $Repo -Arguments @('worktree', 'add', '--detach', (Join-Path $temp 'candidate'), $CandidateSha)
        if ($add.Exit -ne 0) { $stop = "could not examine: the candidate worktree failed: $($add.Err.Trim())" } else { $roots.candidate = Join-Path $temp 'candidate' }
        if (-not $RunnerPath -and $roots.candidate) { $RunnerPath = Join-Path $roots.candidate '.claude/evals/run-agent-evals.ps1' }
        $budgets = @{}
        if (-not $stop) {
            $scenarioFile = Join-Path (Split-Path -Parent $RunnerPath) 'scenarios.json'
            try { foreach ($c in @((Get-Content -Raw -LiteralPath $scenarioFile | ConvertFrom-Json).scenarios)) { $budgets[[string]$c.id] = [decimal]$c.budgetUsd } }
            catch { $stop = "could not examine: $scenarioFile is unreadable." }
            foreach ($s in $Scenarios) { if (-not $stop -and -not $budgets.ContainsKey($s)) { $stop = "could not examine: scenario $s is not in $scenarioFile." } }
        }
        $round = 0
        while (-not $stop) {
            $round++
            $runs = @()
            foreach ($s in $Scenarios) {
                $st = $state[$s]
                if ($st.Decision) { continue }
                $d = Get-AgentRunDecision -Candidate @($st.Candidate) -Baseline @($st.Baseline)
                if ($d.NeedBaseline -and -not $st.Source) {
                    $stored = Get-StoredAgentRunBaseline -ResultsText $StoredResultsText -Version $BaseVersion -Scenario $s -CcVersion $st.CcVersion -Model $st.Model
                    if ($stored) {
                        $st.Baseline.AddRange([string[]]$stored)
                        $st.Source = 'stored'
                        # The stored PASS row's facts name what a FAIL differs on, as a fresh baseline's would.
                        foreach ($line in ($StoredResultsText -split '\r?\n')) {
                            $r = ConvertFrom-AgentRunRow $line
                            if ($r -and -not $st.PassFacts -and $r.Scenario -eq $s -and $r.Class -eq 'PASS' -and $r.CcVersion -eq $st.CcVersion -and $r.Model -eq $st.Model) { $st.PassFacts = $r.Facts }
                        }
                    } else { $st.Source = 'fresh' }
                    $d = Get-AgentRunDecision -Candidate @($st.Candidate) -Baseline @($st.Baseline)
                }
                if ($d.Done) { $st.Decision = $d; continue }
                if ($d.NeedCandidate) { $runs += [pscustomobject]@{ Scenario = $s; Side = 'candidate' } }
                if ($d.NeedBaseline) { $runs += [pscustomobject]@{ Scenario = $s; Side = 'baseline' } }
            }
            if (-not $runs) { break }
            $worst = [decimal]0
            foreach ($r in $runs) { $worst += $budgets[$r.Scenario] }
            if ($spent + $worst -gt $SpendStopUsd) { $stop = "could not examine: the next round could take spend to $($spent + $worst) USD, past the $SpendStopUsd USD stop"; break }
            if (@($runs | Where-Object Side -eq 'baseline').Count -and -not $roots.baseline) {
                $add = Invoke-AgentRunGit -Repo $Repo -Arguments @('worktree', 'add', '--detach', (Join-Path $temp 'baseline'), $BaseSha)
                if ($add.Exit -ne 0) { $stop = "could not examine: the baseline worktree failed: $($add.Err.Trim())"; break }
                $roots.baseline = Join-Path $temp 'baseline'
            }
            $handles = foreach ($r in $runs) {
                $resultsPath = Join-Path $temp "round$round-$($r.Side)-$($r.Scenario).md"
                $h = Start-AgentRun -RunnerPath $RunnerPath -Scenario $r.Scenario -FrameworkRoot $roots[$r.Side] -ResultsPath $resultsPath -AllowedTools $AllowedTools -TimeoutSeconds $RunTimeoutSeconds
                [pscustomobject]@{ Run = $r; Handle = $h; ResultsPath = $resultsPath }
            }
            $deadline = [DateTime]::UtcNow.AddSeconds($RunTimeoutSeconds + 300)
            foreach ($x in @($handles)) {
                $left = [int][Math]::Max(1000, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)
                $killed = -not $x.Handle.Process.WaitForExit($left)
                if ($killed) { try { $x.Handle.Process.Kill($true) } catch { } ; [void]$x.Handle.Process.WaitForExit(10000) }
                $st = $state[$x.Run.Scenario]
                $row = $null
                if (Test-Path -LiteralPath $x.ResultsPath) {
                    foreach ($line in [IO.File]::ReadAllLines($x.ResultsPath)) { $parsed = ConvertFrom-AgentRunRow $line; if ($parsed) { $row = $parsed; $rowLine = $line; break } }
                }
                $sideTag = if ($x.Run.Side -eq 'baseline') { "baseline-v$BaseVersion" } else { 'candidate' }
                $sideList = $st.Candidate
                if ($x.Run.Side -eq 'baseline') { $sideList = $st.Baseline }
                if (-not $row) {
                    $spent += $budgets[$x.Run.Scenario]
                    if ($killed) {
                        $sideList.Add('UNREAD')
                        $rowLines.Add("- **ERROR $($x.Run.Scenario)** (pretag=$sideTag) $([char]0x2014) the runner exceeded $($RunTimeoutSeconds + 300)s and was stopped")
                        continue
                    }
                    $tail = (@(($x.Handle.Out.GetAwaiter().GetResult() + "`n" + $x.Handle.Err.GetAwaiter().GetResult()) -split '\r?\n' | Where-Object { $_.Trim() }) | Select-Object -Last 2) -join ' | '
                    if (-not $stop) { $stop = "could not examine: the runner wrote no row for $($x.Run.Side) $($x.Run.Scenario) (exit $($x.Handle.Process.ExitCode)): $tail" }
                    continue
                }
                $runCost = if ($null -ne $row.CostUsd) { $row.CostUsd } else { $budgets[$x.Run.Scenario] }
                $spent += $runCost
                $rowLines.Add(($rowLine -replace '^(- \*\*[A-Z_]+ [A-Za-z0-9-]+\*\* \([^)]*)\)', "`$1; pretag=$sideTag)"))
                $sideList.Add($row.Class)
                if ($row.Class -eq 'PASS' -and -not $st.PassFacts) { $st.PassFacts = $row.Facts }
                if ($x.Run.Side -eq 'candidate') {
                    if ($row.CcVersion) { $st.CcVersion = $row.CcVersion; $st.Model = $row.Model }
                    if ($row.Class -eq 'FAIL') { $st.FailFacts.Add($row.Facts) }
                }
                if ($row.Quota -and -not $stop) { $stop = "could not examine: a quota or rate-limit refusal on $($x.Run.Side) $($x.Run.Scenario)" }
            }
        }
    } finally {
        foreach ($root in @($roots.Values)) { [void](Invoke-AgentRunGit -Repo $Repo -Arguments @('worktree', 'remove', '--force', $root)) }
        [void](Invoke-AgentRunGit -Repo $Repo -Arguments @('worktree', 'prune'))
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
    $lines = foreach ($s in $Scenarios) {
        $st = $state[$s]
        if (-not $st.Decision) { $st.Decision = [pscustomobject]@{ Done = $true; Verdict = 'CANT_VERIFY'; Exit = 3; Message = $(if ($stop) { $stop } else { 'could not examine: the stage ended before this scenario was decided' }) } }
        # What the candidate's FAIL rows differ on from the first PASS row seen (either side).
        $checks = @(foreach ($ff in $st.FailFacts) { if ($st.PassFacts) { foreach ($k in $ff.Keys) { if ($st.PassFacts.Contains($k) -and $st.PassFacts[$k] -cne $ff[$k]) { "$k=$($ff[$k])" } } } }) | Select-Object -Unique
        "${s}: $($st.Decision.Message) (candidate $(@($st.Candidate | Where-Object { $_ -eq 'PASS' }).Count) PASS of $($st.Candidate.Count) run$(if ($st.Baseline.Count) { "; baseline v$BaseVersion $(@($st.Baseline | Where-Object { $_ -eq 'PASS' }).Count) PASS of $($st.Baseline.Count), $($st.Source)" })$(if ($checks) { "; failing: $($checks -join ', ')" }))"
    }
    $verdicts = @($Scenarios | ForEach-Object { $state[$_].Decision })
    $exit = if (@($verdicts | Where-Object Exit -eq 1).Count) { 1 } elseif (@($verdicts | Where-Object Exit -eq 3).Count) { 3 } else { 0 }
    $verdict = switch ($exit) { 0 { 'GREEN' } 1 { 'REGRESSION' } default { 'COULD NOT EXAMINE' } }
    return [pscustomobject]@{ Exit = $exit; Verdict = $verdict; SpentUsd = $spent; RowLines = @($rowLines); Lines = @($lines); Stop = $stop }
}

# ---- Gate time budget -------------------------------------------------------------------------
# The suite grew by accretion until releasing became impractical -- every RCA added a gate and
# nothing ever measured what the set cost. Static context had the identical failure mode and was
# fixed by declaring a ceiling and making it fail (B-110); this is that pattern applied to time.
# Ceilings live in meta/gate-budget.json, which also records the honest limit: seconds are
# host-dependent, so ceilings sit at roughly 2x the maintainer-box observation. This catches a stage
# growing several-fold. It is not meant to police a busy box, which is why nothing here is tight.
# The waiver map is parsed HERE, before any gate runs, so a malformed -AllowFailingGate is refused in
# seconds rather than after several minutes of green gates. A bare filename with no backlog id is
# rejected on purpose: "this is broken and someone owns it" is the whole difference between a waiver
# and a shrug, and the owning id is the only part of that a script can actually check.
$gateWaivers = @{}
foreach ($spec in @($AllowFailingGate | ForEach-Object { $_ -split ',' } | Where-Object { $_ })) {
    $parts = $spec.Trim() -split '=', 2
    if ($parts.Count -ne 2 -or -not $parts[0].Trim() -or -not $parts[1].Trim()) {
        Write-Host "Release REFUSED: -AllowFailingGate expects '<File.Tests.ps1>=<backlog-id>', got '$spec'."
        Write-Host "  A waiver without an owning item is a silent skip. Example: -AllowFailingGate 'DocTruth.Tests.ps1=B-113'"
        exit 2
    }
    $gateWaivers[$parts[0].Trim()] = $parts[1].Trim()
}

# Pure decision function: given per-file meta-suite results and the operator's waivers, decide what
# still blocks the release. Kept side-effect-free and free of $repo/$script state ON PURPOSE, so
# ReleaseGateWaiver.Tests.ps1 can lift it out by AST and drive every branch without running a
# release. A mechanism whose whole job is to SUPPRESS failures is the last one that should be
# shipped untested.
function Resolve-GateWaiverOutcome {
    param(
        [Parameter(Mandatory)][hashtable]$FileResults,
        [Parameter(Mandatory)][hashtable]$Waivers,
        [int]$TotalExit = 0,
        # Every meta test file the runner knows. A waiver naming one of these that the local subset
        # did not run is refused as CI-only, not mistaken for a typo.
        [string[]]$ManifestFiles = @()
    )
    $messages = @(); $waived = @(); $blocking = 0; $refused = $false

    if ($FileResults.Count -eq 0) {
        # No per-file data. Fall back to the summed total, and refuse to honour a waiver against it:
        # waiving a number you cannot attribute is waiving everything.
        if ($Waivers.Count -gt 0) {
            $messages += 'GATE FAIL: -AllowFailingGate was passed but the meta suite emitted no per-file RESULT lines; refusing to waive a total.'
            $refused = $true
        }
        return [pscustomobject]@{ Messages = $messages; Waived = $waived; BlockingFailures = $TotalExit; Refused = $refused; GateLabel = 'meta-hook test suite' }
    }

    foreach ($name in ($FileResults.Keys | Sort-Object)) {
        if ($FileResults[$name] -eq 0) { continue }
        if ($Waivers.ContainsKey($name)) {
            $waived += "$name ($($FileResults[$name]) failure(s), waived under $($Waivers[$name]))"
            $messages += "GATE WAIVED: meta-suite $name -- $($FileResults[$name]) failure(s), owned by $($Waivers[$name]). It still ran; only its power to block is suspended."
        } else {
            $blocking += $FileResults[$name]
        }
    }
    # A waiver naming a file that PASSED, or that did not run at all, is stale. Refuse it -- otherwise
    # the flag outlives the breakage it was granted for and silently covers the next one.
    foreach ($name in ($Waivers.Keys | Sort-Object)) {
        if (-not $FileResults.ContainsKey($name) -and $ManifestFiles -contains $name) {
            $messages += "GATE FAIL: -AllowFailingGate names '$name', which runs in CI only; release.ps1 does not run it locally, so there is nothing to waive."
            $refused = $true
        } elseif (-not $FileResults.ContainsKey($name)) {
            $messages += "GATE FAIL: -AllowFailingGate names '$name', which the meta suite did not run. Check the filename."
            $refused = $true
        } elseif ($FileResults[$name] -eq 0) {
            $messages += "GATE FAIL: -AllowFailingGate names '$name', but it PASSED. Remove the stale waiver."
            $refused = $true
        }
    }
    $label = if ($waived.Count -gt 0) { 'meta-hook test suite (excluding recorded waivers)' } else { 'meta-hook test suite' }
    return [pscustomobject]@{ Messages = $messages; Waived = $waived; BlockingFailures = $blocking; Refused = $refused; GateLabel = $label }
}

$gateBudgetPath = Join-Path $repo 'meta/gate-budget.json'
$gateBudget = if (Test-Path -LiteralPath $gateBudgetPath) { Get-Content -Raw -LiteralPath $gateBudgetPath | ConvertFrom-Json } else { $null }
$stageTimings = [ordered]@{}
function Measure-Stage([string]$Name, [scriptblock]$Body) {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try { & $Body } finally {
        $sw.Stop()
        $script:stageTimings[$Name] = [math]::Round($sw.Elapsed.TotalSeconds, 1)
        Write-Host ("TIME  {0,-18} {1,7:N1}s" -f $Name, $sw.Elapsed.TotalSeconds)
    }
}
function Assert-GateBudget {
    if (-not $gateBudget) { Write-Host 'GATE FAIL: meta/gate-budget.json is missing -- the runtime ceiling cannot be enforced.'; $script:fatal = $true; return }
    $total = 0.0
    foreach ($name in $stageTimings.Keys) {
        $total += $stageTimings[$name]
        $ceiling = $gateBudget.'ceilings-seconds'.$name
        if ($null -eq $ceiling) { continue }
        Gate ($stageTimings[$name] -le $ceiling) ("gate budget: $name took $($stageTimings[$name])s, ceiling ${ceiling}s")
    }
    $totalCeiling = $gateBudget.'ceilings-seconds'.'total-local-gates'
    if ($null -ne $totalCeiling) {
        Gate ($total -le $totalCeiling) ("gate budget: local gates took $([math]::Round($total,1))s, ceiling ${totalCeiling}s")
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
# is not a useful local gate. Since B-245 the local meta suite is the four release-subject files
# (13.2s serial, 2026-09-19); CI owns the full meta suite and all shipped-hook coverage on the
# release commit before the tag. Re-measure before changing the budget or this banner.
Write-Host "Releasing $Version. Local gates: compose x3 -> validate-dist x3 + context footprint -> release-subject meta files (DocTruth, ReleaseChangelogStamp, GateBudgetConsistency, WorkspaceBom)."
Write-Host "Before the commit, when the release changes what agents are told: live agent runs on the candidate (B-521; measured at about 0.30 USD and 2 minutes; -WaiveAgentRuns `"<reason>`" skips them and the tag records it)."
Write-Host "Before a normal tag, CI must pass all four Windows contexts: root plus three shipped-hook matrices under PowerShell 7."
# The interruption promise used to be "nothing has been committed", full stop. After the push that is
# simply false, and B-88 makes the window longer by adding a multi-minute wait to it. State the three
# durable states instead; all three are safe to re-run the same command from (step 5 now falls
# through to the publish phase rather than exiting when there is nothing left to stage).
Write-Host "If interrupted, you are in exactly one of three states, and re-running the same command as-is is safe in all of them:"
Write-Host "  before 'Staged manifest'         -> nothing committed (also during the pre-tag agent runs that follow it)."
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
# four meta test files whose subject the release commit changes.
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
        # The job wall clock is what the stage budget spends, while the inner measurement isolates
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
$waiversApplied = @()
Measure-Stage 'meta-suite' {
$metaLog = [System.IO.Path]::GetTempFileName()
try {
    # B-245: locally, only the files whose subject the release commit itself changes -- version
    # stamps and changelog heads, the gate budget, new .ps1 bytes. CI runs the whole suite on the
    # release commit, and the tag still waits for that run. -File is single-valued, so one run each;
    # their output is concatenated so RESULT parsing and waivers see one transcript.
    $localMetaFiles = @('DocTruth.Tests.ps1', 'ReleaseChangelogStamp.Tests.ps1', 'GateBudgetConsistency.Tests.ps1', 'WorkspaceBom.Tests.ps1')
    $metaExit = 0; $metaText = ''
    foreach ($metaFile in $localMetaFiles) {
        & pwsh -NoProfile -File (Join-Path $repo '.claude/hooks/tests/Invoke-HookTests.ps1') -File $metaFile *> $metaLog
        $metaExit += [int]$LASTEXITCODE
        $metaText += [System.IO.File]::ReadAllText($metaLog)
    }
    Write-Host -NoNewline $metaText
    # Per-file results, so a waiver can name one file instead of the summed total. If any local
    # file emitted no RESULT line (a runner refusal exits 2 without one), attribute nothing: an
    # empty map falls back to the summed total, which blocks and refuses every waiver.
    $fileResults = @{}
    foreach ($m in [regex]::Matches($metaText, '(?m)^RESULT\s+(\S+)\s+(\d+)\s*$')) {
        $fileResults[$m.Groups[1].Value] = [int]$m.Groups[2].Value
    }
    if (@($localMetaFiles | Where-Object { -not $fileResults.ContainsKey($_) }).Count -gt 0) { $fileResults = @{} }
    $manifestFiles = @(Get-ChildItem -LiteralPath (Join-Path $repo '.claude/hooks/tests') -Filter *.Tests.ps1 | ForEach-Object Name)
    $outcome = Resolve-GateWaiverOutcome -FileResults $fileResults -Waivers $gateWaivers -TotalExit $metaExit -ManifestFiles $manifestFiles
    foreach ($line in $outcome.Messages) { Write-Host $line }
    # $script: is load-bearing -- this runs inside Measure-Stage's scriptblock, which is a child
    # scope, so a bare assignment would land on a local copy and the commit and tag would claim
    # "all gates green" while a waiver was in force.
    $script:waiversApplied += $outcome.Waived
    if ($outcome.Refused) { $script:fatal = $true }
    Gate ($outcome.BlockingFailures -eq 0) $outcome.GateLabel
} finally {
    Remove-Item -LiteralPath $metaLog -Force -ErrorAction SilentlyContinue
}
}
Assert-GateBudget

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
# ---- 5b. Pre-tag agent runs (B-521), then commit -- both skipped when resuming a release whose commit already exists ----
# The staged tree becomes a commit object no branch points to; Invoke-AgentRunStage checks it out in
# a temporary worktree and runs the candidate's own runner there. Its rows ride in the release commit,
# whose tree is asserted to be the evaluated one but for those rows. On exit 1 or 3 the index is reset
# and nothing is committed, pushed or tagged; the rows stay in the working tree.
$agentRunNote = ''
if (-not $nothingToCommit -and $WaiveAgentRuns) {
    $agentRunNote = "WAIVED (-WaiveAgentRuns): $($WaiveAgentRuns -replace '\r?\n', ' ')"
    Write-Host ''
    Write-Host "Pre-tag agent runs: $agentRunNote"
} elseif (-not $nothingToCommit) {
    Write-Host ''
    $tree = Invoke-AgentRunGit -Repo $repo -Arguments @('write-tree')
    $candidate = if ($tree.Exit -eq 0) { Invoke-AgentRunGit -Repo $repo -Arguments @('commit-tree', $tree.Out.Trim(), '-p', 'HEAD', '-m', "B-521 pre-tag candidate v$Version") } else { $tree }
    $range = if ($candidate.Exit -eq 0) { Get-AgentRunRange -Repo $repo -Version $Version -CandidateSha $candidate.Out.Trim() } else { [pscustomobject]@{ Exit = 3; Message = "could not examine: the candidate commit could not be made: $($candidate.Err.Trim())" } }
    if ($range.Exit -ne 0) {
        git -C $repo reset --quiet
        Write-Host "Pre-tag agent runs: $($range.Message)"
        Write-Host "`nRelease REFUSED (exit 3, could not examine). Nothing was committed; the index has been reset. Fix it and re-run the same command, or pass -WaiveAgentRuns `"<reason>`"."
        exit 3
    }
    if (-not $range.Trigger.Count) {
        $agentRunNote = "not triggered: none of the $($range.Changed) path(s) changed since v$($range.Previous) is one agents are told"
        Write-Host "Pre-tag agent runs: $agentRunNote."
    } else {
        Write-Host "Pre-tag agent runs: $($range.Trigger.Count) of $($range.Changed) path(s) changed since v$($range.Previous) are ones agents are told; running $($agentRunScenarios -join ', ') against the candidate (stop at $agentRunSpendStopUsd USD)..."
        $stored = Invoke-AgentRunGit -Repo $repo -Arguments @('show', "$($range.BaseSha):meta/eval-results.md")
        $stage = Invoke-AgentRunStage -Repo $repo -CandidateSha $candidate.Out.Trim() -BaseSha $range.BaseSha -BaseVersion $range.Previous `
            -Scenarios $agentRunScenarios -StoredResultsText $(if ($stored.Exit -eq 0) { $stored.Out } else { '' }) -SpendStopUsd $agentRunSpendStopUsd -AllowedTools $agentRunAllowedTools
        $record = @('', "## $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss K') $([char]0x2014) pre-tag agent runs, v$Version candidate (B-521)", '',
            "Base v$($range.Previous) ($($range.BaseSha.Substring(0, 8))) · candidate tree $($tree.Out.Trim().Substring(0, 8)) · trigger: $($range.Trigger.Count) of $($range.Changed) changed paths · allowed tools: $($agentRunAllowedTools -join ' ') · verdict: $($stage.Verdict) (exit $($stage.Exit)) · spent $($stage.SpentUsd) USD", '') +
            @($stage.RowLines) + @($stage.Lines | ForEach-Object { "- $_" }) + @('')
        Add-Content -LiteralPath (Join-Path $repo 'meta/eval-results.md') -Value ($record -join "`n") -Encoding utf8NoBOM
        foreach ($line in $stage.Lines) { Write-Host "  $line" }
        Write-Host "Pre-tag agent runs: $($stage.Verdict) (exit $($stage.Exit)); spent $($stage.SpentUsd) USD; rows in meta/eval-results.md."
        if ($stage.Exit -ne 0) {
            git -C $repo reset --quiet
            $what = if ($stage.Exit -eq 1) { 'the candidate does worse than the previous release' } else { 'the runs could not be examined' }
            Write-Host "`nRelease REFUSED (exit $($stage.Exit)): $what. Nothing was committed; the index has been reset and the rows stay in meta/eval-results.md."
            Write-Host "Fix it and re-run the same command, or pass -WaiveAgentRuns `"<reason>`", which the release commit and tag record."
            exit $stage.Exit
        }
        git -C $repo add -- meta/eval-results.md
        $committedTree = Invoke-AgentRunGit -Repo $repo -Arguments @('write-tree')
        $drift = if ($committedTree.Exit -eq 0) { Invoke-AgentRunGit -Repo $repo -Arguments @('diff-tree', '-r', '--name-only', $tree.Out.Trim(), $committedTree.Out.Trim()) } else { $committedTree }
        if ($drift.Exit -ne 0 -or (@($drift.Out -split '\r?\n' | Where-Object { $_ }) -join ',') -cne 'meta/eval-results.md') {
            git -C $repo reset --quiet
            [Console]::Error.WriteLine("FATAL: the tree to commit is not the evaluated candidate plus its rows ($(@($drift.Out -split '\r?\n' | Where-Object { $_ }) -join ', ')); nothing was committed.")
            exit 2
        }
        $agentRunNote = "$($stage.Verdict) against v$($range.Previous), spent $($stage.SpentUsd) USD: $($stage.Lines -join '; ')"
    }
}
if (-not $nothingToCommit) {
    Write-Host ''
    # "all gates green" must stop being said the moment it stops being true. A waived gate is named
    # in the commit body with its owning item, so `git log` alone answers what this release did and
    # did not prove.
    $gateNote = if ($waiversApplied.Count -gt 0) {
        "Released via .claude/scripts/release.ps1 — local deterministic gates green (compose ×3, validate-dist ×3 + context footprint, the four release-subject meta test files) EXCEPT these recorded waivers: $($waiversApplied -join '; '). No shipped dist hook suite runs locally; normal tagging waits for CI's PowerShell 7 three-dist hook matrices."
    } else {
        'Released via .claude/scripts/release.ps1 — all local deterministic gates green (compose ×3, validate-dist ×3 + context footprint, the four release-subject meta test files). No shipped dist hook suite runs locally; normal tagging waits for CI''s PowerShell 7 three-dist hook matrices.'
    }
    $commitNotes = @('-m', $gateNote)
    if ($agentRunNote) { $commitNotes += @('-m', "Pre-tag agent runs (B-521): $agentRunNote") }
    git -C $repo commit -m "v${Version}: $Summary" @commitNotes
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
    # A gate waiver changes what the tag means just as much as an unverified-CI waiver does, so it
    # rides on the same annotation rather than living only in a terminal that scrolls away.
    $tagWaiverNote = if ($waiversApplied.Count -gt 0) { " — gate waivers: $($waiversApplied -join '; ')" } else { '' }
    $ciMatrixNote = if ($ciDecision.Status -eq 'GREEN') {
        ' — CI verified root meta suites plus shipped hook suites for dotnet, angular, and monorepo under PowerShell 7 before tag'
    } else {
        ' — CI full hook matrix not verified (see CI waiver/status)'
    }
    # B-521: the pre-tag agent runs' line, read back from the release commit so a resumed run (which
    # made no commit) records it too; a -WaiveAgentRuns waiver is the case that matters most.
    $releaseBody = @(git -C $repo log -1 --format=%B $releaseSha)
    $agentRunLine = @($releaseBody | Where-Object { $_ -like 'Pre-tag agent runs (B-521): *' } | Select-Object -First 1)
    $tagAgentRunNote = if ($agentRunLine) { " — $($agentRunLine[0])" } else { '' }
    git -C $repo tag -a $tagName -m "ai-tech-lead $tagName$($ciDecision.TagNote)$ciMatrixNote$tagWaiverNote$tagAgentRunNote" $releaseSha
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
