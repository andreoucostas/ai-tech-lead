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

# ---- instruction-layout canaries (stub tools only; no model is ever started) ----
$script:ClaudeStubText = @'
$here = Split-Path -Parent $PSCommandPath
if ($args.Count -ge 1 -and $args[0] -eq '--version') { 'stub-claude 9.9.9 (Claude Code)'; exit 0 }
$mode = (Get-Content -LiteralPath (Join-Path $here 'mode.txt') -Raw).Trim()
$cwd = (Get-Location).Path
$files = [ordered]@{}
Get-ChildItem -LiteralPath $cwd -Recurse -File -Force | ForEach-Object {
    $files[($_.FullName.Substring($cwd.Length).TrimStart('\', '/') -replace '\\', '/')] = [IO.File]::ReadAllText($_.FullName)
}
[ordered]@{ cwd = $cwd; args = @($args | ForEach-Object { [string]$_ }); files = $files } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $here 'snapshot.json')
function Expand-Text($rel, $depth) {
    $text = $files[$rel]; $out = $text
    if ($null -eq $text -or $depth -gt 4) { return $out }
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^@(\S+)$') {
            $dir = [IO.Path]::GetDirectoryName("C:\v\$rel")
            $t = [IO.Path]::GetFullPath((Join-Path $dir $Matches[1])).Substring(5) -replace '\\', '/'
            if ($files.Contains($t)) { $out += "`n" + (Expand-Text $t ($depth + 1)) }
        }
    }
    $out
}
$ctx = ''
$hasClaude = @($files.Keys | Where-Object { $_ -in @('CLAUDE.md', '.claude/CLAUDE.md', 'CLAUDE.local.md') }).Count -gt 0
if ($hasClaude) { foreach ($k in 'CLAUDE.md', '.claude/CLAUDE.md', 'CLAUDE.local.md') { if ($files.Contains($k)) { $ctx += (Expand-Text $k 0) + "`n" } } }
elseif ($files.Contains('AGENTS.md')) { $ctx += (Expand-Text 'AGENTS.md' 0) + "`n" }
foreach ($k in $files.Keys) {
    if ($k -like '.claude/rules/*.md') { $ctx += $(if ($mode -match 'rulesimport') { Expand-Text $k 0 } else { $files[$k] }) + "`n" }
}
$cw = '[A-Z]{7}-[A-Z0-9]{4}'
$a = ([regex]::Match([string]$files['AGENTS.md'], $cw)).Value
$r = ''
foreach ($k in $files.Keys) { if ($k -ne 'AGENTS.md' -and -not $r) { $m = [regex]::Match([string]$files[$k], $cw); if ($m.Success) { $r = $m.Value } } }
$found = @([regex]::Matches($ctx, $cw) | ForEach-Object { $_.Value } | Select-Object -Unique)
$say = if ($mode -like 'say:*') { @(($mode.Substring(4) -split ',') | Where-Object { $_ -ne 'none' } | ForEach-Object { if ($_ -eq 'A') { $a } else { $r } }) }
       elseif ($mode -eq 'read') { @($a) }
       else { $found }
$text = if ($say.Count) { $say -join "`n" } else { 'NONE' }
'{"type":"system","subtype":"init"}'
if ($mode -eq 'read') {
    (@{ type = 'assistant'; message = @{ content = @(@{ type = 'tool_use'; id = 't1'; name = 'Read'; input = @{ file_path = 'AGENTS.md' } }) } } | ConvertTo-Json -Compress -Depth 8)
}
if ($mode -eq 'empty') { exit 0 }
(@{ type = 'assistant'; message = @{ content = @(@{ type = 'text'; text = $text }) } } | ConvertTo-Json -Compress -Depth 8)
(@{ type = 'result'; is_error = $false; result = $text } | ConvertTo-Json -Compress)
'@

