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
#   PROTECTED  (CLAUDE.md and the append-only ADR log) -> update leaves consumer bytes identical.
#   UNPROTECTED (carrier)                              -> update overwrites it, even if edited.
# A regression in either direction is invisible in a diff and catastrophic in the field, which is
# why this is asserted by running the installer rather than by reading its source.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

# The one line an update prints for the copies it saves, all below one folder Git ignores (B-429).
$b429BlanketLine = "kept out of Git: every copy this update saves goes under \.claude/framework-update-backup/, whose \.gitignore ends with '\*', so Git ignores the whole folder\."
$carrierRel = '.github/instructions/framework-rules.instructions.md'
$importLine = '@.github/instructions/framework-rules.instructions.md'
# At the retirement ledger's floor (0.76.0): an older stamp is refused, and names -Reinstall.
$staleVersion = '0.76.0'
$learningsFixtureText = "## Disabled framework skill: perf`t`r`nDisabled: 2026-08-01`r`nReason: not used here.`r`n"
[byte[]]$learningsExpectedBytes = @(
    0xEF, 0xBB, 0xBF, 0x23, 0x23, 0x20, 0x44, 0x69, 0x73, 0x61, 0x62, 0x6C, 0x65, 0x64,
    0x20, 0x66, 0x72, 0x61, 0x6D, 0x65, 0x77, 0x6F, 0x72, 0x6B, 0x20, 0x73, 0x6B, 0x69,
    0x6C, 0x6C, 0x3A, 0x20, 0x70, 0x65, 0x72, 0x66, 0x09, 0x0D, 0x0A, 0x44, 0x69, 0x73,
    0x61, 0x62, 0x6C, 0x65, 0x64, 0x3A, 0x20, 0x32, 0x30, 0x32, 0x36, 0x2D, 0x30, 0x38,
    0x2D, 0x30, 0x31, 0x0D, 0x0A, 0x52, 0x65, 0x61, 0x73, 0x6F, 0x6E, 0x3A, 0x20, 0x6E,
    0x6F, 0x74, 0x20, 0x75, 0x73, 0x65, 0x64, 0x20, 0x68, 0x65, 0x72, 0x65, 0x2E, 0x0D,
    0x0A
)

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
    # A hand-written AGENTS.md (no generated-mirror banner): the B-272 layout migration must decline
    # it, so this consumer keeps its pre-B-272 CLAUDE.md and exercises the B-97 carrier pointer.
    Set-Content (Join-Path $t 'AGENTS.md') "# AGENTS`n`nconsumer-authored notes`n" -Encoding utf8
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.github') | Out-Null
    [IO.File]::WriteAllText((Join-Path $t '.github/copilot-instructions.md'), "# Consumer Copilot rules`r`nconsumer sentinel`r`n", [Text.UTF8Encoding]::new($false))
    Set-Content (Join-Path $t '.claude/framework-version.json') "{`"version`": `"$staleVersion`"}" -Encoding utf8
    Set-Content (Join-Path $t '.claude/settings.json') "{`n  `"consumerEdit`": `"recover me`"`n}`n" -Encoding utf8
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/skills/add-warehouse-load') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/skills/add-warehouse-load/references') | Out-Null
    [IO.File]::WriteAllText((Join-Path $t '.claude/skills/add-warehouse-load/SKILL.md'), "---`nname: add-warehouse-load`n---`n# Old framework body`n`nFor a concrete current instance in this repo, see ``warehouse/LoadSales.sql`` — reproduce its **conventions and structure**, not its contents; CLAUDE.md > Conventions wins on any conflict.`n", [Text.UTF8Encoding]::new($false))
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/skills/local-release') | Out-Null
    Set-Content (Join-Path $t '.claude/skills/local-release/SKILL.md') "---`nname: local-release`norigin: discovered`n---`n# Consumer recipe`n" -Encoding utf8
    [IO.File]::WriteAllBytes((Join-Path $t '.claude/skills/add-warehouse-load/references/project-pattern.md'), [Text.UTF8Encoding]::new($false).GetBytes("# Consumer project pattern`r`ncomposition-root: Unity`r`nlifetime: scoped`r`n"))
    # A protected ledger can be written by PS5 with a BOM and CRLF. The trailing HT is already
    # admitted by the heading grammar and keeps dirty extraction observable even if a host masks CR.
    [IO.File]::WriteAllText((Join-Path $t 'LEARNINGS.md'), $learningsFixtureText, [Text.UTF8Encoding]::new($true))
    return $t
}

function Invoke-Installer {
    param([string]$Dist, [string]$Target, [switch]$AllowDirtyTree)
    $installer = Join-Path $repoRoot "dist/$Dist/scripts/install.ps1"
    if ($AllowDirtyTree) { & (Get-PsExe) -NoProfile -File $installer -Target $Target -AllowDirtyTree 2>&1 | Out-String }
    else { & (Get-PsExe) -NoProfile -File $installer -Target $Target 2>&1 | Out-String }
}

function Get-Hash { param([string]$P) (Get-FileHash -LiteralPath $P -Algorithm SHA256).Hash }

function Assert-BytesEqual {
    param([byte[]]$Expected, [byte[]]$Actual, [string]$Message)
    Assert ($Expected.Length -eq $Actual.Length -and
        [Convert]::ToBase64String($Expected) -ceq [Convert]::ToBase64String($Actual)) $Message
}

function Normalize-SkillText {
    param([string]$Text)
    return ([regex]::Replace($Text, '\r\n?', "`n")).TrimEnd([char]10)
}

