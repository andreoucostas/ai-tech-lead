# ComposerFixtures.Tests.ps1 -- fixture-based regression suite for the composer twins
# (scripts/build.sh / build.ps1). Pins the marker-substitution, monorepo union/override,
# whole-file overlay + collision-check, unresolved-marker validation, invalid-mode usage,
# and byte-fidelity (BOM/CRLF/trailing-newline) semantics documented in the composer header
# comments -- plus a same-fixture .ps1-vs-.sh byte-identity proof (F12). Fixtures are
# programmatic, never committed bytes (committed fixture bytes would be exposed to
# core.autocrlf/BOM mangling -- LEARNINGS 2026-07-04): every fixture file is written via
# [IO.File]::WriteAllBytes with exact bytes computed in this file. Each test copies the
# REAL scripts/build.sh + build.ps1 (the bytes under test, unmodified) into a throwaway
# sandbox and runs them as child processes; the real repo's src/ and dist/ are never
# touched. Wired into release.ps1 and both ci.yml legs via Invoke-HookTests.ps1
# auto-discovery (globs *.Tests.ps1). Does NOT ship (meta-only, B-33).
. (Join-Path $PSScriptRoot '_HookHarness.ps1')

$repoRoot     = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path   # ai-tech-lead repo root
$RealBuildSh  = Join-Path $repoRoot 'scripts/build.sh'
$RealBuildPs1 = Join-Path $repoRoot 'scripts/build.ps1'

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$BomBytes  = [byte[]](0xEF, 0xBB, 0xBF)

$script:AllSandboxes = New-Object System.Collections.Generic.List[string]

# --- fixture-harness helpers ---------------------------------------------------------------

# Copies the real composer twins into <tmp>/scripts and pre-creates the six stack dirs the
# .ps1's collision check Resolve-Path's under EAP=Stop, plus an empty src/core. Registers the
# path for cleanup in the outer finally block.
function New-Sandbox {
    $root = Join-Path ([IO.Path]::GetTempPath()) ("composerfixtures-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    $scriptsDir = Join-Path $root 'scripts'
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    Copy-Item -LiteralPath $RealBuildPs1 -Destination (Join-Path $scriptsDir 'build.ps1') -Force
    Copy-Item -LiteralPath $RealBuildSh  -Destination (Join-Path $scriptsDir 'build.sh')  -Force
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'src/core') | Out-Null
    foreach ($stack in @('dotnet', 'angular', 'monorepo')) {
        foreach ($kind in @('snippets', 'files')) {
            New-Item -ItemType Directory -Force -Path (Join-Path $root "src/stacks/$stack/$kind") | Out-Null
        }
    }
    $script:AllSandboxes.Add($root)
    return $root
}

# LF-joined, UTF-8-no-BOM text bytes -- the common case for fixture core/snippet/overlay files.
function Get-LfBytes {
    param([string[]]$Lines, [bool]$TrailingNewline = $true)
    if ($Lines.Count -eq 0) {
        $text = ''
    } else {
        $text = [string]::Join("`n", $Lines)
        if ($TrailingNewline) { $text = $text + "`n" }
    }
    return $Utf8NoBom.GetBytes($text)
}

function Write-Bytes {
    param([string]$Path, [byte[]]$Bytes)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [IO.File]::WriteAllBytes($Path, $Bytes)
}

function Assert-FileBytes {
    param([string]$Path, [byte[]]$Expected, [string]$Msg)
    Assert (Test-Path -LiteralPath $Path -PathType Leaf) "$Msg -- file missing: $Path"
    $actual = [IO.File]::ReadAllBytes($Path)
    Assert ($actual.Length -eq $Expected.Length) "$Msg -- length differs: actual=$($actual.Length) expected=$($Expected.Length)"
    for ($i = 0; $i -lt $actual.Length; $i++) {
        if ($actual[$i] -ne $Expected[$i]) {
            $af = '{0:X2}' -f $actual[$i]
            $ef = '{0:X2}' -f $Expected[$i]
            Assert $false "$Msg -- byte differs at offset $i (actual=0x$af expected=0x$ef)"
        }
    }
}

function Assert-FileAbsent {
    param([string]$Path, [string]$Msg)
    Assert (-not (Test-Path -LiteralPath $Path -PathType Leaf)) $Msg
}

