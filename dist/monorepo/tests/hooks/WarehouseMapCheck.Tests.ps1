if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$scripts=(Resolve-Path (Join-Path $PSScriptRoot '..\..\scripts')).Path
$ps=Join-Path $scripts 'warehouse-map-check.ps1';$sh=Join-Path $scripts 'warehouse-map-check.sh';$bash=Get-BashPath
function Put($p,$t){$d=Split-Path -Parent $p;if($d){New-Item -ItemType Directory -Force $d|Out-Null};[IO.File]::WriteAllText($p,$t,[Text.UTF8Encoding]::new($false))}
function Fixture([bool]$Warehouse=$true){$r=Join-Path ([IO.Path]::GetTempPath()) ('warehouse-map-'+[guid]::NewGuid());New-Item -ItemType Directory -Force $r|Out-Null;if($Warehouse){Put (Join-Path $r 'warehouse/DimCustomer.sql') 'CREATE TABLE dw.DimCustomer (CustomerKey int, EffectiveFrom date, IsCurrent bit);';Put (Join-Path $r 'warehouse/usp_LoadCustomer.sql') 'CREATE PROC etl.usp_LoadCustomer @BatchId int AS SELECT 1;'};$r}
function Check($r,$exit,$text){$p=RunArg $ps $r;Assert ($p.Exit-eq$exit) "ps exit $($p.Exit): $($p.Out)";Assert ($p.Out-match$text) "ps missing $text`: $($p.Out)";if($bash){$s=RunArg $sh $r;Assert ($s.Exit-eq$exit) "sh exit $($s.Exit): $($s.Out)";Assert ($s.Out-match$text) "sh missing $text`: $($s.Out)"}}
Reset-Tests
It 'non-warehouse is not applicable' {$r=Fixture $false;try{Check $r 0 'not-applicable'}finally{Remove-Item -Recurse -Force $r}}
It 'warehouse without map fails' {$r=Fixture;try{Check $r 1 'missing'}finally{Remove-Item -Recurse -Force $r}}
It 'declined map is explicit and non-failing' {$r=Fixture;try{Put (Join-Path $r LEARNINGS.md) "## Declined artifact: warehouse-map`n`nReason: maintained elsewhere.`n";Check $r 0 'declined'}finally{Remove-Item -Recurse -Force $r}}
It 'current and stale maps are distinguished without unrelated JSON false positives' {$r=Fixture;try{Start-Sleep -Milliseconds 1100;Put (Join-Path $r 'docs/warehouse-map.md') '# map';Check $r 0 'current';Start-Sleep -Milliseconds 1100;Put (Join-Path $r 'package.json') '{"version":"2"}';Check $r 0 'current';Put (Join-Path $r 'warehouse/FactSale.sql') 'CREATE TABLE dw.FactSale (BatchId int);';Check $r 1 'stale'}finally{Remove-Item -Recurse -Force $r}}
if(-not $bash){Skip 'warehouse-map-check.sh parity' 'no bash found'}
exit (Write-TestSummary 'WarehouseMapCheck.Tests')
