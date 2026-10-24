# Prevent account-qualified home paths from entering the public authoring tree (B-122).
param([string]$ScanRoot)
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
Reset-Tests

function Find-PrivateHomePath {
    param([string]$Text, [string]$Path = '<memory>')
    $account = '[A-Za-z0-9._-]+'
    $boundary = '(?=$|[\\/ \t\r\n''"\)\]\},;:])'
    $patterns = @(
        ('(?i)[A-Z]:[\\/]Users[\\/]' + $account + $boundary),
        ('(?i)/[A-Z]/Users/' + $account + $boundary),
        ('(?i)/home/' + $account + $boundary),
        ('(?i)/Users/' + $account + $boundary)
    )
    $findings = @()
    $lineNo = 0
    foreach ($line in @($Text -split "`r?`n")) {
        $lineNo++
        foreach ($pattern in $patterns) {
            if ($line -match $pattern) {
                $findings += "${Path}:${lineNo}: $($Matches[0])"
                break
            }
        }
    }
    return @($findings)
}

function Get-RepositoryPrivacyFindings {
    param([string]$Root)
    # File enumeration is stdout. Git may warn on stderr about an unreadable user-level ignore
    # file while still returning a complete exit-0 list; merging that warning turns it into a
    # bogus repository-relative path. A real enumeration failure remains explicit via the exit.
    $paths = @(& git -C $Root ls-files --cached --others --exclude-standard 2>$null)
    $gitExit = $LASTEXITCODE
    if ($gitExit -ne 0) { return @("git enumeration failed with exit $gitExit") }
    if ($paths.Count -eq 0) { return @('git enumeration yielded zero files') }
    $findings = @()
    foreach ($rel in $paths) {
        $full = Join-Path $Root $rel
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
        try {
            $bytes = [IO.File]::ReadAllBytes($full)
            if ($bytes -contains 0) { continue }
            $text = [IO.File]::ReadAllText($full)
            $findings += Find-PrivateHomePath -Text $text -Path $rel
        } catch {
            $findings += "${rel}: unreadable: $($_.Exception.Message)"
        }
    }
    return @($findings)
}

# B-360: a path Git for Windows will not check out stops every Windows CI job at checkout. Rules
# follow its checkout (probed 2026-10-20): a backslash is refused too, and a device name followed by
# spaces, an extension or a stream. Git paths carry no drive prefix, so a colon is always refused.
$script:DeviceName = [regex]::new('^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9]|CONIN\$|CONOUT\$) *(\.|\z)', 'IgnoreCase, CultureInvariant')

function Find-WindowsCheckoutBlocker {
    param([string[]]$Paths)
    $findings = @()
    foreach ($path in $Paths) {
        foreach ($segment in ($path -split '/')) {
            $why = $null
            $device = $script:DeviceName.Match($segment)
            if ($segment -match '[*?"<>|:\\]') { $why = "reserved character '$($Matches[0])'" }
            elseif ($segment -match '[\x00-\x1F]') { $why = ('control character 0x{0:X2}' -f [int][char]$Matches[0]) }
            elseif ($segment -match '[ .]\z') { $why = 'ends in a space or a dot' }
            elseif ($device.Success) { $why = "reserved device name '$($device.Groups[1].Value)'" }
            if ($why) { $findings += "${path}: $why in segment '$segment'"; break }
        }
    }
    return @($findings)
}

function Get-GitPathsAsUtf8 {
    param([string]$Root)
    # -z output read as bytes and decoded as UTF-8: PowerShell's native pipe would decode it with
    # the console code page and split it at newlines.
    $psi = New-Object Diagnostics.ProcessStartInfo 'git', ('-C "' + $Root + '" ls-files -z --cached --others --exclude-standard')
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($psi)
    $stderr = $process.StandardError.ReadToEndAsync()
    $buffer = New-Object IO.MemoryStream
    $process.StandardOutput.BaseStream.CopyTo($buffer)
    $process.WaitForExit()
    $null = $stderr.Result
    if ($process.ExitCode -ne 0) { throw "git enumeration failed with exit $($process.ExitCode)" }
    $text = (New-Object Text.UTF8Encoding $false).GetString($buffer.ToArray())
    return @($text.Split([char]0) | Where-Object { $_ -ne '' })
}

function Get-WindowsCheckoutFindings {
    param([string]$Root)
    try { $paths = @(Get-GitPathsAsUtf8 -Root $Root) } catch { return @($_.Exception.Message) }
    if ($paths.Count -eq 0) { return @('git enumeration yielded zero files') }
    return @(Find-WindowsCheckoutBlocker -Paths $paths)
}

