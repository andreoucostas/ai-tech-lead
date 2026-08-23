# Asserts B-97's delivery contract by BEHAVIOR: run the shipped installer in UPDATE mode over a
# fixture shaped like a real pre-B-97 consumer, then observe what the consumer actually gets.
# Does NOT ship.
#
# Why this exists: B-97 found that no change to CLAUDE.md -- or any protected file -- had reached an
# already-bootstrapped consumer for 24 releases, because the installer restores the consumer's own
# copy over the new one. That protection is CORRECT and must not regress; the fix routes the
# framework-owned rules to an UNPROTECTED carrier instead. Both halves of that are behavioral, and
# InstallerContract.Tests.ps1 covers only greenfield and brownfield -- update mode, the mode every
# existing consumer actually runs, had no test at all.
#
# The two properties that must never silently swap places:
#   PROTECTED  (CLAUDE.md)  -> update must leave it byte-identical, forever.
#   UNPROTECTED (carrier)   -> update must overwrite it, forever, even if edited.
# A regression in either direction is invisible in a diff and catastrophic in the field, which is
# why this is asserted by running the installer rather than by reading its source.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$bash = Get-BashPath

$carrierRel = '.github/instructions/framework-rules.instructions.md'
$importLine = '@.github/instructions/framework-rules.instructions.md'
$staleVersion = '0.40.0'

# A consumer as they exist in the field: bootstrapped (Conventions populated), carrying the four
# framework-owned sections INLINE at whatever version they installed, and no carrier import.
function New-LegacyConsumer {
    param([string]$Stack)
    $t = Join-Path ([IO.Path]::GetTempPath()) "b97update-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
    Set-Content (Join-Path $t 'CLAUDE.md') @"
<!--
ai-tech-lead-framework
  version: $staleVersion
  applied: 2026-07-01
-->
# Acme Billing

## Verification Rules

1. **Verify before you reference.** (stale inline copy as shipped at $staleVersion)

## Leanness

3. **No abstract base class with one subclass.** (stale inline copy)

## SOLID

(stale inline copy)

## Conventions

Repo-specific conventions the consumer owns. Populated by /bootstrap. DO NOT CLOBBER.

## Agentic Workflow

### 1. Classify the intent (stale inline copy)
"@ -Encoding utf8
    Set-Content (Join-Path $t 'AGENTS.md') "# AGENTS`n`nGENERATED FILE`n" -Encoding utf8
    Set-Content (Join-Path $t '.claude/framework-version.json') "{`"version`": `"$staleVersion`"}" -Encoding utf8
    Set-Content (Join-Path $t '.claude/settings.json') "{`n  `"consumerEdit`": `"recover me`"`n}`n" -Encoding utf8
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/skills/add-warehouse-load') | Out-Null
    Set-Content (Join-Path $t '.claude/skills/add-warehouse-load/SKILL.md') "---`nname: add-warehouse-load`n---`n# Old framework body`n`nFor a concrete current instance in this repo, see ``warehouse/LoadSales.sql`` — reproduce its **conventions and structure**, not its contents; CLAUDE.md > Conventions wins on any conflict.`n" -Encoding utf8
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/skills/local-release') | Out-Null
    Set-Content (Join-Path $t '.claude/skills/local-release/SKILL.md') "---`nname: local-release`norigin: discovered`n---`n# Consumer recipe`n" -Encoding utf8
    Set-Content (Join-Path $t 'LEARNINGS.md') "## Disabled framework skill: perf`nDisabled: 2026-08-01`nReason: not used here.`n" -Encoding utf8
    return $t
}

