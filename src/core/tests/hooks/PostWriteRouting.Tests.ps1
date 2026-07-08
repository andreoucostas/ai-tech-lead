# B-09 -- post-write surface routing + self-filter agreement between the .ps1 and .sh twins.
# Two classes of coverage, both host-independent and build-free (they never reach `dotnet build` /
# `npx tsc`, so they are deterministic and need no toolchain):
#   1. A static guard pinning the B-09a fix: on a malformed/empty payload the .ps1 must default the
#      tool name to '' (not $null). The end-of-hook routing uses `$tn -eq ''` for Claude's empty-case
#      exit-2 path, and `$null -eq ''` is $false in PowerShell -- so a $null default misroutes a build
#      failure to the Copilot exit-0 branch, diverging from the .sh twin's `case ... "")` -> exit 2.
#   2. Build-free decision agreement: for inputs that exit before any build (read-style payloads, and
#      non-source paths), the .ps1 and .sh twins must reach the same exit code.
# (post-write's *build-failure* routing itself can't be exercised in this shared/IDENTICAL tests dir:
# it needs a real .cs-vs-.ts failing build, which is stack-specific and cannot be byte-identical
# across repos. This file covers everything reachable without that.)
if (-not (Get-Command Reset-Tests -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$pwPs  = Join-Path $hooks 'post-write.ps1'
$pwSh  = Join-Path $hooks 'post-write.sh'
$bash  = Get-BashPath

Reset-Tests

# --- 1. B-09a static guard (red against the pre-fix .ps1, which had no top-level $tn default) ---
$psSrc = [System.IO.File]::ReadAllText($pwPs)
$shSrc = [System.IO.File]::ReadAllText($pwSh)
$preamble = ($psSrc -split 'if \(-not \[string\]::IsNullOrEmpty\(\$inputJson\)')[0]

It 'post-write.ps1 defaults $tn to '''' before parsing (so malformed/empty payload is not $null)' {
    Assert ($preamble -match "\`$tn\s*=\s*''") `
        'post-write.ps1 does not pre-declare $tn = '''' ahead of the JSON parse -- malformed input leaves it $null and misroutes build failures away from Claude exit 2'
}
It 'post-write.sh defaults tool_name to "" and routes the empty case to exit 2 (twin of the above)' {
    Assert ($shSrc -match 'tool_name=""') 'post-write.sh does not initialise tool_name=""'
    Assert ($shSrc -match 'Edit\|Write\|""') 'post-write.sh routing case does not send the empty tool_name to the exit-2 (Claude) branch'
}
It 'documents the hazard: $null -eq '''' is $false in PowerShell (the reason the default must be '''')' {
    Assert (($null -eq '') -eq $false) 'PowerShell semantics changed: $null -eq '''' is no longer $false'
    Assert (('' -eq '') -eq $true)     'empty-string equality sanity check failed'
}

# --- 2. Build-free decision agreement between twins (run only where bash is present) ---
$cases = @(
    @{ n = 'read-style payload (path, no content) self-filters to exit 0';
       claude = '{"tool_name":"Read","tool_input":{"file_path":"notes.txt"}}';
       copilot = '{"toolName":"view","toolArgs":{"path":"notes.txt"}}' },
    @{ n = 'write payload on a non-source path (.txt) exits 0 before any build';
       claude = '{"tool_name":"Write","tool_input":{"file_path":"notes.txt","content":"hello world"}}';
       copilot = '{"toolName":"create","toolArgs":{"path":"notes.txt","file_text":"hello world"}}' }
)
if (-not $bash) {
    foreach ($c in $cases) { Skip "post-write twins agree: $($c.n)" 'no bash found -- cannot run .sh twin' }
} else {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("pwroute-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    Push-Location $tmp
    try {
        foreach ($c in $cases) {
            foreach ($surface in 'claude','copilot') {
                $evt = $c[$surface]
                It "post-write twins agree ($surface): $($c.n)" {
                    $dps = Get-Decision (Invoke-Hook $pwPs $evt)
                    $dsh = Get-Decision (Invoke-Hook $pwSh $evt)
                    Assert ($dps -eq $dsh) "post-write.ps1 -> $dps but post-write.sh -> $dsh"
                    Assert ($dps -eq 'ALLOW') "expected ALLOW (exit 0), got $dps"
                }
            }
        }
    } finally {
        Pop-Location
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'PostWriteRouting.Tests (B-09 surface routing)')
