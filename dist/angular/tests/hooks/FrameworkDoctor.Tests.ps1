# framework-doctor fixture tests: truthful states, survival paths, and twin agreement.
if (-not (Get-Command Assert -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$scripts = (Resolve-Path (Join-Path $PSScriptRoot '..\..\scripts')).Path
$doctorPs = Join-Path $scripts 'framework-doctor.ps1'
$doctorSh = Join-Path $scripts 'framework-doctor.sh'
$bash = Get-BashPath
if($bash){$null=& $bash --version 2>$null;if($LASTEXITCODE-ne 0){$bash=$null}}
function Put($Path, $Text, [bool]$Bom=$false) { [IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($Bom)) }
# Default wired shell must be one that exists on the TEST host (CI linux has pwsh, not powershell)
# - otherwise the doctor correctly reports it missing and the "healthy" fixtures exit 1.
$defaultShell = if (Get-Command powershell.exe -ErrorAction SilentlyContinue) {'powershell'}
    elseif (Get-Command pwsh -ErrorAction SilentlyContinue) {'pwsh'} else {'bash'}
function Fixture([string]$Shell=$script:defaultShell,[bool]$Pending=$false,[bool]$MissingHook=$false) {
    $r=Join-Path ([IO.Path]::GetTempPath()) ('doctor-'+[guid]::NewGuid())
    New-Item -ItemType Directory -Force (Join-Path $r '.claude/hooks'),(Join-Path $r '.github/hooks'),(Join-Path $r 'scripts')|Out-Null
    Put (Join-Path $r '.claude/framework-version.json') '{"template":"fixture","version":"0.32.0","applied":"2026-07-17"}'
    Put (Join-Path $r 'CLAUDE.md') $(if($Pending){'BOOTSTRAP_PENDING'}else{'# Fixture'})
    $hook='.claude/hooks/guard.ps1'; if($Shell -eq 'bash'){$hook='.claude/hooks/guard.sh'}
    $cmd="$Shell -File $hook"
    Put (Join-Path $r '.claude/settings.json') (@{hooks=@{PreToolUse=@(@{hooks=@(@{command=$cmd})})}}|ConvertTo-Json -Depth 8)
    Put (Join-Path $r '.github/hooks/hooks.json') ('{"hooks":{"preToolUse":[{"bash":"'+($hook-replace '\.ps1$','.sh')+'","powershell":"'+($hook-replace '/','\\')+'"}]}}')
    if(-not $MissingHook){Put (Join-Path $r $hook) '# fixture'; $other=$hook-replace '\.ps1$','.sh'; if($other-ne$hook){Put (Join-Path $r $other) '# fixture'}}
    Put (Join-Path $r '.claude/ai-audit.log') ''
    Put (Join-Path $r 'scripts/template-checks.ps1') ([char]0xFEFF+'exit 0') $false
    Put (Join-Path $r 'scripts/template-checks.sh') "#!/usr/bin/env bash`nexit 0`n"
    Copy-Item $doctorPs (Join-Path $r 'scripts/framework-doctor.ps1')
    Copy-Item $doctorSh (Join-Path $r 'scripts/framework-doctor.sh')
    return $r
}
function Run($Path) {
    $ef=[IO.Path]::GetTempFileName(); try {
        if($Path-match'\.ps1$'){$out=& (Get-PsExe) -NoProfile -ExecutionPolicy Bypass -File $Path 2>$ef}
        else{if(-not $bash){return $null};$out=& $bash $Path 2>$ef}
        [pscustomobject]@{Exit=$LASTEXITCODE;Out=($out-join"`n");Err=[IO.File]::ReadAllText($ef)}
    } finally {Remove-Item -Force -ErrorAction SilentlyContinue $ef}
}
function RunPsHost($Exe,$Path){$ef=[IO.Path]::GetTempFileName();try{$out=& $Exe -NoProfile -ExecutionPolicy Bypass -File $Path 2>$ef;[pscustomobject]@{Exit=$LASTEXITCODE;Out=($out-join"`n");Err=[IO.File]::ReadAllText($ef)}}finally{Remove-Item -Force -ErrorAction SilentlyContinue $ef}}
function Normal($Text){(($Text-replace'available: powershell\.exe','available: powershell')-replace'\\','/')}
function UnixTool($Name){
    $cmd=Get-Command "$Name.exe" -CommandType Application -ErrorAction SilentlyContinue
    if(-not $cmd){$cmd=Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue}
    if($cmd){return $cmd.Source}
    if($bash -and $bash -match '\\Git\\bin\\bash\.exe$'){
        $git=Split-Path (Split-Path $bash -Parent) -Parent
        $candidate=Join-Path $git "usr/bin/$Name.exe"
        if(Test-Path -LiteralPath $candidate){return $candidate}
    }
    throw "Unix tool not found: $Name"
}
Reset-Tests
It 'healthy fixture exits zero and prints canary boundary' {$r=Fixture;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[OK\] Install state') 'install state not OK';Assert ($x.Out-match'Enforcement is only FULL') 'false-full boundary missing'}finally{Remove-Item -Recurse -Force $r}}
It 'adoption pending is not reported broken' {$r=Fixture -Pending $true;try{Put (Join-Path $r '.claude/adoption-pending.json') '{}';$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "pending exit=$($x.Exit)";Assert ($x.Out-match'\[PENDING\] Bootstrap/adoption state') 'pending row missing';Assert ($x.Out-notmatch'\[MISSING\] Stack toolchain') 'dependent false alarm'}finally{Remove-Item -Recurse -Force $r}}
It 'missing hook file exits one' {$r=Fixture -MissingHook $true;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 1) "exit=$($x.Exit)";Assert ($x.Out-match'\[MISSING\] Hook files') 'missing hook row absent'}finally{Remove-Item -Recurse -Force $r}}
It 'missing wired shell exits one and names the lost controls' {$r=Fixture -Shell 'doctor-shell-does-not-exist';try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 1) "exit=$($x.Exit)";Assert ($x.Out-match'\[MISSING\] Wired hook shell') 'missing shell row absent';Assert ($x.Out-match'no write guard, build feedback, or audit trail') 'consequence absent'}finally{Remove-Item -Recurse -Force $r}}
$winPs=Get-Command powershell.exe -ErrorAction SilentlyContinue
if($winPs){It 'PowerShell twin runs under Windows PowerShell 5.1' {$r=Fixture;try{$x=RunPsHost $winPs.Source (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "5.1 exit=$($x.Exit): $($x.Out) $($x.Err)";Assert ($x.Out-match'Enforcement is only FULL') '5.1 output incomplete'}finally{Remove-Item -Recurse -Force $r}}}else{Skip 'Windows PowerShell 5.1 compatibility' 'powershell.exe unavailable on this host'}
if($bash){
It 'twins agree on pending fixture' {$r=Fixture -Shell 'bash' -Pending $true;$old=$env:PATH;try{$env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$old;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');Assert ($p.Exit-eq$s.Exit) "exit mismatch PS=$($p.Exit) SH=$($s.Exit)`nPS:`n$($p.Out)`nSH:`n$($s.Out)`n$($s.Err)";Assert ((Normal $p.Out)-eq(Normal $s.Out)) "stdout mismatch`nPS:`n$($p.Out)`nSH:`n$($s.Out)"}finally{$env:PATH=$old;Remove-Item -Recurse -Force $r}}
It 'bash twin survives without jq or python3 and reports inactive guard' {$r=Fixture -Shell 'bash' -Pending $true;$bin=Join-Path $r 'bin';New-Item -ItemType Directory $bin|Out-Null;$normalBash=$bash;try{if($bash-match'\\Git\\bin\\bash\.exe$'){$git=Split-Path (Split-Path $bash -Parent) -Parent;$usr=Join-Path $git 'usr/bin';foreach($n in 'dirname','sed','grep','sort','paste','head'){Copy-Item (Join-Path $usr "$n.exe") $bin};Get-ChildItem $usr -Filter '*.dll'|Copy-Item -Destination $bin;$restricted=$bin;$bash=Join-Path $usr 'bash.exe'}else{foreach($n in 'dirname','sed','grep','sort','paste','head'){ $src=UnixTool $n;New-Item -ItemType SymbolicLink -Path (Join-Path $bin $n) -Target $src|Out-Null };$restricted=$bin};$old=$env:PATH;$env:PATH=$restricted;try{$s=Run (Join-Path $r 'scripts/framework-doctor.sh')}finally{$env:PATH=$old;$bash=$normalBash};Assert ($null-ne$s) 'bash did not run';Assert ($s.Out-match'\[OK\] Install state') "root resolution failed under restricted PATH: $($s.Out)`nSTDERR: $($s.Err)";Assert ($s.Out-match'\[MISSING\] Guard JSON parser') "parser finding absent: $($s.Out)`nSTDERR: $($s.Err)";Assert ($s.Out-match'\[PENDING\] Bootstrap/adoption state') 'grep fallback did not read pending state'}finally{$bash=$normalBash;Remove-Item -Recurse -Force $r}}
}else{Skip 'framework-doctor.sh parity' 'no bash found'}
It 'pinned canary strings exist in the hooks they quote' {
    $hooks=(Resolve-Path (Join-Path $scripts '..\.claude\hooks')).Path
    foreach($f in @($doctorPs,$doctorSh)){
        $t=[IO.File]::ReadAllText($f)
        $m=[regex]::Match($t,'starts with "([^"]+)"');Assert $m.Success "no quoted session banner in $f"
        foreach($h in 'session-start.ps1','session-start.sh'){Assert ([IO.File]::ReadAllText((Join-Path $hooks $h)).Contains($m.Groups[1].Value)) "$h does not emit '$($m.Groups[1].Value)' quoted by $(Split-Path $f -Leaf)"}
        $m=[regex]::Match($t,'hook says "([^"]+)"');Assert $m.Success "no quoted guard message in $f"
        foreach($h in 'guard.ps1','guard.sh'){Assert ([IO.File]::ReadAllText((Join-Path $hooks $h)).Contains($m.Groups[1].Value)) "$h does not emit '$($m.Groups[1].Value)' quoted by $(Split-Path $f -Leaf)"}
    }
}
exit (Write-TestSummary 'FrameworkDoctor.Tests')
