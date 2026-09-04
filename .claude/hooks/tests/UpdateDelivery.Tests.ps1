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

$carrierRel = '.github/instructions/framework-rules.instructions.md'
$importLine = '@.github/instructions/framework-rules.instructions.md'
$staleVersion = '0.40.0'
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
    Set-Content (Join-Path $t 'AGENTS.md') "# AGENTS`n`nGENERATED FILE`n" -Encoding utf8
    Set-Content (Join-Path $t '.claude/framework-version.json') "{`"version`": `"$staleVersion`"}" -Encoding utf8
    Set-Content (Join-Path $t '.claude/settings.json') "{`n  `"consumerEdit`": `"recover me`"`n}`n" -Encoding utf8
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/skills/add-warehouse-load') | Out-Null
    Set-Content (Join-Path $t '.claude/skills/add-warehouse-load/SKILL.md') "---`nname: add-warehouse-load`n---`n# Old framework body`n`nFor a concrete current instance in this repo, see ``warehouse/LoadSales.sql`` — reproduce its **conventions and structure**, not its contents; CLAUDE.md > Conventions wins on any conflict.`n" -Encoding utf8
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/skills/local-release') | Out-Null
    Set-Content (Join-Path $t '.claude/skills/local-release/SKILL.md') "---`nname: local-release`norigin: discovered`n---`n# Consumer recipe`n" -Encoding utf8
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
        $controlledPath = [string]$isolated['B194_PS_PATH']
        $isolated.Remove('B194_PS_PATH')
        $path64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($controlledPath))
        $installer64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($installer))
        $target64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Target))
        $command = "`$env:PATH=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$path64'));`$installer=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$installer64'));`$target=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$target64'));& `$installer -Target `$target;`$code=`$LASTEXITCODE;if(`$code -in @(2,3,4)){exit `$code};exit 0"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
        return Invoke-B194Process -Executable $PowerShellExe -Arguments @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded
        ) -Environment $isolated
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
    [IO.File]::WriteAllText((Join-Path $target 'CLAUDE.md'), "B194 PROTECTED UPDATE SENTINEL`n", [Text.UTF8Encoding]::new($false))
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
    $carrierPath = Join-Path $target $carrierRel
    $adrPath = Join-Path $target 'docs/architecture-decisions.md'
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $adrPath) | Out-Null
    [IO.File]::WriteAllText($adrPath, "# Architecture Decisions`n`n## ADR-042: Consumer sentinel`n- **Decision**: preserve these bytes.`n", [Text.UTF8Encoding]::new($false))

    $before = Get-Hash $claudePath
    $adrBefore = [IO.File]::ReadAllBytes($adrPath)
    $learningsPath = Join-Path $target 'LEARNINGS.md'
    $learningsBefore = [IO.File]::ReadAllBytes($learningsPath)
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
        Assert-BytesEqual -Expected $adrBefore -Actual ([IO.File]::ReadAllBytes($adrPath)) -Message 'update mode replaced the consumer append-only ADR log'
        Assert-BytesEqual -Expected $learningsExpectedBytes -Actual $learningsBefore -Message 'disabled-skill fixture was not exact BOM + HT + CRLF input'
        Assert-BytesEqual -Expected $learningsBefore -Actual ([IO.File]::ReadAllBytes($learningsPath)) -Message 'update mode modified the protected disabled-skill ledger'
        Assert ($out -match '(?m)^PLAN preserve docs/architecture-decisions\.md\r?$') "update operation plan did not classify the consumer ADR log as preserved. Output:`n$out"
    }

    It "update delivers the unprotected carrier ($powerShellExtension)" {
        Assert (Test-Path -LiteralPath $carrierPath) "carrier $carrierRel was not installed"
        $shipped = Get-Hash (Join-Path $repoRoot "dist/$dist/$carrierRel")
        Assert ((Get-Hash $carrierPath) -eq $shipped) 'installed carrier does not match the shipped one'
    }

    It "update refreshes framework skills while preserving consumer ownership ($powerShellExtension)" {
        $warehouse = Get-Content (Join-Path $target '.claude/skills/add-warehouse-load/SKILL.md') -Raw
        Assert ($warehouse -match 'Bind to the dimensions that already exist') 'the current framework body was not delivered'
        Assert ($warehouse -match 'warehouse/LoadSales.sql') 'the consumer exemplar was lost'
        Assert ((Get-Content (Join-Path $target '.claude/skills/local-release/SKILL.md') -Raw) -match 'Consumer recipe') 'origin: discovered skill was overwritten'
        Assert (-not (Test-Path (Join-Path $target '.claude/skills/perf'))) 'disabled framework skill was reactivated'
        Assert (Test-Path (Join-Path $target '.claude/disabled-skills/perf/SKILL.md')) 'disabled framework skill was not refreshed in its inactive location'
        Assert (Test-Path (Join-Path $target '.claude/framework-update-backup/skills')) 'one-time pre-update skill archive was not created'
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
    foreach ($rel in @('.claude/commands', '.github/hooks', '.github/skills/local-only', '.github/skills/perf', '.github/skills/add-tests')) {
        New-Item -ItemType Directory -Force -Path (Join-Path $t $rel) | Out-Null
    }
    Set-Content -LiteralPath (Join-Path $t 'TECH_DEBT.md') -Value 'BROWNFIELD SIGNAL' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $t '.claude/settings.json') -Value 'SETTINGS SENTINEL' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $t '.github/hooks/hooks.json') -Value 'HOOKS SENTINEL' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $t '.claude/commands/feature.md') -Value 'COMMAND SENTINEL' -Encoding utf8
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
        $githubSkillsBefore = @{}
        foreach ($relative in @('.github/skills/local-only/SKILL.md', '.github/skills/local-only/reference.md', '.github/skills/perf/SKILL.md', '.github/skills/add-tests/SKILL.md')) {
            $githubSkillsBefore[$relative] = [IO.File]::ReadAllBytes((Join-Path $t $relative))
        }
        try {
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
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
        $skillRel = '.claude/skills/add-endpoint/SKILL.md'
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
            Set-Content -LiteralPath (Join-Path $t '.claude/framework-version.json') -Value '{"version":"0.72.0"}' -Encoding utf8
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
            Assert ($LASTEXITCODE -eq 0 -and $override -match 'override: .*allow-dirty-tree') "dirty override failed: $override"
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
            Assert ($LASTEXITCODE -eq 0 -and $override -match 'override: .*allow-dirty-tree') "brownfield override failed: $override"
            Assert (Test-Path -LiteralPath (Join-Path $t 'docs/pre-adoption/TECH_DEBT.md') -PathType Leaf) 'brownfield override did not archive the collision'
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }
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
        Assert (@([regex]::Matches($out, "CANT-VERIFY: retained retired (?:framework path|sample|Git-hook helper) '")).Count -ge 18) 'retired residue diagnostics were unexpectedly empty or incomplete'
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

