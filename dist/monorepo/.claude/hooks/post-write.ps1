# PostToolUse hook -- monorepo variant: dispatches per extension (B-19a trigger filters of both
# stacks). A write to .cs/.csproj/.sln/.props/.targets/.razor/.cshtml runs an incremental
# `dotnet build` (60 s throttle); a write to a .ts source under src/ or any tsconfig*.json runs
# `tsc --noEmit` (5 s throttle). Other files exit silently.
# Tool surfaces handled:
#   Claude Code (CLI + VS Code extension)  -- tool_name in {Write,Edit}; path at tool_input.file_path
#   GitHub Copilot (cloud agent + CLI)     -- toolName  in {edit,create}; path at toolArgs.filePath

$ErrorActionPreference = 'SilentlyContinue'

$null = New-Item -ItemType Directory -Path .claude\.state -Force

$inputJson = [Console]::In.ReadToEnd()
$filePath = ''
# Pre-declare so a malformed/empty payload leaves $tn = '' (not $null): the surface-routing at the
# end uses `$tn -eq ''` for Claude's empty-case exit-2 path, and $null -eq '' is False in PowerShell
# -- which would misroute a build failure to the Copilot exit-0 branch, diverging from the .sh twin's
# `case "$tool_name" in ... "")`. Keeping it '' matches the twin.
$tn = ''

if (-not [string]::IsNullOrEmpty($inputJson)) {
    try {
        $obj = $inputJson | ConvertFrom-Json
        $tn = if ($obj.tool_name) { [string]$obj.tool_name } elseif ($obj.toolName) { [string]$obj.toolName } else { '' }

        # Claude Code: tool_input.file_path
        if ($obj.tool_input) {
            if ($obj.tool_input.file_path) { $filePath = [string]$obj.tool_input.file_path }
            elseif ($obj.tool_input.filePath) { $filePath = [string]$obj.tool_input.filePath }
        }
        # Copilot: toolArgs is a parsed object (per spec), not a JSON string. Try object access first,
        # fall back to string parse for older payload shapes.
        $ta = $obj.toolArgs
        if ($ta -is [string]) { try { $ta = $ta | ConvertFrom-Json } catch { $ta = $null } }
        if ([string]::IsNullOrEmpty($filePath) -and $ta) {
            if ($ta.filePath) { $filePath = [string]$ta.filePath }
            elseif ($ta.file_path) { $filePath = [string]$ta.file_path }
            elseif ($ta.path) { $filePath = [string]$ta.path }
        }

        # Self-filter -- Copilot's hooks.json has no matcher, so gate here. Mirror guard.*: accept
        # known write tools (Claude Write/Edit, Copilot CLI edit/create) OR any tool carrying a file
        # path + content. The path+content arm covers VS Code agent mode's camelCase write tools
        # (str_replace/insert/create), which can't be enumerated; requiring content (not just a path)
        # keeps read-style tools from triggering a check.
        $contentParts = @($obj.tool_input.content, $obj.tool_input.new_string, $obj.tool_input.newString,
                          $obj.tool_input.file_text, $obj.tool_input.new_str, $obj.tool_input.text,
                          $ta.content, $ta.new_string, $ta.newString, $ta.file_text, $ta.new_str, $ta.text) |
                         Where-Object { $_ }
        $knownWrite = (@('Write','Edit','edit','create') -contains $tn) -or ($tn -eq '')
        if (-not ($knownWrite -or ($filePath -and $contentParts))) { exit 0 }
    } catch { }
}

if ([string]::IsNullOrEmpty($filePath) -and $env:CLAUDE_FILE_PATH) {
    $filePath = $env:CLAUDE_FILE_PATH
}

if ([string]::IsNullOrEmpty($filePath)) { exit 0 }
# Monorepo dispatch: pick the stack whose gate can actually validate this file (B-19a).
# .NET: sources plus MSBuild/Razor inputs. Angular: .ts under src/ plus any tsconfig*.json.
# Extensions neither gate reads stay excluded -- a check cannot catch their breakage.
$normalized = $filePath -replace '\\', '/'
$branch = ''
if ($filePath -match '\.(cs|csproj|sln|props|targets|razor|cshtml)$') { $branch = 'dotnet' }
elseif ($normalized -match '(^|/)tsconfig[^/]*\.json$') { $branch = 'angular' }
elseif ($filePath -like '*.ts' -and $normalized -match '/src/') { $branch = 'angular' }
else { exit 0 }

