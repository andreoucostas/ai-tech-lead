# ai-tech-lead dist validator — PowerShell twin of validate-dist.sh. Validates an ALREADY-COMPOSED
# dist/<mode> tree — it does NOT rebuild it (see scripts/build.ps1 for that). Eight checks, each
# with a clear OK/FAIL line:
#   1. no unresolved @stack:NAME markers survive anywhere in the dist (composer leftovers)
#   2. every *.json in the dist parses (ConvertFrom-Json)
#   3. `bash -n` passes on every *.sh in the dist (invokes bash — hard FATAL if unavailable)
#   4. PowerShell AST parse is clean on every *.ps1 in the dist
#   5. the dist's OWN template-checks.ps1 suite passes, run from inside the dist dir
#   6. no meta-dev vocabulary leaks into shipped content (scripts/meta-denylist.txt)
#   7. every script a shipped *.md tells someone to RUN exists (no-dead-instruction)
#   8. every hook registration in settings*.json / hooks.json names a script that exists, with its
#      opposite-language twin (hook-registration)
# Exit 0 = all checks passed. Exit 1 = at least one check failed. Exit 2 = usage error, missing
# dist, or a required tool (bash, for check 3) is unavailable — reported as FATAL, never skipped.
#   Usage: validate-dist.ps1 {dotnet|angular|monorepo} [dist-root]
#   dist-root defaults to "dist" resolved under the repo root (scripts/..). Pass an explicit path
#   to validate a scratch copy instead (e.g. to plant failure fixtures without touching dist/).
# 5.1-safe: no pwsh-only syntax.
# EAP stays 'Continue': under 5.1 with EAP=Stop, a native command (bash -n, template-checks)
# writing to a REDIRECTED stderr raises a terminating NativeCommandError and kills the script
# mid-check — exactly when a planted syntax error should have produced a FAIL line instead.
# Failure detection here is explicit ($LASTEXITCODE / try-catch), not exception-driven.
$ErrorActionPreference = 'Continue'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $RepoRoot

$Mode = $args[0]
if ($Mode -ne 'dotnet' -and $Mode -ne 'angular' -and $Mode -ne 'monorepo') {
    [Console]::Error.WriteLine('usage: validate-dist.ps1 {dotnet|angular|monorepo} [dist-root]')
    exit 2
}
$DistRoot = if ($args.Count -ge 2 -and $args[1]) { $args[1] } else { 'dist' }
$Dist = Join-Path $DistRoot $Mode
if (-not (Test-Path $Dist -PathType Container)) {
    [Console]::Error.WriteLine("no $Dist -- run scripts/build.ps1 $Mode first")
    exit 2
}
# Resolve to absolute NOW: check 5 invokes the dist's own template-checks.ps1, which Set-Location's
# into the dist dir and does not restore it. Any relative path used after check 5 would resolve
# against the wrong root. (The bash twin runs template-checks in a subshell, so its cwd survives --
# resolving up front is what keeps the two legs behaving identically.)
$DistAbs = (Resolve-Path $Dist).Path

$failed = 0
function Fail($m) { Write-Output "FAIL: $m"; $script:failed++ }
function OK($m)   { Write-Output "OK:   $m" }

# Used by check 8. Returns zero or more problem strings for one referenced hook script: the file
# itself, and its opposite-language twin (invariant #3 -- a .ps1 registration whose .sh sibling is
# missing is a half-shipped hook, and the surface that runs the missing one gets nothing).
function Test-HookRef {
    param([string]$Dist, [string]$File, [string]$Script)
    $problems = @()
    # hooks.json writes Windows paths with backslashes, and JSON escaping doubles them, so the raw
    # text holds ".claude\\hooks\\guard.ps1". Collapse any RUN of backslashes to one separator:
    # translating each one separately yields ".claude//hooks//guard.ps1", which happens to resolve on
    # both Windows and POSIX and so would have hidden the sloppiness rather than failing on it.
    $rel = $Script -replace '\\+', '/'
    if ($rel -match '^[A-Za-z]:' -or $rel.StartsWith('/')) { return $problems }   # absolute: not ours to resolve
    if (-not (Test-Path (Join-Path $Dist $rel))) {
        $problems += "$File : `"$rel`" does not exist in this dist"
        return $problems                        # no point asking about the twin of a missing file
    }
    if ($rel -match '\.ps1$')     { $twin = ($rel -replace '\.ps1$', '.sh') }
    elseif ($rel -match '\.sh$')  { $twin = ($rel -replace '\.sh$', '.ps1') }
    else { return $problems }
    if (-not (Test-Path (Join-Path $Dist $twin))) {
        $problems += "$File : `"$rel`" exists but its twin `"$twin`" does not"
    }
    return $problems
}

