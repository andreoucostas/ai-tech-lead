# Records a /bootstrap baseline and reports what a later /rebootstrap must re-analyse.
# Usage:
#   pwsh -NoProfile -File scripts/bootstrap-baseline.ps1 -Mode Record -ClaimsPath <claims.json outside the repo>
#   pwsh -NoProfile -File scripts/bootstrap-baseline.ps1 -Mode Impact
# Both modes hash the working tree (tracked plus untracked, not ignored) with git hash-object, never a
# commit SHA: a squash merge, a fresh clone or a shallow clone sees the same content the same way.
# Paths listed in framework-ownership.json and the baseline file itself are never application churn;
# AGENTS.md is compared line by line instead, so a hand-edited line is reported as EDITED.
# A recorded file whose content now sits at exactly one new path moved (RENAMED): its claims follow it,
# and the files the Known Hazard Areas rows name are recorded so /rebootstrap can re-point those rows.
# Exit codes: 0 done; 1 INVALID input; 2 CANNOT EXAMINE; 3 (Impact) no usable baseline, run in full.
[CmdletBinding()]
param(
    [string]$Mode,
    [string]$ClaimsPath,
    [string]$Root
)
$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Split-Path $PSScriptRoot -Parent }

$script:StateRel = '.claude/bootstrap-baseline.tsv'
$script:AreaDepth = 3
$script:Profiles = @('dotnet', 'angular', 'warehouse')
# A project manifest counts by presence (added, removed or renamed); a workspace file also by content.
$script:Manifests = @{
    dotnet    = @{ Project = @('*.csproj'); Workspace = @('*.sln', '*.slnx') }
    angular   = @{ Project = @('project.json', 'package.json'); Workspace = @('angular.json', 'nx.json') }
    warehouse = @{ Project = @('*.sqlproj'); Workspace = @('dbt_project.yml') }
}
$script:Kinds = @('scoped', 'universal', 'absence')

# Output goes straight to stdout: a message written inside a function whose result a caller is
# capturing would otherwise vanish into that capture.
function Say([string]$Line) { [Console]::Out.WriteLine($Line) }

function Stop-With([int]$Code, [string]$Message) {
    Say $Message
    exit $Code
}

function New-PathMap { return [hashtable]::new([StringComparer]::Ordinal) }

function Invoke-Git([string[]]$Arguments, [byte[]]$Stdin) {
    $git = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($git.Count -ne 1) { Stop-With 2 'CANNOT EXAMINE: git executable is unavailable.' }
    $all = @('-C', $script:RootFull, '-c', 'core.quotePath=false') + $Arguments
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $git[0].Source
    $startInfo.Arguments = (($all | ForEach-Object { '"' + $_ + '"' }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['GIT_OPTIONAL_LOCKS'] = '0'
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    $stdout = New-Object IO.MemoryStream
    try {
        # Windows PowerShell 5.1 opens the redirected stdin with the console input encoding and writes its
        # preamble at once, so under a UTF-8 console git would read a byte-order mark before the first path.
        $console = $null
        if ($PSVersionTable.PSEdition -ne 'Core') {
            try { if ([Console]::InputEncoding.GetPreamble().Length -gt 0) { $console = [Console]::InputEncoding; [Console]::InputEncoding = New-Object Text.UTF8Encoding($false) } }
            catch { $console = $null }
        }
        try { [void]$process.Start() } finally { if ($console) { try { [Console]::InputEncoding = $console } catch { } } }
        $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdout)
        $stderrTask = $process.StandardError.ReadToEndAsync()
        # Raw UTF-8 bytes: Windows PowerShell 5.1 cannot set a stdin encoding for a child process.
        if ($Stdin) { $process.StandardInput.BaseStream.Write($Stdin, 0, $Stdin.Length) }
        $process.StandardInput.Close()
        $process.WaitForExit()
        $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        return [pscustomobject]@{ Exit = [int]$process.ExitCode; Text = [Text.Encoding]::UTF8.GetString($stdout.ToArray()); Error = $stderr }
    } catch {
        Stop-With 2 "CANNOT EXAMINE: could not run git: $($_.Exception.Message)"
    } finally {
        $stdout.Dispose()
        $process.Dispose()
    }
}

function Get-Sha256Hex([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $bytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)) } finally { $sha.Dispose() }
    return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Get-Normalized([string]$Text) {
    return ([regex]::Replace($Text.TrimStart([char]0xFEFF), '\s+', ' ')).Trim()
}

function ConvertTo-GlobRegex([string]$Glob) {
    # '**/' spans zero or more directories, '**' anything, '*' and '?' stay inside one path segment.
    $builder = New-Object Text.StringBuilder
    $i = 0
    while ($i -lt $Glob.Length) {
        $c = $Glob[$i]
        if ($c -eq '*' -and ($i + 1) -lt $Glob.Length -and $Glob[$i + 1] -eq '*') {
            if (($i + 2) -lt $Glob.Length -and $Glob[$i + 2] -eq '/') { [void]$builder.Append('(?:[^\n]*/)?'); $i += 3 }
            else { [void]$builder.Append('[^\n]*'); $i += 2 }
            continue
        }
        if ($c -eq '*') { [void]$builder.Append('[^/\n]*') }
        elseif ($c -eq '?') { [void]$builder.Append('[^/\n]') }
        else { [void]$builder.Append([regex]::Escape([string]$c)) }
        $i++
    }
    return $builder.ToString()
}

