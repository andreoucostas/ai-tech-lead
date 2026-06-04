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
if (-not (Get-Command $agentBin -ErrorAction SilentlyContinue)) {
    Write-Output "Headless agent '$agentBin' not on PATH — cannot run the behavioral A/B (Tier 2)."
    Write-Output "Install/auth it (Copilot CLI) or run only the deterministic before/after (Tier 1)."
    exit 3
}

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

foreach ($arm in 'pre', 'post') {
    $ref = if ($arm -eq 'pre') { $pre } else { $post }
    foreach ($task in $tasks) {
        $tid = $task.id
        $needBuild = [bool]$task.build
        New-Item -ItemType Directory -Force -Path (Join-Path $runDir "$arm/$tid") | Out-Null
        for ($t = 1; $t -le $trials; $t++) {
            $wt = Join-Path ([System.IO.Path]::GetTempPath()) ("impact_" + [guid]::NewGuid().ToString('N'))
            git worktree add -q --detach $wt $ref 2>$null
            if (-not $?) { Write-Output "  worktree add failed for '$ref' — skipping"; continue }

            $cmd = $agentCmd -replace '\{prompt\}', ('"' + ($task.prompt -replace '"', '\"') + '"')
            $start = Get-Date
            Push-Location $wt
            try { Invoke-Expression $cmd 2>$null | Out-Null } catch {}
            Pop-Location
            $dur = [int]((Get-Date) - $start).TotalSeconds

            git -C $wt add -A 2>$null | Out-Null
            $changed = @(git -C $wt diff --cached --name-only 2>$null | Where-Object { $_ })
            $abs = @($changed | ForEach-Object { Join-Path $wt $_ })
            $added = 0; $deleted = 0
            foreach ($l in (git -C $wt diff --cached --numstat 2>$null)) {
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

            git worktree remove --force $wt 2>$null | Out-Null
            if (Test-Path $wt) { Remove-Item -Recurse -Force $wt -ErrorAction SilentlyContinue }
            Write-Output "  $arm/$tid trial $t : acceptance=$acc build=$buildOk files=$($changed.Count)"
        }
    }
}
Write-Output "Done. Per-run metadata in $runDir/. Aggregate into a report with /impact."
