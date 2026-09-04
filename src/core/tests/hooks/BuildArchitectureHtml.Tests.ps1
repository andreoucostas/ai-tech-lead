# build-architecture-html.ps1 deterministic-output contract.
if (-not (Get-Command Reset-Tests -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$scripts = (Resolve-Path (Join-Path $PSScriptRoot '..\..\scripts')).Path
$generator = Join-Path $scripts 'build-architecture-html.ps1'
Reset-Tests

$source = [IO.File]::ReadAllText($generator)
It 'writes BOM-less UTF-8 via .NET rather than a host-dependent content cmdlet' {
    Assert ($source -notmatch 'Set-Content') 'generator still uses Set-Content'
    Assert ($source -match 'UTF8Encoding') 'generator does not construct explicit UTF-8 encoding'
    Assert ($source -match 'WriteAllText') 'generator does not write through the byte-stable .NET path'
}
It 'stamps the supported PowerShell generator into the generated banner' {
    Assert ($source -match [regex]::Escape('scripts/build-architecture-html.ps1')) 'PowerShell generator banner is missing'
    Assert ($source -notmatch 'build-architecture-html\.\{sh,ps1\}') 'retired twin banner remains'
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ('archhtml-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
Push-Location $tmp
try {
    $unicode = [string][char]0x2014 + ' ' + [char]0x00FC + ' ' + [char]0x20AC
    $markdown = "# Fixture`n`nFirst line after the script tag.`n`n| a | b |`n|---|---|`n| 1 | 2 |`n`n" +
        "``````mermaid`ngraph TD; A-->B;`n```````n`nunicode: $unicode`n"
    [IO.File]::WriteAllText((Join-Path $tmp 'fixture.md'), $markdown, [Text.UTF8Encoding]::new($false))
    & (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File $generator 'fixture.md' 'output.html' 'T' | Out-Null
    $exit = [int]$LASTEXITCODE
    $bytes = [IO.File]::ReadAllBytes((Join-Path $tmp 'output.html'))
    $text = [IO.File]::ReadAllText((Join-Path $tmp 'output.html'))

    It 'exits zero and emits the exercised HTML shapes' {
        Assert ($exit -eq 0) "generator exited $exit"
        foreach ($fragment in @('# Fixture','| a | b |','graph TD; A-->B;','unicode:')) {
            Assert ($text.Contains($fragment)) "fixture did not reach output fragment '$fragment'"
        }
    }
    It 'keeps the opening markdown script tag on its own line' {
        Assert ($text -match ('<script id="md" type="text/markdown">' + "`n" + '# Fixture')) 'opening script tag joined the first markdown line'
    }
    It 'emits deterministic LF-only, BOM-less UTF-8 with one trailing newline' {
        Assert (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) 'output contains a UTF-8 BOM'
        Assert (-not $text.Contains("`r")) 'output contains CR/host line endings'
        Assert ($text.EndsWith("`n") -and -not $text.EndsWith("`n`n")) 'output does not end in exactly one LF'
    }
} finally {
    Pop-Location
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'BuildArchitectureHtml.Tests')
