# Planted-defect tests for release.ps1's gate-waiver decision and its runtime budget. Does NOT ship.
#
# Why this file exists: -AllowFailingGate is a mechanism whose entire job is to SUPPRESS a failure.
# Every other gate here fails closed; this one is asked to fail open on request. If it is wrong in
# the permissive direction it does not announce itself -- the release simply goes out claiming more
# than it proved. So it gets red-tests before it gets trust.
#
# It lifts Resolve-GateWaiverOutcome out of release.ps1 by AST rather than by copying it or by
# slicing on comment markers: a copy would drift silently, and a marker slice breaks the moment
# someone renames a comment. If the function is renamed or removed, extraction fails loudly here.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
Reset-Tests
$hostProcess = Get-Process -Id $PID -ErrorAction Stop
Write-Host ("HOST executable={0}; version={1}" -f $hostProcess.Path, $PSVersionTable.PSVersion)
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$release  = Join-Path $repoRoot '.claude/scripts/release.ps1'

# Extraction runs at SCRIPT scope, not inside an It block: dot-sourcing inside a scriptblock defines
# the function in that block's child scope, where every later case would find it missing.
$extractError = $null
$parseErrors = $null
$releaseAst = if (Test-Path -LiteralPath $release) {
    [System.Management.Automation.Language.Parser]::ParseFile($release, [ref]$null, [ref]$parseErrors)
} else { $null }
if ($null -eq $releaseAst) {
    $extractError = "release.ps1 not found at $release"
} elseif ($parseErrors.Count -gt 0) {
    $extractError = "release.ps1 does not parse: $($parseErrors | Select-Object -First 1)"
} else {
    $waiverFn = $releaseAst.FindAll({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Resolve-GateWaiverOutcome'
    }, $true) | Select-Object -First 1
    if ($null -eq $waiverFn) {
        $extractError = 'release.ps1 no longer defines Resolve-GateWaiverOutcome -- it was renamed or inlined, and these tests now verify nothing'
    } else {
        . ([scriptblock]::Create($waiverFn.Extent.Text))
    }
}

It 'the waiver decision function can be lifted out of release.ps1' {
    Assert ($null -eq $extractError) "$extractError"
    Assert ($null -ne (Get-Command Resolve-GateWaiverOutcome -ErrorAction SilentlyContinue)) 'extracted function did not define'
}

# Everything below drives the REAL function, extracted above.

It 'a clean suite with no waivers blocks nothing' {
    $r = Resolve-GateWaiverOutcome -FileResults @{ 'A.Tests.ps1' = 0; 'B.Tests.ps1' = 0 } -Waivers @{}
    Assert ($r.BlockingFailures -eq 0) "expected 0 blocking, got $($r.BlockingFailures)"
    Assert (-not $r.Refused) 'clean run must not be refused'
    Assert ($r.Waived.Count -eq 0) 'clean run must record no waivers'
}

It 'an UNWAIVED failure still blocks -- the mechanism must not fail open by default' {
    $r = Resolve-GateWaiverOutcome -FileResults @{ 'A.Tests.ps1' = 0; 'B.Tests.ps1' = 5 } -Waivers @{}
    Assert ($r.BlockingFailures -eq 5) "an unwaived failure must block; got $($r.BlockingFailures)"
    Assert ($r.Waived.Count -eq 0) 'nothing was waived'
}

It 'a waived failure stops blocking, is recorded, and is announced' {
    $r = Resolve-GateWaiverOutcome -FileResults @{ 'A.Tests.ps1' = 0; 'B.Tests.ps1' = 5 } -Waivers @{ 'B.Tests.ps1' = 'B-113' }
    Assert ($r.BlockingFailures -eq 0) "waived failure must not block; got $($r.BlockingFailures)"
    Assert (-not $r.Refused) 'a valid waiver must not be refused'
    Assert ($r.Waived.Count -eq 1) "expected 1 recorded waiver, got $($r.Waived.Count)"
    Assert ($r.Waived[0] -match 'B-113') "the recorded waiver must name its owning item: $($r.Waived[0])"
    Assert ($r.GateLabel -match 'excluding recorded waivers') "the gate label must stop claiming an unqualified pass: $($r.GateLabel)"
    Assert (($r.Messages -join "`n") -match 'GATE WAIVED') 'a waiver must be announced, not silent'
}

