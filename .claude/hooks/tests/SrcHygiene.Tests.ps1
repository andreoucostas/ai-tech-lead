# Sweeps src/ for agent tool-syntax leakage: stray </content> / </invoke> lines that a
# delegated agent's file-write tooling can leave inside an authored artifact (LEARNINGS
# 2026-07-10 — three of eight monorepo docs shipped with the leak; valid markdown to every
# parser, so no composer/validate-dist/template-checks gate can see it). This makes the
# one-line grep from that learning a permanent gate. Wired into release.ps1 + CI via
# Invoke-HookTests.ps1 auto-discovery (B-33). Does NOT ship.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path   # the ai-tech-lead repo root

# Regex-literal on purpose: '/' needs no escaping, and one pattern keeps the .sweep identical
# to the LEARNINGS recipe (grep -rn '</content>\|</invoke>').
$LeakPattern = '</content>|</invoke>'

function Find-Leakage {
    param([string]$Root)
    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($f in (Get-ChildItem -LiteralPath $Root -Recurse -File)) {
        $text = [IO.File]::ReadAllText($f.FullName)
        if ($text -match $LeakPattern) { $hits.Add($f.FullName) }
    }
    return , $hits.ToArray()
}

Reset-Tests

It 'no tool-syntax leakage (</content> or </invoke>) anywhere under src/' {
    $srcRoot = Join-Path $repoRoot 'src'
    $all = Get-ChildItem -LiteralPath $srcRoot -Recurse -File
    Assert ($all.Count -gt 0) "enumeration found no files under $srcRoot — sweep is broken (vacuous pass)"
    $hits = Find-Leakage $srcRoot
    if ($hits.Count -gt 0) {
        $rel = $hits | ForEach-Object { $_.Substring($repoRoot.Length).TrimStart('\', '/') }
        Assert $false ("tool-syntax leakage in: " + ($rel -join ', '))
    } else {
        Assert $true 'src/ is clean'
    }
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("srchygiene-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    It 'Find-Leakage detects a planted </content> line (positive control)' {
        $f = Join-Path $tmp 'leaky.md'
        [IO.File]::WriteAllText($f, "# doc`nbody text`n</content>`n", (New-Object System.Text.UTF8Encoding($false)))
        $hits = Find-Leakage $tmp
        Assert ($hits.Count -eq 1) 'planted </content> was not detected'
    }
    It 'Find-Leakage detects a planted </invoke> line (positive control)' {
        $f = Join-Path $tmp 'leaky2.md'
        [IO.File]::WriteAllText($f, "text`n</invoke>", (New-Object System.Text.UTF8Encoding($false)))
        $hits = Find-Leakage $tmp
        Assert ($hits.Count -eq 2) 'planted </invoke> was not detected'
    }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'SrcHygiene.Tests (src/ tool-syntax leakage sweep)')
