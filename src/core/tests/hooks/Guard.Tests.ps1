# Guard behavioural tests over the shared PowerShell case table.
# For each BLOCKING case: Claude-shaped event must BLOCK (exit 2), Copilot-shaped event must DENY
# (JSON). For each CLEAN case: both shapes must ALLOW. Cases are generated into both surface shapes
# from one content string, so the same input drives both.
#
# Every result is checked against the expected decision, independently of implementation.
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
. (Join-Path $PSScriptRoot 'fixtures\guard-cases.ps1')
$hooks   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$guardPs = Join-Path $hooks 'guard.ps1'

Reset-Tests
$selectedCases = @($GuardCases)
if ($env:GUARD_TEST_POLICY) {
    $selectedCases = @($GuardCases | Where-Object { $_.policy -eq $env:GUARD_TEST_POLICY })
    if ($selectedCases.Count -eq 0) {
        # Exit 111, NOT 1. The mutation harness decides "the mutation was caught" from a non-zero
        # exit, and this suite's normal exit code is its failure COUNT -- so exiting 1 here is
        # byte-identical to "one case failed" and an untagged case would silently convert the red
        # test into a pass. Verified: with the 'secret' tag removed, GuardPatternErrors reported
        # 4 passed while testing nothing. 111 is outside any plausible failure count and the harness
        # rejects it explicitly.
        [Console]::Error.WriteLine("Guard.Tests: GUARD_TEST_POLICY '$($env:GUARD_TEST_POLICY)' matched no cases")
        exit 111
    }
}
if ($selectedCases.Count -eq 0) { [Console]::Error.WriteLine('Guard.Tests: case table is empty'); exit 111 }
foreach ($case in $selectedCases) {
    foreach ($surface in 'Claude','Copilot') {
        $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $case.f $case.c } else { New-CopilotEvent $case.f $case.c }
        $expected = if (-not $case.block) { 'ALLOW' } elseif ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }
        It "guard $expected ($surface): $($case.n)" {
            $rps = Invoke-Hook $guardPs $evt
            Assert-Decision $rps $expected $case.n
        }
    }
}

# apply_patch: each case's patch is sent in the stdin Copilot captured for an apply_patch call
# (fixtures/guard-patch-cases.ps1). A block is exit 2 for the .claude/settings.json copy, whose
# tool_name is Edit, and a JSON deny for every other shape. The reason must name each file the
# patch writes a blocked line to, and no file it writes cleanly.
. (Join-Path $PSScriptRoot 'fixtures\guard-patch-cases.ps1')
$selectedPatchCases = @($GuardPatchCases)
if ($env:GUARD_TEST_POLICY) { $selectedPatchCases = @($GuardPatchCases | Where-Object { $_.policy -eq $env:GUARD_TEST_POLICY }) }
foreach ($case in $selectedPatchCases) {
    $shapes = if ($case.shapes) { @($case.shapes) } else { @('hooks.json') }
    foreach ($shape in $shapes) {
        $evt = New-PatchEvent $shape $case.p
        $expected = if (-not $case.block) { 'ALLOW' } elseif ($shape -eq '.claude/settings.json') { 'BLOCK' } else { 'DENY' }
        It "guard $expected (apply_patch, $shape): $($case.n)" {
            $rps = Invoke-Hook $guardPs $evt
            Assert-Decision $rps $expected $case.n
            $reason = if ($rps.Exit -eq 2) { [string]$rps.Err } elseif ($rps.Out) { [string]($rps.Out | ConvertFrom-Json).permissionDecisionReason } else { '' }
            foreach ($name in @($case.names)) { if ($name) { Assert ($reason.Contains("Blocked write to $name")) "$($case.n): the reason does not name $name -- $reason" } }
            foreach ($name in @($case.notNames)) { if ($name) { Assert (-not $reason.Contains($name)) "$($case.n): the reason names $name, which the patch writes cleanly -- $reason" } }
        }
    }
}
It 'guard ALLOW (Copilot): an unrelated tool call is not read as a patch' {
    $evt = @{ toolName = 'powershell'; toolArgs = @{ command = 'git status'; description = 'Show the working tree status' } } | ConvertTo-Json -Compress -Depth 6
    Assert-Decision (Invoke-Hook $guardPs $evt) 'ALLOW' 'powershell tool'
}
It 'guard DENY (Copilot): a create whose text carries a patch is checked as that create' {
    $evt = New-CopilotEvent 'src\Foo.cs' "*** Begin Patch`n*** Add File: notes.txt`n+x`n*** End Patch`n#pragma warning disable CS8602"
    Assert-Decision (Invoke-Hook $guardPs $evt) 'DENY' 'create carrying patch text'
}

