# ai-tech-lead dist validator — PowerShell twin of validate-dist.sh. Validates an ALREADY-COMPOSED
# dist/<mode> tree — it does NOT rebuild it (see scripts/build.ps1 for that). Five checks, each with
# a clear OK/FAIL line:
#   1. no unresolved @stack:NAME markers survive anywhere in the dist (composer leftovers)
#   2. every *.json in the dist parses (ConvertFrom-Json)
#   3. `bash -n` passes on every *.sh in the dist (invokes bash — hard FATAL if unavailable)
#   4. PowerShell AST parse is clean on every *.ps1 in the dist
#   5. the dist's OWN template-checks.ps1 suite passes, run from inside the dist dir
#   6. no meta-dev vocabulary leaks into shipped content (scripts/meta-denylist.txt)
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

Write-Output ''
if ($failed -gt 0) { Write-Output "$failed dist validation check(s) FAILED for $Dist."; exit 1 }
Write-Output "All dist validation checks passed for $Dist."
exit 0
