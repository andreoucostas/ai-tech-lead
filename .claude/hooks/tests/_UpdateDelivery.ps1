# Definitions shared by UpdateDelivery.Tests.ps1 and UpdateDelivery2, 3 and 4.Tests.ps1, which dot-source this file;
# it runs no test. One file was split in four so CI runs the quarters in parallel (B-510). Does NOT ship.
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
    param([string]$Dist, [string]$Target, [switch]$AllowDirtyTree, [switch]$AllowMoveAside, [switch]$RemoveLeftovers, [switch]$Reinstall)
    $installer = Join-Path $repoRoot "dist/$Dist/scripts/install.ps1"
    $switches = @()
    if ($AllowDirtyTree) { $switches += '-AllowDirtyTree' }
    if ($AllowMoveAside) { $switches += '-AllowMoveAside' }
    if ($RemoveLeftovers) { $switches += '-RemoveLeftovers' }
    if ($Reinstall) { $switches += '-Reinstall' }
    & (Get-PsExe) -NoProfile -File $installer -Target $Target @switches 2>&1 | Out-String
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

# B-469: a line an update prints to recover a file from a commit, run as printed in PowerShell from outside the repository.
function Invoke-B469Printed {
    param([Parameter(Mandatory)][string]$Line)
    Push-Location ([IO.Path]::GetTempPath())
    try { return (& (Get-PsExe) -NoProfile -Command $Line 2>&1 | Out-String) } finally { Pop-Location }
}
# The bytes git show prints for Spec in Target, read raw: a pipe into PowerShell decodes them with the console's code page.
function Get-B469ShowBytes {
    param([Parameter(Mandatory)][string]$Target, [Parameter(Mandatory)][string]$Spec)
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = (Get-Command git -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
    $start.Arguments = "-C `"$Target`" show $Spec"
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($start)
    $memory = New-Object IO.MemoryStream
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        [void]$process.StandardError.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw "git show $Spec failed (exit $($process.ExitCode))" }
        return , $memory.ToArray()
    } finally { $memory.Dispose(); $process.Dispose() }
}

function New-ArchGeneratorTarget {
    param([Parameter(Mandatory)][string]$Target)
    New-Item -ItemType Directory -Force -Path (Join-Path $Target '.claude') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $Target 'scripts') | Out-Null
    [IO.File]::WriteAllText((Join-Path $Target '.claude/framework-version.json'), '{"version":"0.86.7"}', [Text.UTF8Encoding]::new($false))
}

function New-B429GitTarget {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Ignore)
    $t = New-B309GitTarget -Root $Root -Name 'target' -Ignore $Ignore
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
    [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.94.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/framework-ownership.json'))
    return $t
}

function Write-B429Files {
    param([Parameter(Mandatory)][string]$Folder, [Parameter(Mandatory)][Collections.IDictionary]$Files)
    foreach ($name in $Files.Keys) {
        $path = Join-Path $Folder $name
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
        [IO.File]::WriteAllText($path, $Files[$name], [Text.UTF8Encoding]::new($false))
    }
}

