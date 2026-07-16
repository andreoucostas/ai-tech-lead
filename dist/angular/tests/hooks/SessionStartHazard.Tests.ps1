if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks=(Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path;$ps=Join-Path $hooks 'session-start.ps1';$sh=Join-Path $hooks 'session-start.sh';$bash=Get-BashPath
function RunAt($hook,$root,$json){Push-Location $root;try{Invoke-Hook $hook $json}finally{Pop-Location}}
function Root($status,$reviewed,[switch]$Pending,[switch]$Placeholder){
    $r=Join-Path([IO.Path]::GetTempPath())('session-hazard-'+[guid]::NewGuid());New-Item -ItemType Directory -Force $r|Out-Null
    $marker=$(if($Pending){'<!-- KNOWN_HAZARD_AREAS_PENDING -->'}else{''})
    $data=$(if($Placeholder){'| _(drafted by /bootstrap)_ | _ | _ | _ |'}else{"| Payments.cs | concurrent debit risk | $status | $reviewed |"})
    $content="# Framework Context`n$marker`n## Known Hazard Areas`n`n| Area / file(s) | Hazard | Status | Reviewed |`n|---|---|---|---|`n$data`n`n---`n"
    [IO.File]::WriteAllText((Join-Path $r 'FRAMEWORK-CONTEXT.md'),$content,[Text.UTF8Encoding]::new($false));$r
}
$claude='{"hook_event_name":"SessionStart"}';$copilot='{"timestamp":1}';$old=(Get-Date).AddDays(-200).ToString('yyyy-MM-dd');$today=(Get-Date).ToString('yyyy-MM-dd');Reset-Tests
$twins=@($ps)+$(if($bash){@($sh)}else{@()})
foreach($h in $twins){
It "old unverified resurfaces: $(Split-Path $h -Leaf)" {$r=Root '[UNVERIFIED]' $old;try{$o=RunAt $h $r $claude;Assert($o.Exit-eq0)'hook crashed';Assert($o.Out-match'waited over 90 days')'hazard line absent'}finally{Remove-Item -Recurse -Force $r}}
It "fresh review is silent: $(Split-Path $h -Leaf)" {$r=Root '[UNVERIFIED]' $today;try{$o=RunAt $h $r $claude;Assert($o.Out-notmatch'\*\*Hazard areas:\*\*')'hazard line present'}finally{Remove-Item -Recurse -Force $r}}
It "unparseable review is skipped: $(Split-Path $h -Leaf)" {$r=Root '[UNVERIFIED]' 'not-a-date';try{$o=RunAt $h $r $claude;Assert($o.Exit-eq0)'hook crashed';Assert($o.Out-notmatch'\*\*Hazard areas:\*\*')'hazard line present'}finally{Remove-Item -Recurse -Force $r}}
It "not-a-hazard review is excluded: $(Split-Path $h -Leaf)" {$r=Root "[REVIEWED: not a hazard — $old]" $old;try{$o=RunAt $h $r $claude;Assert($o.Out-notmatch'\*\*Hazard areas:\*\*')'hazard line present'}finally{Remove-Item -Recurse -Force $r}}
It "placeholder is skipped: $(Split-Path $h -Leaf)" {$r=Root '_' '_' -Placeholder;try{$o=RunAt $h $r $claude;Assert($o.Out-notmatch'\*\*Hazard areas:\*\*')'hazard line present'}finally{Remove-Item -Recurse -Force $r}}
It "pending marker suppresses output: $(Split-Path $h -Leaf)" {$r=Root '[UNVERIFIED]' $old -Pending;try{$o=RunAt $h $r $claude;Assert($o.Out-notmatch'\*\*Hazard areas:\*\*')'hazard line present'}finally{Remove-Item -Recurse -Force $r}}
It "old suspected resurfaces: $(Split-Path $h -Leaf)" {$r=Root '[SUSPECTED]' $old;try{$o=RunAt $h $r $claude;Assert($o.Out-match'waited over 90 days')'hazard line absent'}finally{Remove-Item -Recurse -Force $r}}
It "old verified gets lighter confirmed-stale nudge: $(Split-Path $h -Leaf)" {$r=Root '[VERIFIED]' $old;try{$o=RunAt $h $r $claude;Assert($o.Out-match'confirmed hazard area')'confirmed nudge absent';Assert($o.Out-notmatch'waited over 90 days')'confirmed row used open-question wording'}finally{Remove-Item -Recurse -Force $r}}
}
if($bash){
It 'twins agree on stale and fresh verdicts' {foreach($date in @($old,$today)){$r=Root '[UNVERIFIED]' $date;try{$p=RunAt $ps $r $claude;$s=RunAt $sh $r $claude;Assert(($p.Out-match'\*\*Hazard areas:\*\*')-eq($s.Out-match'\*\*Hazard areas:\*\*'))"twin verdict differed for $date"}finally{Remove-Item -Recurse -Force $r}}}
}else{Skip 'session-start twin agreement' 'no bash found'}
It 'Copilot JSON contains hazard in both additionalContext shapes' {$r=Root '[UNVERIFIED]' $old;try{$o=RunAt $ps $r $copilot|Select-Object -ExpandProperty Out|ConvertFrom-Json;Assert($o.additionalContext-match'waited over 90 days')'top-level missing';Assert($o.hookSpecificOutput.additionalContext-match'waited over 90 days')'wrapped missing'}finally{Remove-Item -Recurse -Force $r}}
$shJson=$false;if($bash){$p="$(& $bash -c 'if command -v jq >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then echo yes; fi')";$shJson=($p.Trim()-eq'yes')}
if($bash -and $shJson){It 'Copilot JSON (sh twin) contains hazard in both additionalContext shapes' {$r=Root '[UNVERIFIED]' $old;try{$o=RunAt $sh $r $copilot|Select-Object -ExpandProperty Out|ConvertFrom-Json;Assert($o.additionalContext-match'waited over 90 days')'top-level missing';Assert($o.hookSpecificOutput.additionalContext-match'waited over 90 days')'wrapped missing'}finally{Remove-Item -Recurse -Force $r}}}elseif($bash){Skip 'session-start.sh Copilot JSON hazard case' 'no jq/python3 in bash'}
if(-not$bash){Skip 'session-start.sh hazard cases' 'no bash found'};exit(Write-TestSummary 'SessionStartHazard.Tests')
