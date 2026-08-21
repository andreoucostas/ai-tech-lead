# Scans the Git index for the opt-in maintainer pre-commit hook. This is a bypassable convenience
# net, not release enforcement. It invokes the shipped guard itself so its patterns cannot drift.
$ErrorActionPreference = 'Stop'

function Invoke-GitBytes {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = 'git'
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $null = $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::Start($start)
    $memory = [IO.MemoryStream]::new()
    $process.StandardOutput.BaseStream.CopyTo($memory)
    $errorText = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) { throw "git $($Arguments[0]) failed: $errorText" }
    return $memory.ToArray()
}

$repoRoot = (& git rev-parse --show-toplevel 2>&1)
if ($LASTEXITCODE -ne 0) { throw "git rev-parse failed: $repoRoot" }
$repoRoot = [string]$repoRoot
$guard = Join-Path $repoRoot 'src/core/.claude/hooks/guard.ps1'
if (-not (Test-Path -LiteralPath $guard -PathType Leaf)) {
    [Console]::Error.WriteLine('COMMIT REFUSED: the canonical guard.ps1 was not found.')
    exit 1
}

$nameBytes = Invoke-GitBytes @('diff','--cached','--name-only','--diff-filter=ACMR','-z')
$names = @([Text.Encoding]::UTF8.GetString($nameBytes).Split([char]0) | Where-Object Length)
$refused = $false
foreach ($name in $names) {
    $bytes = Invoke-GitBytes @('show',":$name")
    if ($name -match '(?i)\.ps1$' -and
        ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF)) {
        [Console]::Error.WriteLine("COMMIT REFUSED: staged PowerShell file has no UTF-8 BOM: $name")
        $refused = $true
    }

    $content = [Text.Encoding]::UTF8.GetString($bytes)
    $event = @{ tool_name='Write'; tool_input=@{ file_path=$name; content=$content } } |
        ConvertTo-Json -Compress -Depth 4
    $guardOutput = $event | & (Get-Process -Id $PID).Path -NoProfile -File $guard 2>&1
    if ($LASTEXITCODE -ne 0) {
        foreach ($line in $guardOutput) { [Console]::Error.WriteLine([string]$line) }
        $refused = $true
    }
}

if ($refused) { exit 1 }
