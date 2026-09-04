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
$bash = Get-BashPath

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
    $stderrFile = [IO.Path]::GetTempFileName()
    $saved = @{}
    $started = $false
    $exitCode = $null
    $stdout = @()
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
        $ErrorActionPreference = 'Continue'
        $started = $true
        $stdout = @(& $Executable @Arguments 2>$stderrFile)
        $exitCode = $LASTEXITCODE
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
    try { $stderr = [IO.File]::ReadAllText($stderrFile) } catch { $stderr = $_.Exception.Message }
    try { [IO.File]::Delete($stderrFile) } catch { }
    [pscustomobject]@{
        Started = $started
        Exit = $exitCode
        Out = (($stdout | ForEach-Object { [string]$_ }) -join "`n")
        Err = $stderr
        Exception = $exception
    }
}

function Invoke-B194BashWithLowercaseGitIndex {
    param(
        [string]$WrapperPath,
        [string]$IndexPath,
        [ValidateSet('host','probe','status','installer')][string]$Mode,
        [string[]]$Arguments = @(),
        [hashtable]$Environment = @{}
    )
    $wrappedArguments = @($WrapperPath, $IndexPath, $Mode) + @($Arguments)
    return Invoke-B194Process -Executable $bash -Arguments $wrappedArguments -Environment $Environment
}

function Invoke-B194Installer {
    param(
        [ValidateSet('ps1','sh')][string]$Twin,
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
    if ($Twin -eq 'ps1') {
        $installer = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
        if ($isolated.ContainsKey('B194_PS_PATH')) {
            # The Codex process launcher prepends its own dependency PATH after inheriting the
            # requested environment. Reset PATH inside the already-started native child so this
            # fixture can actually prove its no-pwsh-on-PATH premise.
            $controlledPath = [string]$isolated['B194_PS_PATH']
            $isolated.Remove('B194_PS_PATH')
            $path64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($controlledPath))
            $installer64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($installer))
            $target64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Target))
            # A normally completed script can leave its last native Git probe code (for example
            # non-repository 128) in LASTEXITCODE. Explicit installer `exit` calls terminate this
            # child immediately; reaching the statement after invocation therefore means success.
            $command = "`$env:PATH=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$path64'));`$installer=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$installer64'));`$target=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$target64'));& `$installer -Target `$target;exit 0"
            $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
            return Invoke-B194Process -Executable $PowerShellExe -Arguments @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encoded
            ) -Environment $isolated
        }
        return Invoke-B194Process -Executable $PowerShellExe -Arguments @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $installer, '-Target', $Target
        ) -Environment $isolated
    }
    $installer = Join-Path $repoRoot 'dist/dotnet/scripts/install.sh'
    if ($isolated.ContainsKey('B194_BASH_PATH')) {
        $controlledPath = [string]$isolated['B194_BASH_PATH']
        $isolated.Remove('B194_BASH_PATH')
        return Invoke-B194Process -Executable $bash -Arguments @(
            '-c', 'PATH="$1"; export PATH; exec "$BASH" "$2" "$3"', '_', $controlledPath, $installer, $Target
        ) -Environment $isolated
    }
    return Invoke-B194Process -Executable $bash -Arguments @($installer, $Target) -Environment $isolated
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

function New-B194BashNoGitPath {
    param([string]$Root)
    if ($env:OS -eq 'Windows_NT') { return '/usr/bin:/bin' }
    $bin = Join-Path $Root 'bash-no-git-bin'
    New-Item -ItemType Directory -Force -Path $bin | Out-Null
    foreach ($name in @('awk','cat','cmp','cp','cut','date','dirname','find','grep','head','mkdir','mktemp','mv','openssl','rm','sed','sha256sum','shasum','sort','tar','tr','wc')) {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) {
            New-Item -ItemType SymbolicLink -Path (Join-Path $bin $name) -Target $command.Source -ErrorAction Stop | Out-Null
        }
    }
    return $bin
}

