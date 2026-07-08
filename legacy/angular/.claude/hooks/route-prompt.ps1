# UserPromptSubmit router -- classify natural-language prompts into a workflow
# and inject the matching workflow's deterministic rails before the model responds.
# PowerShell equivalent of route-prompt.sh, for Windows-only PowerShell teams.
# Claude Code treats plain stdout as additionalContext; Copilot (CLI >= v1.0.65, VS Code agent
# mode with Preview agent-hooks) consumes stdout only as JSON additionalContext -- see the
# surface dispatch at the bottom.
# Skips when the user explicitly invoked a slash command (already deterministic).
#
# ASCII-only: Windows PowerShell 5.1 reads .ps1 files as ANSI when no BOM is
# present. Em-dashes are written as "--" to avoid encoding mismatches.

$ErrorActionPreference = 'SilentlyContinue'

# Rails are defined at module level so here-string close markers ('@) sit at
# column 0, which Windows PowerShell requires.

$railsFix = @'
1. Diagnose root cause first; state it before writing any code.
2. Write a failing regression test BEFORE touching production code; confirm it fails for the right reason.
3. Apply the minimal fix; do not refactor unrelated code.
4. Verify the regression test passes, the full related suite passes, build is clean, lint is clean.
5. Apply Boy Scout to BLAST RADIUS only -- never boy-scout unrelated files in a fix.
6. Report root cause, fix, regression-test coverage, blast radius.
'@

$railsFeature = @'
1. Design check first -- list affected layers, files to create/modify, failure modes, test strategy.
2. Decompose into ordered subtasks; run build + test + lint after each before continuing.
3. Apply Boy Scout to every file you touch.
4. Self-review against CLAUDE.md > Conventions; flag new patterns or resolved tech debt.
5. Present what was implemented and tested.

Leanness constraints (CLAUDE.md > Leanness):
- Prefer editing existing files over creating new ones.
- No new interface, abstract class, pipe, or directive unless a second consumer exists in this change-set. State the second consumer if you add one.
- Wrappers must add behavior. Inline shallow service methods that just call HttpClient.
- No defensive code for impossible states; no comments that restate code; no future-proofing.
'@

$railsRefactor = @'
1. Verify starting state -- build and tests must pass BEFORE touching anything.
2. If no tests exist for the target code, write baseline tests FIRST.
3. Refactor incrementally; build + test after each meaningful change.
4. Apply Boy Scout to every file you touched.
5. Verify final state -- no behavior should have changed.
6. Present a before/after summary INCLUDING net LOC delta.

Leanness constraints (CLAUDE.md > Leanness):
- Trend toward less code: delete dead branches, inline single-use abstractions, remove now-redundant types.
- A refactor that grows the codebase needs an explicit reason in the summary.
- Do not introduce new interfaces, helpers, pipes, or wrappers as part of a refactor unless they replace at least as much code as they add.
'@

$railsTest = @'
1. Match existing test structure, naming convention, framework, and mocking approach.
2. Cover happy path, edge cases, error paths, boundary conditions.
3. Do not test framework behavior -- test public behavior only.
4. Verify all new tests pass.
5. Report what was tested and what is still uncovered.
'@

$railsDesign = @'
**DO NOT WRITE ANY CODE.** Produce a design document only.
1. Understand the requirement -- goal, users, acceptance criteria, scope boundary.
2. Analyse impact -- layers affected, files changing, patterns to reuse.
3. Consider at least two approaches with pros/cons and effort estimates.
4. Recommend, with specifics -- component structure, state, services, tests.
5. Surface open questions for the developer to answer before /feature.
'@

$railsDebt = @'
1. Read TECH_DEBT.md and find items in the specified area.
2. Confirm each item still exists in the code (it may have been fixed already).
3. Recommend fix-now vs defer per item, with reason.
4. After fixes: update TECH_DEBT.md -- remove resolved items, add newly discovered.
5. Apply Boy Scout to every file touched.
6. Report what was fixed/deferred plus the updated TECH_DEBT diff.
'@

