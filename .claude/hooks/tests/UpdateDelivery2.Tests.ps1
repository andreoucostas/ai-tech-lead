# The second half of the update-delivery cases; UpdateDelivery.Tests.ps1 holds the first. Split so CI runs the two
# halves in parallel (B-510); both dot-source _UpdateDelivery.ps1 for their fixtures and helpers. Does NOT ship.
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
# -Reinstall: delete the old framework surface of an install older than the retirement-ledger floor and install fresh.
# The fixture is a real v0.26.0 install (built from the local tag), committed to Git, plus consumer-owned files.
function New-ReinstallFixture {
    $target = Join-Path ([IO.Path]::GetTempPath()) ('reinst-' + [guid]::NewGuid().ToString('N'))
    $stage = Join-Path ([IO.Path]::GetTempPath()) ('reinst-stage-' + [guid]::NewGuid().ToString('N'))
    $archive = Join-Path ([IO.Path]::GetTempPath()) ('reinst-' + [guid]::NewGuid().ToString('N') + '.tar')
    New-Item -ItemType Directory -Force -Path $target, $stage | Out-Null
    try {
        & git -C $repoRoot archive --format=tar "--output=$archive" v0.26.0 dist/dotnet 2>&1 | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: could not archive v0.26.0 dist/dotnet'
        # Prefer the Windows tar: a GNU tar earlier on PATH reads 'C:' as a remote host.
        $tarExe = Join-Path $env:SystemRoot 'System32/tar.exe'
        if (-not (Test-Path -LiteralPath $tarExe)) { $tarExe = 'tar' }
        & $tarExe -xf $archive -C $stage 2>&1 | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: could not extract the v0.26.0 archive'
        $src = (Join-Path $stage 'dist/dotnet')
        $skip = @('.template-repo', 'README.md', 'CHANGELOG.md', '.gitignore', '.gitattributes', 'scripts/install.ps1', '.github/workflows/template-ci.yml')
        $oldHooks = [System.Collections.Generic.List[string]]::new()
        foreach ($f in Get-ChildItem -LiteralPath $src -Recurse -Force -File) {
            $rel = $f.FullName.Substring($src.Length).TrimStart('\', '/').Replace('\', '/')
            if ($skip -contains $rel) { continue }
            if ($rel.StartsWith('.claude/hooks/')) { $oldHooks.Add($rel) }
            $dest = Join-Path $target $rel
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
        }
        $enc = [Text.UTF8Encoding]::new($false)
        [IO.File]::WriteAllText((Join-Path $target '.claude/hooks/team-hook.ps1'), "# consumer-added hook`n", $enc)
        New-Item -ItemType Directory -Force -Path (Join-Path $target 'scripts') | Out-Null
        [IO.File]::WriteAllBytes((Join-Path $target 'scripts/consumer-tool.ps1'), [byte[]](0x23, 0x20, 0x63, 0x6F, 0x6E, 0x73, 0x75, 0x6D, 0x65, 0x72, 0x00, 0xFE, 0x0D, 0x0A, 0x7F, 0x31, 0x0A))
        [IO.File]::AppendAllText((Join-Path $target 'CLAUDE.md'), "`nCONSUMER SENTINEL 7f3a`n", $enc)
        [IO.File]::WriteAllText((Join-Path $target '.gitignore'), "/.claude/settings.local.json`n", $enc)
        [IO.File]::WriteAllBytes((Join-Path $target '.claude/settings.local.json'), [byte[]](0x7B, 0x22, 0x6C, 0x6F, 0x63, 0x61, 0x6C, 0x22, 0x3A, 0x31, 0x39, 0x37, 0x31, 0x7D, 0x0A))
        & git -C $target init -q 2>&1 | Out-Null
        & git -C $target config user.email 'fixture@example.test'
        & git -C $target config user.name 'Fixture'
        & git -C $target config core.autocrlf false
        & git -C $target add -A 2>&1 | Out-Null
        & git -C $target commit -qm fixture 2>&1 | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: could not commit the reinstall fixture'
        $head = (& git -C $target rev-parse HEAD).Trim()
        return [pscustomobject]@{ Path = $target; Head = $head; OldHooks = $oldHooks.ToArray() }
    } finally {
        Remove-Item -Recurse -Force -LiteralPath $stage -ErrorAction SilentlyContinue
        Remove-Item -Force -LiteralPath $archive -ErrorAction SilentlyContinue
    }
}

# "<relative path>`t<sha256>" for every file outside .git, then HEAD, then the porcelain status.
function Get-ReinstallFingerprint {
    param([string]$Target)
    $lines = foreach ($f in Get-ChildItem -LiteralPath $Target -Recurse -Force -File -ErrorAction SilentlyContinue) {
        $rel = $f.FullName.Substring($Target.Length).TrimStart('\', '/').Replace('\', '/')
        if ($rel -eq '.git' -or $rel.StartsWith('.git/')) { continue }
        "$rel`t$((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash)"
    }
    $head = (& git -C $Target rev-parse HEAD 2>&1 | Out-String).Trim()
    $status = (& git -C $Target status --porcelain --untracked-files=all 2>&1 | Out-String)
    $sorted = [string[]]@($lines)
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    return (($sorted -join "`n") + "`nHEAD $head`n" + $status)
}

# Runs the built dotnet installer with exactly these switches; returns exit code and combined output.
function Invoke-ReinstallInstaller {
    # -Utf8Output: the console's code page turns a U+2019 in a printed path into ' on the way back, so read it as UTF-8.
    param([string]$Target, [string[]]$Switches = @(), [switch]$Utf8Output)
    $installer = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
    $previous = [Console]::OutputEncoding
    $changed = $false
    if ($Utf8Output) { try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false); $changed = $true } catch { } }
    try { $out = & (Get-PsExe) -NoProfile -File $installer -Target $Target @Switches 2>&1 | Out-String; $exit = $LASTEXITCODE }
    finally { if ($changed) { try { [Console]::OutputEncoding = $previous } catch { } } }
    return [pscustomobject]@{ Exit = $exit; Out = $out }
}

function Remove-ReinstallTemp {
    param([string[]]$Paths)
    foreach ($p in $Paths) {
        if (-not $p -or -not (Test-Path -LiteralPath $p)) { continue }
        # Junctions are detached without recursing through them.
        foreach ($d in Get-ChildItem -LiteralPath $p -Recurse -Force -Directory -ErrorAction SilentlyContinue) {
            if ($d.Attributes -band [IO.FileAttributes]::ReparsePoint) { try { [IO.Directory]::Delete($d.FullName, $false) } catch { } }
        }
        Remove-Item -Recurse -Force -LiteralPath $p -ErrorAction SilentlyContinue
    }
}