function New-LeafRegex([string[]]$Globs) {
    $alternatives = @($Globs | ForEach-Object { ConvertTo-GlobRegex $_ })
    return [regex]::new('^(?:' + ($alternatives -join '|') + ')$')
}

function Get-Excluded {
    $inventory = Join-Path $script:RootFull 'framework-ownership.json'
    if (-not (Test-Path -LiteralPath $inventory -PathType Leaf)) {
        Stop-With 2 'CANNOT EXAMINE: framework-ownership.json is missing, so framework files cannot be told apart from application changes.'
    }
    try { $parsed = [IO.File]::ReadAllText($inventory) | ConvertFrom-Json }
    catch { Stop-With 2 "CANNOT EXAMINE: framework-ownership.json is not valid JSON: $($_.Exception.Message)" }
    $entries = @($parsed.paths)
    if ($entries.Count -eq 0) { Stop-With 2 'CANNOT EXAMINE: framework-ownership.json has no paths inventory.' }
    $excluded = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($entry in $entries) {
        if ($entry.path -isnot [string] -or -not $entry.path) { Stop-With 2 'CANNOT EXAMINE: framework-ownership.json has an entry without a path.' }
        [void]$excluded.Add($entry.path)
    }
    [void]$excluded.Add($script:StateRel)
    return , $excluded
}

function Get-Snapshot {
    # One (path -> blob) map of every non-excluded file in the working tree.
    $probe = Invoke-Git @('rev-parse', '--is-inside-work-tree') $null
    if ($probe.Exit -ne 0 -or $probe.Text.Trim() -ne 'true') {
        Stop-With 2 "CANNOT EXAMINE: $script:RootFull is not inside a Git working tree."
    }
    $excluded = Get-Excluded
    $listed = Invoke-Git @('ls-files', '-z', '--cached', '--others', '--exclude-standard') $null
    if ($listed.Exit -ne 0) { Stop-With 2 "CANNOT EXAMINE: git ls-files failed: $($listed.Error.Trim())" }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $paths = New-Object 'System.Collections.Generic.List[string]'
    foreach ($path in $listed.Text.Split([char]0)) {
        if (-not $path -or $path.IndexOfAny([char[]]"`t`r`n") -ge 0) { continue }
        if ($excluded.Contains($path) -or -not $seen.Add($path)) { continue }
        # Skips deleted-but-tracked paths, submodule directories and dangling links.
        if (-not [IO.File]::Exists((Join-Path $script:RootFull $path))) { continue }
        $paths.Add($path)
    }
    $blobs = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    if ($paths.Count -gt 0) {
        $pathBytes = [Text.Encoding]::UTF8.GetBytes((($paths.ToArray()) -join "`n") + "`n")
        $hashed = Invoke-Git @('hash-object', '--stdin-paths') $pathBytes
        $hashes = @($hashed.Text.Split([char[]]"`n", [StringSplitOptions]::RemoveEmptyEntries))
        if ($hashed.Exit -ne 0 -or $hashes.Count -ne $paths.Count) {
            Stop-With 2 "CANNOT EXAMINE: git hash-object failed: $($hashed.Error.Trim())"
        }
        for ($i = 0; $i -lt $paths.Count; $i++) { $blobs[$paths[$i]] = $hashes[$i].Trim() }
    }
    $sorted = [string[]]@($blobs.Keys)
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    return [pscustomobject]@{ Blobs = $blobs; Sorted = $sorted; Joined = ($sorted -join "`n") }
}

function Get-Areas($Snapshot) {
    # A directory above the area depth covers only its own files; one at the depth covers its subtree.
    $members = New-PathMap
    foreach ($path in $Snapshot.Sorted) {
        $segments = $path.Split('/')
        $dirs = $segments.Count - 1
        if ($dirs -ge $script:AreaDepth) { $area = ($segments[0..($script:AreaDepth - 1)]) -join '/' }
        elseif ($dirs -eq 0) { $area = '.' }
        else { $area = ($segments[0..($dirs - 1)]) -join '/' }
        if (-not $members.ContainsKey($area)) { $members[$area] = New-Object 'System.Collections.Generic.List[string]' }
        $members[$area].Add($Snapshot.Blobs[$path] + ' ' + $path)
    }
    $areas = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    foreach ($area in $members.Keys) { $areas[$area] = (Get-Sha256Hex (($members[$area].ToArray()) -join "`n")).Substring(0, 16) }
    return $areas
}

