# UserPromptSubmit router -- classify natural-language prompts into a workflow
# and inject the matching workflow's deterministic rails before the model responds.
# PowerShell equivalent of route-prompt.sh, for Windows-only PowerShell teams.
# Claude Code treats plain stdout as additionalContext; Copilot (CLI >= v1.0.65, VS Code agent
# mode with Preview agent-hooks) consumes stdout only as JSON additionalContext -- see the
# surface dispatch at the bottom.
# Skips when the user explicitly invoked a slash command (already deterministic).
#
# Unicode rendered text is intentional and matches the canonical bash twin. The mandatory UTF-8
# BOM keeps Windows PowerShell 5.1 decoding these strings correctly.

$ErrorActionPreference = 'SilentlyContinue'

# Emit UTF-8 when captured: consuming harnesses read raw bytes, and the default
# [Console]::OutputEncoding (the OEM code page on Windows) would mangle ⚠/—/🔴 into '?'.
# Guarded so an interactive console's code page is never changed.
if ([Console]::IsOutputRedirected) {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
}

# Rails are defined at module level so here-string close markers ('@) sit at
# column 0, which Windows PowerShell requires.

$railsFix = @'
1. Diagnose root cause first; state it before writing any code.
2. When the repository evidences an applicable test harness, write a failing regression test BEFORE touching production code; otherwise reproduce with the strongest evidenced validation and report tests as not available — never introduce a foreign harness solely for this fix.
3. Apply the minimal fix; do not refactor unrelated code.
4. Derive exact regression and suite commands plus applicable build, test, format, lint, migration/deploy, and data-validation commands from repository evidence; run only safely executable applicable commands under the execution boundary above and report each unsupported category as not available.
5. Apply Boy Scout to BLAST RADIUS only — never boy-scout unrelated files in a fix.
6. Report root cause, fix, regression-test coverage, blast radius.
'@

$railsFeature = @'
1. Design check first — list affected layers, files to create/modify, failure modes, test strategy.
2. Decompose into ordered subtasks; derive exact build, test, format, lint, migration/deploy, and data-validation commands from repository evidence, then run only safely executable applicable commands under the execution boundary above after each before continuing (report unsupported categories as not available).
3. Apply Boy Scout to every file you touch.
4. Self-review against CLAUDE.md > Conventions; flag new patterns or resolved tech debt.
5. Present what was implemented and tested.

Leanness constraints (the framework rules (`.github/instructions/framework-rules.instructions.md` › Leanness; `AGENTS.md` › Leanness on AGENTS.md-native tools)):
- Prefer editing existing files over creating new ones.
# @stack:leanness-feature
- No defensive code for impossible states; no comments that restate code; no future-proofing.
'@

$railsRefactor = @'
1. Derive exact build, test, format, lint, migration/deploy, and data-validation commands from repository evidence and establish a green baseline BEFORE touching anything; report unsupported categories as not available.
2. If the repository has an applicable test harness but the target lacks coverage, write baseline tests FIRST; otherwise report tests as not available, use the strongest evidenced validation, and never introduce a foreign harness solely for this refactor.
3. Refactor incrementally; run applicable checks after each meaningful change.
4. Apply Boy Scout to every file you touched.
5. Verify final state — no behavior should have changed.
6. Present a before/after summary INCLUDING net LOC delta.

Leanness constraints (the framework rules (`.github/instructions/framework-rules.instructions.md` › Leanness; `AGENTS.md` › Leanness on AGENTS.md-native tools)):
- Trend toward less code: delete dead branches, inline single-use abstractions, remove now-redundant types.
- A refactor that grows the codebase needs an explicit reason in the summary.
# @stack:leanness-refactor
'@

$railsTest = @'
1. Match existing test structure, naming convention, framework, and mocking approach.
2. Choose the smallest risk-relevant set: the principal behavior plus only consequential error, edge, or boundary cases; do not build a case matrix for its own sake.
3. Do not test framework behavior — test public behavior only.
4. Derive exact applicable build, test, format, lint, migration/deploy, and data-validation commands from repository evidence; run only safely executable applicable commands under the execution boundary above and report every unsupported category as not available.
5. Report what was tested and what's still uncovered.
'@