if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) {
    Skip 'reinstall: -Reinstall behaviour' 'git is unavailable'
} else {
    It 'reinstall: a plain update from below the retirement-ledger floor refuses before mutation and names -Reinstall' {
        $fx = New-ReinstallFixture
        try {
            $before = Get-ReinstallFingerprint $fx.Path
            $r = Invoke-ReinstallInstaller -Target $fx.Path
            Assert ($r.Exit -eq 4) "expected exit 4 from a plain update below the ledger floor, got $($r.Exit): $($r.Out)"
            Assert ($r.Out -match '-Reinstall') "the refusal does not name -Reinstall: $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $fx.Path)) "the refused update changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: -Reinstall deletes the old framework surface and keeps consumer files' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            $toolBefore = [IO.File]::ReadAllBytes((Join-Path $t 'scripts/consumer-tool.ps1'))
            $localBefore = [IO.File]::ReadAllBytes((Join-Path $t '.claude/settings.local.json'))
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            $o = $r.Out
            Assert ($r.Exit -eq 0) "expected exit 0 from -Reinstall, got $($r.Exit): $o"
            Assert-BytesEqual $toolBefore ([IO.File]::ReadAllBytes((Join-Path $t 'scripts/consumer-tool.ps1'))) "scripts/consumer-tool.ps1 bytes changed: $o"
            Assert-BytesEqual $localBefore ([IO.File]::ReadAllBytes((Join-Path $t '.claude/settings.local.json'))) ".claude/settings.local.json bytes changed: $o"
            $text = ''
            foreach ($n in 'docs/pre-adoption/AGENTS.md', 'docs/pre-adoption/CLAUDE.md') { $p = Join-Path $t $n; if (Test-Path -LiteralPath $p) { $text += [IO.File]::ReadAllText($p) } }
            Assert ($text -match 'CONSUMER SENTINEL 7f3a') "the project text did not survive into docs/pre-adoption/: $o"
            Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/hooks/team-hook.ps1'))) ".claude/hooks/team-hook.ps1 was not deleted: $o"
            $owned = @((Get-Content -LiteralPath (Join-Path $repoRoot 'dist/dotnet/framework-ownership.json') -Raw | ConvertFrom-Json).paths | ForEach-Object { $_.path })
            foreach ($h in $fx.OldHooks) {
                if ($owned -contains $h) { continue }
                Assert (-not (Test-Path -LiteralPath (Join-Path $t $h))) "$h is a v0.26.0 hook this release does not ship, but it is still present: $o"
            }
            $stamp = Get-Content -LiteralPath (Join-Path $t '.claude/framework-version.json') -Raw | ConvertFrom-Json
            $want = (Get-Content -LiteralPath (Join-Path $repoRoot 'dist/dotnet/.claude/framework-version.json') -Raw | ConvertFrom-Json).version
            Assert ($stamp.version -eq $want) "stamp version is $($stamp.version), expected $want : $o"
            Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/framework-update-backup'))) "a .claude/framework-update-backup folder was written: $o"
            Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/.state/settings.json.pre-update'))) "a settings.json.pre-update backup was written: $o"
            foreach ($p in $owned) {
                Assert (Test-Path -LiteralPath (Join-Path $t $p)) "owned path $p is missing after the reinstall: $o"
            }
            Assert ($o.Contains("git show $($fx.Head):.claude/settings.json")) "the output does not give 'git show $($fx.Head):.claude/settings.json': $o"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: -Reinstall with -AllowDirtyTree refuses before mutation' {
        $fx = New-ReinstallFixture
        try {
            $before = Get-ReinstallFingerprint $fx.Path
            $r = Invoke-ReinstallInstaller -Target $fx.Path -Switches @('-Reinstall', '-AllowDirtyTree')
            Assert ($r.Exit -eq 4) "expected exit 4 from -Reinstall -AllowDirtyTree, got $($r.Exit): $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $fx.Path)) "the refused run changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: -Reinstall on a dirty tree refuses before mutation' {
        $fx = New-ReinstallFixture
        try {
            [IO.File]::AppendAllText((Join-Path $fx.Path 'scripts/consumer-tool.ps1'), "# uncommitted edit`n")
            $before = Get-ReinstallFingerprint $fx.Path
            $r = Invoke-ReinstallInstaller -Target $fx.Path -Switches @('-Reinstall')
            Assert ($r.Exit -eq 4) "expected exit 4 from -Reinstall on a dirty tree, got $($r.Exit): $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $fx.Path)) "the refused run changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: -WhatIf -Reinstall lists the deletions and changes nothing' {
        $fx = New-ReinstallFixture
        try {
            $before = Get-ReinstallFingerprint $fx.Path
            $r = Invoke-ReinstallInstaller -Target $fx.Path -Switches @('-WhatIf', '-Reinstall')
            Assert ($r.Exit -eq 0) "expected exit 0 from -WhatIf -Reinstall, got $($r.Exit): $($r.Out)"
            Assert ($r.Out -match 'PLAN delete \.claude/hooks/team-hook\.ps1') "the plan does not list 'PLAN delete .claude/hooks/team-hook.ps1': $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $fx.Path)) "-WhatIf changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: -Reinstall outside update mode refuses and creates nothing' {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('reinst-empty-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Force -Path $t | Out-Null
        try {
            [IO.File]::WriteAllText((Join-Path $t 'README.md'), "# readme`n", [Text.UTF8Encoding]::new($false))
            & git -C $t init -q 2>&1 | Out-Null
            & git -C $t config user.email 'fixture@example.test'
            & git -C $t config user.name 'Fixture'
            & git -C $t add -A 2>&1 | Out-Null
            & git -C $t commit -qm readme 2>&1 | Out-Null
            $before = Get-ReinstallFingerprint $t
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            Assert ($r.Exit -eq 4) "expected exit 4 from -Reinstall on a target with no install, got $($r.Exit): $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $t)) "the refused run created or changed files: $($r.Out)"
        } finally { Remove-ReinstallTemp @($t) }
    }

    It 'reinstall: a skip-worktree file in the sweep refuses before mutation' {
        $fx = New-ReinstallFixture
        try {
            & git -C $fx.Path update-index --skip-worktree -- .claude/settings.json 2>&1 | Out-Null
            Assert ($LASTEXITCODE -eq 0) 'calibration: could not set skip-worktree'
            [IO.File]::AppendAllText((Join-Path $fx.Path '.claude/settings.json'), "`n")
            $before = Get-ReinstallFingerprint $fx.Path
            $r = Invoke-ReinstallInstaller -Target $fx.Path -Switches @('-Reinstall')
            Assert ($r.Exit -eq 4) "expected exit 4 with a skip-worktree file in the sweep, got $($r.Exit): $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $fx.Path)) "the refused run changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    # B-471 (b): the refusal printed one update-index naming both --no- options, which clears only assume-unchanged.
    It 'B-471 reinstall: the skip-worktree refusal prints commands that, run as printed, clear the flag' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            & git -C $t update-index --skip-worktree -- .claude/settings.json 2>&1 | Out-Null
            Assert ($LASTEXITCODE -eq 0) 'calibration: could not set skip-worktree'
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            Assert ($r.Exit -eq 4) "calibration: expected exit 4 with a skip-worktree file in the sweep, got $($r.Exit): $($r.Out)"
            $flat = $r.Out -replace '\s+', ' '
            $commands = @([regex]::Matches($flat, "git (?:-C (?:'[^']*'|[^\s']+) )?update-index (?:--no-[a-z-]+ )+-- (?:'[^']*'|[^\s'),]+)") | ForEach-Object { $_.Value })
            Assert ($commands.Count -gt 0) "the refusal prints no update-index command: $($r.Out)"
            Push-Location -LiteralPath $t
            try { foreach ($command in $commands) { Invoke-Expression $command 2>&1 | Out-Null } } finally { Pop-Location }
            $tag = (@(& git -C $t ls-files -v -- .claude/settings.json) -join '')
            Assert ($tag -cmatch '^H ') "the printed commands ($($commands -join ' ; ')) left the flag set: ls-files -v reads '$tag'"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    # B-471 (b): the sweep's and the copy's stop lines said "re-run with -Reinstall" without the overrides the run was given,
    # so following them exits 4 (here -AllowStackChange, which a stamp naming another stack needs).
    It 'B-471 reinstall: a reinstall stopped in its sweep or in its copy names each override it was given in the re-run advice' {
        $fx = New-ReinstallFixture
        $t = $fx.Path
        $specs = Join-Path $t 'specs'
        $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $denied = $false
        $handle = $null
        try {
            $stamp = Join-Path $t '.claude/framework-version.json'
            [IO.File]::WriteAllText($stamp, ([IO.File]::ReadAllText($stamp) -replace '"template":\s*"[^"]*"', '"template": "angular"'), [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText((Join-Path $specs 'team-spec.md'), "# a team spec`n", [Text.UTF8Encoding]::new($false))
            & git -C $t add -A 2>&1 | Out-Null
            & git -C $t commit -qm 'angular stamp, team spec' 2>&1 | Out-Null
            Assert ($LASTEXITCODE -eq 0) 'calibration: could not commit the fixture change'
            $switches = @('-Reinstall', '-AllowStackChange', '-AllowOutdated')
            # Readable, so the reinstall's byte check passes; not deletable, so its sweep stops there.
            $handle = [IO.File]::Open((Join-Path $t 'scripts/template-checks.ps1'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
            $r = Invoke-ReinstallInstaller -Target $t -Switches $switches
            $flat = $r.Out -replace '\s+', ' '
            Assert ($r.Exit -eq 3 -and $flat -match "Could not delete 'scripts/template-checks\.ps1'") "calibration: the reinstall was not stopped in its sweep by the held file (exit $($r.Exit)): $($r.Out)"
            Assert ($flat -match 're-run with -Reinstall -AllowOutdated -AllowStackChange\.') "the sweep's stop line does not carry the overrides: $($r.Out)"
            $handle.Dispose(); $handle = $null
            & git -C $t checkout -q HEAD -- . 2>&1 | Out-Null
            Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim().Length -eq 0) 'calibration: the restored tree is not clean'
            & icacls $specs /deny "*${sid}:(WD,AD)" | Out-Null
            Assert ($LASTEXITCODE -eq 0) 'calibration: icacls could not deny writes in specs'
            $denied = $true
            $r = Invoke-ReinstallInstaller -Target $t -Switches $switches
            $flat = $r.Out -replace '\s+', ' '
            Assert ($r.Exit -eq 3 -and $flat -match "Could not copy 'specs/") "calibration: the reinstall was not stopped in its copy by the denied folder (exit $($r.Exit)): $($r.Out)"
            Assert ($flat -match 're-run with -Reinstall -AllowOutdated -AllowStackChange\.') "the copy's stop line does not carry the overrides: $($r.Out)"
        } finally {
            if ($handle) { $handle.Dispose() }
            if ($denied) { & icacls $specs /remove:d "*$sid" | Out-Null }
            Remove-ReinstallTemp @($fx.Path)
        }
    }

    It 'reinstall: an ignored file at a shipped path refuses, since no commit holds what the copy would overwrite' {
        $fx = New-ReinstallFixture
        try {
            $rel = '.github/instructions/framework-rules.instructions.md'
            [IO.File]::AppendAllText((Join-Path $fx.Path '.gitignore'), "/$rel`n")
            & git -C $fx.Path add -A 2>&1 | Out-Null
            & git -C $fx.Path commit -qm ignore-rules 2>&1 | Out-Null
            New-Item -ItemType Directory -Force -Path (Join-Path $fx.Path '.github/instructions') | Out-Null
            [IO.File]::WriteAllText((Join-Path $fx.Path $rel), "# a developer's own rules, in no commit`n", [Text.UTF8Encoding]::new($false))
            Assert ((& git -C $fx.Path status --porcelain --untracked-files=all | Out-String).Trim().Length -eq 0) 'calibration: the ignored file shows in git status'
            $before = Get-ReinstallFingerprint $fx.Path
            $r = Invoke-ReinstallInstaller -Target $fx.Path -Switches @('-Reinstall')
            Assert ($r.Exit -eq 4) "expected exit 4 with an ignored file at a shipped path, got $($r.Exit): $($r.Out)"
            Assert ($r.Out.Contains($rel)) "the refusal does not name $rel : $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $fx.Path)) "the refused run changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    # Found by the fresh-session attack: a clean status was taken as proof that the commit holds a file's bytes.
    It 'reinstall: a file a clean filter keeps partly out of Git refuses, though git status is clean' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            & git -C $t config filter.strip.clean 'sed /LOCALONLY/d'
            & git -C $t config filter.strip.smudge 'cat'
            [IO.File]::WriteAllText((Join-Path $t '.gitattributes'), ".claude/rules/*.md filter=strip`n", [Text.UTF8Encoding]::new($false))
            New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/rules') | Out-Null
            [IO.File]::WriteAllText((Join-Path $t '.claude/rules/env.md'), "shared`n", [Text.UTF8Encoding]::new($false))
            & git -C $t add -A 2>&1 | Out-Null
            & git -C $t commit -qm filtered 2>&1 | Out-Null
            [IO.File]::AppendAllText((Join-Path $t '.claude/rules/env.md'), "LOCALONLY token=abc123`n")
            & git -C $t add -A 2>&1 | Out-Null
            Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim().Length -eq 0) 'calibration: the filtered edit shows in git status'
            $before = Get-ReinstallFingerprint $t
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            Assert ($r.Exit -eq 4) "expected exit 4 for a file whose disk bytes the commit does not hold, got $($r.Exit): $($r.Out)"
            Assert ($r.Out.Contains('.claude/rules/env.md')) "the refusal does not name .claude/rules/env.md: $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $t)) "the refused run changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: a same-size edit Git has not noticed refuses, though git status is clean' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            $note = Join-Path $t '.claude/rules/team-notes.md'
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $note) | Out-Null
            [IO.File]::WriteAllText($note, "budget: AAAAAAAA`n", [Text.UTF8Encoding]::new($false))
            $stamp = [DateTime]::UtcNow.AddMinutes(-10)
            [IO.File]::SetLastWriteTimeUtc($note, $stamp)
            & git -C $t add -A 2>&1 | Out-Null
            & git -C $t commit -qm notes 2>&1 | Out-Null
            & git -C $t update-index --really-refresh 2>&1 | Out-Null
            [IO.File]::WriteAllText($note, "budget: SECRET99`n", [Text.UTF8Encoding]::new($false))
            [IO.File]::SetLastWriteTimeUtc($note, $stamp)
            Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim().Length -eq 0) 'calibration: Git noticed the same-size edit'
            $before = Get-ReinstallFingerprint $t
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            Assert ($r.Exit -eq 4) "expected exit 4 for an edit Git has not noticed, got $($r.Exit): $($r.Out)"
            Assert ([IO.File]::ReadAllText($note) -ceq "budget: SECRET99`n") "the unnoticed edit was lost: $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $t)) "the refused run changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: a junction below .claude is neither followed nor emptied' {
        $fx = New-ReinstallFixture
        $outside = Join-Path ([IO.Path]::GetTempPath()) ('reinst-outside-' + [guid]::NewGuid().ToString('N'))
        $link = Join-Path $fx.Path '.claude/linked'
        try {
            New-Item -ItemType Directory -Force -Path $outside | Out-Null
            $payload = [byte[]](0x6F, 0x75, 0x74, 0x00, 0x01, 0x0A)
            [IO.File]::WriteAllBytes((Join-Path $outside 'outside.txt'), $payload)
            [IO.File]::AppendAllText((Join-Path $fx.Path '.gitignore'), "/.claude/linked`n")
            & git -C $fx.Path add -A 2>&1 | Out-Null
            & git -C $fx.Path commit -qm ignore-link 2>&1 | Out-Null
            New-Item -ItemType Junction -Path $link -Target $outside | Out-Null
            Assert (Test-Path -LiteralPath (Join-Path $link 'outside.txt')) 'calibration: the junction does not expose outside.txt'
            $r = Invoke-ReinstallInstaller -Target $fx.Path -Switches @('-Reinstall')
            Assert ($r.Exit -eq 0) "expected exit 0 from -Reinstall beside an ignored junction, got $($r.Exit): $($r.Out)"
            Assert (Test-Path -LiteralPath (Join-Path $outside 'outside.txt')) "outside.txt was deleted through the junction: $($r.Out)"
            Assert-BytesEqual $payload ([IO.File]::ReadAllBytes((Join-Path $outside 'outside.txt'))) "outside.txt bytes changed: $($r.Out)"
            Assert (Test-Path -LiteralPath $link) "the junction itself was removed: $($r.Out)"
        } finally {
            if (Test-Path -LiteralPath $link) { try { [IO.Directory]::Delete($link, $false) } catch { } }
            Remove-ReinstallTemp @($fx.Path, $outside)
        }
    }

    It 'reinstall: the old CLAUDE.md and AGENTS.md move to docs/pre-adoption/ byte for byte, this release''s replace them, and a marker that verifies hands them to /adopt' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            $old = @{ 'CLAUDE.md' = [IO.File]::ReadAllBytes((Join-Path $t 'CLAUDE.md')); 'AGENTS.md' = [IO.File]::ReadAllBytes((Join-Path $t 'AGENTS.md')) }
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            $o = $r.Out
            Assert ($r.Exit -eq 0) "expected exit 0 from -Reinstall, got $($r.Exit): $o"
            foreach ($name in 'CLAUDE.md', 'AGENTS.md') {
                $archive = Join-Path $t "docs/pre-adoption/$name"
                Assert (Test-Path -LiteralPath $archive -PathType Leaf) "docs/pre-adoption/$name is missing: $o"
                Assert-BytesEqual $old[$name] ([IO.File]::ReadAllBytes($archive)) "docs/pre-adoption/$name does not hold the old $name byte for byte: $o"
                Assert-BytesEqual ([IO.File]::ReadAllBytes((Join-Path $repoRoot "dist/dotnet/$name"))) ([IO.File]::ReadAllBytes((Join-Path $t $name))) "$name is not this release's: $o"
            }
            $marker = Join-Path $t '.claude/adoption-pending.json'
            Assert (Test-Path -LiteralPath $marker -PathType Leaf) ".claude/adoption-pending.json was not written: $o"
            $verify = & (Get-PsExe) -NoProfile -File (Join-Path $repoRoot 'dist/dotnet/scripts/adoption-archive.ps1') -Verify -RepoRoot $t -EvidencePath $marker 2>&1 | Out-String
            $verifyExit = $LASTEXITCODE
            Assert ($verifyExit -eq 0 -and $verify -match 'RESULT: PASS') "adoption-archive.ps1 -Verify did not pass on the marker (exit $verifyExit): $verify"
            $mapped = [string[]]@((Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json).archivedOriginals)
            [Array]::Sort($mapped, [StringComparer]::Ordinal)
            Assert (($mapped -join ',') -ceq 'docs/pre-adoption/AGENTS.md,docs/pre-adoption/CLAUDE.md') "archivedOriginals is '$($mapped -join ',')': $o"
            Assert ($o -match 'type:\s+/adopt') "the output does not hand off to /adopt: $o"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: an earlier adoption''s docs/pre-adoption/AGENTS.md refuses before mutation and names it' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            New-Item -ItemType Directory -Force -Path (Join-Path $t 'docs/pre-adoption') | Out-Null
            [IO.File]::WriteAllText((Join-Path $t 'docs/pre-adoption/AGENTS.md'), "# an earlier adoption's archive`n", [Text.UTF8Encoding]::new($false))
            & git -C $t add -A 2>&1 | Out-Null
            & git -C $t commit -qm earlier-archive 2>&1 | Out-Null
            Assert ($LASTEXITCODE -eq 0) 'calibration: could not commit the earlier archive'
            $before = Get-ReinstallFingerprint $t
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            Assert ($r.Exit -eq 3) "expected exit 3 from -Reinstall over an earlier archive, got $($r.Exit): $($r.Out)"
            Assert ($r.Out -match 'docs/pre-adoption/AGENTS\.md') "the refusal does not name docs/pre-adoption/AGENTS.md: $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $t)) "the refused reinstall changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: an earlier archive Git does not track is not said to be in the commit, since deleting it would lose it' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            New-Item -ItemType Directory -Force -Path (Join-Path $t 'docs/pre-adoption') | Out-Null
            [IO.File]::WriteAllText((Join-Path $t 'docs/pre-adoption/AGENTS.md'), "# an untracked earlier archive`n", [Text.UTF8Encoding]::new($false))
            $before = Get-ReinstallFingerprint $t
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            $flat = $r.Out -replace '\s+', ' '
            Assert ($r.Exit -eq 3 -and $flat -match "'docs/pre-adoption/AGENTS\.md', which already exists") "calibration: the reinstall was not refused by the untracked archive (exit $($r.Exit)): $($r.Out)"
            Assert ($flat -notmatch 'keeps it') "the refusal says a commit keeps an archive Git does not track: $($r.Out)"
            Assert ($flat -match 'move it out of the repository') "the refusal does not say to move the untracked archive out of the repository: $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $t)) "the refused reinstall changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: an earlier archive Git tracks with an uncommitted edit is not said to be in the commit, since deleting it would lose the edit' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            $earlier = Join-Path $t 'docs/pre-adoption/AGENTS.md'
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $earlier) | Out-Null
            [IO.File]::WriteAllText($earlier, "# an earlier adoption's archive`n", [Text.UTF8Encoding]::new($false))
            & git -C $t add -A 2>&1 | Out-Null
            & git -C $t commit -qm earlier-archive 2>&1 | Out-Null
            Assert ($LASTEXITCODE -eq 0) 'calibration: could not commit the earlier archive'
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            Assert ($r.Exit -eq 3 -and ($r.Out -replace '\s+', ' ') -match 'keeps it') "calibration: the committed archive, unedited, is not said to be kept by the commit (exit $($r.Exit)): $($r.Out)"
            [IO.File]::AppendAllText($earlier, "a note the team has not committed`n", [Text.UTF8Encoding]::new($false))
            $before = Get-ReinstallFingerprint $t
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            $flat = $r.Out -replace '\s+', ' '
            Assert ($r.Exit -eq 3 -and $flat -match "'docs/pre-adoption/AGENTS\.md', which already exists") "calibration: the reinstall was not refused by the edited archive (exit $($r.Exit)): $($r.Out)"
            Assert ($flat -notmatch 'keeps it') "the refusal says a commit keeps an archive whose edit no commit holds: $($r.Out)"
            Assert ($flat -match 'move it out of the repository') "the refusal does not say to move the edited archive out of the repository: $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $t)) "the refused reinstall changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    It 'reinstall: an earlier archive the installer cannot read is reported as not compared, not as held by no commit' {
        $fx = New-ReinstallFixture
        $handle = $null
        try {
            $t = $fx.Path
            $earlier = Join-Path $t 'docs/pre-adoption/AGENTS.md'
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $earlier) | Out-Null
            [IO.File]::WriteAllText($earlier, "# an earlier adoption's archive`n", [Text.UTF8Encoding]::new($false))
            & git -C $t add -A 2>&1 | Out-Null
            & git -C $t commit -qm earlier-archive 2>&1 | Out-Null
            Assert ($LASTEXITCODE -eq 0) 'calibration: could not commit the earlier archive'
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            Assert ($r.Exit -eq 3 -and ($r.Out -replace '\s+', ' ') -match 'keeps it') "calibration: the committed archive, readable, is not said to be kept by the commit (exit $($r.Exit)): $($r.Out)"
            $before = Get-ReinstallFingerprint $t
            # Commit HEAD holds these exact bytes; only the read fails.
            $handle = [IO.File]::Open($earlier, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            $handle.Dispose(); $handle = $null
            $flat = $r.Out -replace '\s+', ' '
            Assert ($flat -notmatch 'no commit holds it') "the refusal says no commit holds an archive it could not read: $($r.Out)"
            Assert ($r.Exit -eq 4 -and $flat -match "CANT-VERIFY: -Reinstall could not compare 'docs/pre-adoption/AGENTS\.md'") "expected exit 4 and a CANT-VERIFY naming the archive, got $($r.Exit): $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $t)) "the refused reinstall changed the tree: $($r.Out)"
        } finally {
            if ($handle) { $handle.Dispose() }
            Remove-ReinstallTemp @($fx.Path)
        }
    }

    It 'reinstall: an earlier archive staged but never committed is said to be held by no commit, not reported as not compared' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            $earlier = Join-Path $t 'docs/pre-adoption/AGENTS.md'
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $earlier) | Out-Null
            [IO.File]::WriteAllText($earlier, "# an earlier archive, staged, never committed`n", [Text.UTF8Encoding]::new($false))
            & git -C $t add -- docs/pre-adoption/AGENTS.md 2>&1 | Out-Null
            Assert ($LASTEXITCODE -eq 0) 'calibration: could not stage the earlier archive'
            $before = Get-ReinstallFingerprint $t
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            $flat = $r.Out -replace '\s+', ' '
            Assert ($flat -notmatch 'CANT-VERIFY') "a staged archive HEAD does not hold is reported as not compared: $($r.Out)"
            Assert ($r.Exit -eq 3 -and $flat -match "'docs/pre-adoption/AGENTS\.md', which already exists" -and $flat -match 'move it out of the repository') "expected exit 3 and the move-out remedy, got $($r.Exit): $($r.Out)"
            Assert ($before -ceq (Get-ReinstallFingerprint $t)) "the refused reinstall changed the tree: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    # B-481: PowerShell reads U+2019 as a single quote too, so a line that doubles only the ASCII one does not parse.
    It 'reinstall: an archive stop''s restore line, run as printed, restores a target whose path holds a $ and a typographic apostrophe' {
        $fx = New-ReinstallFixture
        $t = $fx.Path + [char]0x2019 + '$x'
        $handle = $null
        try {
            Move-Item -LiteralPath $fx.Path -Destination $t
            # Readable, so the commit-bytes check passes; not movable, so the archive stops at CLAUDE.md, after the sweep.
            $handle = [IO.File]::Open((Join-Path $t 'CLAUDE.md'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall') -Utf8Output
            $handle.Dispose(); $handle = $null
            $flat = $r.Out -replace '\s+', ' '
            Assert ($r.Exit -eq 3 -and $flat -match 'move failed for .CLAUDE\.md.') "calibration: the reinstall was not stopped by the held CLAUDE.md (exit $($r.Exit)): $($r.Out)"
            $line = [regex]::Match($flat, 'git -C (.+?) checkout [0-9a-f]{40} -- \.')
            Assert $line.Success "the stop prints no restore line: $($r.Out)"
            $pasted = & (Get-PsExe) -NoProfile -Command $line.Value 2>&1 | Out-String
            $tracked = (& git -C $t status --porcelain --untracked-files=no 2>&1 | Out-String).Trim()
            Assert ($tracked.Length -eq 0) "the restore line, run as printed ($($line.Value)), did not restore the tracked files: $pasted / $tracked"
        } finally {
            if ($handle) { $handle.Dispose() }
            Remove-ReinstallTemp @($fx.Path, $t)
        }
    }

    # B-481: the sweep's stop line double-quoted the target, so pasted into PowerShell the $x expanded and nothing was restored.
    It 'B-481 reinstall: a sweep stop''s restore line, run as printed, restores a target whose path holds a $ and a typographic apostrophe' {
        $fx = New-ReinstallFixture
        $t = $fx.Path + [char]0x2019 + '$x'
        $handle = $null
        try {
            Move-Item -LiteralPath $fx.Path -Destination $t
            # Readable, so the commit-bytes check passes; not deletable, so the sweep stops there.
            $handle = [IO.File]::Open((Join-Path $t 'scripts/template-checks.ps1'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall') -Utf8Output
            $handle.Dispose(); $handle = $null
            $flat = $r.Out -replace '\s+', ' '
            Assert ($r.Exit -eq 3 -and $flat -match "Could not delete 'scripts/template-checks\.ps1'") "calibration: the reinstall was not stopped in its sweep by the held file (exit $($r.Exit)): $($r.Out)"
            Assert ((& git -C $t status --porcelain --untracked-files=no 2>&1 | Out-String).Trim().Length -gt 0) "calibration: the sweep deleted nothing before the held file: $($r.Out)"
            $line = [regex]::Match($flat, 'git -C (.+?) checkout [0-9a-f]{40} -- \.')
            Assert $line.Success "the sweep's stop prints no restore line: $($r.Out)"
            $pasted = & (Get-PsExe) -NoProfile -Command $line.Value 2>&1 | Out-String
            $tracked = (& git -C $t status --porcelain --untracked-files=no 2>&1 | Out-String).Trim()
            Assert ($tracked.Length -eq 0) "the sweep's restore line, run as printed ($($line.Value)), did not restore the tracked files: $pasted / $tracked"
        } finally {
            if ($handle) { $handle.Dispose() }
            Remove-ReinstallTemp @($fx.Path, $t)
        }
    }

    It 'reinstall: an adoption still pending keeps its marker byte for byte and moves neither instruction file' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            $markerBytes = [Text.UTF8Encoding]::new($false).GetBytes("{`"installedAt`":`"2026-01-01`",`"detectedArtifacts`":[`".cursorrules`"],`"archivedOriginals`":[]}`n")
            [IO.File]::WriteAllBytes((Join-Path $t '.claude/adoption-pending.json'), $markerBytes)
            & git -C $t add -A 2>&1 | Out-Null
            & git -C $t commit -qm pending-adoption 2>&1 | Out-Null
            Assert ($LASTEXITCODE -eq 0) 'calibration: could not commit the pending marker'
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            Assert ($r.Exit -eq 0) "expected exit 0 from -Reinstall with an adoption pending, got $($r.Exit): $($r.Out)"
            Assert-BytesEqual $markerBytes ([IO.File]::ReadAllBytes((Join-Path $t '.claude/adoption-pending.json'))) "the pending adoption's marker changed: $($r.Out)"
            Assert (-not (Test-Path -LiteralPath (Join-Path $t 'docs/pre-adoption'))) "docs/pre-adoption/ was written although an adoption is pending: $($r.Out)"
            Assert ($r.Out -match 'LAYOUT: [^\r\n]*adoption still pending') "the output does not say why the instruction files stayed: $($r.Out)"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }

    # B-482: with an adoption pending the old layout move still replaces the mirror, and -Reinstall writes no backup, so
    # the team's edit to it is only in the commit: the LAYOUT line must say so and print a command that brings it back.
    It 'B-482 reinstall: with an adoption pending, the layout move names the replaced mirror and how to read it back from the commit' {
        $fx = New-ReinstallFixture
        try {
            $t = $fx.Path
            [IO.File]::AppendAllText((Join-Path $t 'AGENTS.md'), "`n- TEAM MIRROR EDIT 5c1e: never call the billing API from a test.`n", [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllBytes((Join-Path $t '.claude/adoption-pending.json'), [Text.UTF8Encoding]::new($false).GetBytes("{`"installedAt`":`"2026-01-01`",`"detectedArtifacts`":[`".cursorrules`"],`"archivedOriginals`":[]}`n"))
            & git -C $t add -A 2>&1 | Out-Null
            & git -C $t commit -qm mirror-edit 2>&1 | Out-Null
            Assert ($LASTEXITCODE -eq 0) 'calibration: could not commit the edited mirror'
            $r = Invoke-ReinstallInstaller -Target $t -Switches @('-Reinstall')
            Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit): $($r.Out)"
            Assert (-not ([IO.File]::ReadAllText((Join-Path $t 'AGENTS.md')).Contains('TEAM MIRROR EDIT 5c1e'))) "calibration: the layout move did not replace the edited mirror: $($r.Out)"
            $flat = $r.Out -replace '\s+', ' '
            $line = [regex]::Match($flat, 'LAYOUT: moving the project instructions[^.]*\..*?Review AGENTS\.md before committing\.')
            Assert $line.Success "calibration: no layout-move line: $($r.Out)"
            Assert ($line.Value -match 'hand edits') "the LAYOUT line does not say the mirror's hand edits are not carried: $($line.Value)"
            $show = [regex]::Match($line.Value, 'git -C .+? show [0-9a-f]{40}:\./AGENTS\.md')
            Assert $show.Success "the LAYOUT line prints no command that reads the replaced mirror back: $($line.Value)"
            # Pasted as printed, from a folder outside the repository, as an installer is usually run.
            Push-Location ([IO.Path]::GetTempPath())
            try { $back = & (Get-PsExe) -NoProfile -Command $show.Value 2>&1 | Out-String } finally { Pop-Location }
            Assert ($back.Contains('TEAM MIRROR EDIT 5c1e')) "the printed command, run as printed outside the repository, does not bring the edit back: $($show.Value) / $back"
        } finally { Remove-ReinstallTemp @($fx.Path) }
    }
}
# B-486: an update refreshes .claude/settings.json from the release and used to leave only the release's keys, so a deny rule
# the team had added stopped applying for every teammate. The team's keys the release does not define are carried back in.
function Get-B486Dist { return [Text.UTF8Encoding]::new($false).GetString([IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/.claude/settings.json'))) }
# Members written after the last one of Text, as a team adds them by hand and as the installer writes them.
function Add-B486TopLevel {
    param([string]$Text, [string[]]$Members)
    $nl = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $at = $Text.TrimEnd().Length - 1
    return $Text.Substring(0, $at).TrimEnd() + ",$nl  " + ($Members -join ",$nl  ") + "$nl}$nl"
}
function Get-B486Notices { param([string]$Output) return @($Output -split '\r?\n' | Where-Object { $_ -match 'NOTICE: \.claude/settings\.json:' } | ForEach-Object { $_.Trim() }) }
function Write-B486Text { param([string]$Path, [string]$Text) [IO.File]::WriteAllBytes($Path, [Text.UTF8Encoding]::new($false).GetBytes($Text)) }
$b486Backup = '.claude/.state/settings.json.pre-update'
$b486Deny = @('"permissions": { "deny": ["Read(./secrets/**)"] }', '"model": "opus"')

It 'B-486 an update carries the top-level settings keys of the team into the refreshed file' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b486-' + [guid]::NewGuid())
    try {
        # A greenfield install, committed; the team then adds a deny rule beside the release's keys, commits, and updates.
        $t = Join-Path $root 'carry'
        [void][IO.Directory]::CreateDirectory($t)
        & git -C $t init -q
        & git -C $t config user.email 'tests@example.invalid'
        & git -C $t config user.name 'installer tests'
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "calibration: the greenfield install failed (exit $LASTEXITCODE): $first"
        & git -C $t add -A 2>&1 | Out-Null
        & git -C $t commit -qm install 2>&1 | Out-Null
        $settings = Join-Path $t '.claude/settings.json'
        $team = Add-B486TopLevel -Text ([IO.File]::ReadAllText($settings)) -Members $b486Deny
        Write-B486Text -Path $settings -Text $team
        & git -C $t add -A 2>&1 | Out-Null
        & git -C $t commit -qm 'team deny rule' 2>&1 | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: could not commit the team settings'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 0 -and $out -match 'Done \(update\)') "the update failed (exit $exit): $out"
        $after = [IO.File]::ReadAllText($settings)
        $json = $after | ConvertFrom-Json
        Assert (@($json.permissions.deny).Count -eq 1 -and @($json.permissions.deny)[0] -ceq 'Read(./secrets/**)') "the team's deny rule is not in the refreshed settings.json: $after"
        Assert ($after.Contains('"deny": ["Read(./secrets/**)"]')) "the one-rule array did not stay as written: $after"
        Assert (($json.PSObject.Properties.Name -join ',') -ceq '_comment,env,defaultShell,hooks,permissions,model') "the keys are not the release's followed by the team's, in the team's order: $(($json.PSObject.Properties.Name -join ','))"
        $dist = Get-B486Dist
        Assert ($after -ceq (Add-B486TopLevel -Text $dist -Members $b486Deny)) 'the refreshed file is not the release''s own bytes followed by the team''s members'
        $kept = [IO.File]::ReadAllText((Join-Path $t $b486Backup))
        Assert ($kept -ceq $team) 'the pre-update backup is not the team''s file as it was'
        Assert ((($out -replace '\s+', ' ') -match 'carried your own top-level keys into the refreshed file, unchanged: permissions, model') -and ($out -match 'and your own top-level keys \(permissions, model\) were carried into it')) "the update did not say which keys it carried: $out"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-486 an update names each team value it replaced or dropped, and -WhatIf prints the same lines' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b486-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        $settings = Join-Path $t '.claude/settings.json'
        $team = '{ "_comment": "team note", "env": { "CLAUDE_CODE_USE_POWERSHELL_TOOL": "0", "B486_TEAM_VAR": "sk-B486-SECRET", "OTHER": "kept" }, "defaultShell": "bash", "hooks": { "Stop": [] } }' + "`n"
        Write-B486Text -Path $settings -Text $team
        $installer = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
        $dry = & (Get-PsExe) -NoProfile -File $installer -Target $t -WhatIf 2>&1 | Out-String
        Assert ($LASTEXITCODE -eq 0 -and $dry -match 'Dry run complete') "calibration: the dry run failed (exit $LASTEXITCODE): $dry"
        Assert (([IO.File]::ReadAllText($settings)) -ceq $team -and -not (Test-Path -LiteralPath (Join-Path $t $b486Backup))) 'the dry run wrote to the target'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 0) "the update failed (exit $exit): $out"
        $lines = Get-B486Notices -Output $out
        # No line for _comment (the release's own note, which the fixture changed), and the backup is named as the file before the
        # update. The env variables the release does not set are the team's, carried (B-507). The file holds no framework hook
        # entry, so each event and matcher the stamped release (0.86.7) registered is named as removed (B-507).
        $copy = "; the file as it was before this update is saved in $b486Backup."
        $expected = @(
            "NOTICE: .claude/settings.json: carried your own env variables into the refreshed file beside this release's, unchanged: B486_TEAM_VAR, OTHER.",
            "NOTICE: .claude/settings.json: your env variable 'CLAUDE_CODE_USE_POWERSHELL_TOOL' differed from this release's and was replaced by it$copy",
            "NOTICE: .claude/settings.json: your 'defaultShell' differed from this release's and was replaced by it$copy")
        $lacks = @('PostToolUse matcher ''Write|Edit''', 'PreToolUse matcher ''Write|Edit''', 'SessionStart with no matcher', 'Stop with no matcher', 'UserPromptSubmit with no matcher' | ForEach-Object {
            "NOTICE: .claude/settings.json: your file lacks the framework's hook entries release 0.86.7 registered under $_ (a removal of yours), so this update wrote the framework's entries as this release ships them; your version is in $b486Backup and in your last commit, if you committed it." })
        Assert ((@($lines | Select-Object -First 3) -join "`n") -ceq ($expected -join "`n")) "the lines for the carried and replaced values are not the expected ones: $($lines -join ' | ')"
        Assert ((@($lines | Select-Object -Skip 3 | Sort-Object -CaseSensitive) -join "`n") -ceq (@($lacks | Sort-Object -CaseSensitive) -join "`n")) "the framework hook entries the file lacks were not each named: $($lines -join ' | ')"
        Assert ((Get-B486Notices -Output $dry | Out-String) -ceq ($lines | Out-String)) "the dry run printed other lines than the update did: $($dry)"
        Assert ($out -notmatch 'sk-B486-SECRET' -and $dry -notmatch 'sk-B486-SECRET') 'a value of the team''s env was printed'
        $merged = (Get-B486Dist).Replace('"env": { "CLAUDE_CODE_USE_POWERSHELL_TOOL": "1" }', '"env": { "CLAUDE_CODE_USE_POWERSHELL_TOOL": "1", "B486_TEAM_VAR": "sk-B486-SECRET", "OTHER": "kept" }')
        Assert ([IO.File]::ReadAllText($settings) -ceq $merged) 'a key both files define did not take the release''s value as it shipped, beside the team''s own env variables'
        Assert ([IO.File]::ReadAllText((Join-Path $t $b486Backup)) -ceq $team) 'the backup does not hold the team''s values'
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

function Set-B486Stamp { param([string]$Target, [string]$Version) [IO.File]::WriteAllText((Join-Path $Target '.claude/framework-version.json'), "{`"version`":`"$Version`"}", [Text.UTF8Encoding]::new($false)) }

It 'B-486 an interrupted update leaves the merged settings in place, and its re-run keeps the team keys and the first backup' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b486-' + [guid]::NewGuid())
    $handle = $null
    try {
        # The team's file is not the release's, so a half-done update shows whether settings.json is written once, merged.
        New-ArchGeneratorTarget -Target $t
        # The release's own manifest as the previous one, so the update does not read the held file while planning.
        Copy-Item -LiteralPath (Join-Path $repoRoot 'dist/dotnet/framework-ownership.json') -Destination (Join-Path $t 'framework-ownership.json')
        $original = '{ "env": { "B486_VAR": "1" }, ' + ($b486Deny -join ', ') + " }`n"
        $settings = Join-Path $t '.claude/settings.json'
        $backup = Join-Path $t $b486Backup
        Write-B486Text -Path $settings -Text $original
        $victim = Join-Path $t 'scripts/wiki-check.ps1'
        [IO.File]::WriteAllText($victim, "# held by another program`n", [Text.UTF8Encoding]::new($false))
        $handle = [IO.File]::Open($victim, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $stopped = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 3 -and $stopped -match 'Could not copy') "calibration: the held file did not stop the update (exit $LASTEXITCODE): $stopped"
        $handle.Dispose(); $handle = $null
        $merged = Add-B486TopLevel -Text ((Get-B486Dist).Replace('"env": { "CLAUDE_CODE_USE_POWERSHELL_TOOL": "1" }', '"env": { "CLAUDE_CODE_USE_POWERSHELL_TOOL": "1", "B486_VAR": "1" }')) -Members $b486Deny
        Assert ([IO.File]::ReadAllText($settings) -ceq $merged) "the stopped update did not leave the release's settings with the team's keys in them: $([IO.File]::ReadAllText($settings))"
        Assert ([IO.File]::ReadAllText($backup) -ceq $original) 'the stopped update did not leave the team''s file in the backup'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the re-run failed (exit $LASTEXITCODE): $out"
        Assert ([IO.File]::ReadAllText($settings) -ceq $merged) "the re-run changed the merged settings: $out"
        Assert ([IO.File]::ReadAllText($backup) -ceq $original) 'the re-run replaced the first backup'
        Assert (($out -replace '\s+', ' ') -match 'kept the earlier pre-update settings backup') "the re-run did not say it kept the backup: $out"
    } finally {
        if ($handle) { $handle.Dispose() }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-486 a backup left by another branch or an earlier run is never imported, and a key the team deleted stays deleted across a later release' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b486-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        $dist = Get-B486Dist
        $settings = Join-Path $t '.claude/settings.json'
        $backup = Join-Path $t $b486Backup
        # Settings equal to the release's own, and a git-ignored backup another branch wrote: it holds nothing of this team's.
        $foreign = '{ "permissions": { "allow": ["Bash(*)"] } }' + "`n"
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backup) | Out-Null
        Write-B486Text -Path $backup -Text $foreign
        Write-B486Text -Path $settings -Text $dist
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $first"
        Assert ([IO.File]::ReadAllText($settings) -ceq $dist -and $first -notmatch 'carried your own' -and [IO.File]::ReadAllText($backup) -ceq $foreign) "a backup another branch wrote was imported as the team's keys: $first"
        # The team's keys are carried by one release, then deleted by hand; a later release (same settings, older stamp) does not bring them back.
        Set-B486Stamp -Target $t -Version '0.97.0'
        Write-B486Text -Path $settings -Text (Add-B486TopLevel -Text $dist -Members $b486Deny)
        $carried = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $carried -match 'carried your own top-level keys') "calibration: the team keys were not carried: $carried"
        Write-B486Text -Path $settings -Text $dist
        Set-B486Stamp -Target $t -Version '0.97.0'
        $later = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and [IO.File]::ReadAllText($settings) -ceq $dist -and $later -notmatch 'carried your own') "a key the team deleted came back from the backup: $later"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-486 a key added after a completed carry survives a later update that stops partway, and its re-run' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b486-' + [guid]::NewGuid())
    $handle = $null
    try {
        New-ArchGeneratorTarget -Target $t
        $dist = Get-B486Dist
        $settings = Join-Path $t '.claude/settings.json'
        Write-B486Text -Path $settings -Text (Add-B486TopLevel -Text $dist -Members $b486Deny[0])
        $one = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $one -match 'unchanged: permissions\.') "calibration: the first update did not carry permissions: $one"
        # The team adds a key after that update; the next release leaves the settings unchanged, and its update stops on a held file.
        $withModel = Add-B486TopLevel -Text $dist -Members $b486Deny
        Write-B486Text -Path $settings -Text $withModel
        Set-B486Stamp -Target $t -Version '0.97.1'
        $victim = Join-Path $t 'scripts/wiki-check.ps1'
        $handle = [IO.File]::Open($victim, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        $stopped = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 3) "calibration: the held file did not stop the update (exit $LASTEXITCODE): $stopped"
        $handle.Dispose(); $handle = $null
        Assert ([IO.File]::ReadAllText($settings) -ceq $withModel) "the stopped update lost a key the team added: $([IO.File]::ReadAllText($settings))"
        $again = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and [IO.File]::ReadAllText($settings) -ceq $withModel) "the re-run lost a key the team added: $again"
    } finally {
        if ($handle) { $handle.Dispose() }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-486 a top-level key the release no longer sets is dropped and named, not carried as the team own' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b486-' + [guid]::NewGuid())
    try {
        # A later release that drops defaultShell: a copy of this dist with the line removed from its settings file.
        $future = Join-Path $root 'future'
        [void][IO.Directory]::CreateDirectory($root)
        Copy-Item -LiteralPath (Join-Path $repoRoot 'dist/dotnet') -Destination $future -Recurse
        $path = Join-Path $future '.claude/settings.json'
        $text = [IO.File]::ReadAllText($path)
        $changed = $text -replace '(?m)^\s*"defaultShell":\s*"powershell",\r?\n', ''
        Assert ($changed -cne $text) 'calibration: settings.json has no defaultShell line to remove'
        Write-B486Text -Path $path -Text $changed
        $stamp = Join-Path $future '.claude/framework-version.json'
        [IO.File]::WriteAllText($stamp, ([IO.File]::ReadAllText($stamp) -replace '"version":\s*"[^"]+"', '"version": "0.99.0"'))
        $t = Join-Path $root 'target'
        New-ArchGeneratorTarget -Target $t
        $settings = Join-Path $t '.claude/settings.json'
        Write-B486Text -Path $settings -Text (Add-B486TopLevel -Text (Get-B486Dist) -Members $b486Deny)
        $out = & (Get-PsExe) -NoProfile -File (Join-Path $future 'scripts/install.ps1') -Target $t 2>&1 | Out-String
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $after = [IO.File]::ReadAllText($settings)
        Assert ($after -notmatch 'defaultShell') "a key the release dropped was carried as the team's: $after"
        Assert ($after -ceq (Add-B486TopLevel -Text ([IO.File]::ReadAllText((Join-Path $future '.claude/settings.json'))) -Members $b486Deny)) "the team's own keys were not carried beside the release's: $after"
        Assert ($out -match "NOTICE: \.claude/settings\.json: your 'defaultShell', which this release does not set, was dropped; the file as it was before this update is saved in $([regex]::Escape($b486Backup))\.") "the dropped key was not named: $out"
        Assert ($out -notmatch 'unchanged: [^\r\n]*defaultShell') "defaultShell is named as carried: $out"
    } finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-486 env variables that differ only in case do not stop the team keys being carried' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b486-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        $dist = Get-B486Dist
        $wide = '"env": { "CLAUDE_CODE_USE_POWERSHELL_TOOL": "1", "HTTP_PROXY": "http://proxy:8080", "http_proxy": "http://proxy:8080" }'
        $team = $dist.Replace('"env": { "CLAUDE_CODE_USE_POWERSHELL_TOOL": "1" }', $wide)
        Assert ($team -cne $dist) 'calibration: the fixture env was not widened'
        $settings = Join-Path $t '.claude/settings.json'
        Write-B486Text -Path $settings -Text (Add-B486TopLevel -Text $team -Members $b486Deny)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        # The first of the two is carried (B-507); the other is not, as PowerShell cannot read both in one file, and says so.
        $carried = $dist.Replace('"env": { "CLAUDE_CODE_USE_POWERSHELL_TOOL": "1" }', '"env": { "CLAUDE_CODE_USE_POWERSHELL_TOOL": "1", "HTTP_PROXY": "http://proxy:8080" }')
        Assert ([IO.File]::ReadAllText($settings) -ceq (Add-B486TopLevel -Text $carried -Members $b486Deny)) "the case-variant env names stopped the team keys being carried: $out"
        Assert (($out -replace '\s+', ' ') -match "carried your own env variable into the refreshed file beside this release's, unchanged: HTTP_PROXY\." -and $out -match "your env variable 'http_proxy' was not carried, because its name differs from 'HTTP_PROXY' only in case") "the carried and the case-variant env variables were not named: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

# B-506: a machine without pwsh installed the Windows PowerShell 5.1 variant as settings.json, beside the release's
# settings.windows.json. Under PowerShell 7 the update writes the pwsh file with the team's keys, says the hooks changed
# interpreter, and retires the variant through the ledger.
It 'B-506 an update of a repository on the 0.98.6 Windows PowerShell 5.1 settings switches it to pwsh, keeps the team keys, deletes the variant and says so' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b506-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        Set-B486Stamp -Target $t -Version '0.98.6'
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.98.6:dist/dotnet/framework-ownership.json'))
        $variant = Get-GitBlobBytes -Spec 'v0.98.6:dist/dotnet/.claude/settings.windows.json'
        $variantText = [Text.UTF8Encoding]::new($false).GetString($variant)
        Assert ($variantText -match '"command": "powershell -NoProfile -ExecutionPolicy Bypass -File \.claude/hooks/guard\.ps1') 'calibration: the 0.98.6 variant does not run the guard under powershell'
        [IO.File]::WriteAllBytes((Join-Path $t '.claude/settings.windows.json'), $variant)
        Write-B486Text -Path (Join-Path $t '.claude/settings.json') -Text (Add-B486TopLevel -Text $variantText -Members $b486Deny)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'Done \(update\)') "the update failed (exit $LASTEXITCODE): $out"
        Assert ([IO.File]::ReadAllText((Join-Path $t '.claude/settings.json')) -ceq (Add-B486TopLevel -Text (Get-B486Dist) -Members $b486Deny)) "settings.json is not the release's pwsh file followed by the team's keys: $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/settings.windows.json'))) "the retired Windows PowerShell 5.1 variant was not deleted: $out"
        $flat = $out -replace '\s+', ' '
        $notice = "NOTICE: .claude/settings.json ran the framework's hooks under Windows PowerShell 5.1; it now runs them under PowerShell 7 (pwsh). Every machine and CI agent that uses Claude Code or runs the framework's checks in this repository needs PowerShell 7."
        Assert ([regex]::Matches($flat, [regex]::Escape($notice)).Count -eq 1) "the switch to PowerShell 7 was not announced once: $out"
        Assert ($flat -match 'carried your own top-level keys into the refreshed file, unchanged: permissions, model\.') "the team keys were not named as carried: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-506 an update of settings that already run pwsh says nothing about Windows PowerShell 5.1' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b506-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        # Each entry names Claude Code's shell field "powershell" and runs pwsh: no Windows PowerShell 5.1 registration.
        Write-B486Text -Path (Join-Path $t '.claude/settings.json') -Text (Add-B486TopLevel -Text (Get-B486Dist) -Members $b486Deny)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'Done \(update\)') "the update failed (exit $LASTEXITCODE): $out"
        Assert ($out -notmatch 'Windows PowerShell 5\.1') "an update of pwsh settings mentioned Windows PowerShell 5.1: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-486 a settings file that is not strict JSON is not carried and the notice names the backup' {
    $utf16 = [Text.Encoding]::Unicode.GetPreamble() + [Text.Encoding]::Unicode.GetBytes('{ "permissions": { "deny": ["Read(./x)"] } }')
    $legs = [ordered]@{
        'a comment'         = [Text.UTF8Encoding]::new($false).GetBytes("{`n  // team note`n  `"permissions`": { `"deny`": [`"Read(./x)`"] }`n}`n")
        'an empty file'     = [byte[]]@()
        'a trailing comma'  = [Text.UTF8Encoding]::new($false).GetBytes('{ "permissions": { "deny": ["Read(./x)"] }, }')
        'keys in two cases' = [Text.UTF8Encoding]::new($false).GetBytes('{ "permissions": {}, "Permissions": {} }')
        'a key in the case of a release key' = [Text.UTF8Encoding]::new($false).GetBytes('{ "Env": { "A": "1" }, "permissions": {} }')
        'UTF-16 text'       = [byte[]]$utf16
    }
    foreach ($leg in $legs.Keys) {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('b486-' + [guid]::NewGuid())
        try {
            New-ArchGeneratorTarget -Target $t
            $settings = Join-Path $t '.claude/settings.json'
            [IO.File]::WriteAllBytes($settings, $legs[$leg])
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $exit = $LASTEXITCODE
            Assert ($exit -eq 0) "${leg}: the update failed (exit $exit): $out"
            $flat = $out -replace '\s+', ' '
            Assert ($flat -match "NOTICE: \.claude/settings\.json: your own top-level keys were not carried into the refreshed file, which holds only this release's keys, because .+\. The file as it was before this update is saved in $([regex]::Escape($b486Backup)); re-add") "${leg}: the update did not say the keys were not carried, naming the backup: $out"
            Assert ($flat -match 'but your own top-level keys were NOT carried into it') "${leg}: the Done line did not say so: $out"
            Assert (Test-B194BytesEqual ([Text.UTF8Encoding]::new($false).GetBytes((Get-B486Dist))) ([IO.File]::ReadAllBytes($settings))) "${leg}: the refreshed file is not the release's own"
            Assert (Test-B194BytesEqual $legs[$leg] ([IO.File]::ReadAllBytes((Join-Path $t $b486Backup)))) "${leg}: the backup is not the team's file as it was"
        } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

It 'B-486 every top-level key a shipped settings file sets is in the installer list of keys no release leaves to the team' {
    # A key a release ships and a later release drops would otherwise be carried as the team's own, because nothing named it.
    $installer = Join-Path $repoRoot 'src/core/scripts/install.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($installer, [ref]$null, [ref]$null)
    $assignment = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -ceq '$script:SjEverShipped' }, $true)
    Assert ($null -ne $assignment) 'calibration: the installer has no $script:SjEverShipped list'
    $listed = @($assignment.Right.FindAll({ param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { [string]$_.Value })
    Assert ($listed.Count -gt 0) 'calibration: the installer list holds no key'
    $files = @(
        foreach ($d in 'dotnet', 'angular', 'monorepo') { "dist/$d/.claude/settings.json"; "src/stacks/$d/files/.claude/settings.json" })
    $unlisted = New-Object System.Collections.Generic.List[string]
    foreach ($relative in $files) {
        $path = Join-Path $repoRoot $relative
        Assert (Test-Path -LiteralPath $path -PathType Leaf) "calibration: $relative does not exist"
        foreach ($key in @(([IO.File]::ReadAllText($path) | ConvertFrom-Json).PSObject.Properties.Name)) {
            if ($listed -cnotcontains $key) { $unlisted.Add("$relative sets '$key'") }
        }
    }
    Assert ($unlisted.Count -eq 0) "a shipped settings file sets a top-level key the installer does not list in `$script:SjEverShipped (append it there): $($unlisted -join '; ')"
}

It 'B-486 an update that carries team keys does not need the system temporary folder' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b486-' + [guid]::NewGuid())
    $savedTemp = $env:TEMP; $savedTmp = $env:TMP
    try {
        # TEMP and TMP name a file, so nothing can be created in them (a folder holding every tmpXXXX.tmp name fails the same way).
        $t = Join-Path $root 'target'
        New-ArchGeneratorTarget -Target $t
        $settings = Join-Path $t '.claude/settings.json'
        Write-B486Text -Path $settings -Text (Add-B486TopLevel -Text (Get-B486Dist) -Members $b486Deny)
        $notAFolder = Join-Path $root 'not-a-folder.txt'
        [IO.File]::WriteAllText($notAFolder, 'x')
        $env:TEMP = $notAFolder; $env:TMP = $notAFolder
        try { $out = Invoke-Installer -Dist 'dotnet' -Target $t; $exit = $LASTEXITCODE } finally { $env:TEMP = $savedTemp; $env:TMP = $savedTmp }
        Assert ($exit -eq 0 -and $out -match 'Done \(update\)') "the update failed without a usable temporary folder (exit $exit): $out"
        Assert ([IO.File]::ReadAllText($settings) -ceq (Add-B486TopLevel -Text (Get-B486Dist) -Members $b486Deny)) "the refreshed settings are not the release followed by the team keys: $out"
        Assert (@(Get-ChildItem -LiteralPath (Join-Path $t '.claude/.state') -Filter 'settings.json.*.tmp' -Force).Count -eq 0) 'a staged copy of the settings was left behind'
    } finally {
        $env:TEMP = $savedTemp; $env:TMP = $savedTmp
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-507: an update kept the release's env and hooks whole, so the team's own env variables and hook entries were dropped. They
# are carried beside the release's now; an entry whose command some release shipped is the framework's and gives way.
function Get-B507Text { param([string]$Spec) return [Text.UTF8Encoding]::new($false).GetString((Get-GitBlobBytes -Spec $Spec)) }
function Add-B507After {
    param([string]$Text, [string]$After, [string]$Insert)
    $at = $Text.IndexOf($After, [StringComparison]::Ordinal)
    if ($at -lt 0) { throw "calibration: the fixture holds no '$After'" }
    return $Text.Substring(0, $at + $After.Length) + $Insert + $Text.Substring($at + $After.Length)
}
# A repository at Version of Stack (its stamp and ownership manifest) whose .claude/settings.json is Settings.
function New-B507Target {
    param([string]$Target, [string]$Settings, [string]$Version = '0.98.6', [string]$Stack = 'dotnet')
    New-ArchGeneratorTarget -Target $Target
    [IO.File]::WriteAllText((Join-Path $Target '.claude/framework-version.json'), "{`"template`":`"$Stack`",`"version`":`"$Version`"}", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllBytes((Join-Path $Target 'framework-ownership.json'), (Get-GitBlobBytes -Spec "v${Version}:dist/$Stack/framework-ownership.json"))
    Write-B486Text -Path (Join-Path $Target '.claude/settings.json') -Text $Settings
}
# Every command under hooks, wherever it sits.
function Get-B507Commands {
    param($Value)
    $found = New-Object System.Collections.Generic.List[string]
    $pending = New-Object System.Collections.Generic.Stack[object]
    $pending.Push($Value)
    while ($pending.Count -gt 0) {
        $v = $pending.Pop()
        if ($null -eq $v -or $v -is [string] -or $v -is [ValueType]) { continue }
        if ($v -is [Array]) { foreach ($item in $v) { $pending.Push($item) }; continue }
        foreach ($p in $v.PSObject.Properties) { if ($p.Name -ceq 'command' -and $p.Value -is [string]) { $found.Add($p.Value) } else { $pending.Push($p.Value) } }
    }
    return $found.ToArray()
}
$b507Bash = '{ "type": "command", "command": "pwsh -NoProfile -File .claude/hooks/team-bash-check.ps1", "shell": "powershell" }'
$b507Post = '{ "type": "command", "command": "powershell -NoProfile -File .claude/hooks/team-audit.ps1", "timeout": 30 }'
$b507Env = '"env": { "CLAUDE_CODE_USE_POWERSHELL_TOOL": "1" }'
# How the update names an event and matcher where the team's framework entries differ from the stamped release's, or lack them.
function Get-B507Differs { param([string]$Label, [string]$Version = '0.98.6') return "NOTICE: .claude/settings.json: the framework's hook entries under $Label in your file are not as release $Version registered them (an edit, a copy or a move of yours), so this update replaced them with this release's registration; your version is in $b486Backup and in your last commit, if you committed it." }
function Get-B507Lacks { param([string]$Label, [string]$Version = '0.98.6') return "NOTICE: .claude/settings.json: your file lacks the framework's hook entries release $Version registered under $Label (a removal of yours), so this update wrote the framework's entries as this release ships them; your version is in $b486Backup and in your last commit, if you committed it." }
# A v0.98.6 install whose settings the team changed (Change) and committed, updated; the NOTICEs of the update about hook entries.
function Invoke-B507Edit {
    param([string]$Target, [scriptblock]$Change)
    $prior = Get-B507Text -Spec 'v0.98.6:dist/dotnet/.claude/settings.json'
    $team = & $Change $prior
    Assert ($team -cne $prior -and $null -ne ($team | ConvertFrom-Json)) 'calibration: the change left the 0.98.6 settings as they were'
    New-B507Target -Target $Target -Settings $team
    & git -C $Target init -q
    & git -C $Target config user.email 'tests@example.invalid'
    & git -C $Target config user.name 'installer tests'
    & git -C $Target add -A 2>&1 | Out-Null
    & git -C $Target commit -qm 'team edits' 2>&1 | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'calibration: could not commit the team settings'
    $out = Invoke-Installer -Dist 'dotnet' -Target $Target
    Assert ($LASTEXITCODE -eq 0 -and $out -match 'Done \(update\)') "the update failed (exit $LASTEXITCODE): $out"
    # Replacement stays: the refreshed file is the release's own, and the team's version is in the backup the NOTICE names.
    Assert ([IO.File]::ReadAllText((Join-Path $Target '.claude/settings.json')) -ceq (Get-B486Dist)) "the refreshed file is not the release's own: $out"
    Assert ([IO.File]::ReadAllText((Join-Path $Target $b486Backup)) -ceq $team) 'the backup the NOTICE names does not hold the team''s file'
    $notices = @(Get-B486Notices -Output $out | Where-Object { $_ -match 'hook entr' })
    Assert (@($notices | Where-Object { $_ -match 'pwsh|powershell -|\.ps1|guard|post-write|timeout|cwd' }).Count -eq 0) "a NOTICE holds command text: $($notices -join ' | ')"
    return , $notices
}

It 'B-507 an update of a repository at the prior release keeps the team env variables and hook entries, refreshes the framework entries and names what it carried' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b507-' + [guid]::NewGuid())
    try {
        # The reviewer's case: at 0.98.6 the team adds two env variables, a Bash PreToolUse hook and a PostToolUse hook, and commits.
        $team = (Get-B507Text -Spec 'v0.98.6:dist/dotnet/.claude/settings.json').Replace($b507Env, '"env": { "CLAUDE_CODE_USE_POWERSHELL_TOOL": "1", "B507_REGION": "eu-west", "B507_TOKEN": "sk-B507-SECRET" }')
        $team = Add-B507After -Text $team -After '"PreToolUse": [' -Insert "`n      { `"matcher`": `"Bash`", `"hooks`": [ $b507Bash ] },"
        $team = Add-B507After -Text $team -After '"PostToolUse": [' -Insert "`n      { `"matcher`": `"Bash`", `"hooks`": [ $b507Post ] },"
        Assert (($team | ConvertFrom-Json).env.B507_TOKEN -ceq 'sk-B507-SECRET') 'calibration: the team settings do not read as JSON'
        New-B507Target -Target $t -Settings $team
        & git -C $t init -q
        & git -C $t config user.email 'tests@example.invalid'
        & git -C $t config user.name 'installer tests'
        & git -C $t add -A 2>&1 | Out-Null
        & git -C $t commit -qm 'team settings' 2>&1 | Out-Null
        Assert ($LASTEXITCODE -eq 0) 'calibration: could not commit the team settings'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 0 -and $out -match 'Done \(update\)') "the update failed (exit $exit): $out"
        $settings = Join-Path $t '.claude/settings.json'
        $after = [IO.File]::ReadAllText($settings)
        $json = $after | ConvertFrom-Json
        Assert ($json.env.B507_REGION -ceq 'eu-west' -and $json.env.B507_TOKEN -ceq 'sk-B507-SECRET' -and $json.env.CLAUDE_CODE_USE_POWERSHELL_TOOL -ceq '1') "the team env variables were not kept beside the release's: $after"
        Assert ($after.Contains($b507Bash) -and $after.Contains($b507Post)) "the team hook entries are not in the refreshed file as the team wrote them: $after"
        foreach ($event in 'PreToolUse', 'PostToolUse') {
            $groups = @($json.hooks.$event | Where-Object { $_.matcher -ceq 'Bash' })
            Assert ($groups.Count -eq 1 -and @($groups[0].hooks).Count -eq 1) "the team entry is not alone in a $event 'Bash' group: $after"
        }
        # The framework entries are this release's: no 0.98.6 command is left, and every command of the release is there.
        $release = @(Get-B507Commands -Value ((Get-B486Dist) | ConvertFrom-Json).hooks)
        $now = @(Get-B507Commands -Value $json.hooks)
        Assert ((@($now | Where-Object { $release -cnotcontains $_ } | Sort-Object -CaseSensitive) -join '|') -ceq 'powershell -NoProfile -File .claude/hooks/team-audit.ps1|pwsh -NoProfile -File .claude/hooks/team-bash-check.ps1') "a command other than the release's and the team's two is registered: $($now -join ' | ')"
        Assert (@($release | Where-Object { $now -cnotcontains $_ }).Count -eq 0) "a hook entry of the release is missing: $after"
        $flat = $out -replace '\s+', ' '
        Assert ($flat -match [regex]::Escape("NOTICE: .claude/settings.json: carried your own env variables into the refreshed file beside this release's, unchanged: B507_REGION, B507_TOKEN.")) "the carried env variables were not named: $out"
        Assert ($flat -match [regex]::Escape("NOTICE: .claude/settings.json: carried your own hook entries into the refreshed file beside this release's, unchanged: 1 under PreToolUse matcher 'Bash', 1 under PostToolUse matcher 'Bash'.")) "the carried hook entries were not named by event and matcher: $out"
        Assert ($flat -match 'and your own env variables \(B507_REGION, B507_TOKEN\) and 2 hook entries were carried into it') "the Done line does not say what was carried: $out"
        Assert ($out -notmatch 'sk-B507-SECRET|eu-west|team-bash-check|team-audit') "a team value or command was printed: $out"
        # The team's own entry runs Windows PowerShell 5.1; the framework's never did here, so the switch to pwsh is not announced.
        Assert ($out -notmatch 'was dropped|differed from this release|not carried|Windows PowerShell 5\.1') "the update reported a loss or a switch it did not make: $out"
        Assert ([IO.File]::ReadAllText((Join-Path $t $b486Backup)) -ceq $team) 'the pre-update backup is not the team''s file as it was'
        # The merged file is what the update writes from itself: a re-run leaves it, and the first backup, as they are.
        & git -C $t add -A 2>&1 | Out-Null
        & git -C $t commit -qm 'update' 2>&1 | Out-Null
        $again = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $again -match '(?m)^PLAN unchanged \.claude/settings\.json\r?$') "the re-run did not list the merged settings as unchanged (exit $LASTEXITCODE): $again"
        Assert ([IO.File]::ReadAllText($settings) -ceq $after) "the re-run changed the merged settings: $again"
        Assert ([IO.File]::ReadAllText((Join-Path $t $b486Backup)) -ceq $team -and ($again -replace '\s+', ' ') -match 'kept the earlier pre-update settings backup') "the re-run replaced the first backup: $again"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-507 an update of a repository on a former Windows PowerShell 5.1 variant replaces every framework entry, carries none, and claims no hook entries of the team' {
    foreach ($spec in 'v0.98.6:dist/dotnet/.claude/settings.windows.json', 'v0.90.0:dist/dotnet/.claude/settings.windows.json') {
        $t = Join-Path ([IO.Path]::GetTempPath()) ('b507-' + [guid]::NewGuid())
        try {
            $variant = Get-B507Text -Spec $spec
            Assert ($variant -match '"command": "powershell -NoProfile -ExecutionPolicy Bypass -File \.claude/hooks/guard\.ps1') "calibration: $spec does not run the guard under powershell"
            New-B507Target -Target $t -Settings $variant -Version ($spec -replace '^v([^:]+):.*$', '$1')
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0 -and $out -match 'Done \(update\)') "${spec}: the update failed (exit $LASTEXITCODE): $out"
            $after = [IO.File]::ReadAllText((Join-Path $t '.claude/settings.json'))
            Assert ($after -ceq (Get-B486Dist)) "${spec}: the refreshed file is not the release's own: $after"
            Assert (@(Get-B507Commands -Value ($after | ConvertFrom-Json).hooks | Where-Object { $_ -match '(?:^|; )powershell ' }).Count -eq 0) "${spec}: a powershell command survived: $after"
            $notices = @(Get-B486Notices -Output $out)
            Assert (@($notices | Where-Object { $_ -match "'hooks'|hook entr" }).Count -eq 0) "${spec}: a NOTICE speaks of hook entries of the team, which has none: $($notices -join ' | ')"
            Assert ($out -notmatch 'carried your own' -and ($out -replace '\s+', ' ') -match "ran the framework's hooks under Windows PowerShell 5\.1") "${spec}: the update carried something, or did not announce the switch to pwsh: $out"
        } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

It 'B-507 a team entry inside a framework matcher group survives the update, in this release''s group of that matcher or its own' {
    $teamPost = '{ "type": "command", "command": "pwsh -NoProfile -File .claude/hooks/team-format.ps1" }'
    $teamPre = '{ "type": "command", "command": "pwsh -NoProfile -File .claude/hooks/guard.ps1 -Team" }'
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b507-' + [guid]::NewGuid())
    try {
        # Beside 0.98.6's audit-trail entry in its PostToolUse 'Write|Edit' group: it goes into this release's group of that matcher.
        $prior = Get-B507Text -Spec 'v0.98.6:dist/dotnet/.claude/settings.json'
        $audit = '.claude/hooks/audit-trail.ps1", "shell": "powershell", "cwd": "." }'
        New-B507Target -Target $t -Settings (Add-B507After -Text $prior -After $audit -Insert ",`n          $teamPost")
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'Done \(update\)') "the update failed (exit $LASTEXITCODE): $out"
        $expected = Add-B507After -Text (Get-B486Dist) -After $audit -Insert ",`n          $teamPost"
        Assert ([IO.File]::ReadAllText((Join-Path $t '.claude/settings.json')) -ceq $expected) "the team entry is not after the release's entries in the release's PostToolUse group: $([IO.File]::ReadAllText((Join-Path $t '.claude/settings.json')))"
        Assert (($out -replace '\s+', ' ') -match [regex]::Escape("unchanged: 1 under PostToolUse matcher 'Write|Edit'.")) "the carried entry was not named by its event and matcher: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b507-' + [guid]::NewGuid())
    try {
        # 0.90.0's guard group matched 'Write|Edit', which this release no longer has: the team's entry stays in that group, alone,
        # though it runs a script of the framework's under .claude/hooks/, because its command is not one any release shipped.
        $prior = Get-B507Text -Spec 'v0.90.0:dist/dotnet/.claude/settings.json'
        $guard = '.claude/hooks/guard.ps1 ; exit $LASTEXITCODE", "shell": "powershell" }'
        New-B507Target -Target $t -Settings (Add-B507After -Text $prior -After $guard -Insert ",`n          $teamPre") -Version '0.90.0'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'Done \(update\)') "the update failed (exit $LASTEXITCODE): $out"
        $after = [IO.File]::ReadAllText((Join-Path $t '.claude/settings.json'))
        $pre = @(($after | ConvertFrom-Json).hooks.PreToolUse)
        $releasePre = @(((Get-B486Dist) | ConvertFrom-Json).hooks.PreToolUse)
        Assert ($pre.Count -eq 2 -and ($pre[0] | ConvertTo-Json -Depth 5 -Compress) -ceq ($releasePre[0] | ConvertTo-Json -Depth 5 -Compress)) "the release's PreToolUse group is not first and as shipped: $after"
        Assert ($pre[1].matcher -ceq 'Write|Edit' -and @($pre[1].hooks).Count -eq 1 -and $pre[1].hooks[0].command -ceq 'pwsh -NoProfile -File .claude/hooks/guard.ps1 -Team') "the team entry is not alone in its own PreToolUse 'Write|Edit' group: $after"
        Assert (($out -replace '\s+', ' ') -match [regex]::Escape("unchanged: 1 under PreToolUse matcher 'Write|Edit'.")) "the carried entry was not named by its event and matcher: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-507 a team override of an env variable the release sets takes the release value and is named without its value, beside the carried team variables' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b507-' + [guid]::NewGuid())
    try {
        New-ArchGeneratorTarget -Target $t
        $dist = Get-B486Dist
        $team = $dist.Replace($b507Env, '"env": { "CLAUDE_CODE_USE_POWERSHELL_TOOL": "b507-override-7f3e", "B507_KEY": "sk-B507-KEY-9d1c" }')
        Assert ($team -cne $dist) 'calibration: the fixture env was not changed'
        $settings = Join-Path $t '.claude/settings.json'
        Write-B486Text -Path $settings -Text $team
        $dry = & (Get-PsExe) -NoProfile -File (Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1') -Target $t -WhatIf 2>&1 | Out-String
        Assert ($LASTEXITCODE -eq 0 -and $dry -match 'Dry run complete') "calibration: the dry run failed (exit $LASTEXITCODE): $dry"
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $expected = $dist.Replace($b507Env, '"env": { "CLAUDE_CODE_USE_POWERSHELL_TOOL": "1", "B507_KEY": "sk-B507-KEY-9d1c" }')
        Assert ([IO.File]::ReadAllText($settings) -ceq $expected) "the release's value did not win, or the team's variable was not carried after the release's: $([IO.File]::ReadAllText($settings))"
        $copy = "; the file as it was before this update is saved in $b486Backup."
        $lines = @(Get-B486Notices -Output $out)
        $want = @(
            "NOTICE: .claude/settings.json: carried your own env variable into the refreshed file beside this release's, unchanged: B507_KEY.",
            "NOTICE: .claude/settings.json: your env variable 'CLAUDE_CODE_USE_POWERSHELL_TOOL' differed from this release's and was replaced by it$copy")
        Assert (($lines -join "`n") -ceq ($want -join "`n")) "the lines are not the carried variable and the replaced override: $($lines -join ' | ')"
        Assert ((Get-B486Notices -Output $dry | Out-String) -ceq ($lines | Out-String)) "the dry run printed other lines than the update did: $dry"
        Assert ($out -notmatch 'b507-override-7f3e|sk-B507-KEY-9d1c' -and $dry -notmatch 'b507-override-7f3e|sk-B507-KEY-9d1c') 'an env value was printed'
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}


It 'B-507 a team copy of this release''s hook entry under another matcher is the framework''s: dropped and named, beside the team''s own entry' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b507-' + [guid]::NewGuid())
    try {
        # At 0.98.6 the team copied the guard entry into a Bash group of its own, beside an entry of its own.
        $prior = Get-B507Text -Spec 'v0.98.6:dist/dotnet/.claude/settings.json'
        $guard = @($prior -split "`n" | Where-Object { $_ -match 'hooks/guard\.ps1' })
        Assert ($guard.Count -eq 1) 'calibration: 0.98.6 does not register one guard entry'
        New-B507Target -Target $t -Settings (Add-B507After -Text $prior -After '"PreToolUse": [' -Insert "`n      { `"matcher`": `"Bash`", `"hooks`": [ $($guard[0].Trim()), $b507Bash ] },")
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'Done \(update\)') "the update failed (exit $LASTEXITCODE): $out"
        $settings = Join-Path $t '.claude/settings.json'
        $bash = @(([IO.File]::ReadAllText($settings) | ConvertFrom-Json).hooks.PreToolUse | Where-Object { $_.matcher -ceq 'Bash' })
        Assert ($bash.Count -eq 1 -and @($bash[0].hooks).Count -eq 1 -and $bash[0].hooks[0].command -ceq 'pwsh -NoProfile -File .claude/hooks/team-bash-check.ps1') "the Bash group does not hold the team's own entry alone: $([IO.File]::ReadAllText($settings))"
        $notices = @(Get-B486Notices -Output $out | Where-Object { $_ -match "release 0\.98\.6" })
        Assert (($notices -join "`n") -ceq (Get-B507Differs -Label "PreToolUse matcher 'Bash'")) "the dropped copy was not the one pair named: $($notices -join ' | ')"
        Assert (($out -replace '\s+', ' ') -match [regex]::Escape("unchanged: 1 under PreToolUse matcher 'Bash'.")) "the team's own entry was not named as carried: $out"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

# The step-4 attacks on the first two versions: at 0.98.6 the team changed framework entries, which the update replaced and the
# first version named nowhere (0.99.0's commands match no earlier release's), the second not when the change equalled an older
# release's entry. The team's framework entries are compared, as a set, with what the stamped release shipped.
It 'B-507 an edit of a framework hook entry and a copy of one under another matcher are replaced, each named by event and matcher without command text' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b507-' + [guid]::NewGuid())
    try {
        $notices = Invoke-B507Edit -Target $t -Change {
            param($prior)
            $guard = @($prior -split "`n" | Where-Object { $_ -match 'hooks/guard\.ps1' })
            Assert ($guard.Count -eq 1 -and ([regex]::Matches($prior, '"timeout": 90')).Count -eq 1) 'calibration: 0.98.6 does not register one guard entry and one 90-second timeout'
            Add-B507After -Text $prior.Replace('"timeout": 90', '"timeout": 300') -After '"PreToolUse": [' -Insert "`n      { `"matcher`": `"Bash`", `"hooks`": [ $($guard[0].Trim()) ] },"
        }
        $want = @((Get-B507Differs -Label "PreToolUse matcher 'Bash'"), (Get-B507Differs -Label "PostToolUse matcher 'Write|Edit'"))
        Assert (($notices -join "`n") -ceq ($want -join "`n")) "the two replaced edits were not each named by event and matcher: $($notices -join ' | ')"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-507 a framework entry moved to a narrower matcher, though an older release shipped it so, is replaced and named at both matchers' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b507-' + [guid]::NewGuid())
    try {
        # The guard back on "Write|Edit" equals 0.90.0's entry there, so a check of each entry alone found nothing to name.
        $notices = Invoke-B507Edit -Target $t -Change { param($prior) $prior.Replace('"matcher": "Write|Edit|NotebookEdit"', '"matcher": "Write|Edit"') }
        $want = @((Get-B507Differs -Label "PreToolUse matcher 'Write|Edit'"), (Get-B507Lacks -Label "PreToolUse matcher 'Write|Edit|NotebookEdit'"))
        Assert (($notices -join "`n") -ceq ($want -join "`n")) "the narrowed guard was not named at both matchers: $($notices -join ' | ')"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-507 a framework entry stripped of a property, though an older release shipped it so, is replaced and named' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b507-' + [guid]::NewGuid())
    try {
        $notices = Invoke-B507Edit -Target $t -Change { param($prior) $prior.Replace('"timeout": 90, "cwd": "." }', '"timeout": 90 }') }
        Assert (($notices -join "`n") -ceq (Get-B507Differs -Label "PostToolUse matcher 'Write|Edit'")) "post-write without cwd was not named: $($notices -join ' | ')"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-507 a framework group the team removed is written back and named' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b507-' + [guid]::NewGuid())
    try {
        $notices = Invoke-B507Edit -Target $t -Change { param($prior) [regex]::Replace($prior, ',\s*"Stop": \[[\s\S]*?\]\s*\}\s*\]', '') }
        Assert (($notices -join "`n") -ceq (Get-B507Lacks -Label 'Stop with no matcher')) "the removed Stop group was not named: $($notices -join ' | ')"
    } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
}

It 'B-507 an unedited file of an earlier release names no framework entry, on every stack' {
    # The 5.1 variants are the case above; these are the pwsh files of 0.80.0, 0.90.0 (its guard on 'Write|Edit') and 0.98.6.
    foreach ($version in '0.80.0', '0.90.0', '0.98.6') {
        foreach ($stack in 'dotnet', 'angular', 'monorepo') {
            $t = Join-Path ([IO.Path]::GetTempPath()) ('b507-' + [guid]::NewGuid())
            try {
                New-B507Target -Target $t -Settings (Get-B507Text -Spec "v${version}:dist/$stack/.claude/settings.json") -Version $version -Stack $stack
                $out = Invoke-Installer -Dist $stack -Target $t
                Assert ($LASTEXITCODE -eq 0 -and $out -match 'Done \(update\)') "$version ${stack}: the update failed (exit $LASTEXITCODE): $out"
                $after = [IO.File]::ReadAllText((Join-Path $t '.claude/settings.json'))
                Assert ($after -ceq [IO.File]::ReadAllText((Join-Path $repoRoot "dist/$stack/.claude/settings.json"))) "$version ${stack}: the refreshed file is not the release's own"
                $notices = @(Get-B486Notices -Output $out | Where-Object { $_ -match 'hook entr' })
                Assert ($notices.Count -eq 0) "$version ${stack}: an unedited file got a NOTICE about hook entries: $($notices -join ' | ')"
            } finally { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

It 'B-507 the installer''s table of what each release shipped holds every release tag''s settings files and this tree''s' {
    # A release missing from the table, or a set it holds wrongly, would name the hook entries of every unedited file of that
    # release as the team's edits, or none of an edited one.
    $installer = Join-Path $repoRoot 'src/core/scripts/install.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($installer, [ref]$null, [ref]$null)
    $tables = @{}
    foreach ($name in '$script:SjShippedEntries', '$script:SjReleaseSets') {
        $assignment = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -ceq $name }, $true)
        Assert ($null -ne $assignment) "calibration: the installer has no $name table"
        $tables[$name] = @($assignment.Right.FindAll({ param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { [string]$_.Value })
    }
    # The installer's own reader and digest, so the table is checked as the update reads a file; each file's entry count is
    # checked against ConvertFrom-Json, so a reader that skips entries cannot pass.
    $code = New-Object System.Text.StringBuilder
    foreach ($statement in $ast.EndBlock.Statements) {
        if ($statement -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $statement.Name -match '^(Skip-SjSpace|Find-Sj\w+|ConvertFrom-SjKey|Read-Sj\w+|Get-Sj(Span|Canonical|Command|EntryDigest|FrameworkEntries)|Read-SettingsJson|Get-LfSha256)$') { [void]$code.AppendLine($statement.Extent.Text) }
        elseif ($statement -is [System.Management.Automation.Language.AssignmentStatementAst] -and $statement.Left.Extent.Text -in '$script:SjStop', '$script:SjEverShippedCommands', '$script:SjFrameworkCommands') { [void]$code.AppendLine($statement.Extent.Text) }
    }
    . ([scriptblock]::Create($code.ToString()))
    $setOf = @{}
    $readSet = {
        param([string]$Name, [string]$Text)
        $Text = $Text.TrimStart([char]0xFEFF)
        $read = Read-SettingsJson -Text $Text
        $member = @($read.Members | Where-Object { $_.Key -ceq 'hooks' })
        Assert ($read.Ok -and $member.Count -eq 1) "calibration: $Name has no readable hooks"
        $hooks = Read-SjHooks -Text $Text -Start $member[0].Start
        Assert ($null -ne $hooks) "calibration: the hooks of $Name are not laid out as the installer reads them"
        $expected = 0
        foreach ($ev in ($Text | ConvertFrom-Json).hooks.PSObject.Properties) { foreach ($group in @($ev.Value)) { $expected += $(if ($null -ne $group.hooks) { @($group.hooks).Count } else { 1 }) } }
        $set = Get-SjFrameworkEntries -Hooks $hooks -Text $Text
        Assert ($set.Count -eq $expected) "calibration: the installer read $($set.Count) framework entries of $Name where ConvertFrom-Json reads $expected entries"
        return , $set
    }
    # Every release tag's files, then this tree's under the version CHANGELOG.md opens as Unreleased.
    $points = New-Object System.Collections.Generic.List[object]
    $tags = @(& git -C $repoRoot tag --list 'v*' | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' })
    Assert ($tags.Count -ge 115) "calibration: only $($tags.Count) release tags"
    foreach ($tag in $tags) {
        $tree = @(& git -C $repoRoot ls-tree -r $tag -- dist)
        foreach ($stack in 'dotnet', 'angular', 'monorepo') {
            if (-not ($tree | Where-Object { $_ -match "`tdist/$stack/" })) { continue }
            foreach ($file in 'settings.json', 'settings.windows.json') {
                $line = @($tree | Where-Object { $_ -match "^\d+ blob ([0-9a-f]{40})`tdist/$stack/\.claude/$([regex]::Escape($file))$" })
                $set = $null
                if ($line.Count -eq 1) {
                    $oid = ($line[0] -split '\s+')[2]
                    if (-not $setOf.ContainsKey($oid)) { $setOf[$oid] = & $readSet "$tag dist/$stack/.claude/$file" (Get-B507Text -Spec $oid) }
                    $set = $setOf[$oid]
                }
                $points.Add([pscustomobject]@{ Version = $tag.Substring(1); Template = $stack; File = $file; Set = $set })
            }
        }
    }
    $unreleased = ([regex]::Match([IO.File]::ReadAllText((Join-Path $repoRoot 'CHANGELOG.md')), '(?m)^## (\d+\.\d+\.\d+) — Unreleased')).Groups[1].Value
    if ($unreleased) {
        foreach ($stack in 'dotnet', 'angular', 'monorepo') {
            foreach ($file in 'settings.json', 'settings.windows.json') {
                $path = Join-Path $repoRoot "dist/$stack/.claude/$file"
                $set = if (Test-Path -LiteralPath $path) { & $readSet "dist/$stack/.claude/$file" ([IO.File]::ReadAllText($path)) } else { $null }
                $points.Add([pscustomobject]@{ Version = $unreleased; Template = $stack; File = $file; Set = $set })
            }
        }
    }
    $find = {
        param([string[]]$Entries, [string[]]$Rows)
        $known = @{}
        foreach ($row in $Entries) { $f = $row.Split(' '); $known[$f[0]] = "$($f[1])`n$(if ($f[2] -ceq '-') { '' } else { $f[2] })" }
        $parsed = @(foreach ($row in $Rows) { $f = $row.Split(' '); [pscustomobject]@{ Template = $f[0]; File = $f[1]; From = [version]($f[2]); Digests = @($f | Select-Object -Skip 3) } })
        foreach ($p in $points) {
            $row = @($parsed | Where-Object { $_.Template -ceq $p.Template -and $_.File -ceq $p.File -and $_.From -le [version]($p.Version) } | Sort-Object From | Select-Object -Last 1)
            $want = if ($null -eq $p.Set) { '-' } else { [string[]]$d = @($p.Set | ForEach-Object { $_.Digest }); [Array]::Sort($d, [StringComparer]::Ordinal); $d -join ' ' }
            $have = if ($row.Count -eq 0) { '(no row)' } else { [string[]]$h = @($row[0].Digests); [Array]::Sort($h, [StringComparer]::Ordinal); $h -join ' ' }
            if ($want -cne $have) { "$($p.Version) $($p.Template) $($p.File): shipped '$want', the table says '$have'"; continue }
            foreach ($x in @($p.Set)) { if ($null -ne $x -and $known[$x.Digest] -cne $x.Pair) { "$($p.Version) $($p.Template) $($p.File): entry $($x.Digest) is not in the entry table under its event and matcher" } }
        }
    }
    $wrong = @(& $find $tables['$script:SjShippedEntries'] $tables['$script:SjReleaseSets'])
    Assert ($wrong.Count -eq 0) "the installer's release table does not hold what a release shipped (add a row from that version on): $($wrong -join '; ')"
    # Hostile calibration: the same check, with the row 0.98.6 reads its settings.json from taken off the table, names 0.98.6.
    $rows = $tables['$script:SjReleaseSets']
    $cut = @($rows | Where-Object { $_.StartsWith('dotnet settings.json ') -and [version]($_.Split(' ')[2]) -le [version]'0.98.6' } | Sort-Object { [version]($_.Split(' ')[2]) } | Select-Object -Last 1)
    Assert ($cut.Count -eq 1) 'calibration: no table row covers 0.98.6'
    Assert (@(& $find $tables['$script:SjShippedEntries'] @($rows | Where-Object { $_ -cne $cut[0] }) | Where-Object { $_.StartsWith('0.98.6 dotnet settings.json:') }).Count -gt 0) 'taking a row off the table did not make the check name a release it covered'
}

It 'B-507 every env variable and hook command a settings file in this repository''s history registers is in the installer''s ever-shipped lists' {
    # An entry running a command some release shipped is the framework's; one the list misses would be carried as the team's own,
    # and run beside this release's (a 5.1 or Bash registration among them).
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'src/core/scripts/install.ps1'), [ref]$null, [ref]$null)
    $listed = @{}
    foreach ($name in '$script:SjEverShippedCommands', '$script:SjEverShippedEnv') {
        $assignment = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -ceq $name }, $true)
        Assert ($null -ne $assignment) "calibration: the installer has no $name list"
        $listed[$name] = @($assignment.Right.FindAll({ param($node) $node -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | ForEach-Object { [string]$_.Value })
    }
    # Every settings file the dists, the legacy template repositories and the sources ever held, and the files as they are now.
    $paths = @('dist/*/.claude/settings.json', 'dist/*/.claude/settings.windows.json', 'legacy/*/.claude/settings.json', 'legacy/*/.claude/settings.windows.json',
        'src/core/.claude/settings.windows.json', 'src/stacks/*/files/.claude/settings.json')
    $log = @(& git -C $repoRoot log --raw --no-abbrev --format= HEAD -- @paths)
    Assert ($LASTEXITCODE -eq 0) "calibration: git log failed: $log"
    $oids = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($line in $log) {
        if ($line -match '^:\d+ \d+ ([0-9a-f]{40}) ([0-9a-f]{40}) ') { foreach ($oid in $Matches[1], $Matches[2]) { if ($oid -notmatch '^0+$') { [void]$oids.Add($oid) } } }
    }
    Assert ($oids.Count -ge 38) "calibration: the history holds only $($oids.Count) settings files"
    $files = @(foreach ($oid in $oids) { [pscustomobject]@{ Name = $oid; Text = (Get-B507Text -Spec $oid) } })
    foreach ($d in 'dotnet', 'angular', 'monorepo') {
        foreach ($relative in "dist/$d/.claude/settings.json", "src/stacks/$d/files/.claude/settings.json") { $files += [pscustomobject]@{ Name = $relative; Text = [IO.File]::ReadAllText((Join-Path $repoRoot $relative)) } }
    }
    $find = {
        param([string[]]$Commands, [string[]]$Env)
        foreach ($file in $files) {
            $json = $file.Text.TrimStart([char]0xFEFF) | ConvertFrom-Json
            foreach ($command in @(Get-B507Commands -Value $json.hooks)) { if ($Commands -cnotcontains $command) { "$($file.Name) runs '$command'" } }
            if ($json.env) { foreach ($variable in $json.env.PSObject.Properties.Name) { if ($Env -cnotcontains $variable) { "$($file.Name) sets env '$variable'" } } }
        }
    }
    $unlisted = @(& $find $listed['$script:SjEverShippedCommands'] $listed['$script:SjEverShippedEnv'] | Sort-Object -Unique)
    Assert ($unlisted.Count -eq 0) "a shipped settings file registers a command or sets a variable the installer does not list (append it there): $($unlisted -join '; ')"
    # Hostile calibration: the same check, with this release's guard command taken off the list, names it.
    $guard = @(Get-B507Commands -Value ((Get-B486Dist) | ConvertFrom-Json).hooks | Where-Object { $_ -match 'guard\.ps1' })
    Assert ($guard.Count -eq 1) 'calibration: the release does not register one guard command'
    $short = @($listed['$script:SjEverShippedCommands'] | Where-Object { $_ -cne $guard[0] })
    Assert (@(& $find $short $listed['$script:SjEverShippedEnv'] | Where-Object { $_.EndsWith("runs '$($guard[0])'") }).Count -gt 0) 'taking a listed command off the list did not make the check name it'
}

# A re-run of the installed release printed a PLAN replace line for each of its 91 files, so the three whose team edits it
# wrote over were named nowhere.
It 'B-495 an update lists a file that already holds the release''s text as unchanged, so its replace lines name only the files whose text it changes' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b495-' + [guid]::NewGuid())
    try {
        New-Item -ItemType Directory -Force -Path $t | Out-Null
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the first install failed (exit $LASTEXITCODE): $first"
        $edited = '.claude/commands/feature.md'; $crlf = '.claude/commands/fix.md'
        [IO.File]::AppendAllText((Join-Path $t $edited), "`nB495 team edit.`n")
        # A core.autocrlf checkout holds the release's text with CRLF line endings: nothing of the team's.
        $crlfPath = Join-Path $t $crlf
        [IO.File]::WriteAllText($crlfPath, ([IO.File]::ReadAllText($crlfPath) -replace "`r?`n", "`r`n"), [Text.UTF8Encoding]::new($false))
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'Done \(update\)') "the update failed (exit $LASTEXITCODE): $out"
        $replaced = @([regex]::Matches($out, '(?m)^PLAN replace (\S+)\r?$') | ForEach-Object { $_.Groups[1].Value })
        Assert ($replaced -ccontains $edited) "the plan did not name the edited file as replaced: $out"
        Assert ($replaced.Count -eq 1) "the plan lists $($replaced.Count) files as replaced where the update changes the text of one: $($replaced -join ', ')"
        Assert ($out -match "(?m)^PLAN unchanged $([regex]::Escape($crlf))\r?$") "the release's text with CRLF line endings was not listed as unchanged: $out"
        Assert ($out -match '(?m)^PLAN unchanged \.claude/settings\.json\r?$') "settings that already equal what the update writes were not listed as unchanged: $out"
        Assert-BytesEqual ([IO.File]::ReadAllBytes((Join-Path $repoRoot "dist/dotnet/$edited"))) ([IO.File]::ReadAllBytes((Join-Path $t $edited))) 'the update did not write the release''s file over the edited one'
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'UpdateDelivery2.Tests')