It 'a waiver covers ONLY the file it names -- it is not a blanket' {
    $r = Resolve-GateWaiverOutcome -FileResults @{ 'B.Tests.ps1' = 5; 'C.Tests.ps1' = 2 } -Waivers @{ 'B.Tests.ps1' = 'B-113' }
    Assert ($r.BlockingFailures -eq 2) "C's failures must still block; got $($r.BlockingFailures)"
}

It 'a waiver naming a file that PASSED is refused as stale' {
    $r = Resolve-GateWaiverOutcome -FileResults @{ 'A.Tests.ps1' = 0 } -Waivers @{ 'A.Tests.ps1' = 'B-113' }
    Assert ($r.Refused) 'a stale waiver must be refused, or it silently covers the next breakage'
    Assert ((($r.Messages -join "`n")) -match 'PASSED') 'the refusal must say why'
}

It 'a waiver naming a file that did not run is refused' {
    $r = Resolve-GateWaiverOutcome -FileResults @{ 'A.Tests.ps1' = 0 } -Waivers @{ 'Typo.Tests.ps1' = 'B-113' }
    Assert ($r.Refused) 'a waiver for a file that never ran must be refused, not ignored'
    Assert ((($r.Messages -join "`n")) -match 'did not run') 'the refusal must say why'
}

It 'with NO per-file results, a waiver is refused rather than applied to the total' {
    $r = Resolve-GateWaiverOutcome -FileResults @{} -Waivers @{ 'B.Tests.ps1' = 'B-113' } -TotalExit 5
    Assert ($r.Refused) 'waiving an unattributable total is waiving everything'
    Assert ($r.BlockingFailures -eq 5) "the total must still block; got $($r.BlockingFailures)"
}

It 'with NO per-file results and no waivers, the summed total still gates' {
    $r = Resolve-GateWaiverOutcome -FileResults @{} -Waivers @{} -TotalExit 3
    Assert ($r.BlockingFailures -eq 3) "expected the total to gate; got $($r.BlockingFailures)"
    Assert (-not $r.Refused) 'no waiver, nothing to refuse'
}

# Extract the actual budget function, its top-level caller statement, and the actual refusal branch.
# The caller is selected as a top-level AST statement containing the command, not as a copied line;
# wrapping it in a false conditional or deleting it therefore changes the executable fixture.
$budgetExtractError = $null
$gateFn = $null
$budgetFn = $null
$budgetCallStatement = $null
$refusalStatement = $null
if ($null -eq $releaseAst) {
    $budgetExtractError = $extractError
} else {
    $gateFn = $releaseAst.FindAll({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Gate'
    }, $true) | Select-Object -First 1
    $budgetFn = $releaseAst.FindAll({ param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Assert-GateBudget'
    }, $true) | Select-Object -First 1
    $budgetCallStatements = @($releaseAst.EndBlock.Statements | Where-Object {
        @($_.FindAll({ param($n)
            $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Assert-GateBudget'
        }, $true)).Count -gt 0
    })
    if ($budgetCallStatements.Count -eq 1) { $budgetCallStatement = $budgetCallStatements[0] }
    $refusalStatements = @($releaseAst.EndBlock.Statements | Where-Object {
        $_.Extent.StartOffset -gt $(if ($budgetCallStatement) { $budgetCallStatement.Extent.EndOffset } else { [int]::MaxValue }) -and
        $_.Extent.Text -match '(?s)\$fatal.*?exit\s+1'
    })
    if ($refusalStatements.Count -eq 1) { $refusalStatement = $refusalStatements[0] }
    if ($null -eq $gateFn -or $null -eq $budgetFn -or $null -eq $budgetCallStatement -or $null -eq $refusalStatement) {
        $budgetExtractError = 'release.ps1 AST did not expose exactly one Gate, Assert-GateBudget caller, and downstream fatal refusal statement'
    }
}

