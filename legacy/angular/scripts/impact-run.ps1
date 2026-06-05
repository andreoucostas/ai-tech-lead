# Behavioral A/B runner — PowerShell twin of impact-run.sh.
# Usage: pwsh scripts/impact-run.ps1 <pre_ref> <post_ref> [--smoke]
# Runs each task in tests/impact/tasks.json through a headless agent (Copilot CLI) in throwaway git
# worktrees at <pre_ref> (old framework) vs <post_ref> (this one), N trials each, capturing per-run
# JSON to docs/impact/runs/. No human input. Stochastic — read trials as a distribution.
$ErrorActionPreference = 'Continue'
$root = (git rev-parse --show-toplevel 2>$null); if (-not $root) { $root = (Get-Location).Path }
Set-Location $root

$pre = $args[0]; $post = $args[1]; $mode = $args[2]
if (-not $pre -or -not $post) { Write-Output "Usage: pwsh scripts/impact-run.ps1 <pre_ref> <post_ref> [--smoke]"; exit 2 }

$cfgPath = 'tests/impact/config.json'; $tasksPath = 'tests/impact/tasks.json'
if (-not (Test-Path $cfgPath) -or -not (Test-Path $tasksPath)) { Write-Output "Missing tests/impact/config.json or tasks.json."; exit 2 }
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
$tasks = Get-Content $tasksPath -Raw | ConvertFrom-Json
$trials = if ($mode -eq '--smoke') { [int]$cfg.smoke_trials } else { [int]$cfg.trials }
if ($trials -lt 1) { $trials = 1 }

$agentCmd = $cfg.agent_cmd
$agentBin = ($agentCmd -split '\s+')[0]

# Resolve the headless agent robustly. Get-Command usually finds copilot.cmd via PATHEXT, but an
# npm-global install may sit in %APPDATA%\npm without that dir being on PATH — so also probe the
# .cmd/.exe shims and the npm-global locations before giving up.
function Resolve-Agent($b) {
    foreach ($c in @($b, "$b.cmd", "$b.exe")) {
        $g = Get-Command $c -ErrorAction SilentlyContinue
        if ($g -and $g.Source) { return $g.Source }
    }
    $dirs = @()
    try { $dirs += (npm prefix -g 2>$null) } catch {}
    if ($env:APPDATA)     { $dirs += (Join-Path $env:APPDATA 'npm') }
    if ($env:USERPROFILE) { $dirs += (Join-Path $env:USERPROFILE '.npm-global') }
    foreach ($d in $dirs) {
        if (-not $d) { continue }
        foreach ($c in @($b, "$b.cmd", "$b.exe")) {
            $p = Join-Path $d $c
            if (Test-Path $p) { return $p }
        }
    }
    return $null
}
$resolved = Resolve-Agent $agentBin
if (-not $resolved) {
    Write-Output "Headless agent '$agentBin' not found — looked for $agentBin / $agentBin.cmd / $agentBin.exe on PATH,"
    Write-Output "in ``npm prefix -g``, and %APPDATA%\npm. Tier 2 (behavioral A/B) skipped."
    Write-Output "Install the Copilot CLI (e.g. npm i -g @github/copilot) and authenticate once, or run Tier 1 only."
    exit 3
}
# Splice the resolved binary back into the command (replace only the first token); use the call
# operator for an absolute path so Invoke-Expression runs it even when it contains spaces.
$rest = $agentCmd.Substring($agentBin.Length)
$agentCmd = $(if ($resolved -match '[\\/]') { '& "' + $resolved + '"' } else { $resolved }) + $rest

# Infer a build command for this repo (used for tasks with "build": true).
$buildCmd = $null
$hasDotnet = Get-ChildItem -Path . -Recurse -File -Include *.sln, *.csproj -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } | Select-Object -First 1
if ($hasDotnet) {
    if (Get-Command dotnet -ErrorAction SilentlyContinue) { $buildCmd = 'dotnet build --nologo --verbosity quiet' }
} elseif (Test-Path 'angular.json') {
    if (Get-Command npx -ErrorAction SilentlyContinue) { $buildCmd = 'npx --no-install tsc --noEmit' }
}

$runDir = 'docs/impact/runs'
if (Test-Path $runDir) { Remove-Item -Recurse -Force $runDir }
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

