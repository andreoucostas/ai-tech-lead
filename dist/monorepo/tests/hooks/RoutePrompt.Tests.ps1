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

function New-RoutePromptFixture {
    $dir = Join-Path ([IO.Path]::GetTempPath()) ('route-prompt-' + [guid]::NewGuid().ToString('N'))
    $repo = Join-Path $dir 'repo'
    $fixtureHooks = Join-Path $repo '.claude\hooks'
    New-Item -ItemType Directory -Path $fixtureHooks -Force | Out-Null
    Copy-Item -LiteralPath $rpPs -Destination (Join-Path $fixtureHooks 'route-prompt.ps1')
    Copy-Item -LiteralPath $rpSh -Destination (Join-Path $fixtureHooks 'route-prompt.sh')
    git -C $repo init --quiet
    return [pscustomobject]@{ Dir = $dir; Repo = $repo; Hooks = $fixtureHooks }
}

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

# --- Copilot single-entry composition drains Boy Scout delivery behind the surface gate ---
foreach ($twin in @(@{ Name = 'ps1'; File = 'route-prompt.ps1' }, @{ Name = 'sh'; File = 'route-prompt.sh' })) {
    if ($twin.Name -eq 'sh' -and -not $bash) {
        Skip "route-prompt.$($twin.Name) Copilot queue composition cases" 'no bash found' -Invariant
        continue
    }

    It "route-prompt.$($twin.Name) Copilot routing + queue -> one payload, routing first, queue consumed once" {
        $fixture = New-RoutePromptFixture
        $queue = Join-Path $fixture.Repo '.claude\.state\boy-scout-queue'
        New-Item -ItemType Directory -Path (Split-Path -Parent $queue) -Force | Out-Null
        [IO.File]::WriteAllText($queue, 'B147_BOY_SCOUT_SENTINEL')
        try {
            $r = Invoke-Hook (Join-Path $fixture.Hooks $twin.File) (New-CopilotPrompt 'fix the broken date formatting')
            Assert ($r.Exit -eq 0) "exit $($r.Exit): $($r.Err)"
            $o = $r.Out | ConvertFrom-Json
            Assert ($o.additionalContext -match 'Routed intent: `fix`') 'routing text missing'
            Assert ($o.additionalContext -match 'B147_BOY_SCOUT_SENTINEL') 'Boy Scout queue missing'
            Assert ($o.additionalContext.IndexOf('Routed intent') -lt $o.additionalContext.IndexOf('B147_BOY_SCOUT_SENTINEL')) 'routing must precede Boy Scout queue'
            Assert (-not (Test-Path -LiteralPath $queue)) 'queue was not deleted after the read'
            $second = Invoke-Hook (Join-Path $fixture.Hooks $twin.File) (New-CopilotPrompt 'why is the sky blue?')
            Assert ([string]::IsNullOrEmpty($second.Out)) 'queue was delivered more than once'
        } finally { Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "route-prompt.$($twin.Name) Copilot empty routing + queue -> queue-only payload" {
        $fixture = New-RoutePromptFixture
        $queue = Join-Path $fixture.Repo '.claude\.state\boy-scout-queue'
        New-Item -ItemType Directory -Path (Split-Path -Parent $queue) -Force | Out-Null
        [IO.File]::WriteAllText($queue, 'B147_QUEUE_ONLY_SENTINEL')
        try {
            $r = Invoke-Hook (Join-Path $fixture.Hooks $twin.File) (New-CopilotPrompt '/review')
            $o = $r.Out | ConvertFrom-Json
            Assert ($o.additionalContext -eq 'B147_QUEUE_ONLY_SENTINEL') "queue-only context differs: '$($o.additionalContext)'"
            Assert (-not (Test-Path -LiteralPath $queue)) 'queue-only delivery did not consume the queue'
        } finally { Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "route-prompt.$($twin.Name) Copilot routing + empty queue -> routing only" {
        $fixture = New-RoutePromptFixture
        try {
            $r = Invoke-Hook (Join-Path $fixture.Hooks $twin.File) (New-CopilotPrompt 'fix the broken date formatting')
            $o = $r.Out | ConvertFrom-Json
            Assert ($o.additionalContext -match 'Routed intent: `fix`') 'routing text missing'
            Assert ($o.additionalContext -notmatch 'B147_.*_SENTINEL') 'unexpected Boy Scout text'
        } finally { Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "route-prompt.$($twin.Name) Copilot empty routing + empty queue -> no output" {
        $fixture = New-RoutePromptFixture
        try {
            $r = Invoke-Hook (Join-Path $fixture.Hooks $twin.File) (New-CopilotPrompt '/review')
            Assert ($r.Exit -eq 0 -and [string]::IsNullOrEmpty($r.Out)) "expected silence, got '$($r.Out)'"
        } finally { Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It "route-prompt.$($twin.Name) Claude routing preserves real queue for Stop delivery" {
        $fixture = New-RoutePromptFixture
        $queue = Join-Path $fixture.Repo '.claude\.state\boy-scout-queue'
        New-Item -ItemType Directory -Path (Split-Path -Parent $queue) -Force | Out-Null
        [IO.File]::WriteAllText($queue, 'B147_CLAUDE_QUEUE_SENTINEL')
        try {
            $r = Invoke-Hook (Join-Path $fixture.Hooks $twin.File) (New-ClaudePrompt 'fix the broken date formatting')
            Assert ($r.Out -match 'Routed intent: `fix`') 'Claude routing text missing'
            Assert ($r.Out -notmatch 'B147_CLAUDE_QUEUE_SENTINEL') 'Claude path stole Boy Scout delivery'
            Assert (Test-Path -LiteralPath $queue) 'Claude path deleted the Stop delivery queue'
        } finally { Remove-Item -LiteralPath $fixture.Dir -Recurse -Force -ErrorAction SilentlyContinue }
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


# --- Force the no-jq fallback branch, sandboxed to exactly cat/grep/tr (what route-prompt.sh
# actually calls) so the sandbox can neither expose a stray real jq/python3 nor break the hook's own
# plumbing. See Invoke-Sandboxed / New-ExecShim in _HookHarness.ps1.
$storeStubScript = "#!/usr/bin/env bash`nprintf 'Python was not found; run without arguments to install from the Microsoft Store, or disable this shortcut from Settings > Manage App Execution Aliases.\n' >&2`nexit 49`n"
if (-not $bash) {
    Skip 'route-prompt.sh sandboxed: no jq, python is the Store stub -> still routes' 'no bash found' -Invariant
    Skip 'route-prompt.sh sandboxed: no jq, working interpreter only as `python` -> emits JSON' 'no bash found' -Invariant
    Skip 'route-prompt.sh sandboxed: jq present -> routes via jq (control)' 'no bash found' -Invariant
} else {
    It 'route-prompt.sh sandboxed: no jq, no python3, no py, python is the Store stub -> still routes (regex fallback)' {
        $r = Invoke-Sandboxed -Bash $bash -ScriptPath $rpSh -Utilities @('cat','grep','tr') -FakeBins @{ python = $storeStubScript } -Stdin (New-ClaudePrompt 'fix the broken date formatting')
        Assert ($r.Exit -eq 0) "exit=$($r.Exit): $($r.Err)"
        Assert (-not [string]::IsNullOrEmpty($r.Out)) 'no output at all (pre-fix produced zero bytes here -- the elif chain committed to the Store-stub branch and never reached the regex fallback)'
        Assert ($r.Out -match 'Routed intent') "rails missing: $($r.Out)"
    }
    if (Resolve-HostPython) {
    It 'route-prompt.sh sandboxed: no jq, working interpreter only as `python` -> emits JSON' {
        $r = Invoke-Sandboxed -Bash $bash -ScriptPath $rpSh -Utilities @('cat','grep','tr') -ExposeInterpreterAs 'python' -Stdin (New-CopilotPrompt 'fix the broken date formatting')
        Assert ($r.Exit -eq 0) "exit=$($r.Exit): $($r.Err)"
        Assert ($r.Out.TrimStart().StartsWith('{')) "expected JSON output (python encode path), got plain stdout (pre-fix: the encode site only ever probed jq/python3, never bare python): $($r.Out)"
        $o = $r.Out | ConvertFrom-Json
        Assert ($o.additionalContext -match 'Routed intent') 'top-level additionalContext missing rails'
        Assert ($o.hookSpecificOutput.additionalContext -eq $o.additionalContext) 'wrapped context differs from top-level'
    }
    } else { Skip 'route-prompt.sh sandboxed: no jq, working interpreter only as `python` -> emits JSON' 'no working python interpreter found on this host (set $env:ATL_TEST_PYTHON to an absolute interpreter path to exercise this case)' -Invariant }
    $jqReal = Resolve-HostJq
    if ($jqReal) {
        It 'route-prompt.sh sandboxed: jq present -> routes via jq (control)' {
            $r = Invoke-Sandboxed -Bash $bash -ScriptPath $rpSh -Utilities @('cat','grep','tr') -FakeBins @{ jq = (New-ExecShim $jqReal) } -Stdin (New-CopilotPrompt 'fix the broken date formatting')
            Assert ($r.Exit -eq 0) "exit=$($r.Exit): $($r.Err)"
            $o = $r.Out | ConvertFrom-Json
            Assert ($o.additionalContext -match 'Routed intent') "jq control: rails missing: $($r.Out)"
        }
    } else {
        Skip 'route-prompt.sh sandboxed: jq present -> routes via jq (control)' 'no working jq found on this host' -Invariant
    }
}

exit (Write-TestSummary 'RoutePrompt.Tests (surface shapes)')
