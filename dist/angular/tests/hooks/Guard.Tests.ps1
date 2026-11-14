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
foreach ($case in $selectedCases) {
    foreach ($surface in 'Claude','Copilot') {
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

exit (Write-TestSummary 'Guard.Tests (PowerShell)')
