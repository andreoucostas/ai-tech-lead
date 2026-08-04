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

# --content-only is an explicit ARGUMENT, deliberately not an environment variable: an ambient switch
# that narrows a gate's scope can be inherited by a shell that never asked for it, and `release.ps1`
# redirects validator output to a log, so the NOTE below would not be seen on an otherwise-green
# gate. A caller must now ask for a partial run in the command itself.
$ContentOnly = $false
$positional  = @()
foreach ($a in $args) {
    if ("$a" -eq '--content-only') { $ContentOnly = $true } else { $positional += $a }
}
$Mode = $positional[0]
if ($Mode -ne 'dotnet' -and $Mode -ne 'angular' -and $Mode -ne 'monorepo') {
    [Console]::Error.WriteLine('usage: validate-dist.ps1 {dotnet|angular|monorepo} [dist-root] [--content-only]')
    exit 2
}
$DistRoot = if ($positional.Count -ge 2 -and $positional[1]) { $positional[1] } else { 'dist' }
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

# --content-only skips checks 1-5 (the parse/marker/template-checks group) and runs only the content
# checks 6, 7 and 8. It exists for ValidateDist.Tests.ps1: those five re-parse every shipped file on
# every case, which made that suite 9 minutes for 15 cases x 2 legs — in a file that runs in
# release.ps1 AND on both CI legs. Neither release.ps1 nor CI passes it, and the suite's green
# anchors still run the FULL validator so the skipped group stays exercised on both legs.
# A restricted run says so loudly on stdout: a subset must never be mistakable for a complete one,
# which is the exact reporting failure this change exists to remove.
if ($ContentOnly) {
    Write-Output "NOTE: --content-only -- checks 1-5 were SKIPPED; this is NOT a full validation."
}

# Resolution for check 8 is CASE-EXACT in both twins. Windows resolves a `.PS1` registration to a
# `.ps1` file on disk and Linux does not, so a registration whose casing differs from the shipped
# file passed on the maintainer's box and would break on a consumer's Linux host — the twins
# disagreeing by PLATFORM rather than by code, which no amount of twin testing on one OS can see.
# Compare each segment against the real directory entry instead of asking the filesystem to match.
function Test-CaseExactPath {
    param([string]$Root, [string]$Relative)
    $current = $Root
    foreach ($segment in @($Relative -split '/' | Where-Object { $_ -ne '' })) {
        $entry = @(Get-ChildItem -LiteralPath $current -Force -ErrorAction SilentlyContinue |
                   Where-Object { $_.Name -ceq $segment })
        if ($entry.Count -eq 0) { return $false }
        $current = $entry[0].FullName
    }
    return $true
}

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
    if ($rel -match '^[A-Za-z]:' -or $rel.StartsWith('/')) {
        # Unlike a documentation example (check 7), committed machine wiring must never be absolute.
        $problems += "$File : `"$rel`" is an absolute path — a committed absolute registration is a dead hook on every machine but the one it was written on"
        return $problems
    }
    if (-not (Test-CaseExactPath -Root $Dist -Relative $rel)) {
        $problems += "$File : `"$rel`" does not exist in this dist"
        return $problems                        # no point asking about the twin of a missing file
    }
    if ($rel -match '\.ps1$')     { $twin = ($rel -replace '\.ps1$', '.sh') }
    elseif ($rel -match '\.sh$')  { $twin = ($rel -replace '\.sh$', '.ps1') }
    else { return $problems }
    if (-not (Test-CaseExactPath -Root $Dist -Relative $twin)) {
        $problems += "$File : `"$rel`" exists but its twin `"$twin`" does not"
    }
    return $problems
}

