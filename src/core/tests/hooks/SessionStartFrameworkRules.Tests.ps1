# session-start framework-rules migration discovery: state matrix and surface parity.
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks=(Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$ps=Join-Path $hooks 'session-start.ps1';$sh=Join-Path $hooks 'session-start.sh';$bash=Get-BashPath
$pointer='Framework rules migration:'
function Root([bool]$Claude=$true,[bool]$Carrier=$true,[bool]$Import=$false){
    $r=Join-Path([IO.Path]::GetTempPath())('session-rules-'+[guid]::NewGuid())
    New-Item -ItemType Directory -Force $r|Out-Null
    if($Claude){$text="# Fixture`n";if($Import){$text+="@.github/instructions/framework-rules.instructions.md`n"};[IO.File]::WriteAllText((Join-Path $r 'CLAUDE.md'),$text,[Text.UTF8Encoding]::new($false))}
    if($Carrier){New-Item -ItemType Directory -Force (Join-Path $r '.github/instructions')|Out-Null;[IO.File]::WriteAllText((Join-Path $r '.github/instructions/framework-rules.instructions.md'),'# Verification Rules',[Text.UTF8Encoding]::new($false))}
    $r
}
function RunAt($hook,$root,$json){Push-Location $root;try{Invoke-Hook $hook $json}finally{Pop-Location}}
$claude='{"hook_event_name":"SessionStart"}';$copilot='{"timestamp":1}';Reset-Tests
foreach($h in @($ps)+$(if($bash){@($sh)}else{@()})){
    It "import absent emits migration pointer: $(Split-Path $h -Leaf)" {$r=Root $true $true $false;try{$o=RunAt $h $r $claude;Assert($o.Exit-eq0)"hook failed: $($o.Err)";Assert($o.Out-match[regex]::Escape($pointer))"pointer absent: $($o.Out)"}finally{Remove-Item -Recurse -Force $r}}
    It "import present is silent: $(Split-Path $h -Leaf)" {$r=Root $true $true $true;try{$o=RunAt $h $r $claude;Assert($o.Out-notmatch[regex]::Escape($pointer))"unexpected pointer: $($o.Out)"}finally{Remove-Item -Recurse -Force $r}}
    It "CLAUDE.md absent is silent: $(Split-Path $h -Leaf)" {$r=Root $false $true $false;try{$o=RunAt $h $r $claude;Assert($o.Out-notmatch[regex]::Escape($pointer))"unexpected pointer: $($o.Out)"}finally{Remove-Item -Recurse -Force $r}}
    It "carrier absent is silent: $(Split-Path $h -Leaf)" {$r=Root $true $false $false;try{$o=RunAt $h $r $claude;Assert($o.Out-notmatch[regex]::Escape($pointer))"unexpected pointer: $($o.Out)"}finally{Remove-Item -Recurse -Force $r}}
}
It 'PowerShell Copilot JSON carries the pointer in both shapes' {$r=Root $true $true $false;try{$o=RunAt $ps $r $copilot|Select-Object -ExpandProperty Out|ConvertFrom-Json;Assert($o.additionalContext-match[regex]::Escape($pointer))'top-level missing';Assert($o.hookSpecificOutput.additionalContext-match[regex]::Escape($pointer))'wrapped missing'}finally{Remove-Item -Recurse -Force $r}}
$shJson=$false;if($bash){$probe="$(& $bash -c 'if command -v jq >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1; then echo yes; fi')";$shJson=($probe.Trim()-eq'yes')}
if($bash-and$shJson){It 'bash Copilot JSON carries the pointer in both shapes' {$r=Root $true $true $false;try{$o=RunAt $sh $r $copilot|Select-Object -ExpandProperty Out|ConvertFrom-Json;Assert($o.additionalContext-match[regex]::Escape($pointer))'top-level missing';Assert($o.hookSpecificOutput.additionalContext-match[regex]::Escape($pointer))'wrapped missing'}finally{Remove-Item -Recurse -Force $r}}}elseif($bash){Skip 'session-start.sh Copilot JSON migration case' 'no jq/python3 in bash'}
if(-not$bash){Skip 'session-start.sh framework-rules cases' 'no bash found'}
exit(Write-TestSummary 'SessionStartFrameworkRules.Tests')
