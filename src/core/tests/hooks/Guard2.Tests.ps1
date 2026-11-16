# The second half of the guard cases, in its own file so the two halves run in parallel: the case table on the
# Copilot surface, then the time-limit and registered-command cases. Guard.Tests.ps1 runs the table on the Claude
# surface, the apply_patch cases and the cases before these; this file sets $GuardTableSurface and dot-sources it,
# so the table, its policy filter and the shared helpers are read in one place.
$GuardTableSurface = 'Copilot'
. (Join-Path $PSScriptRoot 'Guard.Tests.ps1')

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
        return [pscustomobject]@{ TimedOut = (-not $finished); Seconds = [math]::Round($clock.Elapsed.TotalSeconds, 1); Exit = $(if ($finished) { [int]$process.ExitCode } else { -1 })
            Out = $(if ($finished) { [IO.File]::ReadAllText($stdoutFile) } else { '' }); Err = $(if ($finished) { [IO.File]::ReadAllText($stderrFile) } else { '' }) }
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
# A whole-file write is also compared with the file on disk, so a large write over a large file must be decided inside the
# limit too: one pragma in each (the common case), and tens of thousands in each (every one counted in both texts).
$pragma = "#pragma warning disable CS0618`n"
$diskStallCases = @(
    @{ n = 'a 2 MB write holding one #pragma over a 2 MB file holding one'; old = ($pragma + ("var a = 1;`n" * 170000)); new = ($pragma + ("var b = 2;`n" * 180000)); exit = 0 }
    @{ n = 'a write of 40000 #pragma lines over a file of 40000';          old = ($pragma * 40000);                          new = ($pragma * 40000);                          exit = 0 }
    @{ n = 'a write of 40001 #pragma lines over a file of 40000';          old = ($pragma * 40000);                          new = ($pragma * 40001);                          exit = 2 }
)
foreach ($stall in $diskStallCases) {
    It "guard: $($stall.n) is decided inside the time limit" {
        $scratch = $null
        try {
            $path = New-ExistingFile ([ref]$scratch) 'src\Foo.cs' $stall.old
            $r = Invoke-HookBounded $guardPs (New-ClaudeEvent $path $stall.new) $stallLimitMs
            Assert (-not $r.TimedOut) "the hook was still scanning after $($stallLimitMs / 1000) s on a $([int]($stall.new.Length / 1024)) KB write over a $([int]($stall.old.Length / 1024)) KB file and was killed"
            Assert ($r.Exit -eq $stall.exit) "the hook exited $($r.Exit) after $($r.Seconds) s; expected $($stall.exit)"
        } finally { if ($scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue } }
    }
}
# Every Add File section over the same large file used to read that file again and scan it for each pattern the section
# matched (200 sections over one 3.9 MB file took 45 s). The file is read once per event and its directives are counted
# once per pattern, so these decide inside Copilot's 10 s: 200 sections over one file just under the 2 MB the guard reads,
# first each keeping a pragma, then each keeping all six suppressions and skips a .spec.ts file can hold.
function New-AddFilePatch([string]$Path, [string[]]$Lines, [int]$Sections) {
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.Append("*** Begin Patch`n")
    for ($i = 1; $i -le $Sections; $i++) {
        [void]$builder.Append("*** Add File: $Path`n")
        foreach ($line in $Lines) { [void]$builder.Append("+$line`n") }
        [void]$builder.Append("+const v$i = $i;`n")
    }
    [void]$builder.Append("*** End Patch`n")
    $builder.ToString()
}
$directives = @('// eslint-disable-next-line no-console', '// @ts-ignore', "xit('a', () => {});", "it.skip('b', () => {});", "test.concurrent.skip('c', async () => {});", "test.skip('d', () => {});")
$directiveBlock = ($directives -join "`n") + "`n" + ("const filler = 1;`n" * 3)
$sectionCases = @(
    @{ n = '200 Add File sections over one 2 MB .cs file, each keeping its #pragma';  file = 'src\Legacy.cs';        old = ($pragma + ("var a = 1;`n" * 170000));                                   lines = @('#pragma warning disable CS0618') }
    @{ n = '200 Add File sections over one 2 MB .spec.ts file, each keeping all six suppressions and skips'; file = 'src\legacy.spec.ts'; old = ($directiveBlock * [int](1900000 / $directiveBlock.Length)); lines = $directives }
)
foreach ($case in $sectionCases) {
    It "guard: $($case.n) is decided inside 10 s" {
        $scratch = $null
        try {
            $path = New-ExistingFile ([ref]$scratch) $case.file $case.old
            $r = Invoke-HookBounded $guardPs (New-PatchEvent 'hooks.json' (New-AddFilePatch $path $case.lines 200)) 10000
            Assert (-not $r.TimedOut) "the hook was still scanning after 10 s on 200 sections over a $([int]($case.old.Length / 1024)) KB file and was killed"
            Assert ((Get-Decision $r) -eq 'ALLOW') "the hook decided $(Get-Decision $r) after $($r.Seconds) s; every section keeps what the file holds"
        } finally { if ($scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue } }
    }
}
# A patch section's hunks are compared as one text against one text, so a patch of tens of thousands of hunks is counted
# twice per pattern, not twice per hunk (20,000 hunks that each rewrite two directives took 13 to 20 s, and 14,000 that
# each rewrite three, beside one that adds a pragma, outlasted 10 s). Each of these decides inside Copilot's 10 s.
$keepTwo = "@@`n-#pragma warning disable CS0618`n-[Ignore]`n+#pragma warning disable CS0618`n+[Ignore]`n"
$keepThree = "@@`n-#pragma warning disable CS0618`n-[Ignore]`n-[Fact(Skip=`"x`")]`n+#pragma warning disable CS0618`n+[Ignore]`n+[Fact(Skip=`"x`")]`n"
$hunkCases = @(
    @{ n = '20000 hunks of one update, each rewriting a #pragma and an [Ignore]';                       p = ("*** Begin Patch`n*** Update File: src\Foo.cs`n" + ($keepTwo * 20000) + "*** End Patch`n"); decision = 'ALLOW' }
    @{ n = '14000 hunks of one update rewriting three directives each, and one hunk that adds a #pragma'; p = ("*** Begin Patch`n*** Update File: src\Foo.cs`n" + ($keepThree * 14000) + "@@`n-var x = 1;`n+#pragma warning disable CS0612`n*** End Patch`n"); decision = 'DENY' }
)
foreach ($case in $hunkCases) {
    It "guard: $($case.n) is decided inside 10 s" {
        $r = Invoke-HookBounded $guardPs (New-PatchEvent 'hooks.json' $case.p) 10000
        Assert (-not $r.TimedOut) "the hook was still scanning after 10 s on a $([int]($case.p.Length / 1024)) KB patch and was killed"
        Assert ((Get-Decision $r) -eq $case.decision) "the hook decided $(Get-Decision $r) after $($r.Seconds) s; expected $($case.decision)"
    }
}
# Looking for the */ that ends a directive's comment, and for the /* before it, is bounded to its 8-line window, so a text
# of 100,000 lines that each open a block eslint-disable and never close one is counted in the time its size takes (the
# unbounded search was quadratic: 10 s for an edit of 100,000 lines on pwsh, 29 s on Windows PowerShell 5.1, and 17 s and
# 45 s for a write that keeps a 95,000-line file). Each of these decides inside Copilot's 10 s.
$openLine = "/* eslint-disable r`n"
It 'guard BLOCK (Claude): an edit that adds 140000 lines each opening a block eslint-disable with no */ is decided inside 10 s' {
    $r = Invoke-HookBounded $guardPs (New-ClaudeEditEvent 'src/app.ts' $openLine ($openLine * 140000)) 10000
    Assert (-not $r.TimedOut) 'the hook was still scanning after 10 s on a 2.7 MB edit and was killed'
    Assert ((Get-Decision $r) -eq 'BLOCK') "the hook decided $(Get-Decision $r) after $($r.Seconds) s; expected BLOCK"
}
It 'guard ALLOW (Claude): a whole-file write that keeps a 1.9 MB file of 95000 lines each opening a block eslint-disable is decided inside 10 s' {
    $scratch = $null
    try {
        $path = New-ExistingFile ([ref]$scratch) 'src\app.ts' ($openLine * 95000)
        $r = Invoke-HookBounded $guardPs (New-ClaudeEvent $path ($openLine * 95000)) 10000
        Assert (-not $r.TimedOut) 'the hook was still scanning after 10 s on a 1.9 MB write over a 1.9 MB file and was killed'
        Assert ((Get-Decision $r) -eq 'ALLOW') "the hook decided $(Get-Decision $r) after $($r.Seconds) s; expected ALLOW"
    } finally { if ($scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue } }
}
# A folder can be case-sensitive (fsutil file setCaseSensitiveInfo), where Legacy.cs and legacy.cs are two files. The disk text
# and its directives are read by the exact spelling of the path, so an Add File of legacy.cs is not compared with the disk copy
# of Legacy.cs. This needs the NTFS flag on a scratch folder, which a host may refuse; it is skipped there.
$caseCase = 'guard DENY (Copilot): in a case-sensitive folder an Add File of legacy.cs is not compared with the disk copy of Legacy.cs'
$caseFolder = Join-Path ([IO.Path]::GetTempPath()) ('guard-case-' + [guid]::NewGuid().ToString('N'))
$caseSensitive = $false
try {
    $null = New-Item -ItemType Directory -Force -Path $caseFolder
    $null = & fsutil file setCaseSensitiveInfo $caseFolder enable 2>&1
    $caseSensitive = ($LASTEXITCODE -eq 0) -and ([string](& fsutil file queryCaseSensitiveInfo $caseFolder 2>&1) -match 'is enabled')
} catch { $caseSensitive = $false }
if (-not $caseSensitive) {
    Remove-Item -LiteralPath $caseFolder -Recurse -Force -ErrorAction SilentlyContinue
    Skip $caseCase 'this host would not make a scratch folder case-sensitive (fsutil file setCaseSensitiveInfo)'
} else { It $caseCase {
    try {
        [IO.File]::WriteAllText((Join-Path $caseFolder 'Legacy.cs'), "#pragma warning disable CS0618`nvar a = 1;`n", (New-Object System.Text.UTF8Encoding($false)))
        $upper = Join-Path $caseFolder 'Legacy.cs'; $lower = Join-Path $caseFolder 'legacy.cs'
        $patch = "*** Begin Patch`n*** Add File: $upper`n+#pragma warning disable CS0618`n+var a = 2;`n*** Add File: $lower`n+#pragma warning disable CS0618`n+var a = 2;`n*** End Patch`n"
        $r = Invoke-Hook $guardPs (New-PatchEvent 'hooks.json' $patch)
        Assert-Decision $r 'DENY' 'Add File of Legacy.cs, then of legacy.cs, each adding the pragma'
        $reason = [string]($r.Out | ConvertFrom-Json).permissionDecisionReason
        Assert ($reason.Contains("Blocked write to $lower")) "legacy.cs, which has no copy on disk, is not named -- $reason"
        Assert (-not $reason.Contains("Blocked write to $upper")) "Legacy.cs, which keeps the pragma its disk copy holds, is named -- $reason"
    } finally { Remove-Item -LiteralPath $caseFolder -Recurse -Force -ErrorAction SilentlyContinue }
} }
# Password values are counted for the whole event, and a write that holds more than 500 is blocked with a message to write
# it in parts: each one costs about 0.1 ms to check, so 90,000 keyed password="__AAAAAA__"; assignments (1.9 MB) took
# 12 to 15 s. A connection string with no key before it is read only when its literal holds two or more pairs, or one pair
# that is a piece of a longer string, so 140,000 "x";pwd=__A__; pairs between literals are not candidates at all. Each of
# these decides inside Copilot's 10 s.
$credentialStalls = @(
    @{ n = '140000 "x";pwd=__A__; pairs between literals'; c = ('"x";pwd=__A__;' * 140000); surface = 'Claude'; decision = 'ALLOW' }
    @{ n = '70000 "x";pwd=__A__; pairs between literals, then a keyed password'; c = (('"x";pwd=__A__;' * 70000) + 'var password = "hunter2hunter2";'); surface = 'Copilot'; decision = 'DENY' }
    @{ n = '90000 keyed password="__AAAAAA__"; assignments'; c = ('password="__AAAAAA__";' * 90000); surface = 'Claude'; decision = 'BLOCK'; reason = 'too many to check inside the hook' }
    @{ n = 'one keyed literal of 233000 Pwd=$(A); pairs, then a real credential'; c = ('var connectionString = "' + ('Pwd=$(A);' * 233000) + '";' + 'var password = "hunter2hunter2";'); surface = 'Copilot'; decision = 'DENY'; reason = 'too many to check inside the hook'; limit = 5000 }
    # The cap counts a password value once, wherever the passes and the pairs of a match reach it: 250 release-token values
    # fit in each shape that reads a value more than once, 500 fit, and the 501st blocks.
    @{ n = 'a ConnectionStrings section of 250 #{P}# token entries'; c = ('{"ConnectionStrings":{' + ((1..250 | ForEach-Object { '"C' + $_ + '":"Server=s;Password=#{P}#"' }) -join ',') + '}}'); surface = 'Claude'; decision = 'ALLOW' }
    @{ n = '250 keyed connectionString = "...#{P}#" lines'; c = ((1..250 | ForEach-Object { 'var connectionString = "Server=s;Password=#{P}#";' }) -join "`n"); surface = 'Copilot'; decision = 'ALLOW' }
    @{ n = 'one keyed literal of 250 Password=#{P}#; token pairs'; c = ('var connectionString = "' + ('Password=#{P}#;' * 250) + '";'); surface = 'Claude'; decision = 'ALLOW' }
    @{ n = 'a ConnectionStrings section of 500 #{P}# token entries'; c = ('{"ConnectionStrings":{' + ((1..500 | ForEach-Object { '"C' + $_ + '":"Server=s;Password=#{P}#"' }) -join ',') + '}}'); surface = 'Copilot'; decision = 'ALLOW' }
    @{ n = 'a ConnectionStrings section of 501 #{P}# token entries'; c = ('{"ConnectionStrings":{' + ((1..501 | ForEach-Object { '"C' + $_ + '":"Server=s;Password=#{P}#"' }) -join ',') + '}}'); surface = 'Claude'; decision = 'BLOCK'; reason = 'too many to check inside the hook' }
    @{ n = 'one keyed literal of 501 Password=#{P}#; token pairs'; c = ('var connectionString = "' + ('Password=#{P}#;' * 501) + '";'); surface = 'Copilot'; decision = 'DENY'; reason = 'too many to check inside the hook' }
    # Quote-joined pieces and long runs of key=value text, which the one-pair reading looks at around each quote: linear in the text.
    @{ n = '60000 "Password=#{P}#;" + "k=v;" + pieces'; c = ('var cs = ' + ('"Password=#{P}#;" + "k=v;" + ' * 60000) + '"";'); surface = 'Claude'; decision = 'BLOCK'; reason = 'too many to check inside the hook' }
    @{ n = '80000 "k=v;" + pieces, then a Password piece without a trailing ;'; c = ('var cs = ' + ('"k=v;" + ' * 80000 + '"Password=hunter2hunter2";')); surface = 'Copilot'; decision = 'DENY' }
    @{ n = 'a 900 KB line of a=b pairs, then " + "Password=hunter2hunter2"'; c = ('var cs = "' + ('a=b ' * 225000) + '" + "Password=hunter2hunter2";'); surface = 'Claude'; decision = 'BLOCK' }
    @{ n = 'a 900 KB line of a=b pairs, then " + "x" with no password'; c = ('var cs = "' + ('a=b ' * 225000) + '" + "x";'); surface = 'Copilot'; decision = 'ALLOW' }
    @{ n = '40000 .Append( calls with a one-pair literal and a placeholder'; c = ('sb.Append("Password=<from-vault>;");' * 40000); surface = 'Claude'; decision = 'BLOCK'; reason = 'too many to check inside the hook' }
)
foreach ($stall in $credentialStalls) {
    $limitMs = if ($stall.limit) { $stall.limit } else { 10000 }
    It "guard: $($stall.n) is decided inside $($limitMs / 1000) s" {
        $evt = if ($stall.surface -eq 'Claude') { New-ClaudeEvent 'src/Db.cs' $stall.c } else { New-CopilotEvent 'src/Db.cs' $stall.c }
        $r = Invoke-HookBounded $guardPs $evt $limitMs
        Assert (-not $r.TimedOut) "the hook was still scanning after $($limitMs / 1000) s on a $([int]($stall.c.Length / 1024)) KB write and was killed"
        $got = Get-Decision $r
        Assert ($got -eq $stall.decision) "the hook decided $got after $($r.Seconds) s; expected $($stall.decision)"
        if ($stall.reason) { Assert (([string]$r.Err + [string]$r.Out).Contains($stall.reason)) "the block reason does not say the write holds too many values to check -- $($r.Err)$($r.Out)" }
    }
}