function Invoke-Installer {
    param([string]$Twin, [string]$Dist, [string]$Target, [switch]$AllowDirtyTree)
    $inst = Join-Path $repoRoot "dist/$Dist/scripts/install.$Twin"
    if ($Twin -eq 'ps1') {
        if ($AllowDirtyTree) { & (Get-PsExe) -NoProfile -File $inst -Target $Target -AllowDirtyTree 2>&1 | Out-String }
        else { & (Get-PsExe) -NoProfile -File $inst -Target $Target 2>&1 | Out-String }
    } else {
        if ($AllowDirtyTree) { & $bash $inst --allow-dirty-tree $Target 2>&1 | Out-String }
        else { & $bash $inst $Target 2>&1 | Out-String }
    }
}

function Get-Hash { param([string]$P) (Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash }

Reset-Tests

foreach ($twin in @('ps1', 'sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Skip "update delivery ($twin)" 'no bash on this host'; continue }
    $dist = 'dotnet'
    $target = New-LegacyConsumer -Stack $dist
    $claudePath = Join-Path $target 'CLAUDE.md'
    $carrierPath = Join-Path $target $carrierRel

    $before = Get-Hash $claudePath
    $out = Invoke-Installer -Twin $twin -Dist $dist -Target $target
    $installExit = $LASTEXITCODE

    It "update completes and reports success ($twin)" {
        Assert ($installExit -eq 0) "update exited ${installExit}: $out"
        Assert ($out -match 'Done \(update\)') "update did not print its completion banner: $out"
    }

    It "update mode is detected ($twin)" {
        Assert ($out -match 'mode: update') "installer did not enter update mode. stdout:`n$out"
    }

    It "update disclosure precedes the first target mutation ($twin)" {
        $preflightAt = $out.IndexOf('UPDATE PREFLIGHT: This update replaces framework-owned files, including .claude/settings.json.')
        $backupAt = $out.IndexOf('saved pre-update settings: .claude/.state/settings.json.pre-update')
        Assert ($preflightAt -ge 0) "update preflight disclosure was absent. stdout:`n$out"
        Assert ($out -match 'committed, stashed, or copied') 'update preflight omitted the preservation action'
        Assert ($out -match 'Review the resulting diff before committing') 'update preflight omitted diff review'
        Assert ($backupAt -gt $preflightAt) "settings backup (the first target mutation) was reported before the disclosure. stdout:`n$out"
    }

    It "settings backup is named and round-trips the consumer edit before refresh ($twin)" {
        $backup = Join-Path $target '.claude/.state/settings.json.pre-update'
        Assert (Test-Path -LiteralPath $backup -PathType Leaf) 'rolling settings backup was not created'
        Assert ((Get-Content -LiteralPath $backup -Raw) -match 'recover me') 'consumer settings edit was not recoverable from the backup'
        Assert (-not ((Get-Content -LiteralPath (Join-Path $target '.claude/settings.json') -Raw) -match 'recover me')) 'framework settings were not refreshed after backup'
    }

    # THE assertion. If this ever fails, the framework is destroying consumer content.
    It "update leaves the protected CLAUDE.md byte-identical ($twin)" {
        Assert ((Get-Hash $claudePath) -eq $before) 'update mode modified CLAUDE.md -- the v0.20.0 protection has regressed'
    }

    It "update delivers the unprotected carrier ($twin)" {
        Assert (Test-Path -LiteralPath $carrierPath) "carrier $carrierRel was not installed"
        $shipped = Get-Hash (Join-Path $repoRoot "dist/$dist/$carrierRel")
        Assert ((Get-Hash $carrierPath) -eq $shipped) 'installed carrier does not match the shipped one'
    }

    It "update refreshes framework skills while preserving consumer ownership ($twin)" {
        $warehouse = Get-Content (Join-Path $target '.claude/skills/add-warehouse-load/SKILL.md') -Raw
        Assert ($warehouse -match 'Bind to the dimensions that already exist') 'the current framework body was not delivered'
        Assert ($warehouse -match 'warehouse/LoadSales.sql') 'the consumer exemplar was lost'
        Assert ((Get-Content (Join-Path $target '.claude/skills/local-release/SKILL.md') -Raw) -match 'Consumer recipe') 'origin: discovered skill was overwritten'
        Assert (-not (Test-Path (Join-Path $target '.claude/skills/perf'))) 'disabled framework skill was reactivated'
        Assert (Test-Path (Join-Path $target '.claude/disabled-skills/perf/SKILL.md')) 'disabled framework skill was not refreshed in its inactive location'
        Assert (Test-Path (Join-Path $target '.claude/framework-update-backup/skills')) 'one-time pre-update skill archive was not created'
    }

    # The un-migrated consumer must be TOLD, on both surfaces (meta-invariant #5).
    It "session-start emits the migration pointer on both surfaces ($twin)" {
        $hook = Join-Path $target ".claude/hooks/session-start.$twin"
        Assert (Test-Path -LiteralPath $hook) "session-start.$twin missing from the installed repo"
        Push-Location $target
        try {
            $claude = Invoke-Hook -Path $hook -Json '{"hook_event_name":"SessionStart"}'
            $copilot = Invoke-Hook -Path $hook -Json '{"event":"sessionStart"}'
        } finally { Pop-Location }
        Assert ($claude.Out -match 'Framework rules migration') "Claude surface: no pointer. stdout:`n$($claude.Out)"
        Assert ($copilot.Out -match 'additionalContext') 'Copilot surface: output was not the JSON additionalContext shape'
        Assert ($copilot.Out -match 'Framework rules migration') 'Copilot surface: pointer absent from additionalContext'
    }

    It "doctor reports MISSING delivery and defers protected-file sync ($twin)" {
        $doc = Join-Path $target "scripts/framework-doctor.$twin"
        Push-Location $target
        try {
            if ($twin -eq 'ps1') { $d = & (Get-PsExe) -NoProfile -File $doc 2>&1 | Out-String }
            else { $d = & $bash $doc 2>&1 | Out-String }
        } finally { Pop-Location }
        Assert ($d -match '\[MISSING\][^\r\n]*Framework rules delivery') "no MISSING delivery row. output:`n$d"
        # The sync row used to say DIVERGED here, from a version-stamp comparison that could not
        # see migration state at all. An un-migrated consumer's stale stamp is expected, not a
        # finding, and the delivery row above already states the problem and its fix -- so this row
        # defers rather than double-reporting.
        Assert ($d -match 'Protected-file sync[^\r\n]*deferred to Framework rules delivery') "sync row did not defer. output:`n$d"
        Assert ($d -notmatch 'DIVERGED') 'the version-proxy DIVERGED verdict is back'
        Assert ($d -notmatch 'you are behind') 'doctor claimed "you are behind" -- it cannot know that'
    }

    # The half-migrated consumer: import added, stale inline sections left in place. This is the
    # state the shipped pointer's "and delete them" exists to prevent, and nothing verified it.
    It "doctor names the sections a half-migrated consumer must still delete ($twin)" {
        $doc = Join-Path $target "scripts/framework-doctor.$twin"
        $before = Get-Content $claudePath -Raw
        try {
            Set-Content $claudePath ($importLine + "`n`n" + $before) -Encoding utf8
            Push-Location $target
            try {
                if ($twin -eq 'ps1') { $d = & (Get-PsExe) -NoProfile -File $doc 2>&1 | Out-String }
                else { $d = & $bash $doc 2>&1 | Out-String }
            } finally { Pop-Location }
            Assert ($d -match '\[PENDING\][^\r\n]*Protected-file sync') "half-migrated consumer not reported PENDING. output:`n$d"
            Assert ($d -match 'Verification Rules') 'the row did not name the sections still inline'
            Assert ($d -notmatch 'Boy Scout') 'Boy Scout Rule was flagged -- it stays in CLAUDE.md by design'
        } finally { Set-Content $claudePath $before -Encoding utf8 }
    }

    # Perform the one-time migration the pointer asks for, then prove the noise stops.
    It "migrating silences the pointer and clears the doctor rows ($twin)" {
        $migrated = (Get-Content $claudePath -Raw) -replace '(?ms)^## Verification Rules.*?(?=^## Conventions)', "$importLine`n`n"
        $migrated = $migrated -replace '(?ms)^## Agentic Workflow.*$', ''
        $current = (Get-Content (Join-Path $repoRoot "dist/$dist/.claude/framework-version.json") -Raw)
        if ($current -match '"version"\s*:\s*"([^"]+)"') { $migrated = $migrated -replace "version: $staleVersion", "version: $($matches[1])" }
        Set-Content $claudePath $migrated -Encoding utf8
        $hook = Join-Path $target ".claude/hooks/session-start.$twin"
        $doc = Join-Path $target "scripts/framework-doctor.$twin"
        Push-Location $target
        try {
            $s = Invoke-Hook -Path $hook -Json '{"hook_event_name":"SessionStart"}'
            if ($twin -eq 'ps1') { $d = & (Get-PsExe) -NoProfile -File $doc 2>&1 | Out-String }
            else { $d = & $bash $doc 2>&1 | Out-String }
        } finally { Pop-Location }
        Assert ($s.Out -notmatch 'Framework rules migration') "pointer still fires after migration:`n$($s.Out)"
        Assert ($d -match '\[OK\][^\r\n]*Framework rules delivery') "delivery row not OK after migration. output:`n$d"
        Assert ($d -notmatch 'DIVERGED') 'sync row still DIVERGED after the stamp was bumped'
    }

    # The carrier is framework-owned. Overwriting a consumer edit is DELIBERATE -- assert it, so the
    # behaviour is disclosed and cannot drift into "sometimes preserved".
    It "a consumer-edited carrier is overwritten on the next update ($twin)" {
        Add-Content -LiteralPath $carrierPath -Value "`nCONSUMER EDIT THAT MUST NOT SURVIVE`n"
        Invoke-Installer -Twin $twin -Dist $dist -Target $target | Out-Null
        $after = Get-Content -LiteralPath $carrierPath -Raw
        Assert ($after -notmatch 'CONSUMER EDIT THAT MUST NOT SURVIVE') 'the carrier is framework-owned but a consumer edit survived update'
    }

    Remove-Item -Recurse -Force $target -ErrorAction SilentlyContinue
}

foreach ($twin in @('ps1', 'sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Skip "brownfield copy-if-absent wiki ($twin)" 'no bash on this host'; continue }
    It "brownfield leaves the copy-if-absent wiki index active and unarchived ($twin)" {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-wiki-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Force -Path (Join-Path $t 'docs/wiki') | Out-Null
        Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value 'BROWNFIELD SIGNAL' -Encoding utf8
        Set-Content -LiteralPath (Join-Path $t 'docs/wiki/INDEX.md') -Value 'CONSUMER WIKI INDEX SENTINEL' -Encoding utf8
        try {
            Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t | Out-Null
            $wiki = Join-Path $t 'docs/wiki/INDEX.md'
            $archiveRel = 'docs/pre-adoption/docs/wiki/INDEX.md'
            Assert ([IO.File]::ReadAllText($wiki).Contains('CONSUMER WIKI INDEX SENTINEL')) 'brownfield replaced a copy-if-absent wiki index'
            Assert (-not (Test-Path -LiteralPath (Join-Path $t $archiveRel))) 'brownfield unnecessarily archived a copy-if-absent wiki index'
            $marker = Get-Content -LiteralPath (Join-Path $t '.claude/adoption-pending.json') -Raw | ConvertFrom-Json
            Assert (-not ($marker.archivedOriginals -contains $archiveRel)) 'adoption marker listed a copy-if-absent wiki index as archived'
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }
}

# Recovery increment 1: these fixtures are deliberately run against the composed, unfixed dist
# first. Each sentinel is a consumer byte that v0.72.0 loses: settings/hooks/commands on
# brownfield, audit state on both modes, and a GitHub-only skill on update. The update fixture
# seeds a protected file so both baseline twins reach their post-copy GitHub-skill sync path.
function New-NoLossBrownfieldConsumer {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-brown-' + [guid]::NewGuid())
    foreach ($rel in @('.claude/commands', '.github/hooks', '.github/skills/local-only')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $t $rel) | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value 'BROWNFIELD SIGNAL' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $t '.claude/settings.json') -Value 'SETTINGS SENTINEL' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $t '.github/hooks/hooks.json') -Value 'HOOKS SENTINEL' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $t '.claude/commands/feature.md') -Value 'COMMAND SENTINEL' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $t '.github/skills/local-only/SKILL.md') -Value 'GITHUB-ONLY SKILL SENTINEL' -Encoding utf8
    [IO.File]::WriteAllBytes((Join-Path $t '.claude/ai-audit.log'), [byte[]](0, 1, 2, 255, 10, 13, 0))
    return $t
}

