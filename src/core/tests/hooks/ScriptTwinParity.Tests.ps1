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
function CopyPair($name,$root) { New-Item -ItemType Directory -Force (Join-Path $root scripts)|Out-Null;Copy-Item (Join-Path $scripts "$name.ps1") (Join-Path $root scripts);Copy-Item (Join-Path $scripts "$name.sh") (Join-Path $root scripts) }
function TemplateFixture { $r=Temp template;CopyPair template-checks $r;Put (Join-Path $r CLAUDE.md) "version: 1.2.3`n## Verification Rules`nSame`n## Leanness`nSame`n## SOLID`nSame`n## Boy Scout Rule`nSame`n## Agentic Workflow`n### 1. Classify the intent`nSame`n### 2. Continue`n";Put (Join-Path $r AGENTS.md) "## Verification Rules`nSame`n## Leanness`nSame`n## SOLID`nSame`n## Boy Scout Rule`nSame`n## Agentic Workflow`n### 1. Classify the intent`nSame`n### 2. Continue`n";Put (Join-Path $r '.claude/framework-version.json') '{"version":"1.2.3"}';Put (Join-Path $r '.github/copilot-instructions.md') "fixture`n";PutBom (Join-Path $r '.claude/hooks/probe.ps1') "# probe`n";Put (Join-Path $r '.claude/hooks/probe.sh') "# probe`n";Put (Join-Path $r '.claude/skills/demo/SKILL.md') "# demo`n";Put (Join-Path $r '.github/skills/demo/SKILL.md') "# demo`n";$r }
function CarrierTemplateFixture { $r=TemplateFixture;Put (Join-Path $r CLAUDE.md) "version: 1.2.3`n@.github/instructions/framework-rules.instructions.md`n## Boy Scout Rule`nSame`n";Put (Join-Path $r '.github/instructions/framework-rules.instructions.md') "## Verification Rules`nSame`n## Leanness`nSame`n## SOLID`nSame`n## Agentic Workflow`n### 1. Classify the intent`nSame`n### 2. Carrier-only continuation`n";$r }
# The checks this fixture must REACH. Several checks are wrapped in "if the directory exists", so a
# fixture that omits the directory skips the check silently and the twins agree vacuously. Asserting
# the reached set turns "this check never ran" into a failure instead of a green line.
$ExpectedChecks = @('version stamps in sync','mirrored verbatim','Agentic Workflow','copilot-instructions.md present','carry a UTF-8 BOM','<framework scripts parse cleanly>','every hook has its','skills and .github/skills are in sync')
function NormDocs($text) { $known='sync-agent-files|template-checks|wiki-check|build-architecture-html';$x=$text-replace("("+$known+")\.(ps1|sh)"),'$1.<script>';($x-replace'all framework \.(ps1|sh) files parse cleanly\.','all framework scripts parse cleanly.') }
function DocsFixture { $r=Temp docs;CopyPair docs-sync-check $r;Put (Join-Path $r 'docs/enforcement-surfaces.md') "fixture`n";Put (Join-Path $r CLAUDE.md) "# ready`n";Put (Join-Path $r AGENTS.md) "GENERATED FILE`n## Verification Rules`n## Leanness`n## Boy Scout Rule`n## Agentic Workflow`n";Put (Join-Path $r '.github/copilot-instructions.md') "fixture`n";Put (Join-Path $r TECH_DEBT.md) "# debt`n";Put (Join-Path $r FRAMEWORK-CONTEXT.md) "# context`n";Put (Join-Path $r README.md) "# fixture`n";Put (Join-Path $r '.claude/skills/my-skill/SKILL.md') "# skill`n";Put (Join-Path $r '.claude/agents/my-agent.md') "# agent`n";$r }

Reset-Tests
if(-not $bash){foreach($n in 'template-checks clean and drift','docs-sync-check branches and advisories','sync-agent-files recursive mirror','metrics counters'){Skip $n 'bash unavailable; twin comparison requires bash'};exit (Write-TestSummary 'ScriptTwinParity.Tests')}

It 'template-checks clean and planted drift agree in order' {$r=TemplateFixture;try{$ps=Join-Path $r scripts/template-checks.ps1;$sh=Join-Path $r scripts/template-checks.sh;$pt=[IO.File]::ReadAllText($ps);$st=[IO.File]::ReadAllText($sh);Assert (([regex]::Matches($pt,'files parse cleanly\.')).Count-eq 1) 'PowerShell parse-success emission count changed';Assert (([regex]::Matches($st,'files parse cleanly\.')).Count-eq 1) 'bash parse-success emission count changed';foreach($drift in $false,$true){if($drift){Put (Join-Path $r '.claude/framework-version.json') '{"version":"9.9.9"}'};$p=RunArg $ps;$s=RunArg $sh;Assert ($p.Exit-eq$s.Exit) "exit mismatch $($p.Exit)/$($s.Exit)";$recs=Records $p.Out;AssertSeq $recs (Records $s.Out) 'template-checks';if(-not $drift){foreach($want in $ExpectedChecks){$hits=@($recs|Where-Object{$_-like "*$want*"}).Count;Assert ($hits-ge 1) "check '$want' was never reached -- the fixture stopped exercising it, so the twins would agree vacuously here. Restore the fixture input that triggers it."}};if($drift){Assert ($p.Out.Contains('version-stamp drift: CLAUDE.md says 1.2.3, framework-version.json says 9.9.9.')) 'PowerShell drift failure missing';Assert ($s.Out.Contains('version-stamp drift: CLAUDE.md says 1.2.3, framework-version.json says 9.9.9.')) 'bash drift failure missing'}}}finally{Remove-Item -Recurse -Force $r}}

