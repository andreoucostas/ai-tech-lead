# Red/green tests for the WSD-015 sibling-drift gate (scripts/check-sibling-drift.sh / .ps1,
# meta-invariant #1). Builds scratch git repos under a temp dir, copies BOTH twin scripts in
# (unmodified -- the bytes under test), creates a src/stacks tree + commits per scenario, and runs
# each twin as a child process, asserting they agree on exit code and (for FAIL/NOTICE lines)
# output. Does NOT ship; not wired into any dist. Auto-picked-up by Invoke-HookTests.ps1.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path   # the ai-tech-lead repo root
$script:ShScript  = Join-Path $repoRoot 'scripts\check-sibling-drift.sh'
$script:Ps1Script = Join-Path $repoRoot 'scripts\check-sibling-drift.ps1'

function New-ScratchRepo {
    param([string]$Name)
    $dir = Join-Path $script:TmpRoot $Name
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    & git -C $dir init -q | Out-Null
    & git -C $dir config user.name 'Sibling Drift Test' | Out-Null
    & git -C $dir config user.email 'sibling-drift-test@example.com' | Out-Null
    & git -C $dir config core.autocrlf false | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $dir 'scripts') -Force | Out-Null
    $subdirs = @(
        'src/stacks/dotnet/snippets', 'src/stacks/dotnet/files',
        'src/stacks/angular/snippets', 'src/stacks/angular/files',
        'src/stacks/monorepo/snippets', 'src/stacks/monorepo/files'
    )
    foreach ($sub in $subdirs) {
        New-Item -ItemType Directory -Path (Join-Path $dir $sub) -Force | Out-Null
    }
    Copy-Item -LiteralPath $script:ShScript  -Destination (Join-Path $dir 'scripts/check-sibling-drift.sh')
    Copy-Item -LiteralPath $script:Ps1Script -Destination (Join-Path $dir 'scripts/check-sibling-drift.ps1')
    return $dir
}

function Write-RepoFile {
    param([string]$Repo, [string]$RelPath, [string]$Content)
    $full = Join-Path $Repo $RelPath
    $parent = Split-Path -Parent $full
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    [IO.File]::WriteAllText($full, $Content, (New-Object System.Text.UTF8Encoding($false)))
}

function Commit-RepoAll {
    param([string]$Repo, [string]$Message)
    & git -C $Repo add -A | Out-Null
    & git -C $Repo commit -q -m $Message | Out-Null
}

