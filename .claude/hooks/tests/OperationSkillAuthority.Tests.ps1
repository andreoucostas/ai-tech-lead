# Maintainer-only source contract: structural carrier and raw-fixture coverage, not model efficacy.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$skills = @(
    'src/stacks/dotnet/files/.claude/skills/add-endpoint/SKILL.md',
    'src/stacks/dotnet/files/.claude/skills/add-entity/SKILL.md',
    'src/stacks/dotnet/files/.claude/skills/register-service/SKILL.md',
    'src/stacks/dotnet/files/.claude/skills/add-warehouse-load/SKILL.md',
    'src/stacks/angular/files/.claude/skills/add-component/SKILL.md',
    'src/stacks/angular/files/.claude/skills/add-service/SKILL.md',
    'src/stacks/angular/files/.claude/skills/add-lazy-route/SKILL.md',
    'src/stacks/angular/files/.claude/skills/add-signal-store/SKILL.md'
)
$required = @('first-party implementation, configuration, tests, and owner documentation', 'references/project-pattern.md', 'Generated recipes are leads only.', 'Exclude irrelevant scope, investigate conflicting applicable evidence', 'only correctness-material uncertainty', 'conditional fallbacks', 'never authorize a container, library, layer, interface, or token')

Reset-Tests
It 'all eight operation skills derive from scoped consumer evidence without shipping a sidecar' {
    Assert ($skills.Count -eq 8) 'operation-skill inventory changed'
    foreach ($relative in $skills) {
        $path = Join-Path $repoRoot ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
        Assert (Test-Path -LiteralPath $path -PathType Leaf) "missing operation skill: $relative"
        $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
        foreach ($needle in $required) { Assert ($text.Contains($needle)) "$relative omits '$needle'" }
        Assert ($text.IndexOf('## Project-derived pattern authority') -lt $text.IndexOf('0. ')) "$relative puts its operation steps before derive-first authority"
        Assert (-not (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $path) 'references/project-pattern.md'))) "$relative ships a consumer-owned sidecar"
    }
}

It 'entity and service recipes do not restore EF or DI-extension defaults' {
    $entity = [IO.File]::ReadAllText((Join-Path $repoRoot 'src/stacks/dotnet/files/.claude/skills/add-entity/SKILL.md'), [Text.Encoding]::UTF8)
    $service = [IO.File]::ReadAllText((Join-Path $repoRoot 'src/stacks/dotnet/files/.claude/skills/register-service/SKILL.md'), [Text.Encoding]::UTF8)
    foreach ($forbidden in @('EF Core repos only', 'IEntityTypeConfiguration, DbContext registration', 'interface + implementation pair', "the project's DI extension pattern", 'IOptions variants')) {
        Assert (-not $entity.Contains($forbidden)) "entity recipe restores '$forbidden' as a default"
        Assert (-not $service.Contains($forbidden)) "service recipe restores '$forbidden' as a default"
    }
    Assert ($entity.Contains('do not introduce EF Core or another library from this skill')) 'entity recipe does not retain unresolved persistence uncertainty'
    Assert ($service.Contains('do not introduce DI from this skill')) 'service recipe does not retain unresolved composition uncertainty'
}

It 'endpoint and warehouse recipes keep target-family mechanisms conditional' {
    $endpoint = [IO.File]::ReadAllText((Join-Path $repoRoot 'src/stacks/dotnet/files/.claude/skills/add-endpoint/SKILL.md'), [Text.Encoding]::UTF8)
    $warehouse = [IO.File]::ReadAllText((Join-Path $repoRoot 'src/stacks/dotnet/files/.claude/skills/add-warehouse-load/SKILL.md'), [Text.Encoding]::UTF8)
    $normalizedWarehouse = [regex]::Replace($warehouse, '\s+', ' ')
    Assert ($endpoint.Contains('Add the endpoint/application boundary the project evidences')) 'endpoint recipe does not derive its boundary'
    Assert (-not $endpoint.Contains('Controller action (thin — delegates to the service immediately)')) 'endpoint recipe restores unconditional service delegation'
    foreach ($needle in @('same target family', 'use surrogate keys only where that family evidences them', 'Do not require loosely typed staging', 'Preserve rerun safety through the target family')) {
        Assert ($normalizedWarehouse.Contains($needle)) "warehouse recipe omits conditional target-family safeguard '$needle'"
    }
    Assert ($warehouse -match 'Do not impose\s+one warehouse-wide style') 'warehouse recipe restores one warehouse-wide loading style'
    foreach ($forbidden in @('One warehouse, one loading pattern', 'Staging columns stay loosely typed', 'reference dimension surrogate keys (not natural keys', 'add-entity` where the repo evidences EF Core')) {
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
        'files/AGENTS.md',
        'files/.github/copilot-instructions.md',
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
        'snippets/CLAUDE.md/bs-primary-subtract',
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
    $briefing = [IO.File]::ReadAllText((Join-Path $repoRoot 'src/core/docs/presentation/framework-briefing.html'), [Text.Encoding]::UTF8)
    Assert ($briefing.Contains('derive service boundaries from project evidence')) 'framework briefing omits project-derived SOLID authority'
    Assert (-not $briefing.Contains('every injected service behind an interface')) 'framework briefing restores literal interface mandate'
}

exit (Write-TestSummary 'OperationSkillAuthority.Tests')
