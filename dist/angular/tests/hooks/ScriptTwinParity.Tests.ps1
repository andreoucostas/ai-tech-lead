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
function TemplateFixture { $r=Temp template;CopyPair template-checks $r;Put (Join-Path $r CLAUDE.md) "version: 1.2.3`n## Verification Rules`nSame`n## Leanness`nSame`n## SOLID`nSame`n## Boy Scout Rule`nSame`n## Agentic Workflow`n### 1. Classify the intent`nSame`n### 2. Continue`n## Common Tasks`n- ``alpha`` — first → second`n- ``beta`` - plain separator`n";Put (Join-Path $r AGENTS.md) "## Verification Rules`nSame`n## Leanness`nSame`n## SOLID`nSame`n## Boy Scout Rule`nSame`n## Agentic Workflow`n### 1. Classify the intent`nSame`n### 2. Continue`n## Common Tasks`n- ``alpha`` — first → second`n- ``beta`` - plain separator`n";Put (Join-Path $r '.claude/framework-version.json') '{"version":"1.2.3"}';Put (Join-Path $r '.github/copilot-instructions.md') "fixture`n";PutBom (Join-Path $r '.claude/hooks/probe.ps1') "# probe`n";Put (Join-Path $r '.claude/hooks/probe.sh') "# probe`n";Put (Join-Path $r '.claude/skills/demo/SKILL.md') "# demo`n";Put (Join-Path $r '.github/skills/demo/SKILL.md') "# demo`n";$r }
function CarrierTemplateFixture { $r=TemplateFixture;Put (Join-Path $r CLAUDE.md) "version: 1.2.3`n@.github/instructions/framework-rules.instructions.md`n## Boy Scout Rule`nSame`n## Common Tasks`n- ``alpha`` — first → second`n- ``beta`` - plain separator`n";Put (Join-Path $r '.github/instructions/framework-rules.instructions.md') "## Verification Rules`nSame`n## Leanness`nSame`n## SOLID`nSame`n## Agentic Workflow`n### 1. Classify the intent`nSame`n### 2. Carrier-only continuation`n";$r }
# The checks this fixture must REACH. Several checks are wrapped in "if the directory exists", so a
# fixture that omits the directory skips the check silently and the twins agree vacuously. Asserting
# the reached set turns "this check never ran" into a failure instead of a green line.
$ExpectedChecks = @('version stamps in sync','mirrored verbatim','Agentic Workflow','copilot-instructions.md present','carry a UTF-8 BOM','<framework scripts parse cleanly>','every hook has its','skills and .github/skills are in sync','Common Tasks skill inventory matches')
function NormDocs($text) { $known='sync-agent-files|template-checks|wiki-check|warehouse-map-check|build-architecture-html';$x=$text-replace("("+$known+")\.(ps1|sh)"),'$1.<script>';($x-replace'all framework \.(ps1|sh) files parse cleanly\.','all framework scripts parse cleanly.') }
function DocsFixture { $r=Temp docs;CopyPair docs-sync-check $r;Put (Join-Path $r 'docs/enforcement-surfaces.md') "fixture`n";Put (Join-Path $r CLAUDE.md) "# ready`n";Put (Join-Path $r AGENTS.md) "GENERATED FILE`n## Verification Rules`n## Leanness`n## Boy Scout Rule`n## Agentic Workflow`n";Put (Join-Path $r '.github/copilot-instructions.md') "fixture`n";Put (Join-Path $r TECH_DEBT.md) "# debt`n";Put (Join-Path $r FRAMEWORK-CONTEXT.md) "# context`n";Put (Join-Path $r README.md) "# fixture`n";Put (Join-Path $r '.claude/skills/my-skill/SKILL.md') "# skill`n";Put (Join-Path $r '.claude/agents/my-agent.md') "# agent`n";$r }

Reset-Tests
if(-not $bash){foreach($n in 'template-checks clean and drift','docs-sync-check branches and advisories','sync-agent-files recursive mirror','metrics counters'){Skip $n 'bash unavailable; twin comparison requires bash'};exit (Write-TestSummary 'ScriptTwinParity.Tests')}

