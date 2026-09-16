# Tests for the repo meta-dev hooks and the maintainer Claude Code wiring. Only bom-fix remains as a
# hook (the review-on-stop / mark-changed / reset-marker apparatus was retired as a mis-cadenced
# blocking Stop hook). Since B-241 this file also guards .claude/settings.json (every hook -File
# target resolves, plansDirectory exists, auto-memory is off) and the maintainer skills under
# .claude/skills/meta-*/ (frontmatter name == directory, non-empty description) -- the maintainer
# analogue of validate-dist check 8. These do NOT ship.
# Side effects (file rewrites) are isolated to a throwaway temp dir; the real repo is never touched.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$meta     = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path   # the repo .claude\hooks dir
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$bomfix   = Join-Path $meta 'bom-fix.ps1'

# Pure: settings JSON text in, violations out. "could not examine" (unparseable, empty) and "is
# wrong" (dead target, missing directory, memory on) are distinct messages (Maintenance model #7),
# and a hookless or empty document is a violation, never a vacuous pass.
function Get-SettingsWiringViolations {
    param(
        [AllowEmptyString()][string]$Json,
        [Parameter(Mandatory)][scriptblock]$PathExists
    )
    $bad = @()
    if ([string]::IsNullOrWhiteSpace($Json)) { $bad += 'could not examine settings.json: file is empty'; return $bad }
    try { $settings = $Json | ConvertFrom-Json } catch { $bad += "could not examine settings.json: not valid JSON ($($_.Exception.Message))"; return $bad }
    $commands = 0
    if ($settings.hooks) {
        foreach ($eventProp in $settings.hooks.PSObject.Properties) {
            foreach ($registration in @($eventProp.Value)) {
                foreach ($hook in @($registration.hooks)) {
                    if ($hook.type -ne 'command') { continue }
                    $commands++
                    if ($hook.command -notmatch '-File\s+(\S+)') { $bad += "$($eventProp.Name) hook has no -File target: $($hook.command)"; continue }
                    $target = $Matches[1]
                    if (-not (& $PathExists $target)) { $bad += "$($eventProp.Name) hook names a missing script: $target -- a registration that does not resolve is a hook that silently never runs" }
                }
            }
        }
    }
    if ($commands -eq 0) { $bad += 'settings.json registers zero command hooks -- the bom-fix registration is gone or the shape changed' }
    if ($settings.plansDirectory) {
        if (-not (& $PathExists $settings.plansDirectory)) { $bad += "plansDirectory does not exist in the repo: $($settings.plansDirectory)" }
    } else { $bad += 'settings.json has no plansDirectory -- plan-mode drafts would land outside the repo' }
    if ($settings.autoMemoryEnabled -ne $false) { $bad += 'autoMemoryEnabled is not false -- private memory contradicts the root instruction file standing on its own' }
    return $bad
}

# Pure: skill records (@{ Dir; Text }) in, violations out. Maintainer skills carry the meta- prefix
# because shipped skills under src/core are discovered in the same session when a file there is read.
function Get-SkillFileViolations {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Skills)
    $bad = @()
    if (@($Skills).Count -eq 0) { $bad += 'zero maintainer skills found under .claude/skills -- refusing to pass on an empty scan'; return $bad }
    foreach ($s in $Skills) {
        if ($null -eq $s.Text) { $bad += "$($s.Dir): could not examine SKILL.md: file is missing"; continue }
        if ($s.Text -notmatch '(?s)\A---\r?\n(.*?)\r?\n---') { $bad += "$($s.Dir): SKILL.md has no YAML frontmatter"; continue }
        $front = $Matches[1]
        if ($front -notmatch '(?m)^name:\s*(\S+)\s*$') { $bad += "$($s.Dir): frontmatter has no name"; continue }
        if ($Matches[1] -cne $s.Dir) { $bad += "$($s.Dir): frontmatter name '$($Matches[1])' differs from its directory" }
        if ($front -notmatch '(?m)^description:\s*\S') { $bad += "$($s.Dir): frontmatter has no description" }
        if ($s.Dir -notlike 'meta-*') { $bad += "$($s.Dir): maintainer skills carry the meta- prefix so they are not confused with shipped skills discovered in the same session" }
    }
    return $bad
}

function Test-Bom { param($p) $b=[IO.File]::ReadAllBytes($p); ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) }
function Write-NoBom { param($p,$txt) [IO.File]::WriteAllText($p, $txt, (New-Object System.Text.UTF8Encoding($false))) }

