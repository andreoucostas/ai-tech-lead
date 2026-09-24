# Asserts the AUTHORING repo's own docs describe the repo that actually exists. Does NOT ship.
#
# Why this exists: `no-meta-leak` guards what shipped docs must not say, and `no-dead-instruction`
# (validate-dist check 7) guards that shipped docs name commands that resolve. Nothing guarded the
# maintainer-facing docs -- and they had rotted in three separate ways at once (found v0.26.3):
#   * `@@INCLUDE` was documented as the composer's marker syntax in FOUR files. It has never
#     existed. The composer reads `<!-- @stack:NAME -->`. A maintainer following the docs would
#     author a marker the composer silently ignores.
#   * README claimed shipped v0.26.1 against an actual stamp of v0.26.2.
#   * `fidelity-check` was described as a live CI gate months after it was retired from CI.
# Docs that lie to the maintainer are how the NEXT defect gets authored. These are the mechanically
# checkable subset -- prose claims about CI ("CI runs X") are deliberately not asserted here,
# because detecting a claim in prose is NLP, not a gate. See meta/LEARNINGS.md, 2026-07-12.
# Since B-241 (WSD-089) it also guards the root instruction topology: AGENTS.md is the canonical
# maintainer file, CLAUDE.md imports it with one live `@AGENTS.md` line, and both sit under ceilings.
param([switch]$B231ScopeMutation)

if ($B231ScopeMutation) {
    $carrier = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path 'src/core/.github/instructions/framework-rules.instructions.md'
    if (-not (Get-Content -LiteralPath $carrier -Raw).Contains('Every bug-fix edit must be necessary')) {
        [Console]::Error.WriteLine('B-231 framework-owned scope is absent')
        exit 1
    }
    exit 0
}

. (Join-Path $PSScriptRoot '_HookHarness.ps1')
. (Join-Path $PSScriptRoot '_MutationHelper.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$rootDocs = @('README.md', 'CLAUDE.md', 'AGENTS.md', 'DEVELOPING.md')

Reset-Tests

# --- 1. one version, stamped everywhere ---------------------------------------------------------
It 'all three dists carry the SAME version stamp' {
    $vs = @('dotnet', 'angular', 'monorepo') | ForEach-Object {
        (Get-Content (Join-Path $repoRoot "dist/$_/.claude/framework-version.json") -Raw | ConvertFrom-Json).version
    }
    Assert (($vs | Select-Object -Unique).Count -eq 1) "dists disagree on version: $($vs -join ', ') -- release.ps1 stamps all three; a split means one was hand-edited"
}

It 'the root README version stamp matches what is actually shipped' {
    $shipped = (Get-Content (Join-Path $repoRoot 'dist/dotnet/.claude/framework-version.json') -Raw | ConvertFrom-Json).version
    $readme = Get-Content (Join-Path $repoRoot 'README.md') -Raw
    Assert ($readme -match 'Current shipped version is \*\*v([0-9]+\.[0-9]+\.[0-9]+)\*\*') 'README no longer states a shipped version -- the claim was removed or reworded, so this gate went blind'
    Assert ($Matches[1] -eq $shipped) "README says v$($Matches[1]); dists are stamped v$shipped"
}

# v0.48.0 is deliberately untagged: its release commit's CI failed, so WSD-029 correctly withheld
# the tag. The changelog entry records that history inline; do not retroactively tag it.
$untaggedReleaseExceptions = @('0.48.0')

# The decision is a pure function so it can be driven with fixtures. The version it exempts is the
# whole risk here -- an exemption that widens by one character stops being an exemption and starts
# being a disabled gate -- and that is not observable by running it against the real repo, where the
# answer is "no missing tags" on every healthy day.
function Get-MissingReleaseTags {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Versions,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Declared,
        [Parameter(Mandatory)][scriptblock]$TagExists
    )
    # The NEWEST dated head is never checked, and this is not a loophole -- it is the only shape that
    # can ever be satisfied. A release tag follows CI-verified green (WSD-029), so on the release
    # commit itself the newest head is dated and necessarily untagged, in a cycle with no exit:
    # the tag waits on CI, CI runs this suite, this suite would wait on the tag. v0.63.0 hit both
    # halves -- first refusing its own local release, then, after an environment-variable exemption
    # that only release.ps1 could set, failing CI on both legs for exactly the same reason.
    #
    # Nothing is lost. This check exists for releases that were dated and then never tagged because
    # their CI went red (v0.48.0) -- and such a release is only *knowable* as abandoned once a later
    # release is dated above it. At that point it is no longer the newest head and is checked
    # normally. Detection is deferred by one release; it is not given up. Deciding this from the
    # changelog's own ordering rather than from an environment variable also keeps the gate hermetic:
    # it returns the same answer locally, in CI, and on a developer's clone.
    $checkable = @($Versions | Select-Object -Skip 1)
    return @($checkable | Where-Object {
        if ($_ -in $Declared) { return $false }
        return (-not (& $TagExists $_))
    })
}

