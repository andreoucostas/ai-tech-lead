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

# --- 6. root delivery facts ---------------------------------------------------------------
function Get-RootDeliveryFactViolations([string]$Readme, [string]$Claude, [string]$Agents, [hashtable]$ManifestPaths, [hashtable]$DeliveredLegalPaths) {
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
    foreach ($doc in @(@{ Name='CLAUDE.md'; Text=$Claude }, @{ Name='AGENTS.md'; Text=$Agents })) {
        if ($doc.Text -notmatch '(?ms)^## Status\s*(?<status>.*?)(?=^## |\z)') { $bad += "$($doc.Name) omits its Status section" }
        elseif ($Matches.status -match '(?i)current shipped version|\bv?\d+\.\d+\.\d+\b|\bB-\d+\b|\b20\d{2}-\d{2}-\d{2}\b') { $bad += "$($doc.Name) retains a numeric status summary" }
        foreach ($required in @('dist/*/.claude/framework-version.json','CHANGELOG.md','tags','meta/BACKLOG.md')) { if (-not $doc.Text.Contains($required)) { $bad += "$($doc.Name) omits $required pointer" } }
    }
    return $bad
}

It 'root delivery facts defer counts to manifests, ship licence plus notice, and keep status pointers non-numeric' {
    $readme = Get-Content -Raw (Join-Path $repoRoot 'README.md')
    $claude = Get-Content -Raw (Join-Path $repoRoot 'CLAUDE.md')
    $agents = Get-Content -Raw (Join-Path $repoRoot 'AGENTS.md')
    $manifests = @{}
    $delivered = @{}
    foreach ($stack in @('dotnet','angular','monorepo')) {
        $manifests[$stack] = @((Get-Content -Raw (Join-Path $repoRoot "dist/$stack/framework-ownership.json") | ConvertFrom-Json).paths | ForEach-Object path)
        $delivered[$stack] = @('LICENSES/ai-tech-lead-MIT.txt','NOTICE-ai-tech-lead.md') | Where-Object { Test-Path -LiteralPath (Join-Path $repoRoot "dist/$stack/$_") }
    }
    $bad = @(Get-RootDeliveryFactViolations $readme $claude $agents $manifests $delivered)
    Assert ($bad.Count -eq 0) ($bad -join '; ')
}

It 'root delivery fact helper rejects brittle counts, omitted legal paths, and numeric status fixtures' {
    $paths = @{ dotnet=@('LICENSES/ai-tech-lead-MIT.txt','NOTICE-ai-tech-lead.md'); angular=@('LICENSES/ai-tech-lead-MIT.txt','NOTICE-ai-tech-lead.md'); monorepo=@('LICENSES/ai-tech-lead-MIT.txt','NOTICE-ai-tech-lead.md') }
    $good = 'framework-ownership.json is authoritative. LICENSES/ai-tech-lead-MIT.txt NOTICE-ai-tech-lead.md'
    $pointers = "## Status`nVersion authority is dist/*/.claude/framework-version.json. Release history: CHANGELOG.md and tags. Work: meta/BACKLOG.md."
    foreach ($fixture in @('Installing lands 166 files', 'framework-ownership.json is informative', 'LICENSES/ai-tech-lead-MIT.txt', 'NOTICE-ai-tech-lead.md')) {
        $readme = if ($fixture -eq 'framework-ownership.json is informative') { $fixture + ' LICENSES/ai-tech-lead-MIT.txt NOTICE-ai-tech-lead.md' } elseif ($fixture -match 'LICENSE|NOTICE') { 'framework-ownership.json is authoritative. ' + $fixture } else { $good + ' ' + $fixture }
        Assert (@(Get-RootDeliveryFactViolations $readme $pointers $pointers $paths $paths).Count -gt 0) "red fixture was accepted: $fixture"
    }
    Assert (@(Get-RootDeliveryFactViolations $good ($pointers + "`nCurrent shipped version: v1.2.3") $pointers $paths $paths).Count -gt 0) 'numeric CLAUDE status fixture was accepted'
    Assert (@(Get-RootDeliveryFactViolations $good $pointers ($pointers + "`nB-123 is current") $paths $paths).Count -gt 0) 'numeric AGENTS status fixture was accepted'
    $missingDelivery = @{} + $paths; $missingDelivery.dotnet = @('NOTICE-ai-tech-lead.md')
    Assert (@(Get-RootDeliveryFactViolations $good $pointers $pointers $paths $missingDelivery).Count -gt 0) 'missing physical licence fixture was accepted'
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
