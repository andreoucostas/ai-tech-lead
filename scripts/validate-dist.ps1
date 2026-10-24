# ai-tech-lead PowerShell dist validator. Validates an ALREADY-COMPOSED
# dist/<mode> tree — it does NOT rebuild it (see scripts/build.ps1 for that). Sixteen checks, each
# with a clear OK/FAIL line:
#   1. no unresolved @stack:NAME markers survive anywhere in the dist (composer leftovers)
#   2. every *.json in the dist parses under a strict JSON grammar (then ConvertFrom-Json)
#   3. no active shell script, shell shebang, or non-Windows GitHub runner remains
#   4. PowerShell AST parse is clean on every *.ps1 in the dist
#   5. the dist's OWN template-checks.ps1 suite passes, run from inside the dist dir
#   6. no meta-dev vocabulary leaks into shipped content (scripts/meta-denylist.txt)
#   7. every script a shipped *.md tells someone to RUN and every rendered relative inline link resolves
#   8. exactly 18 PowerShell hook registrations resolve with case-exact paths and required settings,
#      on the exact event map (event, matcher, script order, -ExecutionPolicy Bypass, timeout floors)
#   9. every core @stack marker expands from a non-empty stack snippet into the composed file
#  10. section-path citations name a heading that exists in the cited shipped file
#  11. CLAUDE.md imports exactly AGENTS.md and the shipped framework-rules carrier, and no other
#      always-loaded instruction file ships
#  12. top-level ordered-list runs are contiguous and prose step references resolve in-file
#  13. Copilot userPromptSubmitted exists and has at most one entry (only its last entry is delivered)
#  14. each route-prompt rail was reviewed with the canonical workflow bullet it repeats (meta/rail-sync.json;
#      --update-rail-sync records a reviewed pair for the named dist)
#  15. shipped skill and workflow-wrapper frontmatter loads on Copilot CLI
#  16. framework-ownership.json lists exactly the installed files, and framework-retirements.json parses
#      with the installer's rules and equals meta/framework-retirements-baseline.json
# Exit 1 = at least one check found a wrong artifact (FAIL:). Otherwise exit 2 = usage error, missing
# dist, or an input could not be examined (FATAL: or CANT-EXAMINE:, never skipped; the artifact is
# neither proven right nor wrong). Otherwise exit 0 = every check passed.
#   Usage: validate-dist.ps1 {dotnet|angular|monorepo} [dist-root] [-Check name[,name...]]
#   dist-root defaults to "dist" resolved under the repo root (scripts/..). Pass an explicit path
#   to validate a scratch copy instead (e.g. to plant failure fixtures without touching dist/).
# 5.1-safe: no pwsh-only syntax.
# EAP stays 'Continue': under 5.1 with EAP=Stop, a native command (template-checks)
# writing to a REDIRECTED stderr raises a terminating NativeCommandError and kills the script
# mid-check — exactly when a planted syntax error should have produced a FAIL line instead.
# Failure detection here is explicit ($LASTEXITCODE / try-catch), not exception-driven.
$ErrorActionPreference = 'Continue'

$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location -LiteralPath $RepoRoot

# --content-only is an explicit ARGUMENT, deliberately not an environment variable: an ambient switch
# that narrows a gate's scope can be inherited by a shell that never asked for it, and `release.ps1`
# redirects validator output to a log, so the NOTE below would not be seen on an otherwise-green
# gate. A caller must now ask for a partial run in the command itself.
$ContentOnly = $false
$UpdateRailSync = $false
$CheckArg = $null
$positional  = @()
for ($i = 0; $i -lt $args.Count; $i++) {
    $a = "$($args[$i])"
    if ($a -eq '--content-only') { $ContentOnly = $true }
    elseif ($a -eq '--update-rail-sync') { $UpdateRailSync = $true }
    elseif ($a -eq '-Check') {
        $i++
        if ($i -ge $args.Count) { [Console]::Error.WriteLine('usage error: -Check requires one or more comma-separated check names.'); exit 2 }
        $CheckArg = "$($args[$i])"
    } else { $positional += $a }
}
$ValidChecks = @('markers','json','powershell-topology','ps-syntax','template-checks','no-meta-leak','no-dead-instruction','hook-registration','marker-expansion','section-path','carrier-import','step-references','prompt-hook-cardinality','rail-sync','skill-frontmatter','ownership')
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
    if ($ContentOnly) { return @('no-meta-leak','no-dead-instruction','hook-registration','step-references','prompt-hook-cardinality','rail-sync','skill-frontmatter') -contains $name }
    return $true
}
if ($UpdateRailSync -and -not (Test-CheckSelected 'rail-sync')) {
    [Console]::Error.WriteLine('usage error: --update-rail-sync records the rail-sync check''s pairs; select it with -Check rail-sync or run every check.')
    exit 2
}
if ($UpdateRailSync -and $positional.Count -gt 1) {
    [Console]::Error.WriteLine('usage error: --update-rail-sync records the pairs of this repository''s own dist; run it without a dist-root.')
    exit 2
}
$Mode = $positional[0]
if ($Mode -ne 'dotnet' -and $Mode -ne 'angular' -and $Mode -ne 'monorepo') {
    [Console]::Error.WriteLine('usage: validate-dist.ps1 {dotnet|angular|monorepo} [dist-root] [--content-only] [-Check name[,name...]] [--update-rail-sync]')
    exit 2
}
$DistRoot = if ($positional.Count -ge 2 -and $positional[1]) { $positional[1] } else { 'dist' }
$Dist = Join-Path $DistRoot $Mode
# Resolve to absolute NOW: check 5 invokes the dist's own template-checks.ps1, which Set-Location's
# into the dist dir and does not restore it. Any relative path used after check 5 would resolve
# against the wrong root. Windows PowerShell 5.1 also misreads a relative -LiteralPath while the
# current location holds [ or ], so every read goes through $DistAbs; $Dist stays as typed, for messages.
$DistAbs = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($Dist)) { $Dist } else { Join-Path $RepoRoot $Dist }))
if (-not (Test-Path -LiteralPath $DistAbs -PathType Container)) {
    [Console]::Error.WriteLine("no $Dist -- run scripts/build.ps1 $Mode first")
    exit 2
}

$failed = 0
$cantExamine = 0
# Per-check elapsed time. Every check ends by calling OK, Fail or Cant-Examine exactly once, so timing the
# interval between those calls attributes cost without annotating each check by hand.
#
# Why this exists: this validator's runtime was governed by nothing. A check once regressed until a
# suite ran for hours, while every correctness gate stayed green throughout.
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
# An input the check could not read or enumerate, or a scan that is broken: no verdict on the artifact.
function Cant-Examine($m) { Record-Timing $m; Write-Output "CANT-EXAMINE: $m"; $script:cantExamine++ }
function OK($m)   { Record-Timing $m; Write-Output "OK:   $m" }

# --content-only skips checks 1-5 (the parse/marker/template-checks group) and runs only the content
# checks 6, 7, 8, 12, 13 and 14. It exists for ValidateDist.Tests.ps1: those five re-parse every shipped file on
# every case, which made that suite 9 minutes for 15 cases x 2 legs — in a file that runs in
# release.ps1 AND on both CI legs. Neither release.ps1 nor CI passes it, and the suite's green
# anchors still run the FULL validator so the skipped group stays exercised on both legs.
# A restricted run says so loudly on stdout: a subset must never be mistakable for a complete one,
# which is the exact reporting failure this change exists to remove.
if ($ContentOnly) {
    Write-Output "NOTE: --content-only -- checks 1-5 were SKIPPED; this is NOT a full validation."
}

# Resolution for check 8 is CASE-EXACT. Windows' default case-insensitive path resolution would
# otherwise let a `.PS1` registration resolve to a `.ps1` file and conceal non-canonical wiring.
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

# Used by check 8. Returns zero or more problem strings for one referenced PowerShell hook script.
function Test-HookRef {
    param([string]$Dist, [string]$File, [string]$Script)
    $problems = @()
    # hooks.json writes Windows paths with backslashes, and JSON escaping doubles them, so the raw
    # text holds ".claude\\hooks\\guard.ps1". Collapse any RUN of backslashes to one separator:
    # translating each one separately yields ".claude//hooks//guard.ps1", which can still resolve
    # and so would hide the malformed registration rather than failing on it.
    $rel = $Script -replace '\\+', '/'
    if ($rel -match '^[A-Za-z]:' -or $rel.StartsWith('/')) {
        # Unlike a documentation example (check 7), committed machine wiring must never be absolute.
        $problems += "$File : `"$rel`" is an absolute path — a committed absolute registration is a dead hook on every machine but the one it was written on"
        return $problems
    }
    if (-not (Test-CaseExactPath -Root $Dist -Relative $rel)) {
        $problems += "$File : `"$rel`" does not exist in this dist"
        return $problems
    }
    return $problems
}