# --- 1. no unresolved @stack markers -------------------------------------------------------------
$markerRe = '@stack:[A-Za-z0-9_-]+'
$markerFiles = @()
foreach ($f in (Get-ChildItem -Recurse -File -Path $Dist)) {
    try {
        if ((Select-String -Path $f.FullName -Pattern $markerRe -SimpleMatch:$false -Quiet -ErrorAction SilentlyContinue)) {
            $markerFiles += $f.FullName
        }
    } catch { }
}
if ($markerFiles.Count -gt 0) {
    Fail ("unresolved @stack markers in: " + ($markerFiles -join ' '))
} else {
    OK "no unresolved @stack markers in $Dist."
}

# --- 2. every *.json parses -------------------------------------------------------------------------
$jsonFails = @()
foreach ($f in (Get-ChildItem -Recurse -File -Filter *.json -Path $Dist)) {
    try {
        Get-Content $f.FullName -Raw | ConvertFrom-Json | Out-Null
    } catch {
        $jsonFails += $f.FullName
    }
}
if ($jsonFails.Count -gt 0) { Fail ("invalid JSON (ConvertFrom-Json):" + ($jsonFails -join ' ')) }
else { OK "all *.json files parse (ConvertFrom-Json)." }

# --- 3. bash -n on every *.sh ------------------------------------------------------------------------
# Resolve a REAL bash: prefer Git for Windows (not on PowerShell's PATH on typical boxes), and
# never trust a bare `bash` blindly — on Windows that can be the WSL stub in System32, which
# fails without a distro. Probe whatever we picked before using it.
$bashExe = $null
foreach ($candidate in @(
        (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
        (Join-Path $env:ProgramFiles 'Git\usr\bin\bash.exe'))) {
    if ($candidate -and (Test-Path $candidate)) { $bashExe = $candidate; break }
}
if (-not $bashExe) {
    $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
    if ($bashCmd) { $bashExe = $bashCmd.Source }
}
$bashWorks = $false
if ($bashExe) {
    & $bashExe -c 'exit 0' 2>$null 1>$null
    if ($LASTEXITCODE -eq 0) { $bashWorks = $true }
}
if (-not $bashWorks) {
    [Console]::Error.WriteLine('FATAL: no working bash found to syntax-check *.sh files (tried Git for Windows + PATH).')
    exit 2
}
$shFails = @()
foreach ($f in (Get-ChildItem -Recurse -File -Filter *.sh -Path $Dist)) {
    & $bashExe -n ($f.FullName -replace '\\', '/') 2>$null 1>$null
    if ($LASTEXITCODE -ne 0) { $shFails += $f.FullName }
}
if ($shFails.Count -gt 0) { Fail ("bash syntax errors in:" + ($shFails -join ' ')) }
else { OK "all *.sh files parse cleanly (bash -n)." }

# --- 4. PowerShell AST parse on every *.ps1 -----------------------------------------------------------
$ps1Fails = @()
foreach ($f in (Get-ChildItem -Recurse -File -Filter *.ps1 -Path $Dist)) {
    $e = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$e) | Out-Null
    if ($e) { $ps1Fails += "$($f.FullName): $($e[0].Message)" }
}
if ($ps1Fails.Count -gt 0) { Fail ("PS syntax errors: " + ($ps1Fails -join '; ')) }
else { OK "all *.ps1 files parse cleanly." }

# --- 5. the dist's own template-checks suite ------------------------------------------------------
$Tc = Join-Path $Dist 'scripts/template-checks.ps1'
if (-not (Test-Path $Tc)) {
    Fail "missing $Tc -- cannot run the dist's own template-checks suite."
} else {
    $tcOut = & $Tc 2>&1
    $tcStatus = $LASTEXITCODE
    $tcOut | ForEach-Object { Write-Output "  [template-checks] $_" }
    if ($tcStatus -ne 0) {
        Fail "$Tc failed (exit $tcStatus) -- see [template-checks] lines above."
    } else {
        OK "$Tc passed."
    }
}

