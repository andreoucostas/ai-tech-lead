param(
    [Parameter(Mandatory = $true)]
    [string]$RunRoot
)

$ErrorActionPreference = 'Stop'
$runFull = [IO.Path]::GetFullPath($RunRoot)
$tempFull = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not $runFull.StartsWith($tempFull, [StringComparison]::OrdinalIgnoreCase)) {
    throw "RunRoot must be inside the system temporary directory: $runFull"
}
if (Test-Path -LiteralPath $runFull) {
    throw "RunRoot already exists: $runFull"
}

$fixture = $PSScriptRoot
$repoRoot = [IO.Path]::GetFullPath((Join-Path $fixture '../../..'))
$base = Join-Path $fixture 'inputs/base'
$overlay = Join-Path $fixture 'inputs/overlay'
$utf8 = [Text.UTF8Encoding]::new($false)
New-Item -ItemType Directory -Path $runFull | Out-Null

function Copy-DirectoryContents([string]$Source, [string]$Target) {
    New-Item -ItemType Directory -Path $Target -Force | Out-Null
    Get-ChildItem -LiteralPath $Source -Force | Copy-Item -Destination $Target -Recurse -Force
}

function Write-Lines([string]$Path, [object[]]$Lines) {
    [IO.File]::WriteAllLines($Path, [string[]]$Lines, $utf8)
}

foreach ($name in @('before', 'after')) {
    $target = Join-Path $runFull $name
    Copy-DirectoryContents $base $target
    $installer = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
    $installOutput = & 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File $installer $target 2>&1
    $installExit = $LASTEXITCODE
    Write-Lines (Join-Path $runFull "install-$name.txt") $installOutput
    if ($installExit -ne 0) {
        throw "Installer failed for $name with exit $installExit"
    }

    foreach ($file in @('CLAUDE.md', 'AGENTS.md', 'FRAMEWORK-CONTEXT.md')) {
        Copy-Item -LiteralPath (Join-Path $overlay $file) -Destination (Join-Path $target $file) -Force
    }
    if ($name -eq 'after') {
        Copy-DirectoryContents (Join-Path $overlay 'docs/wiki') (Join-Path $target 'docs/wiki')
    }

    $hook = [IO.Path]::GetFullPath((Join-Path $target '.github/hooks/hooks.json'))
    $targetPrefix = [IO.Path]::GetFullPath($target).TrimEnd('\') + '\'
    if (-not $hook.StartsWith($targetPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe hook target: $hook"
    }
    if (Test-Path -LiteralPath $hook) {
        Remove-Item -LiteralPath $hook -Force
    }

    $testOutput = & dotnet run --project (Join-Path $target 'tests/Dispatch.Tests/Dispatch.Tests.csproj') 2>&1
    $testExit = $LASTEXITCODE
    Write-Lines (Join-Path $runFull "visible-$name.txt") $testOutput
    if ($testExit -ne 0) {
        throw "Visible baseline failed for $name"
    }

    $generatedDirectories = Get-ChildItem -LiteralPath $target -Directory -Recurse -Force |
        Where-Object { $_.Name -in @('bin', 'obj') }
    foreach ($directory in $generatedDirectories) {
        $generatedFull = [IO.Path]::GetFullPath($directory.FullName)
        if (-not $generatedFull.StartsWith($targetPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Unsafe generated-directory target: $generatedFull"
        }
    }
    foreach ($directory in $generatedDirectories) {
        Remove-Item -LiteralPath $directory.FullName -Recurse -Force
    }

    & git -C $target init --initial-branch=main | Out-Null
    & git -C $target config user.name 'B224 Fixture'
    & git -C $target config user.email 'b224@example.invalid'
    & git -C $target config core.autocrlf false
    & git -C $target add -A
    & git -C $target commit -m 'Neutral fixture baseline' | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Git commit failed for $name"
    }
}

$controlRoot = Join-Path $runFull 'grader-controls'
New-Item -ItemType Directory -Path $controlRoot | Out-Null
$controlResults = @()
foreach ($case in @('baseline', 'valid', 'off-by-one', 'wrong-scope')) {
    $target = Join-Path $controlRoot $case
    Copy-DirectoryContents $base $target
    Copy-DirectoryContents (Join-Path $fixture 'grading/Dispatch.Acceptance') (Join-Path $target 'grading/Dispatch.Acceptance')
    if ($case -ne 'baseline') {
        $patchName = if ($case -eq 'valid') { 'valid.patch' } elseif ($case -eq 'off-by-one') { 'off-by-one.patch' } else { 'wrong-scope.patch' }
        & git -C $target apply --whitespace=nowarn (Join-Path $fixture "grading/$patchName")
        if ($LASTEXITCODE -ne 0) {
            throw "Patch failed: $patchName"
        }
    }

    $output = & dotnet run --project (Join-Path $target 'grading/Dispatch.Acceptance/Dispatch.Acceptance.csproj') 2>&1
    $exitCode = $LASTEXITCODE
    Write-Lines (Join-Path $controlRoot "$case.txt") $output
    $summary = $output | Where-Object { $_ -match '^\d+ passed, \d+ failed$' } | Select-Object -Last 1
    $controlResults += [pscustomobject]@{ Case = $case; Exit = $exitCode; Summary = $summary }
}

$beforeTree = (& git -C (Join-Path $runFull 'before') rev-parse 'HEAD^{tree}').Trim()
$afterTree = (& git -C (Join-Path $runFull 'after') rev-parse 'HEAD^{tree}').Trim()
$indexCount = ([regex]::Matches(
    [IO.File]::ReadAllText((Join-Path $runFull 'after/docs/wiki/INDEX.md')),
    '(?m)^- \['
)).Count
$manifest = Get-ChildItem -LiteralPath $fixture -File -Recurse | ForEach-Object {
    [pscustomobject]@{
        Path = $_.FullName.Substring($fixture.Length + 1).Replace('\', '/')
        Sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        Length = $_.Length
    }
}
[IO.File]::WriteAllText(
    (Join-Path $runFull 'fixture-manifest.json'),
    ($manifest | ConvertTo-Json -Depth 3),
    $utf8
)

$controlResults | Format-Table -AutoSize
Write-Output "RUN_ROOT=$runFull"
Write-Output "BEFORE_TREE=$beforeTree"
Write-Output "AFTER_TREE=$afterTree"
Write-Output "INDEX_ENTRIES=$indexCount"
Write-Output "BEFORE_REMOTE_COUNT=$(@(& git -C (Join-Path $runFull 'before') remote).Count)"
Write-Output "AFTER_REMOTE_COUNT=$(@(& git -C (Join-Path $runFull 'after') remote).Count)"
