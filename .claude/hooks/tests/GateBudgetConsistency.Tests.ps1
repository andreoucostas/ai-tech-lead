# Gate for meta/gate-budget.json's internal consistency. Does NOT ship.
# Policy: total-local-gates must be at least the sum of all four per-stage ceilings, with zero
# margin required. Every ceilings-seconds value must also be present, numeric, and positive.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
Reset-Tests

$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$realBudget = Join-Path $repoRoot 'meta/gate-budget.json'
$requiredCeilings = @('compose', 'dist-gates', 'meta-suite', 'eval-selftest', 'total-local-gates')
$stageCeilings = @('compose', 'dist-gates', 'meta-suite', 'eval-selftest')
$tmp = Join-Path ([IO.Path]::GetTempPath()) ('gate-budget-consistency-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

function Test-GateBudgetConsistency {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $budget = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    } catch {
        return [pscustomobject]@{ Ok = $false; Message = "MALFORMED: could not read JSON: $($_.Exception.Message)" }
    }
    $ceilings = $budget.'ceilings-seconds'
    if ($null -eq $ceilings) {
        return [pscustomobject]@{ Ok = $false; Message = 'MALFORMED: ceilings-seconds block is missing' }
    }
    foreach ($name in $requiredCeilings) {
        $property = $ceilings.PSObject.Properties[$name]
        if ($null -eq $property) {
            return [pscustomobject]@{ Ok = $false; Message = "MALFORMED: required ceilings-seconds key '$name' is missing" }
        }
        $value = $property.Value
        $numeric = $value -is [byte] -or $value -is [sbyte] -or
                   $value -is [int16] -or $value -is [uint16] -or
                   $value -is [int32] -or $value -is [uint32] -or
                   $value -is [int64] -or $value -is [uint64] -or
                   $value -is [single] -or $value -is [double] -or $value -is [decimal]
        if (-not $numeric -or $value -le 0) {
            return [pscustomobject]@{ Ok = $false; Message = "MALFORMED: ceilings-seconds '$name' must be a positive number; got '$value'" }
        }
    }
    $sum = 0.0
    foreach ($name in $stageCeilings) { $sum += [double]$ceilings.$name }
    $aggregate = [double]$ceilings.'total-local-gates'
    if ($aggregate -lt $sum) {
        $parts = $stageCeilings | ForEach-Object { "$_=$($ceilings.$_)" }
        return [pscustomobject]@{
            Ok = $false
            Message = "SUM MISMATCH: $($parts -join ', '); sum=$sum exceeds total-local-gates=$aggregate"
        }
    }
    return [pscustomobject]@{ Ok = $true; Message = "consistent: stage sum=$sum, total-local-gates=$aggregate" }
}

function New-BudgetFixture {
    param([string]$Name, [scriptblock]$Mutate)
    $budget = Get-Content -Raw -LiteralPath $realBudget | ConvertFrom-Json
    if ($Mutate) { & $Mutate $budget }
    $path = Join-Path $tmp $Name
    $budget | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding utf8
    return $path
}

try {
    It 'rejects the 2026-08-08 drift class and names the disagreeing values' {
        $path = New-BudgetFixture 'drift.json' { param($b) $b.'ceilings-seconds'.'meta-suite' += 1 }
        $result = Test-GateBudgetConsistency $path
        Assert (-not $result.Ok) 'an increased stage ceiling without a recomputed aggregate must fail'
        Assert ($result.Message -match 'sum=.*total-local-gates=') "sum mismatch did not name both values: $($result.Message)"
    }

    It 'accepts a fixture whose aggregate was correctly recomputed' {
        $path = New-BudgetFixture 'recomputed.json' {
            param($b)
            $b.'ceilings-seconds'.'meta-suite' += 1
            $b.'ceilings-seconds'.'total-local-gates' += 1
        }
        $result = Test-GateBudgetConsistency $path
        Assert $result.Ok $result.Message
    }

    It 'rejects a missing ceiling as malformed, not as a sum mismatch' {
        $path = New-BudgetFixture 'missing.json' { param($b) $b.'ceilings-seconds'.PSObject.Properties.Remove('compose') }
        $result = Test-GateBudgetConsistency $path
        Assert (-not $result.Ok) 'a missing required ceiling must fail'
        Assert ($result.Message -match '^MALFORMED.*compose.*missing') "missing-key failure was unclear: $($result.Message)"
        Assert ($result.Message -notmatch '^SUM MISMATCH') "missing key was conflated with a sum mismatch: $($result.Message)"
    }

    It 'rejects a non-numeric ceiling as malformed, not as a sum mismatch' {
        $path = New-BudgetFixture 'non-numeric.json' { param($b) $b.'ceilings-seconds'.'dist-gates' = 'many' }
        $result = Test-GateBudgetConsistency $path
        Assert (-not $result.Ok) 'a non-numeric required ceiling must fail'
        Assert ($result.Message -match '^MALFORMED.*dist-gates.*positive number') "non-numeric failure was unclear: $($result.Message)"
        Assert ($result.Message -notmatch '^SUM MISMATCH') "non-numeric value was conflated with a sum mismatch: $($result.Message)"
    }

    It 'accepts the real current meta/gate-budget.json' {
        $result = Test-GateBudgetConsistency $realBudget
        Assert $result.Ok $result.Message
    }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'GateBudgetConsistency.Tests (budget structure + aggregate policy)')