# B-194's three grouped tests deliberately retain every subprocess result before their first
# assertion.  This small capture helper also keeps native stdout and stderr separate, which is the
# contract the installer itself must preserve when probing optional Git.
function Invoke-B194Process {
    param(
        [string]$Executable,
        [string[]]$Arguments = @(),
        [hashtable]$Environment = @{}
    )
    $stdoutFile = [IO.Path]::GetTempFileName()
    $stderrFile = [IO.Path]::GetTempFileName()
    $saved = @{}
    $started = $false
    $exitCode = $null
    $stdout = ''
    $exception = ''
    $priorPreference = $ErrorActionPreference
    try {
        foreach ($name in $Environment.Keys) {
            $saved[$name] = [Environment]::GetEnvironmentVariable([string]$name, 'Process')
            if ($null -eq $Environment[$name]) {
                Remove-Item -LiteralPath ("Env:" + [string]$name) -Force -ErrorAction SilentlyContinue
            } else {
                [Environment]::SetEnvironmentVariable([string]$name, [string]$Environment[$name], 'Process')
            }
        }
        if (-not $Executable -or -not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
            throw "executable is unavailable: '$Executable'"
        }
        $started = $true
        # Start-Process joins ArgumentList into one Windows command line. Quote whitespace-bearing
        # atoms explicitly so Git config values such as `user.name=B194 fixture` remain one argv.
        $processArguments = @($Arguments | ForEach-Object {
            $argument = [string]$_
            if ($argument -match '[\s"]') { '"' + $argument.Replace('"', '\"') + '"' } else { $argument }
        })
        # Under the aggregate runner this suite executes inside a background job alongside other
        # process-heavy suites. Windows can transiently reject the cross-host PS7 -> PS5.1 launch
        # with Win32 error 5 even though the identical launch succeeds immediately in isolation.
        # Retry only that launch failure; a persistent refusal still returns CANT-VERIFY below.
        $child = $null
        for ($launchAttempt = 1; $launchAttempt -le 5; $launchAttempt++) {
            try {
                $child = Start-Process -FilePath $Executable -ArgumentList $processArguments -NoNewWindow -Wait -PassThru `
                    -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
                break
            } catch {
                $nativeError = if ($_.Exception -is [ComponentModel.Win32Exception]) {
                    $_.Exception.NativeErrorCode
                } elseif ($_.Exception.InnerException -is [ComponentModel.Win32Exception]) {
                    $_.Exception.InnerException.NativeErrorCode
                } else { $null }
                $isTransientAccessRefusal = $nativeError -eq 5 -or $_.Exception.Message -match '(?i)access is denied'
                if (-not $isTransientAccessRefusal -or $launchAttempt -eq 5) { throw }
                Start-Sleep -Milliseconds (200 * $launchAttempt)
            }
        }
        if ($null -eq $child) { throw 'child process launch returned no process' }
        $exitCode = [int]$child.ExitCode
    } catch {
        $started = $false
        $exception = $_.Exception.Message
    } finally {
        $ErrorActionPreference = $priorPreference
        foreach ($name in $Environment.Keys) {
            if ($null -eq $saved[$name]) {
                Remove-Item -LiteralPath ("Env:" + [string]$name) -Force -ErrorAction SilentlyContinue
            } else {
                [Environment]::SetEnvironmentVariable([string]$name, [string]$saved[$name], 'Process')
            }
        }
    }
    try { $stdout = [IO.File]::ReadAllText($stdoutFile).Replace("`r`n", "`n").TrimEnd("`n") } catch { $stdout = $_.Exception.Message }
    try { $stderr = [IO.File]::ReadAllText($stderrFile) } catch { $stderr = $_.Exception.Message }
    # PowerShell serializes progress records to redirected stderr as CLIXML. They are transport
    # noise, not installer diagnostics; retain any CLIXML that also carries a real error token.
    if ($stderr.StartsWith('#< CLIXML') -and $stderr -notmatch '(?i)CANT-VERIFY|ERROR:|Cannot|Exception|fatal') { $stderr = '' }
    try { [IO.File]::Delete($stdoutFile) } catch { }
    try { [IO.File]::Delete($stderrFile) } catch { }
    [pscustomobject]@{
        Started = $started
        Exit = $exitCode
        Out = $stdout
        Err = $stderr
        Exception = $exception
    }
}

function Invoke-B194Installer {
    param(
        [string]$Target,
        [string]$PowerShellExe,
        [hashtable]$Environment = @{}
    )
    $isolated = @{
        GIT_DIR = $null
        GIT_WORK_TREE = $null
        GIT_COMMON_DIR = $null
        GIT_INDEX_FILE = $null
    }
    foreach ($name in $Environment.Keys) { $isolated[$name] = $Environment[$name] }
    $installer = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
    if ($isolated.ContainsKey('B194_PS_PATH')) {
        # pwsh prepends its own directory to an inherited PATH at startup, so the controlled PATH is
        # applied inside the child. The values travel as environment variables to a -File launcher:
        # Microsoft Defender blocks the equivalent -EncodedCommand launch as Trojan:Win32/Commando.A!ml,
        # which surfaced here as "Access is denied".
        $isolated['B194_CHILD_PATH'] = [string]$isolated['B194_PS_PATH']
        $isolated.Remove('B194_PS_PATH')
        $isolated['B194_CHILD_INSTALLER'] = $installer
        $isolated['B194_CHILD_TARGET'] = $Target
        $launcher = Join-Path ([IO.Path]::GetTempPath()) ('b194-launch-' + [guid]::NewGuid().ToString('N') + '.ps1')
        [IO.File]::WriteAllText($launcher, @'
$env:PATH = $env:B194_CHILD_PATH
& $env:B194_CHILD_INSTALLER -Target $env:B194_CHILD_TARGET
$code = $LASTEXITCODE
if ($code -in @(2, 3, 4)) { exit $code }
exit 0
'@, [Text.UTF8Encoding]::new($true))
        try {
            return Invoke-B194Process -Executable $PowerShellExe -Arguments @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $launcher
            ) -Environment $isolated
        } finally { Remove-Item -LiteralPath $launcher -Force -ErrorAction SilentlyContinue }
    }
    return Invoke-B194Process -Executable $PowerShellExe -Arguments @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer, '-Target', $Target
    ) -Environment $isolated
}

function New-B194UpdateTarget {
    param([string]$Parent, [string]$Name)
    $target = Join-Path $Parent $Name
    New-Item -ItemType Directory -Force -Path (Join-Path $target '.claude') | Out-Null
    [IO.File]::WriteAllText((Join-Path $target '.claude/framework-version.json'), "{`"version`":`"0.78.2`"}`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $target '.claude/settings.json'), "{`n  `"consumerEdit`": `"B194 SETTINGS SENTINEL`"`n}`n", [Text.UTF8Encoding]::new($false))
    # Already on the B-272 layout (CLAUDE.md imports AGENTS.md), so update must leave it untouched.
    [IO.File]::WriteAllText((Join-Path $target 'CLAUDE.md'), "@AGENTS.md`nB194 PROTECTED UPDATE SENTINEL`n", [Text.UTF8Encoding]::new($false))
    return $target
}

function New-B194BrownfieldTarget {
    param([string]$Parent, [string]$Name)
    $target = Join-Path $Parent $Name
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    [IO.File]::WriteAllText((Join-Path $target 'TECH_DEBT.md'), "B194 BROWNFIELD ARCHIVE SENTINEL`n", [Text.UTF8Encoding]::new($false))
    return $target
}

function Get-B194Fingerprint {
    param([string]$Root)
    $rootPath = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $entries = [System.Collections.Generic.List[string]]::new()
    foreach ($item in @(Get-ChildItem -LiteralPath $rootPath -Force -Recurse -ErrorAction Stop)) {
        $relative = $item.FullName.Substring($rootPath.Length).TrimStart([char[]]@('\','/')).Replace('\','/')
        if ($item.PSIsContainer) {
            $entries.Add("D|$relative")
        } else {
            $hash = (Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
            $entries.Add("F|$relative|$hash")
        }
    }
    $payload = [Text.UTF8Encoding]::new($false).GetBytes((($entries | Sort-Object -CaseSensitive) -join "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($payload))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Add-B194CaptureProblem {
    param([System.Collections.Generic.List[string]]$Problems, [string]$Label, $Capture)
    if (-not $Capture.Started) { $Problems.Add("${Label}: child did not start ($($Capture.Exception))") | Out-Null }
}

function Add-B194SuccessProblems {
    param([System.Collections.Generic.List[string]]$Problems, [string]$Label, $Capture, [string]$Completion)
    Add-B194CaptureProblem -Problems $Problems -Label $Label -Capture $Capture
    if ($Capture.Exit -ne 0) { $Problems.Add("${Label}: exit $($Capture.Exit); stdout=[$($Capture.Out)]; stderr=[$($Capture.Err)]") | Out-Null }
    if ($Capture.Out -notmatch $Completion) { $Problems.Add("${Label}: completion banner missing; stdout=[$($Capture.Out)]") | Out-Null }
    if ($Capture.Err) { $Problems.Add("${Label}: unexpected stderr=[$($Capture.Err)]") | Out-Null }
}

function Add-B194RefusalProblems {
    param([System.Collections.Generic.List[string]]$Problems, [string]$Label, $Capture, [string]$Before, [string]$After)
    Add-B194CaptureProblem -Problems $Problems -Label $Label -Capture $Capture
    if ($Capture.Exit -ne 4) { $Problems.Add("${Label}: expected exit 4, got $($Capture.Exit); stdout=[$($Capture.Out)]; stderr=[$($Capture.Err)]") | Out-Null }
    if (($Capture.Out + "`n" + $Capture.Err) -notmatch 'CANT-VERIFY') { $Problems.Add("${Label}: CANT-VERIFY missing") | Out-Null }
    if (($Capture.Out + "`n" + $Capture.Err) -match 'Done \(update\)|Done - but this repo|Done\. Next steps') { $Problems.Add("${Label}: refusal printed a completion banner") | Out-Null }
    if ($Before -cne $After) { $Problems.Add("${Label}: target fingerprint changed ($Before -> $After)") | Out-Null }
}

function Add-B194ExpectedProcessProblems {
    param([System.Collections.Generic.List[string]]$Problems, [string]$Label, $Capture, [int]$ExpectedExit)
    Add-B194CaptureProblem -Problems $Problems -Label $Label -Capture $Capture
    if ($Capture.Exit -ne $ExpectedExit) {
        $Problems.Add("${Label}: expected setup exit $ExpectedExit, got $($Capture.Exit); stdout=[$($Capture.Out)]; stderr=[$($Capture.Err)]") | Out-Null
    }
}

function Test-B194BytesEqual {
    param([byte[]]$Left, [byte[]]$Right)
    return ($Left.Length -eq $Right.Length -and
        [Convert]::ToBase64String($Left) -ceq [Convert]::ToBase64String($Right))
}

function Initialize-B194GitTarget {
    param([string]$Target, [string]$GitExe, [hashtable]$Environment = @{})
    $steps = [System.Collections.Generic.List[object]]::new()
    foreach ($step in @(
        @{ Name = 'init'; Args = @('-C', $Target, 'init', '-q') },
        @{ Name = 'add'; Args = @('-C', $Target, 'add', '.') },
        @{ Name = 'commit'; Args = @('-C', $Target, '-c', 'user.name=B194 fixture', '-c', 'user.email=b194@example.invalid', 'commit', '-qm', 'initial') }
    )) {
        $steps.Add([pscustomobject]@{
            Label = "$Target $($step.Name)"
            Capture = (Invoke-B194Process -Executable $GitExe -Arguments $step.Args -Environment $Environment)
            ExpectedExit = 0
        }) | Out-Null
    }
    return $steps.ToArray()
}

Reset-Tests

$powerShellExtension = 'ps1'
& {
    $dist = 'dotnet'
    $target = New-LegacyConsumer -Stack $dist
    $claudePath = Join-Path $target 'CLAUDE.md'
    $legacySkillPath = Join-Path $target '.claude/skills/add-warehouse-load/SKILL.md'
    $legacySkillBefore = [IO.File]::ReadAllBytes($legacySkillPath)
    $carrierPath = Join-Path $target $carrierRel
    $adrPath = Join-Path $target 'docs/architecture-decisions.md'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $adrPath) | Out-Null
    [IO.File]::WriteAllText($adrPath, "# Architecture Decisions`n`n## ADR-042: Consumer sentinel`n- **Decision**: preserve these bytes.`n", [Text.UTF8Encoding]::new($false))

    $before = Get-Hash $claudePath
    $agentsPath = Join-Path $target 'AGENTS.md'
    $agentsBefore = [IO.File]::ReadAllBytes($agentsPath)
    $copilotPath = Join-Path $target '.github/copilot-instructions.md'
    $copilotBefore = [IO.File]::ReadAllBytes($copilotPath)
    $adrBefore = [IO.File]::ReadAllBytes($adrPath)
    $learningsPath = Join-Path $target 'LEARNINGS.md'
    $learningsBefore = [IO.File]::ReadAllBytes($learningsPath)
    $patternPath = Join-Path $target '.claude/skills/add-warehouse-load/references/project-pattern.md'
    $patternBefore = [IO.File]::ReadAllBytes($patternPath)
    $out = Invoke-Installer -Dist $dist -Target $target
    $installExit = $LASTEXITCODE

    It "update completes and reports success ($powerShellExtension)" {
        Assert ($installExit -eq 0) "update exited ${installExit}: $out"
        Assert ($out -match 'Done \(update\)') "update did not print its completion banner: $out"
    }

    It "update mode is detected ($powerShellExtension)" {
        Assert ($out -match 'mode: update') "installer did not enter update mode. stdout:`n$out"
    }

    It "update disclosure precedes the first target mutation ($powerShellExtension)" {
        $preflightAt = $out.IndexOf('UPDATE PREFLIGHT: This update replaces framework-owned files, including .claude/settings.json.')
        $backupAt = $out.IndexOf('saved pre-update settings: .claude/.state/settings.json.pre-update')
        Assert ($preflightAt -ge 0) "update preflight disclosure was absent. stdout:`n$out"
        Assert ($out -match 'committed, stashed, or copied') 'update preflight omitted the preservation action'
        Assert ($out -match 'Review the resulting diff before committing') 'update preflight omitted diff review'
        Assert ($backupAt -gt $preflightAt) "settings backup (the first target mutation) was reported before the disclosure. stdout:`n$out"
    }

    It "settings backup is named and round-trips the consumer edit before refresh ($powerShellExtension)" {
        $backup = Join-Path $target '.claude/.state/settings.json.pre-update'
        Assert (Test-Path -LiteralPath $backup -PathType Leaf) 'rolling settings backup was not created'
        Assert ((Get-Content -LiteralPath $backup -Raw) -match 'recover me') 'consumer settings edit was not recoverable from the backup'
        Assert (-not ((Get-Content -LiteralPath (Join-Path $target '.claude/settings.json') -Raw) -match 'recover me')) 'framework settings were not refreshed after backup'
    }

    # THE assertions. If either fails, the framework is destroying consumer content.
    It "update leaves protected consumer documents byte-identical ($powerShellExtension)" {
        Assert ((Get-Hash $claudePath) -eq $before) 'update mode modified CLAUDE.md -- the v0.20.0 protection has regressed'
        Assert-BytesEqual -Expected $agentsBefore -Actual ([IO.File]::ReadAllBytes($agentsPath)) -Message 'update mode modified protected AGENTS.md'
        Assert-BytesEqual -Expected $copilotBefore -Actual ([IO.File]::ReadAllBytes($copilotPath)) -Message 'update mode modified protected copilot instructions'
        Assert-BytesEqual -Expected $adrBefore -Actual ([IO.File]::ReadAllBytes($adrPath)) -Message 'update mode replaced the consumer append-only ADR log'
        Assert-BytesEqual -Expected $learningsExpectedBytes -Actual $learningsBefore -Message 'disabled-skill fixture was not exact BOM + HT + CRLF input'
        Assert-BytesEqual -Expected $learningsBefore -Actual ([IO.File]::ReadAllBytes($learningsPath)) -Message 'update mode modified the protected disabled-skill ledger'
        Assert ($out -match '(?m)^PLAN preserve docs/architecture-decisions\.md\r?$') "update operation plan did not classify the consumer ADR log as preserved. Output:`n$out"
        Assert ($out -match 'AGENTS\.md is not the retired generated mirror') "a declined layout migration was not reported. Output:`n$out"
        Assert-BytesEqual -Expected $patternBefore -Actual ([IO.File]::ReadAllBytes($patternPath)) -Message 'ordinary update modified consumer-owned project-pattern sidecar'
    }

    It "update delivers the unprotected carrier ($powerShellExtension)" {
        Assert (Test-Path -LiteralPath $carrierPath) "carrier $carrierRel was not installed"
        $shipped = Get-Hash (Join-Path $repoRoot "dist/$dist/$carrierRel")
        Assert ((Get-Hash $carrierPath) -eq $shipped) 'installed carrier does not match the shipped one'
        Assert ((Get-Content -LiteralPath $carrierPath -Raw).Contains('Every bug-fix edit must be necessary')) 'installed framework-owned carrier omitted the B-231 scope'
    }

    It "update refreshes framework skills while preserving consumer ownership ($powerShellExtension)" {
        $warehousePath = Join-Path $target '.claude/skills/add-warehouse-load/SKILL.md'
        $warehouse = [IO.File]::ReadAllText($warehousePath, [Text.UTF8Encoding]::new($false))
        $shippedWarehouse = [IO.File]::ReadAllText((Join-Path $repoRoot "dist/$dist/.claude/skills/add-warehouse-load/SKILL.md"))
        $consumerExemplar = 'For a concrete current instance in this repo, see `warehouse/LoadSales.sql` — reproduce its **conventions and structure**, not its contents; CLAUDE.md > Conventions wins on any conflict.'
        $legacyHasBom = $legacySkillBefore.Length -ge 3 -and $legacySkillBefore[0] -eq 0xEF -and $legacySkillBefore[1] -eq 0xBB -and $legacySkillBefore[2] -eq 0xBF
        $legacySkillText = [Text.UTF8Encoding]::new($false, $true).GetString($legacySkillBefore)
        Assert (-not $legacyHasBom) 'consumer exemplar fixture unexpectedly has a UTF-8 BOM'
        Assert ($legacySkillText.Contains([string][char]0x2014)) 'consumer exemplar fixture lost its non-ASCII em dash'
        $withoutConsumerExemplar = [regex]::Replace($warehouse, '(?m)^' + [regex]::Escape($consumerExemplar) + '\r?\n?', '')
        Assert ((Normalize-SkillText $withoutConsumerExemplar) -ceq (Normalize-SkillText $shippedWarehouse)) 'installed framework skill body does not exactly match the shipped framework body after removing only the preserved consumer exemplar'
        Assert ($warehouse.Contains($consumerExemplar)) 'the exact non-ASCII consumer exemplar was not preserved'
        Assert ($warehouse -match 'warehouse/LoadSales.sql') 'the consumer exemplar was lost'
        Assert ((Get-Content (Join-Path $target '.claude/skills/local-release/SKILL.md') -Raw) -match 'Consumer recipe') 'origin: discovered skill was overwritten'
        Assert (-not (Test-Path (Join-Path $target '.claude/skills/perf'))) 'disabled framework skill was reactivated'
        Assert (Test-Path (Join-Path $target '.claude/disabled-skills/perf/SKILL.md')) 'disabled framework skill was not refreshed in its inactive location'
        Assert (Test-Path (Join-Path $target '.claude/framework-update-backup/skills')) 'one-time pre-update skill archive was not created'
    }

    # The re-append rewrites a framework-owned file, so its bytes must not depend on the host: Windows
    # PowerShell 5.1's Set-Content -Encoding UTF8 added a BOM and a CRLF after the text's own newline.
    It "a skill whose exemplar is re-appended has no BOM and ends in exactly one newline ($powerShellExtension)" {
        $bytes = [IO.File]::ReadAllBytes((Join-Path $target '.claude/skills/add-warehouse-load/SKILL.md'))
        Assert (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) 'the rewritten SKILL.md starts with a UTF-8 BOM'
        $n = $bytes.Length
        Assert ($n -ge 2 -and $bytes[$n - 1] -eq 0x0A -and $bytes[$n - 2] -ne 0x0A -and $bytes[$n - 2] -ne 0x0D) "the rewritten SKILL.md does not end in exactly one LF (last bytes: $($bytes[($n - 3)..($n - 1)] -join ','))"
    }

    # The un-migrated consumer must be TOLD, on both surfaces (meta-invariant #5).
    It "session-start emits the migration pointer on both surfaces ($powerShellExtension)" {
        $hook = Join-Path $target ".claude/hooks/session-start.$powerShellExtension"
        Assert (Test-Path -LiteralPath $hook) "session-start.$powerShellExtension missing from the installed repo"
        Push-Location $target
        try {
            $claude = Invoke-Hook -Path $hook -Json '{"hook_event_name":"SessionStart"}'
            $copilot = Invoke-Hook -Path $hook -Json '{"event":"sessionStart"}'
        } finally { Pop-Location }
        Assert ($claude.Out -match 'Framework rules migration') "Claude surface: no pointer. stdout:`n$($claude.Out)"
        Assert ($copilot.Out -match 'additionalContext') 'Copilot surface: output was not the JSON additionalContext shape'
        Assert ($copilot.Out -match 'Framework rules migration') 'Copilot surface: pointer absent from additionalContext'
    }

    It "doctor reports MISSING delivery and defers protected-file sync ($powerShellExtension)" {
        $doc = Join-Path $target "scripts/framework-doctor.$powerShellExtension"
        Push-Location $target
        try {
            $d = & (Get-PsExe) -NoProfile -File $doc 2>&1 | Out-String
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
    It "doctor names the sections a half-migrated consumer must still delete ($powerShellExtension)" {
        $doc = Join-Path $target "scripts/framework-doctor.$powerShellExtension"
        $before = Get-Content $claudePath -Raw
        try {
            Set-Content $claudePath ($importLine + "`n`n" + $before) -Encoding utf8
            Push-Location $target
            try {
                $d = & (Get-PsExe) -NoProfile -File $doc 2>&1 | Out-String
            } finally { Pop-Location }
            Assert ($d -match '\[PENDING\][^\r\n]*Protected-file sync') "half-migrated consumer not reported PENDING. output:`n$d"
            Assert ($d -match 'Verification Rules') 'the row did not name the sections still inline'
            Assert ($d -notmatch 'Boy Scout') 'Boy Scout Rule was flagged -- it stays in CLAUDE.md by design'
        } finally { Set-Content $claudePath $before -Encoding utf8 }
    }

    # Perform the one-time migration the pointer asks for, then prove the noise stops.
    It "migrating silences the pointer and clears the doctor rows ($powerShellExtension)" {
        $migrated = (Get-Content $claudePath -Raw) -replace '(?ms)^## Verification Rules.*?(?=^## Conventions)', "$importLine`n`n"
        $migrated = $migrated -replace '(?ms)^## Agentic Workflow.*$', ''
        $current = (Get-Content (Join-Path $repoRoot "dist/$dist/.claude/framework-version.json") -Raw)
        if ($current -match '"version"\s*:\s*"([^"]+)"') { $migrated = $migrated -replace "version: $staleVersion", "version: $($matches[1])" }
        Set-Content $claudePath $migrated -Encoding utf8
        $hook = Join-Path $target ".claude/hooks/session-start.$powerShellExtension"
        $doc = Join-Path $target "scripts/framework-doctor.$powerShellExtension"
        Push-Location $target
        try {
            $s = Invoke-Hook -Path $hook -Json '{"hook_event_name":"SessionStart"}'
            $d = & (Get-PsExe) -NoProfile -File $doc 2>&1 | Out-String
        } finally { Pop-Location }
        Assert ($s.Out -notmatch 'Framework rules migration') "pointer still fires after migration:`n$($s.Out)"
        Assert ($d -match '\[OK\][^\r\n]*Framework rules delivery') "delivery row not OK after migration. output:`n$d"
        Assert ($d -notmatch 'DIVERGED') 'sync row still DIVERGED after the stamp was bumped'
    }

    # The carrier is framework-owned. Overwriting a consumer edit is DELIBERATE -- assert it, so the
    # behaviour is disclosed and cannot drift into "sometimes preserved".
    It "a consumer-edited carrier is overwritten on the next update ($powerShellExtension)" {
        Add-Content -LiteralPath $carrierPath -Value "`nCONSUMER EDIT THAT MUST NOT SURVIVE`n"
        Invoke-Installer -Dist $dist -Target $target | Out-Null
        $after = Get-Content -LiteralPath $carrierPath -Raw
        Assert ($after -notmatch 'CONSUMER EDIT THAT MUST NOT SURVIVE') 'the carrier is framework-owned but a consumer edit survived update'
    }

    Remove-Item -Recurse -Force $target -ErrorAction SilentlyContinue
}

# B-272: the older layout (instructions in CLAUDE.md, AGENTS.md a generated mirror) moves once.
# Consumer text survives byte-for-byte in the backups and line-for-line in AGENTS.md; only the
# template lines that describe the old layout, and the import that moves to the stub, change.
$powerShellExtension = 'ps1'
& {
    $dist = 'dotnet'
    $t = Join-Path ([IO.Path]::GetTempPath()) "b272layout-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
    $bomUtf8 = [Text.UTF8Encoding]::new($true)
    $stampAndTitle = @('<!--', 'ai-tech-lead-framework', '  template: dotnet', '  version: 0.89.2', '  applied: 2026-09-01', '-->', '# Acme Billing', '')
    $body = @('## Conventions', '', 'Money is decimal(19,4); never float. B272 CONSUMER SENTINEL — DO NOT CLOBBER.', '',
        '> Our Codex bot mirrors this: never in AGENTS.md edits, and CLAUDE.md wins on any conflict with README.md.', '',
        '```md', '<!-- FRAMEWORK-OWNED: example -->', '@.github/instructions/framework-rules.instructions.md', '```', '',
        '## Boy Scout Rule', '', 'Delete commented-out code.')
    $bodyText = (@($body) -join "`n") + "`n"
    $claudeText = ((@($stampAndTitle) + @(
        '> This file is the repo-specific source of truth for AI-assisted development in this repository and imports the framework rules below.'
        '> Claude Code and supported GitHub Copilot agent surfaces load this file directly. **[AGENTS.md](./AGENTS.md)** is the generated portable mirror for Codex and GitHub code review; Cursor loads both. Gemini defaults to `GEMINI.md`, and Aider requires explicit read configuration. Edit conventions here, never in AGENTS.md.'
        '> **Companion file**: FRAMEWORK-CONTEXT.md. CLAUDE.md wins on any conflict — but flag the contradiction.'
        ''
        '---'
        ''
        '<!-- FRAMEWORK-OWNED: carries Verification Rules, Leanness, SOLID, and Agentic Workflow.'
        '     Deleting this import disables all four rule sets for Claude Code. -->'
        '@.github/instructions/framework-rules.instructions.md'
        ''
    )) -join "`r`n") + "`r`n" + $bodyText
    $expectedAgents = ((@($stampAndTitle) + @(
        '> This file is the repo-specific source of truth for AI-assisted development in this repository. Edit it here; `CLAUDE.md` only imports it for Claude Code.'
        '> **Framework rules** (Verification Rules, Leanness, SOLID, Agentic Workflow) are in [.github/instructions/framework-rules.instructions.md](./.github/instructions/framework-rules.instructions.md). If your agent has not already loaded that file, read it before planning or editing.'
        '> **Companion file**: FRAMEWORK-CONTEXT.md. AGENTS.md wins on any conflict — but flag the contradiction.'
        ''
        '---'
    )) -join "`r`n") + "`r`n`r`n" + $bodyText
    [IO.File]::WriteAllText((Join-Path $t 'CLAUDE.md'), $claudeText, $bomUtf8)
    [IO.File]::WriteAllText((Join-Path $t 'AGENTS.md'), "<!-- GENERATED FILE — do not edit by hand. -->`n# Agent Instructions`n`n## Conventions`n`nstale mirror copy`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), "{`"version`": `"0.89.2`"}`n", [Text.UTF8Encoding]::new($false))
    $claudeBefore = [IO.File]::ReadAllBytes((Join-Path $t 'CLAUDE.md'))
    $agentsBefore = [IO.File]::ReadAllBytes((Join-Path $t 'AGENTS.md'))
    $backupRoot = Join-Path $t '.claude/framework-update-backup/instruction-files'
    $out = Invoke-Installer -Dist $dist -Target $t
    $installExit = $LASTEXITCODE
    $agentsAfter = [IO.File]::ReadAllBytes((Join-Path $t 'AGENTS.md'))
    $claudeAfter = [IO.File]::ReadAllBytes((Join-Path $t 'CLAUDE.md'))
    $rerun = Invoke-Installer -Dist $dist -Target $t
    $rerunExit = $LASTEXITCODE

    It "update moves the older instruction layout into AGENTS.md and backs up both originals ($powerShellExtension)" {
        # Consumer body lines, their fenced example and their LF endings pass through unchanged.
        Assert ($installExit -eq 0) "update exited ${installExit}: $out"
        Assert ($out -match '(?m)^PLAN replace CLAUDE\.md\r?$' -and $out -match '(?m)^PLAN replace AGENTS\.md\r?$') "the plan did not disclose the layout move. Output:`n$out"
        Assert-BytesEqual -Expected ([byte[]]($bomUtf8.GetPreamble() + $bomUtf8.GetBytes($expectedAgents))) -Actual $agentsAfter -Message "AGENTS.md is not CLAUDE.md's text with only the layout lines rewritten (BOM and CRLF kept). Got:`n$([Text.Encoding]::UTF8.GetString($agentsAfter))"
        Assert-BytesEqual -Expected ([IO.File]::ReadAllBytes((Join-Path $repoRoot "dist/$dist/CLAUDE.md"))) -Actual $claudeAfter -Message 'CLAUDE.md is not the shipped two-import stub'
        Assert-BytesEqual -Expected $claudeBefore -Actual ([IO.File]::ReadAllBytes((Join-Path $backupRoot 'CLAUDE.md'))) -Message 'the original CLAUDE.md was not backed up byte-for-byte'
        Assert-BytesEqual -Expected $agentsBefore -Actual ([IO.File]::ReadAllBytes((Join-Path $backupRoot 'AGENTS.md'))) -Message 'the generated AGENTS.md was not backed up byte-for-byte'
    }

    It "a second update leaves the migrated layout and its backups alone ($powerShellExtension)" {
        Assert ($rerunExit -eq 0) "second update exited ${rerunExit}: $rerun"
        Assert-BytesEqual -Expected $agentsAfter -Actual ([IO.File]::ReadAllBytes((Join-Path $t 'AGENTS.md'))) -Message 'a second update changed the migrated AGENTS.md'
        Assert-BytesEqual -Expected $claudeAfter -Actual ([IO.File]::ReadAllBytes((Join-Path $t 'CLAUDE.md'))) -Message 'a second update changed the CLAUDE.md stub'
        Assert-BytesEqual -Expected $claudeBefore -Actual ([IO.File]::ReadAllBytes((Join-Path $backupRoot 'CLAUDE.md'))) -Message 'a second update overwrote the original CLAUDE.md backup'
        Assert ($rerun -match '(?m)^PLAN preserve CLAUDE\.md\r?$' -and $rerun -match '(?m)^PLAN preserve AGENTS\.md\r?$') "the migrated files were not preserved on the second update. Output:`n$rerun"
    }

    Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue
}

# The move must never fire on a consumer that is already on the new layout, even when it imports
# with `@./AGENTS.md` and its own AGENTS.md mentions "GENERATED FILE" in prose.
$powerShellExtension = 'ps1'
& {
    $dist = 'dotnet'
    $t = Join-Path ([IO.Path]::GetTempPath()) "b272done-$(Get-Random)"
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
    [IO.File]::WriteAllText((Join-Path $t 'CLAUDE.md'), "@./AGENTS.md`n@.github/instructions/framework-rules.instructions.md`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $t 'AGENTS.md'), "# Acme`n`n## Conventions`n`n- Never edit a file marked // GENERATED FILE - DO NOT EDIT.`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), "{`"version`": `"0.89.2`"}`n", [Text.UTF8Encoding]::new($false))
    $claudeBefore = [IO.File]::ReadAllBytes((Join-Path $t 'CLAUDE.md'))
    $agentsBefore = [IO.File]::ReadAllBytes((Join-Path $t 'AGENTS.md'))
    $out = Invoke-Installer -Dist $dist -Target $t
    $installExit = $LASTEXITCODE

    It "update leaves an already-migrated layout alone even when AGENTS.md mentions GENERATED FILE ($powerShellExtension)" {
        Assert ($installExit -eq 0) "update exited ${installExit}: $out"
        Assert-BytesEqual -Expected $claudeBefore -Actual ([IO.File]::ReadAllBytes((Join-Path $t 'CLAUDE.md'))) -Message "an already-migrated CLAUDE.md was rewritten. Output:`n$out"
        Assert-BytesEqual -Expected $agentsBefore -Actual ([IO.File]::ReadAllBytes((Join-Path $t 'AGENTS.md'))) -Message "a hand-written AGENTS.md was replaced. Output:`n$out"
        Assert ($out -notmatch 'LAYOUT:') "an already-migrated layout produced a LAYOUT line. Output:`n$out"
    }

    # Claude Code honours an inline import too; a stale banner left at the top of a hand-migrated
    # AGENTS.md must not make the installer replace it.
    [IO.File]::WriteAllText((Join-Path $t 'CLAUDE.md'), "Project instructions: see @AGENTS.md`n@.github/instructions/framework-rules.instructions.md`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $t 'AGENTS.md'), "<!-- GENERATED FILE — do not edit by hand. -->`n# Acme`n`n## Conventions`n`n- Hand-written rules.`n", [Text.UTF8Encoding]::new($false))
    $inlineClaude = [IO.File]::ReadAllBytes((Join-Path $t 'CLAUDE.md'))
    $inlineAgents = [IO.File]::ReadAllBytes((Join-Path $t 'AGENTS.md'))
    $inlineOut = Invoke-Installer -Dist $dist -Target $t
    $inlineExit = $LASTEXITCODE

    It "update treats an inline @AGENTS.md import as already migrated ($powerShellExtension)" {
        Assert ($inlineExit -eq 0) "update exited ${inlineExit}: $inlineOut"
        Assert-BytesEqual -Expected $inlineClaude -Actual ([IO.File]::ReadAllBytes((Join-Path $t 'CLAUDE.md'))) -Message "an inline-import CLAUDE.md was rewritten. Output:`n$inlineOut"
        Assert-BytesEqual -Expected $inlineAgents -Actual ([IO.File]::ReadAllBytes((Join-Path $t 'AGENTS.md'))) -Message "AGENTS.md was replaced although CLAUDE.md already imports it. Output:`n$inlineOut"
    }

    Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue
}

$powerShellExtension = 'ps1'
& {
    It "brownfield leaves the copy-if-absent wiki index active and unarchived ($powerShellExtension)" {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-wiki-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Force -Path (Join-Path $t 'docs/wiki') | Out-Null
        Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value 'BROWNFIELD SIGNAL' -Encoding utf8
        Set-Content -LiteralPath (Join-Path $t 'docs/wiki/INDEX.md') -Value 'CONSUMER WIKI INDEX SENTINEL' -Encoding utf8
        try {
            Invoke-Installer -Dist 'dotnet' -Target $t | Out-Null
            $wiki = Join-Path $t 'docs/wiki/INDEX.md'
            $archiveRel = 'docs/pre-adoption/docs/wiki/INDEX.md'
            Assert ([IO.File]::ReadAllText($wiki).Contains('CONSUMER WIKI INDEX SENTINEL')) 'brownfield replaced a copy-if-absent wiki index'
            Assert (-not (Test-Path -LiteralPath (Join-Path $t $archiveRel))) 'brownfield unnecessarily archived a copy-if-absent wiki index'
            $marker = Get-Content -LiteralPath (Join-Path $t '.claude/adoption-pending.json') -Raw | ConvertFrom-Json
            Assert (-not ($marker.archivedOriginals -contains $archiveRel)) 'adoption marker listed a copy-if-absent wiki index as archived'
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }
}

$powerShellExtension = 'ps1'
& {
    It "brownfield leaves mature architecture and ADRs active and unarchived for in-place screening ($powerShellExtension)" {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-architecture-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Force -Path (Join-Path $t 'docs') | Out-Null
        Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value 'BROWNFIELD SIGNAL' -Encoding utf8
        $documents = @(
            @{ Relative = 'docs/ARCHITECTURE.md'; Text = "# Consumer architecture`n`n[ADR](./adr/0001.md)`n" },
            @{ Relative = 'docs/architecture-decisions.md'; Text = "# Architecture Decisions`n`n## ADR-042: Consumer sentinel`n- **Decision**: preserve these bytes.`n" }
        )
        $before = @{}
        foreach ($document in $documents) {
            $path = Join-Path $t $document.Relative
            [IO.File]::WriteAllText($path, $document.Text, [Text.UTF8Encoding]::new($false))
            $before[$document.Relative] = [IO.File]::ReadAllBytes($path)
        }
        try {
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $marker = Get-Content -LiteralPath (Join-Path $t '.claude/adoption-pending.json') -Raw | ConvertFrom-Json
            foreach ($document in $documents) {
                $path = Join-Path $t $document.Relative
                $archiveRel = "docs/pre-adoption/$($document.Relative)"
                Assert-BytesEqual -Expected $before[$document.Relative] -Actual ([IO.File]::ReadAllBytes($path)) -Message "brownfield replaced $($document.Relative) before adoption could screen it in place"
                Assert (-not (Test-Path -LiteralPath (Join-Path $t $archiveRel))) "brownfield archived $($document.Relative) instead of preserving its project-owned path"
                Assert (-not ($marker.archivedOriginals -contains $archiveRel)) "adoption marker listed screen-in-place document as archived: $($document.Relative)"
                Assert ($out -match "(?m)^PLAN preserve $([regex]::Escape($document.Relative))\r?$") "brownfield operation plan did not classify $($document.Relative) as preserved. Output:`n$out"
            }
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }
}

# Recovery increment 1: these fixtures are deliberately run against the composed, unfixed dist
# first. Each sentinel is a consumer byte that v0.72.0 loses: settings/hooks/commands on
# brownfield, audit state on both modes, and GitHub-only skills on update. B-217 extends the same
# fixture across unknown, byte-identical historical-path, and conflicting historical-path inputs.
function New-NoLossBrownfieldConsumer {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-brown-' + [guid]::NewGuid())
    foreach ($rel in @('.claude/commands', '.claude/skills/add-warehouse-load/references', '.github/hooks', '.github/skills/local-only', '.github/skills/perf', '.github/skills/add-tests')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $t $rel) | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value 'BROWNFIELD SIGNAL' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $t '.claude/settings.json') -Value 'SETTINGS SENTINEL' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $t '.github/hooks/hooks.json') -Value 'HOOKS SENTINEL' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $t '.claude/commands/feature.md') -Value 'COMMAND SENTINEL' -Encoding utf8
    [IO.File]::WriteAllText((Join-Path $t '.claude/skills/add-warehouse-load/SKILL.md'), 'BROWNFIELD FRAMEWORK SKILL COLLISION', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllBytes((Join-Path $t '.claude/skills/add-warehouse-load/references/project-pattern.md'), [Text.UTF8Encoding]::new($false).GetBytes("# Brownfield project pattern`r`ncomposition-root: Angular`r`nlifetime: singleton`r`n"))
    Set-Content -LiteralPath (Join-Path $t '.github/skills/local-only/SKILL.md') -Value 'GITHUB-ONLY SKILL SENTINEL' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $t '.github/skills/local-only/reference.md') -Value 'GITHUB-ONLY RESOURCE SENTINEL' -Encoding utf8
    [IO.File]::WriteAllBytes((Join-Path $t '.github/skills/perf/SKILL.md'), [IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/.claude/skills/perf/SKILL.md')))
    Set-Content -LiteralPath (Join-Path $t '.github/skills/add-tests/SKILL.md') -Value 'CONFLICTING GITHUB SKILL SENTINEL' -Encoding utf8
    [IO.File]::WriteAllBytes((Join-Path $t '.claude/ai-audit.log'), [byte[]](0, 1, 2, 255, 10, 13, 0))
    return $t
}

function New-ArchiveEscapeLink {
    param([Parameter(Mandatory)][string]$Link, [Parameter(Mandatory)][string]$Target)
    New-Item -ItemType Directory -Force -Path $Target | Out-Null
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
}

# Both directions matter. A destination link leaks archived originals outside the repository;
# a source-side link lets the installer mutate a collision that was never inside it. These run
# against the composed dotnet installer because path semantics are runtime behavior, not prose.
$powerShellExtension = 'ps1'
& {
    It "brownfield refuses a reparse/symlink archive destination before moving originals ($powerShellExtension)" {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-dest-link-' + [guid]::NewGuid())
        $outside = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-outside-' + [guid]::NewGuid())
        $collision = '.github/instructions/framework-rules.instructions.md'
        try {
            New-Item -ItemType Directory -Force -Path (Join-Path $t 'docs') | Out-Null
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $t $collision)) | Out-Null
            New-ArchiveEscapeLink -Link (Join-Path $t 'docs/pre-adoption') -Target $outside
            Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value 'BROWNFIELD SIGNAL' -Encoding utf8
            Set-Content -LiteralPath (Join-Path $t $collision) -Value 'DESTINATION ESCAPE SENTINEL' -Encoding utf8
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -ne 0) "archive destination reparse/symlink did not refuse. Output:`n$out"
            Assert ($out -match 'reparse/symlink') "archive destination refusal did not identify the reparse/symlink. Output:`n$out"
            Assert ([IO.File]::ReadAllText((Join-Path $t $collision)).Contains('DESTINATION ESCAPE SENTINEL')) 'archive destination preflight moved the original before refusing'
            Assert (@(Get-ChildItem -LiteralPath $outside -Recurse -Force -ErrorAction SilentlyContinue).Count -eq 0) 'archive destination escape wrote outside the target'
        } finally { Remove-Item -Recurse -Force $t,$outside -ErrorAction SilentlyContinue }
    }

    It "brownfield refuses a reparse/symlink collision source before moving originals ($powerShellExtension)" {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-source-link-' + [guid]::NewGuid())
        $outside = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-source-outside-' + [guid]::NewGuid())
        $collision = '.github/instructions/framework-rules.instructions.md'
        try {
            New-Item -ItemType Directory -Force -Path $t | Out-Null
            New-ArchiveEscapeLink -Link (Join-Path $t '.github') -Target $outside
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $t $collision)) | Out-Null
            Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value 'BROWNFIELD SIGNAL' -Encoding utf8
            Set-Content -LiteralPath (Join-Path $t $collision) -Value 'SOURCE ESCAPE SENTINEL' -Encoding utf8
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -ne 0) "collision source reparse/symlink did not refuse. Output:`n$out"
            Assert ($out -match 'reparse/symlink') "collision source refusal did not identify the reparse/symlink. Output:`n$out"
            Assert ([IO.File]::ReadAllText((Join-Path $t $collision)).Contains('SOURCE ESCAPE SENTINEL')) 'source reparse/symlink preflight moved the outside original'
            Assert (-not (Test-Path -LiteralPath (Join-Path $t 'docs/pre-adoption'))) 'source reparse/symlink preflight mutated the target before refusing'
        } finally { Remove-Item -Recurse -Force $t,$outside -ErrorAction SilentlyContinue }
    }
}

$powerShellExtension = 'ps1'
& {
    It "brownfield archives every incoming collision and preserves audit state ($powerShellExtension)" {
        $t = New-NoLossBrownfieldConsumer
        $auditBefore = [IO.File]::ReadAllBytes((Join-Path $t '.claude/ai-audit.log'))
        $patternPath = Join-Path $t '.claude/skills/add-warehouse-load/references/project-pattern.md'
        $patternBefore = [IO.File]::ReadAllBytes($patternPath)
        $githubSkillsBefore = @{}
        foreach ($relative in @('.github/skills/local-only/SKILL.md', '.github/skills/local-only/reference.md', '.github/skills/perf/SKILL.md', '.github/skills/add-tests/SKILL.md')) {
            $githubSkillsBefore[$relative] = [IO.File]::ReadAllBytes((Join-Path $t $relative))
        }
        try {
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "brownfield install failed (exit $LASTEXITCODE): $out"
            Assert-BytesEqual -Expected $patternBefore -Actual ([IO.File]::ReadAllBytes($patternPath)) -Message 'brownfield adoption modified consumer-owned project-pattern sidecar'
            foreach ($case in @(
                @{ Rel = '.claude/settings.json'; Text = 'SETTINGS SENTINEL' },
                @{ Rel = '.github/hooks/hooks.json'; Text = 'HOOKS SENTINEL' },
                @{ Rel = '.claude/commands/feature.md'; Text = 'COMMAND SENTINEL' }
                @{ Rel = '.claude/skills/add-warehouse-load/SKILL.md'; Text = 'BROWNFIELD FRAMEWORK SKILL COLLISION' }
            )) {
                $archiveRel = "docs/pre-adoption/$($case.Rel)"
                $archive = Join-Path $t $archiveRel
                Assert (Test-Path -LiteralPath $archive -PathType Leaf) "brownfield collision $($case.Rel) was not archived at its exact original-relative path"
                Assert ((Get-Content -LiteralPath $archive -Raw) -match $case.Text) "brownfield collision $($case.Rel) lost its sentinel"
                $marker = Get-Content -LiteralPath (Join-Path $t '.claude/adoption-pending.json') -Raw | ConvertFrom-Json
                Assert ($marker.archivedOriginals -contains $archiveRel) "adoption marker omitted archive mapping $archiveRel"
            }
            Assert-BytesEqual -Expected $auditBefore -Actual ([IO.File]::ReadAllBytes((Join-Path $t '.claude/ai-audit.log'))) -Message 'brownfield overwrote persistent ai-audit.log bytes'
            $marker = Get-Content -LiteralPath (Join-Path $t '.claude/adoption-pending.json') -Raw | ConvertFrom-Json
            Assert ($marker.detectedArtifacts -contains '.github/skills') 'brownfield marker did not route the legacy GitHub skill tree to /adopt'
            Assert (@($marker.archivedOriginals | Where-Object { $_ -like 'docs/pre-adoption/.github/skills*' }).Count -eq 0) 'brownfield marker claimed a GitHub skill was archived'
            foreach ($relative in $githubSkillsBefore.Keys) {
                Assert-BytesEqual -Expected $githubSkillsBefore[$relative] -Actual ([IO.File]::ReadAllBytes((Join-Path $t $relative))) -Message "brownfield changed untrusted GitHub skill input $relative"
            }

            $adoptCommand = [IO.File]::ReadAllText((Join-Path $t '.claude/commands/adopt.md'))
            foreach ($required in @('.github/skills/*/SKILL.md', 'every sibling resource', 'both interactive and headless mode', 'STOP before Phase 2', 'Do not move, delete, overwrite, interpret, execute, archive, or merge', '.claude/skills/<slug>', 'explicitly merge or rename', 'reruns `/adopt`', 'template-checks')) {
                Assert ($adoptCommand.Contains($required)) "shipped /adopt lost the legacy-skill migration contract: $required"
            }

            $update = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "update install failed (exit $LASTEXITCODE): $update"
            Assert-BytesEqual -Expected $patternBefore -Actual ([IO.File]::ReadAllBytes($patternPath)) -Message 'post-adoption update modified consumer-owned project-pattern sidecar'
            Assert-BytesEqual -Expected $auditBefore -Actual ([IO.File]::ReadAllBytes((Join-Path $t '.claude/ai-audit.log'))) -Message 'update overwrote persistent ai-audit.log bytes'
            foreach ($relative in $githubSkillsBefore.Keys) {
                Assert-BytesEqual -Expected $githubSkillsBefore[$relative] -Actual ([IO.File]::ReadAllBytes((Join-Path $t $relative))) -Message "update changed untrusted GitHub skill input $relative"
            }
            Assert ($update -match "CANT-VERIFY: retained retired path '\.github/skills/perf/SKILL\.md'.*may shadow") 'later update did not warn about the identical historical-path GitHub skill'
            Assert ($update -match "CANT-VERIFY: retained retired path '\.github/skills/add-tests/SKILL\.md'.*may shadow") 'later update did not warn about the conflicting historical-path GitHub skill'
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }

    It "archive-destination collision refuses before target mutation ($powerShellExtension)" {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-preflight-' + [guid]::NewGuid())
        $collision = '.github/instructions/framework-rules.instructions.md'
        $archive = Join-Path $t "docs/pre-adoption/$collision"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $t $collision)) | Out-Null
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $archive) | Out-Null
        Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value 'BROWNFIELD SIGNAL' -Encoding utf8
        Set-Content -LiteralPath (Join-Path $t $collision) -Value 'ORIGINAL COLLISION SENTINEL' -Encoding utf8
        Set-Content -LiteralPath $archive -Value 'EARLIER ARCHIVE SENTINEL' -Encoding utf8
        try {
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
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
$powerShellExtension = 'ps1'
& {
    It "brownfield archives a same-path skill collision from the manifest ($powerShellExtension)" {
        $t = New-NoLossBrownfieldConsumer
        $skillRel = '.claude/skills/add-tests/SKILL.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $t $skillRel)) | Out-Null
        Set-Content -LiteralPath (Join-Path $t $skillRel) -Value 'SKILL COLLISION SENTINEL' -Encoding utf8
        try {
            Invoke-Installer -Dist 'dotnet' -Target $t | Out-Null
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

# B-194 PowerShell host matrix. These cases retain optional-Git and refusal semantics without
# routing any PowerShell behavior through a retired shell implementation.
function Get-B194PowerShellHosts {
    $hosts = [System.Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $pwshCommand = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pwshCommand -and $seen.Add($pwshCommand.Source)) {
        $hosts.Add([pscustomobject]@{ Label = 'PowerShell 7'; Path = $pwshCommand.Source; IsWindowsPowerShell = $false }) | Out-Null
    }
    $native = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if ((Test-Path -LiteralPath $native -PathType Leaf) -and $seen.Add($native)) {
        $hosts.Add([pscustomobject]@{ Label = 'Windows PowerShell 5.1'; Path = $native; IsWindowsPowerShell = $true }) | Out-Null
    }
    return $hosts.ToArray()
}

$powerShellHosts = @(Get-B194PowerShellHosts)
It 'PowerShell installer matrix has both supported nonzero Windows hosts' {
    Assert ($powerShellHosts.Count -eq 2) "expected PS7 and Windows PowerShell 5.1, found $($powerShellHosts.Count)"
    Assert (@($powerShellHosts | Where-Object { $_.IsWindowsPowerShell }).Count -eq 1) 'Windows PowerShell 5.1 host is absent'
    Assert (@($powerShellHosts | Where-Object { -not $_.IsWindowsPowerShell }).Count -eq 1) 'PowerShell 7 host is absent'
}

It 'B-194 plain non-Git update and brownfield remain supported when Git is optional' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b194-nongit-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    try {
        $problems = [System.Collections.Generic.List[string]]::new()
        $gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $gitExe = if ($gitCommand) { $gitCommand.Source } else { '' }
        $gitConfig = Join-Path $root 'empty.gitconfig'
        [IO.File]::WriteAllText($gitConfig, '', [Text.UTF8Encoding]::new($false))

        $stubBin = Join-Path $root 'broken-git-bin'
        New-Item -ItemType Directory -Force -Path $stubBin | Out-Null
        $stub = Join-Path $stubBin 'git.cmd'
        [IO.File]::WriteAllText($stub, "@echo off`r`n>>`"%B194_GIT_SENTINEL%`" echo %*`r`necho B194 broken Git stub 1>&2`r`nexit /b 86`r`n", [Text.ASCIIEncoding]::new())
        foreach ($hostCase in $powerShellHosts) {
            $slug = $hostCase.Label -replace '[^A-Za-z0-9]+','-'
            $target = New-B194UpdateTarget -Parent $root -Name "$slug-stub-update"
            $before = [IO.File]::ReadAllBytes((Join-Path $target 'CLAUDE.md'))
            $sentinel = Join-Path $root "$slug.calls"
            $hostPath = (@($stubBin, (Split-Path -Parent $hostCase.Path), (Join-Path $env:SystemRoot 'System32'), $env:SystemRoot) | Select-Object -Unique) -join [IO.Path]::PathSeparator
            $capture = Invoke-B194Installer -Target $target -PowerShellExe $hostCase.Path -Environment @{
                PATH = $hostPath
                B194_PS_PATH = $hostPath
                B194_GIT_SENTINEL = $sentinel
                GIT_CONFIG_GLOBAL = $gitConfig
            }
            Add-B194SuccessProblems -Problems $problems -Label "$($hostCase.Label) broken optional Git update" -Capture $capture -Completion 'Done \(update\)'
            if (-not (Test-B194BytesEqual $before ([IO.File]::ReadAllBytes((Join-Path $target 'CLAUDE.md'))))) {
                $problems.Add("$($hostCase.Label): protected CLAUDE.md bytes changed") | Out-Null
            }
            $calls = if (Test-Path -LiteralPath $sentinel -PathType Leaf) { [IO.File]::ReadAllText($sentinel) } else { '' }
            if ($calls -notmatch '(?m)(^| )-C( |$)') { $problems.Add("$($hostCase.Label): optional Git probe did not use an explicit target") | Out-Null }

            $brownfield = New-B194BrownfieldTarget -Parent $root -Name "$slug-brownfield"
            $brownfieldBytes = [IO.File]::ReadAllBytes((Join-Path $brownfield 'TECH_DEBT.md'))
            $brownfieldCapture = Invoke-B194Installer -Target $brownfield -PowerShellExe $hostCase.Path -Environment @{
                PATH = $hostPath
                B194_PS_PATH = $hostPath
                B194_GIT_SENTINEL = $sentinel
                GIT_CONFIG_GLOBAL = $gitConfig
            }
            Add-B194SuccessProblems -Problems $problems -Label "$($hostCase.Label) broken optional Git brownfield" -Capture $brownfieldCapture -Completion 'Done - but this repo'
            $archive = Join-Path $brownfield 'docs/pre-adoption/TECH_DEBT.md'
            if (-not (Test-Path -LiteralPath $archive -PathType Leaf) -or
                -not (Test-B194BytesEqual $brownfieldBytes ([IO.File]::ReadAllBytes($archive)))) {
                $problems.Add("$($hostCase.Label): brownfield TECH_DEBT archive bytes changed") | Out-Null
            }
        }

        $nativeHost = @($powerShellHosts | Where-Object { $_.IsWindowsPowerShell })[0]
        $pathParts = @()
        if ($gitExe) { $pathParts += (Split-Path -Parent $gitExe) }
        $pathParts += @((Join-Path $env:SystemRoot 'System32'), $env:SystemRoot, (Split-Path -Parent $nativeHost.Path))
        $nativePath = (($pathParts | Where-Object { $_ } | Select-Object -Unique) -join [IO.Path]::PathSeparator)
        $nativeTarget = New-B194UpdateTarget -Parent $root -Name 'native-no-pwsh-update'
        $nativeCapture = Invoke-B194Installer -Target $nativeTarget -PowerShellExe $nativeHost.Path -Environment @{
            PATH = $nativePath
            B194_PS_PATH = $nativePath
            GIT_CONFIG_GLOBAL = $gitConfig
        }
        Add-B194SuccessProblems -Problems $problems -Label 'Windows PowerShell 5.1 with no pwsh on PATH' -Capture $nativeCapture -Completion 'Done \(update\)'
        if ($nativeCapture.Out -notmatch 'powershell\.exe -NoProfile -ExecutionPolicy Bypass -File scripts/framework-doctor\.ps1') {
            $problems.Add("PS5 no-pwsh guidance omitted its resolvable doctor command: $($nativeCapture.Out)") | Out-Null
        }
        if ($nativeCapture.Out -notmatch 'powershell\.exe -NoProfile -ExecutionPolicy Bypass -File scripts/docs-sync-check\.ps1') {
            $problems.Add("PS5 no-pwsh guidance omitted its resolvable docs-sync command: $($nativeCapture.Out)") | Out-Null
        }
        if ($nativeCapture.Out -match '(?m)\brun\s+pwsh -NoProfile -File scripts/(?:framework-doctor|docs-sync-check)\.ps1') {
            $problems.Add('PS5 no-pwsh branch still printed an unavailable pwsh follow-up command') | Out-Null
        }
        Assert ($problems.Count -eq 0) ($problems -join "`n")
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-194 corrupt repository evidence Git absence and ambient routing refuse before mutation' {
    $gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $gitCommand) { Skip 'B-194 repository evidence matrix' 'git is unavailable'; return }
    $gitExe = $gitCommand.Source
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b194-evidence-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    try {
        $problems = [System.Collections.Generic.List[string]]::new()
        $gitConfig = Join-Path $root 'empty.gitconfig'
        [IO.File]::WriteAllText($gitConfig, '', [Text.UTF8Encoding]::new($false))
        $cleanEnvironment = @{
            GIT_DIR = $null; GIT_WORK_TREE = $null; GIT_COMMON_DIR = $null; GIT_INDEX_FILE = $null
            GIT_CONFIG_GLOBAL = $gitConfig
        }
        $noGitBin = Join-Path $root 'no-git-bin'
        New-Item -ItemType Directory -Force -Path $noGitBin | Out-Null

        foreach ($hostCase in $powerShellHosts) {
            $slug = $hostCase.Label -replace '[^A-Za-z0-9]+','-'
            $corrupt = New-B194UpdateTarget -Parent $root -Name "$slug-corrupt-git"
            New-Item -ItemType Directory -Force -Path (Join-Path $corrupt '.git') | Out-Null
            $before = Get-B194Fingerprint $corrupt
            $capture = Invoke-B194Installer -Target $corrupt -PowerShellExe $hostCase.Path -Environment $cleanEnvironment
            Add-B194RefusalProblems -Problems $problems -Label "$($hostCase.Label) corrupt repository evidence" -Capture $capture -Before $before -After (Get-B194Fingerprint $corrupt)

            $absentGit = New-B194UpdateTarget -Parent $root -Name "$slug-git-absent"
            New-Item -ItemType Directory -Force -Path (Join-Path $absentGit '.git') | Out-Null
            $before = Get-B194Fingerprint $absentGit
            $capture = Invoke-B194Installer -Target $absentGit -PowerShellExe $hostCase.Path -Environment @{
                PATH = $noGitBin
                B194_PS_PATH = $noGitBin
                GIT_CONFIG_GLOBAL = $gitConfig
            }
            Add-B194RefusalProblems -Problems $problems -Label "$($hostCase.Label) repository evidence with Git absent" -Capture $capture -Before $before -After (Get-B194Fingerprint $absentGit)

            $ambient = New-B194UpdateTarget -Parent $root -Name "$slug-ambient-index"
            [IO.File]::WriteAllText((Join-Path $ambient 'tracked.txt'), "clean`n", [Text.UTF8Encoding]::new($false))
            foreach ($step in @(Initialize-B194GitTarget -Target $ambient -GitExe $gitExe -Environment $cleanEnvironment)) {
                Add-B194ExpectedProcessProblems -Problems $problems -Label $step.Label -Capture $step.Capture -ExpectedExit 0
            }
            $alternateIndex = Join-Path $root "$slug.index"
            $ambientEnvironment = @{
                GIT_DIR = $null; GIT_WORK_TREE = $null; GIT_COMMON_DIR = $null
                GIT_INDEX_FILE = $alternateIndex; GIT_CONFIG_GLOBAL = $gitConfig
            }
            $readTree = Invoke-B194Process -Executable $gitExe -Arguments @('-C',$ambient,'read-tree','HEAD') -Environment $ambientEnvironment
            Add-B194ExpectedProcessProblems -Problems $problems -Label "$($hostCase.Label) alternate read-tree" -Capture $readTree -ExpectedExit 0
            [IO.File]::WriteAllText((Join-Path $ambient 'tracked.txt'), "dirty`n", [Text.UTF8Encoding]::new($false))
            $normalStatus = Invoke-B194Process -Executable $gitExe -Arguments @('-C',$ambient,'status','--porcelain=v1','--untracked-files=all') -Environment $cleanEnvironment
            Add-B194ExpectedProcessProblems -Problems $problems -Label "$($hostCase.Label) normal dirty calibration" -Capture $normalStatus -ExpectedExit 0
            if ($normalStatus.Out -notmatch 'tracked\.txt') { $problems.Add("$($hostCase.Label): normal index did not expose the dirty file") | Out-Null }
            $before = Get-B194Fingerprint $ambient
            $capture = Invoke-B194Installer -Target $ambient -PowerShellExe $hostCase.Path -Environment $ambientEnvironment
            Add-B194RefusalProblems -Problems $problems -Label "$($hostCase.Label) ambient alternate index" -Capture $capture -Before $before -After (Get-B194Fingerprint $ambient)
        }
        Assert ($problems.Count -eq 0) ($problems -join "`n")
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-194 a classified worktree with unreadable status refuses before mutation' {
    $gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $gitCommand) { Skip 'B-194 unreadable status matrix' 'git is unavailable'; return }
    $gitExe = $gitCommand.Source
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b194-status-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    try {
        $problems = [System.Collections.Generic.List[string]]::new()
        $gitConfig = Join-Path $root 'empty.gitconfig'
        [IO.File]::WriteAllText($gitConfig, '', [Text.UTF8Encoding]::new($false))
        $cleanEnvironment = @{
            GIT_DIR = $null; GIT_WORK_TREE = $null; GIT_COMMON_DIR = $null; GIT_INDEX_FILE = $null
            GIT_CONFIG_GLOBAL = $gitConfig
        }
        foreach ($hostCase in $powerShellHosts) {
            $target = New-B194UpdateTarget -Parent $root -Name (($hostCase.Label -replace '[^A-Za-z0-9]+','-') + '-corrupt-index')
            [IO.File]::WriteAllText((Join-Path $target 'tracked.txt'), "clean`n", [Text.UTF8Encoding]::new($false))
            foreach ($step in @(Initialize-B194GitTarget -Target $target -GitExe $gitExe -Environment $cleanEnvironment)) {
                Add-B194ExpectedProcessProblems -Problems $problems -Label $step.Label -Capture $step.Capture -ExpectedExit 0
            }
            [IO.File]::WriteAllBytes((Join-Path $target '.git/index'), [byte[]](66,49,57,52,0,255,1,2,3))
            $revParse = Invoke-B194Process -Executable $gitExe -Arguments @('-C',$target,'rev-parse','--is-inside-work-tree') -Environment $cleanEnvironment
            Add-B194ExpectedProcessProblems -Problems $problems -Label "$($hostCase.Label) corrupt-index classification" -Capture $revParse -ExpectedExit 0
            $status = Invoke-B194Process -Executable $gitExe -Arguments @('-C',$target,'status','--porcelain=v1','--untracked-files=all') -Environment $cleanEnvironment
            Add-B194CaptureProblem -Problems $problems -Label "$($hostCase.Label) corrupt-index status" -Capture $status
            if ($null -eq $status.Exit -or $status.Exit -eq 0) { $problems.Add("$($hostCase.Label): corrupt-index status unexpectedly succeeded") | Out-Null }
            $before = Get-B194Fingerprint $target
            $capture = Invoke-B194Installer -Target $target -PowerShellExe $hostCase.Path -Environment $cleanEnvironment
            Add-B194RefusalProblems -Problems $problems -Label "$($hostCase.Label) corrupt index" -Capture $capture -Before $before -After (Get-B194Fingerprint $target)
        }
        Assert ($problems.Count -eq 0) ($problems -join "`n")
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
    Skip 'dirty Git update and brownfield safety' 'git is unavailable'
} else {
    It 'dirty Git update refuses before mutation and explicit override is observable' {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('no-loss-dirty-' + [guid]::NewGuid())
        $priorOptionalLocks = [Environment]::GetEnvironmentVariable('GIT_OPTIONAL_LOCKS', 'Process')
        try {
            [Environment]::SetEnvironmentVariable('GIT_OPTIONAL_LOCKS', '1', 'Process')
            New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
            Set-Content -LiteralPath (Join-Path $t '.claude/framework-version.json') -Value '{"version":"0.76.0"}' -Encoding utf8
            Set-Content -LiteralPath (Join-Path $t '.claude/ai-audit.log') -Value 'DIRTY AUDIT SENTINEL' -Encoding utf8
            & git -C $t init -q
            & git -C $t config user.email 'tests@example.invalid'
            & git -C $t config user.name 'installer tests'
            $statRefreshPath = Join-Path $t 'stat-refresh.txt'
            $dirtyPath = Join-Path $t 'dirty.txt'
            [IO.File]::WriteAllText($statRefreshPath, "same`n", [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText($dirtyPath, "before`n", [Text.UTF8Encoding]::new($false))
            & git -C $t add .
            & git -C $t commit -qm initial
            [IO.File]::SetLastWriteTimeUtc($statRefreshPath, [IO.File]::GetLastWriteTimeUtc($statRefreshPath).AddMinutes(5))
            [IO.File]::WriteAllText($dirtyPath, "after`n", [Text.UTF8Encoding]::new($false))
            $before = [IO.File]::ReadAllText($dirtyPath)
            $indexPath = Join-Path $t '.git/index'
            $indexBefore = [IO.File]::ReadAllBytes($indexPath)
            $calibration = (& git -C $t status --porcelain=v1 --untracked-files=all 2>&1 | Out-String)
            $calibrationExit = $LASTEXITCODE
            $calibrationChangedIndex = -not (Test-B194BytesEqual $indexBefore ([IO.File]::ReadAllBytes($indexPath)))
            [IO.File]::WriteAllBytes($indexPath, $indexBefore)
            $fingerprintBefore = Get-B194Fingerprint $t
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $installerExit = $LASTEXITCODE
            $fingerprintAfter = Get-B194Fingerprint $t
            Assert ($calibrationExit -eq 0 -and $calibration -match 'dirty\.txt') "ordinary-status calibration failed: $calibration"
            Assert $calibrationChangedIndex 'ordinary-status calibration did not refresh .git/index'
            Assert ($installerExit -ne 0 -and $out -match 'commit, stash, or copy') "dirty update did not refuse precisely: $out"
            Assert ([IO.File]::ReadAllText($dirtyPath) -eq $before) 'dirty-tree preflight mutated dirty.txt'
            Assert ($fingerprintAfter -ceq $fingerprintBefore) 'dirty-tree preflight changed the target fingerprint'
            $override = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
            Assert ($LASTEXITCODE -eq 0 -and $override -match 'override: -AllowDirtyTree accepted') "dirty override failed: $override"
        } finally {
            if ($null -eq $priorOptionalLocks) { Remove-Item Env:GIT_OPTIONAL_LOCKS -Force -ErrorAction SilentlyContinue }
            else { [Environment]::SetEnvironmentVariable('GIT_OPTIONAL_LOCKS', $priorOptionalLocks, 'Process') }
            Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue
        }
    }

    It 'dirty Git brownfield refuses before mutation and explicit override is observable' {
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
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -ne 0 -and $out -match 'commit, stash, or copy') "dirty brownfield did not refuse precisely: $out"
            Assert ((Get-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Raw) -eq $before) 'brownfield dirty preflight mutated the target'
            $override = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
            Assert ($LASTEXITCODE -eq 0 -and $override -match 'override: -AllowDirtyTree accepted') "brownfield override failed: $override"
            Assert (Test-Path -LiteralPath (Join-Path $t 'docs/pre-adoption/TECH_DEBT.md') -PathType Leaf) 'brownfield override did not archive the collision'
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }

    It 'B-295 a shipped path holding other bytes is archived even when Git status is clean' {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('b295-' + [guid]::NewGuid())
        try {
            # No adoption signal and only ignored collisions: git status is clean, so a dirty-tree
            # check alone would still let a greenfield copy overwrite them.
            $t = Join-Path $root 'ignored'
            New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/commands') | Out-Null
            & git -C $t init -q
            & git -C $t config user.email 'tests@example.invalid'
            & git -C $t config user.name 'installer tests'
            [IO.File]::WriteAllText((Join-Path $t '.gitignore'), ".claude/`n", [Text.UTF8Encoding]::new($false))
            & git -C $t add .gitignore
            & git -C $t commit -qm initial
            $collisions = [ordered]@{
                '.claude/settings.json' = [Text.UTF8Encoding]::new($false).GetBytes("{`"env`":{`"B295`":`"consumer`"}}`n")
                '.claude/commands/review.md' = [Text.UTF8Encoding]::new($false).GetBytes("consumer review command`r`n")
            }
            foreach ($rel in $collisions.Keys) { [IO.File]::WriteAllBytes((Join-Path $t $rel), $collisions[$rel]) }
            $status = (& git -C $t status --porcelain=v1 --untracked-files=all | Out-String)
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $exit = $LASTEXITCODE
            Assert ($status.Trim() -eq '') "calibration: the ignored collisions made git status dirty: $status"
            Assert ($exit -eq 0 -and $out -match 'mode: brownfield' -and $out -match 'secrets') "ignored collisions did not take the brownfield archive (exit $exit): $out"
            foreach ($rel in $collisions.Keys) {
                $archive = Join-Path $t "docs/pre-adoption/$rel"
                Assert ((Test-Path -LiteralPath $archive -PathType Leaf) -and
                    (Test-B194BytesEqual $collisions[$rel] ([IO.File]::ReadAllBytes($archive)))) "'$rel' was not archived byte-for-byte: $out"
            }

            # Identical bytes lose nothing when rewritten, so an interrupted greenfield install must
            # stay greenfield on re-run.
            $same = Join-Path $root 'identical'
            New-Item -ItemType Directory -Force -Path (Join-Path $same 'docs') | Out-Null
            Copy-Item -LiteralPath (Join-Path $repoRoot 'dist/dotnet/docs/defaults.md') -Destination (Join-Path $same 'docs/defaults.md')
            $sameOut = Invoke-Installer -Dist 'dotnet' -Target $same
            Assert ($LASTEXITCODE -eq 0 -and $sameOut -match 'mode: greenfield') "a byte-identical shipped file changed the mode: $sameOut"
        } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

It 'B-299 a bracketed target is installed in place, never into the sibling its wildcard matches' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b299-' + [guid]::NewGuid())
    try {
        # Read as a wildcard, repo[a] matches sibling repoa: that sibling took a greenfield install
        # at exit 0 while the requested target, whose CLAUDE.md makes it brownfield, stayed untouched.
        $t = Join-Path $root 'repo[a]'
        $sibling = Join-Path $root 'repoa'
        [void][IO.Directory]::CreateDirectory($t)
        [void][IO.Directory]::CreateDirectory($sibling)
        $claude = [Text.UTF8Encoding]::new($false).GetBytes("# consumer instructions`r`n")
        [IO.File]::WriteAllBytes((Join-Path $t 'CLAUDE.md'), $claude)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 0 -and $out -match 'into: .*\\repo\[a\]\r?\n' -and $out -match 'mode: brownfield') "the bracketed target was not installed in place as brownfield (exit $exit): $out"
        $archive = Join-Path $t 'docs/pre-adoption/CLAUDE.md'
        Assert ((Test-Path -LiteralPath $archive -PathType Leaf) -and
            (Test-B194BytesEqual $claude ([IO.File]::ReadAllBytes($archive)))) "the target's CLAUDE.md was not archived byte-for-byte: $out"
        Assert (@(Get-ChildItem -LiteralPath $sibling -Force).Count -eq 0) "the wildcard-matched sibling was written to: $out"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

# One case on both hosts keeps the CI case-count parity: only Windows PowerShell can take the 5.1
# fallback, so under pwsh the same fixture asserts the shipped pwsh settings stay in place.
It 'B-299 without pwsh on PATH a bracketed target gets the hook settings for the installing host' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b299-' + [guid]::NewGuid())
    $savedPath = $env:PATH
    try {
        # Test-Path without -LiteralPath reports a file under repo[b] absent, so the fallback
        # left settings.json calling a pwsh the machine does not have.
        $t = Join-Path $root 'repo[b]'
        [void][IO.Directory]::CreateDirectory($t)
        $env:PATH = @($savedPath -split ';' | Where-Object {
            try { $_ -and -not [IO.File]::Exists([IO.Path]::Combine($_, 'pwsh.exe')) } catch { $true }
        }) -join ';'
        Assert ($null -eq (Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue)) 'calibration: pwsh is still resolvable after removing its directories from PATH'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 0) "the bracketed install failed (exit $exit): $out"
        $settings = [IO.File]::ReadAllBytes((Join-Path $t '.claude/settings.json'))
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            Assert ($out -notmatch 'activated Windows PowerShell 5.1 hooks') "a pwsh install took the 5.1 fallback: $out"
            Assert (Test-B194BytesEqual ([IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/.claude/settings.json'))) $settings) "settings.json is not the shipped pwsh variant: $out"
        } else {
            Assert ($out -match 'activated Windows PowerShell 5.1 hooks') "the 5.1 hook fallback did not run: $out"
            Assert (Test-B194BytesEqual ([IO.File]::ReadAllBytes((Join-Path $t '.claude/settings.windows.json'))) $settings) "settings.json is not the Windows PowerShell 5.1 variant: $out"
        }
    } finally {
        $env:PATH = $savedPath
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-300 the brownfield mode line and adoption marker name each detected path once' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b300-' + [guid]::NewGuid())
    try {
        # CLAUDE.md is an adoption signal and also a shipped path holding other bytes.
        [void][IO.Directory]::CreateDirectory($t)
        [IO.File]::WriteAllBytes((Join-Path $t 'CLAUDE.md'), [Text.UTF8Encoding]::new($false).GetBytes("# consumer instructions`r`n"))
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        $mode = [regex]::Match($out, 'mode: brownfield \([^:]*: (?<paths>[^)\r\n]*)\)')
        Assert ($exit -eq 0 -and $mode.Success) "no brownfield mode line (exit $exit): $out"
        Assert ($mode.Groups['paths'].Value -ceq 'CLAUDE.md') "the mode line did not name CLAUDE.md exactly once: $($mode.Value)"
        $marker = [IO.File]::ReadAllText((Join-Path $t '.claude/adoption-pending.json')) | ConvertFrom-Json
        Assert ((@($marker.detectedArtifacts) -join ', ') -ceq 'CLAUDE.md') "detectedArtifacts did not name CLAUDE.md exactly once: $(@($marker.detectedArtifacts) -join ', ')"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-286 the brownfield handoff says which detected files moved and which stayed where they were' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b286-' + [guid]::NewGuid())
    try {
        # .cursorrules is an adoption signal no shipped path collides with: nothing is archived, yet
        # the handoff said the originals it displaced were under a docs/pre-adoption/ that did not exist.
        $signalOnly = Join-Path $root 'signal-only'
        [void][IO.Directory]::CreateDirectory($signalOnly)
        [IO.File]::WriteAllBytes((Join-Path $signalOnly '.cursorrules'), [Text.UTF8Encoding]::new($false).GetBytes("consumer rules`r`n"))
        $out = Invoke-Installer -Dist 'dotnet' -Target $signalOnly
        $exit = $LASTEXITCODE
        Assert ($exit -eq 0 -and $out -match 'mode: brownfield') "the signal-only target did not take brownfield (exit $exit): $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $signalOnly 'docs/pre-adoption'))) "calibration: the signal-only install archived something: $out"
        Assert ($out -notmatch 'displaced|docs/pre-adoption') "the handoff names an archive that does not exist: $out"
        Assert ($out -match 'Left where they were: \.cursorrules\r?\n') "the handoff does not say .cursorrules stayed where it was: $out"

        # A collision moves and a signal-only file stays; the handoff must say which is which.
        $mixed = Join-Path $root 'mixed'
        [void][IO.Directory]::CreateDirectory($mixed)
        [IO.File]::WriteAllBytes((Join-Path $mixed 'CLAUDE.md'), [Text.UTF8Encoding]::new($false).GetBytes("# consumer instructions`r`n"))
        [IO.File]::WriteAllBytes((Join-Path $mixed '.cursorrules'), [Text.UTF8Encoding]::new($false).GetBytes("consumer rules`r`n"))
        $mixedOut = Invoke-Installer -Dist 'dotnet' -Target $mixed
        $mixedExit = $LASTEXITCODE
        Assert ($mixedExit -eq 0 -and (Test-Path -LiteralPath (Join-Path $mixed 'docs/pre-adoption/CLAUDE.md') -PathType Leaf)) "calibration: CLAUDE.md was not archived (exit $mixedExit): $mixedOut"
        Assert ($mixedOut -match 'Moved to docs/pre-adoption/[^\r\n]*: CLAUDE\.md\r?\n') "the handoff does not name what moved: $mixedOut"
        Assert ($mixedOut -match 'Left where they were: \.cursorrules\r?\n') "the handoff does not name what stayed: $mixedOut"
        Assert ($mixedOut -match 'secrets') "the handoff lost the gitignored-secrets warning for archived files: $mixedOut"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

function New-B309GitTarget {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Ignore)
    $t = Join-Path $Root $Name
    [void][IO.Directory]::CreateDirectory($t)
    & git -C $t init -q
    & git -C $t config user.email 'tests@example.invalid'
    & git -C $t config user.name 'installer tests'
    [IO.File]::WriteAllText((Join-Path $t '.gitignore'), $Ignore, [Text.UTF8Encoding]::new($false))
    & git -C $t add .gitignore
    & git -C $t commit -qm base
    return $t
}

It 'B-309 an archived file the consumer had gitignored stays out of Git' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b309-' + [guid]::NewGuid())
    try {
        # Anchored rules ignore the originals but not their docs/pre-adoption/ archives, so the
        # handoff's own "commit the copied files" step staged a personal settings file with its key.
        $t = New-B309GitTarget -Root $root -Name 'anchored' -Ignore "/.claude/settings.json`n/CLAUDE.md`n"
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
        $settings = [Text.UTF8Encoding]::new($false).GetBytes("{`"env`":{`"API_KEY`":`"sk-FIXTURE`"}}`n")
        [IO.File]::WriteAllBytes((Join-Path $t '.claude/settings.json'), $settings)
        [IO.File]::WriteAllText((Join-Path $t 'CLAUDE.md'), "# personal notes`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $t 'TECH_DEBT.md'), "# team debt`n", [Text.UTF8Encoding]::new($false))
        & git -C $t add TECH_DEBT.md
        & git -C $t commit -qm debt
        $dry = & (Get-PsExe) -NoProfile -File (Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1') -Target $t -WhatIf 2>&1 | Out-String
        Assert ($dry -match '(?m)^PLAN create docs/pre-adoption/\.gitignore\r?$') "the dry run did not plan docs/pre-adoption/.gitignore: $dry"
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 0 -and $out -match 'mode: brownfield') "the brownfield install failed (exit $exit): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'docs/pre-adoption/\.claude/settings\.json' -and $status -notmatch 'docs/pre-adoption/CLAUDE\.md') "a gitignored original's archive is committable: $status"
        Assert ($status -match 'docs/pre-adoption/TECH_DEBT\.md') "the tracked team file's archive is not committable: $status"
        $lines = @([IO.File]::ReadAllLines((Join-Path $t 'docs/pre-adoption/.gitignore')) | Where-Object { $_ })
        Assert (($lines -join '|') -ceq '/.claude/settings.json|/CLAUDE.md') "docs/pre-adoption/.gitignore does not hold exactly the two anchored lines: $($lines -join '|')"
        Assert (Test-B194BytesEqual $settings ([IO.File]::ReadAllBytes((Join-Path $t 'docs/pre-adoption/.claude/settings.json')))) 'the archived settings changed bytes'
        Assert ($out -match 'Kept out of Git[^\r\n]*\.claude/settings\.json' -and $out -match 'Kept out of Git[^\r\n]*CLAUDE\.md') "the handoff does not name the kept-out files: $out"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-313 the handoff names framework files the consumer''s ignore rules hide, and only those' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b313-' + [guid]::NewGuid())
    try {
        # Under /.claude/ every installed hook, command and setting is ignored: "commit the copied
        # files" commits none of them and teammates never get them, and nothing said so.
        $hidden = New-B309GitTarget -Root $root -Name 'hidden' -Ignore "/.claude/`n"
        $out = Invoke-Installer -Dist 'dotnet' -Target $hidden
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: greenfield') "the greenfield install failed: $out"
        Assert ($out -match 'WARNING: your ignore rules hide [0-9]+ of the framework''s own files[^\r\n]*\.claude/ \([0-9]+ files\)') "the handoff did not name the hidden .claude files: $out"

        # A rule in the consumer's own .claude/.gitignore disappears when the install replaces that
        # file, so nothing is hidden afterwards; the warning must reflect the installed tree.
        $replaced = New-B309GitTarget -Root $root -Name 'replaced' -Ignore "bin/`n"
        New-Item -ItemType Directory -Force -Path (Join-Path $replaced '.claude') | Out-Null
        [IO.File]::WriteAllText((Join-Path $replaced '.claude/.gitignore'), "*`n!.gitignore`n", [Text.UTF8Encoding]::new($false))
        & git -C $replaced add .claude/.gitignore
        & git -C $replaced commit -qm 'consumer claude ignore'
        $replacedOut = Invoke-Installer -Dist 'dotnet' -Target $replaced -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0 -and $replacedOut -notmatch 'ignore rules hide') "a rule the install replaced still produced the hidden-files warning: $replacedOut"

        # A plain repository gets no warning, before or after its install is committed; the
        # framework's own ignored audit log is not a hidden framework file.
        $plain = New-B309GitTarget -Root $root -Name 'plain' -Ignore "bin/`nobj/`n*.log`n"
        $first = Invoke-Installer -Dist 'dotnet' -Target $plain
        Assert ($LASTEXITCODE -eq 0 -and $first -notmatch 'ignore rules hide') "a plain first install warned about hidden files: $first"
        & git -C $plain add -A
        & git -C $plain commit -qm install
        $update = Invoke-Installer -Dist 'dotnet' -Target $plain
        Assert ($LASTEXITCODE -eq 0 -and $update -match 'mode: update' -and $update -notmatch 'ignore rules hide') "a committed install's update warned about hidden files: $update"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

# B-454: this release ignores .claude/ai-audit.log, so a copy a team tracked under an older release stays tracked. The fixture
# is a greenfield install committed as a team would have, with the log tracked as $Log says; a developer's log differs, so
# the committed bytes are not the shipped (empty) file. 'case' tracks it as .CLAUDE/AI-AUDIT.LOG, which a checkout that
# ignores case can; 'skip-worktree' is the flag that makes a team's local log writes invisible to git status.
function New-B454Target {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][ValidateSet('untracked', 'tracked', 'case', 'skip-worktree')][string]$Log)
    $t = New-B309GitTarget -Root $Root -Name $Name -Ignore "bin/`n"
    $first = Invoke-Installer -Dist 'dotnet' -Target $t
    Assert ($LASTEXITCODE -eq 0 -and $first -match 'mode: greenfield') "calibration: the first install failed (exit $LASTEXITCODE): $first"
    $logPath = Join-Path $t '.claude/ai-audit.log'
    Assert (Test-Path -LiteralPath $logPath -PathType Leaf) "calibration: the install wrote no .claude/ai-audit.log: $first"
    [IO.File]::WriteAllText($logPath, "2026-05-01T09:00:00Z main src/Orders.cs`n", [Text.UTF8Encoding]::new($false))
    & git -C $t add -A
    if ($Log -in 'tracked', 'skip-worktree') { & git -C $t add -f -- .claude/ai-audit.log }
    if ($Log -eq 'case') {
        $blob = (& git -C $t hash-object -w -- $logPath | Out-String).Trim()
        & git -C $t update-index --add --cacheinfo "100644,$blob,.CLAUDE/AI-AUDIT.LOG"
    }
    & git -C $t commit -qm 'framework install'
    if ($Log -eq 'skip-worktree') { & git -C $t update-index --skip-worktree -- .claude/ai-audit.log }
    $tracked = @(& git -C $t ls-files -- ':(icase,literal).claude/ai-audit.log')
    Assert (($Log -eq 'untracked') -eq ($tracked.Count -eq 0)) "calibration: the $Log fixture tracks [$($tracked -join ',')]"
    Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') "calibration: the $Log fixture is not clean before the update"
    return $t
}

# The commands a NOTICE prints between "untrack it with  " and "  and commit that", run from $Root, the repository root the NOTICE
# names, by the shell they are printed for: PowerShell reads each one as a developer's paste would.
function Invoke-B454PrintedCommands {
    param([Parameter(Mandatory)][string]$Output, [Parameter(Mandatory)][string]$Root)
    $m = [regex]::Match($Output, 'From the repository root, untrack it with  (git [^\r\n]*?)  and commit that')
    Assert $m.Success "no untrack command run from the repository root in the handoff: $Output"
    Push-Location -LiteralPath $Root
    try {
        foreach ($command in ($m.Groups[1].Value -split '  and then  ')) {
            $result = (Invoke-Expression "$command 2>&1" | Out-String)
            Assert ($LASTEXITCODE -eq 0) "the printed command '$command' failed in $Root (exit $LASTEXITCODE): $result"
        }
    } finally { Pop-Location }
    return $m.Groups[1].Value
}

It 'B-454 an update that finds .claude/ai-audit.log tracked prints one NOTICE with the command that untracks it and changes nothing itself, and prints none when the log is untracked' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b454-' + [guid]::NewGuid())
    try {
        $t = New-B454Target -Root $root -Name 'tracked' -Log 'tracked'
        $logBytes = [IO.File]::ReadAllBytes((Join-Path $t '.claude/ai-audit.log'))
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: update') "the update failed (exit $LASTEXITCODE): $out"
        $notice = '(?m)^NOTICE: Git tracks \.claude/ai-audit\.log, which this release ignores \(\.claude/\.gitignore\)\. It is local hook telemetry, not compliance evidence, and every developer''s copy differs\. [^\r\n]*untrack it with  git rm --cached -- \.claude/ai-audit\.log  and commit that with the copied files; your local file stays\. [^\r\n]*docs/upgrade-checklist\.md'
        Assert (@([regex]::Matches($out, $notice)).Count -eq 1) "the handoff has not exactly one NOTICE naming the tracked log and its untrack command: $out"
        Assert (@(& git -C $t ls-files -- .claude/ai-audit.log).Count -eq 1) 'the installer untracked the log itself'
        Assert (Test-B194BytesEqual $logBytes ([IO.File]::ReadAllBytes((Join-Path $t '.claude/ai-audit.log')))) 'the installer changed the local log'

        $command = Invoke-B454PrintedCommands -Output $out -Root $t
        Assert ($command -ceq 'git rm --cached -- .claude/ai-audit.log') "unexpected command: $command"
        Assert (@(& git -C $t ls-files -- ':(icase,literal).claude/ai-audit.log').Count -eq 0) 'the printed command left the log tracked'
        Assert (Test-B194BytesEqual $logBytes ([IO.File]::ReadAllBytes((Join-Path $t '.claude/ai-audit.log')))) 'the printed command changed the local log'

        $untracked = New-B454Target -Root $root -Name 'untracked' -Log 'untracked'
        $quiet = Invoke-Installer -Dist 'dotnet' -Target $untracked
        Assert ($LASTEXITCODE -eq 0 -and $quiet -match 'mode: update') "the update over an untracked log failed (exit $LASTEXITCODE): $quiet"
        Assert ($quiet -notmatch '(?m)^(NOTICE: Git tracks|CANT-VERIFY: Git could not say whether it tracks)') "an untracked log produced an audit-log line: $quiet"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-454 a brownfield install that finds .claude/ai-audit.log tracked prints the same NOTICE' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b454-brown-' + [guid]::NewGuid())
    try {
        $t = New-B309GitTarget -Root $root -Name 'target' -Ignore "bin/`n"
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/ai-audit.log'), "2026-05-01T09:00:00Z main src/Orders.cs`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $t 'TECH_DEBT.md'), "# team debt`n", [Text.UTF8Encoding]::new($false))
        & git -C $t add TECH_DEBT.md
        & git -C $t add -f -- .claude/ai-audit.log
        & git -C $t commit -qm 'team debt and a tracked log'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: brownfield') "the brownfield install failed (exit $LASTEXITCODE): $out"
        Assert ($out -cmatch '(?m)^NOTICE: Git tracks \.claude/ai-audit\.log, which this release ignores [^\r\n]*untrack it with  git rm --cached -- \.claude/ai-audit\.log  and commit that') "the brownfield handoff does not name the tracked log: $out"
        [void](Invoke-B454PrintedCommands -Output $out -Root $t)
        Assert (@(& git -C $t ls-files -- .claude/ai-audit.log).Count -eq 0) 'the printed command left the log tracked'
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-454 a log Git tracks in another letter case is named as Git records it, so the printed command untracks it' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b454-case-' + [guid]::NewGuid())
    try {
        $t = New-B454Target -Root $root -Name 'case' -Log 'case'
        # Calibration: the shipped spelling does not untrack the variant, so a command that used it would fail on this checkout.
        & git -C $t rm --cached --dry-run -q -- .claude/ai-audit.log 2>&1 | Out-Null
        Assert ($LASTEXITCODE -ne 0) 'calibration: git rm accepts the shipped spelling for a log tracked as .CLAUDE/AI-AUDIT.LOG'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: update') "the update failed (exit $LASTEXITCODE): $out"
        Assert ($out -cmatch '(?m)^NOTICE: Git tracks \.CLAUDE/AI-AUDIT\.LOG, which this release ignores [^\r\n]*untrack it with  git rm --cached -- \.CLAUDE/AI-AUDIT\.LOG  and commit that') "the handoff does not name the log as Git records it: $out"
        [void](Invoke-B454PrintedCommands -Output $out -Root $t)
        Assert (@(& git -C $t ls-files -- ':(icase,literal).claude/ai-audit.log').Count -eq 0) 'the printed command left the log tracked'
        Assert (Test-Path -LiteralPath (Join-Path $t '.claude/ai-audit.log') -PathType Leaf) 'the printed command removed the local log'
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-454 a tracked log marked skip-worktree gets the command pair that untracks it, since git rm --cached alone is refused there' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b454-skip-' + [guid]::NewGuid())
    try {
        $t = New-B454Target -Root $root -Name 'skip' -Log 'skip-worktree'
        $logBytes = [IO.File]::ReadAllBytes((Join-Path $t '.claude/ai-audit.log'))
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: update') "the update failed (exit $LASTEXITCODE): $out"
        Assert ($out -cmatch '(?m)^NOTICE: Git tracks \.claude/ai-audit\.log, which this release ignores [^\r\n]*untrack it with  git update-index --no-skip-worktree -- \.claude/ai-audit\.log  and then  git rm --cached -- \.claude/ai-audit\.log  and commit that') "the handoff does not give the skip-worktree command pair: $out"
        $command = Invoke-B454PrintedCommands -Output $out -Root $t
        Assert ($command -match 'no-skip-worktree') "unexpected command: $command"
        Assert (@(& git -C $t ls-files -- ':(icase,literal).claude/ai-audit.log').Count -eq 0) 'the printed commands left the log tracked'
        Assert (Test-B194BytesEqual $logBytes ([IO.File]::ReadAllBytes((Join-Path $t '.claude/ai-audit.log')))) 'the printed commands changed the local log'
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-454 when Git cannot say whether it tracks the log inside a work tree, the handoff has a CANT-VERIFY line naming it; outside one it says nothing' {
    $gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $gitCommand) { Skip 'B-454 Git cannot answer' 'git is unavailable'; return }
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b454-cv-' + [guid]::NewGuid())
    try {
        $t = New-B454Target -Root $root -Name 'target' -Log 'tracked'
        $gitConfig = Join-Path $root 'empty.gitconfig'
        [IO.File]::WriteAllText($gitConfig, '', [Text.UTF8Encoding]::new($false))
        # Git that answers every question except ls-files, which this update asks only about the log: the work tree is confirmed, then the question fails.
        $stubBin = Join-Path $root 'ls-files-fails-bin'
        New-Item -ItemType Directory -Force -Path $stubBin | Out-Null
        [IO.File]::WriteAllText((Join-Path $stubBin 'git.cmd'), "@echo off`r`necho %*| findstr /C:`"ls-files`" >nul`r`nif not errorlevel 1 exit /b 86`r`n`"%B454_REAL_GIT%`" %*`r`nexit /b %ERRORLEVEL%`r`n", [Text.ASCIIEncoding]::new())
        $hostPath = (@($stubBin, (Split-Path -Parent (Get-PsExe)), (Join-Path $env:SystemRoot 'System32'), $env:SystemRoot) | Select-Object -Unique) -join [IO.Path]::PathSeparator
        $environment = @{ PATH = $hostPath; B194_PS_PATH = $hostPath; B454_REAL_GIT = $gitCommand.Source; GIT_CONFIG_GLOBAL = $gitConfig }
        $capture = Invoke-B194Installer -Target $t -PowerShellExe (Get-PsExe) -Environment $environment
        Assert ($capture.Started -and $capture.Exit -eq 0 -and $capture.Out -match 'mode: update' -and $capture.Out -match 'Done \(update\)') "the update did not finish (exit $($capture.Exit)): stdout=[$($capture.Out)] stderr=[$($capture.Err)]"
        Assert (@([regex]::Matches($capture.Out, '(?m)^CANT-VERIFY: Git could not say whether it tracks \.claude/ai-audit\.log[^\r\n]*docs/upgrade-checklist\.md')).Count -eq 1) "no single CANT-VERIFY line names the log: $($capture.Out)"
        Assert ($capture.Out -notmatch '(?m)^NOTICE: Git tracks') "a NOTICE was printed although Git could not answer: $($capture.Out)"

        # No work tree: nothing is tracked, so a Git that fails on everything is silent, as it is for the ignore rules.
        $plain = New-B194UpdateTarget -Parent $root -Name 'plain'
        $plainCapture = Invoke-B194Installer -Target $plain -PowerShellExe (Get-PsExe) -Environment $environment
        Assert ($plainCapture.Started -and $plainCapture.Exit -eq 0 -and $plainCapture.Out -match 'Done \(update\)') "the plain update did not finish (exit $($plainCapture.Exit)): stdout=[$($plainCapture.Out)] stderr=[$($plainCapture.Err)]"
        Assert ($plainCapture.Out -notmatch '(?m)^(NOTICE: Git tracks|CANT-VERIFY: Git could not say whether it tracks)') "a target outside a work tree got an audit-log line: $($plainCapture.Out)"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

# The fresh-session attack's fixture: a target one folder below the repository root, 'My App' on disk, whose files Git records
# below 'MY APP/' (two git mv and a commit) while the disk folder is set back to 'My App' by two renames, as a checkout on a
# case-insensitive disk keeps the old spelling. Git takes the prefix from the disk, so a pathspec run from the folder does not
# fold its case: status is clean and the log is tracked, yet 'ls-files :(icase,literal).claude/ai-audit.log' finds nothing there.
function New-B454DriftTarget {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Name, [switch]$SkipWorktree)
    $repo = New-B309GitTarget -Root $Root -Name $Name -Ignore "bin/`n"
    $t = Join-Path $repo 'My App'
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    $first = Invoke-Installer -Dist 'dotnet' -Target $t
    Assert ($LASTEXITCODE -eq 0 -and $first -match 'mode: greenfield') "calibration: the first install failed (exit $LASTEXITCODE): $first"
    [IO.File]::WriteAllText((Join-Path $t '.claude/ai-audit.log'), "2026-05-01T09:00:00Z main src/Orders.cs`n", [Text.UTF8Encoding]::new($false))
    & git -C $repo add -A
    & git -C $repo add -f -- 'My App/.claude/ai-audit.log'
    & git -C $repo commit -qm 'framework install'
    & git -C $repo mv 'My App' 'b454-tmp'
    & git -C $repo mv 'b454-tmp' 'MY APP'
    & git -C $repo commit -qm 'folder case'
    Rename-Item -LiteralPath (Join-Path $repo 'MY APP') -NewName 'b454-tmp'
    Rename-Item -LiteralPath (Join-Path $repo 'b454-tmp') -NewName 'My App'
    if ($SkipWorktree) { & git -C $repo update-index --skip-worktree -- 'MY APP/.claude/ai-audit.log' }
    Assert (@(Get-ChildItem -LiteralPath $repo -Directory -Force | Where-Object { $_.Name -ceq 'My App' }).Count -eq 1) 'calibration: the disk folder is not My App'
    Assert (@(& git -C $repo ls-files | Where-Object { $_ -ceq 'MY APP/.claude/ai-audit.log' }).Count -eq 1) 'calibration: Git does not record the log below MY APP/'
    Assert (@(& git -C $t ls-files -- ':(icase,literal).claude/ai-audit.log').Count -eq 0) 'calibration: the pathspec run from the folder finds the log'
    Assert ((& git -C $repo status --porcelain --untracked-files=all | Out-String).Trim() -eq '') 'calibration: the drift fixture is not clean before the update'
    return [pscustomobject]@{ Repo = $repo; Target = $t }
}

It 'B-454 attack: a subfolder install whose folder Git records in another letter case than the disk holds is still found, and the printed commands, run from the repository root, untrack the log, skip-worktree or not' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b454-drift-' + [guid]::NewGuid())
    try {
        foreach ($skip in $false, $true) {
            $label = if ($skip) { 'skip-worktree' } else { 'plain' }
            $fixture = New-B454DriftTarget -Root $root -Name "drift-$label" -SkipWorktree:$skip
            $logBytes = [IO.File]::ReadAllBytes((Join-Path $fixture.Target '.claude/ai-audit.log'))
            $out = Invoke-Installer -Dist 'dotnet' -Target $fixture.Target
            Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: update') "${label}: the update failed (exit $LASTEXITCODE): $out"
            Assert (@([regex]::Matches($out, '(?m)^NOTICE: Git tracks MY APP/\.claude/ai-audit\.log, which this release ignores \(\.claude/\.gitignore\)\. ')).Count -eq 1) "${label}: the handoff has not exactly one NOTICE naming the log as Git records it: $out"
            Assert ($out -notmatch '(?m)^CANT-VERIFY: Git could not say whether it tracks') "${label}: the handoff also says Git could not answer: $out"
            $expected = if ($skip) { "git update-index --no-skip-worktree -- 'MY APP/.claude/ai-audit.log'  and then  git rm --cached -- 'MY APP/.claude/ai-audit.log'" } else { "git rm --cached -- 'MY APP/.claude/ai-audit.log'" }
            $command = Invoke-B454PrintedCommands -Output $out -Root $fixture.Repo
            Assert ($command -ceq $expected) "${label}: unexpected command: $command"
            Assert (@(& git -C $fixture.Repo ls-files -- ':(top,icase,glob)**/.claude/ai-audit.log').Count -eq 0) "${label}: the printed commands left the log tracked"
            Assert (Test-B194BytesEqual $logBytes ([IO.File]::ReadAllBytes((Join-Path $fixture.Target '.claude/ai-audit.log')))) "${label}: the printed commands changed the local log"
        }
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-454 attack: a target folder named with spaces, brackets, a quote and a dollar sign gets a printed command that works when pasted into PowerShell, and the CANT-VERIFY query is run from the repository root' {
    $gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $gitCommand) { Skip 'B-454 attack: special folder name' 'git is unavailable'; return }
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b454-name-' + [guid]::NewGuid())
    try {
        # Windows allows each of these in a folder name; git rm reads its argument as a pathspec, so [App] needs ':(literal)'.
        $folder = "Dev [App] it's `$x"
        $repo = New-B309GitTarget -Root $root -Name 'repo' -Ignore "bin/`n"
        $t = Join-Path $repo $folder
        New-Item -ItemType Directory -Force -Path $t | Out-Null
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $first -match 'mode: greenfield') "calibration: the first install failed (exit $LASTEXITCODE): $first"
        [IO.File]::WriteAllText((Join-Path $t '.claude/ai-audit.log'), "2026-05-01T09:00:00Z main src/Orders.cs`n", [Text.UTF8Encoding]::new($false))
        & git -C $repo add -A
        & git -C $repo --literal-pathspecs add -f -- "$folder/.claude/ai-audit.log"
        & git -C $repo commit -qm 'framework install'
        Assert (@(& git -C $repo ls-files | Where-Object { $_ -ceq "$folder/.claude/ai-audit.log" }).Count -eq 1) 'calibration: Git does not track the log below the odd folder'
        Assert ((& git -C $repo status --porcelain --untracked-files=all | Out-String).Trim() -eq '') 'calibration: the fixture is not clean before the update'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: update') "the update failed (exit $LASTEXITCODE): $out"
        $expected = "git rm --cached -- '" + ":(literal)$folder/.claude/ai-audit.log".Replace("'", "''") + "'"
        $command = Invoke-B454PrintedCommands -Output $out -Root $repo
        Assert ($command -ceq $expected) "unexpected command: $command"
        Assert (@(& git -C $repo ls-files -- ':(top,icase,glob)**/.claude/ai-audit.log').Count -eq 0) 'the printed command left the log tracked'

        # The CANT-VERIFY line's query must find a case-drifted log from the repository root, whatever folder the update ran in.
        $gitConfig = Join-Path $root 'empty.gitconfig'
        [IO.File]::WriteAllText($gitConfig, '', [Text.UTF8Encoding]::new($false))
        $stubBin = Join-Path $root 'ls-files-fails-bin'
        New-Item -ItemType Directory -Force -Path $stubBin | Out-Null
        [IO.File]::WriteAllText((Join-Path $stubBin 'git.cmd'), "@echo off`r`necho %*| findstr /C:`"ls-files`" >nul`r`nif not errorlevel 1 exit /b 86`r`n`"%B454_REAL_GIT%`" %*`r`nexit /b %ERRORLEVEL%`r`n", [Text.ASCIIEncoding]::new())
        $hostPath = (@($stubBin, (Split-Path -Parent (Get-PsExe)), (Join-Path $env:SystemRoot 'System32'), $env:SystemRoot) | Select-Object -Unique) -join [IO.Path]::PathSeparator
        $drift = New-B454DriftTarget -Root $root -Name 'drift-cv'
        $capture = Invoke-B194Installer -Target $drift.Target -PowerShellExe (Get-PsExe) -Environment @{ PATH = $hostPath; B194_PS_PATH = $hostPath; B454_REAL_GIT = $gitCommand.Source; GIT_CONFIG_GLOBAL = $gitConfig }
        $line = [regex]::Match($capture.Out, '(?m)^CANT-VERIFY: Git could not say whether it tracks \.claude/ai-audit\.log[^\r\n]*$')
        Assert $line.Success "no CANT-VERIFY line names the log: stdout=[$($capture.Out)] stderr=[$($capture.Err)]"
        Assert ($line.Value -match 'From the repository root, run  git ls-files -- "([^"]+)"') "the CANT-VERIFY query is not run from the repository root: $($line.Value)"
        Push-Location -LiteralPath $drift.Repo
        try { $found = @(& git ls-files -- $Matches[1]) } finally { Pop-Location }
        Assert ($found.Count -eq 1 -and $found[0] -ceq 'MY APP/.claude/ai-audit.log') "the printed query does not find the case-drifted log from the repository root: [$($found -join ',')]"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-309 when Git answers that nothing is ignored, the handoff does not guess' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b309-none-' + [guid]::NewGuid())
    try {
        # An empty answer reached the caller as $null, the "could not answer" value, so the generic
        # gitignored-secrets line still printed after Git had said nothing was ignored.
        $t = New-B309GitTarget -Root $root -Name 'target' -Ignore "bin/`n"
        [IO.File]::WriteAllText((Join-Path $t 'TECH_DEBT.md'), "# team debt`n", [Text.UTF8Encoding]::new($false))
        & git -C $t add TECH_DEBT.md
        & git -C $t commit -qm debt
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'Moved to docs/pre-adoption/[^\r\n]*TECH_DEBT\.md') "calibration: the tracked collision was not archived: $out"
        Assert ($out -notmatch 'Some may be files you had gitignored' -and $out -notmatch 'Kept out of Git') "the handoff guessed at gitignored files although Git answered: $out"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-297 a tracked collision spelt differently from the shipped name records the spelling Git tracks' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b297-' + [guid]::NewGuid())
    try {
        # GitHub documents pull_request_template.md in lower case; the disk found it under the
        # shipped upper-case name, Git's case-sensitive pathspecs did not, so the evidence said
        # untracked and /adopt read history at a path that never existed.
        $t = New-B309GitTarget -Root $root -Name 'target' -Ignore "bin/`n"
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.github') | Out-Null
        $template = [Text.UTF8Encoding]::new($false).GetBytes("## Summary`n")
        [IO.File]::WriteAllBytes((Join-Path $t '.github/pull_request_template.md'), $template)
        & git -C $t add .github/pull_request_template.md
        & git -C $t commit -qm template
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: brownfield') "the brownfield install failed: $out"
        $marker = [IO.File]::ReadAllText((Join-Path $t '.claude/adoption-pending.json')) | ConvertFrom-Json
        $entry = @($marker.archiveIntegrity.entries | Where-Object { $_.destination -ceq 'docs/pre-adoption/.github/PULL_REQUEST_TEMPLATE.md' })
        Assert ($entry.Count -eq 1) "no archive entry for the template: $(@($marker.archiveIntegrity.entries | ForEach-Object { $_.destination }) -join ', ')"
        Assert ($entry[0].originalPath -ceq '.github/pull_request_template.md' -and $entry[0].provenance -ceq 'tracked' -and $entry[0].localModification -ceq 'clean' -and $entry[0].provenanceRevision -match '^[0-9a-f]{40}$') "the evidence does not name the tracked file: $($entry[0] | ConvertTo-Json -Compress)"
        $history = & git -C $t show "$($entry[0].provenanceRevision):$($entry[0].originalPath)" 2>&1 | Out-String
        Assert ($LASTEXITCODE -eq 0 -and $history -match '## Summary') "history cannot be read at the recorded path: $history"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

# A case-sensitive folder (WSL makes them; fsutil setCaseSensitiveInfo) can hold two case variants.
$caseSensitiveProbe = Join-Path ([IO.Path]::GetTempPath()) ('case-sensitive-probe-' + [guid]::NewGuid())
$caseSensitiveFoldersAvailable = $false
try {
    [void][IO.Directory]::CreateDirectory($caseSensitiveProbe)
    & fsutil.exe file setCaseSensitiveInfo $caseSensitiveProbe enable 2>&1 | Out-Null
    [IO.File]::WriteAllText((Join-Path $caseSensitiveProbe 'a.txt'), 'lower')
    [IO.File]::WriteAllText((Join-Path $caseSensitiveProbe 'A.txt'), 'upper')
    $caseSensitiveFoldersAvailable = @([IO.Directory]::GetFiles($caseSensitiveProbe)).Count -eq 2
} catch { $caseSensitiveFoldersAvailable = $false }
finally { Remove-Item -LiteralPath $caseSensitiveProbe -Recurse -Force -ErrorAction SilentlyContinue }

if (-not $caseSensitiveFoldersAvailable) {
    Skip 'B-297 a gitignored file beside a tracked case variant keeps the shipped spelling and untracked provenance' 'host cannot create a case-sensitive folder'
} else {
It 'B-297 a gitignored file beside a tracked case variant keeps the shipped spelling and untracked provenance' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b297-cs-' + [guid]::NewGuid())
    try {
        # Only the gitignored upper-case file collides and is archived. Borrowing the tracked variant's
        # spelling made the evidence say tracked, so /adopt's personal-file exception never applied.
        $t = New-B309GitTarget -Root $root -Name 'target' -Ignore "bin/`n"
        $github = Join-Path $t '.github'
        [void][IO.Directory]::CreateDirectory($github)
        & fsutil.exe file setCaseSensitiveInfo $github enable | Out-Null
        [IO.File]::WriteAllText((Join-Path $github 'pull_request_template.md'), "## Team template`n", [Text.UTF8Encoding]::new($false))
        & git -C $t add .github/pull_request_template.md
        & git -C $t commit -qm template
        [IO.File]::AppendAllText((Join-Path $t '.gitignore'), "/.github/PULL_REQUEST_TEMPLATE.md`n", [Text.UTF8Encoding]::new($false))
        & git -C $t commit -qam 'ignore the personal template'
        [IO.File]::WriteAllText((Join-Path $github 'PULL_REQUEST_TEMPLATE.md'), "API_KEY=fixture-not-a-secret`n", [Text.UTF8Encoding]::new($false))
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: brownfield') "the brownfield install failed: $out"
        $marker = [IO.File]::ReadAllText((Join-Path $t '.claude/adoption-pending.json')) | ConvertFrom-Json
        $entry = @($marker.archiveIntegrity.entries | Where-Object { $_.destination -ceq 'docs/pre-adoption/.github/PULL_REQUEST_TEMPLATE.md' })
        Assert ($entry.Count -eq 1) "no archive entry for the template: $(@($marker.archiveIntegrity.entries | ForEach-Object { $_.destination }) -join ', ')"
        Assert ($entry[0].originalPath -ceq '.github/PULL_REQUEST_TEMPLATE.md' -and $entry[0].provenance -ceq 'untracked') "the gitignored file borrowed the tracked variant's history: $($entry[0] | ConvertTo-Json -Compress)"
        $archived = [IO.File]::ReadAllText((Join-Path $t 'docs/pre-adoption/.github/PULL_REQUEST_TEMPLATE.md'))
        Assert ($archived -match 'API_KEY') "calibration: the archive is not the gitignored file: $archived"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}
}

It 'B-306 the doctor reports no phantom retired files in a folder whose name holds brackets' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b306-' + [guid]::NewGuid())
    try {
        # Windows PowerShell 5.1 returns nothing, instead of throwing, for a missing path under a bracketed
        # folder; the doctor read each gap as an entry and reported absent retired files as residue.
        $t = Join-Path $root 'br[k]'
        [void][IO.Directory]::CreateDirectory($t)
        [IO.File]::WriteAllBytes((Join-Path $t 'App.csproj'), [Text.Encoding]::ASCII.GetBytes('<Project />'))
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: greenfield') "calibration: the install failed: $out"
        & git -C $t init -q
        # A relative -File: Windows PowerShell 5.1 reads a bracketed absolute -File path as a wildcard.
        Push-Location -LiteralPath $t
        try { $d = & (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File 'scripts/framework-doctor.ps1' 2>&1 | Out-String } finally { Pop-Location }
        Assert ($d -match '\[OK\] Legacy Git-hook retirement - no default pre-commit hook or retired Git-hook helper remains') "phantom retired hook helpers:`n$d"
        Assert ($d -match '\[OK\] Retired framework residue - none of the 18 v0\.83 retired framework paths remains') "phantom retired framework residue:`n$d"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-312 a developer''s Claude Code local settings stay out of Git after install' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b312-' + [guid]::NewGuid())
    try {
        # The framework's .claude/.gitignore replaces a consumer copy that ignored this file.
        $t = New-B309GitTarget -Root $root -Name 'target' -Ignore "bin/`n"
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the install failed: $out"
        [IO.File]::WriteAllText((Join-Path $t '.claude/settings.local.json'), "{`"env`":{`"API_KEY`":`"sk-FIXTURE`"}}`n", [Text.UTF8Encoding]::new($false))
        $status = (& git -C $t status --porcelain --ignored -- ':(literal).claude/settings.local.json' | Out-String)
        Assert ($status -match '^!! \.claude/settings\.local\.json') "Claude Code's per-developer settings are committable after install: $status"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

# One case on both hosts keeps the CI case-count parity: only Windows PowerShell 5.1 returns nothing,
# instead of throwing, for a missing path under a directory whose name holds brackets.
It 'B-301 a bracketed target gets no false CANT-VERIFY line on first install or update' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b301-' + [guid]::NewGuid())
    try {
        # 5.1 reported phantom paths there at exit 0: 21 CANT-VERIFY lines on first install, 80 on update.
        $t = Join-Path $root 'u[c]'
        [void][IO.Directory]::CreateDirectory($t)
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        $firstExit = $LASTEXITCODE
        # An absent retired path the previous install owned reaches the retirement inspection too.
        $manifestPath = Join-Path $t 'framework-ownership.json'
        $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
        $manifest.paths = @($manifest.paths) + @([pscustomobject]@{ path = 'scripts/sync-agent-files.ps1'; ownership = 'framework-owned/overwritten' })
        [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), [Text.UTF8Encoding]::new($false))
        & git -C $t init -q
        & git -C $t add -A
        & git -C $t -c user.name=fixture -c user.email=fixture@example.invalid commit -qm install
        $update = Invoke-Installer -Dist 'dotnet' -Target $t
        $updateExit = $LASTEXITCODE
        Assert ($firstExit -eq 0 -and $first -match 'mode: greenfield') "the first install failed (exit $firstExit): $first"
        Assert ($first -notmatch 'CANT-VERIFY') "the first install reported CANT-VERIFY for a bracketed target: $first"
        Assert ($updateExit -eq 0 -and $update -match 'mode: update') "the update failed (exit $updateExit): $update"
        Assert ($update -notmatch 'CANT-VERIFY|sync-agent-files') "the update reported CANT-VERIFY or the absent retired path for a bracketed target: $update"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

$legacyV083RetiredPaths = @(
    '.claude/hooks/audit-trail.sh',
    '.claude/hooks/boy-scout-check.sh',
    '.claude/hooks/guard.sh',
    '.claude/hooks/post-write.sh',
    '.claude/hooks/route-prompt.sh',
    '.claude/hooks/session-start.sh',
    'scripts/build-architecture-html.sh',
    'scripts/ci/bitbucket-pipelines.example.yml',
    'scripts/docs-sync-check.sh',
    'scripts/framework-doctor.sh',
    'scripts/hazard-check.sh',
    'scripts/metrics.sh',
    'scripts/setup-git-hooks.ps1',
    'scripts/setup-git-hooks.sh',
    'scripts/template-checks.sh',
    'scripts/test-weakening-scan.sh',
    'scripts/warehouse-map-check.sh',
    'scripts/wiki-check.sh'
)
It 'later updates report and preserve every v0.83 retired executable or sample residue' {
    Assert ($legacyV083RetiredPaths.Count -eq 18) 'retired residue fixture cardinality changed'
    $t = Join-Path ([IO.Path]::GetTempPath()) ('retired-residue-' + [guid]::NewGuid())
    try {
        New-Item -ItemType Directory -Force -Path $t | Out-Null
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "greenfield calibration failed: $first"
        $sentinels = @{}
        foreach ($relative in $legacyV083RetiredPaths) {
            $path = Join-Path $t $relative
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
            $bytes = [Text.UTF8Encoding]::new($false).GetBytes("RETIRED RESIDUE $relative`n")
            [IO.File]::WriteAllBytes($path, $bytes)
            $sentinels[$relative] = $bytes
        }
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "later update failed: $out"
        foreach ($relative in $legacyV083RetiredPaths) {
            $path = Join-Path $t $relative
            Assert (Test-B194BytesEqual $sentinels[$relative] ([IO.File]::ReadAllBytes($path))) "later update changed retired residue $relative"
            Assert ($out -match [regex]::Escape("'$relative'")) "later update made retired residue invisible: $relative"
        }
        # 'generator' joined this set when the architecture viewer retired: build-architecture-html.sh
        # is one of the 18 planted paths and now gets a message naming its canonical Markdown
        # replacement instead of the generic one. The >= 18 floor is unchanged -- every planted
        # residue must still be diagnosed.
        Assert (@([regex]::Matches($out, "CANT-VERIFY: retained retired (?:framework path|sample|Git-hook helper|generator) '")).Count -ge 18) 'retired residue diagnostics were unexpectedly empty or incomplete'
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

function Get-GitBlobBytes {
    param([Parameter(Mandatory)][string]$Spec)
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    # Aggregate children do not inherit the repository as their current directory reliably.
    # Bind the object read to the explicit repo instead of ambient process state.
    $start.WorkingDirectory = $repoRoot
    $start.Arguments = "cat-file blob $Spec"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    if (-not $process.Start()) { throw "could not start git cat-file for $Spec" }
    $memory = New-Object IO.MemoryStream
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $errorText = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw "git cat-file failed for $Spec (exit $($process.ExitCode)): $errorText" }
        return ,$memory.ToArray()
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

It 'wrong-case previous ownership cannot authorize canonical retirement deletion' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('retired-wrong-case-' + [guid]::NewGuid())
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $t 'scripts') | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.82.0"}', [Text.UTF8Encoding]::new($false))
        $manifestBytes = Get-GitBlobBytes -Spec 'v0.82.0:dist/dotnet/framework-ownership.json'
        Assert ($manifestBytes.Count -gt 0) 'the v0.82.0 ownership manifest fixture is empty'
        $manifest = [Text.UTF8Encoding]::new($false, $true).GetString($manifestBytes)
        $anchor = '"path": "scripts/wiki-check.sh"'
        Assert ([regex]::Matches($manifest, [regex]::Escape($anchor)).Count -eq 1) 'historical manifest lacks the one canonical retirement entry'
        $manifest = $manifest.Replace($anchor, '"path": "Scripts/Wiki-Check.sh"')
        [IO.File]::WriteAllText((Join-Path $t 'framework-ownership.json'), $manifest, [Text.UTF8Encoding]::new($false))
        $canonical = Join-Path $t 'scripts/wiki-check.sh'
        $historicalBytes = Get-GitBlobBytes -Spec 'v0.82.0:dist/dotnet/scripts/wiki-check.sh'
        Assert ($historicalBytes.Count -gt 0) 'historical retirement blob fixture is empty'
        [IO.File]::WriteAllBytes($canonical, $historicalBytes)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "wrong-case retirement update failed: $out"
        Assert (Test-Path -LiteralPath $canonical -PathType Leaf) 'wrong-case previous manifest authorized canonical deletion'
        Assert (Test-B194BytesEqual $historicalBytes ([IO.File]::ReadAllBytes($canonical))) 'wrong-case retirement changed canonical bytes'
        Assert ($out -notmatch '(?m)^PLAN delete scripts/wiki-check\.sh\r?$') "wrong-case entry entered the retirement delete plan: $out"
        Assert ($out -match "CANT-VERIFY: retained retired framework path 'scripts/wiki-check\.sh'") "preserved canonical residue was not diagnosed: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

# --- B-239: architecture viewer retirement -------------------------------------------------------
# Two different mechanisms, deliberately: docs/architecture.html is an ORDINARY overwrite (ledger
# deletion is hash-gated and would preserve exactly the consumer-regenerated pages that carry the
# exposure), while the generator is a LEDGER retirement. These are kept separate from the v0.83
# residue fixture above, whose 18-path cardinality contract is about a different release.

It 'update replaces the retired architecture view and preserves the protected Markdown' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('arch-retire-replace-' + [guid]::NewGuid())
    try {
        New-Item -ItemType Directory -Force -Path $t | Out-Null
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "greenfield calibration failed: $first"
        $legacyPage = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/docs/architecture.html'
        Assert ($legacyPage.Count -gt 0) 'legacy architecture page fixture is empty'
        [IO.File]::WriteAllBytes((Join-Path $t 'docs/architecture.html'), $legacyPage)
        $markdownPath = Join-Path $t 'docs/ARCHITECTURE.md'
        [IO.File]::WriteAllText($markdownPath, "# Consumer architecture`n`nlocally edited`n", [Text.UTF8Encoding]::new($false))
        $markdownBefore = [IO.File]::ReadAllBytes($markdownPath)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "retirement update failed: $out"
        Assert ($out -match '(?m)^PLAN replace docs/architecture\.html\r?$') "the retired view was not classified as an ordinary replacement: $out"
        $shipped = [IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/docs/architecture.html'))
        Assert (Test-B194BytesEqual $shipped ([IO.File]::ReadAllBytes((Join-Path $t 'docs/architecture.html')))) 'installed architecture page is not the shipped inert page'
        Assert (Test-B194BytesEqual $markdownBefore ([IO.File]::ReadAllBytes($markdownPath))) 'update modified the protected architecture Markdown'
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

function New-ArchGeneratorTarget {
    param([Parameter(Mandatory)][string]$Target)
    New-Item -ItemType Directory -Force -Path (Join-Path $Target '.claude') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $Target 'scripts') | Out-Null
    [IO.File]::WriteAllText((Join-Path $Target '.claude/framework-version.json'), '{"version":"0.86.7"}', [Text.UTF8Encoding]::new($false))
}

It 'a known retired generator is deleted and a consumer-modified one is preserved and diagnosed' {
    foreach ($modified in @($false, $true)) {
        $label = if ($modified) { 'modified' } else { 'known' }
        $t = Join-Path ([IO.Path]::GetTempPath()) ("arch-retire-gen-$label-" + [guid]::NewGuid())
        try {
            New-ArchGeneratorTarget -Target $t
            $manifestBytes = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/framework-ownership.json'
            Assert ($manifestBytes.Count -gt 0) 'the v0.86.7 ownership manifest fixture is empty'
            [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), $manifestBytes)
            $generator = Join-Path $t 'scripts/build-architecture-html.ps1'
            $bytes = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/scripts/build-architecture-html.ps1'
            Assert ($bytes.Count -gt 0) 'historical generator fixture is empty'
            if ($modified) { $bytes = $bytes + [Text.UTF8Encoding]::new($false).GetBytes("# locally edited`n") }
            [IO.File]::WriteAllBytes($generator, $bytes)
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "$label generator update failed: $out"
            if ($modified) {
                Assert (Test-Path -LiteralPath $generator -PathType Leaf) 'a consumer-modified generator was deleted'
                Assert (Test-B194BytesEqual $bytes ([IO.File]::ReadAllBytes($generator))) 'a preserved generator changed bytes'
                Assert ($out -match "CANT-VERIFY: retired path 'scripts/build-architecture-html\.ps1' has consumer-modified or unknown content") "modified generator was not diagnosed: $out"
            } else {
                Assert (-not (Test-Path -LiteralPath $generator)) 'a known retired generator survived the update'
                Assert ($out -match '(?m)^PLAN delete scripts/build-architecture-html\.ps1\r?$') "known generator deletion was not planned: $out"
            }
        } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

It 'B-308 a retired file another program holds open stops the update unchanged, and a plain re-run finishes it' {
    foreach ($useGit in @($false, $true)) {
        $label = if ($useGit) { 'git' } else { 'plain' }
        $t = Join-Path ([IO.Path]::GetTempPath()) ("b308-$label-" + [guid]::NewGuid())
        $handle = $null
        try {
            # The unguarded delete threw a raw error (exit 1). The held file sorts second, so the first is
            # already deleted when the stop comes; putting it back keeps a Git target clean, which a plain
            # re-run needs, and the old ownership manifest keeps the authority to delete.
            New-ArchGeneratorTarget -Target $t
            [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/framework-ownership.json'))
            $first = Join-Path $t '.claude/commands/impact.md'
            $held = Join-Path $t 'scripts/build-architecture-html.ps1'
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $first) | Out-Null
            $firstBytes = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/.claude/commands/impact.md'
            [IO.File]::WriteAllBytes($first, $firstBytes)
            [IO.File]::WriteAllBytes($held, (Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/scripts/build-architecture-html.ps1'))
            if ($useGit) {
                & git -C $t init -q
                & git -C $t add -A
                & git -C $t -c user.name=tests -c user.email=tests@example.invalid commit -qm 'v0.86.7 install'
            }
            $manifestBefore = [IO.File]::ReadAllBytes((Join-Path $t 'framework-ownership.json'))
            # Another program reading the file without sharing delete, as an editor or a scanner does.
            $handle = [IO.File]::Open($held, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $flat = $out -replace '\s+', ' '
            Assert ($LASTEXITCODE -eq 3) "${label}: a held retired file did not stop the update with exit 3 (exit $LASTEXITCODE): $out"
            Assert ($flat -match "Could not delete retired framework file 'scripts/build-architecture-html\.ps1'") "${label}: the stop did not name the held file: $out"
            Assert ($flat -match 'was put back with its original content') "${label}: the stop did not say the deleted file was put back: $out"
            Assert ($flat -notmatch 'retired: \.claude/commands/impact\.md') "${label}: the stop reported a put-back file as retired: $out"
            Assert ((Test-Path -LiteralPath $first) -and (Test-B194BytesEqual $firstBytes ([IO.File]::ReadAllBytes($first)))) "${label}: the retired file deleted before the stop was not put back: $out"
            Assert ([IO.File]::ReadAllText((Join-Path $t '.claude/framework-version.json')) -match '0\.86\.7') "${label}: the stamp was replaced before the update finished: $out"
            Assert (Test-B194BytesEqual $manifestBefore ([IO.File]::ReadAllBytes((Join-Path $t 'framework-ownership.json')))) "${label}: the ownership manifest was replaced before the update finished: $out"
            if ($useGit) {
                $status = @(& git -C $t status --porcelain)
                Assert ($status.Count -eq 0) "git: the stop left the tree dirty, so a plain re-run would refuse: $($status -join '; ')"
            }
            $handle.Dispose(); $handle = $null
            $rerun = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0 -and -not (Test-Path -LiteralPath $held) -and -not (Test-Path -LiteralPath $first)) "${label}: a plain re-run did not finish the update (exit $LASTEXITCODE): $rerun"
        } finally {
            if ($handle) { $handle.Dispose() }
            Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

It 'B-320 an active copy of a disabled skill that cannot be removed is the only step left undone, and the stop says so' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b320-' + [guid]::NewGuid())
    $handle = $null
    try {
        # The disabled skill's files are carried to .claude/disabled-skills before the active copy goes. A
        # held file there threw a raw error mid-update, and a stop at that point skipped the instruction
        # layout move that followed it, which a re-run then declines.
        New-ArchGeneratorTarget -Target $t
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/framework-ownership.json'))
        [IO.File]::WriteAllText((Join-Path $t 'LEARNINGS.md'), "# Learnings`n`n## Disabled framework skill: perf`n`nNot used here.`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $t 'CLAUDE.md'), "# Project`n`nB320 consumer rule.`n", [Text.UTF8Encoding]::new($false))
        $active = Join-Path $t '.claude/skills/perf'
        New-Item -ItemType Directory -Force -Path $active | Out-Null
        $held = Join-Path $active 'SKILL.md'
        [IO.File]::WriteAllText($held, "---`nname: perf`n---`n# perf`n", [Text.UTF8Encoding]::new($false))
        $handle = [IO.File]::Open($held, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 3) "a held file in a disabled skill's active copy did not stop the update with exit 3 (exit $LASTEXITCODE): $out"
        Assert ($flat -match "Could not remove the active copy of disabled skill '\.claude/skills/perf'") "the stop did not name the skill: $out"
        Assert (Test-Path -LiteralPath (Join-Path $t '.claude/disabled-skills/perf/SKILL.md')) "calibration: the disabled skill was not carried before the delete: $out"
        Assert ([IO.File]::ReadAllText((Join-Path $t 'AGENTS.md')) -match 'B320 consumer rule\.') "the stop skipped the instruction layout move: AGENTS.md does not hold the moved CLAUDE.md text: $out"
        Assert ($flat -match 'kept under \.claude/disabled-skills/perf' -and $flat -match 'delete \.claude/skills/perf by hand' -and
            $flat -match 'Every other step of this update is done') "the stop did not say where the files are kept and what is left: $out"
    } finally {
        if ($handle) { $handle.Dispose() }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-252 the presentation deck stays in the framework checkout: an update removes its installed copies and points an edited one there' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b252-' + [guid]::NewGuid())
    try {
        # Every install copied four deck files (about 97 KB) into docs/presentation/, which nothing
        # installed links to; the deck now stays in the checkout under presentation/.
        foreach ($stack in 'dotnet', 'angular', 'monorepo') {
            $manifest = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "dist/$stack/framework-ownership.json") | ConvertFrom-Json
            Assert (@($manifest.paths | Where-Object { ([string]$_.path) -match 'presentation' }).Count -eq 0) "$stack ownership manifest still installs the deck"
            Assert (Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/presentation/framework-briefing.html") -PathType Leaf) "$stack checkout lost the deck"
        }
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude'), (Join-Path $t 'docs/presentation') | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.89.2","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.89.2:dist/dotnet/framework-ownership.json'))
        foreach ($name in 'TALKING-POINTS.md', 'framework-briefing.html', 'framework-system-map.html', 'framework-technical.html') {
            [IO.File]::WriteAllBytes((Join-Path $t "docs/presentation/$name"), (Get-GitBlobBytes -Spec "v0.89.2:dist/dotnet/docs/presentation/$name"))
        }
        # An unmodified file in a CRLF checkout, and a consumer's edit to another.
        $map = Join-Path $t 'docs/presentation/framework-system-map.html'
        [IO.File]::WriteAllText($map, ([IO.File]::ReadAllText($map) -replace "`r?`n", "`r`n"), [Text.UTF8Encoding]::new($false))
        $talking = Join-Path $t 'docs/presentation/TALKING-POINTS.md'
        [IO.File]::AppendAllText($talking, "`nB252 consumer note.`n")
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        foreach ($name in 'framework-briefing.html', 'framework-system-map.html', 'framework-technical.html') {
            Assert (-not (Test-Path -LiteralPath (Join-Path $t "docs/presentation/$name"))) "the update left the unmodified deck file $name installed: $out"
        }
        Assert ([IO.File]::ReadAllText($talking) -match 'B252 consumer note\.') "the update removed or changed the edited talking points: $out"
        Assert ($flat -match "retained retired presentation file 'docs/presentation/TALKING-POINTS\.md' remains\. The deck is no longer installed") "the kept copy was not reported as the retired deck: $out"
        # Whitespace removed: Windows PowerShell 5.1 may wrap a long line inside the printed path.
        Assert (($out -replace '\s+', '') -match "thecurrentcopyisin'[^']*dist[\\/]dotnet[\\/]presentation'\.Delete'docs/presentation/TALKING-POINTS\.md'afterreview") "the kept copy did not name the checkout's deck folder and only its own file: $out"
        Assert ($flat -notmatch 'no replacement command') "the kept deck copy was reported as a retired command: $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t 'presentation'))) "the update installed the checkout's presentation folder: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'retired recipe skills: an update removes an unmodified copy, keeps an edited one and the folder''s consumer files, and says what remains' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('recipe-retire-' + [guid]::NewGuid())
    try {
        # 0.92.0 stops shipping the generic "add an X" recipes; /bootstrap drafts project skills instead.
        foreach ($stack in 'dotnet', 'angular', 'monorepo') {
            foreach ($name in 'add-service', 'add-component', 'register-service') {
                Assert (-not (Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/.claude/skills/$name"))) "$stack still ships $name"
            }
        }
        $service = Join-Path $t '.claude/skills/add-service/SKILL.md'
        $pattern = Join-Path $t '.claude/skills/add-service/references/project-pattern.md'
        $component = Join-Path $t '.claude/skills/add-component/SKILL.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $pattern), (Split-Path -Parent $component) | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.91.0","template":"monorepo"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.91.0:dist/monorepo/framework-ownership.json'))
        [IO.File]::WriteAllBytes($service, (Get-GitBlobBytes -Spec 'v0.91.0:dist/monorepo/.claude/skills/add-service/SKILL.md'))
        $patternBytes = [Text.UTF8Encoding]::new($false).GetBytes("# Project pattern`nRETIRE-SIDECAR consumer evidence.`n")
        [IO.File]::WriteAllBytes($pattern, $patternBytes)
        # A pre-0.77 bootstrap appended an exemplar line, so this copy matches no shipped digest.
        $componentBytes = (Get-GitBlobBytes -Spec 'v0.91.0:dist/monorepo/.claude/skills/add-component/SKILL.md') +
            [Text.UTF8Encoding]::new($false).GetBytes("For a concrete current instance in this repo, see ``src/app/orders/orders.component.ts``.`n")
        [IO.File]::WriteAllBytes($component, $componentBytes)
        # A project skill /bootstrap drafted at a retired slug is the consumer's, not a retired framework copy.
        $discovered = Join-Path $t '.claude/skills/add-entity/SKILL.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $discovered) | Out-Null
        $discoveredBytes = [Text.UTF8Encoding]::new($false).GetBytes("---`nname: add-entity`ndescription: team recipe`norigin: discovered`n---`nTEAM RECIPE`n")
        [IO.File]::WriteAllBytes($discovered, $discoveredBytes)
        $out = Invoke-Installer -Dist 'monorepo' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath $service)) "the unmodified retired add-service SKILL.md survived: $out"
        Assert (Test-B194BytesEqual $patternBytes ([IO.File]::ReadAllBytes($pattern))) "the consumer's project-pattern.md beside a retired skill changed or vanished: $out"
        Assert ($flat -match "NOTICE: framework skill 'add-service' was retired in 0\.92\.0") "the removed recipe was not reported: $out"
        Assert ($flat -match "Remove the 'add-service' line from AGENTS\.md > Common Tasks, or run /rebootstrap full") "the removal did not name the stale Common Tasks line and the forced rebootstrap: $out"
        Assert (Test-B194BytesEqual $componentBytes ([IO.File]::ReadAllBytes($component))) "the edited retired add-component SKILL.md was not kept byte-identical: $out"
        Assert ($flat -match "'\.claude/skills/add-component/SKILL\.md' sits at the slug of a framework skill retired in 0\.92\.0 and loads as a skill, unless LEARNINGS\.md disables 'add-component'") "the kept recipe was not reported as a live skill at a retired slug: $out"
        Assert (Test-B194BytesEqual $discoveredBytes ([IO.File]::ReadAllBytes($discovered))) "the discovered skill at a retired slug changed or vanished: $out"
        Assert ($flat -notmatch "'\.claude/skills/add-entity/SKILL\.md' (remains|sits at the slug)") "a discovered project skill was reported as a retired framework skill: $out"
        Assert ($flat -notmatch "'\.claude/skills/add-component/SKILL\.md' remains\. It is retired with no replacement command") "the kept recipe was reported as a retired command: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'retired prompt files: an update removes an unmodified copy, keeps an edited one and names the skill that replaces it' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('prompt-retire-' + [guid]::NewGuid())
    try {
        # 0.94.0 ships the Copilot workflows as .agents/skills wrappers; VS Code's Copilot harness loads no prompt files.
        foreach ($stack in 'dotnet', 'angular', 'monorepo') {
            Assert (-not (Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/.github/prompts"))) "$stack still ships .github/prompts"
        }
        $feature = Join-Path $t '.github/prompts/feature.prompt.md'
        $review = Join-Path $t '.github/prompts/review.prompt.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $feature), (Join-Path $t '.claude') | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.93.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/framework-ownership.json'))
        [IO.File]::WriteAllBytes($feature, (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/.github/prompts/feature.prompt.md'))
        $reviewBytes = (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/.github/prompts/review.prompt.md') +
            [Text.UTF8Encoding]::new($false).GetBytes("Also check the team's audit-log rule.`n")
        [IO.File]::WriteAllBytes($review, $reviewBytes)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath $feature)) "the unmodified retired feature prompt survived: $out"
        Assert (Test-Path -LiteralPath (Join-Path $t '.agents/skills/feature/SKILL.md') -PathType Leaf) "the update did not install the feature skill: $out"
        Assert (Test-B194BytesEqual $reviewBytes ([IO.File]::ReadAllBytes($review))) "the edited retired review prompt was not kept byte-identical: $out"
        Assert ($flat -match "retained retired prompt file '\.github/prompts/review\.prompt\.md' remains\. Its workflow now ships as the skill \.agents/skills/review/SKILL\.md, which runs \.claude/commands/review\.md") "the kept prompt was not pointed at the skill that replaces it: $out"
        Assert ($flat -notmatch "'\.github/prompts/review\.prompt\.md' remains\. It is retired with no replacement command") "the kept prompt was reported as retired with no replacement: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'renamed /security-review: an update removes the unmodified wrapper, keeps an edited command pointed at /security-gate and names the stale references in a protected file' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('security-rename-' + [guid]::NewGuid())
    try {
        # B-388: Copilot CLI and Claude Code each ship a built-in /security-review, so 0.95.0 renames this framework's to /security-gate.
        $wrapper = Join-Path $t '.agents/skills/security-review/SKILL.md'
        $command = Join-Path $t '.claude/commands/security-review.md'
        $register = Join-Path $t 'SECURITY_FINDINGS.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $wrapper), (Split-Path -Parent $command) | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.94.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/framework-ownership.json'))
        [IO.File]::WriteAllBytes($wrapper, (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/.agents/skills/security-review/SKILL.md'))
        $commandBytes = (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/.claude/commands/security-review.md') +
            [Text.UTF8Encoding]::new($false).GetBytes("Also check the team's tenant-header rule.`n")
        [IO.File]::WriteAllBytes($command, $commandBytes)
        # SECURITY_FINDINGS.md is consumer-owned: the update keeps it, so its stale names are reported, not rewritten.
        $registerBytes = (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/SECURITY_FINDINGS.md') +
            [Text.UTF8Encoding]::new($false).GetBytes("Procedure: ``.claude/commands/security-review.md``.`n")
        [IO.File]::WriteAllBytes($register, $registerBytes)
        # A prompt file kept from 0.93.0: its successor is the renamed skill, not "no replacement command".
        $prompt = Join-Path $t '.github/prompts/security-review.prompt.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $prompt) | Out-Null
        $promptBytes = (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/.github/prompts/security-review.prompt.md') +
            [Text.UTF8Encoding]::new($false).GetBytes("Also check the team's tenant-header rule.`n")
        [IO.File]::WriteAllBytes($prompt, $promptBytes)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath $wrapper)) "the unmodified retired security-review wrapper survived: $out"
        Assert ($flat -match "NOTICE: this update removes the unmodified '\.agents/skills/security-review/SKILL\.md': this framework's /security-review is now /security-gate") "the removal did not name the new command: $out"
        Assert (Test-Path -LiteralPath (Join-Path $t '.agents/skills/security-gate/SKILL.md') -PathType Leaf) "the update did not install the security-gate wrapper: $out"
        Assert (Test-Path -LiteralPath (Join-Path $t '.claude/commands/security-gate.md') -PathType Leaf) "the update did not install the security-gate command: $out"
        Assert (Test-B194BytesEqual $commandBytes ([IO.File]::ReadAllBytes($command))) "the edited retired security-review command was not kept byte-identical: $out"
        Assert ($flat -match "CANT-VERIFY: retained retired path '\.claude/commands/security-review\.md' remains\. This framework's /security-review is now /security-gate") "the kept command was not pointed at its successor: $out"
        Assert ($flat -notmatch "'\.claude/commands/security-review\.md' remains\. It is retired with no replacement command") "the kept command was reported as retired with no replacement: $out"
        Assert (Test-B194BytesEqual $registerBytes ([IO.File]::ReadAllBytes($register))) "the protected register changed: $out"
        # The replacement must not contain the retired name itself, or applying it never clears the report.
        Assert ($flat -match "MIGRATION: protected consumer carrier 'SECURITY_FINDINGS\.md' names retired framework path '/security-review'\. It was not overwritten; replace that reference with: /security-gate\.") "the register's stale /security-review was not reported with the bare successor: $out"
        Assert ($flat -match "replace that reference with: /security-gate\. Leave a dated history entry, or a mention that deliberately names the host's own built-in command of the old name, as it is\.") "the /security-review MIGRATION did not say which mentions to keep: $out"
        Assert ($flat -match "MIGRATION: protected consumer carrier 'SECURITY_FINDINGS\.md' names retired framework path '\.claude/commands/security-review\.md'\. It was not overwritten; replace that reference with: \.claude/commands/security-gate\.md") "the register's stale command path was not reported: $out"
        Assert (Test-B194BytesEqual $promptBytes ([IO.File]::ReadAllBytes($prompt))) "the edited retired security-review prompt was not kept byte-identical: $out"
        Assert ($flat -match "retained retired prompt file '\.github/prompts/security-review\.prompt\.md' remains\. Its workflow now ships as the skill \.agents/skills/security-gate/SKILL\.md, which runs \.claude/commands/security-gate\.md") "the kept prompt was not pointed at the renamed skill: $out"
        Assert ($flat -notmatch "'\.github/prompts/security-review\.prompt\.md' remains\. It is retired with no replacement command") "the kept prompt was reported as retired with no replacement: $out"
        foreach ($stack in 'dotnet', 'angular', 'monorepo') {
            Assert (-not (Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/.claude/commands/security-review.md"))) "$stack still ships .claude/commands/security-review.md"
            Assert (-not (Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/.agents/skills/security-review"))) "$stack still ships .agents/skills/security-review"
        }
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'a team''s own skill or file at a workflow wrapper path survives updates; an edited copy of the framework''s prompt there, or a kept skill that later takes it in, is saved, never over an older save or into Git, then replaced' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('agents-skill-' + [guid]::NewGuid())
    try {
        # .agents/skills is shared with other agents; before 0.94.0 nothing the framework shipped lived there.
        $t = New-B309GitTarget -Root $root -Name 'target' -Ignore "/.agents/skills/fix/`n/.agents/skills/review/`n"
        $utf8 = [Text.UTF8Encoding]::new($false)
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude'), (Join-Path $t '.agents/skills/review'), (Join-Path $t '.agents/skills/fix'),
            (Join-Path $t '.agents/skills/adopt'), (Join-Path $t '.agents/skills/test'), (Join-Path $t '.claude/framework-update-backup/agents-skills/adopt'),
            (Join-Path $t '.claude/framework-update-backup/agents-skills/test') | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.93.0","template":"dotnet"}', $utf8)
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/framework-ownership.json'))
        $team = Join-Path $t '.agents/skills/review/SKILL.md'
        $teamBytes = $utf8.GetBytes("---`nname: review`ndescription: Team review checklist.`n---`nTEAM REVIEW CHECKLIST`n")
        [IO.File]::WriteAllBytes($team, $teamBytes)
        $design = Join-Path $t '.agents/skills/design/SKILL.md'
        $designBytes = $utf8.GetBytes("---`nname: design`ndescription: Team design notes.`n---`nTEAM DESIGN NOTES`n")
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $design) | Out-Null
        [IO.File]::WriteAllBytes($design, $designBytes)
        # A file where a wrapper's folder goes is the team's too, and must not stall the update.
        $debt = Join-Path $t '.agents/skills/debt'
        $debtBytes = $utf8.GetBytes("TEAM DEBT NOTES`n")
        [IO.File]::WriteAllBytes($debt, $debtBytes)
        # Shipped prompts converted to skills by hand, each with a line of the team's own added.
        $convert = { param($Name) $utf8.GetBytes("---`nname: $Name`ndescription: converted`n---`n") + (Get-GitBlobBytes -Spec "v0.93.0:dist/dotnet/.github/prompts/$Name.prompt.md") + $utf8.GetBytes("TEAM EDIT for ${Name}: ask before touching src/Legacy.`n") }
        $fixBytes = [byte[]](& $convert 'fix'); $adoptBytes = [byte[]](& $convert 'adopt'); $testBytes = [byte[]](& $convert 'test'); $featureBytes = [byte[]](& $convert 'feature')
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.agents/skills/feature'), (Join-Path $t '.claude/framework-update-backup/agents-skills/feature') | Out-Null
        foreach ($pair in @(@('fix', $fixBytes), @('adopt', $adoptBytes), @('test', $testBytes), @('feature', $featureBytes))) {
            [IO.File]::WriteAllBytes((Join-Path $t ".agents/skills/$($pair[0])/SKILL.md"), [byte[]]$pair[1])
        }
        # A hard link at feature's backup path is the file itself, so it is no save: an overwrite in place would reach it.
        New-Item -ItemType HardLink -Path (Join-Path $t '.claude/framework-update-backup/agents-skills/feature/SKILL.md') -Target (Join-Path $t '.agents/skills/feature/SKILL.md') | Out-Null
        Assert ([string](Get-Item -LiteralPath (Join-Path $t '.agents/skills/feature/SKILL.md')).LinkType -eq 'HardLink') 'calibration: the feature skill is not reported as a hard link'
        # adopt's backup path holds an older, different save; test's holds this very file, as after a re-run.
        $olderAdopt = $utf8.GetBytes("OLDER TEAM COPY of adopt`n")
        [IO.File]::WriteAllBytes((Join-Path $t '.claude/framework-update-backup/agents-skills/adopt/SKILL.md'), $olderAdopt)
        [IO.File]::WriteAllBytes((Join-Path $t '.claude/framework-update-backup/agents-skills/test/SKILL.md'), $testBytes)
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $adoptHash = ([BitConverter]::ToString($sha.ComputeHash($adoptBytes))).Replace('-', '').ToLowerInvariant().Substring(0, 16)
            $featureHash = ([BitConverter]::ToString($sha.ComputeHash($featureBytes))).Replace('-', '').ToLowerInvariant().Substring(0, 16)
        } finally { $sha.Dispose() }
        $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (Test-B194BytesEqual $teamBytes ([IO.File]::ReadAllBytes($team))) "the team's own .agents/skills/review/SKILL.md was not kept byte-identical: $out"
        Assert ($flat -match "'\.agents/skills/review/SKILL\.md' is not the framework's /review wrapper, so the update kept it") "the kept team skill was not reported: $out"
        Assert (Test-B194BytesEqual $designBytes ([IO.File]::ReadAllBytes($design))) "the team's own .agents/skills/design/SKILL.md was not kept byte-identical: $out"
        Assert ((Test-Path -LiteralPath $debt -PathType Leaf) -and (Test-B194BytesEqual $debtBytes ([IO.File]::ReadAllBytes($debt)))) "the team's file at .agents/skills/debt was not kept byte-identical: $out"
        Assert ($flat -match "'\.agents/skills/debt' is a file where the framework's /debt wrapper needs a folder, so the update kept it") "the kept file at a wrapper folder was not reported: $out"
        $backups = '.claude/framework-update-backup/agents-skills'
        foreach ($case in @(@('fix', $fixBytes, "$backups/fix/SKILL.md"), @('adopt', $adoptBytes, "$backups/adopt/SKILL.$adoptHash.md"), @('test', $testBytes, "$backups/test/SKILL.md"), @('feature', $featureBytes, "$backups/feature/SKILL.$featureHash.md"))) {
            $name = $case[0]
            $shipped = [IO.File]::ReadAllBytes((Join-Path $repoRoot "dist/dotnet/.agents/skills/$name/SKILL.md"))
            Assert (Test-B194BytesEqual $shipped ([IO.File]::ReadAllBytes((Join-Path $t ".agents/skills/$name/SKILL.md")))) "the converted copy of the framework's $name prompt was not replaced by the wrapper: $out"
            $saved = Join-Path $t $case[2]
            Assert ((Test-Path -LiteralPath $saved -PathType Leaf) -and (Test-B194BytesEqual ([byte[]]$case[1]) ([IO.File]::ReadAllBytes($saved)))) "the edited converted $name copy was not saved byte-identical at $($case[2]) before it was replaced: $out"
        }
        Assert ($flat -match "the update saves it to \.claude/framework-update-backup/agents-skills/fix/SKILL\.md") "the saved fix copy was not reported: $out"
        Assert (Test-B194BytesEqual $olderAdopt ([IO.File]::ReadAllBytes((Join-Path $t "$backups/adopt/SKILL.md")))) "the older save at adopt's backup path was overwritten: $out"
        Assert ($flat -match "the update saves it to \.claude/framework-update-backup/agents-skills/adopt/SKILL\.$adoptHash\.md") "the save beside the older one was not reported: $out"
        Assert ($flat -match "'\.agents/skills/test/SKILL\.md' is already saved at \.claude/framework-update-backup/agents-skills/test/SKILL\.md") "the earlier run's save was not recognised: $out"
        Assert (@(Get-ChildItem -LiteralPath (Join-Path $t "$backups/test") -File).Count -eq 1) "an earlier run's identical save was copied again: $out"
        # No save below the backup folder may become committable, the gitignored fix skill's least of all.
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'agents-skills/fix/SKILL\.md') "the gitignored fix skill's saved copy is committable: $status"
        Assert ($status -notmatch 'framework-update-backup/') "a save under the backup folder is committable: $status"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
        Assert (Test-Path -LiteralPath (Join-Path $t '.agents/skills/bootstrap/SKILL.md') -PathType Leaf) "the update did not install the other wrappers: $out"
        # The ignore-rule warning counts the framework's own hidden wrapper and never the team's kept review skill,
        # which the same rules hide; two hidden files would print as '.agents/ (2 files)'.
        Assert ($out -match "ignore rules hide 1 of the framework's own files[^`r`n]*: \.agents/skills/fix/SKILL\.md\.") "the ignore-rule warning does not name exactly the hidden fix wrapper, so it counts the kept team skill as a framework file: $out"
        # A kept path stays out of the manifest the update writes, so the next update cannot take it for the framework's.
        $owned = (Get-Content -Raw -LiteralPath (Join-Path $t 'framework-ownership.json') | ConvertFrom-Json).paths | ForEach-Object { [string]$_.path }
        Assert (($owned -cnotcontains '.agents/skills/review/SKILL.md') -and ($owned -cnotcontains '.agents/skills/debt/SKILL.md') -and ($owned -ccontains '.agents/skills/fix/SKILL.md')) "the written manifest claims a kept team path or drops an installed wrapper: $($owned -join ', ')"
        # The team then folds the retained review prompt into its own skill, as the retained-prompt message suggests.
        $mergedBytes = [byte[]]($teamBytes + (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/.github/prompts/review.prompt.md'))
        [IO.File]::WriteAllBytes($team, $mergedBytes)
        $again = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the second update failed (exit $LASTEXITCODE): $again"
        Assert (Test-B194BytesEqual $designBytes ([IO.File]::ReadAllBytes($design))) "the second update did not keep the team's own design skill: $again"
        $reviewSave = Join-Path $t "$backups/review/SKILL.md"
        Assert ((Test-Path -LiteralPath $reviewSave -PathType Leaf) -and (Test-B194BytesEqual $mergedBytes ([IO.File]::ReadAllBytes($reviewSave)))) "the second update replaced the team's merged review skill without saving it: $again"
        Assert (Test-B194BytesEqual $debtBytes ([IO.File]::ReadAllBytes($debt))) "the second update did not keep the team's file at .agents/skills/debt: $again"
        Assert (Test-B194BytesEqual $fixBytes ([IO.File]::ReadAllBytes((Join-Path $t "$backups/fix/SKILL.md")))) "the second update changed the saved copy: $again"
        Assert (Test-B194BytesEqual $olderAdopt ([IO.File]::ReadAllBytes((Join-Path $t "$backups/adopt/SKILL.md")))) "the second update changed the older save: $again"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'a linked .agents/skills is kept by an install and by an update, which leave the wrappers out instead of refusing or writing through it' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('agents-link-' + [guid]::NewGuid())
    try {
        # A team that shares skills between agents may link .agents/skills to one folder; before 0.94.0 nothing shipped there.
        $utf8 = [Text.UTF8Encoding]::new($false)
        foreach ($mode in 'update', 'greenfield') {
            $t = Join-Path $root $mode
            $shared = Join-Path $root "$mode-shared-skills"
            $teamSkill = Join-Path $shared 'review/SKILL.md'
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $teamSkill), (Join-Path $t '.agents') | Out-Null
            $teamBytes = $utf8.GetBytes("---`nname: review`ndescription: Shared team review.`n---`nSHARED REVIEW`n")
            [IO.File]::WriteAllBytes($teamSkill, $teamBytes)
            $link = Join-Path $t '.agents/skills'
            # A junction needs no privilege on Windows; elsewhere, where New-Item makes no junction, a symbolic link stands in.
            $linkType = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
            New-Item -ItemType $linkType -Path $link -Target $shared -ErrorAction Stop | Out-Null
            $linkItem = Get-Item -Force -LiteralPath $link -ErrorAction SilentlyContinue
            Assert ($null -ne $linkItem -and (($linkItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) "calibration: no $linkType was created at .agents/skills"
            if ($mode -eq 'update') {
                New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
                [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.93.0","template":"dotnet"}', $utf8)
                [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/framework-ownership.json'))
            }
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "the $mode with a linked .agents/skills failed (exit $LASTEXITCODE): $out"
            Assert ($out -match "'\.agents/skills' is a link, which the (update|install) never writes through, so it kept the link and did not install \.agents/skills/review/SKILL\.md") "the $mode did not report the kept link: $out"
            Assert (((Get-Item -Force -LiteralPath $link).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) "the $mode replaced the link: $out"
            Assert (Test-B194BytesEqual $teamBytes ([IO.File]::ReadAllBytes($teamSkill))) "the $mode changed the team's shared skill: $out"
            Assert (@(Get-ChildItem -LiteralPath $shared -Recurse -File -Force).Count -eq 1) "the $mode wrote a wrapper through the link: $out"
            $owned = @((Get-Content -Raw -LiteralPath (Join-Path $t 'framework-ownership.json') | ConvertFrom-Json).paths | ForEach-Object { [string]$_.path })
            Assert (@($owned | Where-Object { $_.StartsWith('.agents/', [StringComparison]::Ordinal) }).Count -eq 0) "the $mode's manifest claims wrapper paths it did not install: $($owned -join ', ')"
            Assert (Test-Path -LiteralPath (Join-Path $t '.claude/commands/review.md') -PathType Leaf) "the $mode did not install the rest of the framework: $out"
        }
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-B393Sha16 {
    param([byte[]]$Bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant().Substring(0, 16) }
    finally { $sha.Dispose() }
}

# 0.95.0 first shipped .claude/commands/security-gate.md, docs/reference.md and docs/getting-started.md.
function New-B393Target {
    param([Parameter(Mandatory)][string]$Target, [switch]$NoManifest)
    New-Item -ItemType Directory -Force -Path (Join-Path $Target '.claude/commands'), (Join-Path $Target 'docs') | Out-Null
    [IO.File]::WriteAllText((Join-Path $Target '.claude/framework-version.json'), '{"version":"0.94.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
    if (-not $NoManifest) { [IO.File]::WriteAllBytes((Join-Path $Target 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/framework-ownership.json')) }
    $gateBytes = [Text.UTF8Encoding]::new($false).GetBytes("# Team security gate`nOur own release checklist.`n")
    [IO.File]::WriteAllBytes((Join-Path $Target '.claude/commands/security-gate.md'), $gateBytes)
    return $gateBytes
}

It 'B-393 an update saves a team''s own file at a path the previous manifest does not own before the framework''s new file replaces it, beside an older save, once across re-runs, and out of Git when ignored' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b393-' + [guid]::NewGuid())
    try {
        $t = New-B309GitTarget -Root $root -Name 'target' -Ignore "/.claude/commands/security-gate.md`n"
        $utf8 = [Text.UTF8Encoding]::new($false)
        $backups = '.claude/framework-update-backup/files'
        $gateBytes = New-B393Target -Target $t
        $referenceBytes = $utf8.GetBytes("# Team reference`nService endpoints and owners.`n")
        $startedBytes = $utf8.GetBytes("# Team onboarding`nClone, build, run.`n")
        [IO.File]::WriteAllBytes((Join-Path $t 'docs/reference.md'), $referenceBytes)
        [IO.File]::WriteAllBytes((Join-Path $t 'docs/getting-started.md'), $startedBytes)
        # A file the previous manifest owns is the framework's: replaced as before, never saved.
        [IO.File]::WriteAllBytes((Join-Path $t 'docs/defaults.md'), (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/docs/defaults.md') + $utf8.GetBytes("edited`n"))
        # reference.md's save path holds an older, different save; getting-started.md's holds this very file, as after a re-run.
        New-Item -ItemType Directory -Force -Path (Join-Path $t "$backups/docs") | Out-Null
        $olderReference = $utf8.GetBytes("OLDER SAVE of docs/reference.md`n")
        [IO.File]::WriteAllBytes((Join-Path $t "$backups/docs/reference.md"), $olderReference)
        [IO.File]::WriteAllBytes((Join-Path $t "$backups/docs/getting-started.md"), $startedBytes)
        $referenceSave = "$backups/docs/reference.$(Get-B393Sha16 $referenceBytes).md"
        $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        foreach ($relative in '.claude/commands/security-gate.md', 'docs/reference.md', 'docs/getting-started.md') {
            Assert (Test-B194BytesEqual ([IO.File]::ReadAllBytes((Join-Path $repoRoot "dist/dotnet/$relative"))) ([IO.File]::ReadAllBytes((Join-Path $t $relative)))) "the update did not install the framework's $relative`: $out"
        }
        $gateSave = Join-Path $t "$backups/_.claude/commands/security-gate.md"
        Assert ((Test-Path -LiteralPath $gateSave -PathType Leaf) -and (Test-B194BytesEqual $gateBytes ([IO.File]::ReadAllBytes($gateSave)))) "the team's .claude/commands/security-gate.md was replaced without being saved byte-identical at $backups/_.claude/commands/security-gate.md: $out"
        Assert ($flat -match "NOTICE: '\.claude/commands/security-gate\.md' is not a file the framework wrote \(the previous framework-ownership\.json does not list it\), so the update saves it to \.claude/framework-update-backup/files/_\.claude/commands/security-gate\.md") "the save was not reported: $out"
        Assert ((Test-Path -LiteralPath (Join-Path $t $referenceSave) -PathType Leaf) -and (Test-B194BytesEqual $referenceBytes ([IO.File]::ReadAllBytes((Join-Path $t $referenceSave))))) "the team's docs/reference.md was not saved beside the older save at $referenceSave`: $out"
        Assert (Test-B194BytesEqual $olderReference ([IO.File]::ReadAllBytes((Join-Path $t "$backups/docs/reference.md")))) "the older save at docs/reference.md's save path was overwritten: $out"
        Assert ($flat -match "so the update saves it to $([regex]::Escape($referenceSave))") "the save beside the older one was not reported: $out"
        Assert ($flat -match "NOTICE: 'docs/getting-started\.md' is already saved at \.claude/framework-update-backup/files/docs/getting-started\.md") "the earlier run's save was not recognised: $out"
        Assert (@(Get-ChildItem -LiteralPath (Join-Path $t "$backups/docs") -File -Filter 'getting-started*').Count -eq 1) "an earlier run's identical save was copied again: $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t "$backups/docs/defaults.md"))) "a file the previous manifest owns was saved: $out"
        # The team had gitignored security-gate.md, so its saved copy must not become committable.
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/files/_\.claude/commands/security-gate\.md') "the gitignored file's saved copy is committable: $status"
        Assert ($status -notmatch 'framework-update-backup/') "a save under the backup folder is committable: $status"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
        # The update's manifest now owns those paths, so the next update replaces them as framework files and saves nothing.
        $again = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the second update failed (exit $LASTEXITCODE): $again"
        Assert (($again -replace '\s+', ' ') -notmatch 'is not a file the framework wrote|is already saved at \.claude/framework-update-backup/') "the second update saved a file the first one installed: $again"
        Assert (Test-B194BytesEqual $gateBytes ([IO.File]::ReadAllBytes($gateSave))) "the second update changed the saved copy: $again"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-393 an update refuses before any change when both save names for a team''s file at a new framework path hold other content' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b393-refuse-' + [guid]::NewGuid())
    try {
        $gateBytes = New-B393Target -Target $t
        $saves = Join-Path $t '.claude/framework-update-backup/files/_.claude/commands'
        New-Item -ItemType Directory -Force -Path $saves | Out-Null
        [IO.File]::WriteAllText((Join-Path $saves 'security-gate.md'), "OLDER SAVE ONE`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $saves "security-gate.$(Get-B393Sha16 $gateBytes).md"), "OLDER SAVE TWO`n", [Text.UTF8Encoding]::new($false))
        $before = Get-B194Fingerprint -Root $t
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 3) "the update did not refuse with exit 3 (exit $exit): $out"
        Assert (($out -replace '\s+', ' ') -match "ERROR: Refusing update: '\.claude/commands/security-gate\.md' must be saved before the framework's file replaces it, and both \.claude/framework-update-backup/files/_\.claude/commands/security-gate\.md and \.claude/framework-update-backup/files/_\.claude/commands/security-gate\.[0-9a-f]{16}\.md already hold other content\. .*Nothing was changed\.") "the refusal did not name both save paths: $out"
        Assert ((Get-B194Fingerprint -Root $t) -ceq $before) "the refused update changed the target: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-393 a link never carries a save: a linked folder on a new framework path refuses the update unchanged, and a hard link at the save path is no save' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b393-link-' + [guid]::NewGuid())
    try {
        # A junction needs no privilege on Windows; elsewhere, where New-Item makes no junction, a symbolic link stands in.
        $linkType = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
        $linked = Join-Path $root 'linked'
        [void](New-B393Target -Target $linked)
        $shared = Join-Path $root 'shared-docs'
        New-Item -ItemType Directory -Force -Path $shared | Out-Null
        $sharedBytes = [Text.UTF8Encoding]::new($false).GetBytes("# Shared team reference`n")
        [IO.File]::WriteAllBytes((Join-Path $shared 'reference.md'), $sharedBytes)
        Remove-Item -LiteralPath (Join-Path $linked 'docs') -Recurse -Force
        New-Item -ItemType $linkType -Path (Join-Path $linked 'docs') -Target $shared -ErrorAction Stop | Out-Null
        $out = Invoke-Installer -Dist 'dotnet' -Target $linked
        $exit = $LASTEXITCODE
        Assert ($exit -eq 3 -and $out -match 'reparse/symlink') "the update over a linked docs folder did not refuse at the link (exit $exit): $out"
        Assert (Test-B194BytesEqual $sharedBytes ([IO.File]::ReadAllBytes((Join-Path $shared 'reference.md')))) "the update changed the file behind the link: $out"
        Assert (@(Get-ChildItem -LiteralPath $shared -Force).Count -eq 1) "the update wrote through the link: $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $linked '.claude/framework-update-backup'))) "the refused update saved a file: $out"
        # A hard link at the save path is the file itself, so it is no save: the replacement in place would reach it.
        $hard = Join-Path $root 'hard'
        $gateBytes = New-B393Target -Target $hard
        $saves = Join-Path $hard '.claude/framework-update-backup/files/_.claude/commands'
        New-Item -ItemType Directory -Force -Path $saves | Out-Null
        New-Item -ItemType HardLink -Path (Join-Path $saves 'security-gate.md') -Target (Join-Path $hard '.claude/commands/security-gate.md') | Out-Null
        Assert ([string](Get-Item -LiteralPath (Join-Path $hard '.claude/commands/security-gate.md')).LinkType -eq 'HardLink') 'calibration: the team file is not reported as a hard link'
        $out = Invoke-Installer -Dist 'dotnet' -Target $hard
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $beside = Join-Path $saves "security-gate.$(Get-B393Sha16 $gateBytes).md"
        Assert ((Test-Path -LiteralPath $beside -PathType Leaf) -and (Test-B194BytesEqual $gateBytes ([IO.File]::ReadAllBytes($beside)))) "the team file was not saved beside the hard link at its save path: $out"
        Assert (($out -replace '\s+', ' ') -notmatch "is already saved at") "a hard link at the save path counted as a save: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-393 without a usable previous manifest an update saves every file that differs from the release before replacing it, in one summary line' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b393-additive-' + [guid]::NewGuid())
    try {
        $utf8 = [Text.UTF8Encoding]::new($false)
        $gateBytes = New-B393Target -Target $t -NoManifest
        $versionBytes = [IO.File]::ReadAllBytes((Join-Path $t '.claude/framework-version.json'))
        $defaultsBytes = (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/docs/defaults.md') + $utf8.GetBytes("edited`n")
        [IO.File]::WriteAllBytes((Join-Path $t 'docs/defaults.md'), $defaultsBytes)
        # The release's own bytes with CRLF line endings, as a core.autocrlf checkout holds them: nothing to save.
        $latin1 = [Text.Encoding]::GetEncoding(28591)
        $shipped = $latin1.GetString([IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/docs/reference.md'))).Replace("`r`n", "`n")
        [IO.File]::WriteAllBytes((Join-Path $t 'docs/reference.md'), $latin1.GetBytes($shipped.Replace("`n", "`r`n")))
        [IO.File]::WriteAllText((Join-Path $t '.claude/settings.json'), "{`"consumerEdit`":`"recover me`"}`n", $utf8)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $backups = Join-Path $t '.claude/framework-update-backup/files'
        foreach ($case in @(@('_.claude/commands/security-gate.md', $gateBytes), @('docs/defaults.md', $defaultsBytes), @('_.claude/framework-version.json', $versionBytes))) {
            $saved = Join-Path $backups $case[0]
            Assert ((Test-Path -LiteralPath $saved -PathType Leaf) -and (Test-B194BytesEqual ([byte[]]$case[1]) ([IO.File]::ReadAllBytes($saved)))) "$($case[0]) differed from the release and was not saved byte-identical: $out"
        }
        Assert (-not (Test-Path -LiteralPath (Join-Path $backups 'docs/reference.md'))) "a file differing only in line endings was saved: $out"
        Assert (@(Get-ChildItem -LiteralPath (Split-Path -Parent $backups) -Recurse -File -Filter 'settings.json').Count -eq 0) "settings.json, which has its own pre-update save, was saved twice: $out"
        Assert (@([regex]::Matches($flat, "there is no usable previous framework-ownership\.json, so the update cannot tell which files the framework wrote")).Count -eq 1) "the saves were not summed up in exactly one line: $out"
        Assert ($flat -match 'saves the 3 files that differ from this release under \.claude/framework-update-backup/files/') "the summary does not count the three saves: $out"
        Assert ($flat -notmatch 'is not a file the framework wrote') "the saves were reported one line each: $out"
        # Every saved copy stays out of Git through the backup folder's '*', whatever Git can say here.
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
        Assert ([IO.File]::ReadAllText((Join-Path (Split-Path -Parent $backups) '.gitignore')) -ceq "*`n") "the backup folder's .gitignore is not the one line '*'"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-393 no saved file can load as a live skill, command, agent or instruction: no path below the save root has a .claude, .agents or .github folder' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b393-layout-' + [guid]::NewGuid())
    try {
        # Claude Code loads a .claude/skills folder nested anywhere it reads files; Copilot and other agents read .agents and .github.
        # Without a manifest every differing file is saved, so one update covers each shipped root. The skill backup folder
        # already exists, so the one-time skill backup does not take the edited skill instead.
        [void](New-B393Target -Target $t -NoManifest)
        $utf8 = [Text.UTF8Encoding]::new($false)
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/framework-update-backup/skills'), (Join-Path $t '.claude/agents'),
            (Join-Path $t '.claude/skills/create-adr'), (Join-Path $t '.github') | Out-Null
        foreach ($relative in '.claude/agents/test-critic.md', '.claude/skills/create-adr/SKILL.md', '.github/PULL_REQUEST_TEMPLATE.md') {
            [IO.File]::WriteAllBytes((Join-Path $t $relative), [IO.File]::ReadAllBytes((Join-Path $repoRoot "dist/dotnet/$relative")) + $utf8.GetBytes("TEAM EDIT`n"))
        }
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $saveRoot = Join-Path $t '.claude/framework-update-backup'
        $saved = @(Get-ChildItem -LiteralPath $saveRoot -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($saveRoot.Length + 1).Replace('\', '/') })
        Assert ($saved.Count -ge 4) "calibration: the update saved fewer than the four edited files: $($saved -join ', ')"
        $live = @($saved | Where-Object { @($_.Split('/') | Where-Object { $_ -in '.claude', '.agents', '.github' }).Count -gt 0 })
        Assert ($live.Count -eq 0) "saved paths recreate a folder an agent loads: $($live -join ', ')"
        foreach ($expected in 'files/_.claude/agents/test-critic.md', 'files/_.claude/skills/create-adr/SKILL.md', 'files/_.github/PULL_REQUEST_TEMPLATE.md', 'files/_.claude/commands/security-gate.md') {
            Assert ($saved -ccontains $expected) "the edited file was not saved at .claude/framework-update-backup/$expected`: $($saved -join ', ')"
        }
        Assert (($out -replace '\s+', ' ') -match 'saves the \d+ files that differ from this release under \.claude/framework-update-backup/files/') "the summary does not name where the files were saved: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function New-B429GitTarget {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Ignore)
    $t = New-B309GitTarget -Root $Root -Name 'target' -Ignore $Ignore
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
    [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.94.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/framework-ownership.json'))
    return $t
}

It 'B-429 the one-time skill backup keeps out of Git the copy of every skill file Git ignores, a name Git would read as a pattern included, and says so in one line' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-' + [guid]::NewGuid())
    try {
        # A team's personal skill, gitignored with a key beside it: the update's skill backup copied it where Git can commit it, with no notice.
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        $utf8 = [Text.UTF8Encoding]::new($false)
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/skills/my-deploy'), (Join-Path $t '.claude/skills/team-notes') | Out-Null
        $secrets = @{ 'SKILL.md' = "---`nname: my-deploy`ndescription: personal deploy`n---`nUse token.txt`n"; 'token.txt' = "sk-live-FX-SECRET`n"; 'keys[prod].txt' = "PROD-FIXTURE-KEY`n" }
        foreach ($name in $secrets.Keys) { [IO.File]::WriteAllText((Join-Path $t ".claude/skills/my-deploy/$name"), $secrets[$name], $utf8) }
        # A team skill Git tracks: its copy stays committable, which also shows git status reads the backup.
        [IO.File]::WriteAllText((Join-Path $t '.claude/skills/team-notes/SKILL.md'), "---`nname: team-notes`ndescription: shared notes`n---`n", $utf8)
        & git -C $t add -A
        & git -C $t commit -qm 'team skills'
        Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') 'calibration: the fixture is not clean before the update'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        foreach ($name in $secrets.Keys) {
            $copy = Join-Path $t ".claude/framework-update-backup/skills/my-deploy/$name"
            Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq $secrets[$name]) "the skill backup did not copy my-deploy/$name byte-identical: $out"
        }
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/skills/my-deploy/') "a gitignored skill file's backup copy is committable: $status"
        Assert ((& git -C $t status --porcelain --ignored --untracked-files=all | Out-String) -match '!! \.claude/framework-update-backup/skills/team-notes/SKILL\.md') "calibration: Git does not list the tracked team skill's copy as ignored, so git status is not reading the backup: $status"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 an update keeps out of Git the saved copy of a tracked file whose local changes Git is told not to see: skip-worktree at a new framework path, assume-unchanged in a skill' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-skip-' + [guid]::NewGuid())
    try {
        # check-ignore never reports a tracked path, so a local key in a file Git skips was saved where Git can commit it.
        $t = New-B429GitTarget -Root $root -Ignore "/scratch/`n"
        $utf8 = [Text.UTF8Encoding]::new($false)
        New-Item -ItemType Directory -Force -Path (Join-Path $t 'docs'), (Join-Path $t '.claude/skills/team-tool') | Out-Null
        # docs/reference.md is new in 0.95.0, so the update saves the team's file there before replacing it.
        [IO.File]::WriteAllText((Join-Path $t 'docs/reference.md'), "# Team reference template`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $t '.claude/skills/team-tool/config.json'), "{}`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $t '.claude/skills/team-tool/SKILL.md'), "---`nname: team-tool`ndescription: team tool`n---`n", $utf8)
        & git -C $t add -A
        & git -C $t commit -qm 'team files'
        & git -C $t update-index --skip-worktree docs/reference.md
        & git -C $t update-index --assume-unchanged .claude/skills/team-tool/config.json
        $reference = "# Team reference`nLOCAL-ONLY-FIXTURE-KEY`n"
        $config = "{`"key`":`"LOCAL-FIXTURE`"}`n"
        [IO.File]::WriteAllText((Join-Path $t 'docs/reference.md'), $reference, $utf8)
        [IO.File]::WriteAllText((Join-Path $t '.claude/skills/team-tool/config.json'), $config, $utf8)
        Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') 'calibration: Git sees the local changes it was told not to see'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $referenceCopy = '.claude/framework-update-backup/files/docs/reference.md'
        $configCopy = '.claude/framework-update-backup/skills/team-tool/config.json'
        foreach ($case in @(@($referenceCopy, $reference), @($configCopy, $config))) {
            $copy = Join-Path $t $case[0]
            Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq $case[1]) "the team's local content was not saved byte-identical at $($case[0]): $out"
        }
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch [regex]::Escape($referenceCopy)) "the saved copy of a skip-worktree file is committable: $status"
        Assert ($status -notmatch [regex]::Escape($configCopy)) "the backup copy of an assume-unchanged skill file is committable: $status"
        Assert ((& git -C $t status --porcelain --ignored --untracked-files=all | Out-String) -match '!! \.claude/framework-update-backup/skills/team-tool/SKILL\.md') "calibration: Git does not list the tracked team skill's copy as ignored, so git status is not reading the backup: $status"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Write-B429Files {
    param([Parameter(Mandatory)][string]$Folder, [Parameter(Mandatory)][Collections.IDictionary]$Files)
    foreach ($name in $Files.Keys) {
        $path = Join-Path $Folder $name
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
        [IO.File]::WriteAllText($path, $Files[$name], [Text.UTF8Encoding]::new($false))
    }
}

It 'B-429 hardening: the skill backup writes no live ignore file, so a copied .gitignore cannot re-include a kept-out copy; each name starting with . or _ gains a leading _' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-live-' + [guid]::NewGuid())
    try {
        # A personal skill gitignored whole, shipped with GitHub's VisualStudioCode.gitignore template; its launch.json holds a key.
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        $files = [ordered]@{ 'SKILL.md' = "---`nname: my-deploy`ndescription: personal deploy`n---`n"; '.gitignore' = ".vscode/*`n!.vscode/settings.json`n!.vscode/tasks.json`n!.vscode/launch.json`n!.vscode/extensions.json`n"
            '.vscode/launch.json' = "{`"configurations`":[{`"env`":{`"API_KEY`":`"sk-live-FX-SECRET`"}}]}`n"; '_notes.md' = "team notes`n" }
        Write-B429Files -Folder (Join-Path $t '.claude/skills/my-deploy') -Files $files
        & git -C $t add -A
        & git -C $t commit -qm 'framework state'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/skills/my-deploy/') "a copied .gitignore re-included a kept-out copy, so Git can commit it: $status"
        $saved = @{ 'SKILL.md' = 'SKILL.md'; '.gitignore' = '_.gitignore'; '.vscode/launch.json' = '_.vscode/launch.json'; '_notes.md' = '__notes.md' }
        foreach ($name in $files.Keys) {
            $copy = Join-Path $t ".claude/framework-update-backup/skills/my-deploy/$($saved[$name])"
            Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq $files[$name]) "my-deploy/$name was not saved byte-identical at skills/my-deploy/$($saved[$name]): $out"
        }
        $live = @(Get-ChildItem -LiteralPath (Join-Path $t '.claude/framework-update-backup/skills') -Recurse -Force | Where-Object { $_.Name.StartsWith('.') } | ForEach-Object { $_.FullName })
        Assert ($live.Count -eq 0) "the skill backup wrote a name Git or an agent reads: $($live -join ', ')"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 hardening: a skill that is its own Git clone is copied as plain files kept out of Git, never as a repository git add takes as a gitlink' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-clone-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        $deploy = Join-Path $t '.claude/skills/my-deploy'
        Write-B429Files -Folder $deploy -Files ([ordered]@{ 'SKILL.md' = "---`nname: my-deploy`ndescription: personal deploy`n---`n"; 'token.txt' = "sk-live-FX-SECRET`n" })
        & git -C $deploy init -q
        & git -C $deploy -c user.email=tests@example.invalid -c user.name=tests add SKILL.md
        & git -C $deploy -c user.email=tests@example.invalid -c user.name=tests commit -qm skill
        & git -C $t add -A
        & git -C $t commit -qm 'framework state'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/skills/my-deploy') "the copy of the clone is committable, as files or as an embedded repository: $status"
        & git -C $t add -A
        $links = @(& git -C $t ls-files -s | Where-Object { $_ -match '^160000 ' })
        Assert ($links.Count -eq 0) "git add -A took the copy for a gitlink: $($links -join ', ')"
        $copy = Join-Path $t '.claude/framework-update-backup/skills/my-deploy'
        Assert ((Test-Path -LiteralPath (Join-Path $copy '_.git/HEAD') -PathType Leaf) -and -not (Test-Path -LiteralPath (Join-Path $copy '.git'))) "the clone's .git was not copied as plain files at _.git: $out"
        Assert ([IO.File]::ReadAllText((Join-Path $copy 'token.txt')) -ceq "sk-live-FX-SECRET`n") "the clone's token.txt was not saved byte-identical: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 hardening: copies an earlier update left where Git could commit them are no reason to refuse and are kept out, a live .gitignore among them, while any other change still refuses' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-residue-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        & git -C $t add -A
        & git -C $t commit -qm 'framework state'
        # What a first update by 0.98.1 or earlier left beside a gitignored personal skill: untracked copies, its live .gitignore included.
        $residue = [ordered]@{ '.gitignore' = ".vscode/*`n!.vscode/launch.json`n"; '.vscode/launch.json' = "{`"env`":{`"API_KEY`":`"sk-live-FX-SECRET`"}}`n"; 'token.txt' = "sk-live-FX-SECRET`n" }
        $residueRoot = Join-Path $t '.claude/framework-update-backup/skills/my-deploy'
        Write-B429Files -Folder $residueRoot -Files $residue
        $before = @(& git -C $t status --porcelain --untracked-files=all | Where-Object { $_ -match 'framework-update-backup/' })
        Assert ($before.Count -eq 3) "calibration: Git does not show the three leftover copies as committable: $($before -join ' | ')"
        [IO.File]::WriteAllText((Join-Path $t 'notes.txt'), "draft`n", [Text.UTF8Encoding]::new($false))
        $refused = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 4 -and $refused -match 'Refusing to mutate a dirty Git target') "a team's own uncommitted file no longer refuses the update (exit $LASTEXITCODE): $refused"
        # The refusal keeps them out first, so the run after it has none left to count.
        Assert (($refused -replace '\s+', ' ') -match 'so Git ignores the 3 files an earlier update left under that folder, which may hold copies of files you had gitignored') "the refusal did not keep the 3 leftovers out of Git first: $refused"
        Remove-Item -LiteralPath (Join-Path $t 'notes.txt') -Force
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the framework's own leftover copies refused the update, steering the team to commit them (exit $LASTEXITCODE): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/skills/') "a leftover copy is still committable: $status"
        foreach ($name in $residue.Keys) { Assert ([IO.File]::ReadAllText((Join-Path $residueRoot $name)) -ceq $residue[$name]) "the leftover copy $name was changed or removed: $out" }
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 hardening: a skip-worktree file is found whatever the case of its folder on disk' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-case-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/scratch/`n"
        $indexed = Join-Path $t '.claude/skills/Team-Tool'
        Write-B429Files -Folder $indexed -Files ([ordered]@{ 'config.json' = "{}`n"; 'SKILL.md' = "---`nname: team-tool`ndescription: team tool`n---`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'team files'
        & git -C $t update-index --skip-worktree .claude/skills/Team-Tool/config.json
        # Renamed in case on disk only, as Explorer does it; the index keeps Team-Tool, and Git on Windows ignores the case.
        [IO.Directory]::Move($indexed, "$indexed-renaming")
        [IO.Directory]::Move("$indexed-renaming", (Join-Path $t '.claude/skills/team-tool'))
        Assert (@(Get-ChildItem -LiteralPath (Join-Path $t '.claude/skills') -Directory | ForEach-Object { $_.Name }) -ccontains 'team-tool') 'calibration: the folder was not renamed in case on disk'
        $config = "{`"key`":`"LOCAL-FIXTURE`"}`n"
        [IO.File]::WriteAllText((Join-Path $t '.claude/skills/team-tool/config.json'), $config, [Text.UTF8Encoding]::new($false))
        Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') 'calibration: Git sees the local change it was told not to see'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/skills/team-tool/config\.json') "the copy of a skip-worktree file in a folder renamed in case is committable: $status"
        $copy = Join-Path $t '.claude/framework-update-backup/skills/team-tool/config.json'
        Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq $config) "the local content was not saved byte-identical: $out"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 hardening: a keep-out list a team saved as UTF-16 is rewritten as UTF-8 with its own lines kept, so Git reads every line' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-utf16-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        $list = Join-Path $t '.claude/framework-update-backup/.gitignore'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $list) | Out-Null
        # What Windows PowerShell 5.1's '>' writes: UTF-16LE with a byte-order mark.
        [IO.File]::WriteAllText($list, "# team: keep local notes out`r`n/notes/`r`n", [Text.UnicodeEncoding]::new($false, $true))
        Write-B429Files -Folder (Join-Path $t '.claude/skills/my-deploy') -Files ([ordered]@{ 'SKILL.md' = "---`nname: my-deploy`ndescription: personal deploy`n---`n"; 'token.txt' = "sk-live-FX-SECRET`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'framework state'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/skills/my-deploy/') "a line appended to a UTF-16 list is lost to Git, so its copy is committable: $status"
        $bytes = [IO.File]::ReadAllBytes($list)
        Assert (($bytes -notcontains [byte]0) -and -not ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE)) 'the list is still UTF-16'
        $text = [Text.UTF8Encoding]::new($false).GetString($bytes)
        Assert ($text.Contains('# team: keep local notes out') -and $text.Contains('/notes/')) "the team's own lines were not kept: $text"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# A captured native command is decoded with the console's code page. A 65001 console decodes Git's UTF-8 correctly and
# hides a decoding flaw, so this run sets the console to another code page, as a Western European Windows has it, and
# restores it after. Without a console the chcp does nothing and the installer still runs.
function Invoke-InstallerAtCodePage {
    param([Parameter(Mandatory)][string]$Target, [Parameter(Mandatory)][int]$CodePage)
    $installer = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
    $before = [regex]::Match((& cmd /d /c chcp | Out-String), '\d+').Value
    try {
        $out = & cmd /d /c "chcp $CodePage >nul & `"$(Get-PsExe)`" -NoProfile -ExecutionPolicy Bypass -File `"$installer`" -Target `"$Target`"" 2>&1 | Out-String
        $exit = $LASTEXITCODE
    } finally {
        if ($before) { & cmd /d /c "chcp $before >nul" }
    }
    $global:LASTEXITCODE = $exit
    return $out
}

# What a first update by 0.98.1 or earlier left beside a gitignored personal skill holding a file with a non-ASCII name.
function New-B429NonAsciiLeftovers {
    param([Parameter(Mandatory)][string]$Root)
    $t = New-B429GitTarget -Root $Root -Ignore "/.claude/skills/my-deploy/`n"
    & git -C $t add -A
    & git -C $t commit -qm 'framework state'
    $name = 'zug' + [char]0x00E4 + 'nge.env'
    $files = [ordered]@{ 'SKILL.md' = "---`nname: my-deploy`ndescription: personal deploy`n---`n"; 'token.txt' = "sk-live-FX-ASCII`n" }
    $files[$name] = "PROD_PASSWORD=sk-live-FX-NONASCII`n"
    Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $files
    return [pscustomobject]@{ Target = $t; Name = $name; Files = $files }
}

function Assert-B429LeftoversKeptOut {
    param([Parameter(Mandatory)]$Fixture, [Parameter(Mandatory)][string]$Out, [Parameter(Mandatory)][string]$Label)
    $t = $Fixture.Target
    Assert (($Out -replace '\s+', ' ') -match ($b429BlanketLine + ' That covers the 3 files an earlier update left there where Git could commit them')) "${Label}: the three leftovers were not counted: $Out"
    $added = @(& git -C $t add -A --dry-run | Where-Object { $_ -match 'framework-update-backup/skills/' })
    Assert ($added.Count -eq 0) "${Label}: git add -A would still commit a leftover: $($added -join ' | ')"
    $list = [IO.File]::ReadAllBytes((Join-Path $t '.claude/framework-update-backup/.gitignore'))
    Assert ($list.Length -ge 2 -and $list[0] -eq 0x2A -and $list[1] -eq 0x0A) "${Label}: the backup folder's .gitignore does not start with '*'"
    foreach ($name in $Fixture.Files.Keys) {
        Assert ([IO.File]::ReadAllText((Join-Path $t ".claude/framework-update-backup/skills/my-deploy/$name")) -ceq $Fixture.Files[$name]) "${Label}: the leftover $name was changed or removed"
    }
}

It 'B-429 decoding: leftovers an earlier update left, one with a non-ASCII name Git prints quoted, are no reason to refuse and are all kept out' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-quoted-' + [guid]::NewGuid())
    try {
        $fixture = New-B429NonAsciiLeftovers -Root $root
        $out = Invoke-Installer -Dist 'dotnet' -Target $fixture.Target
        Assert ($LASTEXITCODE -eq 0) "a leftover whose name Git prints quoted refused the update, steering the team to commit it (exit $LASTEXITCODE): $out"
        Assert-B429LeftoversKeptOut -Fixture $fixture -Out $out -Label 'default quoting'
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 decoding: with core.quotePath false and the console at code page 850, a non-ASCII leftover is no reason to refuse and Git cannot commit it' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-cp850-' + [guid]::NewGuid())
    try {
        $fixture = New-B429NonAsciiLeftovers -Root $root
        & git -C $fixture.Target config core.quotePath false
        $out = Invoke-InstallerAtCodePage -Target $fixture.Target -CodePage 850
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert-B429LeftoversKeptOut -Fixture $fixture -Out $out -Label 'quotePath false at code page 850'
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# A tracked team skill whose config.json Git stores through a clean filter that redacts its token: the working file
# holds the live token, the committed blob does not, and git status is clean.
function New-B429FilteredSkill {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][ValidateSet('skill', 'root')][string]$AttributesAt)
    $t = New-B429GitTarget -Root $Root -Ignore "/scratch/`n"
    & git -C $t config filter.redact.clean 'sed -e s/sk-live-[A-Za-z0-9-]*/REDACTED/g'
    & git -C $t config filter.redact.smudge cat
    $files = [ordered]@{ 'SKILL.md' = "---`nname: team-deploy`ndescription: deploy`n---`n"; 'config.json' = "token=sk-live-FX-FILTERED`n" }
    if ($AttributesAt -eq 'skill') { $files['.gitattributes'] = "config.json filter=redact`n" }
    else { [IO.File]::WriteAllText((Join-Path $t '.gitattributes'), "/.claude/skills/team-deploy/config.json filter=redact`n", [Text.UTF8Encoding]::new($false)) }
    Write-B429Files -Folder (Join-Path $t '.claude/skills/team-deploy') -Files $files
    & git -C $t add -A
    & git -C $t commit -qm 'team skill, token redacted by a clean filter'
    return $t
}

foreach ($attributesAt in 'skill', 'root') {
    It "B-429 blanket keep-out: no copy of a file Git stores through a redacting filter, set in the $attributesAt .gitattributes, can be staged" {
        $root = Join-Path ([IO.Path]::GetTempPath()) ("b429-filter-$attributesAt-" + [guid]::NewGuid())
        try {
            $t = New-B429FilteredSkill -Root $root -AttributesAt $attributesAt
            Assert ((& git -C $t show 'HEAD:.claude/skills/team-deploy/config.json' | Out-String).Trim() -ceq 'token=REDACTED') 'calibration: the clean filter did not redact the committed blob'
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
            $copy = Join-Path $t '.claude/framework-update-backup/skills/team-deploy/config.json'
            Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq "token=sk-live-FX-FILTERED`n") "the skill backup did not keep the working file's bytes: $out"
            & git -C $t add -A
            $staged = @(& git -C $t ls-files -s -- '.claude/framework-update-backup' | Where-Object { $_ -notmatch '\.claude/framework-update-backup/\.gitignore$' })
            Assert ($staged.Count -eq 0) "git add -A staged a backup copy, outside the filter that redacts its original: $($staged -join ' | ')"
            Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
        } finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

It 'B-429 blanket keep-out: a .gitignore a team committed under the backup folder cannot re-include a copy with its ! rule' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-negation-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/docs/reference.md`n"
        # docs/reference.md is new in 0.95.0, so the update saves the team's own ignored file there before replacing it.
        Write-B429Files -Folder $t -Files ([ordered]@{ 'docs/reference.md' = "# Team reference`nLOCAL-KEY=sk-live-FX-REFERENCE`n" })
        # An older copy's .gitignore the team once committed; its '!' line wins over any list one folder up.
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/files/docs') -Files ([ordered]@{ '.gitignore' = "!reference.md`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'framework state'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $copy = '.claude/framework-update-backup/files/docs/reference.md'
        Assert ([IO.File]::ReadAllText((Join-Path $t $copy)) -ceq "# Team reference`nLOCAL-KEY=sk-live-FX-REFERENCE`n") "the team's ignored file was not saved byte-identical at $copy`: $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch [regex]::Escape($copy)) "a committed .gitignore under the backup folder re-included the copy, so Git can commit it: $status"
        $why = (& git -C $t check-ignore --no-index -v -- $copy | Out-String).Trim()
        Assert ($LASTEXITCODE -eq 0 -and $why -match '^\.claude/framework-update-backup/\.gitignore:1:\*\s') "check-ignore --no-index does not put the copy under the backup folder's '*': $why"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
        Assert (($out -replace '\s+', ' ') -match 'Git tracks 1 file under \.claude/framework-update-backup/') "the handoff does not say the committed file under the backup folder stays tracked: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# What a first update by 0.98.1 left beside a gitignored personal skill: two untracked copies Git could commit.
$b429Residue = [ordered]@{ 'SKILL.md' = "---`nname: my-deploy`ndescription: personal deploy`n---`n"; 'token.txt' = "sk-live-FX-SECRET`n" }
$b429RefusalKeptOut = "'\*' is now the last line of \.claude/framework-update-backup/\.gitignore, so Git ignores the 2 files an earlier update left under that folder, which may hold copies of files you had gitignored"

# The refusal says "Commit": what git add -A would take is what following it commits.
function Assert-B429RefusalKeptOut {
    param([Parameter(Mandatory)][string]$Repo, [Parameter(Mandatory)][string]$Target, [Parameter(Mandatory)][string]$Out, [Parameter(Mandatory)][string]$Change)
    $added = @(& git -C $Repo add -A --dry-run)
    # A list the team tracks there is not a copy: the refusal's '*' changes it.
    Assert (@($added | Where-Object { $_ -match 'framework-update-backup/' -and $_ -notmatch "framework-update-backup/\.gitignore'" }).Count -eq 0) "following the refusal's advice would commit a leftover copy: $($added -join ' | ')"
    Assert (@($added | Where-Object { $_.Contains($Change) }).Count -eq 1) "calibration: git add -A would not take the team's own change: $($added -join ' | ')"
    Assert (($Out -replace '\s+', ' ') -match $b429RefusalKeptOut) "the refusal does not say it kept the 2 leftovers out of Git: $Out"
    Assert ($Out -notmatch 'Nothing was changed') "the refusal says nothing was changed after writing the keep-out: $Out"
    foreach ($name in $b429Residue.Keys) { Assert ([IO.File]::ReadAllText((Join-Path $Target ".claude/framework-update-backup/skills/my-deploy/$name")) -ceq $b429Residue[$name]) "the leftover $name was changed or removed" }
}

It 'B-429 refusal: a dirty target still refuses the update, but first the copies an earlier update left are kept out of Git, so committing the team change cannot commit them, and the refusal says so' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-mixed-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        & git -C $t add -A
        & git -C $t commit -qm 'framework state'
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $b429Residue
        Write-B429Files -Folder $t -Files ([ordered]@{ 'src/Feature.cs' = "class Feature {}`n" })
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 4 -and $out -match 'Refusing to mutate a dirty Git target') "the team's own uncommitted file no longer refuses the update (exit $LASTEXITCODE): $out"
        Assert-B429RefusalKeptOut -Repo $t -Target $t -Out $out -Change 'src/Feature.cs'
        $changed = @(& git -C $t status --porcelain --untracked-files=all)
        Assert ($changed.Count -eq 1 -and $changed[0] -ceq '?? src/Feature.cs') "the refusal changed more than the backup folder's .gitignore: $($changed -join ' | ')"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 refusal: in a target that is a subfolder of its repository, copies an earlier update left are no reason to refuse and are kept out, and beside a team change they are kept out before the refusal' {
    foreach ($withChange in $false, $true) {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-sub-' + [guid]::NewGuid())
        try {
            # Git prints status paths from the repository root: apps/api/.claude/framework-update-backup/...
            $repo = New-B309GitTarget -Root $root -Name 'repo' -Ignore "/scratch/`n"
            $t = Join-Path $repo 'apps/api'
            Write-B429Files -Folder $t -Files ([ordered]@{ '.gitignore' = "/.claude/skills/my-deploy/`n"; '.claude/framework-version.json' = '{"version":"0.94.0","template":"dotnet"}' })
            [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/framework-ownership.json'))
            & git -C $repo add -A
            & git -C $repo commit -qm 'framework state'
            Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $b429Residue
            if ($withChange) { Write-B429Files -Folder $t -Files ([ordered]@{ 'src/Feature.cs' = "class Feature {}`n" }) }
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            if ($withChange) {
                Assert ($LASTEXITCODE -eq 4 -and $out -match 'Refusing to mutate a dirty Git target') "with a team change: the update did not refuse (exit $LASTEXITCODE): $out"
                Assert-B429RefusalKeptOut -Repo $repo -Target $t -Out $out -Change 'apps/api/src/Feature.cs'
            } else {
                Assert ($LASTEXITCODE -eq 0) "the framework's own leftover copies refused the update in a subfolder target, steering the team to commit them (exit $LASTEXITCODE): $out"
                $added = @(& git -C $repo add -A --dry-run | Where-Object { $_ -match 'framework-update-backup/' })
                Assert ($added.Count -eq 0) "git add -A would still commit a leftover: $($added -join ' | ')"
                Assert (($out -replace '\s+', ' ') -match ($b429BlanketLine + ' That covers the 2 files an earlier update left there where Git could commit them')) "the leftovers were not counted in the keep-out line: $out"
            }
        } finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

It 'B-429 tracked copies: an update that saves nothing still says how many files Git tracks under the backup folder, that they may hold gitignored content, and how to untrack them' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-tracked-' + [guid]::NewGuid())
    try {
        # A team that committed everything after 0.98.1's update, its copy of a gitignored personal skill's token included.
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        Write-B429Files -Folder (Join-Path $t '.claude/skills/my-deploy') -Files $b429Residue
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $b429Residue
        & git -C $t add -A
        & git -C $t commit -qm 'update 0.98.1, backup folder included'
        Assert (@(& git -C $t ls-files -- .claude/framework-update-backup).Count -eq 2) 'calibration: the two copies are not tracked'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $flat = $out -replace '\s+', ' '
        Assert ($flat -match 'Git tracks 2 files under \.claude/framework-update-backup/, which may hold copies of files you had gitignored') "the update does not say Git tracks the 2 copies under the backup folder: $out"
        Assert ($flat -match 'git rm -r --cached \.claude/framework-update-backup' -and $flat -match 'stays in your Git history') "the line does not say how to untrack them, or that a committed secret stays in history: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# A team list in the backup folder that commits the saved framework files for review, as WSD-117's reopen case would.
$b429ReincludeList = "# team: commit the saved framework files for review`n!files/`n!files/**`n"
function New-B429ReincludeTarget {
    param([Parameter(Mandatory)][string]$Root)
    # docs/reference.md is new after 0.94.0, so the update saves the team's own ignored file there to files/docs/reference.md.
    $t = New-B429GitTarget -Root $Root -Ignore "/docs/reference.md`n"
    Write-B429Files -Folder $t -Files ([ordered]@{ 'docs/reference.md' = "# Team reference`nLOCAL-KEY=sk-live-FX-REFERENCE`n" })
    return $t
}

It 'B-429 blanket keep-out: a team list whose ! lines after its * re-include copies gains * as its last line, so no copy can be staged' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-star-' + [guid]::NewGuid())
    try {
        $t = New-B429ReincludeTarget -Root $root
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup') -Files ([ordered]@{ '.gitignore' = "*`n" + $b429ReincludeList })
        & git -C $t add -A -f
        & git -C $t commit -qm 'framework state, team list'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert ([IO.File]::ReadAllText((Join-Path $t '.claude/framework-update-backup/files/docs/reference.md')) -ceq "# Team reference`nLOCAL-KEY=sk-live-FX-REFERENCE`n") "the team's ignored file was not saved byte-identical: $out"
        $added = @(& git -C $t add -A --dry-run | Where-Object { $_ -match 'framework-update-backup/files/' })
        Assert ($added.Count -eq 0) "a ! line after the list's * re-included a copy, so git add -A stages it: $($added -join ' | ')"
        $lines = @([IO.File]::ReadAllText((Join-Path $t '.claude/framework-update-backup/.gitignore')) -split "`n" | Where-Object { $_.Trim() })
        Assert ($lines[-1] -ceq '*' -and $lines -ccontains '!files/**') "the list does not end with * after the team's own lines: $($lines -join ' | ')"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 blanket keep-out: a hard-linked list in the backup folder is never written through, and the update reports CANT-VERIFY with the count of files Git can still commit there' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-hardlink-' + [guid]::NewGuid())
    try {
        $t = New-B429ReincludeTarget -Root $root
        $shared = Join-Path $root 'shared-list.txt'
        [IO.File]::WriteAllText($shared, $b429ReincludeList, [Text.UTF8Encoding]::new($false))
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/framework-update-backup') | Out-Null
        New-Item -ItemType HardLink -Path (Join-Path $t '.claude/framework-update-backup/.gitignore') -Value $shared | Out-Null
        & git -C $t add -A
        & git -C $t commit -qm 'framework state, team list'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert ([IO.File]::ReadAllText($shared) -ceq $b429ReincludeList) "the update wrote through the hard link into a file outside the target: $([IO.File]::ReadAllText($shared))"
        $flat = $out -replace '\s+', ' '
        Assert ($flat -notmatch $b429BlanketLine) "the update claims Git ignores the folder although Git can commit a copy there: $out"
        Assert ($flat -match "CANT-VERIFY: every copy this update saves goes under \.claude/framework-update-backup/, but its \.gitignore is a hard link" -and $flat -match 'Git can still commit 1 file there') "the update does not report CANT-VERIFY with the 1 file Git can commit: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 tracked copies: an update never writes a copy onto a path Git tracks under the backup folder, so a rotated token is saved beside it where Git cannot stage it' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-rotated-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        $deploy = Join-Path $t '.claude/skills/my-deploy'
        Write-B429Files -Folder $deploy -Files $b429Residue
        # 0.98.1's update copied the personal skill, and the team committed everything, the backup folder included.
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $b429Residue
        & git -C $t add -A
        & git -C $t commit -qm 'update 0.98.1, backup folder included'
        # Then the team rotated the gitignored token and deleted the folder from disk, as the update's lines advise.
        $rotated = "sk-live-FX-ROTATED-V2`n"
        [IO.File]::WriteAllText((Join-Path $deploy 'token.txt'), $rotated, [Text.UTF8Encoding]::new($false))
        Remove-Item -LiteralPath (Join-Path $t '.claude/framework-update-backup') -Recurse -Force
        $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        & git -C $t add -A
        $staged = (& git -C $t diff --cached -- .claude/framework-update-backup | Out-String)
        Assert ($staged -notmatch 'ROTATED') "git add -A stages the rotated token, written onto a path Git tracks: $staged"
        $copies = @(Get-ChildItem -LiteralPath (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -File | Where-Object { [IO.File]::ReadAllText($_.FullName) -ceq $rotated })
        Assert ($copies.Count -eq 1 -and $copies[0].Name -match '^token\.[0-9a-f]{16}\.txt$') "the rotated token was not saved beside the tracked path under its SHA-256 name: $(@($copies | ForEach-Object { $_.Name }) -join ', ')"
        $flat = $out -replace '\s+', ' '
        Assert ($flat -match $b429BlanketLine -and $flat -match 'Git tracks 2 files under \.claude/framework-update-backup/') "the handoff does not say the folder is kept out and that Git tracks 2 files there: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 blanket keep-out: a read-only list in the backup folder refuses the update before any change, so its refusal that nothing was changed is true' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-readonly-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        Write-B429Files -Folder (Join-Path $t '.claude/skills/my-deploy') -Files $b429Residue
        # The team's own settings, which the update saves before the list's write; before, that save stayed behind the refusal.
        $teamList = "# team list`n/notes/`n"
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/settings.json' = "{`"team`": true}`n"; '.claude/framework-update-backup/.gitignore' = $teamList })
        & git -C $t add -A
        & git -C $t commit -qm 'framework state, team settings and list'
        $list = Join-Path $t '.claude/framework-update-backup/.gitignore'
        (Get-Item -LiteralPath $list).IsReadOnly = $true
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 3 -and ($out -replace '\s+', ' ') -match 'Nothing was changed') "the update did not refuse a read-only list saying nothing was changed (exit $LASTEXITCODE): $out"
        $changed = @(& git -C $t status --porcelain --untracked-files=all)
        Assert ($changed.Count -eq 0) "the refused update changed the tree: $($changed -join ' | ')"
        Assert ([IO.File]::ReadAllText($list) -ceq $teamList) 'the read-only list was changed'
    } finally {
        Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object { $_.IsReadOnly = $false }
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 refusal: when Git tracks the backup folder list, the refusal that ends it with * says the list is now changed and to commit it, and once committed the update runs' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-trackedlist-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/framework-update-backup/.gitignore' = "# team list`n/notes/`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'framework state, team list'
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $b429Residue
        Write-B429Files -Folder $t -Files ([ordered]@{ 'src/Feature.cs' = "class Feature {}`n" })
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 4 -and $out -match 'Refusing to mutate a dirty Git target') "the team's own uncommitted file no longer refuses the update (exit $LASTEXITCODE): $out"
        Assert-B429RefusalKeptOut -Repo $t -Target $t -Out $out -Change 'src/Feature.cs'
        Assert (($out -replace '\s+', ' ') -match 'Git tracks \.claude/framework-update-backup/\.gitignore, so that change shows in git status: commit it with your own changes') "the refusal does not say the tracked list it changed is left to commit: $out"
        & git -C $t add -A
        & git -C $t commit -qm 'commit local changes as the refusal said'
        $committed = @(& git -C $t ls-files -- .claude/framework-update-backup)
        Assert ($committed.Count -eq 1) "following the refusal committed a leftover copy: $($committed -join ' | ')"
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "after committing as the refusal said, the update still refuses (exit $LASTEXITCODE): $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 tracked copies: a tracked backup folder spelt in another case is still found, so no copy is written onto it and the update says Git tracks it' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-case-tracked-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        & git -C $t config core.ignorecase true
        $deploy = Join-Path $t '.claude/skills/my-deploy'
        Write-B429Files -Folder $deploy -Files $b429Residue
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $b429Residue
        & git -C $t add -A
        & git -C $t commit -qm 'update 0.98.1, backup folder included'
        # Renamed in case in two steps, as git mv needs on a case-insensitive disk; Git now tracks .claude/Framework-Update-Backup/.
        & git -C $t mv .claude/framework-update-backup .claude/fub-renaming
        & git -C $t mv .claude/fub-renaming .claude/Framework-Update-Backup
        & git -C $t commit -qm 'backup folder renamed in case'
        Assert (@(& git -C $t ls-files -- .claude/Framework-Update-Backup).Count -eq 2) 'calibration: Git does not track the two copies under the renamed folder'
        $rotated = "sk-live-FX-ROTATED-V2`n"
        [IO.File]::WriteAllText((Join-Path $deploy 'token.txt'), $rotated, [Text.UTF8Encoding]::new($false))
        Remove-Item -LiteralPath (Join-Path $t '.claude/Framework-Update-Backup') -Recurse -Force
        $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        & git -C $t add -A
        $staged = (& git -C $t diff --cached -- ':(icase).claude/framework-update-backup' | Out-String)
        Assert ($staged -notmatch 'sk-live-FX-ROTATED') "git add -A stages the rotated token, written onto a path Git tracks in another case: $staged"
        Assert (($out -replace '\s+', ' ') -match 'Git tracks 2 files under \.claude/framework-update-backup/') "the update does not say Git tracks the 2 files under the folder spelt in another case: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 blanket keep-out: a Hidden list is written in place with its attributes kept, and a Hidden read-only one is refused before any change, naming both attributes' {
    foreach ($readOnly in $false, $true) {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-hidden-' + [guid]::NewGuid())
        try {
            $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
            Write-B429Files -Folder (Join-Path $t '.claude/skills/my-deploy') -Files $b429Residue
            # Team settings the update saves first, so a write that fails later leaves that save behind.
            $teamList = "# team list`n"
            Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/settings.json' = "{`"team`": true}`n"; '.claude/framework-update-backup/.gitignore' = $teamList })
            & git -C $t add -A
            & git -C $t commit -qm 'framework state, team settings and list'
            # What a checkout with core.hideDotFiles=true leaves: the list marked Hidden.
            $list = Get-Item -Force -LiteralPath (Join-Path $t '.claude/framework-update-backup/.gitignore')
            $list.Attributes = $list.Attributes -bor [IO.FileAttributes]::Hidden
            if ($readOnly) { $list.Attributes = $list.Attributes -bor [IO.FileAttributes]::ReadOnly }
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $code = $LASTEXITCODE
            $after = Get-Item -Force -LiteralPath $list.FullName
            # Windows PowerShell 5.1 wraps a captured stderr line at the console width.
            $flat = $out -replace '\s+', ' '
            if ($readOnly) {
                Assert ($code -eq 3 -and $flat -match 'Nothing was changed') "a Hidden read-only list did not refuse the update before any change (exit $code): $out"
                Assert ($flat -match 'marked ReadOnly and Hidden') "the refusal does not name the list's ReadOnly and Hidden attributes: $out"
                $changed = @(& git -C $t status --porcelain --untracked-files=all)
                Assert ($changed.Count -eq 0) "the refused update changed the tree: $($changed -join ' | ')"
            } else {
                Assert ($code -eq 0) "a Hidden list stopped the update (exit $code): $out"
                $lines = @([IO.File]::ReadAllText($list.FullName) -split "`n" | Where-Object { $_.Trim() })
                Assert ($lines[-1] -ceq '*' -and $lines -ccontains '# team list') "the Hidden list does not end with * after the team's line: $($lines -join ' | ')"
                Assert (($after.Attributes -band [IO.FileAttributes]::Hidden) -ne 0) "the list lost its Hidden attribute: $($after.Attributes)"
                $added = @(& git -C $t add -A --dry-run | Where-Object { $_ -match 'framework-update-backup/skills/' })
                Assert ($added.Count -eq 0) "git add -A would commit a backup copy: $($added -join ' | ')"
            }
        } finally {
            Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object { $_.IsReadOnly = $false }
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# A team's own lines in the framework-owned .claude/.gitignore: an update replaced the file and dropped them without a word,
# so a local file they ignored, a token in .claude/mcp.local.json say, showed as committable. Carrying the old lines forward
# was beaten: a line an earlier release shipped looks like a team's, so a line a release drops never went. So the update
# writes the release's file and keeps each file Git ignored before, and would now show, ignored by one anchored line.
$b431Marker = '# Kept ignored by framework updates: files Git ignored before an update replaced this file. Each update rewrites the lines below; put your own rules in the root .gitignore.'
$b431Save = '.claude/framework-update-backup/files/_.claude/_.gitignore'
$b431Notice = "NOTICE: this update writes the framework's \.claude/\.gitignore as released\."
function New-B431Target {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][byte[]]$Ignore, [Parameter(Mandatory)][Collections.IDictionary]$Local)
    $t = New-B429GitTarget -Root $Root -Ignore "/scratch/`n"
    [IO.File]::WriteAllBytes((Join-Path $t '.claude/.gitignore'), $Ignore)
    & git -C $t add -A
    & git -C $t commit -qm 'framework state and team ignore lines'
    Write-B429Files -Folder $t -Files $Local
    return $t
}
# The 0.94.0 release's .claude/.gitignore lines, the file a team edited.
function Get-B431ReleaseLines { return @([Text.UTF8Encoding]::new($false).GetString((Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/.claude/.gitignore')).Split([char]10) | Where-Object { $_ }) }
function Get-B431Committable { param([string]$Target) return @(& git -C $Target status --porcelain --untracked-files=all | Where-Object { $_.StartsWith('?? ') } | ForEach-Object { $_.Substring(3) }) }
# The release's bytes, then, when any file needs it, the marker and one anchored line per file.
function Get-B431Expected {
    param([string[]]$Anchors = @(), [string]$Release = (Join-Path $repoRoot 'dist/dotnet'))
    $bytes = [IO.File]::ReadAllBytes((Join-Path $Release '.claude/.gitignore'))
    if ($Anchors.Count -eq 0) { return , $bytes }
    return [byte[]]($bytes + [Text.UTF8Encoding]::new($false).GetBytes($b431Marker + "`n" + ($Anchors -join "`n") + "`n"))
}
function Get-B431Text { param([string]$Target) return [IO.File]::ReadAllText((Join-Path $Target '.claude/.gitignore')) }

It 'B-431 status: a file a team''s own line in .claude/.gitignore ignored stays ignored by one anchored line after the release''s bytes, the update says so and saves the team''s version out of Git, and a re-run changes nothing' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-' + [guid]::NewGuid())
    try {
        # The first attacking session's fixture: one line for a local MCP config holding a token.
        $team = [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) + 'mcp.local.json' -join "`n") + "`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-live-FX-SECRET`"}`n" })
        Assert ((Get-B431Committable $t).Count -eq 0) 'calibration: the token file is committable before the update'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $committable = Get-B431Committable $t
        Assert ($committable -notcontains '.claude/mcp.local.json') "the team's ignore line was dropped, so its token file is committable: $($committable -join ', ')"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/mcp.local.json')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the update did not write the release's bytes, the marker, then one anchored line for the token file: $(Get-B431Text $t)"
        Assert ($flat -match ($b431Notice + " Your version had lines this release's version lacks \('mcp\.local\.json'\), which no longer apply there; it is saved at " + [regex]::Escape($b431Save) + "\. Git ignored 1 file below \.claude/ before this update that the release's version does not ignore, so the update keeps it ignored with one line below the line '" + [regex]::Escape($b431Marker) + "': /mcp\.local\.json\. Such a line names one file: a folder or wildcard rule of yours no longer covers a file created later\. Put rules of your own in the root \.gitignore: \.claude/\.gitignore is the framework's file, and every update rewrites it\.")) "the dropped line, the save and the anchored file were not reported in one NOTICE: $out"
        Assert ((Test-Path -LiteralPath (Join-Path $t $b431Save) -PathType Leaf) -and (Test-B194BytesEqual $team ([IO.File]::ReadAllBytes((Join-Path $t $b431Save))))) "the team's version was not saved byte-identical at $b431Save`: $out"
        Assert (@($committable | Where-Object { $_ -match 'framework-update-backup/' }).Count -eq 0) "the saved version is committable: $($committable -join ', ')"
        Assert ($flat -notmatch 'CANT-VERIFY') "the update reported CANT-VERIFY: $out"
        $kept = [IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore'))
        $again = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the second update failed (exit $LASTEXITCODE): $again"
        Assert (Test-B194BytesEqual $kept ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "a re-run changed the anchored section: $(Get-B431Text $t)"
        Assert (($again -replace '\s+', ' ') -notmatch "NOTICE: [^.]*\.claude/\.gitignore") "a re-run reported the section again: $again"
        Assert ((Get-B431Committable $t) -notcontains '.claude/mcp.local.json') "after a re-run the token file is committable: $again"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 status: no team line is copied, so a line identical to a framework line appears once, and each file another line ignored gets one anchored line with the glob characters in its name escaped' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-same-' + [guid]::NewGuid())
    try {
        $team = [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) + 'settings.local.json', '*.pem' -join "`n") + "`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/deploy.pem' = "-----FIXTURE KEY-----`n"; '.claude/keys[prod] #1 !.pem' = "-----FIXTURE KEY-----`n" })
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $committable = Get-B431Committable $t
        Assert (@($committable | Where-Object { $_ -like '.claude/*.pem' }).Count -eq 0) "the team's *.pem line was dropped, so a key file is committable: $($committable -join ', ')"
        $text = Get-B431Text $t
        Assert (@($text.Split([char]10) | Where-Object { $_ -ceq 'settings.local.json' }).Count -eq 1) "a team line identical to a framework line is written twice or not at all: $text"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/deploy.pem', '/keys\[prod\]\ \#1\ \!.pem')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the update did not write the release's bytes and one escaped anchored line per key file: $text"
        Assert (($out -replace '\s+', ' ') -notmatch 'CANT-VERIFY') "the update reported CANT-VERIFY: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 status: with a team''s ! lines in the old file, a file one re-included stays committable and each file the old lines ignored stays ignored' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-negation-' + [guid]::NewGuid())
    try {
        # Inserted after the framework's .state/ line: in this order Git ignores mcp.local.json and settings.local.json, the
        # framework's own line after the team's !settings.local.json winning, and shows shared.local.json.
        $release = Get-B431ReleaseLines
        $ownLines = @('*.local.json', '!shared.local.json', '!settings.local.json')
        $team = [Text.UTF8Encoding]::new($false).GetBytes((@($release[0..1]) + $ownLines + @($release[2..($release.Count - 1)]) -join "`n") + "`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-live-FX-SECRET`"}`n"; '.claude/settings.local.json' = "{`"env`":{`"API_KEY`":`"sk-FIXTURE`"}}`n"; '.claude/shared.local.json' = "{`"shared`":true}`n" })
        Assert (((Get-B431Committable $t) -join ',') -ceq '.claude/shared.local.json') "calibration: before the update Git does not show only shared.local.json: $((Get-B431Committable $t) -join ', ')"
        $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $committable = Get-B431Committable $t
        Assert ($committable -notcontains '.claude/mcp.local.json') "the team's *.local.json line was dropped, so its token file is committable: $($committable -join ', ')"
        Assert ($committable -notcontains '.claude/settings.local.json') "the local settings the old lines ignored are committable: $($committable -join ', ')"
        Assert ($committable -contains '.claude/shared.local.json') "a file the old lines showed is now ignored: $($committable -join ', ')"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/mcp.local.json')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the update did not write the release's bytes and one anchored line for the token file alone: $(Get-B431Text $t)"
        Assert (($out -replace '\s+', ' ') -notmatch 'CANT-VERIFY') "the update reported CANT-VERIFY: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 status: a team''s .claude/.gitignore saved with CRLF line endings and a byte-order mark: no framework line is called the team''s, and its file stays ignored by one anchored line' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-crlf-' + [guid]::NewGuid())
    try {
        # What Windows PowerShell 5.1's Set-Content -Encoding UTF8 writes, and Git reads as the same lines.
        $team = [Text.UTF8Encoding]::new($true).GetPreamble() + [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) + 'mcp.local.json' -join "`r`n") + "`r`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-live-FX-SECRET`"}`n" })
        Assert ((Get-B431Committable $t).Count -eq 0) 'calibration: Git does not read the CRLF file with a byte-order mark as ignoring the token file'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert ((Get-B431Committable $t) -notcontains '.claude/mcp.local.json') "the team's CRLF line was dropped, so its token file is committable: $out"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/mcp.local.json')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the update did not write the release's bytes and one anchored line: $(Get-B431Text $t)"
        Assert (($out -replace '\s+', ' ') -match "lacks \('mcp\.local\.json'\), which") "the NOTICE names a framework line differing only in its CR or the byte-order mark as the team's: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 status: when a release''s .claude/.gitignore no longer ignores an existing file the old one ignored, that file stays ignored by one anchored line' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-check-' + [guid]::NewGuid())
    try {
        # A release whose .claude/.gitignore re-includes local settings the 0.94.0 lines ignored.
        $framework = Join-Path $root 'framework'
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRoot 'dist/dotnet') -Destination $framework -Recurse
        [IO.File]::AppendAllText((Join-Path $framework '.claude/.gitignore'), "!settings.local.json`n", [Text.UTF8Encoding]::new($false))
        $team = [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) + 'mcp.local.json' -join "`n") + "`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-live-FX-SECRET`"}`n"; '.claude/settings.local.json' = "{`"env`":{`"API_KEY`":`"sk-FIXTURE`"}}`n" })
        $out = & (Get-PsExe) -NoProfile -File (Join-Path $framework 'scripts/install.ps1') -Target $t 2>&1 | Out-String
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $committable = Get-B431Committable $t
        Assert ($committable -notcontains '.claude/settings.local.json' -and $committable -notcontains '.claude/mcp.local.json') "a file the old lines ignored is committable: $($committable -join ', ')"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/mcp.local.json', '/settings.local.json') -Release $framework) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the update did not write the release's bytes and one anchored line per file: $(Get-B431Text $t)"
        Assert (($out -replace '\s+', ' ') -match 'Git ignored 2 files below \.claude/ before this update that the release''s version does not ignore, so the update keeps them ignored with one line each below the line') "the NOTICE does not count the two anchored files: $out"
        Assert (($out -replace '\s+', ' ') -notmatch 'CANT-VERIFY') "the update reported CANT-VERIFY: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 status: a release that drops its own ! line and rewords a comment takes effect, so the file the ! line showed is ignored, the file is the release''s byte for byte, and the old lines are not called the team''s own' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-release-' + [guid]::NewGuid())
    try {
        # The second attacking session's fixture: release A's file is the shipped one plus '*.local.json' and '!shared.local.json';
        # release B rewords the first comment and drops the '!' line, so shared.local.json, a token, should be ignored after it.
        $utf8 = [Text.UTF8Encoding]::new($false)
        $base = [IO.File]::ReadAllText((Join-Path $repoRoot 'dist/dotnet/.claude/.gitignore'), $utf8)
        $releaseA = $base + "*.local.json`n!shared.local.json`n"
        $lines = $base.Split([char]10)
        $lines[0] = '# Hook state: runtime stamps for throttling and dedup.'
        $releaseB = ($lines -join "`n") + "*.local.json`n"
        $framework = Join-Path $root 'releaseB'
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRoot 'dist/dotnet') -Destination $framework -Recurse
        [IO.File]::WriteAllText((Join-Path $framework '.claude/.gitignore'), $releaseB, $utf8)
        $t = New-B431Target -Root $root -Ignore ($utf8.GetBytes($releaseA)) -Local ([ordered]@{ '.claude/shared.local.json' = "{`"token`":`"sk-FIXTURE1`"}`n" })
        Assert ((Get-B431Committable $t) -contains '.claude/shared.local.json') 'calibration: release A does not show shared.local.json'
        $out = & (Get-PsExe) -NoProfile -File (Join-Path $framework 'scripts/install.ps1') -Target $t -AllowDirtyTree 2>&1 | Out-String
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert ((Get-B431Committable $t) -notcontains '.claude/shared.local.json') "the ! line release B dropped still shows the token file: $(Get-B431Text $t)"
        Assert ((Get-B431Text $t) -ceq $releaseB) "the file is not release B's byte for byte: $(Get-B431Text $t)"
        Assert ($flat -notmatch 'lines of your own' -and -not $flat.Contains('runtime stamps used for throttling')) "the update called release A's lines the team's own: $out"
        Assert ($flat -notmatch 'CANT-VERIFY') "the update reported CANT-VERIFY: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 status: a .claude/.gitignore an earlier update wrote, saved again with a byte-order mark, is rewritten with the same section and no NOTICE or second save' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-bom-' + [guid]::NewGuid())
    try {
        $team = [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) + 'mcp.local.json' -join "`n") + "`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-live-FX-SECRET`"}`n" })
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the first update failed (exit $LASTEXITCODE): $first"
        & git -C $t add -A
        & git -C $t commit -qm 'first update'
        # An editor that writes a byte-order mark saves the file again, otherwise unchanged.
        $written = [IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore'))
        [IO.File]::WriteAllBytes((Join-Path $t '.claude/.gitignore'), [byte[]]([Text.UTF8Encoding]::new($true).GetPreamble() + $written))
        $again = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        $flat = $again -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the second update failed (exit $LASTEXITCODE): $again"
        Assert ($flat -notmatch "NOTICE: [^.]*\.claude/\.gitignore") "the second update repeated a NOTICE for a file it had already handled: $again"
        Assert (@(Get-ChildItem -LiteralPath (Join-Path $t '.claude/framework-update-backup/files/_.claude') -File -Force -ErrorAction SilentlyContinue).Count -le 1) "the second update saved the file again: $again"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/mcp.local.json')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the section repeated, grew or kept the byte-order mark: $(Get-B431Text $t)"
        Assert ((Get-B431Committable $t) -notcontains '.claude/mcp.local.json') "after the second update the token file is committable: $again"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 write last: an update that stops at a file another program holds leaves the team''s .claude/.gitignore as it was, and the re-run keeps the token file it ignored out of Git' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-locked-' + [guid]::NewGuid())
    try {
        # The second attacking session's fixture: the release's lines plus the team's 'token.txt', and a script the update
        # replaces held open by another program, so the update stops at it.
        $team = [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) + 'token.txt' -join "`n") + "`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ 'scripts/wiki-check.ps1' = "# the team's older copy`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'older script'
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/token.txt' = "sk-FIXTURE2`n" })
        Assert ((Get-B431Committable $t).Count -eq 0) 'calibration: the token file is committable before the update'
        $held = [IO.File]::Open((Join-Path $t 'scripts/wiki-check.ps1'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try { $out = Invoke-Installer -Dist 'dotnet' -Target $t; $code = $LASTEXITCODE } finally { $held.Dispose() }
        Assert ($code -ne 0) "calibration: the update did not stop at the held file (exit $code): $out"
        Assert (Test-B194BytesEqual $team ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the stopped update had already replaced the team's .claude/.gitignore: $(Get-B431Text $t)"
        Assert ((Get-B431Committable $t) -notcontains '.claude/token.txt') "after the stopped update the token file is committable: $out"
        $again = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the re-run failed (exit $LASTEXITCODE): $again"
        Assert ((Get-B431Committable $t) -notcontains '.claude/token.txt') "after the re-run the token file is committable: $again"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/token.txt')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the re-run did not write the release's bytes and one anchored line for the token file: $(Get-B431Text $t)"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 write last: a .claude/.gitignore that ends with the marker and no line below it, as an update stopped between its last two writes leaves it, is named in a CANT-VERIFY line' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-stopped-' + [guid]::NewGuid())
    try {
        $stopped = [byte[]]([IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/.claude/.gitignore')) + [Text.UTF8Encoding]::new($false).GetBytes($b431Marker + "`n"))
        $t = New-B431Target -Root $root -Ignore $stopped -Local ([ordered]@{ '.claude/token.txt' = "sk-FIXTURE2`n" })
        $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (($out -replace '\s+', ' ') -match ("CANT-VERIFY: '\.claude/\.gitignore' ends with the line '" + [regex]::Escape($b431Marker) + "' and no line below it, as an update that stopped between its last two writes leaves it")) "the update did not name a file an update stopped between its last two writes: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# A brownfield install archives a team's own .claude/.gitignore for /adopt and installs the framework's (B-441): B-431's rule
# then keeps each file the team's lines ignored ignored, as an update does, and the team's file stays until the last write.
function New-B441Target {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][byte[]]$Ignore, [Parameter(Mandatory)][Collections.IDictionary]$Local, [Collections.IDictionary]$Tracked = @{})
    $t = New-B309GitTarget -Root $Root -Name 'target' -Ignore "bin/`n"
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $t '.claude/.gitignore'), $Ignore)
    Write-B429Files -Folder $t -Files $Tracked
    & git -C $t add -A
    & git -C $t commit -qm 'team claude ignore'
    Write-B429Files -Folder $t -Files $Local
    return $t
}

It 'B-441 a brownfield install over a team''s own .claude/.gitignore writes the release''s bytes, keeps the file its lines ignored ignored by one anchored line, and names the archived version in one NOTICE' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b441-' + [guid]::NewGuid())
    try {
        # B-431's implementation saw it: the team's file moved to docs/pre-adoption/, the framework's replaced it, and Git showed
        # ?? .claude/mcp.local.json while the handoff said to commit the copied files.
        $team = [Text.UTF8Encoding]::new($false).GetBytes("mcp.local.json`n")
        $t = New-B441Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-live-FX-SECRET`"}`n" })
        Assert ((Get-B431Committable $t).Count -eq 0) 'calibration: the token file is committable before the install'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: brownfield') "the brownfield install failed (exit $LASTEXITCODE): $out"
        $committable = Get-B431Committable $t
        Assert ($committable -notcontains '.claude/mcp.local.json') "the install replaced the team's .claude/.gitignore, so its token file is committable: $($committable -join ', ')"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/mcp.local.json')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the install did not write the release's bytes, the marker, then one anchored line for the token file: $(Get-B431Text $t)"
        Assert (Test-B194BytesEqual $team ([IO.File]::ReadAllBytes((Join-Path $t 'docs/pre-adoption/.claude/_.gitignore')))) "the team's version was not archived byte-identical: $out"
        Assert ($flat -match ("NOTICE: this install writes the framework's \.claude/\.gitignore as released\. Your version had lines this release's version lacks \('mcp\.local\.json'\), which no longer apply there; it is saved at docs/pre-adoption/\.claude/_\.gitignore\. Git ignored 1 file below \.claude/ before this install that the release's version does not ignore, so the install keeps it ignored with one line below the line '" + [regex]::Escape($b431Marker) + "': /mcp\.local\.json\.")) "the archived version and the anchored file were not named in one NOTICE: $out"
        Assert ($flat -notmatch 'CANT-VERIFY') "the install reported CANT-VERIFY: $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/framework-update-backup'))) "a brownfield install saved a copy below the update backup folder: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-441 write last: a brownfield install that stops at a file another program holds leaves the team''s .claude/.gitignore in place, so the token file it ignored stays out of Git' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b441-held-' + [guid]::NewGuid())
    try {
        # The install archives in manifest order: .claude/.gitignore goes first, and a team script it archives later is held open.
        $team = [Text.UTF8Encoding]::new($false).GetBytes("token.txt`n")
        $t = New-B441Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/token.txt' = "sk-FIXTURE2`n" }) -Tracked ([ordered]@{ 'scripts/wiki-check.ps1' = "# the team's own script`n" })
        Assert ((Get-B431Committable $t).Count -eq 0) 'calibration: the token file is committable before the install'
        $held = [IO.File]::Open((Join-Path $t 'scripts/wiki-check.ps1'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try { $out = Invoke-Installer -Dist 'dotnet' -Target $t; $code = $LASTEXITCODE } finally { $held.Dispose() }
        Assert ($code -ne 0 -and ($out -replace '\s+', ' ') -match "Brownfield archive move failed for 'scripts/wiki-check\.ps1'") "calibration: the install did not stop at the held file (exit $code): $out"
        Assert ((Test-Path -LiteralPath (Join-Path $t '.claude/.gitignore') -PathType Leaf) -and (Test-B194BytesEqual $team ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore'))))) "the stopped install had already taken the team's .claude/.gitignore away: $out"
        Assert ((Get-B431Committable $t) -notcontains '.claude/token.txt') "after the stopped install the token file is committable: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-435 a brownfield install keeps out of Git the archive of a tracked original whose local changes Git is told not to see: skip-worktree, and assume-unchanged under another letter case' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b435-' + [guid]::NewGuid())
    try {
        # check-ignore never reports a tracked path, so the archive of a file whose local key Git does not see was committable.
        $t = New-B309GitTarget -Root $root -Name 'target' -Ignore "bin/`n"
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/settings.json' = "{}`n"; 'claude.md' = "# team rules`n"; 'TECH_DEBT.md' = "# team debt`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'team files'
        & git -C $t update-index --skip-worktree .claude/settings.json
        & git -C $t update-index --assume-unchanged claude.md
        $local = [ordered]@{ '.claude/settings.json' = "{`"env`":{`"API_KEY`":`"sk-FIXTURE4`"}}`n"; 'claude.md' = "# team rules`nLOCAL-ONLY-FIXTURE-NOTE`n" }
        Write-B429Files -Folder $t -Files $local
        Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') 'calibration: Git sees the local changes it was told not to see'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: brownfield') "the brownfield install failed (exit $LASTEXITCODE): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'docs/pre-adoption/\.claude/settings\.json') "the archive of a skip-worktree original is committable: $status"
        Assert ($status -notmatch '(?i)docs/pre-adoption/claude\.md') "the archive of an assume-unchanged original is committable: $status"
        Assert ($status -match 'docs/pre-adoption/TECH_DEBT\.md') "calibration: the tracked team file's archive is not committable: $status"
        Assert ([IO.File]::ReadAllText((Join-Path $t 'docs/pre-adoption/.claude/settings.json')) -ceq $local['.claude/settings.json'] -and [IO.File]::ReadAllText((Join-Path $t 'docs/pre-adoption/CLAUDE.md')) -ceq $local['claude.md']) "the archives do not hold the local content: $out"
        $lines = @([IO.File]::ReadAllLines((Join-Path $t 'docs/pre-adoption/.gitignore')) | Where-Object { $_ })
        Assert (($lines -join '|') -ceq '/.claude/settings.json|/CLAUDE.md') "docs/pre-adoption/.gitignore does not hold exactly the two anchored lines: $($lines -join '|')"
        Assert ($out -match 'Kept out of Git[^\r\n]*\.claude/settings\.json' -and $out -match 'Kept out of Git[^\r\n]*CLAUDE\.md') "the handoff does not name the kept-out files: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-435 attack: a team''s own .claude/.gitignore is archived as _.gitignore, so its ! rule cannot re-include the kept-out archive of a skip-worktree settings file, and Git confirms the keep-out' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b435-live-' + [guid]::NewGuid())
    try {
        # The fresh-session attack: archived live at docs/pre-adoption/.claude/.gitignore, '!settings.json' beat the keep-out
        # line, so the archive holding the key was ?? and git add -A staged it while the handoff said "Kept out of Git".
        $team = [Text.UTF8Encoding]::new($false).GetBytes("*.local.json`n!settings.json`n")
        $t = New-B441Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-FIXMCP`"}`n" }) -Tracked ([ordered]@{ '.claude/settings.json' = "{}`n" })
        & git -C $t update-index --skip-worktree .claude/settings.json
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/settings.json' = "{`"env`":{`"API_KEY`":`"sk-FIX9`"}}`n" })
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: brownfield') "the brownfield install failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t 'docs/pre-adoption/.claude/.gitignore'))) "the team's .gitignore was archived where Git reads it: $out"
        Assert (Test-B194BytesEqual $team ([IO.File]::ReadAllBytes((Join-Path $t 'docs/pre-adoption/.claude/_.gitignore')))) "the team's .gitignore was not archived byte-identical as _.gitignore: $out"
        & git -C $t check-ignore -q --no-index -- docs/pre-adoption/.claude/settings.json
        Assert ($LASTEXITCODE -eq 0) "Git does not ignore the archive of the skip-worktree settings file: $out"
        $added = @(& git -C $t add -A --dry-run | Where-Object { $_ -match 'pre-adoption/\.claude/settings\.json|mcp\.local' })
        Assert ($added.Count -eq 0) "git add -A would stage a kept-out file: $($added -join ' | ')"
        Assert ($out -match 'Kept out of Git[^\r\n]*\.claude/settings\.json' -and ($out -replace '\s+', ' ') -notmatch 'CANT-VERIFY') "the handoff does not name the kept-out archive, or reports CANT-VERIFY: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'a disabled retired recipe skill: the update finishes, carries the folder''s consumer files and removes the active copy' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('recipe-disabled-' + [guid]::NewGuid())
    try {
        # The retirement deletes the unmodified SKILL.md first; the disabled carry must not then try to copy it.
        $active = Join-Path $t '.claude/skills/add-service'
        $pattern = Join-Path $active 'references/project-pattern.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $pattern) | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.91.0","template":"monorepo"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.91.0:dist/monorepo/framework-ownership.json'))
        [IO.File]::WriteAllText((Join-Path $t 'LEARNINGS.md'), "# Learnings`n`n## Disabled framework skill: add-service`n`nNot used here.`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $active 'SKILL.md'), (Get-GitBlobBytes -Spec 'v0.91.0:dist/monorepo/.claude/skills/add-service/SKILL.md'))
        $patternBytes = [Text.UTF8Encoding]::new($false).GetBytes("# Project pattern`nDISABLED-SIDECAR consumer evidence.`n")
        [IO.File]::WriteAllBytes($pattern, $patternBytes)
        $out = Invoke-Installer -Dist 'monorepo' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update stopped (exit $LASTEXITCODE): $out"
        $carried = Join-Path $t '.claude/disabled-skills/add-service/references/project-pattern.md'
        Assert ((Test-Path -LiteralPath $carried -PathType Leaf) -and (Test-B194BytesEqual $patternBytes ([IO.File]::ReadAllBytes($carried)))) "the consumer's project-pattern.md was not carried to disabled-skills: $out"
        Assert (-not (Test-Path -LiteralPath $active)) "the disabled skill's active copy was left in place: $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/disabled-skills/add-service/SKILL.md'))) "the retired framework SKILL.md was carried instead of retired: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# A disabled skill's active folder is carried to .claude/disabled-skills/ and deleted; the release's copy then goes over the
# carried files (B-430). Those paths are in no manifest, so what the carry and that copy would overwrite is saved first.
function New-B430Target {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Skill, [string]$Ignore = '', [switch]$NoSkillBackup)
    $t = New-B429GitTarget -Root $Root -Ignore "/scratch/`n$Ignore"
    [IO.File]::WriteAllText((Join-Path $t 'LEARNINGS.md'), "# Learnings`n`n## Disabled framework skill: $Skill`n`nNot used here.`n", [Text.UTF8Encoding]::new($false))
    # The one-time skill backup an earlier update took: present, so this update does not copy the skills again.
    if (-not $NoSkillBackup) { New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/framework-update-backup/skills') | Out-Null }
    return $t
}

It 'B-430 a team''s own skill at a disabled framework skill''s path, and a team file at its .claude/disabled-skills path, are saved out of Git before the update writes over them, once across re-runs' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b430-' + [guid]::NewGuid())
    try {
        # B-393's attack: the team's own perf skill was carried to .claude/disabled-skills/perf/, the release's copy went over it,
        # and the active folder was deleted, so its text was left only in Git HEAD.
        $t = New-B430Target -Root $root -Skill 'perf'
        $utf8 = [Text.UTF8Encoding]::new($false)
        $teamSkill = $utf8.GetBytes("---`nname: perf`ndescription: our own load-test checklist`n---`nTEAM PERF RECIPE`n")
        $olderNotes = $utf8.GetBytes("team notes v1`n")
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/skills/perf/notes.md' = "team notes v2`n"; '.claude/disabled-skills/perf/notes.md' = "team notes v1`n" })
        [IO.File]::WriteAllBytes((Join-Path $t '.claude/skills/perf/SKILL.md'), $teamSkill)
        & git -C $t add -A
        & git -C $t commit -qm 'team perf skill'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/skills/perf'))) "the disabled skill's active copy was left in place: $out"
        Assert (Test-B194BytesEqual ([IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/.claude/skills/perf/SKILL.md'))) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/disabled-skills/perf/SKILL.md')))) "the release's perf skill is not at its disabled path: $out"
        Assert ([IO.File]::ReadAllText((Join-Path $t '.claude/disabled-skills/perf/notes.md')) -ceq "team notes v2`n") "the active folder's notes.md was not carried: $out"
        $skillSave = '.claude/framework-update-backup/files/_.claude/skills/perf/SKILL.md'
        $notesSave = '.claude/framework-update-backup/files/_.claude/disabled-skills/perf/notes.md'
        Assert ((Test-Path -LiteralPath (Join-Path $t $skillSave) -PathType Leaf) -and (Test-B194BytesEqual $teamSkill ([IO.File]::ReadAllBytes((Join-Path $t $skillSave))))) "the team's own .claude/skills/perf/SKILL.md was not saved byte-identical at $skillSave before the release's copy went over it: $out"
        Assert ((Test-Path -LiteralPath (Join-Path $t $notesSave) -PathType Leaf) -and (Test-B194BytesEqual $olderNotes ([IO.File]::ReadAllBytes((Join-Path $t $notesSave))))) "the team's .claude/disabled-skills/perf/notes.md was not saved byte-identical at $notesSave before the carry went over it: $out"
        Assert ($flat -match "NOTICE: LEARNINGS\.md disables the framework skill 'perf', so the update moves \.claude/skills/perf/ to \.claude/disabled-skills/perf/, where this release's copy replaces '\.claude/skills/perf/SKILL\.md', which differs from it: the update first saves it to $([regex]::Escape($skillSave))\.") "the save of the team's skill was not reported: $out"
        Assert ($flat -match "NOTICE: '\.claude/disabled-skills/perf/notes\.md' differs from the file this update writes there, so the update first saves it to $([regex]::Escape($notesSave))\.") "the save of the team's disabled-skills file was not reported: $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/') "a saved copy is committable: $status"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
        $again = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the second update failed (exit $LASTEXITCODE): $again"
        Assert (($again -replace '\s+', ' ') -notmatch 'first saves it to') "the second update saved again a file the first one handled: $again"
        Assert (@(Get-ChildItem -LiteralPath (Join-Path $t '.claude/framework-update-backup/files') -Recurse -File -Force).Count -eq 2) "the second update added a save: $again"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-430 a file in a disabled skill''s active copy that Git keeps out of commits is never moved to .claude/disabled-skills, where Git could commit it: it is saved out of Git, named in one NOTICE' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b430-hidden-' + [guid]::NewGuid())
    try {
        # B-429's attack: disabling create-adr moved a developer's ignored local.env to .claude/disabled-skills/create-adr/, where
        # Git showed it as ??; a tracked file whose local changes Git is told not to see leaks the same way. Once with the one-time
        # skill backup already taken (the copies go below files/), once with this update taking it (they are its copies).
        foreach ($withBackup in $true, $false) {
            $label = if ($withBackup) { 'skill backup present' } else { 'skill backup taken now' }
            $t = New-B430Target -Root (Join-Path $root "$withBackup") -Skill 'create-adr' -Ignore "/.claude/skills/create-adr/local.env`n" -NoSkillBackup:(-not $withBackup)
            New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/skills/create-adr') | Out-Null
            [IO.File]::WriteAllBytes((Join-Path $t '.claude/skills/create-adr/SKILL.md'), [IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/.claude/skills/create-adr/SKILL.md')))
            Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/skills/create-adr/config.json' = "{}`n" })
            & git -C $t add -A
            & git -C $t commit -qm 'create-adr with a shared config'
            & git -C $t update-index --skip-worktree .claude/skills/create-adr/config.json
            $local = [ordered]@{ '.claude/skills/create-adr/local.env' = "TOKEN=sk-FIXTURE3`n"; '.claude/skills/create-adr/config.json' = "{`"key`":`"LOCAL-FIXTURE`"}`n" }
            Write-B429Files -Folder $t -Files $local
            Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') "${label}: calibration: Git sees a file it should keep out"
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $flat = $out -replace '\s+', ' '
            Assert ($LASTEXITCODE -eq 0) "${label}: the update failed (exit $LASTEXITCODE): $out"
            Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/skills/create-adr'))) "${label}: the disabled skill's active copy was left in place: $out"
            Assert (Test-Path -LiteralPath (Join-Path $t '.claude/disabled-skills/create-adr/SKILL.md') -PathType Leaf) "${label}: the release's create-adr is not at its disabled path: $out"
            foreach ($name in 'local.env', 'config.json') {
                Assert (-not (Test-Path -LiteralPath (Join-Path $t ".claude/disabled-skills/create-adr/$name"))) "${label}: $name, which Git kept out of commits, was moved to .claude/disabled-skills/create-adr/: $out"
            }
            $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
            Assert ($status -notmatch 'local\.env|config\.json|framework-update-backup/') "${label}: a file Git kept out of commits, or a copy of it, is committable: $status"
            $saveRoot = if ($withBackup) { '.claude/framework-update-backup/files/_.claude/skills/create-adr' } else { '.claude/framework-update-backup/skills/create-adr' }
            foreach ($name in 'config.json', 'local.env') {
                $copy = Join-Path $t "$saveRoot/$name"
                Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq $local[".claude/skills/create-adr/$name"]) "${label}: $name was not saved byte-identical at $saveRoot/$name`: $out"
            }
            $notice = "NOTICE: Git keeps 2 files in the active copy of a disabled skill out of commits \(ignored, or tracked with local changes Git is told not to see\), so the update does not move them to \.claude/disabled-skills/, where Git could commit them: \.claude/skills/create-adr/config\.json is saved at $([regex]::Escape("$saveRoot/config.json")), \.claude/skills/create-adr/local\.env at $([regex]::Escape("$saveRoot/local.env"))\."
            Assert (@([regex]::Matches($flat, $notice)).Count -eq 1) "${label}: the kept-out files were not named in exactly one NOTICE: $out"
        }
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-430 attack: a disabled skill whose folder is spelt in another letter case still keeps the file Git ignores there out of .claude/disabled-skills' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b430-case-' + [guid]::NewGuid())
    try {
        # The fresh-session attack: .claude/skills/Perf on disk and in the index, LEARNINGS.md disabling 'perf'; the
        # case-sensitive :(literal) pathspec missed Perf/local.env, which moved to a committable .claude/disabled-skills path.
        $t = New-B430Target -Root $root -Skill 'perf' -Ignore ".claude/skills/Perf/local.env`n"
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/skills/Perf') | Out-Null
        [IO.File]::WriteAllBytes((Join-Path $t '.claude/skills/Perf/SKILL.md'), [IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/.claude/skills/perf/SKILL.md')))
        & git -C $t add -A
        & git -C $t commit -qm 'perf skill'
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/skills/Perf/local.env' = "TOKEN=sk-FIX10`n" })
        Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') 'calibration: Git does not ignore Perf/local.env'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/disabled-skills/perf/local.env'))) "local.env, which Git ignored, was moved to .claude/disabled-skills/perf/: $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'local\.env') "the ignored file, or a copy of it, is committable: $status"
        $copy = Join-Path $t '.claude/framework-update-backup/files/_.claude/skills/perf/local.env'
        Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq "TOKEN=sk-FIX10`n") "local.env was not saved below the backup folder: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-322 a re-run of a finished update keeps the consumer''s pre-update settings backup' {
    # Every update run saved .claude/settings.json over the last backup, so re-running a finished update
    # replaced the consumer's settings in it with the framework's own; a non-Git target has no other copy.
    # The crlf leg is the framework's file as a core.autocrlf checkout writes it.
    foreach ($leg in 'crlf', 'lf') {
        $t = Join-Path ([IO.Path]::GetTempPath()) ("b322-$leg-" + [guid]::NewGuid())
        try {
            New-ArchGeneratorTarget -Target $t
            [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/framework-ownership.json'))
            $settings = Join-Path $t '.claude/settings.json'
            [IO.File]::WriteAllText($settings, '{"B322":"consumer settings"}', [Text.UTF8Encoding]::new($false))
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "${leg}: the update failed (exit $LASTEXITCODE): $out"
            $backup = Join-Path $t '.claude/.state/settings.json.pre-update'
            Assert ((Test-Path -LiteralPath $backup -PathType Leaf) -and [IO.File]::ReadAllText($backup) -match 'B322') "${leg}: calibration: the update did not back up the consumer's settings: $out"
            if ($leg -eq 'crlf') {
                $lf = [IO.File]::ReadAllText($settings)
                Assert ($lf.Contains("`n") -and -not $lf.Contains("`r")) 'crlf: calibration: the refreshed settings are not a multi-line LF file'
                [IO.File]::WriteAllText($settings, $lf.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
            }
            $rerun = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "${leg}: the re-run failed (exit $LASTEXITCODE): $rerun"
            Assert ([IO.File]::ReadAllText($backup) -match 'B322') "${leg}: the re-run replaced the consumer's settings backup with the framework's: $rerun"
            Assert (($rerun -replace '\s+', ' ') -match 'kept the earlier pre-update settings backup') "${leg}: the re-run did not say it kept the earlier backup: $rerun"
        } finally {
            Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

It 'B-321 a one-time skill backup that a held file or a denied write cut short is taken again, so an edited framework skill keeps a copy' {
    # A backup cut short was skipped by the next run because its folder existed, which then overwrote the
    # edited skill; it survived in no file. The denied leg fails the first write below the backup folder,
    # where a marker written inside the new folder once failed with the folder already there.
    $manifestBytes = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/framework-ownership.json'
    $skillPaths = @(([Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json).paths | ForEach-Object { [string]$_.path } | Where-Object { $_.StartsWith('.claude/skills/') })
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    foreach ($leg in 'denied', 'held') {
        $t = Join-Path ([IO.Path]::GetTempPath()) ("b321-$leg-" + [guid]::NewGuid())
        $handle = $null; $deniedRoot = $null
        try {
            New-ArchGeneratorTarget -Target $t
            [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), $manifestBytes)
            foreach ($relative in $skillPaths) {
                $destination = Join-Path $t $relative
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
                [IO.File]::WriteAllBytes($destination, (Get-GitBlobBytes -Spec "v0.86.7:dist/dotnet/$relative"))
            }
            $edited = Join-Path $t '.claude/skills/remember-for-team/SKILL.md'
            [IO.File]::AppendAllText($edited, "`nB321 consumer edit.`n")
            if ($leg -eq 'held') {
                # A project-adapted sidecar, as /bootstrap writes one; it sorts before the edited skill.
                $held = Join-Path $t '.claude/skills/add-warehouse-load/references/project-pattern.md'
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $held) | Out-Null
                [IO.File]::WriteAllText($held, "# Project pattern`n", [Text.UTF8Encoding]::new($false))
                $handle = [IO.File]::Open($held, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
            } else {
                $deniedRoot = Join-Path $t '.claude/framework-update-backup'
                New-Item -ItemType Directory -Force -Path $deniedRoot | Out-Null
                & icacls $deniedRoot /deny "*${sid}:(OI)(CI)(IO)(WD)" | Out-Null
                Assert ($LASTEXITCODE -eq 0) 'calibration: icacls could not deny writes below the backup folder'
            }
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $flat = $out -replace '\s+', ' '
            Assert ($LASTEXITCODE -eq 3) "${leg}: the cut-short backup did not stop the update with exit 3 (exit $LASTEXITCODE): $out"
            Assert ($flat -match "Could not finish the one-time skill backup at '\.claude/skills/") "${leg}: the stop did not name where the backup stopped: $out"
            if ($leg -eq 'held') { Assert ($flat -match "at '\.claude/skills/add-warehouse-load/references/project-pattern\.md'") "held: the stop did not name the held file: $out" }
            Assert ([IO.File]::ReadAllText($edited) -match 'B321 consumer edit\.') "${leg}: the stop overwrote the edited skill: $out"
            if ($handle) { $handle.Dispose(); $handle = $null }
            if ($deniedRoot) { & icacls $deniedRoot /remove:d "*$sid" | Out-Null; $deniedRoot = $null }
            $rerun = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "${leg}: the re-run did not finish the update (exit $LASTEXITCODE): $rerun"
            $backup = Join-Path $t '.claude/framework-update-backup/skills/remember-for-team/SKILL.md'
            Assert ((Test-Path -LiteralPath $backup -PathType Leaf) -and [IO.File]::ReadAllText($backup) -match 'B321 consumer edit\.') "${leg}: the re-run did not take the backup again, so the edit survives in no file: $rerun"
            Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/framework-update-backup/skills-backup-incomplete'))) "${leg}: the finished backup still has its incomplete marker: $rerun"
        } finally {
            if ($handle) { $handle.Dispose() }
            if ($deniedRoot) { & icacls $deniedRoot /remove:d "*$sid" | Out-Null }
            Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

It 'B-319 an install leaves no source file that a project at the repository root compiles' {
    foreach ($dist in 'dotnet', 'monorepo') {
        $t = Join-Path ([IO.Path]::GetTempPath()) ("b319-$dist-" + [guid]::NewGuid())
        try {
            # An SDK-style project compiles every *.cs beneath it except under bin/, obj/ and dot-folders,
            # so the shipped NetArchTest sample broke `dotnet build` in a repo with its project at the root.
            [void][IO.Directory]::CreateDirectory($t)
            [IO.File]::WriteAllBytes((Join-Path $t 'App.csproj'), [Text.Encoding]::ASCII.GetBytes('<Project Sdk="Microsoft.NET.Sdk" />'))
            $out = Invoke-Installer -Dist $dist -Target $t
            Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: greenfield') "calibration: the $dist install failed: $out"
            $compiled = @(Get-ChildItem -LiteralPath $t -Recurse -File -Force | Where-Object { $_.Extension -eq '.cs' } |
                ForEach-Object { $_.FullName.Substring($t.Length + 1).Replace('\', '/') } |
                Where-Object { -not @($_.Split('/') | Where-Object { $_.StartsWith('.') }).Count })
            Assert ($compiled.Count -eq 0) "$dist installs source files a root-level project compiles: $($compiled -join ', ')"
            Assert (Test-Path -LiteralPath (Join-Path $t 'scripts/ci/ArchitectureTests.cs.sample') -PathType Leaf) "the $dist architecture-test sample was not installed under its inert name: $out"
        } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

It 'B-319 an update retires the compiled architecture-test sample and keeps a consumer-edited one' {
    foreach ($modified in @($false, $true)) {
        $label = if ($modified) { 'modified' } else { 'known' }
        $t = Join-Path ([IO.Path]::GetTempPath()) ("b319-retire-$label-" + [guid]::NewGuid())
        try {
            New-ArchGeneratorTarget -Target $t
            [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/framework-ownership.json'))
            $sample = Join-Path $t 'scripts/ci/ArchitectureTests.sample.cs'
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sample) | Out-Null
            $bytes = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/scripts/ci/ArchitectureTests.sample.cs'
            Assert ($bytes.Count -gt 0) 'calibration: the v0.86.7 sample fixture is empty'
            if ($modified) { $bytes = $bytes + [Text.UTF8Encoding]::new($false).GetBytes("// locally edited`n") }
            [IO.File]::WriteAllBytes($sample, $bytes)
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "$label sample update failed: $out"
            if ($modified) {
                Assert (Test-Path -LiteralPath $sample -PathType Leaf) 'a consumer-edited sample was deleted'
                Assert (Test-B194BytesEqual $bytes ([IO.File]::ReadAllBytes($sample))) 'a preserved sample changed bytes'
                Assert ($out -match "CANT-VERIFY: retired path 'scripts/ci/ArchitectureTests\.sample\.cs' has consumer-modified or unknown content") "the edited sample was not diagnosed: $out"
            } else {
                Assert (-not (Test-Path -LiteralPath $sample)) "a known compiled sample survived the update: $out"
                Assert ($out -match '(?m)^PLAN delete scripts/ci/ArchitectureTests\.sample\.cs\r?$') "the sample's deletion was not planned: $out"
            }
            Assert (Test-Path -LiteralPath (Join-Path $t 'scripts/ci/ArchitectureTests.cs.sample') -PathType Leaf) "the inert sample was not installed: $out"
        } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# Git for Windows checks text out with CRLF (core.autocrlf=true); the ledger records the released LF blobs.
function ConvertTo-B287CrlfBytes {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    $out = New-Object 'System.Collections.Generic.List[byte]' ($Bytes.Length + 4096)
    foreach ($b in $Bytes) { if ($b -eq 0x0A) { $out.Add([byte]0x0D) }; $out.Add($b) }
    return ,$out.ToArray()
}

It 'B-287 a retired file checked out with CRLF line endings is retired like its LF original' {
    $impact = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/.claude/commands/impact.md'
    $generator = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/scripts/build-architecture-html.ps1'
    # A BOM'd blob with non-ASCII bytes catches a text-level rewrite that a plain ASCII blob would not.
    Assert ($generator.Length -gt 3 -and $generator[0] -eq 0xEF -and $generator[1] -eq 0xBB -and $generator[2] -eq 0xBF -and
        @($generator[3..($generator.Length - 1)] | Where-Object { $_ -gt 0x7F }).Count -gt 0) 'calibration: the generator blob is not a BOM-prefixed file with non-ASCII bytes'
    $utf8 = [Text.UTF8Encoding]::new($false)
    $crlfImpact = ConvertTo-B287CrlfBytes $impact
    $firstCr = [Array]::IndexOf($crlfImpact, [byte]0x0D)
    $trailingSpace = [byte[]]($crlfImpact[0..($firstCr - 1)] + @([byte]0x20) + $crlfImpact[$firstCr..($crlfImpact.Length - 1)])
    $cases = @(
        @{ Label = 'crlf-ps1'; Path = 'scripts/build-architecture-html.ps1'; Bytes = (ConvertTo-B287CrlfBytes $generator); Retired = $true },
        @{ Label = 'crlf-md'; Path = '.claude/commands/impact.md'; Bytes = (ConvertTo-B287CrlfBytes $impact); Retired = $true },
        # Line endings are the only difference forgiven: an added BOM or an edited line is consumer content.
        @{ Label = 'crlf-bom-md'; Path = '.claude/commands/impact.md'; Bytes = ([byte[]](0xEF, 0xBB, 0xBF) + (ConvertTo-B287CrlfBytes $impact)); Retired = $false },
        @{ Label = 'crlf-edited-md'; Path = '.claude/commands/impact.md'; Bytes = ((ConvertTo-B287CrlfBytes $impact) + $utf8.GetBytes("# locally edited`r`n")); Retired = $false },
        # Nothing wider than CR LF -> LF: lone CR endings and a trailing-space edit are not Git's conversion.
        @{ Label = 'lone-cr-md'; Path = '.claude/commands/impact.md'; Bytes = ([byte[]]@($impact | ForEach-Object { if ($_ -eq 0x0A) { [byte]0x0D } else { $_ } })); Retired = $false },
        @{ Label = 'crlf-trailing-space-md'; Path = '.claude/commands/impact.md'; Bytes = $trailingSpace; Retired = $false }
    )
    foreach ($case in $cases) {
        $t = Join-Path ([IO.Path]::GetTempPath()) ("b287-$($case.Label)-" + [guid]::NewGuid())
        try {
            New-ArchGeneratorTarget -Target $t
            [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/framework-ownership.json'))
            $planted = Join-Path $t $case.Path
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $planted) | Out-Null
            [IO.File]::WriteAllBytes($planted, [byte[]]$case.Bytes)
            Assert ([Array]::IndexOf([byte[]]$case.Bytes, [byte]0x0D) -ge 0) "calibration: $($case.Label) holds no CR"
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "$($case.Label) update failed: $out"
            $escaped = [regex]::Escape($case.Path)
            if ($case.Retired) {
                Assert (-not (Test-Path -LiteralPath $planted)) "$($case.Label): a CRLF copy of a released blob survived the update: $out"
                Assert ($out -match "(?m)^PLAN delete $escaped\r?$") "$($case.Label): the deletion was not planned: $out"
            } else {
                Assert (Test-Path -LiteralPath $planted -PathType Leaf) "$($case.Label): consumer content was deleted: $out"
                Assert (Test-B194BytesEqual ([byte[]]$case.Bytes) ([IO.File]::ReadAllBytes($planted))) "$($case.Label): consumer content was changed: $out"
                Assert ($out -match "CANT-VERIFY: retired path '$escaped' has consumer-modified or unknown content") "$($case.Label): the preserved file was not diagnosed: $out"
            }
        } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

It 'a missing previous ownership manifest never authorizes generator deletion' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('arch-retire-nomanifest-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        $generator = Join-Path $t 'scripts/build-architecture-html.ps1'
        $bytes = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/scripts/build-architecture-html.ps1'
        [IO.File]::WriteAllBytes($generator, $bytes)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "missing-manifest update failed: $out"
        Assert (Test-Path -LiteralPath $generator -PathType Leaf) 'deletion occurred without previous ownership authority'
        Assert (Test-B194BytesEqual $bytes ([IO.File]::ReadAllBytes($generator))) 'preserved generator changed bytes'
        Assert ($out -match 'CANT-VERIFY: previous framework-ownership\.json is missing') "missing previous manifest was not disclosed: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

# Regression guard. install.ps1 built the .sh twin's replacement only when the matching .ps1 was
# still in the incoming manifest, and the generic residual arm mapped any .sh to its .ps1. Retiring
# the .ps1 would therefore have silently dropped the .sh twin's migration message and, where one
# still appeared, aimed it at a file that is itself retired. Neither twin may name the other.
It 'neither retired generator twin is ever told to migrate to the other' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('arch-retire-twins-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        foreach ($leaf in @('build-architecture-html.ps1', 'build-architecture-html.sh')) {
            [IO.File]::WriteAllText((Join-Path $t "scripts/$leaf"), "# consumer copy`n", [Text.UTF8Encoding]::new($false))
        }
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "twin diagnostic update failed: $out"
        foreach ($leaf in @('build-architecture-html.ps1', 'build-architecture-html.sh')) {
            Assert (Test-Path -LiteralPath (Join-Path $t "scripts/$leaf") -PathType Leaf) "unknown $leaf bytes were deleted"
            Assert ($out -match "CANT-VERIFY: retained retired generator 'scripts/$([regex]::Escape($leaf))' remains") "retained $leaf was not diagnosed: $out"
        }
        Assert ($out -match 'read docs/ARCHITECTURE\.md directly') "no diagnostic named the canonical Markdown replacement: $out"
        Assert ($out -notmatch "migrate references to 'scripts/build-architecture-html\.ps1'") "a diagnostic directed the reader at the retired generator: $out"
        Assert ($out -notmatch "migrate references to 'the supported PowerShell surface'.*build-architecture") "a retired generator got the generic no-successor message: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'a retired path outside the hand-listed categories is still preserved and diagnosed' {
    # The residual gate used to admit only five categories, so anything retired later was preserved
    # in silence and each new retirement had to remember to add itself (B-240). A retired command is
    # none of those five: not a .github skill, sync script, Git-hook helper, v0.83 or the generator.
    $t = Join-Path ([IO.Path]::GetTempPath()) ('retired-uncategorised-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/commands') | Out-Null
        $retained = Join-Path $t '.claude/commands/impact.md'
        [IO.File]::WriteAllText($retained, "# my edited copy`n", [Text.UTF8Encoding]::new($false))
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "uncategorised retirement update failed: $out"
        Assert (Test-Path -LiteralPath $retained -PathType Leaf) 'consumer-modified retired command was deleted'
        Assert ($out -match "CANT-VERIFY: retained retired framework path '\.claude/commands/impact\.md' remains") "retained retired command was not diagnosed: $out"
        Assert ($out -match 'retired with no replacement command') "diagnostic did not say there is no successor: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'a retired .sh whose .ps1 twin is also retired still gets a migration replacement' {
    # The generic .sh arm built its entry only while the twin was still in the incoming manifest, so
    # a pair retired together produced no MIGRATION text at all. Drive the installer: asserting on
    # the ledger alone is inert, because the filter that picks the pair also guarantees the claim.
    $t = Join-Path ([IO.Path]::GetTempPath()) ('retired-twin-migration-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        # CLAUDE.md is consumer-owned/protected: it is not overwritten, so a stale command inside it
        # is exactly what the MIGRATION diagnostic exists to report.
        [IO.File]::WriteAllText((Join-Path $t 'CLAUDE.md'),
            "# Project`n`nRun ``bash scripts/impact-run.sh`` and ``bash scripts/sync-agent-files.sh`` nightly.`n",
            [Text.UTF8Encoding]::new($false))
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "retired-twin migration update failed: $out"
        foreach ($sh in @('scripts/impact-run.sh', 'scripts/sync-agent-files.sh')) {
            Assert ($out -match "MIGRATION: protected consumer carrier 'CLAUDE\.md' names retired framework path '$([regex]::Escape($sh))'") "no MIGRATION line for $sh : $out"
        }
        Assert ($out -match 'that feature is retired and has no replacement command; remove the reference') "the no-successor replacement text was not emitted: $out"
        Assert ($out -notmatch "replace that reference with: .*scripts/impact-run\.ps1") "a diagnostic directed the reader at the retired .ps1 twin: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}
$danglingLinkProbeRoot = Join-Path ([IO.Path]::GetTempPath()) ('retired-link-probe-' + [guid]::NewGuid())
$danglingFileLinksAvailable = $false
try {
    New-Item -ItemType Directory -Force -Path $danglingLinkProbeRoot | Out-Null
    $probeTarget = Join-Path $danglingLinkProbeRoot 'target.txt'
    $probeLink = Join-Path $danglingLinkProbeRoot 'link.txt'
    [IO.File]::WriteAllText($probeTarget, 'probe', [Text.UTF8Encoding]::new($false))
    New-Item -ItemType SymbolicLink -Path $probeLink -Target $probeTarget -ErrorAction Stop | Out-Null
    Remove-Item -LiteralPath $probeTarget -Force
    $danglingFileLinksAvailable = ($null -ne (Get-Item -Force -LiteralPath $probeLink -ErrorAction Stop)) -and -not (Test-Path -LiteralPath $probeLink)
} catch { $danglingFileLinksAvailable = $false }
finally { Remove-Item -LiteralPath $danglingLinkProbeRoot -Recurse -Force -ErrorAction SilentlyContinue }

if (-not $danglingFileLinksAvailable) {
    Skip 'a dangling retired-path reparse is CANT-VERIFY and never classified absent' 'host cannot construct an unprivileged dangling file symlink'
} else {
It 'a dangling retired-path reparse is CANT-VERIFY and never classified absent' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('retired-dangling-' + [guid]::NewGuid())
    $linkTarget = Join-Path ([IO.Path]::GetTempPath()) ('retired-link-target-' + [guid]::NewGuid())
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $t 'scripts') | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.82.0"}', [Text.UTF8Encoding]::new($false))
        $manifestBytes = Get-GitBlobBytes -Spec 'v0.82.0:dist/dotnet/framework-ownership.json'
        Assert ($manifestBytes.Count -gt 0) 'the v0.82.0 ownership manifest fixture is empty'
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), $manifestBytes)
        [IO.File]::WriteAllText($linkTarget, "retired target`n", [Text.UTF8Encoding]::new($false))
        $link = Join-Path $t 'scripts/wiki-check.sh'
        New-Item -ItemType SymbolicLink -Path $link -Target $linkTarget -ErrorAction Stop | Out-Null
        Remove-Item -LiteralPath $linkTarget -Force
        $entry = Get-Item -Force -LiteralPath $link -ErrorAction Stop
        Assert ($null -ne $entry -and -not (Test-Path -LiteralPath $link)) 'fixture does not distinguish Get-Item from Test-Path'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "installer failed instead of preserving dangling residue: $out"
        Assert ($out -match "CANT-VERIFY: retired path 'scripts/wiki-check\.sh' traverses reparse/symlink") "dangling retired link was not classified CANT-VERIFY: $out"
        Assert ($null -ne (Get-Item -Force -LiteralPath $link -ErrorAction Stop)) 'installer removed the dangling retired link'
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $linkTarget -Force -ErrorAction SilentlyContinue
    }
}
}

It 'licence and notice no longer ship: an update removes the unmodified notice and keeps an edited licence copy instead of refusing' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-legal-' + [guid]::NewGuid())
    try {
        # 0.96.0 stops shipping LICENSES/ai-tech-lead-MIT.txt and NOTICE-ai-tech-lead.md into consumer repositories.
        foreach ($stack in 'dotnet', 'angular', 'monorepo') {
            foreach ($rel in 'LICENSES/ai-tech-lead-MIT.txt', 'NOTICE-ai-tech-lead.md') {
                Assert (-not (Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/$rel"))) "$stack still ships $rel"
            }
        }
        $notice = Join-Path $t 'NOTICE-ai-tech-lead.md'
        $licence = Join-Path $t 'LICENSES/ai-tech-lead-MIT.txt'
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude'), (Split-Path -Parent $licence) | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.95.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.95.0:dist/dotnet/framework-ownership.json'))
        [IO.File]::WriteAllBytes($notice, (Get-GitBlobBytes -Spec 'v0.95.0:dist/dotnet/NOTICE-ai-tech-lead.md'))
        # The licence was consumer-owned: the team decides whether to keep it, even an edited copy.
        $licenceBytes = [Text.UTF8Encoding]::new($false).GetBytes("the team's own licence text`n")
        [IO.File]::WriteAllBytes($licence, $licenceBytes)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath $notice)) "the unmodified retired notice survived: $out"
        Assert (Test-B194BytesEqual $licenceBytes ([IO.File]::ReadAllBytes($licence))) "the team's licence copy was not kept byte-identical: $out"
        $manifest = Get-Content -Raw -LiteralPath (Join-Path $t 'framework-ownership.json') | ConvertFrom-Json
        $listed = @($manifest.paths | ForEach-Object path)
        Assert ($listed -notcontains 'NOTICE-ai-tech-lead.md' -and $listed -notcontains 'LICENSES/ai-tech-lead-MIT.txt') "the installed manifest still lists the licence or notice: $($listed -join ', ')"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}
It 'an edited notice stays after the update and is named as the team''s to keep, not as a file to remove' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-notice-' + [guid]::NewGuid())
    try {
        $notice = Join-Path $t 'NOTICE-ai-tech-lead.md'
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.95.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.95.0:dist/dotnet/framework-ownership.json'))
        $noticeBytes = (Get-GitBlobBytes -Spec 'v0.95.0:dist/dotnet/NOTICE-ai-tech-lead.md') + [Text.UTF8Encoding]::new($false).GetBytes("Also covers the team's vendored helpers.`n")
        [IO.File]::WriteAllBytes($notice, $noticeBytes)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (Test-B194BytesEqual $noticeBytes ([IO.File]::ReadAllBytes($notice))) "the edited notice was not kept byte-identical: $out"
        Assert ($flat -match "NOTICE: 'NOTICE-ai-tech-lead\.md' remains because it differs from every notice this framework shipped\. The framework no longer ships a notice; the file is yours to keep or delete\.") "the kept notice was not named as the team's to keep: $out"
        Assert ($flat -notmatch "'NOTICE-ai-tech-lead\.md' remains\. It is retired with no replacement command") "the kept notice got the generic remove-it advice: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Runs the installer with -Target quoted by hand so the child's own parser hands the installer
# exactly $Target, trailing backslash and all (a tab-completed folder name ends in one).
function Invoke-InstallerLiteralTarget {
    param([Parameter(Mandatory)][string]$Dist, [Parameter(Mandatory)][string]$Target)
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = (Get-PsExe)
    $quoted = '"' + $Target + $(if ($Target.EndsWith('\')) { '\' }) + '"'
    $start.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $repoRoot "dist/$Dist/scripts/install.ps1") + '" -Target ' + $quoted
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($start)
    $stderr = $process.StandardError.ReadToEndAsync()
    $stdout = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
    $global:LASTEXITCODE = $process.ExitCode
    return $stdout + $stderr.Result
}

It 'a Git target named with a space and passed with a trailing backslash updates to exit 0 on both hosts' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('trail-' + [guid]::NewGuid())
    try {
        $t = New-B309GitTarget -Root $root -Name 'My Repo' -Ignore "bin/`n"
        $first = Invoke-InstallerLiteralTarget -Dist 'dotnet' -Target ($t + '\')
        Assert ($LASTEXITCODE -eq 0 -and $first -match 'mode: greenfield') "the first install over '$t\' failed (exit $LASTEXITCODE): $first"
        & git -C $t add -A
        & git -C $t commit -qm 'framework install'
        $out = Invoke-InstallerLiteralTarget -Dist 'dotnet' -Target ($t + '\')
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: update') "the update over '$t\' did not reach mode: update with exit 0 (exit $LASTEXITCODE): $out"
        Assert ($out -notmatch 'CANT-VERIFY') "the update could not ask Git about '$t\': $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}
It 'a target below a junction, passed with a trailing backslash, installs; the walk stops at the target, not at the drive root' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('trailj-' + [guid]::NewGuid())
    $real = Join-Path $root 'real'
    $link = Join-Path $root 'link'
    try {
        [void][IO.Directory]::CreateDirectory((Join-Path $real 'sub'))
        & cmd /c "mklink /J `"$link`" `"$real`" >nul"
        Assert (Test-Path -LiteralPath $link) 'calibration: the junction was not created'
        $out = Invoke-InstallerLiteralTarget -Dist 'dotnet' -Target ((Join-Path $link 'sub') + '\')
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: greenfield') "a junction above the target refused the install (exit $LASTEXITCODE): $out"
    } finally {
        if (Test-Path -LiteralPath $link) { & cmd /c "rmdir `"$link`"" }
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'a target that is itself a junction is refused with exit 3 naming the link' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('junctgt-' + [guid]::NewGuid())
    $real = Join-Path $root 'real'
    $link = Join-Path $root 'link'
    try {
        [void][IO.Directory]::CreateDirectory($real)
        & cmd /c "mklink /J `"$link`" `"$real`" >nul"
        Assert (Test-Path -LiteralPath $link) 'calibration: the junction was not created'
        $out = Invoke-InstallerLiteralTarget -Dist 'dotnet' -Target $link
        Assert ($LASTEXITCODE -eq 3 -and $out -match "traverses reparse/symlink '[^']*link'") "an install into a junction was not refused at the link (exit $LASTEXITCODE): $out"
        Assert (@(Get-ChildItem -LiteralPath $real -Force).Count -eq 0) 'the install wrote through the junction'
    } finally {
        if (Test-Path -LiteralPath $link) { & cmd /c "rmdir `"$link`"" }
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# No test can give a folder the cloud-files attribute, so the predicate is taken from the installer's own AST.
It 'the installer predicate calls a reparse point with no link type a folder and a junction or symlink a link' {
    $script = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
    $ast = [Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$null)
    $fn = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-IsLinkEntry' }, $true)
    Assert ($null -ne $fn) 'the installer defines no Test-IsLinkEntry; any reparse point is treated as a link'
    $predicate = $fn.Body.GetScriptBlock()
    $dir = [IO.FileAttributes]'Directory, ReparsePoint'
    Assert (-not (& $predicate ([pscustomobject]@{ Attributes = $dir; LinkType = $null; Target = $null }))) 'a cloud-files folder (no LinkType, no Target) was called a link'
    Assert (-not (& $predicate ([pscustomobject]@{ Attributes = $dir; LinkType = ''; Target = @() }))) 'a cloud-files folder (empty LinkType, empty Target) was called a link'
    Assert (& $predicate ([pscustomobject]@{ Attributes = $dir; LinkType = 'Junction'; Target = @('C:\x') })) 'a junction was not called a link'
    Assert (& $predicate ([pscustomobject]@{ Attributes = $dir; LinkType = 'SymbolicLink'; Target = @('C:\x') })) 'a directory symlink was not called a link'
    Assert (& $predicate ([pscustomobject]@{ Attributes = $dir; LinkType = $null; Target = @('C:\x') })) 'a reparse point that reports a Target was not called a link'
    Assert (-not (& $predicate ([pscustomobject]@{ Attributes = [IO.FileAttributes]'Directory'; LinkType = 'Junction'; Target = @('C:\x') }))) 'an entry without the reparse attribute was called a link'
    Assert (-not (& $predicate $null)) 'a missing entry was called a link'
    $bare = @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.BinaryExpressionAst] -and $n.Operator -eq 'Band' -and $n.Extent.Text -match 'ReparsePoint' }, $true) |
        Where-Object { $_.Extent.StartOffset -lt $fn.Extent.StartOffset -or $_.Extent.StartOffset -ge $fn.Extent.EndOffset })
    Assert ($bare.Count -eq 0) "the installer still tests the reparse attribute alone at: $(($bare | ForEach-Object { $_.Extent.StartLineNumber }) -join ', ')"
}

It 'an update over a 0-byte LEARNINGS.md succeeds and disables no skill' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-emptylearn-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    try {
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the install failed (exit $LASTEXITCODE): $first"
        [IO.File]::WriteAllBytes((Join-Path $t 'LEARNINGS.md'), [byte[]]@())
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 0 -and $out -match '(?m)^\s*mode: update') "an update over an empty LEARNINGS.md did not succeed in update mode (exit $exit): $out"
        Assert ((Get-Item -LiteralPath (Join-Path $t 'LEARNINGS.md')).Length -eq 0) 'the empty LEARNINGS.md was changed'
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# A Windows clone with core.autocrlf=true checks SKILL.md out with CRLF; the exemplar line captured from it
# must not carry its CR into the rewritten file, which is LF throughout and ends in exactly one LF.
It 'a CRLF SKILL.md has its exemplar re-appended without a carriage return' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-crlfexemplar-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    try {
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the install failed (exit $LASTEXITCODE): $first"
        $skill = Join-Path $t '.claude/skills/add-warehouse-load/SKILL.md'
        $exemplar = 'For a concrete current instance in this repo, see `warehouse/LoadSales.sql`.'
        $crlf = ([IO.File]::ReadAllText($skill, [Text.UTF8Encoding]::new($false)).TrimEnd() + "`n`n" + $exemplar + "`n") -replace "`r?`n", "`r`n"
        [IO.File]::WriteAllText($skill, $crlf, [Text.UTF8Encoding]::new($false))
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 0 -and $out -match '(?m)^\s*mode: update') "the update did not succeed in update mode (exit $exit): $out"
        $bytes = [IO.File]::ReadAllBytes($skill)
        $text = [Text.UTF8Encoding]::new($false).GetString($bytes)
        Assert ($text.Contains($exemplar)) 'the exemplar line was not re-appended'
        Assert (-not $text.Contains("`r")) "the rewritten SKILL.md still holds a carriage return (last bytes: $($bytes[($bytes.Length - 4)..($bytes.Length - 1)] -join ','))"
        Assert ($text.EndsWith($exemplar + "`n", [StringComparison]::Ordinal)) 'the rewritten SKILL.md does not end in the exemplar and exactly one LF'
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-464 C5: the version stamp is the 34th of 101 copies, so a file held open later in the manifest stopped the update
# with a raw Copy-Item error after the stamp already named the new release, and the re-run was refused as a dirty tree.
It 'C5 an update stopped by a held file keeps the old version stamp and prints the re-run command' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-c5-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    $handle = $null
    try {
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "calibration: the install failed (exit $LASTEXITCODE): $first"
        $stamp = Join-Path $t '.claude/framework-version.json'
        $newVersion = [string](Get-Content -Raw -LiteralPath $stamp | ConvertFrom-Json).version
        [IO.File]::WriteAllText($stamp, ([IO.File]::ReadAllText($stamp) -replace '"version":\s*"[^"]*"', "`"version`": `"$staleVersion`""), [Text.UTF8Encoding]::new($false))
        $held = Join-Path $t 'scripts/template-checks.ps1'
        $handle = [IO.File]::Open($held, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        $flat = $out -replace '\s+', ' '
        Assert ($exit -eq 3) "the update stopped by a held file did not exit 3 (exit $exit): $out"
        Assert ([string](Get-Content -Raw -LiteralPath $stamp | ConvertFrom-Json).version -ceq $staleVersion) "the stopped update already wrote the new version stamp: $out"
        Assert ($flat -match "Could not copy 'scripts/template-checks\.ps1'" -and $flat -match '[0-9]+ of [0-9]+ framework files' -and $flat -match 'install\.ps1[^ ]* -AllowDirtyTree ') "the stop did not name the file, the count written and the re-run command with -AllowDirtyTree: $out"
        $handle.Dispose(); $handle = $null
        $rerun = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the re-run did not finish the update (exit $LASTEXITCODE): $rerun"
        Assert ([string](Get-Content -Raw -LiteralPath $stamp | ConvertFrom-Json).version -ceq $newVersion) "the re-run did not write the new version stamp: $rerun"
    } finally {
        if ($handle) { $handle.Dispose() }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-464 C7: a mistyped -Stack on an update switched the install to the other stack's release and left the old stack's
# skills live and unowned. The root dispatcher forwarded the override; the stack installer never compared the two stamps.
function Get-TreeSnapshot {
    param([string]$Root)
    return (@(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Sort-Object FullName | ForEach-Object { $_.FullName.Substring($Root.Length) + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }) -join "`n")
}
function Invoke-RootInstallerFor {
    param([string]$Target, [string[]]$Extra = @())
    $out = & (Get-PsExe) -NoProfile -File (Join-Path $repoRoot 'install.ps1') @Extra $Target 2>&1 | Out-String
    return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Output = $out }
}
It 'C7 an update with another -Stack is refused and changes nothing' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-c7a-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    try {
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "calibration: the dotnet install failed (exit $LASTEXITCODE): $first"
        $before = Get-TreeSnapshot -Root $t
        $result = Invoke-RootInstallerFor -Target $t -Extra @('-Stack', 'angular')
        $flat = $result.Output -replace '\s+', ' '
        Assert ($result.Exit -ne 0) "an update naming another stack was not refused (exit $($result.Exit)): $($result.Output)"
        Assert ((Get-TreeSnapshot -Root $t) -ceq $before) "the refused stack change still changed the target: $($result.Output)"
        Assert ([string](Get-Content -Raw -LiteralPath (Join-Path $t '.claude/framework-version.json') | ConvertFrom-Json).template -ceq 'dotnet') 'the stamp no longer names dotnet'
        Assert ($flat -match 'dotnet to angular' -and $flat -match '-AllowStackChange') "the refusal does not name both stacks and -AllowStackChange: $($result.Output)"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}
It 'C7 -AllowStackChange applies the other stack and names each previously owned path it drops, keeping those files' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-c7b-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    try {
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "calibration: the dotnet install failed (exit $LASTEXITCODE): $first"
        $perf = Join-Path $t '.claude/skills/perf/SKILL.md'
        Assert (Test-Path -LiteralPath $perf -PathType Leaf) 'calibration: the dotnet install has no perf skill'
        $result = Invoke-RootInstallerFor -Target $t -Extra @('-Stack', 'angular', '-AllowStackChange')
        $flat = $result.Output -replace '\s+', ' '
        Assert ($result.Exit -eq 0) "the deliberate stack change failed (exit $($result.Exit)): $($result.Output)"
        Assert ([string](Get-Content -Raw -LiteralPath (Join-Path $t '.claude/framework-version.json') | ConvertFrom-Json).template -ceq 'angular') 'the stamp does not name angular'
        Assert ($flat -match 'NOTICE: [^|]*dotnet to angular[^|]*\.claude/skills/perf/SKILL\.md') "no NOTICE names the dropped perf skill: $($result.Output)"
        Assert (Test-Path -LiteralPath $perf -PathType Leaf) 'the stack change deleted a dropped file'
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-464 C8: -WhatIf skipped the Git preflight, so a dry run on a tree the real run refuses ended "Dry run complete".
It 'C8 a dry run on a dirty Git tree names the refusal the real run makes and does not exit 0' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('upd-c8-' + [guid]::NewGuid())
    try {
        $t = New-B309GitTarget -Root $root -Name 'repo' -Ignore "bin/`n"
        [IO.File]::WriteAllText((Join-Path $t 'App.csproj'), '<Project Sdk="Microsoft.NET.Sdk" />', [Text.UTF8Encoding]::new($false))
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "calibration: the install failed (exit $LASTEXITCODE): $first"
        & git -C $t add -A -f 2>&1 | Out-Null
        & git -C $t commit -qm install 2>&1 | Out-Null
        $installer = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
        $clean = & (Get-PsExe) -NoProfile -File $installer -Target $t -WhatIf 2>&1 | Out-String
        Assert ($LASTEXITCODE -eq 0 -and $clean -match 'Dry run complete') "calibration: a dry run on a clean tree did not complete (exit $LASTEXITCODE): $clean"
        [IO.File]::AppendAllText((Join-Path $t 'App.csproj'), "<!-- edited -->`n")
        $dry = & (Get-PsExe) -NoProfile -File $installer -Target $t -WhatIf 2>&1 | Out-String
        $dryExit = $LASTEXITCODE
        $real = & (Get-PsExe) -NoProfile -File $installer -Target $t 2>&1 | Out-String
        $realExit = $LASTEXITCODE
        Assert ($realExit -eq 4 -and $real -match 'Refusing to mutate a dirty Git target') "calibration: the real run did not refuse the dirty tree (exit $realExit): $real"
        Assert ($dryExit -eq 4 -and ($dry -replace '\s+', ' ') -match 'dry run: the real run would refuse: ERROR: Refusing to mutate a dirty Git target') "the dry run did not exit 4 naming the refusal (exit $dryExit): $dry"
        Assert ($dry -notmatch 'Dry run complete') "the dry run still ends as complete: $dry"
        $allowed = & (Get-PsExe) -NoProfile -File $installer -Target $t -WhatIf -AllowDirtyTree 2>&1 | Out-String
        Assert ($LASTEXITCODE -eq 0 -and $allowed -match 'Dry run complete') "a dry run with -AllowDirtyTree did not complete (exit $LASTEXITCODE): $allowed"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-464 D1: a greenfield install stopped late must leave the version stamp where the manifest puts it. Without it the
# re-run read the files already copied as existing AI tooling and archived 93 of the framework's own files as a brownfield install.
It 'D1 a greenfield install stopped by a denied late folder is an update on the re-run, with nothing archived' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-d1-' + [guid]::NewGuid())
    $specs = Join-Path $t 'specs'
    New-Item -ItemType Directory -Force -Path $specs | Out-Null
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $denied = $false
    try {
        & icacls $specs /deny "*${sid}:(WD,AD)" | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: icacls could not deny writes in specs'
        $denied = $true
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 3 -and $out -match 'mode: greenfield') "calibration: the install was not stopped by the denied folder (exit $exit): $out"
        & icacls $specs /remove:d "*$sid" | Out-Null
        $denied = $false
        $rerun = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $rerun -match '(?m)^\s*mode: update') "the re-run did not finish as an update (exit $LASTEXITCODE): $rerun"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t 'docs/pre-adoption'))) 'the re-run archived framework files into docs/pre-adoption'
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/adoption-pending.json'))) 'the re-run wrote an adoption marker'
    } finally {
        if ($denied) { & icacls $specs /remove:d "*$sid" | Out-Null }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-464 D2: the re-run line printed for a stopped update must carry each override the stopped run was given, or it exits 4.
It 'D2 the re-run line of an update stopped by a held file carries the override flags it was given' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-d2-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    $handle = $null
    try {
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "calibration: the install failed (exit $LASTEXITCODE): $first"
        $stamp = Join-Path $t '.claude/framework-version.json'
        $text = [IO.File]::ReadAllText($stamp) -replace '"version":\s*"[^"]*"', '"version": "99.0.0"' -replace '"template":\s*"[^"]*"', '"template": "angular"'
        [IO.File]::WriteAllText($stamp, $text, [Text.UTF8Encoding]::new($false))
        $handle = [IO.File]::Open((Join-Path $t 'scripts/template-checks.ps1'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
        $out = & (Get-PsExe) -NoProfile -File (Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1') -Target $t -AllowDowngrade -AllowStackChange -AllowOutdated 2>&1 | Out-String
        $exit = $LASTEXITCODE
        $flat = $out -replace '\s+', ' '
        Assert ($exit -eq 3) "calibration: the stopped update did not exit 3 (exit $exit): $out"
        foreach ($flag in '-AllowDirtyTree', '-AllowDowngrade', '-AllowStackChange', '-AllowOutdated') {
            Assert ($flat -match "install\.ps1' [^']*$flag") "the printed re-run line does not carry $flag : $out"
        }
    } finally {
        if ($handle) { $handle.Dispose() }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}
# -Reinstall: delete the old framework surface of an install older than the retirement-ledger floor and install fresh.
# The fixture is a real v0.26.0 install (built from the local tag), committed to Git, plus consumer-owned files.
function New-ReinstallFixture {
    $target = Join-Path ([IO.Path]::GetTempPath()) ('reinst-' + [guid]::NewGuid().ToString('N'))
    $stage = Join-Path ([IO.Path]::GetTempPath()) ('reinst-stage-' + [guid]::NewGuid().ToString('N'))
    $archive = Join-Path ([IO.Path]::GetTempPath()) ('reinst-' + [guid]::NewGuid().ToString('N') + '.tar')
    New-Item -ItemType Directory -Force -Path $target, $stage | Out-Null
    try {
        & git -C $repoRoot archive --format=tar "--output=$archive" v0.26.0 dist/dotnet 2>&1 | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: could not archive v0.26.0 dist/dotnet'
        # Prefer the Windows tar: a GNU tar earlier on PATH reads 'C:' as a remote host.
        $tarExe = Join-Path $env:SystemRoot 'System32/tar.exe'
        if (-not (Test-Path -LiteralPath $tarExe)) { $tarExe = 'tar' }
        & $tarExe -xf $archive -C $stage 2>&1 | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: could not extract the v0.26.0 archive'
        $src = (Join-Path $stage 'dist/dotnet')
        $skip = @('.template-repo', 'README.md', 'CHANGELOG.md', '.gitignore', '.gitattributes', 'scripts/install.ps1', '.github/workflows/template-ci.yml')
        $oldHooks = [System.Collections.Generic.List[string]]::new()
        foreach ($f in Get-ChildItem -LiteralPath $src -Recurse -Force -File) {
            $rel = $f.FullName.Substring($src.Length).TrimStart('\', '/').Replace('\', '/')
            if ($skip -contains $rel) { continue }
            if ($rel.StartsWith('.claude/hooks/')) { $oldHooks.Add($rel) }
            $dest = Join-Path $target $rel
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
        }
        $enc = [Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText((Join-Path $target '.claude/hooks/team-hook.ps1'), "# consumer-added hook`n", $enc)
        New-Item -ItemType Directory -Force -Path (Join-Path $target 'scripts') | Out-Null
        [IO.File]::WriteAllBytes((Join-Path $target 'scripts/consumer-tool.ps1'), [byte[]](0x23, 0x20, 0x63, 0x6F, 0x6E, 0x73, 0x75, 0x6D, 0x65, 0x72, 0x00, 0xFE, 0x0D, 0x0A, 0x7F, 0x31, 0x0A))
        [IO.File]::AppendAllText((Join-Path $target 'CLAUDE.md'), "`nCONSUMER SENTINEL 7f3a`n", $enc)
        [IO.File]::WriteAllText((Join-Path $target '.gitignore'), "/.claude/settings.local.json`n", $enc)
        [IO.File]::WriteAllBytes((Join-Path $target '.claude/settings.local.json'), [byte[]](0x7B, 0x22, 0x6C, 0x6F, 0x63, 0x61, 0x6C, 0x22, 0x3A, 0x31, 0x39, 0x37, 0x31, 0x7D, 0x0A))
        & git -C $target init -q 2>&1 | Out-Null
        & git -C $target config user.email 'fixture@example.test'
        & git -C $target config user.name 'Fixture'
        & git -C $target config core.autocrlf false
        & git -C $target add -A 2>&1 | Out-Null
        & git -C $target commit -qm fixture 2>&1 | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: could not commit the reinstall fixture'
        $head = (& git -C $target rev-parse HEAD).Trim()
        return [pscustomobject]@{ Path = $target; Head = $head; OldHooks = $oldHooks.ToArray() }
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $stage -ErrorAction SilentlyContinue
        Remove-Item -Force -LiteralPath $archive -ErrorAction SilentlyContinue
    }
}

# "<relative path>`t<sha256>" for every file outside .git, then HEAD, then the porcelain status.
function Get-ReinstallFingerprint {
    param([string]$Target)
    $lines = foreach ($f in Get-ChildItem -LiteralPath $Target -Recurse -Force -File -ErrorAction SilentlyContinue) {
        $rel = $f.FullName.Substring($Target.Length).TrimStart('\', '/').Replace('\', '/')
        if ($rel -eq '.git' -or $rel.StartsWith('.git/')) { continue }
        "$rel`t$((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash)"
    }
    $head = (& git -C $Target rev-parse HEAD 2>&1 | Out-String).Trim()
    $status = (& git -C $Target status --porcelain --untracked-files=all 2>&1 | Out-String)
    $sorted = [string[]]@($lines)
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    return (($sorted -join "`n") + "`nHEAD $head`n" + $status)
}

# Runs the built dotnet installer with exactly these switches; returns exit code and combined output.
function Invoke-ReinstallInstaller {
    param([string]$Target, [string[]]$Switches = @())
    $installer = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
    $out = & (Get-PsExe) -NoProfile -File $installer -Target $Target @Switches 2>&1 | Out-String
    return [pscustomobject]@{ Exit = $LASTEXITCODE; Out = $out }
}

function Remove-ReinstallTemp {
    param([string[]]$Paths)
    foreach ($p in $Paths) {
        if (-not $p -or -not (Test-Path -LiteralPath $p)) { continue }
        # Junctions are detached without recursing through them.
        foreach ($d in Get-ChildItem -LiteralPath $p -Recurse -Force -Directory -ErrorAction SilentlyContinue) {
            if ($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { try { [IO.Directory]::Delete($d.FullName, $false) } catch { } }
        }
        Remove-Item -Recurse -Force -LiteralPath $p -ErrorAction SilentlyContinue
    }
}

if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
    Skip 'reinstall: -Reinstall behaviour' 'git is unavailable'
} else {
    It 'reinstall: a plain update from below the retirement-ledger floor refuses before mutation and names -Reinstall' {
        $fx = New-ReinstallFixture
        try {
            $before = Get-ReinstallFingerprint $fx.Path
            $r = Invoke-ReinstallInstaller -Target $fx.Path
            Assert ($r.Exit -eq 4) "expected exit 4 from a plain update below the ledger floor, got $($r.Exit): $($r.Out)"
            Assert ($r.Out -match '-Reinstall') "the refusal does not name -Reinstall: $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $fx.Path)) "the refused update changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: -Reinstall deletes the old framework surface and keeps consumer files' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            $toolBefore = [IO.File]::ReadAllBytes((Join-Path $t 'scripts/consumer-tool.ps1'))
            $localBefore = [IO.File]::ReadAllBytes((Join-Path $t '.claude/settings.local.json'))
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            $o = $r.Out
            Assert ($r.Exit -eq 0) "expected exit 0 from -Reinstall, got $($r.Exit): $o"
            Assert-BytesEqual $toolBefore ([IO.File]::ReadAllBytes((Join-Path $t 'scripts/consumer-tool.ps1'))) "scripts/consumer-tool.ps1 bytes changed: $o"
            Assert-BytesEqual $localBefore ([IO.File]::ReadAllBytes((Join-Path $t '.claude/settings.local.json'))) ".claude/settings.local.json bytes changed: $o"
            $text = ''
            foreach ($n in 'AGENTS.md', 'CLAUDE.md') { $p = Join-Path $t $n; if (Test-Path -LiteralPath $p) { $text += [IO.File]::ReadAllText($p) } }
            Assert ($text -match 'CONSUMER SENTINEL 7f3a') "the project text did not survive into AGENTS.md or CLAUDE.md: $o"
            Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/hooks/team-hook.ps1'))) ".claude/hooks/team-hook.ps1 was not deleted: $o"
            $owned = @((Get-Content -LiteralPath (Join-Path $repoRoot 'dist/dotnet/framework-ownership.json') -Raw | ConvertFrom-Json).paths | ForEach-Object { $_.path })
            foreach ($h in $fx.OldHooks) {
                if ($owned -contains $h) { continue }
                Assert (-not (Test-Path -LiteralPath (Join-Path $t $h))) "$h is a v0.26.0 hook this release does not ship, but it is still present: $o"
            }
            $stamp = Get-Content -LiteralPath (Join-Path $t '.claude/framework-version.json') -Raw | ConvertFrom-Json
            $want = (Get-Content -LiteralPath (Join-Path $repoRoot 'dist/dotnet/.claude/framework-version.json') -Raw | ConvertFrom-Json).version
            Assert ($stamp.version -eq $want) "stamp version is $($stamp.version), expected $want : $o"
            Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/framework-update-backup'))) "a .claude/framework-update-backup folder was written: $o"
            Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/.state/settings.json.pre-update'))) "a settings.json.pre-update backup was written: $o"
            foreach ($p in $owned) {
                Assert (Test-Path -LiteralPath (Join-Path $t $p)) "owned path $p is missing after the reinstall: $o"
            }
            Assert ($o.Contains("git show $($fx.Head):.claude/settings.json")) "the output does not give 'git show $($fx.Head):.claude/settings.json': $o"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: -Reinstall with -AllowDirtyTree refuses before mutation' {
        $fx = New-ReinstallFixture
        try {
            $before = Get-ReinstallFingerprint $fx.Path
            $r = Invoke-ReinstallInstaller -Target $fx.Path -Switches @('-Reinstall', '-AllowDirtyTree')
            Assert ($r.Exit -eq 4) "expected exit 4 from -Reinstall -AllowDirtyTree, got $($r.Exit): $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $fx.Path)) "the refused run changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: -Reinstall on a dirty tree refuses before mutation' {
        $fx = New-ReinstallFixture
        try {
            [IO.File]::AppendAllText((Join-Path $fx.Path 'scripts/consumer-tool.ps1'), "# uncommitted edit`n")
            $before = Get-ReinstallFingerprint $fx.Path
            $r = Invoke-ReinstallInstaller -Target $fx.Path -Switches @('-Reinstall')
            Assert ($r.Exit -eq 4) "expected exit 4 from -Reinstall on a dirty tree, got $($r.Exit): $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $fx.Path)) "the refused run changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: -WhatIf -Reinstall lists the deletions and changes nothing' {
        $fx = New-ReinstallFixture
        try {
            $before = Get-ReinstallFingerprint $fx.Path
            $r = Invoke-ReinstallInstaller -Target $fx.Path -Switches @('-WhatIf', '-Reinstall')
            Assert ($r.Exit -eq 0) "expected exit 0 from -WhatIf -Reinstall, got $($r.Exit): $($r.Out)"
            Assert ($r.Out -match 'PLAN delete \.claude/hooks/team-hook\.ps1') "the plan does not list 'PLAN delete .claude/hooks/team-hook.ps1': $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $fx.Path)) "-WhatIf changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: -Reinstall outside update mode refuses and creates nothing' {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('reinst-empty-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $t | Out-Null
        try {
            [IO.File]::WriteAllText((Join-Path $t 'README.md'), "# readme`n", [Text.UTF8Encoding]::new($false))
            & git -C $t init -q 2>&1 | Out-Null
            & git -C $t config user.email 'fixture@example.test'
            & git -C $t config user.name 'Fixture'
            & git -C $t add -A 2>&1 | Out-Null
            & git -C $t commit -qm readme 2>&1 | Out-Null
            $before = Get-ReinstallFingerprint $t
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            Assert ($r.Exit -eq 4) "expected exit 4 from -Reinstall on a target with no install, got $($r.Exit): $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $t)) "the refused run created or changed files: $($r.Out)"
        } finally { Remove-ReinstallTemp @($t) }
    }

    It 'reinstall: a skip-worktree file in the sweep refuses before mutation' {
        $fx = New-ReinstallFixture
        try {
            & git -C $fx.Path update-index --skip-worktree -- .claude/settings.json 2>&1 | Out-Null
            Assert ($LASTEXITCODE -eq 0) 'calibration: could not set skip-worktree'
            [IO.File]::AppendAllText((Join-Path $fx.Path '.claude/settings.json'), "`n")
            $before = Get-ReinstallFingerprint $fx.Path
            $r = Invoke-ReinstallInstaller -Target $fx.Path -Switches @('-Reinstall')
            Assert ($r.Exit -eq 4) "expected exit 4 with a skip-worktree file in the sweep, got $($r.Exit): $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $fx.Path)) "the refused run changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: an ignored file at a shipped path refuses, since no commit holds what the copy would overwrite' {
        $fx = New-ReinstallFixture
        try {
            $rel = '.github/instructions/framework-rules.instructions.md'
            [IO.File]::AppendAllText((Join-Path $fx.Path '.gitignore'), "/$rel`n")
            & git -C $fx.Path add -A 2>&1 | Out-Null
            & git -C $fx.Path commit -qm ignore-rules 2>&1 | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $fx.Path '.github/instructions') | Out-Null
            [IO.File]::WriteAllText((Join-Path $fx.Path $rel), "# a developer's own rules, in no commit`n", [Text.UTF8Encoding]::new($false))
            Assert ((& git -C $fx.Path status --porcelain --untracked-files=all | Out-String).Trim().Length -eq 0) 'calibration: the ignored file shows in git status'
            $before = Get-ReinstallFingerprint $fx.Path
            $r = Invoke-ReinstallInstaller -Target $fx.Path -Switches @('-Reinstall')
            Assert ($r.Exit -eq 4) "expected exit 4 with an ignored file at a shipped path, got $($r.Exit): $($r.Out)"
            Assert ($r.Out.Contains($rel)) "the refusal does not name $rel : $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $fx.Path)) "the refused run changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    # Found by the fresh-session attack: a clean status was taken as proof that the commit holds a file's bytes.
    It 'reinstall: a file a clean filter keeps partly out of Git refuses, though git status is clean' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            & git -C $t config filter.strip.clean 'sed /LOCALONLY/d'
            & git -C $t config filter.strip.smudge 'cat'
            [IO.File]::WriteAllText((Join-Path $t '.gitattributes'), ".claude/rules/*.md filter=strip`n", [Text.UTF8Encoding]::new($false))
            New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/rules') | Out-Null
            [IO.File]::WriteAllText((Join-Path $t '.claude/rules/env.md'), "shared`n", [Text.UTF8Encoding]::new($false))
            & git -C $t add -A 2>&1 | Out-Null
            & git -C $t commit -qm filtered 2>&1 | Out-Null
            [IO.File]::AppendAllText((Join-Path $t '.claude/rules/env.md'), "LOCALONLY token=abc123`n")
            & git -C $t add -A 2>&1 | Out-Null
            Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim().Length -eq 0) 'calibration: the filtered edit shows in git status'
            $before = Get-ReinstallFingerprint $t
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            Assert ($r.Exit -eq 4) "expected exit 4 for a file whose disk bytes the commit does not hold, got $($r.Exit): $($r.Out)"
            Assert ($r.Out.Contains('.claude/rules/env.md')) "the refusal does not name .claude/rules/env.md: $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $t)) "the refused run changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: a same-size edit Git has not noticed refuses, though git status is clean' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            $note = Join-Path $t '.claude/rules/team-notes.md'
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $note) | Out-Null
            [IO.File]::WriteAllText($note, "budget: AAAAAAAA`n", [Text.UTF8Encoding]::new($false))
            $stamp = [DateTime]::UtcNow.AddMinutes(-10)
            [IO.File]::SetLastWriteTimeUtc($note, $stamp)
            & git -C $t add -A 2>&1 | Out-Null
            & git -C $t commit -qm notes 2>&1 | Out-Null
            & git -C $t update-index --really-refresh 2>&1 | Out-Null
            [IO.File]::WriteAllText($note, "budget: SECRET99`n", [Text.UTF8Encoding]::new($false))
            [IO.File]::SetLastWriteTimeUtc($note, $stamp)
            Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim().Length -eq 0) 'calibration: Git noticed the same-size edit'
            $before = Get-ReinstallFingerprint $t
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            Assert ($r.Exit -eq 4) "expected exit 4 for an edit Git has not noticed, got $($r.Exit): $($r.Out)"
            Assert ([IO.File]::ReadAllText($note) -ceq "budget: SECRET99`n") "the unnoticed edit was lost: $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $t)) "the refused run changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: a junction below .claude is neither followed nor emptied' {
        $fx = New-ReinstallFixture
        $outside = Join-Path ([IO.Path]::GetTempPath()) ('reinst-outside-' + [guid]::NewGuid().ToString('N'))
        $link = Join-Path $fx.Path '.claude/linked'
        try {
            New-Item -ItemType Directory -Force -Path $outside | Out-Null
            $payload = [byte[]](0x6F, 0x75, 0x74, 0x00, 0x01, 0x0A)
            [IO.File]::WriteAllBytes((Join-Path $outside 'outside.txt'), $payload)
            [IO.File]::AppendAllText((Join-Path $fx.Path '.gitignore'), "/.claude/linked`n")
            & git -C $fx.Path add -A 2>&1 | Out-Null
            & git -C $fx.Path commit -qm ignore-link 2>&1 | Out-Null
            New-Item -ItemType Junction -Path $link -Target $outside | Out-Null
            Assert (Test-Path -LiteralPath (Join-Path $link 'outside.txt')) 'calibration: the junction does not expose outside.txt'
            $r = Invoke-ReinstallInstaller -Target $fx.Path -Switches @('-Reinstall')
            Assert ($r.Exit -eq 0) "expected exit 0 from -Reinstall beside an ignored junction, got $($r.Exit): $($r.Out)"
            Assert (Test-Path -LiteralPath (Join-Path $outside 'outside.txt')) "outside.txt was deleted through the junction: $($r.Out)"
            Assert-BytesEqual $payload ([IO.File]::ReadAllBytes((Join-Path $outside 'outside.txt'))) "outside.txt bytes changed: $($r.Out)"
            Assert (Test-Path -LiteralPath $link) "the junction itself was removed: $($r.Out)"
        } finally {
            if (Test-Path -LiteralPath $link) { try { [IO.Directory]::Delete($link, $false) } catch { } }
            Remove-ReinstallTemp @($fx.Path, $outside)
        }
    }
}
exit (Write-TestSummary 'UpdateDelivery.Tests')
