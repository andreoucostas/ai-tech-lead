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

# --- Rails may elaborate the canonical Agentic Workflow bullets, not drop their non-negotiables ---
It 'route-prompt.ps1 test rail -> each new behavioral test is seen to fail' {
    $r = Invoke-Hook $rpPs (New-ClaudePrompt 'write tests for the date parser')
    Assert ($r.Out -match '## Routed intent: `test`') 'test intent not routed'
    Assert ($r.Out -match 'fail correctly') 'test rail omits seeing each new behavioral test fail'
}
It 'route-prompt.ps1 feature rail -> no test harness added incidentally' {
    $r = Invoke-Hook $rpPs (New-ClaudePrompt 'implement a new export button')
    Assert ($r.Out -match '## Routed intent: `feature`') 'feature intent not routed'
    Assert ($r.Out -match 'never add a harness incidentally') 'feature rail permits adding a test harness incidentally'
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

It 'route-prompt.ps1 both surfaces -> plan gate asks first with the tech-lead list and evidence-tagged assumptions' {
    $c = Invoke-Hook $rpPs (New-CopilotPrompt 'implement a new export button')
    $o = $c.Out | ConvertFrom-Json
    Assert ($o.additionalContext -match 'ASK FIRST' -and $o.additionalContext -match 'at most five' -and $o.additionalContext -match 'marked unverified') 'Copilot plan gate lacks ask-first, the cap or the evidence tag'
    $k = Invoke-Hook $rpPs (New-ClaudePrompt 'implement a new export button')
    Assert ($k.Out -match 'ASK FIRST' -and $k.Out -match 'at most five' -and $k.Out -match 'marked unverified') 'Claude plan gate lacks ask-first, the cap or the evidence tag'
}

# --- Security overlay reaches the Copilot shape ---
It 'route-prompt.ps1 Copilot event -> security overlay for payment prompt' {
    $r = Invoke-Hook $rpPs (New-CopilotPrompt 'implement payment processing')
    $o = $r.Out | ConvertFrom-Json
    Assert ($o.additionalContext -match 'Security-sensitive surface detected') 'security overlay missing'
}

# --- The security pass is the skill, which captures the scope bundle; the auditor refuses a bare diff request ---
It 'route-prompt.ps1 and the carrier -> security pass names the security-gate skill and offers the auditor only as what it runs' {
    $r = Invoke-Hook $rpPs (New-ClaudePrompt 'implement payment processing')
    $item = @($r.Out -split "`n" | Where-Object { $_ -match '^1\. Run this repository' })
    Assert ($item.Count -eq 1) "expected one overlay item 1, found $($item.Count)"
    Assert ($item[0] -match 'security-gate skill' -and $item[0] -match 'not the CLI''s built-in security agent') 'overlay item 1 lost the skill name or the Copilot CLI clause'
    Assert ($item[0] -match 'refuses a bare diff request' -and $item[0] -notmatch 'cannot examine a raw diff') 'overlay item 1 overclaims or omits what the auditor does with a bare diff'
    Assert ($item[0] -match 'runs the security-auditor' -and $item[0] -notmatch '\bor (its|the) `?security-auditor') 'overlay item 1 offers the auditor as an alternative to the skill'
    $carrier = [IO.File]::ReadAllText((Join-Path $hooks '..\..\.github\instructions\framework-rules.instructions.md'))
    $pass = @($carrier -split "`n" | Where-Object { $_ -match '^\*\*Security-sensitive surfaces always get a security pass' })
    Assert ($pass.Count -eq 1) "expected one carrier security-pass paragraph, found $($pass.Count)"
    Assert ($pass[0] -match '`security-gate` skill' -and $pass[0] -match 'not the CLI''s built-in security agent') 'carrier security pass lost the skill name or the Copilot CLI clause'
    Assert ($pass[0] -match 'refuses a bare diff request' -and $pass[0] -notmatch 'cannot examine a raw diff') 'carrier security pass overclaims or omits what the auditor does with a bare diff'
    Assert ($pass[0] -match 'runs `security-auditor`' -and $pass[0] -notmatch '\bor (its|the) `?security-auditor') 'carrier security pass offers the auditor as an alternative to the skill'
}

# --- A background-task notification re-fires UserPromptSubmit with the notification as the prompt (Claude Code 2.1.300) ---
It 'route-prompt.ps1 Claude background-task notification -> no rails, no routing; a real prompt that mentions the tag still routes' {
    $note = "<task-notification>`n<task-id>by1n9tdjr</task-id>`n<status>completed</status>`n<summary>Background command `"Fix the failing payment build`" completed (exit code 0)</summary>`n</task-notification>"
    foreach ($p in $note, " `n$note", ($note + "`n")) {
        $r = Invoke-Hook $rpPs (New-ClaudePrompt $p)
        Assert ($r.Exit -eq 0 -and [string]::IsNullOrWhiteSpace($r.Out)) "a task notification must be a no-op, got exit $($r.Exit) output: $($r.Out)"
    }
    $real = Invoke-Hook $rpPs (New-ClaudePrompt 'implement a parser for the <task-notification> wrapper')
    Assert ($real.Exit -eq 0 -and $real.Out -match '## Routed intent: `feature`') 'a developer prompt that mentions the tag stopped routing'
    $typed = Invoke-Hook $rpPs (New-ClaudePrompt ($note + "`nimplement a new export button"))
    Assert ($typed.Exit -eq 0 -and $typed.Out -match '## Routed intent: `') 'a typed request pasted after a notification was swallowed'
    $copilot = Invoke-Hook $rpPs (New-CopilotPrompt $note)
    Assert ($copilot.Exit -eq 0 -and -not [string]::IsNullOrWhiteSpace($copilot.Out)) 'the Copilot shape must not take the Claude task-notification exit'
    Assert (($copilot.Out | ConvertFrom-Json).additionalContext -match 'Routed intent: `fix`') 'Copilot shape: a keyword-bearing notification stopped routing'
}

# --- Authentication changes named by their mechanism or status code, never by "auth", still get the overlay ---
It 'route-prompt.ps1 both surfaces -> security overlay for authentication changes that never say auth' {
    $p = 'Only the shipping service may call the ship endpoint: make POST api/checkout/{orderId}/ship return 401 unless the X-Shipping-Key request header equals the configured Shipping:ApiKey value.'
    $claude = Invoke-Hook $rpPs (New-ClaudePrompt $p)
    Assert ($claude.Exit -eq 0) "Claude exit $($claude.Exit)"
    Assert ($claude.Out -match 'Security-sensitive surface detected') 'Claude surface: no security overlay for an API-key check'
    $copilot = Invoke-Hook $rpPs (New-CopilotPrompt $p)
    Assert ($copilot.Exit -eq 0) "Copilot exit $($copilot.Exit)"
    Assert (-not [string]::IsNullOrWhiteSpace($copilot.Out)) 'Copilot surface: no output for an API-key check'
    Assert (($copilot.Out | ConvertFrom-Json).additionalContext -match 'Security-sensitive surface detected') 'Copilot surface: no security overlay for an API-key check'
    # One prompt per keyword and per anchored half; each matches through that keyword alone.
    foreach ($q in @(
        'Make the orders endpoint require a valid API key',
        'Return 403s to callers outside the partner list',
        'Return Forbid() when the caller is not the owner',
        'Add an AccessControl attribute to the orders controller',
        'Configure AddJwtBearer to validate the issuer and audience',
        'Add OAuth2 for the partner app',
        'Add OpenID Connect to the portal',
        'Wire up OIDC with Entra ID',
        'Add OidcOptions to Program.cs',
        'Call AddOidc in startup',
        'Add SSO for the admin pages',
        'Add Sustainsys.Saml2 to the partner portal',
        'Verify the HMAC of incoming webhooks',
        'Add RequireMfa to the admin policy',
        'Set MfaEnabled for staff',
        'Require 2FA for admins',
        'Make TwoFactorEnabled required for admin users'
    )) {
        $r = Invoke-Hook $rpPs (New-ClaudePrompt $q)
        Assert ($r.Exit -eq 0 -and $r.Out -match 'Security-sensitive surface detected') "no security overlay for: $q"
    }
    $plain = Invoke-Hook $rpPs (New-CopilotPrompt 'add a primary key to the orders table')
    Assert (($plain.Out | ConvertFrom-Json).additionalContext -notmatch 'Security-sensitive surface detected') 'a primary-key change got the security overlay'
    # Near misses: processor (sso), ItemFactory (mfa), AndroidClient (oidc), a commit hash (2fa) and an SDK version (403) must not fire.
    $nearMiss = Invoke-Hook $rpPs (New-ClaudePrompt 'Rename OrderProcessor, ItemFactory and AndroidClient, revert commit 4c2fa91 and pin the .NET SDK to 8.0.403')
    Assert ($nearMiss.Exit -eq 0 -and $nearMiss.Out -notmatch 'Security-sensitive surface detected') 'a near miss got the security overlay'
}

# --- Keywords match whatever the culture: tr-TR lowers "I" to a dotless i (U+0131) ---
It 'route-prompt.ps1 both surfaces under tr-TR -> uppercase-I keywords still route and get the security overlay' {
    # The hook runs inside a wrapper that sets tr-TR first; exit 3 means the culture did not take, so nothing was examined.
    $wrapper = Join-Path ([IO.Path]::GetTempPath()) ('route-prompt-tr-' + [guid]::NewGuid().ToString('N') + '.ps1')
    $text = "[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::new('tr-TR')`n" +
        "if ([int][char]'I'.ToLower() -ne 0x131) { exit 3 }`n& '" + $rpPs.Replace("'", "''") + "'`nexit `$LASTEXITCODE`n"
    [IO.File]::WriteAllText($wrapper, $text, (New-Object System.Text.UTF8Encoding($true)))
    try {
        foreach ($p in 'Add LOGIN throttling', 'Require an API key on the orders endpoint', 'Add OpenID Connect to the portal') {
            $r = Invoke-Hook $wrapper (New-ClaudePrompt $p)
            Assert ($r.Exit -eq 0 -and $r.Out -match 'Security-sensitive surface detected') "tr-TR, Claude: no security overlay (exit $($r.Exit)) for: $p"
        }
        $copilot = Invoke-Hook $wrapper (New-CopilotPrompt 'Add LOGIN throttling')
        Assert ($copilot.Exit -eq 0 -and -not [string]::IsNullOrWhiteSpace($copilot.Out)) "tr-TR, Copilot: no output (exit $($copilot.Exit))"
        Assert (($copilot.Out | ConvertFrom-Json).additionalContext -match 'Security-sensitive surface detected') 'tr-TR, Copilot: no security overlay for: Add LOGIN throttling'
        $fix = Invoke-Hook $wrapper (New-ClaudePrompt 'FIX the date formatting')
        Assert ($fix.Exit -eq 0 -and $fix.Out -match '## Routed intent: `fix`') "tr-TR, Claude: FIX did not route (exit $($fix.Exit))"
    } finally { Remove-Item -LiteralPath $wrapper -Force -ErrorAction SilentlyContinue }
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

    It 'route-prompt.ps1 in a subfolder install delivers the install''s own queue, not the outer root''s' {
        $fixture = New-RoutePromptFixture
        $app = Join-Path $fixture.Dir 'outer\app'
        $queue = Join-Path $app '.claude\.state\boy-scout-queue'
        $outerQueue = Join-Path $fixture.Dir 'outer\.claude\.state\boy-scout-queue'
        try {
            $hook = Copy-HookInto $rpPs $app
            git -C (Join-Path $fixture.Dir 'outer') init --quiet
            foreach ($q in $queue, $outerQueue) { New-Item -ItemType Directory -Path (Split-Path -Parent $q) -Force | Out-Null }
            [IO.File]::WriteAllText($queue, 'SUBFOLDER_OWN_QUEUE_SENTINEL')
            [IO.File]::WriteAllText($outerQueue, 'SUBFOLDER_OUTER_QUEUE_SENTINEL')
            $r = Invoke-Hook $hook (New-CopilotPrompt '/review')
            Assert ($r.Exit -eq 0) "exit $($r.Exit): $($r.Err)"
            $o = $r.Out | ConvertFrom-Json
            Assert ($o.additionalContext -eq 'SUBFOLDER_OWN_QUEUE_SENTINEL') "expected the install's own queue, got '$($o.additionalContext)'"
            Assert (-not (Test-Path -LiteralPath $queue)) 'the install''s queue was not consumed'
            Assert (Test-Path -LiteralPath $outerQueue) 'the outer root''s queue was consumed'
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
