# Push a branch and, when that branch has a CI push trigger, watch the resulting run (B-137).
# Maintainer-only, does NOT ship. PowerShell-only by the existing .claude/scripts decision.
#
# Usage: pwsh -NoProfile -File .claude/scripts/push-and-check.ps1 [-Branch <branch>]
#              [-WatchedBranches master] [-TimeoutSeconds 1200] [-AppearSeconds 180]
#              [-PollSeconds 20] [-GhPath <path>] [-GitPath <path>] [-RepoRoot <path>]
param(
    # Defaults to the checked-out branch, resolved through git after -GitPath is resolved.
    [string]$Branch,
    # Keep this default in sync with the branches under `on: push:` in .github/workflows/ci.yml.
    [string[]]$WatchedBranches = @('master'),
    [int]$TimeoutSeconds = 1200,
    [int]$AppearSeconds = 180,
    [int]$PollSeconds = 20,
    # Passed through to watch-ci.ps1; that script owns gh resolution and CI classification.
    [string]$GhPath,
    # Escape hatch for tests and non-standard installs. Normally resolved by Resolve-Git.
    [string]$GitPath,
    [string]$RepoRoot
)
$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
function Write-Line { param([string]$m) Write-Host $m }

function Get-GitCandidates {
    $c = @()
    if ($env:ProgramFiles)        { $c += (Join-Path $env:ProgramFiles 'Git\cmd\git.exe') }
    if (${env:ProgramFiles(x86)}) { $c += (Join-Path ${env:ProgramFiles(x86)} 'Git\cmd\git.exe') }
    if ($env:LOCALAPPDATA)        { $c += (Join-Path $env:LOCALAPPDATA 'Programs\Git\cmd\git.exe') }
    return @($c | Where-Object { Test-Path -LiteralPath $_ })
}

function Resolve-Git {
    param([string]$Explicit)
    if ($Explicit) {
        if (Test-Path -LiteralPath $Explicit) { return $Explicit }
        $found = @(Get-GitCandidates)
        $hint = if (@($found).Count -gt 0) {
            "A real git IS installed at $($found[0]) -- drop -GitPath to use it."
        } else { 'No Git found at any well-known location either.' }
        Write-Line "PUSH FAILED: -GitPath '$Explicit' does not exist."
        Write-Line "  $hint"
        exit 2
    }
    $onPath = (Get-Command git -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($onPath -and $onPath.Source) { return $onPath.Source }
    $found = @(Get-GitCandidates)
    if (@($found).Count -gt 0) {
        Write-Line "note: git is not on PATH; using $($found[0])."
        return $found[0]
    }
    Write-Line 'PUSH FAILED: no git on PATH and none at any well-known install location.'
    Write-Line '  Install Git or pass -GitPath.'
    exit 2
}

$git = Resolve-Git -Explicit $GitPath

# Native stderr must go to a file: Windows PowerShell 5.1 otherwise promotes a non-zero native
# process's stderr to a terminating NativeCommandError under the script-wide Stop preference.
function Invoke-GitCaptured {
    param([string[]]$GitArgs, [switch]$Live)
    $ef = [IO.Path]::GetTempFileName()
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($Live) {
            # Piping into `| Out-Host` is load-bearing, not decoration: inside a function whose
            # result the caller captures (`$r = Invoke-GitCaptured ...`), any pipeline output NOT
            # explicitly sent to the host is swallowed into the function's own return stream rather
            # than reaching the console -- assigning to $out (as the non-live branch does) suppresses
            # display entirely, and merely omitting the assignment does not fix it, because the
            # function boundary itself re-captures unassigned output. Measured directly: without
            # `| Out-Host` here, `git --version`'s stdout never appeared between two Write-Host calls
            # bracketing this function -- only adding `| Out-Host` made it appear live.
            & $git @GitArgs 2>$ef | Tee-Object -Variable streamed | Out-Host
            $out = @($streamed)
        } else {
            $out = @(& $git @GitArgs 2>$ef)
        }
        $code = $LASTEXITCODE
        $err = [IO.File]::ReadAllText($ef)
        if ($Live -and $err) { [Console]::Error.Write($err) }
        return [pscustomobject]@{ Exit=$code; Out=(($out -join "`n").Trim()); Err=$err }
    } finally {
        $ErrorActionPreference = $prev
        if (Test-Path -LiteralPath $ef) { [IO.File]::Delete($ef) }
    }
}

if (-not $Branch) {
    $current = Invoke-GitCaptured -GitArgs @('-C', $RepoRoot, 'rev-parse', '--abbrev-ref', 'HEAD')
    if ($current.Exit -ne 0 -or -not $current.Out) {
        Write-Line 'PUSH FAILED: could not resolve the current branch.'
        if ($current.Err) { [Console]::Error.Write($current.Err) }
        exit $(if ($current.Exit) { $current.Exit } else { 2 })
    }
    $Branch = $current.Out.Trim()
}

$push = Invoke-GitCaptured -GitArgs @('-C', $RepoRoot, 'push', 'origin', $Branch) -Live
if ($push.Exit -ne 0) {
    Write-Line "PUSH FAILED (git exit $($push.Exit))."
    # stdout was streamed already and stderr was printed immediately after the native call. Keep
    # both captured values available above without duplicating them here.
    exit $push.Exit
}

if ($WatchedBranches -notcontains $Branch) {
    Write-Line "Push succeeded for '$Branch'; CI push-trigger watching applies only to [$($WatchedBranches -join ', ')], so it is being skipped."
    exit 0
}

$head = Invoke-GitCaptured -GitArgs @('-C', $RepoRoot, 'rev-parse', 'HEAD')
if ($head.Exit -ne 0 -or -not $head.Out) {
    Write-Line 'PUSH FAILED: push succeeded, but the pushed commit SHA could not be resolved.'
    if ($head.Err) { [Console]::Error.Write($head.Err) }
    exit $(if ($head.Exit) { $head.Exit } else { 2 })
}
$sha = $head.Out.Trim()
$watch = Join-Path $PSScriptRoot 'watch-ci.ps1'
$watchArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$watch,
    '-Sha',$sha,'-TimeoutSeconds',$TimeoutSeconds,'-AppearSeconds',$AppearSeconds,
    '-PollSeconds',$PollSeconds,'-RepoRoot',$RepoRoot)
if ($GhPath) { $watchArgs += @('-GhPath',$GhPath) }

Write-Line "Pushed $Branch @ $sha; watching CI..."
& (Get-Process -Id $PID).Path @watchArgs
$watchExit = $LASTEXITCODE
Write-Line "CI watch finished with exit $watchExit."
exit $watchExit
