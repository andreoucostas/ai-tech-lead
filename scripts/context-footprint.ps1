# ai-tech-lead context-footprint gate (PowerShell twin; bash twin is context-footprint.sh).
# Measures deterministic framework context across all composed dists, renders both hook twins,
# and compares the canonical result with meta/context-footprint.json.
# Usage: context-footprint.ps1 [-Check|-Update]
# Default/-Check: exit 1 for a missing or changed baseline or hook-render mismatch.
# -Update: rewrite the BOM-less, LF-only canonical baseline.
# Exit 2: usage error, missing dist/tool, malformed frontmatter, or fixture execution failure.
param(
    [switch]$Check,
    [switch]$Update
)
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
$baseline = Join-Path $repo 'meta/context-footprint.json'
$utf8 = New-Object System.Text.UTF8Encoding($false, $true)
$lf = [string][char]10

if ($Check -and $Update) {
    [Console]::Error.WriteLine('usage: context-footprint.ps1 [-Check|-Update]')
    exit 2
}
if (-not $Update -and -not (Test-Path $baseline)) {
    [Console]::Error.WriteLine("FAIL: context-footprint baseline missing: $baseline. Run with -Update and review the generated diff.")
    exit 1
}
if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('FATAL: bash is required to render hook twins.')
    exit 2
}
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine('FATAL: pwsh is required to render hook twins.')
    exit 2
}

# --- D1: LF-normalized UTF-8 byte counting -----------------------------------------------------
function Get-NormalizedText([string]$Path) {
    $text = $utf8.GetString([IO.File]::ReadAllBytes($Path))
    return $text.Replace(([char]13 + [char]10), $lf)
}

function Get-ByteCount([string]$Path) {
    return $utf8.GetByteCount((Get-NormalizedText $Path))
}

function New-ItemRecord([string]$Path, [int]$Chars) {
    return [ordered]@{
        path  = $Path.Replace('\', '/')
        chars = $Chars
        tok   = [int][Math]::Round($Chars / 4.0, 0, [MidpointRounding]::ToEven)
    }
}

function Sort-ItemRecords($Items) {
    $array = [object[]]@($Items)
    [Array]::Sort($array, [Comparison[object]]{
        param($left, $right)
        return [StringComparer]::Ordinal.Compare([string]$left.path, [string]$right.path)
    })
    return ,$array
}

# Measure-Object's -Property binder does not resolve keys on [ordered] hashtables (unlike
# Where-Object/Sort-Object, which have dictionary-aware property access) -- it silently returns
# $null/0 rather than erroring. Sum/max manually instead of trusting Measure-Object here.
function Get-CharsSum($Items) {
    $total = 0
    foreach ($item in $Items) { $total += [int]$item.chars }
    return $total
}

function Get-CharsMax($Items) {
    $max = 0
    foreach ($item in $Items) { if ([int]$item.chars -gt $max) { $max = [int]$item.chars } }
    return $max
}

# --- D2: manifest extraction and byte-safe hook fixtures ---------------------------------------
function Split-Frontmatter([string]$Path) {
    $text = Get-NormalizedText $Path
    if (-not $text.EndsWith($lf)) {
        throw "FATAL: manifest file does not end with a trailing newline: $Path"
    }
    $lines = $text.Split([char]10)
    if ($lines.Count -eq 0 -or $lines[0] -ne '---') {
        throw "FATAL: manifest file has no opening frontmatter delimiter: $Path"
    }
    $end = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq '---') {
            $end = $i
            break
        }
    }
    if ($end -lt 0) {
        throw "FATAL: manifest file has no closing frontmatter delimiter: $Path"
    }
    $frontmatter = ($lines[0..$end] -join $lf) + $lf
    $body = ''
    if ($end + 1 -lt $lines.Count) {
        $body = $lines[($end + 1)..($lines.Count - 1)] -join $lf
    }
    return @($utf8.GetByteCount($frontmatter), $utf8.GetByteCount($body))
}