function Assert-BytesEqual {
    param([byte[]]$Expected, [byte[]]$Actual, [string]$Message)
    Assert ($Expected.Length -eq $Actual.Length -and
        [Convert]::ToBase64String($Expected) -ceq [Convert]::ToBase64String($Actual)) $Message
}

function New-ArchiveEscapeLink {
    param([Parameter(Mandatory)][string]$Link, [Parameter(Mandatory)][string]$Target)
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
    if ($env:OS -eq 'Windows_NT') { New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null }
    else { New-Item -ItemType SymbolicLink -Path $Link -Target $Target | Out-Null }
}

# Both directions matter. A destination link leaks archived originals outside the repository;
# a source-side link lets the installer mutate a collision that was never inside it. These run
# against the composed dotnet installer because path semantics are runtime behavior, not prose.
foreach ($twin in @('ps1', 'sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Skip "brownfield archive escape ($twin)" 'no bash on this host'; continue }
    It "brownfield refuses a reparse/symlink archive destination before moving originals ($twin)" {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-dest-link-' + [guid]::NewGuid())
        $outside = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-outside-' + [guid]::NewGuid())
        $collision = '.github/instructions/framework-rules.instructions.md'
        try {
            New-Item -ItemType Directory -Force -Path (Join-Path $t 'docs') | Out-Null
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $t $collision)) | Out-Null
            New-ArchiveEscapeLink -Link (Join-Path $t 'docs/pre-adoption') -Target $outside
            Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value 'BROWNFIELD SIGNAL' -Encoding utf8
            Set-Content -LiteralPath (Join-Path $t $collision) -Value 'DESTINATION ESCAPE SENTINEL' -Encoding utf8
            $out = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -ne 0) "archive destination reparse/symlink did not refuse. Output:`n$out"
            Assert ($out -match 'reparse/symlink') "archive destination refusal did not identify the reparse/symlink. Output:`n$out"
            Assert ([IO.File]::ReadAllText((Join-Path $t $collision)).Contains('DESTINATION ESCAPE SENTINEL')) 'archive destination preflight moved the original before refusing'
            Assert (@(Get-ChildItem -LiteralPath $outside -Recurse -Force -ErrorAction SilentlyContinue).Count -eq 0) 'archive destination escape wrote outside the target'
        } finally { Remove-Item -Recurse -Force $t,$outside -ErrorAction SilentlyContinue }
    }

    It "brownfield refuses a reparse/symlink collision source before moving originals ($twin)" {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-source-link-' + [guid]::NewGuid())
        $outside = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-source-outside-' + [guid]::NewGuid())
        $collision = '.github/instructions/framework-rules.instructions.md'
        try {
            New-Item -ItemType Directory -Force -Path $t | Out-Null
            New-ArchiveEscapeLink -Link (Join-Path $t '.github') -Target $outside
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $t $collision)) | Out-Null
            Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value 'BROWNFIELD SIGNAL' -Encoding utf8
            Set-Content -LiteralPath (Join-Path $t $collision) -Value 'SOURCE ESCAPE SENTINEL' -Encoding utf8
            $out = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -ne 0) "collision source reparse/symlink did not refuse. Output:`n$out"
            Assert ($out -match 'reparse/symlink') "collision source refusal did not identify the reparse/symlink. Output:`n$out"
            Assert ([IO.File]::ReadAllText((Join-Path $t $collision)).Contains('SOURCE ESCAPE SENTINEL')) 'source reparse/symlink preflight moved the outside original'
            Assert (-not (Test-Path -LiteralPath (Join-Path $t 'docs/pre-adoption'))) 'source reparse/symlink preflight mutated the target before refusing'
        } finally { Remove-Item -Recurse -Force $t,$outside -ErrorAction SilentlyContinue }
    }
}