$script:MaintainerPwsh = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty Source

function Invoke-ResolveOnly {
    param([string]$Script, [string[]]$Arguments)
    if (-not $script:MaintainerPwsh) {
        return [pscustomobject]@{ Exit = 3; Out = 'PowerShell 7 is required for maintainer canaries.' }
    }
    $out = & $script:MaintainerPwsh -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments 2>&1
    [pscustomobject]@{ Exit = $LASTEXITCODE; Out = ($out -join "`n") }
}

if ($ScanRoot) {
    $scanFindings = @(Get-RepositoryPrivacyFindings -Root (Resolve-Path $ScanRoot).Path)
    if ($scanFindings) { $scanFindings | ForEach-Object { Write-Host $_ }; exit 1 }
    Write-Host 'repository privacy scan clean'
    exit 0
}

It 'maintainer canary resolution explicitly uses PowerShell 7' {
    Assert (-not [string]::IsNullOrWhiteSpace($script:MaintainerPwsh)) 'pwsh is required for maintainer canaries'
    $major = [Diagnostics.FileVersionInfo]::GetVersionInfo($script:MaintainerPwsh).ProductMajorPart
    Assert ($major -ge 7) "resolved maintainer host is not PowerShell 7+: $script:MaintainerPwsh ($major)"
}

