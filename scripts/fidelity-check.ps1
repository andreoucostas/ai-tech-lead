# Fidelity gate (.ps1 twin; bash twin: fidelity-check.sh): compare dist/<mode> to the FROZEN
# baseline, EOL-normalized. The baseline is the full 138-file legacy/<mode> tree captured at the
# `pre-restructure` tag (== the freeze-v0.25.5 content). Reports match / mismatch /
# missing-in-dist / extra-in-dist. Phase 3 semantics: STRICT — any mismatch, missing, or extra
# file fails (Phase 2's "missing = not-yet-extracted" tolerance is over; a composer regression
# that silently drops files must fail this gate). This is the zero-behaviour-change proof.
#   Usage: fidelity-check.ps1 {dotnet|angular} [baseline-ref]   (baseline-ref default: pre-restructure)
# Works on Windows PowerShell 5.1 and pwsh 7. Uses `git archive --output` + tar.exe (no binary
# pipes — PS pipelines corrupt binary streams).
param(
    [Parameter(Position = 0)][string]$Mode,
    [Parameter(Position = 1)][string]$RefSpec = 'pre-restructure'
)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
$root = (Get-Location).Path

if ($Mode -ne 'dotnet' -and $Mode -ne 'angular') {
    [Console]::Error.WriteLine('usage: fidelity-check.ps1 {dotnet|angular} [ref]'); exit 2
}
$dist = Join-Path $root "dist\$Mode"
if (-not (Test-Path $dist -PathType Container)) {
    [Console]::Error.WriteLine("no dist/$Mode - run scripts/build.ps1 $Mode first"); exit 2
}
# Prefer Windows-native bsdtar: with Git Bash on PATH, `tar.exe` can resolve to MSYS tar, which
# misparses `C:\...` as a remote host ("Cannot connect to C").
$tarExe = Join-Path $env:SystemRoot 'System32\tar.exe'
if (-not (Test-Path $tarExe)) {
    $tarCmd = Get-Command tar.exe -ErrorAction SilentlyContinue
    if (-not $tarCmd) { [Console]::Error.WriteLine('tar.exe not found - cannot materialise the baseline'); exit 2 }
    $tarExe = $tarCmd.Source
}

# Materialise the frozen baseline for this stack from git (archive to a file, then extract).
$ref = Join-Path ([IO.Path]::GetTempPath()) ("fidelity-" + [IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Path $ref -Force | Out-Null
try {
    $tarFile = Join-Path $ref 'baseline.tar'
    & git archive --output="$tarFile" $RefSpec "legacy/$Mode" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tarFile)) {
        [Console]::Error.WriteLine("could not archive legacy/$Mode from $RefSpec"); exit 2
    }
    & $tarExe -xf $tarFile -C $ref
    if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine('tar extraction failed'); exit 2 }
    $base = Join-Path $ref "legacy\$Mode"
    if (-not (Test-Path $base -PathType Container)) {
        [Console]::Error.WriteLine("baseline legacy/$Mode not found at $RefSpec"); exit 2
    }

    # EOL-normalized (CR-stripped) content hash, matching the bash twin's `tr -d '\r'` compare.
    $sha = [System.Security.Cryptography.SHA256]::Create()
    function Get-NormalizedHash([string]$path) {
        $bytes = [IO.File]::ReadAllBytes($path)
        $out = New-Object System.Collections.Generic.List[byte]
        foreach ($b in $bytes) { if ($b -ne 13) { $out.Add($b) } }
        return [BitConverter]::ToString($sha.ComputeHash($out.ToArray()))
    }
    function Get-RelFiles([string]$dir) {
        Get-ChildItem -Path $dir -Recurse -File -Force | ForEach-Object {
            $_.FullName.Substring($dir.Length + 1).Replace('\', '/')
        }
    }

    $match = 0; $mism = 0; $missing = 0; $extra = 0
    $baseFiles = @(Get-RelFiles $base)
    foreach ($rel in $baseFiles) {
        $d = Join-Path $dist ($rel.Replace('/', '\'))
        $b = Join-Path $base ($rel.Replace('/', '\'))
        if (-not (Test-Path $d -PathType Leaf)) { $missing++; Write-Output "MISSING  $rel"; continue }
        if ((Get-NormalizedHash $b) -eq (Get-NormalizedHash $d)) { $match++ }
        else { $mism++; Write-Output "MISMATCH $rel" }
    }
    foreach ($rel in @(Get-RelFiles $dist)) {
        $b = Join-Path $base ($rel.Replace('/', '\'))
        if (-not (Test-Path $b -PathType Leaf)) { $extra++; Write-Output "EXTRA    $rel" }
    }

    $total = $baseFiles.Count
    Write-Output "--- $Mode @ ${RefSpec}: match=$match mismatch=$mism missing=$missing extra=$extra (of $total)"
    # STRICT: mismatch, missing, and extra all fail (Phase 3+).
    if ($mism -eq 0 -and $extra -eq 0 -and $missing -eq 0) { exit 0 } else { exit 1 }
}
finally {
    Remove-Item -Path $ref -Recurse -Force -ErrorAction SilentlyContinue
}
