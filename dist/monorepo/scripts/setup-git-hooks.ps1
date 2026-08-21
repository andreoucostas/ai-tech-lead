# Installs or runs the opt-in consumer pre-commit convenience net. Bypassable with --no-verify;
# this is not enforcement. Scan mode invokes the shipped guard so its patterns cannot drift.
param(
    [Parameter(Position = 0)][string]$Target = '.',
    [switch]$Scan,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'

function Invoke-GitText {
    param([Parameter(Mandatory)][string[]]$Arguments, [switch]$AllowNotFound)
    $output = & git @Arguments 2>&1
    $code = $LASTEXITCODE
    if ($AllowNotFound -and $code -eq 1) { return $null }
    if ($code -ne 0) {
        [Console]::Error.WriteLine("git $($Arguments -join ' ') could not examine the repository (exit $code): $($output -join [Environment]::NewLine)")
        exit 2
    }
    return [string]($output -join [Environment]::NewLine)
}

function Get-RepoRoot([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        [Console]::Error.WriteLine("Git-hook setup refused: target '$Path' is not a directory.")
        exit 2
    }
    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $root = Invoke-GitText -Arguments @('-C', $resolved, 'rev-parse', '--show-toplevel')
    return $root.Trim()
}

function Invoke-StagedScan([string]$RepoRoot) {
    $guard = Join-Path $RepoRoot '.claude/hooks/guard.ps1'
    if (-not (Test-Path -LiteralPath $guard -PathType Leaf)) {
        [Console]::Error.WriteLine('COMMIT REFUSED: the shipped guard.ps1 was not found.')
        exit 1
    }

    $namesRaw = & git -C $RepoRoot diff --cached --name-only --diff-filter=ACMR -z -- 2>&1
    if ($LASTEXITCODE -ne 0) {
        [Console]::Error.WriteLine("COMMIT REFUSED: git could not list staged paths: $namesRaw")
        exit 1
    }
    $names = @(([string]$namesRaw).Split([char]0) | Where-Object Length)
    $refused = $false
    foreach ($name in $names) {
        $diff = & git -C $RepoRoot diff --cached --no-ext-diff --no-color --unified=0 -- $name 2>&1
        if ($LASTEXITCODE -ne 0) {
            [Console]::Error.WriteLine("COMMIT REFUSED: git could not read staged additions for '$name': $diff")
            $refused = $true
            continue
        }
        $inHunk = $false
        $added = [Collections.Generic.List[string]]::new()
        foreach ($line in @($diff)) {
            $text = [string]$line
            if ($text.StartsWith('@@')) { $inHunk = $true; continue }
            if ($inHunk -and $text.StartsWith('+') -and -not $text.StartsWith('+++')) {
                $added.Add($text.Substring(1))
            }
        }
        if ($added.Count -eq 0) { continue }
        $event = @{ tool_name = 'Write'; tool_input = @{ file_path = $name; content = ($added -join "`n") } } |
            ConvertTo-Json -Compress -Depth 4
        $guardOutput = $event | & (Get-Process -Id $PID).Path -NoProfile -File $guard 2>&1
        if ($LASTEXITCODE -ne 0) {
            foreach ($line in $guardOutput) { [Console]::Error.WriteLine([string]$line) }
            $refused = $true
        }
    }
    if ($refused) { exit 1 }
    exit 0
}

$repoRoot = Get-RepoRoot $Target
if ($Scan) { Invoke-StagedScan $repoRoot }

$found = [Collections.Generic.List[string]]::new()
$hooksPath = Invoke-GitText -Arguments @('-C', $repoRoot, 'config', '--get', 'core.hooksPath') -AllowNotFound
if ($null -ne $hooksPath) { $found.Add("core.hooksPath=$($hooksPath.Trim())") }
$gitDirText = Invoke-GitText -Arguments @('-C', $repoRoot, 'rev-parse', '--git-dir')
$gitDir = $gitDirText.Trim()
if (-not [IO.Path]::IsPathRooted($gitDir)) { $gitDir = Join-Path $repoRoot $gitDir }
$hookPath = Join-Path $gitDir 'hooks/pre-commit'
if (Test-Path -LiteralPath $hookPath) { $found.Add("existing pre-commit hook at $hookPath") }
$huskyPath = Join-Path $repoRoot '.husky'
if (Test-Path -LiteralPath $huskyPath -PathType Container) { $found.Add("husky directory at $huskyPath") }
if ($found.Count -gt 0) {
    [Console]::Error.WriteLine("Git-hook setup refused: $($found -join '; '). Nothing was written.")
    exit 3
}
if ($CheckOnly) { Write-Output 'Git-hook setup preflight passed; nothing was written.'; exit 0 }

$hookDirectory = Split-Path -Parent $hookPath
New-Item -ItemType Directory -Force -Path $hookDirectory | Out-Null
$hook = @'
#!/bin/sh
# AI Tech Lead opt-in convenience net. Bypassable with git commit --no-verify; not enforcement.
repo_root=$(git rev-parse --show-toplevel) || exit 1
command -v pwsh >/dev/null 2>&1 || { echo 'COMMIT REFUSED: pwsh is required by the installed pre-commit convenience net.' >&2; exit 1; }
exec pwsh -NoProfile -File "$repo_root/scripts/setup-git-hooks.ps1" -Target "$repo_root" -Scan
'@
[IO.File]::WriteAllText($hookPath, ($hook -replace "`r`n", "`n"), [Text.UTF8Encoding]::new($false))
Write-Output "Installed opt-in pre-commit convenience net at $hookPath. It is bypassable with --no-verify and is not enforcement."
