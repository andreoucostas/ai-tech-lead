# audit-trail.ps1/.sh behavioral tests (stack-agnostic only).
# Tests: normal Write -> line appended; self-path -> no line; Copilot create -> line appended;
# tab-delimited 3-field format; .ps1/.sh twin agree.
# Stack-specific artifact skip (node_modules/dist/.angular/coverage vs obj/bin) differs between
# repos and is NOT asserted here (byte-identical constraint) -- covered by manual fixture
# demonstration.
# Red-before-green: the self-skip test catches a broken skip. If 'ai-audit\.log|' is removed
# from the skip regex in .ps1 (or '*ai-audit.log|' from the .sh case), the self-skip It blocks
# fail because Invoke-Hook appends a line when it should not. The static guards below go red
# the moment the skip expression or the append call disappears from either source file.
if (-not (Get-Command Reset-Tests -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hookPs = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks\audit-trail.ps1')).Path
$hookSh = Join-Path (Split-Path $hookPs -Parent) 'audit-trail.sh'
$srcPs  = [System.IO.File]::ReadAllText($hookPs)
$srcSh  = [System.IO.File]::ReadAllText($hookSh)

Reset-Tests

# --- Static guards (red if skip or append logic disappears from source) ---
It 'audit-trail.ps1 self-skip regex contains ai-audit\.log' {
    Assert ($srcPs -match 'ai-audit\\\.log') 'self-skip regex is missing ai-audit\.log in .ps1'
}
It 'audit-trail.sh self-skip case contains *ai-audit.log' {
    Assert ($srcSh -match '\*ai-audit\.log') 'self-skip case is missing *ai-audit.log in .sh'
}
It 'audit-trail.ps1 appends tab-delimited line via Out-File -Append -Encoding utf8' {
    Assert ($srcPs -match 'Out-File.*-FilePath.*ai-audit\.log.*-Append.*-Encoding\s+utf8') `
        '.ps1 does not append with the expected Out-File -Append -Encoding utf8 signature'
}
It 'audit-trail.sh appends via printf and >> to ai-audit.log' {
    Assert ($srcSh -match 'printf.*>>\s*.claude/ai-audit\.log') `
        '.sh does not append with printf >> .claude/ai-audit.log'
}
It 'both twins use only the constant path-normalisation failure sentinel in fallback branches' {
    Assert ($srcPs -match '\$rel = ''\[path-normalisation-failed\]''') '.ps1 sentinel initialisation missing'
    Assert ($srcPs -match 'catch \{ \$rel = ''\[path-normalisation-failed\]'' \}') '.ps1 catch sentinel missing'
    Assert ($srcPs -notmatch 'catch\s*\{\s*\$rel\s*=\s*\$filePath') '.ps1 still falls back to the failed path'
    Assert (($srcSh | Select-String -Pattern 'rel="\[path-normalisation-failed\]"' -AllMatches).Matches.Count -eq 4) `
        '.sh must use the constant sentinel in its initial, realpath, python, and containment fallbacks'
    Assert ($srcSh -notmatch 'rel="\$file_path"') '.sh still falls back to the failed path'
}

# --- Behavioral tests run from a throwaway CWD; [IO.File] always uses absolute $logPath.
# NOTE: PowerShell unrolls single-element arrays on assignment ($x = @('a') -> $x is scalar),
# so $x[0] returns the first CHARACTER, not the first element. Use @($x)[0] to re-wrap before
# indexing whenever the count is expected to be exactly 1. ---
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("audit-cwd-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $tmp '.claude') -Force | Out-Null
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

    # 4. .sh twin (skipped when no bash found)
    $bash = Get-BashPath
    if (-not $bash) {
        Skip 'Claude Write event appends exactly one line (.sh)' 'no bash found'
        Skip 'self-skip: ai-audit.log path appends no line (.sh)' 'no bash found'
        Skip 'Copilot create event appends exactly one line (.sh)' 'no bash found'
    } else {
        It 'Claude Write event appends exactly one line (.sh)' {
            [System.IO.File]::WriteAllText($logPath, '')
            $null = New-Item -ItemType File -Force -Path 'src/x.txt'
            $evt = New-ClaudeEvent 'src/x.txt' 'hello world'
            $r = Invoke-Hook $hookSh $evt
            Assert ($r.Exit -eq 0) "hook exited $($r.Exit), stderr: $($r.Err)"
            $lines = Get-AuditLines
            Assert ($lines.Count -eq 1) "expected 1 line, got $($lines.Count)"
            $fields = @($lines)[0] -split "`t"
            Assert ($fields.Count -eq 3) "expected 3 tab-delimited fields, got $($fields.Count)"
            Assert ($fields[2] -ne '[path-normalisation-failed]') 'successful resolution unexpectedly hit the failure sentinel'
        }
        It 'self-skip: ai-audit.log path appends no line (.sh)' {
            [System.IO.File]::WriteAllText($logPath, '')
            $evt = New-ClaudeEvent '.claude/ai-audit.log' '# audit content'
            $r = Invoke-Hook $hookSh $evt
            Assert ($r.Exit -eq 0) "hook exited $($r.Exit)"
            $lines = Get-AuditLines
            Assert ($lines.Count -eq 0) "expected 0 lines (self-skip), got $($lines.Count)"
        }
        It 'Copilot create event appends exactly one line (.sh)' {
            [System.IO.File]::WriteAllText($logPath, '')
            $evt = New-CopilotEvent 'src/main.ts' 'console.log("hi");'
            $r = Invoke-Hook $hookSh $evt
            Assert ($r.Exit -eq 0) "hook exited $($r.Exit)"
            $lines = Get-AuditLines
            Assert ($lines.Count -eq 1) "expected 1 line, got $($lines.Count)"
        }
        It 'full fallback chain retains a sentinel audit line without the failed path (.sh)' {
            [System.IO.File]::WriteAllText($logPath, '')
            $oldPath = $env:CLAUDE_FILE_PATH
            try {
                $env:CLAUDE_FILE_PATH = '/SENTINEL-FAKE-HOME/SENTINEL-SECRET-LOCATION/missing.txt'
                $r = Invoke-Sandboxed -Bash $bash -ScriptPath $hookSh -Utilities @('cat','date')
            } finally { $env:CLAUDE_FILE_PATH = $oldPath }
            Assert ($r.Exit -eq 0) "hook exited $($r.Exit), stderr: $($r.Err)"
            $lines = Get-AuditLines
            Assert ($lines.Count -eq 1) "expected retained traceability line, got $($lines.Count)"
            Assert (@($lines)[0] -match '\[path-normalisation-failed\]') "constant sentinel missing; line='$(@($lines)[0])'"
            Assert (@($lines)[0] -notmatch 'SENTINEL-FAKE-HOME|SENTINEL-SECRET-LOCATION') 'failed path leaked'
        }

        It 'existing path outside the repository is redacted (.sh)' {
            [System.IO.File]::WriteAllText($logPath, '')
            $outside = [IO.Path]::GetTempFileName()
            try {
                $r = Invoke-Hook $hookSh (New-ClaudeEvent $outside 'synthetic content')
                Assert ($r.Exit -eq 0) "hook exited $($r.Exit), stderr: $($r.Err)"
                $lines = Get-AuditLines
                Assert ($lines.Count -eq 1) "expected retained traceability line, got $($lines.Count)"
                Assert (@($lines)[0] -match '\[path-normalisation-failed\]') 'outside path was not redacted'
                Assert (@($lines)[0] -notmatch [regex]::Escape([IO.Path]::GetFileName($outside))) 'outside filename leaked'
            } finally { Remove-Item -LiteralPath $outside -Force -ErrorAction SilentlyContinue }
        }
    }
} finally {
    Pop-Location
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'AuditTrail.Tests')