if (-not $ContentOnly) {
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
}   # end of the checks 1-5 group (VALIDATE_DIST_CONTENT_ONLY)

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
$scanErrors = @()
$distFiles = @(Get-ChildItem -Recurse -File -Path $DistAbs)
$filesScanned = @($distFiles).Count
foreach ($f in $distFiles) {
    $rel = ($f.FullName.Substring($DistAbs.Length).TrimStart('\', '/')) -replace '\\', '/'
    $skip = $false
    foreach ($a in $allowPaths) { if ($rel -like "*$a*") { $skip = $true; break } }
    if ($skip) { continue }
    foreach ($p in $denyPatterns) {
        # Select-String is case-insensitive by default -- matches the bash twin's `grep -i`.
        # A read error must be RECORDED, not swallowed: -ErrorAction SilentlyContinue alone let an
        # unreadable file count as scanned and clean, which is the bash twin's `2>/dev/null || true`
        # fail-open in PowerShell clothing (B-59, and sol's review of this change).
        $scanErr = $null
        foreach ($m in (Select-String -Path $f.FullName -Pattern $p -ErrorAction SilentlyContinue -ErrorVariable scanErr)) {
            $leaks += ("{0}:{1}: {2}" -f $rel, $m.LineNumber, $p)
        }
        if ($scanErr) { $scanErrors += ("{0}: {1}" -f $rel, $scanErr[0].Exception.Message) }
    }
}
$leaks = $leaks | Sort-Object
if (@($scanErrors).Count -gt 0) {
    Fail ("no-meta-leak could not scan {0} file(s) in {1} -- the scan is broken, not the dist." -f @($scanErrors).Count, $Dist)
    $scanErrors | Sort-Object -Unique | ForEach-Object { Write-Output "  [no-meta-leak] unreadable: $_" }
} elseif ($filesScanned -eq 0) {
    Fail "no-meta-leak scanned zero files in $Dist -- the input tree is empty, not clean."
} elseif ($leaks.Count -gt 0) {
    Fail ("meta vocabulary in shipped content -- {0} line(s). These reach a consumer repo; fix in src/, not dist/." -f $leaks.Count)
    $leaks | Select-Object -First 20 | ForEach-Object { Write-Output "  [no-meta-leak] $_" }
    if ($leaks.Count -gt 20) { Write-Output ("  [no-meta-leak] ... and {0} more line(s)." -f ($leaks.Count - 20)) }
} else {
    OK "no meta-dev vocabulary in $Dist (no-meta-leak; $(@($denyPatterns).Count) pattern(s) over $filesScanned file(s))."
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
$absoluteRefs = @()
$docReadErrors = @()
$docsScanned = 0
$refsExtracted = 0
foreach ($f in (Get-ChildItem -Recurse -File -Path $DistAbs -Filter *.md)) {
    if ($f.Name -eq 'CHANGELOG.md') { continue }
    $docsScanned++
    $rel = ($f.FullName.Substring($DistAbs.Length).TrimStart('\', '/')) -replace '\\', '/'
    $n = 0
    # Same rule as check 6: a doc that could not be READ is not a doc that contained nothing.
    $docErr = $null
    $lines = @(Get-Content $f.FullName -ErrorAction SilentlyContinue -ErrorVariable docErr)
    if ($docErr) { $docReadErrors += ("{0}: {1}" -f $rel, $docErr[0].Exception.Message); continue }
    foreach ($line in $lines) {
        $n++
        foreach ($m in [regex]::Matches($line, '(?:pwsh|bash|powershell)(?:\s+-[A-Za-z]+(?:\s+[A-Za-z]+)?)*\s+([A-Za-z0-9_./-]+\.(?:ps1|sh))')) {
            $script = $m.Groups[1].Value
            $refsExtracted++
            # An absolute doc path can be a placeholder example; registrations (check 8) cannot.
            if ($script.StartsWith('/')) {
                $absoluteRefs += ("{0}:{1}: absolute example `{2}` out of scope" -f $rel, $n, $script)
                continue
            }
            if (-not (Test-Path (Join-Path $DistAbs $script))) {
                $deadRefs += ("{0}:{1}: `{2}` does not exist in this dist" -f $rel, $n, $script)
            }
        }
    }
}
if (@($docReadErrors).Count -gt 0) {
    Fail ("no-dead-instruction could not read {0} doc(s) in {1} -- the scan is broken, not the dist." -f @($docReadErrors).Count, $Dist)
    $docReadErrors | Sort-Object -Unique | ForEach-Object { Write-Output "  [no-dead-instruction] unreadable: $_" }
} elseif ($docsScanned -eq 0) {
    Fail "no-dead-instruction scanned zero documentation files in $Dist -- the input tree is empty, not clean."
} elseif ($refsExtracted -eq 0) {
    Fail "no-dead-instruction extracted zero script references from $docsScanned doc(s) in $Dist -- the inline-command extractor is broken, not the dist."
} elseif ($deadRefs.Count -gt 0) {
    Fail ("dead instructions in shipped docs -- {0}. A consumer (or their agent) following these gets 'No such file or directory'. Fix in src/, not dist/." -f $deadRefs.Count)
    $deadRefs | Sort-Object -Unique | ForEach-Object { Write-Output "  [no-dead-instruction] $_" }
} else {
    $absoluteRefs | Sort-Object -Unique | ForEach-Object { Write-Output "  [no-dead-instruction] $_" }
    OK "all $($refsExtracted - $absoluteRefs.Count) resolvable documented script references exist in $Dist ($docsScanned doc(s) scanned; $($absoluteRefs.Count) absolute example(s) out of scope)."
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
# Registrations are parsed as JSON. The bash twin emits the same normalized records through its
# python3 and jq branches; ValidateDist.Tests.ps1 compares them when both tools are available.
$SanctionedInterpreters = @('pwsh', 'powershell', 'bash')
$regFiles = @('.claude/settings.json', '.claude/settings.windows.json', '.github/hooks/hooks.json')
$regProblems = @()
$regCount = 0
$settingsCounts = @{}
$hookEntries = 0
function Get-FileArgument {
    param([string]$Command)
    $m = [regex]::Match($Command, '(?i)(?:^|\s)-File\s+(?:"([^"]+)"|(\S+))')
    if (-not $m.Success) { return $null }
    if ($m.Groups[1].Success) { return $m.Groups[1].Value }
    return $m.Groups[2].Value
}
foreach ($rf in $regFiles) {
    $rfAbs = Join-Path $DistAbs $rf
    if (-not (Test-Path $rfAbs)) { $regProblems += "$rf : registration file missing from this dist"; continue }
    try { $json = Get-Content $rfAbs -Raw | ConvertFrom-Json } catch { $regProblems += "$rf : registration file is unparseable"; continue }
    if ($null -eq $json.hooks -or -not ($json.hooks -is [pscustomobject])) { $regProblems += "$rf : registration file has no hooks object"; continue }
    $handlers = 0
    # Every level is type-checked, and the three parsers (here, python3, jq) must agree on the
    # message for each malformed shape. They did not: an event whose value was an object rather than
    # an array produced "no bash/powershell leg" here and in python3 but "not an object" under jq.
    # A twin that disagrees about WHY only looks like a twin.
    if ($rf -like '.claude/*') {
        foreach ($event in @($json.hooks.PSObject.Properties)) {
            if ($event.Value -isnot [System.Array]) { $regProblems += "$rf : hook event '$($event.Name)' must be an array"; continue }
            foreach ($group in @($event.Value)) {
                if ($group -isnot [pscustomobject] -or $group.hooks -isnot [System.Array]) { $regProblems += "$rf : hook group in event '$($event.Name)' has no hooks array"; continue }
                foreach ($entry in @($group.hooks)) {
                    if ($entry.type -ne 'command' -or [string]::IsNullOrWhiteSpace([string]$entry.command)) { $regProblems += "$rf : hook entry must have type 'command' and a non-empty command"; continue }
                    $handlers++; $regCount++
                    $cmd = [string]$entry.command; $interp = (($cmd -split '\s+')[0]).ToLowerInvariant()
                    if ($SanctionedInterpreters -notcontains $interp) { $regProblems += "$rf : unrecognised interpreter '$interp' in: $cmd" }
                    $script = Get-FileArgument $cmd
                    if (-not $script) { $regProblems += "$rf : no -File argument in: $cmd" } else { $regProblems += (Test-HookRef -Dist $DistAbs -File $rf -Script $script) }
                }
            }
        }
        $settingsCounts[$rf] = $handlers
    } else {
        foreach ($event in @($json.hooks.PSObject.Properties)) {
            if ($event.Value -isnot [System.Array]) { $regProblems += "$rf : hook event '$($event.Name)' must be an array"; continue }
            foreach ($entry in @($event.Value)) {
                if ($entry -isnot [pscustomobject]) { $regProblems += "$rf : hook entry in event '$($event.Name)' is not an object"; continue }
                $hasBash = -not [string]::IsNullOrWhiteSpace([string]$entry.bash); $hasPs = -not [string]::IsNullOrWhiteSpace([string]$entry.powershell)
                if (-not $hasBash -and -not $hasPs) { $regProblems += "$rf : hook entry must have at least one bash/powershell leg; a deliberate single-leg entry requires updating this check on purpose"; continue }
                if (-not $hasBash -or -not $hasPs) { $regProblems += "$rf : hook entry has only one bash/powershell leg; a deliberate single-leg entry requires updating this check on purpose" }
                $hookEntries++
                foreach ($kind in @('bash', 'powershell')) { if (-not [string]::IsNullOrWhiteSpace([string]$entry.$kind)) { $handlers++; $regCount++; $script = (([string]$entry.$kind -split '\s+')[0]); $regProblems += (Test-HookRef -Dist $DistAbs -File $rf -Script $script) } }
            }
        }
    }
    if ($handlers -eq 0) { $regProblems += "$rf : registration file yields zero handlers" }
}
if (@($regProblems).Count -gt 0) {
    Fail ("hook registrations reference {0} missing or invalid target(s) in {1}. A registration that cannot start is a hook that silently never runs." -f @($regProblems).Count, $Dist)
    $regProblems | Sort-Object -Unique | ForEach-Object { Write-Output "  [hook-registration] $_" }
} else {
    # The parser is named here too, so both twins' OK lines state how the registrations were read.
    OK "all $regCount hook registrations resolve (settings.json $($settingsCounts['.claude/settings.json']), settings.windows.json $($settingsCounts['.claude/settings.windows.json']), hooks.json $hookEntries entries × 2 legs; parsed by ConvertFrom-Json)"
}

Write-Output ''
if ($failed -gt 0) { Write-Output "$failed dist validation check(s) FAILED for $Dist."; exit 1 }
Write-Output "All dist validation checks passed for $Dist."
exit 0
