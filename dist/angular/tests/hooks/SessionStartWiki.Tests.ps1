if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$subject = Join-Path $hooks 'session-start.ps1'
$distRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

$ordinaryKnowledgeRequirements = @(
    'non-trivial change—including an ordinary feature/fix request naming neither a skill nor a path',
    'locate likely task areas',
    'select relevant scoped wiki, map, skill, or example entries',
    'exclude irrelevant/nonapplicable ones',
    'read bodies/references on demand',
    'Investigate conflicting applicable claims',
    'recheck decisive correctness-material evidence.',
    'only correctness-material gaps from unresolved drafts, opposing scopes, or stale, missing, or inaccessible evidence',
    'Name material evidence and run repository-evidenced verification.',
    'Hook registration alone proves neither firing nor consumption',
    'do not preload the wiki',
    'depend on a hook.'
)

function Get-OrdinaryKnowledgeRoutingOmissions([string]$Text) {
    @($ordinaryKnowledgeRequirements | Where-Object {
        $Text.IndexOf($_, [StringComparison]::Ordinal) -lt 0
    })
}

function Invoke-SessionStartAt($root, $json) {
    Push-Location $root
    try { Invoke-Hook $subject $json } finally { Pop-Location }
}

function New-WikiRoot([int]$count) {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('session-wiki-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force (Join-Path $root 'docs/wiki') | Out-Null
    if ($count -ge 0) {
        $entries = 1..$count | ForEach-Object { "- [gotcha] [entry-$_](./entry-$_.md) — fact $_" }
        [IO.File]::WriteAllText(
            (Join-Path $root 'docs/wiki/INDEX.md'),
            "# Team Wiki Index`n$($entries -join "`n")",
            [Text.UTF8Encoding]::new($false))
    }
    $root
}

$claude = '{"hook_event_name":"SessionStart"}'
$copilot = '{"timestamp":1}'
Reset-Tests

It 'writes a parseable ISO-8601 UTC liveness record' {
    $root = New-WikiRoot -1
    try {
        $result = Invoke-SessionStartAt $root $claude
        $record = Join-Path $root '.claude/.state/last-session-start'
        Assert ($result.Exit -eq 0) 'hook crashed'
        Assert (Test-Path -LiteralPath $record) 'liveness record absent'
        $stamp = [IO.File]::ReadAllText($record)
        $parsed = [datetimeoffset]::MinValue
        $valid = [datetimeoffset]::TryParse($stamp, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)
        Assert $valid "not parseable ISO-8601: $stamp"
        Assert ($stamp -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') "not ISO-8601 UTC: $stamp"
        Assert ($parsed.Offset -eq [TimeSpan]::Zero) "not UTC: $stamp"
    } finally { Remove-Item -Recurse -Force $root }
}

It 'soft-fails when the liveness path is unwritable' {
    $root = New-WikiRoot -1
    try {
        New-Item -ItemType Directory -Force (Join-Path $root '.claude') | Out-Null
        [IO.File]::WriteAllText((Join-Path $root '.claude/.state'), 'path collision', [Text.UTF8Encoding]::new($false))
        $result = Invoke-SessionStartAt $root $claude
        Assert ($result.Exit -eq 0) "hook failed: $($result.Err)"
        Assert ($result.Out -match '## Session preload') 'normal preload output absent'
    } finally { Remove-Item -Recurse -Force $root }
}

It 'small index is inlined' {
    $root = New-WikiRoot 2
    try { Assert ((Invoke-SessionStartAt $root $claude).Out -match 'entry-2') 'small index absent' }
    finally { Remove-Item -Recurse -Force $root }
}

It 'index above the inline threshold is summarized' {
    $root = New-WikiRoot 31
    try {
        $result = Invoke-SessionStartAt $root $claude
        Assert ($result.Out -match '31 wiki entries — read docs/wiki/INDEX.md') 'summary absent'
        Assert ($result.Out -notmatch 'entry-31') 'large index leaked'
    } finally { Remove-Item -Recurse -Force $root }
}

It 'ordinary feature/fix knowledge routing remains scoped, on-demand, and hook-independent' {
    $carriers = @('.github/instructions/framework-rules.instructions.md')
    $agentsPath = Join-Path $distRoot 'AGENTS.md'
    if (Test-Path -LiteralPath $agentsPath -PathType Leaf) {
        $carriers += 'AGENTS.md'
    } elseif (Test-Path -LiteralPath (Join-Path $distRoot '.claude/framework-version.json') -PathType Leaf) {
        Assert $false 'composed distribution omits AGENTS.md'
    }
    foreach ($relative in $carriers) {
        $path = Join-Path $distRoot ($relative -replace '/', [IO.Path]::DirectorySeparatorChar)
        Assert (Test-Path -LiteralPath $path -PathType Leaf) "knowledge carrier missing: $relative"
        $omissions = @(Get-OrdinaryKnowledgeRoutingOmissions ([IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)))
        Assert ($omissions.Count -eq 0) "$relative omits: $($omissions -join '; ')"
    }

    $canonicalPath = Join-Path $distRoot '.github/instructions/framework-rules.instructions.md'
    $canonical = [IO.File]::ReadAllText($canonicalPath, [Text.Encoding]::UTF8)
    foreach ($required in $ordinaryKnowledgeRequirements) {
        $hostile = $canonical.Replace($required, '<removed>')
        Assert ($hostile -cne $canonical) "hostile mutation did not remove '$required'"
        $omissions = @(Get-OrdinaryKnowledgeRoutingOmissions $hostile)
        Assert ($omissions -contains $required) "hostile mutation escaped: $required"
    }
}

It 'missing index is silent' {
    $root = New-WikiRoot -1
    try {
        $missingResult = Invoke-SessionStartAt $root $claude
        Assert ($missingResult.Out -notmatch 'entry-|wiki entries|Team Wiki Index') "wiki output present: [$($missingResult.Out)]"
    }
    finally { Remove-Item -Recurse -Force $root }
}

It 'Copilot JSON contains a small wiki in both additionalContext shapes' {
    $root = New-WikiRoot 2
    try {
        $json = (Invoke-SessionStartAt $root $copilot).Out | ConvertFrom-Json
        Assert ($json.additionalContext -match 'entry-2') 'top-level missing'
        Assert ($json.hookSpecificOutput.additionalContext -match 'entry-2') 'wrapped missing'
    } finally { Remove-Item -Recurse -Force $root }
}

It 'Copilot JSON contains a large summary in both additionalContext shapes' {
    $root = New-WikiRoot 31
    try {
        $json = (Invoke-SessionStartAt $root $copilot).Out | ConvertFrom-Json
        Assert ($json.additionalContext -match '31 wiki entries') 'top-level missing'
        Assert ($json.hookSpecificOutput.additionalContext -match '31 wiki entries') 'wrapped missing'
    } finally { Remove-Item -Recurse -Force $root }
}

exit (Write-TestSummary 'SessionStartWiki.Tests')
