# Asserts that every .ps1 in the repo carries a UTF-8 BOM (repo-wide sweep: src/, scripts/,
# .claude/, dist/). Invariant #4: Windows PowerShell 5.1 mis-parses BOM-less UTF-8; this gate
# catches .ps1 files that escape the bom-fix hook (hand-created outside a hooked session) or
# land in dirs no per-dist template-checks sweep covers (scripts/, .claude/, src/ fragments).
# Wired into release.ps1 via Invoke-HookTests.ps1 auto-discovery. Does NOT ship.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path   # the ai-tech-lead repo root

function Test-HasBom { param($path) $b=[IO.File]::ReadAllBytes($path); ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) }

Reset-Tests

It 'every .ps1 in the repo carries a UTF-8 BOM (invariant #4)' {
    # -File matters: snippet DIRECTORIES are named after their target file (e.g.
    # src/stacks/<s>/snippets/.claude/hooks/audit-trail.ps1/ is a dir of marker snippets).
    $all     = Get-ChildItem -LiteralPath $repoRoot -Recurse -File -Filter *.ps1 | Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
    Assert ($all.Count -gt 0) "enumeration found no .ps1 under $repoRoot — sweep is broken (vacuous pass)"
    $missing = $all | Where-Object { -not (Test-HasBom $_.FullName) }
    if ($missing) {
        $rel = $missing | ForEach-Object { $_.FullName.Substring($repoRoot.Length).TrimStart('\','/') }
        Assert $false ("BOM missing in: " + ($rel -join ', '))
    } else {
        Assert $true 'all files have BOMs'
    }
}

# --- valid-UTF-8 sweep ---------------------------------------------------------------------------
# A file holding a byte sequence that is not valid UTF-8 makes the two composer twins DISAGREE:
# build.sh copies the raw bytes through untouched, while build.ps1 decodes and re-encodes, turning
# the bad byte into U+FFFD. The committed dist then matches whichever composer produced it and the
# other CI leg fails the freshness diff. That is a confusing, far-from-the-cause failure, so catch
# the bad byte at its source instead. (Real occurrence, v0.26.1: an em-dash inside a `sed`
# character class -- `[-—]` -- is matched BYTEWISE, so sed stripped the two continuation bytes and
# left a lone 0xE2 in two post-write.sh files. Every local gate passed; only CI's cross-leg rebuild
# caught it.) Reject-on-invalid is the whole point: UTF8Encoding($false, $true) throws rather than
# silently substituting U+FFFD -- a lenient decode would make this test vacuous.
function Test-IsValidUtf8 {
    param($path)
    $strict = New-Object System.Text.UTF8Encoding($false, $true)
    try { [void]$strict.GetString([IO.File]::ReadAllBytes($path)); $true } catch { $false }
}

It 'every file in the repo is valid UTF-8 (composer twins diverge on invalid bytes)' {
    $all = Get-ChildItem -LiteralPath $repoRoot -Recurse -File |
           Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' }
    Assert ($all.Count -gt 0) "enumeration found no files under $repoRoot -- sweep is broken (vacuous pass)"
    $bad = $all | Where-Object { -not (Test-IsValidUtf8 $_.FullName) }
    if ($bad) {
        $rel = $bad | ForEach-Object { $_.FullName.Substring($repoRoot.Length).TrimStart('\', '/') }
        Assert $false ("invalid UTF-8 in: " + ($rel -join ', '))
    } else {
        Assert $true 'all files decode as UTF-8'
    }
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("workspacebom-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    It 'Test-HasBom returns $false for a BOM-less .ps1 (positive control)' {
        $f = Join-Path $tmp 'nobom.ps1'
        [IO.File]::WriteAllText($f, "exit 0`n", (New-Object System.Text.UTF8Encoding($false)))
        Assert (-not (Test-HasBom $f)) 'Test-HasBom should return $false for a BOM-less file'
    }

    It 'Test-IsValidUtf8 returns $false for a lone 0xE2 lead byte (positive control)' {
        # Exactly the corruption v0.26.1 shipped: an em-dash (E2 80 94) stripped of its
        # continuation bytes. A lenient decoder would map this to U+FFFD and pass.
        $f = Join-Path $tmp 'truncated-emdash.sh'
        [IO.File]::WriteAllBytes($f, [byte[]](0x23, 0x20, 0x61, 0xE2, 0x29, 0x0A))
        Assert (-not (Test-IsValidUtf8 $f)) 'Test-IsValidUtf8 should reject a lone 0xE2 lead byte'
    }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'WorkspaceBom.Tests (repo-wide BOM + UTF-8 gate)')
