# route-prompt surface-shape tests (v0.25.0 Copilot injection port).
# Claude-shaped events (hook_event_name present) must get PLAIN stdout; Copilot-shaped events
# (JSON without hook_event_name) must get the dual-shape JSON (top-level additionalContext +
# hookSpecificOutput wrapper).
if (-not (Get-Command Invoke-Hook -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot '_HookHarness.ps1') }
$hooks = (Resolve-Path (Join-Path $PSScriptRoot '..\..\.claude\hooks')).Path
$rpPs  = Join-Path $hooks 'route-prompt.ps1'

function New-ClaudePrompt  { param($Prompt) (@{ hook_event_name = 'UserPromptSubmit'; prompt = $Prompt } | ConvertTo-Json -Compress) }
function New-CopilotPrompt { param($Prompt) (@{ prompt = $Prompt; timestamp = 1 } | ConvertTo-Json -Compress) }

function New-RoutePromptFixture {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('route-prompt-' + [guid]::NewGuid().ToString('N'))
    $repo = Join-Path $dir 'repo'
    $fixtureHooks = Join-Path $repo '.claude\hooks'
    New-Item -ItemType Directory -Path $fixtureHooks -Force | Out-Null
    Copy-Item -LiteralPath $rpPs -Destination (Join-Path $fixtureHooks 'route-prompt.ps1')
    git -C $repo init --quiet
    return [pscustomobject]@{ Dir = $dir; Repo = $repo; Hooks = $fixtureHooks }
}

Reset-Tests

# --- Claude surface: plain stdout, not JSON ---
It 'route-prompt.ps1 Claude event -> plain rails (fix intent)' {
    $r = Invoke-Hook $rpPs (New-ClaudePrompt 'fix the broken date formatting')
    Assert ($r.Exit -eq 0) "exit $($r.Exit)"
    Assert ($r.Out -match '## Routed intent: `fix`') 'rails missing'
    Assert ($r.Out -match 'repository evidence') 'verification rail does not require repository evidence'
    Assert ($r.Out -match 'not available') 'verification rail does not expose unsupported categories'
    Assert ($r.Out -match 'applicable test harness') 'fix rail still unconditionally requires a regression test'
    Assert ($r.Out -match 'strongest evidenced validation') 'fix rail omits the no-harness validation path'
    Assert ($r.Out -match 'foreign harness') 'fix rail permits adding a foreign harness solely for a fix'
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
    foreach ($evt in (
        (New-ClaudePrompt 'why does it keep crashing?'),
        (New-CopilotPrompt 'why does it keep crashing?'),
        (New-ClaudePrompt 'Why is this tech debt?'),
        (New-CopilotPrompt 'Why is this tech debt?')
    )) {
        $r = Invoke-Hook $rpPs $evt
        Assert ($r.Exit -eq 0 -and [string]::IsNullOrWhiteSpace($r.Out)) 'question carve-out must suppress rails'
    }
}

