# Plan: the contract loop for consumers who never type a slash (2026-10-17, v2)

> Read-only spike at HEAD `ecf1479e`; re-read every `path:line` before editing; a cite that no longer matches is a
> finding to report, not a reason to guess. **Supersedes v1 of this file (committed at `ecf1479e`) by maintainer
> decision, 2026-10-17.** v1 centred on delivering the `review` skill to consumers who never type a slash; the
> maintainer re-centred the plan on defining the requirement before code, deriving the tests from it, and handing
> the reviewer a trace. v1's review sentence becomes Phase 5 of this plan; v1's rails retirement is out. v1's text
> stays in Git history for its citations and its B-406 pre-registration draft.

## 1. Problem, with evidence

A consumer types "add a refund endpoint" and never `/design`. What fires is the carrier's plan gate plus the
per-prompt rails (`route-prompt.ps1:106-109`, `:33-44`, `:24-31`). Read what the developer then approves:

- **A file list, never criteria.** Section 2 asks for files and order (`framework-rules.instructions.md:73`),
  validation (`:74`), assumptions (`:76`) and, on a material gap, five risk questions (`:77`). Nothing restates
  the behaviour. The one surface that writes acceptance criteria is `design.md` Step 1 and the spec template
  (`specs/README.md:35`), reached only through a typed command or the `design` regex
  (`route-prompt.ps1:142`, phrasing such as "how should I"). The carrier's only pointer to it is `:78`.
- **Tests are added, not derived.** The feature rail asks for "the smallest useful tests" (`route-prompt.ps1:34`);
  the fix rail for "a failing regression test" (`:26`). Rule 9 (`verif-rules`, dotnet carrier) catches a test
  that would never fail; it cannot catch a test that agrees with the code on a misread rule, the failure the
  O'Reilly piece names ("the tests can share the same mistake").
- **The report names commands, not criteria.** The Verification & confidence line (`verif-conf-line`, 489/498/538
  chars) separates run from asserted; nothing ties either to what was asked. `REVIEW-GUIDE.md:46-53` tells a
  reviewer to ask whether the author can explain the design; the playbook's PR template (`playbook.md:166-171`)
  asks "Did you run /design first?", and its progress metric (`:227`) treats raw prompts as the developer's
  failure. The field says raw prompts are the norm (B-403 plan §1 item 4).
- **Nothing in the loop can see the wrong thing being built.** None of the nine field reports is about intent
  (`meta/field-reports.md`), and the intake is defect-shaped by design (`:275-279`): a change that correctly
  implements a misread requirement passes every gate, including the tests the same agent wrote to match it.

Delivery evidence that shapes the fix: a required output shape lands where prose does not (a named skill
invoked 6/6 vs 1/6, B-341, `meta/BACKLOG-DONE.md:12947-12950`; rule-only naming reached 1 of 3, B-402,
`meta/BACKLOG.md:44`; an advance approval suppressed the always-loaded rule but not the per-prompt reminder,
B-389, `:13081-13086`). The carrier is the only channel reaching every host, including VS Code's Local harness
with hooks off (`docs/enforcement-surfaces.md:107`, `:181`); the rails reach every host that runs hooks at no
static cost.

## 2. Decision

Each change gets a **contract** that travels the whole loop: agreed before code, implemented and tested against,
reported against, reviewed against. Four parts, all on the path consumers already walk:

- **A. Restate, do not interrogate.** The plan the agent already posts opens with **Done when**: two to six
  observable criteria, each with a boundary example where a threshold, limit or state exists, plus what is out of
  scope. The developer corrects a list; the go-ahead approves it. The five tech-lead questions (`:77`) stay as
  they are and fire only on a material gap (B-403 measures that wording; this plan does not touch it).
- **B. Tests are derived.** Each Done-when line names the test that pins it; boundary examples become cases;
  assertions land at the point of effect, not a proxy. A changed expected value in an existing test, or an edited
  Done-when line, is a requirement change to confirm (Rule 5). The test critic gains one structural question:
  does each test pin a line, does each line have a test.
