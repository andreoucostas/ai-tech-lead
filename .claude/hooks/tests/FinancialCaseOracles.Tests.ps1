. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$source = Join-Path $PSScriptRoot 'fixtures/financial-cases/FinancialCases.cs'
try {
    Add-Type -Path $source -ErrorAction Stop
} catch {
    throw "C# oracle fixture could not compile: $($_.Exception.Message)"
}

Reset-Tests
It 'freezes two successful concurrent changes under sufficient starting state' {
    [int]$startingValue = 100
    [int]$change = 10
    [int]$operationCount = 2
    [int]$expected = $startingValue - ($change * $operationCount)

    Assert ([FinancialCases.Scenarios]::ApplyWithCompareExchange($startingValue, $change) -eq $expected) 'compare-exchange path violates the two-change invariant'
    Assert ([FinancialCases.Scenarios]::ApplyAfterBarrier($startingValue, $change) -ne $expected) 'barrier path did not reproduce the lost change'
}

It 'freezes an unrounded ratio-domain result within its declared tolerance' {
    [double[]]$terms = @(0.004d, 0.004d)
    [double]$expected = 0.008d
    [double]$tolerance = 0.000001d

    Assert ([Math]::Abs([FinancialCases.Scenarios]::SumAtEnd($terms) - $expected) -le $tolerance) 'end-rounded path exceeds the calculation-domain tolerance'
    Assert ([Math]::Abs([FinancialCases.Scenarios]::SumAtBoundary($terms) - $expected) -gt $tolerance) 'boundary-rounded path did not reproduce premature-rounding loss'
}

It 'freezes one effect per request identifier when delivery repeats' {
    [string[]]$requestIds = @('request-1', 'request-1')
    [int]$expectedEffects = 1

    Assert ([FinancialCases.Scenarios]::ProcessUniqueDeliveries($requestIds) -eq $expectedEffects) 'unique-delivery path duplicated the effect'
    Assert ([FinancialCases.Scenarios]::ProcessEveryDelivery($requestIds) -ne $expectedEffects) 'every-delivery path did not reproduce the duplicate effect'
}

It 'freezes a current-record predicate and its expected report total' {
    [FinancialCases.Record[]]$rows = @(
        [FinancialCases.Record]::new('A', $true, [decimal]100),
        [FinancialCases.Record]::new('A', $false, [decimal]50)
    )
    [decimal]$expectedCurrentTotal = 100

    Assert ([FinancialCases.Scenarios]::SelectCurrentRows($rows) -eq $expectedCurrentTotal) 'current-row selection violates its report oracle'
    Assert ([FinancialCases.Scenarios]::SelectAllRows($rows) -ne $expectedCurrentTotal) 'all-row selection did not reproduce the temporal defect'
}

It 'active financial carriers do not make type or mechanism names verdicts' {
    $repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $carriers = @(
        'src/stacks/dotnet/files/AGENTS.md',
        'src/stacks/monorepo/files/AGENTS.md',
        'src/stacks/dotnet/files/.claude/agents/security-auditor.md',
        'src/stacks/monorepo/files/.claude/agents/security-auditor.md',
        'src/stacks/dotnet/files/.claude/agents/test-critic.md',
        'src/stacks/monorepo/files/.claude/agents/test-critic.md',
        'src/stacks/dotnet/files/.claude/commands/bootstrap.md',
        'src/stacks/monorepo/files/.claude/commands/bootstrap.md',
        'src/stacks/dotnet/files/.claude/commands/rebootstrap.md',
        'src/stacks/monorepo/files/.claude/commands/rebootstrap.md',
        'src/stacks/dotnet/files/.claude/skills/add-tests/SKILL.md',
        'src/stacks/monorepo/files/.claude/skills/add-tests/SKILL.md',
        'src/stacks/dotnet/files/.claude/skills/map-warehouse/SKILL.md',
        'src/stacks/dotnet/snippets/.github/instructions/framework-rules.instructions.md/lean-4-8',
        'src/stacks/monorepo/snippets/.github/instructions/framework-rules.instructions.md/lean-4-8',
        'src/stacks/dotnet/snippets/.claude/hooks/route-prompt.ps1/sec-items',
        'src/stacks/monorepo/snippets/.claude/hooks/route-prompt.ps1/sec-items',
        'src/stacks/dotnet/snippets/.claude/hooks/route-prompt.sh/sec-items',
        'src/stacks/monorepo/snippets/.claude/hooks/route-prompt.sh/sec-items',
        'src/stacks/dotnet/files/tests/evals/cases.yaml',
        'src/stacks/monorepo/files/tests/evals/cases.yaml'
    )
    foreach ($path in $carriers) {
        $text = [IO.File]::ReadAllText((Join-Path $repo $path), [Text.Encoding]::UTF8)
        Assert ($text -match '(?i)(applicable|evidence|invariant|oracle|policy|precondition|reproduc|tolerance)') "$path omits the evidence-based decision boundary"
        Assert ($text -notmatch 'Use `decimal` \(never `double`\)|use decimal \(never double\)|flag as Critical|strict decimal/idempotency rules|their absence is a finding|These are the highest-value tests') "$path restores a categorical financial verdict"
    }
}

exit (Write-TestSummary 'FinancialCaseOracles.Tests')