function Invoke-CardinalityFixture {
    param([string]$Root, [string]$Body, [string]$ManifestName)
    $fixture = Join-Path $Root 'Probe.Tests.ps1'
    [IO.File]::WriteAllText($fixture, $Body, (New-Object Text.UTF8Encoding($true)))
    $manifest = Join-Path $Root $ManifestName
    if (Test-Path -LiteralPath $manifest) { Remove-Item -LiteralPath $manifest -Force }
    $savedErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File `
            (Join-Path $Root 'Invoke-HookTests.ps1') -FixtureDiscovery -CaseCountPath $manifest 2>&1
        $exit = [int]$LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorActionPreference
    }
    [pscustomobject]@{ Exit=$exit; Out=(@($out) -join "`n"); Manifest=$manifest }
}

Reset-Tests
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("metahooks-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    # bom-fix: scoped to ai-tech-lead/ paths (the merged repo — WSD-012 D7), idempotent,
    # content-preserving, .ps1-only.
    $repoish = Join-Path $tmp 'ai-tech-lead\sub'; New-Item -ItemType Directory -Path $repoish -Force | Out-Null
    $other   = Join-Path $tmp 'other';            New-Item -ItemType Directory -Path $other   -Force | Out-Null

    It 'bom-fix adds a BOM to a bomless .ps1 under an ai-tech-lead/ path, content intact' {
        $f = Join-Path $repoish 'x.ps1'; Write-NoBom $f "exit 0`n"
        $r = Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress)
        Assert ($null -ne $r -and $r.Exit -eq 0) "bom-fix exited $(if($null -eq $r){'SKIP'}else{$r.Exit}) -- a hook that fails is not a hook that declined"
        Assert (Test-Bom $f) 'BOM was not added'
        Assert (([IO.File]::ReadAllText($f)).Trim() -eq 'exit 0') 'content changed'
    }
    It 'bom-fix is idempotent (already-BOM .ps1 unchanged)' {
        $f = Join-Path $repoish 'y.ps1'; [IO.File]::WriteAllText($f, "exit 0`n", (New-Object System.Text.UTF8Encoding($true)))
        $before = [IO.File]::ReadAllBytes($f).Length
        $r = Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress)
        Assert ($null -ne $r -and $r.Exit -eq 0) "bom-fix exited $(if($null -eq $r){'SKIP'}else{$r.Exit}) -- a hook that fails is not a hook that declined"
        Assert ([IO.File]::ReadAllBytes($f).Length -eq $before) 'idempotent run changed the file'
    }
    It 'bom-fix leaves a .ps1 OUTSIDE ai-tech-lead/ untouched (scope guard)' {
        $f = Join-Path $other 'z.ps1'; Write-NoBom $f "exit 0`n"
        $r = Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress)
        Assert ($null -ne $r -and $r.Exit -eq 0) "bom-fix exited $(if($null -eq $r){'SKIP'}else{$r.Exit}) -- a hook that fails is not a hook that declined"
        Assert (-not (Test-Bom $f)) 'should not have touched a file outside the repo'
    }
    It 'bom-fix does not fire on the LEGACY repo names (ai-tech-lead-dotnet is out of scope now)' {
        $legacy = Join-Path $tmp 'ai-tech-lead-dotnet'; New-Item -ItemType Directory -Path $legacy -Force | Out-Null
        $f = Join-Path $legacy 'l.ps1'; Write-NoBom $f "exit 0`n"
        $r = Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress)
        Assert ($null -ne $r -and $r.Exit -eq 0) "bom-fix exited $(if($null -eq $r){'SKIP'}else{$r.Exit}) -- a hook that fails is not a hook that declined"
        Assert (-not (Test-Bom $f)) 'legacy repos are frozen — the hook must not rewrite them'
    }
    It 'bom-fix ignores non-.ps1 files' {
        $f = Join-Path $repoish 'note.txt'; Write-NoBom $f 'hi'
        $r = Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress)
        Assert ($null -ne $r -and $r.Exit -eq 0) "bom-fix exited $(if($null -eq $r){'SKIP'}else{$r.Exit}) -- a hook that fails is not a hook that declined"
        Assert (-not (Test-Bom $f)) 'should not have rewritten a .txt'
    }

    # This manifest is the CI equality oracle between direct PS7 and PS5.1 runs. Refuse every
    # vacuous or ambiguous child shape, and pin its bytes so host encoding cannot forge equality.
    $cardinalityRoot = Join-Path $tmp 'aggregate-cardinality'
    New-Item -ItemType Directory -Path $cardinalityRoot -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-HookTests.ps1') -Destination $cardinalityRoot
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '_HookHarness.ps1') -Destination $cardinalityRoot

    It 'aggregate rejects a child with no semantic case marker' {
        $r = Invoke-CardinalityFixture $cardinalityRoot "exit 0`n" 'missing.txt'
        Assert ($r.Exit -ne 0) "missing marker stayed green: $($r.Out)"
        Assert ($r.Out -match 'emitted 0 CASE_COUNT markers') "missing marker was not diagnosed: $($r.Out)"
        Assert (-not (Test-Path -LiteralPath $r.Manifest)) 'missing marker produced a manifest'
    }
    It 'aggregate rejects a zero semantic case marker' {
        $r = Invoke-CardinalityFixture $cardinalityRoot "Write-Host 'CASE_COUNT 0'`nexit 0`n" 'zero.txt'
        Assert ($r.Exit -ne 0) "zero marker stayed green: $($r.Out)"
        Assert ($r.Out -match 'non-positive CASE_COUNT') "zero marker was not diagnosed: $($r.Out)"
        Assert (-not (Test-Path -LiteralPath $r.Manifest)) 'zero marker produced a manifest'
    }
    It 'aggregate rejects a suite whose only semantic case was skipped' {
        $body = @'
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
Reset-Tests
Skip 'Windows case' 'fixture deliberately did not execute'
exit (Write-TestSummary 'skip-only fixture')
'@
        $r = Invoke-CardinalityFixture $cardinalityRoot $body 'skip-only.txt'
        Assert ($r.Exit -ne 0) "skip-only suite stayed green: $($r.Out)"
        Assert ($r.Out -match 'CASE_COUNT 0' -and $r.Out -match 'non-positive CASE_COUNT') `
            "skip-only suite was not classified as zero executed cases: $($r.Out)"
        Assert (-not (Test-Path -LiteralPath $r.Manifest)) 'skip-only suite produced a manifest'
    }
    It 'aggregate rejects duplicate semantic case markers' {
        $r = Invoke-CardinalityFixture $cardinalityRoot "Write-Host 'CASE_COUNT 1'`nWrite-Host 'CASE_COUNT 2'`nexit 0`n" 'duplicate.txt'
        Assert ($r.Exit -ne 0) "duplicate markers stayed green: $($r.Out)"
        Assert ($r.Out -match 'emitted 2 CASE_COUNT markers') "duplicate markers were not diagnosed: $($r.Out)"
        Assert (-not (Test-Path -LiteralPath $r.Manifest)) 'duplicate markers produced a manifest'
    }
    It 'aggregate semantic case manifest is deterministic UTF-8 without BOM' {
        $body = "Write-Host 'CASE_COUNT 3'`nexit 0`n"
        $first = Invoke-CardinalityFixture $cardinalityRoot $body 'first.txt'
        $second = Invoke-CardinalityFixture $cardinalityRoot $body 'second.txt'
        Assert ($first.Exit -eq 0 -and $second.Exit -eq 0) "valid marker failed: $($first.Out)`n$($second.Out)"
        $a = [IO.File]::ReadAllBytes($first.Manifest)
        $b = [IO.File]::ReadAllBytes($second.Manifest)
        Assert ($a.Length -gt 0 -and $b.Length -gt 0) 'valid marker produced an empty manifest'
        Assert (-not ($a.Length -ge 3 -and $a[0] -eq 0xEF -and $a[1] -eq 0xBB -and $a[2] -eq 0xBF)) 'manifest unexpectedly has a UTF-8 BOM'
        Assert ([Convert]::ToBase64String($a) -ceq [Convert]::ToBase64String($b)) 'identical runs produced different manifest bytes'
        Assert ([Text.Encoding]::UTF8.GetString($a) -ceq "Probe.Tests.ps1`t3`nTOTAL`t3`n") 'manifest format/content differs from its canonical form'
    }

    # --- maintainer Claude Code wiring (B-241) ---------------------------------------------------
    It 'settings.json: every hook -File target resolves, plansDirectory exists, auto-memory is off' {
        $json = Get-Content -Raw (Join-Path $repoRoot '.claude/settings.json')
        $bad = @(Get-SettingsWiringViolations -Json $json -PathExists { param($p) Test-Path -LiteralPath (Join-Path $repoRoot $p) })
        Assert ($bad.Count -eq 0) ($bad -join '; ')
    }
    It 'settings wiring helper separates unparseable JSON from wrong wiring and refuses vacuous shapes' {
        $good = '{"plansDirectory":".claude/plans/inbox","autoMemoryEnabled":false,"hooks":{"PostToolUse":[{"matcher":"Write|Edit","hooks":[{"type":"command","command":"pwsh -NoProfile -File .claude/hooks/bom-fix.ps1"}]}]}}'
        $exists = { param($p) @('.claude/plans/inbox', '.claude/hooks/bom-fix.ps1') -contains $p }
        Assert (@(Get-SettingsWiringViolations -Json $good -PathExists $exists).Count -eq 0) 'clean fixture was rejected'
        $bad = @(Get-SettingsWiringViolations -Json '{ not json' -PathExists $exists)
        Assert ($bad.Count -eq 1 -and $bad[0] -match 'could not examine') "unparseable JSON must be reported as unexaminable, not as wrong wiring: $($bad -join '; ')"
        $bad = @(Get-SettingsWiringViolations -Json ($good.Replace('bom-fix.ps1', 'nope.ps1')) -PathExists $exists)
        Assert ($bad.Count -eq 1 -and $bad[0] -match 'missing script.*nope\.ps1') "a dead -File target must be named: $($bad -join '; ')"
        $bad = @(Get-SettingsWiringViolations -Json ($good.Replace('.claude/plans/inbox', '.claude/nowhere')) -PathExists $exists)
        Assert ($bad.Count -eq 1 -and $bad[0] -match 'plansDirectory does not exist') "a missing plans directory must be named: $($bad -join '; ')"
        $bad = @(Get-SettingsWiringViolations -Json ($good.Replace('"autoMemoryEnabled":false,', '')) -PathExists $exists)
        Assert ($bad.Count -eq 1 -and $bad[0] -match 'autoMemoryEnabled') "a missing autoMemoryEnabled must be reported: $($bad -join '; ')"
        $bad = @(Get-SettingsWiringViolations -Json '{"plansDirectory":".claude/plans/inbox","autoMemoryEnabled":false,"hooks":{}}' -PathExists $exists)
        Assert ($bad.Count -eq 1 -and $bad[0] -match 'zero command hooks') "a hookless settings file must not pass vacuously: $($bad -join '; ')"
        $bad = @(Get-SettingsWiringViolations -Json '' -PathExists $exists)
        Assert ($bad.Count -eq 1 -and $bad[0] -match 'could not examine') 'empty input must be unexaminable, not clean'
    }
    It 'maintainer skills: frontmatter name matches the directory, description present, meta- prefix' {
        $skillsRoot = Join-Path $repoRoot '.claude/skills'
        $skills = @()
        foreach ($dir in @(Get-ChildItem -LiteralPath $skillsRoot -Directory)) {
            $file = Join-Path $dir.FullName 'SKILL.md'
            $text = if (Test-Path -LiteralPath $file) { Get-Content -Raw -LiteralPath $file } else { $null }
            $skills += @{ Dir = $dir.Name; Text = $text }
        }
        $bad = @(Get-SkillFileViolations -Skills $skills)
        Assert ($bad.Count -eq 0) ($bad -join '; ')
    }
    It 'skill helper rejects a renamed, undescribed, unprefixed, or missing SKILL.md and an empty scan' {
        $good = "---`nname: meta-probe`ndescription: does a thing`n---`n# body"
        Assert (@(Get-SkillFileViolations -Skills @(@{ Dir = 'meta-probe'; Text = $good })).Count -eq 0) 'clean fixture was rejected'
        $bad = @(Get-SkillFileViolations -Skills @(@{ Dir = 'meta-probe'; Text = $good.Replace('name: meta-probe', 'name: other') }))
        Assert ($bad.Count -eq 1 -and $bad[0] -match "differs from its directory") "a name/directory mismatch must be named: $($bad -join '; ')"
        $bad = @(Get-SkillFileViolations -Skills @(@{ Dir = 'meta-probe'; Text = $good.Replace("description: does a thing`n", '') }))
        Assert ($bad.Count -eq 1 -and $bad[0] -match 'no description') "a missing description must be named: $($bad -join '; ')"
        $bad = @(Get-SkillFileViolations -Skills @(@{ Dir = 'probe'; Text = $good.Replace('meta-probe', 'probe') }))
        Assert ($bad.Count -eq 1 -and $bad[0] -match 'meta- prefix') "an unprefixed maintainer skill must be named: $($bad -join '; ')"
        $bad = @(Get-SkillFileViolations -Skills @(@{ Dir = 'meta-probe'; Text = $null }))
        Assert ($bad.Count -eq 1 -and $bad[0] -match 'could not examine.*missing') "a missing file must be unexaminable, not wrong: $($bad -join '; ')"
        $bad = @(Get-SkillFileViolations -Skills @())
        Assert ($bad.Count -eq 1 -and $bad[0] -match 'zero maintainer skills') 'an empty scan must not pass vacuously'
    }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'MetaHooks.Tests (bom-fix + maintainer wiring)')
