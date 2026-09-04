# session-start framework-rules migration discovery matrix.
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks=(Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$sessionStart=Join-Path $hooks 'session-start.ps1'
$pointer='Framework rules migration:'
function Root([bool]$Claude=$true,[bool]$Carrier=$true,[bool]$Import=$false){
    $r=Join-Path([IO.Path]::GetTempPath())('session-rules-'+[guid]::NewGuid());New-Item -ItemType Directory -Force $r|Out-Null
    if($Claude){$text="# Fixture`n";if($Import){$text+="@.github/instructions/framework-rules.instructions.md`n"};[IO.File]::WriteAllText((Join-Path $r 'CLAUDE.md'),$text,[Text.UTF8Encoding]::new($false))}
    if($Carrier){New-Item -ItemType Directory -Force (Join-Path $r '.github/instructions')|Out-Null;[IO.File]::WriteAllText((Join-Path $r '.github/instructions/framework-rules.instructions.md'),'# Verification Rules',[Text.UTF8Encoding]::new($false))}
    $r
}
function RunAt($root,$json){Push-Location $root;try{Invoke-Hook $sessionStart $json}finally{Pop-Location}}
$claude='{"hook_event_name":"SessionStart"}';$copilot='{"timestamp":1}';Reset-Tests
It 'import absent emits migration pointer' {$r=Root $true $true $false;try{$o=RunAt $r $claude;Assert($o.Exit-eq0)"hook failed: $($o.Err)";Assert($o.Out-match[regex]::Escape($pointer))"pointer absent: $($o.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'import present is silent' {$r=Root $true $true $true;try{$o=RunAt $r $claude;Assert($o.Out-notmatch[regex]::Escape($pointer))"unexpected pointer: $($o.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'CLAUDE.md absent is silent' {$r=Root $false $true $false;try{$o=RunAt $r $claude;Assert($o.Out-notmatch[regex]::Escape($pointer))"unexpected pointer: $($o.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'carrier absent is silent' {$r=Root $true $false $false;try{$o=RunAt $r $claude;Assert($o.Out-notmatch[regex]::Escape($pointer))"unexpected pointer: $($o.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'Copilot JSON carries the pointer in both shapes' {$r=Root $true $true $false;try{$o=RunAt $r $copilot|Select-Object -ExpandProperty Out|ConvertFrom-Json;Assert($o.additionalContext-match[regex]::Escape($pointer))'top-level missing';Assert($o.hookSpecificOutput.additionalContext-match[regex]::Escape($pointer))'wrapped missing'}finally{Remove-Item -Recurse -Force $r}}
exit(Write-TestSummary 'SessionStartFrameworkRules.Tests')
