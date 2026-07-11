# WSD-015 sibling-drift gate (.ps1 twin; bash twin: check-sibling-drift.sh). See that file's
# header for the full mechanism, usage, and exit-code documentation (kept in one place to avoid
# drift between the two comment blocks) -- restated here only where PS-specific behavior differs.
#
# Usage: check-sibling-drift.ps1 [BaseRef]   (default: HEAD~1)
#
# 5.1-safe: no ternary/??/&&/||; every branch is an explicit if/else. $ErrorActionPreference is
# NEVER set to 'Stop' around the native git calls below (a nonzero git exit under EAP=Stop throws
# instead of returning, and native stderr can be treated as a terminating error) -- each git
# invocation checks $LASTEXITCODE explicitly instead.
param(
    [Parameter(Position = 0)]
    [string]$BaseRef = 'HEAD~1'
)

# Anchor to the repo this script lives in (scripts/..), not the caller's cwd -- so it works when
# copied into <some-other-repo>/scripts/, same idiom as build.ps1.
Set-Location (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))

function Invoke-Git {
    param([string[]]$GitArgs)
    $out = & git @GitArgs 2>$null
    $code = $LASTEXITCODE
    return @{ Code = $code; Out = $out }
}

$verify = Invoke-Git @('rev-parse', '--verify', '--quiet', "$BaseRef^{commit}")
if ($verify.Code -ne 0 -or -not $verify.Out) {
    Write-Output "NOTICE: sibling-drift check skipped (base '$BaseRef' unresolvable)"
    exit 0
}
$baseSha = $verify.Out
if ($baseSha -is [System.Array]) { $baseSha = $baseSha[0] }

$mb = Invoke-Git @('merge-base', $baseSha, 'HEAD')
if ($mb.Code -eq 0 -and $mb.Out) {
    $rangeStart = $mb.Out
    if ($rangeStart -is [System.Array]) { $rangeStart = $rangeStart[0] }
} else {
    $rangeStart = $baseSha
}

$diffResult = Invoke-Git @('diff', '--name-only', $rangeStart, 'HEAD')
$touched = New-Object System.Collections.Generic.List[string]
if ($diffResult.Code -eq 0 -and $diffResult.Out) {
    foreach ($line in $diffResult.Out) {
        if ($line) { $touched.Add($line) }
    }
}

$logResult = Invoke-Git @('log', "$rangeStart..HEAD", '--format=%B')
$trailers = New-Object System.Collections.Generic.List[string]
if ($logResult.Code -eq 0 -and $logResult.Out) {
    foreach ($line in $logResult.Out) {
        if ($line -match '^Sibling-Reviewed:\s*(.+)$') {
            $trailers.Add($Matches[1])
        }
    }
}

$touchedSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($t in $touched) { [void]$touchedSet.Add($t) }

$pattern = '^src/stacks/(dotnet|angular)/(snippets|files)/(.+)$'
$failLines = New-Object System.Collections.Generic.List[string]
$touchedCount = 0

foreach ($rel in $touched) {
    if ($rel -match $pattern) {
        $touchedCount++
        $kind = $Matches[2]
        $rest = $Matches[3]
        $sibling = "src/stacks/monorepo/$kind/$rest"

        if (Test-Path -LiteralPath $sibling -PathType Leaf) {
            if (-not $touchedSet.Contains($sibling)) {
                $suppressed = $false
                foreach ($trailer in $trailers) {
                    if ($trailer -eq '*') { $suppressed = $true }
                    elseif ($rel.Contains($trailer)) { $suppressed = $true }
                    elseif ($sibling.Contains($trailer)) { $suppressed = $true }
                    if ($suppressed) { break }
                }
                if (-not $suppressed) {
                    # ASCII-only runtime output, matching the .sh twin byte-for-byte (the meta
                    # suite asserts it; a console-codepage decode must not be able to skew it).
                    $failLines.Add("FAIL: $rel changed but its monorepo sibling $sibling was not touched in the same range (WSD-015 -- update the sibling or add a 'Sibling-Reviewed: <path-or-*>' commit trailer)")
                }
            }
        }
    }
}

if ($failLines.Count -gt 0) {
    foreach ($l in $failLines) { Write-Output $l }
    exit 1
}

if ($touchedCount -eq 0) {
    Write-Output 'OK: no src/stacks/{dotnet,angular} paths touched.'
} else {
    Write-Output "OK: no monorepo-sibling drift in $touchedCount touched src/stacks path(s)."
}
exit 0