- **C. The trace is the PR description.** The Verification & confidence line becomes a block: each Done-when
  line → its test → the observed result; beyond the request; blast radius seen; review depth with the reason;
  baseline. The reviewer reads that and opens the diff where the block says the risk is. A spec file is written
  only when the lines outgrow a message or the work spans sessions, by the agent.
- **D. Review depth scales with blast radius.** A change touching a hazard row, a security-sensitive surface, a
  shared caller or an existing test's expectation gets the full `review` skill; the rest gets the block plus CI.
  Phase 3 gives this a deterministic input.

Principles: shapes, not prose; the rails carry the detail (per-prompt, no static cost) and the carrier one clause
per part (hook-less hosts); proportional (the trivial skip at `:80` stays; a one-line fix gets one line); **no new
command, agent, skill, hook or test file; no mandatory spec; no auto-review sentence in this patch; no rails
retirement** (WSD-100 stands and reopens only on its own clause).

## 3. The edits (current text → proposed text; all under `src/`, never `dist/`)

Character counts are LF-normalised UTF-8 bytes of the proposed text, measured 2026-10-17; the implementer
re-measures with `scripts/context-footprint.ps1 -Check` after the build.

### 3.1 Carrier section 2 (`src/core/.github/instructions/framework-rules.instructions.md:71-80`; always loaded)

- `:72` (88 chars) → `For any non-trivial task, STOP before writing code and post a short plan, in this order:`
- New bullet before `:73` (+319):
  `- **Done when**: the requirement restated as two to six observable criteria, each with a boundary example where a threshold, limit or state exists (the case that passes and the one that does not), plus what is out of scope. The developer corrects these lines rather than answering questions; the go-ahead approves them.`
- `:73` unchanged.
- `:74` (65 chars) → (350, +285):
  `- Evidenced validation: for each Done-when line, the test that will pin it, asserting at the point of effect (what leaves the service or is persisted, not a proxy such as a call having been made); boundary examples become cases. Include tests only when a harness exists; otherwise name the strongest evidenced check and report tests as not available.`
