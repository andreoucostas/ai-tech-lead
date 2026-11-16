# The third quarter of the update-delivery cases, from B-471 (c) to -Reinstall: UpdateDelivery.Tests.ps1 holds the
# first, UpdateDelivery3.Tests.ps1 the second and UpdateDelivery4.Tests.ps1 the fourth. Split so CI runs the quarters
# in parallel (B-510); each dot-sources _UpdateDelivery.ps1 for its fixtures and helpers. Does NOT ship.
. (Join-Path $PSScriptRoot '_UpdateDelivery.ps1')

Reset-Tests

# B-471 (c): the layout move's CLAUDE.md stub is a write of this run, so a skip-worktree CLAUDE.md hides it from the commit as it
# hides any framework file the install wrote.
It 'B-471 the skip-worktree WARNING names CLAUDE.md when the instruction layout move rewrote it' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b471c-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "bin/`n"
        [IO.File]::WriteAllText((Join-Path $t 'CLAUDE.md'), "# Project`n`nB471 consumer rule.`n", [Text.UTF8Encoding]::new($false))
        & git -C $t add -A
        & git -C $t commit -qm 'team files'
        & git -C $t update-index --skip-worktree CLAUDE.md
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'moved: CLAUDE\.md -> AGENTS\.md') "calibration: the update did not move the instruction layout (exit $LASTEXITCODE): $out"
        Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String) -notmatch '(?m)^ ?M CLAUDE\.md') 'calibration: Git shows the rewritten CLAUDE.md'
        Assert ($out -cmatch "(?m)^WARNING: Git is told not to see local changes to [0-9]+ of the framework's own files \(skip-worktree or assume-unchanged\)[^\r\n]*: ([^\r\n]*, )?CLAUDE\.md[,.]") "the handoff does not name the CLAUDE.md stub the layout move wrote: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-471 (c): a greenfield in a repository whose Git this installer cannot run is "could not say", not "nothing flagged".
