# SessionStart hook -- format high-signal context when the script is invoked.
# Session-start hook for the supported native Windows PowerShell topology.
# For Claude-shaped input this script emits plain stdout; for other JSON input it emits top-level
# and wrapped JSON additionalContext shapes. Emission and registration do not prove host firing or
# consumption; current VS Code session-hook lifecycles are unverified. See docs/enforcement-surfaces.md.
# Keep fast: no expensive scans. Targets git, CLAUDE.md, AGENTS.md, TECH_DEBT.md, and
# FRAMEWORK-CONTEXT.md only; the hazard table is capped at ~12 entries, so parsing stays cheap.

$ErrorActionPreference = 'SilentlyContinue'

# The repository is the folder that holds this hook's .claude\hooks folder, found from the hook's own
# path as route-prompt.ps1 finds it. PowerShell's location need not be the repository (in a sandbox on a
# host without filesystem enumeration it may be the drive root), so every path below is built from
# $repoRoot and every git call names it with -C.
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
function Get-RepoPath([string]$Relative) { Join-Path $repoRoot $Relative }

# Best-effort proof that hook wiring actually invoked this script. Telemetry must never affect
# the preload: an unwritable or otherwise unavailable state path is deliberately ignored.
try {
    $stateDir = Get-RepoPath '.claude/.state'
    New-Item -ItemType Directory -Force -Path $stateDir -ErrorAction Stop | Out-Null
    [IO.File]::WriteAllText(
        (Join-Path $stateDir 'last-session-start'),
        [DateTime]::UtcNow.ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture),
        [Text.UTF8Encoding]::new($false)
    )
} catch { }

# Emit UTF-8 when captured: consuming harnesses read raw bytes, and the default
# [Console]::OutputEncoding (the OEM code page on Windows) would mangle ⚠/—/🔴 into '?'.
# Guarded so an interactive console's code page is never changed.
if ([Console]::IsOutputRedirected) {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
}

# Read stdin (when redirected) for surface detection; Claude Code events carry hook_event_name. The agents send
# UTF-8, so it is read as UTF-8 (dropping a leading byte-order mark); [Console]::In would decode it with the console's
# input code page, and [Console]::InputEncoding is left alone, as it is the user's console's.
$stdinJson = ''
if ([Console]::IsInputRedirected) { $stdinJson = (New-Object IO.StreamReader([Console]::OpenStandardInput(), (New-Object Text.UTF8Encoding($false)))).ReadToEnd() }

# Weekly, offline-only version awareness. This does not know whether a newer version exists; it
# only names the installed stamp and says how to update. Claim the throttle record before
# emitting so an unwritable state directory cannot turn a low-noise nudge into every-session noise.
$versionNudge = $null
try {
    $versionFile = Get-RepoPath '.claude/framework-version.json'
    $installedVersion = (Get-Content -LiteralPath $versionFile -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json).version
    if ($installedVersion) {
        $nowEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $awarenessFile = Join-Path $stateDir 'last-version-awareness'
        $lastEpoch = 0L
        if (Test-Path -LiteralPath $awarenessFile) {
            [long]::TryParse([IO.File]::ReadAllText($awarenessFile).Trim(), [ref]$lastEpoch) | Out-Null
        }
        if ($lastEpoch -le 0 -or ($nowEpoch - $lastEpoch) -ge (7 * 86400)) {
            [IO.File]::WriteAllText($awarenessFile, $nowEpoch.ToString(), [Text.UTF8Encoding]::new($false))
            $versionNudge = "- **Framework version:** v$installedVersion installed; to update, re-run the installer from a newer framework release."
        }
    }
} catch { }

