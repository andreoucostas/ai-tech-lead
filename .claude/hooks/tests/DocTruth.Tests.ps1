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

# --- 2. no phantom syntax -----------------------------------------------------------------------
It 'no doc documents `@@INCLUDE` -- the composer has never implemented it' {
    # CHANGELOG.md excluded: it is a dated record of what we believed, not live guidance.
    $offenders = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Include *.md |
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

exit (Write-TestSummary 'DocTruth.Tests (the authoring docs describe the repo that exists)')
