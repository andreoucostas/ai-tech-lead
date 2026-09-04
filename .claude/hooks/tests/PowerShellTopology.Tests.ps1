# Windows-only topology contract. Historical shell canaries under meta/canaries are deliberately
# outside the active roots; framework-owned executable and configuration surfaces are not.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

function Get-TopologyFindings {
    param([Parameter(Mandatory)][IO.FileInfo[]]$Files)
    $findings = New-Object System.Collections.Generic.List[string]
    foreach ($file in $Files) {
        $relative = if ($file.FullName.StartsWith($repoRoot, [StringComparison]::OrdinalIgnoreCase)) {
            $file.FullName.Substring($repoRoot.Length).TrimStart('\','/').Replace('\','/')
        } else {
            $file.FullName.Replace('\','/')
        }
        if ($file.Extension -ieq '.sh') { $findings.Add("shell-file:$relative") }
        try {
            $reader = New-Object IO.StreamReader($file.FullName, [Text.Encoding]::UTF8, $true)
            try { $firstLine = $reader.ReadLine() } finally { $reader.Dispose() }
        } catch {
            $findings.Add("cant-verify:$relative")
            continue
        }
        if ($firstLine -match '^#!.*(?:[/\s])(?:ba|da|a|z|k|c|tc|fi)?sh(?:\.exe)?(?:\s|$)') {
            $findings.Add("shell-shebang:$relative")
        }
        if ($relative -match '(?:^|/)\.github/workflows/[^/]+\.ya?ml$') {
            try { $text = [IO.File]::ReadAllText($file.FullName) }
            catch { $findings.Add("cant-verify:$relative"); continue }
            # The runner may come from a matrix, leaving only an expression on the runs-on line.
            # Ignore comment-only lines, then inspect all executable YAML values.
            $activeYaml = (($text -split "`r?`n") | Where-Object { $_ -notmatch '^\s*#' }) -join "`n"
            if ($activeYaml -match '(?i)(?:^|[^A-Za-z0-9_])(?:ubuntu|linux|macos)(?:[-_.A-Za-z0-9]*)(?:$|[^A-Za-z0-9_])') {
                $findings.Add("non-windows-runner:$relative")
            }
            if ($activeYaml -match '(?im)^\s*container\s*:') {
                $findings.Add("unsupported-container:$relative")
            }
        }
        if ($relative -match '(?:^|/)\.claude/settings(?:\.windows)?\.json$' -or
            $relative -match '(?:^|/)\.github/hooks/hooks\.json$') {
            try { $text = [IO.File]::ReadAllText($file.FullName) }
            catch { $findings.Add("cant-verify:$relative"); continue }
            if ($text -match '(?i)"bash"\s*:') { $findings.Add("bash-hook-key:$relative") }
        }
    }
    return $findings.ToArray()
}

function Get-ActiveFrameworkFiles {
    $files = New-Object System.Collections.Generic.List[IO.FileInfo]
    foreach ($root in @('scripts','src','dist','.claude/hooks','.claude/scripts','.claude/git-hooks','.github/workflows','.github/hooks')) {
        $absolute = Join-Path $repoRoot $root
        if (-not (Test-Path -LiteralPath $absolute -PathType Container)) { continue }
        foreach ($file in @(Get-ChildItem -LiteralPath $absolute -Recurse -File -Force -ErrorAction Stop)) {
            $files.Add($file)
        }
    }
    foreach ($relative in @('install.ps1','install.sh','.claude/settings.json')) {
        $absolute = Join-Path $repoRoot $relative
        if (Test-Path -LiteralPath $absolute -PathType Leaf) { $files.Add((Get-Item -LiteralPath $absolute -Force)) }
    }
    return $files.ToArray()
}

Reset-Tests

It 'active framework roots are PowerShell-only and Windows-only' {
    $files = @(Get-ActiveFrameworkFiles)
    Assert ($files.Count -gt 100) "active-root enumeration reached only $($files.Count) files"
    $findings = @(Get-TopologyFindings -Files $files)
    Assert ($findings.Count -eq 0) ("active topology findings:`n" + ($findings -join "`n"))
}

It 'the only repository shell files are the four frozen historical canaries' {
    $expected = @(
        'meta/canaries/agent-stop-delivery/.github/hooks/agent-stop.sh'
        'meta/canaries/b50-copilot-posttooluse/.github/hooks/post-token.sh'
        'meta/canaries/b52-copilot-two-hook/.github/hooks/hook-a.sh'
        'meta/canaries/b52-copilot-two-hook/.github/hooks/hook-b.sh'
    )
    $found = New-Object System.Collections.Generic.List[string]
    $pending = New-Object System.Collections.Generic.Stack[IO.DirectoryInfo]
    $pending.Push((Get-Item -LiteralPath $repoRoot -Force))
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        foreach ($entry in @(Get-ChildItem -LiteralPath $directory.FullName -Force -ErrorAction Stop)) {
            $relative = $entry.FullName.Substring($repoRoot.Length).TrimStart('\','/').Replace('\','/')
            if ($entry.PSIsContainer) {
                if ($relative -in @('.git','.claude/worktrees') -or
                    $relative.StartsWith('.git/', [StringComparison]::OrdinalIgnoreCase) -or
                    $relative.StartsWith('.claude/worktrees/', [StringComparison]::OrdinalIgnoreCase) -or
                    (($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { continue }
                $pending.Push($entry)
            } elseif ($entry.Extension -ieq '.sh') { $found.Add($relative) }
        }
    }
    $actual = @($found | Sort-Object)
    Assert ($actual.Count -eq $expected.Count) "expected four shell canaries, found $($actual.Count): $($actual -join ', ')"
    Assert (($actual -join "`n") -ceq (($expected | Sort-Object) -join "`n")) `
        "shell canary set drifted. expected=$($expected -join ', ') actual=$($actual -join ', ')"
}

It 'the topology instrument detects every prohibited surface' {
    $fixture = Join-Path ([IO.Path]::GetTempPath()) ('ps-topology-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path (Join-Path $fixture '.github/workflows') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $fixture '.github/hooks') | Out-Null
    try {
        [IO.File]::WriteAllText((Join-Path $fixture 'active.sh'), "#!/usr/bin/env bash`nexit 0`n")
        [IO.File]::WriteAllText((Join-Path $fixture 'launcher'), "#!/bin/sh`nexit 0`n")
        [IO.File]::WriteAllText((Join-Path $fixture '.github/workflows/ci.yml'), "jobs:`n  test:`n    strategy:`n      matrix:`n        os: [windows-latest, ubuntu-latest]`n    runs-on: `${{ matrix.os }}`n")
        [IO.File]::WriteAllText((Join-Path $fixture '.github/workflows/container.yml'), "jobs:`n  test:`n    runs-on: windows-latest`n    container: example/image:latest`n")
        [IO.File]::WriteAllText((Join-Path $fixture '.github/hooks/hooks.json'), '{"hooks":{"x":[{"bash":"guard.sh"}]}}')
        $files = @(Get-ChildItem -LiteralPath $fixture -Recurse -File -Force)
        # Fixture paths are outside $repoRoot, so inspect the stable finding prefixes only.
        $findings = @(Get-TopologyFindings -Files $files)
        foreach ($prefix in @('shell-file:','shell-shebang:','non-windows-runner:','unsupported-container:','bash-hook-key:')) {
            Assert (@($findings | Where-Object { $_.StartsWith($prefix, [StringComparison]::Ordinal) }).Count -gt 0) `
                "mutation did not trigger $prefix"
        }
    } finally {
        Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'PowerShellTopology.Tests')