It 'B-471 a greenfield install into a Git repository with no Git on PATH says it could not ask Git about skip-worktree files' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b471c2-' + [guid]::NewGuid())
    try {
        $g = New-B309GitTarget -Root $root -Name 'nogit' -Ignore "bin/`n"
        $savedPath = $env:PATH
        try {
            $env:PATH = (@($savedPath -split ';' | Where-Object { $_ -and -not (Test-Path -LiteralPath (Join-Path $_ 'git.exe')) -and -not (Test-Path -LiteralPath (Join-Path $_ 'git.cmd')) }) -join ';')
            Assert (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) 'calibration: git is still on PATH'
            $blind = Invoke-Installer -Dist 'dotnet' -Target $g
            $blindExit = $LASTEXITCODE
        } finally { $env:PATH = $savedPath }
        Assert ($blindExit -eq 0 -and $blind -match 'mode: greenfield') "calibration: the greenfield without Git on PATH did not finish (exit $blindExit): $blind"
        Assert ($blind -cmatch "(?m)^NOTE: Git could not say whether it is told not to see local changes to any of the framework's files[^\r\n]*run  git ls-files -v  before committing") "a greenfield in a repository whose Git could not run says nothing about skip-worktree files: $blind"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'a disabled retired recipe skill: the update finishes, carries the folder''s consumer files and removes the active copy' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('recipe-disabled-' + [guid]::NewGuid())
    try {
        # The retirement deletes the unmodified SKILL.md first; the disabled carry must not then try to copy it.
        $active = Join-Path $t '.claude/skills/add-service'
        $pattern = Join-Path $active 'references/project-pattern.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $pattern) | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.91.0","template":"monorepo"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.91.0:dist/monorepo/framework-ownership.json'))
        [IO.File]::WriteAllText((Join-Path $t 'LEARNINGS.md'), "# Learnings`n`n## Disabled framework skill: add-service`n`nNot used here.`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $active 'SKILL.md'), (Get-GitBlobBytes -Spec 'v0.91.0:dist/monorepo/.claude/skills/add-service/SKILL.md'))
        $patternBytes = [Text.UTF8Encoding]::new($false).GetBytes("# Project pattern`nDISABLED-SIDECAR consumer evidence.`n")
        [IO.File]::WriteAllBytes($pattern, $patternBytes)
        $out = Invoke-Installer -Dist 'monorepo' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update stopped (exit $LASTEXITCODE): $out"
        $carried = Join-Path $t '.claude/disabled-skills/add-service/references/project-pattern.md'
        Assert ((Test-Path -LiteralPath $carried -PathType Leaf) -and (Test-B194BytesEqual $patternBytes ([IO.File]::ReadAllBytes($carried)))) "the consumer's project-pattern.md was not carried to disabled-skills: $out"
        Assert (-not (Test-Path -LiteralPath $active)) "the disabled skill's active copy was left in place: $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/disabled-skills/add-service/SKILL.md'))) "the retired framework SKILL.md was carried instead of retired: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# A disabled skill's active folder is carried to .claude/disabled-skills/ and deleted; the release's copy then goes over the
# carried files (B-430). Those paths are in no manifest, so what the carry and that copy would overwrite is saved first.
function New-B430Target {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$Skill, [string]$Ignore = '', [switch]$NoSkillBackup)
    $t = New-B429GitTarget -Root $Root -Ignore "/scratch/`n$Ignore"
    [IO.File]::WriteAllText((Join-Path $t 'LEARNINGS.md'), "# Learnings`n`n## Disabled framework skill: $Skill`n`nNot used here.`n", [Text.UTF8Encoding]::new($false))
    # The one-time skill backup an earlier update took: present, so this update does not copy the skills again.
    if (-not $NoSkillBackup) { New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/framework-update-backup/skills') | Out-Null }
    return $t
}

It 'B-430 a team''s own skill at a disabled framework skill''s path, and a team file at its .claude/disabled-skills path, are saved out of Git before the update writes over them, once across re-runs' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b430-' + [guid]::NewGuid())
    try {
        # B-393's attack: the team's own perf skill was carried to .claude/disabled-skills/perf/, the release's copy went over it,
        # and the active folder was deleted, so its text was left only in Git HEAD.
        $t = New-B430Target -Root $root -Skill 'perf'
        $utf8 = [Text.UTF8Encoding]::new($false)
        $teamSkill = $utf8.GetBytes("---`nname: perf`ndescription: our own load-test checklist`n---`nTEAM PERF RECIPE`n")
        $olderNotes = $utf8.GetBytes("team notes v1`n")
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/skills/perf/notes.md' = "team notes v2`n"; '.claude/disabled-skills/perf/notes.md' = "team notes v1`n" })
        [IO.File]::WriteAllBytes((Join-Path $t '.claude/skills/perf/SKILL.md'), $teamSkill)
        & git -C $t add -A
        & git -C $t commit -qm 'team perf skill'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/skills/perf'))) "the disabled skill's active copy was left in place: $out"
        Assert (Test-B194BytesEqual ([IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/.claude/skills/perf/SKILL.md'))) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/disabled-skills/perf/SKILL.md')))) "the release's perf skill is not at its disabled path: $out"
        Assert ([IO.File]::ReadAllText((Join-Path $t '.claude/disabled-skills/perf/notes.md')) -ceq "team notes v2`n") "the active folder's notes.md was not carried: $out"
        $skillSave = '.claude/framework-update-backup/files/_.claude/skills/perf/SKILL.md'
        $notesSave = '.claude/framework-update-backup/files/_.claude/disabled-skills/perf/notes.md'
        Assert ((Test-Path -LiteralPath (Join-Path $t $skillSave) -PathType Leaf) -and (Test-B194BytesEqual $teamSkill ([IO.File]::ReadAllBytes((Join-Path $t $skillSave))))) "the team's own .claude/skills/perf/SKILL.md was not saved byte-identical at $skillSave before the release's copy went over it: $out"
        Assert ((Test-Path -LiteralPath (Join-Path $t $notesSave) -PathType Leaf) -and (Test-B194BytesEqual $olderNotes ([IO.File]::ReadAllBytes((Join-Path $t $notesSave))))) "the team's .claude/disabled-skills/perf/notes.md was not saved byte-identical at $notesSave before the carry went over it: $out"
        Assert ($flat -match "NOTICE: LEARNINGS\.md disables the framework skill 'perf', so the update moves \.claude/skills/perf/ to \.claude/disabled-skills/perf/, where this release's copy replaces '\.claude/skills/perf/SKILL\.md', which differs from it: the update first saves it to $([regex]::Escape($skillSave))\.") "the save of the team's skill was not reported: $out"
        Assert ($flat -match "NOTICE: '\.claude/disabled-skills/perf/notes\.md' differs from the file this update writes there, so the update first saves it to $([regex]::Escape($notesSave))\.") "the save of the team's disabled-skills file was not reported: $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/') "a saved copy is committable: $status"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
        $again = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the second update failed (exit $LASTEXITCODE): $again"
        Assert (($again -replace '\s+', ' ') -notmatch 'first saves it to') "the second update saved again a file the first one handled: $again"
        Assert (@(Get-ChildItem -LiteralPath (Join-Path $t '.claude/framework-update-backup/files') -Recurse -File -Force).Count -eq 2) "the second update added a save: $again"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-430 a file in a disabled skill''s active copy that Git keeps out of commits is never moved to .claude/disabled-skills, where Git could commit it: it is saved out of Git, named in one NOTICE' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b430-hidden-' + [guid]::NewGuid())
    try {
        # B-429's attack: disabling create-adr moved a developer's ignored local.env to .claude/disabled-skills/create-adr/, where
        # Git showed it as ??; a tracked file whose local changes Git is told not to see leaks the same way. Once with the one-time
        # skill backup already taken (the copies go below files/), once with this update taking it (they are its copies).
        foreach ($withBackup in $true, $false) {
            $label = if ($withBackup) { 'skill backup present' } else { 'skill backup taken now' }
            $t = New-B430Target -Root (Join-Path $root "$withBackup") -Skill 'create-adr' -Ignore "/.claude/skills/create-adr/local.env`n" -NoSkillBackup:(-not $withBackup)
            New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/skills/create-adr') | Out-Null
            [IO.File]::WriteAllBytes((Join-Path $t '.claude/skills/create-adr/SKILL.md'), [IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/.claude/skills/create-adr/SKILL.md')))
            Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/skills/create-adr/config.json' = "{}`n" })
            & git -C $t add -A
            & git -C $t commit -qm 'create-adr with a shared config'
            & git -C $t update-index --skip-worktree .claude/skills/create-adr/config.json
            $local = [ordered]@{ '.claude/skills/create-adr/local.env' = "TOKEN=sk-FIXTURE3`n"; '.claude/skills/create-adr/config.json' = "{`"key`":`"LOCAL-FIXTURE`"}`n" }
            Write-B429Files -Folder $t -Files $local
            Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') "${label}: calibration: Git sees a file it should keep out"
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $flat = $out -replace '\s+', ' '
            Assert ($LASTEXITCODE -eq 0) "${label}: the update failed (exit $LASTEXITCODE): $out"
            Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/skills/create-adr'))) "${label}: the disabled skill's active copy was left in place: $out"
            Assert (Test-Path -LiteralPath (Join-Path $t '.claude/disabled-skills/create-adr/SKILL.md') -PathType Leaf) "${label}: the release's create-adr is not at its disabled path: $out"
            foreach ($name in 'local.env', 'config.json') {
                Assert (-not (Test-Path -LiteralPath (Join-Path $t ".claude/disabled-skills/create-adr/$name"))) "${label}: $name, which Git kept out of commits, was moved to .claude/disabled-skills/create-adr/: $out"
            }
            $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
            Assert ($status -notmatch 'local\.env|config\.json|framework-update-backup/') "${label}: a file Git kept out of commits, or a copy of it, is committable: $status"
            $saveRoot = if ($withBackup) { '.claude/framework-update-backup/files/_.claude/skills/create-adr' } else { '.claude/framework-update-backup/skills/create-adr' }
            foreach ($name in 'config.json', 'local.env') {
                $copy = Join-Path $t "$saveRoot/$name"
                Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq $local[".claude/skills/create-adr/$name"]) "${label}: $name was not saved byte-identical at $saveRoot/$name`: $out"
            }
            $notice = "NOTICE: Git keeps 2 files in the active copy of a disabled skill out of commits \(ignored, or tracked with local changes Git is told not to see\), so the update does not move them to \.claude/disabled-skills/, where Git could commit them: \.claude/skills/create-adr/config\.json is saved at $([regex]::Escape("$saveRoot/config.json")), \.claude/skills/create-adr/local\.env at $([regex]::Escape("$saveRoot/local.env"))\."
            Assert (@([regex]::Matches($flat, $notice)).Count -eq 1) "${label}: the kept-out files were not named in exactly one NOTICE: $out"
        }
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-430 attack: a disabled skill whose folder is spelt in another letter case still keeps the file Git ignores there out of .claude/disabled-skills' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b430-case-' + [guid]::NewGuid())
    try {
        # The fresh-session attack: .claude/skills/Perf on disk and in the index, LEARNINGS.md disabling 'perf'; the
        # case-sensitive :(literal) pathspec missed Perf/local.env, which moved to a committable .claude/disabled-skills path.
        $t = New-B430Target -Root $root -Skill 'perf' -Ignore ".claude/skills/Perf/local.env`n"
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/skills/Perf') | Out-Null
        [IO.File]::WriteAllBytes((Join-Path $t '.claude/skills/Perf/SKILL.md'), [IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/.claude/skills/perf/SKILL.md')))
        & git -C $t add -A
        & git -C $t commit -qm 'perf skill'
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/skills/Perf/local.env' = "TOKEN=sk-FIX10`n" })
        Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') 'calibration: Git does not ignore Perf/local.env'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/disabled-skills/perf/local.env'))) "local.env, which Git ignored, was moved to .claude/disabled-skills/perf/: $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'local\.env') "the ignored file, or a copy of it, is committable: $status"
        $copy = Join-Path $t '.claude/framework-update-backup/files/_.claude/skills/perf/local.env'
        Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq "TOKEN=sk-FIX10`n") "local.env was not saved below the backup folder: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-322 a re-run of a finished update keeps the consumer''s pre-update settings backup' {
    # Every update run saved .claude/settings.json over the last backup, so re-running a finished update
    # replaced the consumer's settings in it with the framework's own; a non-Git target has no other copy.
    # The crlf leg is the framework's file as a core.autocrlf checkout writes it.
    foreach ($leg in 'crlf', 'lf') {
        $t = Join-Path ([IO.Path]::GetTempPath()) ("b322-$leg-" + [guid]::NewGuid())
        try {
            New-ArchGeneratorTarget -Target $t
            [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/framework-ownership.json'))
            $settings = Join-Path $t '.claude/settings.json'
            [IO.File]::WriteAllText($settings, '{"B322":"consumer settings"}', [Text.UTF8Encoding]::new($false))
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "${leg}: the update failed (exit $LASTEXITCODE): $out"
            $backup = Join-Path $t '.claude/.state/settings.json.pre-update'
            Assert ((Test-Path -LiteralPath $backup -PathType Leaf) -and [IO.File]::ReadAllText($backup) -match 'B322') "${leg}: calibration: the update did not back up the consumer's settings: $out"
            if ($leg -eq 'crlf') {
                $lf = [IO.File]::ReadAllText($settings)
                Assert ($lf.Contains("`n") -and -not $lf.Contains("`r")) 'crlf: calibration: the refreshed settings are not a multi-line LF file'
                [IO.File]::WriteAllText($settings, $lf.Replace("`n", "`r`n"), [Text.UTF8Encoding]::new($false))
            }
            $rerun = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "${leg}: the re-run failed (exit $LASTEXITCODE): $rerun"
            Assert ([IO.File]::ReadAllText($backup) -match 'B322') "${leg}: the re-run replaced the consumer's settings backup with the framework's: $rerun"
            Assert (($rerun -replace '\s+', ' ') -match 'kept the earlier pre-update settings backup') "${leg}: the re-run did not say it kept the earlier backup: $rerun"
        } finally {
            Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

It 'B-321 a one-time skill backup that a held file or a denied write cut short is taken again, so an edited framework skill keeps a copy' {
    # A backup cut short was skipped by the next run because its folder existed, which then overwrote the
    # edited skill; it survived in no file. The denied leg fails the first write below the backup folder,
    # where a marker written inside the new folder once failed with the folder already there.
    $manifestBytes = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/framework-ownership.json'
    $skillPaths = @(([Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json).paths | ForEach-Object { [string]$_.path } | Where-Object { $_.StartsWith('.claude/skills/') })
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    foreach ($leg in 'denied', 'held') {
        $t = Join-Path ([IO.Path]::GetTempPath()) ("b321-$leg-" + [guid]::NewGuid())
        $handle = $null; $deniedRoot = $null
        try {
            New-ArchGeneratorTarget -Target $t
            [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), $manifestBytes)
            foreach ($relative in $skillPaths) {
                $destination = Join-Path $t $relative
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
                [IO.File]::WriteAllBytes($destination, (Get-GitBlobBytes -Spec "v0.86.7:dist/dotnet/$relative"))
            }
            $edited = Join-Path $t '.claude/skills/remember-for-team/SKILL.md'
            [IO.File]::AppendAllText($edited, "`nB321 consumer edit.`n")
            if ($leg -eq 'held') {
                # A project-adapted sidecar, as /bootstrap writes one; it sorts before the edited skill.
                $held = Join-Path $t '.claude/skills/add-warehouse-load/references/project-pattern.md'
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $held) | Out-Null
                [IO.File]::WriteAllText($held, "# Project pattern`n", [Text.UTF8Encoding]::new($false))
                $handle = [IO.File]::Open($held, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
            } else {
                $deniedRoot = Join-Path $t '.claude/framework-update-backup'
                New-Item -ItemType Directory -Force -Path $deniedRoot | Out-Null
                & icacls $deniedRoot /deny "*${sid}:(OI)(CI)(IO)(WD)" | Out-Null
                Assert ($LASTEXITCODE -eq 0) 'calibration: icacls could not deny writes below the backup folder'
            }
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $flat = $out -replace '\s+', ' '
            Assert ($LASTEXITCODE -eq 3) "${leg}: the cut-short backup did not stop the update with exit 3 (exit $LASTEXITCODE): $out"
            Assert ($flat -match "Could not finish the one-time skill backup at '\.claude/skills/") "${leg}: the stop did not name where the backup stopped: $out"
            if ($leg -eq 'held') { Assert ($flat -match "at '\.claude/skills/add-warehouse-load/references/project-pattern\.md'") "held: the stop did not name the held file: $out" }
            Assert ([IO.File]::ReadAllText($edited) -match 'B321 consumer edit\.') "${leg}: the stop overwrote the edited skill: $out"
            if ($handle) { $handle.Dispose(); $handle = $null }
            if ($deniedRoot) { & icacls $deniedRoot /remove:d "*$sid" | Out-Null; $deniedRoot = $null }
            $rerun = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "${leg}: the re-run did not finish the update (exit $LASTEXITCODE): $rerun"
            $backup = Join-Path $t '.claude/framework-update-backup/skills/remember-for-team/SKILL.md'
            Assert ((Test-Path -LiteralPath $backup -PathType Leaf) -and [IO.File]::ReadAllText($backup) -match 'B321 consumer edit\.') "${leg}: the re-run did not take the backup again, so the edit survives in no file: $rerun"
            Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/framework-update-backup/skills-backup-incomplete'))) "${leg}: the finished backup still has its incomplete marker: $rerun"
        } finally {
            if ($handle) { $handle.Dispose() }
            if ($deniedRoot) { & icacls $deniedRoot /remove:d "*$sid" | Out-Null }
            Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

It 'B-319 an install leaves no source file that a project at the repository root compiles' {
    foreach ($dist in 'dotnet', 'monorepo') {
        $t = Join-Path ([IO.Path]::GetTempPath()) ("b319-$dist-" + [guid]::NewGuid())
        try {
            # An SDK-style project compiles every *.cs beneath it except under bin/, obj/ and dot-folders,
            # so the shipped NetArchTest sample broke `dotnet build` in a repo with its project at the root.
            [void][IO.Directory]::CreateDirectory($t)
            [IO.File]::WriteAllBytes((Join-Path $t 'App.csproj'), [Text.Encoding]::ASCII.GetBytes('<Project Sdk="Microsoft.NET.Sdk" />'))
            $out = Invoke-Installer -Dist $dist -Target $t
            Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: greenfield') "calibration: the $dist install failed: $out"
            $compiled = @(Get-ChildItem -LiteralPath $t -Recurse -File -Force | Where-Object { $_.Extension -eq '.cs' } |
                ForEach-Object { $_.FullName.Substring($t.Length + 1).Replace('\', '/') } |
                Where-Object { -not @($_.Split('/') | Where-Object { $_.StartsWith('.') }).Count })
            Assert ($compiled.Count -eq 0) "$dist installs source files a root-level project compiles: $($compiled -join ', ')"
            Assert (Test-Path -LiteralPath (Join-Path $t 'scripts/ci/ArchitectureTests.cs.sample') -PathType Leaf) "the $dist architecture-test sample was not installed under its inert name: $out"
        } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

It 'B-319 an update retires the compiled architecture-test sample and keeps a consumer-edited one' {
    foreach ($modified in @($false, $true)) {
        $label = if ($modified) { 'modified' } else { 'known' }
        $t = Join-Path ([IO.Path]::GetTempPath()) ("b319-retire-$label-" + [guid]::NewGuid())
        try {
            New-ArchGeneratorTarget -Target $t
            [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/framework-ownership.json'))
            $sample = Join-Path $t 'scripts/ci/ArchitectureTests.sample.cs'
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $sample) | Out-Null
            $bytes = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/scripts/ci/ArchitectureTests.sample.cs'
            Assert ($bytes.Count -gt 0) 'calibration: the v0.86.7 sample fixture is empty'
            if ($modified) { $bytes = $bytes + [Text.UTF8Encoding]::new($false).GetBytes("// locally edited`n") }
            [IO.File]::WriteAllBytes($sample, $bytes)
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "$label sample update failed: $out"
            if ($modified) {
                Assert (Test-Path -LiteralPath $sample -PathType Leaf) 'a consumer-edited sample was deleted'
                Assert (Test-B194BytesEqual $bytes ([IO.File]::ReadAllBytes($sample))) 'a preserved sample changed bytes'
                Assert ($out -match "CANT-VERIFY: retired path 'scripts/ci/ArchitectureTests\.sample\.cs' has consumer-modified or unknown content") "the edited sample was not diagnosed: $out"
            } else {
                Assert (-not (Test-Path -LiteralPath $sample)) "a known compiled sample survived the update: $out"
                Assert ($out -match '(?m)^PLAN delete scripts/ci/ArchitectureTests\.sample\.cs\r?$') "the sample's deletion was not planned: $out"
            }
            Assert (Test-Path -LiteralPath (Join-Path $t 'scripts/ci/ArchitectureTests.cs.sample') -PathType Leaf) "the inert sample was not installed: $out"
        } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

# Git for Windows checks text out with CRLF (core.autocrlf=true); the ledger records the released LF blobs.
function ConvertTo-B287CrlfBytes {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    $out = New-Object 'System.Collections.Generic.List[byte]' ($Bytes.Length + 4096)
    foreach ($b in $Bytes) { if ($b -eq 0x0A) { $out.Add([byte]0x0D) }; $out.Add($b) }
    return ,$out.ToArray()
}

It 'B-287 a retired file checked out with CRLF line endings is retired like its LF original' {
    $impact = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/.claude/commands/impact.md'
    $generator = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/scripts/build-architecture-html.ps1'
    # A BOM'd blob with non-ASCII bytes catches a text-level rewrite that a plain ASCII blob would not.
    Assert ($generator.Length -gt 3 -and $generator[0] -eq 0xEF -and $generator[1] -eq 0xBB -and $generator[2] -eq 0xBF -and
        @($generator[3..($generator.Length - 1)] | Where-Object { $_ -gt 0x7F }).Count -gt 0) 'calibration: the generator blob is not a BOM-prefixed file with non-ASCII bytes'
    $utf8 = [Text.UTF8Encoding]::new($false)
    $crlfImpact = ConvertTo-B287CrlfBytes $impact
    $firstCr = [Array]::IndexOf($crlfImpact, [byte]0x0D)
    $trailingSpace = [byte[]]($crlfImpact[0..($firstCr - 1)] + @([byte]0x20) + $crlfImpact[$firstCr..($crlfImpact.Length - 1)])
    $cases = @(
        @{ Label = 'crlf-ps1'; Path = 'scripts/build-architecture-html.ps1'; Bytes = (ConvertTo-B287CrlfBytes $generator); Retired = $true },
        @{ Label = 'crlf-md'; Path = '.claude/commands/impact.md'; Bytes = (ConvertTo-B287CrlfBytes $impact); Retired = $true },
        # Line endings are the only difference forgiven: an added BOM or an edited line is consumer content.
        @{ Label = 'crlf-bom-md'; Path = '.claude/commands/impact.md'; Bytes = ([byte[]](0xEF, 0xBB, 0xBF) + (ConvertTo-B287CrlfBytes $impact)); Retired = $false },
        @{ Label = 'crlf-edited-md'; Path = '.claude/commands/impact.md'; Bytes = ((ConvertTo-B287CrlfBytes $impact) + $utf8.GetBytes("# locally edited`r`n")); Retired = $false },
        # Nothing wider than CR LF -> LF: lone CR endings and a trailing-space edit are not Git's conversion.
        @{ Label = 'lone-cr-md'; Path = '.claude/commands/impact.md'; Bytes = ([byte[]]@($impact | ForEach-Object { if ($_ -eq 0x0A) { [byte]0x0D } else { $_ } })); Retired = $false },
        @{ Label = 'crlf-trailing-space-md'; Path = '.claude/commands/impact.md'; Bytes = $trailingSpace; Retired = $false }
    )
    foreach ($case in $cases) {
        $t = Join-Path ([IO.Path]::GetTempPath()) ("b287-$($case.Label)-" + [guid]::NewGuid())
        try {
            New-ArchGeneratorTarget -Target $t
            [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/framework-ownership.json'))
            $planted = Join-Path $t $case.Path
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $planted) | Out-Null
            [IO.File]::WriteAllBytes($planted, [byte[]]$case.Bytes)
            Assert ([Array]::IndexOf([byte[]]$case.Bytes, [byte]0x0D) -ge 0) "calibration: $($case.Label) holds no CR"
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "$($case.Label) update failed: $out"
            $escaped = [regex]::Escape($case.Path)
            if ($case.Retired) {
                Assert (-not (Test-Path -LiteralPath $planted)) "$($case.Label): a CRLF copy of a released blob survived the update: $out"
                Assert ($out -match "(?m)^PLAN delete $escaped\r?$") "$($case.Label): the deletion was not planned: $out"
            } else {
                Assert (Test-Path -LiteralPath $planted -PathType Leaf) "$($case.Label): consumer content was deleted: $out"
                Assert (Test-B194BytesEqual ([byte[]]$case.Bytes) ([IO.File]::ReadAllBytes($planted))) "$($case.Label): consumer content was changed: $out"
                Assert ($out -match "CANT-VERIFY: retired path '$escaped' has consumer-modified or unknown content") "$($case.Label): the preserved file was not diagnosed: $out"
            }
        } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

It 'a missing previous ownership manifest never authorizes generator deletion' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('arch-retire-nomanifest-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        $generator = Join-Path $t 'scripts/build-architecture-html.ps1'
        $bytes = Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/scripts/build-architecture-html.ps1'
        [IO.File]::WriteAllBytes($generator, $bytes)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "missing-manifest update failed: $out"
        Assert (Test-Path -LiteralPath $generator -PathType Leaf) 'deletion occurred without previous ownership authority'
        Assert (Test-B194BytesEqual $bytes ([IO.File]::ReadAllBytes($generator))) 'preserved generator changed bytes'
        Assert ($out -match 'CANT-VERIFY: previous framework-ownership\.json is missing') "missing previous manifest was not disclosed: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

# Field report #13: on Bitbucket with Bamboo nothing runs the GitHub Actions workflow, and every update put a deleted copy back.
It 'a deleted GitHub Actions workflow stays deleted across updates; another deleted framework file, or the workflow with no usable manifest, comes back' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('wf-deleted-' + [guid]::NewGuid())
    try {
        $t = New-B309GitTarget -Root $root -Name 'bitbucket' -Ignore "bin/`n"
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $first -match 'mode: greenfield') "calibration: the first install failed (exit $LASTEXITCODE): $first"
        $workflow = Join-Path $t '.github/workflows/docs-sync-check.yml'
        $other = Join-Path $t 'scripts/wiki-check.ps1'
        Assert ((Test-Path -LiteralPath $workflow -PathType Leaf) -and (Test-Path -LiteralPath $other -PathType Leaf)) "calibration: the install wrote no workflow or no scripts/wiki-check.ps1: $first"
        & git -C $t add -A; & git -C $t commit -qm 'framework install'
        Remove-Item -LiteralPath $workflow, $other -Force
        & git -C $t add -A; & git -C $t commit -qm 'no GitHub Actions here'
        $update = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $update -match 'mode: update') "the update failed (exit $LASTEXITCODE): $update"
        Assert (-not (Test-Path -LiteralPath $workflow)) "the update put back the deleted .github/workflows/docs-sync-check.yml: $update"
        Assert (Test-Path -LiteralPath $other -PathType Leaf) "the update did not put back the deleted scripts/wiki-check.ps1: $update"
        $source = Join-Path (Resolve-Path -LiteralPath (Join-Path $repoRoot 'dist/dotnet')).Path '.github\workflows\docs-sync-check.yml'
        Assert ($update -match 'NOTICE: \.github/workflows/docs-sync-check\.yml was not put back' -and $update.Contains($source)) "the update does not say it left the workflow out and where to copy it from ($source): $update"
        $listed = @((Get-Content -Raw -LiteralPath (Join-Path $t 'framework-ownership.json') | ConvertFrom-Json).paths | Where-Object { [string]$_.path -ceq '.github/workflows/docs-sync-check.yml' })
        Assert ($listed.Count -eq 1) "the manifest no longer lists the workflow, so the next update would put it back: $update"
        & git -C $t add -A; & git -C $t commit -qm 'framework update'
        $again = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and -not (Test-Path -LiteralPath $workflow)) "a second update put the workflow back (exit $LASTEXITCODE): $again"
        # Without a usable previous manifest nothing says the framework wrote it, so the workflow is installed.
        Remove-Item -LiteralPath (Join-Path $t 'framework-ownership.json') -Force
        & git -C $t add -A; & git -C $t commit -qm 'no manifest'
        $unowned = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $workflow -PathType Leaf)) "without a previous manifest the update did not install the workflow (exit $LASTEXITCODE): $unowned"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

# The step-4 attack on the field report #13 change: missing from disk is not deleted while Git still tracks the file.
It 'a workflow Git still tracks but that is missing from disk (skip-worktree) is put back, not taken for a deletion' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('wf-skipped-' + [guid]::NewGuid())
    try {
        $t = New-B309GitTarget -Root $root -Name 'skipped' -Ignore "bin/`n"
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $first -match 'mode: greenfield') "calibration: the first install failed (exit $LASTEXITCODE): $first"
        & git -C $t add -A; & git -C $t commit -qm 'framework install'
        & git -C $t update-index --skip-worktree -- .github/workflows/docs-sync-check.yml
        $workflow = Join-Path $t '.github/workflows/docs-sync-check.yml'
        Remove-Item -LiteralPath $workflow -Force
        Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') 'calibration: git status shows the skip-worktree file missing'
        $update = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $update"
        Assert ((Test-Path -LiteralPath $workflow -PathType Leaf) -and $update -notmatch 'was not put back') "a workflow Git still tracks was taken for a deletion: $update"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'a junction or a file in place of .github/workflows is refused as before, never taken for a deletion' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('wf-blocked-' + [guid]::NewGuid())
    $outside = Join-Path $root 'outside'
    try {
        foreach ($shape in 'junction', 'file') {
            $t = New-B309GitTarget -Root $root -Name $shape -Ignore "bin/`n"
            $first = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0 -and $first -match 'mode: greenfield') "calibration: the $shape fixture's first install failed (exit $LASTEXITCODE): $first"
            & git -C $t add -A; & git -C $t commit -qm 'framework install'
            & git -C $t rm -q -- .github/workflows/docs-sync-check.yml; & git -C $t commit -qm 'no GitHub Actions here'
            $folder = Join-Path $t '.github/workflows'
            Assert (-not (Test-Path -LiteralPath $folder)) "calibration: git rm left .github/workflows in the $shape fixture"
            if ($shape -eq 'junction') {
                [void][IO.Directory]::CreateDirectory($outside)
                New-Item -ItemType Junction -Path $folder -Target $outside | Out-Null
            } else {
                [IO.File]::WriteAllText($folder, "not a folder`n", [Text.UTF8Encoding]::new($false))
                & git -C $t add -- .github/workflows; & git -C $t commit -qm 'a file where the folder was'
            }
            Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') "calibration: the $shape fixture is not clean"
            $update = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 3 -and $update -notmatch 'was not put back') "a $shape at .github/workflows was taken for a deletion instead of refused (exit $LASTEXITCODE): $update"
        }
        Assert (@(Get-ChildItem -Force -LiteralPath $outside).Count -eq 0) 'the update wrote through the junction'
    } finally {
        $link = Join-Path $root 'junction/.github/workflows'
        if (Test-Path -LiteralPath $link) { [IO.Directory]::Delete($link) }
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'a workflow kept deleted under the team''s own ignore rule draws no WARNING that the rule hides it' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('wf-ignored-' + [guid]::NewGuid())
    try {
        $t = New-B309GitTarget -Root $root -Name 'ignored' -Ignore "bin/`n"
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $first -match 'mode: greenfield') "calibration: the first install failed (exit $LASTEXITCODE): $first"
        & git -C $t add -A; & git -C $t commit -qm 'framework install'
        & git -C $t rm -q -- .github/workflows/docs-sync-check.yml
        [IO.File]::AppendAllText((Join-Path $t '.gitignore'), ".github/workflows/`n", [Text.UTF8Encoding]::new($false))
        & git -C $t add -- .gitignore; & git -C $t commit -qm 'no GitHub Actions here'
        $update = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and -not (Test-Path -LiteralPath (Join-Path $t '.github/workflows/docs-sync-check.yml'))) "calibration: the update did not keep the workflow deleted (exit $LASTEXITCODE): $update"
        Assert ($update -notmatch 'ignore rules hide') "the update warns that an ignore rule hides a file it did not write: $update"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

# Regression guard. install.ps1 built the .sh twin's replacement only when the matching .ps1 was
# still in the incoming manifest, and the generic residual arm mapped any .sh to its .ps1. Retiring
# the .ps1 would therefore have silently dropped the .sh twin's migration message and, where one
# still appeared, aimed it at a file that is itself retired. Neither twin may name the other.
It 'neither retired generator twin is ever told to migrate to the other' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('arch-retire-twins-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        foreach ($leaf in @('build-architecture-html.ps1', 'build-architecture-html.sh')) {
            [IO.File]::WriteAllText((Join-Path $t "scripts/$leaf"), "# consumer copy`n", [Text.UTF8Encoding]::new($false))
        }
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "twin diagnostic update failed: $out"
        foreach ($leaf in @('build-architecture-html.ps1', 'build-architecture-html.sh')) {
            Assert (Test-Path -LiteralPath (Join-Path $t "scripts/$leaf") -PathType Leaf) "unknown $leaf bytes were deleted"
            Assert ($out -match "CANT-VERIFY: retained retired generator 'scripts/$([regex]::Escape($leaf))' remains") "retained $leaf was not diagnosed: $out"
        }
        Assert ($out -match 'read docs/ARCHITECTURE\.md directly') "no diagnostic named the canonical Markdown replacement: $out"
        Assert ($out -notmatch "migrate references to 'scripts/build-architecture-html\.ps1'") "a diagnostic directed the reader at the retired generator: $out"
        Assert ($out -notmatch "migrate references to 'the supported PowerShell surface'.*build-architecture") "a retired generator got the generic no-successor message: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'a retired path outside the hand-listed categories is still preserved and diagnosed' {
    # The residual gate used to admit only five categories, so anything retired later was preserved
    # in silence and each new retirement had to remember to add itself (B-240). A retired command is
    # none of those five: not a .github skill, sync script, Git-hook helper, v0.83 or the generator.
    $t = Join-Path ([IO.Path]::GetTempPath()) ('retired-uncategorised-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/commands') | Out-Null
        $retained = Join-Path $t '.claude/commands/impact.md'
        [IO.File]::WriteAllText($retained, "# my edited copy`n", [Text.UTF8Encoding]::new($false))
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "uncategorised retirement update failed: $out"
        Assert (Test-Path -LiteralPath $retained -PathType Leaf) 'consumer-modified retired command was deleted'
        Assert ($out -match "CANT-VERIFY: retained retired framework path '\.claude/commands/impact\.md' remains") "retained retired command was not diagnosed: $out"
        Assert ($out -match 'retired with no replacement command') "diagnostic did not say there is no successor: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'a retired .sh whose .ps1 twin is also retired still gets a migration replacement' {
    # The generic .sh arm built its entry only while the twin was still in the incoming manifest, so
    # a pair retired together produced no MIGRATION text at all. Drive the installer: asserting on
    # the ledger alone is inert, because the filter that picks the pair also guarantees the claim.
    $t = Join-Path ([IO.Path]::GetTempPath()) ('retired-twin-migration-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        # CLAUDE.md is consumer-owned/protected: it is not overwritten, so a stale command inside it
        # is exactly what the MIGRATION diagnostic exists to report.
        [IO.File]::WriteAllText((Join-Path $t 'CLAUDE.md'),
            "# Project`n`nRun ``bash scripts/impact-run.sh`` and ``bash scripts/sync-agent-files.sh`` nightly.`n",
            [Text.UTF8Encoding]::new($false))
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "retired-twin migration update failed: $out"
        foreach ($sh in @('scripts/impact-run.sh', 'scripts/sync-agent-files.sh')) {
            Assert ($out -match "MIGRATION: protected consumer carrier 'CLAUDE\.md' names retired framework path '$([regex]::Escape($sh))'") "no MIGRATION line for $sh : $out"
        }
        Assert ($out -match 'that feature is retired and has no replacement command; remove the reference') "the no-successor replacement text was not emitted: $out"
        Assert ($out -notmatch "replace that reference with: .*scripts/impact-run\.ps1") "a diagnostic directed the reader at the retired .ps1 twin: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'a dangling retired-path reparse is CANT-VERIFY and never classified absent' {
    # A junction needs no privilege on Windows, where a file symlink does (B-509: the old file-symlink
    # probe skipped this case on every CI host). Test-Path says True for a dangling junction on both
    # hosts, so the fixture is checked by its reparse attribute and missing target, not by Test-Path.
    $t = Join-Path ([IO.Path]::GetTempPath()) ('retired-dangling-' + [guid]::NewGuid())
    $linkTarget = Join-Path ([IO.Path]::GetTempPath()) ('retired-link-target-' + [guid]::NewGuid())
    try {
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
        New-Item -ItemType Directory -Force -Path (Join-Path $t 'scripts') | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.82.0"}', [Text.UTF8Encoding]::new($false))
        $manifestBytes = Get-GitBlobBytes -Spec 'v0.82.0:dist/dotnet/framework-ownership.json'
        Assert ($manifestBytes.Count -gt 0) 'the v0.82.0 ownership manifest fixture is empty'
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), $manifestBytes)
        New-Item -ItemType Directory -Force -Path $linkTarget | Out-Null
        $link = Join-Path $t 'scripts/wiki-check.sh'
        New-Item -ItemType Junction -Path $link -Target $linkTarget -ErrorAction Stop | Out-Null
        Remove-Item -LiteralPath $linkTarget -Recurse -Force
        $entry = Get-Item -Force -LiteralPath $link -ErrorAction Stop
        Assert ($null -ne $entry -and ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -and
            -not [IO.Directory]::Exists($linkTarget)) 'calibration: scripts/wiki-check.sh is not a dangling junction'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "installer failed instead of preserving dangling residue: $out"
        Assert ($out -match "CANT-VERIFY: retired path 'scripts/wiki-check\.sh' traverses reparse/symlink") "dangling retired link was not classified CANT-VERIFY: $out"
        Assert ($null -ne (Get-Item -Force -LiteralPath $link -ErrorAction Stop)) 'installer removed the dangling retired link'
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $linkTarget -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'licence and notice no longer ship: an update removes the unmodified notice and keeps an edited licence copy instead of refusing' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-legal-' + [guid]::NewGuid())
    try {
        # 0.96.0 stops shipping LICENSES/ai-tech-lead-MIT.txt and NOTICE-ai-tech-lead.md into consumer repositories.
        foreach ($stack in 'dotnet', 'angular', 'monorepo') {
            foreach ($rel in 'LICENSES/ai-tech-lead-MIT.txt', 'NOTICE-ai-tech-lead.md') {
                Assert (-not (Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/$rel"))) "$stack still ships $rel"
            }
        }
        $notice = Join-Path $t 'NOTICE-ai-tech-lead.md'
        $licence = Join-Path $t 'LICENSES/ai-tech-lead-MIT.txt'
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude'), (Split-Path -Parent $licence) | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.95.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.95.0:dist/dotnet/framework-ownership.json'))
        [IO.File]::WriteAllBytes($notice, (Get-GitBlobBytes -Spec 'v0.95.0:dist/dotnet/NOTICE-ai-tech-lead.md'))
        # The licence was consumer-owned: the team decides whether to keep it, even an edited copy.
        $licenceBytes = [Text.UTF8Encoding]::new($false).GetBytes("the team's own licence text`n")
        [IO.File]::WriteAllBytes($licence, $licenceBytes)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath $notice)) "the unmodified retired notice survived: $out"
        Assert (Test-B194BytesEqual $licenceBytes ([IO.File]::ReadAllBytes($licence))) "the team's licence copy was not kept byte-identical: $out"
        $manifest = Get-Content -Raw -LiteralPath (Join-Path $t 'framework-ownership.json') | ConvertFrom-Json
        $listed = @($manifest.paths | ForEach-Object path)
        Assert ($listed -notcontains 'NOTICE-ai-tech-lead.md' -and $listed -notcontains 'LICENSES/ai-tech-lead-MIT.txt') "the installed manifest still lists the licence or notice: $($listed -join ', ')"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}
It 'an edited notice stays after the update and is named as the team''s to keep, not as a file to remove' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-notice-' + [guid]::NewGuid())
    try {
        $notice = Join-Path $t 'NOTICE-ai-tech-lead.md'
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.95.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.95.0:dist/dotnet/framework-ownership.json'))
        $noticeBytes = (Get-GitBlobBytes -Spec 'v0.95.0:dist/dotnet/NOTICE-ai-tech-lead.md') + [Text.UTF8Encoding]::new($false).GetBytes("Also covers the team's vendored helpers.`n")
        [IO.File]::WriteAllBytes($notice, $noticeBytes)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (Test-B194BytesEqual $noticeBytes ([IO.File]::ReadAllBytes($notice))) "the edited notice was not kept byte-identical: $out"
        Assert ($flat -match "NOTICE: 'NOTICE-ai-tech-lead\.md' remains because it differs from every notice this framework shipped\. The framework no longer ships a notice; the file is yours to keep or delete\.") "the kept notice was not named as the team's to keep: $out"
        Assert ($flat -notmatch "'NOTICE-ai-tech-lead\.md' remains\. It is retired with no replacement command") "the kept notice got the generic remove-it advice: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Runs the installer with -Target quoted by hand so the child's own parser hands the installer
# exactly $Target, trailing backslash and all (a tab-completed folder name ends in one).
function Invoke-InstallerLiteralTarget {
    param([Parameter(Mandatory)][string]$Dist, [Parameter(Mandatory)][string]$Target)
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = (Get-PsExe)
    $quoted = '"' + $Target + $(if ($Target.EndsWith('\')) { '\' }) + '"'
    $start.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + (Join-Path $repoRoot "dist/$Dist/scripts/install.ps1") + '" -Target ' + $quoted
    $start.UseShellExecute = $false
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::Start($start)
    $stderr = $process.StandardError.ReadToEndAsync()
    $stdout = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
    $global:LASTEXITCODE = $process.ExitCode
    return $stdout + $stderr.Result
}

It 'a Git target named with a space and passed with a trailing backslash updates to exit 0 on both hosts' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('trail-' + [guid]::NewGuid())
    try {
        $t = New-B309GitTarget -Root $root -Name 'My Repo' -Ignore "bin/`n"
        $first = Invoke-InstallerLiteralTarget -Dist 'dotnet' -Target ($t + '\')
        Assert ($LASTEXITCODE -eq 0 -and $first -match 'mode: greenfield') "the first install over '$t\' failed (exit $LASTEXITCODE): $first"
        & git -C $t add -A
        & git -C $t commit -qm 'framework install'
        $out = Invoke-InstallerLiteralTarget -Dist 'dotnet' -Target ($t + '\')
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: update') "the update over '$t\' did not reach mode: update with exit 0 (exit $LASTEXITCODE): $out"
        Assert ($out -notmatch 'CANT-VERIFY') "the update could not ask Git about '$t\': $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}
It 'a target below a junction, passed with a trailing backslash, installs; the walk stops at the target, not at the drive root' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('trailj-' + [guid]::NewGuid())
    $real = Join-Path $root 'real'
    $link = Join-Path $root 'link'
    try {
        [void][IO.Directory]::CreateDirectory((Join-Path $real 'sub'))
        & cmd /c "mklink /J `"$link`" `"$real`" >nul"
        Assert (Test-Path -LiteralPath $link) 'calibration: the junction was not created'
        $out = Invoke-InstallerLiteralTarget -Dist 'dotnet' -Target ((Join-Path $link 'sub') + '\')
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: greenfield') "a junction above the target refused the install (exit $LASTEXITCODE): $out"
    } finally {
        if (Test-Path -LiteralPath $link) { & cmd /c "rmdir `"$link`"" }
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'a target that is itself a junction is refused with exit 3 naming the link' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('junctgt-' + [guid]::NewGuid())
    $real = Join-Path $root 'real'
    $link = Join-Path $root 'link'
    try {
        [void][IO.Directory]::CreateDirectory($real)
        & cmd /c "mklink /J `"$link`" `"$real`" >nul"
        Assert (Test-Path -LiteralPath $link) 'calibration: the junction was not created'
        $out = Invoke-InstallerLiteralTarget -Dist 'dotnet' -Target $link
        Assert ($LASTEXITCODE -eq 3 -and $out -match "traverses reparse/symlink '[^']*link'") "an install into a junction was not refused at the link (exit $LASTEXITCODE): $out"
        Assert (@(Get-ChildItem -LiteralPath $real -Force).Count -eq 0) 'the install wrote through the junction'
    } finally {
        if (Test-Path -LiteralPath $link) { & cmd /c "rmdir `"$link`"" }
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# No test can give a folder the cloud-files attribute, so the predicate is taken from the installer's own AST.
It 'the installer predicate calls a reparse point with no link type a folder and a junction or symlink a link' {
    $script = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
    $ast = [Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$null)
    $fn = $ast.Find({ param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Test-IsLinkEntry' }, $true)
    Assert ($null -ne $fn) 'the installer defines no Test-IsLinkEntry; any reparse point is treated as a link'
    $predicate = $fn.Body.GetScriptBlock()
    $dir = [IO.FileAttributes]'Directory, ReparsePoint'
    Assert (-not (& $predicate ([pscustomobject]@{ Attributes = $dir; LinkType = $null; Target = $null }))) 'a cloud-files folder (no LinkType, no Target) was called a link'
    Assert (-not (& $predicate ([pscustomobject]@{ Attributes = $dir; LinkType = ''; Target = @() }))) 'a cloud-files folder (empty LinkType, empty Target) was called a link'
    Assert (& $predicate ([pscustomobject]@{ Attributes = $dir; LinkType = 'Junction'; Target = @('C:\x') })) 'a junction was not called a link'
    Assert (& $predicate ([pscustomobject]@{ Attributes = $dir; LinkType = 'SymbolicLink'; Target = @('C:\x') })) 'a directory symlink was not called a link'
    Assert (& $predicate ([pscustomobject]@{ Attributes = $dir; LinkType = $null; Target = @('C:\x') })) 'a reparse point that reports a Target was not called a link'
    Assert (-not (& $predicate ([pscustomobject]@{ Attributes = [IO.FileAttributes]'Directory'; LinkType = 'Junction'; Target = @('C:\x') }))) 'an entry without the reparse attribute was called a link'
    Assert (-not (& $predicate $null)) 'a missing entry was called a link'
    $bare = @($ast.FindAll({ param($n) $n -is [Management.Automation.Language.BinaryExpressionAst] -and $n.Operator -eq 'Band' -and $n.Extent.Text -match 'ReparsePoint' }, $true) |
        Where-Object { $_.Extent.StartOffset -lt $fn.Extent.StartOffset -or $_.Extent.StartOffset -ge $fn.Extent.EndOffset })
    Assert ($bare.Count -eq 0) "the installer still tests the reparse attribute alone at: $(($bare | ForEach-Object { $_.Extent.StartLineNumber }) -join ', ')"
}

It 'an update over a 0-byte LEARNINGS.md succeeds and disables no skill' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-emptylearn-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    try {
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the install failed (exit $LASTEXITCODE): $first"
        [IO.File]::WriteAllBytes((Join-Path $t 'LEARNINGS.md'), [byte[]]@())
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 0 -and $out -match '(?m)^\s*mode: update') "an update over an empty LEARNINGS.md did not succeed in update mode (exit $exit): $out"
        Assert ((Get-Item -LiteralPath (Join-Path $t 'LEARNINGS.md')).Length -eq 0) 'the empty LEARNINGS.md was changed'
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# A Windows clone with core.autocrlf=true checks SKILL.md out with CRLF; the exemplar line captured from it
# must not carry its CR into the rewritten file, which is LF throughout and ends in exactly one LF.
It 'a CRLF SKILL.md has its exemplar re-appended without a carriage return' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-crlfexemplar-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    try {
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the install failed (exit $LASTEXITCODE): $first"
        $skill = Join-Path $t '.claude/skills/add-warehouse-load/SKILL.md'
        $exemplar = 'For a concrete current instance in this repo, see `warehouse/LoadSales.sql`.'
        $crlf = ([IO.File]::ReadAllText($skill, [Text.UTF8Encoding]::new($false)).TrimEnd() + "`n`n" + $exemplar + "`n") -replace "`r?`n", "`r`n"
        [IO.File]::WriteAllText($skill, $crlf, [Text.UTF8Encoding]::new($false))
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 0 -and $out -match '(?m)^\s*mode: update') "the update did not succeed in update mode (exit $exit): $out"
        $bytes = [IO.File]::ReadAllBytes($skill)
        $text = [Text.UTF8Encoding]::new($false).GetString($bytes)
        Assert ($text.Contains($exemplar)) 'the exemplar line was not re-appended'
        Assert (-not $text.Contains("`r")) "the rewritten SKILL.md still holds a carriage return (last bytes: $($bytes[($bytes.Length - 4)..($bytes.Length - 1)] -join ','))"
        Assert ($text.EndsWith($exemplar + "`n", [StringComparison]::Ordinal)) 'the rewritten SKILL.md does not end in the exemplar and exactly one LF'
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-480: the copy loop wrote the release's SKILL.md and a later step appended the team's exemplar line, so an update that
# stopped between the two (a later file held, or the SKILL.md itself unwritable by then) left a SKILL.md without the line,
# and the re-run had none to carry.
It 'B-480 an update stopped after it replaced a SKILL.md keeps the team''s exemplar line through the re-run' {
    $exemplar = 'For a concrete current instance in this repo, see `warehouse/LoadSales.sql`.'
    foreach ($leg in 'later-file-held', 'skill-held-after-copy') {
        $t = Join-Path ([IO.Path]::GetTempPath()) ("b480-$leg-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Force -Path $t | Out-Null
        $handle = $null; $watcher = $null; $state = [hashtable]::Synchronized(@{ Handle = $null })
        try {
            $first = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "${leg}: calibration: the install failed (exit $LASTEXITCODE): $first"
            $skill = Join-Path $t '.claude/skills/add-warehouse-load/SKILL.md'
            # An older body, so the release's copy changes the file's length, which the watcher below reads without opening it.
            [IO.File]::WriteAllText($skill, "---`nname: add-warehouse-load`n---`n# Old framework body`n`n$exemplar`n", [Text.UTF8Encoding]::new($false))
            if ($leg -eq 'later-file-held') {
                # scripts/ follows .claude/skills/ in the manifest, so the copy loop has replaced SKILL.md when it stops here.
                $handle = [IO.File]::Open((Join-Path $t 'scripts/template-checks.ps1'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
            } else {
                # The attack: SKILL.md becomes unwritable once the copy has written it, so only a later write to it can fail.
                $watcher = [PowerShell]::Create()
                [void]$watcher.AddScript({
                        param($Path, $OldLength, $State)
                        $clock = [Diagnostics.Stopwatch]::StartNew()
                        while ($clock.Elapsed.TotalSeconds -lt 300) {
                            $info = [IO.FileInfo]::new($Path)
                            if ($info.Exists -and $info.Length -ne $OldLength) {
                                try { $State.Handle = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read); return } catch { }
                            }
                            [Threading.Thread]::Sleep(1)
                        }
                    }).AddArgument($skill).AddArgument(([IO.FileInfo]::new($skill)).Length).AddArgument($state)
                $async = $watcher.BeginInvoke()
            }
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $exit = $LASTEXITCODE
            if ($leg -eq 'later-file-held') {
                Assert ($exit -eq 3 -and ($out -replace '\s+', ' ') -match "Could not copy 'scripts/template-checks\.ps1'") "${leg}: calibration: the update did not stop at the held file (exit $exit): $out"
                $handle.Dispose(); $handle = $null
            } else {
                Assert ($null -ne $state.Handle) "${leg}: calibration: the watcher never held SKILL.md after the copy wrote it: $out"
                Assert ($exit -eq 0 -or ($exit -eq 3 -and ($out -replace '\s+', ' ') -match "Could not copy '\.claude/skills/add-warehouse-load/SKILL\.md'")) "${leg}: the update neither finished nor stopped naming SKILL.md (exit $exit): $out"
                $state.Handle.Dispose(); $state.Handle = $null
            }
            if ($exit -ne 0) {
                $rerun = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
                Assert ($LASTEXITCODE -eq 0) "${leg}: the printed re-run did not finish the update (exit $LASTEXITCODE): $rerun"
            }
            $text = [IO.File]::ReadAllText($skill, [Text.UTF8Encoding]::new($false))
            Assert ($text -notmatch 'Old framework body') "${leg}: SKILL.md does not hold the release's body: $text"
            Assert ($text.EndsWith("`n`n$exemplar`n", [StringComparison]::Ordinal)) "${leg}: the team's exemplar line was lost (it survives only in .claude/framework-update-backup/): $text"
        } finally {
            if ($handle) { $handle.Dispose() }
            if ($watcher) { $watcher.Stop(); $watcher.Dispose() }
            if ($state.Handle) { $state.Handle.Dispose() }
            Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# B-464 C5: the version stamp is the 34th of 101 copies, so a file held open later in the manifest stopped the update
# with a raw Copy-Item error after the stamp already named the new release, and the re-run was refused as a dirty tree.
It 'C5 an update stopped by a held file keeps the old version stamp and prints the re-run command' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-c5-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    $handle = $null
    try {
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "calibration: the install failed (exit $LASTEXITCODE): $first"
        $stamp = Join-Path $t '.claude/framework-version.json'
        $newVersion = [string](Get-Content -Raw -LiteralPath $stamp | ConvertFrom-Json).version
        [IO.File]::WriteAllText($stamp, ([IO.File]::ReadAllText($stamp) -replace '"version":\s*"[^"]*"', "`"version`": `"$staleVersion`""), [Text.UTF8Encoding]::new($false))
        $held = Join-Path $t 'scripts/template-checks.ps1'
        $handle = [IO.File]::Open($held, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        $flat = $out -replace '\s+', ' '
        Assert ($exit -eq 3) "the update stopped by a held file did not exit 3 (exit $exit): $out"
        Assert ([string](Get-Content -Raw -LiteralPath $stamp | ConvertFrom-Json).version -ceq $staleVersion) "the stopped update already wrote the new version stamp: $out"
        Assert ($flat -match "Could not copy 'scripts/template-checks\.ps1'" -and $flat -match '[0-9]+ of [0-9]+ framework files' -and $flat -match 'install\.ps1[^ ]* -AllowDirtyTree ') "the stop did not name the file, the count written and the re-run command with -AllowDirtyTree: $out"
        $handle.Dispose(); $handle = $null
        $rerun = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the re-run did not finish the update (exit $LASTEXITCODE): $rerun"
        Assert ([string](Get-Content -Raw -LiteralPath $stamp | ConvertFrom-Json).version -ceq $newVersion) "the re-run did not write the new version stamp: $rerun"
    } finally {
        if ($handle) { $handle.Dispose() }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-464 C7: a mistyped -Stack on an update switched the install to the other stack's release and left the old stack's
# skills live and unowned. The root dispatcher forwarded the override; the stack installer never compared the two stamps.
function Get-TreeSnapshot {
    param([string]$Root)
    return (@(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Sort-Object FullName | ForEach-Object { $_.FullName.Substring($Root.Length) + ':' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash }) -join "`n")
}
function Invoke-RootInstallerFor {
    param([string]$Target, [string[]]$Extra = @())
    $out = & (Get-PsExe) -NoProfile -File (Join-Path $repoRoot 'install.ps1') @Extra $Target 2>&1 | Out-String
    return [pscustomobject]@{ Exit = [int]$LASTEXITCODE; Output = $out }
}
It 'C7 an update with another -Stack is refused and changes nothing' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-c7a-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    try {
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "calibration: the dotnet install failed (exit $LASTEXITCODE): $first"
        $before = Get-TreeSnapshot -Root $t
        $result = Invoke-RootInstallerFor -Target $t -Extra @('-Stack', 'angular')
        $flat = $result.Output -replace '\s+', ' '
        Assert ($result.Exit -ne 0) "an update naming another stack was not refused (exit $($result.Exit)): $($result.Output)"
        Assert ((Get-TreeSnapshot -Root $t) -ceq $before) "the refused stack change still changed the target: $($result.Output)"
        Assert ([string](Get-Content -Raw -LiteralPath (Join-Path $t '.claude/framework-version.json') | ConvertFrom-Json).template -ceq 'dotnet') 'the stamp no longer names dotnet'
        Assert ($flat -match 'dotnet to angular' -and $flat -match '-AllowStackChange') "the refusal does not name both stacks and -AllowStackChange: $($result.Output)"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}
It 'C7 -AllowStackChange applies the other stack and names each previously owned path it drops, keeping those files' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-c7b-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    try {
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "calibration: the dotnet install failed (exit $LASTEXITCODE): $first"
        $perf = Join-Path $t '.claude/skills/perf/SKILL.md'
        Assert (Test-Path -LiteralPath $perf -PathType Leaf) 'calibration: the dotnet install has no perf skill'
        $result = Invoke-RootInstallerFor -Target $t -Extra @('-Stack', 'angular', '-AllowStackChange')
        $flat = $result.Output -replace '\s+', ' '
        Assert ($result.Exit -eq 0) "the deliberate stack change failed (exit $($result.Exit)): $($result.Output)"
        Assert ([string](Get-Content -Raw -LiteralPath (Join-Path $t '.claude/framework-version.json') | ConvertFrom-Json).template -ceq 'angular') 'the stamp does not name angular'
        Assert ($flat -match 'NOTICE: [^|]*dotnet to angular[^|]*\.claude/skills/perf/SKILL\.md') "no NOTICE names the dropped perf skill: $($result.Output)"
        Assert (Test-Path -LiteralPath $perf -PathType Leaf) 'the stack change deleted a dropped file'
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-464 C8: -WhatIf skipped the Git preflight, so a dry run on a tree the real run refuses ended "Dry run complete".
It 'C8 a dry run on a dirty Git tree names the refusal the real run makes and does not exit 0' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('upd-c8-' + [guid]::NewGuid())
    try {
        $t = New-B309GitTarget -Root $root -Name 'repo' -Ignore "bin/`n"
        [IO.File]::WriteAllText((Join-Path $t 'App.csproj'), '<Project Sdk="Microsoft.NET.Sdk" />', [Text.UTF8Encoding]::new($false))
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "calibration: the install failed (exit $LASTEXITCODE): $first"
        & git -C $t add -A -f 2>&1 | Out-Null
        & git -C $t commit -qm install 2>&1 | Out-Null
        $installer = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
        $clean = & (Get-PsExe) -NoProfile -File $installer -Target $t -WhatIf 2>&1 | Out-String
        Assert ($LASTEXITCODE -eq 0 -and $clean -match 'Dry run complete') "calibration: a dry run on a clean tree did not complete (exit $LASTEXITCODE): $clean"
        [IO.File]::AppendAllText((Join-Path $t 'App.csproj'), "<!-- edited -->`n")
        $dry = & (Get-PsExe) -NoProfile -File $installer -Target $t -WhatIf 2>&1 | Out-String
        $dryExit = $LASTEXITCODE
        $real = & (Get-PsExe) -NoProfile -File $installer -Target $t 2>&1 | Out-String
        $realExit = $LASTEXITCODE
        Assert ($realExit -eq 4 -and $real -match 'Refusing to mutate a dirty Git target') "calibration: the real run did not refuse the dirty tree (exit $realExit): $real"
        Assert ($dryExit -eq 4 -and ($dry -replace '\s+', ' ') -match 'dry run: the real run would refuse: ERROR: Refusing to mutate a dirty Git target') "the dry run did not exit 4 naming the refusal (exit $dryExit): $dry"
        Assert ($dry -notmatch 'Dry run complete') "the dry run still ends as complete: $dry"
        $allowed = & (Get-PsExe) -NoProfile -File $installer -Target $t -WhatIf -AllowDirtyTree 2>&1 | Out-String
        Assert ($LASTEXITCODE -eq 0 -and $allowed -match 'Dry run complete') "a dry run with -AllowDirtyTree did not complete (exit $LASTEXITCODE): $allowed"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-464 D1: a greenfield install stopped late must leave the version stamp where the manifest puts it. Without it the
# re-run read the files already copied as existing AI tooling and archived 93 of the framework's own files as a brownfield install.
It 'D1 a greenfield install stopped by a denied late folder is an update on the re-run, with nothing archived' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-d1-' + [guid]::NewGuid())
    $specs = Join-Path $t 'specs'
    New-Item -ItemType Directory -Force -Path $specs | Out-Null
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $denied = $false
    try {
        & icacls $specs /deny "*${sid}:(WD,AD)" | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: icacls could not deny writes in specs'
        $denied = $true
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 3 -and $out -match 'mode: greenfield') "calibration: the install was not stopped by the denied folder (exit $exit): $out"
        & icacls $specs /remove:d "*$sid" | Out-Null
        $denied = $false
        $rerun = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $rerun -match '(?m)^\s*mode: update') "the re-run did not finish as an update (exit $LASTEXITCODE): $rerun"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t 'docs/pre-adoption'))) 'the re-run archived framework files into docs/pre-adoption'
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/adoption-pending.json'))) 'the re-run wrote an adoption marker'
    } finally {
        if ($denied) { & icacls $specs /remove:d "*$sid" | Out-Null }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-464 D2: the re-run line printed for a stopped update must carry each override the stopped run was given, or it exits 4.
It 'D2 the re-run line of an update stopped by a held file carries the override flags it was given' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-d2-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force -Path $t | Out-Null
    $handle = $null
    try {
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "calibration: the install failed (exit $LASTEXITCODE): $first"
        $stamp = Join-Path $t '.claude/framework-version.json'
        $text = [IO.File]::ReadAllText($stamp) -replace '"version":\s*"[^"]*"', '"version": "99.0.0"' -replace '"template":\s*"[^"]*"', '"template": "angular"'
        [IO.File]::WriteAllText($stamp, $text, [Text.UTF8Encoding]::new($false))
        $handle = [IO.File]::Open((Join-Path $t 'scripts/template-checks.ps1'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
        $out = & (Get-PsExe) -NoProfile -File (Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1') -Target $t -AllowDowngrade -AllowStackChange -AllowOutdated 2>&1 | Out-String
        $exit = $LASTEXITCODE
        $flat = $out -replace '\s+', ' '
        Assert ($exit -eq 3) "calibration: the stopped update did not exit 3 (exit $exit): $out"
        foreach ($flag in '-AllowDirtyTree', '-AllowDowngrade', '-AllowStackChange', '-AllowOutdated') {
            Assert ($flat -match "install\.ps1' [^']*$flag") "the printed re-run line does not carry $flag : $out"
        }
    } finally {
        if ($handle) { $handle.Dispose() }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-464 D3: a greenfield install stopped before its version stamp was told to delete "the files this run copied", which it
# did not name, and to do that by folder would delete a team's own file beside the framework's. Its re-run is a clean greenfield.
It 'D3 a greenfield install stopped before the version stamp is told to re-run the installer, and that re-run is a greenfield that archives nothing' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-d3-' + [guid]::NewGuid())
    $commands = Join-Path $t '.claude/commands'
    $ours = Join-Path $t '.claude/agents/ours.md'
    New-Item -ItemType Directory -Force -Path $commands, (Split-Path -Parent $ours) | Out-Null
    [IO.File]::WriteAllText($ours, "# a team agent`n", [Text.UTF8Encoding]::new($false))
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $denied = $false
    try {
        & icacls $commands /deny "*${sid}:(WD,AD)" | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: icacls could not deny writes in .claude/commands'
        $denied = $true
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        $flat = $out -replace '\s+', ' '
        Assert ($exit -eq 3 -and $out -match 'mode: greenfield') "calibration: the install was not stopped by the denied folder (exit $exit): $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/framework-version.json'))) "calibration: the stop came after the version stamp: $out"
        Assert ($flat -match 'framework files were written\. Resolve the cause \(usually a program holding the file open\), then re-run the installer\.') "the stop before the stamp did not say to re-run the installer: $out"
        Assert ($flat -notmatch 'delete the files|archive them') "the stop before the stamp still tells the developer to delete files: $out"
        & icacls $commands /remove:d "*$sid" | Out-Null
        $denied = $false
        $rerun = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $rerun -match '(?m)^\s*mode: greenfield' -and $rerun -match 'must type:\s+/bootstrap') "the plain re-run was not a greenfield install with the /bootstrap hand-off (exit $LASTEXITCODE): $rerun"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t 'docs/pre-adoption')) -and -not (Test-Path -LiteralPath (Join-Path $t '.claude/adoption-pending.json'))) 'the re-run archived files or wrote an adoption marker'
        Assert ((Test-Path -LiteralPath (Join-Path $t '.claude/framework-version.json')) -and [IO.File]::ReadAllText($ours) -ceq "# a team agent`n") 'the re-run did not finish, or changed the team agent beside the framework files'
    } finally {
        if ($denied) { & icacls $commands /remove:d "*$sid" | Out-Null }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-464 D3's premise, pinned: the plain advice holds only while no framework file written before the stamp is an adoption signal
# (a re-run would then archive it). The installer's own signal list is read, a path counts when it is one or sits under one, and
# the instrument is shown to flag a manifest in which the stamp comes late.
function Get-SignalsBeforeStamp {
    param([string[]]$Paths, [string[]]$Signals, [string]$Stamp)
    $stampAt = [Array]::IndexOf($Paths, $Stamp)
    if ($stampAt -lt 0) { return @('(no stamp entry)') }
    $early = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $stampAt; $i++) {
        foreach ($signal in $Signals) {
            if ($Paths[$i] -ieq $signal -or $Paths[$i].StartsWith($signal + '/', [StringComparison]::OrdinalIgnoreCase)) { $early.Add($Paths[$i]); break }
        }
    }
    return @($early)
}
It 'D4 every manifest puts the version stamp before every adoption signal, so a greenfield stopped before it re-runs as a greenfield' {
    $stampPath = '.claude/framework-version.json'
    foreach ($dist in 'dotnet', 'angular', 'monorepo') {
        $list = [regex]::Match([IO.File]::ReadAllText((Join-Path $repoRoot "dist/$dist/scripts/install.ps1")), '(?s)\$adoptionSignals\s*=\s*@\((.*?)\)')
        Assert $list.Success "calibration: dist/$dist/scripts/install.ps1 has no `$adoptionSignals list to read"
        $signals = @([regex]::Matches($list.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
        Assert ($signals.Count -ge 15 -and $signals -contains 'CLAUDE.md' -and $signals -contains '.github/instructions') "calibration: dist/$dist's signal list read as $($signals -join ', ')"
        $paths = @((Get-Content -Raw -LiteralPath (Join-Path $repoRoot "dist/$dist/framework-ownership.json") | ConvertFrom-Json).paths | ForEach-Object { [string]$_.path })
        Assert ($paths -contains $stampPath) "calibration: dist/$dist's manifest has no $stampPath entry"
        $late = @(Get-SignalsBeforeStamp -Paths $paths -Signals $signals -Stamp $stampPath)
        Assert ($late.Count -eq 0) "dist/$dist's manifest copies $($late -join ', ') before $stampPath, so a greenfield stopped before the stamp would re-run as a brownfield install and archive it; the plain re-run advice in Stop-IncompleteCopy is then wrong"
        if ($dist -eq 'dotnet') {
            $reordered = @('.claude/commands/adopt.md', 'agents.md', '.github/instructions/framework-rules.instructions.md', $stampPath, 'CLAUDE.md')
            Assert ((@(Get-SignalsBeforeStamp -Paths $reordered -Signals $signals -Stamp $stampPath) -join ',') -ceq 'agents.md,.github/instructions/framework-rules.instructions.md') 'the check did not flag a manifest that copies AGENTS.md and a file under .github/instructions before the stamp'
        }
    }
}

# B-464 D5: a greenfield install runs no Git preflight, so its stopped-after-the-stamp line must not add -AllowDirtyTree the developer never
# passed, nor call every change Git shows this run's own: a team's uncommitted edit may be among them. Its re-run is an update and does refuse a dirty tree.
It 'D5 a greenfield install stopped after its stamp in a Git repository with a team edit prints a re-run line without -AllowDirtyTree and without the claim that the changes are its own' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-d5-' + [guid]::NewGuid())
    $specs = Join-Path $t 'specs'
    New-Item -ItemType Directory -Force -Path $specs | Out-Null
    & git -C $t init -q
    & git -C $t config user.email 'tests@example.invalid'
    & git -C $t config user.name 'installer tests'
    [IO.File]::WriteAllText((Join-Path $t 'Smoke.csproj'), '<Project />', [Text.UTF8Encoding]::new($false))
    & git -C $t add Smoke.csproj
    & git -C $t commit -qm base
    [IO.File]::AppendAllText((Join-Path $t 'Smoke.csproj'), "<!-- team edit -->`n")
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $denied = $false
    try {
        & icacls $specs /deny "*${sid}:(WD,AD)" | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: icacls could not deny writes in specs'
        $denied = $true
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        $flat = $out -replace '\s+', ' '
        Assert ($exit -eq 3 -and $out -match 'mode: greenfield') "calibration: the install was not stopped by the denied folder (exit $exit): $out"
        Assert (Test-Path -LiteralPath (Join-Path $t '.claude/framework-version.json')) "calibration: the stop came before the version stamp: $out"
        Assert ($flat -match "then re-run pwsh -NoProfile -File '[^']*install\.ps1' '[^']*'|then re-run powershell\.exe -NoProfile -ExecutionPolicy Bypass -File '[^']*install\.ps1' '[^']*'") "the printed re-run line is not the installer and the target alone: $out"
        Assert ($flat -notmatch "this run's own") "the stop still calls every change Git shows this run's own: $out"
        Assert ($flat -match 'did not check your Git tree' -and $flat -match 'review git status first' -and $flat -match 'add -AllowDirtyTree only after that review') "the stop does not tell the developer to review git status before adding -AllowDirtyTree: $out"
        & icacls $specs /remove:d "*$sid" | Out-Null
        $denied = $false
        $refused = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 4 -and $refused -match 'Refusing to mutate a dirty Git target') "calibration: the printed line's re-run was not refused as a dirty tree (exit $LASTEXITCODE): $refused"
        $rerun = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0 -and $rerun -match '(?m)^\s*mode: update') "the re-run with -AllowDirtyTree did not finish as an update (exit $LASTEXITCODE): $rerun"
        Assert ([IO.File]::ReadAllText((Join-Path $t 'Smoke.csproj')) -match 'team edit') 'the re-run changed the team edit'
        Assert (@(& git -C $t status --short | Where-Object { $_ -match '^ M Smoke\.csproj' }).Count -eq 1) 'Git no longer shows the team edit as modified'
    } finally {
        if ($denied) { & icacls $specs /remove:d "*$sid" | Out-Null }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-464 D6: the re-run of a greenfield stopped after its stamp is an update, so it ends "Done (update)" and points at docs-sync-check,
# which fails by design until /bootstrap has run; the stop line is where the developer or the agent learns that the next step is still /bootstrap.
It 'D6 a greenfield install stopped after its stamp says its re-run reports an update while the next step is still /bootstrap' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-d6-' + [guid]::NewGuid())
    $specs = Join-Path $t 'specs'
    New-Item -ItemType Directory -Force -Path $specs | Out-Null
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $denied = $false
    try {
        & icacls $specs /deny "*${sid}:(WD,AD)" | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: icacls could not deny writes in specs'
        $denied = $true
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        $flat = $out -replace '\s+', ' '
        Assert ($exit -eq 3 -and $out -match 'mode: greenfield') "calibration: the install was not stopped by the denied folder (exit $exit): $out"
        Assert (Test-Path -LiteralPath (Join-Path $t '.claude/framework-version.json')) "calibration: the stop came before the version stamp: $out"
        Assert ($flat -match 'reports itself as an update' -and $flat -match 'next step is still /bootstrap' -and $flat -match 'docs-sync-check fails until it has run') "the stop does not say the re-run reports an update while /bootstrap is still the next step: $out"
        & icacls $specs /remove:d "*$sid" | Out-Null
        $denied = $false
        $rerun = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $rerun -match '(?m)^\s*mode: update' -and $rerun -match 'Done \(update\)') "calibration: the re-run did not report itself as an update (exit $LASTEXITCODE): $rerun"
    } finally {
        if ($denied) { & icacls $specs /remove:d "*$sid" | Out-Null }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-471 (b): a greenfield stopped before its stamp was told to "re-run the installer" without the -AllowOutdated it was given,
# so following the line on an outdated checkout exits 4.
It 'B-471 a greenfield install stopped before the version stamp names the override it was given in its re-run advice' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('upd-b471g-' + [guid]::NewGuid())
    $commands = Join-Path $t '.claude/commands'
    New-Item -ItemType Directory -Force -Path $commands | Out-Null
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $denied = $false
    try {
        & icacls $commands /deny "*${sid}:(WD,AD)" | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: icacls could not deny writes in .claude/commands'
        $denied = $true
        $out = & (Get-PsExe) -NoProfile -File (Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1') -Target $t -AllowOutdated 2>&1 | Out-String
        $exit = $LASTEXITCODE
        $flat = $out -replace '\s+', ' '
        Assert ($exit -eq 3 -and $out -match 'mode: greenfield') "calibration: the install was not stopped by the denied folder (exit $exit): $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/framework-version.json'))) "calibration: the stop came after the version stamp: $out"
        Assert ($flat -match 're-run the installer with -AllowOutdated\.') "the stop before the stamp does not say to re-run with -AllowOutdated: $out"
    } finally {
        if ($denied) { & icacls $commands /remove:d "*$sid" | Out-Null }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'UpdateDelivery2.Tests')