# Every case above pipes stdin straight into guard.ps1. The agent host does not: the registration
# carries "shell": "powershell", so the whole command STRING runs inside an outer PowerShell, and
# `-Command` collapses a failing native command's exit code to 1. The host then reads a non-blocking
# error and performs the write anyway. Launch the registered command the way the host does, reading
# it from the registration file the host reads.
$installRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$registrationRelative = '.claude/settings.json'
$expectedInterpreter = 'pwsh'
$registeredCase = "registered guard command blocks with exit 2 through the host's outer -Command shell ($registrationRelative)"
# The registration is a per-stack whole file, so the authoring source tree src/core has nothing to launch. A built
# dist always has it (validate-dist resolves every registration), so this never skips where CI runs it.
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
    $interpreter = (($command -replace '^\s*if \(\$env:CLAUDE_PROJECT_DIR\) \{[^}]*\}\s*;\s*', '') -split '\s+')[0]
    Assert ($interpreter -ceq $expectedInterpreter) "$registrationRelative registers '$interpreter', not '$expectedInterpreter'; this leg would relaunch the other PowerShell host"
    # The outgoing-commit guard refuses a literal key shape, so assemble one at run time.
    $keyShaped = 'AKIA' + '1234567890ABCDEF'
    # The registered command reads CLAUDE_PROJECT_DIR; a test run inside an agent session inherits that
    # session's value, so every launch below sets or clears it itself.
    $ambientProjectDir = $env:CLAUDE_PROJECT_DIR
    Push-Location $installRoot
    try {
        $env:CLAUDE_PROJECT_DIR = $null
        $blocked = Invoke-RawProcess -FileName (Get-PsExe) -Arguments @('-NoProfile', '-Command', $command) `
            -Stdin (New-ClaudeEvent 'sample.env' ('AWS_ACCESS_KEY_ID=' + $keyShaped))
        Assert ($blocked.Exit -eq 2) "blocked write exited $($blocked.Exit) through the outer -Command shell, not 2; the host reads anything but 2 as a non-blocking error and writes the file anyway. stderr: $($blocked.Err.Trim())"
        Assert ($blocked.Err -match 'Blocked write to sample\.env') "the outer -Command shell lost the block reason on stderr: $($blocked.Err.Trim())"
        $allowed = Invoke-RawProcess -FileName (Get-PsExe) -Arguments @('-NoProfile', '-Command', $command) `
            -Stdin (New-ClaudeEvent 'notes.md' 'nothing to declare here')
        Assert ($allowed.Exit -eq 0) "clean write exited $($allowed.Exit) through the outer -Command shell, not 0; every write would be reported as a hook error. stderr: $($allowed.Err.Trim())"
    } finally { Pop-Location; $env:CLAUDE_PROJECT_DIR = $ambientProjectDir }
} }

