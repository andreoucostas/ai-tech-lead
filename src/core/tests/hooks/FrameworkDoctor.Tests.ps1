# framework-doctor fixture tests: truthful states, survival paths, and twin agreement.
if (-not (Get-Command Assert -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$scripts = (Resolve-Path (Join-Path $PSScriptRoot '..\..\scripts')).Path
$doctorPs = Join-Path $scripts 'framework-doctor.ps1'
$doctorSh = Join-Path $scripts 'framework-doctor.sh'
$bash = Get-BashPath
if($bash){$null=& $bash --version 2>$null;if($LASTEXITCODE-ne 0){$bash=$null}}
function Put($Path, $Text, [bool]$Bom=$false) { [IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($Bom)) }
function Resolve-WindowsPowerShell {
    $onPath=Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1
    if($onPath){return $onPath.Source}
    if($env:SystemRoot){
        $wellKnown=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if(Test-Path -LiteralPath $wellKnown -PathType Leaf){return $wellKnown}
    }
    return $null
}
# Default wired shell must be one that exists on the TEST host (CI linux has pwsh, not powershell)
# - otherwise the doctor correctly reports it missing and the "healthy" fixtures exit 1.
$winPs=Resolve-WindowsPowerShell
$defaultShell = if ($winPs) {$winPs}
    elseif (Get-Command pwsh -ErrorAction SilentlyContinue) {'pwsh'} else {'bash'}
function Fixture([string]$Shell=$script:defaultShell,[bool]$Pending=$false,[bool]$MissingHook=$false,[bool]$HookArguments=$false,[bool]$CopilotBash=$true,[bool]$CopilotPowerShell=$true,[string]$Template='fixture') {
    $r=Join-Path ([IO.Path]::GetTempPath()) ('doctor-'+[guid]::NewGuid())
    New-Item -ItemType Directory -Force (Join-Path $r '.claude/hooks'),(Join-Path $r '.github/hooks'),(Join-Path $r '.github/instructions'),(Join-Path $r 'scripts')|Out-Null
    Put (Join-Path $r '.claude/framework-version.json') ('{"template":"'+$Template+'","version":"0.32.0","applied":"2026-07-17"}')
    $claude="<!--`n  version: 0.32.0`n-->`n@.github/instructions/framework-rules.instructions.md`n# Fixture"
    if($Pending){$claude+="`nBOOTSTRAP_PENDING"}
    Put (Join-Path $r 'CLAUDE.md') $claude
    Put (Join-Path $r '.github/instructions/framework-rules.instructions.md') "---`napplyTo: `"**`"`n---`n# Verification Rules"
    $shellLeaf=Split-Path $Shell -Leaf;$hook='.claude/hooks/guard.ps1'; if($shellLeaf-match'^bash(?:\.exe)?$'){$hook='.claude/hooks/guard.sh'}
    $shellToken=if($Shell-match'[\\/]'){('"'+$Shell+'"')}else{$Shell};$cmd="$shellToken -File $hook"
    Put (Join-Path $r '.claude/settings.json') (@{hooks=@{PreToolUse=@(@{hooks=@(@{command=$cmd})})}}|ConvertTo-Json -Depth 8)
    $bashArgs=if($HookArguments){' --mode scan'}else{''};$psArgs=if($HookArguments){' -Mode scan'}else{''}
    $copilotFields=@();if($CopilotBash){$copilotFields+='"bash":".claude/hooks/guard.sh'+$bashArgs+'"'};if($CopilotPowerShell){$copilotFields+='"powershell":".claude\\hooks\\guard.ps1'+$psArgs+'"'}
    Put (Join-Path $r '.github/hooks/hooks.json') ('{"hooks":{"preToolUse":[{'+($copilotFields-join',')+'}]}}')
    if(-not $MissingHook){Put (Join-Path $r '.claude/hooks/guard.ps1') '# fixture';Put (Join-Path $r '.claude/hooks/guard.sh') '# fixture'}
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
# The third replace maps each twin's self-reference to its own sibling script name
# (docs-sync-check.ps1 vs docs-sync-check.sh) to one common token: each twin correctly names its
# own sibling on the Mirror-check failure row, so that one difference is not a defect and must
# not fail the comparison. Keep this narrow -- do not strip .ps1/.sh generally, or real twin
# divergences elsewhere would be hidden.
function Normal($Text){((($Text-replace'available: powershell\.exe','available: powershell')-replace'[\\/]+','/')-replace'docs-sync-check\.(?:ps1|sh)','docs-sync-check.<ext>')}
function New-ParserProbeBin {
    param([Parameter(Mandatory)][string]$Bash,[bool]$PowerShellCopilot=$true,[bool]$BashCopilot=$true,[string]$Template='fixture')
    $bin=Join-Path ([IO.Path]::GetTempPath()) ('doctor-parser-bin-'+[guid]::NewGuid())
    New-Item -ItemType Directory -Force $bin|Out-Null
    $jq=@'
#!/bin/sh
if [ "$1" = "-r" ]; then
  case "$2" in *template*) echo __TEMPLATE__;; *version*) echo 0.32.0;; *applied*) echo 2026-07-17;; esac
fi
exit 0
'@
    Put (Join-Path $bin 'jq') ($jq.Replace('__TEMPLATE__',$Template)+"`n")
    if($BashCopilot){Put (Join-Path $bin 'copilot') "#!/bin/sh`nexit 0`n"}
    if($PowerShellCopilot){Put (Join-Path $bin 'copilot.cmd') "@exit /b 0`r`n"}
    # Callers reassign $env:PATH mid-loop to point at a just-constructed (and later deleted) fixture
    # bin, then call this function again for the next case -- so the child bash processes below,
    # which inherit $env:PATH, cannot be trusted to find even `command`, `ln`, or `chmod` on it.
    # Anchor every subprocess here to a fixed, known-good PATH instead of the ambient one.
    $safePath='/usr/bin:/bin:/usr/local/bin'
    $utilityNames=@('sed','grep','sort','head')
    if($Bash-match'\\Git\\bin\\bash\.exe$'){
        foreach($name in $utilityNames){Put (Join-Path $bin $name) ("#!/bin/sh`nexec /usr/bin/$name `"`$@`"`n")}
    }else{$posixBin=ConvertTo-PosixPath $bin;$null=& $Bash -c ('PATH="{1}:$PATH"; for t in sed grep sort head; do ln -sf "$(command -v $t)" "{0}/$t"; done' -f $posixBin,$safePath) 2>$null}
    $posix=ConvertTo-PosixPath $bin
    $chmodNames=@('jq');if($BashCopilot){$chmodNames+='copilot'};if($Bash-match'\\Git\\bin\\bash\.exe$'){$chmodNames+=$utilityNames}
    $chmod='PATH="'+$safePath+':$PATH" chmod +x '+(($chmodNames|ForEach-Object{'"'+$posix+'/'+$_+'"'})-join' ');$null=& $Bash -c $chmod 2>$null
    if($LASTEXITCODE-ne 0){Remove-Item -Recurse -Force $bin;throw "could not make controlled jq executable (exit $LASTEXITCODE)"}
    return $bin
}
function Add-FakeToolCommands {
    param([Parameter(Mandatory)][string]$Bin,[Parameter(Mandatory)][string]$Bash,[string[]]$Names)
    foreach($name in $Names){Put (Join-Path $Bin $name) "#!/bin/sh`nexit 0`n";Put (Join-Path $Bin ($name+'.cmd')) "@exit /b 0`r`n"}
    if($Names.Count){$quoted=@($Names|ForEach-Object{'"'+(ConvertTo-PosixPath (Join-Path $Bin $_))+'"'});$null=& $Bash -c ('PATH="/usr/bin:/bin:/usr/local/bin:$PATH" chmod +x '+($quoted-join' ')) 2>$null;Assert ($LASTEXITCODE-eq 0) 'could not make controlled tool commands executable'}
}
$script:DoctorRowNames=@('Install state','Framework rules delivery','Protected-file sync','Bootstrap/adoption state','Wired hook shell','Hook liveness','Hook files','Guard JSON parser','Stack toolchain','Copilot surface','Mirror and version integrity','Audit trail substrate')
function Parse-DoctorResult($Result) {
    $text=$Result.Out-replace"`r",'';$parts=$text-split"`n`n",2;$rows=@{}
    foreach($line in ($parts[0]-split"`n")){
        if($line-match'^\[(OK|MISSING|PENDING|CANT-VERIFY)\] (.+?) - (.*)$'){
            $name=$matches[2];Assert (-not $rows.ContainsKey($name)) "duplicate doctor row '$name'";$rows[$name]=[pscustomobject]@{State=$matches[1];Name=$name;Detail=$matches[3]}
        }
    }
    $actual=@($rows.Keys|Sort-Object);$expected=@($script:DoctorRowNames|Sort-Object)
    Assert (($actual-join'|')-eq($expected-join'|')) "doctor row names differ: actual=$($actual-join',') expected=$($expected-join',')"
    $ok=@($rows.Values|Where-Object State -eq 'OK').Count;$missing=@($rows.Values|Where-Object State -eq 'MISSING').Count
    $summary=[regex]::Match($text,'Script-verifiable checks: (\d+) ok / (\d+) missing\.')
    Assert $summary.Success "doctor summary absent: $text";Assert ([int]$summary.Groups[1].Value-eq$ok) "doctor summary ok=$($summary.Groups[1].Value), rows=$ok";Assert ([int]$summary.Groups[2].Value-eq$missing) "doctor summary missing=$($summary.Groups[2].Value), rows=$missing"
    $expectedExit=if($missing-gt 0){1}else{0};Assert ($Result.Exit-eq$expectedExit) "doctor exit=$($Result.Exit), expected=$expectedExit from $missing MISSING rows"
    $canaries=if($parts.Count-gt 1){$parts[1]}else{''};[pscustomobject]@{Rows=$rows;Ok=$ok;Missing=$missing;Canaries=$canaries}
}
function Compare-DoctorResults($PowerShellResult,$BashResult,[string[]]$ExpectedDivergentRows=@()) {
    $p=Parse-DoctorResult $PowerShellResult;$s=Parse-DoctorResult $BashResult;$actual=@()
    foreach($name in $script:DoctorRowNames){$pr=$p.Rows[$name];$sr=$s.Rows[$name];$pv=Normal("[$($pr.State)] $name - $($pr.Detail)");$sv=Normal("[$($sr.State)] $name - $($sr.Detail)");if($pv-ne$sv){$actual+=$name}}
    $actual=@($actual|Sort-Object -Unique);$expected=@($ExpectedDivergentRows|Sort-Object -Unique)
    Assert (($actual-join'|')-eq($expected-join'|')) "doctor divergence set actual={$($actual-join', ')} expected={$($expected-join', ')}`nPS:`n$($PowerShellResult.Out)`nSH:`n$($BashResult.Out)"
    [pscustomobject]@{PowerShell=$p;Bash=$s}
}
Reset-Tests
$wellKnownWinPs = if ($env:SystemRoot) { Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe' } else { $null }
if ($wellKnownWinPs -and (Test-Path -LiteralPath $wellKnownWinPs -PathType Leaf)) {
It 'Windows PowerShell resolver falls back to the usable SystemRoot executable when PATH cannot resolve it' {
    $oldPath=$env:PATH
    try {
        $env:PATH=[IO.Path]::GetTempPath()
        Assert (-not (Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue)) 'fixture PATH still resolves powershell.exe'
        $resolved=Resolve-WindowsPowerShell
        Assert ($resolved-eq$wellKnownWinPs) "resolved '$resolved', expected '$wellKnownWinPs'"
        $null=& $resolved -NoProfile -Command 'exit 0'
        Assert ($LASTEXITCODE-eq 0) "resolved Windows PowerShell is not usable (exit $LASTEXITCODE)"
    } finally {$env:PATH=$oldPath}
}
} else { Skip 'Windows PowerShell resolver falls back to the usable SystemRoot executable when PATH cannot resolve it' 'Windows PowerShell 5.1 is genuinely absent on this host' -Invariant }
It 'healthy fixture exits zero and prints canary boundary' {$r=Fixture;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[OK\] Install state') 'install state not OK';Assert ($x.Out-match'Enforcement is only FULL') 'false-full boundary missing'}finally{Remove-Item -Recurse -Force $r}}
It 'missing framework-rules import is reported honestly' {$r=Fixture -Pending $true;try{$p=Join-Path $r 'CLAUDE.md';Put $p (([IO.File]::ReadAllText($p))-replace'(?m)^@\.github/instructions/framework-rules\.instructions\.md\r?\n','');$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 1) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[MISSING\] Framework rules delivery') "delivery row absent: $($x.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'protected-file version divergence uses the required honest wording' {$r=Fixture -Pending $true;try{$p=Join-Path $r 'CLAUDE.md';Put $p (([IO.File]::ReadAllText($p))-replace'version: 0\.32\.0','version: 0.31.0');$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 1) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[MISSING\] Protected-file sync - DIVERGED . protected file not synchronized with installed machinery; review required') "honest divergence row absent: $($x.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'adoption pending is not reported broken' {$r=Fixture -Pending $true;try{Put (Join-Path $r '.claude/adoption-pending.json') '{}';$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "pending exit=$($x.Exit)";Assert ($x.Out-match'\[PENDING\] Bootstrap/adoption state') 'pending row missing';Assert ($x.Out-notmatch'\[MISSING\] Stack toolchain') 'dependent false alarm'}finally{Remove-Item -Recurse -Force $r}}
It 'missing hook file exits one' {$r=Fixture -MissingHook $true;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 1) "exit=$($x.Exit)";Assert ($x.Out-match'\[MISSING\] Hook files') 'missing hook row absent'}finally{Remove-Item -Recurse -Force $r}}
It 'bare-name wired shell is portable CANT-VERIFY and does not change exit' {$r=Fixture -Shell 'doctor-shell-bare-name' -Pending $true;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');$parsed=Parse-DoctorResult $x;Assert ($parsed.Rows['Wired hook shell'].State-eq'CANT-VERIFY') "state=$($parsed.Rows['Wired hook shell'].State)";Assert ($parsed.Rows['Wired hook shell'].Detail-match'portable bare interpreter name doctor-shell-bare-name') 'portable wording absent';Assert ($parsed.Rows['Wired hook shell'].Detail-notmatch'pin an absolute') 'obsolete pin remediation remains'}finally{Remove-Item -Recurse -Force $r}}
It 'no liveness record is CANT-VERIFY and does not change exit' {$r=Fixture -Pending $true;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[CANT-VERIFY\] Hook liveness - no hook has recorded a run here;') "CANT-VERIFY row absent: $($x.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'liveness record is OK and quotes its timestamp' {$r=Fixture -Pending $true;$stamp='2026-07-31T12:34:56Z';try{New-Item -ItemType Directory -Force (Join-Path $r '.claude/.state')|Out-Null;Put (Join-Path $r '.claude/.state/last-session-start') $stamp;$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match("\[OK\] Hook liveness - hooks have demonstrably run in this repo, most recently at '{0}'\." -f [regex]::Escape($stamp))) "OK row does not quote timestamp: $($x.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'existing absolute wired shell is OK only on this machine' {$shell=[IO.Path]::GetTempFileName();$r=Fixture -Shell $shell -Pending $true;try{$wired=(Get-Content -Raw (Join-Path $r '.claude/settings.json')|ConvertFrom-Json).hooks.PreToolUse[0].hooks[0].command;Assert ($wired-eq('"'+$shell+'" -File .claude/hooks/guard.ps1')) "fixture did not receive one path: $wired";$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[OK\] Wired hook shell - wired interpreter paths exist on this machine:') "scoped OK row absent: $($x.Out)"}finally{Remove-Item -Recurse -Force $r;Remove-Item -Force -ErrorAction SilentlyContinue $shell}}
It 'missing absolute wired shell restores portable wiring and exits one' {$shell=(Join-Path ([IO.Path]::GetTempPath()) 'doctor-missing/interpreter.exe');$r=Fixture -Shell $shell -Pending $true;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 1) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[MISSING\] Wired hook shell - the configured machine-specific interpreter path is absent on this machine:') "MISSING row absent: $($x.Out)";Assert ($x.Out-match'restore portable bare-name wiring') "portable remediation absent: $($x.Out)"}finally{Remove-Item -Recurse -Force $r}}
if($winPs){It 'PowerShell twin runs under Windows PowerShell 5.1' {$r=Fixture;try{$x=RunPsHost $winPs (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "5.1 exit=$($x.Exit): $($x.Out) $($x.Err)";Assert ($x.Out-match'Enforcement is only FULL') '5.1 output incomplete'}finally{Remove-Item -Recurse -Force $r}}}else{Skip 'Windows PowerShell 5.1 compatibility' 'Windows PowerShell 5.1 is genuinely absent on this host' -Invariant}
if($bash){
It 'PowerShell doctor cannot infer parser availability for a Copilot-only bash guard' {$r=Fixture -Pending $true;$bin=New-ParserProbeBin $bash;$old=$env:PATH;try{$settings=Get-Content -Raw (Join-Path $r '.claude/settings.json');$copilot=Get-Content -Raw (Join-Path $r '.github/hooks/hooks.json');Assert ($settings-match'guard\.ps1') "setup: Claude PowerShell guard absent: $settings";Assert ($settings-notmatch'guard\.sh') "setup: Claude unexpectedly wires guard.sh: $settings";Assert ($copilot-match'"bash"\s*:\s*"\.claude/hooks/guard\.sh"') "setup: Copilot bash guard absent: $copilot";$env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$bin+[IO.Path]::PathSeparator+$old;$null=& $bash --noprofile --norc -c 'command -v jq >/dev/null 2>&1';Assert ($LASTEXITCODE-eq 0) 'setup: controlled child bash cannot resolve jq';$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');$parsed=Parse-DoctorResult $x;Assert ($parsed.Rows['Guard JSON parser'].State-eq'CANT-VERIFY') "expected CANT-VERIFY for Copilot-only bash guard, got: $($x.Out)";Assert ($x.Exit-eq 0-and$parsed.Missing-eq 0) 'CANT-VERIFY changed exit or missing summary contribution'}finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$bin}}
It 'PowerShell doctor cannot promote a Claude bash guard from its child bash PATH' {$r=Fixture -Shell 'bash' -Pending $true;$bin=New-ParserProbeBin $bash;$old=$env:PATH;try{$settings=Get-Content -Raw (Join-Path $r '.claude/settings.json');Assert ($settings-match'guard\.sh') "setup: Claude bash guard absent: $settings";$env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$bin+[IO.Path]::PathSeparator+$old;$null=& $bash --noprofile --norc -c 'command -v jq >/dev/null 2>&1';Assert ($LASTEXITCODE-eq 0) 'setup: controlled child bash cannot resolve jq';$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');$parsed=Parse-DoctorResult $x;Assert ($parsed.Rows['Guard JSON parser'].State-eq'CANT-VERIFY') "expected CANT-VERIFY despite child-bash jq visibility, got: $($x.Out)";Assert ($x.Exit-eq 0-and$parsed.Missing-eq 0) 'CANT-VERIFY changed exit or missing summary contribution'}finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$bin}}
It 'PowerShell parser verdict is identical with bash present and absent from its PATH' {$r=Fixture -Shell 'bash' -Pending $true;$bin=New-ParserProbeBin $bash;$old=$env:PATH;try{$env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$bin;$present=Run (Join-Path $r 'scripts/framework-doctor.ps1');$env:PATH=$bin;Assert (-not (Get-Command bash -ErrorAction SilentlyContinue)) 'setup: bash still resolves in absent arm';$absent=Run (Join-Path $r 'scripts/framework-doctor.ps1');$pp=Parse-DoctorResult $present;$ap=Parse-DoctorResult $absent;Assert ($pp.Rows['Guard JSON parser'].State-eq'CANT-VERIFY') 'present arm state';Assert ($ap.Rows['Guard JSON parser'].State-eq'CANT-VERIFY') 'absent arm state';Assert ($pp.Rows['Guard JSON parser'].Detail-eq$ap.Rows['Guard JSON parser'].Detail) 'PATH changed parser detail';Assert ($pp.Ok-eq$ap.Ok-and$pp.Missing-eq$ap.Missing) 'PATH changed summary contribution'}finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$bin}}
It 'both twins require the parser for bare and absolute bash and bash.exe registrations' {
    $holder=Join-Path ([IO.Path]::GetTempPath()) ('doctor-bash-names-'+[guid]::NewGuid());$bin=New-ParserProbeBin $bash;$old=$env:PATH
    New-Item -ItemType Directory -Force $holder|Out-Null
    try{
        $env:PATH=$bin
        foreach($name in @('bash','bash.exe')){foreach($shell in @($name,(Join-Path $holder $name))){
            if($shell-match'[\\/]'){Put $shell '# fixture'};$r=Fixture -Shell $shell -Pending $true -CopilotBash $false
            try{
                $p=Parse-DoctorResult (Run (Join-Path $r 'scripts/framework-doctor.ps1'));$s=Parse-DoctorResult (Run (Join-Path $r 'scripts/framework-doctor.sh'))
                Assert ($p.Rows['Guard JSON parser'].State-eq'CANT-VERIFY') "PowerShell shell '$shell' did not require parser"
                Assert ($s.Rows['Guard JSON parser'].State-eq'OK') "Bash shell '$shell' did not require parser"
            }finally{Remove-Item -Recurse -Force $r}
        }}
    }finally{$env:PATH=$old;Remove-Item -Recurse -Force $holder,$bin}
}
It 'both twins recognize shell-valid quoted and case-insensitive Bash guard registrations' {
    $bin=New-ParserProbeBin $bash;$old=$env:PATH
    try{
        $env:PATH=$bin
        foreach($command in @("bash '.claude/hooks/guard.sh'","'/usr/bin/bash' .claude/hooks/guard.sh",'C:\Git\BASH.EXE .claude/hooks/guard.sh')){
            $r=Fixture -Pending $true -CopilotBash $false
            try{
                $jsonCommand=$command.Replace('\','\\').Replace('"','\"')
                Put (Join-Path $r '.claude/settings.json') ('{"hooks":{"PreToolUse":[{"hooks":[{"command":"'+$jsonCommand+'"}]}]}}')
                $p=Parse-DoctorResult (Run (Join-Path $r 'scripts/framework-doctor.ps1'));$s=Parse-DoctorResult (Run (Join-Path $r 'scripts/framework-doctor.sh'))
                Assert ($p.Rows['Hook files'].State-eq'OK') "PowerShell command '$command' did not resolve its hook target"
                Assert ($s.Rows['Hook files'].State-eq'OK') "Bash command '$command' did not resolve its hook target"
                Assert ($p.Rows['Guard JSON parser'].State-eq'CANT-VERIFY') "PowerShell command '$command' did not require parser"
                Assert ($s.Rows['Guard JSON parser'].State-eq'OK') "Bash command '$command' did not require parser"
            }finally{Remove-Item -Recurse -Force $r}
        }
    }finally{$env:PATH=$old;Remove-Item -Recurse -Force $bin}
}
It 'both twins ignore a Bash non-guard target and a bash -c mention of guard.sh' {
    $bin=New-ParserProbeBin $bash;$old=$env:PATH
    try{
        $env:PATH=$bin
        foreach($command in @('bash -File .claude/hooks/session-start.sh','bash -c "echo .claude/hooks/guard.sh"')){
            $r=Fixture -Shell 'bash' -Pending $true -CopilotBash $false
            try{
                Put (Join-Path $r '.claude/hooks/session-start.sh') '# fixture';Put (Join-Path $r '.claude/settings.json') (@{hooks=@{SessionStart=@(@{hooks=@(@{command=$command})})}}|ConvertTo-Json -Depth 8)
                $p=Parse-DoctorResult (Run (Join-Path $r 'scripts/framework-doctor.ps1'));$s=Parse-DoctorResult (Run (Join-Path $r 'scripts/framework-doctor.sh'))
                Assert ($p.Rows['Guard JSON parser'].State-eq'OK') "PowerShell command '$command' created parser demand"
                Assert ($s.Rows['Guard JSON parser'].State-eq'OK') "Bash command '$command' created parser demand"
            }finally{Remove-Item -Recurse -Force $r}
        }
    }finally{$env:PATH=$old;Remove-Item -Recurse -Force $bin}
}
It 'historical child-bash inference wrongly promotes the fixed CANT-VERIFY row under the same PATH' {
    $r=Fixture -Shell 'bash' -Pending $true;$bin=New-ParserProbeBin $bash;$old=$env:PATH
    try{
        $env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$bin+[IO.Path]::PathSeparator+$old
        $doc=Join-Path $r 'scripts/framework-doctor.ps1';$fixed=Run $doc;$fixedParsed=Parse-DoctorResult $fixed
        Assert ($fixedParsed.Rows['Guard JSON parser'].State-eq'CANT-VERIFY') "fixed contract not reachable: $($fixed.Out)"
        $text=([IO.File]::ReadAllText($doc)-replace"`r`n","`n")
        $functionAnchor='function Has($Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }'
        Assert ([regex]::Matches($text,[regex]::Escape($functionAnchor)).Count-eq 1) 'historical-function insertion anchor is not unique'
        Assert ([regex]::Matches($text,'function Invoke-BashProbe').Count-eq 0) 'fixed source still contains Invoke-BashProbe'
        $historicalFunction=@'
function Invoke-BashProbe($Command) {
    $bashCommand = Get-Command bash -ErrorAction SilentlyContinue
    if (-not $bashCommand) { return $null }
    try {
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $bashCommand.Source
        $startInfo.Arguments = '--noprofile --norc -c "' + $Command + '"'
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        if ($process.Start()) {
            if ($process.WaitForExit(3000)) { $result = ($process.ExitCode -eq 0) }
            else { $process.Kill(); $result = $null }
        } else { $result = $null }
        $process.Dispose()
        return $result
    } catch { return $null }
}
'@ -replace"`r`n","`n"
        $mutated=$text.Replace($functionAnchor,$functionAnchor+"`n"+$historicalFunction.TrimEnd("`n"))
        $begin='# PARSER-VANTAGE-BRANCH-BEGIN';$end='# PARSER-VANTAGE-BRANCH-END'
        Assert ([regex]::Matches($mutated,[regex]::Escape($begin)).Count-eq 1) 'parser begin anchor is not unique';Assert ([regex]::Matches($mutated,[regex]::Escape($end)).Count-eq 1) 'parser end anchor is not unique'
        $start=$mutated.IndexOf($begin)+$begin.Length;$finish=$mutated.IndexOf($end,$start)
        $historicalBranch=@'

if ($bashGuardRegistered) {
    $bashParser = Invoke-BashProbe 'command -v jq >/dev/null 2>&1 && exit 0; for c in python3 python py; do command -v $c >/dev/null 2>&1 && printf ''{}'' | $c -c ''import json,sys; json.load(sys.stdin)'' >/dev/null 2>&1 && exit 0; done; exit 1'
    if ($null -eq $bashParser) { Row CANT-VERIFY 'Guard JSON parser' 'bash is wired but this script could not observe its PATH.' }
    elseif ($bashParser) { Row OK 'Guard JSON parser' 'jq or a working python interpreter is available.' }
    else { Row MISSING 'Guard JSON parser' 'the bash write guard is INACTIVE and allows writes with only a warning. Fix: install jq.' }
} else { Row OK 'Guard JSON parser' 'not required by the registered PowerShell guards.' }

'@ -replace"`r`n","`n"
        $mutated=$mutated.Substring(0,$start)+$historicalBranch+$mutated.Substring($finish)
        Put $doc $mutated $true
        $tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($doc,[ref]$tokens,[ref]$errors);Assert ($errors.Count-eq 0) "mutant parser errors: $($errors.Message-join'; ')"
        $mutant=Run $doc;$mutantParsed=Parse-DoctorResult $mutant
        Assert ($mutantParsed.Rows['Guard JSON parser'].State-eq'OK') "historical mutant did not promote to OK: $($mutant.Out)"
        Assert ($mutantParsed.Ok-eq($fixedParsed.Ok+1)) "mutant ok count $($mutantParsed.Ok), fixed $($fixedParsed.Ok)";Assert ($mutantParsed.Missing-eq$fixedParsed.Missing) 'mutant changed missing count'
        $contractRejected=$false;try{Assert ($mutantParsed.Rows['Guard JSON parser'].State-eq'CANT-VERIFY') 'mutant violates fixed parser contract'}catch{$contractRejected=$true};Assert $contractRejected 'contract helper accepted historical mutant'
        if($winPs){$mutant51=RunPsHost $winPs $doc;Assert ($mutant51.Out-match'\[OK\] Guard JSON parser') "5.1 did not parse/run mutant: $($mutant51.Err)"}
    }finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$bin}
}
It 'Copilot CLI visibility is controlled per twin and only constructed asymmetry diverges' {
    $r=Fixture -Pending $true -CopilotBash $false;$old=$env:PATH
    try{
        foreach($case in @(
            [pscustomobject]@{Name='both';P=$true;S=$true;Expected=@()},
            [pscustomobject]@{Name='neither';P=$false;S=$false;Expected=@()},
            [pscustomobject]@{Name='PowerShell-only';P=$true;S=$false;Expected=@('Copilot surface')},
            [pscustomobject]@{Name='Bash-only';P=$false;S=$true;Expected=@('Copilot surface')}
        )){
            $pbin=New-ParserProbeBin $bash $case.P $case.P;$sbin=New-ParserProbeBin $bash $false $case.S
            try{
                $env:PATH=$pbin;$pSetup=[bool](Get-Command copilot -ErrorAction SilentlyContinue);Assert ($pSetup-eq$case.P) "setup $($case.Name): PowerShell visibility=$pSetup"
                $p=Run (Join-Path $r 'scripts/framework-doctor.ps1')
                $env:PATH=$sbin;$null=& $bash -c 'command -v copilot >/dev/null 2>&1';$sSetup=($LASTEXITCODE-eq 0);Assert ($sSetup-eq$case.S) "setup $($case.Name): Bash visibility=$sSetup"
                $s=Run (Join-Path $r 'scripts/framework-doctor.sh');$c=Compare-DoctorResults $p $s $case.Expected
                $pHas=$c.PowerShell.Rows['Copilot surface'].Detail-match'CLI is available';$sHas=$c.Bash.Rows['Copilot surface'].Detail-match'CLI is available'
                Assert ($pHas-eq$case.P) "result $($case.Name): PowerShell detail='$($c.PowerShell.Rows['Copilot surface'].Detail)'";Assert ($sHas-eq$case.S) "result $($case.Name): Bash detail='$($c.Bash.Rows['Copilot surface'].Detail)'"
            }finally{Remove-Item -Recurse -Force $pbin,$sbin}
        }
    }finally{$env:PATH=$old;Remove-Item -Recurse -Force $r}
}
It 'genuine no-bash and Copilot-only bash fixtures have exact parser divergence sets' {
    $bin=New-ParserProbeBin $bash;$old=$env:PATH
    try{
        $env:PATH=$bin
        foreach($copilotBash in @($false,$true)){
            $r=Fixture -Pending $true -CopilotBash $copilotBash
            try{
                if(-not$copilotBash){$settings=Get-Content -Raw (Join-Path $r '.claude/settings.json');$copilot=Get-Content -Raw (Join-Path $r '.github/hooks/hooks.json');Assert ($settings-notmatch'guard\.sh') "setup: Claude unexpectedly wires guard.sh: $settings";Assert ($copilot-notmatch'"bash"') "setup: Copilot unexpectedly has a bash member: $copilot";Assert ($copilot-notmatch'guard\.sh') "setup: Copilot unexpectedly targets guard.sh: $copilot"}
                $p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$expected=if($copilotBash){@('Guard JSON parser')}else{@()};$c=Compare-DoctorResults $p $s $expected
                if($copilotBash){Assert ($c.PowerShell.Rows['Guard JSON parser'].State-eq'CANT-VERIFY') 'Copilot-only PS state';Assert ($c.Bash.Rows['Guard JSON parser'].State-eq'OK') 'Copilot-only Bash state'}else{Assert ($c.PowerShell.Rows['Guard JSON parser'].State-eq'OK') 'no-bash PS state';Assert ($c.Bash.Rows['Guard JSON parser'].State-eq'OK') 'no-bash Bash state'}
            }finally{Remove-Item -Recurse -Force $r}
        }
    }finally{$env:PATH=$old;Remove-Item -Recurse -Force $bin}
}
It 'twins agree outside the parser row when liveness is absent and present' {$r=Fixture -Shell 'bash' -Pending $true;$bin=New-ParserProbeBin $bash;$old=$env:PATH;try{$env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$bin+[IO.Path]::PathSeparator+$old;foreach($stamp in @($null,'2026-07-31T12:34:56Z')){Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $r '.claude/.state/last-session-start');if($stamp){New-Item -ItemType Directory -Force (Join-Path $r '.claude/.state')|Out-Null;Put (Join-Path $r '.claude/.state/last-session-start') $stamp};$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$c=Compare-DoctorResults $p $s @('Guard JSON parser');Assert ($c.PowerShell.Rows['Guard JSON parser'].State-eq'CANT-VERIFY') 'PowerShell parser state';Assert ($c.Bash.Rows['Guard JSON parser'].State-eq'OK') 'Bash parser state'}}finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$bin}}
It 'Copilot hook registrations with arguments resolve only their file paths' {$r=Fixture -Shell 'bash' -Pending $true -HookArguments $true;$bin=New-ParserProbeBin $bash;$old=$env:PATH;try{$env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$bin+[IO.Path]::PathSeparator+$old;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$c=Compare-DoctorResults $p $s @('Guard JSON parser');Assert ($c.PowerShell.Rows['Hook files'].State-eq'OK') 'PowerShell hook row';Assert ($c.Bash.Rows['Hook files'].State-eq'OK') 'Bash hook row'}finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$bin}}
# Non-pending cases reach Mirror and Audit; the controlled template matrix below separately forces
# every Stack-toolchain marker with both available and absent command sets.
It 'twins agree outside the parser row on non-pending mirror pass' {$r=Fixture -Shell 'bash';$bin=New-ParserProbeBin $bash;$old=$env:PATH;try{$env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$bin+[IO.Path]::PathSeparator+$old;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$c=Compare-DoctorResults $p $s @('Guard JSON parser');Assert ($c.PowerShell.Rows['Mirror and version integrity'].State-eq'OK') 'PS mirror row'}finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$bin}}
It 'twins agree outside the parser row on non-pending mirror failure' {$r=Fixture -Shell 'bash';$bin=New-ParserProbeBin $bash;$old=$env:PATH;try{Put (Join-Path $r 'scripts/template-checks.ps1') ([char]0xFEFF+'exit 1') $false;Put (Join-Path $r 'scripts/template-checks.sh') "#!/usr/bin/env bash`nexit 1`n";$env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$bin+[IO.Path]::PathSeparator+$old;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$c=Compare-DoctorResults $p $s @('Guard JSON parser');Assert ($c.PowerShell.Rows['Mirror and version integrity'].State-eq'MISSING') 'PS mirror row'}finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$bin}}
It 'Stack toolchain rows use byte-identical doctor-process wording for every template and outcome' {
    $old=$env:PATH
    try{
        foreach($template in @('dotnet','angular','monorepo')){
            $required=if($template-eq'dotnet'){@('dotnet')}elseif($template-eq'angular'){@('node','npx')}else{@('dotnet','node','npx')}
            foreach($present in @($true,$false)){
                $r=Fixture -Pending $false -CopilotBash $false -Template $template;$pbin=New-ParserProbeBin $bash $true $true $template;$sbin=New-ParserProbeBin $bash $true $true $template
                try{
                    if($present){Add-FakeToolCommands $pbin $bash $required;Add-FakeToolCommands $sbin $bash $required}
                    $env:PATH=$pbin;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$pp=Parse-DoctorResult $p
                    $env:PATH=$sbin;$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$sp=Parse-DoctorResult $s
                    $expectedState=if($present){'OK'}else{'MISSING'};$pr=$pp.Rows['Stack toolchain'];$sr=$sp.Rows['Stack toolchain'];Assert ($pr.State-eq$expectedState) "PS $template present=$present state=$($pr.State)";Assert ($sr.State-eq$pr.State) "SH $template state=$($sr.State), PS=$($pr.State)";Assert ($pr.Detail-eq$sr.Detail) "Stack detail mismatch PS='$($pr.Detail)' SH='$($sr.Detail)'";Assert ($pr.Detail-match'this doctor process environment') "generic environment boundary absent: $($pr.Detail)";Assert ($pr.Detail-notmatch'PowerShell doctor|Bash doctor') "shell-specific environment leaked: $($pr.Detail)"
                }finally{Remove-Item -Recurse -Force $r,$pbin,$sbin}
            }
        }
    }finally{$env:PATH=$old}
}
# Sandbox utility list for framework-doctor.sh; kept identical to the fixture's original inline
# version so behaviour does not shift on refactor (dirname/paste are unused by the script itself,
# but were part of the proven sandbox and there is no reason to narrow it here). Now built via the
# shared Invoke-Sandboxed helper in _HookHarness.ps1 so other hook test files can reuse it too.
$doctorUtils = @('dirname','sed','grep','sort','paste','head')
It 'bash twin survives without jq or ANY working python and reports the guard inactive (no interpreter present at all)' {
    $r=Fixture -Shell 'bash' -Pending $true;$pbin=New-ParserProbeBin $bash $true $true;$old=$env:PATH
    try{
        $doc=Join-Path $r 'scripts/framework-doctor.sh'
        $env:PATH=$pbin;Assert ([bool](Get-Command copilot -ErrorAction SilentlyContinue)) 'setup: Copilot not visible to PowerShell'
        $p=Run (Join-Path $r 'scripts/framework-doctor.ps1')
        $env:PATH=$old
        $s=Invoke-Sandboxed -Bash $bash -ScriptPath $doc -Utilities $doctorUtils
        Assert ($s.Out-match'\[OK\] Install state') "root resolution failed under restricted PATH: $($s.Out)`nSTDERR: $($s.Err)"
        Assert ($s.Out-match'\[MISSING\] Guard JSON parser') "parser finding absent: $($s.Out)`nSTDERR: $($s.Err)"
        Assert ($s.Out-match'\[PENDING\] Bootstrap/adoption state') 'grep fallback did not read pending state'
        $null=Compare-DoctorResults $p $s @('Guard JSON parser','Copilot surface')
    }finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$pbin}}
