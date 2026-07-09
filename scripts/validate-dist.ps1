# ai-tech-lead dist validator — PowerShell twin of validate-dist.sh. Validates an ALREADY-COMPOSED
# dist/<mode> tree — it does NOT rebuild it (see scripts/build.ps1 for that). Five checks, each with
# a clear OK/FAIL line:
#   1. no unresolved @stack:NAME markers survive anywhere in the dist (composer leftovers)
#   2. every *.json in the dist parses (ConvertFrom-Json)
#   3. `bash -n` passes on every *.sh in the dist (invokes bash — hard FATAL if unavailable)
#   4. PowerShell AST parse is clean on every *.ps1 in the dist
#   5. the dist's OWN template-checks.ps1 suite passes, run from inside the dist dir
# Exit 0 = all checks passed. Exit 1 = at least one check failed. Exit 2 = usage error, missing
# dist, or a required tool (bash, for check 3) is unavailable — reported as FATAL, never skipped.
#   Usage: validate-dist.ps1 {dotnet|angular} [dist-root]
#   dist-root defaults to "dist" resolved under the repo root (scripts/..). Pass an explicit path
#   to validate a scratch copy instead (e.g. to plant failure fixtures without touching dist/).
# 5.1-safe: no pwsh-only syntax.
# EAP stays 'Continue': under 5.1 with EAP=Stop, a native command (bash -n, template-checks)
# writing to a REDIRECTED stderr raises a terminating NativeCommandError and kills the script
# mid-check — exactly when a planted syntax error should have produced a FAIL line instead.
# Failure detection here is explicit ($LASTEXITCODE / try-catch), not exception-driven.
$ErrorActionPreference = 'Continue'

Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

$Mode = $args[0]
if ($Mode -ne 'dotnet' -and $Mode -ne 'angular') {
    [Console]::Error.WriteLine('usage: validate-dist.ps1 {dotnet|angular} [dist-root]')
    exit 2
}
$DistRoot = if ($args.Count -ge 2 -and $args[1]) { $args[1] } else { 'dist' }
$Dist = Join-Path $DistRoot $Mode
if (-not (Test-Path $Dist -PathType Container)) {
    [Console]::Error.WriteLine("no $Dist -- run scripts/build.ps1 $Mode first")
    exit 2
}

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

Write-Output ''
if ($failed -gt 0) { Write-Output "$failed dist validation check(s) FAILED for $Dist."; exit 1 }
Write-Output "All dist validation checks passed for $Dist."
exit 0
