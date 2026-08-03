# Watch the CI run for a commit and report its conclusion (B-88). Maintainer-only, does NOT ship.
#
# Usage:  pwsh -NoProfile -File .claude/scripts/watch-ci.ps1 -Sha <sha> [-TimeoutSeconds 1200]
#                [-AppearSeconds 180] [-PollSeconds 20] [-GhPath <path>] [-ExpectedJobs windows,linux]
#
# WHY THIS EXISTS. release.ps1 ran every local gate, refused to commit on failure, pushed, tagged,
# and exited -- BEFORE CI had an opinion. So "Release complete" was a statement about the
# maintainer's box, not about the repo. On 2026-08-02 v0.44.0 went red on both CI legs, and so did
# the three commits after it: four consecutive red runs on master, unnoticed for over an hour, and
# only because the maintainer asked.
#
# THE EXIT CONTRACT IS THE POINT -- three outcomes, not two:
#   0  the CI workflow's push run for -Sha completed AND concluded success, AND every expected job
#      (the two CI legs) concluded success.
#   1  it concluded failure/cancelled/timed_out/action_required/startup_failure, or an expected job
#      concluded something other than success.
#   3  CANT-VERIFY -- the result could not be observed at all: no gh, gh failed, output did not
#      parse, no run appeared, still running at the timeout, an unrecognised conclusion, or an
#      expected job absent (absent is not the same fact as failed -- B-71/B-85's shared lesson).
#
# NO PATH MAY EXIT 0 WITHOUT A POSITIVE OBSERVATION OF SUCCESS. Every unknown resolves to 3. That
# rule is the whole reason this file is not three lines of `gh run list | grep success`: B-64, B-72,
# B-74 and B-75 were all instruments that could not fail, reporting success.
#
# PowerShell-only by decision (meta/workspace-decisions.md): meta scripts run only on the
# maintainer's box; invariant #3 twin parity binds shipped hooks/scripts and scripts/, not this.
param(
    [Parameter(Mandatory)][string]$Sha,
    # Overall budget. CI has measured ~7-8 min wall time on this repo; 20 min leaves room for a
    # queued runner without waiting forever.
    [int]$TimeoutSeconds = 1200,
    # Sub-deadline (inside TimeoutSeconds) for the run to be REGISTERED at all. A push does not
    # create a run instantly, so an empty result early means "not yet", not "no CI".
    [int]$AppearSeconds = 180,
    [int]$PollSeconds = 20,
    # Escape hatch for tests and for a non-standard install. Normally resolved (see Resolve-Gh).
    [string]$GhPath,
    [string]$RepoRoot,
    # The two CI legs (.github/workflows/ci.yml). A workflow-level `success` does not prove both legs
    # ran -- watching only the aggregate is how a silently-skipped leg would look green.
    [string[]]$ExpectedJobs = @('windows', 'linux')
)
$ErrorActionPreference = 'Stop'

$EXIT_GREEN = 0
$EXIT_RED   = 1
$EXIT_CANT  = 3

if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }

function Write-Line { param([string]$m) Write-Host $m }

# Run git without letting a non-zero exit kill this script.
#
# WINDOWS POWERSHELL 5.1 ONLY: 5.1 turns a native command's stderr into a NativeCommandError record,
# and under $ErrorActionPreference='Stop' that record is TERMINATING -- `2>$null` redirects the text
# but does NOT stop the record being raised. pwsh 7 does not do this ($PSNativeCommandUseErrorAction-
# Preference defaults to False -- verified on this box, 7.6.4). So `git rev-parse` against a
# non-repo directory silently worked under 7 and killed the script under 5.1, with NO output at all.
#
# That defect was invisible until the test suite was made to run the watcher under the SAME host the
# suite runs under; with the harness's default host resolution (which prefers pwsh 7 whenever it
# resolves) 5.1 was never actually the host under test. That is verbatim B-74's finding, one release
# later, in new code.
function Invoke-GitQuiet {
    param([string[]]$GitArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & git @GitArgs 2>$null
        return [pscustomobject]@{ Exit = $LASTEXITCODE; Out = (($out -join "`n").Trim()) }
    } finally { $ErrorActionPreference = $prev }
}

# Every CANT-VERIFY exit goes through here, so none of them can accidentally read as success and all
# of them say WHY. An unverifiable CI result must never be reported as a verified one; the doctor's
# CANT-VERIFY tier already models this in the shipped product.
function Exit-CantVerify {
    param([string]$Reason, [string]$Hint)
    Write-Line ''
    Write-Line "CI CANT-VERIFY: $Reason"
    if ($Hint) { Write-Line "  $Hint" }
    exit $EXIT_CANT
}