function Get-ManifestRows($Snapshot, [string[]]$Selected) {
    $rows = New-Object 'System.Collections.Generic.List[string]'
    foreach ($profile in $Selected) {
        $project = New-LeafRegex $script:Manifests[$profile].Project
        $workspace = New-LeafRegex $script:Manifests[$profile].Workspace
        foreach ($path in $Snapshot.Sorted) {
            $leaf = $path.Substring($path.LastIndexOf('/') + 1)
            if ($project.IsMatch($leaf)) { $rows.Add("project`t$profile`t$path") }
            if ($workspace.IsMatch($leaf)) { $rows.Add("workspace`t$profile`t$path`t$($Snapshot.Blobs[$path])") }
        }
    }
    return , $rows
}

function Test-SafePattern([string]$Pattern) {
    if (-not $Pattern -or $Pattern.IndexOfAny([char[]]"`t`r`n") -ge 0) { return $false }
    if ($Pattern.StartsWith('/') -or $Pattern -match '^[A-Za-z]:') { return $false }
    foreach ($segment in $Pattern.TrimEnd('/').Split('/')) { if ($segment -eq '' -or $segment -eq '.' -or $segment -eq '..') { return $false } }
    return $true
}

function Resolve-Evidence($Snapshot, [string]$Pattern) {
    # Returns the ordinally sorted non-excluded paths a glob, exact file or directory names.
    if ($Pattern.IndexOfAny([char[]]'*?') -ge 0) {
        $regex = '(?m)^' + (ConvertTo-GlobRegex $Pattern) + '$'
    } elseif ($Snapshot.Blobs.ContainsKey($Pattern)) {
        return , @($Pattern)
    } else {
        $regex = '(?m)^' + [regex]::Escape($Pattern.TrimEnd('/') + '/') + '[^\n]*$'
    }
    $found = @([regex]::Matches($Snapshot.Joined, $regex) | ForEach-Object { $_.Value })
    return , $found
}

function Get-HazardPaths($Snapshot) {
    # Each file a Known Hazard Areas row names, found the way hazard-check finds row paths.
    $found = New-PathMap
    $context = Join-Path $script:RootFull 'FRAMEWORK-CONTEXT.md'
    if (-not (Test-Path -LiteralPath $context -PathType Leaf)) { return $found }
    $inside = $false
    foreach ($line in ([IO.File]::ReadAllText($context).TrimStart([char]0xFEFF) -replace "`r", '').Split("`n")) {
        if ($line.TrimEnd() -ceq '## Known Hazard Areas') { $inside = $true; continue }
        if (-not $inside) { continue }
        if ($line.StartsWith('## ')) { break }
        $cells = $line.Split('|')
        if (-not $line.StartsWith('|') -or $cells.Count -lt 3) { continue }
        $tokens = @([regex]::Matches($cells[1], '`([^`]*)`') | ForEach-Object { $_.Groups[1].Value }) +
            @([regex]::Replace($cells[1], '`[^`]*`', ' ') -split '[\s,;]+')
        foreach ($token in $tokens) {
            $path = ($token.Trim().Trim('(', ')', '"', "'").TrimEnd('.', ':') -replace '\\', '/') -replace '^\./', ''
            if ($Snapshot.Blobs.ContainsKey($path)) { $found[$path] = $Snapshot.Blobs[$path] }
        }
    }
    return $found
}

function Get-Moves($Snapshot, $State) {
    # Maps "path<TAB>blob" to a new path for each recorded file that moved unchanged: its path is gone, and
    # exactly one recorded path and one current path, not itself recorded, hold its content. A file that
    # moved and changed, or was split, is not a move.
    $now = New-PathMap
    foreach ($path in $Snapshot.Sorted) {
        $blob = $Snapshot.Blobs[$path]
        if ($now.ContainsKey($blob)) { $now[$blob] = '' } else { $now[$blob] = $path }
    }
    $pairs = New-Object 'System.Collections.Generic.List[object]'
    foreach ($path in $State.Hazards.Keys) { $pairs.Add(@($path, $State.Hazards[$path])) }
    foreach ($claim in $State.Claims) { foreach ($row in $claim.Evidence) { if ($row.Blob -ne '-') { $pairs.Add(@($row.Path, $row.Blob)) } } }
    $was = New-PathMap; $recorded = New-PathMap
    foreach ($pair in $pairs) {
        $recorded[$pair[0]] = $true
        if (-not $was.ContainsKey($pair[1])) { $was[$pair[1]] = $pair[0] } elseif ($was[$pair[1]] -cne $pair[0]) { $was[$pair[1]] = '' }
    }
    $moves = New-PathMap
    foreach ($pair in $pairs) {
        if ($Snapshot.Blobs.ContainsKey($pair[0]) -or $was[$pair[1]] -cne $pair[0] -or -not $now.ContainsKey($pair[1])) { continue }
        $to = $now[$pair[1]]
        if ($to -and -not $recorded.ContainsKey($to)) { $moves["$($pair[0])`t$($pair[1])"] = $to }
    }
    return $moves
}

