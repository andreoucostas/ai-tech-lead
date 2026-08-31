# framework-doctor fixture tests: truthful states, survival paths, and twin agreement.
param([ValidateSet(0,1,2,3,4,5,6,7,9)][int]$ProtectedSyncArm=0)
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
function Fixture([string]$Shell=$script:defaultShell,[bool]$Pending=$false,[bool]$MissingHook=$false,[bool]$HookArguments=$false,[bool]$CopilotBash=$true,[bool]$CopilotPowerShell=$true,[string]$Template='dotnet',[ValidateSet('angularJson','package')][string]$AngularEvidence='angularJson') {
    $r=Join-Path ([IO.Path]::GetTempPath()) ('doctor-'+[guid]::NewGuid())
    New-Item -ItemType Directory -Force (Join-Path $r '.claude/hooks'),(Join-Path $r '.github/hooks'),(Join-Path $r '.github/instructions'),(Join-Path $r 'scripts')|Out-Null
    Put (Join-Path $r '.claude/framework-version.json') ('{"template":"'+$Template+'","version":"0.32.0","applied":"2026-07-17","decimal":0.01,"exponent":1e01,"negativeExponent":1e-01}')
    $withApplicationEvidence=$PSBoundParameters.ContainsKey('Template')
    if($withApplicationEvidence-and$Template-match'dotnet|monorepo'){Put (Join-Path $r 'App.csproj') '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>'}
    if($withApplicationEvidence-and$Template-match'angular|monorepo'){
        if($AngularEvidence-eq'package'){Put (Join-Path $r 'package.json') '{"dependencies":{"@angular/core":"20.0.0"}}'}
        else{Put (Join-Path $r 'angular.json') '{"version":1}'}
    }
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
        else{
            if(-not $bash){return $null}
            # Git Bash extends a Windows-only PATH with its own tool directories while it starts.
            # The controlled parser/toolchain matrices intentionally set PATH to one fixture bin;
            # re-apply that POSIX path inside the launched shell before it runs the doctor so host
            # jq/python/copilot/dotnet cannot satisfy an absence arm by accident.
            if($bash-match'\\Git\\bin\\bash\.exe$'-and$env:PATH-notmatch';'){
                $binPath=ConvertTo-PosixPath $env:PATH;$scriptPath=ConvertTo-PosixPath $Path
                # Source rather than exec a nested Git Bash: that nested process silently adds
                # Git/usr/bin back to PATH (and reintroduces jq/python). $0 remains the doctor
                # path, so its existing root calculation is exercised unchanged.
                $out=& $bash --noprofile --norc -c 'PATH="$1"; export PATH; hash -r; . "$2"' $scriptPath $binPath $scriptPath 2>$ef
            }else{$out=& $bash $Path 2>$ef}
        }
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
    param([Parameter(Mandatory)][string]$Bash,[bool]$PowerShellCopilot=$true,[bool]$BashCopilot=$true,[string]$Template='dotnet',[bool]$IncludeBash=$false)
    $bin=Join-Path ([IO.Path]::GetTempPath()) ('doctor-parser-bin-'+[guid]::NewGuid())
    New-Item -ItemType Directory -Force $bin|Out-Null
$jq=@'
#!/bin/sh
if [ "$1" = "empty" ]; then
  IFS= read -r input || :
  case "$input" in *" junk"*|*",}"*|*"/*"*|*"NaN"*|*"Infinity"*|*"'"*) exit 4;; esac
  exit 0
fi
if [ "$1" = "-e" ]; then
  if [ -n "${3:-}" ]; then
    grep -Eq ' junk|NaN|Infinity|/\*|,[[:space:]]*}' "$3" 2>/dev/null && exit 4
    grep -q "'" "$3" 2>/dev/null && exit 4
    grep -Eq '\{[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:' "$3" 2>/dev/null && exit 4
    grep -Eq '^[[:space:]]*\{' "$3" 2>/dev/null || exit 4
  else
    IFS= read -r input || :
    case "$input" in *" junk"*) exit 4;; esac
    printf '%s\n' "$input" | grep -Eq ',[[:space:]]*[]}]' && exit 4
    case "${2:-}" in *'type == "object"'*) case "$input" in [[:space:]]*\{*) :;; \{*) :;; *) exit 4;; esac;; esac
  fi
  exit 0