# Claude Code starts a hook in the session's current directory, which the agent's own Set-Location
# moves, and exports the session root as CLAUDE_PROJECT_DIR. Launched from a subfolder the registered
# command must still find guard.ps1; a relative -File alone does not, and the write goes ahead.
$subfolderCase = "registered guard command blocks when the session directory is a subfolder ($registrationRelative)"
if (-not (Test-Path -LiteralPath (Join-Path $installRoot $registrationRelative) -PathType Leaf)) {
    Skip $subfolderCase "no $registrationRelative in this tree (authoring source layout); the dist legs launch it"
} else { It $subfolderCase {
    $registration = [IO.File]::ReadAllText((Join-Path $installRoot $registrationRelative)) | ConvertFrom-Json
    $command = [string]@(foreach ($group in @($registration.hooks.PreToolUse)) { foreach ($entry in @($group.hooks)) { if ([string]$entry.command -match 'guard\.ps1') { $entry.command } } })[0]
    $subfolder = Join-Path $installRoot 'docs'
    Assert (Test-Path -LiteralPath $subfolder -PathType Container) 'this tree has no docs folder to stand in for the subfolder'
    $ambientProjectDir = $env:CLAUDE_PROJECT_DIR
    Push-Location $subfolder
    try {
        $env:CLAUDE_PROJECT_DIR = $installRoot
        $blocked = Invoke-RawProcess -FileName (Get-PsExe) -Arguments @('-NoProfile', '-Command', $command) `
            -Stdin (New-ClaudeEvent 'sample.env' ('AWS_ACCESS_KEY_ID=' + 'AKIA' + '1234567890ABCDEF'))
        Assert ($blocked.Exit -eq 2) "a blocked write launched from a subfolder exited $($blocked.Exit), not 2: the guard did not start, and the host writes the file. stderr: $($blocked.Err.Trim())"
        Assert ($blocked.Err -match 'Blocked write to sample\.env') "the guard gave no block reason from a subfolder: $($blocked.Err.Trim())"
        $allowed = Invoke-RawProcess -FileName (Get-PsExe) -Arguments @('-NoProfile', '-Command', $command) `
            -Stdin (New-ClaudeEvent 'notes.md' 'nothing to declare here')
        Assert ($allowed.Exit -eq 0) "a clean write launched from a subfolder exited $($allowed.Exit), not 0. stderr: $($allowed.Err.Trim())"
    } finally { Pop-Location; $env:CLAUDE_PROJECT_DIR = $ambientProjectDir }
} }