- `:75`, `:76`, `:77` unchanged (`:77` is B-403's measured wording).
- `:78` (112 chars) → (176, +64):
  `- When the Done-when lines outgrow one message, or the work will span sessions, write them to `specs/<slug>.md` yourself (template: `specs/README.md`) and implement against it.`
- `:80` unchanged.

### 3.2 Rule 5 (`src/stacks/{dotnet,angular,monorepo}/snippets/.github/instructions/framework-rules.instructions.md/verif-rules:5`, 237 chars each; always loaded)

Append (+176): ` A changed expected value in an existing test, or an edited Done-when line or acceptance criterion, is a requirement change: confirm it with the developer; it is never a green.` Angular's line says "spec" where the others say "test"; keep each stack's noun.

### 3.3 Verification & confidence block (`verif-conf-line:1` ×3, 489/498/538 chars; always loaded)

Replace the bullet (dotnet, 717 chars, +228; angular and monorepo keep their own example commands, `ng test --watch=false` → 87 passed, 0 failed, and both):
`- **Close with the Verification & confidence block**, which is also the pull request description: each Done-when line → the test that pins it → the command you ran and its observed result (e.g. `dotnet test` → 142 passed, 0 failed), or "asserted, not run"; **Beyond the request**: none, or each behaviour the diff adds that no line asked for; **Blast radius seen**: callers changed or affected as `path:symbol`, or none found; **Review depth**: light, or the full `review` skill with the reason (a hazard row, a security-sensitive surface, a shared caller, a changed test expectation); **Baseline**: spec, plan approved this session, or stated request only. Show the evidence, never the bare claim "tests pass".`
The dropped sentence ("This calibration is deliberate…", 111 chars) is rationale, not instruction. `src/core/.claude/workflow.md:20-26` (on demand, inlined by the commands) gets the same block with a generic example.

### 3.4 Rails (`src/core/.claude/hooks/route-prompt.ps1`; per prompt, no static cost; `.ps1`, keep the BOM)

- `$railsPlanGate` `:107-108` (821 chars) → (1,111 chars). Keep `ASK FIRST`, `at most five`, `marked unverified` (asserted by `RoutePrompt.Tests.ps1:66-72`):
  `## Plan gate (ask -> restate -> plan -> confirm)`
  `Before writing code: if the request leaves a material gap, ASK FIRST — at most five tech-lead questions (who consumes this and what breaks for them; what fails and how you'd know in production; rollback; data that moves or changes shape; blast radius against the hazard list), each with the assumption you'd otherwise make — and post the plan only after the answers. Otherwise post the plan now, in this order: DONE WHEN (two to six observable criteria, each with a boundary example where a threshold, limit or state exists; what is out of scope); files to change and order of operations; for each criterion the test that will pin it, asserting at the point of effect (boundary examples become cases); each assumption with the file, command or query that verified it or marked unverified. Do not guess past a material ambiguity to seem helpful. Then WAIT for the developer's explicit go-ahead before editing code; it approves the Done-when lines. Skip the wait only for a trivial, unambiguous change (typo, one-liner), and say that you're skipping it and why.`
- `$railsFix` `:26`: "write a failing regression test BEFORE touching production code" → "write the regression test that pins the Done-when line (the expected behaviour at the boundary, asserted at the point of effect) and see it fail BEFORE touching production code". `:30` → `6. Report root cause and fix, then the Verification & confidence block: each Done-when line → its test → the observed result; beyond the request; blast radius seen; review depth.`
- `$railsFeature` `:34`: "and the smallest useful tests when an applicable harness exists" → "and, for each Done-when line, the test that pins it (boundary examples become cases; assert at the point of effect) when an applicable harness exists". `:38` → `5. Present the Verification & confidence block: each Done-when line → its test → the observed result; beyond the request; blast radius seen; review depth.`
- `$railsReview` `:89-94`: add `5. Check the trace: every Done-when line (from the spec, else the approved plan, else the stated request; say which) has a test in scope and an observed result; anything in the diff beyond those lines is listed, never approved silently; a changed expected value in an existing test is a requirement change.`
- `$railsDesign`, `$railsRefactor`, `$railsTest`, `$railsDebt`, `$railsSecurity`, `$railsExecutionSafety`: unchanged.
- `meta/rail-sync.json`: the Feature and Bug fix pairs change for all three dists; re-record with `scripts/validate-dist.ps1 <dist> -Check rail-sync --update-rail-sync` after reading each rail against its section 1 bullet (the rails elaborate section 2; the bullets at `:64` are unchanged).

### 3.5 Commands (on demand; frontmatter unchanged, so no static cost)

- `fix.md:21`: the regression test "pins the Done-when line: the expected behaviour at the boundary, asserted at the point of effect, and fails for the right reason before the fix". `:38-42` Step 7 → the block of 3.3.
- `feature.md:15`: "recommend `/design` first (it writes one)" → "write `specs/<slug>.md` yourself from `specs/README.md` when the Done-when lines you posted outgrow the message or the work spans sessions". `:21` → `- Which test pins each Done-when line, at the point of effect?` `:26`: "State the plan: Done when first, then files…". `:41` Step 5 → the block.
- `review.md:51` ("Give every applicable reviewer the requested behaviour…"): add the Done-when lines (spec, else the approved plan, else the stated request; say which). `:86` **Spec conformance** → **Contract conformance**: the baseline in that order; every line has a test in the bundle and an observed result; unmet lines, scope creep and changed expected values are issues. `:112` add `- Done-when lines pinned: <N of M, from test-critic; or no criteria supplied>`.
- `design.md:87-93`: note that on the natural-language path the plan gate restates the criteria and the agent persists them when they outgrow the message; `:93` "they run `/feature`" → "they say go, or run `/feature`".
- `specs/README.md:7-16`: add the natural-language path to the lifecycle: a plain request → the plan gate posts Done-when lines → go-ahead → the agent writes this spec only when the lines outgrow the message or the work spans sessions → `/review` verifies it.

### 3.6 Test critic (`src/stacks/{dotnet,angular,monorepo}/files/.claude/agents/test-critic.md`; body only, no static cost)

Add to the checklist (dotnet after `:27`, angular after `:27`, monorepo after `:31`):
`- **Untraced or unpinned** — `medium`: a new test that pins no Done-when line or spec acceptance criterion in scope (name the test), or a line in scope with no test (name the line); a stated boundary with no case on each side of it; an assertion on a proxy (a request was created, a method was called) where the point of effect (what left the service, what was persisted or rendered) is observable. Take the lines from the spec, else the approved plan the parent supplies, else report `no criteria supplied`.`
Output, under `### Would-fail-if-broken verdict` (`:41`/`:41`/`:45`): `- Done-when lines pinned: <N of M, or no criteria supplied>`. Stack-specific wording follows each file's existing voice.

### 3.7 Documentation (zero static)

- `REVIEW-GUIDE.md:46-53` ×3: replace the three questions with: does every Done-when line have a test at its boundary; does anything in the diff fall under Beyond the request; where does the block say to look. Add "What the agent hands you": the block of 3.3 as the PR description, and "Review depth": full review when the block says so, light otherwise, with the reason read before the diff.
- `playbook.md` ×3 (dotnet and angular `:159-171`, monorepo `:161-173`): "The /design command is the gatekeeper" → the Done-when lines are the gatekeeper for every non-trivial request, `/design` for deliberate design work; the PR template becomes the block plus "why this approach, what alternatives". The "Command usage" metric (`:227`; monorepo `:229`) becomes Done-when lines present in PR descriptions.
- `src/core/docs/getting-started.md:68`: "It posts a plan: the files…" → "It restates what done means: two to six criteria with boundary examples and what is out of scope, then the files it will change and the test that pins each criterion". `:73`: the line → the block, and "paste it into your pull request description".
- `src/core/docs/reference.md:116`: "Specs written by `/design`" → "Specs written by `/design`, or by the agent when a change's Done-when lines outgrow the plan message."
- `ci-integration.md`: untouched here (Phase 3).

### 3.8 CHANGELOGs (Invariant 7)

Root `CHANGELOG.md` under a new `## 0.98.0 — Unreleased` head, maintainer's voice; `src/stacks/*/files/CHANGELOG.md` the same head, consumer's voice, for example: "Before code, the agent now restates what done means: two to six criteria with a boundary example each and what is out of scope; your go-ahead approves them. Tests are derived from those lines and assert at the point of effect. The closing Verification & confidence block pairs each line with its test and result, lists anything beyond the request, the blast radius seen and whether a full review is warranted; paste it into your pull request." Mind `no-meta-leak` (`scripts/meta-denylist.txt`): no B- or WSD- numbers in the three consumer files.

### 3.9 Budget (static, LF-normalised chars; `meta/context-footprint.json` at `ecf1479e`)

| Dist | Used | Ceiling | Carrier | Estimated change (3.1 + 3.2 + 3.3) | After |
|---|---|---|---|---|---|
| dotnet | 38,595 | 40,000 | 19,639 | +16 +319 +285 +64 +176 +228 = +1,088 | 39,683 |
| angular | 36,384 | 40,000 | 19,195 | about +1,090 | about 37,470 |
| monorepo | 42,973 | 48,000 | 21,113 | about +1,090 | about 44,060 |

dotnet fits with 317 to spare; a ceiling breach is the maintainer's call (AGENTS.md › Verification). Cut candidates
if the maintainer wants headroom back, each rationale rather than instruction, measured in the dotnet carrier: Rule 9's
"*Why:*" sentence (173), Test leanness #14's (182), #15's (121); the Done-when bullet's parenthesis "(the case that
passes and the one that does not)" (52). Per-prompt growth: the plan-gate rail +290, the fix and feature rails about
+150 each; recorded in the baseline, not gated.

