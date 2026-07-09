# WS-M2 -- guard behavioural tests. For each BLOCKING case: Claude-shaped event must BLOCK (exit 2),
# Copilot-shaped event must DENY (JSON). For each CLEAN case: both shapes must ALLOW.
# Cases are generated into both surface shapes from one content string, so the same input drives both.
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
. (Join-Path $PSScriptRoot 'fixtures\guard-cases.ps1')
$hooks = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$guardPs = Join-Path $hooks 'guard.ps1'

Reset-Tests
foreach ($case in $GuardCases) {
    $claude  = New-ClaudeEvent  $case.f $case.c
    $copilot = New-CopilotEvent $case.f $case.c
    if ($case.block) {
        It "guard.ps1 BLOCKS (Claude): $($case.n)"  { Assert-Decision (Invoke-Hook $guardPs $claude)  'BLOCK' $case.n }
        It "guard.ps1 DENIES (Copilot): $($case.n)" { Assert-Decision (Invoke-Hook $guardPs $copilot) 'DENY'  $case.n }
    } else {
        It "guard.ps1 ALLOWS (Claude): $($case.n)"  { Assert-Decision (Invoke-Hook $guardPs $claude)  'ALLOW' $case.n }
        It "guard.ps1 ALLOWS (Copilot): $($case.n)" { Assert-Decision (Invoke-Hook $guardPs $copilot) 'ALLOW' $case.n }
    }
}
# Empty stdin and malformed JSON must degrade-safe to ALLOW (exit 0), never crash.
It 'guard.ps1 empty stdin -> allow'     { Assert-Decision (Invoke-Hook $guardPs '')             'ALLOW' 'empty' }
It 'guard.ps1 malformed json -> allow'  { Assert-Decision (Invoke-Hook $guardPs 'not json {')   'ALLOW' 'malformed' }

exit (Write-TestSummary 'Guard.Tests (guard.ps1)')
