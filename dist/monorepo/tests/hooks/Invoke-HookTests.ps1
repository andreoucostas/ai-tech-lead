# Suite entry point -- runs every *.Tests.ps1 in this directory as an isolated pwsh process and
# exits with the TOTAL number of failures (0 = green). Each test file degrades-safe: .sh twin tests
# self-skip when no bash is present, so this is safe to run on a pure-Windows or pure-*nix host.
# Usage:  pwsh -NoProfile -File tests/hooks/Invoke-HookTests.ps1
$ErrorActionPreference = 'Stop'
# Prefer pwsh (7+); fall back to Windows PowerShell 5.1 where pwsh is absent (5.1-safe if/else).
if (Get-Command pwsh -ErrorAction SilentlyContinue) { $psExe = 'pwsh' } else { $psExe = 'powershell' }
$files = Get-ChildItem -LiteralPath $PSScriptRoot -Filter *.Tests.ps1 | Sort-Object Name
$throttle = 4
$next = 0
$running = @()
$results = @{}

while ($next -lt $files.Count -or $running.Count -gt 0) {
    while ($next -lt $files.Count -and $running.Count -lt $throttle) {
        $index = $next
        $file = $files[$index]
        $running += Start-Job -ArgumentList $psExe, $file.FullName, $index -ScriptBlock {
            param($exe, $path, $resultIndex)
            $output = @(& $exe -NoProfile -ExecutionPolicy Bypass -File $path 2>&1 |
                ForEach-Object { $_.ToString() })
            [pscustomobject]@{
                Index    = $resultIndex
                ExitCode = [int]$LASTEXITCODE
                Output   = $output
            }
        }
        $next++
    }

    $done = $running | Wait-Job -Any
    $result = Receive-Job -Job $done
    $results[[int]$result.Index] = $result
    $running = @($running | Where-Object Id -ne $done.Id)
    Remove-Job -Job $done
}

$total = 0
for ($i = 0; $i -lt $files.Count; $i++) {
    $f = $files[$i]
    $result = $results[$i]
    Write-Host ("--- {0} ---" -f $f.Name)
    foreach ($line in $result.Output) { Write-Host $line }
    $total += [int]$result.ExitCode
}
Write-Host ("=== Hook test suite: {0} failure(s) across {1} file(s) ===" -f $total, $files.Count)
exit $total