## 4. B-406 pre-registration (frozen in Phase 0 before any run; written into `meta/eval-results.md` in the style of B-388 and B-405)

- **Q.** On the natural-language path, with the contract patch installed, does the agent (a) post Done-when lines
  with at least one boundary example before any file write and stop for the go-ahead; (b) write tests that assert
  each stated outcome; (c) close with the block? Compared with 0.97.2 as installed.
- **T.** `-TargetPatch` (`run-agent-evals.ps1:30`, `:796-825`; cut with `git diff --output`, DEVELOPING.md `:312-319`)
  applying 3.1, 3.2, 3.3 and 3.4 to the installed `dist/dotnet` carrier and `route-prompt.ps1`; nothing else. **C.**
  0.97.2 as installed. Both on a fresh clone per run of the frozen fixture.
- **Fixture.** B-337's bootstrapped orders repository (`meta/eval-results.md:3547-3549`) at HEAD's `dist/dotnet`,
  frozen under `meta/eval-fixtures/b406-orders/` with its hash recorded, after the `RepositoryPrivacy` test passes
  on it and its size is reported; scenarios name it with `fixture` (`run-agent-evals.ps1:4673`).
- **Prompts.** S1 `contract-restate`: B-348's prompt K (`:3565-3567`) with its approval clause removed (K's first
  sentence alone, B-348's R): the agent should stop at the gate. S2 `contract-trace`: K as written, approval clause
  included, so the run implements and reports. Both pre-flighted through the dist `route-prompt.ps1` on both event
  shapes: `EXIT=0`, routed `feature`, "Security-sensitive surface detected" present (K names a refund).