# Runs one twin as a child process inside $RepoDir. $Kind is 'ps1' or 'sh'. When -ArgSet is not
# passed, the script is invoked with NO positional arg (default base-ref = HEAD~1) -- distinct
# from passing an explicit empty string, which both twins must treat as an unresolvable base
# (deliberate: bash's `${1-default}` vs `${1:-default}`, see check-sibling-drift.sh's BASE line).
function Invoke-Twin {
    param(
        [Parameter(Mandatory)][string]$RepoDir,
        [Parameter(Mandatory)][ValidateSet('ps1', 'sh')][string]$Kind,
        [string]$BaseArg,
        [switch]$ArgSet
    )
    Push-Location $RepoDir
    try {
        if ($Kind -eq 'ps1') {
            if ($ArgSet) {
                $out = & (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File 'scripts/check-sibling-drift.ps1' $BaseArg 2>&1
            } else {
                $out = & (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File 'scripts/check-sibling-drift.ps1' 2>&1
            }
        } else {
            $bash = Get-BashPath
            if (-not $bash) { return $null }
            if ($ArgSet) {
                $out = & $bash 'scripts/check-sibling-drift.sh' $BaseArg 2>&1
            } else {
                $out = & $bash 'scripts/check-sibling-drift.sh' 2>&1
            }
        }
        $code = $LASTEXITCODE
        return [pscustomobject]@{ Exit = $code; Out = ($out -join "`n") }
    } finally { Pop-Location }
}

Reset-Tests
$script:TmpRoot = Join-Path ([IO.Path]::GetTempPath()) ("siblingdrift-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $script:TmpRoot -Force | Out-Null

try {
    # --- (a) RED: dotnet snippet edited, monorepo sibling exists and untouched -> exit 1 -----
    $repoA = New-ScratchRepo 'case-a'
    Write-RepoFile $repoA 'src/stacks/dotnet/snippets/x/NAME'    "v1`n"
    Write-RepoFile $repoA 'src/stacks/monorepo/snippets/x/NAME' "v1`n"
    Commit-RepoAll $repoA 'init'
    Write-RepoFile $repoA 'src/stacks/dotnet/snippets/x/NAME'    "v2`n"
    Commit-RepoAll $repoA 'edit dotnet snippet only'

    It '(a) ps1: violation -> exit 1, FAIL names both paths' {
        $r = Invoke-Twin -RepoDir $repoA -Kind ps1
        Assert ($r.Exit -eq 1) "expected exit 1, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match [regex]::Escape('src/stacks/dotnet/snippets/x/NAME')) 'FAIL line missing stack path'
        Assert ($r.Out -match [regex]::Escape('src/stacks/monorepo/snippets/x/NAME')) 'FAIL line missing sibling path'
    }
    if (Get-BashPath) {
        It '(a) sh twin: violation -> exit 1, FAIL names both paths' {
            $r = Invoke-Twin -RepoDir $repoA -Kind sh
            Assert ($r.Exit -eq 1) "expected exit 1, got $($r.Exit): $($r.Out)"
            Assert ($r.Out -match [regex]::Escape('src/stacks/dotnet/snippets/x/NAME')) 'FAIL line missing stack path'
            Assert ($r.Out -match [regex]::Escape('src/stacks/monorepo/snippets/x/NAME')) 'FAIL line missing sibling path'
        }
        It '(a) twins agree byte-for-byte (modulo line endings)' {
            $ps = Invoke-Twin -RepoDir $repoA -Kind ps1
            $sh = Invoke-Twin -RepoDir $repoA -Kind sh
            Assert ($ps.Exit -eq $sh.Exit) "exit mismatch: ps1=$($ps.Exit) sh=$($sh.Exit)"
            Assert (($ps.Out -replace "`r`n", "`n") -eq ($sh.Out -replace "`r`n", "`n")) "output mismatch:`nps1: $($ps.Out)`nsh:  $($sh.Out)"
        }
    } else {
        Skip '(a) sh twin' 'bash not found on this host'
    }

    # --- (g) RED: files/ kind -- angular file edited, monorepo files/ sibling untouched -> exit 1
    $repoG = New-ScratchRepo 'case-g'
    Write-RepoFile $repoG 'src/stacks/angular/files/y.md'   "v1`n"
    Write-RepoFile $repoG 'src/stacks/monorepo/files/y.md'  "v1`n"
    Commit-RepoAll $repoG 'init'
    Write-RepoFile $repoG 'src/stacks/angular/files/y.md'   "v2`n"
    Commit-RepoAll $repoG 'edit angular file only'

    It '(g) ps1: files/ kind violation -> exit 1' {
        $r = Invoke-Twin -RepoDir $repoG -Kind ps1
        Assert ($r.Exit -eq 1) "expected exit 1, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match [regex]::Escape('src/stacks/angular/files/y.md')) 'FAIL line missing stack path'
        Assert ($r.Out -match [regex]::Escape('src/stacks/monorepo/files/y.md')) 'FAIL line missing sibling path'
    }
    if (Get-BashPath) {
        It '(g) sh twin: files/ kind violation -> exit 1' {
            $r = Invoke-Twin -RepoDir $repoG -Kind sh
            Assert ($r.Exit -eq 1) "expected exit 1, got $($r.Exit): $($r.Out)"
            Assert ($r.Out -match [regex]::Escape('src/stacks/angular/files/y.md')) 'FAIL line missing stack path'
            Assert ($r.Out -match [regex]::Escape('src/stacks/monorepo/files/y.md')) 'FAIL line missing sibling path'
        }
        It '(g) twins agree byte-for-byte (modulo line endings)' {
            $ps = Invoke-Twin -RepoDir $repoG -Kind ps1
            $sh = Invoke-Twin -RepoDir $repoG -Kind sh
            Assert ($ps.Exit -eq $sh.Exit) "exit mismatch: ps1=$($ps.Exit) sh=$($sh.Exit)"
            Assert (($ps.Out -replace "`r`n", "`n") -eq ($sh.Out -replace "`r`n", "`n")) "output mismatch:`nps1: $($ps.Out)`nsh:  $($sh.Out)"
        }
    } else {
        Skip '(g) sh twin' 'bash not found on this host'
    }

    # --- (b) GREEN: same edit, but the commit also touches the monorepo sibling -> exit 0 -----
    $repoB = New-ScratchRepo 'case-b'
    Write-RepoFile $repoB 'src/stacks/dotnet/snippets/x/NAME'    "v1`n"
    Write-RepoFile $repoB 'src/stacks/monorepo/snippets/x/NAME' "v1`n"
    Commit-RepoAll $repoB 'init'
    Write-RepoFile $repoB 'src/stacks/dotnet/snippets/x/NAME'    "v2`n"
    Write-RepoFile $repoB 'src/stacks/monorepo/snippets/x/NAME' "v2`n"
    Commit-RepoAll $repoB 'edit both'

    It '(b) ps1: sibling touched in same commit -> exit 0' {
        $r = Invoke-Twin -RepoDir $repoB -Kind ps1
        Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match '^OK:') "expected an OK line, got: $($r.Out)"
    }
    if (Get-BashPath) {
        It '(b) sh twin: sibling touched in same commit -> exit 0' {
            $r = Invoke-Twin -RepoDir $repoB -Kind sh
            Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit): $($r.Out)"
            Assert ($r.Out -match '^OK:') "expected an OK line, got: $($r.Out)"
        }
    } else {
        Skip '(b) sh twin' 'bash not found on this host'
    }

    # --- (c) GREEN: stack snippet edited, no monorepo sibling exists on disk -> exit 0 --------
    $repoC = New-ScratchRepo 'case-c'
    Write-RepoFile $repoC 'src/stacks/dotnet/snippets/x/NAME' "v1`n"
    Commit-RepoAll $repoC 'init'
    Write-RepoFile $repoC 'src/stacks/dotnet/snippets/x/NAME' "v2`n"
    Commit-RepoAll $repoC 'no sibling on disk'

    It '(c) ps1: no sibling on disk -> exit 0' {
        $r = Invoke-Twin -RepoDir $repoC -Kind ps1
        Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit): $($r.Out)"
    }
    if (Get-BashPath) {
        It '(c) sh twin: no sibling on disk -> exit 0' {
            $r = Invoke-Twin -RepoDir $repoC -Kind sh
            Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit): $($r.Out)"
        }
    } else {
        Skip '(c) sh twin' 'bash not found on this host'
    }

    # --- (d) GREEN: violation suppressed by a 'Sibling-Reviewed:' trailer ----------------------
    # (d1) exact sibling path
    $repoD1 = New-ScratchRepo 'case-d1'
    Write-RepoFile $repoD1 'src/stacks/dotnet/snippets/x/NAME'    "v1`n"
    Write-RepoFile $repoD1 'src/stacks/monorepo/snippets/x/NAME' "v1`n"
    Commit-RepoAll $repoD1 'init'
    Write-RepoFile $repoD1 'src/stacks/dotnet/snippets/x/NAME' "v2`n"
    Commit-RepoAll $repoD1 "edit dotnet only`n`nSibling-Reviewed: src/stacks/monorepo/snippets/x/NAME"

    It '(d1) ps1: exact-path trailer suppresses the violation -> exit 0' {
        $r = Invoke-Twin -RepoDir $repoD1 -Kind ps1
        Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit): $($r.Out)"
    }
    if (Get-BashPath) {
        It '(d1) sh twin: exact-path trailer suppresses the violation -> exit 0' {
            $r = Invoke-Twin -RepoDir $repoD1 -Kind sh
            Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit): $($r.Out)"
        }
    } else {
        Skip '(d1) sh twin' 'bash not found on this host'
    }

    # (d2) wildcard trailer
    $repoD2 = New-ScratchRepo 'case-d2'
    Write-RepoFile $repoD2 'src/stacks/dotnet/snippets/x/NAME'    "v1`n"
    Write-RepoFile $repoD2 'src/stacks/monorepo/snippets/x/NAME' "v1`n"
    Commit-RepoAll $repoD2 'init'
    Write-RepoFile $repoD2 'src/stacks/dotnet/snippets/x/NAME' "v2`n"
    Commit-RepoAll $repoD2 "edit dotnet only`n`nSibling-Reviewed: *"

    It "(d2) ps1: '*' trailer suppresses the violation -> exit 0" {
        $r = Invoke-Twin -RepoDir $repoD2 -Kind ps1
        Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit): $($r.Out)"
    }
    if (Get-BashPath) {
        It "(d2) sh twin: '*' trailer suppresses the violation -> exit 0" {
            $r = Invoke-Twin -RepoDir $repoD2 -Kind sh
            Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit): $($r.Out)"
        }
    } else {
        Skip '(d2) sh twin' 'bash not found on this host'
    }

    # --- (e) GREEN: commit touches ONLY the monorepo side -> exit 0 ----------------------------
    $repoE = New-ScratchRepo 'case-e'
    Write-RepoFile $repoE 'src/stacks/monorepo/snippets/x/NAME' "v1`n"
    Commit-RepoAll $repoE 'init'
    Write-RepoFile $repoE 'src/stacks/monorepo/snippets/x/NAME' "v2`n"
    Commit-RepoAll $repoE 'monorepo only'

    It '(e) ps1: monorepo-only edit -> exit 0, no dotnet/angular paths touched' {
        $r = Invoke-Twin -RepoDir $repoE -Kind ps1
        Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match 'no src/stacks/\{dotnet,angular\} paths touched') "unexpected message: $($r.Out)"
    }
    if (Get-BashPath) {
        It '(e) sh twin: monorepo-only edit -> exit 0, no dotnet/angular paths touched' {
            $r = Invoke-Twin -RepoDir $repoE -Kind sh
            Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit): $($r.Out)"
            Assert ($r.Out -match 'no src/stacks/\{dotnet,angular\} paths touched') "unexpected message: $($r.Out)"
        }
    } else {
        Skip '(e) sh twin' 'bash not found on this host'
    }

    # --- (f) GREEN: unresolvable base (all-zeros SHA) -> NOTICE, exit 0 ------------------------
    $repoF = New-ScratchRepo 'case-f'
    Write-RepoFile $repoF 'src/stacks/dotnet/snippets/x/NAME' "v1`n"
    Commit-RepoAll $repoF 'init'
    $zeroSha = '0000000000000000000000000000000000000000'

    It '(f) ps1: unresolvable (all-zeros) base -> NOTICE, exit 0' {
        $r = Invoke-Twin -RepoDir $repoF -Kind ps1 -BaseArg $zeroSha -ArgSet
        Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit): $($r.Out)"
        Assert ($r.Out -match '^NOTICE:') "expected a NOTICE line, got: $($r.Out)"
    }
    if (Get-BashPath) {
        It '(f) sh twin: unresolvable (all-zeros) base -> NOTICE, exit 0' {
            $r = Invoke-Twin -RepoDir $repoF -Kind sh -BaseArg $zeroSha -ArgSet
            Assert ($r.Exit -eq 0) "expected exit 0, got $($r.Exit): $($r.Out)"
            Assert ($r.Out -match '^NOTICE:') "expected a NOTICE line, got: $($r.Out)"
        }
    } else {
        Skip '(f) sh twin' 'bash not found on this host'
    }
} finally {
    Remove-Item -LiteralPath $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}

exit (Write-TestSummary 'SiblingDrift.Tests (WSD-015 gate)')
