# Tests for the repo meta-dev hooks. Only bom-fix remains (the review-on-stop / mark-changed /
# reset-marker apparatus was retired as a mis-cadenced blocking Stop hook). These do NOT ship.
# Side effects (file rewrites) are isolated to a throwaway temp dir; the real repo is never touched.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$meta     = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path   # the repo .claude\hooks dir
$bomfix   = Join-Path $meta 'bom-fix.ps1'

function Test-Bom { param($p) $b=[IO.File]::ReadAllBytes($p); ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) }
function Write-NoBom { param($p,$txt) [IO.File]::WriteAllText($p, $txt, (New-Object System.Text.UTF8Encoding($false))) }

function Invoke-CardinalityFixture {
    param([string]$Root, [string]$Body, [string]$ManifestName)
    $fixture = Join-Path $Root 'Probe.Tests.ps1'
    [IO.File]::WriteAllText($fixture, $Body, (New-Object Text.UTF8Encoding($true)))
    $manifest = Join-Path $Root $ManifestName
    if (Test-Path -LiteralPath $manifest) { Remove-Item -LiteralPath $manifest -Force }
    $savedErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $out = & (Get-Process -Id $PID).Path -NoProfile -ExecutionPolicy Bypass -File `
            (Join-Path $Root 'Invoke-HookTests.ps1') -FixtureDiscovery -CaseCountPath $manifest 2>&1
        $exit = [int]$LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorActionPreference
    }
    [pscustomobject]@{ Exit=$exit; Out=(@($out) -join "`n"); Manifest=$manifest }
}

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
        $r = Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress)
        Assert ($null -ne $r -and $r.Exit -eq 0) "bom-fix exited $(if($null -eq $r){'SKIP'}else{$r.Exit}) -- a hook that fails is not a hook that declined"
        Assert (Test-Bom $f) 'BOM was not added'
        Assert (([IO.File]::ReadAllText($f)).Trim() -eq 'exit 0') 'content changed'
    }
    It 'bom-fix is idempotent (already-BOM .ps1 unchanged)' {
        $f = Join-Path $repoish 'y.ps1'; [IO.File]::WriteAllText($f, "exit 0`n", (New-Object System.Text.UTF8Encoding($true)))
        $before = [IO.File]::ReadAllBytes($f).Length
        $r = Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress)
        Assert ($null -ne $r -and $r.Exit -eq 0) "bom-fix exited $(if($null -eq $r){'SKIP'}else{$r.Exit}) -- a hook that fails is not a hook that declined"
        Assert ([IO.File]::ReadAllBytes($f).Length -eq $before) 'idempotent run changed the file'
    }
    It 'bom-fix leaves a .ps1 OUTSIDE ai-tech-lead/ untouched (scope guard)' {
        $f = Join-Path $other 'z.ps1'; Write-NoBom $f "exit 0`n"
        $r = Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress)
        Assert ($null -ne $r -and $r.Exit -eq 0) "bom-fix exited $(if($null -eq $r){'SKIP'}else{$r.Exit}) -- a hook that fails is not a hook that declined"
        Assert (-not (Test-Bom $f)) 'should not have touched a file outside the repo'
    }
    It 'bom-fix does not fire on the LEGACY repo names (ai-tech-lead-dotnet is out of scope now)' {
        $legacy = Join-Path $tmp 'ai-tech-lead-dotnet'; New-Item -ItemType Directory -Path $legacy -Force | Out-Null
        $f = Join-Path $legacy 'l.ps1'; Write-NoBom $f "exit 0`n"
        $r = Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress)
        Assert ($null -ne $r -and $r.Exit -eq 0) "bom-fix exited $(if($null -eq $r){'SKIP'}else{$r.Exit}) -- a hook that fails is not a hook that declined"
        Assert (-not (Test-Bom $f)) 'legacy repos are frozen — the hook must not rewrite them'
    }
    It 'bom-fix ignores non-.ps1 files' {
        $f = Join-Path $repoish 'note.txt'; Write-NoBom $f 'hi'
        $r = Invoke-Hook $bomfix (@{tool_name='Write';tool_input=@{file_path=$f}} | ConvertTo-Json -Compress)
        Assert ($null -ne $r -and $r.Exit -eq 0) "bom-fix exited $(if($null -eq $r){'SKIP'}else{$r.Exit}) -- a hook that fails is not a hook that declined"
        Assert (-not (Test-Bom $f)) 'should not have rewritten a .txt'
    }

    # This manifest is the CI equality oracle between direct PS7 and PS5.1 runs. Refuse every
    # vacuous or ambiguous child shape, and pin its bytes so host encoding cannot forge equality.
    $cardinalityRoot = Join-Path $tmp 'aggregate-cardinality'
    New-Item -ItemType Directory -Path $cardinalityRoot -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-HookTests.ps1') -Destination $cardinalityRoot
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '_HookHarness.ps1') -Destination $cardinalityRoot

    It 'aggregate rejects a child with no semantic case marker' {
        $r = Invoke-CardinalityFixture $cardinalityRoot "exit 0`n" 'missing.txt'
        Assert ($r.Exit -ne 0) "missing marker stayed green: $($r.Out)"
        Assert ($r.Out -match 'emitted 0 CASE_COUNT markers') "missing marker was not diagnosed: $($r.Out)"
        Assert (-not (Test-Path -LiteralPath $r.Manifest)) 'missing marker produced a manifest'
    }
    It 'aggregate rejects a zero semantic case marker' {
        $r = Invoke-CardinalityFixture $cardinalityRoot "Write-Host 'CASE_COUNT 0'`nexit 0`n" 'zero.txt'
        Assert ($r.Exit -ne 0) "zero marker stayed green: $($r.Out)"
        Assert ($r.Out -match 'non-positive CASE_COUNT') "zero marker was not diagnosed: $($r.Out)"
        Assert (-not (Test-Path -LiteralPath $r.Manifest)) 'zero marker produced a manifest'
    }
    It 'aggregate rejects a suite whose only semantic case was skipped' {
        $body = @'
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
Reset-Tests
Skip 'Windows case' 'fixture deliberately did not execute'
exit (Write-TestSummary 'skip-only fixture')
'@
        $r = Invoke-CardinalityFixture $cardinalityRoot $body 'skip-only.txt'
        Assert ($r.Exit -ne 0) "skip-only suite stayed green: $($r.Out)"
        Assert ($r.Out -match 'CASE_COUNT 0' -and $r.Out -match 'non-positive CASE_COUNT') `
            "skip-only suite was not classified as zero executed cases: $($r.Out)"
        Assert (-not (Test-Path -LiteralPath $r.Manifest)) 'skip-only suite produced a manifest'
    }
    It 'aggregate rejects duplicate semantic case markers' {
        $r = Invoke-CardinalityFixture $cardinalityRoot "Write-Host 'CASE_COUNT 1'`nWrite-Host 'CASE_COUNT 2'`nexit 0`n" 'duplicate.txt'
        Assert ($r.Exit -ne 0) "duplicate markers stayed green: $($r.Out)"
        Assert ($r.Out -match 'emitted 2 CASE_COUNT markers') "duplicate markers were not diagnosed: $($r.Out)"
        Assert (-not (Test-Path -LiteralPath $r.Manifest)) 'duplicate markers produced a manifest'
    }
    It 'aggregate semantic case manifest is deterministic UTF-8 without BOM' {
        $body = "Write-Host 'CASE_COUNT 3'`nexit 0`n"
        $first = Invoke-CardinalityFixture $cardinalityRoot $body 'first.txt'
        $second = Invoke-CardinalityFixture $cardinalityRoot $body 'second.txt'
        Assert ($first.Exit -eq 0 -and $second.Exit -eq 0) "valid marker failed: $($first.Out)`n$($second.Out)"
        $a = [IO.File]::ReadAllBytes($first.Manifest)
        $b = [IO.File]::ReadAllBytes($second.Manifest)
        Assert ($a.Length -gt 0 -and $b.Length -gt 0) 'valid marker produced an empty manifest'
        Assert (-not ($a.Length -ge 3 -and $a[0] -eq 0xEF -and $a[1] -eq 0xBB -and $a[2] -eq 0xBF)) 'manifest unexpectedly has a UTF-8 BOM'
        Assert ([Convert]::ToBase64String($a) -ceq [Convert]::ToBase64String($b)) 'identical runs produced different manifest bytes'
        Assert ([Text.Encoding]::UTF8.GetString($a) -ceq "Probe.Tests.ps1`t3`nTOTAL`t3`n") 'manifest format/content differs from its canonical form'
    }
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'MetaHooks.Tests (bom-fix)')
