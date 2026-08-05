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
function Fixture([string]$Shell=$script:defaultShell,[bool]$Pending=$false,[bool]$MissingHook=$false,[bool]$HookArguments=$false) {
    $r=Join-Path ([IO.Path]::GetTempPath()) ('doctor-'+[guid]::NewGuid())
    New-Item -ItemType Directory -Force (Join-Path $r '.claude/hooks'),(Join-Path $r '.github/hooks'),(Join-Path $r '.github/instructions'),(Join-Path $r 'scripts')|Out-Null
    Put (Join-Path $r '.claude/framework-version.json') '{"template":"fixture","version":"0.32.0","applied":"2026-07-17"}'
    $claude="<!--`n  version: 0.32.0`n-->`n@.github/instructions/framework-rules.instructions.md`n# Fixture"
    if($Pending){$claude+="`nBOOTSTRAP_PENDING"}
    Put (Join-Path $r 'CLAUDE.md') $claude
    Put (Join-Path $r '.github/instructions/framework-rules.instructions.md') "---`napplyTo: `"**`"`n---`n# Verification Rules"
    $shellLeaf=Split-Path $Shell -Leaf;$hook='.claude/hooks/guard.ps1'; if($shellLeaf-match'^bash(?:\.exe)?$'){$hook='.claude/hooks/guard.sh'}
    $shellToken=if($Shell-match'[\\/]'){('"'+$Shell+'"')}else{$Shell};$cmd="$shellToken -File $hook"
    Put (Join-Path $r '.claude/settings.json') (@{hooks=@{PreToolUse=@(@{hooks=@(@{command=$cmd})})}}|ConvertTo-Json -Depth 8)
    $bashArgs=if($HookArguments){' --mode scan'}else{''};$psArgs=if($HookArguments){' -Mode scan'}else{''}
    Put (Join-Path $r '.github/hooks/hooks.json') ('{"hooks":{"preToolUse":[{"bash":"'+($hook-replace '\.ps1$','.sh')+$bashArgs+'","powershell":"'+($hook-replace '/','\\')+$psArgs+'"}]}}')
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
# The third replace maps each twin's self-reference to its own sibling script name
# (docs-sync-check.ps1 vs docs-sync-check.sh) to one common token: each twin correctly names its
# own sibling on the Mirror-check failure row, so that one difference is not a defect and must
# not fail the comparison. Keep this narrow -- do not strip .ps1/.sh generally, or real twin
# divergences elsewhere would be hidden.
function Normal($Text){((($Text-replace'available: powershell\.exe','available: powershell')-replace'\\','/')-replace'docs-sync-check\.(?:ps1|sh)','docs-sync-check.<ext>')}
Reset-Tests
It 'healthy fixture exits zero and prints canary boundary' {$r=Fixture;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[OK\] Install state') 'install state not OK';Assert ($x.Out-match'Enforcement is only FULL') 'false-full boundary missing'}finally{Remove-Item -Recurse -Force $r}}
It 'missing framework-rules import is reported honestly' {$r=Fixture -Pending $true;try{$p=Join-Path $r 'CLAUDE.md';Put $p (([IO.File]::ReadAllText($p))-replace'(?m)^@\.github/instructions/framework-rules\.instructions\.md\r?\n','');$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 1) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[MISSING\] Framework rules delivery') "delivery row absent: $($x.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'protected-file version divergence uses the required honest wording' {$r=Fixture -Pending $true;try{$p=Join-Path $r 'CLAUDE.md';Put $p (([IO.File]::ReadAllText($p))-replace'version: 0\.32\.0','version: 0.31.0');$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 1) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[MISSING\] Protected-file sync - DIVERGED . protected file not synchronized with installed machinery; review required') "honest divergence row absent: $($x.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'adoption pending is not reported broken' {$r=Fixture -Pending $true;try{Put (Join-Path $r '.claude/adoption-pending.json') '{}';$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "pending exit=$($x.Exit)";Assert ($x.Out-match'\[PENDING\] Bootstrap/adoption state') 'pending row missing';Assert ($x.Out-notmatch'\[MISSING\] Stack toolchain') 'dependent false alarm'}finally{Remove-Item -Recurse -Force $r}}
It 'missing hook file exits one' {$r=Fixture -MissingHook $true;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 1) "exit=$($x.Exit)";Assert ($x.Out-match'\[MISSING\] Hook files') 'missing hook row absent'}finally{Remove-Item -Recurse -Force $r}}
It 'bare-name wired shell is CANT-VERIFY and does not change exit' {$r=Fixture -Shell 'doctor-shell-bare-name' -Pending $true;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[CANT-VERIFY\] Wired hook shell - hooks are wired to the bare name doctor-shell-bare-name') 'CANT-VERIFY row absent';Assert ($x.Out-match'Script-verifiable checks: 6 ok / 0 missing\.') "summary counted CANT-VERIFY or new rows incorrectly: $($x.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'no liveness record is CANT-VERIFY and does not change exit' {$r=Fixture -Pending $true;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[CANT-VERIFY\] Hook liveness - no hook has recorded a run here;') "CANT-VERIFY row absent: $($x.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'liveness record is OK and quotes its timestamp' {$r=Fixture -Pending $true;$stamp='2026-07-31T12:34:56Z';try{New-Item -ItemType Directory -Force (Join-Path $r '.claude/.state')|Out-Null;Put (Join-Path $r '.claude/.state/last-session-start') $stamp;$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match("\[OK\] Hook liveness - hooks have demonstrably run in this repo, most recently at '{0}'\." -f [regex]::Escape($stamp))) "OK row does not quote timestamp: $($x.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'existing absolute wired shell is OK' {$shell=[IO.Path]::GetTempFileName();$r=Fixture -Shell $shell -Pending $true;try{$wired=(Get-Content -Raw (Join-Path $r '.claude/settings.json')|ConvertFrom-Json).hooks.PreToolUse[0].hooks[0].command;Assert ($wired-eq('"'+$shell+'" -File .claude/hooks/guard.ps1')) "fixture did not receive one path: $wired";$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[OK\] Wired hook shell - wired interpreter paths exist:') "OK row absent: $($x.Out)"}finally{Remove-Item -Recurse -Force $r;Remove-Item -Force -ErrorAction SilentlyContinue $shell}}
It 'missing absolute wired shell is MISSING and exits one' {$shell=(Join-Path ([IO.Path]::GetTempPath()) 'doctor-missing/interpreter.exe');$r=Fixture -Shell $shell -Pending $true;try{$x=Run (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 1) "exit=$($x.Exit): $($x.Out)";Assert ($x.Out-match'\[MISSING\] Wired hook shell - the wired interpreter path does not exist on this machine') "MISSING row absent: $($x.Out)"}finally{Remove-Item -Recurse -Force $r}}
$winPs=Get-Command powershell.exe -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 1
if($winPs){It 'PowerShell twin runs under Windows PowerShell 5.1' {$r=Fixture;try{$x=RunPsHost $winPs.Source (Join-Path $r 'scripts/framework-doctor.ps1');Assert ($x.Exit-eq 0) "5.1 exit=$($x.Exit): $($x.Out) $($x.Err)";Assert ($x.Out-match'Enforcement is only FULL') '5.1 output incomplete'}finally{Remove-Item -Recurse -Force $r}}}else{Skip 'Windows PowerShell 5.1 compatibility' 'powershell.exe unavailable on this host'}
if($bash){
It 'twins agree when the liveness record is absent and when it is present' {$r=Fixture -Shell 'bash' -Pending $true;$old=$env:PATH;try{$env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$old;foreach($stamp in @($null,'2026-07-31T12:34:56Z')){Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $r '.claude/.state/last-session-start');if($stamp){New-Item -ItemType Directory -Force (Join-Path $r '.claude/.state')|Out-Null;Put (Join-Path $r '.claude/.state/last-session-start') $stamp};$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');Assert ($p.Exit-eq 0-and$s.Exit-eq 0) "exit mismatch PS=$($p.Exit) SH=$($s.Exit)";Assert ((Normal $p.Out)-eq(Normal $s.Out)) "stdout mismatch for stamp '$stamp'`nPS:`n$($p.Out)`nSH:`n$($s.Out)"}}finally{$env:PATH=$old;Remove-Item -Recurse -Force $r}}
It 'Copilot hook registrations with arguments resolve only their file paths' {$r=Fixture -Shell 'bash' -Pending $true -HookArguments $true;try{$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');Assert ($p.Out-match'\[OK\] Hook files') "PowerShell hook row not OK: $($p.Out)";Assert ($s.Out-match'\[OK\] Hook files') "bash hook row not OK: $($s.Out)";Assert ((Normal $p.Out)-eq(Normal $s.Out)) "stdout mismatch`nPS:`n$($p.Out)`nSH:`n$($s.Out)"}finally{Remove-Item -Recurse -Force $r}}
It 'twins agree on pending fixture' {$r=Fixture -Shell 'bash' -Pending $true;$old=$env:PATH;try{$env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$old;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');Assert ($p.Exit-eq$s.Exit) "exit mismatch PS=$($p.Exit) SH=$($s.Exit)`nPS:`n$($p.Out)`nSH:`n$($s.Out)`n$($s.Err)";Assert ((Normal $p.Out)-eq(Normal $s.Out)) "stdout mismatch`nPS:`n$($p.Out)`nSH:`n$($s.Out)"}finally{$env:PATH=$old;Remove-Item -Recurse -Force $r}}
# All three pending-guarded rows (Stack toolchain, Mirror and version integrity, Audit trail
# substrate) sit behind PENDING and are skipped by every fixture above, since they all use
# -Pending $true. The two cases below use a non-pending fixture so those rows actually run and
# get twin-compared. Coverage gap: the fixture's template value ('fixture') matches neither the
# dotnet nor the angular case in 'Stack toolchain', so the .ps1 regex vs .sh case-glob difference
# in that row is still never exercised by any test in this file.
It 'twins agree on non-pending fixture where the mirror check passes' {$r=Fixture -Shell 'bash';$old=$env:PATH;try{$env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$old;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');Assert ($p.Exit-eq$s.Exit) "exit mismatch PS=$($p.Exit) SH=$($s.Exit)`nPS:`n$($p.Out)`nSH:`n$($s.Out)`n$($s.Err)";Assert ($p.Out-match'\[OK\] Mirror and version integrity') "PS mirror row not OK: $($p.Out)";Assert ((Normal $p.Out)-eq(Normal $s.Out)) "stdout mismatch`nPS:`n$($p.Out)`nSH:`n$($s.Out)"}finally{$env:PATH=$old;Remove-Item -Recurse -Force $r}}
It 'twins agree on non-pending fixture where the mirror check fails' {$r=Fixture -Shell 'bash';$old=$env:PATH;try{Put (Join-Path $r 'scripts/template-checks.ps1') ([char]0xFEFF+'exit 1') $false;Put (Join-Path $r 'scripts/template-checks.sh') "#!/usr/bin/env bash`nexit 1`n";$env:PATH=(Split-Path $bash -Parent)+[IO.Path]::PathSeparator+$old;$p=Run (Join-Path $r 'scripts/framework-doctor.ps1');$s=Run (Join-Path $r 'scripts/framework-doctor.sh');Assert ($p.Exit-eq$s.Exit) "exit mismatch PS=$($p.Exit) SH=$($s.Exit)`nPS:`n$($p.Out)`nSH:`n$($s.Out)`n$($s.Err)";Assert ($p.Out-match'\[MISSING\] Mirror and version integrity') "PS mirror row not MISSING: $($p.Out)";Assert ((Normal $p.Out)-eq(Normal $s.Out)) "stdout mismatch`nPS:`n$($p.Out)`nSH:`n$($s.Out)"}finally{$env:PATH=$old;Remove-Item -Recurse -Force $r}}
# Sandbox utility list for framework-doctor.sh; kept identical to the fixture's original inline
# version so behaviour does not shift on refactor (dirname/paste are unused by the script itself,
# but were part of the proven sandbox and there is no reason to narrow it here). Now built via the
# shared Invoke-Sandboxed helper in _HookHarness.ps1 so other hook test files can reuse it too.
$doctorUtils = @('dirname','sed','grep','sort','paste','head')
It 'bash twin survives without jq or ANY working python and reports the guard inactive (no interpreter present at all)' {
    $r=Fixture -Shell 'bash' -Pending $true
    try{
        $doc=Join-Path $r 'scripts/framework-doctor.sh'
        $s=Invoke-Sandboxed -Bash $bash -ScriptPath $doc -Utilities $doctorUtils
        Assert ($s.Out-match'\[OK\] Install state') "root resolution failed under restricted PATH: $($s.Out)`nSTDERR: $($s.Err)"
        Assert ($s.Out-match'\[MISSING\] Guard JSON parser') "parser finding absent: $($s.Out)`nSTDERR: $($s.Err)"
        Assert ($s.Out-match'\[PENDING\] Bootstrap/adoption state') 'grep fallback did not read pending state'
    }finally{Remove-Item -Recurse -Force $r}}
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
        $searchText='    resolve_pybin'+"`n"+'    if [ -n "$_pybin" ]; then row OK '+$q+'Guard JSON parser'+$q+' '+$q+'jq or a working python interpreter is available.'+$q
        Assert ($text.Contains($searchText)) 'could not locate the Guard JSON parser row''s resolve_pybin call to mutate -- framework-doctor.sh may have changed shape; update this test'
        $naiveText='    _pybin=""'+"`n"+'    for _naivecand in python3 python py; do command -v "$_naivecand" >/dev/null 2>&1 && { _pybin=$_naivecand; break; }; done'+"`n"+'    if [ -n "$_pybin" ]; then row OK '+$q+'Guard JSON parser'+$q+' '+$q+'jq or a working python interpreter is available.'+$q
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
    }
}
exit (Write-TestSummary 'FrameworkDoctor.Tests')