It 'every dated root changelog release has a corresponding git tag or declared exception' {
    $changelog = [IO.File]::ReadAllLines((Join-Path $repoRoot 'CHANGELOG.md'), [Text.Encoding]::UTF8)
    $versions = @($changelog | ForEach-Object {
        if ($_ -match '^## ([0-9]+\.[0-9]+\.[0-9]+) — [0-9]{4}-[0-9]{2}-[0-9]{2}$') { $Matches[1] }
    })
    Assert ($versions.Count -gt 0) 'root CHANGELOG.md yielded zero dated release heads -- the heading grammar changed and this gate is blind'
    $missing = @(Get-MissingReleaseTags -Versions $versions -Declared $untaggedReleaseExceptions -TagExists {
            param($v)
            git -C $repoRoot rev-parse -q --verify "refs/tags/v$v" *> $null
            return ($LASTEXITCODE -eq 0)
        })
    if ($missing) { Assert $false ("dated root changelog release(s) have no git tag: " + (($missing | ForEach-Object { "v$_" }) -join ', ')) }
    Assert $true 'clean'
}

It 'the newest dated head is exempt, and every older one is still reconciled' {
    $tagged = { param($v) return ($v -eq '0.62.0') }
    # The release being cut: newest head untagged, and it must NOT be reported -- reporting it is the
    # deadlock (tag waits on CI, CI runs this, this waits on the tag) that broke v0.63.0 twice.
    $cutting = @(Get-MissingReleaseTags -Versions @('0.63.0', '0.62.0') -Declared @() -TagExists $tagged)
    Assert ($cutting.Count -eq 0) "the newest dated head must not be reported: $($cutting -join ', ')"
    # One release later, the same abandoned release IS reported -- detection is deferred, not given
    # up. This is the assertion that keeps the exemption from becoming a disabled gate.
    $later = @(Get-MissingReleaseTags -Versions @('0.64.0', '0.63.0', '0.62.0') -Declared @() -TagExists $tagged)
    Assert ($later -contains '0.63.0') 'once a newer release is dated above it, an untagged release must be reported'
    Assert ($later -notcontains '0.62.0') 'a tagged release must never be reported as missing'
    Assert ($later -notcontains '0.64.0') 'the newest head must stay exempt regardless of depth'
    # A declared exception still stands on its own, below the newest head.
    $declared = @(Get-MissingReleaseTags -Versions @('0.64.0', '0.48.0') -Declared @('0.48.0') -TagExists $tagged)
    Assert ($declared.Count -eq 0) 'a declared exception must remain exempt'
    # Degenerate inputs must not throw or silently pass everything.
    Assert (@(Get-MissingReleaseTags -Versions @('0.63.0') -Declared @() -TagExists $tagged).Count -eq 0) 'a single head is the newest head'
    Assert (@(Get-MissingReleaseTags -Versions @() -Declared @() -TagExists $tagged).Count -eq 0) 'no dated heads yields nothing'
}

