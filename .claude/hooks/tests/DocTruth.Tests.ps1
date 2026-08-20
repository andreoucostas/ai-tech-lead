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
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$rootDocs = @('README.md', 'CLAUDE.md', 'AGENTS.md', 'DEVELOPING.md')
$docTruthSuitePath = $MyInvocation.MyCommand.Path

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

It 'every dated root changelog release has a corresponding git tag or declared exception' {
    # v0.48.0 is deliberately untagged: its release commit's CI failed, so WSD-029 correctly
    # withheld the tag. The changelog entry records that history inline; do not retroactively tag it.
    $untaggedReleaseExceptions = @('0.48.0')
    $changelog = [IO.File]::ReadAllLines((Join-Path $repoRoot 'CHANGELOG.md'), [Text.Encoding]::UTF8)
    $versions = @($changelog | ForEach-Object {
        if ($_ -match '^## ([0-9]+\.[0-9]+\.[0-9]+) — [0-9]{4}-[0-9]{2}-[0-9]{2}$') { $Matches[1] }
    })
    Assert ($versions.Count -gt 0) 'root CHANGELOG.md yielded zero dated release heads -- the heading grammar changed and this gate is blind'
    $missing = @($versions | Where-Object {
        if ($_ -in $untaggedReleaseExceptions) { return $false }
        git -C $repoRoot rev-parse -q --verify "refs/tags/v$_" *> $null
        return ($LASTEXITCODE -ne 0)
    })
    if ($missing) { Assert $false ("dated root changelog release(s) have no git tag: " + (($missing | ForEach-Object { "v$_" }) -join ', ')) }
    Assert $true 'clean'
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

# This checks heading topology, not whether the mirrors tell the same truth. For example, deleting
# Maintenance model rule 6 from AGENTS.md while leaving its heading intact remains green. Likewise,
# four CLAUDE.md sections deliberately map to one AGENTS.md heading, which could retain only one of
# those concepts and still pass. This test catches one event: a section appears on either side
# without a mirror decision. A future content-truth gap needs a content measure, not more topology.
It 'root CLAUDE.md and AGENTS.md headings have an explicit mirror mapping' {
    $table = @(
        [pscustomobject]@{ Claude = 'What this repo is'; Agents = 'What this repo is' }
        [pscustomobject]@{ Claude = 'Meta-invariants (canonical list — referenced everywhere, restated nowhere)'; Agents = 'Meta-invariants (canonical definitions live in CLAUDE.md — same numbering)' }
        [pscustomobject]@{ Claude = 'How to approach a change (meta-workflows)'; Agents = 'Workflows, done-ness, verification' }
        [pscustomobject]@{ Claude = 'Maintenance model (who implements, who reviews, what "green" means)'; Agents = 'Maintenance model' }
        [pscustomobject]@{ Claude = 'Definition of done per artifact type'; Agents = 'Workflows, done-ness, verification' }
        [pscustomobject]@{ Claude = 'Verification (evidence-based — name the command, show the result)'; Agents = 'Workflows, done-ness, verification' }
        [pscustomobject]@{ Claude = 'Inherited disciplines (they apply to meta-work too)'; Agents = 'Workflows, done-ness, verification' }
        [pscustomobject]@{ Claude = 'Commit & push policy (stated in full — not by reference)'; Agents = 'Conventions' }
        [pscustomobject]@{ Claude = 'Conventions'; Agents = 'Conventions' }
        [pscustomobject]@{ Claude = 'Status'; Agents = 'Status' }
    )
    Assert (@($table).Count -gt 0) 'heading mirror mapping table is empty -- this gate is blind'

    $claudeHeadings = @([IO.File]::ReadAllLines((Join-Path $repoRoot 'CLAUDE.md'), [Text.Encoding]::UTF8) | ForEach-Object {
        if ($_ -match '^## (.+)$') { $Matches[1] }
    })
    $agentsHeadings = @([IO.File]::ReadAllLines((Join-Path $repoRoot 'AGENTS.md'), [Text.Encoding]::UTF8) | ForEach-Object {
        if ($_ -match '^## (.+)$') { $Matches[1] }
    })
    Assert ($claudeHeadings.Count -gt 0) 'CLAUDE.md yielded zero ## headings -- the heading grammar changed and this gate is blind'
    Assert ($agentsHeadings.Count -gt 0) 'AGENTS.md yielded zero ## headings -- the heading grammar changed and this gate is blind'

    foreach ($heading in $claudeHeadings) {
        Assert (@($table | Where-Object { $_.Claude -ceq $heading }).Count -gt 0) "CLAUDE.md heading '$heading' has no mapping -- decide its mirror target and add it to the table"
    }
    foreach ($mapping in $table) {
        Assert (@($agentsHeadings | Where-Object { $_ -ceq $mapping.Agents }).Count -gt 0) "mapped AGENTS.md target '$($mapping.Agents)' for CLAUDE.md heading '$($mapping.Claude)' does not exist"
    }
    foreach ($heading in $agentsHeadings) {
        Assert (@($table | Where-Object { $_.Agents -ceq $heading }).Count -gt 0) "AGENTS.md heading '$heading' is not the target of any CLAUDE.md heading mapping"
    }
    Assert $true 'clean'
}

# The 5.1 arm. Both defects this guards against (a `-Include` that does not filter, a BOM-less file
# decoded against the system codepage) are INVISIBLE under pwsh 7, which is how they survived to
# v0.58.0 while this suite reported 8/8. Re-running the whole suite under the other host is the only
# measure that sees them.
#
# It reports SKIP, never a pass, when it cannot actually run 5.1 -- under 5.1 itself (where it would
# recurse) and on a host without powershell.exe. An arm that verified nothing must not be
# indistinguishable from one that verified something: that is B-71's class, and reporting a
# not-run leg as [ok] is the stronger form of it.
$windowsPowerShell = if ($env:SystemRoot) { Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' } else { $null }
if ($PSVersionTable.PSEdition -ne 'Core') {
    Skip 'the suite also passes under Windows PowerShell 5.1' 'already running under Windows PowerShell; the pwsh 7 run drives this arm'
} elseif (-not $windowsPowerShell -or -not (Test-Path -LiteralPath $windowsPowerShell)) {
    Skip 'the suite also passes under Windows PowerShell 5.1' 'no powershell.exe on this host -- NOT a pass; the 5.1 leg was not exercised'
} else {
    It 'the suite also passes under Windows PowerShell 5.1' {
        & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $docTruthSuitePath *> $null
        Assert ($LASTEXITCODE -eq 0) "Windows PowerShell 5.1 DocTruth run failed with exit $LASTEXITCODE"
    }
}

exit (Write-TestSummary 'DocTruth.Tests (the authoring docs describe the repo that exists)')
