# Guard behavioural tests over the shared PowerShell case table.
# For each BLOCKING case: Claude-shaped event must BLOCK (exit 2), Copilot-shaped event must DENY
# (JSON). For each CLEAN case: both shapes must ALLOW. Cases are generated into both surface shapes
# from one content string, so the same input drives both.
#
# The cases run in two files so their halves run in parallel: this one runs the table on the Claude
# surface, the apply_patch cases and the cases after them; Guard2.Tests.ps1 sets $GuardTableSurface,
# dot-sources this file for the table on the Copilot surface, then runs the time-limit and
# registered-command cases.
#
# Every result is checked against the expected decision, independently of implementation.
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
. (Join-Path $PSScriptRoot 'fixtures\guard-cases.ps1')
. (Join-Path $PSScriptRoot 'fixtures\guard-patch-cases.ps1')
$hooks   = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$guardPs = Join-Path $hooks 'guard.ps1'

Reset-Tests
# A file that exists under a new scratch folder, for the tests that need the guard to find a file on disk (the folder
# is returned through $Scratch for the caller to remove). Returns the file's absolute path.
function New-ExistingFile([ref]$Scratch, [string]$RelativePath, [string]$Text) {
    $Scratch.Value = Join-Path ([IO.Path]::GetTempPath()) ('guard-disk-' + [guid]::NewGuid().ToString('N'))
    $path = Join-Path $Scratch.Value $RelativePath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $path) | Out-Null
    [IO.File]::WriteAllText($path, $Text, (New-Object System.Text.UTF8Encoding($false)))
    $path
}
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
$tableSurface = if ($GuardTableSurface -eq 'Copilot') { 'Copilot' } else { 'Claude' }
foreach ($case in $selectedCases) {
    foreach ($surface in @($tableSurface)) {
        $expected = if (-not $case.block) { 'ALLOW' } elseif ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }
        It "guard $expected ($surface): $($case.n)" {
            # A disk case is a whole-file write over a file that exists: the file is written under a scratch folder
            # and the event carries its absolute path.
            $scratch = $null
            try {
                $path = $case.f
                if ($case.ContainsKey('disk')) { $path = New-ExistingFile ([ref]$scratch) $case.f $case.disk }
                $evt = if ($case.ContainsKey('o')) {
                    if ($surface -eq 'Claude') { New-ClaudeEditEvent $path $case.o $case.c } else { New-CopilotEditEvent $path $case.o $case.c }
                } elseif ($surface -eq 'Claude') { New-ClaudeEvent $path $case.c } else { New-CopilotEvent $path $case.c }
                $rps = Invoke-Hook $guardPs $evt
                Assert-Decision $rps $expected $case.n
            } finally { if ($scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue } }
        }
    }
}
# Guard2.Tests.ps1 runs its own cases after the table.
if ($tableSurface -eq 'Copilot') { return }

# apply_patch: each case's patch is sent in the stdin Copilot captured for an apply_patch call
# (fixtures/guard-patch-cases.ps1). A block is exit 2 for the .claude/settings.json copy, whose
# tool_name is Edit, and a JSON deny for every other shape. The reason must name each file the
# patch writes a blocked line to, and no file it writes cleanly.
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
# Claude Code's NotebookEdit, as Claude Code 2.1.312 sent it (2026-11-04): the notebook in notebook_path, the cell's
# new text in new_source, edit_mode replace or insert (insert adds cell_type). A delete removes the cell and writes
# no source, so its new_source is not read: refusing it would keep a leaked key in the notebook.
It 'guard BLOCK (Claude NotebookEdit): a key-shaped cell source on replace and insert; a clean cell and a delete pass' {
    $keyShaped = 'AKIA' + '1234567890ABCDEF'   # assembled at run time, as the outgoing-commit guard asks
    $notebook = 'analysis\x.ipynb'
    $cells = @(
        @{ mode = 'replace'; source = "aws_key = '$keyShaped'"; expected = 'BLOCK' }
        @{ mode = 'insert';  source = "aws_key = '$keyShaped'"; expected = 'BLOCK'; type = 'code' }
        @{ mode = 'replace'; source = 'print(1)';               expected = 'ALLOW' }
        @{ mode = 'delete';  source = "aws_key = '$keyShaped'"; expected = 'ALLOW' }
    )
    foreach ($cell in $cells) {
        $in = [ordered]@{ notebook_path = $notebook; cell_id = 'c0a1b2c3'; new_source = $cell.source; edit_mode = $cell.mode }
        if ($cell.type) { $in.cell_type = $cell.type }
        $r = Invoke-Hook $guardPs (@{ tool_name = 'NotebookEdit'; tool_input = $in } | ConvertTo-Json -Compress -Depth 6)
        Assert-Decision $r $cell.expected "NotebookEdit $($cell.mode) of '$($cell.source)'"
        if ($cell.expected -eq 'BLOCK') {
            Assert (([string]$r.Err).Contains("Blocked write to ${notebook}: it contains an AWS access key id")) "NotebookEdit $($cell.mode): the reason does not name the notebook and the key -- $($r.Err)"
        }
    }
}
It 'guard DENY (Copilot): a create whose text carries a patch is checked as that create' {
    $evt = New-CopilotEvent 'src\Foo.cs' "*** Begin Patch`n*** Add File: notes.txt`n+x`n*** End Patch`n#pragma warning disable CS8602"
    Assert-Decision (Invoke-Hook $guardPs $evt) 'DENY' 'create carrying patch text'
}

# --- A suppression or skip is counted against the text the write replaces (the table's o and disk cases, and the patch cases) ---
# The edit spellings the guard reads: Claude Code's Edit, Copilot CLI's edit with snake_case and with camelCase field names
# (and with toolArgs sent as a JSON string), and the text editor's str_replace under a Claude-format envelope. Each passes
# when it keeps the pragma its old text holds and is blocked when it adds a second. An insert (new_str, no old text) replaces
# nothing, so it is read as it always was.
It 'guard: an edit that keeps a #pragma warning disable passes in every field spelling, and one that adds a second, or an insert, is blocked' {
    $file = 'C:\work\repo\src\Foo.cs'
    $old = "#pragma warning disable CS0618`nvar a = Old();"
    $kept = "$old`nvar b = Old();"
    $added = "#pragma warning disable CS0618`n#pragma warning disable CS0612`nvar a = Old();"
    $shapes = @(
        @{ n = 'Claude Edit';                       deny = 'BLOCK'; e = { param($o, $n) @{ tool_name = 'Edit'; tool_input = @{ file_path = $file; old_string = $o; new_string = $n } } } }
        @{ n = 'Copilot edit (old_str/new_str)';    deny = 'DENY';  e = { param($o, $n) @{ toolName = 'edit'; toolArgs = @{ path = $file; old_str = $o; new_str = $n } } } }
        @{ n = 'Copilot edit (camelCase)';          deny = 'DENY';  e = { param($o, $n) @{ toolName = 'edit'; toolArgs = @{ filePath = $file; oldString = $o; newString = $n } } } }
        @{ n = 'Copilot edit (toolArgs as a string)'; deny = 'DENY'; e = { param($o, $n) @{ toolName = 'edit'; toolArgs = (@{ path = $file; old_str = $o; new_str = $n } | ConvertTo-Json -Compress) } } }
        @{ n = 'str_replace under a Claude envelope'; deny = 'BLOCK'; e = { param($o, $n) @{ tool_name = 'Edit'; tool_input = @{ path = $file; old_str = $o; new_str = $n } } } }
    )
    foreach ($shape in $shapes) {
        $keptEvent = (& $shape.e $old $kept) | ConvertTo-Json -Compress -Depth 6
        $addedEvent = (& $shape.e $old $added) | ConvertTo-Json -Compress -Depth 6
        Assert-Decision (Invoke-Hook $guardPs $keptEvent) 'ALLOW' "$($shape.n) keeping the pragma"
        Assert-Decision (Invoke-Hook $guardPs $addedEvent) $shape.deny "$($shape.n) adding a second pragma"
    }
    $insert = @{ toolName = 'insert'; toolArgs = @{ path = $file; insert_line = 3; new_str = '#pragma warning disable CS0618' } } | ConvertTo-Json -Compress -Depth 6
    Assert-Decision (Invoke-Hook $guardPs $insert) 'DENY' 'an insert of a pragma, which replaces no text'
}

