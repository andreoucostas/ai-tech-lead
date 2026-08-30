param([string]$Root = (Join-Path $PSScriptRoot '..'))
$ErrorActionPreference = 'Stop'
try {
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { throw 'root is not a directory' }
    $rootPath = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path
} catch {
    [Console]::Error.WriteLine('Could not resolve the warehouse repository root; warehouse applicability cannot be determined.')
    exit 2
}
$signalFile = Join-Path $PSScriptRoot 'warehouse-signals.tsv'
if (-not (Test-Path -LiteralPath $signalFile -PathType Leaf)) { [Console]::Error.WriteLine('warehouse-signals.tsv is missing'); exit 2 }
try {
    $excluded = @('.git','node_modules','bower_components','vendor','bin','obj','dist','build','out','.next','.angular','.nx','coverage')
    $files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    $directories = [System.Collections.Generic.Queue[System.IO.DirectoryInfo]]::new()
    $directories.Enqueue((Get-Item -LiteralPath $rootPath -Force -ErrorAction Stop))
    while ($directories.Count -gt 0) {
        $directory = $directories.Dequeue()
        foreach ($item in Get-ChildItem -LiteralPath $directory.FullName -Force -ErrorAction Stop) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            if ($item.PSIsContainer) {
                if ($item.Name -notin $excluded) { $directories.Enqueue($item) }
            } elseif ($item.Extension -in @('.sql','.sqlproj') -or $item.Name -eq 'dbt_project.yml' -or
                ($item.Extension -in @('.yml','.yaml','.json') -and $item.FullName -match '(?i)[\\/](etl|pipelines?|warehouse|datafactory|synapse|dags?)[\\/]|(pipeline|datafactory|synapse|dag)[^\\/]*\.(yml|yaml|json)$')) {
                $files.Add($item)
            }
        }
    }
    $files = @($files)
} catch {
    [Console]::Error.WriteLine('Could not enumerate warehouse artifacts; this is a host/resource problem, so warehouse applicability cannot be determined.')
    exit 2
}
$hits = @()
try { $signalLines = @(Get-Content -LiteralPath $signalFile -ErrorAction Stop) }
catch { [Console]::Error.WriteLine('Could not read warehouse-signals.tsv; warehouse applicability cannot be determined.'); exit 2 }
foreach ($line in $signalLines) {
    if ($line.StartsWith('#') -or [string]::IsNullOrWhiteSpace($line)) { continue }
    $parts = $line -split "`t"
    if ($parts.Count -ne 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) { [Console]::Error.WriteLine("invalid warehouse signal: $line"); exit 2 }
    foreach ($file in $files) {
        try { $matched = $file.Name -match $parts[1] -or (Select-String -LiteralPath $file.FullName -Pattern $parts[1] -Quiet -ErrorAction Stop) }
        catch { [Console]::Error.WriteLine("Could not read warehouse artifact '$($file.FullName)'; warehouse applicability cannot be determined."); exit 2 }
        if ($matched) { $hits += $parts[0]; break }
    }
}
$hits = @($hits | Sort-Object -Unique)
if ($hits.Count -lt 2) { Write-Output "WAREHOUSE_MAP not-applicable ($($hits.Count) independent signal(s))"; exit 0 }
$map = Join-Path $rootPath 'docs/warehouse-map.md'
if (-not (Test-Path -LiteralPath $map -PathType Leaf)) {
    Write-Output 'WAREHOUSE_MAP missing - run /map-warehouse or inspect the live schema before a warehouse write.'; exit 1
}
$mapTime = (Get-Item -LiteralPath $map).LastWriteTimeUtc
$newer = @($files | Where-Object { $_.LastWriteTimeUtc -gt $mapTime })
if ($newer.Count -gt 0) { Write-Output "WAREHOUSE_MAP stale ($($newer.Count) warehouse artifact(s) newer than the map)"; exit 1 }
Write-Output "WAREHOUSE_MAP current ($($hits.Count) independent signal categories)"; exit 0