function Test-NamesOldPath([string]$Text, [string]$Old, [string]$New) {
    # True when the text names the old path, or a folder or file name the move changed.
    if ($Text.IndexOf($Old, [StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    $kept = $New.Split('/')
    foreach ($segment in $Old.Split('/')) {
        if ($kept -contains $segment) { continue }
        if ([regex]::IsMatch($Text, '(?<!\w)' + [regex]::Escape($segment) + '(?!\w)', 'IgnoreCase')) { return $true }
    }
    return $false
}

function Get-Followed($Snapshot, $Moves, $Claim) {
    # The moves a claim follows: a file named exactly goes wherever it went, a glob or folder only to a path it
    # still matches. A claim whose text names what a move changed is Named: rechecked, never re-pointed.
    $followed = New-PathMap; $named = $false
    foreach ($row in $Claim.Evidence) {
        $key = "$($row.Path)`t$($row.Blob)"
        if (-not $Moves.ContainsKey($key)) { continue }
        $to = $Moves[$key]
        if ($row.Pattern -cne $row.Path -and (Resolve-Evidence $Snapshot $row.Pattern) -cnotcontains $to) { continue }
        $followed[$key] = $to
        if (Test-NamesOldPath $Claim.Text $row.Path $to) { $named = $true }
    }
    return [pscustomobject]@{ Moves = $followed; Named = $named }
}

function Read-Agents {
    # Text is the whole file normalized, to explain a refused claim. Lines maps a hash of each non-empty
    # line outside HTML comments (the version stamp lives in one) to that line. Statements are the list
    # items, wrapped lines joined, under ## Conventions (outside ### Verification Commands) and
    # ## Architecture Decisions; a claim's text must equal one of them.
    $agents = Join-Path $script:RootFull 'AGENTS.md'
    if (-not (Test-Path -LiteralPath $agents -PathType Leaf)) { Stop-With 2 'CANNOT EXAMINE: AGENTS.md is missing.' }
    $raw = [IO.File]::ReadAllText($agents)
    $lines = New-PathMap
    $statements = New-Object 'System.Collections.Generic.List[string]'
    $section = ''; $inScope = $false; $fenced = $false; $item = $null
    foreach ($line in ([regex]::Replace($raw, '(?s)<!--.*?-->', '') -split "`n")) {
        $normalized = Get-Normalized $line
        if ($normalized) { $lines[(Get-Sha256Hex $normalized).Substring(0, 12)] = $normalized }
        if ($normalized.StartsWith('```')) { $fenced = -not $fenced }
        $heading = [regex]::Match($normalized, '^(#{1,6}) (.+?)(?: #+)?$')
        $bullet = [regex]::Match($normalized, '^(?:[-*+]|\d+[.)]) (.+)$')
        $break = $fenced -or -not $normalized -or $heading.Success -or $bullet.Success -or $normalized.StartsWith('|') -or $normalized -match '^([-*_])\1{2,}$'
        if ($null -ne $item -and $break) { $statements.Add($item); $item = $null }
        if ($fenced -or -not $normalized) { continue }
        if ($heading.Success) {
            $level = $heading.Groups[1].Value.Length
            if ($level -le 2) { $section = $heading.Groups[2].Value; $inScope = $section -eq 'Conventions' -or $section -eq 'Architecture Decisions' }
            elseif ($level -eq 3 -and $section -eq 'Conventions') { $inScope = $heading.Groups[2].Value -ne 'Verification Commands' }
            continue
        }
        if (-not $inScope) { continue }
        # A break other than a new list item has already closed the item, so only wrapped text appends.
        if ($bullet.Success) { $item = $bullet.Groups[1].Value } elseif ($null -ne $item) { $item += ' ' + $normalized }
    }
    if ($null -ne $item) { $statements.Add($item) }
    $statementSet = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($statement in $statements) { [void]$statementSet.Add($statement) }
    return [pscustomobject]@{ Text = (Get-Normalized $raw); Lines = $lines; Statements = $statements; StatementSet = $statementSet }
}

function Read-State {
    # Returns $null when there is no usable baseline; the reason is in $script:StateProblem.
    $path = Join-Path $script:RootFull $script:StateRel
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $script:StateProblem = "$script:StateRel is missing"; return $null }
    $state = [pscustomobject]@{
        Recorded = ''; Profiles = New-Object 'System.Collections.Generic.List[string]'
        Areas = New-Object 'System.Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
        Projects = @{}; Workspaces = @{}; Hazards = New-PathMap
        Claims = New-Object 'System.Collections.Generic.List[object]'; ClaimsById = @{}; Lines = New-PathMap
    }
    $schema = $false
    foreach ($line in ([IO.File]::ReadAllText($path).TrimStart([char]0xFEFF) -replace "`r", '').Split("`n")) {
        if (-not $line -or $line.StartsWith('#')) { continue }
        $f = $line.Split("`t")
        switch ($f[0]) {
            'schema' { if ($f.Count -ne 2 -or $f[1] -ne '1') { $script:StateProblem = "$script:StateRel has an unsupported schema"; return $null }; $schema = $true }
            'recorded' { $state.Recorded = $f[1] }
            'profile' { if ($script:Profiles -notcontains $f[1]) { $script:StateProblem = "$script:StateRel names an unknown profile '$($f[1])'"; return $null }; $state.Profiles.Add($f[1]) }
            'line' { if ($f.Count -ne 2) { $script:StateProblem = "$script:StateRel has a malformed line row"; return $null }; $state.Lines[$f[1]] = $true }
            'area' { if ($f.Count -ne 3) { $script:StateProblem = "$script:StateRel has a malformed area row"; return $null }; $state.Areas[$f[1]] = $f[2] }
            'project' {
                if ($f.Count -ne 3) { $script:StateProblem = "$script:StateRel has a malformed project row"; return $null }
                if (-not $state.Projects.ContainsKey($f[1])) { $state.Projects[$f[1]] = New-PathMap }
                $state.Projects[$f[1]][$f[2]] = $true
            }
            'workspace' {
                if ($f.Count -ne 4) { $script:StateProblem = "$script:StateRel has a malformed workspace row"; return $null }
                if (-not $state.Workspaces.ContainsKey($f[1])) { $state.Workspaces[$f[1]] = New-PathMap }
                $state.Workspaces[$f[1]][$f[2]] = $f[3]
            }
            'hazard' { if ($f.Count -ne 3) { $script:StateProblem = "$script:StateRel has a malformed hazard row"; return $null }; $state.Hazards[$f[1]] = $f[2] }
            'claim' {
                if ($f.Count -ne 6 -or $script:Kinds -notcontains $f[4]) { $script:StateProblem = "$script:StateRel has a malformed claim row"; return $null }
                $claim = [pscustomobject]@{ Id = $f[1]; Profile = $f[2]; Pass = $f[3]; Kind = $f[4]; Text = $f[5]; Line = $line
                    Evidence = New-Object 'System.Collections.Generic.List[object]'; EvidenceLines = New-Object 'System.Collections.Generic.List[string]' }
                $state.Claims.Add($claim); $state.ClaimsById[$f[1]] = $claim
            }
            'evidence' {
                if ($f.Count -ne 5 -or -not $state.ClaimsById.ContainsKey($f[1])) { $script:StateProblem = "$script:StateRel has a malformed evidence row"; return $null }
                $state.ClaimsById[$f[1]].Evidence.Add([pscustomobject]@{ Pattern = $f[2]; Path = $f[3]; Blob = $f[4] })
                $state.ClaimsById[$f[1]].EvidenceLines.Add($line)
            }
            default { $script:StateProblem = "$script:StateRel has an unknown row '$($f[0])'"; return $null }
        }
    }
    if (-not $schema -or $state.Profiles.Count -eq 0) { $script:StateProblem = "$script:StateRel has no schema or profile rows"; return $null }
    return $state
}

function Get-Excerpt([string]$Text) {
    if ($Text.Length -le 100) { return $Text }
    return $Text.Substring(0, 100) + '...'
}

function Invoke-Record {
    if (-not $ClaimsPath -or -not (Test-Path -LiteralPath $ClaimsPath -PathType Leaf)) {
        Stop-With 1 'INVALID: -ClaimsPath must name an existing claims JSON file (write it outside the repository).'
    }
    try { $claimsInput = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $ClaimsPath).Path).TrimStart([char]0xFEFF) | ConvertFrom-Json }
    catch { Stop-With 1 "INVALID: the claims file is not valid JSON: $($_.Exception.Message)" }
    $snapshot = Get-Snapshot
    $agents = Read-Agents
    $problems = New-Object 'System.Collections.Generic.List[string]'
    $selected = @($claimsInput.profiles | Where-Object { $_ })
    if ($selected.Count -eq 0) { $problems.Add('INVALID: profiles must list at least one of dotnet, angular, warehouse.') }
    foreach ($profile in $selected) { if ($script:Profiles -cnotcontains $profile) { $problems.Add("INVALID: unknown profile '$profile' (expected dotnet, angular or warehouse).") } }
    $rows = New-Object 'System.Collections.Generic.List[string]'
    $ids = @{}
    $texts = New-Object 'System.Collections.Generic.List[string]'
    foreach ($claim in @($claimsInput.claims)) {
        if ($null -eq $claim) { continue }
        $text = if ($claim.text -is [string]) { Get-Normalized $claim.text } else { '' }
        $label = if ($text) { Get-Excerpt $text } else { '<no text>' }
        if ($selected -cnotcontains $claim.profile) { $problems.Add("INVALID: claim '$label' names profile '$($claim.profile)', which is not in profiles."); continue }
        if ($claim.pass -isnot [string] -or -not $claim.pass -or $claim.pass.IndexOfAny([char[]]"`t`r`n") -ge 0) { $problems.Add("INVALID: claim '$label' has no pass id."); continue }
        if ($script:Kinds -cnotcontains $claim.kind) { $problems.Add("INVALID: claim '$label' has kind '$($claim.kind)' (expected scoped, universal or absence)."); continue }
        if (-not $text) { $problems.Add("INVALID: claim '$label' has no text; copy one whole statement verbatim."); continue }
        if (-not $agents.StatementSet.Contains($text)) {
            # Name the statement to copy: the one holding this fragment, else the longest one it holds.
            $whole = @($agents.Statements | Where-Object { $_.Contains($text) } | Select-Object -First 1)
            if ($whole.Count -eq 0) { $whole = @($agents.Statements | Where-Object { $text.Contains($_) } | Sort-Object Length -Descending | Select-Object -First 1) }
            if ($whole.Count -eq 1) { $problems.Add("INVALID: claim '$label' is not one whole statement; copy the whole statement: $($whole[0])") }
            elseif ($agents.Text.Contains($text)) { $problems.Add("INVALID: claim '$label' is not a list item under ## Conventions or ## Architecture Decisions, so no claim can cover it.") }
            else { $problems.Add("INVALID: claim '$label' was not found in AGENTS.md; copy one whole statement verbatim.") }
            continue
        }
        $id = (Get-Sha256Hex "$($claim.profile)`n$text").Substring(0, 12)
        if ($ids.ContainsKey($id)) { $problems.Add("INVALID: claim '$label' is listed twice."); continue }
        $ids[$id] = $true
        $patterns = @($claim.evidence | Where-Object { $_ -is [string] } | ForEach-Object { ($_ -replace '\\', '/').Trim() -replace '^\./', '' })
        if ($patterns.Count -eq 0) { $problems.Add("INVALID: claim '$label' names no evidence path or glob."); continue }
        $evidenceRows = New-Object 'System.Collections.Generic.List[string]'
        foreach ($pattern in $patterns) {
            if (-not (Test-SafePattern $pattern)) { $problems.Add("INVALID: claim '$label' evidence '$pattern' is not a repository-relative path or glob."); continue }
            $found = Resolve-Evidence $snapshot $pattern
            if ($found.Count -eq 0 -and $claim.kind -ne 'absence') {
                $problems.Add("INVALID: claim '$label' evidence '$pattern' matches no file outside the paths framework-ownership.json lists.")
                continue
            }
            if ($found.Count -eq 0) { $evidenceRows.Add("evidence`t$id`t$pattern`t-`t-") }
            foreach ($path in $found) { $evidenceRows.Add("evidence`t$id`t$pattern`t$path`t$($snapshot.Blobs[$path])") }
        }
        $rows.Add("claim`t$id`t$($claim.profile)`t$($claim.pass)`t$($claim.kind)`t$text")
        $rows.AddRange($evidenceRows)
        $texts.Add($text)
    }
    if ($problems.Count -gt 0) {
        foreach ($problem in $problems) { Say $problem }
        Stop-With 1 "$($problems.Count) claim problem(s); nothing was recorded."
    }
    # Carry forward an unlisted claim that AGENTS.md still states: its old evidence hashes keep it
    # affected until a run rechecks and lists it, so carrying it forward never marks it verified.
    $carried = 0
    $previous = Read-State
    if ($previous) {
        $moves = Get-Moves $snapshot $previous
        foreach ($old in $previous.Claims) {
            if ($ids.ContainsKey($old.Id) -or $selected -cnotcontains $old.Profile -or -not $agents.StatementSet.Contains($old.Text)) { continue }
            $ids[$old.Id] = $true
            $rows.Add($old.Line)
            # A file that moved unchanged is re-pointed, unless the claim's text names what the move changed.
            $follow = Get-Followed $snapshot $moves $old
            for ($i = 0; $i -lt $old.Evidence.Count; $i++) {
                $row = $old.Evidence[$i]; $key = "$($row.Path)`t$($row.Blob)"
                if ($follow.Named -or -not $follow.Moves.ContainsKey($key)) { $rows.Add($old.EvidenceLines[$i]); continue }
                $to = $follow.Moves[$key]
                $pattern = if ($row.Pattern -ceq $row.Path) { $to } else { $row.Pattern }
                $rows.Add("evidence`t$($old.Id)`t$pattern`t$to`t$($row.Blob)")
            }
            $texts.Add($old.Text)
            $carried++
        }
    }
    # A statement no claim covers is never rechecked by an incremental run; name it for the report.
    $claimed = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($text in $texts) { [void]$claimed.Add($text) }
    $unclaimed = @($agents.Statements | Where-Object { -not $claimed.Contains($_) })
    $areas = Get-Areas $snapshot
    $areaKeys = [string[]]@($areas.Keys)
    [Array]::Sort($areaKeys, [StringComparer]::Ordinal)
    $out = New-Object 'System.Collections.Generic.List[string]'
    $out.Add('# ai-tech-lead rebootstrap baseline. Written by scripts/bootstrap-baseline.ps1 -Mode Record; do not edit by hand.')
    $out.Add("schema`t1")
    $out.Add("recorded`t$([DateTime]::UtcNow.ToString('yyyy-MM-dd'))")
    foreach ($profile in $selected) { $out.Add("profile`t$profile") }
    $lineKeys = [string[]]@($agents.Lines.Keys)
    [Array]::Sort($lineKeys, [StringComparer]::Ordinal)
    foreach ($key in $lineKeys) { $out.Add("line`t$key") }
    foreach ($area in $areaKeys) { $out.Add("area`t$area`t$($areas[$area])") }
    $out.AddRange((Get-ManifestRows $snapshot $selected))
    $hazards = Get-HazardPaths $snapshot
    $hazardKeys = [string[]]@($hazards.Keys)
    [Array]::Sort($hazardKeys, [StringComparer]::Ordinal)
    foreach ($path in $hazardKeys) { $out.Add("hazard`t$path`t$($hazards[$path])") }
    $out.AddRange($rows)
    $target = Join-Path $script:RootFull $script:StateRel
    [IO.Directory]::CreateDirectory((Split-Path $target -Parent)) | Out-Null
    # .NET calls, not Move-Item: Windows PowerShell 5.1 reads a bracketed -Destination as a wildcard.
    $temp = $target + '.tmp'
    [IO.File]::WriteAllText($temp, (($out.ToArray()) -join "`n") + "`n", (New-Object Text.UTF8Encoding($false)))
    [IO.File]::Copy($temp, $target, $true)
    [IO.File]::Delete($temp)
    # In full, not excerpted, so the text can be copied into a claim.
    foreach ($statement in $unclaimed) { Say "UNCLAIMED $statement" }
    Say "RECORDED claims=$($ids.Count) carried=$carried unclaimed=$($unclaimed.Count) profiles=$($selected -join ',')"
    Say "WROTE $script:StateRel"
    exit 0
}

