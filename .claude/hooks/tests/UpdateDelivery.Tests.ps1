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

    It "doctor reports MISSING delivery and DIVERGED sync ($twin)" {
        $doc = Join-Path $target "scripts/framework-doctor.$twin"
        Push-Location $target
        try {
            if ($twin -eq 'ps1') { $d = & (Get-PsExe) -NoProfile -File $doc 2>&1 | Out-String }
            else { $d = & $bash $doc 2>&1 | Out-String }
        } finally { Pop-Location }
        Assert ($d -match '\[MISSING\][^\r\n]*Framework rules delivery') "no MISSING delivery row. output:`n$d"
        Assert ($d -match 'DIVERGED') 'no DIVERGED protected-file-sync row'
        Assert ($d -notmatch 'you are behind') 'doctor claimed "you are behind" -- it cannot know that (B-97 finding 5)'
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

exit (Write-TestSummary 'UpdateDelivery.Tests')