$msg = ''
if ($branch -eq 'dotnet') {
    # Bail cleanly if no dotnet CLI on PATH.
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { exit 0 }

    # Discover the build target: walk up from the written file to the nearest .sln so the whole
    # solution is built and cross-project breaks are caught; fall back to the nearest .csproj if no
    # solution exists up the tree. The old root-cwd `dotnet build` silently built nothing when the
    # solution lived in a subdirectory.
    $fileDir = Split-Path -Parent $filePath
    if ([string]::IsNullOrEmpty($fileDir)) { $fileDir = '.' }
    try { $dir = (Resolve-Path -LiteralPath $fileDir -ErrorAction Stop).Path } catch { exit 0 }

    $target = $null
    $probe = $dir
    while ($probe) {
        $sln = Get-ChildItem -LiteralPath $probe -Filter *.sln -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($sln) { $target = $sln.FullName; break }
        $parent = Split-Path -Parent $probe
        if ($parent -eq $probe) { break }
        $probe = $parent
    }
    if (-not $target) {
        $probe = $dir
        while ($probe) {
            $proj = Get-ChildItem -LiteralPath $probe -Filter *.csproj -File -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($proj) { $target = $proj.FullName; break }
            $parent = Split-Path -Parent $probe
            if ($parent -eq $probe) { break }
            $probe = $parent
        }
    }
    if (-not $target) { exit 0 }

    # Throttle: skip if a build was started within the last 60 seconds.
    $stamp = '.claude\.state\last-build-ts'
    # UTC integer epoch. NOT Get-Date -UFormat %s: under Windows PowerShell 5.1 that returns a
    # fractional local-time string, and [double]::Parse is culture-sensitive -- in comma-decimal
    # locales (de-DE/el-GR/fr-FR) the dot is a group separator, so the value overflows Int32 and
    # throws on every write. This form is culture-free, integer, UTC, and agrees with the .sh twin's
    # `date +%s`.
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if (Test-Path $stamp) {
        $lastRaw = Get-Content $stamp -Raw
        if ($lastRaw) {
            $last = 0
            if ([int]::TryParse($lastRaw.Trim(), [ref]$last) -and ($now - $last) -lt 60) {
                exit 0
            }
        }
    }
    Set-Content -Path $stamp -Value $now -Encoding ASCII

    # Only surface output on failure -- emitting the build summary every successful write wastes context tokens.
    $out = dotnet build $target --no-restore --verbosity quiet 2>&1
    if ($LASTEXITCODE -eq 0) { exit 0 }

    # Clear the throttle stamp so the next write rebuilds instead of skipping a known-broken build.
    Remove-Item $stamp -Force

    $msg = "## dotnet build failed -- fix before continuing:`n" + (($out | Select-Object -Last 20 | ForEach-Object { "$_" }) -join "`n")
}
else {
    # Discover the workspace root: walk up from the written file to the nearest ancestor holding
    # an Angular tsconfig. Supports root, ClientApp/, and Nx apps/* layouts -- the old root-cwd
    # assumption silently skipped the type-check for anything but a workspace at the repo root.
    $fileDir = Split-Path -Parent $filePath
    if ([string]::IsNullOrEmpty($fileDir)) { $fileDir = '.' }
    try { $dir = (Resolve-Path -LiteralPath $fileDir -ErrorAction Stop).Path } catch { exit 0 }

    $workspace = $null
    $probe = $dir
    while ($probe) {
        if ((Test-Path (Join-Path $probe 'tsconfig.app.json')) -or (Test-Path (Join-Path $probe 'tsconfig.json'))) {
            $workspace = $probe; break
        }
        $parent = Split-Path -Parent $probe
        if ($parent -eq $probe) { break }
        $probe = $parent
    }
    if (-not $workspace) { exit 0 }

    # Prefer tsconfig.app.json: an Nx/CLI app's tsconfig.json is solution-style (files:[], include:[],
    # references), and `tsc -p` against it compiles nothing and exits 0 -- a silent false pass.
    # tsconfig.app.json carries the real files/include, so the type-check actually runs.
    $project = if (Test-Path (Join-Path $workspace 'tsconfig.app.json')) { 'tsconfig.app.json' } else { 'tsconfig.json' }

    # Resolve tsc: node_modules may sit in the workspace or be hoisted to a monorepo root above it.
    $hasModules = $false
    $mp = $workspace
    while ($mp) {
        if (Test-Path (Join-Path $mp 'node_modules')) { $hasModules = $true; break }
        $parent = Split-Path -Parent $mp
        if ($parent -eq $mp) { break }
        $mp = $parent
    }
    if (-not $hasModules) { exit 0 }

    # Per-workspace state (absolute, under the repo-root .state) so multiple apps in a monorepo
    # neither clobber each other's incremental tsbuildinfo nor cross-suppress each other's throttle.
    $repoState = Join-Path (Get-Location).Path '.claude\.state'
    $null = New-Item -ItemType Directory -Path $repoState -Force
    $wsRel = try { [string](Resolve-Path -LiteralPath $workspace -Relative -ErrorAction Stop) } catch { $workspace }
    $key = ($wsRel -replace '[^A-Za-z0-9]', '_') -replace '_+$', ''
    if ([string]::IsNullOrEmpty($key)) { $key = 'root' }
    $stamp = Join-Path $repoState "last-build-$key"
    $buildInfo = Join-Path $repoState "tsbuildinfo-$key"

    # Throttle: skip if a check was started within the last 5 seconds.
    # UTC integer epoch. NOT Get-Date -UFormat %s: under Windows PowerShell 5.1 that returns a
    # fractional local-time string, and [double]::Parse is culture-sensitive -- in comma-decimal
    # locales (de-DE/el-GR/fr-FR) the dot is a group separator, so the value overflows Int32 and
    # throws on every write. This form is culture-free, integer, UTC, and agrees with the .sh twin's
    # `date +%s`.
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if (Test-Path $stamp) {
        $lastRaw = Get-Content $stamp -Raw
        if ($lastRaw) {
            $last = 0
            if ([int]::TryParse($lastRaw.Trim(), [ref]$last) -and ($now - $last) -lt 5) {
                exit 0
            }
        }
    }
    Set-Content -Path $stamp -Value $now -Encoding ASCII

    # Only surface output on failure -- emitting type-check output every successful write wastes context tokens.
    # Run from the workspace dir (npx resolves tsc by walking up to the monorepo node_modules);
    # the tsBuildInfoFile is an absolute repo-root path so it is unaffected by the Push-Location.
    Push-Location $workspace
    try {
        $out = npx --no-install tsc --noEmit -p $project --incremental --tsBuildInfoFile $buildInfo 2>&1
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($code -eq 0) { exit 0 }

    # Clear the throttle stamp so the next write re-checks instead of skipping a known-broken type-check.
    Remove-Item $stamp -Force

    $msg = "## tsc --noEmit failed -- fix before continuing:`n" + (($out | Select-Object -Last 20 | ForEach-Object { "$_" }) -join "`n")
}

# Surface per surface, discriminating by tool-name casing (mirror guard.ps1). Claude Code is the
# only surface consuming exit 2 + stderr; its tools are PascalCase Edit/Write -- and the ambiguous
# empty case routes here too, since its PostToolUse matcher only fires on Write|Edit.
# -ceq is required: case-insensitive -eq would route Copilot's lowercase 'edit' here by mistake.
if ($tn -ceq 'Edit' -or $tn -ceq 'Write' -or $tn -eq '') {
    [Console]::Error.WriteLine($msg)
    exit 2
}

# Everything else -- Copilot CLI (lowercase edit/create) AND VS Code agent mode (camelCase
# str_replace/insert/etc.) -- is sent the JSON additionalContext shape below, but a live sentinel
# canary (Copilot CLI 1.0.68, 2026-07-04) found the CLI model does NOT consume postToolUse stdout;
# this branch is emit-for-forward-compat only (see docs/enforcement-surfaces.md). VS Code unverified.
(@{ additionalContext = $msg } | ConvertTo-Json -Compress)
exit 0
