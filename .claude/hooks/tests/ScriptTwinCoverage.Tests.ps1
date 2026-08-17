# Registry gate: every shipped script twin needs behavioural coverage or a documented exclusion.
. (Join-Path $PSScriptRoot '_HookHarness.ps1')
Reset-Tests
It 'classifies every shipped script twin' {
    $root=(Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $core=Join-Path $root 'src/core/scripts'
    $stack=Join-Path $root 'src/stacks'
    $files=@(Get-ChildItem $core -Filter *.ps1 -File)+@(Get-ChildItem $stack -Recurse -Filter *.ps1 -File|Where-Object{$_.FullName-match'[\\/]files[\\/]scripts[\\/]'} )
    $pairs=@($files|Where-Object{Test-Path ($_.FullName-replace'\.ps1$','.sh')}|ForEach-Object{$_.BaseName}|Sort-Object -Unique)
    $parity=[IO.File]::ReadAllText((Join-Path $root 'src/core/tests/hooks/ScriptTwinParity.Tests.ps1'))
    $covered=@('template-checks','docs-sync-check','sync-agent-files','metrics')|Where-Object{$parity.Contains($_)}
    $ack=@{
        'install'='covered by the installer contract test in this meta suite'
        'wiki-check'='covered by tests/hooks/WikiCheck.Tests.ps1'
        'build-architecture-html'='covered by tests/hooks/BuildArchitectureHtml.Tests.ps1'
        'framework-doctor'='covered by tests/hooks/FrameworkDoctor.Tests.ps1'
        'warehouse-map-check'='covered by tests/hooks/WarehouseMapCheck.Tests.ps1'
        'hazard-check'='covered by tests/hooks/HazardCheck.Tests.ps1'
        'impact-run'='deliberately excluded: requires an external agent CLI, git worktrees and paid API calls'
    }
    foreach($name in $pairs){Assert (($covered-contains$name)-or$ack.ContainsKey($name)) "unclassified script twin '$name': add a behavioural case or record a written reason"}
}
exit (Write-TestSummary 'ScriptTwinCoverage.Tests')
