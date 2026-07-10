# AI Tech Lead Framework — root installer wrapper.
# Usage: pwsh install.ps1 [-Stack dotnet|angular|monorepo] C:\path\to\target-repo
#
# Thin dispatcher only: it selects a stack, then delegates to
# dist/<stack>/scripts/install.ps1, which does all the real work (greenfield / brownfield /
# update detection, the copy, the pwsh->5.1 settings fallback, ...). This wrapper adds NO
# install logic of its own — stack selection and delegation, nothing more.
#
# Stack resolution (first match wins):
#   1. -Stack flag        explicit; always wins.
#   2. update stamp       target/.claude/framework-version.json exists -> use its "template".
#   3. auto-detect        *.csproj or *.sln -> dotnet ; angular.json -> angular ;
#                         both -> monorepo (mixed repo: both stacks' rails install together).
#                         Searched in the target root plus two directory levels below it.
#   4. nothing detected   error: pass -Stack.
# Every error exits 2 with an actionable message on stderr. -Stack / -Target are validated by
# hand (not via ValidateSet / Mandatory) so bad input also exits 2 — and the twin, not an
# interactive prompt — matching install.sh.
param(
    [Parameter()][string]$Stack,
    [Parameter(Position = 0)][string]$Target
)
$ErrorActionPreference = 'Stop'

$usage = 'Usage: pwsh install.ps1 [-Stack dotnet|angular|monorepo] C:\path\to\target-repo'
# Exit 2 with an actionable message on stderr. Write-Error is avoided on purpose: under
# ErrorActionPreference=Stop it throws before the following exit runs, which -File maps to
# exit code 1 — this keeps every wrapper-level failure at the documented exit 2.
function Die([string]$msg) { [Console]::Error.WriteLine($msg); exit 2 }

$selfDir = $PSScriptRoot

if (-not $Target) { Die $usage }
if (-not (Test-Path -LiteralPath $Target -PathType Container)) { Die "Target '$Target' is not a directory." }
$tgt = (Resolve-Path -LiteralPath $Target).Path

$reason = ''
if ($Stack) {
    if ($Stack -ne 'dotnet' -and $Stack -ne 'angular' -and $Stack -ne 'monorepo') { Die "Unknown stack '$Stack' (expected: dotnet, angular, or monorepo)." }
    $reason = '-Stack flag'
}
else {
    $vf = Join-Path $tgt '.claude/framework-version.json'
    if (Test-Path -LiteralPath $vf -PathType Leaf) {
        # Existing install: honour the stack it was installed with (update mode). The stamp's
        # "template" value already matches the dist mode names (dotnet / angular / monorepo).
        try { $tmpl = (Get-Content -Raw -LiteralPath $vf | ConvertFrom-Json).template } catch { $tmpl = $null }
        if (-not $tmpl) { Die "Existing install at '$tgt', but .claude/framework-version.json has no readable ""template"" value — pass -Stack dotnet|angular|monorepo." }
        if ($tmpl -ne 'dotnet' -and $tmpl -ne 'angular' -and $tmpl -ne 'monorepo') { Die "Existing install names an unknown stack ""$tmpl"" in .claude/framework-version.json — pass -Stack dotnet|angular|monorepo." }
        $Stack = $tmpl
        $reason = "update stamp (.claude/framework-version.json template=$tmpl)"
    }
    else {
        # Auto-detect from build markers in the target root + two levels below (-Depth 2 walks
        # the root plus two subdirectory levels).
        $hasDotnet = [bool](Get-ChildItem -LiteralPath $tgt -Recurse -Depth 2 -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -eq '.csproj' -or $_.Extension -eq '.sln' } | Select-Object -First 1)
        $hasAngular = [bool](Get-ChildItem -LiteralPath $tgt -Recurse -Depth 2 -File -Filter 'angular.json' -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($hasDotnet -and $hasAngular) {
            $Stack = 'monorepo'; $reason = 'auto-detected (found both *.csproj/*.sln and angular.json — mixed repo)'
        }
        elseif ($hasDotnet) { $Stack = 'dotnet'; $reason = 'auto-detected (found *.csproj/*.sln)' }
        elseif ($hasAngular) { $Stack = 'angular'; $reason = 'auto-detected (found angular.json)' }
        else {
            Die ("Could not determine the stack for '$tgt': no *.csproj/*.sln and no angular.json in the target root or two levels below.`n" +
                'Pass it explicitly: -Stack dotnet|angular|monorepo.')
        }
    }
}

$delegate = Join-Path $selfDir "dist/$Stack/scripts/install.ps1"
if (-not (Test-Path -LiteralPath $delegate -PathType Leaf)) { Die "Internal error: expected installer not found at $delegate" }

Write-Output "Stack: $Stack (via $reason)"
Write-Output "Delegating to dist/$Stack/scripts/install.ps1 ..."
Write-Output ""
& $delegate $tgt
exit $LASTEXITCODE