$body = (& {

Write-Output "## Session preload"
if ($versionNudge) { Write-Output $versionNudge }

# 1. Git branch + last 3 commits. $inGit gates every git-backed section (this one, the test entry points, the debt
# heat): the repository may sit above the folder the framework is installed in, so a `.git` entry in $repoRoot is not
# the test. git's own words go to $null; an unborn branch makes several of its calls fail with a fatal line.
$inGit = ([string](git -C $repoRoot rev-parse --is-inside-work-tree 2>$null)).Trim() -eq 'true'
if ($inGit) {
    $branch = git -C $repoRoot rev-parse --abbrev-ref HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $branch) {
        Write-Output "- **Branch:** ``$branch``"
    } else {
        Write-Output "- **Branch:** ``(unknown)``"
    }

    $recent = git -C $repoRoot log -3 --format='  - `%h` %s' 2>$null
    if ($LASTEXITCODE -eq 0 -and $recent) {
        Write-Output "- **Recent commits:**"
        foreach ($line in $recent) { Write-Output $line }
    }
}

# 2. Adoption / bootstrap state warning
if (Test-Path -LiteralPath (Get-RepoPath '.claude/adoption-pending.json')) {
    Write-Output "- 🔴 **ADOPTION PENDING — this repo is not consolidated yet.** The installer detected pre-existing AI tooling and inventoried it in ``.claude/adoption-pending.json``; any originals it moved are under ``docs/pre-adoption/``. The required next step is ``/adopt`` — NOT ``/bootstrap``, which would skip the archive/merge/provenance flow. ``/adopt`` is developer-initiated and cannot be invoked by the model: if you are an agent, stop and tell the developer to type ``/adopt``."
} else {
    # AGENTS.md is the project instruction file; a repo still on the older layout keeps it in CLAUDE.md.
    foreach ($instructionFile in @('AGENTS.md', 'CLAUDE.md')) {
        if (-not (Test-Path -LiteralPath (Get-RepoPath $instructionFile))) { continue }
        $text = Get-Content -LiteralPath (Get-RepoPath $instructionFile) -Raw -Encoding UTF8
        if ($text -and $text -match 'BOOTSTRAP_PENDING') {
            Write-Output "- ⚠ **$instructionFile is unbootstrapped** (BOOTSTRAP_PENDING marker present). ``/bootstrap`` must run before non-trivial work — conventions are still placeholder. It is developer-initiated and cannot be invoked by the model: if you are an agent, tell the developer to type ``/bootstrap``."
            # Before /bootstrap records a test command, name up to eight test entry points the repository tracks, leaving out every
            # framework-owned or retired framework path; when the ownership manifest lists no path, list nothing rather than a framework file.
            if ($inGit -and (Test-Path -LiteralPath (Get-RepoPath 'framework-ownership.json'))) {
                $framework = @{}; $ownedCount = 0
                try {
                    foreach ($entry in @((Get-Content -LiteralPath (Get-RepoPath 'framework-ownership.json') -Raw -Encoding UTF8 | ConvertFrom-Json).paths | Where-Object { $_.path })) { $framework[[string]$entry.path] = $true }
                    $ownedCount = $framework.Count
                    if ($ownedCount -and (Test-Path -LiteralPath (Get-RepoPath 'framework-retirements.json'))) { foreach ($entry in @((Get-Content -LiteralPath (Get-RepoPath 'framework-retirements.json') -Raw -Encoding UTF8 | ConvertFrom-Json).retirements | Where-Object { $_.path })) { $framework[[string]$entry.path] = $true } }
                } catch { $ownedCount = 0 }
                if ($ownedCount) {
                    # Entry points first (test projects, *.Tests.ps1 scripts, package.json), then files under test folders. Git filters and orders
                    # the paths; at most 500 candidates are examined and the first nine that qualify stop the listing, so a large tree costs little.
                    $exclude = @(':(exclude,glob,icase)**/node_modules/**', ':(exclude,glob,icase)**/bower_components/**', ':(exclude,glob,icase)**/bin/**', ':(exclude,glob,icase)**/obj/**', ':(exclude,glob,icase)**/dist/**')
                    $seen = @{}
                    $found = @(& {
                        git -C $repoRoot -c core.quotepath=off ls-files -- ':(glob,icase)**/*tests.csproj' ':(glob,icase)**/*test.csproj' ':(glob,icase)**/*.tests.ps1' ':(glob)**/package.json' $exclude 2>$null
                        git -C $repoRoot -c core.quotepath=off ls-files -- ':(glob,icase)**/tests/**' ':(glob,icase)**/test/**' ':(glob,icase)**/spec/**' ':(glob,icase)**/__tests__/**' $exclude 2>$null
                    } | Select-Object -First 500 | Where-Object {
                        $_ -and -not $seen.ContainsKey($_) -and -not $framework.ContainsKey($_) -and (Test-Path -LiteralPath (Get-RepoPath $_) -PathType Leaf) -and ($_ -notmatch '(^|/)package\.json$' -or $(try { @((Get-Content -LiteralPath (Get-RepoPath $_) -Raw -Encoding UTF8 | ConvertFrom-Json).scripts.PSObject.Properties.Name | Where-Object { $_ -cmatch '^test(:|$)' }).Count -gt 0 } catch { $false })) -and ($seen[$_] = $true)
                    } | Select-Object -First 9)
                    if ($found.Count) {
                        $shown = (@($found | Select-Object -First 8) -join ', ') + $(if ($found.Count -gt 8) { ' (and more)' } else { '' })
                        Write-Output "- **Unrecorded test entry points** (no Verification Commands recorded yet): $shown. Files, not recorded commands: before reporting tests **not available**, read the applicable one and run it with its evidenced interpreter; add no harness; migration/deploy stays manual/CI-only."
                    }
                }
            }
            break
        }
    }
    # Once /bootstrap has recorded a test command, name it, so a bug fix runs it on its own and sees it fail before the edit: a first test
    # run sent in the same turn as the edit can start after the edit lands and show no red.
    $agentsText = if (Test-Path -LiteralPath (Get-RepoPath 'AGENTS.md')) { Get-Content -LiteralPath (Get-RepoPath 'AGENTS.md') -Raw -Encoding UTF8 } else { '' }
    if ($agentsText -and $agentsText -notmatch 'BOOTSTRAP_PENDING') {
        $inCommands = $false
        $testCommands = @(@(foreach ($line in ($agentsText -split '\r?\n')) {
            if ($line -match '^#{1,6}\s') { $inCommands = $line -match '^#{2,6}\s+Verification Commands\s*$'; continue }
            if ($inCommands -and $line -match '^\|\s*\**test\**\s*\|([^|]*)\|') {
                $cell = $Matches[1]
                if ($cell -notmatch '^\s*not available') { foreach ($span in [regex]::Matches($cell, '`([^`]+)`')) { $span.Groups[1].Value } }
            }
        }) | Select-Object -Unique)
        if ($testCommands.Count) {
            $one = $testCommands.Count -eq 1
            $shown = (@($testCommands | Select-Object -First 3 | ForEach-Object { "``$_``" }) -join ', ') + $(if ($testCommands.Count -gt 3) { ' (and more)' } else { '' })
            Write-Output "- **Recorded test command$(if (-not $one) { 's' }):** $shown (``AGENTS.md`` › Verification Commands). For a bug fix, before any production edit, run $(if ($one) { 'it' } else { 'the applicable one' }) alone, with no other tool call in the same turn, and see the failing case fail: an edit sent in that turn can land first and hide the red."
        }
    }
}

# 3. Migration pointers. Existing consumers keep their protected CLAUDE.md and AGENTS.md on
# update; the installer moves the older layout (instructions in CLAUDE.md) only when AGENTS.md is
# the retired generated mirror, and the newly delivered carrier needs its import. This is
# discovery, not delivery: do not duplicate the rules into hook output.
if (Test-Path -LiteralPath (Get-RepoPath 'CLAUDE.md')) {
    $claude = Get-Content -LiteralPath (Get-RepoPath 'CLAUDE.md') -Raw -Encoding UTF8
    # Any @AGENTS.md mention counts, as in the installer: Claude Code honours inline imports too.
    if ($claude -and $claude -cnotmatch '(?<![\w/.@-])@(\./)?AGENTS\.md(?![\w-])') {
        Write-Output '- ⚠ **Instruction layout migration:** this repository''s instructions are still in `CLAUDE.md`; the framework now reads and writes them in `AGENTS.md`. Read `CLAUDE.md` for project conventions until this is fixed. To fix it, merge `CLAUDE.md`''s content into `AGENTS.md`, then reduce `CLAUDE.md` to the two lines `@AGENTS.md` and `@.github/instructions/framework-rules.instructions.md` (see `docs/upgrade-checklist.md`).'
    }
    if ((Test-Path -LiteralPath (Get-RepoPath '.github/instructions/framework-rules.instructions.md')) -and
        $claude -and -not $claude.Contains('@.github/instructions/framework-rules.instructions.md')) {
        Write-Output '- ⚠ **Framework rules migration:** `.github/instructions/framework-rules.instructions.md` is the current framework ruleset and supersedes any identically-titled sections in `CLAUDE.md`. Read it now. To make this permanent, add `@.github/instructions/framework-rules.instructions.md` to `CLAUDE.md` where those sections are, and delete them.'
    }
}

# 4. Workflow-routing pointer. The script writes this into whichever output shape the surface
# dispatch selects below. The framework rules (`.github/instructions/framework-rules.instructions.md`
# › Agentic Workflow) remain the canonical
# file-based routing definition. Hook firing and consumption are capability-specific; current VS Code
# session-hook lifecycles are unverified. The full intent->workflow vocabulary lives in section 1.
if (Test-Path -LiteralPath (Get-RepoPath 'CLAUDE.md')) {
    Write-Output '- **Workflow routing:** when a prompt clearly matches a workflow and the developer did not type a `/command`, self-classify and apply that workflow''s rails from the framework rules (`.github/instructions/framework-rules.instructions.md` › Agentic Workflow), section 1. State which workflow you concluded.'
}

# 5. TECH_DEBT items touching recently changed files
if ((Test-Path -LiteralPath (Get-RepoPath 'TECH_DEBT.md')) -and $inGit) {
    # --relative: from a folder below the repository root, only that folder's files, named as TECH_DEBT.md names them.
    $recentFiles = git -C $repoRoot log --since="14 days ago" --name-only --relative --format="" 2>$null |
        Where-Object { $_ -and $_.Trim() } |
        Sort-Object -Unique |
        Select-Object -First 30

    if ($recentFiles) {
        $debt = Get-Content -LiteralPath (Get-RepoPath 'TECH_DEBT.md') -Raw -Encoding UTF8
        $hot = 0
        if ($debt) {
            foreach ($f in $recentFiles) {
                if ([string]::IsNullOrWhiteSpace($f)) { continue }
                if ($debt.Contains($f)) { $hot++ }
            }
        }
        if ($hot -gt 0) {
            Write-Output "- **Debt heat:** $hot TECH_DEBT entry(ies) touch files changed in the last 14 days. Consider ``/debt`` for trojan-horse opportunities."
        }
    }
}

# 6. Overdue security findings
if (Test-Path -LiteralPath (Get-RepoPath 'SECURITY_FINDINGS.md')) {
    $secContent = Get-Content -LiteralPath (Get-RepoPath 'SECURITY_FINDINGS.md') -Raw -Encoding UTF8
    $openCount = ([regex]::Matches($secContent, '\| Open ')).Count
    if ($openCount -gt 0) {
        $today = (Get-Date).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
        $overdue = 0
        foreach ($line in (Get-Content -LiteralPath (Get-RepoPath 'SECURITY_FINDINGS.md') -Encoding UTF8)) {
            if ($line -match '\| Open ') {
                $dates = [regex]::Matches($line, '\d{4}-\d{2}-\d{2}')
                if ($dates.Count -ge 2) {
                    $due = $dates[1].Value
                    if ([string]::Compare($due, $today, $false) -lt 0) { $overdue++ }
                }
            }
        }
        if ($overdue -gt 0) {
            Write-Output "- 🔴 **Security:** $overdue overdue finding(s) in SECURITY_FINDINGS.md. Remediation SLA breached — review before starting new work."
        } else {
            Write-Output "- **Security:** $openCount open finding(s) in SECURITY_FINDINGS.md."
        }
    }
}

# 7. Team wiki index (cheap capped preload; staleness belongs to wiki-check)
if (Test-Path -LiteralPath (Get-RepoPath 'docs/wiki/INDEX.md')) {
    $wikiIndex = Get-Content -LiteralPath (Get-RepoPath 'docs/wiki/INDEX.md') -Raw -Encoding UTF8
    $wikiCount = ([regex]::Matches($wikiIndex, '(?m)^- \[')).Count
    if ($wikiCount -le 30) { Write-Output $wikiIndex.TrimEnd() }
    else { Write-Output "$wikiCount wiki entries — read docs/wiki/INDEX.md" }
}

# 8. Hazard-area staleness
if (Test-Path -LiteralPath (Get-RepoPath 'FRAMEWORK-CONTEXT.md')) {
    $frameworkContext = Get-Content -LiteralPath (Get-RepoPath 'FRAMEWORK-CONTEXT.md') -Raw -Encoding UTF8
    if ($frameworkContext -and $frameworkContext -notmatch 'KNOWN_HAZARD_AREAS_PENDING') {
        $inHazards = $false
        $openStale = 0
        $confirmedStale = 0
        $cutoff = (Get-Date).AddDays(-90)
        foreach ($line in (Get-Content -LiteralPath (Get-RepoPath 'FRAMEWORK-CONTEXT.md') -Encoding UTF8)) {
            if ($line -match '^## Known Hazard Areas\s*$') { $inHazards = $true; continue }
            if ($inHazards -and $line -match '^## ') { break }
            if (-not $inHazards -or $line -notmatch '^\|') { continue }
            $cells = $line.Split('|') | ForEach-Object { $_.Trim() }
            if ($cells.Count -lt 6) { continue }
            $area = $cells[1]; $hazard = $cells[2]; $status = $cells[3]; $rev = $cells[4]
            if (($area -eq '_(drafted by /bootstrap)_' -and $hazard -eq '_' -and $status -eq '_' -and $rev -eq '_') -or
                $status.StartsWith('[REVIEWED: not a hazard')) { continue }
            try {
                $reviewed = [datetime]::ParseExact($rev, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
                if ($reviewed -ge $cutoff) { continue }
            } catch { continue }
            if ($status -eq '[UNVERIFIED]' -or $status -eq '[SUSPECTED]') { $openStale++ }
            elseif ($status -eq '[VERIFIED]') { $confirmedStale++ }
        }
        if ($openStale -gt 0) {
            Write-Output "- ⚠ **Hazard areas:** $openStale hazard area(s) have waited over 90 days for a human answer — confirm each, or mark it 'not a hazard', in FRAMEWORK-CONTEXT.md > Known Hazard Areas."
        } elseif ($confirmedStale -gt 0) {
            Write-Output "- **Hazard areas:** $confirmedStale confirmed hazard area(s) are over 90 days old — a quick re-confirm in FRAMEWORK-CONTEXT.md keeps the map trustworthy."
        }
    }
}

}) -join "`n"

# Surface dispatch. Claude-shaped input selects plain stdout. Other JSON input selects top-level
# and hookSpecificOutput-wrapped SessionStart additionalContext JSON. These are script-emitted
# shapes only: registration and output do not prove that a host fired the event or consumed the
# result. Empty or non-JSON stdin selects plain stdout. Current VS Code session-hook lifecycles are
# unverified; dated CLI evidence is recorded in docs/enforcement-surfaces.md.
$isCopilot = ($stdinJson -and $stdinJson.TrimStart().StartsWith('{') -and ($stdinJson -notmatch '"hook_event_name"'))
if ($isCopilot) {
    $payload = @{
        additionalContext  = $body
        hookSpecificOutput = @{ hookEventName = 'SessionStart'; additionalContext = $body }
    }
    Write-Output ($payload | ConvertTo-Json -Compress -Depth 4)
} else {
    Write-Output $body
}

exit 0