# Short base dir for throwaway worktrees — Windows' 260-char MAX_PATH means a deep %TEMP% path plus a
# deep source tree overflows the limit and breaks `git worktree add` and the build. A drive-root dir
# keeps paths shallow; core.longpaths gives git extra headroom on top.
$wtBase = if ($env:SystemDrive) { Join-Path "$($env:SystemDrive)\" 'iwt' } else { Join-Path ([IO.Path]::GetTempPath()) 'iwt' }
try { New-Item -ItemType Directory -Force -Path $wtBase -ErrorAction Stop | Out-Null }
catch { $wtBase = Join-Path ([IO.Path]::GetTempPath()) 'iwt'; New-Item -ItemType Directory -Force -Path $wtBase | Out-Null }
git -c core.longpaths=true worktree prune 2>$null | Out-Null
$wtn = 0

# Exclude build artifacts from the captured diff so the A/B measures source changes only — robust even
# when the consumer repo doesn't gitignore bin/obj/node_modules/dist. (git clean -fd wouldn't remove
# those ignored dirs anyway; we filter the file list rather than clean the tree.)
$artExcl = @(':(exclude,glob)**/bin/**', ':(exclude,glob)**/obj/**', ':(exclude,glob)**/node_modules/**', ':(exclude,glob)**/dist/**', ':(exclude,glob)**/.angular/**', ':(exclude,glob)**/.vs/**', ':(exclude,glob)**/TestResults/**', ':(exclude,glob)**/coverage/**')

foreach ($arm in 'pre', 'post') {
    $ref = if ($arm -eq 'pre') { $pre } else { $post }
    foreach ($task in $tasks) {
        $tid = $task.id
        $needBuild = [bool]$task.build
        New-Item -ItemType Directory -Force -Path (Join-Path $runDir "$arm/$tid") | Out-Null
        for ($t = 1; $t -le $trials; $t++) {
            $wtn++; $wt = Join-Path $wtBase "w$wtn"
            if (Test-Path $wt) { Remove-Item -Recurse -Force $wt -ErrorAction SilentlyContinue }
            git -c core.longpaths=true worktree add -q --detach $wt $ref 2>$null
            if (-not $?) { Write-Output "  worktree add failed for '$ref' (path: $wt) — skipping"; continue }
            git -C $wt config core.longpaths true 2>$null | Out-Null

            $cmd = $agentCmd -replace '\{prompt\}', ('"' + ($task.prompt -replace '"', '\"') + '"')
            $start = Get-Date
            Push-Location $wt
            try { Invoke-Expression $cmd 2>$null | Out-Null } catch {}
            Pop-Location
            $dur = [int]((Get-Date) - $start).TotalSeconds

            git -C $wt add -A 2>$null | Out-Null
            $changed = @(git -C $wt diff --cached --name-only -- . @artExcl 2>$null | Where-Object { $_ })
            $abs = @($changed | ForEach-Object { Join-Path $wt $_ })
            $added = 0; $deleted = 0
            foreach ($l in (git -C $wt diff --cached --numstat -- . @artExcl 2>$null)) {
                $p = $l -split '\s+'
                if ($p[0] -match '^\d+$') { $added += [int]$p[0] }
                if ($p[1] -match '^\d+$') { $deleted += [int]$p[1] }
            }

            $buildOk = $null
            if ($needBuild -and $buildCmd) {
                Push-Location $wt
                Invoke-Expression $buildCmd 2>$null | Out-Null
                $buildOk = ($LASTEXITCODE -eq 0)
                Pop-Location
            }

            $assertReport = @(); $acc = $true
            foreach ($rx in @($task.asserts_match)) {
                if (-not $rx) { continue }
                $hit = $false
                if ($abs.Count -gt 0) { $hit = [bool](Select-String -Path $abs -Pattern $rx -ErrorAction SilentlyContinue | Select-Object -First 1) }
                if (-not $hit) { $acc = $false }
                $assertReport += [pscustomobject]@{ regex = $rx; expect = 'present'; pass = $hit }
            }
            foreach ($rx in @($task.asserts_no_match)) {
                if (-not $rx) { continue }
                $hit = $false
                if ($abs.Count -gt 0) { $hit = [bool](Select-String -Path $abs -Pattern $rx -ErrorAction SilentlyContinue | Select-Object -First 1) }
                $pass = -not $hit
                if (-not $pass) { $acc = $false }
                $assertReport += [pscustomobject]@{ regex = $rx; expect = 'absent'; pass = $pass }
            }
            if ($needBuild -and $buildOk -eq $false) { $acc = $false }

            $metrics = [pscustomobject]@{}
            if ($abs.Count -gt 0) {
                try { $metrics = (& "$root/scripts/metrics.ps1" @abs | ConvertFrom-Json).metrics } catch {}
            }

            [pscustomobject]@{
                arm = $arm; task = $tid; trial = $t; ref = $ref
                build_ok = $buildOk; acceptance = $acc; asserts = $assertReport
                antipatterns_introduced = $metrics
                files_changed = $changed.Count; lines_added = $added; lines_deleted = $deleted; duration_s = $dur
            } | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $runDir "$arm/$tid/$t.json") -Encoding UTF8

            git -c core.longpaths=true worktree remove --force $wt 2>$null | Out-Null
            if (Test-Path $wt) { Remove-Item -Recurse -Force $wt -ErrorAction SilentlyContinue }
            Write-Output "  $arm/$tid trial $t : acceptance=$acc build=$buildOk files=$($changed.Count)"
        }
    }
}
Write-Output "Done. Per-run metadata in $runDir/. Aggregate into a report with /impact."
