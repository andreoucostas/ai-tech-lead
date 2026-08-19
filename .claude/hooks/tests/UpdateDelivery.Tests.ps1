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
    param([string]$Twin, [string]$Dist, [string]$Target)
    $inst = Join-Path $repoRoot "dist/$Dist/scripts/install.$Twin"
    if ($Twin -eq 'ps1') { & (Get-PsExe) -NoProfile -File $inst $Target 2>&1 | Out-String }
    else { & $bash $inst $Target 2>&1 | Out-String }
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

# Brownfield collision: a pre-existing file at the carrier path must be archived, not destroyed.
foreach ($twin in @('ps1', 'sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Skip "brownfield carrier collision ($twin)" 'no bash on this host'; continue }
    It "brownfield archives a pre-existing carrier with provenance ($twin)" {
        $t = Join-Path ([IO.Path]::GetTempPath()) "b97brown-$(Get-Random)"
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.github/instructions') | Out-Null
        Set-Content (Join-Path $t 'TECH_DEBT.md') '# debt' -Encoding utf8   # adoption signal -> brownfield
        Set-Content (Join-Path $t $carrierRel) 'PRE-EXISTING CONSUMER INSTRUCTIONS' -Encoding utf8
        try {
            Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t | Out-Null
            $archived = @(Get-ChildItem -Recurse -Force -LiteralPath (Join-Path $t 'docs/pre-adoption') -ErrorAction SilentlyContinue |
                Where-Object { -not $_.PSIsContainer -and (Get-Content -LiteralPath $_.FullName -Raw) -match 'PRE-EXISTING CONSUMER INSTRUCTIONS' })
            Assert ($archived.Count -ge 1) 'the pre-existing carrier was destroyed rather than archived to docs/pre-adoption/'
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }
}

# An UPDATE must SUCCEED, and both twins must agree that it did. This is not a formality: the bash
# installer runs under `set -euo pipefail`, and its disabled-skill restore pipes a grep whose
# NO-MATCH case is the normal one. pipefail promoted that to a pipeline failure and -e aborted the
# whole installer -- after the files were copied but before the "Done (update)" banner -- so every
# update exited 1 with no error text while install.ps1 exited 0. A consumer wiring the documented
# installer into CI saw a red pipeline on a good install, and an AI agent running it saw a bare
# failure. Greenfield masked it because a different branch ran last, which is why exit code alone is
# not enough here: assert the completion banner too, or a future early abort passes again.
It 'an update completes and reports success on both twins, for every dist' {
    foreach ($dist in @('dotnet','angular','monorepo')) {
        foreach ($twin in @('ps1','sh')) {
            if ($twin -eq 'sh' -and -not $bash) { continue }
            $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-exit-' + [guid]::NewGuid())
            New-Item -ItemType Directory -Force $t | Out-Null
            try {
                $first = Invoke-Installer -Twin $twin -Dist $dist -Target $t
                Assert ($LASTEXITCODE -eq 0) "$dist/$twin greenfield install failed (exit $LASTEXITCODE): $first"
                Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/.state/settings.json.pre-update'))) "$dist/$twin greenfield created an update-only settings backup"
                $second = Invoke-Installer -Twin $twin -Dist $dist -Target $t
                $code = $LASTEXITCODE
                Assert ($code -eq 0) "$dist/$twin UPDATE exited $code; a successful update must exit 0. Output:`n$second"
                Assert ($second -match 'Done \(update\)') "$dist/$twin update did not print its completion banner, so it aborted part-way even though it exited 0. Output:`n$second"
            } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
        }
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
