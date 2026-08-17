# hazard-check behavioral and twin-parity tests.
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$scripts=(Resolve-Path(Join-Path $PSScriptRoot '..\..\scripts')).Path;$hazardPs=Join-Path $scripts 'hazard-check.ps1';$hazardSh=Join-Path $scripts 'hazard-check.sh';$bash=Get-BashPath
if($bash){& $bash -c ':' 2>$null|Out-Null;if($LASTEXITCODE-ne0){$bash=$null}}
function Put($Path,$Text,[bool]$Bom=$false){[IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($Bom))}
function Fixture($Rows=@(),[switch]$Pending,[switch]$NoSection,[switch]$Missing,[switch]$Hostile){$r=Join-Path([IO.Path]::GetTempPath())('hazard-'+[guid]::NewGuid());New-Item -ItemType Directory -Force $r|Out-Null;if(-not$Missing){$body=if($NoSection){"# Context`nNothing here.`n"}else{"# Context`n$(if($Pending){'KNOWN_HAZARD_AREAS_PENDING'})`n## Known Hazard Areas`n| Area / file(s) | Hazard | Status | Reviewed |`n|---|---|---|---|`n$($Rows-join"`n")`n## Next`n"};if($Hostile){$body=$body-replace"`n","`r`n"};Put(Join-Path $r 'FRAMEWORK-CONTEXT.md')$body ([bool]$Hostile)};$r}
function Row($Area,$Status='[VERIFIED]',$Reviewed='2026-01-01'){"| $Area | risk | $Status | $Reviewed |"}
function Make($Root,$Path,[switch]$Directory){$p=Join-Path $Root $Path;if($Directory){New-Item -ItemType Directory -Force $p|Out-Null}else{New-Item -ItemType Directory -Force (Split-Path $p -Parent)|Out-Null;Put $p 'x'}}
function Check($Root,$Expected,$Label,$Text=''){$p=RunArg $hazardPs $Root;Assert($p.Exit-eq$Expected)"$Label ps1 exit $($p.Exit): $($p.Out) $($p.Err)";if($Text){Assert($p.Out-match[regex]::Escape($Text))"$Label ps1 missing text: $Text -- $($p.Out)"};if($bash){$s=RunArg $hazardSh $Root;Assert($s.Exit-eq$Expected)"$Label sh exit $($s.Exit): $($s.Out) $($s.Err)";if($Text){Assert($s.Out-match[regex]::Escape($Text))"$Label sh missing text: $Text -- $($s.Out)"};Assert($p.Exit-eq$s.Exit)"$Label twins disagree"}}
Reset-Tests
It 'missing path fails and names it'{$r=Fixture @(Row 'src/Payments.cs');try{Check $r 1 'missing path' 'src/Payments.cs'}finally{Remove-Item -Recurse -Force $r}}
It 'existing path passes'{$r=Fixture @(Row 'src/Payments.cs');try{Make $r 'src/Payments.cs';Check $r 0 'existing path'}finally{Remove-Item -Recurse -Force $r}}
$passes=@(@{n='pure prose';a='the payment reconciliation flow'},@{n='symbol';a='`TenantContext`'},@{n='URL';a='https://wiki.example.com/hazards'})
foreach($c in $passes){It "$($c.n) is ignored"{$r=Fixture @(Row $c.a);try{Check $r 0 $c.n}finally{Remove-Item -Recurse -Force $r}}}
It 'existing extensionless directory passes'{$r=Fixture @(Row 'src/app');try{Make $r 'src/app' -Directory;Check $r 0 'directory'}finally{Remove-Item -Recurse -Force $r}}
It 'prose containing existing path passes'{$r=Fixture @(Row 'concurrency in `src/Payments.cs` and its callers');try{Make $r 'src/Payments.cs';Check $r 0 'prose path'}finally{Remove-Item -Recurse -Force $r}}
It 'second missing candidate fails'{$r=Fixture @(Row '`src/Payments.cs`, `src/Missing.cs`');try{Make $r 'src/Payments.cs';Check $r 1 'multiple candidates' 'src/Missing.cs'}finally{Remove-Item -Recurse -Force $r}}
# /bootstrap drafts the Area cell freely, so a row naming only a filename is ordinary input. It must
# resolve tree-wide, or this blocking gate would fail a consumer's CI on a perfectly normal row.
It 'bare filename resolves anywhere in the tree'{$r=Fixture @(Row 'PaymentService.cs');try{Make $r 'src/Domain/PaymentService.cs';Check $r 0 'bare filename'}finally{Remove-Item -Recurse -Force $r}}
It 'bare filename that exists nowhere fails'{$r=Fixture @(Row 'PaymentService.cs');try{Make $r 'src/Domain/Other.cs';Check $r 1 'bare filename missing' 'PaymentService.cs'}finally{Remove-Item -Recurse -Force $r}}
It 'wildcard existing prefix passes'{$r=Fixture @(Row 'src/app/**/*.component.ts');try{Make $r 'src/app' -Directory;Check $r 0 'wildcard prefix'}finally{Remove-Item -Recurse -Force $r}}
It 'wildcard missing prefix fails'{$r=Fixture @(Row 'src/gone/**/*.ts');try{Check $r 1 'wildcard missing' 'src/gone'}finally{Remove-Item -Recurse -Force $r}}
# A wildcard INSIDE a segment truncates to the segment before it, so only 'src' is asserted to exist.
# The bash twin originally word-split the unquoted candidate here, which made the shell pathname-expand
# the glob against the cwd; the prefix became the cwd's file list joined by '/'. Both twins are checked.
It 'wildcard inside a segment truncates to the previous segment'{$r=Fixture @(Row 'src/ap*p/x');try{Make $r 'src' -Directory;Check $r 0 'partial segment wildcard'}finally{Remove-Item -Recurse -Force $r}}
It 'wildcard with no leading directory is discarded'{$r=Fixture @(Row '*.ts');try{Check $r 0 'bare wildcard'}finally{Remove-Item -Recurse -Force $r}}
# A row whose cells are ALL empty is malformed content, not a table separator. The bash twin used to
# classify it as a separator and skip it while the .ps1 twin reported it -- a silent twin divergence
# that a green bash run could not show, because agreeing to do nothing looks identical to agreeing.
It 'all-empty row is reported, not treated as a separator'{$r=Fixture @('|  |  |  |  |');try{Check $r 1 'all-empty row' "unrecognised Status ''"}finally{Remove-Item -Recurse -Force $r}}
It 'unrecognised status fails for status reason'{$r=Fixture @(Row 'plain prose' '[PROBABLY]');try{Check $r 1 'bad status' "unrecognised Status '[PROBABLY]'"}finally{Remove-Item -Recurse -Force $r}}
It 'reviewed-not-hazard status passes'{$r=Fixture @(Row 'src/Payments.cs' '[REVIEWED: not a hazard — 2026-01-01]');try{Make $r 'src/Payments.cs';Check $r 0 'reviewed status'}finally{Remove-Item -Recurse -Force $r}}
It 'non-date fails for date reason'{$r=Fixture @(Row 'plain prose' '[VERIFIED]' 'not-a-date');try{Check $r 1 'non-date' "invalid Reviewed date 'not-a-date'"}finally{Remove-Item -Recurse -Force $r}}
It 'non-calendar date fails for date reason'{$r=Fixture @(Row 'plain prose' '[VERIFIED]' '2026-02-30');try{Check $r 1 'calendar date' "invalid Reviewed date '2026-02-30'"}finally{Remove-Item -Recurse -Force $r}}
It 'three-cell row fails for cell reason'{$r=Fixture @('| src/Payments.cs | risk | [VERIFIED] |');try{Check $r 1 'cell count' 'does not have 4 cells'}finally{Remove-Item -Recurse -Force $r}}
It 'placeholder row passes'{$r=Fixture @('| _(drafted by /bootstrap)_ | _ | _ | _ |');try{Check $r 0 'placeholder'}finally{Remove-Item -Recurse -Force $r}}
It 'missing context skips'{$r=Fixture -Missing;try{Check $r 0 'missing context' 'skipped (no FRAMEWORK-CONTEXT.md)'}finally{Remove-Item -Recurse -Force $r}}
It 'pending table skips'{$r=Fixture -Pending;try{Check $r 0 'pending' 'skipped (hazard table not yet drafted)'}finally{Remove-Item -Recurse -Force $r}}
It 'missing section skips'{$r=Fixture -NoSection;try{Check $r 0 'missing section' 'skipped (no Known Hazard Areas section)'}finally{Remove-Item -Recurse -Force $r}}
# On Git Bash MSYS opens files in text mode, so CR never reaches sed/grep/awk; this can only catch
# CR stripping regressions on the CI Linux leg, not on Windows.
It 'BOM and CRLF table passes'{$r=Fixture @(Row 'src/Payments.cs') -Hostile;try{Make $r 'src/Payments.cs';Check $r 0 'hostile formatting'}finally{Remove-Item -Recurse -Force $r}}
It 'failing run is read-only for both twins'{$r=Fixture @(Row 'src/Missing.cs');try{$file=Join-Path $r 'FRAMEWORK-CONTEXT.md';$before=(Get-FileHash $file -Algorithm SHA256).Hash;$p=RunArg $hazardPs $r;Assert($p.Exit-eq1)'ps1 did not fail';Assert((Get-FileHash $file -Algorithm SHA256).Hash-eq$before)'ps1 changed input';if($bash){$s=RunArg $hazardSh $r;Assert($s.Exit-eq1)'sh did not fail';Assert((Get-FileHash $file -Algorithm SHA256).Hash-eq$before)'sh changed input'}}finally{Remove-Item -Recurse -Force $r}}
It 'two bad rows count both failures'{$r=Fixture @((Row 'plain prose' '[PROBABLY]'),(Row 'plain prose' '[VERIFIED]' 'not-a-date'));try{Check $r 1 'failure count' '2 hazard-check failure(s).'}finally{Remove-Item -Recurse -Force $r}}
if(-not$bash){Skip 'hazard-check.sh parity' 'no bash found'}
exit(Write-TestSummary 'HazardCheck.Tests')
