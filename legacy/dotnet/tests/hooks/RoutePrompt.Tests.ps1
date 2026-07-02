# route-prompt surface-shape tests (v0.25.0 Copilot injection port).
# Claude-shaped events (hook_event_name present) must get PLAIN stdout; Copilot-shaped events
# (JSON without hook_event_name) must get the dual-shape JSON (top-level additionalContext +
# hookSpecificOutput wrapper). The .sh twin must agree at decision level (output present/absent,
# exit 0, same salience markers) -- byte shape may differ when the bash env lacks jq/python3,
# where the .sh degrades to plain stdout by design.
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$rpPs  = Join-Path $hooks 'route-prompt.ps1'
$rpSh  = Join-Path $hooks 'route-prompt.sh'
$bash  = Get-BashPath

function New-ClaudePrompt  { param($Prompt) (@{ hook_event_name = 'UserPromptSubmit'; prompt = $Prompt } | ConvertTo-Json -Compress) }
function New-CopilotPrompt { param($Prompt) (@{ prompt = $Prompt; timestamp = 1 } | ConvertTo-Json -Compress) }

Reset-Tests

# --- Claude surface: plain stdout, not JSON ---
It 'route-prompt.ps1 Claude event -> plain rails (fix intent)' {
    $r = Invoke-Hook $rpPs (New-ClaudePrompt 'fix the broken date formatting')
    Assert ($r.Exit -eq 0) "exit $($r.Exit)"
    Assert ($r.Out -match '## Routed intent: `fix`') 'rails missing'
    Assert (-not $r.Out.TrimStart().StartsWith('{')) 'Claude surface must not get JSON'
}

# --- Copilot surface: dual-shape JSON ---
It 'route-prompt.ps1 Copilot event -> JSON additionalContext (fix intent)' {
    $r = Invoke-Hook $rpPs (New-CopilotPrompt 'fix the broken date formatting')
    Assert ($r.Exit -eq 0) "exit $($r.Exit)"
    $o = $r.Out | ConvertFrom-Json
    Assert ($o.additionalContext -match 'Routed intent: `fix`') 'top-level additionalContext missing rails'
    Assert ($o.hookSpecificOutput.hookEventName -eq 'UserPromptSubmit') 'hookSpecificOutput.hookEventName wrong'
    Assert ($o.hookSpecificOutput.additionalContext -eq $o.additionalContext) 'wrapped context differs from top-level'
}

# --- Plan gate rides along for fix/feature/refactor/test ---
It 'route-prompt.ps1 Copilot event -> plan gate included for feature intent' {
    $r = Invoke-Hook $rpPs (New-CopilotPrompt 'implement a new export button')
    $o = $r.Out | ConvertFrom-Json
    Assert ($o.additionalContext -match 'Plan gate') 'plan gate missing'
}

# --- Security overlay reaches the Copilot shape ---
It 'route-prompt.ps1 Copilot event -> security overlay for payment prompt' {
    $r = Invoke-Hook $rpPs (New-CopilotPrompt 'implement payment processing')
    $o = $r.Out | ConvertFrom-Json
    Assert ($o.additionalContext -match 'Security-sensitive surface detected') 'security overlay missing'
}

# --- No-op cases stay no-op on both surfaces ---
It 'route-prompt.ps1 slash command -> no output (both surfaces)' {
    foreach ($evt in (New-ClaudePrompt '/fix the thing'), (New-CopilotPrompt '/fix the thing')) {
        $r = Invoke-Hook $rpPs $evt
        Assert ($r.Exit -eq 0 -and [string]::IsNullOrWhiteSpace($r.Out)) 'slash command must be a no-op'
    }
}
It 'route-prompt.ps1 answer-only question -> no rails (both surfaces)' {
    foreach ($evt in (New-ClaudePrompt 'why does it keep crashing?'), (New-CopilotPrompt 'why does it keep crashing?')) {
        $r = Invoke-Hook $rpPs $evt
        Assert ($r.Exit -eq 0 -and [string]::IsNullOrWhiteSpace($r.Out)) 'question carve-out must suppress rails'
    }
}

# --- Twin agreement at decision level ---
if (-not $bash) {
    Skip 'route-prompt twin surface agreement' 'no bash found'
} else {
    $twinCases = @(
        @{ n = 'fix intent (Claude)';    evt = (New-ClaudePrompt  'fix the broken date formatting'); marker = 'Routed intent' },
        @{ n = 'fix intent (Copilot)';   evt = (New-CopilotPrompt 'fix the broken date formatting'); marker = 'Routed intent' },
        @{ n = 'security (Copilot)';     evt = (New-CopilotPrompt 'implement payment processing');   marker = 'Security-sensitive' },
        @{ n = 'slash no-op (Copilot)';  evt = (New-CopilotPrompt '/review');                        marker = '' }
    )
    foreach ($case in $twinCases) {
        It "route-prompt twins agree: $($case.n)" {
            $rps = Invoke-Hook $rpPs $case.evt; $rsh = Invoke-Hook $rpSh $case.evt
            Assert ($rps.Exit -eq 0 -and $rsh.Exit -eq 0) "exits: ps1=$($rps.Exit) sh=$($rsh.Exit)"
            if ($case.marker) {
                Assert ($rps.Out -match $case.marker -and $rsh.Out -match $case.marker) "marker '$($case.marker)': ps1=$($rps.Out -match $case.marker) sh=$($rsh.Out -match $case.marker)"
            } else {
                Assert ([string]::IsNullOrWhiteSpace($rps.Out) -and [string]::IsNullOrWhiteSpace($rsh.Out)) 'both twins must stay silent'
            }
        }
    }
}

exit (Write-TestSummary 'RoutePrompt.Tests (surface shapes)')