function Invoke-Impact {
    $state = Read-State
    $snapshot = Get-Snapshot
    $agents = Read-Agents
    if (-not $state) {
        Say "BASELINE none -- cannot examine: $script:StateProblem"
        Stop-With 3 'RESULT full'
    }
    Say "BASELINE recorded=$($state.Recorded) claims=$($state.Claims.Count) profiles=$($state.Profiles -join ',')"

    $areas = Get-Areas $snapshot
    $changed = New-Object 'System.Collections.Generic.List[string]'
    foreach ($area in $areas.Keys) { if (-not $state.Areas.ContainsKey($area) -or $state.Areas[$area] -ne $areas[$area]) { $changed.Add($area) } }
    foreach ($area in $state.Areas.Keys) { if (-not $areas.ContainsKey($area)) { $changed.Add($area) } }
    $changedSorted = [string[]]@($changed.ToArray())
    [Array]::Sort($changedSorted, [StringComparer]::Ordinal)
    # Every changed area is listed: an incremental pass scopes to exactly this list.
    Say "CHANGED-AREAS $($changedSorted.Count)"
    foreach ($area in $changedSorted) { Say "AREA $area" }
    $edited = @($agents.Lines.Keys | Where-Object { -not $state.Lines.ContainsKey($_) } | ForEach-Object { $agents.Lines[$_] } | Sort-Object)
    foreach ($line in $edited) { Say "EDITED $(Get-Excerpt $line)" }
    # Every move is listed: /rebootstrap re-points a hazard row that names the old path.
    $moves = Get-Moves $snapshot $state
    $renamed = New-Object 'System.Collections.Generic.SortedSet[string]' ([StringComparer]::Ordinal)
    foreach ($key in $moves.Keys) { [void]$renamed.Add($key.Split("`t")[0] + ' -> ' + $moves[$key]) }
    foreach ($line in $renamed) { Say "RENAMED $line" }

    # Classify every claim; unaffected ones carry forward and are never printed.
    $affected = @{}; $status = @{}
    foreach ($claim in $state.Claims) {
        $reason = $null
        if (-not $agents.StatementSet.Contains($claim.Text)) { $reason = 'edited-or-removed' }
        else {
            $follow = Get-Followed $snapshot $moves $claim
            foreach ($pattern in @($claim.Evidence | ForEach-Object { $_.Pattern } | Select-Object -Unique)) {
                $recorded = New-PathMap; $found = New-PathMap
                foreach ($path in (Resolve-Evidence $snapshot $pattern)) { $found[$path] = $snapshot.Blobs[$path] }
                foreach ($row in @($claim.Evidence | Where-Object { $_.Pattern -eq $pattern -and $_.Blob -ne '-' })) {
                    $recorded[$row.Path] = $row.Blob
                    # A followed file counts as still at its recorded path.
                    $key = "$($row.Path)`t$($row.Blob)"
                    if ($follow.Moves.ContainsKey($key)) { $found.Remove($follow.Moves[$key]); $found[$row.Path] = $row.Blob }
                }
                if ($found.Count -eq 0 -and $claim.Kind -ne 'absence') { $reason = 'no-evidence-match'; break }
                if ($found.Count -ne $recorded.Count) { $reason = 'changed-evidence'; continue }
                foreach ($path in $found.Keys) {
                    if (-not $recorded.ContainsKey($path) -or $recorded[$path] -ne $found[$path]) { $reason = 'changed-evidence'; break }
                }
            }
            if (-not $reason -and $follow.Named) { $reason = 'names-old-path' }
        }
        $status[$claim.Id] = $reason
        if ($reason) { $affected[$claim.Id] = $true }
    }
    # Unchanged areas do not prove every claim current: a record carries an unlisted claim forward
    # with the evidence hashes it had, which may already be stale.
    if ($changedSorted.Count -eq 0 -and $edited.Count -eq 0 -and $affected.Count -eq 0) { Stop-With 0 'RESULT stop' }

    $currentManifests = @{}
    foreach ($row in (Get-ManifestRows $snapshot @($state.Profiles))) {
        $f = $row.Split("`t")
        if (-not $currentManifests.ContainsKey($f[1])) { $currentManifests[$f[1]] = @{ Projects = (New-PathMap); Workspaces = (New-PathMap) } }
        if ($f[0] -eq 'project') { $currentManifests[$f[1]].Projects[$f[2]] = $true } else { $currentManifests[$f[1]].Workspaces[$f[2]] = $f[3] }
    }
    $modes = @{}
    foreach ($profile in $state.Profiles) {
        $now = if ($currentManifests.ContainsKey($profile)) { $currentManifests[$profile] } else { @{ Projects = (New-PathMap); Workspaces = (New-PathMap) } }
        $wasProjects = if ($state.Projects.ContainsKey($profile)) { $state.Projects[$profile] } else { New-PathMap }
        $wasWorkspaces = if ($state.Workspaces.ContainsKey($profile)) { $state.Workspaces[$profile] } else { New-PathMap }
        $moved = New-Object 'System.Collections.Generic.List[string]'
        foreach ($path in $now.Projects.Keys) { if (-not $wasProjects.ContainsKey($path)) { $moved.Add($path) } }
        foreach ($path in $wasProjects.Keys) { if (-not $now.Projects.ContainsKey($path)) { $moved.Add($path) } }
        foreach ($path in $now.Workspaces.Keys) { if (-not $wasWorkspaces.ContainsKey($path) -or $wasWorkspaces[$path] -ne $now.Workspaces[$path]) { $moved.Add($path) } }
        foreach ($path in $wasWorkspaces.Keys) { if (-not $now.Workspaces.ContainsKey($path)) { $moved.Add($path) } }
        $movedSorted = [string[]]@($moved.ToArray())
        [Array]::Sort($movedSorted, [StringComparer]::Ordinal)

        $claims = @($state.Claims | Where-Object { $_.Profile -eq $profile })
        $hit = @($claims | Where-Object { $affected.ContainsKey($_.Id) }).Count
        $percent = if ($claims.Count -gt 0) { [int][Math]::Floor(100 * $hit / $claims.Count) } else { 0 }
        if ($movedSorted.Count -gt 0) {
            $mode = 'full'; $why = "manifest $($movedSorted[0])"
            if ($movedSorted.Count -gt 1) { $why += " (+$($movedSorted.Count - 1) more)" }
        } elseif ($claims.Count -eq 0) { $mode = 'full'; $why = 'no-claims' }
        elseif (2 * $hit -gt $claims.Count) { $mode = 'full'; $why = 'threshold' }
        else { $mode = 'incremental'; $why = 'none' }
        $modes[$profile] = $mode
        Say "PROFILE $profile $mode affected=$hit/$($claims.Count) ($percent%) reason=$why"
    }

    # A full profile rechecks every claim anyway, so only incremental profiles list claims.
    foreach ($claim in $state.Claims) {
        if ($modes[$claim.Profile] -ne 'incremental') { continue }
        if ($status[$claim.Id]) { Say "CLAIM $($status[$claim.Id]) $($claim.Id) $($claim.Profile)/$($claim.Pass): $(Get-Excerpt $claim.Text)" }
    }
    # With no changed file an "all X" or "no X" claim cannot have changed, so it needs no recheck.
    foreach ($claim in $state.Claims) {
        if ($changedSorted.Count -eq 0) { break }
        if ($modes[$claim.Profile] -ne 'incremental' -or $status[$claim.Id] -or $claim.Kind -eq 'scoped') { continue }
        Say "RECHECK $($claim.Kind) $($claim.Id) $($claim.Profile)/$($claim.Pass): $(Get-Excerpt $claim.Text)"
    }

    if (@($modes.Values | Where-Object { $_ -ne 'full' }).Count -eq 0) { $result = 'full' }
    else { $result = 'incremental' }
    Say "RESULT $result"
    exit 0
}

if (-not (Test-Path -LiteralPath $Root -PathType Container)) { Stop-With 2 "CANNOT EXAMINE: root '$Root' is not a directory." }
$script:RootFull = (Resolve-Path -LiteralPath $Root).Path
$script:StateProblem = ''
# exit is not an exception, so this catch sees only failures; they must not read as INVALID (1).
try {
    switch ($Mode) {
        'Record' { Invoke-Record }
        'Impact' { Invoke-Impact }
        default { Stop-With 1 "INVALID: -Mode must be Record or Impact (got '$Mode')." }
    }
} catch {
    Stop-With 2 "CANNOT EXAMINE: unexpected failure: $($_.Exception.Message)"
}
