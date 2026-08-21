# AI Tech Lead Framework — root installer wrapper.
# Usage: pwsh install.ps1 [-Stack dotnet|angular|monorepo] [-GitHooks] C:\path\to\target-repo
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
    [Parameter()][switch]$GitHooks,
    [Parameter(Position = 0)][string]$Target
)
$ErrorActionPreference = 'Stop'

$usage = 'Usage: pwsh install.ps1 [-Stack dotnet|angular|monorepo] [-GitHooks] C:\path\to\target-repo'
# Exit 2 with an actionable message on stderr. Write-Error is avoided on purpose: under
# ErrorActionPreference=Stop it throws before the following exit runs, which -File maps to
# exit code 1 — this keeps every wrapper-level failure at the documented exit 2.
function Die([string]$msg) { [Console]::Error.WriteLine($msg); exit 2 }

$selfDir = $PSScriptRoot
function Test-WarehouseRepo([string]$Path) {
    $signals = Join-Path $selfDir 'dist/dotnet/scripts/warehouse-signals.tsv'; if (-not (Test-Path -LiteralPath $signals)) { return $false }
    $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '[\\/](\.git|node_modules|bin|obj|dist)[\\/]' -and ($_.Extension -in @('.sql','.sqlproj') -or $_.Name -eq 'dbt_project.yml' -or ($_.Extension -in @('.yml','.yaml','.json') -and $_.FullName -match '(?i)[\\/](etl|pipelines?|warehouse|datafactory|synapse|dags?)[\\/]|(pipeline|datafactory|synapse|dag)[^\\/]*\.(yml|yaml|json)$')) })
    $hits=0
    foreach($line in Get-Content -LiteralPath $signals){if($line.StartsWith('#')-or[string]::IsNullOrWhiteSpace($line)){continue};$parts=$line-split"`t",2;foreach($file in $files){if($file.Name-match$parts[1]-or(Select-String -LiteralPath $file.FullName -Pattern $parts[1] -Quiet)){$hits++;break}}}
    return $hits -ge 2
}

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
        elseif (Test-WarehouseRepo $tgt) { $Stack='dotnet'; $reason='warehouse SQL fallback (at least two independent signals)' }
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
& $delegate -Target $tgt -GitHooks:$GitHooks
exit $LASTEXITCODE
