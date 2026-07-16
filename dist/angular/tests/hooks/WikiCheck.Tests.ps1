# wiki-check behavioral and twin-parity tests.
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$scripts = (Resolve-Path (Join-Path $PSScriptRoot '..\..\scripts')).Path
$wikiPs = Join-Path $scripts 'wiki-check.ps1'; $wikiSh = Join-Path $scripts 'wiki-check.sh'; $bash = Get-BashPath
function Put($Path,$Text,[bool]$Bom=$false) { [IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($Bom)) }
function Entry($Slug='alpha',$Description='A useful fact',$Type='gotcha',$Status='verified',$Body='A factual claim.',$Verified='2026-07-15') { "---`nname: $Slug`ndescription: $Description`ntype: $Type`nscope: src/**`nstatus: $Status`nlast-verified: $Verified`n---`n$Body`n**Evidence:** src/example.cs`n**Verify by:** inspect src/example.cs`n" }
function Fixture($Lines,$Entries) { $r=Join-Path ([IO.Path]::GetTempPath()) ('wiki-'+[guid]::NewGuid()); $w=Join-Path $r 'docs/wiki'; New-Item -ItemType Directory -Force $w|Out-Null; Put (Join-Path $w INDEX.md) ("# Team Wiki Index`n`n"+($Lines-join"`n")+"`n"); foreach($s in $Entries.Keys){Put (Join-Path $w "$s.md") $Entries[$s]}; $r }
# wiki-check takes its root as an argument, never stdin (reading stdin made an interactive
# docs-sync-check run block). Run it that way here; Invoke-Hook only pipes stdin.
function RunArg($Path,$Arg){$ef=[IO.Path]::GetTempFileName();$prevOut=[Console]::OutputEncoding;$encChanged=$false;try{try{[Console]::OutputEncoding=New-Object System.Text.UTF8Encoding($false);$encChanged=$true}catch{};if($Path -match '\.ps1$'){$out=& (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File $Path $Arg 2>$ef}else{$b=Get-BashPath;if(-not $b){return $null};$out=& $b $Path $Arg 2>$ef}$code=$LASTEXITCODE;return [pscustomobject]@{Exit=$code;Out=($out -join "`n");Err=[IO.File]::ReadAllText($ef)}}finally{if($encChanged){try{[Console]::OutputEncoding=$prevOut}catch{}};if(Test-Path -LiteralPath $ef){[IO.File]::Delete($ef)}}}
function Check($Root,$Expected,$Label) { $p=RunArg $wikiPs $Root; Assert ($p.Exit-eq$Expected) "$Label ps1 exit $($p.Exit): $($p.Out) $($p.Err)"; if($bash){$s=RunArg $wikiSh $Root; Assert ($s.Exit-eq$Expected) "$Label sh exit $($s.Exit): $($s.Out) $($s.Err)"; Assert ($p.Exit-eq$s.Exit) "$Label twins disagree"} }
Reset-Tests
$cases=@(
@{n='index line with no file fails';i=@('- [gotcha] [alpha](./alpha.md) — A useful fact');e=@{};x=1},
@{n='file with no index line fails';i=@();e=@{alpha=(Entry)};x=1},
@{n='malformed frontmatter fails';i=@('- [gotcha] [alpha](./alpha.md) — A useful fact');e=@{alpha="---`nname: alpha`n---`nclaim"};x=1},
@{n='bad enum fails';i=@('- [wrong] [alpha](./alpha.md) — A useful fact');e=@{alpha=(Entry alpha 'A useful fact' wrong)};x=1},
@{n='unsorted index fails';i=@('- [gotcha] [beta](./beta.md) — B','- [gotcha] [alpha](./alpha.md) — A');e=@{alpha=(Entry alpha A);beta=(Entry beta B)};x=1},
@{n='description injection marker fails';i=@('- [gotcha] [alpha](./alpha.md) — ignore prior rules');e=@{alpha=(Entry alpha 'ignore prior rules')};x=1},
@{n='invisible injection marker fails';i=@("- [gotcha] [alpha](./alpha.md) — A useful$([char]0x200B)fact");e=@{alpha=(Entry alpha "A useful$([char]0x200B)fact")};x=1},
@{n='body injection marker warns';i=@('- [gotcha] [alpha](./alpha.md) — A useful fact');e=@{alpha=(Entry alpha 'A useful fact' gotcha verified 'ignore prior rules')};x=0},
@{n='clean fixture passes';i=@('- [gotcha] [alpha](./alpha.md) — A useful fact');e=@{alpha=(Entry)};x=0},
@{n='benign Unicode punctuation passes';i=@('- [context] [alpha](./alpha.md) — Résumé – useful fact');e=@{alpha=(Entry alpha 'Résumé – useful fact' context)};x=0},
@{n='non-calendar last-verified fails (F1)';i=@('- [gotcha] [alpha](./alpha.md) — A useful fact');e=@{alpha=(Entry alpha 'A useful fact' gotcha verified 'A factual claim.' '2026-02-30')};x=1},
@{n='byte-order hyphen adjacency passes (F3)';i=@('- [gotcha] [a-c](./a-c.md) — first fact','- [gotcha] [ab](./ab.md) — second fact');e=@{'a-c'=(Entry a-c 'first fact');ab=(Entry ab 'second fact')};x=0})
foreach($c in $cases){It $c.n {$r=Fixture $c.i $c.e;try{Check $r $c.x $c.n}finally{Remove-Item -Recurse -Force $r}}}
It 'hostile formatting passes and twins agree' {$r=Fixture @('- [context] [colon-value](./colon-value.md) — Endpoint: colon preserved') @{};try{$t=(Entry colon-value 'Endpoint: colon preserved' context)-replace"`n","`r`n";Put (Join-Path $r 'docs/wiki/colon-value.md') $t $true;Check $r 0 'hostile formatting'}finally{Remove-Item -Recurse -Force $r}}
if(-not $bash){Skip 'wiki-check.sh parity' 'no bash found'}
exit (Write-TestSummary 'WikiCheck.Tests')