fi
if [ "$1" = "-r" ]; then
  json_file=${3:-}; json_input=''
  if [ -z "$json_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do json_input="${json_input}${json_input:+
}$line"; done
  fi
  json_match() {
    if [ -n "$json_file" ]; then grep -Eq "$1" "$json_file" 2>/dev/null
    else printf '%s\n' "$json_input" | grep -Eq "$1"
    fi
  }
  case "$2" in
    *template*) if json_match '"template"[[:space:]]*:'; then echo __TEMPLATE__; else echo; fi;;
    *version*) echo 0.32.0;;
    *applied*) echo 2026-07-17;;
    *angular_workspace_evidence*) if json_match '^[[:space:]]*\{'; then echo true; else echo false; fi;;
    *angular_package_evidence*) if json_match '"(dependencies|devDependencies|peerDependencies|optionalDependencies)"[^}]*"@angular/core"[[:space:]]*:'; then echo true; else echo false; fi;;
    *angular_nx_evidence*) if json_match '"notes"|"Plugin"|"Executor"|"Generator"|"Collection"'; then echo false; elif json_match '"@(angular|nx/angular|angular-devkit|schematics/angular)(/[^" ]+|:[^" ]+)"'; then echo true; else echo false; fi;;
    *command*) printf '%s\n' "$json_input" | sed 's/"command"/\
"command"/g' | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\\"\([^"]*\)\\"\(.*\)".*/"\1"\2/p; t; s/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p';;
  esac
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
    $utilityNames=@('sed','grep','sort','head');if($IncludeBash){$utilityNames+='bash'}
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
function Get-StackCanary($Parsed) {
    $match=[regex]::Match($Parsed.Canaries,'(?m)^\[CANT-VERIFY\] Agent-host stack toolchain - .+$')
    Assert $match.Success "agent-host stack canary absent: $($Parsed.Canaries)"
    return $match.Value
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
function Assert-ProtectedSyncPair($Root,[string]$State,[string]$Detail,[string]$DeliveryState='OK') {
    Assert ([bool]$bash) 'bash is required to verify framework-doctor twin agreement'
    $p=Run (Join-Path $Root 'scripts/framework-doctor.ps1');$s=Run (Join-Path $Root 'scripts/framework-doctor.sh');$c=Compare-DoctorResults $p $s
    foreach($parsed in @($c.PowerShell,$c.Bash)){
        $row=$parsed.Rows['Protected-file sync'];Assert ($row.State-eq$State) "Protected-file sync state=$($row.State), expected=$State; detail=$($row.Detail)";Assert ($row.Detail-eq$Detail) "Protected-file sync detail='$($row.Detail)', expected='$Detail'"
        Assert ($parsed.Rows['Framework rules delivery'].State-eq$DeliveryState) "Framework rules delivery state=$($parsed.Rows['Framework rules delivery'].State), expected=$DeliveryState"
    }
}
function Add-InlineFrameworkHeadings($Root,[string[]]$Headings){$p=Join-Path $Root 'CLAUDE.md';Put $p (([IO.File]::ReadAllText($p))+"`n"+(($Headings|ForEach-Object{"## $_"})-join"`n"))}
function New-ProtectedSyncFixture([ValidateSet('migrated','one','all','boy-scout','no-import','no-claude','empty-claude','empty-list')][string]$Case){
    $r=Fixture -Pending $true -CopilotBash $false
    switch($Case){
        one {Add-InlineFrameworkHeadings $r @('Leanness')}
        all {Add-InlineFrameworkHeadings $r @('Verification Rules','Leanness','SOLID','Agentic Workflow')}
        boy-scout {Add-InlineFrameworkHeadings $r @('Boy Scout Rule')}
        no-import {$p=Join-Path $r 'CLAUDE.md';Put $p (([IO.File]::ReadAllText($p))-replace'(?m)^@\.github/instructions/framework-rules\.instructions\.md\r?\n','')}
        no-claude {Remove-Item -Force (Join-Path $r 'CLAUDE.md')}
        empty-claude {Put (Join-Path $r 'CLAUDE.md') ''}
        empty-list {
            $p=Join-Path $r 'scripts/framework-doctor.ps1';$text=[IO.File]::ReadAllText($p);$mutated=$text.Replace("`$frameworkHeadings = @('Verification Rules', 'Leanness', 'SOLID', 'Agentic Workflow')",'$frameworkHeadings = @()');Assert ($mutated-ne$text) 'PowerShell empty-list subject mutation missed';Put $p $mutated $true
            $s=Join-Path $r 'scripts/framework-doctor.sh';$text=[IO.File]::ReadAllText($s);$mutated=[regex]::Replace($text,"framework_headings='Verification Rules\r?\nLeanness\r?\nSOLID\r?\nAgentic Workflow'","framework_headings=''");Assert ($mutated-ne$text) 'shell empty-list subject mutation missed';Put $s $mutated
        }
    }
    $r
}
$migratedDetail='migrated - the carrier is authoritative.'
$incompletePrefix='migration incomplete - these sections duplicate the carrier and may conflict:'
$incompleteSuffix='Fix: delete them from CLAUDE.md.'
$inspectionMissing='framework heading inspection is incomplete; protected-file migration state cannot be verified.'
function It-ProtectedSyncArm([int]$Arm,[string]$Name,[scriptblock]$Body){if($ProtectedSyncArm-eq 0-or$ProtectedSyncArm-eq$Arm){It $Name $Body}}
It-ProtectedSyncArm 1 'Protected-file sync arm 1: imported carrier with no inline framework headings is migrated' {$r=New-ProtectedSyncFixture migrated;try{Assert-ProtectedSyncPair $r OK $migratedDetail}finally{Remove-Item -Recurse -Force $r}}
It-ProtectedSyncArm 2 'Protected-file sync arm 2: one inline heading is pending and names Leanness' {$r=New-ProtectedSyncFixture one;try{Assert-ProtectedSyncPair $r PENDING "$incompletePrefix Leanness. $incompleteSuffix"}finally{Remove-Item -Recurse -Force $r}}
It-ProtectedSyncArm 3 'Protected-file sync arm 3: all inline headings are pending and all are named' {$r=New-ProtectedSyncFixture all;try{Assert-ProtectedSyncPair $r PENDING "$incompletePrefix Verification Rules, Leanness, SOLID, Agentic Workflow. $incompleteSuffix"}finally{Remove-Item -Recurse -Force $r}}
It-ProtectedSyncArm 4 'Protected-file sync arm 4: Boy Scout Rule alone is not a framework migration finding' {$r=New-ProtectedSyncFixture boy-scout;try{Assert-ProtectedSyncPair $r OK $migratedDetail}finally{Remove-Item -Recurse -Force $r}}
It-ProtectedSyncArm 5 'Protected-file sync arm 5: missing import defers without double-reporting' {$r=New-ProtectedSyncFixture no-import;try{Assert-ProtectedSyncPair $r OK 'deferred to Framework rules delivery.' MISSING}finally{Remove-Item -Recurse -Force $r}}
It-ProtectedSyncArm 6 'Protected-file sync arm 6: absent CLAUDE.md is missing' {$r=New-ProtectedSyncFixture no-claude;try{Assert-ProtectedSyncPair $r MISSING 'CLAUDE.md is absent; protected-file migration state cannot be inspected.' MISSING}finally{Remove-Item -Recurse -Force $r}}
It-ProtectedSyncArm 7 'Protected-file sync arm 7: an empty heading list fails closed instead of passing vacuously' {$r=New-ProtectedSyncFixture empty-list;try{Assert-ProtectedSyncPair $r MISSING $inspectionMissing}finally{Remove-Item -Recurse -Force $r}}
It-ProtectedSyncArm 9 'Protected-file sync arm 9: an empty CLAUDE.md still emits the row on both twins' {
    # Regression guard. Get-Content -Raw returns $null (not '') for an empty file, so an unguarded
    # .Contains() threw and the row VANISHED from the PowerShell report -- 6 ok / 2 missing with no
    # Protected-file sync line at all -- while the .sh twin reported deferred. An inert row reads as
    # a clean run, which is the failure class where a check silently stops checking.
    $r=New-ProtectedSyncFixture empty-claude;try{Assert-ProtectedSyncPair $r OK 'deferred to Framework rules delivery.' MISSING}finally{Remove-Item -Recurse -Force $r}}
if($ProtectedSyncArm-ne 0){exit (Write-TestSummary 'FrameworkDoctor.Tests')}
It 'adoption pending is not reported broken' {$r=Fixture -Pending $true;try{Put (Join-Path $r '.claude/adoption-pending.json') '{}';$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "pending exit=$($x.Exit)";Assert ($x.Out-match'\[PENDING\] Bootstrap/adoption state') 'pending row missing';Assert ($x.Out-notmatch'\[MISSING\] Stack toolchain') 'dependent false alarm'}finally{Remove-Item -Recurse -Force $r}}
It 'missing hook file exits one' {$r=Fixture -MissingHook $true;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 1) "exit=$($x.Exit)";Assert ($x.Out-match'\[MISSING\] Hook files') 'missing hook row absent'}finally{Remove-Item -Recurse -Force $r}}
It 'bare-name wired shell is portable CANT-VERIFY and does not change exit' {$r=Fixture -Shell 'doctor-shell-bare-name' -Pending $true;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');$parsed=Parse-DoctorResult $x;Assert ($parsed.Rows['Wired hook shell'].State-eq'CANT-VERIFY') "state=$($parsed.Rows['Wired hook shell'].State)";Assert ($parsed.Rows['Wired hook shell'].Detail-match'portable bare interpreter name doctor-shell-bare-name') 'portable wording absent';Assert ($parsed.Rows['Wired hook shell'].Detail-notmatch'pin an absolute') 'obsolete pin remediation remains'}finally{Remove-Item -Recurse -Force $r}}
It 'existing absolute wired shell is OK only on this machine' {$shell=[IO.Path]::GetTempFileName();$r=Fixture -Shell $shell -Pending $true;try{$wired=(Get-Content -Raw (Join-Path $r '.claude/settings.json')|ConvertFrom-Json).hooks.PreToolUse[0].hooks[0].command;Assert ($wired-eq('"'+$shell+'" -File .claude/hooks/guard.ps1')) "fixture did not receive one path: $wired";$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[OK\] Wired hook shell - wired interpreter paths exist on this machine:') "scoped OK row absent: $($x.Out)"}finally{Remove-Item -Recurse -Force $r;Remove-Item -Force -ErrorAction SilentlyContinue $shell}}
It 'missing absolute wired shell restores portable wiring and exits one' {$shell=(Join-Path ([IO.Path]::GetTempPath()) 'doctor-missing/interpreter.exe');$r=Fixture -Shell $shell -Pending $true;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 1) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[MISSING\] Wired hook shell - the configured machine-specific interpreter path is absent on this machine:') "MISSING row absent: $($x.Out)";Assert ($x.Out-match'restore portable bare-name wiring') "portable remediation absent: $($x.Out)"}finally{Remove-Item -Recurse -Force $r}}
if($winPs){It 'PowerShell twin runs under Windows PowerShell 5.1' {$r=Fixture;try{$x=RunPsHost $winPs (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "5.1 exit=$($x.Exit): $($x.Out) $($x.Err)";Assert ($x.Out-match'Enforcement is only FULL') '5.1 output incomplete'}finally{Remove-Item -Recurse -Force $r}}}else{Skip 'Windows PowerShell 5.1 compatibility' 'Windows PowerShell 5.1 is genuinely absent on this host' -Invariant}
if($bash){
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
        $validSettings=Get-Content -Raw (Join-Path $r '.claude/settings.json')
        $validCopilot=Get-Content -Raw (Join-Path $r '.github/hooks/hooks.json')
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
                $env:PATH=$sbin
                if($bash-match'\\Git\\bin\\bash\.exe$'){
                    if($PSVersionTable.PSEdition-eq'Desktop'){
                        $controlledPath=$env:PATH
                        [Environment]::SetEnvironmentVariable('Path',$null,'Process')
                        [Environment]::SetEnvironmentVariable('PATH',$controlledPath,'Process')
                    }
                    $posixBin=ConvertTo-PosixPath $sbin;$posixBash=ConvertTo-PosixPath $bash
                    $probeScript='while [ "$#" -gt 2 ]; do shift; done; [ "$#" -eq 2 ] || exit 64; PATH="$1"; export PATH; hash -r; if "$2" -c "command -v copilot >/dev/null 2>&1"; then printf "yes\n"; else printf "no\n"; fi'
                    $probe=Invoke-RawProcess -FileName $bash -Arguments @('--noprofile','--norc','-s','_',$posixBin,$posixBash) -Stdin $probeScript
                    Assert ($probe.Exit-eq 0) "setup $($case.Name): Bash probe exit=$($probe.Exit); stderr='$($probe.Err)'"
                    Assert ($probe.Err-ceq '') "setup $($case.Name): Bash probe stderr='$($probe.Err)'"
                    Assert (($probe.Out-ceq'yes')-or($probe.Out-ceq'no')) "setup $($case.Name): Bash probe sentinel='$($probe.Out)'"
                    $sSetup=($probe.Out-ceq'yes')
                }
                else{$null=& $bash -c 'command -v copilot >/dev/null 2>&1';$sSetup=($LASTEXITCODE-eq 0)}
                Assert ($sSetup-eq$case.S) "setup $($case.Name): Bash visibility=$sSetup"
                $s=Run (Join-Path $r 'scripts/framework-doctor.sh');$c=Compare-DoctorResults $p $s $case.Expected
                $pHas=$c.PowerShell.Rows['Copilot surface'].Detail-match'CLI is available';$sHas=$c.Bash.Rows['Copilot surface'].Detail-match'CLI is available'
                Assert ($pHas-eq$case.P) "result $($case.Name): PowerShell detail='$($c.PowerShell.Rows['Copilot surface'].Detail)'";Assert ($sHas-eq$case.S) "result $($case.Name): Bash detail='$($c.Bash.Rows['Copilot surface'].Detail)'"
            }finally{Remove-Item -Recurse -Force $pbin,$sbin}
        }
        $pbin=New-ParserProbeBin $bash $false $false;$sbin=New-ParserProbeBin $bash $false $false dotnet $true
        try{
            $pdoc=Join-Path $r 'scripts/framework-doctor.ps1';$ptext=[IO.File]::ReadAllText($pdoc);$pmutated=$ptext.Replace('$copilotReadFailed = $false','$copilotReadFailed = $true');Assert ($pmutated-ne$ptext) 'PowerShell unreadable-Copilot mutation missed';Put $pdoc $pmutated $true
            $sdoc=Join-Path $r 'scripts/framework-doctor.sh';$stext=[IO.File]::ReadAllText($sdoc);$smutated=$stext.Replace('copilot_read_failed=0','copilot_read_failed=1');Assert ($smutated-ne$stext) 'Bash unreadable-Copilot mutation missed';Put $sdoc $smutated
            $env:PATH=$pbin;$p=Run $pdoc;$env:PATH=$sbin;$s=Run $sdoc;$c=Compare-DoctorResults $p $s
            Assert ($c.PowerShell.Rows['Copilot surface'].State-eq'CANT-VERIFY') "PowerShell unreadable hooks JSON was not CANT-VERIFY: $($p.Out)"
            Assert ($c.Bash.Rows['Copilot surface'].State-eq'CANT-VERIFY') "Bash unreadable hooks JSON was not CANT-VERIFY: $($s.Out)"
            foreach($rowName in @('Hook files','Guard JSON parser')){Assert ($c.PowerShell.Rows[$rowName].State-eq'CANT-VERIFY'-and$c.Bash.Rows[$rowName].State-eq'CANT-VERIFY') "unreadable hooks JSON did not make $rowName CANT-VERIFY on both twins"}
            Copy-Item -LiteralPath $doctorPs -Destination $pdoc -Force;Copy-Item -LiteralPath $doctorSh -Destination $sdoc -Force
            $ptext=[IO.File]::ReadAllText($pdoc);$pmutated=$ptext.Replace('$settingsReadFailed = $false','$settingsReadFailed = $true');Assert ($pmutated-ne$ptext) 'PowerShell unreadable-settings mutation missed';Put $pdoc $pmutated $true
            $stext=[IO.File]::ReadAllText($sdoc);$smutated=$stext.Replace('settings_read_failed=0','settings_read_failed=1');Assert ($smutated-ne$stext) 'Bash unreadable-settings mutation missed';Put $sdoc $smutated
            $env:PATH=$pbin;$p=Run $pdoc;$env:PATH=$sbin;$s=Run $sdoc;$c=Compare-DoctorResults $p $s
            foreach($rowName in @('Wired hook shell','Hook files','Guard JSON parser')){Assert ($c.PowerShell.Rows[$rowName].State-eq'CANT-VERIFY'-and$c.Bash.Rows[$rowName].State-eq'CANT-VERIFY') "unreadable settings did not make $rowName CANT-VERIFY on both twins"}
            Copy-Item -LiteralPath $doctorPs -Destination $pdoc -Force;Copy-Item -LiteralPath $doctorSh -Destination $sdoc -Force
            foreach($invalidSettings in @(
                @{Label='junk-suffixed';Json='{"command":"bash .claude/hooks/guard.sh" junk'},
                @{Label='trailing-comma';Json='{"command":"bash .claude/hooks/guard.sh",}'},
                @{Label='single-quoted';Json="{'command':'bash .claude/hooks/guard.sh'}"},
                @{Label='non-finite';Json='{"command":"bash .claude/hooks/guard.sh","probe":NaN}'},
                @{Label='leading-zero';Json='{"command":"bash .claude/hooks/guard.sh","probe":01}'},
                @{Label='uppercase-command';Json='{"Command":"bash .claude/hooks/guard.sh"}'}
            )){
                Put (Join-Path $r '.claude/settings.json') $invalidSettings.Json
                $env:PATH=$pbin;$p=Run $pdoc;$env:PATH=$sbin;$s=Run $sdoc;$c=Compare-DoctorResults $p $s
                Assert ($c.PowerShell.Rows['Wired hook shell'].State-eq'MISSING'-and$c.Bash.Rows['Wired hook shell'].State-eq'MISSING') "$($invalidSettings.Label) settings with a plausible command was treated as live registration evidence"
            }
            Put (Join-Path $r '.claude/settings.json') $validSettings
            foreach($invalidCopilot in @(
                @{Label='junk-suffixed';Json='{"hooks":{"preToolUse":[{"bash":".claude/hooks/guard.sh"}]} junk'},
                @{Label='trailing-comma';Json='{"hooks":{"preToolUse":[{"bash":".claude/hooks/guard.sh"}]},}'},
                @{Label='single-quoted';Json="{'hooks':{'preToolUse':[{'bash':'.claude/hooks/guard.sh'}]}}"},
                @{Label='non-finite';Json='{"hooks":{"preToolUse":[{"bash":".claude/hooks/guard.sh"}]},"probe":NaN}'},
                @{Label='leading-zero';Json='{"hooks":{"preToolUse":[{"bash":".claude/hooks/guard.sh"}]},"probe":01}'}
            )){
                Put (Join-Path $r '.github/hooks/hooks.json') $invalidCopilot.Json
                $env:PATH=$pbin;$p=Run $pdoc;$env:PATH=$sbin;$s=Run $sdoc;$c=Compare-DoctorResults $p $s
                foreach($rowName in @('Hook files','Guard JSON parser','Copilot surface')){Assert ($c.PowerShell.Rows[$rowName].State-eq'MISSING'-and$c.Bash.Rows[$rowName].State-eq'MISSING') "$($invalidCopilot.Label) hooks JSON did not make $rowName MISSING on both twins"}
            }
            Put (Join-Path $r '.github/hooks/hooks.json') $validCopilot
        }finally{Remove-Item -Recurse -Force $pbin,$sbin}
    }finally{
        if($PSVersionTable.PSEdition-eq'Desktop'){
            [Environment]::SetEnvironmentVariable('Path',$null,'Process')
            [Environment]::SetEnvironmentVariable('PATH',$old,'Process')
        }else{$env:PATH=$old}
        Remove-Item -Recurse -Force $r
    }
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
It 'twins agree outside the parser row when liveness is absent, empty, whitespace, and present' {
    $r=Fixture -Shell 'bash' -Pending $true;$bin=New-ParserProbeBin $bash;$old=$env:PATH
    try{
        $env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$bin+[IO.Path]::PathSeparator+$old
        foreach($world in @(
            [pscustomobject]@{Create=$false;Content='';State='CANT-VERIFY'},
            [pscustomobject]@{Create=$true;Content='';State='CANT-VERIFY'},
            [pscustomobject]@{Create=$true;Content='   ';State='CANT-VERIFY'},
            [pscustomobject]@{Create=$true;Content='2026-07-31T12:34:56Z';State='OK'}
        )){
            $path=Join-Path $r '.claude/.state/last-session-start'
            Remove-Item -Force -ErrorAction SilentlyContinue $path
            if($world.Create){New-Item -ItemType Directory -Force (Split-Path $path -Parent)|Out-Null;Put $path $world.Content}
            $p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$c=Compare-DoctorResults $p $s @('Guard JSON parser')
            Assert ($c.PowerShell.Rows['Hook liveness'].State-eq$world.State) "PowerShell liveness state=$($c.PowerShell.Rows['Hook liveness'].State), expected=$($world.State)"
            Assert ($c.Bash.Rows['Hook liveness'].State-eq$world.State) "Bash liveness state=$($c.Bash.Rows['Hook liveness'].State), expected=$($world.State)"
            Assert ($c.PowerShell.Rows['Guard JSON parser'].State-eq'CANT-VERIFY') 'PowerShell parser state'
            Assert ($c.Bash.Rows['Guard JSON parser'].State-eq'OK') 'Bash parser state'
        }
    }finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$bin}
}
It 'hook registrations resolve arguments and every command in minified JSON' {
    $r=Fixture -Shell 'bash' -Pending $true -HookArguments $true;$bin=New-ParserProbeBin $bash;$old=$env:PATH
    try{
        $env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$bin+[IO.Path]::PathSeparator+$old
        $p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$c=Compare-DoctorResults $p $s @('Guard JSON parser')
        Assert ($c.PowerShell.Rows['Hook files'].State-eq'OK') 'PowerShell argument-path hook row';Assert ($c.Bash.Rows['Hook files'].State-eq'OK') 'Bash argument-path hook row'
        Put (Join-Path $r '.claude/settings.json') '{"hooks":{"PreToolUse":[{"hooks":[{"command":"bash .claude/hooks/guard.sh --mode scan"},{"command":"bash .claude/hooks/missing.sh --mode scan"}]}]}}'
        $p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$c=Compare-DoctorResults $p $s @('Guard JSON parser')
        Assert ($c.PowerShell.Rows['Hook files'].State-eq'MISSING') 'PowerShell did not inspect every minified command';Assert ($c.Bash.Rows['Hook files'].State-eq'MISSING') 'Bash did not inspect every minified command'
    }finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$bin}
}
# Non-pending cases reach Mirror and Audit; the controlled template matrix below separately forces
# every Stack-toolchain marker with both available and absent command sets.
It 'twins agree outside the parser row on non-pending mirror pass' {$r=Fixture -Shell 'bash';$bin=New-ParserProbeBin $bash;$old=$env:PATH;try{$env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$bin+[IO.Path]::PathSeparator+$old;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$c=Compare-DoctorResults $p $s @('Guard JSON parser');Assert ($c.PowerShell.Rows['Mirror and version integrity'].State-eq'OK') 'PS mirror row'}finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$bin}}
It 'twins agree outside the parser row on non-pending mirror failure' {
    $r=Fixture -Shell 'bash';$bin=New-ParserProbeBin $bash;$old=$env:PATH
    try{
        $env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$bin+[IO.Path]::PathSeparator+$old
        foreach($world in @(
            [pscustomobject]@{Status=3;State='MISSING'},
            [pscustomobject]@{Status=2;State='CANT-VERIFY'},
            [pscustomobject]@{Status=1;State='CANT-VERIFY'}
        )){
            Put (Join-Path $r 'scripts/template-checks.ps1') ([char]0xFEFF+"exit $($world.Status)") $false
            Put (Join-Path $r 'scripts/template-checks.sh') "#!/usr/bin/env bash`nexit $($world.Status)`n"
            $p=Run (Join-Path $r 'scripts/framework-doctor.ps1')
            $s=Run (Join-Path $r 'scripts/framework-doctor.sh')
            $c=Compare-DoctorResults $p $s @('Guard JSON parser')
            $pr=$c.PowerShell.Rows['Mirror and version integrity'];$sr=$c.Bash.Rows['Mirror and version integrity']
            Assert ($pr.State-eq$world.State) "PowerShell checker status $($world.Status) mapped to $($pr.State), expected $($world.State)"
            Assert ($sr.State-eq$world.State) "bash checker status $($world.Status) mapped to $($sr.State), expected $($world.State)"
            Assert ($pr.Detail-notmatch'/generate-copilot'-and$sr.Detail-notmatch'/generate-copilot') "checker status $($world.Status) retained guessed remediation"
            if($world.Status-eq 3){
                $expected='template-checks reported integrity findings. Run it directly and follow its exact findings.'
                Assert ($pr.Detail-ceq$expected-and$sr.Detail-ceq$expected) "verified-finding guidance changed: PS='$($pr.Detail)' SH='$($sr.Detail)'"
            }else{
                $needle="did not complete (exit $($world.Status))"
                Assert ($pr.Detail.Contains($needle)-and$pr.Detail.Contains('UNKNOWN rather than missing')) "PowerShell abnormal status detail changed: $($pr.Detail)"
                Assert ($sr.Detail.Contains($needle)-and$sr.Detail.Contains('UNKNOWN rather than missing')) "bash abnormal status detail changed: $($sr.Detail)"
            }
        }
    }finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$bin}
}
It 'Stack toolchain rows use byte-identical doctor-process wording for every template and outcome' {
    $old=$env:PATH
    try{
        foreach($template in @('dotnet','angular','monorepo')){
            $required=if($template-eq'dotnet'){@('dotnet')}elseif($template-eq'angular'){@('node','npx')}else{@('dotnet','node','npx')}
            foreach($present in @($true,$false)){
                $r=Fixture -Pending $false -CopilotBash $false -Template $template -AngularEvidence package;$pbin=New-ParserProbeBin $bash $true $true $template;$sbin=New-ParserProbeBin $bash $true $true $template $true
                try{
                    if($present){Add-FakeToolCommands $pbin $bash $required;Add-FakeToolCommands $sbin $bash $required}
                    $env:PATH=$pbin;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$pp=Parse-DoctorResult $p
                    $env:PATH=$sbin;$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$sp=Parse-DoctorResult $s
                    $expectedState=if($present){'OK'}else{'MISSING'};$pr=$pp.Rows['Stack toolchain'];$sr=$sp.Rows['Stack toolchain'];Assert ($pr.State-eq$expectedState) "PS $template present=$present state=$($pr.State)";Assert ($sr.State-eq$pr.State) "SH $template state=$($sr.State), PS=$($pr.State)";Assert ($pr.Detail-eq$sr.Detail) "Stack detail mismatch PS='$($pr.Detail)' SH='$($sr.Detail)'";Assert ($pr.Detail-match'this doctor process environment') "generic environment boundary absent: $($pr.Detail)";Assert ($pr.Detail-notmatch'PowerShell doctor|Bash doctor') "shell-specific environment leaked: $($pr.Detail)"
                    if($present){$selected=if($template-eq'dotnet'){'.NET file'}elseif($template-eq'angular'){'Angular file'}else{'.NET or Angular file'};$pc=Get-StackCanary $pp;$sc=Get-StackCanary $sp;Assert ($pc-match[regex]::Escape($selected)) "PS $template canary did not select its constructible application world: $pc";Assert ($sc-eq$pc) "SH $template canary mismatch: PS='$pc' SH='$sc'"}
                }finally{Remove-Item -Recurse -Force $r,$pbin,$sbin}
            }
        }
        foreach($cross in @(
            @{Template='dotnet';Remove='App.csproj';Add='PACKAGE.JSON';Content='{"dependencies":{"@angular/core":"20.0.0"}}';Tools=@('node','npx');Label='Angular'},
            @{Template='angular';Remove='angular.json';Add='APP.CSPROJ';Content='<Project Sdk="Microsoft.NET.Sdk" />';Tools=@('dotnet');Label='.NET'}
        )){
            $r=Fixture -Pending $false -CopilotBash $false -Template $cross.Template;$pbin=New-ParserProbeBin $bash $true $true $cross.Template;$sbin=New-ParserProbeBin $bash $true $true $cross.Template $true
            try{
                Remove-Item -LiteralPath (Join-Path $r $cross.Remove) -Force;Put (Join-Path $r $cross.Add) $cross.Content
                Add-FakeToolCommands $pbin $bash $cross.Tools;Add-FakeToolCommands $sbin $bash $cross.Tools
                $env:PATH=$pbin;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$pp=Parse-DoctorResult $p
                $env:PATH=$sbin;$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$sp=Parse-DoctorResult $s
                Assert ($pp.Rows['Stack toolchain'].State-eq'OK'-and$pp.Rows['Stack toolchain'].Detail-match[regex]::Escape($cross.Label)) "PowerShell erased cross-template $($cross.Label) evidence: $($p.Out)"
                Assert ($sp.Rows['Stack toolchain'].State-eq$pp.Rows['Stack toolchain'].State-and$sp.Rows['Stack toolchain'].Detail-eq$pp.Rows['Stack toolchain'].Detail) "cross-template $($cross.Label) mismatch: PS='$($pp.Rows['Stack toolchain'].Detail)' SH='$($sp.Rows['Stack toolchain'].Detail)'"
                $pc=Get-StackCanary $pp;$sc=Get-StackCanary $sp;Assert ($pc-match[regex]::Escape($cross.Label+' file')) "PowerShell cross-template canary did not select $($cross.Label): $pc";Assert ($sc-eq$pc) "Bash cross-template canary mismatch: PS='$pc' SH='$sc'"
            }finally{Remove-Item -Recurse -Force $r,$pbin,$sbin}
        }
        $r=Fixture -Pending $false -CopilotBash $false -Template dotnet
        $pbin=New-ParserProbeBin $bash $true $true dotnet;$sbin=New-ParserProbeBin $bash $true $true dotnet $true
        try{
            Remove-Item -LiteralPath (Join-Path $r 'App.csproj') -Force
            New-Item -ItemType Directory -Force (Join-Path $r 'warehouse')|Out-Null
            Put (Join-Path $r 'Warehouse.sln') 'Microsoft Visual Studio Solution File, Format Version 12.00'
            Put (Join-Path $r 'warehouse/Warehouse.sqlproj') '<Project Sdk="Microsoft.Build.Sql" />'
            Put (Join-Path $r 'warehouse/DimCustomer.sql') 'CREATE TABLE dw.DimCustomer (CustomerKey int, IsCurrent bit);'
            Put (Join-Path $r 'warehouse/usp_LoadCustomer.sql') 'CREATE PROC etl.usp_LoadCustomer @BatchId int AS SELECT 1;'
            $env:PATH=$pbin;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$pp=Parse-DoctorResult $p
            $env:PATH=$sbin;$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$sp=Parse-DoctorResult $s
            $pr=$pp.Rows['Stack toolchain'];$sr=$sp.Rows['Stack toolchain']
            Assert ($pr.State-eq'OK') "PowerShell warehouse-only toolchain state=$($pr.State): $($pr.Detail)"
            Assert ($sr.State-eq$pr.State) "Bash warehouse-only state=$($sr.State), PowerShell=$($pr.State)"
            Assert ($pr.Detail-eq$sr.Detail) "warehouse-only toolchain detail mismatch PS='$($pr.Detail)' SH='$($sr.Detail)'"
            Assert ($pr.Detail-match'not applicable') "warehouse-only result did not name non-applicability: $($pr.Detail)"
            Assert ($pr.Detail-match'no repository-evidenced') "warehouse-only result did not name the evidence boundary: $($pr.Detail)"
            $pc=Get-StackCanary $pp;$sc=Get-StackCanary $sp
            Assert ($pc-match'not applicable: no repository-evidenced') "PowerShell warehouse-only canary remained applicable: $pc"
            Assert ($sc-eq$pc) "Bash warehouse-only canary mismatch: PS='$pc' SH='$sc'"
        }finally{Remove-Item -Recurse -Force $r,$pbin,$sbin}
        $r=Fixture -Pending $false -CopilotBash $false -Template monorepo
        $pbin=New-ParserProbeBin $bash $true $true monorepo;$sbin=New-ParserProbeBin $bash $true $true monorepo $true
        try{
            Remove-Item -LiteralPath (Join-Path $r 'App.csproj'),(Join-Path $r 'angular.json') -Force
            New-Item -ItemType Directory -Force (Join-Path $r 'NODE_MODULES/generated'),(Join-Path $r 'BIN'),(Join-Path $r 'OBJ'),(Join-Path $r 'DIST')|Out-Null
            Put (Join-Path $r 'NODE_MODULES/generated/package.json') '{"dependencies":{"@angular/core":"20.0.0"}}'
            Put (Join-Path $r 'BIN/App.sln') 'generated solution';Put (Join-Path $r 'OBJ/App.csproj') '<Project />';Put (Join-Path $r 'DIST/angular.json') '{"version":1}'
            $env:PATH=$pbin;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$pp=Parse-DoctorResult $p
            $env:PATH=$sbin;$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$sp=Parse-DoctorResult $s
            Assert ($pp.Rows['Stack toolchain'].State-eq'OK'-and$pp.Rows['Stack toolchain'].Detail-match'not applicable') "PowerShell treated generated/dependency evidence as an app: $($p.Out)"
            Assert ($sp.Rows['Stack toolchain'].State-eq$pp.Rows['Stack toolchain'].State-and$sp.Rows['Stack toolchain'].Detail-eq$pp.Rows['Stack toolchain'].Detail) "generated/dependency scan mismatch: PS='$($pp.Rows['Stack toolchain'].Detail)' SH='$($sp.Rows['Stack toolchain'].Detail)'"
        }finally{Remove-Item -Recurse -Force $r,$pbin,$sbin}
        $r=Fixture -Pending $false -CopilotBash $false -Template dotnet
        $pbin=New-ParserProbeBin $bash $true $true dotnet;$sbin=New-ParserProbeBin $bash $true $true dotnet $true
        try{
            New-Item -ItemType Directory -Force (Join-Path $r '.src')|Out-Null
            Move-Item -LiteralPath (Join-Path $r 'App.csproj') -Destination (Join-Path $r '.src/App.csproj')
            Add-FakeToolCommands $pbin $bash @('dotnet');Add-FakeToolCommands $sbin $bash @('dotnet')
            $env:PATH=$pbin;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$pp=Parse-DoctorResult $p
            $env:PATH=$sbin;$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$sp=Parse-DoctorResult $s
            Assert ($pp.Rows['Stack toolchain'].State-eq'OK'-and$pp.Rows['Stack toolchain'].Detail-match'\.NET') "PowerShell omitted a non-excluded hidden source directory: $($p.Out)"
            Assert ($sp.Rows['Stack toolchain'].State-eq$pp.Rows['Stack toolchain'].State-and$sp.Rows['Stack toolchain'].Detail-eq$pp.Rows['Stack toolchain'].Detail) "hidden-source scan mismatch: PS='$($pp.Rows['Stack toolchain'].Detail)' SH='$($sp.Rows['Stack toolchain'].Detail)'"
        }finally{Remove-Item -Recurse -Force $r,$pbin,$sbin}
        foreach($stampCase in @(
            @{Name='malformed JSON with plausible template';Stamp='junk {"template":"dotnet"}';JqTemplate='dotnet';BreakJq=$true;State='MISSING';Detail='invalid JSON';Exit=1},
            @{Name='trailing-comma JSON';Stamp='{"template":"dotnet",}';JqTemplate='dotnet';BreakJq=$true;State='MISSING';Detail='invalid JSON';Exit=1},
            @{Name='commented JSON';Stamp='{/*comment*/"template":"dotnet"}';JqTemplate='dotnet';BreakJq=$true;State='MISSING';Detail='invalid JSON';Exit=1},
            @{Name='unquoted-key JSON';Stamp='{template:"dotnet"}';JqTemplate='dotnet';BreakJq=$true;State='MISSING';Detail='invalid JSON';Exit=1},
            @{Name='non-finite JSON constant';Stamp='{"template":"dotnet","probe":NaN}';JqTemplate='dotnet';BreakJq=$true;State='MISSING';Detail='invalid JSON';Exit=1},
            @{Name='leading-zero JSON number';Stamp='{"template":"dotnet","probe":01}';JqTemplate='dotnet';BreakJq=$true;State='MISSING';Detail='invalid JSON';Exit=1},
            @{Name='uppercase template property';Stamp='{"Template":"dotnet"}';JqTemplate='';BreakJq=$false;State='MISSING';Detail='lacks the required non-empty string';Exit=1},
            @{Name='valid JSON without template';Stamp='{}';JqTemplate='';BreakJq=$false;State='MISSING';Detail='lacks the required non-empty string';Exit=1},
            @{Name='valid one-object JSON array';Stamp='[{"template":"dotnet"}]';JqTemplate='';BreakJq=$false;State='MISSING';Detail='lacks the required non-empty string';Exit=1},
            @{Name='valid JSON with whitespace-only template';Stamp='{"template":"   "}';JqTemplate='   ';BreakJq=$false;State='MISSING';Detail='lacks the required non-empty string';Exit=1},
            @{Name='valid JSON with unsupported template';Stamp='{"template":"foo"}';JqTemplate='foo';BreakJq=$false;State='MISSING';Detail='unsupported template';Exit=1}
        )){
            $r=Fixture -Pending $true;$pbin=New-ParserProbeBin $bash $true $true dotnet;$sbin=New-ParserProbeBin $bash $true $true $stampCase.JqTemplate $true
            try{
                Put (Join-Path $r '.claude/framework-version.json') $stampCase.Stamp
                if($stampCase.BreakJq){Put (Join-Path $sbin 'jq') "#!/bin/sh`nIFS= read -r input || :`n[ `"`$input`" = '{}' ] && exit 0`nexit 4`n"}
                $env:PATH=$pbin;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1')
                $env:PATH=$sbin;$s=Run (Join-Path $r 'scripts/framework-doctor.sh')
                $pLine=[regex]::Match(($p.Out-replace"`r",''),'(?m)^\[(MISSING|CANT-VERIFY)\] Install state - .+$').Value
                $sLine=[regex]::Match(($s.Out-replace"`r",''),'(?m)^\[(MISSING|CANT-VERIFY)\] Install state - .+$').Value
                Assert ($p.Exit-eq$stampCase.Exit-and$s.Exit-eq$stampCase.Exit) "$($stampCase.Name) exits differ: PS=$($p.Exit), SH=$($s.Exit)"
                Assert ($pLine-match('^\['+$stampCase.State+'\].*'+[regex]::Escape($stampCase.Detail))) "PowerShell $($stampCase.Name) row wrong: $($p.Out)"
                Assert ($sLine-eq$pLine) "$($stampCase.Name) install-state mismatch: PS='$pLine' SH='$sLine'"
            }finally{Remove-Item -Recurse -Force $r,$pbin,$sbin}
        }
        $realJq=Resolve-HostJq
        if($realJq){
            foreach($realJqCase in @(@{Name='scalar';Stamp='"dotnet"'},@{Name='one-object array';Stamp='[{"template":"dotnet"}]'})){
                $r=Fixture -Shell 'bash' -Pending $true
                try{
                    Put (Join-Path $r '.claude/framework-version.json') $realJqCase.Stamp
                    $s=Invoke-Sandboxed -Bash $bash -ScriptPath (Join-Path $r 'scripts/framework-doctor.sh') -Utilities @('dirname','sed','grep','sort','paste','head') -FakeBins @{jq=(New-ExecShim $realJq)}
                    Assert ($s.Exit-eq 1-and$s.Out-match'\[MISSING\] Install state - \.claude/framework-version\.json is valid JSON but lacks the required non-empty string') "real jq did not classify valid $($realJqCase.Name) JSON as missing-template: $($s.Out)`nSTDERR: $($s.Err)"
                }finally{Remove-Item -Recurse -Force $r}
            }
        }
        if(Resolve-HostPython){
            $r=Fixture -Shell 'bash' -Pending $true
            try{
                $s=Invoke-Sandboxed -Bash $bash -ScriptPath (Join-Path $r 'scripts/framework-doctor.sh') -Utilities @('dirname','sed','grep','sort','paste','head') -FakeBins @{jq="#!/usr/bin/env bash`nexit 49`n"} -ExposeInterpreterAs python
                Assert ($s.Out-match'\[OK\] Install state - template=dotnet') "broken jq suppressed the working Python install-state fallback: $($s.Out)`nSTDERR: $($s.Err)"
                Assert ($s.Out-match'\[OK\] Guard JSON parser') "broken jq suppressed the working Python guard-parser fallback: $($s.Out)`nSTDERR: $($s.Err)"
                Assert ($s.Out-match'\[OK\] Copilot surface') "broken jq was misreported as invalid hooks JSON instead of falling back to Python: $($s.Out)`nSTDERR: $($s.Err)"
            }finally{Remove-Item -Recurse -Force $r}
        }
        $r=Fixture -Pending $true;$pbin=New-ParserProbeBin $bash;$sbin=New-ParserProbeBin $bash $true $true dotnet $true
        try{
            $pdoc=Join-Path $r 'scripts/framework-doctor.ps1';$ptext=[IO.File]::ReadAllText($pdoc);$pmutated=$ptext.Replace('$stampReadFailed = $false','$stampReadFailed = $true');Assert ($pmutated-ne$ptext) 'PowerShell unreadable-stamp mutation missed';Put $pdoc $pmutated $true
            $sdoc=Join-Path $r 'scripts/framework-doctor.sh';$stext=[IO.File]::ReadAllText($sdoc);$smutated=$stext.Replace('stamp_read_failed=0','stamp_read_failed=1');Assert ($smutated-ne$stext) 'Bash unreadable-stamp mutation missed';Put $sdoc $smutated
            $env:PATH=$pbin;$p=Run $pdoc;$env:PATH=$sbin;$s=Run $sdoc
            Assert ($p.Exit-eq 0-and$s.Exit-eq 0) "unreadable stamp changed exit: PS=$($p.Exit), SH=$($s.Exit)"
            Assert (($p.Out-replace"`r",'')-match'\[CANT-VERIFY\] Install state - \.claude/framework-version\.json exists but could not be read') "PowerShell unreadable stamp row absent: $($p.Out)"
            Assert (($s.Out-replace"`r",'')-match'\[CANT-VERIFY\] Install state - \.claude/framework-version\.json exists but could not be read') "Bash unreadable stamp row absent: $($s.Out)"
        }finally{Remove-Item -Recurse -Force $r,$pbin,$sbin}
        $r=Fixture -Pending $false -CopilotBash $false -Template dotnet
        $pbin=New-ParserProbeBin $bash $true $true dotnet;$sbin=New-ParserProbeBin $bash $true $true dotnet $true
        try{
            Remove-Item -LiteralPath (Join-Path $r 'App.csproj') -Force
            foreach($markerCase in @(
                @{File='package.json';Content='{"dependencies":{"@ANGULAR/CORE":"20.0.0"},"scripts":{"probe":"echo \"@angular/core\": fake"}}';State='OK';Label='escaped package-string/uppercase key'},
                @{File='package.json';Content='{"scripts":{"@angular/core":"echo fake"}}';State='OK';Label='non-dependency package key'},
                @{File='nx.json';Content='{"notes":"do not use angular-devkit"}';State='OK';Label='Nx prose'},
                @{File='nx.json';Content='{"notes":"@nx/angular/plugin is not enabled"}';State='OK';Label='Nx package-prefix prose'},
                @{File='nx.json';Content='{"notes":{"plugin":"@nx/angular/plugin"}}';State='OK';Label='nested notes plugin field'},
                @{File='nx.json';Content='{"plugins":["@nx/angular"]}';State='OK';Label='bare Nx token'},
                @{File='nx.json';Content='{"plugins":[{"Plugin":"@nx/angular/plugin"}]}';State='OK';Label='uppercase Nx plugin field'},
                @{File='project.json';Content='{"targets":{"build":{"Executor":"@angular-devkit/build-angular:browser"}}}';State='OK';Label='uppercase Nx executor field'},
                @{File='project.json';Content='{"targets":{"build":{"executor":"@angular-devkit/build-angular:browser"}}}';State='MISSING';Label='schema-positioned target executor'},
                @{File='package.json';Content='{"dependencies":{"@angular/core":"20.0.0"},"decimal":0.01,"exponent":1e01,"negativeExponent":1e-01}';State='MISSING';Label='valid JSON numeric controls'},
                @{File='package.json';Content='{"dependencies":{"@angular/core":"20.0.0"} junk';State='CANT-VERIFY';Label='malformed plausible package'},
                @{File='angular.json';Content='{"version":1 junk';State='CANT-VERIFY';Label='malformed Angular workspace'},
                @{File='angular.json';Content='[]';State='CANT-VERIFY';Label='array Angular workspace'},
                @{File='package.json';Content='"@angular/core"';State='CANT-VERIFY';Label='scalar package marker'},
                @{File='angular.json';Content='{"version":1,}';State='CANT-VERIFY';Label='trailing-comma Angular workspace'},
                @{File='package.json';Content="{'dependencies':{'@angular/core':'20.0.0'}}";State='CANT-VERIFY';Label='single-quoted package marker'},
                @{File='nx.json';Content='{plugin:"@nx/angular"}';State='CANT-VERIFY';Label='unquoted-key Nx marker'},
                @{File='package.json';Content='{"dependencies":{"@angular/core":"20.0.0"},"probe":NaN}';State='CANT-VERIFY';Label='non-finite package constant'},
                @{File='package.json';Content='{"dependencies":{"@angular/core":"20.0.0"},"probe":01}';State='CANT-VERIFY';Label='leading-zero package number'}
            )){
                Remove-Item -LiteralPath (Join-Path $r 'angular.json'),(Join-Path $r 'package.json'),(Join-Path $r 'nx.json'),(Join-Path $r 'project.json') -Force -ErrorAction SilentlyContinue;Put (Join-Path $r $markerCase.File) $markerCase.Content
                $env:PATH=$pbin;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$pp=Parse-DoctorResult $p
                $env:PATH=$sbin;$s=Run (Join-Path $r 'scripts/framework-doctor.sh');$sp=Parse-DoctorResult $s
                Assert ($pp.Rows['Stack toolchain'].State-eq$markerCase.State) "PowerShell $($markerCase.Label) marker state=$($pp.Rows['Stack toolchain'].State): $($p.Out)"
                if($markerCase.State-eq'OK'){Assert ($pp.Rows['Stack toolchain'].Detail-match'not applicable') "PowerShell treated $($markerCase.Label) as Angular evidence: $($p.Out)"}
                Assert ($sp.Rows['Stack toolchain'].State-eq$pp.Rows['Stack toolchain'].State-and$sp.Rows['Stack toolchain'].Detail-eq$pp.Rows['Stack toolchain'].Detail) "$($markerCase.Label) evidence mismatch: PS='$($pp.Rows['Stack toolchain'].Detail)' SH='$($sp.Rows['Stack toolchain'].Detail)'"
            }
        }finally{Remove-Item -Recurse -Force $r,$pbin,$sbin}
        $r=Fixture -Pending $false -CopilotBash $false -Template monorepo
        $pbin=New-ParserProbeBin $bash $true $true monorepo;$sbin=New-ParserProbeBin $bash $true $true monorepo $true
        try{
            $pdoc=Join-Path $r 'scripts/framework-doctor.ps1';$ptext=[IO.File]::ReadAllText($pdoc);$pmutated=$ptext.Replace('$markerScanFailed = $false','$markerScanFailed = $true');Assert ($pmutated-ne$ptext) 'PowerShell marker-scan failure mutation missed';Put $pdoc $pmutated $true
            $sdoc=Join-Path $r 'scripts/framework-doctor.sh';$stext=[IO.File]::ReadAllText($sdoc);$smutated=$stext.Replace('marker_scan_failed=0','marker_scan_failed=1');Assert ($smutated-ne$stext) 'Bash marker-scan failure mutation missed';Put $sdoc $smutated
            $env:PATH=$pbin;$p=Run $pdoc;$pp=Parse-DoctorResult $p
            $env:PATH=$sbin;$s=Run $sdoc;$sp=Parse-DoctorResult $s
            Assert ($pp.Rows['Stack toolchain'].State-eq'CANT-VERIFY') "PowerShell incomplete marker scan was not honest: $($p.Out)"
            Assert ($sp.Rows['Stack toolchain'].State-eq$pp.Rows['Stack toolchain'].State-and$sp.Rows['Stack toolchain'].Detail-eq$pp.Rows['Stack toolchain'].Detail) "incomplete marker scan mismatch: PS='$($pp.Rows['Stack toolchain'].Detail)' SH='$($sp.Rows['Stack toolchain'].Detail)'"
            $pc=Get-StackCanary $pp;$sc=Get-StackCanary $sp;Assert ($pc-match'cannot be verified') "PowerShell incomplete-marker canary remained actionable: $pc";Assert ($sc-eq$pc) "Bash incomplete-marker canary mismatch: PS='$pc' SH='$sc'"
        }finally{Remove-Item -Recurse -Force $r,$pbin,$sbin}
    }finally{$env:PATH=$old}
}
# Minimal native utilities the doctor itself exercises under a controlled PATH.
$doctorUtils = @('sed','grep')
It 'bash twin survives without jq or ANY working python and reports the guard inactive (no interpreter present at all)' {
    $r=Fixture -Shell 'bash' -Pending $true;$pbin=New-ParserProbeBin $bash $true $true;$old=$env:PATH
    try{
        $doc=Join-Path $r 'scripts/framework-doctor.sh'
        Remove-Item -Force (Join-Path $pbin 'jq')
        $env:PATH=$pbin;Assert ([bool](Get-Command copilot -ErrorAction SilentlyContinue)) 'setup: Copilot not visible to PowerShell'
        $p=Run (Join-Path $r 'scripts/framework-doctor.ps1')
        $s=Run $doc
        Assert ($s.Out-match'\[CANT-VERIFY\] Install state') "install-state parser boundary absent under restricted PATH: $($s.Out)`nSTDERR: $($s.Err)"
        Assert ($s.Out-match'\[CANT-VERIFY\] Guard JSON parser') "unverifiable registration/parser boundary absent: $($s.Out)`nSTDERR: $($s.Err)"
        Assert ($s.Out-match'\[PENDING\] Bootstrap/adoption state') 'grep fallback did not read pending state'
        $null=Compare-DoctorResults $p $s @('Install state','Wired hook shell','Hook files','Guard JSON parser','Copilot surface')
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
It 'bash twin does not accept the Microsoft Store alias stub as a working parser' {
    $r=Fixture -Shell 'bash' -Pending $true;$pbin=New-ParserProbeBin $bash $true $true;$old=$env:PATH
    try{
        $doc=Join-Path $r 'scripts/framework-doctor.sh'
        $stub="#!/usr/bin/env bash`nprintf 'Python was not found; run without arguments to install from the Microsoft Store, or disable this shortcut from Settings > Manage App Execution Aliases.\n' >&2`nexit 49`n"
        Remove-Item -Force (Join-Path $pbin 'jq');Put (Join-Path $pbin 'python') $stub
        $posixPython=ConvertTo-PosixPath (Join-Path $pbin 'python');$null=& $bash -c ('PATH="/usr/bin:/bin:/usr/local/bin:$PATH" chmod +x "{0}"' -f $posixPython) 2>$null;Assert ($LASTEXITCODE-eq 0) 'could not make Store-alias stub executable'
        $env:PATH=$pbin;$s=Run $doc
        Assert ($s.Out-match'\[CANT-VERIFY\] Guard JSON parser') "expected CANT-VERIFY while registrations and parser availability are both unverifiable, got: $($s.Out)`nSTDERR: $($s.Err)"
        Assert ($s.Out-notmatch'\[OK\] Guard JSON parser') "Store alias stub was accepted as a working interpreter: $($s.Out)"
    }finally{$env:PATH=$old;Remove-Item -Recurse -Force $r,$pbin}}
}else{Skip 'framework-doctor.sh parity' 'no bash found' -Invariant}
It 'pinned canary strings exist in the hooks they quote' {
    $hooks=(Resolve-Path (Join-Path $scripts '..\.claude\hooks')).Path
    foreach($f in @($doctorPs,$doctorSh)){
        $t=[IO.File]::ReadAllText($f)
        $finishStart=if($f-match'\.ps1$'){$t.IndexOf('function Finish {')}else{$t.IndexOf('finish() {')};$stackCanary=$t.IndexOf('[CANT-VERIFY] Agent-host stack toolchain');$summary=$t.IndexOf('Script-verifiable checks:')
        $finishText=if($finishStart-ge 0-and$stackCanary-gt$finishStart){$t.Substring($finishStart,$stackCanary-$finishStart)}else{''}
        $m=[regex]::Match($finishText,'Claude hooks - .*starts with "([^"]+)"');Assert $m.Success "no quoted session banner in $f"
        foreach($h in 'session-start.ps1','session-start.sh'){Assert ([IO.File]::ReadAllText((Join-Path $hooks $h)).Contains($m.Groups[1].Value)) "$h does not emit '$($m.Groups[1].Value)' quoted by $(Split-Path $f -Leaf)"}
        $m=[regex]::Match($t,'hook says "([^"]+)"');Assert $m.Success "no quoted guard message in $f"
        foreach($h in 'guard.ps1','guard.sh'){Assert ([IO.File]::ReadAllText((Join-Path $hooks $h)).Contains($m.Groups[1].Value)) "$h does not emit '$($m.Groups[1].Value)' quoted by $(Split-Path $f -Leaf)"}
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