foreach ($case in @(
    @{ Rel = 'LICENSES/ai-tech-lead-MIT.txt'; Text = 'consumer licence'; Message = "Refusing to overwrite 'LICENSES/ai-tech-lead-MIT.txt': the existing file is not identical to the framework licence." },
    @{ Rel = 'NOTICE-ai-tech-lead.md'; Text = 'consumer notice'; Message = "Refusing to overwrite 'NOTICE-ai-tech-lead.md': the existing file is not marked FRAMEWORK-OWNED." }
)) {
    It "legal-file refusal remains exit 3 without an update completion banner ($($case.Rel))" {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-legal-' + [guid]::NewGuid())
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent (Join-Path $t $case.Rel)) | Out-Null
        Set-Content -LiteralPath (Join-Path $t '.claude/framework-version.json') -Value '{"version":"0.55.0"}' -Encoding utf8
        Set-Content -LiteralPath (Join-Path $t $case.Rel) -Value $case.Text -Encoding utf8
        try {
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $code = $LASTEXITCODE
            Assert ($code -eq 3) "legal-file refusal exit changed from 3 to $code. Output:`n$out"
            $messageText = (($out -replace '\s+', ' ').Trim())
            $expectedText = (($case.Message -replace '\s+', ' ').Trim())
            Assert ($messageText -match [regex]::Escape($expectedText)) "legal-file refusal message changed. Output:`n$out"
            Assert ($out -notmatch 'Done \(update\)') "failed update printed the success-only completion banner. Output:`n$out"
        } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
    }
}

exit (Write-TestSummary 'UpdateDelivery.Tests')
