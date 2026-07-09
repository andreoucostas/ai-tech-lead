# B-28 -- build-architecture-html twin agreement: identical input must yield byte-identical output.
# The pre-fix .ps1 diverged from the .sh twin three ways: (1) the head here-string carried no
# trailing newline, joining the opening <script> tag and the first markdown line onto one line;
# (2) each twin stamped its own filename into the GENERATED comment; (3) Set-Content wrote host
# EOLs (+ BOM on PS 5.1) and appended its own trailing newline, where bash writes raw LF, no BOM.
# Consequence: whoever regenerated architecture.html last "won", producing spurious diffs between
# the Windows maintainer (pwsh) and the linux CI leg (bash) -- see BACKLOG B-28 / B-11.
if (-not (Get-Command Reset-Tests -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$scripts = (Resolve-Path (Join-Path $PSScriptRoot '..\..\scripts')).Path
$genPs = Join-Path $scripts 'build-architecture-html.ps1'
$genSh = Join-Path $scripts 'build-architecture-html.sh'
$bash  = Get-BashPath

Reset-Tests

# --- static guards (host-independent; red against the pre-fix .ps1) ---
$psSrc = [System.IO.File]::ReadAllText($genPs)
$shSrc = [System.IO.File]::ReadAllText($genSh)

It 'the .ps1 writes the OUTPUT file BOM-less via .NET, not Set-Content (which adds BOM on 5.1 + a host-EOL trailing newline)' {
    Assert ($psSrc -notmatch 'Set-Content') 'build-architecture-html.ps1 still uses Set-Content -- output encoding/EOL diverges from the bash twin'
    Assert ($psSrc -match 'UTF8Encoding') 'build-architecture-html.ps1 does not construct an explicit BOM-less UTF8Encoding for the output file'
}
It 'both twins stamp the same neutral generator name into the GENERATED comment' {
    $neutral = [regex]::Escape('build-architecture-html.{sh,ps1}')
    Assert ($psSrc -match $neutral) '.ps1 GENERATED comment does not use the neutral {sh,ps1} generator name'
    Assert ($shSrc -match $neutral) '.sh GENERATED comment does not use the neutral {sh,ps1} generator name'
}

# --- twin agreement: byte-identical output from identical (LF) input ---
if (-not $bash) {
    Skip 'twins emit byte-identical HTML from identical markdown' 'no bash found -- cannot run .sh twin'
    Skip 'opening <script> tag sits on its own line (the B-28 join symptom)' 'no bash found -- cannot run .sh twin'
} else {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("archhtml-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    Push-Location $tmp
    try {
        # LF fixture exercising the shapes that exposed the bug: a first line the head tag could
        # join onto, a table, a mermaid block, and non-ASCII text (em dash built from code points
        # so this test file parses identically regardless of its own encoding).
        $u = [string][char]0x2014 + ' ' + [char]0x00FC + ' ' + [char]0x20AC
        $mdLf = "# Fixture`n`nFirst line after the script tag.`n`n| a | b |`n|---|---|`n| 1 | 2 |`n`n" +
                "``````mermaid`ngraph TD; A-->B;`n```````n`nunicode: $u`n"
        [System.IO.File]::WriteAllText((Join-Path $tmp 'fixture.md'), $mdLf, [System.Text.UTF8Encoding]::new($false))

        & (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File $genPs 'fixture.md' 'out-ps.html' 'T' | Out-Null
        $psExit = $LASTEXITCODE
        & $bash $genSh 'fixture.md' 'out-sh.html' 'T' | Out-Null
        $shExit = $LASTEXITCODE

        It 'both twins exit 0 on the fixture' {
            Assert ($psExit -eq 0) "build-architecture-html.ps1 exited $psExit"
            Assert ($shExit -eq 0) "build-architecture-html.sh exited $shExit"
        }
        $bp = [System.IO.File]::ReadAllBytes((Join-Path $tmp 'out-ps.html'))
        $bs = [System.IO.File]::ReadAllBytes((Join-Path $tmp 'out-sh.html'))
        It 'twins emit byte-identical HTML from identical markdown' {
            Assert ($bp.Length -eq $bs.Length) "output length differs: .ps1=$($bp.Length) bytes, .sh=$($bs.Length) bytes"
            $diffAt = -1
            for ($i = 0; $i -lt $bp.Length; $i++) { if ($bp[$i] -ne $bs[$i]) { $diffAt = $i; break } }
            Assert ($diffAt -lt 0) "first differing byte at offset $diffAt (.ps1=0x$($bp[$diffAt].ToString('x2')) .sh=0x$($bs[$diffAt].ToString('x2')))"
        }
        It 'opening <script> tag sits on its own line (the B-28 join symptom)' {
            $txt = [System.IO.File]::ReadAllText((Join-Path $tmp 'out-ps.html'))
            Assert ($txt -match ('<script id="md" type="text/markdown">' + "`n" + '# Fixture')) `
                'the opening <script id="md"> tag and the first markdown line are joined -- the head is missing its trailing newline'
        }
    } finally {
        Pop-Location
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'BuildArchitectureHtml.Tests (B-28 twin parity)')
