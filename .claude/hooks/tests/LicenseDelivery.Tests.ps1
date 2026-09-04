# Asserts B-81's legal-file delivery contract by running the SHIPPED installers against real temp
# directories. Does NOT ship.
#
# These paths cannot use the ordinary protected/unprotected split: protection would freeze a stale
# framework notice, while ordinary bulk copying would destroy a consumer collision. The ownership
# policy is therefore asserted on the supported PowerShell installer, including every refusal path.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$licenseRel = 'LICENSES/ai-tech-lead-MIT.txt'
$noticeRel = 'NOTICE-ai-tech-lead.md'

function New-LicenseTarget {
    param([switch]$Update)
    $t = Join-Path ([IO.Path]::GetTempPath()) "b81license-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    if ($Update) {
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
        Set-Content -LiteralPath (Join-Path $t '.claude/framework-version.json') -Value '{"version":"0.53.0"}' -Encoding UTF8
    }
    return $t
}

function Invoke-LicenseInstaller {
    param([string]$Target, [string]$Dist = 'dotnet')
    $inst = Join-Path $repoRoot "dist/$Dist/scripts/install.ps1"
    $ef = [IO.Path]::GetTempFileName()
    try {
        $out = & (Get-PsExe) -NoProfile -File $inst $Target 2>$ef
        [pscustomobject]@{ Exit = $LASTEXITCODE; Out = (($out -join "`n") + [IO.File]::ReadAllText($ef)) }
    } finally { Remove-Item -Force -LiteralPath $ef -ErrorAction SilentlyContinue }
}

function Get-LfText([string]$Path) {
    return ([IO.File]::ReadAllText($Path) -replace "`r`n", "`n" -replace "`r", "`n")
}

Reset-Tests
    foreach ($dist in @('dotnet', 'angular', 'monorepo')) {
        It "greenfield creates the licence and notice with the shipped content ($dist)" {
            $t = New-LicenseTarget
            try {
                $r = Invoke-LicenseInstaller -Target $t -Dist $dist
                Assert ($r.Exit -eq 0) "greenfield install exited $($r.Exit): $($r.Out)"
                foreach ($rel in @($licenseRel, $noticeRel)) {
                    Assert (Test-Path -LiteralPath (Join-Path $t $rel)) "$rel was not installed"
                    Assert ((Get-LfText (Join-Path $t $rel)) -eq (Get-LfText (Join-Path $repoRoot "dist/$dist/$rel"))) "$rel differs from the shipped file"
                }
            } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
        }

        It "brownfield without a legal collision creates both files ($dist)" {
            $t = New-LicenseTarget
            Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value '# existing debt' -Encoding UTF8
            try {
                $r = Invoke-LicenseInstaller -Target $t -Dist $dist
                Assert ($r.Exit -eq 0) "brownfield install exited $($r.Exit): $($r.Out)"
                Assert (Test-Path -LiteralPath (Join-Path $t $licenseRel)) "$licenseRel was not installed"
                Assert (Test-Path -LiteralPath (Join-Path $t $noticeRel)) "$noticeRel was not installed"
                Assert (Test-Path -LiteralPath (Join-Path $t '.claude/adoption-pending.json')) 'fixture did not exercise brownfield mode'
            } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
        }
    }

    foreach ($rel in @($licenseRel, $noticeRel)) {
        It "brownfield refuses a conflicting $rel without changing it" {
            $t = New-LicenseTarget
            Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value '# existing debt' -Encoding UTF8
            $p = Join-Path $t $rel
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null
            [IO.File]::WriteAllText($p, "CONSUMER CONTENT`n", [Text.UTF8Encoding]::new($false))
            $before = [IO.File]::ReadAllBytes($p)
            try {
                $r = Invoke-LicenseInstaller -Target $t
                Assert ($r.Exit -ne 0) "conflicting $rel was accepted"
                Assert ($r.Out -match [regex]::Escape($rel)) "refusal did not name $rel. output: $($r.Out)"
                Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -eq [Convert]::ToBase64String($before)) "$rel was changed despite refusal"
                Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/adoption-pending.json'))) 'refusal mutated the target before stopping'
                Write-Host "[observed refusal] exit=$($r.Exit) path=$rel message=$($r.Out.Trim())"
            } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
        }
    }

    It 'update replaces a stale framework-owned notice' {
        $t = New-LicenseTarget -Update
        $p = Join-Path $t $noticeRel
        [IO.File]::WriteAllText($p, "<!-- FRAMEWORK-OWNED — stale -->`nOLD NOTICE`n", [Text.UTF8Encoding]::new($false))
        try {
            $r = Invoke-LicenseInstaller -Target $t
            Assert ($r.Exit -eq 0) "update exited $($r.Exit): $($r.Out)"
            Assert ((Get-LfText $p) -eq (Get-LfText (Join-Path $repoRoot "dist/dotnet/$noticeRel"))) 'stale framework-owned notice was not replaced'
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }

    It 'update leaves an LF-normalised-identical licence byte-untouched' {
        $t = New-LicenseTarget -Update
        $p = Join-Path $t $licenseRel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null
        $crlf = (Get-LfText (Join-Path $repoRoot "dist/dotnet/$licenseRel")) -replace "`n", "`r`n"
        [IO.File]::WriteAllText($p, $crlf, [Text.UTF8Encoding]::new($false))
        $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($p))
        try {
            $r = Invoke-LicenseInstaller -Target $t
            Assert ($r.Exit -eq 0) "update exited $($r.Exit): $($r.Out)"
            Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -eq $before) 'LF-normalised-identical licence was rewritten instead of left untouched'
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }

    It 'update refuses a notice whose ownership marker was removed' {
        $t = New-LicenseTarget -Update
        $p = Join-Path $t $noticeRel
        [IO.File]::WriteAllText($p, "CONSUMER-MODIFIED NOTICE`n", [Text.UTF8Encoding]::new($false))
        $before = [IO.File]::ReadAllBytes($p)
        try {
            $r = Invoke-LicenseInstaller -Target $t
            Assert ($r.Exit -ne 0) 'consumer-modified notice was accepted'
            Assert ($r.Out -match [regex]::Escape($noticeRel)) "refusal did not name $noticeRel. output: $($r.Out)"
            Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -eq [Convert]::ToBase64String($before)) 'consumer-modified notice was changed despite refusal'
            Write-Host "[observed refusal] exit=$($r.Exit) path=$noticeRel message=$($r.Out.Trim())"
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }
exit (Write-TestSummary 'LicenseDelivery.Tests')