function Invoke-HookFixture(
    [string]$Dist,
    [string]$Hook,
    [string]$Fixture,
    [string]$Event,
    [string]$TempRoot
) {
    $work = Join-Path $TempRoot ("$Dist-$Hook-" + $Fixture.Replace('/', '-'))
    New-Item -ItemType Directory -Force $work | Out-Null
    if ($Hook -eq 'session-start') {
        [IO.File]::WriteAllText(
            (Join-Path $work 'CLAUDE.md'),
            '# Fixture' + $lf + 'BOOTSTRAP_PENDING' + $lf,
            $utf8
        )
        [IO.File]::WriteAllText(
            (Join-Path $work 'SECURITY_FINDINGS.md'),
            '| ID | Severity | Status | Found | Due |' + $lf +
            '| CF-1 | High | Open | 2000-01-01 | 2000-01-02 |' + $lf,
            $utf8
        )
    }
    $eventPath = Join-Path $work 'event.json'
    $shOutput = Join-Path $work 'sh.out'
    $psOutput = Join-Path $work 'ps.out'
    [IO.File]::WriteAllText($eventPath, $Event, $utf8)

    $workArg = $work.Replace('\', '/')
    $eventArg = $eventPath.Replace('\', '/')
    $shOutputArg = $shOutput.Replace('\', '/')
    $psOutputArg = $psOutput.Replace('\', '/')
    $shHook = (Join-Path $repo "dist/$Dist/.claude/hooks/$Hook.sh").Replace('\', '/')
    $psHook = (Join-Path $repo "dist/$Dist/.claude/hooks/$Hook.ps1").Replace('\', '/')

    & bash -c 'cd "$1" && LC_ALL=C bash "$2" < "$3" > "$4" 2>&1' footprint $workArg $shHook $eventArg $shOutputArg
    if ($LASTEXITCODE -ne 0) {
        throw "FATAL: bash hook failed: $Dist/$Hook/$Fixture"
    }
    & bash -c 'cd "$1" && pwsh -NoProfile -File "$2" < "$3" > "$4" 2>&1' footprint $workArg $psHook $eventArg $psOutputArg
    if ($LASTEXITCODE -ne 0) {
        throw "FATAL: PowerShell hook failed: $Dist/$Hook/$Fixture"
    }

    $shText = Get-NormalizedText $shOutput
    $psText = Get-NormalizedText $psOutput
    if ($shText -cne $psText) {
        throw "FAIL: hook twin-render mismatch: $Dist/$Hook/$Fixture"
    }
    if ($shText.TrimStart().StartsWith('{')) {
        throw "FATAL: fixture took JSON output branch: $Dist/$Hook/$Fixture"
    }
    return $utf8.GetByteCount($shText)
}

$prompts = [ordered]@{
    'intent/debt'       = 'Review the technical debt in this area'
    'intent/design'     = 'Design the best approach for this component'
    'intent/feature'    = 'Implement a new component'
    'intent/fix'        = 'Fix the broken component'
    'intent/refactor'   = 'Refactor this component'
    'intent/review'     = 'Review this code'
    'intent/test'       = 'Write tests for this component'
    'security-only'     = 'Explain password auth'
    'worst/fix-security'= 'Fix the broken password auth'
}

# --- D3: canonical hand-rolled JSON -------------------------------------------------------------
function ConvertTo-JsonString([string]$Value) {
    $builder = New-Object Text.StringBuilder
    foreach ($character in $Value.ToCharArray()) {
        switch ([int]$character) {
            8  { [void]$builder.Append('\b') }
            9  { [void]$builder.Append('\t') }
            10 { [void]$builder.Append('\n') }
            12 { [void]$builder.Append('\f') }
            13 { [void]$builder.Append('\r') }
            34 { [void]$builder.Append('\"') }
            92 { [void]$builder.Append('\\') }
            default {
                if ([int]$character -lt 32) {
                    [void]$builder.AppendFormat('\u{0:x4}', [int]$character)
                } else {
                    [void]$builder.Append($character)
                }
            }
        }
    }
    return '"' + $builder.ToString() + '"'
}

function ConvertTo-CanonicalJson($Value, [int]$Level = 0) {
    $pad = '  ' * $Level
    $childPad = '  ' * ($Level + 1)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [string]) { return ConvertTo-JsonString $Value }
    if ($Value -is [int] -or $Value -is [long]) {
        return $Value.ToString([Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [Collections.IDictionary]) {
        $lines = @()
        foreach ($key in $Value.Keys) {
            $lines += $childPad + (ConvertTo-JsonString ([string]$key)) + ': ' +
                (ConvertTo-CanonicalJson $Value[$key] ($Level + 1))
        }
        if ($lines.Count -eq 0) { return '{}' }
        return '{' + $lf + ($lines -join (',' + $lf)) + $lf + $pad + '}'
    }
    if ($Value -is [Collections.IEnumerable]) {
        $lines = @()
        foreach ($entry in $Value) {
            $lines += $childPad + (ConvertTo-CanonicalJson $entry ($Level + 1))
        }
        if ($lines.Count -eq 0) { return '[]' }
        return '[' + $lf + ($lines -join (',' + $lf)) + $lf + $pad + ']'
    }
    throw "FATAL: unsupported JSON value type: $($Value.GetType().FullName)"
}

# --- D2/D4: measure all dists, derive totals, and issue advisory warnings -----------------------
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('context-footprint-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $tempRoot | Out-Null
try {
    $distData = [ordered]@{}
    $derived = [ordered]@{}
    foreach ($dist in @('dotnet', 'angular', 'monorepo')) {
        $root = Join-Path $repo "dist/$dist"
        if (-not (Test-Path $root)) { throw "FATAL: missing dist/$dist -- rebuild first." }
        $groups = [ordered]@{
            'static.claude'  = [Collections.ArrayList]@()
            'static.copilot' = [Collections.ArrayList]@()
            'instructed'     = [Collections.ArrayList]@()
            'session'        = [Collections.ArrayList]@()
            'prompt'         = [Collections.ArrayList]@()
            'ondemand-info'  = [Collections.ArrayList]@()
        }

        [void]$groups['static.claude'].Add((New-ItemRecord 'CLAUDE.md' (Get-ByteCount (Join-Path $root 'CLAUDE.md'))))
        foreach ($relative in @('AGENTS.md', '.github/copilot-instructions.md')) {
            [void]$groups['static.copilot'].Add((New-ItemRecord $relative (Get-ByteCount (Join-Path $root $relative))))
        }
        foreach ($relative in @('FRAMEWORK-CONTEXT.md', 'docs/defaults.md', 'docs/wiki/INDEX.md')) {
            $path = Join-Path $root $relative
            if (Test-Path $path) {
                [void]$groups['instructed'].Add((New-ItemRecord $relative (Get-ByteCount $path)))
            }
        }

        $manifestFiles = @()
        foreach ($pattern in @('.claude/skills/*/SKILL.md', '.claude/commands/*.md', '.claude/agents/*.md')) {
            $manifestFiles += Get-ChildItem (Join-Path $root $pattern) -File -ErrorAction SilentlyContinue
        }
        $manifestRecords = @()
        foreach ($file in $manifestFiles) {
            $relative = $file.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
            $manifestRecords += [ordered]@{ path = $relative; file = $file }
        }
        foreach ($record in (Sort-ItemRecords $manifestRecords)) {
            $parts = Split-Frontmatter $record.file.FullName
            [void]$groups['static.claude'].Add((New-ItemRecord ($record.path + '#frontmatter') $parts[0]))
            [void]$groups['ondemand-info'].Add((New-ItemRecord ($record.path + '#body') $parts[1]))
        }

        $sessionChars = Invoke-HookFixture $dist 'session-start' 'bootstrap-overdue' '{"hook_event_name":"SessionStart"}' $tempRoot
        [void]$groups['session'].Add((New-ItemRecord 'fixture/session-start' $sessionChars))
        foreach ($name in $prompts.Keys) {
            $event = '{"hook_event_name":"UserPromptSubmit","prompt":"' + $prompts[$name] + '"}'
            $chars = Invoke-HookFixture $dist 'route-prompt' $name $event $tempRoot
            [void]$groups['prompt'].Add((New-ItemRecord ("fixture/route-prompt/$name") $chars))
        }
        foreach ($group in @($groups.Keys)) {
            $groups[$group] = Sort-ItemRecords $groups[$group]
        }

        $distData[$dist] = $groups
        $claudeTotal = Get-CharsSum $groups['static.claude']
        $copilotTotal = Get-CharsSum $groups['static.copilot']
        $promptMaximum = Get-CharsMax $groups['prompt']
        $derived[$dist] = [ordered]@{
            'static.claude.chars'  = [int]$claudeTotal
            'static.claude.tok'    = [int][Math]::Round($claudeTotal / 4.0)
            'static.copilot.chars' = [int]$copilotTotal
            'static.copilot.tok'   = [int][Math]::Round($copilotTotal / 4.0)
            'prompt.max.chars'     = [int]$promptMaximum
            'prompt.max.tok'       = [int][Math]::Round($promptMaximum / 4.0)
        }
    }

    $dotnetClaude = ($distData.dotnet['static.claude'] | Where-Object path -eq 'CLAUDE.md').chars
    $angularClaude = ($distData.angular['static.claude'] | Where-Object path -eq 'CLAUDE.md').chars
    $monorepoClaude = ($distData.monorepo['static.claude'] | Where-Object path -eq 'CLAUDE.md').chars
    $largestSingle = [Math]::Max($dotnetClaude, $angularClaude)
    $derived['monorepo-claude-ratio-permille'] = [int][Math]::Round(1000 * $monorepoClaude / $largestSingle)

    $document = [ordered]@{
        'schema-version' = 1
        'generated-by' = 'scripts/context-footprint.ps1 + scripts/context-footprint.sh'
        'counting-rule' = 'LF-normalized UTF-8 bytes; ~tok = round(chars/4)'
        'ceilings' = [ordered]@{
            'static.claude.single-stack.chars' = 40000
            'static.claude.monorepo.chars' = 48000
            'monorepo-claude-ratio-permille' = 1500
        }
        'dists' = $distData
        'derived' = $derived
        '_notes' = @(
            'Claude frontmatter is a stable over-approximation of harness injection.',
            'Copilot skill frontmatter and .agent.md wrapper consumption are unverified; B-17 instructions join static.copilot when added.',
            'ondemand-info is reported but never policy-gated.',
            'Token values are chars÷4 approximations.'
        )
    }
    $json = (ConvertTo-CanonicalJson $document) + $lf

    foreach ($dist in @('dotnet', 'angular')) {
        if ($derived[$dist]['static.claude.chars'] -gt 40000) {
            Write-Output "WARN: $dist static.claude exceeds 40000 chars."
        }
    }
    if ($derived.monorepo['static.claude.chars'] -gt 48000) {
        Write-Output 'WARN: monorepo static.claude exceeds 48000 chars.'
    }
    if ($derived['monorepo-claude-ratio-permille'] -gt 1500) {
        Write-Output 'WARN: monorepo CLAUDE.md exceeds 1.5x the larger single-stack CLAUDE.md.'
    }

    if ($Update) {
        [IO.File]::WriteAllText($baseline, $json, $utf8)
        Write-Output 'UPDATED: meta/context-footprint.json'
        exit 0
    }
    $expected = Get-NormalizedText $baseline
    if ($expected -cne $json) {
        Write-Output 'FAIL: context footprint differs from meta/context-footprint.json. Review the change, then run -Update.'
        exit 1
    }
    Write-Output 'OK: context footprint matches meta/context-footprint.json.'
    exit 0
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    if ($_.Exception.Message.StartsWith('FATAL:')) { exit 2 }
    exit 1
} finally {
    Remove-Item -Recurse -Force $tempRoot -ErrorAction SilentlyContinue
}