- **Cells.** S1-T, S1-C, S2-T, S2-C; 6 valid runs each on Claude Code via `run-agent-evals.ps1 -Executor claude
  -Model sonnet -Trials 6` (T with `-TargetPatch`); Copilot CLI on restored access (B-399). Valid: frozen host and
  model, hooks loaded, the patch present in the installed carrier (T), normal shutdown, and for S2 a change under
  `src/`; else CANNOT-EXAMINE, repeated once. Stop: 25 USD, or 30 premium requests.
- **Grader (Phase 0).** `Get-TranscriptEvidence` (`run-agent-evals.ps1:1105-1126`) keeps only `tool_use` blocks;
  extend it to keep assistant `text` blocks with their ordinal (no second parser). Classes, main agent:
  - CONTRACT (S1): the assistant text before the first `Write`, `Edit`, `MultiEdit`, `NotebookEdit` or shell
    tool_use contains a heading or label matching `(?im)^\W*(done when|acceptance criteria)` followed by at least
    two list lines, at least one naming two of K's outcomes (`202`, `404`, `409`, "paid", "not paid",
    "does not exist") or the word "boundary"; and the run ends with no file write. PARTIAL: lines without a boundary,
    or after a write. NONE otherwise. STOPPED (reported): no write in the run.
  - TESTS-AT-BOUNDARY (S2): a test file in the diff asserts each of K's three outcomes (202, 404, 409); ALL, SOME
    (which), NONE. Scored only on runs with a test file.
  - TRACE (S2): the final result text matches `Beyond the request`, `Blast radius`, `Review depth`, and at least
    one line pairing a Done-when line with a test or command result. FULL, PARTIAL (which parts), NONE.
  - SIDE CHECK (S2-T, B-389): this framework's security pass (`security-gate` skill or `security-auditor`) in the
    run, as B-348's PROJECT class; S2-C's count recorded beside it.
  - Cost per run: tokens, USD or premium requests, wall time, subagent count; median T minus C per scenario.
- **Readings, fixed now.** R1 REACHED: S1-T CONTRACT in 5 or 6 of 6 with S1-C at most 2 (two-sided Fisher
  reported, counts decide), and S2-T TRACE FULL in 5 or 6 of 6. R2 ABANDON: S1-T CONTRACT 3 or fewer, or S2-T TRACE
  FULL 3 or fewer: ship nothing from 3.1 to 3.7; file the finding. 4 of 6 in either cell: six more runs of that
  cell, pooled (10 or more of 12 → R1). SIDE CHECK below 5 of 6 in S2-T: revert the patch; ship nothing.
  TESTS-AT-BOUNDARY is reported, and gating only if S2-T ALL is below S2-C ALL. Cost above 1.5x C tokens or 8
  minutes added is recorded in the certification row, not a reading. **Not shown:** the fix path (Phase 4), the
  resume across a real second turn (S1 shows the stop, not what follows a go-ahead), Copilot until access returns,
  VS Code, Angular and monorepo, the `review` skill's own behaviour.