$railsDesign = @'
**DO NOT WRITE ANY CODE.** Produce a design document only.
1. Understand the requirement — goal, users, acceptance criteria, scope boundary.
2. Analyse impact — layers affected, files changing, patterns to reuse.
3. Consider at least two approaches with pros/cons and effort estimates.
4. Recommend, with specifics — component structure, state, services, tests.
5. Surface open questions for the developer to answer before /feature.
'@

$railsDebt = @'
1. Read TECH_DEBT.md and find items in the specified area.
2. Confirm each item still exists in the code (it may have been fixed already).
3. Derive applicable tests and other validation from repository evidence; when no test harness exists, report tests as not available and use the strongest evidenced validation — never introduce a foreign harness solely for debt cleanup.
4. Recommend fix-now vs defer per item, with reason.
5. After fixes: update TECH_DEBT.md — remove resolved items, add newly discovered.
6. Apply Boy Scout to every file touched.
7. Report what was fixed/deferred plus the validation results and updated TECH_DEBT diff.
'@

$railsReview = @'
This is a quality gate, not a rubber stamp.
1. Check correctness and every CLAUDE.md > Conventions item per changed file.
2. Check test quality — behavior coverage, descriptive names, regression detection.
3. Derive and run only safely executable build, test, format, lint, migration/deploy, and data-validation commands supported by repository evidence yourself, subject to the execution boundary above; do not trust they pass, and report unsupported categories as not available.
4. Check architecture/debt trajectory and Boy Scout application.
Output: APPROVE or REQUEST CHANGES with a severity-tagged issues table.
'@

$railsSecurity = @'
## Security-sensitive surface detected

# @stack:sec-intro
1. Run /security-review on the diff (or invoke the security-auditor agent) — do not self-certify.
# @stack:sec-items
If this prompt does NOT actually touch a sensitive surface, say so and skip this overlay.
'@

$railsPlanGate = @'
## Plan gate (present -> clarify -> confirm)
Before writing code: post a short plan (files to change, order of operations, how you'll verify) AND any clarifying questions for whatever is underspecified — do not guess past a material ambiguity to seem helpful. Then WAIT for the developer's explicit go-ahead before editing code. Skip the wait only for a trivial, unambiguous change (typo, one-liner), and say that you're skipping it and why.
'@

$railsExecutionSafety = @'
## Verification execution boundary
Derive all six command categories, but run only safely executable verification. A recorded migration/deploy command is manual/CI-only unless repository evidence identifies that exact invocation as non-mutating validation/dry-run, or the developer explicitly authorizes execution against a known target. Otherwise report it as recorded but not run.
'@

$inputJson = [Console]::In.ReadToEnd()
if ([string]::IsNullOrEmpty($inputJson)) { exit 0 }
$isClaude = $inputJson -match '"hook_event_name"'

# Try ConvertFrom-Json first (handles escapes correctly); fall back to regex if it fails.
$prompt = ''
try {
    $obj = $inputJson | ConvertFrom-Json
    if ($obj -and $obj.prompt) { $prompt = [string]$obj.prompt }
} catch {
    if ($inputJson -match '"prompt"\s*:\s*"([^"]*)"') {
        $prompt = $Matches[1]
    }
}
if ([string]::IsNullOrEmpty($prompt) -and $isClaude) { exit 0 }

# Skip if the user already chose a workflow.
if ($prompt.StartsWith('/') -and $isClaude) { exit 0 }

$routeEligible = -not [string]::IsNullOrEmpty($prompt) -and -not $prompt.StartsWith('/')
$lc = if ($routeEligible) { $prompt.ToLower() } else { '' }

# Priority order: review > debt > design > test > fix > refactor > feature
$intent = ''
if     ($lc -match '(review this|review the|review my (changes|pr|code)|quality gate)')                                                   { $intent = 'review' }
elseif ($lc -match '(tech debt|technical debt|cleanup debt|debt (in|register))')                                                          { $intent = 'debt' }
elseif ($lc -match "(how should i|what'?s the best way|design (a|the)|approach (for|to)|how would you|trade.?offs?)")                     { $intent = 'design' }
elseif ($lc -match '(write tests?|add tests?|test coverage|increase coverage|generate tests?)')                                            { $intent = 'test' }
elseif ($lc -match '(\bfix\b|\bbug\b|\bbroken\b|\bcrash|\bfails?\b|\bfailing\b|\bthrows?\b|\bthrowing\b|\bregression\b|not working)')      { $intent = 'fix' }
elseif ($lc -match '(\brefactor\b|cleanup|clean up|\bextract\b|\brename\b|simplify|reorganis[ez]|restructure|\btidy\b)')                  { $intent = 'refactor' }
elseif ($lc -match '(\badd\b|\bimplement\b|\bcreate\b|\bbuild\b|new (feature|endpoint|component|service|screen|route))')                  { $intent = 'feature' }

# Answer-only carve-out (CLAUDE.md section 1): a question-shaped prompt with no
# imperative verb asks for an explanation, not a code change -- don't impose workflow
# ceremony. Clearing $intent suppresses the rails + plan-gate; the security overlay
# below still fires if the question touches a sensitive surface.
$isQuestion = ($lc -match "^\s*(why|what|what'?s|how come|when|where|which|who|is|are|does|do|can|could|would|should)\b") -or ($prompt.TrimEnd() -match '\?$')
$hasImperative = $lc -match '\b(add|fix|implement|create|build|make|change|update|modify|remove|delete|refactor|rename|extract|write|test|review|clean\s?up|migrate|wire|integrate|introduce)\b'
if ($isQuestion -and -not $hasImperative -and $intent -in @('fix','feature','refactor','test','debt')) { $intent = '' }

# Security overlay fires IN ADDITION to any workflow intent -- it is not an
# exclusive intent, so a security-relevant feature still gets the feature rails.
# @stack:sensitive-regex

if ([string]::IsNullOrEmpty($intent) -and -not $sensitive -and $isClaude) { exit 0 }

$parts = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrEmpty($intent)) {
    $parts.Add("## Routed intent: ``$intent``")
    $parts.Add('')
    $parts.Add("This natural-language prompt was classified as **$intent**. The rails below mirror the framework rules (``.github/instructions/framework-rules.instructions.md`` › Agentic Workflow; ``AGENTS.md`` › Agentic Workflow on AGENTS.md-native tools) section 1 — the canonical definition, already in your context; they are repeated here for salience. Apply them before responding. If the actual intent differs, say so and proceed normally.")
    $parts.Add('')
    $parts.Add($railsExecutionSafety)
    $parts.Add('')

    if ($intent -in @('fix','feature','refactor','test')) {
        $parts.Add($railsPlanGate)
    }

    switch ($intent) {
        'fix'      { $parts.Add($railsFix) }
        'feature'  { $parts.Add($railsFeature) }
        'refactor' { $parts.Add($railsRefactor) }
        'test'     { $parts.Add($railsTest) }
        'design'   { $parts.Add($railsDesign) }
        'debt'     { $parts.Add($railsDebt) }
        'review'   { $parts.Add($railsReview) }
    }
}