# A whole-file write is compared with the file on disk, but only when that file can be read as one. Every other leg is read
# as it always was (blocked): no old text is no match, so the write is judged by what it contains alone.
It 'guard BLOCK (Claude) and DENY (Copilot): a whole-file write with no readable file under it to compare with is blocked for its pragma' {
    $existing = "#pragma warning disable CS0618`nvar a = 1;`n"
    $content = "#pragma warning disable CS0618`nvar a = 2;`n"
    $scratch = $null
    $stream = $null
    try {
        $path = New-ExistingFile ([ref]$scratch) 'src\Foo.cs' $existing
        # The control: the file is there and readable, so the same write to its absolute path passes. The legs below differ from it only in what stands at the path.
        foreach ($surface in 'Claude', 'Copilot') {
            $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $path $content } else { New-CopilotEvent $path $content }
            Assert-Decision (Invoke-Hook $guardPs $evt) 'ALLOW' "the control, an existing file under $surface"
        }
        $directory = Join-Path $scratch 'dir\Foo.cs'
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
        $oversize = Join-Path $scratch 'big\Foo.cs'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $oversize) | Out-Null
        [IO.File]::WriteAllText($oversize, $existing + ('/' * (5 * 1MB)), (New-Object System.Text.UTF8Encoding($false)))   # past the 4 MB the guard reads
        $locked = Join-Path $scratch 'locked\Foo.cs'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $locked) | Out-Null
        [IO.File]::WriteAllText($locked, $existing, (New-Object System.Text.UTF8Encoding($false)))
        $stream = New-Object IO.FileStream($locked, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
        $legs = @(
            @{ n = 'a directory at the path';           p = $directory }
            @{ n = 'a file past the size the guard reads'; p = $oversize }
            @{ n = 'a file another process holds locked'; p = $locked }
            @{ n = 'no file at the path';               p = (Join-Path $scratch 'absent\Foo.cs') }
        )
        foreach ($leg in $legs) {
            foreach ($surface in 'Claude', 'Copilot') {
                $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $leg.p $content } else { New-CopilotEvent $leg.p $content }
                Assert-Decision (Invoke-Hook $guardPs $evt) $(if ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }) "$($leg.n) ($surface)"
            }
        }
        # A relative path is the tool's to resolve against its own directory, which the hook cannot know, so it is never read even when
        # a file stands at that path under the hook's directory. The first assertion proves the child starts in the scratch folder.
        Push-Location $scratch
        try {
            $startedIn = (Invoke-RawProcess -FileName (Get-PsExe) -Arguments @('-NoProfile', '-Command', '(Get-Location).Path')).Out
            Assert ((Split-Path -Leaf $startedIn) -eq (Split-Path -Leaf $scratch)) "the hook would not start in the scratch folder ($startedIn), so the relative-path legs prove nothing"
            foreach ($surface in 'Claude', 'Copilot') {
                $evt = if ($surface -eq 'Claude') { New-ClaudeEvent 'src\Foo.cs' $content } else { New-CopilotEvent 'src\Foo.cs' $content }
                Assert-Decision (Invoke-Hook $guardPs $evt) $(if ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }) "a relative path to an existing file ($surface)"
            }
        } finally { Pop-Location }
    } finally {
        if ($stream) { $stream.Dispose() }
        if ($scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# An apply_patch Add File over a file that exists is a whole-file write, compared with that file as a Write is.
It 'guard: an apply_patch Add File over an existing file keeps the pragma it holds, and over a file or path without one is blocked' {
    $scratch = $null
    try {
        $path = New-ExistingFile ([ref]$scratch) 'src\Foo.cs' "#pragma warning disable CS0618`nvar a = 1;`n"
        $keeps = "*** Begin Patch`n*** Add File: $path`n+#pragma warning disable CS0618`n+var a = 2;`n*** End Patch`n"
        $adds = "*** Begin Patch`n*** Add File: $path`n+#pragma warning disable CS0618`n+#pragma warning disable CS0612`n+var a = 2;`n*** End Patch`n"
        $absent = "*** Begin Patch`n*** Add File: $(Join-Path $scratch 'src\New.cs')`n+#pragma warning disable CS0618`n*** End Patch`n"
        foreach ($shape in 'hooks.json', '.claude/settings.json') {
            $deny = if ($shape -eq '.claude/settings.json') { 'BLOCK' } else { 'DENY' }
            Assert-Decision (Invoke-Hook $guardPs (New-PatchEvent $shape $keeps)) 'ALLOW' "an Add File that keeps the pragma on disk ($shape)"
            Assert-Decision (Invoke-Hook $guardPs (New-PatchEvent $shape $adds)) $deny "an Add File that adds a second pragma ($shape)"
            Assert-Decision (Invoke-Hook $guardPs (New-PatchEvent $shape $absent)) $deny "an Add File of a new file with a pragma ($shape)"
        }
    } finally { if ($scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue } }
}

# The file under a whole-file write is the one the tool writes only when Windows and Node resolve the path to the same
# file. Windows drops a trailing dot or space from every segment ('Dir.\Legacy.cs' reads Dir\Legacy.cs) and reads
# 'Legacy.cs::$DATA' as Legacy.cs, where Node writes the literal name, so such a path is compared with nothing and the write
# is judged by its own pragmas. A '.' segment collapses the same way in both, so it is still compared.
It 'guard BLOCK (Claude) and DENY (Copilot): a path Windows and Node resolve to different files is not compared with the file Windows would open' {
    $existing = "#pragma warning disable CS0618`n#pragma warning disable CS0612`n#pragma warning disable CS8602`n"
    $scratch = $null
    try {
        $path = New-ExistingFile ([ref]$scratch) 'Dir\Legacy.cs' $existing
        $folder = Split-Path -Parent (Split-Path -Parent $path)
        $forms = @(
            @{ n = 'a dot after a folder name';        p = "$folder\Dir.\Legacy.cs";      allowed = $false }
            @{ n = 'a dot after the file name';        p = "$folder\Dir\Legacy.cs.";      allowed = $false }
            @{ n = 'a space after the file name';      p = "$folder\Dir\Legacy.cs ";      allowed = $false }
            @{ n = 'a space after a folder name';      p = "$folder\Dir \Legacy.cs";      allowed = $false }
            @{ n = 'an NTFS stream suffix';            p = "${path}::`$DATA";             allowed = $false }
            @{ n = 'a dot segment after \\?\';         p = "\\?\$folder\Dir\.\Legacy.cs"; allowed = $false }
            @{ n = 'the path as it is (control)';      p = $path;                         allowed = $true }
            @{ n = 'a . segment without \\?\ (control)'; p = "$folder\Dir\.\Legacy.cs";   allowed = $true }
            @{ n = 'forward slashes (control)';        p = $path.Replace('\', '/');       allowed = $true }
        )
        foreach ($form in $forms) {
            foreach ($surface in 'Claude', 'Copilot') {
                $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $form.p $existing } else { New-CopilotEvent $form.p $existing }
                $expected = if ($form.allowed) { 'ALLOW' } elseif ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }
                Assert-Decision (Invoke-Hook $guardPs $evt) $expected "$($form.n) ($surface)"
            }
        }
    } finally { if ($scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue } }
}

# One event reads at most 4 MB of files from disk: three Add File sections over three different 1.5 MB files that each keep
# their pragma, the first two are compared with their files and the third, past the budget, has no old text and is blocked.
It 'guard DENY (Copilot): an apply_patch reads at most 4 MB of files, so the file past the budget has no old text' {
    $scratch = $null
    try {
        $text = "#pragma warning disable CS0618`n" + ("var a = 1;`n" * 136000)   # about 1.5 MB
        $first = New-ExistingFile ([ref]$scratch) 'src\First.cs' $text
        $second = Join-Path $scratch 'src\Second.cs'; $third = Join-Path $scratch 'src\Third.cs'
        [IO.File]::WriteAllText($second, $text, (New-Object System.Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText($third, $text, (New-Object System.Text.UTF8Encoding($false)))
        $patch = "*** Begin Patch`n" + (-join @($first, $second, $third | ForEach-Object { "*** Add File: $_`n+#pragma warning disable CS0618`n+var b = 2;`n" })) + "*** End Patch`n"
        $r = Invoke-Hook $guardPs (New-PatchEvent 'hooks.json' $patch)
        Assert-Decision $r 'DENY' 'three Add File sections over three 1.5 MB files'
        $reason = [string]($r.Out | ConvertFrom-Json).permissionDecisionReason
        Assert ($reason.Contains("Blocked write to $third")) "the file past the budget is not named -- $reason"
        Assert (-not $reason.Contains($first) -and -not $reason.Contains($second)) "a file inside the budget is named -- $reason"
    } finally { if ($scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue } }
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
# tr-TR upper-cases i to a dotted capital I (U+0130) and lower-cases I to a dotless i (U+0131); a key name cased that way is still the key.
It 'guard BLOCK (Claude) and DENY (Copilot) under tr-TR: credential literals under key names in Turkish casing (dotted capital I, dotless small i)' {
    $wrapper = Join-Path ([IO.Path]::GetTempPath()) ('guard-tr-' + [guid]::NewGuid().ToString('N') + '.ps1')
    $text = "[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::new('tr-TR')`n" +
        "if ([regex]::IsMatch('I', 'i', 'IgnoreCase')) { exit 3 }`n& '" + $guardPs.Replace("'", "''") + "'`nexit `$LASTEXITCODE`n"
    [IO.File]::WriteAllText($wrapper, $text, (New-Object System.Text.UTF8Encoding($true)))
    $value = 'Zq8v' + 'R2mK4tW7xN'   # assembled at run time, as the outgoing-commit guard asks
    $dotted = [string][char]0x0130; $dotless = [string][char]0x0131
    $writes = @(
        @{ n = 'AP(U+0130)_KEY';                  f = 'src/Client.cs'; c = "const string AP${dotted}_KEY = `"$value`";" }
        @{ n = 'ap(U+0131)_key';                  f = '.env.local.json'; c = "{ `"ap${dotless}_key`": `"$value`" }" }
        @{ n = 'CONNECT(U+0130)ONSTR(U+0130)NG';  f = 'src/Db.cs'; c = "const string CONNECT${dotted}ONSTR${dotted}NG = `"Server=db;User Id=app;Password=$value;`";" }
        @{ n = 'connect(U+0131)onstr(U+0131)ng';  f = 'src/Db.cs'; c = "var connect${dotless}onstr${dotless}ng = `"Server=db;User Id=app;Password=$value;`";" }
        @{ n = 'CONNECT(U+0130)ONSTR(U+0130)NGS'; f = 'src/Api/appsettings.json'; c = "{ `"CONNECT${dotted}ONSTR${dotted}NGS`": { `"Main`": `"Server=db;User Id=app;Password=$value;`" } }" }
        @{ n = 'connect(U+0131)onstr(U+0131)ngs'; f = 'src/Api/appsettings.json'; c = "{ `"connect${dotless}onstr${dotless}ngs`": { `"Main`": `"Server=db;User Id=app;Password=$value;`" } }" }
    )
    try {
        foreach ($write in $writes) {
            foreach ($surface in 'Claude', 'Copilot') {
                $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $write.f $write.c } else { New-CopilotEvent $write.f $write.c }
                $r = Invoke-Hook $wrapper $evt
                Assert ($r.Exit -ne 3) 'tr-TR did not take in the wrapper (exit 3), so nothing was examined'
                Assert-Decision $r $(if ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }) "tr-TR, $surface, $($write.n)"
                $reason = if ($r.Exit -eq 2) { [string]$r.Err } else { [string]($r.Out | ConvertFrom-Json).permissionDecisionReason }
                Assert ($reason.Contains('hardcoded credential literal')) "tr-TR, $surface, $($write.n): blocked for another reason -- $reason"
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
# a leading ~ (a home folder, which the host does not expand), a URI, a drive-relative, rooted or device path, a UNC
# path on another host, a stream suffix, or a '..' out of the repository. \\?\C:\... is the drive path C:\... .
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

# A repository opened through a UNC path (\\server\share\repo, \\wsl.localhost\Ubuntu\...) reads '\\server\share\' as the
# drive part of a written path. The repository here is reached through this machine's administrative share \\localhost\<drive>$.
$uncCase = 'guard: a repository opened through a UNC path keeps the exemption on its tests and the credential check on its source'
$uncBase = Join-Path ([IO.Path]::GetTempPath()) ('guard-root-' + [guid]::NewGuid().ToString('N'))
$uncTail = $uncBase.Substring(0, 1) + '$' + $uncBase.Substring(2)
if (-not [regex]::IsMatch($uncBase, '^[A-Za-z]:\\') -or -not (Test-Path -LiteralPath ('\\localhost\' + $uncBase.Substring(0, 1) + '$\'))) {
    Skip $uncCase "this machine has no administrative share \\localhost\$($uncBase.Substring(0, 1))`$ to reach the repository through"
} else { It $uncCase {
    $credential = 'var password = "hunter2hunter2";'
    try {
        $null = Copy-HookInto $guardPs (Join-Path $uncBase 'shop')
        $uncRoot = '\\localhost\' + $uncTail + '\shop'
        $hook = "$uncRoot\.claude\hooks\guard.ps1"
        $writes = @(
            @{ f = "$uncRoot\tests\AuthServiceTests.cs";                                  allowed = $true;  n = 'a UNC test path' }
            @{ f = ($uncRoot.Replace('\', '/') + '/tests/AuthServiceTests.cs');           allowed = $true;  n = 'a UNC test path with forward slashes' }
            @{ f = 'tests\AuthServiceTests.cs';                                           allowed = $true;  n = 'a relative test path' }
            @{ f = "$uncRoot\src\AuthService.cs";                                         allowed = $false; n = 'a UNC source path' }
            @{ f = "$uncRoot\tests\..\src\AuthService.cs";                                allowed = $false; n = 'a UNC path that leaves tests\ through ..' }
            @{ f = ('\\fileserver\' + $uncTail + '\shop\tests\AuthServiceTests.cs');       allowed = $false; n = 'the same path on another host' }
            @{ f = ('\\localhost\' + $uncTail.Substring(0, 2) + '\..\' + $uncTail + '\shop\tests\AuthServiceTests.cs'); allowed = $false; n = 'a .. above the share' }
        )
        foreach ($write in $writes) {
            foreach ($surface in 'Claude', 'Copilot') {
                $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $write.f $credential } else { New-CopilotEvent $write.f $credential }
                $expected = if ($write.allowed) { 'ALLOW' } elseif ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }
                Assert-Decision (Invoke-Hook $hook $evt) $expected "$($write.n) ($surface)"
            }
        }
    } finally { Remove-Item -LiteralPath $uncBase -Recurse -Force -ErrorAction SilentlyContinue }
} }

# Node, which the hosts run on, resolves '.' and '..' and drops a trailing separator before it writes, so Foo.cs\, Foo.cs\. and
# Foo.cs\x\.. all write Foo.cs (observed with Node's fs.writeFileSync); the extension checks read the name that walk leaves.
It 'guard BLOCK (Claude) and DENY (Copilot): a trailing separator, \. or \x\.. after a .cs or .spec.ts name still reads that name' {
    $writes = @(
        @{ f = 'src\Foo.cs\';            c = '#pragma warning disable CS8602' }
        @{ f = 'src/Foo.cs/.';           c = '#pragma warning disable CS8602' }
        @{ f = 'src\Foo.cs\x\..';        c = '#pragma warning disable CS8602' }
        @{ f = 'src/app.spec.ts/';       c = "fit('x', () => {});" }
        @{ f = 'src\app.spec.ts\x\..';   c = "fit('x', () => {});" }
    )
    foreach ($write in $writes) {
        foreach ($surface in 'Claude', 'Copilot') {
            $evt = if ($surface -eq 'Claude') { New-ClaudeEvent $write.f $write.c } else { New-CopilotEvent $write.f $write.c }
            Assert-Decision (Invoke-Hook $guardPs $evt) $(if ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }) "$($write.f) ($surface)"
        }
    }
}
# Windows opens an 8.3 short name (APPSPE~1.TS is app.spec.ts where the volume keeps short names), which has lost the .spec infix.
It 'guard BLOCK (Claude) and DENY (Copilot): a focused test written through an 8.3 short name of a spec file' {
    foreach ($surface in 'Claude', 'Copilot') {
        $evt = if ($surface -eq 'Claude') { New-ClaudeEvent 'src\APPSPE~1.TS' "fit('x', () => {});" } else { New-CopilotEvent 'src\APPSPE~1.TS' "fit('x', () => {});" }
        Assert-Decision (Invoke-Hook $guardPs $evt) $(if ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }) "src\APPSPE~1.TS ($surface)"
    }
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

# --- The team's allowlist (.claude/guard-allowlist.txt) waives the secret checks for the paths it lists ---
# Label text and samples that only look like credentials are written to listed paths; every other check still runs
# there, the waiver reaches no path the list does not match, and the agent cannot write the list itself.
$allowlistText = "# team-reviewed`r`nsrc/assets/i18n/*.json`r`n./src/app/shared/labels.ts`r`n/src/styles/**`r`ndocs/guides/`r`n"
$i18nText = '{"login":{"password":"Enter your password","title":"Sign in"}}'
$labelText = "export const labels = {`n  password: 'Password',`n  user: 'User name'`n};`n"
$cssText = ".sk-" + "navigation-drawer-expanded-panel { display: block; }`n"   # assembled at run time, as the outgoing-commit guard asks
function New-AllowlistedRoot([ref]$Base, [string]$Text) {
    $Base.Value = Join-Path ([IO.Path]::GetTempPath()) ('guard-allow-' + [guid]::NewGuid().ToString('N'))
    $root = Join-Path $Base.Value 'shop'
    $hook = Copy-HookInto $guardPs $root
    if ($null -ne $Text) { [IO.File]::WriteAllText((Join-Path $root '.claude\guard-allowlist.txt'), $Text, (New-Object System.Text.UTF8Encoding($false))) }
    return $hook
}
# $Cwd is the event's top-level cwd, the folder Claude Code and Copilot CLI say the tool runs in.
function New-SurfaceEvent([string]$Surface, [string]$File, [string]$Text, [string]$Cwd) {
    $e = if ($Surface -eq 'Claude') { @{ tool_name = 'Write'; tool_input = @{ file_path = $File; content = $Text } } }
         else { @{ toolName = 'create'; toolArgs = @{ path = $File; file_text = $Text } } }
    if ($Cwd) { $e.cwd = $Cwd }
    $e | ConvertTo-Json -Compress -Depth 6
}

It 'guard: a path listed in the team allowlist is not checked for secrets (i18n text, a label map, a css class)' {
    $base = $null
    try {
        $hook = New-AllowlistedRoot ([ref]$base) $allowlistText
        $root = Join-Path $base 'shop'
        $writes = @(
            @{ f = "$root\src\assets\i18n\en.json";      t = $i18nText;  n = 'an i18n file matched by *' }
            @{ f = 'src/assets/i18n/de.json';             t = $i18nText;  n = 'a relative i18n path from the root'; c = $root }
            @{ f = "$root\src\app\shared\labels.ts";      t = $labelText; n = 'a label map listed with ./' }
            @{ f = "$root\src\styles\theme\drawer.css";   t = $cssText;   n = 'a css file matched by /src/styles/**' }
            @{ f = "$root\docs\guides\setup.md";         t = 'Set `password = "hunter2hunter2"` in your local settings.'; n = 'a sample under a listed folder/' }
        )
        foreach ($write in $writes) {
            foreach ($surface in 'Claude', 'Copilot') {
                Assert-Decision (Invoke-Hook $hook (New-SurfaceEvent $surface $write.f $write.t $write.c)) 'ALLOW' "$($write.n) ($surface)"
            }
        }
    } finally { if ($base) { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue } }
}

It 'guard: the allowlist waives no path it does not list, and a missing allowlist waives nothing' {
    $base = $null; $bare = $null
    try {
        $hook = New-AllowlistedRoot ([ref]$base) $allowlistText
        $root = Join-Path $base 'shop'
        $bareHook = New-AllowlistedRoot ([ref]$bare) $null
        $bareRoot = Join-Path $bare 'shop'
        $writes = @(
            @{ h = $hook;     f = "$root\src\app\login\labels.ts";            t = $labelText; n = 'an unlisted label map' }
            @{ h = $hook;     f = "$root\src\assets\i18n\legacy\en.json";     t = $i18nText;  n = 'a file one folder below a * entry' }
            @{ h = $hook;     f = "$root\vendor\src\assets\i18n\en.json";     t = $i18nText;  n = 'a path that only ends like a listed one' }
            @{ h = $hook;     f = "$root\src\assets\i18n\..\..\app\Auth.cs";  t = 'var password = "hunter2hunter2";'; n = 'a .. out of a listed folder' }
            @{ h = $bareHook; f = "$bareRoot\src\assets\i18n\en.json";        t = $i18nText;  n = 'a repository without an allowlist' }
        )
        foreach ($write in $writes) {
            foreach ($surface in 'Claude', 'Copilot') {
                $expected = if ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }
                Assert-Decision (Invoke-Hook $write.h (New-SurfaceEvent $surface $write.f $write.t)) $expected "$($write.n) ($surface)"
            }
        }
    } finally {
        foreach ($b in $base, $bare) { if ($b) { Remove-Item -LiteralPath $b -Recurse -Force -ErrorAction SilentlyContinue } }
    }
}

It 'guard: a path listed in the team allowlist is still checked for suppressions and skipped tests' {
    $base = $null
    try {
        $hook = New-AllowlistedRoot ([ref]$base) "src/**`r`n"
        $root = Join-Path $base 'shop'
        $writes = @(
            @{ f = "$root\src\Auth.cs";            t = "#pragma warning disable CS0618`nvar password = `"hunter2hunter2`";"; r = 'pragma warning disable' }
            @{ f = "$root\src\app\labels.ts";      t = "// @ts-ignore`nexport const password = 'Password';"; r = '@ts-ignore' }
            @{ f = "$root\src\app\login.spec.ts";  t = "it.only('signs in', () => { login('hunter2hunter2'); });"; r = 'focused test' }
        )
        foreach ($write in $writes) {
            foreach ($surface in 'Claude', 'Copilot') {
                $result = Invoke-Hook $hook (New-SurfaceEvent $surface $write.f $write.t)
                Assert-Decision $result $(if ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }) "$($write.f) ($surface)"
                $said = if ($surface -eq 'Claude') { $result.Err } else { $result.Out }
                Assert ($said.Contains($write.r)) "$($write.f) ($surface): expected the reason '$($write.r)', got: $said"
            }
        }
    } finally { if ($base) { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue } }
}

It 'guard: the agent cannot write the team allowlist itself, by Write, Edit or a patch' {
    $base = $null
    try {
        $hook = New-AllowlistedRoot ([ref]$base) $allowlistText
        $root = Join-Path $base 'shop'
        $list = "$root\.claude\guard-allowlist.txt"
        $events = @(
            @{ s = 'Claude';  e = (New-ClaudeEvent $list "src/**`n");                                  n = 'a Claude Write' }
            @{ s = 'Copilot'; e = (New-CopilotEvent '.claude/guard-allowlist.txt' "src/**`n");          n = 'a Copilot create' }
            @{ s = 'Claude';  e = (New-ClaudeEditEvent $list 'docs/guides/' "docs/guides/`nsrc/**");  n = 'a Claude Edit' }
            @{ s = 'Copilot'; e = (New-CopilotEditEvent $list 'docs/guides/' "docs/guides/`nsrc/**"); n = 'a Copilot edit' }
            @{ s = 'Claude';  e = (New-ClaudeEvent "$root\.claude\GUARD-~1.TXT" "src/**`n");          n = 'a Claude Write to the 8.3 short name' }
            @{ s = 'Copilot'; e = (New-PatchEvent 'hooks.json' "*** Begin Patch`n*** Update File: src/list.txt`n*** Move to: .claude/guard-allowlist.txt`n*** End Patch`n"); n = 'an apply_patch move onto the allowlist' }
        )
        foreach ($case in $events) {
            $result = Invoke-Hook $hook $case.e
            Assert-Decision $result $(if ($case.s -eq 'Claude') { 'BLOCK' } else { 'DENY' }) $case.n
            $said = if ($case.s -eq 'Claude') { $result.Err } else { $result.Out }
            Assert ($said.Contains('reviewed in a pull request')) "$($case.n): expected the team-review reason, got: $said"
        }
    } finally { if ($base) { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue } }
}

It 'guard: the agent cannot shorten or delete the team allowlist (an empty edit, an emptying write, a patch deletion)' {
    $base = $null
    try {
        $hook = New-AllowlistedRoot ([ref]$base) $allowlistText
        $root = Join-Path $base 'shop'
        $list = "$root\.claude\guard-allowlist.txt"
        $events = @(
            @{ s = 'Claude';  e = (New-ClaudeEditEvent $list "# team-reviewed`r`n" '');  n = 'a Claude Edit whose new_string is empty' }
            @{ s = 'Copilot'; e = (New-CopilotEditEvent $list "# team-reviewed`r`n" ''); n = 'a Copilot edit whose new_str is empty' }
            @{ s = 'Claude';  e = (New-ClaudeEvent $list '');                             n = 'a Claude Write that empties the list' }
            @{ s = 'Copilot'; e = (New-PatchEvent 'hooks.json' "*** Begin Patch`n*** Update File: .claude/guard-allowlist.txt`n@@`n-# team-reviewed`n*** End Patch`n"); n = 'an apply_patch that only removes a line' }
            @{ s = 'Copilot'; e = (New-PatchEvent 'hooks.json' "*** Begin Patch`n*** Delete File: .claude/guard-allowlist.txt`n*** End Patch`n"); n = 'an apply_patch that deletes the list' }
        )
        foreach ($case in $events) {
            $result = Invoke-Hook $hook $case.e
            Assert-Decision $result $(if ($case.s -eq 'Claude') { 'BLOCK' } else { 'DENY' }) $case.n
            $said = if ($case.s -eq 'Claude') { $result.Err } else { $result.Out }
            Assert ($said.Contains('reviewed in a pull request')) "$($case.n): expected the team-review reason, got: $said"
        }
        $view = @{ toolName = 'view'; toolArgs = @{ path = $list } } | ConvertTo-Json -Compress -Depth 6
        Assert-Decision (Invoke-Hook $hook $view) 'ALLOW' 'a Copilot view of the list'
    } finally { if ($base) { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue } }
}

# An 8.3 short name need not look like the list's: with four other guard-*.txt files in .claude\, Windows gives the list a
# hash-style alias (GUC529~1.TXT). The alias is read back from the volume; a volume with 8.3 names off has none to test.
$shortBase = Join-Path ([IO.Path]::GetTempPath()) ('guard-short-' + [guid]::NewGuid().ToString('N'))
$shortRoot = Join-Path $shortBase 'shop'
$shortHook = Copy-HookInto $guardPs $shortRoot
foreach ($decoy in 'aaaaa', 'bbbbb', 'ccccc', 'ddddd') { [IO.File]::WriteAllText("$shortRoot\.claude\guard-$decoy.txt", "x`n") }
[IO.File]::WriteAllText("$shortRoot\.claude\guard-allowlist.txt", "docs/guides/`n")
$shortName = $null; $shortFolder = $null
try {
    $fso = New-Object -ComObject Scripting.FileSystemObject
    $shortName = $fso.GetFile("$shortRoot\.claude\guard-allowlist.txt").ShortName
    $shortFolder = $fso.GetFolder("$shortRoot\.claude").ShortName
} catch { }
$shortCase = 'guard: the agent cannot write the team allowlist through an 8.3 short name that does not look like it'
if (-not $shortName -or $shortName -eq 'guard-allowlist.txt' -or $shortName -notmatch '~[0-9]') {
    Skip $shortCase "8.3 short names are disabled on the volume holding $shortBase (short name read back: '$shortName')"
} else {
    It $shortCase {
        $events = @(
            @{ s = 'Claude';  e = (New-ClaudeEvent "$shortRoot\.claude\$shortName" "**`n");                 n = "a Claude Write to .claude\$shortName" }
            @{ s = 'Copilot'; e = (New-CopilotEvent "$shortRoot\.claude\$shortName" "**`n");                n = "a Copilot create to .claude\$shortName" }
            @{ s = 'Copilot'; e = (New-CopilotEvent ".claude/$shortName" "**`n");                            n = "a relative Copilot create to .claude/$shortName" }
            @{ s = 'Copilot'; e = (New-CopilotEvent "$shortRoot\$shortFolder\$shortName" "**`n");           n = "a Copilot create to $shortFolder\$shortName" }
            @{ s = 'Claude';  e = (New-ClaudeEditEvent "$shortRoot\.claude\$shortName" 'docs/guides/' '**'); n = "a Claude Edit of .claude\$shortName" }
            @{ s = 'Copilot'; e = (New-CopilotEvent "$shortRoot\.claude\GUD777~1.TXT" "**`n");              n = 'a Copilot create to a short-looking name not yet on disk in .claude' }
        )
        foreach ($case in $events) {
            $result = Invoke-Hook $shortHook $case.e
            Assert-Decision $result $(if ($case.s -eq 'Claude') { 'BLOCK' } else { 'DENY' }) $case.n
        }
        Assert-Decision (Invoke-Hook $shortHook (New-CopilotEvent "$shortRoot\docs\NOTES~1.md" "notes`n")) 'ALLOW' 'a clean write to a short-looking name outside .claude'
    }
}
Remove-Item -LiteralPath $shortBase -Recurse -Force -ErrorAction SilentlyContinue

# An event can name its file in more than one field (file_path, filePath, path, notebook_path), and a tool may write the
# one the guard did not read first: the waiver needs every one listed, and the list is blocked through any one of them.
$waiverSecret = '{"k":"sk-' + 'live0123456789abcdefghijklmn"}'   # assembled at run time, as the outgoing-commit guard asks
function ConvertTo-EventJson($Event) { $Event | ConvertTo-Json -Compress -Depth 6 }
function Get-SurfaceBlock([string]$Surface) { if ($Surface -eq 'Claude') { 'BLOCK' } else { 'DENY' } }
It 'guard: the allowlist waives a write only when it lists every path field the event names' {
    $base = $null
    try {
        $hook = New-AllowlistedRoot ([ref]$base) $allowlistText
        $root = Join-Path $base 'shop'
        $listed = "$root\docs\guides\a.md"; $target = "$root\src\Api\appsettings.json"; $list = "$root\.claude\guard-allowlist.txt"; $decoy = "$root\docs\notes.md"
        $events = @(
            @{ s = 'Copilot'; x = 'DENY';  n = 'a Copilot create {filePath: listed, path: unlisted} with a secret'
               e = @{ toolName = 'create'; toolArgs = @{ filePath = $listed; path = $target; file_text = $waiverSecret } } }
            @{ s = 'Copilot'; x = 'DENY';  n = 'a Copilot edit {filePath: listed, path: unlisted} with a secret'
               e = @{ toolName = 'edit'; toolArgs = @{ filePath = $listed; path = $target; old_str = 'x'; new_str = $waiverSecret } } }
            @{ s = 'Claude';  x = 'BLOCK'; n = 'a Claude NotebookEdit {file_path: listed, notebook_path: unlisted} with a secret'
               e = @{ tool_name = 'NotebookEdit'; tool_input = @{ file_path = $listed; notebook_path = $target; new_source = $waiverSecret; edit_mode = 'replace' } } }
            @{ s = 'Copilot'; x = 'DENY';  n = 'a Copilot create {filePath: decoy, path: the list}'
               e = @{ toolName = 'create'; toolArgs = @{ filePath = $decoy; path = $list; file_text = "**`n" } } }
            @{ s = 'Claude';  x = 'BLOCK'; n = 'a Claude NotebookEdit {file_path: decoy, notebook_path: the list}'
               e = @{ tool_name = 'NotebookEdit'; tool_input = @{ file_path = $decoy; notebook_path = $list; new_source = '**'; edit_mode = 'replace' } } }
            @{ s = 'Copilot'; x = 'ALLOW'; n = 'a Copilot create whose two path fields are both listed'
               e = @{ toolName = 'create'; cwd = $root; toolArgs = @{ filePath = $listed; path = 'docs/guides/a.md'; file_text = $waiverSecret } } }
        )
        foreach ($case in $events) { Assert-Decision (Invoke-Hook $hook (ConvertTo-EventJson $case.e)) $case.x $case.n }
    } finally { if ($base) { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue } }
}

# A tool resolves a relative path against its working directory, the event's cwd, not the repository's root.
It 'guard: a relative path is waived only as the event''s working directory resolves it' {
    $base = $null
    try {
        $hook = New-AllowlistedRoot ([ref]$base) "docs/guides/`nfixtures/`nsrc/assets/i18n/*.json`n"
        $root = Join-Path $base 'shop'
        $app = "$root\src\app"
        $patch = { param($Path, $Cwd) $e = @{ toolName = 'apply_patch'; toolArgs = "*** Begin Patch`n*** Add File: $Path`n+$waiverSecret`n*** End Patch`n" }; if ($Cwd) { $e.cwd = $Cwd }; ConvertTo-EventJson $e }
        $cases = @(
            @{ x = 'DENY';  n = 'a patch adding fixtures/k.json from src\app (writes the unlisted src\app\fixtures\k.json)'; j = (& $patch 'fixtures/k.json' $app) }
            @{ x = 'ALLOW'; n = 'a patch adding ../../fixtures/k.json from src\app';                                       j = (& $patch '../../fixtures/k.json' $app) }
            @{ x = 'DENY';  n = 'a patch adding fixtures/k.json with no working directory';                                  j = (& $patch 'fixtures/k.json' $null) }
        )
        foreach ($surface in 'Claude', 'Copilot') {
            $cases += @{ x = (Get-SurfaceBlock $surface); n = "fixtures/k.json from src\app ($surface)";                j = (New-SurfaceEvent $surface 'fixtures/k.json' $waiverSecret $app) }
            $cases += @{ x = (Get-SurfaceBlock $surface); n = "fixtures/k.json with no working directory ($surface)";   j = (New-SurfaceEvent $surface 'fixtures/k.json' $waiverSecret) }
            $cases += @{ x = (Get-SurfaceBlock $surface); n = "fixtures/k.json from a folder outside the repository ($surface)"; j = (New-SurfaceEvent $surface 'fixtures/k.json' $waiverSecret $base) }
            $cases += @{ x = 'ALLOW'; n = "fixtures/k.json from the root ($surface)";                                     j = (New-SurfaceEvent $surface 'fixtures/k.json' $waiverSecret $root) }
            $cases += @{ x = 'ALLOW'; n = "i18n/fr.json from src\assets ($surface)";                                      j = (New-SurfaceEvent $surface 'i18n/fr.json' $i18nText "$root\src\assets") }
        }
        foreach ($case in $cases) { Assert-Decision (Invoke-Hook $hook $case.j) $case.x $case.n }
    } finally { if ($base) { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue } }
}

# A read of the list, and an ordinary name with '~' and a digit that is not where the list is or could not be its 8.3
# alias, are not writes to the list.
It 'guard: a view of the allowlist and ordinary names with ~ and a digit are not blocked as the allowlist' {
    $base = $null
    try {
        $hook = New-AllowlistedRoot ([ref]$base) $allowlistText
        $root = Join-Path $base 'shop'
        $list = "$root\.claude\guard-allowlist.txt"
        $otherDrive = if ($root.Substring(0, 1) -eq 'D') { 'E' } else { 'D' }
        $view = @{ tool_name = 'str_replace_editor'; tool_input = @{ command = 'view'; path = $list } }
        Assert-Decision (Invoke-Hook $hook (ConvertTo-EventJson $view)) 'ALLOW' 'a str_replace_editor view of the list'
        $create = @{ tool_name = 'str_replace_editor'; tool_input = @{ command = 'create'; path = $list; file_text = "**`n" } }
        Assert-Decision (Invoke-Hook $hook (ConvertTo-EventJson $create)) 'DENY' 'a str_replace_editor create of the list'
        $undo = @{ tool_name = 'str_replace_editor'; tool_input = @{ command = 'undo_edit'; path = $list } }
        Assert-Decision (Invoke-Hook $hook (ConvertTo-EventJson $undo)) 'DENY' 'a str_replace_editor undo_edit of the list'
        $names = @("${otherDrive}:\elsewhere\REPORT~1.TXT", '\\nonexistent-host-b489\share\a~1.md', '~1.md', "$root\.claude\notes~1.md", "$root\.claude\backup~2.json")
        foreach ($name in $names) {
            foreach ($surface in 'Claude', 'Copilot') {
                Assert-Decision (Invoke-Hook $hook (New-SurfaceEvent $surface $name "hello`n" $root)) 'ALLOW' "$name ($surface)"
            }
        }
        foreach ($name in "$root\.claude\GU1A2B~1.TXT", "$root\.claude\guard~12.txt", '\\nonexistent-host-b489\share\GU1A2B~1.TXT') {
            foreach ($surface in 'Claude', 'Copilot') {
                Assert-Decision (Invoke-Hook $hook (New-SurfaceEvent $surface $name "**`n" $root)) (Get-SurfaceBlock $surface) "$name, a possible alias of the list ($surface)"
            }
        }
    } finally { if ($base) { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue } }
}

It 'guard: the allowlist stays blocked through every path field and from a subfolder, and a secret elsewhere stays blocked' {
    $base = $null
    try {
        $hook = New-AllowlistedRoot ([ref]$base) $allowlistText
        $root = Join-Path $base 'shop'
        $list = "$root\.claude\guard-allowlist.txt"; $app = "$root\src\app"
        $events = @(
            @{ s = 'Claude';  e = @{ tool_name = 'Write'; tool_input = @{ file_path = $list; content = "**`n" } } }
            @{ s = 'Claude';  e = @{ tool_name = 'NotebookEdit'; tool_input = @{ notebook_path = $list; new_source = '**'; edit_mode = 'replace' } } }
            @{ s = 'Copilot'; e = @{ toolName = 'create'; toolArgs = @{ path = $list; file_text = "**`n" } } }
            @{ s = 'Copilot'; e = @{ toolName = 'edit'; toolArgs = @{ filePath = $list; old_str = 'docs/guides/'; new_str = '**' } } }
            @{ s = 'Copilot'; e = @{ toolName = 'edit'; toolArgs = @{ file_path = $list; old_str = 'docs/guides/'; new_str = '**' } } }
            @{ s = 'Claude';  e = @{ tool_name = 'Write'; cwd = $app; tool_input = @{ file_path = '..\..\.claude\guard-allowlist.txt'; content = "**`n" } } }
            @{ s = 'Copilot'; e = @{ toolName = 'create'; cwd = $app; toolArgs = @{ path = '../../.claude/GUARD-~1.TXT'; file_text = "**`n" } } }
            @{ s = 'Copilot'; e = @{ toolName = 'apply_patch'; cwd = $app; toolArgs = "*** Begin Patch`n*** Update File: ../../.claude/guard-allowlist.txt`n@@`n-docs/guides/`n+**`n*** End Patch`n" } }
        )
        foreach ($case in $events) {
            $result = Invoke-Hook $hook (ConvertTo-EventJson $case.e)
            Assert-Decision $result (Get-SurfaceBlock $case.s) ($case.e | ConvertTo-Json -Compress -Depth 4)
            $said = if ($case.s -eq 'Claude') { $result.Err } else { $result.Out }
            Assert ($said.Contains('reviewed in a pull request')) "$($case.e | ConvertTo-Json -Compress -Depth 4): expected the team-review reason, got: $said"
        }
        foreach ($surface in 'Claude', 'Copilot') {
            foreach ($cwd in $root, $app) {
                Assert-Decision (Invoke-Hook $hook (New-SurfaceEvent $surface 'appsettings.json' $waiverSecret $cwd)) (Get-SurfaceBlock $surface) "a secret to an unlisted relative path from $cwd ($surface)"
            }
            Assert-Decision (Invoke-Hook $hook (New-SurfaceEvent $surface "$root\src\Api\appsettings.json" $waiverSecret $app)) (Get-SurfaceBlock $surface) "a secret to an unlisted absolute path ($surface)"
        }
    } finally { if ($base) { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue } }
}

It 'guard: a list line built to backtrack answers within 2 s and waives nothing it does not match' {
    $secret = '{"k":"sk-' + 'live0123456789abcdefghijklmn"}'   # assembled at run time, as the outgoing-commit guard asks
    $cases = @(
        @{ l = "**/fixtures/**/samples/**/*.json`n"; p = ((@('fixtures\samples') * 600) -join '\') + '\appsettings.cs' }
        @{ l = "**/**/**/**/**/**/**/**/x.json`n";   p = ((@('a') * 40) -join '\') + '\appsettings.cs' }
    )
    foreach ($case in $cases) {
        $base = $null
        try {
            $hook = New-AllowlistedRoot ([ref]$base) $case.l
            $path = (Join-Path $base 'shop') + '\src\' + $case.p
            foreach ($surface in 'Claude', 'Copilot') {
                $clock = [Diagnostics.Stopwatch]::StartNew()
                $result = Invoke-Hook $hook (New-SurfaceEvent $surface $path $secret)
                $ms = $clock.ElapsedMilliseconds
                Assert-Decision $result $(if ($surface -eq 'Claude') { 'BLOCK' } else { 'DENY' }) "$($case.l.Trim()) on a $($path.Length)-character path ($surface)"
                Assert ($ms -lt 2000) "$($case.l.Trim()) on a $($path.Length)-character path ($surface): the guard took $ms ms, expected under 2000"
            }
        } finally { if ($base) { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue } }
    }
    $base = $null
    try {
        $hook = New-AllowlistedRoot ([ref]$base) "**/fixtures/**/samples/**/*.json`n"
        $path = (Join-Path $base 'shop') + '\src\fixtures\login\samples\en\users.json'
        foreach ($surface in 'Claude', 'Copilot') {
            Assert-Decision (Invoke-Hook $hook (New-SurfaceEvent $surface $path $secret)) 'ALLOW' "a matching path is still waived ($surface)"
        }
    } finally { if ($base) { Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue } }
}

# --- A write the guard cannot fully read is refused, not let through ---
$bomMark = [string][char]0xFEFF
function Get-SurfaceDecision([string]$Surface) { if ($Surface -eq 'Claude') { 'BLOCK' } else { 'DENY' } }
function Get-PatchSurfaceEvent([string]$Surface, [string]$Patch) { New-PatchEvent $(if ($Surface -eq 'Claude') { '.claude/settings.json' } else { 'hooks.json' }) $Patch }

It 'guard: a patch header preceded by a byte-order mark is still read as a header (the allowlist behind U+FEFF)' {
    $patch = "*** Begin Patch`n*** Add File: docs/a.txt`n+one`n${bomMark}*** Add File: .claude/guard-allowlist.txt`n+src/**`n*** End Patch`n"
    foreach ($surface in 'Claude', 'Copilot') {
        Assert-Decision (Invoke-Hook $guardPs (Get-PatchSurfaceEvent $surface $patch)) (Get-SurfaceDecision $surface) "an Add File of the allowlist after U+FEFF ($surface)"
    }
}

It 'guard: a section with two Move to lines checks both targets (the allowlist as the second)' {
    $patch = "*** Begin Patch`n*** Update File: src/list.txt`n*** Move to: docs/x.txt`n*** Move to: .claude/guard-allowlist.txt`n*** End Patch`n"
    foreach ($surface in 'Claude', 'Copilot') {
        Assert-Decision (Invoke-Hook $guardPs (Get-PatchSurfaceEvent $surface $patch)) (Get-SurfaceDecision $surface) "a second Move to onto the allowlist ($surface)"
    }
}

It 'guard: a write whose JSON the guard cannot parse (keys differing only in case, an empty key) is blocked' {
    $events = @(
        @{ s = 'Claude';  n = 'a Write with a repeated key in another case'; e = '{"tool_name":"Write","tool_input":{"file_path":"docs/a.txt","File_Path":"docs/b.txt","content":"x"}}' }
        @{ s = 'Claude';  n = 'a Write to the allowlist with an empty key'; e = '{"tool_name":"Write","tool_input":{"file_path":".claude/guard-allowlist.txt","":"y","content":"src/**"}}' }
        @{ s = 'Copilot'; n = 'a create with a repeated key in another case'; e = '{"toolName":"create","toolArgs":{"path":"docs/a.txt","Path":"docs/b.txt","file_text":"x"}}' }
        @{ s = 'Copilot'; n = 'a create whose toolArgs string has a repeated key'; e = '{"toolName":"create","toolArgs":"{\"path\":\"docs/a.txt\",\"Path\":\"docs/b.txt\",\"file_text\":\"x\"}"}' }
        @{ s = 'Copilot'; n = 'an unknown tool carrying a content field with a repeated key'; e = '{"toolName":"writeIt","toolArgs":{"filePath":"docs/a.txt","FILEPATH":"docs/b.txt","content":"x"}}' }
    )
    foreach ($case in $events) {
        $result = Invoke-Hook $guardPs $case.e
        Assert-Decision $result (Get-SurfaceDecision $case.s) $case.n
        $said = if ($case.s -eq 'Claude') { $result.Err } else { $result.Out }
        Assert ($said.Contains('without duplicate or empty keys')) "$($case.n): expected the resend reason, got: $said"
    }
}

It 'guard: a non-write Copilot call whose arguments repeat a key in another case is allowed' {
    $events = @(
        '{"toolName":"bash","toolArgs":{"command":"ls","Command":"dir"}}'
        '{"toolName":"bash","toolArgs":"{\"command\":\"ls\",\"Command\":\"dir\",\"\":\"x\"}"}'
        '{"toolName":"some-mcp-search","toolArgs":{"query":"a","Query":"b"}}'
    )
    foreach ($e in $events) { Assert-Decision (Invoke-Hook $guardPs $e) 'ALLOW' $e }
}

exit (Write-TestSummary 'Guard.Tests (PowerShell)')