$script:CopilotStubText = @'
$here = Split-Path -Parent $PSCommandPath
if ($args.Count -ge 1 -and $args[0] -eq '--version') { 'stub-copilot 7.7.7'; exit 0 }
$mode = (Get-Content -LiteralPath (Join-Path $here 'mode.txt') -Raw).Trim()
$cwd = (Get-Location).Path
$files = [ordered]@{}
Get-ChildItem -LiteralPath $cwd -Recurse -File -Force | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } | ForEach-Object {
    $files[($_.FullName.Substring($cwd.Length).TrimStart('\', '/') -replace '\\', '/')] = [IO.File]::ReadAllText($_.FullName)
}
[ordered]@{ cwd = $cwd; args = @($args | ForEach-Object { [string]$_ }); files = $files } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $here 'snapshot.json')
function Expand-Text($rel, $depth) {
    $text = $files[$rel]; $out = $text
    if ($null -eq $text -or $depth -gt 4) { return $out }
    foreach ($line in ($text -split "`r?`n")) {
        if ($line -match '^@(\S+)$') {
            $dir = [IO.Path]::GetDirectoryName("C:\v\$rel")
            $t = [IO.Path]::GetFullPath((Join-Path $dir $Matches[1])).Substring(5) -replace '\\', '/'
            if ($files.Contains($t)) { $out += "`n" + (Expand-Text $t ($depth + 1)) }
        }
    }
    $out
}
$parts = @()
foreach ($k in 'AGENTS.md', 'CLAUDE.md') { if ($files.Contains($k)) { $parts += (Expand-Text $k 0) } }
foreach ($k in $files.Keys) {
    if ($k -like '.github/instructions/*.instructions.md' -and $files[$k] -match '(?m)^applyTo:') { $parts += $files[$k] }
    if ($k -like '.claude/rules/*.md') { $parts += $files[$k] }
}
$all = $parts -join "`n----`n"
$root = $env:STUB_SESSION_ROOT
function New-Session($lines) {
    $d = Join-Path $root ([guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $d -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $d 'events.jsonl') -Value $lines -Encoding utf8
}
$decoy = @((@{ type = 'session.start'; data = @{ context = @{ cwd = 'C:\somewhere\else' } } } | ConvertTo-Json -Compress -Depth 6),
           (@{ type = 'user.message'; data = @{ transformedContent = $all + $all + $all } } | ConvertTo-Json -Compress -Depth 6))
New-Session $decoy
if ($mode -ne 'noevents') {
    $lines = @((@{ type = 'session.start'; data = @{ context = @{ cwd = $cwd } } } | ConvertTo-Json -Compress -Depth 6),
               (@{ type = 'user.message'; data = @{ content = 'prompt'; transformedContent = $all + "`nprompt" } } | ConvertTo-Json -Compress -Depth 6))
    if ($mode -eq 'tool') { $lines += (@{ type = 'tool.execution_start'; data = @{ toolName = 'view' } } | ConvertTo-Json -Compress -Depth 6) }
    $lines += (@{ type = 'assistant.message'; data = @{ content = ((($all -split '\s+') | Where-Object { $_ -match '^[A-Z]{7}-[A-Z0-9]{4}$' }) -join ' ') } } | ConvertTo-Json -Compress -Depth 6)
    New-Session $lines
}
'stub reply'
'@

$script:CodewordRx = '[A-Z]{7}-[A-Z0-9]{4}'

function New-StubDir {
    param([string]$Name, [string]$Text, [string]$Mode)
    $d = Join-Path ([IO.Path]::GetTempPath()) ('layoutcanary-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $d, (Join-Path $d 'fx'), (Join-Path $d 'sessions') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $d $Name) -Value $Text -Encoding utf8
    Set-Content -LiteralPath (Join-Path $d 'mode.txt') -Value $Mode
    [pscustomobject]@{ Dir = $d; Cmd = (Join-Path $d $Name); Fx = (Join-Path $d 'fx'); Sessions = (Join-Path $d 'sessions') }
}

function Invoke-LayoutCanary {
    param([string]$ScriptName, [string]$Layout, [string]$Mode = 'faithful', [string[]]$Extra = @(), [string]$ToolOverride = '', [scriptblock]$Prepare)
    $isClaude = $ScriptName -eq 'canary-import-resolution.ps1'
    $s = New-StubDir $(if ($isClaude) { 'claude-stub.ps1' } else { 'copilot-stub.ps1' }) $(if ($isClaude) { $script:ClaudeStubText } else { $script:CopilotStubText }) $Mode
    $old = $env:STUB_SESSION_ROOT
    try {
        $env:STUB_SESSION_ROOT = $s.Sessions
        if ($Prepare) { & $Prepare $s }
        $cmd = if ($ToolOverride) { $ToolOverride } else { $s.Cmd }
        $a = @('-Layout', $Layout, $(if ($isClaude) { '-ClaudeCmd' } else { '-CopilotCmd' }), $cmd, '-FixtureParent', $s.Fx, '-TimeoutSeconds', '60')
        if (-not $isClaude) { $a += @('-SessionStateRoot', $s.Sessions) }
        $r = Invoke-ResolveOnly (Join-Path $repoRoot ".claude\scripts\$ScriptName") ($a + $Extra)
        $snapPath = Join-Path $s.Dir 'snapshot.json'
        [pscustomobject]@{
            Exit = $r.Exit; Out = $r.Out
            Canary = @($r.Out -split "`n" | Where-Object { $_ -like 'CANARY *' })
            Snap = $(if (Test-Path -LiteralPath $snapPath) { Get-Content -LiteralPath $snapPath -Raw | ConvertFrom-Json -AsHashtable } else { $null })
            Leftover = @(Get-ChildItem -LiteralPath $s.Fx -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'CLAUDE.md' }).Count
            Dir = $s.Dir
        }
    } finally {
        $env:STUB_SESSION_ROOT = $old
    }
}
function Remove-Quiet { param([string]$Path) Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue }

$script:ClaudeLayouts = [ordered]@{
    'agents-only'           = @{ Files = @('AGENTS.md'); A = 'IN'; R = 'n/a'; Verdict = 'AS-EXPECTED' }
    'agents-import'         = @{ Files = @('AGENTS.md', '.github/instructions/framework-rules.instructions.md'); A = 'IN'; R = 'IN'; Verdict = 'AS-EXPECTED' }
    'rules-folder'          = @{ Files = @('AGENTS.md', '.claude/rules/framework-rules.md'); A = 'IN'; R = 'IN'; Verdict = 'AS-EXPECTED' }
    'shadowed'              = @{ Files = @('AGENTS.md', 'CLAUDE.local.md'); A = 'OUT'; R = 'n/a'; Verdict = 'AS-EXPECTED' }
    'shadowed-rules-folder' = @{ Files = @('AGENTS.md', '.claude/rules/framework-rules.md', 'CLAUDE.local.md'); A = 'OUT'; R = 'IN'; Verdict = 'AS-EXPECTED' }
    'shadowed-rules-import' = @{ Files = @('AGENTS.md', '.github/instructions/framework-rules.instructions.md', '.claude/rules/framework.md', 'CLAUDE.local.md'); A = 'OUT'; R = 'OUT'; Verdict = 'OBSERVED' }
}

It 'Claude layout canary builds exactly the files each layout claims, sentinels only where intended' {
    foreach ($name in $script:ClaudeLayouts.Keys) {
        $L = $script:ClaudeLayouts[$name]
        $r = Invoke-LayoutCanary 'canary-import-resolution.ps1' $name
        try {
            Assert ($null -ne $r.Snap) "$name built no fixture the stub could read (exit $($r.Exit)): $($r.Out)"
            $got = @($r.Snap.files.Keys | Sort-Object)
            Assert (($got -join '|') -eq (($L.Files | Sort-Object) -join '|')) "$name fixture files differ: $($got -join ', ')"
            Assert (-not ($r.Snap.cwd.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase))) "$name fixture is inside the repository: $($r.Snap.cwd)"
            $agents = [regex]::Matches($r.Snap.files['AGENTS.md'], $script:CodewordRx)
            Assert ($agents.Count -eq 1) "$name AGENTS.md should carry exactly one sentinel, has $($agents.Count)"
            $aSent = $agents[0].Value
            foreach ($k in $r.Snap.files.Keys) {
                if ($k -ne 'AGENTS.md') { Assert (-not ($r.Snap.files[$k] -match [regex]::Escape($aSent))) "$name sentinel A leaked into $k" }
            }
            $others = @($r.Snap.files.Keys | Where-Object { $_ -ne 'AGENTS.md' -and $r.Snap.files[$_] -cmatch $script:CodewordRx })
            if ($L.R -eq 'n/a') { Assert ($others.Count -eq 0) "$name should hold no second sentinel, found one in $($others -join ', ')" }
            else {
                Assert ($others.Count -eq 1) "$name sentinel R must live in exactly one file, found $($others -join ', ')"
                $rSent = [regex]::Match($r.Snap.files[$others[0]], $script:CodewordRx).Value
                Assert ($rSent -ne $aSent) "$name R equals A"
                Assert (-not ($r.Snap.files['AGENTS.md'] -match [regex]::Escape($rSent))) "$name sentinel R leaked into AGENTS.md"
            }
            $hasClaudeFile = @($r.Snap.files.Keys | Where-Object { $_ -in @('CLAUDE.md', '.claude/CLAUDE.md') }).Count
            Assert ($hasClaudeFile -eq 0) "$name built a CLAUDE.md"
            Assert (($r.Snap.files.ContainsKey('CLAUDE.local.md')) -eq ($name -like 'shadowed*')) "$name CLAUDE.local.md presence is wrong"
            if ($name -eq 'agents-import') { Assert ($r.Snap.files['AGENTS.md'] -match '(?m)^@\.github/instructions/framework-rules\.instructions\.md\s*$') 'agents-import AGENTS.md lacks the import line' }
            if ($name -like '*rules-folder') { Assert (-not ($r.Snap.files['.claude/rules/framework-rules.md'] -match '(?m)^---')) "$name rules file has front matter" }
            if ($name -eq 'shadowed-rules-import') {
                $lines = @($r.Snap.files['.claude/rules/framework.md'] -split "`r?`n" | Where-Object { $_.Trim() })
                Assert (($lines -join '|') -eq '@../../AGENTS.md|@../../.github/instructions/framework-rules.instructions.md') "shadowed-rules-import rules file is not the two import lines: $($lines -join '|')"
            }
            Assert ($r.Leftover -eq 0) "$name left its fixture behind"
        } finally { Remove-Quiet $r.Dir }
    }
}

It 'Claude layout canary scores IN and OUT from the answer and exits 0 on the expected result' {
    foreach ($name in $script:ClaudeLayouts.Keys) {
        $L = $script:ClaudeLayouts[$name]
        $r = Invoke-LayoutCanary 'canary-import-resolution.ps1' $name
        try {
            Assert ($r.Exit -eq 0) "$name expected exit 0, got $($r.Exit): $($r.Out)"
            Assert ($r.Canary.Count -eq 1) "$name printed $($r.Canary.Count) CANARY lines"
            $want = "CANARY layout=$name bare=false A=$($L.A) R=$($L.R) file_reads=0 "
            Assert ($r.Canary[0].StartsWith($want)) "$name CANARY line is not '$want...': $($r.Canary[0])"
            Assert ($r.Canary[0] -match "verdict=$($L.Verdict) tool=stub-claude 9\.9\.9") "$name verdict/tool wrong: $($r.Canary[0])"
            Assert (($r.Out -split "`n")[-1] -like 'CANARY *') "$name CANARY line is not the last line"
        } finally { Remove-Quiet $r.Dir }
    }
    $r = Invoke-LayoutCanary 'canary-import-resolution.ps1' 'shadowed-rules-import' 'faithful-rulesimport'
    try { Assert ($r.Exit -eq 0 -and $r.Canary[0] -match 'A=IN R=IN .*expected=unknown verdict=OBSERVED') "unknown layout did not report what was seen: $($r.Canary[0])" } finally { Remove-Quiet $r.Dir }
}

It 'Claude layout canary exits 1 UNEXPECTED when the answer contradicts the documented expectation' {
    $r = Invoke-LayoutCanary 'canary-import-resolution.ps1' 'agents-only' 'say:none'
    try { Assert ($r.Exit -eq 1 -and $r.Canary[0] -match 'A=OUT .*verdict=UNEXPECTED') "missing A was not UNEXPECTED (exit $($r.Exit)): $($r.Canary[0])"; Assert ($r.Leftover -eq 0) 'fixture left behind' } finally { Remove-Quiet $r.Dir }
    $r = Invoke-LayoutCanary 'canary-import-resolution.ps1' 'shadowed' 'say:A'
    try { Assert ($r.Exit -eq 1 -and $r.Canary[0] -match 'A=IN .*verdict=UNEXPECTED') "unshadowed A was not UNEXPECTED (exit $($r.Exit)): $($r.Canary[0])" } finally { Remove-Quiet $r.Dir }
}

It 'Claude layout canary exits 2 INCONCLUSIVE on a file-access tool call or an empty run, and removes the fixture' {
    $r = Invoke-LayoutCanary 'canary-import-resolution.ps1' 'agents-only' 'read'
    try { Assert ($r.Exit -eq 2 -and $r.Canary[0] -match 'file_reads=1 .*verdict=INCONCLUSIVE') "file read not INCONCLUSIVE (exit $($r.Exit)): $($r.Canary[0]) / $($r.Out)"; Assert ($r.Leftover -eq 0) 'fixture left behind' } finally { Remove-Quiet $r.Dir }
    $r = Invoke-LayoutCanary 'canary-import-resolution.ps1' 'agents-only' 'empty'
    try { Assert ($r.Exit -eq 2 -and $r.Canary[0] -match 'verdict=INCONCLUSIVE') "empty answer not INCONCLUSIVE (exit $($r.Exit)): $($r.Out)" } finally { Remove-Quiet $r.Dir }
}

It 'Claude layout canary exits 2 when the tool is missing, or a CLAUDE.md sits above the fixture' {
    $r = Invoke-LayoutCanary 'canary-import-resolution.ps1' 'agents-only' 'faithful' @() 'C:\no-such-dir\claude.exe'
    try { Assert ($r.Exit -eq 2 -and $r.Canary[0] -match 'verdict=INCONCLUSIVE tool=unavailable') "missing tool not exit 2 (exit $($r.Exit)): $($r.Out)"; Assert ($r.Leftover -eq 0) 'fixture left behind' } finally { Remove-Quiet $r.Dir }
    $r = Invoke-LayoutCanary 'canary-import-resolution.ps1' 'agents-only' 'faithful' @() '' { param($s) Set-Content -LiteralPath (Join-Path $s.Fx 'CLAUDE.md') -Value 'above' }
    try { Assert ($r.Exit -eq 2 -and $null -eq $r.Snap -and $r.Out -match 'above the fixture') "ancestor CLAUDE.md not caught (exit $($r.Exit)): $($r.Out)" } finally { Remove-Quiet $r.Dir }
}

It 'Claude layout canary -Bare adds --bare, reports OBSERVED, and the call stays cheap and one-shot' {
    $r = Invoke-LayoutCanary 'canary-import-resolution.ps1' 'agents-only' 'faithful' @('-Bare')
    try {
        Assert ($r.Exit -eq 0 -and $r.Canary[0] -match 'layout=agents-only bare=true .*expected=unknown verdict=OBSERVED') "bare line wrong (exit $($r.Exit)): $($r.Canary[0])"
        Assert ($r.Snap.args -contains '--bare') 'the one-shot call lacks --bare'
        Assert (($r.Snap.args -contains '--model') -and ($r.Snap.args -contains 'haiku') -and ($r.Snap.args -contains '--max-budget-usd')) "model or budget flags missing: $($r.Snap.args -join ' ')"
    } finally { Remove-Quiet $r.Dir }
    $r = Invoke-LayoutCanary 'canary-import-resolution.ps1' 'agents-only'
    try { Assert (-not ($r.Snap.args -contains '--bare')) 'a run without -Bare passed --bare' } finally { Remove-Quiet $r.Dir }
}

It 'Claude canary default invocation still builds the CLAUDE.md-import fixture and scores POSITIVE' {
    $s = New-StubDir 'claude-stub.ps1' $script:ClaudeStubText 'faithful'
    try {
        $r = Invoke-ResolveOnly (Join-Path $repoRoot '.claude\scripts\canary-import-resolution.ps1') @('-ClaudeCmd', $s.Cmd, '-TimeoutSeconds', '60')
        if ($r.Out -match 'Fixture: (\S+)') { Remove-Quiet $Matches[1] }
        Assert ($r.Exit -eq 0 -and $r.Out -match 'VERDICT: POSITIVE' -and $r.Out -notmatch 'CANARY layout=') "default invocation changed (exit $($r.Exit)): $($r.Out)"
    } finally { Remove-Quiet $s.Dir }
}

$script:CopilotLayouts = [ordered]@{
    'agents-only'             = @{ Files = @('AGENTS.md'); A = 1; R = 'n/a'; R2 = 'n/a' }
    'agents-plus-claude-stub' = @{ Files = @('AGENTS.md', 'CLAUDE.md', '.github/instructions/framework-rules.instructions.md'); A = 2; R = 2; R2 = 'n/a' }
    'agents-import'           = @{ Files = @('AGENTS.md', '.github/instructions/framework-rules.instructions.md'); A = 1; R = 2; R2 = 'n/a' }
    'rules-both-folders'      = @{ Files = @('AGENTS.md', '.github/instructions/framework-rules.instructions.md', '.claude/rules/framework-rules.md'); A = 1; R = 1; R2 = 1 }
}

It 'Copilot layout canary builds the files each layout claims and prints the counts the events file shows' {
    foreach ($name in $script:CopilotLayouts.Keys) {
        $L = $script:CopilotLayouts[$name]
        $r = Invoke-LayoutCanary 'canary-copilot-instructions.ps1' $name
        try {
            Assert ($null -ne $r.Snap) "$name built no fixture (exit $($r.Exit)): $($r.Out)"
            $got = @($r.Snap.files.Keys | Sort-Object)
            Assert (($got -join '|') -eq (($L.Files | Sort-Object) -join '|')) "$name fixture files differ: $($got -join ', ')"
            Assert (-not ($r.Snap.cwd.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase))) "$name fixture is inside the repository"
            Assert ((-not $r.Snap.files.ContainsKey('CLAUDE.md')) -eq ($name -ne 'agents-plus-claude-stub')) "$name CLAUDE.md presence is wrong"
            Assert ([regex]::Matches($r.Snap.files['AGENTS.md'], $script:CodewordRx).Count -eq 1) "$name AGENTS.md should carry exactly one sentinel"
            if ($name -eq 'agents-plus-claude-stub') {
                $cl = @($r.Snap.files['CLAUDE.md'] -split "`r?`n" | Where-Object { $_ -like '@*' })
                Assert (($cl -join '|') -eq '@AGENTS.md|@.github/instructions/framework-rules.instructions.md') "CLAUDE.md import lines wrong: $($cl -join '|')"
            }
            if ($L.R -ne 'n/a') { Assert ($r.Snap.files['.github/instructions/framework-rules.instructions.md'] -match '(?m)^applyTo: "\*\*"') "$name rules file lacks applyTo" }
            Assert ($r.Exit -eq 0) "$name expected exit 0, got $($r.Exit): $($r.Out)"
            Assert ($r.Canary.Count -eq 1 -and (($r.Out -split "`n")[-1]) -like 'CANARY *') "$name did not print one final CANARY line"
            $want = "CANARY layout=$name A_count=$($L.A) R_count=$($L.R) R2_count=$($L.R2) verdict=OBSERVED tool=stub-copilot 7.7.7"
            Assert ($r.Canary[0] -eq $want) "$name line is '$($r.Canary[0])', wanted '$want'"
            Assert ($r.Leftover -eq 0) "$name left its fixture behind"
        } finally { Remove-Quiet $r.Dir }
    }
}

It 'Copilot layout canary exits 2 INCONCLUSIVE on a tool call, no events file, or a missing tool' {
    $r = Invoke-LayoutCanary 'canary-copilot-instructions.ps1' 'agents-only' 'tool'
    try { Assert ($r.Exit -eq 2 -and $r.Canary[0] -match 'verdict=INCONCLUSIVE') "tool call not INCONCLUSIVE (exit $($r.Exit)): $($r.Out)" } finally { Remove-Quiet $r.Dir }
    $r = Invoke-LayoutCanary 'canary-copilot-instructions.ps1' 'agents-only' 'noevents'
    try { Assert ($r.Exit -eq 2 -and $r.Canary[0] -match 'verdict=INCONCLUSIVE') "missing events not INCONCLUSIVE (exit $($r.Exit)): $($r.Out)"; Assert ($r.Leftover -eq 0) 'fixture left behind' } finally { Remove-Quiet $r.Dir }
    $r = Invoke-LayoutCanary 'canary-copilot-instructions.ps1' 'agents-only' 'faithful' @() 'C:\no-such-dir\copilot.cmd'
    try { Assert ($r.Exit -eq 2 -and $r.Canary[0] -match 'verdict=INCONCLUSIVE tool=unavailable') "missing tool not exit 2 (exit $($r.Exit)): $($r.Out)" } finally { Remove-Quiet $r.Dir }
}

exit (Write-TestSummary 'RepositoryPrivacy.Tests (authoring-tree privacy)')
