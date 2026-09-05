# B-216 source contract: structural carrier/fixture coverage, not model efficacy evidence.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
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

It 'raw Unity fixture has only its evidenced composition root and lifetime' {
    $path = Join-Path $repoRoot 'src/core/tests/fixtures/b216-unity/CompositionRoot.cs'
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