# A python.org install ships python.exe and no python3.exe; probing only python3 (or only jq)
# never sees it, so the guard was reported INACTIVE while guard.sh (which DOES probe
# python3/python/py by execution) was ACTIVE -- a false alarm on the write floor.
if (Resolve-HostPython) {
It 'bash twin reports the guard ACTIVE when jq is absent but a working interpreter resolves only as `python`' {
    $r=Fixture -Shell 'bash' -Pending $true
    try{
        $doc=Join-Path $r 'scripts/framework-doctor.sh'
        $s=Invoke-Sandboxed -Bash $bash -ScriptPath $doc -Utilities $doctorUtils -ExposeInterpreterAs 'python'
        Assert ($s.Out-match'\[OK\] Guard JSON parser') "expected OK (working interpreter present as `python`), got: $($s.Out)`nSTDERR: $($s.Err)"
    }finally{Remove-Item -Recurse -Force $r}}
} else { Skip 'bash twin reports the guard ACTIVE when jq is absent but a working interpreter resolves only as `python`' 'no working python interpreter found on this host (set $env:ATL_TEST_PYTHON to an absolute interpreter path to exercise this case)' -Invariant }
# The Microsoft Store alias stub resolves under the name `python` but is not an interpreter (prints
# "Python was not found" and exits 49) -- it must not be accepted as satisfying the guard floor.
It 'bash twin reports the guard MISSING when the only `python` on PATH is the Microsoft Store alias stub' {
    $r=Fixture -Shell 'bash' -Pending $true
    try{
        $doc=Join-Path $r 'scripts/framework-doctor.sh'
        $stub="#!/usr/bin/env bash`nprintf 'Python was not found; run without arguments to install from the Microsoft Store, or disable this shortcut from Settings > Manage App Execution Aliases.\n' >&2`nexit 49`n"
        $s=Invoke-Sandboxed -Bash $bash -ScriptPath $doc -Utilities $doctorUtils -FakeBins @{ python = $stub }
        Assert ($s.Out-match'\[MISSING\] Guard JSON parser') "expected MISSING (stub is not an interpreter), got: $($s.Out)`nSTDERR: $($s.Err)"
    }finally{Remove-Item -Recurse -Force $r}}