# ---- 1. Resolve gh -------------------------------------------------------------------------------
# NOT optional plumbing on the maintainer box: `Get-Command gh` FAILS there while gh.exe is installed
# and authenticated, because the session PATH is the corrupted one (a literal unexpanded ${PATH}).
# Without the absolute-path fallback this feature would be dead on the machine it was written for.
#
# The message must distinguish two DIFFERENT facts -- "no GitHub CLI on this host" and "found at
# <path> but not on PATH". Reporting a broken PATH identically to an absent tool is exactly what let
# B-71's 5.1 skip and B-85's bash-leg FATAL persist.
function Get-GhCandidates {
    $c = @()
    if ($env:ProgramFiles)        { $c += (Join-Path $env:ProgramFiles 'GitHub CLI\gh.exe') }
    if (${env:ProgramFiles(x86)}) { $c += (Join-Path ${env:ProgramFiles(x86)} 'GitHub CLI\gh.exe') }
    if ($env:LOCALAPPDATA)        { $c += (Join-Path $env:LOCALAPPDATA 'Programs\GitHub CLI\gh.exe') }
    return @($c | Where-Object { Test-Path -LiteralPath $_ })
}

function Resolve-Gh {
    param([string]$Explicit)
    if ($Explicit) {
        if (Test-Path -LiteralPath $Explicit) { return $Explicit }
        $found = @(Get-GhCandidates)
        $hint = if (@($found).Count -gt 0) {
            "A real gh IS installed at $($found[0]) -- drop -GhPath to use it."
        } else {
            'No GitHub CLI found at any well-known location either.'
        }
        Exit-CantVerify -Reason "-GhPath '$Explicit' does not exist." -Hint $hint
    }
    $onPath = (Get-Command gh -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($onPath -and $onPath.Source) { return $onPath.Source }
    $found = @(Get-GhCandidates)
    if (@($found).Count -gt 0) {
        # Resolved, but say so: this is a HOST/PATH fact worth surfacing, not a silent fixup.
        Write-Line "note: gh is not on PATH; using $($found[0]) (this box's PATH is known-corrupted)."
        return $found[0]
    }
    Exit-CantVerify -Reason 'no GitHub CLI (gh) on PATH and none at any well-known install location.' `
        -Hint 'Install it (winget install --id GitHub.cli) or pass -GhPath. This is a host problem, not a release problem.'
}

$gh = Resolve-Gh -Explicit $GhPath

# Invoke gh capturing stdout, stderr and the exit code separately (the _HookHarness.ps1 pattern:
# merging 2>&1 would put stderr text into the JSON we are about to parse).
function Invoke-Gh {
    param([string[]]$GhArgs)
    # Same 5.1 hazard as Invoke-GitQuiet: a gh that exits non-zero (unauthenticated, offline, rate
    # limited) must be REPORTED as CANT-VERIFY, not raised as a terminating error that kills the
    # script before it can say so.
    $ef = [IO.Path]::GetTempFileName()
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out  = & $gh @GhArgs 2>$ef
        $code = $LASTEXITCODE
        $err  = [IO.File]::ReadAllText($ef)
        return [pscustomobject]@{ Exit = $code; Out = ($out -join "`n"); Err = $err; Args = $GhArgs }
    } finally {
        $ErrorActionPreference = $prev
        if (Test-Path -LiteralPath $ef) { [IO.File]::Delete($ef) }
    }
}

