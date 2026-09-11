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
    $t = (Resolve-Path -LiteralPath $t).Path
    Assert ($t.StartsWith([IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) 'b81license-')), [StringComparison]::OrdinalIgnoreCase)) 'licence fixture resolved outside its expected temporary-directory prefix'
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

function Get-PriorLicenseText {
    # Historical fixture stays in this maintainer-only test; no old licence artifact ships.
    $prior = (Get-LfText (Join-Path $repoRoot "src/core/$licenseRel")).Replace('ai-tech-lead contributors', 'Costas Andreou')
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($prior)))).Replace('-', '').ToLowerInvariant()
    } finally { $sha.Dispose() }
    Assert ($hash -ceq '14d518c3282ed071127059700be0498802c3a89ddeca37e42150445f93a04e17') 'historical licence fixture no longer matches the frozen released-content hash'
    return $prior
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

    foreach ($dist in @('dotnet', 'angular', 'monorepo')) {
        foreach ($mode in @('adoption', 'update')) {
            It "$mode migrates the exact prior licence with LF and CRLF ($dist)" {
                $prior = Get-PriorLicenseText
                $current = Get-LfText (Join-Path $repoRoot "dist/$dist/$licenseRel")
                Assert ($current -cne $prior) 'migration fixture must differ from the current shipped licence'
                foreach ($ending in @('LF', 'CRLF')) {
                    $t = New-LicenseTarget -Update:($mode -eq 'update')
                    if ($mode -eq 'adoption') {
                        Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value '# existing debt' -Encoding UTF8
                    }
                    $p = Join-Path $t $licenseRel
                    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null
                    $fixture = if ($ending -eq 'CRLF') { $prior.Replace("`n", "`r`n") } else { $prior }
                    [IO.File]::WriteAllText($p, $fixture, [Text.UTF8Encoding]::new($false))
                    try {
                        $r = Invoke-LicenseInstaller -Target $t -Dist $dist
                        Assert ($r.Exit -eq 0) "$ending prior-licence $mode exited $($r.Exit): $($r.Out)"
                        Assert ((Get-LfText $p) -ceq $current) "$ending prior licence was not replaced with the current shipped notice"
                        if ($mode -eq 'adoption') {
                            Assert (Test-Path -LiteralPath (Join-Path $t '.claude/adoption-pending.json')) "$ending fixture did not exercise adoption mode"
                        } else {
                            Assert ((Get-LfText (Join-Path $t '.claude/framework-version.json')) -ceq (Get-LfText (Join-Path $repoRoot "dist/$dist/.claude/framework-version.json"))) "$ending update did not install the current framework stamp"
                            Assert ($r.Out -notmatch ('left untouched[^\r\n]*' + [regex]::Escape($licenseRel))) "$ending update falsely reported the migrated licence as untouched"
                        }
                    } finally { Remove-Item -Recurse -Force -LiteralPath $t -ErrorAction SilentlyContinue }
                }
            }

            foreach ($change in @('attribution', 'terms')) {
                It "$mode refuses a prior licence with changed $change before mutation ($dist)" {
                    $prior = Get-PriorLicenseText
                    $fixture = if ($change -eq 'attribution') {
                        $prior.Replace('Costas Andreou', 'Consumer Modified')
                    } else {
                        $prior.Replace('free of charge', 'subject to a fee')
                    }
                    Assert ($fixture -cne $prior) "$change hostile fixture did not change the prior licence"
                    $t = New-LicenseTarget -Update:($mode -eq 'update')
                    if ($mode -eq 'adoption') {
                        Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value '# existing debt' -Encoding UTF8
                    }
                    $stamp = Join-Path $t '.claude/framework-version.json'
                    $stampBefore = if ($mode -eq 'update') { [Convert]::ToBase64String([IO.File]::ReadAllBytes($stamp)) } else { $null }
                    $p = Join-Path $t $licenseRel
                    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null
                    [IO.File]::WriteAllText($p, $fixture, [Text.UTF8Encoding]::new($false))
                    $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($p))
                    try {
                        $r = Invoke-LicenseInstaller -Target $t -Dist $dist
                        Assert ($r.Exit -eq 3) "prior licence with changed $change did not refuse with exit 3: exit=$($r.Exit). output: $($r.Out)"
                        Assert ($r.Out -match [regex]::Escape($licenseRel)) "refusal did not name $licenseRel. output: $($r.Out)"
                        Assert ($r.Out -notmatch '(?m)^Done') 'refusal printed installer completion before stopping'
                        Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($p)) -ceq $before) 'modified prior licence was changed despite refusal'
                        Assert (-not (Test-Path -LiteralPath (Join-Path $t $noticeRel))) 'refusal installed the framework notice before stopping'
                        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/adoption-pending.json'))) 'refusal created an adoption marker before stopping'
                        if ($mode -eq 'update') {
                            Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($stamp)) -ceq $stampBefore) 'refusal changed the existing framework stamp before stopping'
                        } else {
                            Assert (-not (Test-Path -LiteralPath $stamp)) 'refusal installed a framework stamp before stopping'
                        }
                    } finally { Remove-Item -Recurse -Force -LiteralPath $t -ErrorAction SilentlyContinue }
                }
            }
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
