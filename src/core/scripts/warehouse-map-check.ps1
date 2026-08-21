param([string]$Root = (Join-Path $PSScriptRoot '..'))
$ErrorActionPreference = 'Stop'
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$signalFile = Join-Path $PSScriptRoot 'warehouse-signals.tsv'
if (-not (Test-Path -LiteralPath $signalFile)) { Write-Error 'warehouse-signals.tsv is missing'; exit 2 }
try {
    $files = @(Get-ChildItem -LiteralPath $rootPath -Recurse -File -Force -ErrorAction Stop | Where-Object {
        $_.FullName -notmatch '[\\/](\.git|node_modules|bin|obj|dist)[\\/]' -and ($_.Extension -in @('.sql','.sqlproj') -or $_.Name -eq 'dbt_project.yml' -or ($_.Extension -in @('.yml','.yaml','.json') -and $_.FullName -match '(?i)[\\/](etl|pipelines?|warehouse|datafactory|synapse|dags?)[\\/]|(pipeline|datafactory|synapse|dag)[^\\/]*\.(yml|yaml|json)$'))
    })
} catch {
    [Console]::Error.WriteLine('Could not enumerate warehouse artifacts; this is a host/resource problem, so warehouse applicability cannot be determined.')
    exit 2
}
$hits = @()
foreach ($line in Get-Content -LiteralPath $signalFile) {
    if ($line.StartsWith('#') -or [string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split "`t",2
    if ($parts.Count -ne 2) { Write-Error "invalid warehouse signal: $line"; exit 2 }
    foreach ($file in $files) {
        if ($file.Name -match $parts[1] -or (Select-String -LiteralPath $file.FullName -Pattern $parts[1] -Quiet)) { $hits += $parts[0]; break }
    }
}
$hits = @($hits | Sort-Object -Unique)
if ($hits.Count -lt 2) { Write-Output "WAREHOUSE_MAP not-applicable ($($hits.Count) independent signal(s))"; exit 0 }
$map = Join-Path $rootPath 'docs/warehouse-map.md'; $learnings = Join-Path $rootPath 'LEARNINGS.md'
if (-not (Test-Path -LiteralPath $map)) {
    if ((Test-Path -LiteralPath $learnings) -and (Select-String -LiteralPath $learnings -Pattern '^## Declined artifact: warehouse-map\s*$' -Quiet)) { Write-Output 'WAREHOUSE_MAP declined (recorded in LEARNINGS.md)'; exit 0 }
    Write-Output 'WAREHOUSE_MAP missing - run /map-warehouse or inspect the live schema before a warehouse write.'; exit 1
}
$mapTime = (Get-Item -LiteralPath $map).LastWriteTimeUtc
$newer = @($files | Where-Object { $_.LastWriteTimeUtc -gt $mapTime })
if ($newer.Count -gt 0) { Write-Output "WAREHOUSE_MAP stale ($($newer.Count) warehouse artifact(s) newer than the map)"; exit 1 }
Write-Output "WAREHOUSE_MAP current ($($hits.Count) independent signal categories)"; exit 0