$railsReview = @'
This is a quality gate, not a rubber stamp.
1. Check correctness and every CLAUDE.md > Conventions item per changed file.
2. Check test quality -- behavior coverage, descriptive names, regression detection.
3. Run build + tests yourself -- do not trust they pass.
4. Check architecture/debt trajectory and Boy Scout application.
Output: APPROVE or REQUEST CHANGES with a severity-tagged issues table.
'@

$railsSecurity = @'
## Security-sensitive surface detected

This prompt touches a security-sensitive area (auth, tokens, session, PII, output sanitisation). DORA's evidence is that AI amplifies existing weaknesses fastest here, so this overlay applies ON TOP OF any workflow rails above. Before presenting the change as complete:
1. Run /security-review on the diff (or invoke the security-auditor agent) -- do not self-certify.
2. Never bypass Angular's sanitisation (bypassSecurityTrust*, direct innerHTML) without an explicit, reviewed reason; rely on the framework's escaping.
3. Keep tokens/secrets out of localStorage where an httpOnly cookie is viable; never log credentials or PII.
4. Validate and encode at trust boundaries (route params, HTTP responses, user input); guard against XSS/CSRF.
5. Record anything you could not fully verify in SECURITY_FINDINGS.md.
If this prompt does NOT actually touch a sensitive surface, say so and skip this overlay.
'@

$railsPlanGate = @'
## Plan gate (present -> clarify -> confirm)
Before writing code: post a short plan (files to change, order of operations, how you'll verify) AND any clarifying questions for whatever is underspecified -- do not guess past a material ambiguity to seem helpful. Then WAIT for the developer's explicit go-ahead before editing code. Skip the wait only for a trivial, unambiguous change (typo, one-liner), and say that you're skipping it and why.
'@

$inputJson = [Console]::In.ReadToEnd()
if ([string]::IsNullOrEmpty($inputJson)) { exit 0 }

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
if ([string]::IsNullOrEmpty($prompt)) { exit 0 }

# Skip if the user already chose a workflow.
if ($prompt.StartsWith('/')) { exit 0 }

$lc = $prompt.ToLower()

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
if ($isQuestion -and -not $hasImperative -and $intent -in @('fix','feature','refactor','test')) { $intent = '' }

# Security overlay fires IN ADDITION to any workflow intent -- it is not an
# exclusive intent, so a security-relevant feature still gets the feature rails.
$sensitive = $lc -match '(\bauth\b|authenticat|authori[sz]|login|password|secret|token|credential|session|cookie|\bjwt\b|permission|\brole\b|\bpii\b|personal data|gdpr|encrypt|sanitiz|bypasssecuritytrust|innerhtml|\bxss\b|\bcsrf\b|payment|money|currency)'

if ([string]::IsNullOrEmpty($intent) -and -not $sensitive) { exit 0 }

$parts = New-Object System.Collections.Generic.List[string]
if (-not [string]::IsNullOrEmpty($intent)) {
    $parts.Add("## Routed intent: ``$intent``")
    $parts.Add('')
    $parts.Add("This natural-language prompt was classified as **$intent**. The rails below mirror ``CLAUDE.md > Agentic Workflow`` section 1 -- the canonical definition, already in your context; they are repeated here for salience. Apply them before responding. If the actual intent differs, say so and proceed normally.")
    $parts.Add('')

    if ($intent -in @('fix','feature','refactor','test')) {
        $parts.Add($railsPlanGate)
        $parts.Add('')
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
    $parts.Add('')
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
    $payload = @{
        additionalContext  = $body
        hookSpecificOutput = @{ hookEventName = 'UserPromptSubmit'; additionalContext = $body }
    }
    Write-Output ($payload | ConvertTo-Json -Compress -Depth 4)
}

exit 0