## 5. Phases

0. **Records and harness** (ordinary). The pre-registration above into `meta/eval-results.md`; `B-406` filed in
   `meta/BACKLOG.md` (20 open entries at `ecf1479e`; heading, filed-against, priority, at most three lines); correct
   B-403's line (`meta/BACKLOG.md:165-166`): the runner has no "proceed autonomously" string (it passes
   `--dangerously-skip-permissions`, `run-agent-evals.ps1:1184`); the approval clause lives in prompts K and N. Two
   scenarios in `.claude/evals/scenarios.json`, the grader, the text-block extension, the fixture frozen, the
   pre-flight. Verify: `.claude/hooks/tests/Invoke-HookTests.ps1 -File DocTruth.Tests.ps1`,
   `-File RepositoryPrivacy.Tests.ps1`, `-File BacklogHygiene.Tests.ps1`; the runner's `-SelfTest`. Commit.
1. **The runs** (ordinary, ships nothing). Claude arm now; Copilot on restored access. Results, the
   `meta/host-certification.md` row (Claude Code only; everything in Not shown named as such) and the raw readings in
   one commit. Report the readings to the maintainer and wait.
2. **The contract patch on R1** (**guarded**: `src/core/.claude/hooks/**`). 3.1 to 3.8. Required: a commit body of
   at most five lines (harm: the developer approves a file list and the tests agree with the code on a misread rule;
   the smaller fix rejected: a sentence pointing at `/design`, which consumers never type, and a review record only
   inside `/review`; what could be let through: a model that posts the shape and still guesses the boundary); a
   red-first case in `src/core/tests/hooks/RoutePrompt.Tests.ps1` next to `:66-72` asserting `DONE WHEN` on both
   surfaces and `Done-when` in the fix rail, with the `Red-first:` trailer and the `RED_FIRST PASS` line; the file
   green under `pwsh` and `powershell.exe` as separate runs plus one CP437 leg; the **dist** `route-prompt.ps1` piped
   both event shapes and asserted `EXIT=0` plus `DONE WHEN`; the three dist runners. Then the `src/**` recipe: review
   the `src/stacks/monorepo/` sibling of every snippet touched (verif-rules, verif-conf-line, test-critic, REVIEW-GUIDE,
   playbook), `scripts/build.ps1` ×3 with `dist/` in the same commit, `scripts/validate-dist.ps1` ×3 (re-record
   rail-sync, watch `no-meta-leak`), `scripts/context-footprint.ps1 -Check` → review → `-Update`. Step 4 of AGENTS.md
   does not list `route-prompt.ps1`, so no attack is required; the implementation prompt's cycle runs one anyway.
   On R2 or a failed side check: nothing from this phase ships.
3. **Review depth floor** (ordinary; `src/core/scripts/review-scope.ps1` is an ordinary script). The manifest gains
   the hazard rows whose literal paths intersect the captured paths, reusing `hazard-check.ps1`'s candidate parsing
   by loading it from the script by AST (precedent: B-397's `Get-PatchSections`), never a second parser;
   `review.md` Step 1 hands the rows to the auditors and Step 3's Review depth reads them; `ci-integration.md` names
   the range run. Red-first case in review-scope's test file on both hosts plus CP437; the dist copy on a fixture; the
   `src/**` recipe.
4. **Fix path** (ordinary, ships nothing). Plant one defect in a copy of the frozen fixture, pre-register S3 with its
   own reading (the fix rail's Done-when line in the first message; the regression test at the boundary), run T vs C,
   extend the grader. Its result decides whether `$railsFix`'s wording needs a second pass.
5. **The review sentence** (v1's §3 at `ecf1479e`; deferred). Re-pre-register only after Phase 2 has shipped in a
   release of its own and one consumer's field result is recorded: the block's "Review depth: full" line may make an
   always-loaded sentence unnecessary, and the reading decides. On a BUILTIN capture, rename `review` (WSD-114).

Out of this plan: retiring the rails (WSD-100 stands; its reopen clause is its own); `$railsDesign` and `design.md`'s
interview (B-403 in flight); the ask-first bullet's wording (`:77`).
