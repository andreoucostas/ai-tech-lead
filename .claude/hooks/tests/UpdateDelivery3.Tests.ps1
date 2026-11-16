# The second quarter of the update-delivery cases, from B-320 to B-471 (c): UpdateDelivery.Tests.ps1 holds the
# first, UpdateDelivery2.Tests.ps1 the third and UpdateDelivery4.Tests.ps1 the fourth. Split so CI runs the quarters
# in parallel (B-510); each dot-sources _UpdateDelivery.ps1 for its fixtures and helpers. Does NOT ship.
. (Join-Path $PSScriptRoot '_UpdateDelivery.ps1')

Reset-Tests

It 'B-320 an active copy of a disabled skill that cannot be removed is the only step left undone, and the stop says so' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b320-' + [guid]::NewGuid())
    $handle = $null
    try {
        # The disabled skill's files are carried to .claude/disabled-skills before the active copy goes. A
        # held file there threw a raw error mid-update, and a stop at that point skipped the instruction
        # layout move that followed it, which a re-run then declines.
        New-ArchGeneratorTarget -Target $t
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/framework-ownership.json'))
        [IO.File]::WriteAllText((Join-Path $t 'LEARNINGS.md'), "# Learnings`n`n## Disabled framework skill: perf`n`nNot used here.`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $t 'CLAUDE.md'), "# Project`n`nB320 consumer rule.`n", [Text.UTF8Encoding]::new($false))
        $active = Join-Path $t '.claude/skills/perf'
        New-Item -ItemType Directory -Force -Path $active | Out-Null
        $held = Join-Path $active 'SKILL.md'
        [IO.File]::WriteAllText($held, "---`nname: perf`n---`n# perf`n", [Text.UTF8Encoding]::new($false))
        $handle = [IO.File]::Open($held, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 3) "a held file in a disabled skill's active copy did not stop the update with exit 3 (exit $LASTEXITCODE): $out"
        Assert ($flat -match "Could not remove the active copy of disabled skill '\.claude/skills/perf'") "the stop did not name the skill: $out"
        Assert (Test-Path -LiteralPath (Join-Path $t '.claude/disabled-skills/perf/SKILL.md')) "calibration: the disabled skill was not carried before the delete: $out"
        Assert ([IO.File]::ReadAllText((Join-Path $t 'AGENTS.md')) -match 'B320 consumer rule\.') "the stop skipped the instruction layout move: AGENTS.md does not hold the moved CLAUDE.md text: $out"
        Assert ($flat -match 'kept under \.claude/disabled-skills/perf' -and $flat -match 'delete \.claude/skills/perf by hand' -and
            $flat -match 'Every other step of this update is done') "the stop did not say where the files are kept and what is left: $out"
    } finally {
        if ($handle) { $handle.Dispose() }
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-471 (a): the writes outside the wrapped copy loop died with a raw error and exit 1, not the copy stop's exit 3 and re-run line.
function New-B471DisabledSkillTarget {
    param([Parameter(Mandatory)][string]$Target)
    New-ArchGeneratorTarget -Target $Target
    [IO.File]::WriteAllBytes((Join-Path $Target 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.86.7:dist/dotnet/framework-ownership.json'))
    [IO.File]::WriteAllText((Join-Path $Target 'LEARNINGS.md'), "# Learnings`n`n## Disabled framework skill: perf`n`nNot used here.`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $Target 'CLAUDE.md'), "# Project`n`nB471 consumer rule.`n", [Text.UTF8Encoding]::new($false))
    New-Item -ItemType Directory -Force -Path (Join-Path $Target '.claude/skills/perf') | Out-Null
    [IO.File]::WriteAllText((Join-Path $Target '.claude/skills/perf/SKILL.md'), "---`nname: perf`n---`n# perf`n", [Text.UTF8Encoding]::new($false))
}
It 'B-471 a disabled skill carry or an instruction layout move that cannot write stops with exit 3 and the re-run line, and the re-run finishes the update' {
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    foreach ($case in @(
            @{ Label = 'carry'; Denied = '.claude/disabled-skills/perf'; Named = "Could not copy '\.claude/disabled-skills/perf/SKILL\.md'" },
            @{ Label = 'layout'; Denied = '.claude/framework-update-backup/instruction-files'; Named = "Could not copy '\.claude/framework-update-backup/instruction-files/CLAUDE\.md'" })) {
        $t = Join-Path ([IO.Path]::GetTempPath()) ("b471a-$($case.Label)-" + [guid]::NewGuid())
        $folder = Join-Path $t $case.Denied
        $denied = $false
        try {
            New-B471DisabledSkillTarget -Target $t
            New-Item -ItemType Directory -Force -Path $folder | Out-Null
            & icacls $folder /deny "*${sid}:(WD,AD)" | Out-Null
            Assert ($LASTEXITCODE -eq 0) "calibration: icacls could not deny writes in $($case.Denied)"
            $denied = $true
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $exit = $LASTEXITCODE
            $flat = $out -replace '\s+', ' '
            Assert ($exit -eq 3) "$($case.Label): a write the update could not make did not stop with exit 3 (exit $exit): $out"
            Assert ($flat -match $case.Named -and $flat -match 'then re-run (pwsh|powershell\.exe) [^'']*''[^'']*install\.ps1'' -AllowDirtyTree ') "$($case.Label): the stop does not name the path and the re-run line: $out"
            & icacls $folder /remove:d "*$sid" | Out-Null
            $denied = $false
            $rerun = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
            Assert ($LASTEXITCODE -eq 0) "$($case.Label): the printed re-run did not finish the update (exit $LASTEXITCODE): $rerun"
            Assert ((Test-Path -LiteralPath (Join-Path $t '.claude/disabled-skills/perf/SKILL.md')) -and -not (Test-Path -LiteralPath (Join-Path $t '.claude/skills/perf'))) "$($case.Label): the re-run did not carry the disabled skill: $rerun"
            # Stopped inside the move, the copy has already written the template AGENTS.md, so the re-run says to merge by hand.
            $kept = (@('AGENTS.md', 'CLAUDE.md') | ForEach-Object { [IO.File]::ReadAllText((Join-Path $t $_)) }) -join "`n"
            Assert ($kept -match 'B471 consumer rule\.' -and ($rerun -match 'moved: CLAUDE\.md -> AGENTS\.md' -or $rerun -match 'LAYOUT: [^\r\n]*Merge CLAUDE\.md into AGENTS\.md by hand')) "$($case.Label): the re-run lost the project instructions, or left them unmoved without saying so: $rerun"
        } finally {
            if ($denied) { & icacls $folder /remove:d "*$sid" | Out-Null }
            Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

It 'B-252 the presentation deck stays in the framework checkout: an update removes its installed copies and points an edited one there' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b252-' + [guid]::NewGuid())
    try {
        # Every install copied four deck files (about 97 KB) into docs/presentation/, which nothing
        # installed links to; the deck now stays in the checkout under presentation/.
        foreach ($stack in 'dotnet', 'angular', 'monorepo') {
            $manifest = Get-Content -Raw -LiteralPath (Join-Path $repoRoot "dist/$stack/framework-ownership.json") | ConvertFrom-Json
            Assert (@($manifest.paths | Where-Object { ([string]$_.path) -match 'presentation' }).Count -eq 0) "$stack ownership manifest still installs the deck"
            Assert (Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/presentation/framework-briefing.html") -PathType Leaf) "$stack checkout lost the deck"
        }
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude'), (Join-Path $t 'docs/presentation') | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.89.2","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.89.2:dist/dotnet/framework-ownership.json'))
        foreach ($name in 'TALKING-POINTS.md', 'framework-briefing.html', 'framework-system-map.html', 'framework-technical.html') {
            [IO.File]::WriteAllBytes((Join-Path $t "docs/presentation/$name"), (Get-GitBlobBytes -Spec "v0.89.2:dist/dotnet/docs/presentation/$name"))
        }
        # An unmodified file in a CRLF checkout, and a consumer's edit to another.
        $map = Join-Path $t 'docs/presentation/framework-system-map.html'
        [IO.File]::WriteAllText($map, ([IO.File]::ReadAllText($map) -replace "`r?`n", "`r`n"), [Text.UTF8Encoding]::new($false))
        $talking = Join-Path $t 'docs/presentation/TALKING-POINTS.md'
        [IO.File]::AppendAllText($talking, "`nB252 consumer note.`n")
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        foreach ($name in 'framework-briefing.html', 'framework-system-map.html', 'framework-technical.html') {
            Assert (-not (Test-Path -LiteralPath (Join-Path $t "docs/presentation/$name"))) "the update left the unmodified deck file $name installed: $out"
        }
        Assert ([IO.File]::ReadAllText($talking) -match 'B252 consumer note\.') "the update removed or changed the edited talking points: $out"
        Assert ($flat -match "retained retired presentation file 'docs/presentation/TALKING-POINTS\.md' remains\. The deck is no longer installed") "the kept copy was not reported as the retired deck: $out"
        # Whitespace removed: Windows PowerShell 5.1 may wrap a long line inside the printed path.
        Assert (($out -replace '\s+', '') -match "thecurrentcopyisin'[^']*dist[\\/]dotnet[\\/]presentation'\.Delete'docs/presentation/TALKING-POINTS\.md'afterreview") "the kept copy did not name the checkout's deck folder and only its own file: $out"
        Assert ($flat -notmatch 'no replacement command') "the kept deck copy was reported as a retired command: $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t 'presentation'))) "the update installed the checkout's presentation folder: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'retired recipe skills: an update removes an unmodified copy, keeps an edited one and the folder''s consumer files, and says what remains' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('recipe-retire-' + [guid]::NewGuid())
    try {
        # 0.92.0 stops shipping the generic "add an X" recipes; /bootstrap drafts project skills instead.
        foreach ($stack in 'dotnet', 'angular', 'monorepo') {
            foreach ($name in 'add-service', 'add-component', 'register-service') {
                Assert (-not (Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/.claude/skills/$name"))) "$stack still ships $name"
            }
        }
        $service = Join-Path $t '.claude/skills/add-service/SKILL.md'
        $pattern = Join-Path $t '.claude/skills/add-service/references/project-pattern.md'
        $component = Join-Path $t '.claude/skills/add-component/SKILL.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $pattern), (Split-Path -Parent $component) | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.91.0","template":"monorepo"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.91.0:dist/monorepo/framework-ownership.json'))
        [IO.File]::WriteAllBytes($service, (Get-GitBlobBytes -Spec 'v0.91.0:dist/monorepo/.claude/skills/add-service/SKILL.md'))
        $patternBytes = [Text.UTF8Encoding]::new($false).GetBytes("# Project pattern`nRETIRE-SIDECAR consumer evidence.`n")
        [IO.File]::WriteAllBytes($pattern, $patternBytes)
        # A pre-0.77 bootstrap appended an exemplar line, so this copy matches no shipped digest.
        $componentBytes = (Get-GitBlobBytes -Spec 'v0.91.0:dist/monorepo/.claude/skills/add-component/SKILL.md') +
            [Text.UTF8Encoding]::new($false).GetBytes("For a concrete current instance in this repo, see ``src/app/orders/orders.component.ts``.`n")
        [IO.File]::WriteAllBytes($component, $componentBytes)
        # A project skill /bootstrap drafted at a retired slug is the consumer's, not a retired framework copy.
        $discovered = Join-Path $t '.claude/skills/add-entity/SKILL.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $discovered) | Out-Null
        $discoveredBytes = [Text.UTF8Encoding]::new($false).GetBytes("---`nname: add-entity`ndescription: team recipe`norigin: discovered`n---`nTEAM RECIPE`n")
        [IO.File]::WriteAllBytes($discovered, $discoveredBytes)
        $out = Invoke-Installer -Dist 'monorepo' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath $service)) "the unmodified retired add-service SKILL.md survived: $out"
        Assert (Test-B194BytesEqual $patternBytes ([IO.File]::ReadAllBytes($pattern))) "the consumer's project-pattern.md beside a retired skill changed or vanished: $out"
        Assert ($flat -match "NOTICE: framework skill 'add-service' was retired in 0\.92\.0") "the removed recipe was not reported: $out"
        Assert ($flat -match "Remove the 'add-service' line from AGENTS\.md > Common Tasks, or run /rebootstrap full") "the removal did not name the stale Common Tasks line and the forced rebootstrap: $out"
        Assert (Test-B194BytesEqual $componentBytes ([IO.File]::ReadAllBytes($component))) "the edited retired add-component SKILL.md was not kept byte-identical: $out"
        Assert ($flat -match "'\.claude/skills/add-component/SKILL\.md' sits at the slug of a framework skill retired in 0\.92\.0 and loads as a skill, unless LEARNINGS\.md disables 'add-component'") "the kept recipe was not reported as a live skill at a retired slug: $out"
        Assert (Test-B194BytesEqual $discoveredBytes ([IO.File]::ReadAllBytes($discovered))) "the discovered skill at a retired slug changed or vanished: $out"
        Assert ($flat -notmatch "'\.claude/skills/add-entity/SKILL\.md' (remains|sits at the slug)") "a discovered project skill was reported as a retired framework skill: $out"
        Assert ($flat -notmatch "'\.claude/skills/add-component/SKILL\.md' remains\. It is retired with no replacement command") "the kept recipe was reported as a retired command: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'retired prompt files: an update removes an unmodified copy, keeps an edited one and names the skill that replaces it' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('prompt-retire-' + [guid]::NewGuid())
    try {
        # 0.94.0 ships the Copilot workflows as .agents/skills wrappers; VS Code's Copilot harness loads no prompt files.
        foreach ($stack in 'dotnet', 'angular', 'monorepo') {
            Assert (-not (Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/.github/prompts"))) "$stack still ships .github/prompts"
        }
        $feature = Join-Path $t '.github/prompts/feature.prompt.md'
        $review = Join-Path $t '.github/prompts/review.prompt.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $feature), (Join-Path $t '.claude') | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.93.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/framework-ownership.json'))
        [IO.File]::WriteAllBytes($feature, (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/.github/prompts/feature.prompt.md'))
        $reviewBytes = (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/.github/prompts/review.prompt.md') +
            [Text.UTF8Encoding]::new($false).GetBytes("Also check the team's audit-log rule.`n")
        [IO.File]::WriteAllBytes($review, $reviewBytes)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath $feature)) "the unmodified retired feature prompt survived: $out"
        Assert (Test-Path -LiteralPath (Join-Path $t '.agents/skills/feature/SKILL.md') -PathType Leaf) "the update did not install the feature skill: $out"
        Assert (Test-B194BytesEqual $reviewBytes ([IO.File]::ReadAllBytes($review))) "the edited retired review prompt was not kept byte-identical: $out"
        Assert ($flat -match "retained retired prompt file '\.github/prompts/review\.prompt\.md' remains\. Its workflow now ships as the skill \.agents/skills/review/SKILL\.md, which runs \.claude/commands/review\.md") "the kept prompt was not pointed at the skill that replaces it: $out"
        Assert ($flat -notmatch "'\.github/prompts/review\.prompt\.md' remains\. It is retired with no replacement command") "the kept prompt was reported as retired with no replacement: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'renamed /security-review: an update removes the unmodified wrapper, keeps an edited command pointed at /security-gate and names the stale references in a protected file' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('security-rename-' + [guid]::NewGuid())
    try {
        # B-388: Copilot CLI and Claude Code each ship a built-in /security-review, so 0.95.0 renames this framework's to /security-gate.
        $wrapper = Join-Path $t '.agents/skills/security-review/SKILL.md'
        $command = Join-Path $t '.claude/commands/security-review.md'
        $register = Join-Path $t 'SECURITY_FINDINGS.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $wrapper), (Split-Path -Parent $command) | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.94.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/framework-ownership.json'))
        [IO.File]::WriteAllBytes($wrapper, (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/.agents/skills/security-review/SKILL.md'))
        $commandBytes = (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/.claude/commands/security-review.md') +
            [Text.UTF8Encoding]::new($false).GetBytes("Also check the team's tenant-header rule.`n")
        [IO.File]::WriteAllBytes($command, $commandBytes)
        # SECURITY_FINDINGS.md is consumer-owned: the update keeps it, so its stale names are reported, not rewritten.
        $registerBytes = (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/SECURITY_FINDINGS.md') +
            [Text.UTF8Encoding]::new($false).GetBytes("Procedure: ``.claude/commands/security-review.md``.`n")
        [IO.File]::WriteAllBytes($register, $registerBytes)
        # A prompt file kept from 0.93.0: its successor is the renamed skill, not "no replacement command".
        $prompt = Join-Path $t '.github/prompts/security-review.prompt.md'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $prompt) | Out-Null
        $promptBytes = (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/.github/prompts/security-review.prompt.md') +
            [Text.UTF8Encoding]::new($false).GetBytes("Also check the team's tenant-header rule.`n")
        [IO.File]::WriteAllBytes($prompt, $promptBytes)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath $wrapper)) "the unmodified retired security-review wrapper survived: $out"
        Assert ($flat -match "NOTICE: this update removes the unmodified '\.agents/skills/security-review/SKILL\.md': this framework's /security-review is now /security-gate") "the removal did not name the new command: $out"
        Assert (Test-Path -LiteralPath (Join-Path $t '.agents/skills/security-gate/SKILL.md') -PathType Leaf) "the update did not install the security-gate wrapper: $out"
        Assert (Test-Path -LiteralPath (Join-Path $t '.claude/commands/security-gate.md') -PathType Leaf) "the update did not install the security-gate command: $out"
        Assert (Test-B194BytesEqual $commandBytes ([IO.File]::ReadAllBytes($command))) "the edited retired security-review command was not kept byte-identical: $out"
        Assert ($flat -match "CANT-VERIFY: retained retired path '\.claude/commands/security-review\.md' remains\. This framework's /security-review is now /security-gate") "the kept command was not pointed at its successor: $out"
        Assert ($flat -notmatch "'\.claude/commands/security-review\.md' remains\. It is retired with no replacement command") "the kept command was reported as retired with no replacement: $out"
        Assert (Test-B194BytesEqual $registerBytes ([IO.File]::ReadAllBytes($register))) "the protected register changed: $out"
        # The replacement must not contain the retired name itself, or applying it never clears the report.
        Assert ($flat -match "MIGRATION: protected consumer carrier 'SECURITY_FINDINGS\.md' names retired framework path '/security-review'\. It was not overwritten; replace that reference with: /security-gate\.") "the register's stale /security-review was not reported with the bare successor: $out"
        Assert ($flat -match "replace that reference with: /security-gate\. Leave a dated history entry, or a mention that deliberately names the host's own built-in command of the old name, as it is\.") "the /security-review MIGRATION did not say which mentions to keep: $out"
        Assert ($flat -match "MIGRATION: protected consumer carrier 'SECURITY_FINDINGS\.md' names retired framework path '\.claude/commands/security-review\.md'\. It was not overwritten; replace that reference with: \.claude/commands/security-gate\.md") "the register's stale command path was not reported: $out"
        Assert (Test-B194BytesEqual $promptBytes ([IO.File]::ReadAllBytes($prompt))) "the edited retired security-review prompt was not kept byte-identical: $out"
        Assert ($flat -match "retained retired prompt file '\.github/prompts/security-review\.prompt\.md' remains\. Its workflow now ships as the skill \.agents/skills/security-gate/SKILL\.md, which runs \.claude/commands/security-gate\.md") "the kept prompt was not pointed at the renamed skill: $out"
        Assert ($flat -notmatch "'\.github/prompts/security-review\.prompt\.md' remains\. It is retired with no replacement command") "the kept prompt was reported as retired with no replacement: $out"
        foreach ($stack in 'dotnet', 'angular', 'monorepo') {
            Assert (-not (Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/.claude/commands/security-review.md"))) "$stack still ships .claude/commands/security-review.md"
            Assert (-not (Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/.agents/skills/security-review"))) "$stack still ships .agents/skills/security-review"
        }
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'a team''s own skill or file at a workflow wrapper path survives updates; an edited copy of the framework''s prompt there, or a kept skill that later takes it in, is saved, never over an older save or into Git, then replaced' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('agents-skill-' + [guid]::NewGuid())
    try {
        # .agents/skills is shared with other agents; before 0.94.0 nothing the framework shipped lived there.
        $t = New-B309GitTarget -Root $root -Name 'target' -Ignore "/.agents/skills/fix/`n/.agents/skills/review/`n"
        $utf8 = [Text.UTF8Encoding]::new($false)
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude'), (Join-Path $t '.agents/skills/review'), (Join-Path $t '.agents/skills/fix'),
            (Join-Path $t '.agents/skills/adopt'), (Join-Path $t '.agents/skills/test'), (Join-Path $t '.claude/framework-update-backup/agents-skills/adopt'),
            (Join-Path $t '.claude/framework-update-backup/agents-skills/test') | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.93.0","template":"dotnet"}', $utf8)
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/framework-ownership.json'))
        $team = Join-Path $t '.agents/skills/review/SKILL.md'
        $teamBytes = $utf8.GetBytes("---`nname: review`ndescription: Team review checklist.`n---`nTEAM REVIEW CHECKLIST`n")
        [IO.File]::WriteAllBytes($team, $teamBytes)
        $design = Join-Path $t '.agents/skills/design/SKILL.md'
        $designBytes = $utf8.GetBytes("---`nname: design`ndescription: Team design notes.`n---`nTEAM DESIGN NOTES`n")
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $design) | Out-Null
        [IO.File]::WriteAllBytes($design, $designBytes)
        # A file where a wrapper's folder goes is the team's too, and must not stall the update.
        $debt = Join-Path $t '.agents/skills/debt'
        $debtBytes = $utf8.GetBytes("TEAM DEBT NOTES`n")
        [IO.File]::WriteAllBytes($debt, $debtBytes)
        # Shipped prompts converted to skills by hand, each with a line of the team's own added.
        $convert = { param($Name) $utf8.GetBytes("---`nname: $Name`ndescription: converted`n---`n") + (Get-GitBlobBytes -Spec "v0.93.0:dist/dotnet/.github/prompts/$Name.prompt.md") + $utf8.GetBytes("TEAM EDIT for ${Name}: ask before touching src/Legacy.`n") }
        $fixBytes = [byte[]](& $convert 'fix'); $adoptBytes = [byte[]](& $convert 'adopt'); $testBytes = [byte[]](& $convert 'test'); $featureBytes = [byte[]](& $convert 'feature')
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.agents/skills/feature'), (Join-Path $t '.claude/framework-update-backup/agents-skills/feature') | Out-Null
        foreach ($pair in @(@('fix', $fixBytes), @('adopt', $adoptBytes), @('test', $testBytes), @('feature', $featureBytes))) {
            [IO.File]::WriteAllBytes((Join-Path $t ".agents/skills/$($pair[0])/SKILL.md"), [byte[]]$pair[1])
        }
        # A hard link at feature's backup path is the file itself, so it is no save: an overwrite in place would reach it.
        New-Item -ItemType HardLink -Path (Join-Path $t '.claude/framework-update-backup/agents-skills/feature/SKILL.md') -Target (Join-Path $t '.agents/skills/feature/SKILL.md') | Out-Null
        Assert ([string](Get-Item -LiteralPath (Join-Path $t '.agents/skills/feature/SKILL.md')).LinkType -eq 'HardLink') 'calibration: the feature skill is not reported as a hard link'
        # adopt's backup path holds an older, different save; test's holds this very file, as after a re-run.
        $olderAdopt = $utf8.GetBytes("OLDER TEAM COPY of adopt`n")
        [IO.File]::WriteAllBytes((Join-Path $t '.claude/framework-update-backup/agents-skills/adopt/SKILL.md'), $olderAdopt)
        [IO.File]::WriteAllBytes((Join-Path $t '.claude/framework-update-backup/agents-skills/test/SKILL.md'), $testBytes)
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $adoptHash = ([BitConverter]::ToString($sha.ComputeHash($adoptBytes))).Replace('-', '').ToLowerInvariant().Substring(0, 16)
            $featureHash = ([BitConverter]::ToString($sha.ComputeHash($featureBytes))).Replace('-', '').ToLowerInvariant().Substring(0, 16)
        } finally { $sha.Dispose() }
        $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (Test-B194BytesEqual $teamBytes ([IO.File]::ReadAllBytes($team))) "the team's own .agents/skills/review/SKILL.md was not kept byte-identical: $out"
        Assert ($flat -match "'\.agents/skills/review/SKILL\.md' is not the framework's /review wrapper, so the update kept it") "the kept team skill was not reported: $out"
        Assert (Test-B194BytesEqual $designBytes ([IO.File]::ReadAllBytes($design))) "the team's own .agents/skills/design/SKILL.md was not kept byte-identical: $out"
        Assert ((Test-Path -LiteralPath $debt -PathType Leaf) -and (Test-B194BytesEqual $debtBytes ([IO.File]::ReadAllBytes($debt)))) "the team's file at .agents/skills/debt was not kept byte-identical: $out"
        Assert ($flat -match "'\.agents/skills/debt' is a file where the framework's /debt wrapper needs a folder, so the update kept it") "the kept file at a wrapper folder was not reported: $out"
        $backups = '.claude/framework-update-backup/agents-skills'
        foreach ($case in @(@('fix', $fixBytes, "$backups/fix/SKILL.md"), @('adopt', $adoptBytes, "$backups/adopt/SKILL.$adoptHash.md"), @('test', $testBytes, "$backups/test/SKILL.md"), @('feature', $featureBytes, "$backups/feature/SKILL.$featureHash.md"))) {
            $name = $case[0]
            $shipped = [IO.File]::ReadAllBytes((Join-Path $repoRoot "dist/dotnet/.agents/skills/$name/SKILL.md"))
            Assert (Test-B194BytesEqual $shipped ([IO.File]::ReadAllBytes((Join-Path $t ".agents/skills/$name/SKILL.md")))) "the converted copy of the framework's $name prompt was not replaced by the wrapper: $out"
            $saved = Join-Path $t $case[2]
            Assert ((Test-Path -LiteralPath $saved -PathType Leaf) -and (Test-B194BytesEqual ([byte[]]$case[1]) ([IO.File]::ReadAllBytes($saved)))) "the edited converted $name copy was not saved byte-identical at $($case[2]) before it was replaced: $out"
        }
        Assert ($flat -match "the update saves it to \.claude/framework-update-backup/agents-skills/fix/SKILL\.md") "the saved fix copy was not reported: $out"
        Assert (Test-B194BytesEqual $olderAdopt ([IO.File]::ReadAllBytes((Join-Path $t "$backups/adopt/SKILL.md")))) "the older save at adopt's backup path was overwritten: $out"
        Assert ($flat -match "the update saves it to \.claude/framework-update-backup/agents-skills/adopt/SKILL\.$adoptHash\.md") "the save beside the older one was not reported: $out"
        Assert ($flat -match "'\.agents/skills/test/SKILL\.md' is already saved at \.claude/framework-update-backup/agents-skills/test/SKILL\.md") "the earlier run's save was not recognised: $out"
        Assert (@(Get-ChildItem -LiteralPath (Join-Path $t "$backups/test") -File).Count -eq 1) "an earlier run's identical save was copied again: $out"
        # No save below the backup folder may become committable, the gitignored fix skill's least of all.
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'agents-skills/fix/SKILL\.md') "the gitignored fix skill's saved copy is committable: $status"
        Assert ($status -notmatch 'framework-update-backup/') "a save under the backup folder is committable: $status"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
        Assert (Test-Path -LiteralPath (Join-Path $t '.agents/skills/bootstrap/SKILL.md') -PathType Leaf) "the update did not install the other wrappers: $out"
        # The ignore-rule warning counts the framework's own hidden wrapper and never the team's kept review skill,
        # which the same rules hide; two hidden files would print as '.agents/ (2 files)'.
        Assert ($out -match "ignore rules hide 1 of the framework's own files[^`r`n]*: \.agents/skills/fix/SKILL\.md\.") "the ignore-rule warning does not name exactly the hidden fix wrapper, so it counts the kept team skill as a framework file: $out"
        # A kept path stays out of the manifest the update writes, so the next update cannot take it for the framework's.
        $owned = (Get-Content -Raw -LiteralPath (Join-Path $t 'framework-ownership.json') | ConvertFrom-Json).paths | ForEach-Object { [string]$_.path }
        Assert (($owned -cnotcontains '.agents/skills/review/SKILL.md') -and ($owned -cnotcontains '.agents/skills/debt/SKILL.md') -and ($owned -ccontains '.agents/skills/fix/SKILL.md')) "the written manifest claims a kept team path or drops an installed wrapper: $($owned -join ', ')"
        # The team then folds the retained review prompt into its own skill, as the retained-prompt message suggests.
        $mergedBytes = [byte[]]($teamBytes + (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/.github/prompts/review.prompt.md'))
        [IO.File]::WriteAllBytes($team, $mergedBytes)
        $again = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the second update failed (exit $LASTEXITCODE): $again"
        Assert (Test-B194BytesEqual $designBytes ([IO.File]::ReadAllBytes($design))) "the second update did not keep the team's own design skill: $again"
        $reviewSave = Join-Path $t "$backups/review/SKILL.md"
        Assert ((Test-Path -LiteralPath $reviewSave -PathType Leaf) -and (Test-B194BytesEqual $mergedBytes ([IO.File]::ReadAllBytes($reviewSave)))) "the second update replaced the team's merged review skill without saving it: $again"
        Assert (Test-B194BytesEqual $debtBytes ([IO.File]::ReadAllBytes($debt))) "the second update did not keep the team's file at .agents/skills/debt: $again"
        Assert (Test-B194BytesEqual $fixBytes ([IO.File]::ReadAllBytes((Join-Path $t "$backups/fix/SKILL.md")))) "the second update changed the saved copy: $again"
        Assert (Test-B194BytesEqual $olderAdopt ([IO.File]::ReadAllBytes((Join-Path $t "$backups/adopt/SKILL.md")))) "the second update changed the older save: $again"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'a linked .agents/skills is kept by an install and by an update, which leave the wrappers out instead of refusing or writing through it' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('agents-link-' + [guid]::NewGuid())
    try {
        # A team that shares skills between agents may link .agents/skills to one folder; before 0.94.0 nothing shipped there.
        $utf8 = [Text.UTF8Encoding]::new($false)
        foreach ($mode in 'update', 'greenfield') {
            $t = Join-Path $root $mode
            $shared = Join-Path $root "$mode-shared-skills"
            $teamSkill = Join-Path $shared 'review/SKILL.md'
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $teamSkill), (Join-Path $t '.agents') | Out-Null
            $teamBytes = $utf8.GetBytes("---`nname: review`ndescription: Shared team review.`n---`nSHARED REVIEW`n")
            [IO.File]::WriteAllBytes($teamSkill, $teamBytes)
            $link = Join-Path $t '.agents/skills'
            # A junction needs no privilege on Windows; elsewhere, where New-Item makes no junction, a symbolic link stands in.
            $linkType = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
            New-Item -ItemType $linkType -Path $link -Target $shared -ErrorAction Stop | Out-Null
            $linkItem = Get-Item -Force -LiteralPath $link -ErrorAction SilentlyContinue
            Assert ($null -ne $linkItem -and (($linkItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) "calibration: no $linkType was created at .agents/skills"
            if ($mode -eq 'update') {
                New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
                [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.93.0","template":"dotnet"}', $utf8)
                [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/framework-ownership.json'))
            }
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "the $mode with a linked .agents/skills failed (exit $LASTEXITCODE): $out"
            Assert ($out -match "'\.agents/skills' is a link, which the (update|install) never writes through, so it kept the link and did not install \.agents/skills/review/SKILL\.md") "the $mode did not report the kept link: $out"
            Assert (((Get-Item -Force -LiteralPath $link).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) "the $mode replaced the link: $out"
            Assert (Test-B194BytesEqual $teamBytes ([IO.File]::ReadAllBytes($teamSkill))) "the $mode changed the team's shared skill: $out"
            Assert (@(Get-ChildItem -LiteralPath $shared -Recurse -File -Force).Count -eq 1) "the $mode wrote a wrapper through the link: $out"
            $owned = @((Get-Content -Raw -LiteralPath (Join-Path $t 'framework-ownership.json') | ConvertFrom-Json).paths | ForEach-Object { [string]$_.path })
            Assert (@($owned | Where-Object { $_.StartsWith('.agents/', [StringComparison]::Ordinal) }).Count -eq 0) "the $mode's manifest claims wrapper paths it did not install: $($owned -join ', ')"
            Assert (Test-Path -LiteralPath (Join-Path $t '.claude/commands/review.md') -PathType Leaf) "the $mode did not install the rest of the framework: $out"
        }
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Get-B393Sha16 {
    param([byte[]]$Bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant().Substring(0, 16) }
    finally { $sha.Dispose() }
}

# 0.95.0 first shipped .claude/commands/security-gate.md, docs/reference.md and docs/getting-started.md.
function New-B393Target {
    param([Parameter(Mandatory)][string]$Target, [switch]$NoManifest)
    New-Item -ItemType Directory -Force -Path (Join-Path $Target '.claude/commands'), (Join-Path $Target 'docs') | Out-Null
    [IO.File]::WriteAllText((Join-Path $Target '.claude/framework-version.json'), '{"version":"0.94.0","template":"dotnet"}', [Text.UTF8Encoding]::new($false))
    if (-not $NoManifest) { [IO.File]::WriteAllBytes((Join-Path $Target 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/framework-ownership.json')) }
    $gateBytes = [Text.UTF8Encoding]::new($false).GetBytes("# Team security gate`nOur own release checklist.`n")
    [IO.File]::WriteAllBytes((Join-Path $Target '.claude/commands/security-gate.md'), $gateBytes)
    return $gateBytes
}

It 'B-393 an update saves a team''s own file at a path the previous manifest does not own before the framework''s new file replaces it, beside an older save, once across re-runs, and out of Git when ignored' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b393-' + [guid]::NewGuid())
    try {
        $t = New-B309GitTarget -Root $root -Name 'target' -Ignore "/.claude/commands/security-gate.md`n"
        $utf8 = [Text.UTF8Encoding]::new($false)
        $backups = '.claude/framework-update-backup/files'
        $gateBytes = New-B393Target -Target $t
        $referenceBytes = $utf8.GetBytes("# Team reference`nService endpoints and owners.`n")
        $startedBytes = $utf8.GetBytes("# Team onboarding`nClone, build, run.`n")
        [IO.File]::WriteAllBytes((Join-Path $t 'docs/reference.md'), $referenceBytes)
        [IO.File]::WriteAllBytes((Join-Path $t 'docs/getting-started.md'), $startedBytes)
        # A file the previous manifest owns is the framework's: replaced as before, never saved.
        [IO.File]::WriteAllBytes((Join-Path $t 'docs/defaults.md'), (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/docs/defaults.md') + $utf8.GetBytes("edited`n"))
        # reference.md's save path holds an older, different save; getting-started.md's holds this very file, as after a re-run.
        New-Item -ItemType Directory -Force -Path (Join-Path $t "$backups/docs") | Out-Null
        $olderReference = $utf8.GetBytes("OLDER SAVE of docs/reference.md`n")
        [IO.File]::WriteAllBytes((Join-Path $t "$backups/docs/reference.md"), $olderReference)
        [IO.File]::WriteAllBytes((Join-Path $t "$backups/docs/getting-started.md"), $startedBytes)
        $referenceSave = "$backups/docs/reference.$(Get-B393Sha16 $referenceBytes).md"
        $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        foreach ($relative in '.claude/commands/security-gate.md', 'docs/reference.md', 'docs/getting-started.md') {
            Assert (Test-B194BytesEqual ([IO.File]::ReadAllBytes((Join-Path $repoRoot "dist/dotnet/$relative"))) ([IO.File]::ReadAllBytes((Join-Path $t $relative)))) "the update did not install the framework's $relative`: $out"
        }
        $gateSave = Join-Path $t "$backups/_.claude/commands/security-gate.md"
        Assert ((Test-Path -LiteralPath $gateSave -PathType Leaf) -and (Test-B194BytesEqual $gateBytes ([IO.File]::ReadAllBytes($gateSave)))) "the team's .claude/commands/security-gate.md was replaced without being saved byte-identical at $backups/_.claude/commands/security-gate.md: $out"
        Assert ($flat -match "NOTICE: '\.claude/commands/security-gate\.md' is not a file the framework wrote \(the previous framework-ownership\.json does not list it\), so the update saves it to \.claude/framework-update-backup/files/_\.claude/commands/security-gate\.md") "the save was not reported: $out"
        Assert ((Test-Path -LiteralPath (Join-Path $t $referenceSave) -PathType Leaf) -and (Test-B194BytesEqual $referenceBytes ([IO.File]::ReadAllBytes((Join-Path $t $referenceSave))))) "the team's docs/reference.md was not saved beside the older save at $referenceSave`: $out"
        Assert (Test-B194BytesEqual $olderReference ([IO.File]::ReadAllBytes((Join-Path $t "$backups/docs/reference.md")))) "the older save at docs/reference.md's save path was overwritten: $out"
        Assert ($flat -match "so the update saves it to $([regex]::Escape($referenceSave))") "the save beside the older one was not reported: $out"
        Assert ($flat -match "NOTICE: 'docs/getting-started\.md' is already saved at \.claude/framework-update-backup/files/docs/getting-started\.md") "the earlier run's save was not recognised: $out"
        Assert (@(Get-ChildItem -LiteralPath (Join-Path $t "$backups/docs") -File -Filter 'getting-started*').Count -eq 1) "an earlier run's identical save was copied again: $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t "$backups/docs/defaults.md"))) "a file the previous manifest owns was saved: $out"
        # The team had gitignored security-gate.md, so its saved copy must not become committable.
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/files/_\.claude/commands/security-gate\.md') "the gitignored file's saved copy is committable: $status"
        Assert ($status -notmatch 'framework-update-backup/') "a save under the backup folder is committable: $status"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
        # The update's manifest now owns those paths, so the next update replaces them as framework files and saves nothing.
        $again = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the second update failed (exit $LASTEXITCODE): $again"
        Assert (($again -replace '\s+', ' ') -notmatch 'is not a file the framework wrote|is already saved at \.claude/framework-update-backup/') "the second update saved a file the first one installed: $again"
        Assert (Test-B194BytesEqual $gateBytes ([IO.File]::ReadAllBytes($gateSave))) "the second update changed the saved copy: $again"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-393 an update refuses before any change when both save names for a team''s file at a new framework path hold other content' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b393-refuse-' + [guid]::NewGuid())
    try {
        $gateBytes = New-B393Target -Target $t
        $saves = Join-Path $t '.claude/framework-update-backup/files/_.claude/commands'
        New-Item -ItemType Directory -Force -Path $saves | Out-Null
        [IO.File]::WriteAllText((Join-Path $saves 'security-gate.md'), "OLDER SAVE ONE`n", [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $saves "security-gate.$(Get-B393Sha16 $gateBytes).md"), "OLDER SAVE TWO`n", [Text.UTF8Encoding]::new($false))
        $before = Get-B194Fingerprint -Root $t
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        Assert ($exit -eq 3) "the update did not refuse with exit 3 (exit $exit): $out"
        Assert (($out -replace '\s+', ' ') -match "ERROR: Refusing update: '\.claude/commands/security-gate\.md' must be saved before the framework's file replaces it, and both \.claude/framework-update-backup/files/_\.claude/commands/security-gate\.md and \.claude/framework-update-backup/files/_\.claude/commands/security-gate\.[0-9a-f]{16}\.md already hold other content\. .*Nothing was changed\.") "the refusal did not name both save paths: $out"
        Assert ((Get-B194Fingerprint -Root $t) -ceq $before) "the refused update changed the target: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Windows decides once per process whether it may use a path of 260 characters or more (the LongPathsEnabled setting and
# the program's manifest) and keeps the answer in the process's PEB. Clearing it there makes the process behave as on a host
# where the setting is off. PowerShell 7's .NET handles a long path itself either way. The installer runs in that process,
# as the root dispatcher runs it.
$b432Wrapper = @'
param([string]$Installer, [string]$Target)
$env:ATL_SOURCE_CHECK = 'off'
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class B432Peb {
    [StructLayout(LayoutKind.Sequential)]
    struct Pbi { public IntPtr ExitStatus; public IntPtr Peb; public IntPtr AffinityMask; public IntPtr BasePriority; public IntPtr Pid; public IntPtr ParentPid; }
    [DllImport("ntdll.dll")] static extern int NtQueryInformationProcess(IntPtr process, int infoClass, ref Pbi info, int length, out int returned);
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [DllImport("ntdll.dll")] public static extern byte RtlAreLongPathsEnabled();
    public static void ClearLongPathAware() { Pbi p = new Pbi(); int r; NtQueryInformationProcess(GetCurrentProcess(), 0, ref p, Marshal.SizeOf(p), out r); Marshal.WriteByte(p.Peb, 3, (byte)(Marshal.ReadByte(p.Peb, 3) & 0x7F)); }
}
"@
[B432Peb]::ClearLongPathAware()
Write-Output "B432-LONG-PATHS=$([B432Peb]::RtlAreLongPathsEnabled())"
& $Installer -Target $Target
exit $LASTEXITCODE
'@
It 'B-432 without Windows long-path support an update under PowerShell 7 saves the team file at a save path of 260 characters or more' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b432-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        # 195 characters: every file the release ships fits below 260, and the team file's save path does not.
        $t = $root
        while ($t.Length -lt 183) { $t = Join-Path $t 'deepfolder' }
        $t = Join-Path $t ('t' * (194 - $t.Length))
        $gateBytes = New-B393Target -Target $t
        $save = Join-Path $t '.claude/framework-update-backup/files/_.claude/commands/security-gate.md'
        Assert ($t.Length -eq 195 -and $save.Length -ge 260 -and ($t.Length + 1 + 52) -lt 260) "calibration: the target is $($t.Length) characters and its save path $($save.Length)"
        $wrapper = Join-Path $root 'b432-wrapper.ps1'
        [IO.File]::WriteAllText($wrapper, $b432Wrapper, [Text.UTF8Encoding]::new($true))
        $run = Invoke-RawProcess -FileName (Get-PsExe) -Arguments @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $wrapper, '-Installer', (Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'), '-Target', $t)
        $out = $run.Out + "`n" + $run.Err
        $exit = $run.Exit
        Assert ($out -match 'B432-LONG-PATHS=0') "calibration: the process still has long-path support: $out"
        Assert ($exit -eq 0) "the update failed (exit $exit): $out"
        Assert ((Test-Path -LiteralPath $save -PathType Leaf) -and (Test-B194BytesEqual $gateBytes ([IO.File]::ReadAllBytes($save)))) "the team's file was not saved at its long save path: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-393 a link never carries a save: a linked folder on a new framework path refuses the update unchanged, and a hard link at the save path is no save' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b393-link-' + [guid]::NewGuid())
    try {
        # A junction needs no privilege on Windows; elsewhere, where New-Item makes no junction, a symbolic link stands in.
        $linkType = if ($env:OS -eq 'Windows_NT') { 'Junction' } else { 'SymbolicLink' }
        $linked = Join-Path $root 'linked'
        [void](New-B393Target -Target $linked)
        $shared = Join-Path $root 'shared-docs'
        New-Item -ItemType Directory -Force -Path $shared | Out-Null
        $sharedBytes = [Text.UTF8Encoding]::new($false).GetBytes("# Shared team reference`n")
        [IO.File]::WriteAllBytes((Join-Path $shared 'reference.md'), $sharedBytes)
        Remove-Item -LiteralPath (Join-Path $linked 'docs') -Recurse -Force
        New-Item -ItemType $linkType -Path (Join-Path $linked 'docs') -Target $shared -ErrorAction Stop | Out-Null
        $out = Invoke-Installer -Dist 'dotnet' -Target $linked
        $exit = $LASTEXITCODE
        Assert ($exit -eq 3 -and $out -match 'reparse/symlink') "the update over a linked docs folder did not refuse at the link (exit $exit): $out"
        Assert (Test-B194BytesEqual $sharedBytes ([IO.File]::ReadAllBytes((Join-Path $shared 'reference.md')))) "the update changed the file behind the link: $out"
        Assert (@(Get-ChildItem -LiteralPath $shared -Force).Count -eq 1) "the update wrote through the link: $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $linked '.claude/framework-update-backup'))) "the refused update saved a file: $out"
        # A hard link at the save path is the file itself, so it is no save: the replacement in place would reach it.
        $hard = Join-Path $root 'hard'
        $gateBytes = New-B393Target -Target $hard
        $saves = Join-Path $hard '.claude/framework-update-backup/files/_.claude/commands'
        New-Item -ItemType Directory -Force -Path $saves | Out-Null
        New-Item -ItemType HardLink -Path (Join-Path $saves 'security-gate.md') -Target (Join-Path $hard '.claude/commands/security-gate.md') | Out-Null
        Assert ([string](Get-Item -LiteralPath (Join-Path $hard '.claude/commands/security-gate.md')).LinkType -eq 'HardLink') 'calibration: the team file is not reported as a hard link'
        $out = Invoke-Installer -Dist 'dotnet' -Target $hard
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $beside = Join-Path $saves "security-gate.$(Get-B393Sha16 $gateBytes).md"
        Assert ((Test-Path -LiteralPath $beside -PathType Leaf) -and (Test-B194BytesEqual $gateBytes ([IO.File]::ReadAllBytes($beside)))) "the team file was not saved beside the hard link at its save path: $out"
        Assert (($out -replace '\s+', ' ') -notmatch "is already saved at") "a hard link at the save path counted as a save: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-393 without a usable previous manifest an update saves every file that differs from the release before replacing it, in one summary line' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b393-additive-' + [guid]::NewGuid())
    try {
        $utf8 = [Text.UTF8Encoding]::new($false)
        $gateBytes = New-B393Target -Target $t -NoManifest
        $versionBytes = [IO.File]::ReadAllBytes((Join-Path $t '.claude/framework-version.json'))
        $defaultsBytes = (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/docs/defaults.md') + $utf8.GetBytes("edited`n")
        [IO.File]::WriteAllBytes((Join-Path $t 'docs/defaults.md'), $defaultsBytes)
        # The release's own bytes with CRLF line endings, as a core.autocrlf checkout holds them: nothing to save.
        $latin1 = [Text.Encoding]::GetEncoding(28591)
        $shipped = $latin1.GetString([IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/docs/reference.md'))).Replace("`r`n", "`n")
        [IO.File]::WriteAllBytes((Join-Path $t 'docs/reference.md'), $latin1.GetBytes($shipped.Replace("`n", "`r`n")))
        [IO.File]::WriteAllText((Join-Path $t '.claude/settings.json'), "{`"consumerEdit`":`"recover me`"}`n", $utf8)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $backups = Join-Path $t '.claude/framework-update-backup/files'
        foreach ($case in @(@('_.claude/commands/security-gate.md', $gateBytes), @('docs/defaults.md', $defaultsBytes), @('_.claude/framework-version.json', $versionBytes))) {
            $saved = Join-Path $backups $case[0]
            Assert ((Test-Path -LiteralPath $saved -PathType Leaf) -and (Test-B194BytesEqual ([byte[]]$case[1]) ([IO.File]::ReadAllBytes($saved)))) "$($case[0]) differed from the release and was not saved byte-identical: $out"
        }
        Assert (-not (Test-Path -LiteralPath (Join-Path $backups 'docs/reference.md'))) "a file differing only in line endings was saved: $out"
        Assert (@(Get-ChildItem -LiteralPath (Split-Path -Parent $backups) -Recurse -File -Filter 'settings.json').Count -eq 0) "settings.json, which has its own pre-update save, was saved twice: $out"
        Assert (@([regex]::Matches($flat, "there is no usable previous framework-ownership\.json, so the update cannot tell which files the framework wrote")).Count -eq 1) "the saves were not summed up in exactly one line: $out"
        Assert ($flat -match 'saves the 3 files that differ from this release under \.claude/framework-update-backup/files/') "the summary does not count the three saves: $out"
        Assert ($flat -notmatch 'is not a file the framework wrote') "the saves were reported one line each: $out"
        # Every saved copy stays out of Git through the backup folder's '*', whatever Git can say here.
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
        Assert ([IO.File]::ReadAllText((Join-Path (Split-Path -Parent $backups) '.gitignore')) -ceq "*`n") "the backup folder's .gitignore is not the one line '*'"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-393 no saved file can load as a live skill, command, agent or instruction: no path below the save root has a .claude, .agents or .github folder' {
    $t = Join-Path ([IO.Path]::GetTempPath()) ('b393-layout-' + [guid]::NewGuid())
    try {
        # Claude Code loads a .claude/skills folder nested anywhere it reads files; Copilot and other agents read .agents and .github.
        # Without a manifest every differing file is saved, so one update covers each shipped root. The skill backup folder
        # already exists, so the one-time skill backup does not take the edited skill instead.
        [void](New-B393Target -Target $t -NoManifest)
        $utf8 = [Text.UTF8Encoding]::new($false)
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/framework-update-backup/skills'), (Join-Path $t '.claude/agents'),
            (Join-Path $t '.claude/skills/create-adr'), (Join-Path $t '.github') | Out-Null
        foreach ($relative in '.claude/agents/test-critic.md', '.claude/skills/create-adr/SKILL.md', '.github/PULL_REQUEST_TEMPLATE.md') {
            [IO.File]::WriteAllBytes((Join-Path $t $relative), [IO.File]::ReadAllBytes((Join-Path $repoRoot "dist/dotnet/$relative")) + $utf8.GetBytes("TEAM EDIT`n"))
        }
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $saveRoot = Join-Path $t '.claude/framework-update-backup'
        $saved = @(Get-ChildItem -LiteralPath $saveRoot -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($saveRoot.Length + 1).Replace('\', '/') })
        Assert ($saved.Count -ge 4) "calibration: the update saved fewer than the four edited files: $($saved -join ', ')"
        $live = @($saved | Where-Object { @($_.Split('/') | Where-Object { $_ -in '.claude', '.agents', '.github' }).Count -gt 0 })
        Assert ($live.Count -eq 0) "saved paths recreate a folder an agent loads: $($live -join ', ')"
        foreach ($expected in 'files/_.claude/agents/test-critic.md', 'files/_.claude/skills/create-adr/SKILL.md', 'files/_.github/PULL_REQUEST_TEMPLATE.md', 'files/_.claude/commands/security-gate.md') {
            Assert ($saved -ccontains $expected) "the edited file was not saved at .claude/framework-update-backup/$expected`: $($saved -join ', ')"
        }
        Assert (($out -replace '\s+', ' ') -match 'saves the \d+ files that differ from this release under \.claude/framework-update-backup/files/') "the summary does not name where the files were saved: $out"
    } finally {
        Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-469: an update copied every file of yours it replaced, the ones the last commit already held included, and teams forgot the
# copies and committed them. A file that commit holds as it is on disk is named by the commit instead, with a line that prints it.
It 'B-469 an update copies no file of yours the last commit holds, the settings aside: each line about one names that commit and gives the file back as it was on disk, and a file the commit does not hold is still copied' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b469-' + [guid]::NewGuid())
    try {
        # 0.93.0: before the wrappers, and before 0.95.0 first shipped security-gate.md, docs/reference.md and docs/getting-started.md.
        $t = New-B309GitTarget -Root $root -Name 'target' -Ignore "/.claude/skills/my-deploy/`n"
        $utf8 = [Text.UTF8Encoding]::new($false)
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
        [IO.File]::WriteAllText((Join-Path $t '.claude/framework-version.json'), '{"version":"0.93.0","template":"dotnet"}', $utf8)
        [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/framework-ownership.json'))
        $held = [ordered]@{
            '.claude/commands/security-gate.md' = "# Team security gate`nB469 TEAM GATE`n"
            'docs/reference.md' = "# Team reference`nB469 TEAM REFERENCE`n"
            '.claude/skills/team-notes/SKILL.md' = "---`nname: team-notes`ndescription: shared notes`n---`nB469 TEAM NOTES`n"
            'CLAUDE.md' = "# Acme`n`n## Conventions`n`nB469 CONSUMER RULE.`n"
            'AGENTS.md' = "<!-- GENERATED FILE - do not edit by hand. -->`n# Agent Instructions`n`nB469 MIRROR HAND EDIT`n"
            '.claude/settings.json' = "{`n  `"defaultShell`": `"bash`",`n  `"b469Team`": `"B469 SETTINGS`"`n}`n"
        }
        $held['.agents/skills/fix/SKILL.md'] = $utf8.GetString([byte[]]($utf8.GetBytes("---`nname: fix`ndescription: converted`n---`n") + (Get-GitBlobBytes -Spec 'v0.93.0:dist/dotnet/.github/prompts/fix.prompt.md') + $utf8.GetBytes("B469 TEAM EDIT to fix`n")))
        Write-B429Files -Folder $t -Files $held
        Write-B429Files -Folder $t -Files ([ordered]@{ 'docs/getting-started.md' = "# Team onboarding`n"; '.claude/skills/my-deploy/token.txt' = "sk-live-FX-B469`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'team files'
        $head = (& git -C $t rev-parse HEAD | Out-String).Trim()
        # Checked out again as a Windows clone writes them, with CRLF line endings: the committed blobs hold LF, so each file is
        # held as a checkout writes it, not byte for byte.
        & git -C $t config core.autocrlf true
        foreach ($relative in $held.Keys) { Remove-Item -LiteralPath (Join-Path $t $relative) -Force }
        & git -C $t checkout -q -- .
        $onDisk = @{}
        foreach ($relative in $held.Keys) { $onDisk[$relative] = [IO.File]::ReadAllBytes((Join-Path $t $relative)) }
        Assert ([Text.Encoding]::ASCII.GetString($onDisk['docs/reference.md']).Contains("`r`n") -and (& git -C $t status --porcelain | Out-String).Trim() -eq '') 'calibration: the checkout did not write CRLF, or left the tree dirty'
        # Bytes no commit holds: an uncommitted edit, and a file Git ignores.
        $dirty = "# Team onboarding`nB469 UNCOMMITTED EDIT`n"
        [IO.File]::WriteAllText((Join-Path $t 'docs/getting-started.md'), $dirty, $utf8)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $wrapper = [IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/.agents/skills/fix/SKILL.md'))
        Assert ($flat -match 'moved: CLAUDE\.md -> AGENTS\.md' -and (Test-B194BytesEqual $wrapper ([IO.File]::ReadAllBytes((Join-Path $t '.agents/skills/fix/SKILL.md'))))) "calibration: the update did not replace the wrapper and move the layout: $out"
        $lines = @{}
        foreach ($relative in '.claude/commands/security-gate.md', 'docs/reference.md', '.agents/skills/fix/SKILL.md', 'CLAUDE.md', 'AGENTS.md') {
            $escaped = [regex]::Escape($relative)
            $lines[$relative] = [regex]::Match($flat, "in commit ${head}: (git -C '[^']+' (?:show ${head}:\./$escaped|checkout ${head} -- $escaped)) (prints it|puts it back)")
            Assert $lines[$relative].Success "no line names commit $head and a line that gives back $relative`: $out"
        }
        $copies = @(Get-ChildItem -LiteralPath (Join-Path $t '.claude/framework-update-backup') -Recurse -File -Force | ForEach-Object { $_.FullName.Substring($t.Length + 1).Replace('\', '/') })
        $expected = @('.claude/framework-update-backup/.gitignore', '.claude/framework-update-backup/files/docs/getting-started.md', '.claude/framework-update-backup/skills/my-deploy/token.txt')
        Assert ((@($copies | Sort-Object -CaseSensitive) -join ' | ') -ceq ($expected -join ' | ')) "the update copied a file the commit holds, or missed one it does not: $($copies -join ' | ')"
        # The settings keep their own copy whatever the commit holds (the maintainer's choice after B-469's second attack round).
        $settingsCopy = Join-Path $t '.claude/.state/settings.json.pre-update'
        Assert ((Test-Path -LiteralPath $settingsCopy -PathType Leaf) -and (Test-B194BytesEqual $onDisk['.claude/settings.json'] ([IO.File]::ReadAllBytes($settingsCopy)))) "the settings were not copied to .claude/.state/settings.json.pre-update as they were on disk: $out"
        Assert ($flat -match 'the file as it was before this update is saved in \.claude/\.state/settings\.json\.pre-update\.' -and $flat -notmatch '\.claude/settings\.json (puts it back|prints it)') "a NOTICE names a commit, not the copy, for the settings: $out"
        # What no commit holds is still copied byte for byte, out of Git.
        Assert ([IO.File]::ReadAllText((Join-Path $t '.claude/framework-update-backup/files/docs/getting-started.md')) -ceq $dirty) "the uncommitted edit was not copied as it was: $out"
        Assert ([IO.File]::ReadAllText((Join-Path $t '.claude/framework-update-backup/skills/my-deploy/token.txt')) -ceq "sk-live-FX-B469`n") "the ignored skill file was not copied as it was: $out"
        Assert ($flat -match "'docs/getting-started\.md' is not a file the framework wrote \(the previous framework-ownership\.json does not list it\), so the update saves it to \.claude/framework-update-backup/files/docs/getting-started\.md") "the copy of the uncommitted edit was not reported: $out"
        Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String) -notmatch 'framework-update-backup/') 'a copy is committable'
        # Each line, run as printed from outside the repository, gives back the bytes that were on disk, CRLF line endings
        # included: what a git show prints, sent to a file, or the file a checkout puts back.
        foreach ($relative in @($lines.Keys | Sort-Object)) {
            $line = $lines[$relative]
            if ($line.Groups[2].Value -ceq 'prints it') {
                $dump = Join-Path $root 'printed.bin'
                $null = Invoke-B469Printed -Line "$($line.Groups[1].Value) > '$dump'"
                $back = [IO.File]::ReadAllBytes($dump)
            } else {
                $null = Invoke-B469Printed -Line $line.Groups[1].Value
                $back = [IO.File]::ReadAllBytes((Join-Path $t $relative))
            }
            Assert (Test-B194BytesEqual $onDisk[$relative] $back) "the line for $relative, run as printed, does not give back the file as it was on disk ($($back.Length) bytes against $($onDisk[$relative].Length)): $($line.Groups[1].Value)"
        }
        # One line says how to list and restore the rest; its checkout, run as printed, restores a replaced file.
        $recover = [regex]::Match($flat, "recover from Git: .*?commit ${head}, HEAD when it ran.*? (git -C '[^']+' checkout ${head} -- )<path>")
        Assert $recover.Success "no recover from Git line names commit $head and the checkout that restores a file: $out"
        [IO.File]::WriteAllText((Join-Path $t 'docs/reference.md'), "overwritten`n", $utf8)
        $null = Invoke-B469Printed -Line ($recover.Groups[1].Value + 'docs/reference.md')
        Assert (Test-B194BytesEqual $onDisk['docs/reference.md'] ([IO.File]::ReadAllBytes((Join-Path $t 'docs/reference.md')))) 'the printed checkout did not restore the replaced docs/reference.md byte for byte'
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 the one-time skill backup keeps out of Git the copy of every skill file Git ignores, a name Git would read as a pattern included, and says so in one line' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-' + [guid]::NewGuid())
    try {
        # A team's personal skill, gitignored with a key beside it: the update's skill backup copied it where Git can commit it, with no notice.
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        $utf8 = [Text.UTF8Encoding]::new($false)
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/skills/my-deploy'), (Join-Path $t '.claude/skills/team-notes') | Out-Null
        $secrets = @{ 'SKILL.md' = "---`nname: my-deploy`ndescription: personal deploy`n---`nUse token.txt`n"; 'token.txt' = "sk-live-FX-SECRET`n"; 'keys[prod].txt' = "PROD-FIXTURE-KEY`n" }
        foreach ($name in $secrets.Keys) { [IO.File]::WriteAllText((Join-Path $t ".claude/skills/my-deploy/$name"), $secrets[$name], $utf8) }
        # A team skill Git tracks unchanged: the last commit holds it, so it is not copied (B-469).
        [IO.File]::WriteAllText((Join-Path $t '.claude/skills/team-notes/SKILL.md'), "---`nname: team-notes`ndescription: shared notes`n---`n", $utf8)
        & git -C $t add -A
        & git -C $t commit -qm 'team skills'
        Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') 'calibration: the fixture is not clean before the update'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        foreach ($name in $secrets.Keys) {
            $copy = Join-Path $t ".claude/framework-update-backup/skills/my-deploy/$name"
            Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq $secrets[$name]) "the skill backup did not copy my-deploy/$name byte-identical: $out"
        }
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/framework-update-backup/skills/team-notes'))) "the skill backup copied a skill the last commit holds: $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/skills/my-deploy/') "a gitignored skill file's backup copy is committable: $status"
        Assert ((& git -C $t status --porcelain --ignored --untracked-files=all | Out-String) -match '!! \.claude/framework-update-backup/skills/my-deploy/token\.txt') "calibration: Git does not list the copy of token.txt as ignored, so git status is not reading the backup: $status"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 an update keeps out of Git the saved copy of a tracked file whose local changes Git is told not to see: skip-worktree at a new framework path, assume-unchanged in a skill' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-skip-' + [guid]::NewGuid())
    try {
        # check-ignore never reports a tracked path, so a local key in a file Git skips was saved where Git can commit it.
        $t = New-B429GitTarget -Root $root -Ignore "/scratch/`n"
        $utf8 = [Text.UTF8Encoding]::new($false)
        New-Item -ItemType Directory -Force -Path (Join-Path $t 'docs'), (Join-Path $t '.claude/skills/team-tool') | Out-Null
        # docs/reference.md is new in 0.95.0, so the update saves the team's file there before replacing it.
        [IO.File]::WriteAllText((Join-Path $t 'docs/reference.md'), "# Team reference template`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $t '.claude/skills/team-tool/config.json'), "{}`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $t '.claude/skills/team-tool/SKILL.md'), "---`nname: team-tool`ndescription: team tool`n---`n", $utf8)
        & git -C $t add -A
        & git -C $t commit -qm 'team files'
        & git -C $t update-index --skip-worktree docs/reference.md
        & git -C $t update-index --assume-unchanged .claude/skills/team-tool/config.json
        $reference = "# Team reference`nLOCAL-ONLY-FIXTURE-KEY`n"
        $config = "{`"key`":`"LOCAL-FIXTURE`"}`n"
        [IO.File]::WriteAllText((Join-Path $t 'docs/reference.md'), $reference, $utf8)
        [IO.File]::WriteAllText((Join-Path $t '.claude/skills/team-tool/config.json'), $config, $utf8)
        Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') 'calibration: Git sees the local changes it was told not to see'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $referenceCopy = '.claude/framework-update-backup/files/docs/reference.md'
        $configCopy = '.claude/framework-update-backup/skills/team-tool/config.json'
        foreach ($case in @(@($referenceCopy, $reference), @($configCopy, $config))) {
            $copy = Join-Path $t $case[0]
            Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq $case[1]) "the team's local content was not saved byte-identical at $($case[0]): $out"
        }
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch [regex]::Escape($referenceCopy)) "the saved copy of a skip-worktree file is committable: $status"
        Assert ($status -notmatch [regex]::Escape($configCopy)) "the backup copy of an assume-unchanged skill file is committable: $status"
        Assert ((& git -C $t status --porcelain --ignored --untracked-files=all | Out-String) -match '!! \.claude/framework-update-backup/skills/team-tool/config\.json') "calibration: Git does not list the assume-unchanged skill file's copy as ignored, so git status is not reading the backup: $status"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/framework-update-backup/skills/team-tool/SKILL.md'))) "the skill backup copied a skill file the last commit holds: $out"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# B-440: Git treats an ignored file as expendable, so checking out a branch that tracks a backup path overwrote the saved copy of a
# skip-worktree file's local content, which no commit holds, without a word (exit 0). The update names such copies so the team moves them out first.
It 'B-440 an update names each saved copy of a file whose local changes Git was told not to see, and no other, with the checkout that can overwrite it' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b440-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/scratch/`n"
        $utf8 = [Text.UTF8Encoding]::new($false)
        New-Item -ItemType Directory -Force -Path (Join-Path $t 'docs'), (Join-Path $t '.claude/skills/team-tool') | Out-Null
        # docs/reference.md is new in 0.95.0, so the update saves the team's file there before replacing it.
        [IO.File]::WriteAllText((Join-Path $t 'docs/reference.md'), "# Team reference template`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $t '.claude/skills/team-tool/config.json'), "{}`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $t '.claude/skills/team-tool/SKILL.md'), "---`nname: team-tool`ndescription: team tool`n---`n", $utf8)
        & git -C $t add -A
        & git -C $t commit -qm 'team files'
        & git -C $t update-index --skip-worktree docs/reference.md
        & git -C $t update-index --assume-unchanged .claude/skills/team-tool/config.json
        [IO.File]::WriteAllText((Join-Path $t 'docs/reference.md'), "# Team reference`nLOCAL-ONLY-FIXTURE-KEY`n", $utf8)
        [IO.File]::WriteAllText((Join-Path $t '.claude/skills/team-tool/config.json'), "{`"key`":`"LOCAL-FIXTURE`"}`n", $utf8)
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $referenceCopy = '.claude/framework-update-backup/files/docs/reference.md'
        $configCopy = '.claude/framework-update-backup/skills/team-tool/config.json'
        # The team-tool SKILL.md is tracked unchanged: the last commit holds it, so it is not copied (B-469), nor named.
        $skillCopy = '.claude/framework-update-backup/skills/team-tool/SKILL.md'
        foreach ($copy in $referenceCopy, $configCopy) { Assert (Test-Path -LiteralPath (Join-Path $t $copy) -PathType Leaf) "calibration: the update did not save $copy : $out" }
        Assert (-not (Test-Path -LiteralPath (Join-Path $t $skillCopy))) "the update copied a skill file the last commit holds: $out"
        $notice = [regex]::Match($out, "(?m)^\s*NOTICE: [^\r\n]*told not to see[^\r\n]*")
        Assert $notice.Success "no NOTICE names the saved copies of files Git was told not to see: $out"
        Assert ($notice.Value.Contains("$referenceCopy, $configCopy") -and $notice.Value -match 'checking out a branch that tracks' -and $notice.Value -match 'before you switch branches') "the NOTICE does not name both copies and the checkout that can overwrite them: $($notice.Value)"
        Assert (-not $notice.Value.Contains($skillCopy)) "the NOTICE names the copy of a file Git sees, whose content a commit holds: $($notice.Value)"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 hardening: the skill backup writes no live ignore file, so a copied .gitignore cannot re-include a kept-out copy; each name starting with . or _ gains a leading _' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-live-' + [guid]::NewGuid())
    try {
        # A personal skill gitignored whole, shipped with GitHub's VisualStudioCode.gitignore template; its launch.json holds a key.
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        $files = [ordered]@{ 'SKILL.md' = "---`nname: my-deploy`ndescription: personal deploy`n---`n"; '.gitignore' = ".vscode/*`n!.vscode/settings.json`n!.vscode/tasks.json`n!.vscode/launch.json`n!.vscode/extensions.json`n"
            '.vscode/launch.json' = "{`"configurations`":[{`"env`":{`"API_KEY`":`"sk-live-FX-SECRET`"}}]}`n"; '_notes.md' = "team notes`n" }
        Write-B429Files -Folder (Join-Path $t '.claude/skills/my-deploy') -Files $files
        & git -C $t add -A
        & git -C $t commit -qm 'framework state'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/skills/my-deploy/') "a copied .gitignore re-included a kept-out copy, so Git can commit it: $status"
        $saved = @{ 'SKILL.md' = 'SKILL.md'; '.gitignore' = '_.gitignore'; '.vscode/launch.json' = '_.vscode/launch.json'; '_notes.md' = '__notes.md' }
        foreach ($name in $files.Keys) {
            $copy = Join-Path $t ".claude/framework-update-backup/skills/my-deploy/$($saved[$name])"
            Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq $files[$name]) "my-deploy/$name was not saved byte-identical at skills/my-deploy/$($saved[$name]): $out"
        }
        $live = @(Get-ChildItem -LiteralPath (Join-Path $t '.claude/framework-update-backup/skills') -Recurse -Force | Where-Object { $_.Name.StartsWith('.') } | ForEach-Object { $_.FullName })
        Assert ($live.Count -eq 0) "the skill backup wrote a name Git or an agent reads: $($live -join ', ')"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 hardening: a skill that is its own Git clone is copied as plain files kept out of Git, never as a repository git add takes as a gitlink' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-clone-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        $deploy = Join-Path $t '.claude/skills/my-deploy'
        Write-B429Files -Folder $deploy -Files ([ordered]@{ 'SKILL.md' = "---`nname: my-deploy`ndescription: personal deploy`n---`n"; 'token.txt' = "sk-live-FX-SECRET`n" })
        & git -C $deploy init -q
        & git -C $deploy -c user.email=tests@example.invalid -c user.name=tests add SKILL.md
        & git -C $deploy -c user.email=tests@example.invalid -c user.name=tests commit -qm skill
        & git -C $t add -A
        & git -C $t commit -qm 'framework state'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/skills/my-deploy') "the copy of the clone is committable, as files or as an embedded repository: $status"
        & git -C $t add -A
        $links = @(& git -C $t ls-files -s | Where-Object { $_ -match '^160000 ' })
        Assert ($links.Count -eq 0) "git add -A took the copy for a gitlink: $($links -join ', ')"
        $copy = Join-Path $t '.claude/framework-update-backup/skills/my-deploy'
        Assert ((Test-Path -LiteralPath (Join-Path $copy '_.git/HEAD') -PathType Leaf) -and -not (Test-Path -LiteralPath (Join-Path $copy '.git'))) "the clone's .git was not copied as plain files at _.git: $out"
        Assert ([IO.File]::ReadAllText((Join-Path $copy 'token.txt')) -ceq "sk-live-FX-SECRET`n") "the clone's token.txt was not saved byte-identical: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 hardening: copies an earlier update left where Git could commit them are no reason to refuse and are kept out, a live .gitignore among them, while any other change still refuses' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-residue-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        & git -C $t add -A
        & git -C $t commit -qm 'framework state'
        # What a first update by 0.98.1 or earlier left beside a gitignored personal skill: untracked copies, its live .gitignore included.
        $residue = [ordered]@{ '.gitignore' = ".vscode/*`n!.vscode/launch.json`n"; '.vscode/launch.json' = "{`"env`":{`"API_KEY`":`"sk-live-FX-SECRET`"}}`n"; 'token.txt' = "sk-live-FX-SECRET`n" }
        $residueRoot = Join-Path $t '.claude/framework-update-backup/skills/my-deploy'
        Write-B429Files -Folder $residueRoot -Files $residue
        $before = @(& git -C $t status --porcelain --untracked-files=all | Where-Object { $_ -match 'framework-update-backup/' })
        Assert ($before.Count -eq 3) "calibration: Git does not show the three leftover copies as committable: $($before -join ' | ')"
        [IO.File]::WriteAllText((Join-Path $t 'notes.txt'), "draft`n", [Text.UTF8Encoding]::new($false))
        $refused = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 4 -and $refused -match 'Refusing to mutate a dirty Git target') "a team's own uncommitted file no longer refuses the update (exit $LASTEXITCODE): $refused"
        # The refusal keeps them out first, so the run after it has none left to count.
        Assert (($refused -replace '\s+', ' ') -match 'so Git ignores the 3 files an earlier update left under that folder, which may hold copies of files you had gitignored') "the refusal did not keep the 3 leftovers out of Git first: $refused"
        Remove-Item -LiteralPath (Join-Path $t 'notes.txt') -Force
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the framework's own leftover copies refused the update, steering the team to commit them (exit $LASTEXITCODE): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/skills/') "a leftover copy is still committable: $status"
        foreach ($name in $residue.Keys) { Assert ([IO.File]::ReadAllText((Join-Path $residueRoot $name)) -ceq $residue[$name]) "the leftover copy $name was changed or removed: $out" }
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 hardening: a skip-worktree file is found whatever the case of its folder on disk' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-case-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/scratch/`n"
        $indexed = Join-Path $t '.claude/skills/Team-Tool'
        Write-B429Files -Folder $indexed -Files ([ordered]@{ 'config.json' = "{}`n"; 'SKILL.md' = "---`nname: team-tool`ndescription: team tool`n---`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'team files'
        & git -C $t update-index --skip-worktree .claude/skills/Team-Tool/config.json
        # Renamed in case on disk only, as Explorer does it; the index keeps Team-Tool, and Git on Windows ignores the case.
        [IO.Directory]::Move($indexed, "$indexed-renaming")
        [IO.Directory]::Move("$indexed-renaming", (Join-Path $t '.claude/skills/team-tool'))
        Assert (@(Get-ChildItem -LiteralPath (Join-Path $t '.claude/skills') -Directory | ForEach-Object { $_.Name }) -ccontains 'team-tool') 'calibration: the folder was not renamed in case on disk'
        $config = "{`"key`":`"LOCAL-FIXTURE`"}`n"
        [IO.File]::WriteAllText((Join-Path $t '.claude/skills/team-tool/config.json'), $config, [Text.UTF8Encoding]::new($false))
        Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') 'calibration: Git sees the local change it was told not to see'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/skills/team-tool/config\.json') "the copy of a skip-worktree file in a folder renamed in case is committable: $status"
        $copy = Join-Path $t '.claude/framework-update-backup/skills/team-tool/config.json'
        Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq $config) "the local content was not saved byte-identical: $out"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 hardening: a keep-out list a team saved as UTF-16 is rewritten as UTF-8 with its own lines kept, so Git reads every line' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-utf16-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        $list = Join-Path $t '.claude/framework-update-backup/.gitignore'
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $list) | Out-Null
        # What Windows PowerShell 5.1's '>' writes: UTF-16LE with a byte-order mark.
        [IO.File]::WriteAllText($list, "# team: keep local notes out`r`n/notes/`r`n", [Text.UnicodeEncoding]::new($false, $true))
        Write-B429Files -Folder (Join-Path $t '.claude/skills/my-deploy') -Files ([ordered]@{ 'SKILL.md' = "---`nname: my-deploy`ndescription: personal deploy`n---`n"; 'token.txt' = "sk-live-FX-SECRET`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'framework state'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'framework-update-backup/skills/my-deploy/') "a line appended to a UTF-16 list is lost to Git, so its copy is committable: $status"
        $bytes = [IO.File]::ReadAllBytes($list)
        Assert (($bytes -notcontains [byte]0) -and -not ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE)) 'the list is still UTF-16'
        $text = [Text.UTF8Encoding]::new($false).GetString($bytes)
        Assert ($text.Contains('# team: keep local notes out') -and $text.Contains('/notes/')) "the team's own lines were not kept: $text"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# A captured native command is decoded with the console's code page. A 65001 console decodes Git's UTF-8 correctly and
# hides a decoding flaw, so this run sets the console to another code page, as a Western European Windows has it, and
# restores it after. Without a console the chcp does nothing and the installer still runs.
function Invoke-InstallerAtCodePage {
    param([Parameter(Mandatory)][string]$Target, [Parameter(Mandatory)][int]$CodePage)
    $installer = Join-Path $repoRoot 'dist/dotnet/scripts/install.ps1'
    $before = [regex]::Match((& cmd /d /c chcp | Out-String), '\d+').Value
    try {
        $out = & cmd /d /c "chcp $CodePage >nul & `"$(Get-PsExe)`" -NoProfile -ExecutionPolicy Bypass -File `"$installer`" -Target `"$Target`"" 2>&1 | Out-String
        $exit = $LASTEXITCODE
    } finally {
        if ($before) { & cmd /d /c "chcp $before >nul" }
    }
    $global:LASTEXITCODE = $exit
    return $out
}

# What a first update by 0.98.1 or earlier left beside a gitignored personal skill holding a file with a non-ASCII name.
function New-B429NonAsciiLeftovers {
    param([Parameter(Mandatory)][string]$Root)
    $t = New-B429GitTarget -Root $Root -Ignore "/.claude/skills/my-deploy/`n"
    & git -C $t add -A
    & git -C $t commit -qm 'framework state'
    $name = 'zug' + [char]0x00E4 + 'nge.env'
    $files = [ordered]@{ 'SKILL.md' = "---`nname: my-deploy`ndescription: personal deploy`n---`n"; 'token.txt' = "sk-live-FX-ASCII`n" }
    $files[$name] = "PROD_PASSWORD=sk-live-FX-NONASCII`n"
    Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $files
    return [pscustomobject]@{ Target = $t; Name = $name; Files = $files }
}

function Assert-B429LeftoversKeptOut {
    param([Parameter(Mandatory)]$Fixture, [Parameter(Mandatory)][string]$Out, [Parameter(Mandatory)][string]$Label)
    $t = $Fixture.Target
    Assert (($Out -replace '\s+', ' ') -match ($b429BlanketLine + ' That covers the 3 files an earlier update left there where Git could commit them')) "${Label}: the three leftovers were not counted: $Out"
    $added = @(& git -C $t add -A --dry-run | Where-Object { $_ -match 'framework-update-backup/skills/' })
    Assert ($added.Count -eq 0) "${Label}: git add -A would still commit a leftover: $($added -join ' | ')"
    $list = [IO.File]::ReadAllBytes((Join-Path $t '.claude/framework-update-backup/.gitignore'))
    Assert ($list.Length -ge 2 -and $list[0] -eq 0x2A -and $list[1] -eq 0x0A) "${Label}: the backup folder's .gitignore does not start with '*'"
    foreach ($name in $Fixture.Files.Keys) {
        Assert ([IO.File]::ReadAllText((Join-Path $t ".claude/framework-update-backup/skills/my-deploy/$name")) -ceq $Fixture.Files[$name]) "${Label}: the leftover $name was changed or removed"
    }
}

It 'B-429 decoding: leftovers an earlier update left, one with a non-ASCII name Git prints quoted, are no reason to refuse and are all kept out' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-quoted-' + [guid]::NewGuid())
    try {
        $fixture = New-B429NonAsciiLeftovers -Root $root
        $out = Invoke-Installer -Dist 'dotnet' -Target $fixture.Target
        Assert ($LASTEXITCODE -eq 0) "a leftover whose name Git prints quoted refused the update, steering the team to commit it (exit $LASTEXITCODE): $out"
        Assert-B429LeftoversKeptOut -Fixture $fixture -Out $out -Label 'default quoting'
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 decoding: with core.quotePath false and the console at code page 850, a non-ASCII leftover is no reason to refuse and Git cannot commit it' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-cp850-' + [guid]::NewGuid())
    try {
        $fixture = New-B429NonAsciiLeftovers -Root $root
        & git -C $fixture.Target config core.quotePath false
        $out = Invoke-InstallerAtCodePage -Target $fixture.Target -CodePage 850
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert-B429LeftoversKeptOut -Fixture $fixture -Out $out -Label 'quotePath false at code page 850'
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# A tracked team skill whose config.json Git stores through a clean filter that redacts its token: the working file
# holds the live token, the committed blob does not, and git status is clean.
function New-B429FilteredSkill {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][ValidateSet('skill', 'root')][string]$AttributesAt)
    $t = New-B429GitTarget -Root $Root -Ignore "/scratch/`n"
    & git -C $t config filter.redact.clean 'sed -e s/sk-live-[A-Za-z0-9-]*/REDACTED/g'
    & git -C $t config filter.redact.smudge cat
    $files = [ordered]@{ 'SKILL.md' = "---`nname: team-deploy`ndescription: deploy`n---`n"; 'config.json' = "token=sk-live-FX-FILTERED`n" }
    if ($AttributesAt -eq 'skill') { $files['.gitattributes'] = "config.json filter=redact`n" }
    else { [IO.File]::WriteAllText((Join-Path $t '.gitattributes'), "/.claude/skills/team-deploy/config.json filter=redact`n", [Text.UTF8Encoding]::new($false)) }
    Write-B429Files -Folder (Join-Path $t '.claude/skills/team-deploy') -Files $files
    & git -C $t add -A
    & git -C $t commit -qm 'team skill, token redacted by a clean filter'
    return $t
}

foreach ($attributesAt in 'skill', 'root') {
    It "B-429 blanket keep-out: no copy of a file Git stores through a redacting filter, set in the $attributesAt .gitattributes, can be staged" {
        $root = Join-Path ([IO.Path]::GetTempPath()) ("b429-filter-$attributesAt-" + [guid]::NewGuid())
        try {
            $t = New-B429FilteredSkill -Root $root -AttributesAt $attributesAt
            Assert ((& git -C $t show 'HEAD:.claude/skills/team-deploy/config.json' | Out-String).Trim() -ceq 'token=REDACTED') 'calibration: the clean filter did not redact the committed blob'
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
            $copy = Join-Path $t '.claude/framework-update-backup/skills/team-deploy/config.json'
            Assert ((Test-Path -LiteralPath $copy -PathType Leaf) -and [IO.File]::ReadAllText($copy) -ceq "token=sk-live-FX-FILTERED`n") "the skill backup did not keep the working file's bytes: $out"
            & git -C $t add -A
            $staged = @(& git -C $t ls-files -s -- '.claude/framework-update-backup' | Where-Object { $_ -notmatch '\.claude/framework-update-backup/\.gitignore$' })
            Assert ($staged.Count -eq 0) "git add -A staged a backup copy, outside the filter that redacts its original: $($staged -join ' | ')"
            Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
        } finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

It 'B-429 blanket keep-out: a .gitignore a team committed under the backup folder cannot re-include a copy with its ! rule' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-negation-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/docs/reference.md`n"
        # docs/reference.md is new in 0.95.0, so the update saves the team's own ignored file there before replacing it.
        Write-B429Files -Folder $t -Files ([ordered]@{ 'docs/reference.md' = "# Team reference`nLOCAL-KEY=sk-live-FX-REFERENCE`n" })
        # An older copy's .gitignore the team once committed; its '!' line wins over any list one folder up.
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/files/docs') -Files ([ordered]@{ '.gitignore' = "!reference.md`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'framework state'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $copy = '.claude/framework-update-backup/files/docs/reference.md'
        Assert ([IO.File]::ReadAllText((Join-Path $t $copy)) -ceq "# Team reference`nLOCAL-KEY=sk-live-FX-REFERENCE`n") "the team's ignored file was not saved byte-identical at $copy`: $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch [regex]::Escape($copy)) "a committed .gitignore under the backup folder re-included the copy, so Git can commit it: $status"
        $why = (& git -C $t check-ignore --no-index -v -- $copy | Out-String).Trim()
        Assert ($LASTEXITCODE -eq 0 -and $why -match '^\.claude/framework-update-backup/\.gitignore:1:\*\s') "check-ignore --no-index does not put the copy under the backup folder's '*': $why"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
        Assert (($out -replace '\s+', ' ') -match 'Git tracks 1 file under \.claude/framework-update-backup/') "the handoff does not say the committed file under the backup folder stays tracked: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# What a first update by 0.98.1 left beside a gitignored personal skill: two untracked copies Git could commit.
$b429Residue = [ordered]@{ 'SKILL.md' = "---`nname: my-deploy`ndescription: personal deploy`n---`n"; 'token.txt' = "sk-live-FX-SECRET`n" }
$b429RefusalKeptOut = "'\*' is now the last line of \.claude/framework-update-backup/\.gitignore, so Git ignores the 2 files an earlier update left under that folder, which may hold copies of files you had gitignored"

# The refusal says "Commit": what git add -A would take is what following it commits.
function Assert-B429RefusalKeptOut {
    param([Parameter(Mandatory)][string]$Repo, [Parameter(Mandatory)][string]$Target, [Parameter(Mandatory)][string]$Out, [Parameter(Mandatory)][string]$Change)
    $added = @(& git -C $Repo add -A --dry-run)
    # A list the team tracks there is not a copy: the refusal's '*' changes it.
    Assert (@($added | Where-Object { $_ -match 'framework-update-backup/' -and $_ -notmatch "framework-update-backup/\.gitignore'" }).Count -eq 0) "following the refusal's advice would commit a leftover copy: $($added -join ' | ')"
    Assert (@($added | Where-Object { $_.Contains($Change) }).Count -eq 1) "calibration: git add -A would not take the team's own change: $($added -join ' | ')"
    Assert (($Out -replace '\s+', ' ') -match $b429RefusalKeptOut) "the refusal does not say it kept the 2 leftovers out of Git: $Out"
    Assert ($Out -notmatch 'Nothing was changed') "the refusal says nothing was changed after writing the keep-out: $Out"
    foreach ($name in $b429Residue.Keys) { Assert ([IO.File]::ReadAllText((Join-Path $Target ".claude/framework-update-backup/skills/my-deploy/$name")) -ceq $b429Residue[$name]) "the leftover $name was changed or removed" }
}

It 'B-429 refusal: a dirty target still refuses the update, but first the copies an earlier update left are kept out of Git, so committing the team change cannot commit them, and the refusal says so' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-mixed-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        & git -C $t add -A
        & git -C $t commit -qm 'framework state'
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $b429Residue
        Write-B429Files -Folder $t -Files ([ordered]@{ 'src/Feature.cs' = "class Feature {}`n" })
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 4 -and $out -match 'Refusing to mutate a dirty Git target') "the team's own uncommitted file no longer refuses the update (exit $LASTEXITCODE): $out"
        Assert-B429RefusalKeptOut -Repo $t -Target $t -Out $out -Change 'src/Feature.cs'
        $changed = @(& git -C $t status --porcelain --untracked-files=all)
        Assert ($changed.Count -eq 1 -and $changed[0] -ceq '?? src/Feature.cs') "the refusal changed more than the backup folder's .gitignore: $($changed -join ' | ')"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 refusal: in a target that is a subfolder of its repository, copies an earlier update left are no reason to refuse and are kept out, and beside a team change they are kept out before the refusal' {
    foreach ($withChange in $false, $true) {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-sub-' + [guid]::NewGuid())
        try {
            # Git prints status paths from the repository root: apps/api/.claude/framework-update-backup/...
            $repo = New-B309GitTarget -Root $root -Name 'repo' -Ignore "/scratch/`n"
            $t = Join-Path $repo 'apps/api'
            Write-B429Files -Folder $t -Files ([ordered]@{ '.gitignore' = "/.claude/skills/my-deploy/`n"; '.claude/framework-version.json' = '{"version":"0.94.0","template":"dotnet"}' })
            [IO.File]::WriteAllBytes((Join-Path $t 'framework-ownership.json'), (Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/framework-ownership.json'))
            & git -C $repo add -A
            & git -C $repo commit -qm 'framework state'
            Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $b429Residue
            if ($withChange) { Write-B429Files -Folder $t -Files ([ordered]@{ 'src/Feature.cs' = "class Feature {}`n" }) }
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            if ($withChange) {
                Assert ($LASTEXITCODE -eq 4 -and $out -match 'Refusing to mutate a dirty Git target') "with a team change: the update did not refuse (exit $LASTEXITCODE): $out"
                Assert-B429RefusalKeptOut -Repo $repo -Target $t -Out $out -Change 'apps/api/src/Feature.cs'
            } else {
                Assert ($LASTEXITCODE -eq 0) "the framework's own leftover copies refused the update in a subfolder target, steering the team to commit them (exit $LASTEXITCODE): $out"
                $added = @(& git -C $repo add -A --dry-run | Where-Object { $_ -match 'framework-update-backup/' })
                Assert ($added.Count -eq 0) "git add -A would still commit a leftover: $($added -join ' | ')"
                Assert (($out -replace '\s+', ' ') -match ($b429BlanketLine + ' That covers the 2 files an earlier update left there where Git could commit them')) "the leftovers were not counted in the keep-out line: $out"
            }
        } finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

It 'B-429 tracked copies: an update that saves nothing still says how many files Git tracks under the backup folder, that they may hold gitignored content, and how to untrack them' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-tracked-' + [guid]::NewGuid())
    try {
        # A team that committed everything after 0.98.1's update, its copy of a gitignored personal skill's token included.
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        Write-B429Files -Folder (Join-Path $t '.claude/skills/my-deploy') -Files $b429Residue
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $b429Residue
        & git -C $t add -A
        & git -C $t commit -qm 'update 0.98.1, backup folder included'
        Assert (@(& git -C $t ls-files -- .claude/framework-update-backup).Count -eq 2) 'calibration: the two copies are not tracked'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $flat = $out -replace '\s+', ' '
        Assert ($flat -match 'Git tracks 2 files under \.claude/framework-update-backup/, which may hold copies of files you had gitignored') "the update does not say Git tracks the 2 copies under the backup folder: $out"
        Assert ($flat -match 'git rm -r --cached \.claude/framework-update-backup' -and $flat -match 'stays in your Git history') "the line does not say how to untrack them, or that a committed secret stays in history: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# A team list in the backup folder that commits the saved framework files for review, as WSD-117's reopen case would.
$b429ReincludeList = "# team: commit the saved framework files for review`n!files/`n!files/**`n"
function New-B429ReincludeTarget {
    param([Parameter(Mandatory)][string]$Root)
    # docs/reference.md is new after 0.94.0, so the update saves the team's own ignored file there to files/docs/reference.md.
    $t = New-B429GitTarget -Root $Root -Ignore "/docs/reference.md`n"
    Write-B429Files -Folder $t -Files ([ordered]@{ 'docs/reference.md' = "# Team reference`nLOCAL-KEY=sk-live-FX-REFERENCE`n" })
    return $t
}

It 'B-429 blanket keep-out: a team list whose ! lines after its * re-include copies gains * as its last line, so no copy can be staged' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-star-' + [guid]::NewGuid())
    try {
        $t = New-B429ReincludeTarget -Root $root
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup') -Files ([ordered]@{ '.gitignore' = "*`n" + $b429ReincludeList })
        # The list is forced in past its own '*'; the team's file stays ignored, so no commit holds it and the update copies it (B-469).
        & git -C $t add -A
        & git -C $t add -f -- .claude/framework-update-backup/.gitignore
        & git -C $t commit -qm 'framework state, team list'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert ([IO.File]::ReadAllText((Join-Path $t '.claude/framework-update-backup/files/docs/reference.md')) -ceq "# Team reference`nLOCAL-KEY=sk-live-FX-REFERENCE`n") "the team's ignored file was not saved byte-identical: $out"
        $added = @(& git -C $t add -A --dry-run | Where-Object { $_ -match 'framework-update-backup/files/' })
        Assert ($added.Count -eq 0) "a ! line after the list's * re-included a copy, so git add -A stages it: $($added -join ' | ')"
        $lines = @([IO.File]::ReadAllText((Join-Path $t '.claude/framework-update-backup/.gitignore')) -split "`n" | Where-Object { $_.Trim() })
        Assert ($lines[-1] -ceq '*' -and $lines -ccontains '!files/**') "the list does not end with * after the team's own lines: $($lines -join ' | ')"
        Assert (($out -replace '\s+', ' ') -match $b429BlanketLine) "the handoff does not say the backup folder is kept out of Git: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 blanket keep-out: a hard-linked list in the backup folder is never written through, and the update reports CANT-VERIFY with the count of files Git can still commit there' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-hardlink-' + [guid]::NewGuid())
    try {
        $t = New-B429ReincludeTarget -Root $root
        $shared = Join-Path $root 'shared-list.txt'
        [IO.File]::WriteAllText($shared, $b429ReincludeList, [Text.UTF8Encoding]::new($false))
        New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude/framework-update-backup') | Out-Null
        New-Item -ItemType HardLink -Path (Join-Path $t '.claude/framework-update-backup/.gitignore') -Value $shared | Out-Null
        & git -C $t add -A
        & git -C $t commit -qm 'framework state, team list'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert ([IO.File]::ReadAllText($shared) -ceq $b429ReincludeList) "the update wrote through the hard link into a file outside the target: $([IO.File]::ReadAllText($shared))"
        $flat = $out -replace '\s+', ' '
        Assert ($flat -notmatch $b429BlanketLine) "the update claims Git ignores the folder although Git can commit a copy there: $out"
        Assert ($flat -match "CANT-VERIFY: every copy this update saves goes under \.claude/framework-update-backup/, but its \.gitignore is a hard link" -and $flat -match 'Git can still commit 1 file there') "the update does not report CANT-VERIFY with the 1 file Git can commit: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 tracked copies: an update never writes a copy onto a path Git tracks under the backup folder, so a rotated token is saved beside it where Git cannot stage it' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-rotated-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        $deploy = Join-Path $t '.claude/skills/my-deploy'
        Write-B429Files -Folder $deploy -Files $b429Residue
        # 0.98.1's update copied the personal skill, and the team committed everything, the backup folder included.
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $b429Residue
        & git -C $t add -A
        & git -C $t commit -qm 'update 0.98.1, backup folder included'
        # Then the team rotated the gitignored token and deleted the folder from disk, as the update's lines advise.
        $rotated = "sk-live-FX-ROTATED-V2`n"
        [IO.File]::WriteAllText((Join-Path $deploy 'token.txt'), $rotated, [Text.UTF8Encoding]::new($false))
        Remove-Item -LiteralPath (Join-Path $t '.claude/framework-update-backup') -Recurse -Force
        $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        & git -C $t add -A
        $staged = (& git -C $t diff --cached -- .claude/framework-update-backup | Out-String)
        Assert ($staged -notmatch 'ROTATED') "git add -A stages the rotated token, written onto a path Git tracks: $staged"
        $copies = @(Get-ChildItem -LiteralPath (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -File | Where-Object { [IO.File]::ReadAllText($_.FullName) -ceq $rotated })
        Assert ($copies.Count -eq 1 -and $copies[0].Name -match '^token\.[0-9a-f]{16}\.txt$') "the rotated token was not saved beside the tracked path under its SHA-256 name: $(@($copies | ForEach-Object { $_.Name }) -join ', ')"
        $flat = $out -replace '\s+', ' '
        Assert ($flat -match $b429BlanketLine -and $flat -match 'Git tracks 2 files under \.claude/framework-update-backup/') "the handoff does not say the folder is kept out and that Git tracks 2 files there: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 blanket keep-out: a read-only list in the backup folder refuses the update before any change, so its refusal that nothing was changed is true' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-readonly-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        Write-B429Files -Folder (Join-Path $t '.claude/skills/my-deploy') -Files $b429Residue
        # The team's own settings, which the update saves before the list's write; before, that save stayed behind the refusal.
        $teamList = "# team list`n/notes/`n"
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/settings.json' = "{`"team`": true}`n"; '.claude/framework-update-backup/.gitignore' = $teamList })
        & git -C $t add -A
        & git -C $t commit -qm 'framework state, team settings and list'
        $list = Join-Path $t '.claude/framework-update-backup/.gitignore'
        (Get-Item -LiteralPath $list).IsReadOnly = $true
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 3 -and ($out -replace '\s+', ' ') -match 'Nothing was changed') "the update did not refuse a read-only list saying nothing was changed (exit $LASTEXITCODE): $out"
        $changed = @(& git -C $t status --porcelain --untracked-files=all)
        Assert ($changed.Count -eq 0) "the refused update changed the tree: $($changed -join ' | ')"
        Assert ([IO.File]::ReadAllText($list) -ceq $teamList) 'the read-only list was changed'
    } finally {
        Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object { $_.IsReadOnly = $false }
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 refusal: when Git tracks the backup folder list, the refusal that ends it with * says the list is now changed and to commit it, and once committed the update runs' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-trackedlist-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/framework-update-backup/.gitignore' = "# team list`n/notes/`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'framework state, team list'
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $b429Residue
        Write-B429Files -Folder $t -Files ([ordered]@{ 'src/Feature.cs' = "class Feature {}`n" })
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 4 -and $out -match 'Refusing to mutate a dirty Git target') "the team's own uncommitted file no longer refuses the update (exit $LASTEXITCODE): $out"
        Assert-B429RefusalKeptOut -Repo $t -Target $t -Out $out -Change 'src/Feature.cs'
        Assert (($out -replace '\s+', ' ') -match 'Git tracks \.claude/framework-update-backup/\.gitignore, so that change shows in git status: commit it with your own changes') "the refusal does not say the tracked list it changed is left to commit: $out"
        & git -C $t add -A
        & git -C $t commit -qm 'commit local changes as the refusal said'
        $committed = @(& git -C $t ls-files -- .claude/framework-update-backup)
        Assert ($committed.Count -eq 1) "following the refusal committed a leftover copy: $($committed -join ' | ')"
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "after committing as the refusal said, the update still refuses (exit $LASTEXITCODE): $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 tracked copies: a tracked backup folder spelt in another case is still found, so no copy is written onto it and the update says Git tracks it' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-case-tracked-' + [guid]::NewGuid())
    try {
        $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
        & git -C $t config core.ignorecase true
        $deploy = Join-Path $t '.claude/skills/my-deploy'
        Write-B429Files -Folder $deploy -Files $b429Residue
        Write-B429Files -Folder (Join-Path $t '.claude/framework-update-backup/skills/my-deploy') -Files $b429Residue
        & git -C $t add -A
        & git -C $t commit -qm 'update 0.98.1, backup folder included'
        # Renamed in case in two steps, as git mv needs on a case-insensitive disk; Git now tracks .claude/Framework-Update-Backup/.
        & git -C $t mv .claude/framework-update-backup .claude/fub-renaming
        & git -C $t mv .claude/fub-renaming .claude/Framework-Update-Backup
        & git -C $t commit -qm 'backup folder renamed in case'
        Assert (@(& git -C $t ls-files -- .claude/Framework-Update-Backup).Count -eq 2) 'calibration: Git does not track the two copies under the renamed folder'
        $rotated = "sk-live-FX-ROTATED-V2`n"
        [IO.File]::WriteAllText((Join-Path $deploy 'token.txt'), $rotated, [Text.UTF8Encoding]::new($false))
        Remove-Item -LiteralPath (Join-Path $t '.claude/Framework-Update-Backup') -Recurse -Force
        $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        & git -C $t add -A
        $staged = (& git -C $t diff --cached -- ':(icase).claude/framework-update-backup' | Out-String)
        Assert ($staged -notmatch 'sk-live-FX-ROTATED') "git add -A stages the rotated token, written onto a path Git tracks in another case: $staged"
        Assert (($out -replace '\s+', ' ') -match 'Git tracks 2 files under \.claude/framework-update-backup/') "the update does not say Git tracks the 2 files under the folder spelt in another case: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-429 blanket keep-out: a Hidden list is written in place with its attributes kept, and a Hidden read-only one is refused before any change, naming both attributes' {
    foreach ($readOnly in $false, $true) {
        $root = Join-Path ([IO.Path]::GetTempPath()) ('b429-hidden-' + [guid]::NewGuid())
        try {
            $t = New-B429GitTarget -Root $root -Ignore "/.claude/skills/my-deploy/`n"
            Write-B429Files -Folder (Join-Path $t '.claude/skills/my-deploy') -Files $b429Residue
            # Team settings the update saves first, so a write that fails later leaves that save behind.
            $teamList = "# team list`n"
            Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/settings.json' = "{`"team`": true}`n"; '.claude/framework-update-backup/.gitignore' = $teamList })
            & git -C $t add -A
            & git -C $t commit -qm 'framework state, team settings and list'
            # What a checkout with core.hideDotFiles=true leaves: the list marked Hidden.
            $list = Get-Item -Force -LiteralPath (Join-Path $t '.claude/framework-update-backup/.gitignore')
            $list.Attributes = $list.Attributes -bor [IO.FileAttributes]::Hidden
            if ($readOnly) { $list.Attributes = $list.Attributes -bor [IO.FileAttributes]::ReadOnly }
            $out = Invoke-Installer -Dist 'dotnet' -Target $t
            $code = $LASTEXITCODE
            $after = Get-Item -Force -LiteralPath $list.FullName
            # Windows PowerShell 5.1 wraps a captured stderr line at the console width.
            $flat = $out -replace '\s+', ' '
            if ($readOnly) {
                Assert ($code -eq 3 -and $flat -match 'Nothing was changed') "a Hidden read-only list did not refuse the update before any change (exit $code): $out"
                Assert ($flat -match 'marked ReadOnly and Hidden') "the refusal does not name the list's ReadOnly and Hidden attributes: $out"
                $changed = @(& git -C $t status --porcelain --untracked-files=all)
                Assert ($changed.Count -eq 0) "the refused update changed the tree: $($changed -join ' | ')"
            } else {
                Assert ($code -eq 0) "a Hidden list stopped the update (exit $code): $out"
                $lines = @([IO.File]::ReadAllText($list.FullName) -split "`n" | Where-Object { $_.Trim() })
                Assert ($lines[-1] -ceq '*' -and $lines -ccontains '# team list') "the Hidden list does not end with * after the team's line: $($lines -join ' | ')"
                Assert (($after.Attributes -band [IO.FileAttributes]::Hidden) -ne 0) "the list lost its Hidden attribute: $($after.Attributes)"
                $added = @(& git -C $t add -A --dry-run | Where-Object { $_ -match 'framework-update-backup/skills/' })
                Assert ($added.Count -eq 0) "git add -A would commit a backup copy: $($added -join ' | ')"
            }
        } finally {
            Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue | ForEach-Object { $_.IsReadOnly = $false }
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# A team's own lines in the framework-owned .claude/.gitignore: an update replaced the file and dropped them without a word,
# so a local file they ignored, a token in .claude/mcp.local.json say, showed as committable. Carrying the old lines forward
# was beaten: a line an earlier release shipped looks like a team's, so a line a release drops never went. So the update
# writes the release's file and keeps each file Git ignored before, and would now show, ignored by one anchored line.
$b431Marker = '# Kept ignored by framework updates: files Git ignored before an update replaced this file. Each update rewrites the lines below; put your own rules in the root .gitignore.'
$b431Save = '.claude/framework-update-backup/files/_.claude/_.gitignore'
$b431Notice = "NOTICE: this update writes the framework's \.claude/\.gitignore as released\."
function New-B431Target {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][byte[]]$Ignore, [Parameter(Mandatory)][Collections.IDictionary]$Local)
    $t = New-B429GitTarget -Root $Root -Ignore "/scratch/`n"
    [IO.File]::WriteAllBytes((Join-Path $t '.claude/.gitignore'), $Ignore)
    & git -C $t add -A
    & git -C $t commit -qm 'framework state and team ignore lines'
    Write-B429Files -Folder $t -Files $Local
    return $t
}
# The 0.94.0 release's .claude/.gitignore lines, the file a team edited.
function Get-B431ReleaseLines { return @([Text.UTF8Encoding]::new($false).GetString((Get-GitBlobBytes -Spec 'v0.94.0:dist/dotnet/.claude/.gitignore')).Split([char]10) | Where-Object { $_ }) }
function Get-B431Committable { param([string]$Target) return @(& git -C $Target status --porcelain --untracked-files=all | Where-Object { $_.StartsWith('?? ') } | ForEach-Object { $_.Substring(3) }) }
# The release's bytes, then, when any file needs it, the marker and one anchored line per file.
function Get-B431Expected {
    param([string[]]$Anchors = @(), [string]$Release = (Join-Path $repoRoot 'dist/dotnet'))
    $bytes = [IO.File]::ReadAllBytes((Join-Path $Release '.claude/.gitignore'))
    if ($Anchors.Count -eq 0) { return , $bytes }
    return [byte[]]($bytes + [Text.UTF8Encoding]::new($false).GetBytes($b431Marker + "`n" + ($Anchors -join "`n") + "`n"))
}
function Get-B431Text { param([string]$Target) return [IO.File]::ReadAllText((Join-Path $Target '.claude/.gitignore')) }

It 'B-431 status: a file a team''s own line in .claude/.gitignore ignored stays ignored by one anchored line after the release''s bytes, the update says so and where the team''s version is, a commit or a copy out of Git, and a re-run changes nothing' {
    # B-469: the team's version the last commit holds is named by that commit; one with uncommitted lines is copied out of Git.
    foreach ($leg in 'committed', 'uncommitted') {
        $root = Join-Path ([IO.Path]::GetTempPath()) ("b431-$leg-" + [guid]::NewGuid())
        try {
            # The first attacking session's fixture: one line for a local MCP config holding a token.
            $team = [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) + 'mcp.local.json' -join "`n") + "`n")
            $committed = if ($leg -eq 'committed') { $team } else { [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) -join "`n") + "`n") }
            $t = New-B431Target -Root $root -Ignore $committed -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-live-FX-SECRET`"}`n" })
            $head = (& git -C $t rev-parse HEAD | Out-String).Trim()
            if ($leg -eq 'uncommitted') { [IO.File]::WriteAllBytes((Join-Path $t '.claude/.gitignore'), $team) }
            Assert ((Get-B431Committable $t).Count -eq 0) "${leg}: calibration: the token file is committable before the update"
            $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree:($leg -eq 'uncommitted')
            $flat = $out -replace '\s+', ' '
            Assert ($LASTEXITCODE -eq 0) "${leg}: the update failed (exit $LASTEXITCODE): $out"
            $committable = Get-B431Committable $t
            Assert ($committable -notcontains '.claude/mcp.local.json') "${leg}: the team's ignore line was dropped, so its token file is committable: $($committable -join ', ')"
            Assert (Test-B194BytesEqual (Get-B431Expected @('/mcp.local.json')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "${leg}: the update did not write the release's bytes, the marker, then one anchored line for the token file: $(Get-B431Text $t)"
            $where = if ($leg -eq 'committed') { "it is in commit ${head}: (git -C '[^']+' show (${head}:\./\.claude/\.gitignore)) prints it" } else { 'it is saved at ' + [regex]::Escape($b431Save) }
            $notice = [regex]::Match($flat, ($b431Notice + " Your version had lines this release's version lacks \('mcp\.local\.json'\), which no longer apply there; $where\. Git ignored 1 file below \.claude/ before this update that the release's version does not ignore, so the update keeps it ignored with one line below the line '" + [regex]::Escape($b431Marker) + "': /mcp\.local\.json\. Such a line names one file: a folder or wildcard rule of yours no longer covers a file created later\. Put rules of your own in the root \.gitignore: \.claude/\.gitignore is the framework's file, and every update rewrites it\."))
            Assert $notice.Success "${leg}: the dropped line, where the team's version is and the anchored file were not reported in one NOTICE: $out"
            if ($leg -eq 'committed') {
                Assert (-not (Test-Path -LiteralPath (Join-Path $t $b431Save))) "${leg}: the team's version, which the last commit holds, was copied to $b431Save`: $out"
                Assert (Test-B194BytesEqual $team (Get-B469ShowBytes -Target $t -Spec $notice.Groups[2].Value)) "${leg}: the line the NOTICE prints does not print the team's version byte for byte: $($notice.Groups[1].Value)"
            } else {
                Assert ((Test-Path -LiteralPath (Join-Path $t $b431Save) -PathType Leaf) -and (Test-B194BytesEqual $team ([IO.File]::ReadAllBytes((Join-Path $t $b431Save))))) "${leg}: the team's version was not saved byte-identical at $b431Save`: $out"
            }
            Assert (@($committable | Where-Object { $_ -match 'framework-update-backup/' }).Count -eq 0) "${leg}: the saved version is committable: $($committable -join ', ')"
            Assert ($flat -notmatch 'CANT-VERIFY') "${leg}: the update reported CANT-VERIFY: $out"
            $kept = [IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore'))
            $again = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
            Assert ($LASTEXITCODE -eq 0) "${leg}: the second update failed (exit $LASTEXITCODE): $again"
            Assert (Test-B194BytesEqual $kept ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "${leg}: a re-run changed the anchored section: $(Get-B431Text $t)"
            Assert (($again -replace '\s+', ' ') -notmatch "NOTICE: [^.]*\.claude/\.gitignore") "${leg}: a re-run reported the section again: $again"
            Assert ((Get-B431Committable $t) -notcontains '.claude/mcp.local.json') "${leg}: after a re-run the token file is committable: $again"
        } finally {
            Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
# GIT_LITERAL_PATHSPECS=1 makes Git read a ':(literal)' or ':(icase)' prefix as part of the file name, so the question
# "what does Git ignore below .claude/" matched nothing and the token file lost its ignore line without a word.
It 'B-461 a caller''s GIT_LITERAL_PATHSPECS around an update still keeps a file a team''s own .claude/.gitignore line ignored' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b461-' + [guid]::NewGuid())
    $prior = [Environment]::GetEnvironmentVariable('GIT_LITERAL_PATHSPECS', 'Process')
    try {
        $team = [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) + 'mcp.local.json' -join "`n") + "`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-live-FX-SECRET`"}`n" })
        Assert ((Get-B431Committable $t).Count -eq 0) 'calibration: the token file is committable before the update'
        $env:GIT_LITERAL_PATHSPECS = '1'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $exit = $LASTEXITCODE
        if ($null -eq $prior) { Remove-Item -LiteralPath Env:GIT_LITERAL_PATHSPECS -ErrorAction SilentlyContinue } else { $env:GIT_LITERAL_PATHSPECS = $prior }
        Assert ($exit -eq 0) "the update failed (exit $exit): $out"
        $committable = Get-B431Committable $t
        Assert ($committable -notcontains '.claude/mcp.local.json') "the team's ignore line was dropped, so its token file is committable: $($committable -join ', ') :: $out"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/mcp.local.json')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the update did not keep the token file ignored by one anchored line: $(Get-B431Text $t)"
    } finally {
        if ($null -eq $prior) { Remove-Item -LiteralPath Env:GIT_LITERAL_PATHSPECS -ErrorAction SilentlyContinue } else { $env:GIT_LITERAL_PATHSPECS = $prior }
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 status: no team line is copied, so a line identical to a framework line appears once, and each file another line ignored gets one anchored line with the glob characters in its name escaped' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-same-' + [guid]::NewGuid())
    try {
        $team = [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) + 'settings.local.json', '*.pem' -join "`n") + "`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/deploy.pem' = "-----FIXTURE KEY-----`n"; '.claude/keys[prod] #1 !.pem' = "-----FIXTURE KEY-----`n" })
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $committable = Get-B431Committable $t
        Assert (@($committable | Where-Object { $_ -like '.claude/*.pem' }).Count -eq 0) "the team's *.pem line was dropped, so a key file is committable: $($committable -join ', ')"
        $text = Get-B431Text $t
        Assert (@($text.Split([char]10) | Where-Object { $_ -ceq 'settings.local.json' }).Count -eq 1) "a team line identical to a framework line is written twice or not at all: $text"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/deploy.pem', '/keys\[prod\]\ \#1\ \!.pem')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the update did not write the release's bytes and one escaped anchored line per key file: $text"
        Assert (($out -replace '\s+', ' ') -notmatch 'CANT-VERIFY') "the update reported CANT-VERIFY: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 status: with a team''s ! lines in the old file, a file one re-included stays committable and each file the old lines ignored stays ignored' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-negation-' + [guid]::NewGuid())
    try {
        # Inserted after the framework's .state/ line: in this order Git ignores mcp.local.json and settings.local.json, the
        # framework's own line after the team's !settings.local.json winning, and shows shared.local.json.
        $release = Get-B431ReleaseLines
        $ownLines = @('*.local.json', '!shared.local.json', '!settings.local.json')
        $team = [Text.UTF8Encoding]::new($false).GetBytes((@($release[0..1]) + $ownLines + @($release[2..($release.Count - 1)]) -join "`n") + "`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-live-FX-SECRET`"}`n"; '.claude/settings.local.json' = "{`"env`":{`"API_KEY`":`"sk-FIXTURE`"}}`n"; '.claude/shared.local.json' = "{`"shared`":true}`n" })
        Assert (((Get-B431Committable $t) -join ',') -ceq '.claude/shared.local.json') "calibration: before the update Git does not show only shared.local.json: $((Get-B431Committable $t) -join ', ')"
        $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $committable = Get-B431Committable $t
        Assert ($committable -notcontains '.claude/mcp.local.json') "the team's *.local.json line was dropped, so its token file is committable: $($committable -join ', ')"
        Assert ($committable -notcontains '.claude/settings.local.json') "the local settings the old lines ignored are committable: $($committable -join ', ')"
        Assert ($committable -contains '.claude/shared.local.json') "a file the old lines showed is now ignored: $($committable -join ', ')"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/mcp.local.json')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the update did not write the release's bytes and one anchored line for the token file alone: $(Get-B431Text $t)"
        Assert (($out -replace '\s+', ' ') -notmatch 'CANT-VERIFY') "the update reported CANT-VERIFY: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 status: a team''s .claude/.gitignore saved with CRLF line endings and a byte-order mark: no framework line is called the team''s, and its file stays ignored by one anchored line' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-crlf-' + [guid]::NewGuid())
    try {
        # What Windows PowerShell 5.1's Set-Content -Encoding UTF8 writes, and Git reads as the same lines.
        $team = [Text.UTF8Encoding]::new($true).GetPreamble() + [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) + 'mcp.local.json' -join "`r`n") + "`r`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-live-FX-SECRET`"}`n" })
        Assert ((Get-B431Committable $t).Count -eq 0) 'calibration: Git does not read the CRLF file with a byte-order mark as ignoring the token file'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert ((Get-B431Committable $t) -notcontains '.claude/mcp.local.json') "the team's CRLF line was dropped, so its token file is committable: $out"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/mcp.local.json')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the update did not write the release's bytes and one anchored line: $(Get-B431Text $t)"
        Assert (($out -replace '\s+', ' ') -match "lacks \('mcp\.local\.json'\), which") "the NOTICE names a framework line differing only in its CR or the byte-order mark as the team's: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 status: when a release''s .claude/.gitignore no longer ignores an existing file the old one ignored, that file stays ignored by one anchored line' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-check-' + [guid]::NewGuid())
    try {
        # A release whose .claude/.gitignore re-includes local settings the 0.94.0 lines ignored.
        $framework = Join-Path $root 'framework'
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRoot 'dist/dotnet') -Destination $framework -Recurse
        [IO.File]::AppendAllText((Join-Path $framework '.claude/.gitignore'), "!settings.local.json`n", [Text.UTF8Encoding]::new($false))
        $team = [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) + 'mcp.local.json' -join "`n") + "`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-live-FX-SECRET`"}`n"; '.claude/settings.local.json' = "{`"env`":{`"API_KEY`":`"sk-FIXTURE`"}}`n" })
        $out = & (Get-PsExe) -NoProfile -File (Join-Path $framework 'scripts/install.ps1') -Target $t 2>&1 | Out-String
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        $committable = Get-B431Committable $t
        Assert ($committable -notcontains '.claude/settings.local.json' -and $committable -notcontains '.claude/mcp.local.json') "a file the old lines ignored is committable: $($committable -join ', ')"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/mcp.local.json', '/settings.local.json') -Release $framework) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the update did not write the release's bytes and one anchored line per file: $(Get-B431Text $t)"
        Assert (($out -replace '\s+', ' ') -match 'Git ignored 2 files below \.claude/ before this update that the release''s version does not ignore, so the update keeps them ignored with one line each below the line') "the NOTICE does not count the two anchored files: $out"
        Assert (($out -replace '\s+', ' ') -notmatch 'CANT-VERIFY') "the update reported CANT-VERIFY: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 status: a release that drops its own ! line and rewords a comment takes effect, so the file the ! line showed is ignored, the file is the release''s byte for byte, and the old lines are not called the team''s own' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-release-' + [guid]::NewGuid())
    try {
        # The second attacking session's fixture: release A's file is the shipped one plus '*.local.json' and '!shared.local.json';
        # release B rewords the first comment and drops the '!' line, so shared.local.json, a token, should be ignored after it.
        $utf8 = [Text.UTF8Encoding]::new($false)
        $base = [IO.File]::ReadAllText((Join-Path $repoRoot 'dist/dotnet/.claude/.gitignore'), $utf8)
        $releaseA = $base + "*.local.json`n!shared.local.json`n"
        $lines = $base.Split([char]10)
        $lines[0] = '# Hook state: runtime stamps for throttling and dedup.'
        $releaseB = ($lines -join "`n") + "*.local.json`n"
        $framework = Join-Path $root 'releaseB'
        New-Item -ItemType Directory -Force -Path $root | Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRoot 'dist/dotnet') -Destination $framework -Recurse
        [IO.File]::WriteAllText((Join-Path $framework '.claude/.gitignore'), $releaseB, $utf8)
        $t = New-B431Target -Root $root -Ignore ($utf8.GetBytes($releaseA)) -Local ([ordered]@{ '.claude/shared.local.json' = "{`"token`":`"sk-FIXTURE1`"}`n" })
        Assert ((Get-B431Committable $t) -contains '.claude/shared.local.json') 'calibration: release A does not show shared.local.json'
        $out = & (Get-PsExe) -NoProfile -File (Join-Path $framework 'scripts/install.ps1') -Target $t -AllowDirtyTree 2>&1 | Out-String
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert ((Get-B431Committable $t) -notcontains '.claude/shared.local.json') "the ! line release B dropped still shows the token file: $(Get-B431Text $t)"
        Assert ((Get-B431Text $t) -ceq $releaseB) "the file is not release B's byte for byte: $(Get-B431Text $t)"
        Assert ($flat -notmatch 'lines of your own' -and -not $flat.Contains('runtime stamps used for throttling')) "the update called release A's lines the team's own: $out"
        Assert ($flat -notmatch 'CANT-VERIFY') "the update reported CANT-VERIFY: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 status: a .claude/.gitignore an earlier update wrote, saved again with a byte-order mark, is rewritten with the same section and no NOTICE or second save' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-bom-' + [guid]::NewGuid())
    try {
        $team = [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) + 'mcp.local.json' -join "`n") + "`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-live-FX-SECRET`"}`n" })
        $first = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0) "the first update failed (exit $LASTEXITCODE): $first"
        & git -C $t add -A
        & git -C $t commit -qm 'first update'
        # An editor that writes a byte-order mark saves the file again, otherwise unchanged.
        $written = [IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore'))
        [IO.File]::WriteAllBytes((Join-Path $t '.claude/.gitignore'), [byte[]]([Text.UTF8Encoding]::new($true).GetPreamble() + $written))
        $again = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        $flat = $again -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0) "the second update failed (exit $LASTEXITCODE): $again"
        Assert ($flat -notmatch "NOTICE: [^.]*\.claude/\.gitignore") "the second update repeated a NOTICE for a file it had already handled: $again"
        Assert (@(Get-ChildItem -LiteralPath (Join-Path $t '.claude/framework-update-backup/files/_.claude') -File -Force -ErrorAction SilentlyContinue).Count -le 1) "the second update saved the file again: $again"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/mcp.local.json')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the section repeated, grew or kept the byte-order mark: $(Get-B431Text $t)"
        Assert ((Get-B431Committable $t) -notcontains '.claude/mcp.local.json') "after the second update the token file is committable: $again"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 write last: an update that stops at a file another program holds leaves the team''s .claude/.gitignore as it was, and the re-run keeps the token file it ignored out of Git' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-locked-' + [guid]::NewGuid())
    try {
        # The second attacking session's fixture: the release's lines plus the team's 'token.txt', and a script the update
        # replaces held open by another program, so the update stops at it.
        $team = [Text.UTF8Encoding]::new($false).GetBytes(((Get-B431ReleaseLines) + 'token.txt' -join "`n") + "`n")
        $t = New-B431Target -Root $root -Ignore $team -Local ([ordered]@{ 'scripts/wiki-check.ps1' = "# the team's older copy`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'older script'
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/token.txt' = "sk-FIXTURE2`n" })
        Assert ((Get-B431Committable $t).Count -eq 0) 'calibration: the token file is committable before the update'
        $held = [IO.File]::Open((Join-Path $t 'scripts/wiki-check.ps1'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try { $out = Invoke-Installer -Dist 'dotnet' -Target $t; $code = $LASTEXITCODE } finally { $held.Dispose() }
        Assert ($code -ne 0) "calibration: the update did not stop at the held file (exit $code): $out"
        Assert (Test-B194BytesEqual $team ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the stopped update had already replaced the team's .claude/.gitignore: $(Get-B431Text $t)"
        Assert ((Get-B431Committable $t) -notcontains '.claude/token.txt') "after the stopped update the token file is committable: $out"
        $again = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the re-run failed (exit $LASTEXITCODE): $again"
        Assert ((Get-B431Committable $t) -notcontains '.claude/token.txt') "after the re-run the token file is committable: $again"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/token.txt')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the re-run did not write the release's bytes and one anchored line for the token file: $(Get-B431Text $t)"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-431 write last: a .claude/.gitignore that ends with the marker and no line below it, as an update stopped between its last two writes leaves it, is named in a CANT-VERIFY line' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b431-stopped-' + [guid]::NewGuid())
    try {
        $stopped = [byte[]]([IO.File]::ReadAllBytes((Join-Path $repoRoot 'dist/dotnet/.claude/.gitignore')) + [Text.UTF8Encoding]::new($false).GetBytes($b431Marker + "`n"))
        $t = New-B431Target -Root $root -Ignore $stopped -Local ([ordered]@{ '.claude/token.txt' = "sk-FIXTURE2`n" })
        $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowDirtyTree
        Assert ($LASTEXITCODE -eq 0) "the update failed (exit $LASTEXITCODE): $out"
        Assert (($out -replace '\s+', ' ') -match ("CANT-VERIFY: '\.claude/\.gitignore' ends with the line '" + [regex]::Escape($b431Marker) + "' and no line below it, as an update that stopped between its last two writes leaves it")) "the update did not name a file an update stopped between its last two writes: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# A brownfield install archives a team's own .claude/.gitignore for /adopt and installs the framework's (B-441): B-431's rule
# then keeps each file the team's lines ignored ignored, as an update does, and the team's file stays until the last write.
function New-B441Target {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][byte[]]$Ignore, [Parameter(Mandatory)][Collections.IDictionary]$Local, [Collections.IDictionary]$Tracked = @{})
    $t = New-B309GitTarget -Root $Root -Name 'target' -Ignore "bin/`n"
    New-Item -ItemType Directory -Force -Path (Join-Path $t '.claude') | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $t '.claude/.gitignore'), $Ignore)
    Write-B429Files -Folder $t -Files $Tracked
    & git -C $t add -A
    & git -C $t commit -qm 'team claude ignore'
    Write-B429Files -Folder $t -Files $Local
    return $t
}

It 'B-441 a brownfield install over a team''s own .claude/.gitignore writes the release''s bytes, keeps the file its lines ignored ignored by one anchored line, and names the archived version in one NOTICE' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b441-' + [guid]::NewGuid())
    try {
        # B-431's implementation saw it: the team's file moved to docs/pre-adoption/, the framework's replaced it, and Git showed
        # ?? .claude/mcp.local.json while the handoff said to commit the copied files.
        $team = [Text.UTF8Encoding]::new($false).GetBytes("mcp.local.json`n")
        $t = New-B441Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-live-FX-SECRET`"}`n" })
        Assert ((Get-B431Committable $t).Count -eq 0) 'calibration: the token file is committable before the install'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        $flat = $out -replace '\s+', ' '
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: brownfield') "the brownfield install failed (exit $LASTEXITCODE): $out"
        $committable = Get-B431Committable $t
        Assert ($committable -notcontains '.claude/mcp.local.json') "the install replaced the team's .claude/.gitignore, so its token file is committable: $($committable -join ', ')"
        Assert (Test-B194BytesEqual (Get-B431Expected @('/mcp.local.json')) ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore')))) "the install did not write the release's bytes, the marker, then one anchored line for the token file: $(Get-B431Text $t)"
        Assert (Test-B194BytesEqual $team ([IO.File]::ReadAllBytes((Join-Path $t 'docs/pre-adoption/.claude/_.gitignore')))) "the team's version was not archived byte-identical: $out"
        Assert ($flat -match ("NOTICE: this install writes the framework's \.claude/\.gitignore as released\. Your version had lines this release's version lacks \('mcp\.local\.json'\), which no longer apply there; it is saved at docs/pre-adoption/\.claude/_\.gitignore\. Git ignored 1 file below \.claude/ before this install that the release's version does not ignore, so the install keeps it ignored with one line below the line '" + [regex]::Escape($b431Marker) + "': /mcp\.local\.json\.")) "the archived version and the anchored file were not named in one NOTICE: $out"
        Assert ($flat -notmatch 'CANT-VERIFY') "the install reported CANT-VERIFY: $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t '.claude/framework-update-backup'))) "a brownfield install saved a copy below the update backup folder: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-441 write last: a brownfield install that stops at a file another program holds leaves the team''s .claude/.gitignore in place, so the token file it ignored stays out of Git' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b441-held-' + [guid]::NewGuid())
    try {
        # The install archives in manifest order: .claude/.gitignore goes first, and a team script it archives later is held open.
        $team = [Text.UTF8Encoding]::new($false).GetBytes("token.txt`n")
        $t = New-B441Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/token.txt' = "sk-FIXTURE2`n" }) -Tracked ([ordered]@{ 'scripts/wiki-check.ps1' = "# the team's own script`n" })
        Assert ((Get-B431Committable $t).Count -eq 0) 'calibration: the token file is committable before the install'
        $held = [IO.File]::Open((Join-Path $t 'scripts/wiki-check.ps1'), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try { $out = Invoke-Installer -Dist 'dotnet' -Target $t -AllowMoveAside; $code = $LASTEXITCODE } finally { $held.Dispose() }
        Assert ($code -ne 0 -and ($out -replace '\s+', ' ') -match "Brownfield archive move failed for 'scripts/wiki-check\.ps1'") "calibration: the install did not stop at the held file (exit $code): $out"
        Assert ((Test-Path -LiteralPath (Join-Path $t '.claude/.gitignore') -PathType Leaf) -and (Test-B194BytesEqual $team ([IO.File]::ReadAllBytes((Join-Path $t '.claude/.gitignore'))))) "the stopped install had already taken the team's .claude/.gitignore away: $out"
        Assert ((Get-B431Committable $t) -notcontains '.claude/token.txt') "after the stopped install the token file is committable: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-435 a brownfield install keeps out of Git the archive of a tracked original whose local changes Git is told not to see: skip-worktree, and assume-unchanged under another letter case' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b435-' + [guid]::NewGuid())
    try {
        # check-ignore never reports a tracked path, so the archive of a file whose local key Git does not see was committable.
        $t = New-B309GitTarget -Root $root -Name 'target' -Ignore "bin/`n"
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/settings.json' = "{}`n"; 'claude.md' = "# team rules`n"; 'TECH_DEBT.md' = "# team debt`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'team files'
        & git -C $t update-index --skip-worktree .claude/settings.json
        & git -C $t update-index --assume-unchanged claude.md
        $local = [ordered]@{ '.claude/settings.json' = "{`"env`":{`"API_KEY`":`"sk-FIXTURE4`"}}`n"; 'claude.md' = "# team rules`nLOCAL-ONLY-FIXTURE-NOTE`n" }
        Write-B429Files -Folder $t -Files $local
        Assert ((& git -C $t status --porcelain --untracked-files=all | Out-String).Trim() -eq '') 'calibration: Git sees the local changes it was told not to see'
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: brownfield') "the brownfield install failed (exit $LASTEXITCODE): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch 'docs/pre-adoption/\.claude/settings\.json') "the archive of a skip-worktree original is committable: $status"
        Assert ($status -notmatch '(?i)docs/pre-adoption/claude\.md') "the archive of an assume-unchanged original is committable: $status"
        Assert ($status -match 'docs/pre-adoption/TECH_DEBT\.md') "calibration: the tracked team file's archive is not committable: $status"
        Assert ([IO.File]::ReadAllText((Join-Path $t 'docs/pre-adoption/.claude/settings.json')) -ceq $local['.claude/settings.json'] -and [IO.File]::ReadAllText((Join-Path $t 'docs/pre-adoption/CLAUDE.md')) -ceq $local['claude.md']) "the archives do not hold the local content: $out"
        $lines = @([IO.File]::ReadAllLines((Join-Path $t 'docs/pre-adoption/.gitignore')) | Where-Object { $_ })
        Assert (($lines -join '|') -ceq '/.claude/settings.json|/CLAUDE.md') "docs/pre-adoption/.gitignore does not hold exactly the two anchored lines: $($lines -join '|')"
        Assert ($out -match 'Kept out of Git[^\r\n]*\.claude/settings\.json' -and $out -match 'Kept out of Git[^\r\n]*CLAUDE\.md') "the handoff does not name the kept-out files: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-435 attack: a team''s own .claude/.gitignore is archived as _.gitignore, so its ! rule cannot re-include the kept-out archive of a skip-worktree settings file, and Git confirms the keep-out' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b435-live-' + [guid]::NewGuid())
    try {
        # The fresh-session attack: archived live at docs/pre-adoption/.claude/.gitignore, '!settings.json' beat the keep-out
        # line, so the archive holding the key was ?? and git add -A staged it while the handoff said "Kept out of Git".
        $team = [Text.UTF8Encoding]::new($false).GetBytes("*.local.json`n!settings.json`n")
        $t = New-B441Target -Root $root -Ignore $team -Local ([ordered]@{ '.claude/mcp.local.json' = "{`"token`":`"sk-FIXMCP`"}`n" }) -Tracked ([ordered]@{ '.claude/settings.json' = "{}`n" })
        & git -C $t update-index --skip-worktree .claude/settings.json
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/settings.json' = "{`"env`":{`"API_KEY`":`"sk-FIX9`"}}`n" })
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: brownfield') "the brownfield install failed (exit $LASTEXITCODE): $out"
        Assert (-not (Test-Path -LiteralPath (Join-Path $t 'docs/pre-adoption/.claude/.gitignore'))) "the team's .gitignore was archived where Git reads it: $out"
        Assert (Test-B194BytesEqual $team ([IO.File]::ReadAllBytes((Join-Path $t 'docs/pre-adoption/.claude/_.gitignore')))) "the team's .gitignore was not archived byte-identical as _.gitignore: $out"
        & git -C $t check-ignore -q --no-index -- docs/pre-adoption/.claude/settings.json
        Assert ($LASTEXITCODE -eq 0) "Git does not ignore the archive of the skip-worktree settings file: $out"
        $added = @(& git -C $t add -A --dry-run | Where-Object { $_ -match 'pre-adoption/\.claude/settings\.json|mcp\.local' })
        Assert ($added.Count -eq 0) "git add -A would stage a kept-out file: $($added -join ' | ')"
        Assert ($out -match 'Kept out of Git[^\r\n]*\.claude/settings\.json' -and ($out -replace '\s+', ' ') -notmatch 'CANT-VERIFY') "the handoff does not name the kept-out archive, or reports CANT-VERIFY: $out"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

It 'B-449 the handoff names a framework file the install wrote where Git is told not to see local changes (skip-worktree, or assume-unchanged under another letter case) and the two commands that clear the flags; a flagged file the install left alone is not named' {
    $root = Join-Path ([IO.Path]::GetTempPath()) ('b449-' + [guid]::NewGuid())
    try {
        # check-ignore never reports a tracked path, so the install wrote the framework's file at a flagged path, git status showed
        # nothing there, and "commit the copied files" kept the team's committed version: teammates never got the framework's.
        # One update-index naming both --no- options clears only one flag, so the handoff gives the pair and the test runs it.
        $clear = {
            param([string]$Text, [string]$Folder)
            $m = [regex]::Match($Text, 'run both  (git -C [^\r\n]+? update-index --no-skip-worktree -- [^\r\n]+?)  and  (git -C [^\r\n]+? update-index --no-assume-unchanged -- [^\r\n]+?)  \(one command naming both options clears only one flag\), then commit')
            Assert $m.Success "the handoff does not give the two commands that clear the flags: $Text"
            foreach ($i in 1, 2) { Invoke-Expression $m.Groups[$i].Value; Assert ($LASTEXITCODE -eq 0) "the printed command failed (exit ${LASTEXITCODE}): $($m.Groups[$i].Value)" }
            return (& git -C $Folder status --porcelain --untracked-files=all | Out-String)
        }

        $t = New-B309GitTarget -Root $root -Name 'brownfield' -Ignore "bin/`n"
        Write-B429Files -Folder $t -Files ([ordered]@{ '.claude/settings.json' = "{}`n"; 'claude.md' = "# team rules`n"; 'TECH_DEBT.md' = "# team debt`n" })
        & git -C $t add -A
        & git -C $t commit -qm 'team files'
        & git -C $t update-index --skip-worktree .claude/settings.json
        & git -C $t update-index --assume-unchanged claude.md
        $out = Invoke-Installer -Dist 'dotnet' -Target $t
        Assert ($LASTEXITCODE -eq 0 -and $out -match 'mode: brownfield') "the brownfield install failed (exit $LASTEXITCODE): $out"
        $status = (& git -C $t status --porcelain --untracked-files=all | Out-String)
        Assert ($status -notmatch '(?mi)^ ?M (\.claude/settings\.json|claude\.md)') "calibration: Git shows the framework's file at a flagged path: $status"
        Assert ($out -cmatch "(?m)^WARNING: Git is told not to see local changes to 2 of the framework's own files \(skip-worktree or assume-unchanged\)[^\r\n]*: \.claude/settings\.json, claude\.md\. To make Git show them, run both ") "the handoff does not name the two flagged files the install wrote: $out"
        Assert ($out -cnotmatch 'TECH_DEBT\.md[^\r\n]*\. To make Git show them') "the handoff names an unflagged file: $out"
        $after = & $clear $out $t
        Assert ($after -match '(?m)^ M \.claude/settings\.json' -and $after -match '(?m)^ M claude\.md') "after the printed commands Git still does not show the framework's files: $after"

        # An update names a flagged file it replaced, and not one it leaves alone: AGENTS.md is the team's, so it stays as it was.
        $u = New-B309GitTarget -Root $root -Name 'update' -Ignore "bin/`n"
        $first = Invoke-Installer -Dist 'dotnet' -Target $u
        Assert ($LASTEXITCODE -eq 0 -and $first -match 'mode: greenfield' -and $first -notmatch 'told not to see') "the greenfield install failed, or warned with nothing flagged (exit $LASTEXITCODE): $first"
        # A value of a key the release defines, so the update replaces it: a key the release lacks would be carried (B-486).
        Write-B429Files -Folder $u -Files ([ordered]@{ '.claude/settings.json' = "{`"defaultShell`":`"team-copy-before-b449`"}`n" })
        & git -C $u add -A
        & git -C $u commit -qm 'team install'
        & git -C $u update-index --skip-worktree .claude/settings.json
        & git -C $u update-index --assume-unchanged AGENTS.md
        $update = Invoke-Installer -Dist 'dotnet' -Target $u
        Assert ($LASTEXITCODE -eq 0 -and $update -match 'mode: update') "the update failed (exit $LASTEXITCODE): $update"
        Assert ([IO.File]::ReadAllText((Join-Path $u '.claude/settings.json')) -notmatch 'team-copy-before-b449' -and (& git -C $u show HEAD:.claude/settings.json | Out-String) -match 'team-copy-before-b449') 'calibration: the update did not replace the committed settings'
        Assert ((& git -C $u status --porcelain --untracked-files=all | Out-String) -notmatch '(?m)^ ?M \.claude/settings\.json') 'calibration: Git shows the replaced settings'
        Assert ($update -cmatch "(?m)^WARNING: Git is told not to see local changes to 1 of the framework's own files \(skip-worktree or assume-unchanged\)[^\r\n]*: \.claude/settings\.json\. To make Git show them, run both ") "the update's handoff does not name the one replaced flagged file: $update"
        Assert ($update -cnotmatch 'AGENTS\.md[^\r\n]*\. To make Git show them') "the update's handoff names a flagged file it left alone: $update"
        $afterUpdate = & $clear $update $u
        Assert ($afterUpdate -match '(?m)^ M \.claude/settings\.json') "after the printed commands Git still does not show the replaced settings: $afterUpdate"

        # Git failing that one question is "could not examine", not "nothing flagged": a git.cmd ahead on PATH fails only ls-files -v.
        $shim = Join-Path $root 'git-shim'
        [void][IO.Directory]::CreateDirectory($shim)
        $realGit = (Get-Command git -CommandType Application | Select-Object -First 1).Source
        [IO.File]::WriteAllText((Join-Path $shim 'git.cmd'), "@echo off`r`nif ""%~3""==""ls-files"" if ""%~4""==""-v"" exit /b 1`r`n""$realGit"" %*`r`n")
        $blind = New-B309GitTarget -Root $root -Name 'blind' -Ignore "bin/`n"
        $savedPath = $env:PATH
        try { $env:PATH = "$shim;$savedPath"; $blindOut = Invoke-Installer -Dist 'dotnet' -Target $blind; $blindExit = $LASTEXITCODE } finally { $env:PATH = $savedPath }
        Assert ($blindExit -eq 0 -and $blindOut -match 'mode: greenfield') "the install with a failing ls-files -v did not finish (exit $blindExit): $blindOut"
        Assert ($blindOut -cmatch "(?m)^NOTE: Git could not say whether it is told not to see local changes to any of the framework's files[^\r\n]*run  git ls-files -v  before committing") "the handoff says nothing when Git could not say whether files are flagged: $blindOut"
    } finally {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'UpdateDelivery3.Tests')
