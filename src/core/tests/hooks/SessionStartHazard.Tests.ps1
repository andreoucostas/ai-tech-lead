if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks=(Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path;$ps=Join-Path $hooks 'session-start.ps1';$sh=Join-Path $hooks 'session-start.sh';$bash=Get-BashPath
function RunAt($hook,$root,$json){Push-Location $root;try{Invoke-Hook $hook $json}finally{Pop-Location}}
function Root($status,$reviewed,[switch]$Pending,[switch]$Placeholder,[ValidateSet('LF','CRLF')][string]$Eol='LF',[string]$HeadingSuffix='',[switch]$FinalRow,[switch]$Malformed){
    $r=Join-Path([IO.Path]::GetTempPath())('session-hazard-'+[guid]::NewGuid());New-Item -ItemType Directory -Force $r|Out-Null
    $marker=$(if($Pending){'<!-- KNOWN_HAZARD_AREAS_PENDING -->'}else{''})
    $data=$(if($Placeholder){'| _(drafted by /bootstrap)_ | _ | _ | _ |'}elseif($Malformed){"| Payments.cs | concurrent debit risk | $status | $reviewed"}else{"| Payments.cs | concurrent debit risk | $status | $reviewed |"})
    $eolText=$(if($Eol-eq'CRLF'){"`r`n"}else{"`n"})
    $lines=@('# Framework Context',$marker,"## Known Hazard Areas$HeadingSuffix",'','| Area / file(s) | Hazard | Status | Reviewed |','|---|---|---|---|',$data)
    if(-not$FinalRow){$lines+=@('','---','')}
    $content=$lines-join$eolText
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
It 'twins agree on hostile stale-row readers without false advisories' {
    $expected='- ⚠ **Hazard areas:** 1 hazard area(s) have waited over 90 days for a human answer — confirm each, or mark it ''not a hazard'', in FRAMEWORK-CONTEXT.md > Known Hazard Areas.'
    $worlds=@(
        @{Name='EOF stale';Make={Root '[UNVERIFIED]' $old -FinalRow};Expect=$expected;Bytes='EOF'},
        @{Name='CRLF stale';Make={Root '[UNVERIFIED]' $old -Eol CRLF};Expect=$expected;Bytes='CRLF'},
        @{Name='horizontal-heading stale';Make={Root '[UNVERIFIED]' $old -HeadingSuffix "`t  "};Expect=$expected;Bytes='HWS'},
        @{Name='malformed EOF stale';Make={Root '[UNVERIFIED]' $old -FinalRow -Malformed};Expect=$null;Bytes='MalformedEOF'}
    )
    $problems=[Collections.Generic.List[string]]::new()
    foreach($world in $worlds){
        $r=&$world.Make
        try{
            $path=Join-Path $r 'FRAMEWORK-CONTEXT.md';$bytes=[IO.File]::ReadAllBytes($path);$text=[Text.Encoding]::UTF8.GetString($bytes)
            $p=RunAt $ps $r $claude;$s=RunAt $sh $r $claude
            switch($world.Bytes){
                'EOF'{if($bytes.Length-eq0-or$bytes[-1]-ne124){$problems.Add("$($world.Name): fixture did not end at byte 0x7C")}}
                'CRLF'{if(-not$text.Contains("## Known Hazard Areas`r`n")){$problems.Add("$($world.Name): fixture lacks CRLF heading")}}
                'HWS'{if(-not$text.Contains("## Known Hazard Areas`t  `n")){$problems.Add("$($world.Name): fixture lacks exact HT+spaces heading suffix")}}
                'MalformedEOF'{if(-not$text.EndsWith($old)-or$bytes[-1]-in10,13,124){$problems.Add("$($world.Name): fixture is not an unterminated row without its closing pipe")}}
            }
            if($p.Exit-ne0-or$s.Exit-ne0){$problems.Add("$($world.Name): nonzero exit ps1=$($p.Exit) sh=$($s.Exit)")}
            if("$($p.Err)".Trim()-ne''-or"$($s.Err)".Trim()-ne''){$problems.Add("$($world.Name): stderr ps1='$(("$($p.Err)").Trim())' sh='$(("$($s.Err)").Trim())'")}
            $pLines=@(($p.Out-split"`n")|Where-Object{$_-match'\*\*Hazard areas:\*\*'});$sLines=@(($s.Out-split"`n")|Where-Object{$_-match'\*\*Hazard areas:\*\*'})
            $count=$(if($world.Expect){1}else{0})
            if($pLines.Count-ne$count-or$sLines.Count-ne$count){$problems.Add("$($world.Name): advisory count expected=$count ps1=$($pLines.Count) sh=$($sLines.Count)")}
            if($world.Expect){if($pLines.Count-eq1-and$pLines[0]-ne$world.Expect){$problems.Add("$($world.Name): PowerShell advisory text drift")};if($sLines.Count-eq1-and$sLines[0]-ne$world.Expect){$problems.Add("$($world.Name): Bash advisory text drift")}}
        }finally{Remove-Item -Recurse -Force $r}
    }
    Assert($problems.Count-eq0)($problems-join"`n")
}
}else{Skip 'session-start twin agreement' 'no bash found'}
It 'Copilot JSON contains hazard in both additionalContext shapes' {$r=Root '[UNVERIFIED]' $old;try{$o=RunAt $ps $r $copilot|Select-Object -ExpandProperty Out|ConvertFrom-Json;Assert($o.additionalContext-match'waited over 90 days')'top-level missing';Assert($o.hookSpecificOutput.additionalContext-match'waited over 90 days')'wrapped missing'}finally{Remove-Item -Recurse -Force $r}}
# Probe by EXECUTION across jq / python3 / python / py -- same reach as session-start.sh's own
# resolver (a python.org install has no python3.exe; a name-only python3 probe would falsely skip
# this case on exactly the host the resolver targets).
$probeCmd='if command -v jq >/dev/null 2>&1; then echo yes; else for c in python3 python py; do if command -v "$c" >/dev/null 2>&1 && printf "{}" | "$c" -c "import json,sys;json.load(sys.stdin)" >/dev/null 2>&1; then echo yes; break; fi; done; fi'
$shJson=$false;if($bash){$p="$(& $bash -c $probeCmd)";$shJson=($p.Trim()-eq'yes')}
if($bash -and $shJson){It 'Copilot JSON (sh twin) contains hazard in both additionalContext shapes' {$r=Root '[UNVERIFIED]' $old;try{$o=RunAt $sh $r $copilot|Select-Object -ExpandProperty Out|ConvertFrom-Json;Assert($o.additionalContext-match'waited over 90 days')'top-level missing';Assert($o.hookSpecificOutput.additionalContext-match'waited over 90 days')'wrapped missing'}finally{Remove-Item -Recurse -Force $r}}}elseif($bash){Skip 'session-start.sh Copilot JSON hazard case' 'no jq and no working python3/python/py in bash -- this host cannot exercise the JSON-encode branch at all' -Invariant}
if(-not$bash){Skip 'session-start.sh hazard cases' 'no bash found'};exit(Write-TestSummary 'SessionStartHazard.Tests')