# --- 2. no phantom syntax -----------------------------------------------------------------------
It 'no doc documents `@@INCLUDE` -- the composer has never implemented it' {
    # CHANGELOG.md excluded: it is a dated record of what we believed, not live guidance.
    $offenders = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Filter *.md |
        Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' -and $_.Name -ne 'CHANGELOG.md' } |
        Where-Object { Select-String -Path $_.FullName -Pattern '@@INCLUDE' -Quiet }
    if ($offenders) {
        $rel = $offenders | ForEach-Object { $_.FullName.Substring($repoRoot.Length).TrimStart('\', '/') }
        Assert $false ("phantom marker syntax `@@INCLUDE` documented in: " + ($rel -join ', ') + ". The composer reads `<!-- @stack:NAME -->`.")
    }
    Assert $true 'clean'
}

It 'the marker syntax the docs teach is the one the composer implements' {
    $composer = Get-Content (Join-Path $repoRoot 'scripts/build.ps1') -Raw
    Assert ($composer -match '@stack:') 'build.ps1 no longer mentions @stack: -- the marker syntax changed and this gate is now checking a dead string'
    $documented = $rootDocs | Where-Object { (Get-Content (Join-Path $repoRoot $_) -Raw) -match '@stack:' }
    Assert ($documented.Count -gt 0) 'no root doc documents the @stack: marker syntax at all'
}

# --- 3. authoring docs name real files ----------------------------------------------------------
# The maintainer-side twin of validate-dist check 7. Root docs are dense with `scripts/x.ps1` and
# `.claude/scripts/release.ps1`; rename one and the docs rot silently.
It 'every script path named in a root doc exists' {
    $dead = @()
    foreach ($doc in $rootDocs) {
        $n = 0
        foreach ($line in (Get-Content (Join-Path $repoRoot $doc))) {
            $n++
            # A path qualified by a dist on the same line is a DIST path, not a root one -- e.g. the
            # red-test recipe `sed -i 's|pwsh scripts/install.ps1|...|' dist/monorepo/README.md`
            # names a string INSIDE a dist doc. validate-dist check 7 owns those; this test owns root.
            if ($line -match 'dist/') { continue }
            foreach ($m in [regex]::Matches($line, '(?<![\w./-])((?:scripts|\.claude)/[A-Za-z0-9_./-]+\.(?:ps1|sh|txt))')) {
                $p = $m.Groups[1].Value
                if (-not (Test-Path (Join-Path $repoRoot $p))) { $dead += "${doc}:${n}: $p" }
            }
        }
    }
    if ($dead) { Assert $false ("root docs name files that do not exist:`n  " + (($dead | Sort-Object -Unique) -join "`n  ")) }
    Assert $true 'clean'
}

# --- 4. CI runs what it claims to run -----------------------------------------------------------
It 'every script CI invokes actually exists' {
    $ci = Get-Content (Join-Path $repoRoot '.github/workflows/ci.yml') -Raw
    $dead = @()
    foreach ($m in [regex]::Matches($ci, '(?<![\w./-])((?:scripts|\.claude|dist/[a-z]+/(?:scripts|tests))/[A-Za-z0-9_./-]+\.(?:ps1|sh))')) {
        $p = $m.Groups[1].Value
        if (-not (Test-Path (Join-Path $repoRoot $p))) { $dead += $p }
    }
    if ($dead) { Assert $false ("ci.yml invokes scripts that do not exist: " + (($dead | Sort-Object -Unique) -join ', ')) }
    Assert $true 'clean'
}

# --- 5. backlog item identifiers are unambiguous -----------------------------------------------
It 'every live backlog item has a unique id' {
    $backlog = [IO.File]::ReadAllLines((Join-Path $repoRoot 'meta/BACKLOG.md'), [Text.Encoding]::UTF8)
    $ids = @($backlog | ForEach-Object {
        if ($_ -match '^### (B-[0-9]+) ·') { $Matches[1] }
    })
    Assert ($ids.Count -gt 0) 'BACKLOG.md yielded zero live item ids -- the heading grammar changed and this gate is blind'
    $duplicates = @($ids | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicates) { Assert $false ("duplicate live backlog item ids: " + ($duplicates -join ', ')) }
    Assert $true 'clean'
}

# --- 6. root instruction topology: one canonical file, one import, ceilings (B-241 / WSD-089) ------
# Root AGENTS.md is the canonical maintainer instruction file; root CLAUDE.md imports it with one live
# `@AGENTS.md` line and adds Claude-specific notes. This replaced B-82's heading-topology mapping,
# which its own header admitted was blind to body deletion: with one canonical file there is nothing
# to mirror. The ceilings are budgets in the WSD-055 sense, applied to the maintainer file: AGENTS.md
# under 120 lines (WSD-093; the file states the rule itself) and <= 19,500 LF bytes (1.2x the 16,043 measured
# at adoption, 2026-09-16); CLAUDE.md <= 40 lines; AGENTS.md plus a fixed allowance for the parent
# container's ~1 KB stub stays under Codex's 32 KiB project-document cap (Codex concatenates root ->
# cwd and silently stops adding files at the cap). Hermetic: the allowance is a constant, not a read
# of a file outside this repository. Raising a ceiling is a recorded WSD-089 amendment.
$rootInstructionCeilings = @{ ClaudeMaxLines = 40; AgentsMaxLines = 119; AgentsMaxBytes = 19500; ParentStubAllowanceBytes = 4096; CodexCapBytes = 32768 }

function Get-RootInstructionTopologyViolations {
    param(
        [AllowEmptyString()][string]$Claude,
        [AllowEmptyString()][string]$Agents,
        [Parameter(Mandatory)][hashtable]$Ceilings
    )
    $bad = @()
    if ([string]::IsNullOrWhiteSpace($Claude)) { $bad += 'could not examine root CLAUDE.md: empty or unreadable' }
    if ([string]::IsNullOrWhiteSpace($Agents)) { $bad += 'could not examine root AGENTS.md: empty or unreadable' }
    if ($bad.Count -gt 0) { return $bad }
    $claudeLf = $Claude.Replace("`r`n", "`n")
    $agentsLf = $Agents.Replace("`r`n", "`n")
    # A live import is a line that is exactly `@AGENTS.md`, outside fenced code. A backticked mention
    # is prose (the host skips code spans), so it must not satisfy this check.
    $inFence = $false; $liveImport = 0
    foreach ($line in ($claudeLf -split "`n")) {
        if ($line.TrimStart() -match '^(?:```|~~~)') { $inFence = -not $inFence; continue }
        if (-not $inFence -and $line.Trim() -ceq '@AGENTS.md') { $liveImport++ }
    }
    if ($liveImport -ne 1) { $bad += "root CLAUDE.md must carry exactly one live '@AGENTS.md' import line outside code; found $liveImport" }
    $claudeLines = @($claudeLf.TrimEnd("`n") -split "`n").Count
    if ($claudeLines -gt $Ceilings.ClaudeMaxLines) { $bad += "root CLAUDE.md is $claudeLines lines; ceiling $($Ceilings.ClaudeMaxLines) -- Claude-specific notes only; everything else belongs in AGENTS.md" }
    $agentsLines = @($agentsLf.TrimEnd("`n") -split "`n").Count
    if ($agentsLines -gt $Ceilings.AgentsMaxLines) { $bad += "root AGENTS.md is $agentsLines lines; ceiling $($Ceilings.AgentsMaxLines) -- adding a clause means cutting one (WSD-093)" }
    $agentsBytes = [Text.Encoding]::UTF8.GetByteCount($agentsLf)
    if ($agentsBytes -gt $Ceilings.AgentsMaxBytes) { $bad += "root AGENTS.md is $agentsBytes LF bytes; ceiling $($Ceilings.AgentsMaxBytes) (WSD-089)" }
    if (($agentsBytes + $Ceilings.ParentStubAllowanceBytes) -ge $Ceilings.CodexCapBytes) { $bad += "root AGENTS.md ($agentsBytes bytes) plus the $($Ceilings.ParentStubAllowanceBytes)-byte parent-stub allowance reaches Codex's $($Ceilings.CodexCapBytes)-byte project-document cap" }
    if ($agentsLf -notmatch '(?m)^> \*\*YOU ARE IN THE FRAMEWORK AUTHORING REPO') { $bad += 'root AGENTS.md does not open with the authoring-repo banner -- Codex concatenates it ahead of the shipped AGENTS.md copies under src/ and dist/' }
    # AGENTS.md is read by Codex, which performs no imports: a bare import token there is dead text
    # for Codex and a second import for Claude. Backticked or inline mentions are fine.
    $inFence = $false
    foreach ($line in ($agentsLf -split "`n")) {
        if ($line.TrimStart() -match '^(?:```|~~~)') { $inFence = -not $inFence; continue }
        if (-not $inFence -and $line -match '^\s*@[A-Za-z0-9_./~-]+\s*$') { $bad += "root AGENTS.md carries a stray import token: $($line.Trim())" }
    }
    return $bad
}

It 'root CLAUDE.md imports AGENTS.md exactly once, both stay under their ceilings, and the banner leads' {
    $claude = Get-Content -Raw (Join-Path $repoRoot 'CLAUDE.md')
    $agents = Get-Content -Raw (Join-Path $repoRoot 'AGENTS.md')
    $bad = @(Get-RootInstructionTopologyViolations -Claude $claude -Agents $agents -Ceilings $rootInstructionCeilings)
    Assert ($bad.Count -eq 0) ($bad -join '; ')
}

It 'a 120-line root AGENTS.md breaks its own "under 120 lines" rule (WSD-093)' {
    $agents120 = "# canonical`n`n> **YOU ARE IN THE FRAMEWORK AUTHORING REPO, NOT A CONSUMER PROJECT.** banner`n" + ("- clause`n" * 117)
    $bad = @(Get-RootInstructionTopologyViolations -Claude "# entry`n`n@AGENTS.md`n" -Agents $agents120 -Ceilings $rootInstructionCeilings)
    Assert (@($bad | Where-Object { $_ -match 'AGENTS\.md is 120 lines' }).Count -eq 1) "a 120-line AGENTS.md was accepted: $($bad -join '; ')"
}

It 'root topology helper rejects a missing or backticked import, oversize files, a missing banner, stray tokens, and empty input' {
    $c = $rootInstructionCeilings
    $goodClaude = "# entry`n`n> see AGENTS.md`n`n@AGENTS.md`n`n## Claude Code specifics`n- note`n"
    $goodAgents = "# canonical`n`n> **YOU ARE IN THE FRAMEWORK AUTHORING REPO, NOT A CONSUMER PROJECT.** banner`n`n## Status`nCLAUDE.md imports this file (``@AGENTS.md``).`n"
    Assert (@(Get-RootInstructionTopologyViolations -Claude $goodClaude -Agents $goodAgents -Ceilings $c).Count -eq 0) 'clean fixture was rejected'
    $bad = @(Get-RootInstructionTopologyViolations -Claude ($goodClaude.Replace("`n@AGENTS.md`n", "`n``@AGENTS.md```n")) -Agents $goodAgents -Ceilings $c)
    Assert ($bad.Count -eq 1 -and $bad[0] -match 'exactly one live.*found 0') "a backticked import must not count as live: $($bad -join '; ')"
    $bad = @(Get-RootInstructionTopologyViolations -Claude ($goodClaude + "@AGENTS.md`n") -Agents $goodAgents -Ceilings $c)
    Assert ($bad.Count -eq 1 -and $bad[0] -match 'found 2') "a duplicated import must be reported: $($bad -join '; ')"
    $bad = @(Get-RootInstructionTopologyViolations -Claude ($goodClaude + ("- padding`n" * $c.ClaudeMaxLines)) -Agents $goodAgents -Ceilings $c)
    Assert ($bad.Count -eq 1 -and $bad[0] -match 'CLAUDE\.md is \d+ lines; ceiling') "an oversize CLAUDE.md must be reported: $($bad -join '; ')"
    $bad = @(Get-RootInstructionTopologyViolations -Claude $goodClaude -Agents ($goodAgents + ("- padding`n" * $c.AgentsMaxLines)) -Ceilings $c)
    Assert ($bad.Count -eq 1 -and $bad[0] -match 'AGENTS\.md is \d+ lines; ceiling') "an oversize AGENTS.md must be reported: $($bad -join '; ')"
    $bad = @(Get-RootInstructionTopologyViolations -Claude $goodClaude -Agents ($goodAgents + ('x' * $c.AgentsMaxBytes) + "`n") -Ceilings $c)
    Assert ($bad.Count -eq 1 -and $bad[0] -match 'LF bytes; ceiling') "an over-budget AGENTS.md must be reported: $($bad -join '; ')"
    $tight = @{} + $c; $tight.ParentStubAllowanceBytes = $c.CodexCapBytes
    $bad = @(Get-RootInstructionTopologyViolations -Claude $goodClaude -Agents $goodAgents -Ceilings $tight)
    Assert ($bad.Count -eq 1 -and $bad[0] -match 'project-document cap') "the Codex cap must be reported when the allowance consumes it: $($bad -join '; ')"
    $bad = @(Get-RootInstructionTopologyViolations -Claude $goodClaude -Agents ($goodAgents.Replace('> **YOU ARE IN THE FRAMEWORK AUTHORING REPO', '> **you are somewhere')) -Ceilings $c)
    Assert ($bad.Count -eq 1 -and $bad[0] -match 'authoring-repo banner') "a missing banner must be reported: $($bad -join '; ')"
    $bad = @(Get-RootInstructionTopologyViolations -Claude $goodClaude -Agents ($goodAgents + "@meta/BACKLOG.md`n") -Ceilings $c)
    Assert ($bad.Count -eq 1 -and $bad[0] -match 'stray import token: @meta/BACKLOG\.md') "a stray import token must be reported: $($bad -join '; ')"
    $bad = @(Get-RootInstructionTopologyViolations -Claude '' -Agents $goodAgents -Ceilings $c)
    Assert ($bad.Count -eq 1 -and $bad[0] -match 'could not examine root CLAUDE\.md') 'an empty CLAUDE.md must be unexaminable, not clean'
    $bad = @(Get-RootInstructionTopologyViolations -Claude $goodClaude -Agents '' -Ceilings $c)
    Assert ($bad.Count -eq 1 -and $bad[0] -match 'could not examine root AGENTS\.md') 'an empty AGENTS.md must be unexaminable, not clean'
}

# --- 7. root delivery facts ---------------------------------------------------------------
# Root AGENTS.md is the canonical maintainer file (WSD-089); CLAUDE.md imports it and carries no Status
# section of its own, so the pointer checks target AGENTS.md alone.
function Get-RootDeliveryFactViolations([string]$Readme, [string]$Agents, [hashtable]$ManifestPaths, [hashtable]$DeliveredLegalPaths) {
    $bad = @()
    if ($Readme -match '(?is)\binstall(?:ing|ed)?\b.{0,80}\b[0-9,]+\s+files\b') { $bad += 'README has a brittle installed-file count' }
    if ($Readme -notmatch 'framework-ownership\.json.{0,100}(?i:authoritative)') { $bad += 'README does not name framework-ownership.json as authoritative' }
    if ($Readme -notmatch 'LICENSES/ai-tech-lead-MIT\.txt' -or $Readme -notmatch 'NOTICE-ai-tech-lead\.md') { $bad += 'README omits shipped licence/notice paths' }
    foreach ($stack in @('dotnet','angular','monorepo')) {
        $paths = @($ManifestPaths[$stack])
        if ($paths -notcontains 'LICENSES/ai-tech-lead-MIT.txt' -or $paths -notcontains 'NOTICE-ai-tech-lead.md') { $bad += "$stack manifest omits licence or notice" }
        $delivered = @($DeliveredLegalPaths[$stack])
        if ($delivered -notcontains 'LICENSES/ai-tech-lead-MIT.txt' -or $delivered -notcontains 'NOTICE-ai-tech-lead.md') { $bad += "$stack dist omits licence or notice" }
    }
    if ($Agents -notmatch '(?ms)^## Status\s*(?<status>.*?)(?=^## |\z)') { $bad += 'AGENTS.md omits its Status section' }
    elseif ($Matches.status -match '(?i)current shipped version|\bv?\d+\.\d+\.\d+\b|\bB-\d+\b|\b20\d{2}-\d{2}-\d{2}\b') { $bad += 'AGENTS.md retains a numeric status summary' }
    foreach ($required in @('dist/*/.claude/framework-version.json','CHANGELOG.md','tags','meta/BACKLOG.md')) { if (-not $Agents.Contains($required)) { $bad += "AGENTS.md omits $required pointer" } }
    return $bad
}

# B-239 (2026-09-16 plan, S4.1/S6.2): the generator (`build-architecture-html.ps1`) and the three
# `src/stacks/*/files/docs/architecture.html` whole-file overrides are retired. Nothing produces
# `docs/architecture.html` anymore -- it is a single static, inert compatibility stub authored
# once at `src/core/docs/architecture.html` and composed byte-for-byte into all three dists. A
# token deny-list (e.g. "contains no `<script") is deliberately NOT used: it is not a complete
# no-fetch oracle -- `<img src="relative.png">` contains none of the denied tokens and still
# specifies a fetchable resource. Exact bytes are the oracle. Comparing source to copies alone is
# also rejected: it would accept a uniformly unsafe change where all four committed copies drifted
# identically wrong. So the expected bytes are pinned HERE, independent of every file under test --
# never read from src/core/docs/architecture.html or any dist copy.
$expectedArchitectureStubBytes = [Text.Encoding]::UTF8.GetBytes(((@(
    '<!doctype html>'
    '<html lang="en">'
    '<head>'
    '<meta charset="utf-8">'
    '<meta name="viewport" content="width=device-width, initial-scale=1">'
    '<title>Architecture — see docs/ARCHITECTURE.md</title>'
    '<style>'
    '  body { font-family: -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;'
    '         line-height: 1.6; max-width: 42rem; margin: 0 auto; padding: 2rem 1.25rem; }'
    '  code { font-family: ui-monospace, SFMono-Regular, Consolas, monospace; }'
    '</style>'
    '</head>'
    '<body>'
    '<h1>This generated view is retired</h1>'
    '<p>This page is no longer generated. It used to load its Markdown and diagram renderers from a'
    'third-party content delivery network each time it was opened, which this framework no longer'
    'ships.</p>'
    '<p><strong>Read <code>docs/ARCHITECTURE.md</code> instead.</strong> It is the canonical source and'
    'is unchanged. Open it in your editor or your Git host, which display the Mermaid diagrams this page'
    'used to render.</p>'
    '<p><a href="ARCHITECTURE.md">docs/ARCHITECTURE.md</a></p>'
    '<p>This file remains only so existing links and bookmarks do not break, and is safe to delete.</p>'
    '</body>'
    '</html>'
) -join "`n") + "`n"))

function Get-ArchitectureStubViolations {
    param(
        [Parameter(Mandatory)][byte[]]$ExpectedBytes,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Targets,
        [Parameter(Mandatory)][int]$ExpectedCount,
        [Parameter(Mandatory)][scriptblock]$ReadBytes
    )
    $bad = @()
    # A target list that is empty, short, or long must fail loudly -- a check that ends up
    # scanning zero files would otherwise report zero violations and pass silently, which is
    # indistinguishable from a genuinely clean result.
    if (@($Targets).Count -ne $ExpectedCount) {
        $bad += "architecture stub target list is malformed: expected $ExpectedCount committed copies, found $(@($Targets).Count) -- refusing to pass on an empty or incomplete scan"
        return $bad
    }
    foreach ($t in $Targets) {
        try {
            $actual = & $ReadBytes $t.Path
        } catch {
            $bad += "$($t.Label): could not examine architecture stub: $($_.Exception.Message)"
            continue
        }
        if ($null -eq $actual) {
            $bad += "$($t.Label): could not examine architecture stub: file is missing"
            continue
        }
        if ([Convert]::ToBase64String($actual) -cne [Convert]::ToBase64String($ExpectedBytes)) {
            $bad += "$($t.Label): architecture.html is not byte-identical to the pinned retirement stub"
        }
    }
    return $bad
}

It 'root delivery facts defer counts to manifests, ship licence plus notice, and keep status pointers non-numeric' {
    $readme = Get-Content -Raw (Join-Path $repoRoot 'README.md')
    $agents = Get-Content -Raw (Join-Path $repoRoot 'AGENTS.md')
    $manifests = @{}
    $delivered = @{}
    foreach ($stack in @('dotnet','angular','monorepo')) {
        $manifests[$stack] = @((Get-Content -Raw (Join-Path $repoRoot "dist/$stack/framework-ownership.json") | ConvertFrom-Json).paths | ForEach-Object path)
        $delivered[$stack] = @('LICENSES/ai-tech-lead-MIT.txt','NOTICE-ai-tech-lead.md') | Where-Object { Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/$_") }
    }
    $bad = @(Get-RootDeliveryFactViolations $readme $agents $manifests $delivered)
    Assert ($bad.Count -eq 0) ($bad -join '; ')
}

It 'B-231 keeps one outcome scope across fresh carriers and truthful protected updates' {
    $carrier = Get-Content -Raw (Join-Path $repoRoot 'src/core/.github/instructions/framework-rules.instructions.md')
    Assert ($carrier.Contains('Every bug-fix edit must be necessary')) 'framework-owned outcome rule is absent'
    Assert ($carrier.Contains('existing caller/extension compatibility')) 'necessary caller/extension edits are not allowed'
    Assert ($carrier.Contains('meaningful verification')) 'meaningful verification edits are not allowed'
    Assert ($carrier.Contains('Requested cleanup/refactoring is allowed')) 'explicitly requested refactoring is not allowed'
    Assert ($carrier.Contains('public/protected signatures or virtual/override behaviour')) 'unrequested extension-contract breaks are not checked'
    foreach ($stack in @('dotnet','angular','monorepo')) {
        $dist = Join-Path $repoRoot "dist/$stack"
        $copilot = Get-Content -Raw (Join-Path $dist '.github/copilot-instructions.md')
        $hook = Get-Content -Raw (Join-Path $dist '.claude/hooks/boy-scout-check.ps1')
        $readme = Get-Content -Raw (Join-Path $dist 'README.md')
        Assert ($copilot.Contains('Follow framework-rules: edit only for outcome, compatibility, verification, or requested refactoring')) "$stack fresh copilot carrier omits the outcome scope"
        Assert (-not $copilot.Contains('Boy Scout (apply only to evidenced constructs on touched files)')) "$stack fresh copilot carrier retains touched-file scope"
        Assert ($hook.Contains('advisory candidates')) "$stack hook no longer identifies its findings as advisory"
        Assert ($hook.Contains('do not add a TODO for unrelated deferred cleanup')) "$stack hook permits a touched-file TODO rule"
        Assert ($readme.Contains('protected consumer paths') -and $readme.Contains('framework-rules.instructions.md')) "$stack update guidance does not distinguish protected content from the framework-owned carrier"
    }
}

It 'every committed architecture HTML is the pinned, byte-identical retirement stub' {
    $targets = @(
        @{ Label = 'src/core/docs/architecture.html'; Path = (Join-Path $repoRoot 'src/core/docs/architecture.html') }
        @{ Label = 'dist/dotnet/docs/architecture.html'; Path = (Join-Path $repoRoot 'dist/dotnet/docs/architecture.html') }
        @{ Label = 'dist/angular/docs/architecture.html'; Path = (Join-Path $repoRoot 'dist/angular/docs/architecture.html') }
        @{ Label = 'dist/monorepo/docs/architecture.html'; Path = (Join-Path $repoRoot 'dist/monorepo/docs/architecture.html') }
    )
    $readBytes = {
        param($path)
        if (-not (Test-Path -LiteralPath $path)) { return $null }
        [IO.File]::ReadAllBytes($path)
    }
    $bad = @(Get-ArchitectureStubViolations -ExpectedBytes $expectedArchitectureStubBytes -Targets $targets -ExpectedCount 4 -ReadBytes $readBytes)
    Assert ($bad.Count -eq 0) ($bad -join '; ')
}

It 'the architecture stub helper separates a wrong byte from an unexaminable file and refuses an empty scan' {
    $expected = [Text.Encoding]::UTF8.GetBytes("<html></html>`n")
    $one = @(@{ Label = 'fixture'; Path = 'n/a' })

    # "is wrong": a byte mismatch, including a resource a token deny-list would miss entirely --
    # an <img src> carries none of the tokens such a scan would deny, yet still fetches something.
    foreach ($mutant in @(
            [Text.Encoding]::UTF8.GetBytes("<html><script>1</script></html>`n"),
            [Text.Encoding]::UTF8.GetBytes(('<html><img src="relative.png"></html>' + "`n"))
        )) {
        $bad = @(Get-ArchitectureStubViolations -ExpectedBytes $expected -Targets $one -ExpectedCount 1 -ReadBytes { param($p) $mutant })
        Assert ($bad.Count -eq 1) 'a byte-mismatched copy must be reported'
        Assert ($bad[0] -match 'is not byte-identical') "a content mismatch must be reported as wrong, not as unexaminable: $($bad[0])"
    }

    # "could not examine": missing file
    $bad = @(Get-ArchitectureStubViolations -ExpectedBytes $expected -Targets $one -ExpectedCount 1 -ReadBytes { param($p) $null })
    Assert ($bad.Count -eq 1) 'a missing copy must be reported'
    Assert ($bad[0] -match 'could not examine.*missing') "a missing file must be reported as unexaminable, not as wrong content: $($bad[0])"

    # "could not examine": a read failure (e.g. a locked handle) -- never conflated with "is wrong"
    $bad = @(Get-ArchitectureStubViolations -ExpectedBytes $expected -Targets $one -ExpectedCount 1 -ReadBytes { param($p) throw 'access denied' })
    Assert ($bad.Count -eq 1) 'an unreadable copy must be reported'
    Assert ($bad[0] -match 'could not examine.*access denied') "a read failure must be reported as unexaminable, not as wrong content: $($bad[0])"

    # a check that would scan zero (or the wrong number of) files must fail, not pass vacuously
    $bad = @(Get-ArchitectureStubViolations -ExpectedBytes $expected -Targets @() -ExpectedCount 4 -ReadBytes { param($p) $expected })
    Assert ($bad.Count -eq 1) 'an empty target list must be reported, not silently pass as zero violations'
    Assert ($bad[0] -match 'expected 4') "the malformed-target-list message must be distinguishable from a content or read failure: $($bad[0])"

    # clean pass
    $bad = @(Get-ArchitectureStubViolations -ExpectedBytes $expected -Targets $one -ExpectedCount 1 -ReadBytes { param($p) $expected })
    Assert ($bad.Count -eq 0) 'a byte-identical copy must not be reported'
}

It 'B-231 scope mutation is reachable and restores its scratch bytes' {
    $hostPath = (Get-Process -Id $PID).Path
    $target = Join-Path $repoRoot 'src/core/.github/instructions/framework-rules.instructions.md'
    Invoke-MutationRedTest -TargetFile $target -ScratchSourceRoot $repoRoot `
        -Find 'Every bug-fix edit must be necessary' -Replacement 'Every bug-fix edit is optional' -ExpectedExit 1 -Command {
            param($scratchTarget, $scratchRoot)
            & $hostPath -NoProfile -File (Join-Path $scratchRoot '.claude/hooks/tests/DocTruth.Tests.ps1') -B231ScopeMutation
            $global:LASTEXITCODE = $LASTEXITCODE
        } | Out-Null
}

It 'root delivery fact helper rejects brittle counts, omitted legal paths, and numeric status fixtures' {
    $paths = @{ dotnet=@('LICENSES/ai-tech-lead-MIT.txt','NOTICE-ai-tech-lead.md'); angular=@('LICENSES/ai-tech-lead-MIT.txt','NOTICE-ai-tech-lead.md'); monorepo=@('LICENSES/ai-tech-lead-MIT.txt','NOTICE-ai-tech-lead.md') }
    $good = 'framework-ownership.json is authoritative. LICENSES/ai-tech-lead-MIT.txt NOTICE-ai-tech-lead.md'
    $pointers = "## Status`nVersion authority is dist/*/.claude/framework-version.json. Release history: CHANGELOG.md and tags. Work: meta/BACKLOG.md."
    foreach ($fixture in @('Installing lands 166 files', 'framework-ownership.json is informative', 'LICENSES/ai-tech-lead-MIT.txt', 'NOTICE-ai-tech-lead.md')) {
        $readme = if ($fixture -eq 'framework-ownership.json is informative') { $fixture + ' LICENSES/ai-tech-lead-MIT.txt NOTICE-ai-tech-lead.md' } elseif ($fixture -match 'LICENSE|NOTICE') { 'framework-ownership.json is authoritative. ' + $fixture } else { $good + ' ' + $fixture }
        Assert (@(Get-RootDeliveryFactViolations $readme $pointers $paths $paths).Count -gt 0) "red fixture was accepted: $fixture"
    }
    Assert (@(Get-RootDeliveryFactViolations $good ($pointers + "`nB-123 is current") $paths $paths).Count -gt 0) 'numeric AGENTS status fixture was accepted'
    Assert (@(Get-RootDeliveryFactViolations $good ($pointers + "`nCurrent shipped version: v1.2.3") $paths $paths).Count -gt 0) 'version-numbered AGENTS status fixture was accepted'
    Assert (@(Get-RootDeliveryFactViolations $good ($pointers.Replace('meta/BACKLOG.md', 'the backlog')) $paths $paths).Count -gt 0) 'AGENTS fixture missing a required pointer was accepted'
    $missingDelivery = @{} + $paths; $missingDelivery.dotnet = @('NOTICE-ai-tech-lead.md')
    Assert (@(Get-RootDeliveryFactViolations $good $pointers $paths $missingDelivery).Count -gt 0) 'missing physical licence fixture was accepted'
}

# CI and the aggregate runner invoke this complete suite directly under both supported hosts. Keep
# this case host-local: a PS7 parent relaunching the suite under 5.1 made the PS7 manifest count a
# case that the direct 5.1 run could only skip, defeating equal/nonzero cardinality.
It 'the suite executes under the directly selected supported PowerShell host' {
    $hostLeaf = [IO.Path]::GetFileName((Get-Process -Id $PID).Path)
    if ($PSVersionTable.PSEdition -eq 'Core') {
        Assert ($PSVersionTable.PSVersion.Major -ge 7 -and $hostLeaf -match '^pwsh(?:\.exe)?$') `
            "expected direct PowerShell 7, observed $hostLeaf $($PSVersionTable.PSVersion)"
    } else {
        Assert ($PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion.Major -eq 5 -and
            $PSVersionTable.PSVersion.Minor -eq 1 -and $hostLeaf -match '^powershell(?:\.exe)?$') `
            "expected direct Windows PowerShell 5.1, observed $hostLeaf $($PSVersionTable.PSVersion)"
    }
}

exit (Write-TestSummary 'DocTruth.Tests (the authoring docs describe the repo that exists)')
