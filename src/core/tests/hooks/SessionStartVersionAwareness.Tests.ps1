if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks=(Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path;$ps=Join-Path $hooks 'session-start.ps1';$sh=Join-Path $hooks 'session-start.sh';$bash=Get-BashPath
function Put($p,$s){$d=Split-Path $p -Parent;if($d){New-Item -ItemType Directory -Force $d|Out-Null};[IO.File]::WriteAllText($p,$s,[Text.UTF8Encoding]::new($false))}
function Root{$r=Join-Path([IO.Path]::GetTempPath())('session-version-'+[guid]::NewGuid());New-Item -ItemType Directory -Force (Join-Path $r '.claude')|Out-Null;Put (Join-Path $r '.claude/framework-version.json') '{"template":"dotnet","version":"0.56.0"}';$r}
function RunAt($hook,$root){Push-Location $root;try{Invoke-Hook $hook '{"hook_event_name":"SessionStart"}'}finally{Pop-Location}}
$line='- **Framework version:** v0.56.0 installed; check for updates: https://github.com/andreoucostas/ai-tech-lead/releases'
$stamp='.claude/.state/last-version-awareness';Reset-Tests
foreach($h in @($ps)+$(if($bash){@($sh)}else{@()})){
  $name=Split-Path $h -Leaf
  It "version awareness fires when no throttle exists: $name" {$r=Root;try{$o=RunAt $h $r;Assert($o.Exit-eq0)'hook crashed';Assert($o.Out.Contains($line))"nudge missing: $($o.Out)";Assert(Test-Path (Join-Path $r $stamp))'throttle record missing'}finally{Remove-Item -Recurse -Force $r}}
  It "version awareness is throttled within seven days: $name" {$r=Root;try{Put (Join-Path $r $stamp) ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString());$o=RunAt $h $r;Assert($o.Exit-eq0)'hook crashed';Assert(-not$o.Out.Contains($line))'nudge was not throttled'}finally{Remove-Item -Recurse -Force $r}}
  It "version awareness fires after seven days: $name" {$r=Root;try{Put (Join-Path $r $stamp) (([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-8*86400).ToString());$o=RunAt $h $r;Assert($o.Exit-eq0)'hook crashed';Assert($o.Out.Contains($line))'nudge missing after window'}finally{Remove-Item -Recurse -Force $r}}
  It "unwritable state does not break the session: $name" {$r=Root;try{Put (Join-Path $r '.claude/.state') 'file blocks directory creation';$o=RunAt $h $r;Assert($o.Exit-eq0)"hook crashed: $($o.Err)";Assert(-not$o.Out.Contains($line))'unpersisted nudge would repeat every session'}finally{Remove-Item -Recurse -Force $r}}
}
if($bash){It 'version-awareness twins emit identical text and state' {$r1=Root;$r2=Root;try{$p=RunAt $ps $r1;$s=RunAt $sh $r2;Assert($p.Exit-eq$s.Exit)'exit drift';Assert($p.Out-eq$s.Out)"output drift`nPS: $($p.Out)`nSH: $($s.Out)";Assert(([IO.File]::ReadAllText((Join-Path $r1 $stamp)) -match '^\d+$'))'PowerShell stamp invalid';Assert(([IO.File]::ReadAllText((Join-Path $r2 $stamp)) -match '^\d+$'))'bash stamp invalid'}finally{Remove-Item -Recurse -Force $r1,$r2}}}else{Skip 'version-awareness twin agreement' 'no bash found'}
exit(Write-TestSummary 'SessionStartVersionAwareness.Tests')