# Relative paths (forward-slash, sorted) of every file under Root -- for tree-set comparison.
function Get-RelFileSet {
    param([string]$Root)
    if (-not (Test-Path -LiteralPath $Root)) { return @() }
    $rootFull = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\', '/')
    $items = Get-ChildItem -LiteralPath $Root -Recurse -File -Force
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($it in $items) {
        $rel = $it.FullName.Substring($rootFull.Length).TrimStart('\', '/')
        $out.Add(($rel -replace '\\', '/'))
    }
    return $out.ToArray() | Sort-Object
}

function Assert-BytesEqual {
    param([string]$PathA, [string]$PathB, [string]$Msg)
    $a = [IO.File]::ReadAllBytes($PathA)
    $b = [IO.File]::ReadAllBytes($PathB)
    Assert ($a.Length -eq $b.Length) "$Msg -- length differs: $($a.Length) vs $($b.Length)"
    for ($i = 0; $i -lt $a.Length; $i++) {
        if ($a[$i] -ne $b[$i]) { Assert $false "$Msg -- byte differs at offset $i" }
    }
}

# Recursive tree-compare: same relative-path set on both sides, then byte-compare each pair.
function Assert-SameTree {
    param([string]$RootA, [string]$RootB, [string]$Msg)
    $setA = @(Get-RelFileSet $RootA)
    $setB = @(Get-RelFileSet $RootB)
    $onlyA = @($setA | Where-Object { $setB -notcontains $_ })
    $onlyB = @($setB | Where-Object { $setA -notcontains $_ })
    Assert (($onlyA.Count -eq 0) -and ($onlyB.Count -eq 0)) "$Msg -- tree mismatch: only-in-A=[$($onlyA -join ',')] only-in-B=[$($onlyB -join ',')]"
    foreach ($rel in $setA) {
        Assert-BytesEqual (Join-Path $RootA $rel) (Join-Path $RootB $rel) "$Msg ($rel)"
    }
}

# Runs one composer twin as a child process. Twin is 'ps1' or 'sh'. Never sets
# $ErrorActionPreference='Stop' around this call (native stderr under Stop throws a
# terminating NativeCommandError); stderr is captured via redirect-to-tempfile, and
# $LASTEXITCODE is read immediately after the call, never through a truncating pipe.
#
# Both twins are deliberately spawned WITHOUT changing this process's cwd first: the sandbox
# is always a foreign directory relative to the test runner, so every fixture also exercises
# the composers' self-anchoring (`cd "$(dirname "$0")/.."` in the .sh; Set-Location + the
# [Environment]::CurrentDirectory sync in the .ps1 -- the fixture work found the .ps1's raw
# [System.IO.File] calls resolve against the PROCESS cwd, which Set-Location alone does not
# move; see build.ps1's anchor comment and LEARNINGS 2026-07-11).
function Invoke-Composer {
    param([string]$Sandbox, [string]$Mode, [string]$Twin)
    if ($Twin -eq 'sh') {
        $bash = Get-BashPath
        if (-not $bash) { return $null }
    }
    $ef = [IO.Path]::GetTempFileName()
    try {
        if ($Twin -eq 'ps1') {
            $scriptPath = Join-Path $Sandbox 'scripts/build.ps1'
            $out = & (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File $scriptPath $Mode 2>$ef
        } else {
            $scriptPath = Join-Path $Sandbox 'scripts/build.sh'
            $out = & $bash $scriptPath $Mode 2>$ef
        }
        $code = $LASTEXITCODE
        $errText = [IO.File]::ReadAllText($ef)
        return [pscustomobject]@{ Exit = $code; Out = ($out -join "`n"); Err = $errText }
    } finally {
        if (Test-Path -LiteralPath $ef) { [IO.File]::Delete($ef) }
    }
}

# Runs an It per available twin (ps1 always; sh only if Get-BashPath resolves) against the
# same already-populated Sandbox/Mode, handing the assertion scriptblock a context object
# {Sandbox, Mode, Twin, Result}. Emits a Skip entry for the sh leg when bash is absent.
function Invoke-BothTwins {
    param([string]$NamePrefix, [string]$Sandbox, [string]$Mode, [scriptblock]$Assertion)
    $twins = @('ps1')
    if (Get-BashPath) { $twins += 'sh' }
    foreach ($twin in $twins) {
        It ("{0} [{1}]" -f $NamePrefix, $twin) {
            $r = Invoke-Composer -Sandbox $Sandbox -Mode $Mode -Twin $twin
            $ctx = [pscustomobject]@{ Sandbox = $Sandbox; Mode = $Mode; Twin = $twin; Result = $r }
            & $Assertion $ctx
        }
    }
    if (-not (Get-BashPath)) { Skip ("{0} [sh]" -f $NamePrefix) 'bash not found on this host' }
}

# F12's representative green tree: markers (single-stack + concat-union, no monorepo override
# on one marker, monorepo-only snippet on another) + whole-file overlays (per-stack, monorepo,
# and a dotnet override of a core file) -- exercises every composer mechanism at once so a
# .ps1-vs-.sh byte-identity check on it is a meaningful twin-agreement proof.
function Populate-GreenFixture {
    param([string]$Sandbox)
    Write-Bytes (Join-Path $Sandbox 'src/core/README.md') (Get-LfBytes @('Head', '<!-- @stack:sect -->', 'Tail'))
    Write-Bytes (Join-Path $Sandbox 'src/stacks/dotnet/snippets/README.md/sect') (Get-LfBytes @('D-only'))
    Write-Bytes (Join-Path $Sandbox 'src/stacks/angular/snippets/README.md/sect') (Get-LfBytes @('A-only'))

    Write-Bytes (Join-Path $Sandbox 'src/core/config.sh') (Get-LfBytes @('#!/usr/bin/env bash', '# @stack:setup', 'echo base'))
    Write-Bytes (Join-Path $Sandbox 'src/stacks/monorepo/snippets/config.sh/setup') (Get-LfBytes @('echo monorepo-setup'))

    Write-Bytes (Join-Path $Sandbox 'src/core/plain.md') (Get-LfBytes @('No markers here'))

    Write-Bytes (Join-Path $Sandbox 'src/core/override-me.md') (Get-LfBytes @('core version'))
    Write-Bytes (Join-Path $Sandbox 'src/stacks/dotnet/files/override-me.md') (Get-LfBytes @('dotnet version'))

    Write-Bytes (Join-Path $Sandbox 'src/stacks/dotnet/files/only-dotnet.md') (Get-LfBytes @('dotnet file'))
    Write-Bytes (Join-Path $Sandbox 'src/stacks/angular/files/only-angular.md') (Get-LfBytes @('angular file'))
    Write-Bytes (Join-Path $Sandbox 'src/stacks/monorepo/files/only-monorepo.md') (Get-LfBytes @('monorepo file'))
}

# --- fixture matrix (F1-F12, per the locked plan) -------------------------------------------

Reset-Tests
try {
    # F1: HTML marker substitution, single-stack (dotnet) -- marker line replaced by snippet lines.
    $sb1 = New-Sandbox
    Write-Bytes (Join-Path $sb1 'src/core/README.md') (Get-LfBytes @('# Title', '<!-- @stack:intro -->', 'Footer line'))
    Write-Bytes (Join-Path $sb1 'src/stacks/dotnet/snippets/README.md/intro') (Get-LfBytes @('Dotnet intro line 1', 'Dotnet intro line 2'))
    $expectF1 = Get-LfBytes @('# Title', 'Dotnet intro line 1', 'Dotnet intro line 2', 'Footer line')
    Invoke-BothTwins -NamePrefix 'F1 HTML marker substitution, single-stack (dotnet)' -Sandbox $sb1 -Mode 'dotnet' -Assertion {
        param($ctx)
        Assert ($ctx.Result.Exit -eq 0) "compose failed: $($ctx.Result.Err)"
        Assert-FileBytes (Join-Path $ctx.Sandbox 'dist/dotnet/README.md') $expectF1 'F1 dist bytes'
    }

    # F2: hash marker substitution (scripts), single-stack (dotnet) -- same mechanism, '#' form.
    $sb2 = New-Sandbox
    Write-Bytes (Join-Path $sb2 'src/core/.claude/hooks/h.sh') (Get-LfBytes @('#!/usr/bin/env bash', '# @stack:extra', 'echo done'))
    Write-Bytes (Join-Path $sb2 'src/stacks/dotnet/snippets/.claude/hooks/h.sh/extra') (Get-LfBytes @('echo dotnet-only-1', 'echo dotnet-only-2'))
    $expectF2 = Get-LfBytes @('#!/usr/bin/env bash', 'echo dotnet-only-1', 'echo dotnet-only-2', 'echo done')
    Invoke-BothTwins -NamePrefix 'F2 hash marker substitution (scripts), single-stack (dotnet)' -Sandbox $sb2 -Mode 'dotnet' -Assertion {
        param($ctx)
        Assert ($ctx.Result.Exit -eq 0) "compose failed: $($ctx.Result.Err)"
        Assert-FileBytes (Join-Path $ctx.Sandbox 'dist/dotnet/.claude/hooks/h.sh') $expectF2 'F2 dist bytes'
    }

    # F3: absent snippet -- marker line is simply gone, no blank residue, no literal "@stack:" text.
    $sb3 = New-Sandbox
    Write-Bytes (Join-Path $sb3 'src/core/README.md') (Get-LfBytes @('Head', '<!-- @stack:opt -->', 'Tail'))
    $expectF3 = Get-LfBytes @('Head', 'Tail')
    Invoke-BothTwins -NamePrefix 'F3 absent snippet removes marker line cleanly (angular)' -Sandbox $sb3 -Mode 'angular' -Assertion {
        param($ctx)
        Assert ($ctx.Result.Exit -eq 0) "compose failed: $($ctx.Result.Err)"
        Assert-FileBytes (Join-Path $ctx.Sandbox 'dist/angular/README.md') $expectF3 'F3 dist bytes'
    }

    # F4: monorepo authored override wins -- ONLY the monorepo snippet, never the dotnet+angular concat.
    $sb4 = New-Sandbox
    Write-Bytes (Join-Path $sb4 'src/core/README.md') (Get-LfBytes @('Head', '<!-- @stack:combo -->', 'Tail'))
    Write-Bytes (Join-Path $sb4 'src/stacks/dotnet/snippets/README.md/combo') (Get-LfBytes @('DOTNET LINE'))
    Write-Bytes (Join-Path $sb4 'src/stacks/angular/snippets/README.md/combo') (Get-LfBytes @('ANGULAR LINE'))
    Write-Bytes (Join-Path $sb4 'src/stacks/monorepo/snippets/README.md/combo') (Get-LfBytes @('MONO LINE A', 'MONO LINE B'))
    $expectF4 = Get-LfBytes @('Head', 'MONO LINE A', 'MONO LINE B', 'Tail')
    Invoke-BothTwins -NamePrefix 'F4 monorepo authored override wins over concat' -Sandbox $sb4 -Mode 'monorepo' -Assertion {
        param($ctx)
        Assert ($ctx.Result.Exit -eq 0) "compose failed: $($ctx.Result.Err)"
        Assert-FileBytes (Join-Path $ctx.Sandbox 'dist/monorepo/README.md') $expectF4 'F4 dist bytes'
    }

    # F5: monorepo concat union (no monorepo snippet) -- dotnet lines then angular lines; also one-sided.
    $sb5a = New-Sandbox
    Write-Bytes (Join-Path $sb5a 'src/core/README.md') (Get-LfBytes @('Head', '<!-- @stack:union -->', 'Tail'))
    Write-Bytes (Join-Path $sb5a 'src/stacks/dotnet/snippets/README.md/union') (Get-LfBytes @('D1', 'D2'))
    Write-Bytes (Join-Path $sb5a 'src/stacks/angular/snippets/README.md/union') (Get-LfBytes @('A1'))
    $expectF5a = Get-LfBytes @('Head', 'D1', 'D2', 'A1', 'Tail')
    Invoke-BothTwins -NamePrefix 'F5 monorepo concat union, two-sided (dotnet then angular)' -Sandbox $sb5a -Mode 'monorepo' -Assertion {
        param($ctx)
        Assert ($ctx.Result.Exit -eq 0) "compose failed: $($ctx.Result.Err)"
        Assert-FileBytes (Join-Path $ctx.Sandbox 'dist/monorepo/README.md') $expectF5a 'F5 two-sided dist bytes'
    }

    $sb5b = New-Sandbox
    Write-Bytes (Join-Path $sb5b 'src/core/README.md') (Get-LfBytes @('Head', '<!-- @stack:onesided -->', 'Tail'))
    Write-Bytes (Join-Path $sb5b 'src/stacks/angular/snippets/README.md/onesided') (Get-LfBytes @('ONLY A1', 'ONLY A2'))
    $expectF5b = Get-LfBytes @('Head', 'ONLY A1', 'ONLY A2', 'Tail')
    Invoke-BothTwins -NamePrefix 'F5 monorepo concat union, one-sided (angular only)' -Sandbox $sb5b -Mode 'monorepo' -Assertion {
        param($ctx)
        Assert ($ctx.Result.Exit -eq 0) "compose failed: $($ctx.Result.Err)"
        Assert-FileBytes (Join-Path $ctx.Sandbox 'dist/monorepo/README.md') $expectF5b 'F5 one-sided dist bytes'
    }

    # F6: whole-file override -- files/ beats core in that stack's dist; core intact in the other.
    $sb6 = New-Sandbox
    Write-Bytes (Join-Path $sb6 'src/core/docs/x.md') (Get-LfBytes @('CORE CONTENT LINE'))
    Write-Bytes (Join-Path $sb6 'src/stacks/dotnet/files/docs/x.md') (Get-LfBytes @('DOTNET OVERRIDE LINE'))
    $expectF6dotnet = Get-LfBytes @('DOTNET OVERRIDE LINE')
    $expectF6angular = Get-LfBytes @('CORE CONTENT LINE')
    Invoke-BothTwins -NamePrefix 'F6 whole-file override wins in dotnet dist' -Sandbox $sb6 -Mode 'dotnet' -Assertion {
        param($ctx)
        Assert ($ctx.Result.Exit -eq 0) "compose failed: $($ctx.Result.Err)"
        Assert-FileBytes (Join-Path $ctx.Sandbox 'dist/dotnet/docs/x.md') $expectF6dotnet 'F6 dotnet dist bytes'
    }
    Invoke-BothTwins -NamePrefix 'F6 core file intact in angular dist (no override there)' -Sandbox $sb6 -Mode 'angular' -Assertion {
        param($ctx)
        Assert ($ctx.Result.Exit -eq 0) "compose failed: $($ctx.Result.Err)"
        Assert-FileBytes (Join-Path $ctx.Sandbox 'dist/angular/docs/x.md') $expectF6angular 'F6 angular dist bytes'
    }

    # F7: stack-only file -- present in its own stack's dist, absent from the other.
    $sb7 = New-Sandbox
    Write-Bytes (Join-Path $sb7 'src/stacks/angular/files/only-ng.md') (Get-LfBytes @('ANGULAR ONLY'))
    $expectF7 = Get-LfBytes @('ANGULAR ONLY')
    Invoke-BothTwins -NamePrefix 'F7 stack-only file present in angular dist' -Sandbox $sb7 -Mode 'angular' -Assertion {
        param($ctx)
        Assert ($ctx.Result.Exit -eq 0) "compose failed: $($ctx.Result.Err)"
        Assert-FileBytes (Join-Path $ctx.Sandbox 'dist/angular/only-ng.md') $expectF7 'F7 angular dist bytes'
    }
    Invoke-BothTwins -NamePrefix 'F7 stack-only file absent from dotnet dist' -Sandbox $sb7 -Mode 'dotnet' -Assertion {
        param($ctx)
        Assert ($ctx.Result.Exit -eq 0) "compose failed: $($ctx.Result.Err)"
        Assert-FileAbsent (Join-Path $ctx.Sandbox 'dist/dotnet/only-ng.md') 'F7 should be absent from dotnet dist'
    }

    # F8 (RED->GREEN): monorepo files/ collision, no override -> exit 1 naming the relpath;
    # add an override -> exit 0, override content wins. Both twins must make the same decision.
    $sb8 = New-Sandbox
    Write-Bytes (Join-Path $sb8 'src/stacks/dotnet/files/collide.md') (Get-LfBytes @('DOTNET COLLIDE'))
    Write-Bytes (Join-Path $sb8 'src/stacks/angular/files/collide.md') (Get-LfBytes @('ANGULAR COLLIDE'))
    $hasBash8 = [bool](Get-BashPath)

    It 'F8 RED [ps1]: monorepo files/ collision without override exits 1 naming the relpath' {
        $r = Invoke-Composer -Sandbox $sb8 -Mode 'monorepo' -Twin 'ps1'
        Assert ($r.Exit -eq 1) "expected exit 1, got $($r.Exit)"
        Assert ($r.Err -match 'ERROR:') "stderr missing ERROR: -- got: $($r.Err)"
        Assert ($r.Err -match [regex]::Escape('collide.md')) "stderr does not name the colliding relpath -- got: $($r.Err)"
    }
    if ($hasBash8) {
        It 'F8 RED [sh]: monorepo files/ collision without override exits 1 naming the relpath' {
            $r = Invoke-Composer -Sandbox $sb8 -Mode 'monorepo' -Twin 'sh'
            Assert ($r.Exit -eq 1) "expected exit 1, got $($r.Exit)"
            Assert ($r.Err -match 'ERROR:') "stderr missing ERROR: -- got: $($r.Err)"
            Assert ($r.Err -match [regex]::Escape('collide.md')) "stderr does not name the colliding relpath -- got: $($r.Err)"
        }
        It 'F8 twin agreement: both composers make the same RED decision' {
            $r1 = Invoke-Composer -Sandbox $sb8 -Mode 'monorepo' -Twin 'ps1'
            $r2 = Invoke-Composer -Sandbox $sb8 -Mode 'monorepo' -Twin 'sh'
            Assert ($r1.Exit -eq $r2.Exit) "twins disagree on collision exit code: ps1=$($r1.Exit) sh=$($r2.Exit)"
        }
    } else {
        Skip 'F8 RED [sh]' 'bash not found on this host'
        Skip 'F8 twin agreement' 'bash not found on this host'
    }

    It 'F8 GREEN [ps1]: monorepo files/ override resolves the collision' {
        Write-Bytes (Join-Path $sb8 'src/stacks/monorepo/files/collide.md') (Get-LfBytes @('MONO RESOLVED'))
        $r = Invoke-Composer -Sandbox $sb8 -Mode 'monorepo' -Twin 'ps1'
        Assert ($r.Exit -eq 0) "expected exit 0 after override, got $($r.Exit): $($r.Err)"
        Assert-FileBytes (Join-Path $sb8 'dist/monorepo/collide.md') (Get-LfBytes @('MONO RESOLVED')) 'F8 dist bytes'
    }
    if ($hasBash8) {
        It 'F8 GREEN [sh]: monorepo files/ override resolves the collision' {
            $r = Invoke-Composer -Sandbox $sb8 -Mode 'monorepo' -Twin 'sh'
            Assert ($r.Exit -eq 0) "expected exit 0 after override, got $($r.Exit): $($r.Err)"
            Assert-FileBytes (Join-Path $sb8 'dist/monorepo/collide.md') (Get-LfBytes @('MONO RESOLVED')) 'F8 dist bytes'
        }
    } else {
        Skip 'F8 GREEN [sh]' 'bash not found on this host'
    }

    # F9 (RED): a core file whose text contains "@stack:oops" NOT as an exact marker line ->
    # unresolved-marker validation fails, exit 1, in every mode.
    $sb9 = New-Sandbox
    Write-Bytes (Join-Path $sb9 'src/core/notes.md') (Get-LfBytes @('see <!-- @stack:oops --> here'))
    foreach ($mode in @('dotnet', 'angular', 'monorepo')) {
        Invoke-BothTwins -NamePrefix "F9 RED unresolved inline @stack marker ($mode mode)" -Sandbox $sb9 -Mode $mode -Assertion {
            param($ctx)
            Assert ($ctx.Result.Exit -eq 1) "expected exit 1, got $($ctx.Result.Exit)"
            Assert ($ctx.Result.Err -match 'ERROR:') "stderr missing ERROR: -- got: $($ctx.Result.Err)"
            Assert ($ctx.Result.Err -match 'unresolved') "stderr missing 'unresolved' -- got: $($ctx.Result.Err)"
        }
    }

    # F10: byte fidelity -- (a) BOM+CRLF plain copy: BOM kept, CRLF->LF; (b) BOM survives marker
    # substitution; (c) a marker-less core file missing its trailing newline stays that way.
    $sb10 = New-Sandbox
    $srcF10a = [byte[]]($BomBytes + $Utf8NoBom.GetBytes(([string]::Join("`r`n", @('$x = 1', '$y = 2'))) + "`r`n"))
    Write-Bytes (Join-Path $sb10 'src/core/a.ps1') $srcF10a
    $expectF10a = [byte[]]($BomBytes + $Utf8NoBom.GetBytes(([string]::Join("`n", @('$x = 1', '$y = 2'))) + "`n"))

    $srcF10b = [byte[]]($BomBytes + $Utf8NoBom.GetBytes(([string]::Join("`n", @('preamble', '# @stack:tag', 'after'))) + "`n"))
    Write-Bytes (Join-Path $sb10 'src/core/b.ps1') $srcF10b
    Write-Bytes (Join-Path $sb10 'src/stacks/dotnet/snippets/b.ps1/tag') (Get-LfBytes @('Snippet Line 1'))
    $expectF10b = [byte[]]($BomBytes + $Utf8NoBom.GetBytes(([string]::Join("`n", @('preamble', 'Snippet Line 1', 'after'))) + "`n"))

    $srcF10c = $Utf8NoBom.GetBytes('only line, no marker, no trailing newline')
    Write-Bytes (Join-Path $sb10 'src/core/c.txt') $srcF10c
    $expectF10c = $srcF10c

    Invoke-BothTwins -NamePrefix 'F10 byte fidelity (BOM+CRLF copy / BOM+marker substitution / missing trailing NL preserved)' -Sandbox $sb10 -Mode 'dotnet' -Assertion {
        param($ctx)
        Assert ($ctx.Result.Exit -eq 0) "compose failed: $($ctx.Result.Err)"
        Assert-FileBytes (Join-Path $ctx.Sandbox 'dist/dotnet/a.ps1') $expectF10a 'F10a BOM+CRLF plain copy -> BOM kept, CRLF->LF'
        Assert-FileBytes (Join-Path $ctx.Sandbox 'dist/dotnet/b.ps1') $expectF10b 'F10b BOM survives marker substitution'
        Assert-FileBytes (Join-Path $ctx.Sandbox 'dist/dotnet/c.txt') $expectF10c 'F10c missing trailing newline preserved on plain copy'
    }

    # F11 (RED): invalid mode -> usage error, exit 2, both twins.
    $sb11 = New-Sandbox
    Invoke-BothTwins -NamePrefix 'F11 RED invalid mode "sushi" exits 2' -Sandbox $sb11 -Mode 'sushi' -Assertion {
        param($ctx)
        Assert ($ctx.Result.Exit -eq 2) "expected exit 2, got $($ctx.Result.Exit)"
        Assert ($ctx.Result.Err -match '(?i)usage') "stderr missing a usage message -- got: $($ctx.Result.Err)"
    }

    # F12: twin agreement -- one representative green fixture (markers + overlays in all three
    # modes) composed by BOTH twins into SEPARATE sandboxes; assert byte-identical trees per mode.
    $sbF12ps = New-Sandbox
    Populate-GreenFixture $sbF12ps
    $sbF12sh = New-Sandbox
    Populate-GreenFixture $sbF12sh
    if (Get-BashPath) {
        foreach ($mode in @('dotnet', 'angular', 'monorepo')) {
            It "F12 twin agreement: .ps1 tree == .sh tree for $mode" {
                $r1 = Invoke-Composer -Sandbox $sbF12ps -Mode $mode -Twin 'ps1'
                Assert ($r1.Exit -eq 0) "ps1 compose failed for $mode : $($r1.Err)"
                $r2 = Invoke-Composer -Sandbox $sbF12sh -Mode $mode -Twin 'sh'
                Assert ($r2.Exit -eq 0) "sh compose failed for $mode : $($r2.Err)"
                Assert-SameTree (Join-Path $sbF12ps "dist/$mode") (Join-Path $sbF12sh "dist/$mode") "F12 $mode"
            }
        }
    } else {
        foreach ($mode in @('dotnet', 'angular', 'monorepo')) {
            Skip "F12 twin agreement ($mode)" 'bash not found on this host'
        }
    }
} finally {
    foreach ($s in $script:AllSandboxes) {
        Remove-Item -LiteralPath $s -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit (Write-TestSummary 'ComposerFixtures.Tests (composer regression)')
