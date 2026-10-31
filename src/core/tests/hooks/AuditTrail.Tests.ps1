# audit-trail.ps1 behavioral tests (stack-agnostic only).
# Tests: normal Write -> line appended; self-path -> no line; Copilot create -> line appended;
# tab-delimited 3-field format; path failures redact unsafe data.
# Stack-specific artifact skip (node_modules/dist/.angular/coverage vs obj/bin) differs between
# repos and is NOT asserted here (byte-identical constraint) -- covered by manual fixture
# demonstration.
# Red-before-green: the self-skip test catches a broken skip. If 'ai-audit\.log|' is removed
# from the skip regex in .ps1, the self-skip It blocks
# fail because Invoke-Hook appends a line when it should not. The static guards below go red
# the moment the skip expression or the append call disappears from the source file.
if (-not (Get-Command Reset-Tests -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
. (Join-Path $PSScriptRoot 'fixtures\guard-patch-cases.ps1')
$hookSrc = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks\audit-trail.ps1')).Path
$srcPs  = [System.IO.File]::ReadAllText($hookSrc)

Reset-Tests

# --- Static guards (red if skip or append logic disappears from source) ---
It 'audit-trail.ps1 self-skip regex contains ai-audit\.log' {
    Assert ($srcPs -match 'ai-audit\\\.log') 'self-skip regex is missing ai-audit\.log in .ps1'
}
It 'audit-trail.ps1 appends through a FileStream that lets other processes only read, not through Out-File' {
    Assert ($srcPs -match '\[IO\.FileStream\].*\[IO\.FileMode\]::Append.*\[IO\.FileAccess\]::Write.*\[IO\.FileShare\]::Read\b') `
        '.ps1 does not open the log with FileStream Append / Write / FileShare.Read'
    $code = (@($srcPs -split '\r?\n' | Where-Object { $_ -notmatch '^\s*#' })) -join "`n"
    Assert ($code -notmatch 'Out-File') '.ps1 appends with Out-File again, whose share mode loses lines under parallel hook runs'
}
It 'the PowerShell hook uses only the constant path-normalisation failure sentinel in fallback branches' {
    Assert ($srcPs -match '\$rel = ''\[path-normalisation-failed\]''') '.ps1 sentinel initialisation missing'
    Assert ($srcPs -match 'catch \{ \$rel = ''\[path-normalisation-failed\]'' \}') '.ps1 catch sentinel missing'
    Assert ($srcPs -notmatch 'catch\s*\{\s*\$rel\s*=\s*\$filePath') '.ps1 still falls back to the failed path'
}

# --- Behavioral tests run a copy of the hook (and the guard its patch split loads) installed in a
# throwaway Git repository; [IO.File] always uses absolute $logPath.
# NOTE: PowerShell unrolls single-element arrays on assignment ($x = @('a') -> $x is scalar),
# so $x[0] returns the first CHARACTER, not the first element. Use @($x)[0] to re-wrap before
# indexing whenever the count is expected to be exactly 1. ---
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("audit-cwd-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $tmp '.claude') -Force | Out-Null
$hookPs = Copy-HookInto $hookSrc $tmp
$null = Copy-HookInto (Join-Path (Split-Path -Parent $hookSrc) 'guard.ps1') $tmp
git -C $tmp init -q 2>$null
git -C $tmp -c user.name=fixture -c user.email=fixture@example.invalid commit --allow-empty -q -m fixture 2>$null
$branch = [string](git -C $tmp rev-parse --abbrev-ref HEAD 2>$null)
$logPath = Join-Path $tmp '.claude\ai-audit.log'
[System.IO.File]::WriteAllText($logPath, '')

function Get-AuditLines { @([System.IO.File]::ReadAllLines($logPath) | Where-Object { $_ -ne '' }) }

Push-Location $tmp
try {
    # 1. Claude Write event -> exactly one line appended (.ps1), against a file that genuinely
    #    exists on disk so Resolve-Path succeeds -- proving the success path resolves the real
    #    relative path rather than silently taking the failure-sentinel branch.
    It 'Claude Write event appends exactly one line (.ps1)' {
        [System.IO.File]::WriteAllText($logPath, '')
        $null = New-Item -ItemType File -Force -Path 'src/x.txt'
        $evt = New-ClaudeEvent 'src/x.txt' 'hello world'
        $r = Invoke-Hook $hookPs $evt
        Assert ($r.Exit -eq 0) "hook exited $($r.Exit), stderr: $($r.Err)"
        $lines = Get-AuditLines
        Assert ($lines.Count -eq 1) "expected 1 line, got $($lines.Count)"
        $fields = @($lines)[0] -split "`t"
        Assert ($fields.Count -eq 3) "expected 3 tab-delimited fields, got $($fields.Count): '@($lines)[0]'"
        Assert ($fields[2] -match 'x\.txt') "3rd field does not contain the file path (got '$($fields[2])')"
        Assert ($fields[2] -ne '[path-normalisation-failed]') 'successful resolution unexpectedly hit the failure sentinel'
    }

    # 2. Self-skip: ai-audit.log path -> NO line appended (.ps1)
    It 'self-skip: ai-audit.log path appends no line (.ps1)' {
        [System.IO.File]::WriteAllText($logPath, '')
        $evt = New-ClaudeEvent '.claude/ai-audit.log' '# audit content'
        $r = Invoke-Hook $hookPs $evt
        Assert ($r.Exit -eq 0) "hook exited $($r.Exit)"
        $lines = Get-AuditLines
        Assert ($lines.Count -eq 0) "expected 0 lines (self-skip), got $($lines.Count)"
    }

    # 3. Copilot create event -> one line appended (.ps1), against a real on-disk file (see #1).
    It 'Copilot create event appends exactly one line (.ps1)' {
        [System.IO.File]::WriteAllText($logPath, '')
        $null = New-Item -ItemType File -Force -Path 'src/main.ts'
        $evt = New-CopilotEvent 'src/main.ts' 'console.log("hi");'
        $r = Invoke-Hook $hookPs $evt
        Assert ($r.Exit -eq 0) "hook exited $($r.Exit)"
        $lines = Get-AuditLines
        Assert ($lines.Count -eq 1) "expected 1 line, got $($lines.Count)"
        $fields = @($lines)[0] -split "`t"
        Assert ($fields[2] -ne '[path-normalisation-failed]') 'successful resolution unexpectedly hit the failure sentinel'
    }

    # The agents send the event as UTF-8. Read through [Console]::In it was decoded with the console's input code
    # page, so on code page 437 (850, 1252) the bytes of a non-ASCII folder or file name arrived as other characters,
    # no such path resolved, and the log held the sentinel in place of the path. The harness feeds UTF-8, so this is
    # red on a console whose code page is not 65001 and green on one that is.
    It 'a Write to a path with a non-ASCII folder and file name logs the path as written' {
        [System.IO.File]::WriteAllText($logPath, '')
        $folder = "M$([char]0xFC)ller"
        $file = "R$([char]0xE9)sum$([char]0xE9).md"
        $null = New-Item -ItemType File -Force -Path "src/$folder/$file"
        $r = Invoke-Hook $hookPs (New-ClaudeEvent "src/$folder/$file" 'hello world')
        Assert ($r.Exit -eq 0) "hook exited $($r.Exit), stderr: $($r.Err)"
        $lines = Get-AuditLines
        Assert ($lines.Count -eq 1) "expected 1 line, got $($lines.Count)"
        $expected = ".\src\$folder\$file"
        Assert ((@($lines)[0] -split "`t")[2] -ceq $expected) "expected '$expected', got '$(@($lines)[0])'"
    }

    # Under ar-SA the calendar is Umm al-Qura, where 2026 is 1448. The hook runs inside a wrapper that sets
    # ar-SA first; exit 3 means the culture did not take.
    It 'under ar-SA (Umm al-Qura calendar) the timestamp is the Gregorian UTC time' {
        [System.IO.File]::WriteAllText($logPath, '')
        $null = New-Item -ItemType File -Force -Path 'src/x.txt'
        $wrapper = Join-Path ([IO.Path]::GetTempPath()) ('audit-ar-' + [guid]::NewGuid().ToString('N') + '.ps1')
        $text = "[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::new('ar-SA')`n" +
            "if ([Globalization.CultureInfo]::CurrentCulture.Calendar -is [Globalization.GregorianCalendar]) { exit 3 }`n& '" + $hookPs.Replace("'", "''") + "'`nexit `$LASTEXITCODE`n"
        [IO.File]::WriteAllText($wrapper, $text, (New-Object System.Text.UTF8Encoding($true)))
        try {
            $before = [DateTime]::UtcNow
            $r = Invoke-Hook $wrapper (New-ClaudeEvent 'src/x.txt' 'hello world')
            Assert ($r.Exit -ne 3) 'ar-SA did not take in the hook''s process (its calendar is Gregorian), so nothing was examined'
            Assert ($r.Exit -eq 0) "hook exited $($r.Exit), stderr: $($r.Err)"
            $lines = Get-AuditLines
            Assert ($lines.Count -eq 1) "expected 1 line, got $($lines.Count)"
            $stamp = (@($lines)[0] -split "`t")[0]
            $parsed = [DateTime]::MinValue
            $ok = [DateTime]::TryParseExact($stamp, "yyyy-MM-dd'T'HH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]'AssumeUniversal, AdjustToUniversal', [ref]$parsed)
            Assert ($ok -and [Math]::Abs(($parsed - $before).TotalMinutes) -lt 10) "timestamp '$stamp' is not the Gregorian UTC time $($before.ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture))"
        } finally { Remove-Item -LiteralPath $wrapper -Force -ErrorAction SilentlyContinue }
    }

    It 'path-normalisation failure retains a sentinel audit line without the failed path (.ps1)' {
        [System.IO.File]::WriteAllText($logPath, '')
        $unsafe = 'C:\SENTINEL-FAKE-HOME\SENTINEL-SECRET-LOCATION\missing.txt'
        $r = Invoke-Hook $hookPs (New-ClaudeEvent $unsafe 'synthetic content')
        Assert ($r.Exit -eq 0) "hook exited $($r.Exit)"
        $lines = Get-AuditLines
        Assert ($lines.Count -eq 1) "expected retained traceability line, got $($lines.Count)"
        Assert (@($lines)[0] -match '\[path-normalisation-failed\]') 'constant sentinel missing'
        Assert (@($lines)[0] -notmatch 'SENTINEL-FAKE-HOME|SENTINEL-SECRET-LOCATION') 'failed path leaked'
    }

    It 'existing path outside the repository is redacted (.ps1)' {
        [System.IO.File]::WriteAllText($logPath, '')
        $outside = [IO.Path]::GetTempFileName()
        try {
            $r = Invoke-Hook $hookPs (New-ClaudeEvent $outside 'synthetic content')
            Assert ($r.Exit -eq 0) "hook exited $($r.Exit)"
            $lines = Get-AuditLines
            Assert ($lines.Count -eq 1) "expected retained traceability line, got $($lines.Count)"
            Assert (@($lines)[0] -match '\[path-normalisation-failed\]') 'outside path was not redacted'
            Assert (@($lines)[0] -notmatch [regex]::Escape([IO.Path]::GetFileName($outside))) 'outside filename leaked'
        } finally { Remove-Item -LiteralPath $outside -Force -ErrorAction SilentlyContinue }
    }

    # apply_patch, in the envelopes Copilot CLI 1.0.95 sent its two hook files (fixtures/guard-patch-cases.ps1):
    # one line per path the captured patch names (an add, an update, a delete, and an update that moves its
    # file). The deleted file and the moved file's old path no longer exist, so their lines carry the sentinel.
    foreach ($shape in 'hooks.json', '.claude/settings.json') {
        It "apply_patch event appends one line per file the patch writes ($shape)" {
            [System.IO.File]::WriteAllText($logPath, '')
            foreach ($name in 'a', 'b', 'e') { $null = New-Item -ItemType File -Force -Path "notes/$name.txt" }
            $r = Invoke-Hook $hookPs (New-PatchEvent $shape $CapturedPatch)
            Assert ($r.Exit -eq 0) "hook exited $($r.Exit), stderr: $($r.Err)"
            $lines = Get-AuditLines
            Assert ($lines.Count -eq 5) "expected 5 lines (notes\a.txt to notes\e.txt), got $($lines.Count)"
            foreach ($name in 'a', 'b', 'e') {
                Assert (@($lines | Where-Object { ($_ -split "`t")[2] -match "notes[\\/]$name\.txt$" }).Count -eq 1) "no line names notes\$name.txt"
            }
        }
    }

    It 'apply_patch event: a skipped path drops only its own line' {
        [System.IO.File]::WriteAllText($logPath, '')
        $null = New-Item -ItemType File -Force -Path 'notes/a.txt'
        $patch = "*** Begin Patch`n*** Update File: .claude\ai-audit.log`n@@`n+x`n*** Add File: notes\a.txt`n+alpha`n*** End Patch`n"
        $r = Invoke-Hook $hookPs (New-PatchEvent 'hooks.json' $patch)
        Assert ($r.Exit -eq 0) "hook exited $($r.Exit), stderr: $($r.Err)"
        $lines = Get-AuditLines
        Assert ($lines.Count -eq 1 -and (@($lines)[0] -split "`t")[2] -match 'notes[\\/]a\.txt$') "expected one line for notes\a.txt, got: $($lines -join ' | ')"
    }

    # PowerShell's location need not be the repository: in a sandbox on a host without filesystem enumeration it
    # may start at the drive root. The hook finds the repository from its own path, so with the location elsewhere
    # each surface's write still appends its line, with the branch and the repository-relative path, to the
    # repository's log; a relative path is the repository's.
    It 'location outside the repository: a Claude Write and a Copilot create each append their line to the repository''s log' {
        Assert ($branch -and $branch -ne 'HEAD') "fixture has no branch: '$branch'"
        foreach ($name in 'x.txt', 'main.ts') { $null = New-Item -ItemType File -Force -Path (Join-Path $tmp "src\$name") }
        $elsewhere = Join-Path ([IO.Path]::GetTempPath()) ('audit-elsewhere-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $elsewhere -Force | Out-Null
        Push-Location $elsewhere
        try {
            foreach ($case in @(@{ Event = (New-ClaudeEvent (Join-Path $tmp 'src\x.txt') 'hello world'); Path = '.\src\x.txt' },
                                @{ Event = (New-CopilotEvent 'src/main.ts' 'console.log("hi");'); Path = '.\src\main.ts' })) {
                [System.IO.File]::WriteAllText($logPath, '')
                $r = Invoke-Hook $hookPs $case.Event
                Assert ($r.Exit -eq 0) "hook exited $($r.Exit), stderr: $($r.Err)"
                $lines = Get-AuditLines
                Assert ($lines.Count -eq 1) "expected 1 line in the repository's log for $($case.Path), got $($lines.Count)"
                $fields = @($lines)[0] -split "`t"
                Assert ($fields.Count -eq 3 -and $fields[1] -ceq $branch -and $fields[2] -ceq $case.Path) "expected branch '$branch' and path '$($case.Path)', got '$(@($lines)[0])'"
            }
            Assert (-not (Test-Path -LiteralPath (Join-Path $elsewhere '.claude'))) "the hook wrote under PowerShell's location"
        } finally {
            Pop-Location
            Remove-Item -LiteralPath $elsewhere -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # The stack's skip line (dist hooks only) tested the absolute path, so a repository whose own folder was named like
    # a skipped one recorded nothing. The folders of every stack are nested here, so each dist is red on its own names
    # and the src hook, which has no skip line, is green throughout.
    It 'a repository whose own path holds bin, obj, node_modules, dist, .angular and coverage still records a write by absolute path' {
        $deep = Join-Path ([IO.Path]::GetTempPath()) ('audit-dirs-' + [guid]::NewGuid().ToString('N'))
        $repo = Join-Path $deep 'bin\obj\node_modules\dist\.angular\coverage\app'
        try {
            $deepHook = Copy-HookInto $hookSrc $repo
            $null = Copy-HookInto (Join-Path (Split-Path -Parent $hookSrc) 'guard.ps1') $repo
            $null = New-Item -ItemType File -Force -Path (Join-Path $repo 'src\x.txt')
            $r = Invoke-Hook $deepHook (New-ClaudeEvent (Join-Path $repo 'src\x.txt') 'hello world')
            Assert ($r.Exit -eq 0) "hook exited $($r.Exit), stderr: $($r.Err)"
            $deepLog = Join-Path $repo '.claude\ai-audit.log'
            $lines = if (Test-Path -LiteralPath $deepLog) { @([IO.File]::ReadAllLines($deepLog) | Where-Object { $_ -ne '' }) } else { @() }
            Assert ($lines.Count -eq 1) "expected 1 line for an absolute path in a repository under ...\bin\obj\node_modules\dist\.angular\coverage\, got $($lines.Count)"
            Assert ((@($lines)[0] -split "`t")[2] -ceq '.\src\x.txt') "expected '.\src\x.txt', got '$(@($lines)[0])'"
        } finally { Remove-Item -LiteralPath $deep -Recurse -Force -ErrorAction SilentlyContinue }
    }

    # The skip is tested on the repository-relative path, where a top-level `.angular\...` has no separator before its
    # first folder; each folder the hook source names as skipped is still skipped by absolute path, and `src` is not.
    It 'every folder the hook source skips is skipped by absolute path at the top level, and src is not' {
        foreach ($name in 'bin', 'obj', 'node_modules', 'dist', '.angular', 'coverage', 'src') {
            [System.IO.File]::WriteAllText($logPath, '')
            $file = Join-Path $tmp "$name\f.txt"
            $null = New-Item -ItemType File -Force -Path $file
            $r = Invoke-Hook $hookPs (New-ClaudeEvent $file 'hello world')
            Assert ($r.Exit -eq 0) "hook exited $($r.Exit), stderr: $($r.Err)"
            $skipped = $srcPs.Contains('[\\/]' + [regex]::Escape($name) + '[\\/]')
            $count = (Get-AuditLines).Count
            Assert ($count -eq $(if ($skipped) { 0 } else { 1 })) "$name\f.txt by absolute path: the hook source $(if ($skipped) { 'skips' } else { 'does not skip' }) '$name', but $count line(s) were recorded"
        }
    }

    # Parallel tool calls fire this hook together, and Out-File -Append opened the log in a share mode a second appender
    # could not join, so under SilentlyContinue the loser dropped its line without a word. Here the log is held with
    # FileShare.None for 2 s from the moment the hook starts: the unfixed hook has tried within that time, failed and
    # exited, so it leaves 0 lines; the fixed one retries for 3 s and appends once the hold ends.
    It 'a log another process holds for two seconds still receives the line' {
        [System.IO.File]::WriteAllText($logPath, '')
        $null = New-Item -ItemType File -Force -Path 'src/x.txt'
        $stdinFile = [IO.Path]::GetTempFileName(); $stdoutFile = [IO.Path]::GetTempFileName(); $stderrFile = [IO.Path]::GetTempFileName()
        try {
            [IO.File]::WriteAllText($stdinFile, (New-ClaudeEvent 'src/x.txt' 'hello world'), (New-Object System.Text.UTF8Encoding($false)))
            $hold = [IO.File]::Open($logPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            try {
                $p = Start-Process -FilePath (Get-PsExe) -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $hookPs) -NoNewWindow -PassThru `
                    -RedirectStandardInput $stdinFile -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
                $null = $p.Handle
                Start-Sleep -Milliseconds 2000
            } finally { $hold.Dispose() }
            Assert ($p.WaitForExit(30000)) 'the hook was still running 30 s after the log was released'
            Assert ($p.ExitCode -eq 0) "hook exited $($p.ExitCode), stderr: $([IO.File]::ReadAllText($stderrFile))"
            $lines = Get-AuditLines
            Assert ($lines.Count -eq 1) "expected the hook to retry until the hold ended and append 1 line, got $($lines.Count)"
            Assert ((@($lines)[0] -split "`t").Count -eq 3) "expected 3 tab-delimited fields, got '$(@($lines)[0])'"
            $bytes = [IO.File]::ReadAllBytes($logPath)
            Assert (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) 'the log starts with a UTF-8 BOM'
            Assert ($bytes[$bytes.Length - 2] -eq 13 -and $bytes[$bytes.Length - 1] -eq 10) 'the line does not end with CRLF'
        } finally { Remove-Item -LiteralPath $stdinFile, $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue }
    }

    # When the log stays held past the hook's retries, the line is lost, but the hook says so on stderr and still exits 0.
    It 'a log that stays held makes the hook say so on stderr and still exit 0' {
        [System.IO.File]::WriteAllText($logPath, '')
        $hold = [IO.File]::Open($logPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try { $r = Invoke-Hook $hookPs (New-ClaudeEvent 'src/x.txt' 'hello world') } finally { $hold.Dispose() }
        Assert ($r.Exit -eq 0) "hook exited $($r.Exit), stderr: $($r.Err)"
        Assert ($r.Err -match 'ai-audit\.log') "no stderr line names the log: '$($r.Err)'"
        Assert (@($r.Err -split "`n" | Where-Object { $_.Trim() }).Count -eq 1) "expected exactly one stderr line, got: '$($r.Err)'"
        Assert ((Get-AuditLines).Count -eq 0) 'a line was written although the log was held'
    }

} finally {
    Pop-Location
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'AuditTrail.Tests')