It 'template-checks accepts both layouts and rejects missing or divergent framework sections' {foreach($case in 'old-layout','carrier-layout','missing-both','leanness-drift'){$r=if($case-eq'carrier-layout'){CarrierTemplateFixture}else{TemplateFixture};try{if($case-eq'missing-both'){Put (Join-Path $r CLAUDE.md) "version: 1.2.3`n## Leanness`nSame`n## SOLID`nSame`n## Boy Scout Rule`nSame`n## Agentic Workflow`n### 1. Classify the intent`nSame`n"};if($case-eq'leanness-drift'){Put (Join-Path $r AGENTS.md) "## Verification Rules`nSame`n## Leanness`nDifferent`n## SOLID`nSame`n## Boy Scout Rule`nSame`n## Agentic Workflow`n### 1. Classify the intent`nSame`n### 2. Continue`n"};$p=RunArg (Join-Path $r scripts/template-checks.ps1);$s=RunArg (Join-Path $r scripts/template-checks.sh);Assert ($p.Exit-eq$s.Exit) "$case exit mismatch $($p.Exit)/$($s.Exit)";AssertSeq (Records $p.Out) (Records $s.Out) "$case template-checks";if($case-in @('old-layout','carrier-layout')){Assert ($p.Exit-eq 0) "$case should pass: $($p.Out)"}elseif($case-eq'missing-both'){Assert ($p.Exit-ne 0) 'missing-both should fail';Assert ($p.Out.Contains("section '## Verification Rules' is missing from both")) 'missing-both finding absent'}else{Assert ($p.Exit-ne 0) 'Leanness drift should fail';Assert ($p.Out.Contains("AGENTS.md section '## Leanness' is not a verbatim mirror")) 'Leanness drift finding absent'}}finally{Remove-Item -Recurse -Force $r}}}

It 'docs-sync-check branches and advisory prose agree' {foreach($template in $true,$false){$r=if($template){TemplateFixture}else{DocsFixture};try{if($template){CopyPair docs-sync-check $r;Put (Join-Path $r '.template-repo') ''};$p=RunArg (Join-Path $r scripts/docs-sync-check.ps1);$s=RunArg (Join-Path $r scripts/docs-sync-check.sh);Assert ($p.Exit-eq$s.Exit) "docs exit mismatch";Assert ((NormDocs $p.Out)-eq(NormDocs $s.Out)) "docs stdout differs`nPS:`n$($p.Out)`nSH:`n$($s.Out)";if(-not$template){$a="NOTE: docs/ci-integration.md is missing — restore it from the template if you need the portable required-build recipe. (advisory — not a failure)";$b="NOTE: README.md does not mention: skill:my-skill agent:my-agent — update the What's-in-the-box / subagents tables (they may have drifted). (advisory — not a failure)";foreach($x in $a,$b){Assert ($p.Out.Contains($x)) "PowerShell advisory differs: $x";Assert ($s.Out.Contains($x)) "bash advisory differs: $x"}}}finally{Remove-Item -Recurse -Force $r}}}

It 'sync-agent-files recursively produces identical trees' {$seed=Temp sync-seed;try{Put (Join-Path $seed '.claude/skills/a/SKILL.md') '# a';Put (Join-Path $seed '.claude/skills/a/reference/notes.md') 'nested';foreach($kind in 'ps1','sh'){$r=Temp "sync-$kind";Copy-Item (Join-Path $seed '.claude') $r -Recurse -Force;CopyPair sync-agent-files $r;InitSafe $r;$res=RunHere (Join-Path $r "scripts/sync-agent-files.$kind") $r;if($kind-eq'ps1'){$pr=$res;$proot=$r}else{$sr=$res;$sroot=$r}};try{Assert ($pr.Exit-eq$sr.Exit) 'sync exits differ';Assert ($pr.Out-eq$sr.Out) 'sync stdout differs';$trees=@();foreach($root in $proot,$sroot){$base=(Resolve-Path (Join-Path $root '.github/skills')).Path;$rows=@(Get-ChildItem $base -Recurse -File|ForEach-Object{($_.FullName.Substring($base.Length).TrimStart('\','/')-replace'\\','/')+'|'+(Get-FileHash $_.FullName -Algorithm SHA256).Hash}|Sort-Object);$trees+=,(,$rows)};Assert (($trees[0]|ConvertTo-Json -Compress)-eq($trees[1]|ConvertTo-Json -Compress)) 'sync output trees differ'}finally{Remove-Item -Recurse -Force $proot,$sroot}}finally{Remove-Item -Recurse -Force $seed}}

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