# --- Credential names match whatever the culture: tr-TR folds "I" to a dotless i (U+0131) ---
It 'guard BLOCK (Claude) and DENY (Copilot) under tr-TR: credential literals under API_KEY, CONNECTIONSTRING and CONNECTIONSTRINGS' {
    # The guard runs inside a wrapper that sets tr-TR first; exit 3 means that culture's regex casing did not take, so nothing was examined.
    $wrapper = Join-Path ([IO.Path]::GetTempPath()) ('guard-tr-' + [guid]::NewGuid().ToString('N') + '.ps1')
    $text = "[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::new('tr-TR')`n" +
        "if ([regex]::IsMatch('I', 'i', 'IgnoreCase')) { exit 3 }`n& '" + $guardPs.Replace("'", "''") + "'`nexit `$LASTEXITCODE`n"
    [IO.File]::WriteAllText($wrapper, $text, (New-Object System.Text.UTF8Encoding($true)))
    $value = 'Zq8v' + 'R2mK4tW7xN'   # assembled at run time, as the outgoing-commit guard asks
    $writes = @(
        @{ f = 'src/Client.cs'; c = "const string API_KEY = `"$value`";" }
        @{ f = 'src/Db.cs'; c = "const string CONNECTIONSTRING = `"Server=db;User Id=app;Password=$value;`";" }
        @{ f = 'src/Api/appsettings.json'; c = "{ `"CONNECTIONSTRINGS`": { `"Main`": `"Server=db;User Id=app;Password=$value;`" } }" }
    )
    try {
        foreach ($write in $writes) {
            foreach ($surface in 'Claude', 'Copilot') {
                $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $write.f $write.c } else { New-CopilotEvent $write.f $write.c }
                $r = Invoke-Hook $wrapper $evt
                Assert ($r.Exit -ne 3) 'tr-TR did not take in the wrapper (exit 3), so nothing was examined'
                Assert-Decision $r $(if ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }) "tr-TR, $surface, $($write.f)"
                $reason = if ($r.Exit -eq 2) { [string]$r.Err } else { [string]($r.Out | ConvertFrom-Json).permissionDecisionReason }
                Assert ($reason.Contains('hardcoded credential literal')) "tr-TR, $surface, $($write.f): blocked for another reason -- $reason"
            }
        }
    } finally { Remove-Item -LiteralPath $wrapper -Force -ErrorAction SilentlyContinue }
}