# An interpreter that is not found leaves $LASTEXITCODE null, and `exit $null` is exit 0: the host
# reads success and writes the file. This is NOT the registered string: its interpreter token is
# replaced by a name that cannot resolve, the only way either host can reach that branch without
# relaunching the other one. The event is a clean write, so exit 2 can only come from the command.
$noInterpreterCase = "registered guard command refuses a write when its interpreter cannot start ($registrationRelative, interpreter name replaced)"
if (-not (Test-Path -LiteralPath (Join-Path $installRoot $registrationRelative) -PathType Leaf)) {
    Skip $noInterpreterCase "no $registrationRelative in this tree (authoring source layout); the dist legs launch it"
} else { It $noInterpreterCase {
    $registration = [IO.File]::ReadAllText((Join-Path $installRoot $registrationRelative)) | ConvertFrom-Json
    $command = [string]@(foreach ($group in @($registration.hooks.PreToolUse)) { foreach ($entry in @($group.hooks)) { if ([string]$entry.command -match 'guard\.ps1') { $entry.command } } })[0]
    $pattern = '(^|;\s*)' + [regex]::Escape($expectedInterpreter) + '(?=\s+-NoProfile)'
    $unstartable = [regex]::Replace($command, $pattern, '${1}no-such-interpreter-9f3a')
    Assert ($unstartable -cne $command) "could not replace the interpreter token in: $command"
    $ambientProjectDir = $env:CLAUDE_PROJECT_DIR
    Push-Location $installRoot
    try {
        $env:CLAUDE_PROJECT_DIR = $null
        $refused = Invoke-RawProcess -FileName (Get-PsExe) -Arguments @('-NoProfile', '-Command', $unstartable) `
            -Stdin (New-ClaudeEvent 'notes.md' 'nothing to declare here')
        Assert ($refused.Exit -eq 2) "with an interpreter that cannot start the command exited $($refused.Exit), not 2: the host carries out the write unguarded. stderr: $($refused.Err.Trim())"
        Assert ($refused.Err -match 'no-such-interpreter-9f3a') "the refusal does not name the interpreter that could not start: $($refused.Err.Trim())"
    } finally { Pop-Location; $env:CLAUDE_PROJECT_DIR = $ambientProjectDir }
} }

# Empty stdin and malformed JSON must degrade-safe to ALLOW (exit 0), never crash.
It 'guard.ps1 empty stdin -> allow'     { Assert-Decision (Invoke-Hook $guardPs '')             'ALLOW' 'empty' }
It 'guard.ps1 malformed JSON degrades safely' {
    Assert-Decision (Invoke-Hook $guardPs 'not json {') 'ALLOW' 'malformed'
}

exit (Write-TestSummary 'Guard2.Tests (PowerShell)')