function New-BudgetBoundaryScript {
    param([switch]$OverBudget)
    Assert ($null -eq $budgetExtractError) "$budgetExtractError"
    $seconds = if ($OverBudget) { '2.0' } else { '0.5' }
    $lines = @(
        '$ErrorActionPreference = ''Stop''',
        '$gateBudget = [pscustomobject]@{ ''ceilings-seconds'' = [pscustomobject]@{ probe = 1.0; ''total-local-gates'' = 1.0 } }',
        ('$stageTimings = [ordered]@{ probe = ' + $seconds + ' }'),
        '$script:fatal = $false',
        $gateFn.Extent.Text,
        $budgetFn.Extent.Text,
        $budgetCallStatement.Extent.Text,
        $refusalStatement.Extent.Text,
        "Write-Output 'BUDGET_BOUNDARY downstream-reached'",
        'exit 0'
    )
    return ($lines -join "`n")
}

function Invoke-BudgetBoundary {
    param([switch]$OverBudget)
    $path = Join-Path ([IO.Path]::GetTempPath()) ('release-budget-boundary-' + [guid]::NewGuid().ToString('N') + '.ps1')
    try {
        [IO.File]::WriteAllText($path, (New-BudgetBoundaryScript -OverBudget:$OverBudget), (New-Object Text.UTF8Encoding($true)))
        return Invoke-RawProcess -FileName (Get-PsExe) -Arguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',$path)
    } finally { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
}

It 'the actual release budget caller allows clean work and refuses over-budget work downstream' {
    $clean = Invoke-BudgetBoundary
    Assert ($clean.Exit -eq 0) "within-budget source boundary did not allow: EXIT=$($clean.Exit); OUT=$($clean.Out); ERR=$($clean.Err)"
    Assert ($clean.Out -match 'BUDGET_BOUNDARY downstream-reached') 'within-budget boundary did not reach downstream continuation'

    $over = Invoke-BudgetBoundary -OverBudget
    Assert ($over.Exit -eq 1) "over-budget source boundary did not refuse: EXIT=$($over.Exit); OUT=$($over.Out); ERR=$($over.Err)"
    Assert ($over.Out -match 'Release REFUSED: fix the failing gate') 'over-budget boundary did not execute the release refusal branch'
    Assert ($over.Out -notmatch 'BUDGET_BOUNDARY downstream-reached') 'over-budget boundary reached downstream success continuation'
}

# --- the runtime budget -------------------------------------------------------------------------

It 'the gate budget file exists, parses, and declares a ceiling for every stage release.ps1 times' {
    $budgetPath = Join-Path $repoRoot 'meta/gate-budget.json'
    Assert (Test-Path -LiteralPath $budgetPath) 'meta/gate-budget.json is missing -- the runtime ceiling cannot be enforced'
    $budget = Get-Content -Raw -LiteralPath $budgetPath | ConvertFrom-Json
    Assert ($null -ne $budget.'ceilings-seconds') 'gate-budget.json has no ceilings-seconds block'
    # Every stage release.ps1 actually measures must have a ceiling, or the budget silently covers
    # less than it appears to. Names are read out of release.ps1 itself, not restated here.
    $text = Get-Content -Raw -LiteralPath $release
    $staged = [regex]::Matches($text, "Measure-Stage\s+'([^']+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    Assert ($staged.Count -ge 3) "expected release.ps1 to time several stages, found $($staged.Count)"
    foreach ($name in $staged) {
        Assert ($null -ne $budget.'ceilings-seconds'.$name) "release.ps1 times stage '$name' but gate-budget.json declares no ceiling for it"
    }
    Assert ($null -ne $budget.'ceilings-seconds'.'total-local-gates') 'no total-local-gates ceiling'
}

It 'release.ps1 exposes the same budget function used by the executable boundary' {
    Assert ($null -eq $budgetExtractError) "$budgetExtractError"
    Assert ($budgetFn.Name -ceq 'Assert-GateBudget') 'budget function extraction did not select the actual source function'
    Assert ($budgetCallStatement.Extent.Text.Trim() -match '^Assert-GateBudget\s*$') 'budget caller is no longer the expected direct source statement'
}

exit (Write-TestSummary 'ReleaseGateWaiver.Tests (gate waiver + runtime budget)')