# --- Copilot single-entry composition drains Boy Scout delivery behind the surface gate ---
    It 'route-prompt.ps1 Copilot routing + queue -> one payload, routing first, queue consumed once' {
        $fixture = New-RoutePromptFixture
        $queue = Join-Path $fixture.Repo '.claude\.state\boy-scout-queue'
        New-Item -ItemType Directory -Path (Split-Path -Parent $queue) -Force | Out-Null
        [IO.File]::WriteAllText($queue, 'B147_BOY_SCOUT_SENTINEL')
        try {
            $r = Invoke-Hook (Join-Path $fixture.Hooks 'route-prompt.ps1') (New-CopilotPrompt 'fix the broken date formatting')
            Assert ($r.Exit -eq 0) "exit $($r.Exit): $($r.Err)"
            $o = $r.Out | ConvertFrom-Json
            Assert ($o.additionalContext -match 'Routed intent: `fix`') 'routing text missing'
            Assert ($o.additionalContext -match 'B147_BOY_SCOUT_SENTINEL') 'Boy Scout queue missing'
            Assert ($o.additionalContext.IndexOf('Routed intent') -lt $o.additionalContext.IndexOf('B147_BOY_SCOUT_SENTINEL')) 'routing must precede Boy Scout queue'
            Assert (-not (Test-Path -LiteralPath $queue)) 'queue was not deleted after the read'
            $second = Invoke-Hook (Join-Path $fixture.Hooks 'route-prompt.ps1') (New-CopilotPrompt 'why is the sky blue?')
            Assert ([string]::IsNullOrEmpty($second.Out)) 'queue was delivered more than once'
        } finally { Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'route-prompt.ps1 Copilot empty routing + queue -> queue-only payload' {
        $fixture = New-RoutePromptFixture
        $queue = Join-Path $fixture.Repo '.claude\.state\boy-scout-queue'
        New-Item -ItemType Directory -Path (Split-Path -Parent $queue) -Force | Out-Null
        [IO.File]::WriteAllText($queue, 'B147_QUEUE_ONLY_SENTINEL')
        try {
            $r = Invoke-Hook (Join-Path $fixture.Hooks 'route-prompt.ps1') (New-CopilotPrompt '/review')
            $o = $r.Out | ConvertFrom-Json
            Assert ($o.additionalContext -eq 'B147_QUEUE_ONLY_SENTINEL') "queue-only context differs: '$($o.additionalContext)'"
            Assert (-not (Test-Path -LiteralPath $queue)) 'queue-only delivery did not consume the queue'
        } finally { Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'route-prompt.ps1 Copilot routing + empty queue -> routing only' {
        $fixture = New-RoutePromptFixture
        try {
            $r = Invoke-Hook (Join-Path $fixture.Hooks 'route-prompt.ps1') (New-CopilotPrompt 'fix the broken date formatting')
            $o = $r.Out | ConvertFrom-Json
            Assert ($o.additionalContext -match 'Routed intent: `fix`') 'routing text missing'
            Assert ($o.additionalContext -match 'repository evidence') 'verification rail does not require repository evidence'
            Assert ($o.additionalContext -match 'not available') 'verification rail does not expose unsupported categories'
            Assert ($o.additionalContext -match 'applicable test harness') 'fix rail still unconditionally requires a regression test'
            Assert ($o.additionalContext -match 'strongest evidenced validation') 'fix rail omits the no-harness validation path'
            Assert ($o.additionalContext -match 'foreign harness') 'fix rail permits adding a foreign harness solely for a fix'
            Assert ($o.additionalContext -notmatch 'B147_.*_SENTINEL') 'unexpected Boy Scout text'
        } finally { Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'route-prompt.ps1 Copilot empty routing + empty queue -> no output' {
        $fixture = New-RoutePromptFixture
        try {
            $r = Invoke-Hook (Join-Path $fixture.Hooks 'route-prompt.ps1') (New-CopilotPrompt '/review')
            Assert ($r.Exit -eq 0 -and [string]::IsNullOrEmpty($r.Out)) "expected silence, got '$($r.Out)'"
        } finally { Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'route-prompt.ps1 Claude routing preserves real queue for Stop delivery' {
        $fixture = New-RoutePromptFixture
        $queue = Join-Path $fixture.Repo '.claude\.state\boy-scout-queue'
        New-Item -ItemType Directory -Path (Split-Path -Parent $queue) -Force | Out-Null
        [IO.File]::WriteAllText($queue, 'B147_CLAUDE_QUEUE_SENTINEL')
        try {
            $r = Invoke-Hook (Join-Path $fixture.Hooks 'route-prompt.ps1') (New-ClaudePrompt 'fix the broken date formatting')
            Assert ($r.Out -match 'Routed intent: `fix`') 'Claude routing text missing'
            Assert ($r.Out -notmatch 'B147_CLAUDE_QUEUE_SENTINEL') 'Claude path stole Boy Scout delivery'
            Assert (Test-Path -LiteralPath $queue) 'Claude path deleted the Stop delivery queue'
        } finally { Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

exit (Write-TestSummary 'RoutePrompt.Tests (surface shapes)')