function Invoke-GhJson {
    param([string[]]$GhArgs, [string]$What)
    $r = Invoke-Gh -GhArgs $GhArgs
    if ($r.Exit -ne 0) {
        Exit-CantVerify -Reason "gh exited $($r.Exit) while $What." `
            -Hint ("gh said: " + (("$($r.Err)`n$($r.Out)").Trim() -replace '\s+', ' '))
    }
    # Flattened DELIBERATELY, and it is not defensive noise -- two different mechanisms wrapped these
    # rows one level too deep, and both had the same consequence: `$_.event` on a wrapped array
    # returns the collection of ALL events, `-eq 'push'` matches a non-empty result, non-empty is
    # truthy, and a failed pull_request run for the same sha decides the release.
    #   1. A unary comma on this return (`,(@(...))`) -- @() at the CALL site does not flatten it.
    #   2. Windows PowerShell 5.1's ConvertFrom-Json, which does not enumerate a top-level JSON
    #      array: `@('[{a},{b}]' | ConvertFrom-Json).Count` is 1 under 5.1 and 2 under pwsh 7
    #      (measured). -NoEnumerate does not exist in 5.1, so the flatten has to be explicit.
    # SINGLE-row payloads survive both bugs by accident -- a one-element wrapper behaves like the
    # element for property access -- so only the multi-row cases can see this. That is why the
    # event-filter and re-run cases exist, and why they are worth their weight.
    try {
        $parsed = $r.Out | ConvertFrom-Json
        $flat = New-Object System.Collections.Generic.List[object]
        foreach ($p in @($parsed)) {
            if ($null -ne $p -and $p -is [System.Collections.IEnumerable] -and $p -isnot [string]) {
                foreach ($q in $p) { $flat.Add($q) }
            } else { $flat.Add($p) }
        }
        return $flat.ToArray()
    }
    catch {
        # A parse failure must never read as green. This is the shape of the trap: an empty or
        # unexpected payload silently becoming "no failures found". Say WHY it did not parse -- a
        # bare "did not parse" sends the reader looking in the wrong place.
        Exit-CantVerify -Reason "gh output did not parse as JSON while $What ($($_.Exception.Message))." `
            -Hint ("first 200 chars: " + $r.Out.Substring(0, [Math]::Min(200, $r.Out.Length)))
    }
}

# ---- 2. Repo slug --------------------------------------------------------------------------------
# Asked of gh itself rather than regexed out of the remote URL: gh already understands SSH forms,
# ports, enterprise hosts and insteadOf rewrites. -R <slug> is then passed on EVERY call so the
# answer never depends on the caller's working directory (B-63's vantage-point class).
$slug = $null
Push-Location $RepoRoot
try {
    $r = Invoke-Gh -GhArgs @('repo', 'view', '--json', 'nameWithOwner')
    if ($r.Exit -eq 0) {
        try { $slug = (@($r.Out | ConvertFrom-Json))[0].nameWithOwner } catch { $slug = $null }
    }
    if (-not $slug) {
        $g = Invoke-GitQuiet -GitArgs @('-C', $RepoRoot, 'remote', 'get-url', 'origin')
        if ($g.Exit -eq 0 -and $g.Out -match 'github\.com[:/](?<slug>[^/]+/[^/\s]+?)(?:\.git)?\s*$') {
            $slug = $Matches['slug']
        }
    }
} finally { Pop-Location }
if (-not $slug) {
    Exit-CantVerify -Reason 'could not determine the GitHub owner/repo for this checkout.' `
        -Hint 'gh repo view failed and origin does not look like a github.com remote. Is gh authenticated (gh auth status)?'
}

# ---- 3. Expand the sha ---------------------------------------------------------------------------
# A short sha is convenient on the command line but headSha comes back full, so expand it here and
# fall back to prefix matching when git cannot resolve it (e.g. driven from a scratch dir in tests).
$g = Invoke-GitQuiet -GitArgs @('-C', $RepoRoot, 'rev-parse', $Sha)
$fullSha = if ($g.Exit -eq 0 -and $g.Out) { $g.Out } else { $Sha }
$fullSha = "$fullSha".Trim()

function Test-ShaMatch {
    param([string]$HeadSha)
    if (-not $HeadSha) { return $false }
    $a = $HeadSha.ToLowerInvariant(); $b = $fullSha.ToLowerInvariant()
    if ($a.Length -le $b.Length) { return $b.StartsWith($a) }
    return $a.StartsWith($b)
}

Write-Line "Watching CI for $slug @ $($fullSha.Substring(0, [Math]::Min(7, $fullSha.Length))) (timeout ${TimeoutSeconds}s)."

# ---- 4. Poll -------------------------------------------------------------------------------------
# ONE monotonic clock for both budgets: the appearance window is a sub-deadline inside the overall
# timeout, not a second independent wall-clock sum (which would also be vulnerable to clock changes).
$listArgs = @('run', 'list', '-R', $slug, '--commit', $fullSha, '--json',
              'databaseId,status,conclusion,workflowName,url,headSha,event')
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$settled = $false
$watched = $null

while ($true) {
    $rows = @(Invoke-GhJson -GhArgs $listArgs -What "listing runs for $fullSha")
    # Only the PUSH run decides a release. CI also triggers on pull_request (ci.yml:17-21), so a sha
    # can carry a PR run whose verdict is not this release's.
    $mine = @($rows | Where-Object { $_.event -eq 'push' -and (Test-ShaMatch $_.headSha) })

    if (@($mine).Count -eq 0) {
        if ($sw.Elapsed.TotalSeconds -ge $AppearSeconds) {
            Exit-CantVerify -Reason "no push run appeared for $fullSha within ${AppearSeconds}s." `
                -Hint "Check https://github.com/$slug/actions -- CI may be disabled, or the push may not have landed on a branch CI watches."
        }
        Write-Line ("  no run yet ... {0:n0}s elapsed" -f $sw.Elapsed.TotalSeconds)
        Start-Sleep -Seconds $PollSeconds
        continue
    }

    # Settle once before locking the workflow set. Today there is exactly one workflow, so "first row
    # = the complete set" happens to hold -- it would silently become premature the day a second
    # workflow is added and registers a moment later.
    if (-not $settled) {
        $settled = $true
        Write-Line ("  run(s) registered; settling ... {0:n0}s elapsed" -f $sw.Elapsed.TotalSeconds)
        Start-Sleep -Seconds $PollSeconds
        continue
    }

    # Latest attempt per workflow. A re-run updates a run in place, so latest-per-workflow is
    # re-run-safe; "any row that failed wins" would report a sha permanently red after a successful
    # re-run.
    $watched = @($mine | Group-Object workflowName | ForEach-Object {
        @($_.Group | Sort-Object databaseId -Descending)[0]
    })

    $pending = @($watched | Where-Object { $_.status -ne 'completed' })
    if (@($pending).Count -eq 0) { break }

    if ($sw.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
        $names = (@($pending | ForEach-Object { "$($_.workflowName)=$($_.status)" }) -join ', ')
        Exit-CantVerify -Reason "still running after ${TimeoutSeconds}s: $names." `
            -Hint "Watch it yourself: $($watched[0].url)"
    }
    $names = (@($pending | ForEach-Object { "$($_.workflowName)=$($_.status)" }) -join ', ')
    Write-Line ("  {0} ... {1:n0}s elapsed" -f $names, $sw.Elapsed.TotalSeconds)
    Start-Sleep -Seconds $PollSeconds
}

# ---- 5. Classify the conclusions -----------------------------------------------------------------
# Whitelist success; enumerate the known-bad; send everything ELSE to CANT-VERIFY. GitHub's
# conclusion vocabulary grows (neutral, skipped, stale, ...), and a value this script has never heard
# of is not evidence of success.
$KNOWN_BAD = @('failure', 'cancelled', 'timed_out', 'action_required', 'startup_failure')
$bad     = @($watched | Where-Object { $KNOWN_BAD -contains $_.conclusion })
$good    = @($watched | Where-Object { $_.conclusion -eq 'success' })
$unknown = @($watched | Where-Object { $_.conclusion -ne 'success' -and $KNOWN_BAD -notcontains $_.conclusion })

if (@($bad).Count -gt 0) {
    Write-Line ''
    Write-Line 'CI RED:'
    foreach ($w in $bad) { Write-Line "  $($w.workflowName): $($w.conclusion)  $($w.url)" }
    exit $EXIT_RED
}
if (@($unknown).Count -gt 0) {
    $names = (@($unknown | ForEach-Object { "$($_.workflowName)=$($_.conclusion)" }) -join ', ')
    Exit-CantVerify -Reason "unrecognised conclusion: $names." -Hint "See $($watched[0].url)"
}

# ---- 6. Both legs must have actually run ---------------------------------------------------------
# A workflow-level success does not prove every job ran: a leg can be skipped by a condition, or
# quietly removed. B-70 is about a test never exercised on a leg before shipping; watching only the
# aggregate conclusion cannot see that. (This narrows the exposure -- it does NOT close B-70.)
$jobs = @()
foreach ($w in $watched) {
    $view = Invoke-GhJson -GhArgs @('run', 'view', "$($w.databaseId)", '-R', $slug, '--json', 'jobs') `
                          -What "reading jobs for run $($w.databaseId)"
    if (@($view).Count -gt 0 -and $view[0].jobs) { $jobs += @($view[0].jobs) }
}
$missing = @()
$failedJobs = @()
foreach ($name in $ExpectedJobs) {
    $j = @($jobs | Where-Object { $_.name -eq $name })
    if (@($j).Count -eq 0) { $missing += $name; continue }
    if (@($j | Where-Object { $_.conclusion -ne 'success' }).Count -gt 0) {
        $failedJobs += "$name=$(@($j)[0].conclusion)"
    }
}
if (@($failedJobs).Count -gt 0) {
    Write-Line ''
    Write-Line "CI RED: the workflow concluded success but a leg did not: $($failedJobs -join ', ')"
    Write-Line "  $($watched[0].url)"
    exit $EXIT_RED
}
if (@($missing).Count -gt 0) {
    # ABSENT is not FAILED. A renamed job means this script's expectation is stale, which is a
    # different fact from a leg that ran and failed -- and conflating them is the exact habit
    # B-71/B-85 record. CANT-VERIFY, so it does not tag and does not silently pass either.
    Exit-CantVerify -Reason "expected CI leg(s) not present in the run: $($missing -join ', ')." `
        -Hint ("Jobs observed: " + ((@($jobs | ForEach-Object { $_.name }) | Sort-Object -Unique) -join ', ') +
               ". If ci.yml renamed a job, pass -ExpectedJobs or update the default.")
}

Write-Line ''
Write-Line "CI GREEN: $(@($good).Count) workflow(s), legs $($ExpectedJobs -join ' + ') all success."
Write-Line "  $($watched[0].url)"
exit $EXIT_GREEN
