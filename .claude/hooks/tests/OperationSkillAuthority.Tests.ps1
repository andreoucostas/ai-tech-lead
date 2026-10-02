# Maintainer-only source contract: structural carrier and raw-fixture coverage, not model efficacy.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$warehouseSkill = 'src/stacks/dotnet/files/.claude/skills/add-warehouse-load/SKILL.md'
# 0.92.0 stopped shipping these generic "add an X" recipes; /bootstrap drafts project skills for
# operations a consumer's own code repeats instead.
$retiredRecipes = @('add-component', 'add-endpoint', 'add-entity', 'add-lazy-route', 'add-service', 'add-signal-store', 'register-service')
$required = @('first-party implementation, configuration, tests, and owner documentation', 'references/project-pattern.md', 'Generated recipes are leads only.', 'Exclude irrelevant scope, investigate conflicting applicable evidence', 'only correctness-material uncertainty', 'conditional fallbacks', 'never authorize a container, library, layer, interface, or token')

Reset-Tests
It 'the seven generic recipe skills no longer ship and the ledger retires each for installed consumers' {
    foreach ($stack in @('angular', 'dotnet', 'monorepo')) {
        foreach ($name in $retiredRecipes) {
            Assert (-not (Test-Path -LiteralPath (Join-Path $repoRoot "src/stacks/$stack/files/.claude/skills/$name"))) "src/stacks/$stack still authors retired recipe skill $name"
            Assert (-not (Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/.claude/skills/$name"))) "dist/$stack still ships retired recipe skill $name"
        }
    }
    $ledger = [IO.File]::ReadAllText((Join-Path $repoRoot 'src/core/framework-retirements.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
    foreach ($name in $retiredRecipes) {
        $entry = @($ledger.retirements | Where-Object { [string]$_.path -ceq ".claude/skills/$name/SKILL.md" })
        Assert ($entry.Count -eq 1) "retirement ledger has no entry for .claude/skills/$name/SKILL.md"
        Assert ([string]$entry[0].'retired-in' -ceq '0.92.0') "$name is not retired in 0.92.0"
    }
}

It 'the one remaining operation skill derives from scoped consumer evidence without shipping a sidecar' {
    $path = Join-Path $repoRoot ($warehouseSkill -replace '/', [IO.Path]::DirectorySeparatorChar)
    Assert (Test-Path -LiteralPath $path -PathType Leaf) "missing operation skill: $warehouseSkill"
    $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    foreach ($needle in $required) { Assert ($text.Contains($needle)) "$warehouseSkill omits '$needle'" }
    Assert ($text.IndexOf('## Project-derived pattern authority') -lt $text.IndexOf('0. ')) "$warehouseSkill puts its operation steps before derive-first authority"
    Assert (-not (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $path) 'references/project-pattern.md'))) "$warehouseSkill ships a consumer-owned sidecar"
}

It 'the warehouse recipe keeps target-family mechanisms conditional' {
    $warehouse = [IO.File]::ReadAllText((Join-Path $repoRoot $warehouseSkill), [Text.Encoding]::UTF8)
    $normalizedWarehouse = [regex]::Replace($warehouse, '\s+', ' ')
    foreach ($needle in @('conflicting evidence and correctness-material gaps remain unresolved', 'same target family', 'use surrogate keys only where that family evidences them', 'Do not require loosely typed staging', 'Preserve rerun safety through the target family', 'evidenced reject/quarantine path is valid', 'applicable target-family deployment vehicle')) {
        Assert ($normalizedWarehouse.Contains($needle)) "warehouse recipe omits conditional target-family safeguard '$needle'"
    }
    Assert ($warehouse -match 'Do not impose\s+one warehouse-wide style') 'warehouse recipe restores one warehouse-wide loading style'
    foreach ($forbidden in @('following the repo''s existing staging → warehouse patterns', 'What is never right is dropping unmatched rows', 'repo''s one existing vehicle', 'One warehouse, one loading pattern', 'Staging columns stay loosely typed', 'reference dimension surrogate keys (not natural keys', 'add-entity` where the repo evidences EF Core', 'use add-entity')) {
        Assert (-not $warehouse.Contains($forbidden)) "warehouse recipe restores unsupported mechanism '$forbidden'"
    }
}

It 'defaults do not select composition or Angular architecture mechanisms' {
    $dotnet = [IO.File]::ReadAllText((Join-Path $repoRoot 'src/stacks/dotnet/files/docs/defaults.md'), [Text.Encoding]::UTF8)
    $angular = [IO.File]::ReadAllText((Join-Path $repoRoot 'src/stacks/angular/files/docs/defaults.md'), [Text.Encoding]::UTF8)
    $monorepo = [IO.File]::ReadAllText((Join-Path $repoRoot 'src/stacks/monorepo/files/docs/defaults.md'), [Text.Encoding]::UTF8)
    foreach ($text in @($dotnet, $monorepo)) {
        Assert ($text.Contains('do not select extension methods or `Program.cs` from this default')) 'default does not condition its composition-root mechanism'
        Assert ($text.Contains('do not select `IOptions<T>`, `IOptionsMonitor<T>`, or `IOptionsSnapshot<T>` solely from this default')) 'default does not condition its options mechanism'
        Assert (-not $text.Contains('Register via extension methods per project')) 'default restores extension-method mandate'
    }
    foreach ($text in @($angular, $monorepo)) {
        foreach ($needle in @('standalone/NgModule shape', 'choice between `inject()` and constructor injection needs an explicit design decision', 'route-loading mechanism')) {
            Assert ($text.Contains($needle)) "Angular default omits conditional mechanism '$needle'"
        }
        Assert (-not $text.Contains('Standalone components as default')) 'default restores standalone mandate'
        Assert (-not $text.Contains('Feature areas are lazy-loaded routes')) 'default restores lazy-route mandate'
    }
}

It 'raw Unity fixture has only its evidenced composition root and lifetime' {
    $path = Join-Path $repoRoot '.claude/hooks/tests/fixtures/operation-authority-unity/CompositionRoot.cs'
    $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    Assert ($text.Contains('UnityContainer')) 'Unity composition root absent'
    Assert ($text.Contains('ContainerControlledLifetimeManager')) 'evidenced Unity lifetime absent'
    foreach ($forbidden in @('Microsoft.Extensions.DependencyInjection', 'IServiceCollection', 'AddScoped<')) {
        Assert (-not $text.Contains($forbidden)) "fixture acquired unsupported MS.DI artifact '$forbidden'"
    }
}

It 'active authority carriers do not restore a framework-selected service seam' {
    $perStack = @(
        'files/.claude/agents/bloat-radar.md',
        'files/docs/defaults.md',
        'files/docs/REVIEW-GUIDE.md',
        'files/docs/ARCHITECTURE.md',
        'files/README.md',
        'files/tests/evals/cases.yaml',
        'snippets/.github/instructions/framework-rules.instructions.md/lean-1-2',
        'snippets/.github/instructions/framework-rules.instructions.md/solid-1-5',
        'snippets/.github/instructions/framework-rules.instructions.md/solid-mechanism',
        'snippets/.github/instructions/framework-rules.instructions.md/workflow-bullets',
        'snippets/.claude/agents/solid-check.md/principles',
        'snippets/.claude/agents/solid-check.md/counterweight',
        'snippets/.claude/agents/solid-check.md/scope',
        'snippets/.claude/hooks/route-prompt.ps1/leanness-feature',
        'snippets/.github/agents/solid-check.agent.md/dip-note',
        'snippets/AGENTS.md/bs-primary-subtract',
        'files/.claude/skills/enforce-architecture/SKILL.md'
    )
    foreach ($stack in @('dotnet', 'angular', 'monorepo')) {
        foreach ($relative in $perStack) {
            $path = Join-Path $repoRoot "src/stacks/$stack/$relative"
            Assert (Test-Path -LiteralPath $path -PathType Leaf) "missing active carrier: $stack/$relative"
            $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
            Assert ([regex]::IsMatch($text, '(?i)(project evidence|project[- ]evidenced|project''s evidenced|evidenced project|first-party)')) "$stack/$relative omits project-derived authority"
            Assert (-not [regex]::IsMatch($text, '(?is)(every injected.{0,100}(interface|abstraction)|literal SOLID|interface per injected|abstraction/token per injected)')) "$stack/$relative restores a framework-selected service seam"
        }
    }
    $briefing = [IO.File]::ReadAllText((Join-Path $repoRoot 'src/core/presentation/framework-briefing.html'), [Text.Encoding]::UTF8)
    Assert ($briefing.Contains('derive service boundaries from project evidence')) 'framework briefing omits project-derived SOLID authority'
    Assert (-not $briefing.Contains('every injected service behind an interface')) 'framework briefing restores literal interface mandate'
}

exit (Write-TestSummary 'OperationSkillAuthority.Tests')
