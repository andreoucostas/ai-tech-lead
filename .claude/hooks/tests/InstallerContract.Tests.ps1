# Asserts the SHIPPED installer prints the agent-handoff contract -- in every dist, in BOTH modes,
# from BOTH twins. Does NOT ship.
#
# Why this exists: the installer's closing message is the one surface an installing AI agent is
# guaranteed to see (it fires at the moment the agent acts, whatever doc it did or didn't read).
# Its text was therefore load-bearing -- and nothing tested it. The greenfield branch had quietly
# drifted weaker than the brownfield one: it omitted "or replicate it by hand", and never warned
# that docs-sync-check fails BY DESIGN until /bootstrap runs. A real agent duly copied the files
# and walked away without committing them, and a red docs-sync-check reads to an agent as a bug to
# fix. Fixed in v0.26.3; this is the gate that keeps it fixed (meta/LEARNINGS.md, 2026-07-12).
#
# The contract is asserted as BEHAVIOR (run the installer, read stdout), not as prose in a source
# file -- which is the only way to catch a mode branch that silently stops printing it.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$bash = Get-BashPath

# Every mode must state ALL of these. They are the things an agent gets wrong without them:
# leaves files uncommitted / thinks it may finish / hand-rolls the populate step / "fixes" a red check.
$contract = @(
    @{ Name = 'tells the agent to COMMIT the copied files'; Pattern = 'commit the copied files' },
    @{ Name = 'tells the agent its task is NOT complete until it hands off'; Pattern = 'NOT complete until' },
    @{ Name = 'forbids hand-replicating the populate command'; Pattern = 'replicate it by hand' },
    @{ Name = 'warns docs-sync-check is red BY DESIGN until populate runs'; Pattern = 'by design|until /(bootstrap|adopt) has run' }
    @{ Name = 'tells every developer to run framework-doctor locally'; Pattern = 'Each developer should run.+framework-doctor' }
)

function New-Target {
    param([ValidateSet('greenfield', 'brownfield')][string]$Mode, [string]$Stack)
    $t = Join-Path ([IO.Path]::GetTempPath()) "instcontract-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    if ($Stack -in @('dotnet', 'monorepo')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $t 'api') | Out-Null
        Set-Content (Join-Path $t 'api/Api.csproj') '<Project Sdk="Microsoft.NET.Sdk.Web"></Project>' -Encoding utf8
    }
    if ($Stack -in @('angular', 'monorepo')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $t 'web') | Out-Null
        Set-Content (Join-Path $t 'web/angular.json') '{"version":1}' -Encoding utf8
    }
    # An adoption signal is what flips greenfield -> brownfield. TECH_DEBT.md is one of them, so its
    # mere presence selects the /adopt branch; greenfield targets must carry NONE of them.
    if ($Mode -eq 'brownfield') { Set-Content (Join-Path $t 'TECH_DEBT.md') '# debt' -Encoding utf8 }
    $t
}

Reset-Tests

foreach ($dist in @('dotnet', 'angular', 'monorepo')) {
    foreach ($mode in @('greenfield', 'brownfield')) {
        $expectCmd = if ($mode -eq 'greenfield') { '/bootstrap' } else { '/adopt' }

        foreach ($twin in @('ps1', 'sh')) {
            $label = "$dist/$mode/$twin"

            if ($twin -eq 'sh' -and -not $bash) { Skip "installer contract: $label" 'no bash on this host'; continue }

            $target = New-Target -Mode $mode -Stack $dist
            $inst = Join-Path $repoRoot "dist/$dist/scripts/install.$twin"
            try {
                if ($twin -eq 'ps1') { $out = & (Get-PsExe) -NoProfile -File $inst $target 2>&1 | Out-String }
                else { $out = & $bash $inst $target 2>&1 | Out-String }

                It "installer states the whole agent contract: $label" {
                    Assert ($out -match 'IF YOU ARE AN AI AGENT') `
                        "$label : no agent-addressed block at all. An installing agent is the primary reader of this output."
                    foreach ($c in $contract) {
                        Assert ($out -match $c.Pattern) `
                            "$label : installer never $($c.Name) (no match for /$($c.Pattern)/). Agents get this wrong without being told."
                    }
                    Assert ($out -match [regex]::Escape($expectCmd)) `
                        "$label : never names $expectCmd -- the developer is left with a half-installed repo."
                    # The wrong populate command is worse than none: /bootstrap on a brownfield repo
                    # skips the archive/merge/provenance flow the installer just staged.
                    $wrongCmd = if ($mode -eq 'greenfield') { '/adopt' } else { '/bootstrap' }
                    if ($mode -eq 'greenfield') {
                        Assert (-not ($out -match [regex]::Escape($wrongCmd))) "$label : names $wrongCmd, which is the other mode's command"
                    }
                }
            }
            finally { Remove-Item -Recurse -Force $target -ErrorAction SilentlyContinue }
        }
    }
}

exit (Write-TestSummary 'InstallerContract.Tests (shipped installer prints the agent contract)')