It 'scanner recognizes concrete Windows, MSYS, Linux and macOS homes' {
    $samples = @(
        ('C:' + '\Users\' + 'ExamplePerson\file.txt'),
        ('d:' + '/users/' + 'example.person'),
        ('/c/Us' + 'ers/example-person/file'),
        ('/ho' + 'me/example_person'),
        ('/Us' + 'ers/example-person/Documents')
    )
    foreach ($sample in $samples) {
        $found = @(Find-PrivateHomePath -Text $sample -Path 'fixture.txt')
        Assert ($found.Count -eq 1) "expected one finding for dynamically assembled sample"
        Assert ($found[0] -match '^fixture\.txt:1:') "finding did not name file and line: $($found[0])"
    }
}

It 'scanner ignores placeholders and regex documentation' {
    $safe = @'
C:\Users\<account>\file
/home/<username>/file
DENY [A-Za-z]:[\\/]Users[\\/]
DENY /Users/[^/ \t]+/
'@
    Assert (@(Find-PrivateHomePath -Text $safe).Count -eq 0) 'placeholder or regex prose was treated as a concrete home'
}

It 'the current non-ignored working tree has no concrete private home paths' {
    $findings = @(Get-RepositoryPrivacyFindings -Root $repoRoot)
    if ($findings) { Assert $false ("private home paths found:`n  " + ($findings -join "`n  ")) }
    Assert $true 'clean'
}

It 'Windows checkout rule refuses reserved characters, control characters, a trailing space or dot and device names' {
    $bad = @('*.bodydiff', 'docs/aux.md', 'x./y', 'tail.', 'end /x', 'a\b.md', 'a?b', 'q"q', 'l<t', 'g>t', 'p|p', 'ads:x',
        'Con', 'aux .md', 'nul.tar.gz', 'COM1.txt', 'src/lpt9', 'conin$', ('tab' + [char]9), ('bell' + [char]7 + '/x'))
    foreach ($path in $bad) {
        Assert (@(Find-WindowsCheckoutBlocker -Paths @($path)).Count -eq 1) "not refused: $path"
    }
    $good = @('.gitignore', 'docs/console.md', 'com0.txt', 'com10', 'lpt/readme', 'auxiliary/x.md', 'dir.d/file', ('caf' + [char]0xE9 + '.md'))
    $found = @(Find-WindowsCheckoutBlocker -Paths $good)
    Assert ($found.Count -eq 0) ('refused a path Windows checks out: ' + ($found -join '; '))
}

It 'the Windows checkout scan reads a fixture index as UTF-8 and names each blocked path' {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('b360-' + [guid]::NewGuid().ToString('N'))
    try {
        & git init -q $temp 2>$null
        $blob = '' | & git -C $temp hash-object -w --stdin
        $cafe = 'docs/caf' + [char]0xE9 + '.md'
        foreach ($path in '*.bodydiff', 'docs/aux.md', 'x./y', $cafe) {
            & git -C $temp -c core.protectNTFS=false update-index --add --cacheinfo "100644,$blob,$path"
            Assert ($LASTEXITCODE -eq 0) "calibration: could not index $path"
        }
        $paths = @(Get-GitPathsAsUtf8 -Root $temp)
        Assert ($paths -ccontains $cafe) ('the non-ASCII path was not decoded as UTF-8: ' + ($paths -join '; '))
        $findings = @(Get-WindowsCheckoutFindings -Root $temp)
        Assert ($findings.Count -eq 3) ('expected three findings: ' + ($findings -join '; '))
        foreach ($path in '*.bodydiff', 'docs/aux.md', 'x./y') {
            Assert (@($findings | Where-Object { $_.StartsWith("${path}: ") }).Count -eq 1) "not named: $path"
        }
    } finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'every tracked or unignored path in the repository can be checked out on Windows' {
    $findings = @(Get-WindowsCheckoutFindings -Root $repoRoot)
    if ($findings) { Assert $false ("paths Windows cannot check out:`n  " + ($findings -join "`n  ")) }
    Assert $true 'clean'
}

It 'Copilot canaries resolve APPDATA defaults and explicit overrides without launching' {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('b122-copilot-' + [guid]::NewGuid().ToString('N'))
    $default = Join-Path $temp 'npm\copilot.cmd'
    $explicit = Join-Path $temp 'explicit path\copilot.cmd'
    New-Item -ItemType Directory -Path (Split-Path $default), (Split-Path $explicit) -Force | Out-Null
    Set-Content -LiteralPath $default, $explicit -Value '@echo off' -Encoding Ascii
    $old = $env:APPDATA
    try {
        $env:APPDATA = $temp
        foreach ($name in 'canary-applyto-scope.ps1','canary-copilot-instructions.ps1') {
            $script = Join-Path $repoRoot ".claude\scripts\$name"
            $r = Invoke-ResolveOnly $script @('-ResolveOnly')
            Assert ($r.Exit -eq 0 -and $r.Out -eq (Resolve-Path $default).Path) "$name did not resolve APPDATA default: $($r.Out)"
            $r = Invoke-ResolveOnly $script @('-ResolveOnly','-CopilotCmd',$explicit)
            Assert ($r.Exit -eq 0 -and $r.Out -eq (Resolve-Path $explicit).Path) "$name did not honor explicit override: $($r.Out)"
        }
    } finally { $env:APPDATA = $old }
}

It 'Claude canary resolves USERPROFILE default and explicit override without launching' {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('b122-claude-' + [guid]::NewGuid().ToString('N'))
    $default = Join-Path $temp '.local\bin\claude.exe'
    $explicit = Join-Path $temp 'explicit path\claude.exe'
    New-Item -ItemType Directory -Path (Split-Path $default), (Split-Path $explicit) -Force | Out-Null
    Set-Content -LiteralPath $default, $explicit -Value '' -Encoding Ascii
    $script = Join-Path $repoRoot '.claude\scripts\canary-single-carrier.ps1'
    $old = $env:USERPROFILE
    try {
        $env:USERPROFILE = $temp
        $r = Invoke-ResolveOnly $script @('-ResolveOnly')
        Assert ($r.Exit -eq 0 -and $r.Out -eq (Resolve-Path $default).Path) "Claude canary did not resolve USERPROFILE default: $($r.Out)"
        $r = Invoke-ResolveOnly $script @('-ResolveOnly','-ClaudeCmd',$explicit)
        Assert ($r.Exit -eq 0 -and $r.Out -eq (Resolve-Path $explicit).Path) "Claude canary did not honor explicit override: $($r.Out)"
    } finally { $env:USERPROFILE = $old }
}

It 'missing environment defaults fail with generic override guidance' {
    $oldApp = $env:APPDATA; $oldProfile = $env:USERPROFILE
    try {
        $env:APPDATA = $null; $env:USERPROFILE = $null
        $copilot = Invoke-ResolveOnly (Join-Path $repoRoot '.claude\scripts\canary-applyto-scope.ps1') @('-ResolveOnly')
        $claude = Invoke-ResolveOnly (Join-Path $repoRoot '.claude\scripts\canary-single-carrier.ps1') @('-ResolveOnly')
        Assert ($copilot.Exit -ne 0 -and $copilot.Out -match 'pass -CopilotCmd') "Copilot missing-default diagnostic is not actionable: $($copilot.Out)"
        Assert ($claude.Exit -ne 0 -and $claude.Out -match 'pass -ClaudeCmd') "Claude missing-default diagnostic is not actionable: $($claude.Out)"
    } finally { $env:APPDATA = $oldApp; $env:USERPROFILE = $oldProfile }
}

It 'Claude canaries honour -TimeoutSeconds against a hung CLI and report could-not-examine' {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('b464-timeout-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    $fake = Join-Path $temp 'claude.cmd'
    Set-Content -LiteralPath $fake -Value "@echo off`r`nping -n 21 127.0.0.1 >nul" -Encoding Ascii
    $oldPath = $env:PATH
    try {
        $env:PATH = "$temp;$env:PATH"
        $cases = @(
            @{ Name = 'canary-single-carrier.ps1';    Args = @('-ClaudeCmd', $fake, '-TimeoutSeconds', '5') }
            @{ Name = 'canary-import-resolution.ps1'; Args = @('-TimeoutSeconds', '5') }
        )
        foreach ($c in $cases) {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $r = Invoke-ResolveOnly (Join-Path $repoRoot ".claude\scripts\$($c.Name)") $c.Args
            $sw.Stop()
            Assert ($sw.Elapsed.TotalSeconds -lt 15) "$($c.Name) ignored -TimeoutSeconds 5: returned after $([int]$sw.Elapsed.TotalSeconds) s"
            Assert ($r.Exit -eq 2 -and $r.Out -match 'INCONCLUSIVE - the CLI did not finish within 5 s') "$($c.Name) did not report could-not-examine (exit $($r.Exit)): $($r.Out)"
        }
    } finally { $env:PATH = $oldPath; Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

function New-FakeCopilot {
    param([string]$Dir, [string]$Body)
    New-Item -ItemType Directory -Path $Dir -Force | Out-Null
    $path = Join-Path $Dir 'copilot.cmd'
    Set-Content -LiteralPath $path -Value ("@echo off`r`nif ""%~1""==""--version"" (echo fake-copilot 0.0 & exit /b 0)`r`n" + $Body) -Encoding Ascii
    return $path
}

It 'Copilot canaries score a sentinel hit with no tool use as before' {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('b464-hit-' + [guid]::NewGuid().ToString('N'))
    try {
        $fake = New-FakeCopilot $temp 'echo QUVIRAX-3T8P MELDOVAR-9K2R VANTORIX-5H1D PELGRAMO-8W2F KRESSIDA-4B7N'
        $r = Invoke-ResolveOnly (Join-Path $repoRoot '.claude\scripts\canary-copilot-instructions.ps1') @('-CopilotCmd', $fake, '-TimeoutSeconds', '60')
        Assert ($r.Exit -eq 0 -and $r.Out -match 'BOTH REACH') "copilot-instructions hit without tool use changed (exit $($r.Exit)): $($r.Out)"
        $r = Invoke-ResolveOnly (Join-Path $repoRoot '.claude\scripts\canary-applyto-scope.ps1') @('-CopilotCmd', $fake, '-TimeoutSeconds', '60')
        Assert ($r.Exit -eq 1 -and $r.Out -match 'DOES NOT GATE') "applyto-scope hit without tool use changed (exit $($r.Exit)): $($r.Out)"
    } finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'Copilot canaries score a sentinel hit alongside a file-tool use as inconclusive' {
    $temp = Join-Path ([IO.Path]::GetTempPath()) ('b464-tool-' + [guid]::NewGuid().ToString('N'))
    try {
        $fake = New-FakeCopilot $temp 'echo Reading file .github/instructions/x.md & echo QUVIRAX-3T8P MELDOVAR-9K2R VANTORIX-5H1D PELGRAMO-8W2F KRESSIDA-4B7N'
        $r = Invoke-ResolveOnly (Join-Path $repoRoot '.claude\scripts\canary-copilot-instructions.ps1') @('-CopilotCmd', $fake, '-TimeoutSeconds', '60')
        Assert ($r.Exit -eq 2 -and $r.Out -match 'INCONCLUSIVE - a hit came with a file-tool use') "copilot-instructions scored a tool-assisted hit (exit $($r.Exit)): $($r.Out)"
        $r = Invoke-ResolveOnly (Join-Path $repoRoot '.claude\scripts\canary-applyto-scope.ps1') @('-CopilotCmd', $fake, '-TimeoutSeconds', '60')
        Assert ($r.Exit -eq 2 -and $r.Out -match 'INCONCLUSIVE - a hit came with a file-tool use') "applyto-scope scored a tool-assisted hit (exit $($r.Exit)): $($r.Out)"
    } finally { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}

exit (Write-TestSummary 'RepositoryPrivacy.Tests (authoring-tree privacy)')
