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

function Invoke-ResolveOnly {
    param([string]$Script, [string[]]$Arguments)
    $exe = (Get-Process -Id $PID).Path
    $out = & $exe -NoProfile -ExecutionPolicy Bypass -File $Script @Arguments 2>&1
    [pscustomobject]@{ Exit = $LASTEXITCODE; Out = ($out -join "`n") }
}

if ($ScanRoot) {
    $scanFindings = @(Get-RepositoryPrivacyFindings -Root (Resolve-Path $ScanRoot).Path)
    if ($scanFindings) { $scanFindings | ForEach-Object { Write-Host $_ }; exit 1 }
    Write-Host 'repository privacy scan clean'
    exit 0
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

exit (Write-TestSummary 'RepositoryPrivacy.Tests (authoring-tree privacy)')