# Strict JSON grammar for every registration and JSON-parse decision below. ConvertFrom-Json alone
# accepts single quotes, bare keys and NaN on both hosts, and trailing commas, comments and hex on
# pwsh, while both agent hosts read these files with a strict parser: one such file means no hook
# in it runs and every gate green. Copied from the shipped framework-doctor.ps1 (ConvertFrom-StrictJson)
# because this validator must not depend on a script inside the dist it examines.
function ConvertFrom-StrictJson([string]$Text) {
    $state = [pscustomobject]@{ Text = $Text; Index = 0; Length = $Text.Length }
    function Fail-StrictJson { throw 'invalid strict JSON' }
    function Skip-JsonWhitespace { while ($state.Index -lt $state.Length -and ([int]$state.Text[$state.Index] -in @(0x20,0x09,0x0A,0x0D))) { $state.Index++ } }
    function Read-JsonString { if($state.Index-ge$state.Length-or$state.Text[$state.Index]-ne'"'){Fail-StrictJson};$state.Index++;while($state.Index-lt$state.Length){$c=$state.Text[$state.Index];$state.Index++;if($c-eq'"'){return};if([int]$c-lt0x20){Fail-StrictJson};if($c-eq'\'){if($state.Index-ge$state.Length){Fail-StrictJson};$escape=$state.Text[$state.Index];$state.Index++;if('"\/bfnrt'.IndexOf($escape)-ge0){continue};if($escape-ne'u'-or$state.Index+4-gt$state.Length){Fail-StrictJson};for($h=0;$h-lt4;$h++){if(-not[Uri]::IsHexDigit($state.Text[$state.Index+$h])){Fail-StrictJson}};$state.Index+=4}};Fail-StrictJson }
    function Read-JsonNumber { if($state.Text[$state.Index]-eq'-'){$state.Index++;if($state.Index-ge$state.Length){Fail-StrictJson}};$code=[int]$state.Text[$state.Index];if($code-eq0x30){$state.Index++;if($state.Index-lt$state.Length-and[int]$state.Text[$state.Index]-ge0x30-and[int]$state.Text[$state.Index]-le0x39){Fail-StrictJson}}elseif($code-ge0x31-and$code-le0x39){do{$state.Index++}while($state.Index-lt$state.Length-and[int]$state.Text[$state.Index]-ge0x30-and[int]$state.Text[$state.Index]-le0x39)}else{Fail-StrictJson};if($state.Index-lt$state.Length-and$state.Text[$state.Index]-eq'.'){$state.Index++;$start=$state.Index;while($state.Index-lt$state.Length-and[int]$state.Text[$state.Index]-ge0x30-and[int]$state.Text[$state.Index]-le0x39){$state.Index++};if($state.Index-eq$start){Fail-StrictJson}};if($state.Index-lt$state.Length-and($state.Text[$state.Index]-eq'e'-or$state.Text[$state.Index]-eq'E')){$state.Index++;if($state.Index-lt$state.Length-and($state.Text[$state.Index]-eq'+'-or$state.Text[$state.Index]-eq'-')){$state.Index++};$start=$state.Index;while($state.Index-lt$state.Length-and[int]$state.Text[$state.Index]-ge0x30-and[int]$state.Text[$state.Index]-le0x39){$state.Index++};if($state.Index-eq$start){Fail-StrictJson}} }
    function Read-JsonArray { $state.Index++;Skip-JsonWhitespace;if($state.Index-lt$state.Length-and$state.Text[$state.Index]-eq']'){$state.Index++;return};while($true){Read-JsonValue;Skip-JsonWhitespace;if($state.Index-ge$state.Length){Fail-StrictJson};$c=$state.Text[$state.Index];$state.Index++;if($c-eq']'){return};if($c-ne','){Fail-StrictJson};Skip-JsonWhitespace} }
    function Read-JsonObject { $state.Index++;Skip-JsonWhitespace;if($state.Index-lt$state.Length-and$state.Text[$state.Index]-eq'}'){$state.Index++;return};while($true){Read-JsonString;Skip-JsonWhitespace;if($state.Index-ge$state.Length-or$state.Text[$state.Index]-ne':'){Fail-StrictJson};$state.Index++;Read-JsonValue;Skip-JsonWhitespace;if($state.Index-ge$state.Length){Fail-StrictJson};$c=$state.Text[$state.Index];$state.Index++;if($c-eq'}'){return};if($c-ne','){Fail-StrictJson};Skip-JsonWhitespace} }
    function Read-JsonValue { Skip-JsonWhitespace;if($state.Index-ge$state.Length){Fail-StrictJson};$c=$state.Text[$state.Index];if($c-eq'"'){Read-JsonString;return};if($c-eq'{'){Read-JsonObject;return};if($c-eq'['){Read-JsonArray;return};foreach($literal in @('true','false','null')){if($state.Index+$literal.Length-le$state.Length-and$state.Text.Substring($state.Index,$literal.Length)-ceq$literal){$state.Index+=$literal.Length;return}};if($c-eq'-'-or([int]$c-ge0x30-and[int]$c-le0x39)){Read-JsonNumber;return};Fail-StrictJson }
    Read-JsonValue;Skip-JsonWhitespace;if($state.Index-ne$state.Length){Fail-StrictJson};return($Text|ConvertFrom-Json -ErrorAction Stop)
}

# -Force on every enumeration below is LOAD-BEARING, not defensive. A leading-dot directory can be
# classified as hidden by a host/filesystem combination; omitting it can silently skip most of the
# distribution. The cardinality checks below make an empty or partial scan observable.
if (-not $ContentOnly) {
if (Test-CheckSelected 'markers') {
# --- 1. no unresolved @stack markers -------------------------------------------------------------
$markerRe = '@stack:[A-Za-z0-9_-]+'
$markerFiles = @()
$markerReadFails = @()
$markerInputs = @()
$markerEnumError = $null
try { $markerInputs = @(Get-ChildItem -Recurse -File -Force -LiteralPath $DistAbs -ErrorAction Stop) }
catch { $markerEnumError = $_.Exception.Message }
foreach ($f in $markerInputs) {
    try {
        if ((Select-String -LiteralPath $f.FullName -Pattern $markerRe -SimpleMatch:$false -Quiet -ErrorAction Stop)) {
            $markerFiles += $f.FullName
        }
    } catch { $markerReadFails += $f.FullName }
}
if ($null -ne $markerEnumError) {
    Cant-Examine "marker scan could not enumerate $Dist : $markerEnumError"
} elseif ($markerInputs.Count -eq 0) {
    Fail "marker scan found zero files in $Dist."
} elseif ($markerReadFails.Count -gt 0) {
    Cant-Examine ("marker scan could not read:" + ($markerReadFails -join ' '))
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
$coreRoot = (Resolve-Path -LiteralPath (Join-Path $RepoRoot 'src/core')).ProviderPath
$expansionProblems = @()
$expansionUnreadable = @()
$markerCount = 0
$consumedSnippets = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($coreFile in (Get-ChildItem -Recurse -File -Force -LiteralPath $coreRoot)) {
    $coreRel = $coreFile.FullName.Substring($coreRoot.Length).TrimStart('\', '/').Replace('\', '/')
    $distFile = Join-Path $DistAbs ($coreRel -replace '/', [IO.Path]::DirectorySeparatorChar)
    # A failed read is a statement error under EAP 'Continue': the variable would keep the PREVIOUS
    # file's text. Catch it, record the file, and skip what depended on it.
    $distText = $null
    if (Test-Path -LiteralPath $distFile) {
        try { $distText = ([IO.File]::ReadAllText($distFile) -replace "`r`n", "`n") } catch { $expansionUnreadable += $distFile; continue }
    }
    $coreText = $null
    try { $coreText = [IO.File]::ReadAllText($coreFile.FullName) } catch { $expansionUnreadable += $coreFile.FullName; continue }
    # BOTH marker forms, anchored exactly as the composer anchors them (build.ps1 $HtmlMarker /
    # $HashMarker): markdown uses `<!-- @stack:NAME -->`, scripts use `# @stack:NAME`, and each must
    # be the whole line. Matching only the HTML form left this gate blind to the 15 hash markers in
    # route-prompt/audit-trail/.gitignore/CI -- i.e. blind to the shipped hooks, which is the very
    # failure class it exists to catch. Anchoring also stops a prose mention of the syntax counting
    # as a marker.
    foreach ($match in [regex]::Matches($coreText, '(?m)^[ \t]*(?:<!-- @stack:([A-Za-z0-9_-]+) -->|# @stack:([A-Za-z0-9_-]+))[ \t]*\r?$')) {
        $markerCount++
        $name = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value }
        [void]$consumedSnippets.Add("$coreRel/$name")
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
                # A marker NO stack supplies is not stack-only, it is a typo: the composer would
                # drop the line from every dist, so fail it here.
                if ($otherCount -eq 0) {
                    $expansionProblems += "$Mode : $coreRel @stack:$name is supplied by no stack (no src/stacks/*/snippets/$coreRel/$name exists)"
                    continue
                }
                if ($otherCount -lt 2) { continue }
            }
        }
        $snippetTexts = @()
        $snippetUnreadable = $false
        foreach ($snippetPath in $snippetPaths) {
            try { $snippetTexts += ([IO.File]::ReadAllText($snippetPath) -replace "`r`n", "`n").TrimEnd("`n", "`r") }
            catch { $expansionUnreadable += $snippetPath; $snippetUnreadable = $true }
        }
        if ($snippetUnreadable) { continue }
        $snippetText = $snippetTexts -join "`n"
        if ([string]::IsNullOrWhiteSpace($snippetText)) {
            $expansionProblems += "$Mode : $coreRel @stack:$name resolves to an empty expansion"
        } elseif ($null -eq $distText) {
            $expansionProblems += "$Mode : $coreRel @stack:$name cannot expand because the composed file is missing"
        } elseif (-not $distText.Contains($snippetText)) {
            $expansionProblems += "$Mode : $coreRel @stack:$name snippet content is absent from the composed file"
        }
    }
}
# The mirror image: a snippet no core marker consumes (its marker line deleted or renamed, or its core
# file gone) ships in no dist, and nothing else reports it.
$stacksRoot = Join-Path $RepoRoot 'src/stacks'
if (Test-Path -LiteralPath $stacksRoot -PathType Container) {
    foreach ($stackDir in (Get-ChildItem -LiteralPath $stacksRoot -Directory -Force)) {
        $snipRoot = Join-Path $stackDir.FullName 'snippets'
        if (-not (Test-Path -LiteralPath $snipRoot -PathType Container)) { continue }
        $snipRootFull = (Resolve-Path -LiteralPath $snipRoot).ProviderPath
        foreach ($snip in (Get-ChildItem -Recurse -File -Force -LiteralPath $snipRootFull)) {
            $snipRel = $snip.FullName.Substring($snipRootFull.Length).TrimStart('\', '/').Replace('\', '/')
            if (-not $consumedSnippets.Contains($snipRel)) {
                $expansionProblems += "$($stackDir.Name) : src/stacks/$($stackDir.Name)/snippets/$snipRel no core marker consumes this snippet"
            }
        }
    }
}
if ($expansionUnreadable.Count -gt 0) {
    Cant-Examine ("marker-expansion could not read {0} file(s) in {1} -- the inventory is broken, not the dist." -f @($expansionUnreadable | Sort-Object -Unique).Count, $Mode)
    $expansionUnreadable | Sort-Object -Unique | ForEach-Object { Write-Output "  [marker-expansion] unreadable: $_" }
} elseif ($markerCount -eq 0) {
    Fail "marker-expansion inventory found zero core @stack markers -- the inventory is broken, not the dist."
} elseif ($expansionProblems.Count -gt 0) {
    Fail ("marker expansion failed for {0} problem(s) in {1}." -f $expansionProblems.Count, $Mode)
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
$citationReadFails = @()
foreach ($citedFile in $citationFiles) {
    $fileToken = [regex]::Escape($citedFile)
    $target = Join-Path $DistAbs ($citedFile -replace '/', [IO.Path]::DirectorySeparatorChar)
    $targetLines = @()
    $targetPresent = Test-Path -LiteralPath $target -PathType Leaf
    if ($targetPresent) {
        try { $targetLines = @([IO.File]::ReadAllLines($target)) } catch { $citationReadFails += $citedFile }
    }
    if ($targetLines.Count -gt 0 -or $targetPresent) { [void]$targetFileLookup.Add($citedFile) }
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
foreach ($f in (Get-ChildItem -Recurse -File -Force -LiteralPath $DistAbs)) {
    $rel = $f.FullName.Substring($DistAbs.Length).TrimStart('\', '/').Replace('\', '/')
    if ($f.Name -eq 'CHANGELOG.md') { continue }
    # A failed read is a statement error under EAP 'Continue': the variable would keep the PREVIOUS
    # file's content and this file would be reported as scanned. Catch it and move on.
    $bytes = $null
    try { $bytes = [IO.File]::ReadAllBytes($f.FullName) } catch { $citationReadFails += $rel; continue }
    if ($bytes -contains 0) { continue }
    $fileLines = $null
    try { $fileLines = [IO.File]::ReadAllLines($f.FullName) } catch { $citationReadFails += $rel; continue }
    $textFilesScanned++
    $lineNo = 0
    foreach ($line in $fileLines) {
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
if ($citationReadFails.Count -gt 0) {
    Cant-Examine ("section-path scan could not read:" + (($citationReadFails | Sort-Object -Unique) -join ' '))
} elseif ($textFilesScanned -eq 0) {
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
$claudeLines = @()
$claudeText = $null
$claudeReadError = $null
if (Test-Path -LiteralPath $claudePath -PathType Leaf) {
    try { $claudeText = [IO.File]::ReadAllText($claudePath); $claudeLines = @($claudeText -split "`r?`n") }
    catch { $claudeReadError = $_.Exception.Message }
}
if (-not (Test-Path -LiteralPath $claudePath -PathType Leaf)) {
    Fail "framework-rules import cannot be checked because CLAUDE.md is missing from $Dist."
} elseif ($null -ne $claudeReadError) {
    Cant-Examine "carrier-import could not read CLAUDE.md in $Dist : $claudeReadError"
} elseif ($claudeText.IndexOf($importLine, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
    Fail "CLAUDE.md is missing required import $importLine."
} elseif (-not (Test-Path -LiteralPath $carrierPath -PathType Leaf)) {
    Fail "CLAUDE.md imports $importLine but the carrier file is missing from $Dist."
} elseif (@($claudeLines | Where-Object { $_ -match '^@AGENTS\.md\s*$' }).Count -eq 0) {
    # B-272: AGENTS.md holds the project instructions; Claude Code reaches it only through this import.
    Fail "CLAUDE.md is missing required import @AGENTS.md."
} elseif (-not (Test-Path -LiteralPath (Join-Path $DistAbs 'AGENTS.md') -PathType Leaf)) {
    Fail "CLAUDE.md imports @AGENTS.md but AGENTS.md is missing from $Dist."
} else {
    # Invariant 2: the shipped AGENTS.md is the one instruction file. The context ceiling counts three
    # fixed files, so an extra import or a second always-loaded file would add to every prompt unmeasured.
    # Any @ token outside a fence or code span is an import (Claude Code resolves them mid-line too).
    $instructionProblems = @()
    $allowedImports = @('@AGENTS.md', $importLine)
    $fenceChar = $null
    $lineNo = 0
    foreach ($line in $claudeLines) {
        $lineNo++
        if ($line -match '^\s*(`{3,}|~{3,})') {
            $char = $Matches[1].Substring(0, 1)
            if ($null -eq $fenceChar) { $fenceChar = $char } elseif ($fenceChar -eq $char) { $fenceChar = $null }
            continue
        }
        if ($null -ne $fenceChar) { continue }
        $prose = [regex]::Replace($line, '`+[^`]*`+', '')
        foreach ($m in [regex]::Matches($prose, '(?:^|[\s(])(@[^\s)\]>",;]+)')) {
            $token = $m.Groups[1].Value
            if (@($allowedImports | Where-Object { $_ -ieq $token }).Count -eq 0) {
                $instructionProblems += "CLAUDE.md : unexpected import $token (line $lineNo); it may import only @AGENTS.md and the framework-rules carrier"
            }
        }
    }
    $instructionFiles = @()
    $instructionEnumError = $null
    try { $instructionFiles = @(Get-ChildItem -Recurse -File -Force -LiteralPath $DistAbs -ErrorAction Stop) }
    catch { $instructionEnumError = $_.Exception.Message }
    foreach ($f in $instructionFiles) {
        $rel = $f.FullName.Substring($DistAbs.Length).TrimStart('\', '/').Replace('\', '/')
        $isInstruction = $false
        if ($rel -imatch '^\.claude/rules/') { $isInstruction = $true }
        elseif ($rel -ieq '.github/copilot-instructions.md') { $isInstruction = $true }
        elseif ($rel -imatch '^\.github/instructions/.+\.instructions\.md$' -and $rel -ine '.github/instructions/framework-rules.instructions.md') { $isInstruction = $true }
        elseif ($f.Name -ieq 'GEMINI.md' -or $f.Name -ieq 'CLAUDE.local.md') { $isInstruction = $true }
        elseif ($rel.Contains('/') -and ($f.Name -ieq 'AGENTS.md' -or $f.Name -ieq 'CLAUDE.md')) { $isInstruction = $true }
        if ($isInstruction) {
            $instructionProblems += "$rel : an instruction file outside the expected set (root AGENTS.md, root CLAUDE.md, the framework-rules carrier); fold it into AGENTS.md"
        }
    }
    if ($null -ne $instructionEnumError) {
        Cant-Examine "carrier-import could not enumerate $Dist : $instructionEnumError"
    } elseif ($instructionProblems.Count -gt 0) {
        Fail ("unexpected always-loaded instruction content in $Dist -- {0} finding(s). The shipped AGENTS.md is the one instruction file; anything else loads on every prompt outside the measured context footprint." -f $instructionProblems.Count)
        $instructionProblems | Sort-Object -Unique | ForEach-Object { Write-Output "  [carrier-import] $_" }
    } else {
        OK "CLAUDE.md imports AGENTS.md and the delivered framework-rules carrier."
    }
}
}

if (Test-CheckSelected 'json') {
# --- 2. every *.json parses -------------------------------------------------------------------------
$jsonFails = @()
$jsonReadFails = @()
$jsonInputs = @()
$jsonEnumError = $null
try { $jsonInputs = @(Get-ChildItem -Recurse -File -Force -Filter *.json -LiteralPath $DistAbs -ErrorAction Stop) }
catch { $jsonEnumError = $_.Exception.Message }
foreach ($f in $jsonInputs) {
    try {
        $jsonText = [IO.File]::ReadAllText($f.FullName)
    } catch { $jsonReadFails += $f.FullName; continue }
    try {
        ConvertFrom-StrictJson $jsonText | Out-Null
    } catch { $jsonFails += $f.FullName
    }
}
if ($null -ne $jsonEnumError) { Cant-Examine "JSON scan could not enumerate $Dist : $jsonEnumError" }
elseif ($jsonInputs.Count -eq 0) { Fail "JSON scan found zero files in $Dist." }
elseif ($jsonReadFails.Count -gt 0) { Cant-Examine ("JSON scan could not read:" + ($jsonReadFails -join ' ')) }
elseif ($jsonFails.Count -gt 0) { Fail ("invalid JSON (strict grammar):" + ($jsonFails -join ' ')) }
else { OK "all $($jsonInputs.Count) *.json files parse (strict grammar, then ConvertFrom-Json)." }
}

if (Test-CheckSelected 'powershell-topology') {
# --- 3. PowerShell-only executable topology ------------------------------------------------------
$topologyProblems = @()
$topologyReadFails = @()
$topologyFiles = @()
$topologyEnumError = $null
try { $topologyFiles = @(Get-ChildItem -Recurse -File -Force -LiteralPath $DistAbs -ErrorAction Stop) }
catch { $topologyEnumError = $_.Exception.Message }
foreach ($f in $topologyFiles) {
    $relative = $f.FullName.Substring($DistAbs.Length).TrimStart('\','/').Replace('\','/')
    if ($f.Extension -ieq '.sh') { $topologyProblems += "$relative : active .sh implementation" }
    try {
        $reader = New-Object IO.StreamReader($f.FullName, [Text.Encoding]::UTF8, $true)
        try { $firstLine = $reader.ReadLine() } finally { $reader.Dispose() }
    } catch { $topologyReadFails += "$relative : $($_.Exception.Message)"; continue }
    if ($firstLine -match '^#!.*(?:^|[/\s])(?:sh|bash|dash|ash|zsh|ksh|fish|csh|tcsh)(?:\s|$)') {
        $topologyProblems += "$relative : active shell shebang '$firstLine'"
    }
}
$workflowRoot = Join-Path $DistAbs '.github/workflows'
if (Test-Path -LiteralPath $workflowRoot -PathType Container) {
    foreach ($workflow in @(Get-ChildItem -LiteralPath $workflowRoot -File -Force -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @('.yml','.yaml') })) {
        try { $workflowText = [IO.File]::ReadAllText($workflow.FullName) }
        catch { $topologyReadFails += "$($workflow.Name) : $($_.Exception.Message)"; continue }
        # A matrix-selected runner does not expose its OS on the runs-on line. Ignore comment-only
        # lines, then inspect every executable YAML value; container jobs are unsupported too.
        $activeWorkflow = (($workflowText -split "`r?`n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
        if ($activeWorkflow -match '(?i)(?:^|[^A-Za-z0-9_])(?:ubuntu|linux|macos)(?:[-_.A-Za-z0-9]*)(?:$|[^A-Za-z0-9_])') {
            $topologyProblems += ".github/workflows/$($workflow.Name) : unsupported non-Windows runner"
        }
        if ($activeWorkflow -match '(?im)^\s*container\s*:') {
            $topologyProblems += ".github/workflows/$($workflow.Name) : unsupported container job"
        }
    }
}
if ($null -ne $topologyEnumError) { Cant-Examine "PowerShell topology scan could not enumerate $Dist : $topologyEnumError" }
elseif ($topologyFiles.Count -eq 0) { Fail "PowerShell topology scan found zero files in $Dist." }
elseif ($topologyReadFails.Count -gt 0) {
    Cant-Examine "PowerShell topology scan could not read $($topologyReadFails.Count) file(s)."
    $topologyReadFails | Sort-Object -Unique | ForEach-Object { Write-Output "  [powershell-topology] $_" }
} elseif ($topologyProblems.Count -gt 0) {
    Fail "PowerShell-only topology has $($topologyProblems.Count) active shell or non-Windows CI surface(s)."
    $topologyProblems | Sort-Object -Unique | ForEach-Object { Write-Output "  [powershell-topology] $_" }
} else { OK "PowerShell-only topology: $($topologyFiles.Count) files scanned; no active .sh, shell shebang, or non-Windows GitHub runner." }
}

if (Test-CheckSelected 'ps-syntax') {
# --- 4. PowerShell AST parse on every *.ps1 -----------------------------------------------------------
# Parse in the current process rather than silently upgrading a deliberate Windows PowerShell 5.1
# run to pwsh. Retain a distinct host/PATH diagnostic for the impossible-to-continue case where the
# current process cannot identify its own executable.
$currentPowerShellHost = (Get-Process -Id $PID).Path
if (-not $currentPowerShellHost) {
    [Console]::Error.WriteLine('FATAL: no PowerShell host found on PATH or at any known location; this is a host/PATH problem, not a dist problem, so *.ps1 syntax could not be checked.')
    exit 2
}
$ps1Fails = @()
$ps1ReadFails = @()
$ps1Inputs = @()
$ps1EnumError = $null
try { $ps1Inputs = @(Get-ChildItem -Recurse -File -Force -Filter *.ps1 -LiteralPath $DistAbs -ErrorAction Stop) }
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
if ($null -ne $ps1EnumError) { Cant-Examine "PowerShell scan could not enumerate $Dist : $ps1EnumError" }
elseif ($ps1Inputs.Count -eq 0) { Fail "PowerShell scan found zero files in $Dist." }
elseif ($ps1ReadFails.Count -gt 0) { Cant-Examine ("PowerShell scan could not read:" + ($ps1ReadFails -join ' ')) }
elseif ($ps1Fails.Count -gt 0) { Fail ("PS syntax errors: " + ($ps1Fails -join '; ')) }
else { OK "all $($ps1Inputs.Count) *.ps1 files parse cleanly." }
}

if (Test-CheckSelected 'template-checks') {
# --- 5. the dist's own template-checks suite ------------------------------------------------------
$Tc = Join-Path $DistAbs 'scripts/template-checks.ps1'
if (-not (Test-Path -LiteralPath $Tc)) {
    Fail "missing $Tc -- cannot run the dist's own template-checks suite."
} else {
    $tcOut = & $Tc 2>&1
    $tcStatus = $LASTEXITCODE
    $tcOut | ForEach-Object { Write-Output "  [template-checks] $_" }
    if ($tcStatus -eq 2) {
        # template-checks' own contract: 2 = a required input could not be inspected, 3 = a verified finding.
        Cant-Examine "$Tc could not examine its input (exit 2) -- see [template-checks] lines above."
    } elseif ($tcStatus -ne 0) {
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
# scripts/meta-denylist.txt so policy and implementation remain independently reviewable.
$DenyFile = Join-Path $RepoRoot 'scripts/meta-denylist.txt'
if (-not (Test-Path -LiteralPath $DenyFile)) {
    [Console]::Error.WriteLine("FATAL: missing $DenyFile -- cannot run the no-meta-leak check.")
    exit 2
}
$denyPatterns = @()
$allowPaths   = @()
foreach ($line in (Get-Content -LiteralPath $DenyFile)) {
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
$distFiles = @(Get-ChildItem -Recurse -File -Force -LiteralPath $DistAbs)
$filesScanned = @($distFiles).Count
foreach ($f in $distFiles) {
    $rel = ($f.FullName.Substring($DistAbs.Length).TrimStart('\', '/')) -replace '\\', '/'
    $skip = $false
    foreach ($a in $allowPaths) { if ($rel -like "*$a*") { $skip = $true; break } }
    if ($skip) { continue }
    foreach ($p in $denyPatterns) {
        # Select-String is case-insensitive by default, which is the intended denylist behavior.
        # A read error must be RECORDED, not swallowed: -ErrorAction SilentlyContinue alone let an
        # unreadable file count as scanned and clean (B-59, and sol's review of this change).
        $scanErr = $null
        foreach ($m in (Select-String -LiteralPath $f.FullName -Pattern $p -ErrorAction SilentlyContinue -ErrorVariable scanErr)) {
            $leaks += ("{0}:{1}: {2}" -f $rel, $m.LineNumber, $p)
        }
        if ($scanErr) { $scanErrors += ("{0}: {1}" -f $rel, $scanErr[0].Exception.Message) }
    }
}
$leaks = $leaks | Sort-Object
if (@($scanErrors).Count -gt 0) {
    Cant-Examine ("no-meta-leak could not scan {0} file(s) in {1} -- the scan is broken, not the dist." -f @($scanErrors).Count, $Dist)
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
# Resolution base is the DIST ROOT, not the doc's own directory. The extractor intentionally still
# recognizes stale `bash ... .sh` examples so retiring Bash cannot make dead historical instructions
# invisible to this diagnostic.
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
foreach ($f in (Get-ChildItem -Recurse -File -Force -LiteralPath $DistAbs -Filter *.md)) {
    if ($f.Name -eq 'CHANGELOG.md') { continue }
    $docsScanned++
    $rel = ($f.FullName.Substring($DistAbs.Length).TrimStart('\', '/')) -replace '\\', '/'
    $n = 0
    # Same rule as check 6: a doc that could not be READ is not a doc that contained nothing.
    $docErr = $null
    $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue -ErrorVariable docErr)
    if ($docErr) { $docReadErrors += ("{0}: {1}" -f $rel, $docErr[0].Exception.Message); continue }
    $fenceChar = $null
    foreach ($line in $lines) {
        $n++
        # Command examples are instructions even inside code fences; keep the established check-7
        # grammar independent from the rendered-link grammar below.
        foreach ($m in [regex]::Matches($line, '(?i)(?:(?:pwsh|bash|powershell)(?:\.exe)?(?:\s+-[A-Za-z]+(?:\s+[A-Za-z]+)?)*\s+([A-Za-z0-9_./\\-]+\.(?:ps1|sh))|python\s+([A-Za-z0-9_./\\-]+\.py))')) {
            # Backslash paths (`.\scripts\x.ps1`) are normalised to `/` before the existence test.
            $script = (@($m.Groups[1].Value, $m.Groups[2].Value) | Where-Object { $_ } | Select-Object -First 1) -replace '\\', '/'
            $refsExtracted++
            if ($script.StartsWith('/')) {
                $absoluteRefs += ("{0}:{1}: absolute example `{2}` out of scope" -f $rel, $n, $script)
                continue
            }
            if (-not (Test-Path -LiteralPath (Join-Path $DistAbs $script))) {
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
    Cant-Examine ("no-dead-instruction could not read {0} doc(s) in {1} -- the scan is broken, not the dist." -f @($docReadErrors).Count, $Dist)
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
# Bare interpreter names remain intentional team-portable configuration. Runtime resolution is
# reported by the doctor's `Hook liveness` row; this build-time check proves the configured host,
# shell routing, cardinality, and case-exact script target.
$regFiles = @('.claude/settings.json', '.claude/settings.windows.json', '.github/hooks/hooks.json')
$regProblems = @()
$regUnreadable = @()
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
# The exact event map each registration file must carry: which script sits on which event, the
# matcher, the order within an event, and the timeout floors. Counting handlers and checking each
# one's target left a dist whose guard sat on the wrong event, behind a matcher naming no tool, or
# under a 1 s timeout green while the hook never did its job. The post-write floor is the hook's
# own budget ceiling (clamped to 80 s by the hook) plus a margin for its bounded-tool cleanup.
function New-HookExpectation {
    param([string]$Name, [int]$Floor = 0, [bool]$Required = $false, [string]$Mode = '')
    return @{ Name = $Name; Script = ".claude/hooks/$Name.ps1"; Floor = $Floor; Required = $Required; Mode = $Mode }
}
function Get-HookWiringProblems {
    param([string]$File, $Hooks, [bool]$Claude)
    $problems = @()
    $sessionStart = New-HookExpectation 'session-start'
    $routePrompt = New-HookExpectation 'route-prompt'
    $guard = New-HookExpectation 'guard' 10
    $postWrite = New-HookExpectation 'post-write' 85 $true
    $auditTrail = New-HookExpectation 'audit-trail'
    if ($Claude) {
        $expected = @(
            @{ Event = 'SessionStart';     Matcher = '';           Handlers = @($sessionStart) },
            @{ Event = 'UserPromptSubmit'; Matcher = '';           Handlers = @($routePrompt) },
            @{ Event = 'PreToolUse';       Matcher = 'Write|Edit'; Handlers = @($guard) },
            @{ Event = 'PostToolUse';      Matcher = 'Write|Edit'; Handlers = @($postWrite, $auditTrail) },
            @{ Event = 'Stop';             Matcher = '';           Handlers = @((New-HookExpectation 'boy-scout-check')) }
        )
        $timeoutKey = 'timeout'; $commandKey = 'command'
    } else {
        $expected = @(
            @{ Event = 'sessionStart';        Matcher = ''; Handlers = @($sessionStart) },
            @{ Event = 'userPromptSubmitted'; Matcher = ''; Handlers = @($routePrompt) },
            @{ Event = 'preToolUse';          Matcher = ''; Handlers = @($guard) },
            @{ Event = 'postToolUse';         Matcher = ''; Handlers = @($postWrite, $auditTrail) },
            @{ Event = 'agentStop';           Matcher = ''; Handlers = @((New-HookExpectation 'boy-scout-check' 0 $false 'scan')) }
        )
        $timeoutKey = 'timeoutSec'; $commandKey = 'powershell'
    }
    $eventNames = @($expected | ForEach-Object { $_.Event })
    foreach ($property in @($Hooks.PSObject.Properties)) {
        if ($eventNames -cnotcontains $property.Name) { $problems += "$File : unexpected hook event '$($property.Name)'; the only registered events are $($eventNames -join ', ') (names are case-exact)" }
    }
    foreach ($exp in $expected) {
        $match = @($Hooks.PSObject.Properties | Where-Object { $_.Name -ceq $exp.Event })
        if ($match.Count -ne 1) { $problems += "$File : hook event '$($exp.Event)' is not registered"; continue }
        if ($match[0].Value -isnot [System.Array]) { continue }
        $carriers = @($match[0].Value)
        $entries = @()
        if ($Claude) {
            if ($carriers.Count -ne 1) { $problems += "$File : event '$($exp.Event)' must hold exactly one hook group, found $($carriers.Count)" }
            if ($carriers.Count -gt 0 -and $carriers[0] -is [pscustomobject]) {
                $carrier = $carriers[0]
                if ($carrier.hooks -is [System.Array]) { $entries = @($carrier.hooks) }
            } else { continue }
        } else {
            $carrier = $null
            $entries = $carriers
        }
        # Claude carries the matcher on the group; Copilot has no matcher at all, and guard.ps1
        # self-filters by path and content.
        $matcherHolders = @(); if ($Claude) { $matcherHolders = @($carrier) } else { $matcherHolders = @($entries) }
        foreach ($holder in $matcherHolders) {
            $found = @(); if ($holder -is [pscustomobject]) { $found = @($holder.PSObject.Properties | Where-Object { $_.Name -ieq 'matcher' }) }
            if ($exp.Matcher -ne '') {
                $foundText = 'none'; if ($found.Count -gt 0) { $foundText = [string]$found[0].Value }
                if ($found.Count -ne 1 -or $found[0].Name -cne 'matcher' -or [string]$found[0].Value -cne $exp.Matcher) { $problems += "$File : $($exp.Event) matcher must be exactly '$($exp.Matcher)', found '$foundText'" }
            } elseif ($found.Count -gt 0) {
                $problems += "$File : $($exp.Event) must not carry a matcher, found '$([string]$found[0].Value)'"
            }
        }
        $wanted = @($exp.Handlers | ForEach-Object { $_.Script })
        if ($entries.Count -ne $exp.Handlers.Count) { $problems += "$File : event '$($exp.Event)' must register exactly $($exp.Handlers.Count) handler(s) ($($wanted -join ', ')), found $($entries.Count)" }
        for ($i = 0; $i -lt [Math]::Min($entries.Count, $exp.Handlers.Count); $i++) {
            $h = $exp.Handlers[$i]; $entry = $entries[$i]
            $cmd = ''
            if ($entry -is [pscustomobject]) {
                $cp = @($entry.PSObject.Properties | Where-Object { $_.Name -ceq $commandKey })
                if ($cp.Count -eq 1) { $cmd = [string]$cp[0].Value }
            }
            $target = Get-FileArgument $cmd
            $rel = ''; if ($target) { $rel = $target -replace '\\+', '/' }
            if ($rel -cne $h.Script) { $problems += "$File : event '$($exp.Event)' handler $($i + 1) must run $($h.Script), found '$rel'" }
            if ($h.Mode -ne '' -and $cmd -cnotmatch ('(?:^|\s)-Mode\s+' + [regex]::Escape($h.Mode) + '(?:\s|$)')) { $problems += "$File : event '$($exp.Event)' command must pass -Mode $($h.Mode): $cmd" }
            if ($h.Floor -gt 0 -and $entry -is [pscustomobject]) {
                $tp = @($entry.PSObject.Properties | Where-Object { $_.Name -ceq $timeoutKey })
                if ($tp.Count -eq 0) {
                    if ($h.Required) { $problems += "$File : $($h.Name) timeout must be at least $($h.Floor) s, found none ($timeoutKey is missing)" }
                } elseif ($tp[0].Value -isnot [ValueType] -or $tp[0].Value -is [bool]) {
                    $problems += "$File : $($h.Name) timeout must be at least $($h.Floor) s, found '$([string]$tp[0].Value)' ($timeoutKey is not a number)"
                } elseif ([double]$tp[0].Value -lt $h.Floor) {
                    $problems += "$File : $($h.Name) timeout must be at least $($h.Floor) s, found $($tp[0].Value) ($timeoutKey)"
                }
            }
        }
    }
    return $problems
}
foreach ($rf in $regFiles) {
    $rfAbs = Join-Path $DistAbs $rf
    if (-not (Test-Path -LiteralPath $rfAbs)) { $regProblems += "$rf : registration file missing from this dist"; continue }
    # Unreadable (could not examine) and unparseable (a wrong artifact) are different results.
    $rawRegistration = $null
    try { $rawRegistration = [IO.File]::ReadAllText($rfAbs) }
    catch { $regUnreadable += $rf; continue }
    $json = $null
    try { $json = ConvertFrom-StrictJson $rawRegistration }
    catch { $regProblems += "$rf : registration file is unparseable (not strict JSON)"; continue }
    if ($rawRegistration -match '(?i)"bash"\s*:') { $regProblems += "$rf : Bash hook key remains in PowerShell-only configuration" }
    if ($null -eq $json.hooks -or -not ($json.hooks -is [pscustomobject])) { $regProblems += "$rf : registration file has no hooks object"; continue }
    $handlers = 0
    if ($rf -like '.claude/*') {
        if ([string]$json.env.CLAUDE_CODE_USE_POWERSHELL_TOOL -cne '1') { $regProblems += "$rf : CLAUDE_CODE_USE_POWERSHELL_TOOL must be '1'" }
        if ([string]$json.defaultShell -cne 'powershell') { $regProblems += "$rf : defaultShell must be exactly 'powershell'" }
        $expectedInterpreter = if ($rf -ceq '.claude/settings.json') { 'pwsh' } else { 'powershell' }
        foreach ($event in @($json.hooks.PSObject.Properties)) {
            if ($event.Value -isnot [System.Array]) { $regProblems += "$rf : hook event '$($event.Name)' must be an array"; continue }
            foreach ($group in @($event.Value)) {
                if ($group -isnot [pscustomobject] -or $group.hooks -isnot [System.Array]) { $regProblems += "$rf : hook group in event '$($event.Name)' has no hooks array"; continue }
                foreach ($entry in @($group.hooks)) {
                    if ($entry.type -ne 'command' -or [string]::IsNullOrWhiteSpace([string]$entry.command)) { $regProblems += "$rf : hook entry must have type 'command' and a non-empty command"; continue }
                    $handlers++; $regCount++
                    $cmd = [string]$entry.command; $interp = ($cmd -split '\s+')[0]
                    if ($interp -cne $expectedInterpreter) { $regProblems += "$rf : expected interpreter '$expectedInterpreter', found '$interp' in: $cmd" }
                    if ($cmd -cnotmatch '(?:^|\s)-NoProfile(?:\s|$)') { $regProblems += "$rf : command omits exact -NoProfile: $cmd" }
                    if ($cmd -cnotmatch '(?:^|\s)-ExecutionPolicy\s+Bypass(?:\s|$)') { $regProblems += "$rf : command omits exact -ExecutionPolicy Bypass: $cmd" }
                    if ([string]$entry.shell -cne 'powershell') { $regProblems += "$rf : command hook shell must be exactly 'powershell': $cmd" }
                    if ([string]$entry.cwd -cne '.') { $regProblems += "$rf : Claude-format entry must set ""cwd"": ""."" (repository root); Copilot runtimes read this file too, and one starting it in a subfolder workspace fails its relative -File: $cmd" }
                    $script = Get-FileArgument $cmd
                    if (-not $script) { $regProblems += "$rf : no -File argument in: $cmd" }
                    elseif ($script -notmatch '\.ps1$') { $regProblems += "$rf : non-PowerShell hook target '$script'" }
                    else { $regProblems += (Test-HookRef -Dist $DistAbs -File $rf -Script $script) }
                }
            }
        }
        $settingsCounts[$rf] = $handlers
    } else {
        foreach ($event in @($json.hooks.PSObject.Properties)) {
            if ($event.Value -isnot [System.Array]) { $regProblems += "$rf : hook event '$($event.Name)' must be an array"; continue }
            foreach ($entry in @($event.Value)) {
                if ($entry -isnot [pscustomobject]) { $regProblems += "$rf : hook entry in event '$($event.Name)' is not an object"; continue }
                $hasPs = -not [string]::IsNullOrWhiteSpace([string]$entry.powershell)
                if (-not $hasPs) { $regProblems += "$rf : hook entry must have one non-empty powershell command"; continue }
                $hookEntries++
                $handlers++; $regCount++
                $cmd = [string]$entry.powershell
                $interp = ($cmd -split '\s+')[0]
                if ($interp -cne 'pwsh') { $regProblems += "$rf : Copilot command must explicitly invoke 'pwsh', found '$interp' in: $cmd" }
                if ($cmd -cnotmatch '(?:^|\s)-NoProfile(?:\s|$)') { $regProblems += "$rf : command omits exact -NoProfile: $cmd" }
                if ($cmd -cnotmatch '(?:^|\s)-ExecutionPolicy\s+Bypass(?:\s|$)') { $regProblems += "$rf : command omits exact -ExecutionPolicy Bypass: $cmd" }
                if ([string]$entry.cwd -cne '.') { $regProblems += "$rf : Copilot entry must set ""cwd"": ""."" (repository root), or a host starting it elsewhere fails its relative -File: $cmd" }
                $script = Get-FileArgument $cmd
                if (-not $script) { $regProblems += "$rf : no -File argument in: $cmd" }
                elseif ($script -notmatch '\.ps1$') { $regProblems += "$rf : non-PowerShell hook target '$script'" }
                else { $regProblems += (Test-HookRef -Dist $DistAbs -File $rf -Script $script) }
            }
        }
    }
    if ($handlers -eq 0) { $regProblems += "$rf : registration file yields zero handlers" }
    else { $regProblems += (Get-HookWiringProblems -File $rf -Hooks $json.hooks -Claude ($rf -like '.claude/*')) }
}
# The handler counts below are meaningless once a registration file could not be read.
if (@($regUnreadable).Count -eq 0) {
    foreach ($rf in @('.claude/settings.json','.claude/settings.windows.json')) {
        if ([int]$settingsCounts[$rf] -ne 6) { $regProblems += "$rf : expected exactly 6 command hooks, found $([int]$settingsCounts[$rf])" }
    }
    if ($hookEntries -ne 6) { $regProblems += ".github/hooks/hooks.json : expected exactly 6 PowerShell entries, found $hookEntries" }
    if ($regCount -ne 18) { $regProblems += "all registration files : expected exactly 18 PowerShell handlers, found $regCount" }
}
if (@($regProblems).Count -gt 0) {
    Fail ("hook registrations reference {0} missing or invalid target(s) in {1}. A registration that cannot start is a hook that silently never runs." -f @($regProblems).Count, $Dist)
    $regProblems | Sort-Object -Unique | ForEach-Object { Write-Output "  [hook-registration] $_" }
}
if (@($regUnreadable).Count -gt 0) {
    Cant-Examine ("hook registration scan could not read:" + (($regUnreadable | Sort-Object -Unique) -join ' '))
} elseif (@($regProblems).Count -eq 0) {
    OK "exactly 18 PowerShell hook registrations resolve (settings.json 6, settings.windows.json 6, hooks.json 6; strict JSON; event map, matchers and timeout floors pinned)"
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
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }
    if ($scope -eq '.claude/skills') {
        $stepFiles += @(Get-ChildItem -LiteralPath $path -Recurse -Force -File -Filter *.md)
    } else {
        $stepFiles += @(Get-ChildItem -LiteralPath $path -Force -File -Filter *.md)
    }
}
$stepFiles = @($stepFiles | Sort-Object FullName -Unique)
$stepProblems = @()
$stepReadFails = @()
$stepLabelCount = 0
$stepReferenceCount = 0
foreach ($file in $stepFiles) {
    $relative = $file.FullName.Substring($DistAbs.Length).TrimStart('\','/').Replace('\','/')
    $rawLines = $null
    try { $rawLines = @([IO.File]::ReadAllLines($file.FullName)) } catch { $stepReadFails += $relative; continue }
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
if ($stepReadFails.Count -gt 0) {
    Cant-Examine ("step-reference scan could not read:" + (($stepReadFails | Sort-Object -Unique) -join ' '))
} elseif (@($stepFiles).Count -eq 0) {
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
        $doc = ConvertFrom-StrictJson ([IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8))
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
    } else {
        # Renaming the event used to disarm this check instead of failing it: no event, no finding.
        $promptHookProblems += "$relative : no userPromptSubmitted event; the routing and rail hook is not registered under the exact event name Copilot CLI delivers"
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

if (Test-CheckSelected 'rail-sync') {
# --- 14. route-prompt rails reviewed against the canonical workflow bullets ----------------------
# The per-prompt rails repeat the framework rules' section-1 Agentic Workflow bullets; v0.77.0 added two
# clauses to the bullets and no rail followed. meta/rail-sync.json records, per dist and workflow, the
# SHA-256 of each composed bullet (with its continuation lines) and of its rail as last reviewed
# together. A change to either, or a section-1 bullet with no paired rail, fails here until someone
# reviews the pair and records it again with --update-rail-sync.
$railSyncPath = Join-Path $RepoRoot 'meta/rail-sync.json'
$railRulesRel = '.github/instructions/framework-rules.instructions.md'
$railRouteRel = '.claude/hooks/route-prompt.ps1'
$railCoreRules = 'src/core/.github/instructions/framework-rules.instructions.md'
$railStackBullets = "src/stacks/$Mode/snippets/.github/instructions/framework-rules.instructions.md/workflow-bullets"
$railCoreRoute = 'src/core/.claude/hooks/route-prompt.ps1'
$railPairs = [ordered]@{ 'Bug fix' = 'railsFix'; 'Debt cleanup' = 'railsDebt'; 'Feature' = 'railsFeature'; 'Investigation / design' = 'railsDesign'; 'Refactor' = 'railsRefactor'; 'Test' = 'railsTest' }
$railSha = [Security.Cryptography.SHA256]::Create()
$railCurrent = [ordered]@{}
$railProblems = @()
$railBlind = $null
function Get-RailSourceLine([string]$Relative, [string]$Needle) {
    $path = Join-Path $RepoRoot $Relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    $lines = [IO.File]::ReadAllLines($path)
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].TrimEnd() -ceq $Needle) { return "$Relative`:$($i + 1)" } }
    return $null
}
try {
    $railRulesText = ([IO.File]::ReadAllText((Join-Path $DistAbs $railRulesRel), [Text.Encoding]::UTF8)).Replace("`r`n", "`n")
    $railRouteText = ([IO.File]::ReadAllText((Join-Path $DistAbs $railRouteRel), [Text.Encoding]::UTF8)).Replace("`r`n", "`n")
} catch { $railBlind = "cannot read $railRulesRel or $railRouteRel in $Dist ($($_.Exception.Message))" }
if (-not $railBlind) {
    $railSection = [regex]::Match($railRulesText, '(?ms)^### 1\. Classify the intent.*?(?=^### |\z)')
    if (-not $railSection.Success) { $railBlind = "no '### 1. Classify the intent' section in $railRulesRel" }
}
if (-not $railBlind) {
    # Each section-1 bullet with its continuation lines, indented or not (Markdown folds both into the
    # item); a blank line or the next bullet ends it. Any bold-led bullet counts, whatever follows the name.
    $railBullets = [ordered]@{}
    $railBulletLine = @{}
    $railOpen = $null
    $railFirstLine = ($railRulesText.Substring(0, $railSection.Index) -split "`n").Count
    $railSectionLines = $railSection.Value -split "`n"
    for ($i = 0; $i -lt $railSectionLines.Count; $i++) {
        $line = $railSectionLines[$i]
        $start = [regex]::Match($line, '^- \*\*(.+?)\*\*')
        if ($start.Success) {
            $railOpen = $start.Groups[1].Value
            if ($railBullets.Contains($railOpen)) { $railProblems += "'$railOpen': section 1 of $railRulesRel holds two bullets of that name" }
            $railBullets[$railOpen] = $line.TrimEnd()
            $railBulletLine[$railOpen] = $railFirstLine + $i
        } elseif ($null -ne $railOpen -and $line.Trim()) {
            $railBullets[$railOpen] = $railBullets[$railOpen] + "`n" + $line.TrimEnd()
        } else { $railOpen = $null }
    }
    foreach ($name in @($railBullets.Keys)) {
        if (-not $railPairs.Contains($name)) { $railProblems += "'$name': a workflow bullet in section 1 of $railRulesRel has no route-prompt rail paired in validate-dist's rail-sync map" }
    }
    foreach ($name in $railPairs.Keys) {
        $var = $railPairs[$name]
        if (-not $railBullets.Contains($name)) { $railProblems += "'$name': no canonical bullet in section 1 of $railRulesRel"; continue }
        $rails = [regex]::Matches($railRouteText, "(?ms)^\`$$var = @'\n(.*?)\n'@")
        if ($rails.Count -ne 1) { $railProblems += "'$name': found $($rails.Count) `$$var rail(s) in $railRouteRel; expected one"; continue }
        $firstBulletLine = ($railBullets[$name] -split "`n")[0]
        $bulletSource = Get-RailSourceLine $railCoreRules $firstBulletLine
        if (-not $bulletSource) { $bulletSource = Get-RailSourceLine $railStackBullets $firstBulletLine }
        if (-not $bulletSource) { $bulletSource = "$railCoreRules or $railStackBullets" }
        $railSource = Get-RailSourceLine $railCoreRoute "`$$var = @'"
        if (-not $railSource) { $railSource = $railCoreRoute }
        $railCurrent[$name] = [pscustomobject]@{
            Bullet = ([BitConverter]::ToString($railSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($railBullets[$name])))).Replace('-', '').ToLowerInvariant()
            Rail = ([BitConverter]::ToString($railSha.ComputeHash([Text.Encoding]::UTF8.GetBytes($rails[0].Groups[1].Value)))).Replace('-', '').ToLowerInvariant()
            BulletAt = "$railRulesRel`:$($railBulletLine[$name]) (authored at $bulletSource)"
            RailAt = "`$$var ($railSource, with any @stack snippet it expands from src/stacks/$Mode/snippets/.claude/hooks/route-prompt.ps1/)"
        }
    }
}
$railRecord = $null
$railRecordError = $null
if (Test-Path -LiteralPath $railSyncPath -PathType Leaf) {
    try { $railRecord = [IO.File]::ReadAllText($railSyncPath, [Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop }
    catch { $railRecordError = $_.Exception.Message }
    if (-not $railRecordError -and ($null -eq $railRecord -or -not ($railRecord.dists -is [pscustomobject]))) { $railRecordError = 'it holds no dists object' }
}
$railUpdateCommand = "scripts/validate-dist.ps1 $Mode -Check rail-sync --update-rail-sync"
if ($railBlind) {
    Cant-Examine "rail-sync could not examine $Dist -- $railBlind."
} elseif ($railProblems.Count -gt 0) {
    Fail "rail-sync could not pair every section-1 workflow bullet with its route-prompt rail -- $($railProblems.Count) finding(s)."
    $railProblems | ForEach-Object { Write-Output "  [rail-sync] $_" }
} elseif ($railRecordError) {
    Cant-Examine "rail-sync cannot examine meta/rail-sync.json -- $railRecordError. Repair it, or delete it and record every dist again with $railUpdateCommand."
} elseif ($UpdateRailSync) {
    $record = [ordered]@{}
    if ($null -ne $railRecord) {
        foreach ($entry in @($railRecord.dists.PSObject.Properties | Sort-Object Name)) { $record[$entry.Name] = $entry.Value }
    }
    $modePairs = [ordered]@{}
    foreach ($name in $railCurrent.Keys) { $modePairs[$name] = [pscustomobject]@{ bullet = $railCurrent[$name].Bullet; rail = $railCurrent[$name].Rail } }
    $record[$Mode] = [pscustomobject]$modePairs
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('{')
    $lines.Add('  "schema-version": 1,')
    $lines.Add('  "note": "SHA-256 of each canonical Agentic Workflow bullet and its route-prompt rail, as last reviewed together. Written by scripts/validate-dist.ps1 <dist> -Check rail-sync --update-rail-sync.",')
    $lines.Add('  "dists": {')
    $distNames = @($record.Keys | Sort-Object)
    for ($d = 0; $d -lt $distNames.Count; $d++) {
        $lines.Add("    `"$($distNames[$d])`": {")
        $pairNames = @($record[$distNames[$d]].PSObject.Properties.Name | Sort-Object)
        for ($p = 0; $p -lt $pairNames.Count; $p++) {
            $pair = $record[$distNames[$d]].($pairNames[$p])
            $comma = if ($p -lt $pairNames.Count - 1) { ',' } else { '' }
            $lines.Add("      `"$($pairNames[$p])`": { `"bullet`": `"$($pair.bullet)`", `"rail`": `"$($pair.rail)`" }$comma")
        }
        $lines.Add("    }$(if ($d -lt $distNames.Count - 1) { ',' } else { '' })")
    }
    $lines.Add('  }')
    $lines.Add('}')
    $railWritten = $false
    try { [IO.File]::WriteAllText($railSyncPath, (($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false))); $railWritten = $true }
    catch { Cant-Examine "rail-sync could not write meta/rail-sync.json -- $($_.Exception.Message)." }
    if ($railWritten) { OK "rail-sync recorded $($railCurrent.Count) reviewed bullet/rail pair(s) for $Mode in meta/rail-sync.json." }
} elseif ($null -eq $railRecord) {
    Fail "rail-sync has no record: meta/rail-sync.json is missing. Review each route-prompt rail against its bullet, then run $railUpdateCommand."
} else {
    $recorded = $railRecord.dists.$Mode
    $railDrift = @()
    foreach ($name in $railCurrent.Keys) {
        $was = if ($null -ne $recorded) { $recorded.$name } else { $null }
        $now = $railCurrent[$name]
        if ($null -eq $was) { $railDrift += "'$name': no reviewed record for $Mode; review the bullet at $($now.BulletAt) against its rail $($now.RailAt)"; continue }
        $bulletChanged = [string]$was.bullet -cne $now.Bullet
        $railChanged = [string]$was.rail -cne $now.Rail
        if ($bulletChanged -and $railChanged) { $railDrift += "'$name': both changed -- the bullet at $($now.BulletAt) and its rail $($now.RailAt)" }
        elseif ($bulletChanged) { $railDrift += "'$name': the bullet changed at $($now.BulletAt); review its rail $($now.RailAt)" }
        elseif ($railChanged) { $railDrift += "'$name': the rail changed, $($now.RailAt); review it against the bullet at $($now.BulletAt)" }
    }
    if ($railDrift.Count -gt 0) {
        Fail "a canonical workflow bullet or its route-prompt rail changed without the pair being reviewed -- $($railDrift.Count) finding(s). Review each pair, then run $railUpdateCommand."
        $railDrift | ForEach-Object { Write-Output "  [rail-sync] $_" }
    } else {
        OK "route-prompt rails match the reviewed canonical workflow bullets in $Dist (rail-sync; $($railCurrent.Count) pair(s))."
    }
}
}

if (Test-CheckSelected 'skill-frontmatter') {
# --- 15. shipped skill descriptions load on Copilot CLI -----------------------------------------
# DELIVERY CONSTRAINT observed on Copilot CLI 1.0.89 (`copilot skill list`): a SKILL.md whose
# description exceeds 1024 characters fails to load ("Skill description must be at most 1024
# characters"), the Agent Skills specification's limit. monorepo add-tests shipped at 1,078 in
# v0.77.0 to v0.91.0. Folded and literal blocks are joined the way YAML folds them.
# The .agents/skills workflow wrappers are scanned too. Copilot CLI 1.0.92 (`copilot skill list`)
# lists .agents/skills/<name> in place of a same-named .claude/commands/<name>.md, so a wrapper
# carries that command's frontmatter plus `name: <name>`, and every command has one: a drifted
# wrapper changes the description, argument hint and model invocation Copilot uses while Claude
# Code keeps the command's, and a missing one leaves VS Code without the command.
$skillFiles = @()
foreach ($skillsRelative in @('.claude/skills', '.agents/skills')) {
    $skillsRoot = Join-Path $DistAbs $skillsRelative
    if (Test-Path -LiteralPath $skillsRoot -PathType Container) {
        $skillFiles += @(Get-ChildItem -LiteralPath $skillsRoot -Directory -Force |
            ForEach-Object { Join-Path $_.FullName 'SKILL.md' } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    }
}
# A delimiter is '---' with only trailing whitespace: Copilot CLI 1.0.92 loads '---  ' but refuses
# ' ---' as malformed frontmatter, and an indented '---' inside a block scalar is content. Comparisons
# here are ordinal: -ceq ignores zero-width characters such as U+FEFF and U+200B, and Copilot refuses
# them in a delimiter or a name. It trims a trailing U+FEFF from a name; this check refuses that too.
function Test-OrdinalEqual([string]$Left, [string]$Right) { return [string]::Equals($Left, $Right, [StringComparison]::Ordinal) }
# Top-level keys, unquoted: a bare key, a quoted one, or an explicit '? key'. YAML keys are case-sensitive.
function Get-FrontmatterKeys([string[]]$Lines) {
    foreach ($line in $Lines) {
        $key = [regex]::Match($line, '^\?\s+(?:"([^"]*)"|''([^'']*)''|(\S.*?))(?:\s+#.*)?\s*$')
        if (-not $key.Success) { $key = [regex]::Match($line, '^(?:"([^"]*)"|''([^'']*)''|([^\s"''#?{\[-][^:]*?))\s*:(?:\s|$)') }
        if (-not $key.Success) { continue }
        foreach ($group in 1, 2, 3) { if ($key.Groups[$group].Success) { $key.Groups[$group].Value; break } }
    }
}
function Get-FrontmatterEnd([string[]]$Lines) {
    if ($Lines.Count -eq 0 -or -not (Test-OrdinalEqual $Lines[0].TrimEnd() '---')) { return -1 }
    for ($i = 1; $i -lt $Lines.Count; $i++) { if (Test-OrdinalEqual $Lines[$i].TrimEnd() '---') { return $i } }
    return -1
}
function Get-FrontmatterLines([string[]]$Lines) {
    $close = Get-FrontmatterEnd $Lines
    if ($close -lt 0) { return $null }
    return , @(if ($close -gt 1) { $Lines[1..($close - 1)] })
}
# B-359: Copilot CLI 1.0.92 refuses a frontmatter holding an unquoted argument-hint list ("must be a
# string"), a disable-model-invocation other than true or false, or an unquoted value holding ': ', and
# a wrapper copies its command's frontmatter, so /<name> then loads nowhere. Indented lines are block
# content and are not read here; a plain value's ' #' comment is dropped first, as YAML drops it.
function Get-FrontmatterValueProblems([string]$Relative, [string[]]$Lines) {
    foreach ($line in $Lines) {
        $pair = [regex]::Match($line, '^([^\s"''#?{\[-][^:]*?):(?:\s+(.*?))?\s*$')
        if (-not $pair.Success) { continue }
        $key = $pair.Groups[1].Value
        $value = $pair.Groups[2].Value
        $plain = $value -notmatch '^["''|>\[{]'
        $scalar = if ($plain) { [regex]::Replace($value, '\s+#.*$', '') } else { $value }
        if ($key -ceq 'argument-hint' -and $value -match '^[\[{]') {
            "$Relative : argument-hint is an unquoted YAML list or map, not a string"
        }
        if ($key -ceq 'disable-model-invocation' -and $scalar -cnotmatch '^(?:true|false)$') {
            "$Relative : disable-model-invocation is '$value', not true or false"
        }
        if ($plain -and $scalar -match ':(?:\s|$)') {
            "$Relative : $key has an unquoted value holding ': '"
        }
    }
}
$skillProblems = @()
$skillReadFails = @()
$wrapperProblems = @()
$valueProblems = @()
$valueScanCount = 0
$claudeSkillCount = 0
$wrapperCount = 0
$commandCount = 0
$longestDescription = 0
foreach ($skillPath in $skillFiles) {
    $relative = $skillPath.Substring($DistAbs.Length).TrimStart('\','/').Replace('\','/')
    $lines = $null
    try { $lines = @([IO.File]::ReadAllLines($skillPath, [Text.Encoding]::UTF8)) } catch { $skillReadFails += $relative; continue }
    if ($relative.StartsWith('.claude/skills/', [StringComparison]::Ordinal)) { $claudeSkillCount++ }
    $end = Get-FrontmatterEnd $lines
    if ($end -lt 0) { $skillProblems += "$relative : no terminated YAML frontmatter"; continue }
    $valueScanCount++
    $valueProblems += @(Get-FrontmatterValueProblems $relative @(if ($end -gt 1) { $lines[1..($end - 1)] }))
    $description = $null
    for ($i = 1; $i -lt $end; $i++) {
        $match = [regex]::Match($lines[$i], '^description:\s*(.*)$')
        if (-not $match.Success) { continue }
        $value = $match.Groups[1].Value.Trim()
        if ($value -eq '' -or $value -match '^[>|][+-]?$') {
            $block = New-Object System.Collections.Generic.List[string]
            for ($j = $i + 1; $j -lt $end -and ($lines[$j] -match '^\s+\S' -or $lines[$j].Trim() -eq ''); $j++) {
                if ($lines[$j].Trim() -ne '') { $block.Add($lines[$j].Trim()) }
            }
            $separator = if ($value.StartsWith('|')) { "`n" } else { ' ' }
            $description = $block -join $separator
        } elseif ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
            $description = $Matches[1]
        } else {
            $description = $value
        }
        break
    }
    if ($null -eq $description) { $skillProblems += "$relative : no description in its frontmatter"; continue }
    if ($description.Length -gt $longestDescription) { $longestDescription = $description.Length }
    if ($description.Length -gt 1024) {
        $skillProblems += "$relative : description is $($description.Length) characters"
    }
    if ($relative -notmatch '^\.agents/skills/([^/]+)/SKILL\.md$') { continue }
    $workflow = $Matches[1]
    $wrapperCount++
    # install.ps1 keeps or saves a team's file at a wrapper path only for these names; another would be overwritten.
    if ($workflow -cnotmatch '^[a-z0-9-]+$') {
        $wrapperProblems += "$relative : its folder name is not lowercase letters, digits and hyphens, so install.ps1 would overwrite a team's file there"
    }
    # Get-FrontmatterLines returns the line array as one object; @() around the call would nest it.
    $frontmatter = Get-FrontmatterLines $lines
    if ($null -eq $frontmatter) { $frontmatter = @() }
    if ($frontmatter.Count -eq 0 -or -not (Test-OrdinalEqual $frontmatter[0] "name: $workflow")) {
        $wrapperProblems += "$relative : its frontmatter does not open with 'name: $workflow'"
    }
    # The installer tells a framework wrapper from a team's skill at this path by this sentence.
    $body = ($lines[($end + 1)..($lines.Count - 1)] -join "`n")
    if ($end + 1 -ge $lines.Count -or -not $body.Contains('`.claude/commands/' + $workflow + '.md` is the single source of truth')) {
        $wrapperProblems += "$relative : its body does not name .claude/commands/$workflow.md as the single source of truth"
    }
    $commandPath = Join-Path $DistAbs ".claude/commands/$workflow.md"
    if (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) {
        $wrapperProblems += "$relative : runs .claude/commands/$workflow.md, which does not ship"
        continue
    }
    $commandRaw = $null
    try { $commandRaw = @([IO.File]::ReadAllLines($commandPath, [Text.Encoding]::UTF8)) } catch { $skillReadFails += ".claude/commands/$workflow.md"; continue }
    $commandFrontmatter = Get-FrontmatterLines $commandRaw
    $wrapperRest = @(if ($frontmatter.Count -gt 1) { $frontmatter[1..($frontmatter.Count - 1)] })
    # A repeated key is invalid YAML to Copilot ("duplicate entry with key"), however it is spelt; the
    # wrapper carries the command's keys after its name line, so a name key in the command repeats too.
    $seenKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $repeatedKeys = @(Get-FrontmatterKeys $frontmatter | Where-Object { -not $seenKeys.Add($_) } | Sort-Object -CaseSensitive -Unique)
    if ($repeatedKeys.Count -gt 0) {
        $wrapperProblems += "$relative : its frontmatter, the name line plus .claude/commands/$workflow.md's, repeats the key(s) $($repeatedKeys -join ', '), which Copilot refuses as a duplicate entry"
    }
    if ($null -eq $commandFrontmatter -or -not (Test-OrdinalEqual ($wrapperRest -join "`n") ($commandFrontmatter -join "`n"))) {
        $wrapperProblems += "$relative : frontmatter after its name line differs from .claude/commands/$workflow.md"
    }
}
$commandsRoot = Join-Path $DistAbs '.claude/commands'
if (Test-Path -LiteralPath $commandsRoot -PathType Container) {
    foreach ($command in @(Get-ChildItem -LiteralPath $commandsRoot -File -Filter '*.md' -Force)) {
        $commandCount++
        $workflow = [IO.Path]::GetFileNameWithoutExtension($command.Name)
        $commandRaw = $null
        try { $commandRaw = @([IO.File]::ReadAllLines($command.FullName, [Text.Encoding]::UTF8)) } catch { $skillReadFails += ".claude/commands/$($command.Name)"; continue }
        $commandLines = Get-FrontmatterLines $commandRaw
        if ($null -ne $commandLines) {
            $valueScanCount++
            $valueProblems += @(Get-FrontmatterValueProblems ".claude/commands/$($command.Name)" $commandLines)
        }
        if (-not (Test-Path -LiteralPath (Join-Path $DistAbs ".agents/skills/$workflow/SKILL.md") -PathType Leaf)) {
            $wrapperProblems += ".claude/commands/$($command.Name) : no .agents/skills/$workflow/SKILL.md wrapper, so VS Code has no /$workflow"
        }
    }
}
if ($skillReadFails.Count -gt 0) {
    Cant-Examine ("skill frontmatter scan could not read:" + (($skillReadFails | Sort-Object -Unique) -join ' '))
} elseif ($claudeSkillCount -eq 0) {
    Fail "skill frontmatter scan found no .claude/skills/*/SKILL.md in $Dist -- the scan is blind."
} elseif ($commandCount -eq 0) {
    Fail "workflow wrapper scan found no .claude/commands/*.md in $Dist -- the scan is blind."
} elseif ($skillProblems.Count -gt 0 -or $wrapperProblems.Count -gt 0 -or $valueProblems.Count -gt 0) {
    if ($skillProblems.Count -gt 0) {
        Fail "shipped skills Copilot CLI cannot load, or that have no description -- $($skillProblems.Count) finding(s). Copilot CLI 1.0.89 refuses to load a skill whose description exceeds 1024 characters, and 1.0.92 one whose frontmatter it cannot find; one with no description loads, described by its body."
        $skillProblems | Sort-Object -Unique | ForEach-Object { Write-Output "  [skill-frontmatter] $_" }
    }
    if ($wrapperProblems.Count -gt 0) {
        Fail "workflow skill wrappers drift from their commands -- $($wrapperProblems.Count) finding(s). Copilot CLI 1.0.92 lists .agents/skills/<name>/SKILL.md in place of .claude/commands/<name>.md, so each command needs a wrapper carrying its frontmatter plus its name."
        $wrapperProblems | Sort-Object -Unique | ForEach-Object { Write-Output "  [skill-frontmatter] $_" }
    }
    if ($valueProblems.Count -gt 0) {
        Fail "shipped frontmatter values Copilot CLI refuses -- $($valueProblems.Count) finding(s). Copilot CLI 1.0.92 refuses an unquoted argument-hint list (`"must be a string`"), a disable-model-invocation other than true or false, and an unquoted value holding ': '; quote the value, and a wrapper carries its command's."
        $valueProblems | Sort-Object -Unique | ForEach-Object { Write-Output "  [skill-frontmatter] $_" }
    }
} else {
    OK "every shipped skill description loads on Copilot CLI ($($skillFiles.Count) SKILL.md files; longest description $longestDescription of 1024 characters; $wrapperCount workflow wrapper(s) carry their command's frontmatter; $valueScanCount frontmatter(s) hold no value Copilot CLI refuses)."
}
}

if (Test-CheckSelected 'ownership') {
# --- 16. the ownership manifest and the retirement ledger match what ships -------------------------
# The installer is the only consumer of framework-ownership.json and framework-retirements.json and it
# refuses a dist whose manifest is missing, malformed, or names a file that is not shipped (exit 3).
# build.ps1 generates the manifest, but exits 1 after writing a partial dist, and nothing here read
# either file. This check applies the installer's own parse rules (src/core/scripts/install.ps1
# Read-OwnershipManifest, Read-RetirementLedger and the incoming-metadata block) to the dist, and the
# composer's own rules for which files are listed (build.ps1 step 3: every file except the install-
# excluded set, tests/hooks/** and presentation/**) and for the ledger (step 4: it equals
# meta/framework-retirements-baseline.json entry for entry). The excluded set is read from the dist's
# own scripts/install.ps1, the same declaration build.ps1 reads.
$ownProblems = @()
$ownUnreadable = @()
$ownManifestRel = 'framework-ownership.json'
$ownLedgerRel = 'framework-retirements.json'
$ownBaselineRel = 'meta/framework-retirements-baseline.json'
function Test-OwnershipPathShape([string]$Relative) {
    # Get-ContainedTargetPath's shape rules, without the target-root containment (implied by them).
    if ([string]::IsNullOrWhiteSpace($Relative) -or $Relative.Contains('\') -or $Relative.Contains([string][char]0) -or
        $Relative.StartsWith('/') -or $Relative -match '^[A-Za-z]:') { return $false }
    foreach ($segment in $Relative.Split('/')) {
        if ([string]::IsNullOrEmpty($segment) -or $segment -eq '.' -or $segment -eq '..') { return $false }
    }
    return $true
}
# One JSON metadata file: Doc is set when it parsed; a missing file is recorded as a problem, an
# unreadable one as could-not-examine, and unparseable JSON as a problem.
function Read-OwnershipDoc([string]$Path, [string]$Label, [bool]$Required) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        if ($Required) { $script:ownProblems += "$Label is missing from this dist; the installer refuses a dist without it (exit 3)" }
        return $null
    }
    $text = $null
    try { $text = [IO.File]::ReadAllText($Path) } catch { $script:ownUnreadable += $Label; return $null }
    try { return ($text | ConvertFrom-Json -ErrorAction Stop) }
    catch { $script:ownProblems += "$Label is not parseable JSON"; return $null }
}
$ownFiles = @()
$ownEnumError = $null
try { $ownFiles = @(Get-ChildItem -Recurse -File -Force -LiteralPath $DistAbs -ErrorAction Stop) }
catch { $ownEnumError = $_.Exception.Message }
$shipped = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($f in $ownFiles) { [void]$shipped.Add($f.FullName.Substring($DistAbs.Length).TrimStart('\', '/').Replace('\', '/')) }

# The install-excluded set, from the dist's own installer.
$ownExcluded = $null
$installerPath = Join-Path $DistAbs 'scripts/install.ps1'
if (-not (Test-Path -LiteralPath $installerPath -PathType Leaf)) {
    $ownProblems += 'scripts/install.ps1 is missing from this dist, so the set of files the installer excludes is unknown'
} else {
    $installerText = $null
    try { $installerText = [IO.File]::ReadAllText($installerPath) } catch { $ownUnreadable += 'scripts/install.ps1' }
    if ($null -ne $installerText) {
        $excludedMatch = [regex]::Match($installerText, '(?ms)^\$excludedFromInstall\s*=\s*@\((.*?)\)')
        if (-not $excludedMatch.Success) { $ownProblems += 'scripts/install.ps1 declares no $excludedFromInstall set' }
        else { $ownExcluded = @([regex]::Matches($excludedMatch.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value }) }
    }
}

# --- the manifest, with the installer's rules
$manifestPaths = $null
$manifestDoc = Read-OwnershipDoc (Join-Path $DistAbs $ownManifestRel) $ownManifestRel $true
if ($null -ne $manifestDoc) {
    $entries = @($manifestDoc.paths)
    if (-not ($manifestDoc.PSObject.Properties.Name -contains 'schema-version') -or [int]$manifestDoc.'schema-version' -ne 1 -or $null -eq $manifestDoc.paths) {
        $ownProblems += "$ownManifestRel has an unsupported or missing schema"
    } elseif ($entries.Count -eq 0) {
        $ownProblems += "$ownManifestRel contains no paths"
    } else {
        $manifestPaths = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        $seenInsensitive = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in $entries) {
            $relative = [string]$entry.path
            $ownership = [string]$entry.ownership
            if (-not (Test-OwnershipPathShape $relative)) { $ownProblems += "$ownManifestRel has an unsafe or non-normalized path '$relative'"; continue }
            if (-not $seenInsensitive.Add($relative)) { $ownProblems += "$ownManifestRel contains duplicate path '$relative'"; continue }
            if ($ownership -notin @('framework-owned/overwritten', 'consumer-owned/protected', 'mixed')) {
                $ownProblems += "$ownManifestRel has unsupported ownership '$ownership' for '$relative'"
            }
            [void]$manifestPaths.Add($relative)
        }
    }
}

# --- the ledger, with the installer's rules
$ledgerEntries = $null
$ledgerDoc = Read-OwnershipDoc (Join-Path $DistAbs $ownLedgerRel) $ownLedgerRel $true
if ($null -ne $ledgerDoc) {
    if (-not ($ledgerDoc.PSObject.Properties.Name -contains 'schema-version') -or [int]$ledgerDoc.'schema-version' -ne 1 -or $null -eq $ledgerDoc.retirements) {
        $ownProblems += "$ownLedgerRel has an unsupported or missing schema"
    } else {
        $ledgerEntries = @($ledgerDoc.retirements)
        $seenRetired = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in $ledgerEntries) {
            $relative = [string]$entry.path
            $version = [string]$entry.'retired-in'
            $hashes = @($entry.'known-content-sha256' | ForEach-Object { [string]$_ })
            if (-not (Test-OwnershipPathShape $relative)) { $ownProblems += "$ownLedgerRel has an unsafe or non-normalized path '$relative'"; $ledgerEntries = $null; continue }
            if (-not $seenRetired.Add($relative)) { $ownProblems += "$ownLedgerRel contains duplicate path '$relative'"; $ledgerEntries = $null }
            if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { $ownProblems += "$ownLedgerRel has invalid retired-in version '$version' for '$relative'"; $ledgerEntries = $null }
            if ($hashes.Count -eq 0 -or @($hashes | Where-Object { $_ -cnotmatch '^[0-9a-f]{64}$' }).Count -gt 0 -or @($hashes | Select-Object -Unique).Count -ne $hashes.Count) {
                $ownProblems += "$ownLedgerRel has invalid or duplicate known-content-sha256 values for '$relative'"; $ledgerEntries = $null
            }
        }
    }
}
if ($null -ne $ledgerEntries -and $null -ne $manifestPaths) {
    foreach ($entry in $ledgerEntries) {
        if ($manifestPaths.Contains([string]$entry.path)) { $ownProblems += "retirement '$([string]$entry.path)' is still present in the ownership manifest" }
    }
}

# --- the ledger against the maintainer baseline (build.ps1 step 4: same cumulative entries)
if ($null -ne $ledgerEntries) {
    $baselinePath = Join-Path $RepoRoot $ownBaselineRel
    $baselineDoc = $null
    if (-not (Test-Path -LiteralPath $baselinePath -PathType Leaf)) {
        $ownUnreadable += $ownBaselineRel
    } else {
        try { $baselineDoc = [IO.File]::ReadAllText($baselinePath) | ConvertFrom-Json -ErrorAction Stop }
        catch { $ownUnreadable += $ownBaselineRel }
    }
    if ($null -ne $baselineDoc) {
        if ($null -eq $baselineDoc.retirements -or [int]$baselineDoc.'schema-version' -ne 1) {
            $ownUnreadable += $ownBaselineRel
        } else {
            $baseline = @($baselineDoc.retirements)
            $difference = $null
            if ($ledgerEntries.Count -ne $baseline.Count) {
                $difference = "$($ledgerEntries.Count) entries in the dist, $($baseline.Count) in the baseline"
            } else {
                for ($i = 0; $i -lt $baseline.Count; $i++) {
                    $current = $ledgerEntries[$i]; $maintained = $baseline[$i]
                    $currentHashes = @($current.'known-content-sha256' | ForEach-Object { [string]$_ })
                    $maintainedHashes = @($maintained.'known-content-sha256' | ForEach-Object { [string]$_ })
                    if ([string]$current.path -cne [string]$maintained.path -or
                        [string]$current.'retired-in' -cne [string]$maintained.'retired-in' -or
                        $currentHashes.Count -ne $maintainedHashes.Count -or
                        ($maintainedHashes.Count -gt 0 -and (Compare-Object -ReferenceObject $maintainedHashes -DifferenceObject $currentHashes -CaseSensitive))) {
                        $difference = "entry $($i + 1) differs (dist '$([string]$current.path)' retired-in '$([string]$current.'retired-in')', baseline '$([string]$maintained.path)' retired-in '$([string]$maintained.'retired-in')')"
                        break
                    }
                }
            }
            if ($null -ne $difference) { $ownProblems += "$ownLedgerRel differs from $ownBaselineRel : $difference" }
        }
    }
}

# --- the manifest against the files
$installedCount = 0
if ($null -eq $ownEnumError -and $null -ne $manifestPaths -and $null -ne $ownExcluded) {
    foreach ($rel in $shipped) {
        $notInstalled = $ownExcluded -ccontains $rel -or $rel.StartsWith('tests/hooks/', [StringComparison]::Ordinal) -or $rel.StartsWith('presentation/', [StringComparison]::Ordinal)
        if ($notInstalled) {
            if ($manifestPaths.Contains($rel)) { $ownProblems += "$rel is listed in $ownManifestRel but the installer never installs it (install-excluded, tests/hooks/** or presentation/**)" }
            continue
        }
        $installedCount++
        if (-not $manifestPaths.Contains($rel)) { $ownProblems += "$rel ships but is not listed in $ownManifestRel; the installer would never copy it" }
    }
    foreach ($listed in $manifestPaths) {
        if (-not $shipped.Contains($listed)) { $ownProblems += "$listed is listed in $ownManifestRel but is not a shipped file; the installer refuses the dist (exit 3)" }
    }
}

if ($null -ne $ownEnumError) {
    Cant-Examine "ownership scan could not enumerate $Dist : $ownEnumError"
} elseif ($shipped.Count -eq 0) {
    Fail "ownership scan found zero files in $Dist."
} else {
    if ($ownProblems.Count -gt 0) {
        Fail ("ownership manifest or retirement ledger disagree with what ships in {0} -- {1} finding(s). The installer refuses such a dist or never copies the unlisted file." -f $Dist, $ownProblems.Count)
        $ownProblems | Sort-Object -Unique | ForEach-Object { Write-Output "  [ownership] $_" }
    }
    if ($ownUnreadable.Count -gt 0) {
        Cant-Examine ("ownership check could not read:" + (($ownUnreadable | Sort-Object -Unique) -join ' '))
    } elseif ($ownProblems.Count -eq 0) {
        OK "$ownManifestRel lists exactly the $installedCount installed files; $ownLedgerRel is valid, retires nothing that is installed and equals $ownBaselineRel ($($ledgerEntries.Count) entries)."
    }
}
}

Report-Timings
Write-Output ''
if ($failed -gt 0) { Write-Output "$failed dist validation check(s) FAILED for $Dist."; if ($cantExamine -gt 0) { Write-Output "$cantExamine more could not be examined (CANT-EXAMINE)." }; exit 1 }
if ($cantExamine -gt 0) { Write-Output "$cantExamine dist validation check(s) could not examine their input for $Dist -- no verdict; exit 2."; exit 2 }
Write-Output "All dist validation checks passed for $Dist."
exit 0