# The Store-stub-rejection case above cannot go red against the pre-fix script (pre-fix never
# considered bare `python` at all, so it happened to reject the stub too, by accident rather than
# design -- not a regression test). This case proves the property that actually matters: an
# EXECUTION check is load-bearing, a NAME-only probe is not. It mutates a copy of the real,
# already-fixed script so ONLY the Guard JSON parser row's own resolution accepts any candidate
# that merely resolves by name (no round-trip JSON check) -- the shape of probe every other
# parser-dependent hook in this repo deliberately avoids -- and shows that naive variant wrongly
# accepting the Store stub as OK. (The earlier, shared resolve_pybin used to parse
# framework-version.json is left untouched, so this stays a surgical, single-row mutation instead
# of cascading into an early script exit that would never reach the row under test.)
It 'a NAME-only python probe (no execution check) wrongly accepts the Store stub -- proves the execution check is load-bearing' {
    $r=Fixture -Shell 'bash' -Pending $true
    try{
        $doc=Join-Path $r 'scripts/framework-doctor.sh'
        $text=[IO.File]::ReadAllText($doc)
        $q=[char]39
        $searchText='    resolve_pybin'+"`n"+'    if [ -n "$_pybin" ]; then row OK '+$q+'Guard JSON parser'+$q+' '+$q+'jq or a working python interpreter is available in this Bash environment.'+$q
        Assert ($text.Contains($searchText)) 'could not locate the Guard JSON parser row''s resolve_pybin call to mutate -- framework-doctor.sh may have changed shape; update this test'
        $naiveText='    _pybin=""'+"`n"+'    for _naivecand in python3 python py; do command -v "$_naivecand" >/dev/null 2>&1 && { _pybin=$_naivecand; break; }; done'+"`n"+'    if [ -n "$_pybin" ]; then row OK '+$q+'Guard JSON parser'+$q+' '+$q+'jq or a working python interpreter is available in this Bash environment.'+$q
        $mutated=$text.Replace($searchText,$naiveText)
        Assert ($mutated -ne $text) 'mutation did not change the file'
        [IO.File]::WriteAllText($doc,$mutated)
        $stub="#!/usr/bin/env bash`nprintf 'Python was not found; run without arguments to install from the Microsoft Store, or disable this shortcut from Settings > Manage App Execution Aliases.\n' >&2`nexit 49`n"
        $s=Invoke-Sandboxed -Bash $bash -ScriptPath $doc -Utilities $doctorUtils -FakeBins @{ python = $stub }
        Assert ($s.Out-match'\[OK\] Guard JSON parser') "the naive NAME-only probe should have wrongly accepted the stub as OK -- if this does not reproduce, the mutation is not exercising the intended branch. Got: $($s.Out)`nSTDERR: $($s.Err)"
    }finally{Remove-Item -Recurse -Force $r}}
}else{Skip 'framework-doctor.sh parity' 'no bash found' -Invariant}
It 'pinned canary strings exist in the hooks they quote' {
    $hooks=(Resolve-Path (Join-Path $scripts '..\.claude\hooks')).Path
    foreach($f in @($doctorPs,$doctorSh)){
        $t=[IO.File]::ReadAllText($f)
        $m=[regex]::Match($t,'starts with "([^"]+)"');Assert $m.Success "no quoted session banner in $f"
        foreach($h in 'session-start.ps1','session-start.sh'){Assert ([IO.File]::ReadAllText((Join-Path $hooks $h)).Contains($m.Groups[1].Value)) "$h does not emit '$($m.Groups[1].Value)' quoted by $(Split-Path $f -Leaf)"}
        $m=[regex]::Match($t,'hook says "([^"]+)"');Assert $m.Success "no quoted guard message in $f"
        foreach($h in 'guard.ps1','guard.sh'){Assert ([IO.File]::ReadAllText((Join-Path $hooks $h)).Contains($m.Groups[1].Value)) "$h does not emit '$($m.Groups[1].Value)' quoted by $(Split-Path $f -Leaf)"}
        $finishStart=if($f-match'\.ps1$'){$t.IndexOf('function Finish {')}else{$t.IndexOf('finish() {')};$stackCanary=$t.IndexOf('[CANT-VERIFY] Agent-host stack toolchain');$summary=$t.IndexOf('Script-verifiable checks:')
        $finishPrefix=if($finishStart-ge 0-and$stackCanary-gt$finishStart){$t.Substring($finishStart,$stackCanary-$finishStart)}else{''};$separatorPattern=if($f-match'\.ps1$'){"(?m)^\s*Write-(?:Output|Host) ''\s*`$"}else{'(?m)^\s*echo\s*$'}
        Assert ($finishPrefix-match$separatorPattern-and$stackCanary-lt$summary) "stack canary is not after the row separator and before the summary in $(Split-Path $f -Leaf)"
        Assert ($t.Contains('make and then revert')) "stack canary does not require reverting the edit in $(Split-Path $f -Leaf)";Assert ($t.Contains('post-write throttle')) "stack canary does not mention the throttle in $(Split-Path $f -Leaf)"
        Assert ($t.Contains('## dotnet build failed')) "dotnet canary prefix absent from $(Split-Path $f -Leaf)";Assert ($t.Contains('## tsc --noEmit failed')) "tsc canary prefix absent from $(Split-Path $f -Leaf)"
    }
    $localPostWrite=@();foreach($name in 'post-write.ps1','post-write.sh'){$candidate=Join-Path $hooks $name;if(Test-Path $candidate){$localPostWrite+=$candidate}}
    if($localPostWrite.Count){$postWrite=$localPostWrite}else{$repo=(Resolve-Path (Join-Path $scripts '..\..\..')).Path;$postWrite=@(Get-ChildItem (Join-Path $repo 'src/stacks') -Recurse -File|Where-Object{$_.Name-match'^post-write\.(?:ps1|sh)$'}|Select-Object -ExpandProperty FullName)}
    Assert (@($postWrite).Count-gt 0) 'no post-write hooks found for canary pin';foreach($h in $postWrite){$t=[IO.File]::ReadAllText($h);Assert ($t-match'## (?:dotnet build|tsc --noEmit) failed') "post-write canary prefix absent from $h"}
}
exit (Write-TestSummary 'FrameworkDoctor.Tests')
