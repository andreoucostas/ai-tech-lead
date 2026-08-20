# ai-tech-lead dist validator — PowerShell twin of validate-dist.sh. Validates an ALREADY-COMPOSED
# dist/<mode> tree — it does NOT rebuild it (see scripts/build.ps1 for that). Thirteen checks, each
# with a clear OK/FAIL line:
#   1. no unresolved @stack:NAME markers survive anywhere in the dist (composer leftovers)
#   2. every *.json in the dist parses (ConvertFrom-Json)
#   3. `bash -n` passes on every *.sh in the dist (invokes bash — hard FATAL if unavailable)
#   4. PowerShell AST parse is clean on every *.ps1 in the dist
#   5. the dist's OWN template-checks.ps1 suite passes, run from inside the dist dir
#   6. no meta-dev vocabulary leaks into shipped content (scripts/meta-denylist.txt)
#   7. every script a shipped *.md tells someone to RUN and every rendered relative inline link resolves
#   8. every hook registration in settings*.json / hooks.json names a script that exists, with its
#      opposite-language twin (hook-registration)
#   9. every core @stack marker expands from a non-empty stack snippet into the composed file
#  10. section-path citations name a heading that exists in the cited shipped file
#  11. CLAUDE.md imports the shipped framework-rules carrier
#  12. top-level ordered-list runs are contiguous and prose step references resolve in-file
#  13. Copilot userPromptSubmitted has at most one entry (only its last entry is delivered)
# Exit 0 = all checks passed. Exit 1 = at least one check failed. Exit 2 = usage error, missing
# dist, or a required tool (bash, for check 3) is unavailable — reported as FATAL, never skipped.
#   Usage: validate-dist.ps1 {dotnet|angular|monorepo} [dist-root] [-Check name[,name...]]
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
$CheckArg = $null
$positional  = @()
for ($i = 0; $i -lt $args.Count; $i++) {
    $a = "$($args[$i])"
    if ($a -eq '--content-only') { $ContentOnly = $true }
    elseif ($a -eq '-Check') {
        $i++
        if ($i -ge $args.Count) { [Console]::Error.WriteLine('usage error: -Check requires one or more comma-separated check names.'); exit 2 }
        $CheckArg = "$($args[$i])"
    } else { $positional += $a }
}
$ValidChecks = @('markers','json','bash-syntax','ps-syntax','template-checks','no-meta-leak','no-dead-instruction','hook-registration','marker-expansion','section-path','carrier-import','step-references','prompt-hook-cardinality')
$SelectedChecks = @()
if ($null -ne $CheckArg) {
    $SelectedChecks = @($CheckArg -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    $unknownChecks = @($SelectedChecks | Where-Object { $ValidChecks -cnotcontains $_ } | Sort-Object -Unique)
    if ($SelectedChecks.Count -eq 0 -or $unknownChecks.Count -gt 0) {
        $bad = if ($unknownChecks.Count -gt 0) { $unknownChecks -join ', ' } else { '(empty)' }
        [Console]::Error.WriteLine("usage error: unknown check name(s): $bad. Valid names: $($ValidChecks -join ', ').")
        exit 2
    }
}
if ($ContentOnly -and $null -ne $CheckArg) {
    [Console]::Error.WriteLine('usage error: --content-only and -Check cannot be combined; choose one scope selector.')
    exit 2
}
function Test-CheckSelected($name) {
    if ($null -ne $CheckArg) { return $SelectedChecks -ccontains $name }
    if ($ContentOnly) { return @('no-meta-leak','no-dead-instruction','hook-registration','step-references','prompt-hook-cardinality') -contains $name }
    return $true
}
$Mode = $positional[0]
if ($Mode -ne 'dotnet' -and $Mode -ne 'angular' -and $Mode -ne 'monorepo') {
    [Console]::Error.WriteLine('usage: validate-dist.ps1 {dotnet|angular|monorepo} [dist-root] [--content-only] [-Check name[,name...]]')
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
# Per-check elapsed time, mirroring the bash twin [#3]. Every check ends by calling OK or Fail
# exactly once, so timing the interval between those calls attributes cost without annotating each
# check by hand.
#
# Why this exists: this validator's runtime was governed by nothing. A check once regressed to the
# point where its bash twin could not finish AT ALL, and that was found only because a maintainer
# asked why a suite had been running for hours -- every correctness gate stayed green throughout.
# Correctness was gated; cost was not, so a 20x regression was invisible in the run that caused it.
# Timings go to stderr so stdout stays exactly the OK:/FAIL: stream every caller already parses.
$CheckCeilingSeconds = if ($env:VALIDATE_DIST_CHECK_CEILING_S) { [double]$env:VALIDATE_DIST_CHECK_CEILING_S } else { 25 }
$script:timings = @()
$script:tLast   = [Diagnostics.Stopwatch]::StartNew()
function Record-Timing($label) {
    $script:timings += [pscustomobject]@{ Seconds = $script:tLast.Elapsed.TotalSeconds; Label = $label }
    $script:tLast.Restart()
}
function Report-Timings {
    foreach ($t in $script:timings) {
        $label = if ($t.Label.Length -gt 60) { $t.Label.Substring(0, 60) } else { $t.Label }
        [Console]::Error.WriteLine(("TIMING {0,6:n1}s  {1}" -f $t.Seconds, $label))
        if ($t.Seconds -gt $CheckCeilingSeconds) {
            [Console]::Error.WriteLine(("WARNING: check `"{0}`" took {1:n1}s, over the {2}s ceiling. Gate cost is a defect too -- profile it before it becomes a timeout." -f $label, $t.Seconds, $CheckCeilingSeconds))
        }
    }
}
function Fail($m) { Record-Timing $m; Write-Output "FAIL: $m"; $script:failed++ }
function OK($m)   { Record-Timing $m; Write-Output "OK:   $m" }

# --content-only skips checks 1-5 (the parse/marker/template-checks group) and runs only the content
# checks 6, 7, 8, 12 and 13. It exists for ValidateDist.Tests.ps1: those five re-parse every shipped file on
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

# -Force on every enumeration below is LOAD-BEARING, not defensive. PowerShell treats a leading dot
# as "hidden" on Linux/macOS, so without it `Get-ChildItem -Recurse` silently skips everything under
# `.claude/` and `.github/` there — which is most of what a dist ships. On Windows the same call
# returns those files, so this twin under-scanned on Linux ONLY, and no local run could show it:
# check 6 would never have looked at a single hook or skill for meta-leaks, and check 7 would have
# scanned a fraction of the docs while reporting a clean pass. Found by the CI linux leg (2026-08-04)
# via a test whose mutation had the identical blind spot.
if (-not $ContentOnly) {
if (Test-CheckSelected 'markers') {
# --- 1. no unresolved @stack markers -------------------------------------------------------------
$markerRe = '@stack:[A-Za-z0-9_-]+'
$markerFiles = @()
$markerReadFails = @()
$markerInputs = @()
$markerEnumError = $null
try { $markerInputs = @(Get-ChildItem -Recurse -File -Force -Path $Dist -ErrorAction Stop) }
catch { $markerEnumError = $_.Exception.Message }
foreach ($f in $markerInputs) {
    try {
        if ((Select-String -LiteralPath $f.FullName -Pattern $markerRe -SimpleMatch:$false -Quiet -ErrorAction Stop)) {
            $markerFiles += $f.FullName
        }
    } catch { $markerReadFails += $f.FullName }
}
if ($null -ne $markerEnumError) {
    Fail "marker scan could not enumerate $Dist : $markerEnumError"
} elseif ($markerInputs.Count -eq 0) {
    Fail "marker scan found zero files in $Dist."
} elseif ($markerReadFails.Count -gt 0) {
    Fail ("marker scan could not read:" + ($markerReadFails -join ' '))
} elseif ($markerFiles.Count -gt 0) {
    Fail ("unresolved @stack markers in: " + ($markerFiles -join ' '))
} else {
    OK "no unresolved @stack markers in $Dist ($($markerInputs.Count) files scanned)."
}
}

if (Test-CheckSelected 'marker-expansion') {
# --- 1a. every core marker expands from a non-empty snippet --------------------------------------
# The composer consumes a marker even when its snippet is absent, producing a marker-free but
# silently empty section. Derive the inventory from core rather than maintaining a second list.
$coreRoot = (Resolve-Path (Join-Path $RepoRoot 'src/core')).Path
$expansionProblems = @()
$markerCount = 0
foreach ($coreFile in (Get-ChildItem -Recurse -File -Force -Path $coreRoot)) {
    $coreRel = $coreFile.FullName.Substring($coreRoot.Length).TrimStart('\', '/').Replace('\', '/')
    $distFile = Join-Path $DistAbs ($coreRel -replace '/', [IO.Path]::DirectorySeparatorChar)
    $distText = if (Test-Path -LiteralPath $distFile) { ([IO.File]::ReadAllText($distFile) -replace "`r`n", "`n") } else { $null }
    # BOTH marker forms, anchored exactly as the composer anchors them (build.ps1 $HtmlMarker /
    # $HashMarker): markdown uses `<!-- @stack:NAME -->`, scripts use `# @stack:NAME`, and each must
    # be the whole line. Matching only the HTML form left this gate blind to the 15 hash markers in
    # route-prompt/audit-trail/.gitignore/CI -- i.e. blind to the shipped hooks, which is the very
    # failure class it exists to catch. Anchoring also stops a prose mention of the syntax counting
    # as a marker.
    foreach ($match in [regex]::Matches([IO.File]::ReadAllText($coreFile.FullName), '(?m)^[ \t]*(?:<!-- @stack:([A-Za-z0-9_-]+) -->|# @stack:([A-Za-z0-9_-]+))[ \t]*\r?$')) {
        $markerCount++
        $name = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
        # Resolve with the composer's exact semantics: monorepo prefers its authored snippet, then
        # falls back to dotnet + angular concatenation (either side may be absent).
        $snippetPaths = @()
        if ($Mode -eq 'monorepo') {
            $mono = Join-Path $RepoRoot (("src/stacks/monorepo/snippets/{0}/{1}" -f $coreRel, $name) -replace '/', [IO.Path]::DirectorySeparatorChar)
            if (Test-Path -LiteralPath $mono -PathType Leaf) { $snippetPaths = @($mono) }
            else {
                foreach ($fallbackStack in @('dotnet','angular')) {
                    $candidate = Join-Path $RepoRoot (("src/stacks/{0}/snippets/{1}/{2}" -f $fallbackStack, $coreRel, $name) -replace '/', [IO.Path]::DirectorySeparatorChar)
                    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $snippetPaths += $candidate }
                }
            }
        } else {
            $candidate = Join-Path $RepoRoot (("src/stacks/{0}/snippets/{1}/{2}" -f $Mode, $coreRel, $name) -replace '/', [IO.Path]::DirectorySeparatorChar)
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $snippetPaths = @($candidate) }
            if ($snippetPaths.Count -eq 0) {
                $otherCount = 0
                foreach ($otherStack in @('dotnet','angular','monorepo') | Where-Object { $_ -ne $Mode }) {
                    $other = Join-Path $RepoRoot (("src/stacks/{0}/snippets/{1}/{2}" -f $otherStack, $coreRel, $name) -replace '/', [IO.Path]::DirectorySeparatorChar)
                    if (Test-Path -LiteralPath $other -PathType Leaf) { $otherCount++ }
                }
                # A one-stack snippet is intentionally stack-only. If both sibling stacks carry the
                # marker, this stack must too; that shape identifies an accidentally deleted file.
                if ($otherCount -lt 2) { continue }
            }
        }
        $snippetText = (($snippetPaths | ForEach-Object { ([IO.File]::ReadAllText($_) -replace "`r`n", "`n").TrimEnd("`n", "`r") }) -join "`n")
        if ([string]::IsNullOrWhiteSpace($snippetText)) {
            $expansionProblems += "$Mode : $coreRel @stack:$name resolves to an empty expansion"
        } elseif ($null -eq $distText) {
            $expansionProblems += "$Mode : $coreRel @stack:$name cannot expand because the composed file is missing"
        } elseif (-not $distText.Contains($snippetText)) {
            $expansionProblems += "$Mode : $coreRel @stack:$name snippet content is absent from the composed file"
        }
    }
}
if ($markerCount -eq 0) {
    Fail "marker-expansion inventory found zero core @stack markers -- the inventory is broken, not the dist."
} elseif ($expansionProblems.Count -gt 0) {
    Fail ("marker expansion failed for {0} core marker(s) in {1}." -f $expansionProblems.Count, $Mode)
    $expansionProblems | Sort-Object -Unique | ForEach-Object { Write-Output "  [marker-expansion] $_" }
} else {
    OK "all $markerCount core @stack markers expand from non-empty $Mode snippets into composed files."
}
}

if (Test-CheckSelected 'section-path') {
# --- 1b. section-path references resolve ---------------------------------------------------------
# This finite registry deliberately avoids a permissive "everything after >" capture. Changelogs
# are historical records and are excluded by path. Scan every textual shipped file, not only *.md.
$citationFiles = @('CLAUDE.md','AGENTS.md','.github/instructions/framework-rules.instructions.md')
$citationHeadings = @('Architecture Decisions','Verification Rules','Repository Structure','Agentic Workflow','Codebase Context',"What We've Learned",'Boy Scout Rule','Common Tasks','Conventions','Leanness','SOLID')
$regexOptions = [Text.RegularExpressions.RegexOptions]::IgnoreCase
$citationFileFilter = New-Object Text.RegularExpressions.Regex (($citationFiles | ForEach-Object { [regex]::Escape($_) }) -join '|'), $regexOptions
$citationPatterns = @()
$targetFileLookup = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$targetHeadingLookup = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($citedFile in $citationFiles) {
    $fileToken = [regex]::Escape($citedFile)
    $target = Join-Path $DistAbs ($citedFile -replace '/', [IO.Path]::DirectorySeparatorChar)
    $targetLines = if (Test-Path -LiteralPath $target -PathType Leaf) { [IO.File]::ReadAllLines($target) } else { @() }
    if ($targetLines.Count -gt 0 -or (Test-Path -LiteralPath $target -PathType Leaf)) { [void]$targetFileLookup.Add($citedFile) }
    foreach ($heading in $citationHeadings) {
        # Only the two registered citation forms count. A terminating backtick or a
        # punctuation/end boundary prevents prose such as "CLAUDE.md > Conventions wins"
        # from being mistaken for a citation.
        $headingToken = [regex]::Escape($heading)
        $plainBacktick = New-Object Text.RegularExpressions.Regex ("``$fileToken\s*(?:>|›)\s*$headingToken``"), $regexOptions
        $markdownLink = New-Object Text.RegularExpressions.Regex ("\[$fileToken\]\([^)]*\)\s*(?:>|›)\s*$headingToken(?=$|[``;,\.\):\]])"), $regexOptions
        $headingRegex = New-Object Text.RegularExpressions.Regex (("^#+\s+{0}\s*$" -f $headingToken)), $regexOptions
        $citationPatterns += [pscustomobject]@{ File = $citedFile; Heading = $heading; Plain = $plainBacktick; Markdown = $markdownLink }
        if ($targetLines | Where-Object { $headingRegex.IsMatch($_) } | Select-Object -First 1) {
            [void]$targetHeadingLookup.Add("$citedFile`0$heading")
        }
    }
}
$citationProblems = @()
$textFilesScanned = 0
foreach ($f in (Get-ChildItem -Recurse -File -Force -Path $DistAbs)) {
    $rel = $f.FullName.Substring($DistAbs.Length).TrimStart('\', '/').Replace('\', '/')
    if ($f.Name -eq 'CHANGELOG.md') { continue }
    $bytes = [IO.File]::ReadAllBytes($f.FullName)
    if ($bytes -contains 0) { continue }
    $textFilesScanned++
    $lineNo = 0
    foreach ($line in [IO.File]::ReadAllLines($f.FullName)) {
        $lineNo++
        if (-not $citationFileFilter.IsMatch($line)) { continue }
        foreach ($citedFile in $citationFiles) {
            foreach ($citation in $citationPatterns) {
                if ($citation.File -ne $citedFile) { continue }
                $seen = $citation.Plain.IsMatch($line) -or $citation.Markdown.IsMatch($line)
                if (-not $seen) { continue }
                if (-not $targetFileLookup.Contains($citation.File)) {
                    $citationProblems += "$rel`:$lineNo cites $($citation.File) > $($citation.Heading), but $($citation.File) is missing"
                } elseif (-not $targetHeadingLookup.Contains("$($citation.File)`0$($citation.Heading)")) {
                    $citationProblems += "$rel`:$lineNo cites $($citation.File) > $($citation.Heading), but that heading does not exist"
                }
                break
            }
        }
    }
}
if ($textFilesScanned -eq 0) {
    Fail "section-path reference check scanned zero textual files in $Dist -- the input is empty or unreadable."
} elseif ($citationProblems.Count -gt 0) {
    Fail ("unresolved section-path references in shipped content -- {0}." -f $citationProblems.Count)
    $citationProblems | Sort-Object -Unique | ForEach-Object { Write-Output "  [section-path-reference] $_" }
} else {
    OK "all registered section-path references resolve ($textFilesScanned textual file(s) scanned; CHANGELOG.md excluded)."
}
}

if (Test-CheckSelected 'carrier-import') {
# --- 1c. CLAUDE.md imports the delivered framework-rules carrier --------------------------------
$importLine = '@.github/instructions/framework-rules.instructions.md'
$claudePath = Join-Path $DistAbs 'CLAUDE.md'
$carrierPath = Join-Path $DistAbs '.github/instructions/framework-rules.instructions.md'
if (-not (Test-Path -LiteralPath $claudePath -PathType Leaf)) {
    Fail "framework-rules import cannot be checked because CLAUDE.md is missing from $Dist."
} elseif (-not (Select-String -LiteralPath $claudePath -SimpleMatch -Pattern $importLine -Quiet)) {
    Fail "CLAUDE.md is missing required import $importLine."
} elseif (-not (Test-Path -LiteralPath $carrierPath -PathType Leaf)) {
    Fail "CLAUDE.md imports $importLine but the carrier file is missing from $Dist."
} else {
    OK "CLAUDE.md imports the delivered framework-rules carrier."
}
}

if (Test-CheckSelected 'json') {
# --- 2. every *.json parses -------------------------------------------------------------------------
$jsonFails = @()
$jsonReadFails = @()
$jsonInputs = @()
$jsonEnumError = $null
try { $jsonInputs = @(Get-ChildItem -Recurse -File -Force -Filter *.json -Path $Dist -ErrorAction Stop) }
catch { $jsonEnumError = $_.Exception.Message }
foreach ($f in $jsonInputs) {
    try {
        $jsonText = [IO.File]::ReadAllText($f.FullName)
    } catch { $jsonReadFails += $f.FullName; continue }
    try {
        $jsonText | ConvertFrom-Json | Out-Null
    } catch { $jsonFails += $f.FullName
    }
}
if ($null -ne $jsonEnumError) { Fail "JSON scan could not enumerate $Dist : $jsonEnumError" }
elseif ($jsonInputs.Count -eq 0) { Fail "JSON scan found zero files in $Dist." }
elseif ($jsonReadFails.Count -gt 0) { Fail ("JSON scan could not read:" + ($jsonReadFails -join ' ')) }
elseif ($jsonFails.Count -gt 0) { Fail ("invalid JSON (ConvertFrom-Json):" + ($jsonFails -join ' ')) }
else { OK "all $($jsonInputs.Count) *.json files parse (ConvertFrom-Json)." }
}

if (Test-CheckSelected 'bash-syntax') {
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
$shReadFails = @()
$shInputs = @()
$shEnumError = $null
try { $shInputs = @(Get-ChildItem -Recurse -File -Force -Filter *.sh -Path $Dist -ErrorAction Stop) }
catch { $shEnumError = $_.Exception.Message }
foreach ($f in $shInputs) {
    try { $null = [IO.File]::OpenRead($f.FullName).Dispose() }
    catch { $shReadFails += $f.FullName; continue }
    & $bashExe -n ($f.FullName -replace '\\', '/') 2>$null 1>$null
    if ($LASTEXITCODE -ne 0) { $shFails += $f.FullName }
}
if ($null -ne $shEnumError) { Fail "shell scan could not enumerate $Dist : $shEnumError" }
elseif ($shInputs.Count -eq 0) { Fail "shell scan found zero files in $Dist." }
elseif ($shReadFails.Count -gt 0) { Fail ("shell scan could not read:" + ($shReadFails -join ' ')) }
elseif ($shFails.Count -gt 0) { Fail ("bash syntax errors in:" + ($shFails -join ' ')) }
else { OK "all $($shInputs.Count) *.sh files parse cleanly (bash -n)." }
}

if (Test-CheckSelected 'ps-syntax') {
# --- 4. PowerShell AST parse on every *.ps1 -----------------------------------------------------------
# The bash twin must resolve a host from PATH or known Windows locations. This twin already runs
# inside a resolved host, so retain its in-process parser rather than silently upgrading a
# deliberate 5.1 run. The same host/PATH diagnostic is retained for the impossible-to-continue
# case where the current process cannot identify its own executable.
$currentPowerShellHost = (Get-Process -Id $PID).Path
if (-not $currentPowerShellHost) {
    [Console]::Error.WriteLine('FATAL: no PowerShell host found on PATH or at any known location; this is a host/PATH problem, not a dist problem, so *.ps1 syntax could not be checked.')
    exit 2
}
$ps1Fails = @()
$ps1ReadFails = @()
$ps1Inputs = @()
$ps1EnumError = $null
try { $ps1Inputs = @(Get-ChildItem -Recurse -File -Force -Filter *.ps1 -Path $Dist -ErrorAction Stop) }
catch { $ps1EnumError = $_.Exception.Message }
foreach ($f in $ps1Inputs) {
    $e = $null
    try {
        # ParseFile reports some read failures as ParserError objects instead of throwing. Probe
        # readability explicitly so an inaccessible file cannot be mislabeled as invalid syntax.
        $null = [IO.File]::OpenRead($f.FullName).Dispose()
        [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$e) | Out-Null
    }
    catch { $ps1ReadFails += $f.FullName; continue }
    if ($e) { $ps1Fails += "$($f.FullName): $($e[0].Message)" }
}
if ($null -ne $ps1EnumError) { Fail "PowerShell scan could not enumerate $Dist : $ps1EnumError" }
elseif ($ps1Inputs.Count -eq 0) { Fail "PowerShell scan found zero files in $Dist." }
elseif ($ps1ReadFails.Count -gt 0) { Fail ("PowerShell scan could not read:" + ($ps1ReadFails -join ' ')) }
elseif ($ps1Fails.Count -gt 0) { Fail ("PS syntax errors: " + ($ps1Fails -join '; ')) }
else { OK "all $($ps1Inputs.Count) *.ps1 files parse cleanly." }
}

if (Test-CheckSelected 'template-checks') {
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
}
}   # end of the checks 1-5 group (VALIDATE_DIST_CONTENT_ONLY)

if (Test-CheckSelected 'no-meta-leak') {
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
$distFiles = @(Get-ChildItem -Recurse -File -Force -Path $DistAbs)
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
}

if (Test-CheckSelected 'no-dead-instruction') {
# --- 7. no dead instructions or local document links ------------------------------------------
# Every script a shipped doc tells someone to RUN and every rendered relative inline link must
# actually resolve. `no-meta-leak` (check 6)
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
$linksExtracted = 0
$deadLinks = @()
foreach ($f in (Get-ChildItem -Recurse -File -Force -Path $DistAbs -Filter *.md)) {
    if ($f.Name -eq 'CHANGELOG.md') { continue }
    $docsScanned++
    $rel = ($f.FullName.Substring($DistAbs.Length).TrimStart('\', '/')) -replace '\\', '/'
    $n = 0
    # Same rule as check 6: a doc that could not be READ is not a doc that contained nothing.
    $docErr = $null
    $lines = @(Get-Content $f.FullName -ErrorAction SilentlyContinue -ErrorVariable docErr)
    if ($docErr) { $docReadErrors += ("{0}: {1}" -f $rel, $docErr[0].Exception.Message); continue }
    $fenceChar = $null
    foreach ($line in $lines) {
        $n++
        # Command examples are instructions even inside code fences; keep the established check-7
        # grammar independent from the rendered-link grammar below.
        foreach ($m in [regex]::Matches($line, '(?:(?:pwsh|bash|powershell)(?:\s+-[A-Za-z]+(?:\s+[A-Za-z]+)?)*\s+([A-Za-z0-9_./-]+\.(?:ps1|sh))|python\s+([A-Za-z0-9_./-]+\.py))')) {
            $script = @($m.Groups[1].Value, $m.Groups[2].Value) | Where-Object { $_ } | Select-Object -First 1
            $refsExtracted++
            if ($script.StartsWith('/')) {
                $absoluteRefs += ("{0}:{1}: absolute example `{2}` out of scope" -f $rel, $n, $script)
                continue
            }
            if (-not (Test-Path (Join-Path $DistAbs $script))) {
                $deadRefs += ("{0}:{1}: `{2}` does not exist in this dist" -f $rel, $n, $script)
            }
        }
        if ($line -match '^\s*(`{3,}|~{3,})') {
            $char = $Matches[1].Substring(0,1)
            if ($null -eq $fenceChar) { $fenceChar = $char }
            elseif ($fenceChar -eq $char) { $fenceChar = $null }
            continue
        }
        if ($null -ne $fenceChar) { continue }
        # Bounded Markdown grammar: rendered, single-line inline links only. Fenced blocks and
        # inline-code spans are examples rather than navigable links. Reference definitions,
        # multiline destinations, remote URLs and anchor validation are deliberately out of scope.
        $rendered = [regex]::Replace($line, '`+[^`]*`+', '')
        foreach ($m in [regex]::Matches($rendered, '(?<!!)\[[^\]]+\]\((?<target><[^>]+>|[^\s\)]+)(?:\s+[^\)]*)?\)')) {
            $target = $m.Groups['target'].Value.Trim('<','>')
            if ($target -match '^(?:[A-Za-z][A-Za-z0-9+.-]*:|//|#|/)') { continue }
            $pathPart = ($target -split '[?#]', 2)[0]
            if ([string]::IsNullOrWhiteSpace($pathPart)) { continue }
            $linksExtracted++
            try {
                if ($pathPart -match '%(?![0-9A-Fa-f]{2})' -or $pathPart -match '%(?:[01][0-9A-Fa-f]|7F)') {
                    throw 'malformed or control percent escape'
                }
                $decoded = [Uri]::UnescapeDataString($pathPart)
                $resolved = [IO.Path]::GetFullPath((Join-Path $f.DirectoryName $decoded))
                $rootPrefix = $DistAbs.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
                if ($resolved.Equals($DistAbs, [StringComparison]::OrdinalIgnoreCase)) {
                    continue
                } elseif (-not $resolved.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                    $deadLinks += ("{0}:{1}: `{2}` escapes this dist" -f $rel, $n, $target)
                    continue
                }
                $targetRel = $resolved.Substring($rootPrefix.Length).Replace('\','/')
                if (-not (Test-CaseExactPath -Root $DistAbs -Relative $targetRel)) {
                    $deadLinks += ("{0}:{1}: `{2}` does not resolve relative to this document" -f $rel, $n, $target)
                }
            } catch {
                $deadLinks += ("{0}:{1}: `{2}` is not a valid relative link target" -f $rel, $n, $target)
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
} elseif ($linksExtracted -eq 0) {
    Fail "no-dead-instruction extracted zero relative inline Markdown links from $docsScanned doc(s) in $Dist -- the link extractor is broken, not the dist."
} elseif ($deadRefs.Count -gt 0) {
    Fail ("dead instructions in shipped docs -- {0}. A consumer (or their agent) following these gets 'No such file or directory'. Fix in src/, not dist/." -f $deadRefs.Count)
    $deadRefs | Sort-Object -Unique | ForEach-Object { Write-Output "  [no-dead-instruction] $_" }
} elseif ($deadLinks.Count -gt 0) {
    Fail ("dangling markdown links in shipped docs -- {0}. Targets resolve relative to the document that contains them." -f $deadLinks.Count)
    $deadLinks | Sort-Object -Unique | ForEach-Object { Write-Output "  [no-dead-instruction] $_" }
} else {
    $absoluteRefs | Sort-Object -Unique | ForEach-Object { Write-Output "  [no-dead-instruction] $_" }
    OK "all $linksExtracted relative inline Markdown links and $($refsExtracted - $absoluteRefs.Count) resolvable documented script references resolve in $Dist ($docsScanned doc(s) scanned; $($absoluteRefs.Count) absolute example(s) out of scope)."
}
}

if (Test-CheckSelected 'hook-registration') {
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
}

if (Test-CheckSelected 'step-references') {
# --- 12. ordered-list runs and prose step references ---------------------------------------------
# Top-level labels only: nested ordered lists are out of scope, and a genuine second procedure
# renumbered from 1 is accepted. References are file-scoped, so one can resolve against the wrong
# list in a multi-list file. Numbered ranges and unnumbered references are also deliberately out of
# scope. Fenced code is blanked before both assertions; each Markdown file is read exactly once.
$stepFiles = @()
foreach ($scope in @('.claude/skills','.claude/commands','.claude/agents')) {
    $path = Join-Path $DistAbs $scope
    if (-not (Test-Path $path -PathType Container)) { continue }
    if ($scope -eq '.claude/skills') {
        $stepFiles += @(Get-ChildItem -LiteralPath $path -Recurse -Force -File -Filter *.md)
    } else {
        $stepFiles += @(Get-ChildItem -LiteralPath $path -Force -File -Filter *.md)
    }
}
$stepFiles = @($stepFiles | Sort-Object FullName -Unique)
$stepProblems = @()
$stepLabelCount = 0
$stepReferenceCount = 0
foreach ($file in $stepFiles) {
    $relative = $file.FullName.Substring($DistAbs.Length).TrimStart('\','/').Replace('\','/')
    $rawLines = @([IO.File]::ReadAllLines($file.FullName))
    $lines = New-Object System.Collections.Generic.List[string]
    $inFence = $false
    foreach ($line in $rawLines) {
        if ($line -match '^(?:```|~~~)') { $inFence = -not $inFence; $lines.Add(''); continue }
        if ($inFence) { $lines.Add('') } else { $lines.Add($line) }
    }
    $labels = New-Object System.Collections.Generic.List[int]
    $definitions = New-Object 'System.Collections.Generic.HashSet[int]'
    $references = New-Object System.Collections.Generic.List[int]
    foreach ($line in $lines) {
        if ($line -cmatch '^(?<n>\d+)\. ') { $labels.Add([int]$Matches.n) }
        if ($line -cmatch '^#{1,6}\s+Step\s+(?<n>\d+)\b') { $null = $definitions.Add([int]$Matches.n) }
        if ($line -match '^#{1,6}\s') { continue }
        foreach ($match in [regex]::Matches($line, '(?<![A-Za-z0-9_])[sS]tep\s+(?:\*\*)?(?<n>\d+)(?:\*\*)?')) {
            $references.Add([int]$match.Groups['n'].Value)
        }
    }
    $stepLabelCount += @($labels).Count
    $stepReferenceCount += @($references).Count
    $previous = $null
    foreach ($label in $labels) {
        if ($null -eq $previous -or $label -ne ($previous + 1)) {
            if ($label -ne 0 -and $label -ne 1) { $stepProblems += "$relative : ordered-list run starts at $label (expected 0 or 1)" }
        }
        $previous = $label
    }
    foreach ($reference in $references) {
        if (-not ($labels -contains $reference) -and -not $definitions.Contains($reference)) {
            $stepProblems += "$relative : prose step $reference has no ordered-list label or Step $reference heading in this file"
        }
    }
}
if (@($stepFiles).Count -eq 0) {
    Fail "step-reference scan found zero Markdown files in $Dist -- the input is empty or the scan scope changed."
} elseif ($stepReferenceCount -eq 0) {
    Fail "step-reference scan found zero prose references in $Dist ($(@($stepFiles).Count) files scanned; $stepLabelCount ordered-list labels found) -- the extractor is blind."
} elseif (@($stepProblems).Count -gt 0) {
    Fail "ordered-list or step-reference defects in shipped workflows -- $(@($stepProblems).Count) finding(s) ($(@($stepFiles).Count) files scanned; $stepLabelCount labels found; $stepReferenceCount prose references found)."
    $stepProblems | Sort-Object -Unique | ForEach-Object { Write-Output "  [step-references] $_" }
} else {
    OK "ordered-list runs are contiguous and prose step references resolve ($(@($stepFiles).Count) files scanned; $stepLabelCount labels found; $stepReferenceCount prose references found)."
}
}

if (Test-CheckSelected 'prompt-hook-cardinality') {
# --- 13. Copilot model-facing prompt hook cardinality -------------------------------------------
# DELIVERY CONSTRAINT observed on Copilot CLI 1.0.80, not a design preference: only the last
# userPromptSubmitted entry's additionalContext is delivered. If Copilot later honours every entry,
# a composed single hook still works and this check is merely a harmless anachronism.
$promptHookFiles = @(Get-ChildItem -LiteralPath $DistAbs -Recurse -Force -File -Filter hooks.json)
$promptHookProblems = @()
$promptHookEvents = 0
foreach ($file in $promptHookFiles) {
    $relative = $file.FullName.Substring($DistAbs.Length).TrimStart('\','/').Replace('\','/')
    try {
        $doc = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8) | ConvertFrom-Json
    } catch {
        $promptHookProblems += "$relative : hooks.json is unparseable ($($_.Exception.Message))"
        continue
    }
    if ($null -eq $doc.hooks) {
        $promptHookProblems += "$relative : hooks.json has no hooks object"
        continue
    }
    $events = @($doc.hooks.PSObject.Properties)
    $promptHookEvents += $events.Count
    $event = @($events | Where-Object { $_.Name -ceq 'userPromptSubmitted' })
    if ($event.Count -eq 1) {
        $entries = @($event[0].Value)
        if ($entries.Count -gt 1) {
            $promptHookProblems += "$relative : userPromptSubmitted has $($entries.Count) entries; Copilot CLI 1.0.80 delivers only the last entry, so compose model-facing additionalContext into one hook instead"
        }
    }
}
if ($promptHookFiles.Count -eq 0) {
    Fail "prompt-hook cardinality scan found no hooks.json in $Dist -- the scan is blind."
} elseif ($promptHookEvents -eq 0) {
    Fail "prompt-hook cardinality scan parsed zero events from $($promptHookFiles.Count) hooks.json file(s) in $Dist -- the scan is blind."
} elseif ($promptHookProblems.Count -gt 0) {
    Fail "Copilot prompt-hook delivery constraint violated -- $($promptHookProblems.Count) finding(s). Only the last userPromptSubmitted entry is delivered by Copilot CLI 1.0.80, so compose into one hook instead; if Copilot later honours every entry, the composed hook remains valid and this check is a harmless anachronism."
    $promptHookProblems | Sort-Object -Unique | ForEach-Object { Write-Output "  [prompt-hook-cardinality] $_" }
} else {
    OK "Copilot userPromptSubmitted cardinality is delivery-safe ($($promptHookFiles.Count) hooks.json file(s), $promptHookEvents events; at most one entry per userPromptSubmitted)."
}
}

Report-Timings
Write-Output ''
if ($failed -gt 0) { Write-Output "$failed dist validation check(s) FAILED for $Dist."; exit 1 }
Write-Output "All dist validation checks passed for $Dist."
exit 0
