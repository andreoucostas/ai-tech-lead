param([string]$Root = (Join-Path $PSScriptRoot '..'), [switch]$Digest)
$ErrorActionPreference = 'Stop'
# Freshness is decided by content, never by file times: a full pass records `digest=<16 hex>` (printed by -Digest)
# in its stamp line, and the map is current only while the warehouse artifacts still hash to it. Exit 0 current or
# not applicable, 1 missing or stale, 2 could not examine.
try {
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { throw 'root is not a directory' }
    $rootPath = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path
} catch {
    [Console]::Error.WriteLine('Could not resolve the warehouse repository root; warehouse applicability cannot be determined.')
    exit 2
}
function Fail-Examine([string]$Message) { [Console]::Error.WriteLine($Message); exit 2 }
# Git runs as a process with UTF-8 output (a PowerShell pipe garbles non-ASCII paths under CP437) and LC_ALL=C (so its
# refusal can be matched). Output is read asynchronously before stdin is written, or a long path list deadlocks.
function Invoke-Git([string]$Arguments, [string]$InputText = $null) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'git'
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $rootPath
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $psi.StandardErrorEncoding = New-Object System.Text.UTF8Encoding($false)
    $psi.EnvironmentVariables['LC_ALL'] = 'C'
    # Windows PowerShell's stdin writer takes the console's input encoding and writes its BOM ahead of the first path.
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $consoleInput = $null
    if ($psi.PSObject.Properties['StandardInputEncoding']) { $psi.StandardInputEncoding = $utf8 }
    else { try { $consoleInput = [Console]::InputEncoding; [Console]::InputEncoding = $utf8 } catch { $consoleInput = $null } }
    try { $process = [System.Diagnostics.Process]::Start($psi) }
    finally { if ($consoleInput) { try { [Console]::InputEncoding = $consoleInput } catch { } } }
    $out = $process.StandardOutput.ReadToEndAsync()
    $err = $process.StandardError.ReadToEndAsync()
    if ($InputText) { $process.StandardInput.Write($InputText) }
    $process.StandardInput.Close()
    $process.WaitForExit()
    [pscustomobject]@{ Exit = $process.ExitCode; Out = $out.Result; Err = $err.Result }
}
$excluded = @('.git','node_modules','bower_components','vendor','bin','obj','dist','build','out','.next','.angular','.nx','coverage')
function Test-ArtifactName([IO.FileInfo]$item) {
    $item.Extension -in @('.sql','.sqlproj') -or $item.Name -eq 'dbt_project.yml' -or
        ($item.Extension -in @('.yml','.yaml','.json') -and $item.FullName -match '(?i)[\\/](etl|pipelines?|warehouse|datafactory|synapse|dags?)[\\/]|(pipeline|datafactory|synapse|dag)[^\\/]*\.(yml|yaml|json)$')
}
$gitMode = $false
try { $probe = Invoke-Git 'rev-parse --is-inside-work-tree' }
catch {
    if (Test-Path -LiteralPath (Join-Path $rootPath '.git')) { Fail-Examine 'Git is not available but this is a Git repository; the warehouse artifacts cannot be listed as Git sees them.' }
    $probe = $null
}
if ($probe) {
    if ($probe.Exit -eq 0) { $gitMode = $probe.Out.Trim() -eq 'true' }
    elseif ($probe.Err -notmatch 'not a git repository') { Fail-Examine "Git could not examine the repository ($($probe.Err.Trim())); warehouse applicability cannot be determined." }
}
# $files holds the artifacts; $relative maps each full path to its forward-slash path from the root.
$files = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
$relative = @{}
try {
    if ($gitMode) {
        # The files Git tracks or would add: an ignored generated folder (a dbt target/) is not the warehouse.
        $listing = Invoke-Git '-c core.quotepath=off ls-files -z --cached --others --exclude-standard'
        if ($listing.Exit -ne 0) { throw "git ls-files: $($listing.Err.Trim())" }
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        $linkDirs = @{}
        foreach ($path in $listing.Out.Split([char]0)) {
            if ($path -eq '' -or -not $seen.Add($path)) { continue }
            $segments = $path.Split('/'); $inExcluded = $false
            for ($s = 0; $s -lt $segments.Count - 1; $s++) { if ($segments[$s] -in $excluded) { $inExcluded = $true; break } }
            if ($inExcluded) { continue }
            $full = Join-Path $rootPath ($path.Replace('/', [IO.Path]::DirectorySeparatorChar))
            $item = New-Object System.IO.FileInfo($full)
            # The index still lists a file deleted from the working tree; a deleted artifact changes the digest instead.
            if (-not $item.Exists -or -not (Test-ArtifactName $item)) { continue }
            if ($item.LinkType -in @('SymbolicLink', 'Junction')) { continue }
            # Git descends into a junction; the walk below does not, so neither does this listing.
            $underLink = $false; $dir = $item.Directory
            while ($dir -and $dir.FullName.Length -gt $rootPath.TrimEnd('\', '/').Length) {
                if (-not $linkDirs.ContainsKey($dir.FullName)) { $linkDirs[$dir.FullName] = $dir.LinkType -in @('SymbolicLink', 'Junction') }
                if ($linkDirs[$dir.FullName]) { $underLink = $true; break }
                $dir = $dir.Parent
            }
            if ($underLink) { continue }
            $files.Add($item); $relative[$item.FullName] = $path
        }
    } else {
        $directories = [System.Collections.Generic.Queue[System.IO.DirectoryInfo]]::new()
        $directories.Enqueue((Get-Item -LiteralPath $rootPath -Force -ErrorAction Stop))
        $prefix = $rootPath.TrimEnd('\', '/').Length + 1
        while ($directories.Count -gt 0) {
            $directory = $directories.Dequeue()
            foreach ($item in Get-ChildItem -LiteralPath $directory.FullName -Force -ErrorAction Stop) {
                # Only links are skipped. A OneDrive (cloud files) folder carries the ReparsePoint attribute too and has no
                # LinkType; skipping it hid every warehouse artifact under a synced folder as "not-applicable".
                if ($item.LinkType -in @('SymbolicLink', 'Junction')) { continue }
                if ($item.PSIsContainer) {
                    if ($item.Name -notin $excluded) { $directories.Enqueue($item) }
                } elseif (Test-ArtifactName $item) {
                    $files.Add($item); $relative[$item.FullName] = $item.FullName.Substring($prefix).Replace('\', '/')
                }
            }
        }
    }
    $files = @($files)
} catch {
    Fail-Examine 'Could not enumerate warehouse artifacts; this is a host/resource problem, so warehouse applicability cannot be determined.'
}
# SHA-256 over the ordinally sorted "<path> <content id>" lines. In Git the content id is the blob id of the working
# file, which applies the repository's line-ending rules, so two clones of one commit agree; outside Git, the bytes' hash.
function Get-ArtifactDigest {
    $paths = [string[]]@($files | ForEach-Object { $relative[$_.FullName] })
    [Array]::Sort($paths, [StringComparer]::Ordinal)
    $ids = @{}
    if ($gitMode -and $paths.Count -gt 0) {
        if (@($paths | Where-Object { $_ -match '[\r\n]' }).Count -gt 0) { Fail-Examine 'A warehouse artifact path contains a line break; its content cannot be identified.' }
        try { $hashed = Invoke-Git 'hash-object --stdin-paths' (($paths -join "`n") + "`n") } catch { $hashed = $null }
        $lines = if ($hashed) { @($hashed.Out.Split("`n") | Where-Object { $_ -ne '' }) } else { @() }
        if (-not $hashed -or $hashed.Exit -ne 0 -or $lines.Count -ne $paths.Count) { Fail-Examine "Could not read a warehouse artifact's content ($(if ($hashed) { $hashed.Err.Trim() })); the map's freshness cannot be determined." }
        for ($i = 0; $i -lt $paths.Count; $i++) { $ids[$paths[$i]] = $lines[$i].Trim() }
    } else {
        $sha = [Security.Cryptography.SHA256]::Create()
        foreach ($file in $files) {
            try {
                $stream = [IO.File]::Open($file.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
                try { $ids[$relative[$file.FullName]] = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() } finally { $stream.Dispose() }
            } catch { Fail-Examine "Could not read warehouse artifact '$($file.FullName)'; the map's freshness cannot be determined." }
        }
    }
    $text = New-Object System.Text.StringBuilder
    foreach ($path in $paths) { [void]$text.Append($path).Append(' ').Append($ids[$path]).Append("`n") }
    $hash = [Security.Cryptography.SHA256]::Create().ComputeHash((New-Object System.Text.UTF8Encoding($false)).GetBytes($text.ToString()))
    [BitConverter]::ToString($hash).Replace('-', '').ToLowerInvariant().Substring(0, 16)
}
if ($Digest) { Write-Output "digest=$(Get-ArtifactDigest)"; exit 0 }
$signalFile = Join-Path $PSScriptRoot 'warehouse-signals.tsv'
if (-not (Test-Path -LiteralPath $signalFile -PathType Leaf)) { [Console]::Error.WriteLine('warehouse-signals.tsv is missing'); exit 2 }
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
# Name the remedy skill only where this repository has it; some stacks do not ship it.
$mapSkill = Test-Path -LiteralPath (Join-Path $rootPath '.claude/skills/map-warehouse/SKILL.md') -PathType Leaf
if (-not (Test-Path -LiteralPath $map -PathType Leaf)) {
    if ($mapSkill) { Write-Output 'WAREHOUSE_MAP missing - run /map-warehouse or inspect the live schema before a warehouse write.' }
    else { Write-Output 'WAREHOUSE_MAP missing - inspect the live schema before a warehouse write.' }
    exit 1
}
try { $mapText = [IO.File]::ReadAllText($map) }
catch { Fail-Examine 'Could not read docs/warehouse-map.md; the map''s freshness cannot be determined.' }
if ($mapText.Contains('<!-- warehouse-map full pass: none -->')) {
    if ($mapSkill) { Write-Output 'WAREHOUSE_MAP stale (no full pass yet) - run /map-warehouse for the whole warehouse before trusting rows a scoped pass did not write.' }
    else { Write-Output 'WAREHOUSE_MAP stale (no full pass yet) - inspect the live schema before trusting rows a scoped pass did not write.' }
    exit 1
}
# A scoped pass rewrites the file but leaves the full pass's line alone, so only that line's digest certifies the map.
$stamp = [regex]::Match($mapText, '<!-- warehouse-map full pass: \S+ digest=([0-9a-f]{16}) -->')
if (-not $stamp.Success) { Write-Output 'WAREHOUSE_MAP stale (no content stamp; a full pass records one)'; exit 1 }
if ($stamp.Groups[1].Value -ne (Get-ArtifactDigest)) { Write-Output 'WAREHOUSE_MAP stale (warehouse artifacts changed since the full pass)'; exit 1 }
Write-Output "WAREHOUSE_MAP current ($($hits.Count) independent signal categories)"; exit 0
