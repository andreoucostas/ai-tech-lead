# Behavioural parity for shipped utility-script twins.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
$scripts = (Resolve-Path (Join-Path $PSScriptRoot '..\..\scripts')).Path
$bash = Get-BashPath

function Put($Path,$Text) { $parent=Split-Path $Path -Parent; if($parent){New-Item -ItemType Directory -Force $parent|Out-Null}; [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false))) }
# A fixture .ps1 under a scanned directory must carry a BOM or the BOM check reports it -- which
# would still be equal across twins, but would stop the "clean" fixture from being clean.
function PutBom($Path,$Text) { $parent=Split-Path $Path -Parent; if($parent){New-Item -ItemType Directory -Force $parent|Out-Null}; [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($true))) }
function Temp($Name) { $p=Join-Path ([IO.Path]::GetTempPath()) ($Name+'-'+[guid]::NewGuid());New-Item -ItemType Directory $p|Out-Null;$p }
function NormPath($p) { ([IO.Path]::GetFullPath($p).TrimEnd('\','/') -replace '\\','/').ToLowerInvariant() }
function InitSafe($p) { git -C $p init --quiet; Assert ($LASTEXITCODE-eq 0) "git init failed: $p"; Push-Location $p;try{$got=git rev-parse --show-toplevel;Assert ((NormPath $got)-eq(NormPath $p)) "unsafe git root '$got', expected '$p'"}finally{Pop-Location} }
function RunHere($path,$cwd,[string[]]$args=@()) { Push-Location $cwd;try{RunArg $path $args}finally{Pop-Location} }
function Records($text) { $a=@();foreach($line in ($text -split "`r?`n")){if($line-match'^(OK|FAIL):\s+(.*)$'){$m=$Matches[2];if($m-eq'all framework .ps1 files parse cleanly.'-or$m-eq'all framework .sh files parse cleanly.'){$m='<framework scripts parse cleanly>'};$a+=($Matches[1]+'|'+$m)}};,$a }
function AssertSeq($a,$b,$label) { Assert (($a|ConvertTo-Json -Compress)-eq($b|ConvertTo-Json -Compress)) "$label ordered output differs`nPS: $($a-join"`n")`nSH: $($b-join"`n")" }
# An exit-code mismatch used to report only the two numbers, so a red CI leg on a host you cannot
# reproduce locally told you nothing about WHICH check disagreed -- B-130 names this exact gap as
# the thing blocking its own diagnosis. Always dump both twins' output with the codes.
function AssertExit($p,$s,$label) { Assert ($p.Exit-eq$s.Exit) "$label exit mismatch $($p.Exit)/$($s.Exit)`nPS OUT:`n$($p.Out)`nPS ERR:`n$($p.Err)`nSH OUT:`n$($s.Out)`nSH ERR:`n$($s.Err)" }
function CopyPair($name,$root) { New-Item -ItemType Directory -Force (Join-Path $root scripts)|Out-Null;Copy-Item (Join-Path $scripts "$name.ps1") (Join-Path $root scripts);Copy-Item (Join-Path $scripts "$name.sh") (Join-Path $root scripts) }
# EOL here is LOAD-BEARING and must stay LF. This fixture is shared by four tests that predate
# Common Tasks; switching it to CRLF to give check 8 an EOL control broke all four on the CI linux
# leg while every Windows leg stayed green (v0.53.0 release run).
# The mechanism is worth knowing, because it makes this class invisible here: MSYS opens files in
# TEXT mode, so on Git Bash `sed`/`grep`/`awk` never see a CR at all -- the platform strips it before
# the tool runs. On linux they see it. Checks 1-7 were written against an LF fixture and had
# therefore never once been handed a CR on any host; the CRLF fixture fed them one, on the only leg
# that can perceive it. A shared fixture is not the place to buy coverage for one check -- the CRLF
# control lives in its own case below, where it can only destabilise the check it exercises.
# The .template-repo marker is what template-checks uses to decide it may parse CHANGELOG.md at all
# (B-131: an unmarked consumer owns its changelog convention). A fixture named TemplateFixture that
# omitted the marker was silently exercising the CONSUMER branch, so its changelog assertions
# agreed vacuously.
function TemplateFixture { $r=Temp template;CopyPair template-checks $r;Put (Join-Path $r '.template-repo') "fixture`n";Put (Join-Path $r CHANGELOG.md) "# Changelog`n`n## 1.2.3 — 2026-08-08`n`n- Fixture.`n";Put (Join-Path $r CLAUDE.md) "version: 1.2.3`n## Verification Rules`nSame`n## Leanness`nSame`n## SOLID`nSame`n## Boy Scout Rule`nSame`n### Apply only when the file is the primary target of the change:`nSame primary-target rules`n## Agentic Workflow`n### 1. Classify the intent`nSame`n### 2. Continue`n## Common Tasks`n- ``alpha`` — first → second`n- ``beta`` - plain separator`n";Put (Join-Path $r AGENTS.md) "## Verification Rules`nSame`n## Leanness`nSame`n## SOLID`nSame`n## Boy Scout Rule`nSame`n### Apply only when the file is the primary target of the change:`nSame primary-target rules`n## Agentic Workflow`n### 1. Classify the intent`nSame`n### 2. Continue`n## Common Tasks`n- ``alpha`` — first → second`n- ``beta`` - plain separator`n";Put (Join-Path $r '.claude/framework-version.json') '{"version":"1.2.3"}';Put (Join-Path $r '.github/copilot-instructions.md') "fixture`n";PutBom (Join-Path $r '.claude/hooks/probe.ps1') "# probe`n";Put (Join-Path $r '.claude/hooks/probe.sh') "# probe`n";Put (Join-Path $r '.claude/skills/demo/SKILL.md') "# demo`n";Put (Join-Path $r '.github/skills/demo/SKILL.md') "# demo`n";$r }
function CarrierTemplateFixture { $r=TemplateFixture;Put (Join-Path $r CLAUDE.md) "version: 1.2.3`n@.github/instructions/framework-rules.instructions.md`n## Boy Scout Rule`nSame`n### Apply only when the file is the primary target of the change:`nSame primary-target rules`n## Common Tasks`n- ``alpha`` — first → second`n- ``beta`` - plain separator`n";Put (Join-Path $r '.github/instructions/framework-rules.instructions.md') "## Verification Rules`nSame`n## Leanness`nSame`n## SOLID`nSame`n## Agentic Workflow`n### 1. Classify the intent`nSame`n### 2. Carrier-only continuation`n";$r }
# The checks this fixture must REACH. Several checks are wrapped in "if the directory exists", so a
# fixture that omits the directory skips the check silently and the twins agree vacuously. Asserting
# the reached set turns "this check never ran" into a failure instead of a green line.
$ExpectedChecks = @('version stamps in sync','mirrored verbatim','Agentic Workflow','copilot-instructions.md present','carry a UTF-8 BOM','<framework scripts parse cleanly>','every hook has its','skills and .github/skills are in sync','Common Tasks skill inventory matches')
function NormDocs($text) { $known='sync-agent-files|template-checks|wiki-check|warehouse-map-check|build-architecture-html';$x=$text-replace("("+$known+")\.(ps1|sh)"),'$1.<script>';($x-replace'all framework \.(ps1|sh) files parse cleanly\.','all framework scripts parse cleanly.') }
function LiteralCount($text,$needle) { @([regex]::Matches([string]$text,[regex]::Escape($needle))).Count }
function TerminalLineCount($text,$sentinel) { @(([string]$text -split '\r\n|\n|\r') | Where-Object { $_.Trim().EndsWith($sentinel,[StringComparison]::Ordinal) }).Count }
function SetWarehouseStub($root,[int]$psStatus,[int]$shStatus,[string]$stream,[string]$sentinel) {
    $psWrite=if($stream-eq'stderr'){"[Console]::Error.WriteLine('$sentinel')"}else{"Write-Output '$sentinel'"}
    $shRedirect=if($stream-eq'stderr'){' >&2'}else{''}
    PutBom (Join-Path $root 'scripts/warehouse-map-check.ps1') "$psWrite`nexit $psStatus`n"
    Put (Join-Path $root 'scripts/warehouse-map-check.sh') "#!/usr/bin/env bash`nprintf '%s\n' '$sentinel'$shRedirect`nexit $shStatus`n"
}
function DocsFixture { $r=Temp docs;CopyPair docs-sync-check $r;Put (Join-Path $r 'docs/enforcement-surfaces.md') "fixture`n";Put (Join-Path $r CLAUDE.md) "# ready`n";Put (Join-Path $r AGENTS.md) "GENERATED FILE`n## Verification Rules`n## Leanness`n## Boy Scout Rule`n## Agentic Workflow`n";Put (Join-Path $r '.github/copilot-instructions.md') "fixture`n";Put (Join-Path $r TECH_DEBT.md) "# debt`n";Put (Join-Path $r FRAMEWORK-CONTEXT.md) "# context`n";Put (Join-Path $r README.md) "# fixture`n";Put (Join-Path $r '.claude/skills/my-skill/SKILL.md') "# skill`n";Put (Join-Path $r '.claude/agents/my-agent.md') "# agent`n";$r }

Reset-Tests
if(-not $bash){foreach($n in 'template-checks clean and drift','docs-sync-check branches and advisories','sync-agent-files recursive mirror','metrics counters'){Skip $n 'bash unavailable; twin comparison requires bash'};exit (Write-TestSummary 'ScriptTwinParity.Tests')}

It 'template-checks clean and planted drift agree in order' {
    $r=TemplateFixture
    try {
        $ps=Join-Path $r scripts/template-checks.ps1
        $sh=Join-Path $r scripts/template-checks.sh
        $pt=[IO.File]::ReadAllText($ps)
        $st=[IO.File]::ReadAllText($sh)
        Assert (([regex]::Matches($pt,'files parse cleanly\.')).Count-eq 1) 'PowerShell parse-success emission count changed'
        Assert (([regex]::Matches($st,'files parse cleanly\.')).Count-eq 1) 'bash parse-success emission count changed'

        $driftResult=$null
        foreach($drift in $false,$true){
            if($drift){
                Put (Join-Path $r '.claude/framework-version.json') '{"version":"9.9.9"}'
                Remove-Item -LiteralPath (Join-Path $r '.github/copilot-instructions.md') -Force
            }
            $p=RunArg $ps;$s=RunArg $sh
            AssertExit $p $s 'template-checks'
            $recs=Records $p.Out
            AssertSeq $recs (Records $s.Out) 'template-checks'
            if(-not $drift){
                foreach($want in $ExpectedChecks){
                    $hits=@($recs|Where-Object{$_-like "*$want*"}).Count
                    Assert ($hits-ge 1) "check '$want' was never reached -- the fixture stopped exercising it, so the twins would agree vacuously here. Restore the fixture input that triggers it."
                }
            }else{
                Assert ($p.Out.Contains('version-stamp drift: CLAUDE.md says 1.2.3, framework-version.json says 9.9.9.')) 'PowerShell drift failure missing'
                Assert ($s.Out.Contains('version-stamp drift: CLAUDE.md says 1.2.3, framework-version.json says 9.9.9.')) 'bash drift failure missing'
                $driftResult=[pscustomobject]@{PowerShell=$p;Bash=$s}
            }
        }

        # Reach each twin's real CHANGELOG read-failure branch by changing only its input operand.
        # Synthesising exit 2 would prove the assertion, not the checker behavior.
        $absent='CHANGELOG.__b175_absent__'
        Assert (-not(Test-Path -LiteralPath (Join-Path $r $absent))) 'resource fixture path unexpectedly exists'
        $psSource=[IO.File]::ReadAllText($ps)
        $psAnchor="Resolve-Path -LiteralPath 'CHANGELOG.md'"
        Assert ((LiteralCount $psSource $psAnchor)-eq 1) 'PowerShell CHANGELOG input anchor changed'
        PutBom $ps ($psSource.Replace($psAnchor,"Resolve-Path -LiteralPath '$absent'"))
        $shSource=[IO.File]::ReadAllText($sh)
        $shLines=@($shSource -split "`r?`n"|Where-Object{$_.StartsWith('  changelog_heads=$(grep -E ')})
        Assert ($shLines.Count-eq 1) 'bash CHANGELOG input anchor changed'
        Assert ((LiteralCount $shLines[0] 'CHANGELOG.md')-eq 1) 'bash CHANGELOG operand count changed'
        Put $sh ($shSource.Replace($shLines[0],$shLines[0].Replace('CHANGELOG.md',$absent)))
        $resourceP=RunArg $ps;$resourceS=RunArg $sh
        AssertExit $resourceP $resourceS 'template-checks resource failure'

        $summary='2 framework check(s) FAILED.'
        Assert ($driftResult.PowerShell.Exit-eq 3) "PowerShell two-finding drift exit=$($driftResult.PowerShell.Exit), expected fixed status 3"
        Assert ($driftResult.Bash.Exit-eq 3) "bash two-finding drift exit=$($driftResult.Bash.Exit), expected fixed status 3"
        Assert ($driftResult.PowerShell.Out.Contains($summary)) 'PowerShell printed finding count changed'
        Assert ($driftResult.Bash.Out.Contains($summary)) 'bash printed finding count changed'
        $resourceDiagnostic='CANT-VERIFY: template-checks could not inspect CHANGELOG.md; changelog headings remain UNKNOWN. Fix the host/resource read problem and rerun.'
        Assert ($resourceP.Exit-eq 2-and$resourceP.Out.Trim()-ceq$resourceDiagnostic) "PowerShell resource contract changed: exit=$($resourceP.Exit) out='$($resourceP.Out)'"
        Assert ($resourceS.Exit-eq 2-and$resourceS.Out.Trim()-ceq$resourceDiagnostic) "bash resource contract changed: exit=$($resourceS.Exit) out='$($resourceS.Out)'"
    }finally{Remove-Item -Recurse -Force $r}
}

It 'template-checks Common Tasks twins agree on planted inventory failures and edge fixtures' {
    foreach ($case in 'one-sided','duplicate','zero-extraction','absent-one','case-variant','single-slug','absent-both') {
        $r=TemplateFixture
        try {
            $claude=Join-Path $r CLAUDE.md; $agents=Join-Path $r AGENTS.md
            if($case-eq'one-sided'){Put $claude (([IO.File]::ReadAllText($claude))-replace'- `alpha` —',"- ``zz-planted`` — planted`r`n- ``alpha`` —")}
            elseif($case-eq'duplicate'){Put $claude (([IO.File]::ReadAllText($claude))-replace'- `alpha` —',"- ``alpha`` — duplicate`r`n- ``alpha`` —")}
            elseif($case-eq'zero-extraction'){foreach($p in $claude,$agents){Put $p (([IO.File]::ReadAllText($p))-replace'(?m)^- `','* `')}}
            elseif($case-eq'absent-one'){Put $agents (([IO.File]::ReadAllText($agents))-replace'(?ms)^## Common Tasks\r?\n.*$','')}
            elseif($case-eq'case-variant'){Put $agents (([IO.File]::ReadAllText($agents))-replace'- `alpha` —','- `Alpha` —')}
            elseif($case-eq'single-slug'){foreach($p in $claude,$agents){Put $p (([IO.File]::ReadAllText($p))-replace'(?m)^- `beta` - plain separator\r?\n','')}}
            elseif($case-eq'absent-both'){foreach($p in $claude,$agents){Put $p (([IO.File]::ReadAllText($p))-replace'(?ms)^## Common Tasks\r?\n.*$','')}}
            $p=RunArg (Join-Path $r scripts/template-checks.ps1);$s=RunArg (Join-Path $r scripts/template-checks.sh)
            AssertExit $p $s $case
            AssertSeq (Records $p.Out) (Records $s.Out) "$case Common Tasks"
            if($case-in @('one-sided','duplicate','zero-extraction','absent-one','case-variant')){Assert ($p.Exit-ne 0) "$case should fail"}
            else{Assert ($p.Exit-eq 0) "$case should pass: $($p.Out)"}
            if($case-eq'one-sided'){Assert ($p.Out.Contains('Common Tasks skill inventory differs: missing from AGENTS.md: zz-planted.')) 'one-sided finding absent'}
            elseif($case-eq'duplicate'){Assert ($p.Out.Contains('Common Tasks skill inventory has duplicate slug in CLAUDE.md: alpha.')) 'duplicate finding absent'}
            elseif($case-eq'zero-extraction'){Assert ($p.Out.Contains('Common Tasks sections yielded zero skill slugs — the list grammar changed and this check is now blind.')) 'zero-extraction finding absent'}
            elseif($case-eq'absent-one'){Assert ($p.Out.Contains('Common Tasks section is missing from AGENTS.md.')) 'absent-one finding absent';Assert (-not $p.Out.Contains('Common Tasks skill inventory differs:')) 'absent-one emitted misleading inventory drift'}
            elseif($case-eq'absent-both'){Assert ($p.Out.Contains('Common Tasks section is absent from both CLAUDE.md and AGENTS.md; skill inventory check did not run.')) 'absent-both explicit OK absent'}
        } finally { Remove-Item -Recurse -Force $r }
    }
}

# CRLF lives HERE, scoped to the one check that needs it, and NOT in the shared TemplateFixture --
# see the comment on that function for what putting it there cost. A CRLF repo is the normal case for
# a Windows consumer who cloned with core.autocrlf=true, so both twins must strip CR identically
# before parsing.
#
# HONEST LIMIT, do not read a Windows green here as evidence: this case CANNOT fail on Windows. MSYS
# opens files in text mode, so the CR is gone before awk sees it -- disabling the .sh twin's CR strip
# entirely still leaves this case passing on Git Bash (measured 2026-08-17). It earns its keep only
# on the CI linux leg, where the CR actually reaches the tool, and it has not been observed red
# anywhere. Treat it as linux-only coverage, not as a red-tested assertion.
It 'template-checks Common Tasks agrees across twins when the mirrors use CRLF' {
    $r=TemplateFixture
    try {
        foreach ($f in 'CLAUDE.md','AGENTS.md') {
            $p2=Join-Path $r $f
            [IO.File]::WriteAllText($p2, ([IO.File]::ReadAllText($p2) -replace "`r`n","`n" -replace "`n","`r`n"), (New-Object Text.UTF8Encoding($false)))
        }
        $p=RunArg (Join-Path $r scripts/template-checks.ps1);$s=RunArg (Join-Path $r scripts/template-checks.sh)
        AssertExit $p $s 'crlf-common-tasks'
        AssertSeq (Records $p.Out) (Records $s.Out) 'crlf-common-tasks'
        Assert ($p.Exit-eq 0) "a CRLF mirror pair should pass: $($p.Out)"
        foreach ($twin in @(@('PowerShell',$p),@('bash',$s))) {
            Assert ($twin[1].Out.Contains('Common Tasks skill inventory matches between CLAUDE.md and AGENTS.md.')) "$($twin[0]) did not reach the Common Tasks check on CRLF input -- a CR left on the heading silently skips the whole section, which reads as a pass"
        }
    } finally { Remove-Item -Recurse -Force $r }
}

It 'template-checks accepts both layouts and rejects missing or divergent framework sections' {foreach($case in 'old-layout','carrier-layout','missing-both','leanness-drift'){$r=if($case-eq'carrier-layout'){CarrierTemplateFixture}else{TemplateFixture};try{if($case-eq'missing-both'){Put (Join-Path $r CLAUDE.md) "version: 1.2.3`n## Leanness`nSame`n## SOLID`nSame`n## Boy Scout Rule`nSame`n## Agentic Workflow`n### 1. Classify the intent`nSame`n"};if($case-eq'leanness-drift'){Put (Join-Path $r AGENTS.md) "## Verification Rules`nSame`n## Leanness`nDifferent`n## SOLID`nSame`n## Boy Scout Rule`nSame`n## Agentic Workflow`n### 1. Classify the intent`nSame`n### 2. Continue`n"};$p=RunArg (Join-Path $r scripts/template-checks.ps1);$s=RunArg (Join-Path $r scripts/template-checks.sh);AssertExit $p $s $case;AssertSeq (Records $p.Out) (Records $s.Out) "$case template-checks";if($case-in @('old-layout','carrier-layout')){Assert ($p.Exit-eq 0) "$case should pass: $($p.Out)"}elseif($case-eq'missing-both'){Assert ($p.Exit-ne 0) 'missing-both should fail';Assert ($p.Out.Contains("section '## Verification Rules' is missing from both")) 'missing-both finding absent'}else{Assert ($p.Exit-ne 0) 'Leanness drift should fail';Assert ($p.Out.Contains("AGENTS.md section '## Leanness' is not a verbatim mirror")) 'Leanness drift finding absent'}}finally{Remove-Item -Recurse -Force $r}}}

It 'template-checks rejects the observed one-line Boy Scout applicability drift' {
    $r=TemplateFixture
    try {
        $agents=Join-Path $r 'AGENTS.md'
        $before=[IO.File]::ReadAllText($agents)
        $after=$before.Replace('### Apply only when the file is the primary target of the change:', '### Apply only when the file is the primary target')
        Assert ($after-cne$before) 'Boy Scout regression mutation did not change the fixture'
        Put $agents $after
        $p=RunArg (Join-Path $r scripts/template-checks.ps1);$s=RunArg (Join-Path $r scripts/template-checks.sh)
        AssertExit $p $s 'boy-scout-applicability-drift'
        AssertSeq (Records $p.Out) (Records $s.Out) 'boy-scout-applicability-drift'
        Assert ($p.Exit-ne 0) 'one-line Boy Scout applicability drift should fail'
        Assert ($p.Out.Contains("AGENTS.md section '## Boy Scout Rule' is not a verbatim mirror")) 'PowerShell Boy Scout drift finding absent'
        Assert ($s.Out.Contains("AGENTS.md section '## Boy Scout Rule' is not a verbatim mirror")) 'bash Boy Scout drift finding absent'
    } finally { Remove-Item -Recurse -Force $r }
}

It 'template-checks rejects an Unreleased head at the stamped version but accepts a dated one' {foreach($case in 'dated','unreleased'){$r=TemplateFixture;try{$head=if($case-eq'dated'){'## 1.2.3 — 2026-08-08'}else{'## 1.2.3 — Unreleased'};Put (Join-Path $r 'CHANGELOG.md') "# Changelog`n`n$head`n`n- Fixture.`n";$p=RunArg (Join-Path $r scripts/template-checks.ps1);$s=RunArg (Join-Path $r scripts/template-checks.sh);AssertExit $p $s $case;AssertSeq (Records $p.Out) (Records $s.Out) "$case template-checks";if($case-eq'dated'){Assert ($p.Exit-eq 0) "dated head at the stamped version should pass: $($p.Out)"}else{Assert ($p.Exit-ne 0) 'Unreleased head at the stamped version should fail';$want="still reads '$head' — stamp it with a real release date before shipping.";Assert ($p.Out.Contains($want)) "PowerShell placeholder finding absent: $($p.Out)";Assert ($s.Out.Contains($want)) "bash placeholder finding absent: $($s.Out)"}}finally{Remove-Item -Recurse -Force $r}}}

It 'docs-sync-check branches and advisory prose agree' {
    # Capture every process before asserting. On the old wrappers both unable worlds must be visible
    # in the one aggregate failure; an early status-2 assertion must not hide the unexpected status.
    $templateResult=$null
    $consumerResults=[ordered]@{}
    $r=TemplateFixture
    try {
        CopyPair docs-sync-check $r
        Put (Join-Path $r '.template-repo') ''
        $templateResult=[pscustomobject]@{Name='template';Ps=RunArg (Join-Path $r scripts/docs-sync-check.ps1);Sh=RunArg (Join-Path $r scripts/docs-sync-check.sh) -BashOptions @('-e')}
    } finally { Remove-Item -Recurse -Force $r }

    $r=DocsFixture
    try {
        SetWarehouseStub $r 0 0 stdout 'WAREHOUSE_CHILD_STATUS_0'
        $consumerResults['status-0']=[pscustomobject]@{Name='status-0';Ps=RunArg (Join-Path $r scripts/docs-sync-check.ps1);Sh=RunArg (Join-Path $r scripts/docs-sync-check.sh) -BashOptions @('-e')}

        Put (Join-Path $r '.github/skills/my-skill/SKILL.md') "# skill`n"
        foreach($world in @(
            [pscustomobject]@{Name='status-1';PsStatus=1;ShStatus=1;Stream='stdout';Sentinel='WAREHOUSE_CHILD_STATUS_1'},
            [pscustomobject]@{Name='status-2';PsStatus=2;ShStatus=2;Stream='stderr';Sentinel='WAREHOUSE_CHILD_STATUS_2'},
            [pscustomobject]@{Name='unexpected';PsStatus=-1;ShStatus=7;Stream='stderr';Sentinel='WAREHOUSE_CHILD_STATUS_UNEXPECTED'}
        )) {
            SetWarehouseStub $r $world.PsStatus $world.ShStatus $world.Stream $world.Sentinel
            $consumerResults[$world.Name]=[pscustomobject]@{Name=$world.Name;Ps=RunArg (Join-Path $r scripts/docs-sync-check.ps1);Sh=RunArg (Join-Path $r scripts/docs-sync-check.sh) -BashOptions @('-e')}
        }
    } finally { Remove-Item -Recurse -Force $r }

    $issues=[Collections.Generic.List[string]]::new()
    function Expect($condition,$message) { if(-not$condition){[void]$issues.Add($message)} }
    foreach($pair in @($templateResult)+@($consumerResults.Values)) {
        Expect ($pair.Ps.Exit-eq$pair.Sh.Exit) "$($pair.Name) exit mismatch $($pair.Ps.Exit)/$($pair.Sh.Exit)`nPS OUT:`n$($pair.Ps.Out)`nPS ERR:`n$($pair.Ps.Err)`nSH OUT:`n$($pair.Sh.Out)`nSH ERR:`n$($pair.Sh.Err)"
        Expect ((NormDocs $pair.Ps.Out)-eq(NormDocs $pair.Sh.Out)) "$($pair.Name) stdout differs`nPS:`n$($pair.Ps.Out)`nSH:`n$($pair.Sh.Out)"
    }

    $oldNote='NOTE: warehouse map is missing or stale; refresh it before a warehouse write. (advisory - not a failure)'
    $newNote='NOTE: warehouse map could not be verified; this is not evidence that the map is missing or stale. (advisory - not a failure)'
    $zero=$consumerResults['status-0']
    foreach($twin in @(@('PowerShell',$zero.Ps,'FAIL: .github/skills is missing — run scripts/sync-agent-files.ps1.'),@('bash',$zero.Sh,'FAIL: .github/skills is missing — run scripts/sync-agent-files.sh.'))) {
        $label=$twin[0];$result=$twin[1];$missingMirror=$twin[2]
        Expect ($result.Exit-eq 1) "$label status-0/missing-mirror exit should be 1, got $($result.Exit)"
        Expect ((LiteralCount $result.Out 'WAREHOUSE_CHILD_STATUS_0')-eq 1) "$label status-0 checker sentinel cardinality differs"
        Expect ((LiteralCount $result.Out $missingMirror)-eq 1) "$label missing-mirror finding cardinality differs"
        Expect ((LiteralCount $result.Out $oldNote)-eq 0) "$label status 0 emitted the missing/stale warehouse note"
        Expect ((LiteralCount $result.Out $newNote)-eq 0) "$label status 0 emitted the unable-to-verify warehouse note"
    }
    $a="NOTE: docs/ci-integration.md is missing — restore it from the template if you need the portable required-build recipe. (advisory — not a failure)"
    $b="NOTE: README.md does not mention: skill:my-skill agent:my-agent — update the What's-in-the-box / subagents tables (they may have drifted). (advisory — not a failure)"
    foreach($advisory in $a,$b){Expect ($zero.Ps.Out.Contains($advisory)) "PowerShell advisory differs: $advisory";Expect ($zero.Sh.Out.Contains($advisory)) "bash advisory differs: $advisory"}

    $one=$consumerResults['status-1']
    foreach($twin in @(@('PowerShell',$one.Ps),@('bash',$one.Sh))) {
        $label=$twin[0];$result=$twin[1]
        Expect ($result.Exit-eq 0) "$label status-1 wrapper should remain non-failing, got $($result.Exit)"
        Expect ((LiteralCount $result.Out 'WAREHOUSE_CHILD_STATUS_1')-eq 1) "$label status-1 checker sentinel cardinality differs"
        Expect ((LiteralCount $result.Out $oldNote)-eq 1) "$label status 1 missing/stale note cardinality differs"
        Expect ((LiteralCount $result.Out $newNote)-eq 0) "$label status 1 emitted unable-to-verify note"
    }

    foreach($world in @(@('status-2','WAREHOUSE_CHILD_STATUS_2'),@('unexpected','WAREHOUSE_CHILD_STATUS_UNEXPECTED'))) {
        $pair=$consumerResults[$world[0]];$sentinel=$world[1]
        foreach($twin in @(@('PowerShell',$pair.Ps),@('bash',$pair.Sh))) {
            $label=$twin[0];$result=$twin[1]
            Expect ($result.Exit-eq 0) "$label $($world[0]) wrapper should remain non-failing, got $($result.Exit)"
            $sentinelCount=TerminalLineCount $result.Err $sentinel
            Expect ($sentinelCount-eq 1) "$label $($world[0]) stderr sentinel cardinality differs (got $sentinelCount)`nERR:`n$($result.Err)"
            Expect ((LiteralCount $result.Out $newNote)-eq 1) "$label $($world[0]) unable-to-verify note cardinality differs"
            Expect ((LiteralCount $result.Out $oldNote)-eq 0) "$label $($world[0]) emitted contradictory missing/stale note"
        }
    }
    Assert ($issues.Count-eq 0) ("docs-sync matrix failures:`n"+($issues-join"`n"))
}

It 'sync-agent-files recursively produces identical trees' {
    $seed=Temp sync-seed
    $roots=[Collections.Generic.List[string]]::new()
    try{
        Put (Join-Path $seed '.claude/skills/a/SKILL.md') '# a'
        Put (Join-Path $seed '.claude/skills/a/reference/notes.md') 'nested'
        $sourceBase=(Resolve-Path (Join-Path $seed '.claude/skills')).Path
        $sourceFingerprint=@(Get-ChildItem $sourceBase -Recurse -File|ForEach-Object{($_.FullName.Substring($sourceBase.Length).TrimStart('\','/')-replace'\\','/')+'|'+(Get-FileHash $_.FullName -Algorithm SHA256).Hash}|Sort-Object)-join"`n"
        $results=@{}
        $testRoots=@{}
        foreach($kind in 'ps1','sh'){
            $r=Temp "sync-$kind";$roots.Add($r)|Out-Null
            Copy-Item (Join-Path $seed '.claude') $r -Recurse -Force
            CopyPair sync-agent-files $r
            InitSafe $r
            $results[$kind]=RunHere (Join-Path $r "scripts/sync-agent-files.$kind") $r
            $testRoots[$kind]=$r
        }
        $issues=[Collections.Generic.List[string]]::new()
        $expected='Synced skills: .claude/skills -> .github/skills'
        foreach($kind in 'ps1','sh'){
            $result=$results[$kind]
            if($result.Exit-ne0){$issues.Add("$kind sync exit=$($result.Exit)")}
            if($result.Out-cne$expected){$issues.Add("$kind sync stdout differs: [$($result.Out)]")}
            if(-not[string]::IsNullOrEmpty($result.Err)){$issues.Add("$kind sync stderr was not empty: [$($result.Err)]")}
            $mirror=Join-Path $testRoots[$kind] '.github/skills'
            if(-not(Test-Path -LiteralPath $mirror -PathType Container)){$issues.Add("$kind mirror is missing");continue}
            $mirrorBase=(Resolve-Path $mirror).Path
            $mirrorFingerprint=@(Get-ChildItem $mirrorBase -Recurse -File|ForEach-Object{($_.FullName.Substring($mirrorBase.Length).TrimStart('\','/')-replace'\\','/')+'|'+(Get-FileHash $_.FullName -Algorithm SHA256).Hash}|Sort-Object)-join"`n"
            if($mirrorFingerprint-cne$sourceFingerprint){$issues.Add("$kind mirror differs from the canonical source")}
        }
        Assert ($issues.Count-eq0) ($issues-join"`n")
    }finally{
        foreach($r in $roots){Remove-Item -Recurse -Force $r}
        Remove-Item -Recurse -Force $seed
    }
}

It 'sync-agent-files twins fall back to the current directory outside Git' {
    $seed=Temp sync-nongit-seed
    try{
        Put (Join-Path $seed '.claude/skills/a/SKILL.md') '# a'
        Put (Join-Path $seed '.claude/skills/a/reference/notes.md') 'nested'
        foreach($kind in 'ps1','sh'){
            $r=Temp "sync-nongit-$kind"
            try{
                Copy-Item (Join-Path $seed '.claude') $r -Recurse -Force
                CopyPair sync-agent-files $r
                $null=git -C $r rev-parse --show-toplevel 2>$null
                Assert ($LASTEXITCODE-ne 0) "setup: $r unexpectedly resolves inside Git"
                $res=RunHere (Join-Path $r "scripts/sync-agent-files.$kind") $r
                Assert ($res.Exit-eq 0) "$kind non-Git sync exit=$($res.Exit): $($res.Err)"
                Assert ($res.Out-eq'Synced skills: .claude/skills -> .github/skills') "$kind non-Git stdout differs: $($res.Out)"
                Assert ([string]::IsNullOrEmpty($res.Err)) "$kind non-Git stderr was not empty: $($res.Err)"
                $mirrored=Join-Path $r '.github/skills/a/reference/notes.md'
                Assert ((Test-Path -LiteralPath $mirrored)-and([IO.File]::ReadAllText($mirrored)-eq'nested')) "$kind non-Git nested mirror missing"
            }finally{Remove-Item -Recurse -Force $r}
        }
    }finally{Remove-Item -Recurse -Force $seed}
}

It 'metrics twins agree on every non-zero counter' {$pairs=@();$localPs=Join-Path $scripts metrics.ps1;if(Test-Path $localPs){$pairs+=,$localPs}else{$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path;$pairs+=@(Get-ChildItem (Join-Path $root 'stacks/*/files/scripts/metrics.ps1'))};foreach($mp in $pairs){$ms=$mp.FullName;if(-not$ms){$ms=$mp};$sh=$ms-replace'\.ps1$','.sh';$r=Temp metrics;try{InitSafe $r;# Canonically-cased source exercises source patterns; case-sensitivity parity is intentionally not asserted.
Put (Join-Path $r sample.cs) @'
async Task Work() { }
_logger.LogInformation($"x");
#pragma warning disable CS1
Console.WriteLine("x");
// TODO TODO
throw new NotImplementedException();
var s = new UserService();
var h = MD5.Create(); var h2 = SHA1.Create();
q.FromSqlRaw("x");
double TotalAmount;
[Fact] void T() { Assert.True(true); }
[Fact(Skip = "x")] void S() { }
'@;Put (Join-Path $r sample.ts) @'
let x: any; let y = <any>x;
// @ts-ignore
// eslint-disable
stream.subscribe();
sanitizer.bypassSecurityTrustHtml(x);
console.log(x);
// TODO TODO
throw new Error("not implemented");
const s = new UserService();
describe("x", () => { it("y", () => { expect(true).toBe(true); }); });
fit("x", () => {});
'@;Put (Join-Path $r 'bin/excluded.cs') 'Console.WriteLine("excluded");';Put (Join-Path $r 'node_modules/excluded.ts') 'console.log("excluded");';$p=RunHere $ms $r;$s=RunHere $sh $r;Assert ($p.Exit-eq$s.Exit) "metrics exits differ for $ms";$pj=$p.Out|ConvertFrom-Json;$sj=$s.Out|ConvertFrom-Json;$pk=@($pj.metrics.psobject.Properties.Name|Sort-Object);$sk=@($sj.metrics.psobject.Properties.Name|Sort-Object);Assert (($pk-join'|')-eq($sk-join'|')) "metric key sets differ for $ms";foreach($k in $pk){$pv=[int]$pj.metrics.$k;$sv=[int]$sj.metrics.$k;Assert ($pv-gt 0) "$k expected non-zero, got $pv";Assert ($pv-eq$sv) "$k differs: PS=$pv SH=$sv"};Assert (($pj.metrics|ConvertTo-Json -Compress)-eq($sj.metrics|ConvertTo-Json -Compress)) "whole metrics objects differ for $ms"}finally{Remove-Item -Recurse -Force $r}}}

exit (Write-TestSummary 'ScriptTwinParity.Tests')