It 'template-checks clean and planted drift agree in order' {$r=TemplateFixture;try{$ps=Join-Path $r scripts/template-checks.ps1;$sh=Join-Path $r scripts/template-checks.sh;$pt=[IO.File]::ReadAllText($ps);$st=[IO.File]::ReadAllText($sh);Assert (([regex]::Matches($pt,'files parse cleanly\.')).Count-eq 1) 'PowerShell parse-success emission count changed';Assert (([regex]::Matches($st,'files parse cleanly\.')).Count-eq 1) 'bash parse-success emission count changed';foreach($drift in $false,$true){if($drift){Put (Join-Path $r '.claude/framework-version.json') '{"version":"9.9.9"}'};$p=RunArg $ps;$s=RunArg $sh;AssertExit $p $s 'template-checks';$recs=Records $p.Out;AssertSeq $recs (Records $s.Out) 'template-checks';if(-not $drift){foreach($want in $ExpectedChecks){$hits=@($recs|Where-Object{$_-like "*$want*"}).Count;Assert ($hits-ge 1) "check '$want' was never reached -- the fixture stopped exercising it, so the twins would agree vacuously here. Restore the fixture input that triggers it."}};if($drift){Assert ($p.Out.Contains('version-stamp drift: CLAUDE.md says 1.2.3, framework-version.json says 9.9.9.')) 'PowerShell drift failure missing';Assert ($s.Out.Contains('version-stamp drift: CLAUDE.md says 1.2.3, framework-version.json says 9.9.9.')) 'bash drift failure missing'}}}finally{Remove-Item -Recurse -Force $r}}

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

It 'template-checks rejects an Unreleased head at the stamped version but accepts a dated one' {foreach($case in 'dated','unreleased'){$r=TemplateFixture;try{$head=if($case-eq'dated'){'## 1.2.3 — 2026-08-08'}else{'## 1.2.3 — Unreleased'};Put (Join-Path $r 'CHANGELOG.md') "# Changelog`n`n$head`n`n- Fixture.`n";$p=RunArg (Join-Path $r scripts/template-checks.ps1);$s=RunArg (Join-Path $r scripts/template-checks.sh);AssertExit $p $s $case;AssertSeq (Records $p.Out) (Records $s.Out) "$case template-checks";if($case-eq'dated'){Assert ($p.Exit-eq 0) "dated head at the stamped version should pass: $($p.Out)"}else{Assert ($p.Exit-ne 0) 'Unreleased head at the stamped version should fail';$want="still reads '$head' — stamp it with a real release date before shipping.";Assert ($p.Out.Contains($want)) "PowerShell placeholder finding absent: $($p.Out)";Assert ($s.Out.Contains($want)) "bash placeholder finding absent: $($s.Out)"}}finally{Remove-Item -Recurse -Force $r}}}

It 'docs-sync-check branches and advisory prose agree' {foreach($template in $true,$false){$r=if($template){TemplateFixture}else{DocsFixture};try{if($template){CopyPair docs-sync-check $r;Put (Join-Path $r '.template-repo') ''};$p=RunArg (Join-Path $r scripts/docs-sync-check.ps1);$s=RunArg (Join-Path $r scripts/docs-sync-check.sh);AssertExit $p $s 'docs-sync-check';Assert ((NormDocs $p.Out)-eq(NormDocs $s.Out)) "docs stdout differs`nPS:`n$($p.Out)`nSH:`n$($s.Out)";if(-not$template){$a="NOTE: docs/ci-integration.md is missing — restore it from the template if you need the portable required-build recipe. (advisory — not a failure)";$b="NOTE: README.md does not mention: skill:my-skill agent:my-agent — update the What's-in-the-box / subagents tables (they may have drifted). (advisory — not a failure)";foreach($x in $a,$b){Assert ($p.Out.Contains($x)) "PowerShell advisory differs: $x";Assert ($s.Out.Contains($x)) "bash advisory differs: $x"}}}finally{Remove-Item -Recurse -Force $r}}}

It 'sync-agent-files recursively produces identical trees' {$seed=Temp sync-seed;try{Put (Join-Path $seed '.claude/skills/a/SKILL.md') '# a';Put (Join-Path $seed '.claude/skills/a/reference/notes.md') 'nested';foreach($kind in 'ps1','sh'){$r=Temp "sync-$kind";Copy-Item (Join-Path $seed '.claude') $r -Recurse -Force;CopyPair sync-agent-files $r;InitSafe $r;$res=RunHere (Join-Path $r "scripts/sync-agent-files.$kind") $r;if($kind-eq'ps1'){$pr=$res;$proot=$r}else{$sr=$res;$sroot=$r}};try{Assert ($pr.Exit-eq$sr.Exit) 'sync exits differ';Assert ($pr.Out-eq$sr.Out) 'sync stdout differs';$trees=@();foreach($root in $proot,$sroot){$base=(Resolve-Path (Join-Path $root '.github/skills')).Path;$rows=@(Get-ChildItem $base -Recurse -File|ForEach-Object{($_.FullName.Substring($base.Length).TrimStart('\','/')-replace'\\','/')+'|'+(Get-FileHash $_.FullName -Algorithm SHA256).Hash}|Sort-Object);$trees+=,(,$rows)};Assert (($trees[0]|ConvertTo-Json -Compress)-eq($trees[1]|ConvertTo-Json -Compress)) 'sync output trees differ'}finally{Remove-Item -Recurse -Force $proot,$sroot}}finally{Remove-Item -Recurse -Force $seed}}

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
                Assert ($res.Out-eq'Synced 1 skill(s): .claude/skills -> .github/skills') "$kind non-Git stdout differs: $($res.Out)"
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
