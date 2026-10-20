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