# --- The test/sample exemption reads the written path under the repository the hook belongs to ---
# A checkout that itself sits under folders named Development, test or samples must keep the credential
# check on its source files and the exemption on its own tests. The case table above sends paths that lie
# outside the repository; this puts a copy of the hook inside such a repository (a hook finds its
# repository from its own path), so the repository's own paths are the ones under test.
It 'guard: a repository under Development\test folders keeps the credential check on its source and the exemption on its tests' {
    $base = Join-Path ([IO.Path]::GetTempPath()) ('guard-root-' + [guid]::NewGuid().ToString('N'))
    $root = Join-Path $base 'Development\test\repo'
    $credential = 'var password = "hunter2hunter2";'
    try {
        $hook = Copy-HookInto $guardPs $root
        $writes = @(
            @{ f = "$root\src\AuthService.cs";                         allowed = $false; n = 'an absolute source path' }
            @{ f = ($root.Replace('\', '/') + '/src/AuthService.cs');  allowed = $false; n = 'an absolute source path with forward slashes' }
            @{ f = 'src\AuthService.cs';                               allowed = $false; n = 'a relative source path' }
            @{ f = "$root\tests\..\src\AuthService.cs";                allowed = $false; n = 'an absolute path that leaves tests\ through ..' }
            @{ f = $root.ToUpperInvariant() + '\src\AuthService.cs';   allowed = $false; n = 'an absolute source path in another letter case' }
            @{ f = "$root\tests\AuthServiceTests.cs";                  allowed = $true;  n = 'an absolute test path' }
            @{ f = "$root\src\Api.UnitTests\AuthClient.cs";            allowed = $true;  n = 'an absolute path in a UnitTests folder' }
            @{ f = "$root\src\..\tests\AuthServiceTests.cs";           allowed = $true;  n = 'an absolute path that enters tests\ through ..' }
        )
        foreach ($write in $writes) {
            foreach ($surface in 'Claude', 'Copilot') {
                $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $write.f $credential } else { New-CopilotEvent $write.f $credential }
                $expected = if ($write.allowed) { 'ALLOW' } elseif ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }
                Assert-Decision (Invoke-Hook $hook $evt) $expected "$($write.n) ($surface)"
            }
        }
        $patch = "*** Begin Patch`n*** Add File: $root\src\AuthService.cs`n+$credential`n*** End Patch`n"
        Assert-Decision (Invoke-Hook $hook (New-PatchEvent 'hooks.json' $patch)) 'DENY' 'an apply_patch Add File: at an absolute source path'
    } finally { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue }
}

# The path is read by its text alone. One the hook cannot read as a path under its repository exempts nothing:
# a leading ~ (a home folder, which the host does not expand), a URI, a drive-relative, rooted, UNC or device
# path, a stream suffix, or a '..' out of the repository. \\?\C:\... is the drive path C:\... .
It 'guard: a path the hook cannot read as under its repository is never exempt, and a \\?\ drive path is read as the drive path' {
    $base = Join-Path ([IO.Path]::GetTempPath()) ('guard-root-' + [guid]::NewGuid().ToString('N'))
    $root = Join-Path $base 'Development\test\shop'
    $drive = $root.Substring(0, 2)
    $credential = 'var password = "hunter2hunter2";'
    try {
        $hook = Copy-HookInto $guardPs $root
        $writes = @(
            @{ f = '~\Development\test\shop\src\AuthService.cs';       allowed = $false; n = 'a ~ path that spells test folders' }
            @{ f = '~/tests/AuthServiceTests.cs';                      allowed = $false; n = 'a ~ path to a test file' }
            @{ f = 'file:///' + $root.Replace('\', '/') + '/tests/AuthServiceTests.cs'; allowed = $false; n = 'a file: URI to a test file' }
            @{ f = $drive + 'tests\AuthServiceTests.cs';               allowed = $false; n = 'a drive-relative path' }
            @{ f = '\tests\AuthServiceTests.cs';                       allowed = $false; n = 'a rooted path without a drive' }
            @{ f = '/tests/AuthServiceTests.cs';                       allowed = $false; n = 'a rooted path with a forward slash' }
            @{ f = '\\fileserver\share\tests\AuthServiceTests.cs';     allowed = $false; n = 'a UNC path to a test file' }
            @{ f = '\\.\' + "$root\tests\AuthServiceTests.cs";         allowed = $false; n = 'a device path to a test file' }
            @{ f = '\\?\UNC\fileserver\share\tests\AuthServiceTests.cs'; allowed = $false; n = 'a \\?\UNC path to a test file' }
            @{ f = "$root\tests\AuthServiceTests.cs:notes";            allowed = $false; n = 'a test file with a stream suffix' }
            @{ f = '..\shop\tests\AuthServiceTests.cs';                allowed = $false; n = 'a relative path that climbs out of the repository and back in' }
            @{ f = '\\?\' + "$root\src\AuthService.cs";                allowed = $false; n = 'a \\?\ drive path to source' }
            @{ f = '\\?\' + "$root\tests\AuthServiceTests.cs";         allowed = $true;  n = 'a \\?\ drive path to a test file' }
            @{ f = '\\?\' + "$root\src\..\tests\AuthServiceTests.cs";  allowed = $true;  n = 'a \\?\ drive path that enters tests\ through ..' }
        )
        foreach ($write in $writes) {
            foreach ($surface in 'Claude', 'Copilot') {
                $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $write.f $credential } else { New-CopilotEvent $write.f $credential }
                $expected = if ($write.allowed) { 'ALLOW' } elseif ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }
                Assert-Decision (Invoke-Hook $hook $evt) $expected "$($write.n) ($surface)"
            }
        }
    } finally { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue }
}

# The hook reads its stdin as UTF-8, which is what the agents send, not through the console's input code page
# (437, 850, 1252): decoded that way a non-ASCII folder name no longer matches the repository's root, and a
# genuine test file is refused. This is red only where the console is not UTF-8 (the CP437 leg).
It 'guard: a test file under a repository folder with a non-ASCII name is exempt, and its source is not' {
    $base = Join-Path ([IO.Path]::GetTempPath()) ('guard-root-' + [guid]::NewGuid().ToString('N'))
    $root = Join-Path $base ('M' + [char]0x00FC + 'ller\shop')
    $credential = 'var password = "hunter2hunter2";'
    try {
        $hook = Copy-HookInto $guardPs $root
        foreach ($surface in 'Claude', 'Copilot') {
            $test = "$root\tests\AuthServiceTests.cs"; $source = "$root\src\AuthService.cs"
            $evtTest = if ($surface -eq 'Claude') { New-ClaudeEvent $test $credential } else { New-CopilotEvent $test $credential }
            $evtSource = if ($surface -eq 'Claude') { New-ClaudeEvent $source $credential } else { New-CopilotEvent $source $credential }
            Assert-Decision (Invoke-Hook $hook $evtTest) 'ALLOW' "a test file under $($root.Substring($base.Length)) ($surface)"
            Assert-Decision (Invoke-Hook $hook $evtSource) $(if ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }) "a source file under $($root.Substring($base.Length)) ($surface)"
        }
    } finally { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue }
}

# --- A hostile write must not stall the hook past its time limit ---
# Copilot's hooks.json gives the hook 10 s and Claude Code 60 s; past either the write goes ahead unchecked.
# Invoke-Hook waits without end, so these runs wait up to $stallLimitMs and kill the hook past it. Each
# payload is sized so that the quadratic pattern needs several times that limit on either host, while a
# linear scan of it finishes in a second or two.
$stallLimitMs = 15000
function Invoke-HookBounded {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Json, [int]$TimeoutMs = 15000)
    Assert-PowerShellSubject $Path
    $stdinFile = [IO.Path]::GetTempFileName()
    $stdoutFile = [IO.Path]::GetTempFileName()
    $stderrFile = [IO.Path]::GetTempFileName()
    $process = $null
    try {
        [IO.File]::WriteAllText($stdinFile, $Json, (New-Object System.Text.UTF8Encoding($false)))
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $process = Start-Process -FilePath (Get-PsExe) -ArgumentList ('"-NoProfile" "-ExecutionPolicy" "Bypass" "-File" "' + $Path + '"') -NoNewWindow -PassThru `
            -RedirectStandardInput $stdinFile -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
        $null = $process.Handle   # keeps the exit code readable on Windows PowerShell 5.1
        $finished = $process.WaitForExit($TimeoutMs)
        $clock.Stop()
        if (-not $finished) { try { $process.Kill() } catch { }; $process.WaitForExit() }
        return [pscustomobject]@{ TimedOut = (-not $finished); Seconds = [math]::Round($clock.Elapsed.TotalSeconds, 1); Exit = $(if ($finished) { [int]$process.ExitCode } else { -1 }) }
    } finally {
        if ($process) { $process.Dispose() }
        foreach ($tempFile in $stdinFile, $stdoutFile, $stderrFile) { if (Test-Path -LiteralPath $tempFile) { [IO.File]::Delete($tempFile) } }
    }
}
It 'guard: a connection-string literal that never closes, with 60000 password keys, is decided inside the time limit' {
    $content = 'var connectionString = "' + ('password=abcd;' * 60000)
    $r = Invoke-HookBounded $guardPs (New-ClaudeEvent 'src/AuthService.cs' $content) $stallLimitMs
    Assert (-not $r.TimedOut) "the hook was still scanning after $($stallLimitMs / 1000) s on a $([int]($content.Length / 1024)) KB write and was killed"
    Assert ($r.Exit -eq 0) "the hook exited $($r.Exit) after $($r.Seconds) s on a write with no credential literal in it"
}
# Each opening follows other text on its line: a line that starts with [ also reaches the [Ignore] pattern,
# which is quadratic on such lines too (a separate, known stall) and would hide the Skip pattern under test.
It 'guard: 30000 unclosed [Fact( openings, each after other text on its line, are decided inside the time limit' {
    $content = "x[Fact(`n" * 30000
    $r = Invoke-HookBounded $guardPs (New-ClaudeEvent 'src/Foo.cs' $content) $stallLimitMs
    Assert (-not $r.TimedOut) "the hook was still scanning after $($stallLimitMs / 1000) s on a $([int]($content.Length / 1024)) KB write and was killed"
    Assert ($r.Exit -eq 0) "the hook exited $($r.Exit) after $($r.Seconds) s on a write with no skip in it"
}
# A path with a ~ made the hook ask the file system to expand an 8.3 name; for an unreachable host that waited
# ~21 s per path (192.0.2.0/24 is TEST-NET-1, never routed). The path is now read by its text alone.
It 'guard: a write to a UNC path with a ~ segment is decided inside the time limit' {
    $r = Invoke-HookBounded $guardPs (New-ClaudeEvent '\\192.0.2.14\share\TESTS~1\AuthService.cs' 'var password = "hunter2hunter2";') $stallLimitMs
    Assert (-not $r.TimedOut) "the hook was still resolving the path after $($stallLimitMs / 1000) s and was killed"
    Assert ($r.Exit -eq 2) "the hook exited $($r.Exit) after $($r.Seconds) s on a credential literal at a path outside the repository"
}
It 'guard: an apply_patch that adds three files under a UNC path with a ~ segment is decided inside the time limit' {
    # A different host in each section: Windows remembers an unreachable one, which would answer the later sections at once.
    $patch = "*** Begin Patch`n" + (-join @(1..3 | ForEach-Object { "*** Add File: \\192.0.2.$($_ + 20)\share\TESTS~$_\F$_.cs`n+var x = $_;`n" })) +
        "*** Add File: src\AuthService.cs`n+var password = `"hunter2hunter2`";`n*** End Patch`n"
    $r = Invoke-HookBounded $guardPs (New-PatchEvent '.claude/settings.json' $patch) $stallLimitMs
    Assert (-not $r.TimedOut) "the hook was still resolving the paths after $($stallLimitMs / 1000) s and was killed"
    Assert ($r.Exit -eq 2) "the hook exited $($r.Exit) after $($r.Seconds) s on a patch with a credential literal in it"
}
# The other scans that grew faster than their input. Each payload is a repeated fragment that the old pattern
# re-read to the end of the text from every repetition (or, for the password keys, that the old code collected
# into a growing array before it looked at the first); none is capped, so a longer real input is read the same.
$stallCases = @(
    @{ n = '200000 blank lines in a .cs file';                             f = 'src/Foo.cs';        c = ("`n" * 200000);                                                  exit = 0 }
    @{ n = '30000 lines that each open an unclosed [Fact( in a .cs file';  f = 'src/Foo.cs';        c = ("[Fact(`n" * 30000);                                             exit = 0 }
    @{ n = 'a closed connection string with 150000 password keys';         f = 'src/AuthService.cs'; c = ('var connectionString = "' + ('password=abcd;' * 150000) + '"');  exit = 2 }
    @{ n = '20000 SAS sv=...& fragments';                                  f = 'src/Storage.cs';    c = ('sv=2022-11-02&' * 20000);                                       exit = 0 }
    @{ n = '12000 SAS sig= fragments, each followed by an &';              f = 'src/Storage.cs';    c = (('sig=' + ('A' * 40) + '&') * 12000);                            exit = 0 }
    @{ n = 'one SAS sig= value of 100000 characters';                      f = 'src/Storage.cs';    c = ('sig=' + ('A' * 100000));                                        exit = 0 }
    @{ n = 'a credential literal of 1500000 < characters';                 f = 'src/AuthService.cs'; c = ('var password = "' + ('<' * 1500000) + '"');                     exit = 2 }
)
foreach ($stall in $stallCases) {
    It "guard: $($stall.n) is decided inside the time limit" {
        $r = Invoke-HookBounded $guardPs (New-ClaudeEvent $stall.f $stall.c) $stallLimitMs
        Assert (-not $r.TimedOut) "the hook was still scanning after $($stallLimitMs / 1000) s on a $([int]($stall.c.Length / 1024)) KB write and was killed"
        Assert ($r.Exit -eq $stall.exit) "the hook exited $($r.Exit) after $($r.Seconds) s; expected $($stall.exit)"
    }
}

# Every case above pipes stdin straight into guard.ps1. The agent host does not: the registration
# carries "shell": "powershell", so the whole command STRING runs inside an outer PowerShell, and
# `-Command` collapses a failing native command's exit code to 1. The host then reads a non-blocking
# error and performs the write anyway. Launch the registered command the way the host does, reading
# it from the registration file THIS host uses -- never the other host's (PowerShell topology).
$installRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$registrationRelative = if ($PSVersionTable.PSVersion.Major -ge 6) { '.claude/settings.json' } else { '.claude/settings.windows.json' }
$expectedInterpreter = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'powershell' }
$registeredCase = "registered guard command blocks with exit 2 through the host's outer -Command shell ($registrationRelative)"
# src/core carries only settings.windows.json; the pwsh registration is a per-stack whole file, so the
# authoring source tree has nothing to launch under PowerShell 7. A built dist always has both
# (validate-dist resolves every registration), so this never skips where CI runs it.
if (-not (Test-Path -LiteralPath (Join-Path $installRoot $registrationRelative) -PathType Leaf)) {
    Skip $registeredCase "no $registrationRelative in this tree (authoring source layout); the dist legs launch it"
} else { It $registeredCase {
    $registrationPath = Join-Path $installRoot $registrationRelative
    Assert (Test-Path -LiteralPath $registrationPath -PathType Leaf) "registration file not found: $registrationRelative"
    $registration = [IO.File]::ReadAllText($registrationPath) | ConvertFrom-Json
    $registered = @(foreach ($group in @($registration.hooks.PreToolUse)) {
        foreach ($entry in @($group.hooks)) { if ([string]$entry.command -match 'guard\.ps1') { [string]$entry.command } }
    })
    Assert ($registered.Count -eq 1) "expected exactly one registered guard command in $registrationRelative, found $($registered.Count)"
    $command = $registered[0]
    Assert ((($command -split '\s+')[0]) -ceq $expectedInterpreter) "$registrationRelative registers '$((($command -split '\s+')[0]))', not '$expectedInterpreter'; this leg would relaunch the other PowerShell host"
    # The outgoing-commit guard refuses a literal key shape, so assemble one at run time.
    $keyShaped = 'AKIA' + '1234567890ABCDEF'
    Push-Location $installRoot
    try {
        $blocked = Invoke-RawProcess -FileName (Get-PsExe) -Arguments @('-NoProfile', '-Command', $command) `
            -Stdin (New-ClaudeEvent 'sample.env' ('AWS_ACCESS_KEY_ID=' + $keyShaped))
        Assert ($blocked.Exit -eq 2) "blocked write exited $($blocked.Exit) through the outer -Command shell, not 2; the host reads anything but 2 as a non-blocking error and writes the file anyway. stderr: $($blocked.Err.Trim())"
        Assert ($blocked.Err -match 'Blocked write to sample\.env') "the outer -Command shell lost the block reason on stderr: $($blocked.Err.Trim())"
        $allowed = Invoke-RawProcess -FileName (Get-PsExe) -Arguments @('-NoProfile', '-Command', $command) `
            -Stdin (New-ClaudeEvent 'notes.md' 'nothing to declare here')
        Assert ($allowed.Exit -eq 0) "clean write exited $($allowed.Exit) through the outer -Command shell, not 0; every write would be reported as a hook error. stderr: $($allowed.Err.Trim())"
    } finally { Pop-Location }
} }

# Empty stdin and malformed JSON must degrade-safe to ALLOW (exit 0), never crash.
It 'guard.ps1 empty stdin -> allow'     { Assert-Decision (Invoke-Hook $guardPs '')             'ALLOW' 'empty' }
It 'guard.ps1 malformed JSON degrades safely' {
    Assert-Decision (Invoke-Hook $guardPs 'not json {') 'ALLOW' 'malformed'
}

exit (Write-TestSummary 'Guard.Tests (PowerShell)')