# --- 6. no meta-dev vocabulary in shipped content -------------------------------------------------
# The don't-ship boundary (invariant #6) made deterministic. Everything under dist/ lands in a
# consumer's repo, so the framework's own development vocabulary — tracking ids, the two-repo
# authoring past, maintainer-only tooling — must not appear there. Patterns live in
# scripts/meta-denylist.txt and are read by BOTH twins, so the denylist itself cannot drift between
# the PowerShell and bash legs (invariant #3).
$DenyFile = Join-Path $RepoRoot 'scripts/meta-denylist.txt'
if (-not (Test-Path $DenyFile)) {
    [Console]::Error.WriteLine("FATAL: missing $DenyFile -- cannot run the no-meta-leak check.")
    exit 2
}
$denyPatterns = @()
$allowPaths   = @()
foreach ($line in (Get-Content $DenyFile)) {
    $t = $line.Trim()
    if ($t -eq '' -or $t.StartsWith('#')) { continue }
    if ($t -match '^DENY\s+(.+)$')  { $denyPatterns += $Matches[1].Trim(); continue }
    if ($t -match '^ALLOW\s+(.+)$') { $allowPaths   += $Matches[1].Trim(); continue }
}
if ($denyPatterns.Count -eq 0) {
    [Console]::Error.WriteLine("FATAL: $DenyFile defines no DENY patterns.")
    exit 2
}
$leaks = @()
foreach ($f in (Get-ChildItem -Recurse -File -Path $DistAbs)) {
    $rel = ($f.FullName.Substring($DistAbs.Length).TrimStart('\', '/')) -replace '\\', '/'
    $skip = $false
    foreach ($a in $allowPaths) { if ($rel -like "*$a*") { $skip = $true; break } }
    if ($skip) { continue }
    foreach ($p in $denyPatterns) {
        # Select-String is case-insensitive by default -- matches the bash twin's `grep -i`.
        foreach ($m in (Select-String -Path $f.FullName -Pattern $p -ErrorAction SilentlyContinue)) {
            $leaks += ("{0}:{1}: {2}" -f $rel, $m.LineNumber, $p)
        }
    }
}
$leaks = $leaks | Sort-Object
if ($leaks.Count -gt 0) {
    Fail ("meta vocabulary in shipped content -- {0} line(s). These reach a consumer repo; fix in src/, not dist/." -f $leaks.Count)
    $leaks | Select-Object -First 20 | ForEach-Object { Write-Output "  [no-meta-leak] $_" }
    if ($leaks.Count -gt 20) { Write-Output ("  [no-meta-leak] ... and {0} more line(s)." -f ($leaks.Count - 20)) }
} else {
    OK "no meta-dev vocabulary in $Dist (no-meta-leak)."
}

# --- 7. no dead instructions ------------------------------------------------------------------
# Every script a shipped doc tells someone to RUN must actually exist. `no-meta-leak` (check 6)
# proves shipped files don't say the wrong *words*; nothing proved they don't give the wrong
# *commands*. They did: dist/monorepo's README told installing agents to run `pwsh install.ps1`,
# which exists nowhere in that dist — root-installer wording copied into a dist doc. An agent that
# followed it verbatim got "No such file or directory" (v0.26.3; meta/LEARNINGS.md).
#
# Resolution base is the DIST ROOT, not the doc's own directory — the framework documents every
# command as run from the repo root (`bash scripts/docs-sync-check.sh` in docs/ci-integration.md
# means from the consumer's root, not from docs/).
#
# CHANGELOG.md is skipped by design: release notes quote commands that WERE wrong in order to say
# they are now fixed. It is the one shipped doc whose job is to describe the past.
$deadRefs = @()
foreach ($f in (Get-ChildItem -Recurse -File -Path $DistAbs -Filter *.md)) {
    if ($f.Name -eq 'CHANGELOG.md') { continue }
    $rel = ($f.FullName.Substring($DistAbs.Length).TrimStart('\', '/')) -replace '\\', '/'
    $n = 0
    foreach ($line in (Get-Content $f.FullName)) {
        $n++
        foreach ($m in [regex]::Matches($line, '(?:pwsh|bash|powershell)(?:\s+-[A-Za-z]+(?:\s+[A-Za-z]+)?)*\s+([A-Za-z0-9_./-]+\.(?:ps1|sh))')) {
            $script = $m.Groups[1].Value
            if ($script.StartsWith('/')) { continue }   # absolute path / placeholder, not ours to resolve
            if (-not (Test-Path (Join-Path $DistAbs $script))) {
                $deadRefs += ("{0}:{1}: `{2}` does not exist in this dist" -f $rel, $n, $script)
            }
        }
    }
}
if ($deadRefs.Count -gt 0) {
    Fail ("dead instructions in shipped docs -- {0}. A consumer (or their agent) following these gets 'No such file or directory'. Fix in src/, not dist/." -f $deadRefs.Count)
    $deadRefs | Sort-Object -Unique | ForEach-Object { Write-Output "  [no-dead-instruction] $_" }
} else {
    OK "every documented command resolves in $Dist (no-dead-instruction)."
}

# --- 8. hook registrations point at hooks that exist ---------------------------------------------
# Nothing read the registration files at all. Check 2 proves they are valid JSON; check 7 checks
# only *.md. So a registration naming a script that is not in the dist -- a renamed hook, a
# half-composed stack -- shipped silently, and the consumer-side symptom is the worst kind: the
# hook simply never runs. No write guard, no post-write feedback, no audit trail, and no error
# anyone reads.
#
# What this deliberately does NOT do: fail on a BARE interpreter name. A bare name is the correct
# shipped value. Pinning absolute interpreter paths was tried and reverted in v0.38.1 --
# .claude/settings.json is committed team configuration, so recording the installing developer's
# machine-specific path breaks every teammate on another OS or profile. Whether a bare name
# RESOLVES on a given box is a runtime property no build-time check can see; that is what the
# doctor's `Hook liveness` row (v0.39.0) reports from the consumer's own machine. This check
# answers the build-time half only: does the thing we point at exist, and do both twins exist.
#
# Extraction is deliberately TEXTUAL and identical in both twins. The bash twin's JSON parser is
# python3-or-jq depending on the box, so parsing there would leave whichever branch this machine
# lacks untested while the PowerShell leg used ConvertFrom-Json -- three code paths for one check.
$SanctionedInterpreters = @('pwsh', 'powershell', 'bash')
$regFiles = @('.claude/settings.json', '.claude/settings.windows.json', '.github/hooks/hooks.json')
$regProblems = @()
$regCount = 0
foreach ($rf in $regFiles) {
    $rfAbs = Join-Path $DistAbs $rf
    if (-not (Test-Path $rfAbs)) { $regProblems += "$rf : registration file missing from this dist"; continue }
    $raw = Get-Content $rfAbs -Raw

    # settings*.json: "command": "<interpreter> [flags] -File <path>"
    foreach ($m in [regex]::Matches($raw, '"command"\s*:\s*"([^"]+)"')) {
        $cmd = $m.Groups[1].Value
        $regCount++
        $interp = ($cmd -split '\s+')[0]
        if ($SanctionedInterpreters -notcontains $interp) {
            $regProblems += "$rf : unrecognised interpreter '$interp' in: $cmd"
        }
        $fm = [regex]::Match($cmd, '-File\s+(\S+)')
        if (-not $fm.Success) { $regProblems += "$rf : no -File argument in: $cmd"; continue }
        $regProblems += (Test-HookRef -Dist $DistAbs -File $rf -Script $fm.Groups[1].Value)
    }

    # hooks.json: "bash": "<path> [args]" / "powershell": "<path> [args]" -- the value IS the script,
    # with the interpreter implied by the key, and Windows paths written with backslashes.
    foreach ($m in [regex]::Matches($raw, '"(bash|powershell)"\s*:\s*"([^"]+)"')) {
        $regCount++
        $script = (($m.Groups[2].Value) -split '\s+')[0]
        $regProblems += (Test-HookRef -Dist $DistAbs -File $rf -Script $script)
    }
}
# Vacuous-pass guard: an extraction that silently matches nothing reports a clean dist. The three
# files carry 6 + 6 + 8 registrations today; require enough to prove the regexes still bite.
if ($regCount -lt 15) {
    Fail "hook-registration check extracted only $regCount registration(s) from $Dist -- the extraction is broken, not the dist."
} elseif (@($regProblems).Count -gt 0) {
    Fail ("hook registrations reference {0} missing or invalid target(s) in {1}. A registration that cannot start is a hook that silently never runs." -f @($regProblems).Count, $Dist)
    $regProblems | Sort-Object -Unique | ForEach-Object { Write-Output "  [hook-registration] $_" }
} else {
    OK "all $regCount hook registrations resolve in $Dist (hook-registration)."
}

Write-Output ''
if ($failed -gt 0) { Write-Output "$failed dist validation check(s) FAILED for $Dist."; exit 1 }
Write-Output "All dist validation checks passed for $Dist."
exit 0