foreach ($twin in @('ps1', 'sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Skip "no-loss lifecycle ($twin)" 'no bash on this host'; continue }
    It "brownfield archives every incoming collision and preserves audit state ($twin)" {
        $t = New-NoLossBrownfieldConsumer
        $auditBefore = [IO.File]::ReadAllBytes((Join-Path $t '.claude/ai-audit.log'))
        try {
            $out = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "brownfield install failed (exit $LASTEXITCODE): $out"
            foreach ($case in @(
                @{ Rel = '.claude/settings.json'; Text = 'SETTINGS SENTINEL' },
                @{ Rel = '.github/hooks/hooks.json'; Text = 'HOOKS SENTINEL' },
                @{ Rel = '.claude/commands/feature.md'; Text = 'COMMAND SENTINEL' }
            )) {
                $archiveRel = "docs/pre-adoption/$($case.Rel)"
                $archive = Join-Path $t $archiveRel
                Assert (Test-Path -LiteralPath $archive -PathType Leaf) "brownfield collision $($case.Rel) was not archived at its exact original-relative path"
                Assert ((Get-Content -LiteralPath $archive -Raw) -match $case.Text) "brownfield collision $($case.Rel) lost its sentinel"
                $marker = Get-Content -LiteralPath (Join-Path $t '.claude/adoption-pending.json') -Raw | ConvertFrom-Json
                Assert ($marker.archivedOriginals -contains $archiveRel) "adoption marker omitted archive mapping $archiveRel"
            }
            Assert-BytesEqual -Expected $auditBefore -Actual ([IO.File]::ReadAllBytes((Join-Path $t '.claude/ai-audit.log'))) -Message 'brownfield overwrote persistent ai-audit.log bytes'
            Assert ((Get-Content -LiteralPath (Join-Path $t '.github/skills/local-only/SKILL.md') -Raw) -match 'GITHUB-ONLY SKILL SENTINEL') 'brownfield deleted an unknown GitHub-only skill'

            $update = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "update install failed (exit $LASTEXITCODE): $update"
            Assert-BytesEqual -Expected $auditBefore -Actual ([IO.File]::ReadAllBytes((Join-Path $t '.claude/ai-audit.log'))) -Message 'update overwrote persistent ai-audit.log bytes'
            Assert ((Get-Content -LiteralPath (Join-Path $t '.github/skills/local-only/SKILL.md') -Raw) -match 'GITHUB-ONLY SKILL SENTINEL') 'update deleted an unknown GitHub-only skill'
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }

    It "archive-destination collision refuses before target mutation ($twin)" {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-preflight-' + [guid]::NewGuid())
        $collision = '.github/instructions/framework-rules.instructions.md'
        $archive = Join-Path $t "docs/pre-adoption/$collision"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $t $collision)) | Out-Null
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $archive) | Out-Null
        Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value 'BROWNFIELD SIGNAL' -Encoding utf8
        Set-Content -LiteralPath (Join-Path $t $collision) -Value 'ORIGINAL COLLISION SENTINEL' -Encoding utf8
        Set-Content -LiteralPath $archive -Value 'EARLIER ARCHIVE SENTINEL' -Encoding utf8
        try {
            $out = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -ne 0) "pre-existing archive destination did not refuse. Output:`n$out"
            Assert ($out -match 'archive destination') "refusal did not identify the archive collision. Output:`n$out"
            Assert ((Get-Content -LiteralPath (Join-Path $t $collision) -Raw) -match 'ORIGINAL COLLISION SENTINEL') 'preflight mutated the original collision before refusing'
            Assert ((Get-Content -LiteralPath $archive -Raw) -match 'EARLIER ARCHIVE SENTINEL') 'preflight replaced an earlier archive'
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }
}

