# Tests for the repo meta-dev hooks. Only bom-fix remains (the review-on-stop / mark-changed /
# reset-marker apparatus was retired as a mis-cadenced blocking Stop hook). These do NOT ship.
# Side effects (file rewrites) are isolated to a throwaway temp dir; the real repo is never touched.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$meta     = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path   # the repo .claude\hooks dir
$bomfix   = Join-Path $meta 'bom-fix.ps1'
$bomfixSh = Join-Path $meta 'bom-fix.sh'

function Test-Bom { param($p) $b=[IO.File]::ReadAllBytes($p); ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) }
function Write-NoBom { param($p,$txt) [IO.File]::WriteAllText($p, $txt, (New-Object System.Text.UTF8Encoding($false))) }

Reset-Tests
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("metahooks-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    # bom-fix: scoped to ai-tech-lead/ paths (the merged repo — WSD-012 D7), idempotent,
    # content-preserving, .ps1-only.
    $repoish = Join-Path $tmp 'ai-tech-lead\sub'; New-Item -ItemType Directory -Path $repoish -Force | Out-Null
    $other   = Join-Path $tmp 'other';            New-Item -ItemType Directory -Path $other   -Force | Out-Null

    It 'bom-fix adds a BOM to a bomless .ps1 under an ai-tech-lead/ path, content intact' {
        $f = Join-Path $repoish 'x.ps1'; Write-NoBom $f "exit 0`n"
        Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress) | Out-Null
        Assert (Test-Bom $f) 'BOM was not added'
        Assert (([IO.File]::ReadAllText($f)).Trim() -eq 'exit 0') 'content changed'
    }
    It 'bom-fix is idempotent (already-BOM .ps1 unchanged)' {
        $f = Join-Path $repoish 'y.ps1'; [IO.File]::WriteAllText($f, "exit 0`n", (New-Object System.Text.UTF8Encoding($true)))
        $before = [IO.File]::ReadAllBytes($f).Length
        Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress) | Out-Null
        Assert ([IO.File]::ReadAllBytes($f).Length -eq $before) 'idempotent run changed the file'
    }
    It 'bom-fix leaves a .ps1 OUTSIDE ai-tech-lead/ untouched (scope guard)' {
        $f = Join-Path $other 'z.ps1'; Write-NoBom $f "exit 0`n"
        Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress) | Out-Null
        Assert (-not (Test-Bom $f)) 'should not have touched a file outside the repo'
    }
    It 'bom-fix does not fire on the LEGACY repo names (ai-tech-lead-dotnet is out of scope now)' {
        $legacy = Join-Path $tmp 'ai-tech-lead-dotnet'; New-Item -ItemType Directory -Path $legacy -Force | Out-Null
        $f = Join-Path $legacy 'l.ps1'; Write-NoBom $f "exit 0`n"
        Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress) | Out-Null
        Assert (-not (Test-Bom $f)) 'legacy repos are frozen — the hook must not rewrite them'
    }
    It 'bom-fix ignores non-.ps1 files' {
        $f = Join-Path $repoish 'note.txt'; Write-NoBom $f 'hi'
        Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress) | Out-Null
        Assert (-not (Test-Bom $f)) 'should not have rewritten a .txt'
    }

    # Twin parity [#3]: bom-fix.sh must make the same decisions as bom-fix.ps1. Self-skips without bash.
    if (Get-BashPath) {
        It 'bom-fix.sh twin adds a BOM to a bomless .ps1 under an ai-tech-lead/ path, content intact' {
            $f = Join-Path $repoish 'sh1.ps1'; Write-NoBom $f "exit 0`n"
            $fwd = $f -replace '\\','/'
            Invoke-Hook $bomfixSh (@{tool_name='Write';tool_input=@{file_path=$fwd}} | ConvertTo-Json -Compress) | Out-Null
            Assert (Test-Bom $f) 'BOM was not added by the .sh twin'
            Assert (([IO.File]::ReadAllText($f)).Trim() -eq 'exit 0') 'content changed'
        }
        It 'bom-fix.sh twin is idempotent (already-BOM .ps1 unchanged)' {
            $f = Join-Path $repoish 'sh2.ps1'; [IO.File]::WriteAllText($f, "exit 0`n", (New-Object System.Text.UTF8Encoding($true)))
            $before = [IO.File]::ReadAllBytes($f).Length
            $fwd = $f -replace '\\','/'
            Invoke-Hook $bomfixSh (@{tool_name='Write';tool_input=@{file_path=$fwd}} | ConvertTo-Json -Compress) | Out-Null
            Assert ([IO.File]::ReadAllBytes($f).Length -eq $before) 'idempotent run changed the file'
        }
        It 'bom-fix.sh twin leaves a .ps1 OUTSIDE ai-tech-lead/ untouched (scope guard)' {
            $f = Join-Path $other 'sh3.ps1'; Write-NoBom $f "exit 0`n"
            $fwd = $f -replace '\\','/'
            Invoke-Hook $bomfixSh (@{tool_name='Write';tool_input=@{file_path=$fwd}} | ConvertTo-Json -Compress) | Out-Null
            Assert (-not (Test-Bom $f)) 'should not have touched a file outside the repo'
        }
        It 'bom-fix.sh twin does not fire on the LEGACY repo names (twin agreement on the new scope)' {
            $legacy = Join-Path $tmp 'ai-tech-lead-angular'; New-Item -ItemType Directory -Path $legacy -Force | Out-Null
            $f = Join-Path $legacy 'lsh.ps1'; Write-NoBom $f "exit 0`n"
            $fwd = $f -replace '\\','/'
            Invoke-Hook $bomfixSh (@{tool_name='Write';tool_input=@{file_path=$fwd}} | ConvertTo-Json -Compress) | Out-Null
            Assert (-not (Test-Bom $f)) 'legacy repos are frozen — the .sh twin must not rewrite them'
        }
    } else {
        Skip 'bom-fix.sh twin tests' 'bash not found on this host'
    }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'MetaHooks.Tests (bom-fix)')
