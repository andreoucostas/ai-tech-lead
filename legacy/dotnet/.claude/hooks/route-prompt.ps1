# UserPromptSubmit router -- classify natural-language prompts into a workflow
# and inject the matching workflow's deterministic rails before the model responds.
# PowerShell equivalent of route-prompt.sh, for Windows-only PowerShell teams.
# Plain stdout is treated as additionalContext by Claude Code.
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
- No new interface, abstract class, or generic helper unless a second consumer exists in this change-set. State the second consumer if you add one.
- Wrappers must add behavior. Inline shallow delegates.
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
- Do not introduce new interfaces, helpers, or wrappers as part of a refactor unless they replace at least as much code as they add.
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

if ([string]::IsNullOrEmpty($intent)) { exit 0 }

Write-Output "## Routed intent: ``$intent``"
Write-Output ''
Write-Output "This natural-language prompt was classified as **$intent**. Apply the rails for that workflow before responding. If the user's actual intent differs, ignore these rails and proceed normally -- but state explicitly what you concluded the intent is."
Write-Output ''

switch ($intent) {
    'fix'      { Write-Output $railsFix }
    'feature'  { Write-Output $railsFeature }
    'refactor' { Write-Output $railsRefactor }
    'test'     { Write-Output $railsTest }
    'design'   { Write-Output $railsDesign }
    'debt'     { Write-Output $railsDebt }
    'review'   { Write-Output $railsReview }
}

exit 0