# Keep only the collision class not already exercised by the combined lifecycle fixture above.
# The former audit/command/GitHub repetitions each performed another full install while asserting
# a strict subset of that fixture's postconditions.
foreach ($twin in @('ps1', 'sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Skip "independent no-loss evidence ($twin)" 'no bash on this host'; continue }
    It "brownfield archives a same-path skill collision from the manifest ($twin)" {
        $t = New-NoLossBrownfieldConsumer
        $skillRel = '.claude/skills/add-endpoint/SKILL.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $t $skillRel)) | Out-Null
        Set-Content -LiteralPath (Join-Path $t $skillRel) -Value 'SKILL COLLISION SENTINEL' -Encoding utf8
        try {
            Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t | Out-Null
            $archive = Join-Path $t "docs/pre-adoption/$skillRel"
            Assert (Test-Path -LiteralPath $archive -PathType Leaf) 'same-path skill collision was not archived before replacement'
            Assert ([IO.File]::ReadAllText($archive).Contains('SKILL COLLISION SENTINEL')) 'same-path skill archive lost its sentinel'
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }

}

# The preservation check itself must have a constructible failure world; otherwise it could be a
# vacuous assertion that passes even when both installer and fixture are wrong.
It 'audit-byte preservation assertion rejects a deliberately mutated fixture' {
    $expected = [byte[]](0, 1, 2, 255)
    $mutated = [byte[]](0, 1, 99, 255)
    $rejected = $false
    try { Assert-BytesEqual -Expected $expected -Actual $mutated -Message 'deliberate mutation must fail' } catch { $rejected = $true }
    Assert $rejected 'audit preservation assertion accepted a deliberately mutated fixture'
}

foreach ($twin in @('ps1', 'sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Skip "dirty-tree safety ($twin)" 'no bash on this host'; continue }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Skip "dirty-tree safety ($twin)" 'git is unavailable'; continue }
    It "dirty Git update refuses before mutation and explicit override is observable ($twin)" {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-dirty-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
        Set-Content -LiteralPath (Join-Path $t '.claude/framework-version.json') -Value '{"version":"0.72.0"}' -Encoding utf8
        Set-Content -LiteralPath (Join-Path $t '.claude/ai-audit.log') -Value 'DIRTY AUDIT SENTINEL' -Encoding utf8
        try {
            & git -C $t init -q
            & git -C $t config user.email 'tests@example.invalid'
            & git -C $t config user.name 'installer tests'
            Set-Content -LiteralPath (Join-Path $t 'tracked.txt') -Value 'clean' -Encoding utf8
            & git -C $t add .
            & git -C $t commit -qm initial
            Set-Content -LiteralPath (Join-Path $t 'tracked.txt') -Value 'dirty' -Encoding utf8
            $before = Get-Content -LiteralPath (Join-Path $t 'tracked.txt') -Raw
            $out = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -ne 0) "dirty Git target was mutated without refusal. Output:`n$out"
            Assert ($out -match 'commit, stash, or copy') "dirty-tree refusal omitted recovery action. Output:`n$out"
            Assert ((Get-Content -LiteralPath (Join-Path $t 'tracked.txt') -Raw) -eq $before) 'dirty-tree preflight mutated the target before refusing'
            $override = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t -AllowDirtyTree
            Assert ($LASTEXITCODE -eq 0) "explicit dirty-tree override failed (exit $LASTEXITCODE): $override"
            Assert ($override -match 'override: .*allow-dirty-tree') "dirty-tree override was not named on stdout. Output:`n$override"
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }
}

foreach ($twin in @('ps1', 'sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Skip "brownfield dirty-tree safety ($twin)" 'no bash on this host'; continue }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Skip "brownfield dirty-tree safety ($twin)" 'git is unavailable'; continue }
    It "dirty Git brownfield refuses before mutation and explicit override is observable ($twin)" {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-brown-dirty-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Force -Path $t | Out-Null
        try {
            & git -C $t init -q
            & git -C $t config user.email 'tests@example.invalid'
            & git -C $t config user.name 'installer tests'
            Set-Content -LiteralPath (Join-Path $t 'tracked.txt') -Value 'clean' -Encoding utf8
            & git -C $t add .
            & git -C $t commit -qm initial
            Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value 'DIRTY BROWNFIELD SENTINEL' -Encoding utf8
            $before = Get-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Raw
            $out = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -ne 0) "dirty Git brownfield target was mutated without refusal. Output:`n$out"
            Assert ($out -match 'commit, stash, or copy') "brownfield dirty-tree refusal omitted recovery action. Output:`n$out"
            Assert ((Get-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Raw) -eq $before) 'brownfield dirty-tree preflight mutated the target before refusing'
            $override = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t -AllowDirtyTree
            Assert ($LASTEXITCODE -eq 0) "explicit brownfield dirty-tree override failed (exit $LASTEXITCODE): $override"
            Assert ($override -match 'override: .*allow-dirty-tree') "brownfield dirty-tree override was not named on stdout. Output:`n$override"
            Assert (Test-Path -LiteralPath (Join-Path $t 'docs/pre-adoption/TECH_DEBT.md') -PathType Leaf) 'explicit brownfield override did not complete the collision archive'
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }
}

# The legal-file preflight owns exit 3 and runs before every update mutation. Keep its v0.54.0
# refusal contract intact, and prove a failed update never prints the success-only completion banner.
foreach ($twin in @('ps1','sh')) {
    if ($twin -eq 'sh' -and -not $bash) { continue }
    foreach ($case in @(
        @{ Rel = 'LICENSES/ai-tech-lead-MIT.txt'; Text = 'consumer licence'; Message = "Refusing to overwrite 'LICENSES/ai-tech-lead-MIT.txt': the existing file is not identical to the framework licence." },
        @{ Rel = 'NOTICE-ai-tech-lead.md'; Text = 'consumer notice'; Message = "Refusing to overwrite 'NOTICE-ai-tech-lead.md': the existing file is not marked FRAMEWORK-OWNED." }
    )) {
        It "legal-file refusal remains exit 3 without an update completion banner ($twin, $($case.Rel))" {
            $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-legal-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $t $case.Rel)) | Out-Null
            Set-Content -LiteralPath (Join-Path $t '.claude/framework-version.json') -Value '{"version":"0.55.0"}' -Encoding utf8
            Set-Content -LiteralPath (Join-Path $t $case.Rel) -Value $case.Text -Encoding utf8
            try {
                $out = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t
                $code = $LASTEXITCODE
                Assert ($code -eq 3) "legal-file refusal exit changed from 3 to $code. Output:`n$out"
                Assert ($out -match [regex]::Escape($case.Message)) "legal-file refusal message changed. Output:`n$out"
                Assert ($out -notmatch 'Done \(update\)') "failed update printed the success-only completion banner. Output:`n$out"
            } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
        }
    }
}

exit (Write-TestSummary 'UpdateDelivery.Tests')
