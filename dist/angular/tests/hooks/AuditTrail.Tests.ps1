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
It 'audit-trail.ps1 appends tab-delimited line via Out-File -Append -Encoding utf8' {
    Assert ($srcPs -match 'Out-File.*-FilePath.*ai-audit\.log.*-Append.*-Encoding\s+utf8') `
        '.ps1 does not append with the expected Out-File -Append -Encoding utf8 signature'
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

} finally {
    Pop-Location
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'AuditTrail.Tests')
