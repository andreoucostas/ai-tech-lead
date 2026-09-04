if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks=(Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path;$sessionStart=Join-Path $hooks 'session-start.ps1'
function RunAt($root,$json){Push-Location $root;try{Invoke-Hook $sessionStart $json}finally{Pop-Location}}
function Root($status,$reviewed,[switch]$Pending,[switch]$Placeholder,[ValidateSet('LF','CRLF')][string]$Eol='LF',[string]$HeadingSuffix='',[switch]$FinalRow,[switch]$Malformed){
    $r=Join-Path([IO.Path]::GetTempPath())('session-hazard-'+[guid]::NewGuid());New-Item -ItemType Directory -Force $r|Out-Null
    $marker=$(if($Pending){'<!-- KNOWN_HAZARD_AREAS_PENDING -->'}else{''})
    $data=$(if($Placeholder){'| _(drafted by /bootstrap)_ | _ | _ | _ |'}elseif($Malformed){"| Payments.cs | concurrent debit risk | $status | $reviewed"}else{"| Payments.cs | concurrent debit risk | $status | $reviewed |"})
    $eolText=$(if($Eol-eq'CRLF'){"`r`n"}else{"`n"});$lines=@('# Framework Context',$marker,"## Known Hazard Areas$HeadingSuffix",'','| Area / file(s) | Hazard | Status | Reviewed |','|---|---|---|---|',$data)
    if(-not$FinalRow){$lines+=@('','---','')};[IO.File]::WriteAllText((Join-Path $r 'FRAMEWORK-CONTEXT.md'),($lines-join$eolText),[Text.UTF8Encoding]::new($false));$r
}
$claude='{"hook_event_name":"SessionStart"}';$copilot='{"timestamp":1}';$old=(Get-Date).AddDays(-200).ToString('yyyy-MM-dd');$today=(Get-Date).ToString('yyyy-MM-dd');Reset-Tests
It 'old unverified resurfaces' {$r=Root '[UNVERIFIED]' $old;try{$o=RunAt $r $claude;Assert($o.Exit-eq0)'hook crashed';Assert($o.Out-match'waited over 90 days')'hazard line absent'}finally{Remove-Item -Recurse -Force $r}}
It 'fresh review is silent' {$r=Root '[UNVERIFIED]' $today;try{$o=RunAt $r $claude;Assert($o.Out-notmatch'\*\*Hazard areas:\*\*')'hazard line present'}finally{Remove-Item -Recurse -Force $r}}
It 'unparseable review is skipped' {$r=Root '[UNVERIFIED]' 'not-a-date';try{$o=RunAt $r $claude;Assert($o.Exit-eq0)'hook crashed';Assert($o.Out-notmatch'\*\*Hazard areas:\*\*')'hazard line present'}finally{Remove-Item -Recurse -Force $r}}
It 'not-a-hazard review is excluded' {$r=Root "[REVIEWED: not a hazard — $old]" $old;try{$o=RunAt $r $claude;Assert($o.Out-notmatch'\*\*Hazard areas:\*\*')'hazard line present'}finally{Remove-Item -Recurse -Force $r}}
It 'placeholder is skipped' {$r=Root '_' '_' -Placeholder;try{$o=RunAt $r $claude;Assert($o.Out-notmatch'\*\*Hazard areas:\*\*')'hazard line present'}finally{Remove-Item -Recurse -Force $r}}
It 'pending marker suppresses output' {$r=Root '[UNVERIFIED]' $old -Pending;try{$o=RunAt $r $claude;Assert($o.Out-notmatch'\*\*Hazard areas:\*\*')'hazard line present'}finally{Remove-Item -Recurse -Force $r}}
It 'old suspected resurfaces' {$r=Root '[SUSPECTED]' $old;try{$o=RunAt $r $claude;Assert($o.Out-match'waited over 90 days')'hazard line absent'}finally{Remove-Item -Recurse -Force $r}}
It 'old verified gets a lighter confirmed-stale nudge' {$r=Root '[VERIFIED]' $old;try{$o=RunAt $r $claude;Assert($o.Out-match'confirmed hazard area')'confirmed nudge absent';Assert($o.Out-notmatch'waited over 90 days')'confirmed row used open-question wording'}finally{Remove-Item -Recurse -Force $r}}
It 'hostile stale-row readers retain exact semantics without false advisories' {
    $expected='- ⚠ **Hazard areas:** 1 hazard area(s) have waited over 90 days for a human answer — confirm each, or mark it ''not a hazard'', in FRAMEWORK-CONTEXT.md > Known Hazard Areas.'
    $worlds=@(
        @{Name='EOF stale';Make={Root '[UNVERIFIED]' $old -FinalRow};Expect=$expected;Bytes='EOF'},
        @{Name='CRLF stale';Make={Root '[UNVERIFIED]' $old -Eol CRLF};Expect=$expected;Bytes='CRLF'},
        @{Name='horizontal-heading stale';Make={Root '[UNVERIFIED]' $old -HeadingSuffix "`t  "};Expect=$expected;Bytes='HWS'},
        @{Name='malformed EOF stale';Make={Root '[UNVERIFIED]' $old -FinalRow -Malformed};Expect=$null;Bytes='MalformedEOF'}
    );Assert($worlds.Count-gt0)'hostile world table is empty';$problems=[Collections.Generic.List[string]]::new()
    foreach($world in $worlds){$r=&$world.Make;try{$path=Join-Path $r 'FRAMEWORK-CONTEXT.md';$bytes=[IO.File]::ReadAllBytes($path);$text=[Text.Encoding]::UTF8.GetString($bytes);$result=RunAt $r $claude
        switch($world.Bytes){'EOF'{if($bytes.Length-eq0-or$bytes[-1]-ne124){$problems.Add("$($world.Name): fixture did not end at byte 0x7C")}}'CRLF'{if(-not$text.Contains("## Known Hazard Areas`r`n")){$problems.Add("$($world.Name): fixture lacks CRLF heading")}}'HWS'{if(-not$text.Contains("## Known Hazard Areas`t  `n")){$problems.Add("$($world.Name): fixture lacks heading suffix")}}'MalformedEOF'{if(-not$text.EndsWith($old)-or$bytes[-1]-in10,13,124){$problems.Add("$($world.Name): malformed fixture shape drifted")}}}
        if($result.Exit-ne0-or"$($result.Err)".Trim()-ne''){$problems.Add("$($world.Name): exit=$($result.Exit) stderr=$($result.Err)")};$lines=@(($result.Out-split"`n")|Where-Object{$_-match'\*\*Hazard areas:\*\*'});$count=$(if($world.Expect){1}else{0});if($lines.Count-ne$count){$problems.Add("$($world.Name): advisory count expected=$count actual=$($lines.Count)")};if($world.Expect-and$lines.Count-eq1-and$lines[0]-ne$world.Expect){$problems.Add("$($world.Name): advisory text drift")}
    }finally{Remove-Item -Recurse -Force $r}};Assert($problems.Count-eq0)($problems-join"`n")
}
It 'Copilot JSON contains hazard in both additionalContext shapes' {$r=Root '[UNVERIFIED]' $old;try{$o=RunAt $r $copilot|Select-Object -ExpandProperty Out|ConvertFrom-Json;Assert($o.additionalContext-match'waited over 90 days')'top-level missing';Assert($o.hookSpecificOutput.additionalContext-match'waited over 90 days')'wrapped missing'}finally{Remove-Item -Recurse -Force $r}}
exit(Write-TestSummary 'SessionStartHazard.Tests')