if ($sensitive) {
    $parts.Add($railsSecurity)
}

$body = ($parts -join "`n")

# Surface dispatch. Claude Code includes hook_event_name in the event payload and treats plain
# stdout as additionalContext. Copilot parses stdout only as JSON: the CLI (>= v1.0.65) and
# VS Code agent mode (Preview agent-hooks) inject userPromptSubmitted additionalContext into the
# model-facing prompt -- emit both the top-level and wrapped shapes, mirroring guard.ps1's
# dual-shape approach. Older Copilot versions ignore this JSON output entirely: harmless no-op,
# same as before this hook was registered for Copilot.
if ($inputJson -match '"hook_event_name"') {
    Write-Output $body
} else {
    $candidateRoot = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\..'))
    $repoRoot = (& git -C $candidateRoot rev-parse --show-toplevel 2>$null | Select-Object -First 1)
    $queuedText = ''
    if ($repoRoot) {
        $repoRoot = [IO.Path]::GetFullPath($repoRoot.Trim())
        $queueFile = Join-Path $repoRoot '.claude\.state\boy-scout-queue'
        if (Test-Path -LiteralPath $queueFile) {
            $queuedText = [string](Get-Content -LiteralPath $queueFile -Raw)
            Remove-Item -LiteralPath $queueFile -Force
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($queuedText)) {
        if (-not [string]::IsNullOrEmpty($body)) { $body += "`n" }
        $body += $queuedText
    }
    if ([string]::IsNullOrEmpty($body)) { exit 0 }
    $payload = @{
        additionalContext  = $body
        hookSpecificOutput = @{ hookEventName = 'UserPromptSubmit'; additionalContext = $body }
    }
    Write-Output ($payload | ConvertTo-Json -Compress -Depth 4)
}

exit 0