function ConvertTo-B194BashPath {
    param([string]$Path)
    if ($env:OS -eq 'Windows_NT' -and $Path -match '^([A-Za-z]):[\\/](.*)$') {
        return ('/' + $matches[1].ToLowerInvariant() + '/' + $matches[2].Replace('\','/'))
    }
    return $Path
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

$b197TestName = 'B-197 Bash temporary lifecycle is path-safe'
$b197GitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $bash) {
    Skip $b197TestName 'no bash on this host'
} elseif (-not $b197GitCommand) {
    Skip $b197TestName 'git is unavailable'
} else {
    It $b197TestName {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('b197-temp-' + [guid]::NewGuid().ToString('N'))
        $problems = [System.Collections.Generic.List[string]]::new()
        $isolatedGit = @{
            GIT_DIR = $null; GIT_WORK_TREE = $null; GIT_COMMON_DIR = $null; GIT_INDEX_FILE = $null
        }
        try {
            New-Item -ItemType Directory -Force -Path $root | Out-Null
            $xdgConfig = Join-Path $root 'xdg-config'
            New-Item -ItemType Directory -Force -Path $xdgConfig | Out-Null
            $gitConfig = Join-Path $root 'empty.gitconfig'
            [IO.File]::WriteAllText($gitConfig, '', [Text.UTF8Encoding]::new($false))
            $isolatedGit.GIT_CONFIG_GLOBAL = $gitConfig
            $isolatedGit.XDG_CONFIG_HOME = $xdgConfig
            $installer = ConvertTo-B194BashPath (Join-Path $repoRoot 'dist/dotnet/scripts/install.sh')
            $runner = 'cd "$1" && TMPDIR="$2" && export TMPDIR && shift 2 && exec "$BASH" "$@"'

            $spacedWork = Join-Path $root 'spaced-caller'
            $spacedTemp = Join-Path $spacedWork 'prefix dir'
            $spacedTarget = Join-Path $root 'spaced-target'
            New-Item -ItemType Directory -Force -Path $spacedWork, $spacedTemp, $spacedTarget | Out-Null
            $spacedSentinel = Join-Path $spacedWork 'prefix'
            $sentinelBytes = [Text.UTF8Encoding]::new($false).GetBytes("B197 OWNED SENTINEL`n")
            [IO.File]::WriteAllBytes($spacedSentinel, $sentinelBytes)
            $spacedBefore = Get-B194Fingerprint $spacedWork
            $spacedEnvironment = @{}
            foreach ($name in $isolatedGit.Keys) { $spacedEnvironment[$name] = $isolatedGit[$name] }
            $spacedCapture = Invoke-B194Process -Executable $bash -Arguments @(
                '-c', $runner, 'b197-spaced', (ConvertTo-B194BashPath $spacedWork),
                'prefix dir', $installer, (ConvertTo-B194BashPath $spacedTarget)
            ) -Environment $spacedEnvironment

            $confinedTarget = Join-Path $root 'confined-target'
            $confinedTemp = Join-Path $confinedTarget '.tmp'
            New-Item -ItemType Directory -Force -Path (Join-Path $confinedTarget '.claude'), $confinedTemp | Out-Null
            [IO.File]::WriteAllText((Join-Path $confinedTarget '.claude/framework-version.json'), '{"version":"0.78.3"}', [Text.UTF8Encoding]::new($false))
            $confinedSentinel = Join-Path $confinedTemp 'tracked-sentinel.txt'
            $confinedSentinelBytes = [Text.UTF8Encoding]::new($false).GetBytes("B197 TRACKED TEMP ROOT`n")
            [IO.File]::WriteAllBytes($confinedSentinel, $confinedSentinelBytes)
            $gitExe = $b197GitCommand.Source
            $gitSetup = @(Initialize-B194GitTarget -Target $confinedTarget -GitExe $gitExe -Environment $isolatedGit)
            $trackedSentinel = Invoke-B194Process -Executable $gitExe -Arguments @(
                '-C', $confinedTarget, 'ls-files', '--error-unmatch', '--', '.tmp/tracked-sentinel.txt'
            ) -Environment $isolatedGit
            $cleanStatus = Invoke-B194Process -Executable $gitExe -Arguments @(
                '--no-optional-locks', '-C', $confinedTarget, 'status', '--porcelain=v1', '--untracked-files=all'
            ) -Environment $isolatedGit
            $confinedBefore = Get-B194Fingerprint $confinedTarget
            $confinedEnvironment = @{}
            foreach ($name in $isolatedGit.Keys) { $confinedEnvironment[$name] = $isolatedGit[$name] }
            $confinedCapture = Invoke-B194Process -Executable $bash -Arguments @(
                '-c', $runner, 'b197-confined', (ConvertTo-B194BashPath $root),
                'confined-target/.tmp', $installer,
                (ConvertTo-B194BashPath $confinedTarget)
            ) -Environment $confinedEnvironment

            # Both installer children have returned. Capture post-state defensively so a stronger
            # regression in one world cannot prevent the other world's verdict from being retained.
            $spacedAfter = ''
            $spacedWorkExists = Test-Path -LiteralPath $spacedWork -PathType Container
            if ($spacedWorkExists) {
                try { $spacedAfter = Get-B194Fingerprint $spacedWork }
                catch { $problems.Add("spaced TMPDIR post-state could not be fingerprinted: $($_.Exception.Message)") | Out-Null }
            } else { $problems.Add('spaced TMPDIR installer removed the caller-owned working directory') | Out-Null }
            $spacedTempExists = Test-Path -LiteralPath $spacedTemp -PathType Container
            $spacedSentinelExists = Test-Path -LiteralPath $spacedSentinel -PathType Leaf
            $spacedSentinelAfter = [byte[]]@()
            if ($spacedSentinelExists) {
                try { $spacedSentinelAfter = [IO.File]::ReadAllBytes($spacedSentinel) }
                catch { $problems.Add("spaced TMPDIR sentinel could not be read: $($_.Exception.Message)") | Out-Null }
            }
            $spacedResidue = @()
            if ($spacedTempExists) {
                try { $spacedResidue = @(Get-ChildItem -LiteralPath $spacedTemp -Recurse -File -Force -ErrorAction Stop) }
                catch { $problems.Add("spaced TMPDIR residue could not be enumerated: $($_.Exception.Message)") | Out-Null }
            }

            $confinedAfter = ''
            if (Test-Path -LiteralPath $confinedTarget -PathType Container) {
                try { $confinedAfter = Get-B194Fingerprint $confinedTarget }
                catch { $problems.Add("confined TMPDIR post-state could not be fingerprinted: $($_.Exception.Message)") | Out-Null }
            } else { $problems.Add('confined TMPDIR installer removed the target directory') | Out-Null }
            $confinedTempExists = Test-Path -LiteralPath $confinedTemp -PathType Container
            $confinedSentinelExists = Test-Path -LiteralPath $confinedSentinel -PathType Leaf
            $confinedSentinelAfter = [byte[]]@()
            if ($confinedSentinelExists) {
                try { $confinedSentinelAfter = [IO.File]::ReadAllBytes($confinedSentinel) }
                catch { $problems.Add("confined TMPDIR sentinel could not be read: $($_.Exception.Message)") | Out-Null }
            }
            $confinedResidue = @()
            if ($confinedTempExists) {
                try {
                    $confinedResidue = @(Get-ChildItem -LiteralPath $confinedTemp -Recurse -File -Force -ErrorAction Stop |
                        Where-Object { $_.FullName -cne $confinedSentinel })
                } catch { $problems.Add("confined TMPDIR residue could not be enumerated: $($_.Exception.Message)") | Out-Null }
            }

            Add-B194CaptureProblem -Problems $problems -Label 'spaced TMPDIR installer' -Capture $spacedCapture
            if ($spacedCapture.Exit -ne 0) { $problems.Add("spaced TMPDIR installer: expected exit 0, got $($spacedCapture.Exit); stdout=[$($spacedCapture.Out)]; stderr=[$($spacedCapture.Err)]") | Out-Null }
            if ($spacedCapture.Out -notmatch 'Done\. Next steps in the target repo:') { $problems.Add("spaced TMPDIR installer: greenfield completion missing; stdout=[$($spacedCapture.Out)]") | Out-Null }
            if ($spacedCapture.Err) { $problems.Add("spaced TMPDIR installer: unexpected stderr=[$($spacedCapture.Err)]") | Out-Null }
            if (-not $spacedTempExists) { $problems.Add('spaced TMPDIR installer removed its caller-owned temp directory') | Out-Null }
            if (-not $spacedSentinelExists -or -not (Test-B194BytesEqual $sentinelBytes $spacedSentinelAfter)) { $problems.Add('spaced TMPDIR installer deleted or changed the unrelated split-prefix sentinel') | Out-Null }
            if ($spacedResidue.Count -ne 0) { $problems.Add("spaced TMPDIR installer leaked $($spacedResidue.Count) temporary file(s)") | Out-Null }
            if ($spacedAfter -and $spacedAfter -cne $spacedBefore) { $problems.Add("spaced TMPDIR installer changed the caller-owned working tree ($spacedBefore -> $spacedAfter)") | Out-Null }

            foreach ($step in $gitSetup) { Add-B194ExpectedProcessProblems -Problems $problems -Label $step.Label -Capture $step.Capture -ExpectedExit $step.ExpectedExit }
            Add-B194ExpectedProcessProblems -Problems $problems -Label 'confined TMPDIR tracked-sentinel calibration' -Capture $trackedSentinel -ExpectedExit 0
            if ($trackedSentinel.Out -cne '.tmp/tracked-sentinel.txt' -or $trackedSentinel.Err.Length -ne 0) { $problems.Add("confined TMPDIR sentinel was not proven tracked; stdout=[$($trackedSentinel.Out)]; stderr=[$($trackedSentinel.Err)]") | Out-Null }
            Add-B194ExpectedProcessProblems -Problems $problems -Label 'confined TMPDIR clean-status calibration' -Capture $cleanStatus -ExpectedExit 0
            if ($cleanStatus.Out.Length -ne 0 -or $cleanStatus.Err.Length -ne 0) { $problems.Add("confined TMPDIR fixture was not clean; stdout=[$($cleanStatus.Out)]; stderr=[$($cleanStatus.Err)]") | Out-Null }
            Add-B194CaptureProblem -Problems $problems -Label 'confined TMPDIR installer' -Capture $confinedCapture
            $confinedCombined = $confinedCapture.Out + "`n" + $confinedCapture.Err
            if ($confinedCapture.Exit -ne 3) { $problems.Add("confined TMPDIR installer: expected exit 3, got $($confinedCapture.Exit); stdout=[$($confinedCapture.Out)]; stderr=[$($confinedCapture.Err)]") | Out-Null }
            if ($confinedCombined -notmatch 'Refusing temporary-file placement inside the selected target') { $problems.Add("confined TMPDIR installer: specific containment refusal missing; output=[$confinedCombined]") | Out-Null }
            if ($confinedCombined -match 'dirty Git target|commit, stash, or copy') { $problems.Add("confined TMPDIR installer falsely diagnosed a dirty target; output=[$confinedCombined]") | Out-Null }
            if ($confinedCombined -match 'Done \(update\)|Done - but this repo|Done\. Next steps') { $problems.Add("confined TMPDIR installer printed completion; output=[$confinedCombined]") | Out-Null }
            if ($confinedAfter -and $confinedAfter -cne $confinedBefore) { $problems.Add("confined TMPDIR installer left persistent target mutation ($confinedBefore -> $confinedAfter)") | Out-Null }
            if (-not $confinedTempExists) { $problems.Add('confined TMPDIR installer removed the tracked temp directory') | Out-Null }
            if (-not $confinedSentinelExists -or -not (Test-B194BytesEqual $confinedSentinelBytes $confinedSentinelAfter)) { $problems.Add('confined TMPDIR installer deleted or changed the tracked temp-root sentinel') | Out-Null }
            if ($confinedResidue.Count -ne 0) { $problems.Add("confined TMPDIR installer left $($confinedResidue.Count) generated temporary file(s)") | Out-Null }

            Assert ($problems.Count -eq 0) ($problems -join "`n")
        } finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

foreach ($twin in @('ps1', 'sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Skip "update delivery ($twin)" 'no bash on this host'; continue }
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

    # THE assertions. If either fails, the framework is destroying consumer content.
    It "update leaves protected consumer documents byte-identical ($twin)" {
        Assert ((Get-Hash $claudePath) -eq $before) 'update mode modified CLAUDE.md -- the v0.20.0 protection has regressed'
        Assert-BytesEqual -Expected $adrBefore -Actual ([IO.File]::ReadAllBytes($adrPath)) -Message 'update mode replaced the consumer append-only ADR log'
        Assert-BytesEqual -Expected $learningsExpectedBytes -Actual $learningsBefore -Message 'disabled-skill fixture was not exact BOM + HT + CRLF input'
        Assert-BytesEqual -Expected $learningsBefore -Actual ([IO.File]::ReadAllBytes($learningsPath)) -Message 'update mode modified the protected disabled-skill ledger'
        Assert ($out -match '(?m)^PLAN preserve docs/architecture-decisions\.md\r?$') "update operation plan did not classify the consumer ADR log as preserved. Output:`n$out"
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

foreach ($twin in @('ps1', 'sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Skip "brownfield screen-in-place architecture and ADRs ($twin)" 'no bash on this host'; continue }
    It "brownfield leaves mature architecture and ADRs active and unarchived for in-place screening ($twin)" {
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
            $out = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t
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
        $githubSkillsBefore = @{}
        foreach ($relative in @('.github/skills/local-only/SKILL.md', '.github/skills/local-only/reference.md', '.github/skills/perf/SKILL.md', '.github/skills/add-tests/SKILL.md')) {
            $githubSkillsBefore[$relative] = [IO.File]::ReadAllBytes((Join-Path $t $relative))
        }
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

            $update = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "update install failed (exit $LASTEXITCODE): $update"
            Assert-BytesEqual -Expected $auditBefore -Actual ([IO.File]::ReadAllBytes((Join-Path $t '.claude/ai-audit.log'))) -Message 'update overwrote persistent ai-audit.log bytes'
            foreach ($relative in $githubSkillsBefore.Keys) {
                Assert-BytesEqual -Expected $githubSkillsBefore[$relative] -Actual ([IO.File]::ReadAllBytes((Join-Path $t $relative))) -Message "update changed untrusted GitHub skill input $relative"
            }
            Assert ($update -match "CANT-VERIFY: retained retired path '\.github/skills/perf/SKILL\.md'.*may shadow") 'later update did not warn about the identical historical-path GitHub skill'
            Assert ($update -match "CANT-VERIFY: retained retired path '\.github/skills/add-tests/SKILL\.md'.*may shadow") 'later update did not warn about the conflicting historical-path GitHub skill'
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

# B-194 red-first matrix.  Keep these as exactly three results: each branch is expensive because it
# runs the shipped installer, and the existing suites already own clean/dirty Git controls.
It 'B-194 plain non-Git update and brownfield remain supported when Git is optional' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b194-nongit-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    try {
        $problems = [System.Collections.Generic.List[string]]::new()
        $pwshCommand = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $pwshExe = if ($pwshCommand) { $pwshCommand.Source } else { '' }
        $gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $gitExe = if ($gitCommand) { $gitCommand.Source } else { '' }
        $gitConfig = Join-Path $root 'empty.gitconfig'
        [IO.File]::WriteAllText($gitConfig, '', [Text.UTF8Encoding]::new($false))
        $cleanGitEnvironment = @{
            GIT_DIR = $null; GIT_WORK_TREE = $null; GIT_COMMON_DIR = $null; GIT_INDEX_FILE = $null
            GIT_CONFIG_GLOBAL = $gitConfig
        }

        $nativeUpdate = $null
        $nativeBrownfield = $null
        $nativeUpdateTarget = ''
        $nativeBrownfieldTarget = ''
        $nativeUpdateProtected = [byte[]]@()
        $nativeBrownfieldProtected = [byte[]]@()
        $nativePrerequisite = $null
        if ($env:OS -eq 'Windows_NT') {
            $nativePs = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $pathParts = @()
            if ($gitExe) { $pathParts += (Split-Path -Parent $gitExe) }
            $pathParts += @((Join-Path $env:SystemRoot 'System32'), $env:SystemRoot, (Split-Path -Parent $nativePs))
            $nativePath = (($pathParts | Where-Object { $_ } | Select-Object -Unique) -join [IO.Path]::PathSeparator)
            $nativeEnvironment = @{
                PATH = $nativePath; B194_PS_PATH = $nativePath; GIT_CONFIG_GLOBAL = $gitConfig
                GIT_DIR = $null; GIT_WORK_TREE = $null; GIT_COMMON_DIR = $null; GIT_INDEX_FILE = $null
            }
            $path64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($nativePath))
            $prerequisiteCommand = "`$env:PATH=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$path64'));`$gitOnPath=@(& where.exe git 2>`$null);`$pwshOnPath=@(& where.exe pwsh 2>`$null);`$git=Get-Command git -CommandType Application -ErrorAction SilentlyContinue;if(-not `$git -or `$gitOnPath.Count -eq 0){Write-Error 'real Git is absent from PATH';exit 11};if(`$pwshOnPath.Count -gt 0){Write-Error 'pwsh unexpectedly exists on PATH';exit 12};Write-Output `$git.Source;exit 0"
            $prerequisiteEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($prerequisiteCommand))
            $prerequisiteEnvironment = $nativeEnvironment.Clone()
            $prerequisiteEnvironment.Remove('B194_PS_PATH')
            $nativePrerequisite = Invoke-B194Process -Executable $nativePs -Arguments @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $prerequisiteEncoded
            ) -Environment $prerequisiteEnvironment
            $nativeUpdateTarget = New-B194UpdateTarget -Parent $root -Name 'native-update'
            $nativeBrownfieldTarget = New-B194BrownfieldTarget -Parent $root -Name 'native-brownfield'
            $nativeUpdateProtected = [IO.File]::ReadAllBytes((Join-Path $nativeUpdateTarget 'CLAUDE.md'))
            $nativeBrownfieldProtected = [IO.File]::ReadAllBytes((Join-Path $nativeBrownfieldTarget 'TECH_DEBT.md'))
            $nativeUpdate = Invoke-B194Installer -Twin ps1 -Target $nativeUpdateTarget -PowerShellExe $nativePs -Environment $nativeEnvironment
            $nativeBrownfield = Invoke-B194Installer -Twin ps1 -Target $nativeBrownfieldTarget -PowerShellExe $nativePs -Environment $nativeEnvironment
        }

        $stubBin = Join-Path $root 'broken-git-bin'
        New-Item -ItemType Directory -Force -Path $stubBin | Out-Null
        $cmdStub = Join-Path $stubBin 'git.cmd'
        $shStub = Join-Path $stubBin 'git'
        [IO.File]::WriteAllText($cmdStub, "@echo off`r`n>>`"%B194_GIT_SENTINEL%`" echo %*`r`necho B194 broken Git stub 1>&2`r`nexit /b 86`r`n", [Text.ASCIIEncoding]::new())
        [IO.File]::WriteAllText($shStub, "#!/bin/sh`nprintf '%s\\n' `"`$*`" >> `"`$B194_GIT_SENTINEL`"`nprintf '%s\\n' 'B194 broken Git stub' >&2`nexit 86`n", [Text.UTF8Encoding]::new($false))
        $chmodCapture = Invoke-B194Process -Executable $bash -Arguments @('-c', 'chmod +x "$1"', '_', $shStub)

        $stubPsTarget = New-B194UpdateTarget -Parent $root -Name 'stub-ps1-update'
        $stubShTarget = New-B194UpdateTarget -Parent $root -Name 'stub-sh-update'
        $stubPsProtected = [IO.File]::ReadAllBytes((Join-Path $stubPsTarget 'CLAUDE.md'))
        $stubShProtected = [IO.File]::ReadAllBytes((Join-Path $stubShTarget 'CLAUDE.md'))
        $stubPsSentinel = Join-Path $root 'stub-ps1.calls'
        $stubShSentinel = Join-Path $root 'stub-sh.calls'
        $stubPath = $stubBin + [IO.Path]::PathSeparator + $env:PATH
        $stubBashPath = (ConvertTo-B194BashPath $stubBin) + ':/usr/bin:/bin:/cmd'
        $stubPsCapture = Invoke-B194Installer -Twin ps1 -Target $stubPsTarget -PowerShellExe $pwshExe -Environment @{
            PATH = $stubPath; B194_GIT_SENTINEL = $stubPsSentinel; GIT_CONFIG_GLOBAL = $gitConfig
        }
        $stubShCapture = Invoke-B194Installer -Twin sh -Target $stubShTarget -Environment @{
            B194_BASH_PATH = $stubBashPath; B194_GIT_SENTINEL = $stubShSentinel; GIT_CONFIG_GLOBAL = $gitConfig
        }

        $executeOnlyRestrict = $null
        $executeOnlyRestore = $null
        $executeOnlyCapture = $null
        $executeOnlyTarget = ''
        $executeOnlyProtected = [byte[]]@()
        if ($env:OS -ne 'Windows_NT' -and $bash) {
            $executeOnlyParent = Join-Path $root 'execute-only-parent'
            $executeOnlyTarget = New-B194UpdateTarget -Parent $executeOnlyParent -Name 'bash-update'
            $executeOnlyProtected = [IO.File]::ReadAllBytes((Join-Path $executeOnlyTarget 'CLAUDE.md'))
            $executeOnlyRestrict = Invoke-B194Process -Executable $bash -Arguments @(
                '-c', 'chmod 311 "$1" || exit 91; [ -x "$1" ] || exit 92; [ ! -r "$1" ] || exit 93', '_', $executeOnlyParent
            )
            $executeOnlyCapture = Invoke-B194Installer -Twin sh -Target $executeOnlyTarget -Environment $cleanGitEnvironment
            $executeOnlyRestore = Invoke-B194Process -Executable $bash -Arguments @('-c', 'chmod 700 "$1"', '_', $executeOnlyParent)
        }

        # All installer and setup children above are captured before validation begins.
        Add-B194ExpectedProcessProblems -Problems $problems -Label 'broken-Git stub chmod' -Capture $chmodCapture -ExpectedExit 0
        if ($env:OS -eq 'Windows_NT') {
            Add-B194ExpectedProcessProblems -Problems $problems -Label 'native PowerShell 5.1 real-Git/no-pwsh-on-PATH prerequisite' -Capture $nativePrerequisite -ExpectedExit 0
            if (-not $nativePrerequisite.Out) { $problems.Add('native PowerShell 5.1 prerequisite did not identify the resolved Git application') | Out-Null }
            Add-B194SuccessProblems -Problems $problems -Label 'native PowerShell 5.1 non-Git update' -Capture $nativeUpdate -Completion 'Done \(update\)'
            Add-B194SuccessProblems -Problems $problems -Label 'native PowerShell 5.1 non-Git brownfield' -Capture $nativeBrownfield -Completion 'Done - but this repo'
            if (-not (Test-B194BytesEqual $nativeUpdateProtected ([IO.File]::ReadAllBytes((Join-Path $nativeUpdateTarget 'CLAUDE.md'))))) {
                $problems.Add('native PowerShell 5.1 update changed protected CLAUDE.md bytes') | Out-Null
            }
            $carrier = Join-Path $nativeUpdateTarget $carrierRel
            if (-not (Test-Path -LiteralPath $carrier -PathType Leaf) -or (Get-Hash $carrier) -ne (Get-Hash (Join-Path $repoRoot "dist/dotnet/$carrierRel"))) {
                $problems.Add('native PowerShell 5.1 update did not deliver the exact carrier') | Out-Null
            }
            $archive = Join-Path $nativeBrownfieldTarget 'docs/pre-adoption/TECH_DEBT.md'
            if (-not (Test-Path -LiteralPath $archive -PathType Leaf) -or -not (Test-B194BytesEqual $nativeBrownfieldProtected ([IO.File]::ReadAllBytes($archive)))) {
                $problems.Add('native PowerShell 5.1 brownfield did not preserve exact TECH_DEBT archive bytes') | Out-Null
            }
            try {
                $marker = Get-Content -LiteralPath (Join-Path $nativeBrownfieldTarget '.claude/adoption-pending.json') -Raw -ErrorAction Stop | ConvertFrom-Json
                if (-not ($marker.archivedOriginals -contains 'docs/pre-adoption/TECH_DEBT.md')) {
                    $problems.Add('native PowerShell 5.1 brownfield marker omitted the TECH_DEBT archive') | Out-Null
                }
            } catch { $problems.Add("native PowerShell 5.1 brownfield marker unreadable: $($_.Exception.Message)") | Out-Null }
        }

        foreach ($case in @(
            @{ Label = 'PowerShell broken Git without repository evidence'; Capture = $stubPsCapture; Target = $stubPsTarget; Protected = $stubPsProtected; Sentinel = $stubPsSentinel },
            @{ Label = 'Bash broken Git without repository evidence'; Capture = $stubShCapture; Target = $stubShTarget; Protected = $stubShProtected; Sentinel = $stubShSentinel }
        )) {
            Add-B194SuccessProblems -Problems $problems -Label $case.Label -Capture $case.Capture -Completion 'Done \(update\)'
            if (-not (Test-B194BytesEqual $case.Protected ([IO.File]::ReadAllBytes((Join-Path $case.Target 'CLAUDE.md'))))) {
                $problems.Add("$($case.Label): protected CLAUDE.md bytes changed") | Out-Null
            }
            $calls = if (Test-Path -LiteralPath $case.Sentinel -PathType Leaf) { [IO.File]::ReadAllText($case.Sentinel) } else { '' }
            if (-not $calls -or $calls -notmatch '(?m)(^| )-C( |$)') { $problems.Add("$($case.Label): out-of-target Git invocation sentinel was not observed") | Out-Null }
            if ([IO.Path]::GetFullPath($case.Sentinel).StartsWith([IO.Path]::GetFullPath($case.Target) + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
                $problems.Add("$($case.Label): Git invocation sentinel was inside the mutation target") | Out-Null
            }
        }
        if ($env:OS -ne 'Windows_NT' -and $bash) {
            Add-B194ExpectedProcessProblems -Problems $problems -Label 'execute-only/no-read ancestor prerequisite' -Capture $executeOnlyRestrict -ExpectedExit 0
            Add-B194ExpectedProcessProblems -Problems $problems -Label 'execute-only ancestor restore' -Capture $executeOnlyRestore -ExpectedExit 0
            Add-B194SuccessProblems -Problems $problems -Label 'Bash plain target beneath execute-only ancestor' -Capture $executeOnlyCapture -Completion 'Done \(update\)'
            if (-not (Test-B194BytesEqual $executeOnlyProtected ([IO.File]::ReadAllBytes((Join-Path $executeOnlyTarget 'CLAUDE.md'))))) {
                $problems.Add('Bash execute-only-ancestor update changed protected CLAUDE.md bytes') | Out-Null
            }
            $executeOnlyCarrier = Join-Path $executeOnlyTarget $carrierRel
            if (-not (Test-Path -LiteralPath $executeOnlyCarrier -PathType Leaf) -or (Get-Hash $executeOnlyCarrier) -ne (Get-Hash (Join-Path $repoRoot "dist/dotnet/$carrierRel"))) {
                $problems.Add('Bash execute-only-ancestor update did not deliver the exact carrier') | Out-Null
            }
        }
        Assert ($problems.Count -eq 0) ($problems -join "`n")
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-194 corrupt repository evidence and ambient Git routing refuse before mutation' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b194-evidence-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    try {
        $problems = [System.Collections.Generic.List[string]]::new()
        $setup = [System.Collections.Generic.List[object]]::new()
        $refusals = [System.Collections.Generic.List[object]]::new()
        $pwshCommand = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $pwshExe = if ($pwshCommand) { $pwshCommand.Source } else { '' }
        $nativePs = if ($env:OS -eq 'Windows_NT') { Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' } else { '' }
        $gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $gitExe = if ($gitCommand) { $gitCommand.Source } else { '' }
        $gitConfig = Join-Path $root 'empty.gitconfig'
        [IO.File]::WriteAllText($gitConfig, '', [Text.UTF8Encoding]::new($false))
        $lowercaseRoutingWrapper = Join-Path $root 'lowercase-git-routing.sh'
        $lowercaseRoutingScript = @'
#!/usr/bin/env bash
index_path=$1
mode=$2
shift 2
if [ "$mode" = host ]; then
  ostype_value=${OSTYPE:-}
  msystem_value=${MSYSTEM:-}
  case "$ostype_value:$msystem_value" in
    msys*:*|cygwin*:MINGW32|cygwin*:MINGW64|cygwin*:UCRT64|cygwin*:CLANGARM64) ;;
    *) printf 'OSTYPE=%s;MSYSTEM=%s;PWD_W=\n' "$ostype_value" "$msystem_value"; exit 14 ;;
  esac
  windows_path=$(builtin pwd -W 2>/dev/null) || {
    printf 'OSTYPE=%s;MSYSTEM=%s;PWD_W=\n' "$ostype_value" "$msystem_value"
    exit 15
  }
  case "$windows_path" in
    [A-Za-z]:/*) ;;
    //?*/?*)
      remainder=${windows_path#//}
      server=${remainder%%/*}
      share_and_rest=${remainder#*/}
      share=${share_and_rest%%/*}
      [ -n "$server" ] && [ -n "$share" ] || {
        printf 'OSTYPE=%s;MSYSTEM=%s;PWD_W=%s\n' "$ostype_value" "$msystem_value" "$windows_path"
        exit 16
      }
      case "$windows_path" in "//$server/$share"|"//$server/$share"/*) ;; *) exit 16 ;; esac
      ;;
    *)
      printf 'OSTYPE=%s;MSYSTEM=%s;PWD_W=%s\n' "$ostype_value" "$msystem_value" "$windows_path"
      exit 16
      ;;
  esac
  printf 'OSTYPE=%s;MSYSTEM=%s;PWD_W=%s\n' "$ostype_value" "$msystem_value" "$windows_path"
  exit 0
fi
unset GIT_INDEX_FILE
git_index_file=$index_path
export git_index_file
case "$mode" in
  probe)
    [ "$git_index_file" = "$index_path" ] && [ -z "${GIT_INDEX_FILE+x}" ] || exit 12
    printf '%s\n' "$git_index_file"
    ;;
  status) exec git -C "$1" status --porcelain=v1 --untracked-files=all ;;
  installer) exec "$BASH" "$1" "$2" ;;
  *) exit 13 ;;
esac
'@ -replace "`r`n", "`n"
        [IO.File]::WriteAllText($lowercaseRoutingWrapper, $lowercaseRoutingScript, [Text.UTF8Encoding]::new($false))
        $cleanGitEnvironment = @{
            GIT_DIR = $null; GIT_WORK_TREE = $null; GIT_COMMON_DIR = $null; GIT_INDEX_FILE = $null
            GIT_CONFIG_GLOBAL = $gitConfig
        }

        $corruptHosts = @(
            @{ Label = 'corrupt .git PowerShell 7'; Twin = 'ps1'; Host = $pwshExe },
            @{ Label = 'corrupt .git Bash'; Twin = 'sh'; Host = '' }
        )
        if ($env:OS -eq 'Windows_NT') { $corruptHosts += @{ Label = 'corrupt .git native PowerShell 5.1'; Twin = 'ps1'; Host = $nativePs } }
        foreach ($hostCase in $corruptHosts) {
            $target = New-B194UpdateTarget -Parent $root -Name ($hostCase.Label -replace '[^A-Za-z0-9]+','-')
            New-Item -ItemType Directory -Force -Path (Join-Path $target '.git') | Out-Null
            $before = Get-B194Fingerprint $target
            $capture = Invoke-B194Installer -Twin $hostCase.Twin -Target $target -PowerShellExe $hostCase.Host -Environment $cleanGitEnvironment
            $refusals.Add([pscustomobject]@{ Label = $hostCase.Label; Capture = $capture; Before = $before; After = (Get-B194Fingerprint $target) }) | Out-Null
        }

        $noGitBin = Join-Path $root 'ps-no-git-bin'
        New-Item -ItemType Directory -Force -Path $noGitBin | Out-Null
        $psGitProbe = Invoke-B194Process -Executable $pwshExe -Arguments @('-NoProfile','-Command','if (Get-Command git -CommandType Application -ErrorAction SilentlyContinue) { exit 9 } else { exit 0 }') -Environment @{ PATH = $noGitBin }
        $psNoGitTarget = New-B194UpdateTarget -Parent $root -Name 'evidence-no-git-ps1'
        New-Item -ItemType Directory -Force -Path (Join-Path $psNoGitTarget '.git') | Out-Null
        $psNoGitBefore = Get-B194Fingerprint $psNoGitTarget
        $psNoGitCapture = Invoke-B194Installer -Twin ps1 -Target $psNoGitTarget -PowerShellExe $pwshExe -Environment @{ PATH = $noGitBin; GIT_CONFIG_GLOBAL = $gitConfig }
        $refusals.Add([pscustomobject]@{ Label = 'repository evidence with Git absent PowerShell'; Capture = $psNoGitCapture; Before = $psNoGitBefore; After = (Get-B194Fingerprint $psNoGitTarget) }) | Out-Null

        $bashNoGitPath = New-B194BashNoGitPath -Root $root
        $bashGitProbe = Invoke-B194Process -Executable $bash -Arguments @('-c','PATH="$1"; export PATH; command -v git','_', $bashNoGitPath)
        $bashNoGitTarget = New-B194UpdateTarget -Parent $root -Name 'evidence-no-git-sh'
        New-Item -ItemType Directory -Force -Path (Join-Path $bashNoGitTarget '.git') | Out-Null
        $bashNoGitBefore = Get-B194Fingerprint $bashNoGitTarget
        $bashNoGitCapture = Invoke-B194Installer -Twin sh -Target $bashNoGitTarget -Environment @{ B194_BASH_PATH = $bashNoGitPath; GIT_CONFIG_GLOBAL = $gitConfig }
        $refusals.Add([pscustomobject]@{ Label = 'repository evidence with Git absent Bash'; Capture = $bashNoGitCapture; Before = $bashNoGitBefore; After = (Get-B194Fingerprint $bashNoGitTarget) }) | Out-Null

        $ambientHosts = @(
            @{ Label = 'ambient alternate index PowerShell 7'; Twin = 'ps1'; Host = $pwshExe },
            @{ Label = 'ambient alternate index Bash'; Twin = 'sh'; Host = '' }
        )
        if ($env:OS -eq 'Windows_NT') {
            $msysHostProbe = Invoke-B194BashWithLowercaseGitIndex -WrapperPath $lowercaseRoutingWrapper -IndexPath '_' -Mode host -Environment $cleanGitEnvironment
            $setup.Add([pscustomobject]@{ Label = 'lowercase routing Git-for-Windows host prerequisite'; Capture = $msysHostProbe; ExpectedExit = 0; HostEvidence = $true }) | Out-Null
            if ($msysHostProbe.Started -and $msysHostProbe.Exit -eq 0) {
                $ambientHosts += @{ Label = 'ambient lowercase alternate index Git Bash'; Twin = 'sh'; Host = ''; Lowercase = $true }
            }
        }
        foreach ($ambientHost in $ambientHosts) {
            $target = New-B194UpdateTarget -Parent $root -Name ($ambientHost.Label -replace '[^A-Za-z0-9]+','-')
            [IO.File]::WriteAllText((Join-Path $target 'tracked.txt'), "clean`n", [Text.UTF8Encoding]::new($false))
            foreach ($step in @(Initialize-B194GitTarget -Target $target -GitExe $gitExe -Environment $cleanGitEnvironment)) { $setup.Add($step) | Out-Null }
            $alternateIndex = Join-Path $root (($ambientHost.Label -replace '[^A-Za-z0-9]+','-') + '.index')
            $ambientEnvironment = @{
                GIT_DIR = $null; GIT_WORK_TREE = $null; GIT_COMMON_DIR = $null
                GIT_INDEX_FILE = $alternateIndex; GIT_CONFIG_GLOBAL = $gitConfig
            }
            $setup.Add([pscustomobject]@{ Label = "$($ambientHost.Label) read-tree"; Capture = (Invoke-B194Process -Executable $gitExe -Arguments @('-C',$target,'read-tree','HEAD') -Environment $ambientEnvironment); ExpectedExit = 0 }) | Out-Null
            $setup.Add([pscustomobject]@{ Label = "$($ambientHost.Label) assume-unchanged"; Capture = (Invoke-B194Process -Executable $gitExe -Arguments @('-C',$target,'update-index','--assume-unchanged','tracked.txt') -Environment $ambientEnvironment); ExpectedExit = 0 }) | Out-Null
            [IO.File]::WriteAllText((Join-Path $target 'tracked.txt'), "dirty`n", [Text.UTF8Encoding]::new($false))
            $normalStatus = Invoke-B194Process -Executable $gitExe -Arguments @('-C',$target,'status','--porcelain=v1','--untracked-files=all') -Environment $cleanGitEnvironment
            if ($ambientHost.Lowercase) {
                $caseProbe = Invoke-B194BashWithLowercaseGitIndex -WrapperPath $lowercaseRoutingWrapper -IndexPath $alternateIndex -Mode probe -Environment $cleanGitEnvironment
                $setup.Add([pscustomobject]@{ Label = "$($ambientHost.Label) lowercase boundary"; Capture = $caseProbe; ExpectedExit = 0; ExactOutput = $alternateIndex }) | Out-Null
                $hiddenStatus = Invoke-B194BashWithLowercaseGitIndex -WrapperPath $lowercaseRoutingWrapper -IndexPath $alternateIndex -Mode status -Arguments @($target) -Environment $cleanGitEnvironment
            } else {
                $hiddenStatus = Invoke-B194Process -Executable $gitExe -Arguments @('-C',$target,'status','--porcelain=v1','--untracked-files=all') -Environment $ambientEnvironment
            }
            $setup.Add([pscustomobject]@{ Label = "$($ambientHost.Label) normal dirty status"; Capture = $normalStatus; ExpectedExit = 0; Output = 'dirty' }) | Out-Null
            $setup.Add([pscustomobject]@{ Label = "$($ambientHost.Label) ambient hidden status"; Capture = $hiddenStatus; ExpectedExit = 0; Output = 'empty' }) | Out-Null
            $before = Get-B194Fingerprint $target
            if ($ambientHost.Lowercase) {
                $installer = Join-Path $repoRoot 'dist/dotnet/scripts/install.sh'
                $capture = Invoke-B194BashWithLowercaseGitIndex -WrapperPath $lowercaseRoutingWrapper -IndexPath $alternateIndex -Mode installer -Arguments @($installer,$target) -Environment $cleanGitEnvironment
            } else {
                $capture = Invoke-B194Installer -Twin $ambientHost.Twin -Target $target -PowerShellExe $ambientHost.Host -Environment $ambientEnvironment
            }
            $refusals.Add([pscustomobject]@{ Label = $ambientHost.Label; Capture = $capture; Before = $before; After = (Get-B194Fingerprint $target) }) | Out-Null
        }

        # Every child surface is now captured; only validation follows.
        Add-B194ExpectedProcessProblems -Problems $problems -Label 'PowerShell Git-absence probe' -Capture $psGitProbe -ExpectedExit 0
        Add-B194ExpectedProcessProblems -Problems $problems -Label 'Bash Git-absence probe' -Capture $bashGitProbe -ExpectedExit 1
        foreach ($step in $setup) {
            Add-B194ExpectedProcessProblems -Problems $problems -Label $step.Label -Capture $step.Capture -ExpectedExit $step.ExpectedExit
            if ($null -ne $step.ExactOutput -and $step.Capture.Out -ne [string]$step.ExactOutput) { $problems.Add("$($step.Label): expected exact output '$($step.ExactOutput)', got '$($step.Capture.Out)'") | Out-Null }
            if ($step.HostEvidence) {
                $hostEvidencePattern = '^OSTYPE=(?:msys[^;]*;MSYSTEM=[^;]*|cygwin[^;]*;MSYSTEM=(?:MINGW32|MINGW64|UCRT64|CLANGARM64));PWD_W=(?:[A-Za-z]:/.*|//[^/]+/[^/]+(?:/.*)?)$'
                if ($step.Capture.Out -cnotmatch $hostEvidencePattern) { $problems.Add("$($step.Label): malformed provider evidence '$($step.Capture.Out)'") | Out-Null }
                elseif ($step.Capture.Exit -eq 0) { Write-Host "INFO B-194 provider evidence: $($step.Capture.Out)" }
            }
            if ($step.Output -eq 'dirty' -and $step.Capture.Out -notmatch 'tracked\.txt') { $problems.Add("$($step.Label): ordinary index did not expose tracked.txt") | Out-Null }
            if ($step.Output -eq 'empty' -and $step.Capture.Out.Trim().Length -ne 0) { $problems.Add("$($step.Label): alternate index did not hide the dirty file: $($step.Capture.Out)") | Out-Null }
        }
        foreach ($case in $refusals) { Add-B194RefusalProblems -Problems $problems -Label $case.Label -Capture $case.Capture -Before $case.Before -After $case.After }
        Assert ($problems.Count -eq 0) ($problems -join "`n")
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-194 a classified worktree with unreadable status refuses before mutation' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b194-status-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $root | Out-Null
    try {
        $problems = [System.Collections.Generic.List[string]]::new()
        $setup = [System.Collections.Generic.List[object]]::new()
        $refusals = [System.Collections.Generic.List[object]]::new()
        $pwshCommand = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $pwshExe = if ($pwshCommand) { $pwshCommand.Source } else { '' }
        $nativePs = if ($env:OS -eq 'Windows_NT') { Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' } else { '' }
        $gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        $gitExe = if ($gitCommand) { $gitCommand.Source } else { '' }
        $gitConfig = Join-Path $root 'empty.gitconfig'
        [IO.File]::WriteAllText($gitConfig, '', [Text.UTF8Encoding]::new($false))
        $cleanGitEnvironment = @{
            GIT_DIR = $null; GIT_WORK_TREE = $null; GIT_COMMON_DIR = $null; GIT_INDEX_FILE = $null
            GIT_CONFIG_GLOBAL = $gitConfig
        }
        $hosts = @(
            @{ Label = 'corrupt index PowerShell 7'; Twin = 'ps1'; Host = $pwshExe },
            @{ Label = 'corrupt index Bash'; Twin = 'sh'; Host = '' }
        )
        if ($env:OS -eq 'Windows_NT') { $hosts += @{ Label = 'corrupt index native PowerShell 5.1'; Twin = 'ps1'; Host = $nativePs } }
        foreach ($hostCase in $hosts) {
            $target = New-B194UpdateTarget -Parent $root -Name ($hostCase.Label -replace '[^A-Za-z0-9]+','-')
            [IO.File]::WriteAllText((Join-Path $target 'tracked.txt'), "clean`n", [Text.UTF8Encoding]::new($false))
            foreach ($step in @(Initialize-B194GitTarget -Target $target -GitExe $gitExe -Environment $cleanGitEnvironment)) { $setup.Add($step) | Out-Null }
            [IO.File]::WriteAllBytes((Join-Path $target '.git/index'), [byte[]](66,49,57,52,0,255,1,2,3))
            $revParse = Invoke-B194Process -Executable $gitExe -Arguments @('-C',$target,'rev-parse','--is-inside-work-tree') -Environment $cleanGitEnvironment
            $status = Invoke-B194Process -Executable $gitExe -Arguments @('-C',$target,'status','--porcelain=v1','--untracked-files=all') -Environment $cleanGitEnvironment
            $setup.Add([pscustomobject]@{ Label = "$($hostCase.Label) rev-parse"; Capture = $revParse; ExpectedExit = 0; Output = 'true' }) | Out-Null
            $setup.Add([pscustomobject]@{ Label = "$($hostCase.Label) corrupt status"; Capture = $status; ExpectedExit = $null; Output = 'failed' }) | Out-Null
            $before = Get-B194Fingerprint $target
            $capture = Invoke-B194Installer -Twin $hostCase.Twin -Target $target -PowerShellExe $hostCase.Host -Environment $cleanGitEnvironment
            $refusals.Add([pscustomobject]@{ Label = $hostCase.Label; Capture = $capture; Before = $before; After = (Get-B194Fingerprint $target) }) | Out-Null
        }

        # Every child surface is now captured; only validation follows.
        foreach ($step in $setup) {
            if ($step.Output -eq 'failed') {
                Add-B194CaptureProblem -Problems $problems -Label $step.Label -Capture $step.Capture
                if ($null -eq $step.Capture.Exit -or $step.Capture.Exit -eq 0) { $problems.Add("$($step.Label): corrupt index status unexpectedly succeeded") | Out-Null }
            } else {
                Add-B194ExpectedProcessProblems -Problems $problems -Label $step.Label -Capture $step.Capture -ExpectedExit $step.ExpectedExit
            }
            if ($step.Output -eq 'true' -and $step.Capture.Out.Trim() -cne 'true') { $problems.Add("$($step.Label): expected exact true, got [$($step.Capture.Out)]") | Out-Null }
        }
        foreach ($case in $refusals) { Add-B194RefusalProblems -Problems $problems -Label $case.Label -Capture $case.Capture -Before $case.Before -After $case.After }
        Assert ($problems.Count -eq 0) ($problems -join "`n")
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

foreach ($twin in @('ps1', 'sh')) {
    if ($twin -eq 'sh' -and -not $bash) { Skip "dirty-tree safety ($twin)" 'no bash on this host'; continue }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Skip "dirty-tree safety ($twin)" 'git is unavailable'; continue }
    It "dirty Git update refuses before mutation and explicit override is observable ($twin)" {
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
            # A normal `git status` refreshes this clean file's cached stat data in .git/index even
            # though the installer subsequently refuses because dirty.txt changed. The preflight
            # must use --no-optional-locks so its own safety check does not mutate the target.
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
            $out = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t
            $installerExit = $LASTEXITCODE
            $fingerprintAfter = Get-B194Fingerprint $t
            Assert ($calibrationExit -eq 0) "ordinary-status calibration failed (exit $calibrationExit): $calibration"
            Assert ($calibration -match 'dirty\.txt') "ordinary-status calibration did not observe dirty.txt: $calibration"
            Assert $calibrationChangedIndex 'ordinary-status calibration did not refresh .git/index; fixture cannot discriminate optional locking'
            Assert ($installerExit -ne 0) "dirty Git target was mutated without refusal. Output:`n$out"
            Assert ($out -match 'commit, stash, or copy') "dirty-tree refusal omitted recovery action. Output:`n$out"
            Assert ([IO.File]::ReadAllText($dirtyPath) -eq $before) 'dirty-tree preflight mutated dirty.txt before refusing'
            Assert ($fingerprintAfter -ceq $fingerprintBefore) 'dirty-tree preflight changed the target fingerprint before refusing'
            $override = Invoke-Installer -Twin $twin -Dist 'dotnet' -Target $t -AllowDirtyTree
            Assert ($LASTEXITCODE -eq 0) "explicit dirty-tree override failed (exit $LASTEXITCODE): $override"
            Assert ($override -match 'override: .*allow-dirty-tree') "dirty-tree override was not named on stdout. Output:`n$override"
        } finally {
            if ($null -eq $priorOptionalLocks) {
                Remove-Item -LiteralPath Env:GIT_OPTIONAL_LOCKS -Force -ErrorAction SilentlyContinue
            } else {
                [Environment]::SetEnvironmentVariable('GIT_OPTIONAL_LOCKS', $priorOptionalLocks, 'Process')
            }
            Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue
        }
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
                # PS5 formats native stderr as a wrapped ErrorRecord. Collapse host-inserted
                # whitespace while retaining an exact content comparison for the refusal words.
                $messageText = (($out -replace '\s+', ' ').Trim())
                $expectedText = (($case.Message -replace '\s+', ' ').Trim())
                Assert ($messageText -match [regex]::Escape($expectedText)) "legal-file refusal message changed. Output:`n$out"
                Assert ($out -notmatch 'Done \(update\)') "failed update printed the success-only completion banner. Output:`n$out"
            } finally { Remove-Item -Recurse -Force $t -ErrorAction SilentlyContinue }
        }
    }
}

exit (Write-TestSummary 'UpdateDelivery.Tests')
