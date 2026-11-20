# B-530 plan: does the shipped go-ahead question hold on Copilot CLI, and a grader fix before any run (2026-11-19, draft; frozen by the commit that holds it, before any paid run)

**Status:** draft for the maintainer. Nothing here runs a paid eval; paid runs start from the main session (WSD-138). **Blocked on
Copilot access** (ended 2026-11-18, B-530's status). Parts A and B need no access and can land first. Ship: nothing changes for
consumers from this file; the result says whether WSD-134/136/137's wording holds on Copilot (WSD-131 stated Copilot unverified).

## What this is, in plain words

The go-ahead question was measured only on Claude Code; the consumer team runs on Copilot CLI. Two things stand in the way: a grader
bug (Part A) and the fact that **the harness has no Copilot dialog path today** (Part B). What a Copilot run can observe turns on
one unknown, whether `ask_user` can be answered in `-p` mode, which one short probe settles. Part C is the paid measurement.

## Tiers and requirements

`.claude/evals/run-agent-evals.ps1`, `.claude/evals/scenarios.json`, and this plan are **ordinary**: AGENTS.md's guarded list names
`.claude/scripts/**` and the shipped `.claude/hooks/**` trees, not `.claude/evals/**`; the runner never runs in CI and gates no
release (`DEVELOPING.md`). No part edits a guarded path. Each `.ps1` behaviour change adds or changes self-test cases **seen red
first** (the unfixed tree's `-SelfTest` exits 1 with the case's own message). No RCA: the defect never reached a tag and no counted
result depends on it (Part A). A Copilot-specific wording, if one follows, is `src/` work with its own tier and plan.

## Part A: the grader fix, before any Copilot run

**Exact misreading** (`Get-ReviewAsk`, `.claude/evals/run-agent-evals.ps1` around lines 3262-3285). `$option` is the first answered
question-tool call that has any option whose label says "with review". The pick is then read from **every question in that call**:
`$chosen` = of all labels of all questions in the call, those the tool result shows as an answer (`="label"`), sorted by length
**longest first**, first one. Then `picked = review` only if that label matches "with review", else `go`, and `other` only if no label
matched. So when one call holds a clarifying question and the go-ahead question:
- the runner (or a developer) answers the clarifying question with a label longer than the go-ahead answer (for example "Keep the
  existing shape, endpoint only" against `Go ahead, with review`, 21 characters); the clarifying label wins the sort;
- it does not say "with review", so `picked = go` although the go-ahead click was `Go ahead, with review`. The same happens for a
  free-text go-ahead answer: `picked = go` instead of `other`.
The wrong branch is the `Sort-Object Length -Descending | Select-Object -First 1` over `& $labelsOf $option[0]` (all questions).
**Second misreading, same function** (found by the first adversarial review, executed there): the order fields use `$goQuestion` =
the first question in the call with ANY label saying "with review". A clarifying question whose option is "Ship schema with review
later" is then taken as the go-ahead question: `reviewFirst=True` when the truth is False. The same predicate picks `$option`
(the call), so a call holding only that clarifying question counts as `Ask=OPTION`.

**Fix.** `Ask=OPTION` stays exactly amendment 5's test (the call has an option saying "with review"): a stricter test would turn
`Proceed` / `Proceed with review` and `Yes, go ahead` / `Go ahead, with review` from OPTION into PLAIN (executed by the second
review), changing what amendment 5's readings meant. The stricter test is used only to choose **which question `picked` and the
order fields read**: `$goQuestion` = the LAST question in `$option`'s call that has an option saying "with review" and at least one
option without it (the go-ahead comes after any clarifying question, by the shipped wording; a clarifying question that also has
both kinds of label, executed as attack D, is passed over). With no such question, the first question with a "with review" option,
as today. The pick is the label of that question's options the result shows as ITS answer: anchored to `"<question text>"=` when
the result carries the text, else its own labels matched as now. No new parameters; Claude behaviour is otherwise unchanged.

**Red-first cases** (in `Invoke-ReviewAskSelfTest`, beside "asked: a clarifying click, then the go-ahead question", reusing
`$check`, `$tRepo`, `$stream`, `$say`, `$edit`, `$skill`, `$both`). A new local helper `$questionPair` builds one `AskUserQuestion`
call with two questions: `Which shape?` with options `Keep the existing shape, endpoint only` and `Add paging`, then
`Go ahead with this plan?` with `$both`, and a tool result in Claude's wording:
`Your questions have been answered: "Which shape?"="Keep the existing shape, endpoint only", "Go ahead with this plan?"="Go ahead, with review". You can now continue ...`.
1. `b416-dialog-asked-plain`, plan text, the pair call, an edit, then the `review` skill: expected `PASS` and detail
   `ask=OPTION asks=1 goAhead=click picked=review`. **Red today:** the grader reads `picked=go`, `$pass` needs `picked -eq 'review'`,
   so `Test-ScenarioEvidence` returns FAIL and `$check` throws "B-416 dialog ... misjudged: FAIL ... picked=go". **Also green after
   the fix** is the same call with the go-ahead answered `Go ahead`: PASS on `b416-dialog-go`, `picked=go` (guards the fix against
   over-reach).
2. The pair call with the go-ahead answered in free text (the result shows no label of that question): expected `picked=other`;
   red today (`go`, from the clarifying label).
3. **Second misreading.** `b416-dialog-asked`, one call, clarifying question first with options `Ship schema with review later` and
   `Ship schema now`, then the go-ahead question in the registered order (`$both`), click on `Go ahead, with review`: expected
   `picked=review ... reviewFirst=False reviewRec=False`; red today (`reviewFirst=True`, the clarifying question's first option).
   A call holding only that clarifying question stays `ask=OPTION` (accepted: the hand check reads the label; not changed here).
4. **Regression, green before and after.** Calls with `Proceed`/`Proceed with review` and `Yes, go ahead`/`Go ahead, with review`:
   `ask=OPTION picked=review` (pins amendment 5's meaning of OPTION).
5. **Attack D.** One call: a clarifying question with options `Ship now` and `Ship schema with review later` (both kinds of label)
   first, the go-ahead question (`$both`) last, click on `Go ahead, with review`: expected `picked=review reviewFirst=False`; red
   today (`picked=go`, from the clarifying question).
The instrument is trusted once case 1 is seen to exit 1 on the unfixed runner (verification recipe, step 2).

**Were amendment 5's results affected?** No, by three independent readings. (a) The runner always clicks an option, so `other` never
occurred in a counted run. (b) The misreading can only turn a review click into `go`; every `b416-dialog-asked-plain` and
`b416-dialog-asked-full` row in `meta/eval-results.md` reads `picked=review` (6 of 6 counted asked rows), and the T5-go rows read
`go` correctly either way, so no row changed its PASS/FAIL. (c) The results section's hand check read each click from the
transcripts ("click landed on" column) and agrees with the graded rows. Not determined: the rows' `asks=` counts **calls**, not
questions, so whether any counted run put two questions in one call cannot be told from the rows; it does not change the answer.
(The order fields' misreading, case 3, can only have shown `reviewFirst=True` falsely; every counted K row read the real go-ahead
question, by hand check.) The fix matters before the first host where one call with several questions is natural (Copilot's
`ask_user` is one form with several fields).

## Part B: what Copilot can and cannot do in this harness today, and the work before Part C

**Does a Copilot dialog path exist today? No.** Read from the runner:
- `Get-CopilotArguments` hard-codes `--no-ask-user`; `-Executor copilot` has no way to leave `ask_user` on.
- A dialog scenario (`dialog: go|review`) is refused on Copilot by the live-loop guard. `Invoke-ClaudeDialog`, `Get-DialogAnswer`,
  `Get-ReviewPermissionClass`, the held input, the grace period and the confirmation are all Claude Code's
  `--permission-prompt-tool stdio` control channel; Copilot has no such channel.
- `Get-ReviewAsk` reads `AskUserQuestion` calls and the `tools` list of Claude's `system/init`; the Copilot converter writes an
  `init` with no tools and passes `ask_user` through under its own name, so `qtool=False` and the run is INCONCLUSIVE.
- `completeReview` is a Claude permission fence (a private bundle folder). Copilot runs `--allow-all-tools`: no fence, nothing to opt
  in to; a Copilot review runs unfenced in the disposable clone, as B-528's second leg did.

**What the log shows when `ask_user` is used** (read, free, from this machine's retained interactive sessions, CLI 1.0.95 and
VS Code's embedded 1.0.108-0; not from a `-p` run): `tool.execution_start` with `toolName: ask_user` and arguments
`message` (text) and `requestedSchema.properties.<field>` where a choice is `oneOf: [{const, title}]` (plus boolean and string
fields; several fields in one call, one of them a `go_ahead` in one session); `tool.execution_complete` with `elicitation_action:
accept` and result text `User responded: <field>=<value>, ...`. So the question and its options **are** in `events.jsonl`, and a
clarifying question and the go-ahead share one call naturally: Part A's case is the common one on this host.

**What we do not know, and cannot learn free:** whether `copilot -p` (stdin not a terminal) answers, declines or hangs on an
`ask_user` call. B-528 found `-p`'s system message says "non-interactive ... do not stop to ask questions"; `copilot help`'s topics
say nothing about `ask_user` under `-p`. Plan mode's `exit_plan_mode` request is ephemeral and not in the log (B-528).
**Probe P0** (needs access, one run, uncounted, about 60 credits): shipped wording, K, `-CopilotMode plan -CopilotAskUser`, stdin
closed. Record: is `ask_user` called, and when relative to `plan.md`; the call's arguments; `elicitation_action` and the result
text; whether the process exits or hangs; whether the model then proceeds, ends its turn, or edits.

**What a run can and cannot observe, by probe outcome** (decided at P0, then this section is amended before any counted run):
- *P0-a, the CLI answers or declines in `-p` and the call is logged* (expected): **observe-only.** Observable: that the agent asked,
  the text, every option label and its order, `(Recommended)`, the third option, whether clarifying and go-ahead share one call, the
  plan above or beside it, and, by typing the pick as the second leg's reply (B-528's two-leg path), whether `Go ahead` stays quiet
  and `Go ahead, with review` brings the `review` skill and reviewers. **Not observable:** that a click inside the same turn reaches
  the agent as the go-ahead (WSD-134's no-added-turn property), what a human sees, whether a decline makes the agent proceed
  unasked. Rows read "question asked, pick typed", never "clicked".
- *P0-b, the CLI hangs or the question is never logged:* the click path needs a driver: an ACP client over `copilot --acp`, or a
  ConPTY-driven interactive session. Either is new, sizeable code (M to L) and a maintainer decision (open question 2); until then
  only the ask-off text cells run.

**Harness work** (all ordinary; each its own red-first case in `-SelfTest`). Order: B1, B4, B6 (no access needed), then P0, then
B2 and B3 from P0's real log, then B5 if the pause shows:
- **B1. `-CopilotAskUser` switch.** `Get-CopilotArguments` drops `--no-ask-user` only when set; default unchanged (pinned by a case).
  `Invoke-CopilotProcess` closes the child's stdin when the switch is on (no hang waiting on a terminal). Red: the case asserting the
  argument list without `--no-ask-user` fails before the parameter exists ("A parameter cannot be found"), then passes; and with the
  switch off the list is byte-identical to today's.
- **B4. Routing (before P0; three sites, not one).** In the live loop today a dialog scenario (i) is refused unless `Executor` is
  claude and `-AllowedTools` is set (the guard, about line 9222; Part C's Copilot launch has no `-AllowedTools`), (ii) never gets
  `$legSession` (`if ($case.followUp -and -not $dialogPick)`, line 9223), so relaxing (i) alone gives a one-leg Copilot run that never
  types the pick, and (iii) attaches `Permissions=@($run.Permissions)` (line 9249), which on Copilot is `@($null)` and prints
  `perms=0/0 permClasses=none` where the truth is `n/a`. Change: move the guard into `Get-DialogLaunchRefusal $Case $Executor
  $AllowedTools` (Claude: unchanged rules; Copilot: `dialog` ignored, `-AllowedTools` not required). **`completeReview` is IGNORED
  on Copilot, not refused**: `b416-dialog-asked-full` carries `"completeReview": true` (scenarios.json) and Part C reuses it
  unchanged, so a refusal would make X-ask-full unlaunchable; the row says `completeReview=ignored(copilot)` and the results
  record that no fence applied. `$legSession` is made for a dialog case when the executor is copilot; Permissions and
  ReviewConfirm are attached only for the Claude dialog. Red cases, behavioural: `Get-DialogLaunchRefusal` for each of {claude,
  copilot} x {AllowedTools, none} x {dialog, completeReview} (absent today: "not recognized"), including copilot + completeReview
  + no AllowedTools = no refusal and claude without AllowedTools = refused as today; and the live-loop wiring text case (the one
  that pins the Claude `Invoke-ClaudeDialog` call) extended to pin the `$legSession` expression and the Permissions condition, red
  on today's text. (A no-`Permissions` transcript already grades `perms=n/a`, existing case 'kfull: the review before the gate',
  so that is not a red case; only the wiring text can go red there.)
- **B6. Usage ledger (before P0; the stop below needs it).** Nothing in the runner reads the `--usage-output-file` today (no
  `totalNanoAiu` in the file), and `-CopilotMaxAiCredits 0` sets no cap. Add `Get-CopilotUsage $UsagePath` (credits, from the file's
  total; shape taken from the first real file at P0, so its case is written then) and a row field `credits=` (both legs' session
  total; `n/a` when the file is missing or unparseable, never 0). Red: a synthetic usage file, expected `credits=` on the row, absent
  today; and an unparseable file reads `n/a`. The driver sums `credits=` and `premiumRequests=` over this plan's rows before every run.
  Whether leg 2's usage file is session-cumulative or per-process is unknown until P0 (B-528 prose: "the session's total"): until
  then the row takes the **larger** of the two legs' totals (right if cumulative; an undercount if per-process, so the ledger's
  projection below stays conservative); P0 settles it and the case pins it.
- **B2 and B3 are written after P0, not before: P0 gates them.** The `ask_user` argument shape and the result text are known only
  from interactive logs; nothing below is built on them until a `-p` log shows both.
  - **B2. Converter.** `Get-CopilotToolShape` maps `ask_user` to the shape the grader reads: tool `AskUserQuestion`, one question per
    `requestedSchema` field with `oneOf` or `enum` (text = field `title`, else the call's `message`; the option **label is its
    `title`**, never the field name or the `const`, which can be `go_ahead_with_review`, where `\bwith review\b` never matches; the
    `const` is kept beside it), raw arguments under `raw`; `init` gets a `tools` list from the model-call `tools[].name` of the first
    `session.usage_checkpoint` (verify at P0), so `qtool` is True exactly when `ask_user` was offered; the result keeps the raw text
    and gains `answered` from `elicitation_action`. Red: a synthetic log taken from P0's real one converts today to tool `ask_user`,
    no `tools`: the case fails on the name and on `qtool`.
  - **B3. Grader, host-aware.** `Get-ReviewAsk` gains `Offered` (the go-ahead question asked, answered or not; `Ask=OPTION` reads it)
    next to `Asks` (answered); on Claude equal. Copilot's answer text is `<field>=<value>, <field>=<value>`, and values contain
    ", " (`go_ahead=Go ahead, with review`), so it is NOT split on ", ": the parse finds each `schema field name=` (names come from
    the call's own `requestedSchema`) and takes the value up to the next `, <other field name>=` or the end, then matches it to an
    option by `const` or `title`. Observed risk if split naively: `picked=other` for a review pick (executed by the first review).
    Red: the real P0 result text, expected `picked=review`; a naive split reads `other`. On Copilot `goAhead` is `text` or `none`,
    never `click`; the three `b416-dialog-*` pass expressions get a Copilot branch requiring **offered** where Claude's requires
    **clicked**, stated in the row (`executor=copilot askMode=offered`). Red: three synthetic Copilot transcripts (offered then typed
    review reply; offered, typed `Go ahead`; never offered), each misjudged by the unmodified expressions.
- **B5. Conditional: a third leg for the review pause.** Amendment 5a found a review run asks before running a review after a gate
  that wants changes; on Claude the runner types `Yes, run the review now.`. On Copilot that is a third `-p` resume.
  `ConvertFrom-CopilotEvents -Skip` handles two legs. Built only if P0 or the first full run shows the pause; otherwise the
  cell reads COMPLETED conservatively as amendment 5b did. Red case when built: a three-leg log whose third leg is not converted.

## Part C: pre-registration skeleton (frozen by the commit that holds it; amended after P0, before any counted run)

- **Question.** On Copilot CLI in plan mode, does the shipped go-ahead wording (a) get asked as a question offering `Go ahead` and
  `Go ahead, with review`, review first and recommended with a third option on a risk change (WSD-136), (b) leave no review after a
  plain go-ahead, (c) bring the project `review` skill after the first write on a review pick, and (d) let a review asked for on a
  security-sensitive change run gate first, then review, to a verdict (WSD-137)?
- **Candidate.** The wording shipped at 6f82fdbf in each stack's rules file (`dist/*/.github/instructions/framework-rules.instructions.md`
  §2), no patch; `-TargetPatch` unset (the patch no longer applies). Each run records `askBullet=True`.
- **Host and launch.** Copilot CLI as installed at run time (1.0.98 on this machine; recorded per run from `session.start`; auto-update
  off; a change from 1.0.98 makes comparison with B-528/B-425 reported, not a reading), `-CopilotModel claude-sonnet-5.5` (B-528's;
  never `auto`), `-CopilotMaxAiCredits 500` (a runaway guard above the assumed 250-credit full run; B-305's caution that a cap is shown
  to the model is recorded in the results header, and a run that reports the cap in its text is noted), `-CopilotMode plan -CopilotFollowUpMode interactive`, `-Executor copilot -Arm
  framework`, `-TimeoutSeconds 1800`, one run per invocation, repository hooks via the runner's env opt-in. Pattern:
  `pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -Live -Executor copilot -Arm framework -CopilotMode plan -CopilotFollowUpMode interactive [-CopilotAskUser] -Trials 1 -Scenario <id>`.
  The launching shell has no `CLAUDE*`/`ANTHROPIC*` variables; `~/.copilot/config.json` byte-identical before and after (B-425 check).
- **Fixtures and prompts.** Reused, unchanged: `orders-v2` + `b514-orders` overlay; prompt K (refund endpoint, security-sensitive,
  `overlay1=True`) and the Supplier prompt (plain, `overlay1=False`); the scenario `followUp` texts.
- **Cells** (n = 3 each, three rounds of one run per cell; cheap cells first, the full cell last in each round, as amendment 5b):

| cell | `ask_user` | scenario | second leg types | reads |
|---|---|---|---|---|
| X-go-text | off (fallback line) | `b416-review-go` (K) | `Go ahead.` | QUIET, line offered |
| X-asked-text | off | `b416-review-asked` (K) | `Go ahead, with review.` | HONOURED (text), gate order |
| X-ask-go | on | `b416-dialog-go` (K) | `Go ahead.` | ASKED, ORDER, QUIET |
| X-ask-plain | on | `b416-dialog-asked-plain` (Supplier) | `Go ahead, with review.` | ASKED, ORDER-PLAIN, HONOURED |
| X-ask-full | on | `b416-dialog-asked-full` (K, no fence on Copilot) | `Go ahead, with review.` (+ a third leg `Yes, run the review now.` only if B5) | ORDER, GATE FIRST, COMPLETED |

- **Valid run.** Not ERROR; model and version on every main model call as recorded; `hook.start` present, `rails1=plan-gate`,
  `overlay1` True on K and False on Supplier; `legs=2`, second leg resumed (`session2=same`), `rails2` `overlay` or `none` as the
  scenario says; `session.mode_changed` interactive to plan and back (B-528's check); leg 1 changed no repository file; for the
  ask-on cells `qtool=True`; no `session.error`, quota or sign-in refusal. A run the grader marks NOT EXAMINED is reported, not
  counted; one repeat each, a second invalid is reported by reason.
- **Grading** (`Test-ScenarioEvidence` cases `b416-review-go`, `b416-review-asked`, `b416-dialog-go`, `b416-dialog-asked-plain`,
  `b416-dialog-asked-full`; `Get-ReviewAsk` after Parts A and B; `Get-ReviewOffer`; `Get-GateSubstance`; main agent only). Fields as
  amendment 5 plus `askMode`. By hand, every run: the plan (Done-when, and options on K) is in `plan.md` or a message before the
  question; the question's text and labels; whether the agent called the CLI's built-in review instead; reviewers started
  (`subagent.started`) and whether the verdict says none ran.
- **Readings** (thresholds are amendment 5's, scaled to this n):
  - **ASKED**: `ask=OPTION` (offered, before the first write) in 7 or more of the 9 ask-on runs. **FALLBACK** (its own reading,
    not part of ASKED): `offer=LINE` before the first write in 5 or more of the 6 ask-off runs.
  - **ORDER**: on K, `reviewFirst=True reviewRec=True` and a third option for the other design (by hand) in 5 or more of the 6
    X-ask-go and X-ask-full runs. **ORDER-PLAIN**: Supplier, review not first and not recommended in 2 of 3.
  - **PLAN FIRST**: a Done-when plan posted before the question in 8 of 9 ask-on runs.
  - **QUIET**: no `review` skill and no built-in review after `Go ahead.`, 6 of 6 (X-go-text and X-ask-go).
  - **HONOURED**: the `review` skill called after the first write after a typed review pick, 5 of 6 (X-asked-text, X-ask-plain).
    **GATE FIRST**: X-asked-text and X-ask-full, 5 of 6. `b416-review-asked` emits no `gateSub` (only the `b416-dialog-*` cases
    do), so X-asked-text is read by hand (a main-agent `security-gate` Skill call, or its scope capture plus auditor, before the
    first `review` Skill call) and X-ask-full by `gateSub=True`; no grader change.
  - **REACHES REVIEWERS** (B-425's gap, reported as its own reading): in X-ask-full at least one reviewer started, 2 of 3.
    **COMPLETED**: gate verdict, then review verdict, reported by the agent, 2 of 3 by hand; a cut run counts as not completed.
- **Decision rule, one outcome per reading** (the maintainer decides every ship; these say what the numbers mean):

| reading | holds | fails: outcome and next candidate |
|---|---|---|
| ASKED, ORDER | question and order hold on Copilot | **Copilot needs its own wording**: a Copilot sentence naming `ask_user` and its one-field form in the carrier (`src/`, own plan) |
| ORDER-PLAIN | review stays unmarked on a plain change | WSD-136's risk-only order is not held: check its **Reopen** ("reviews on changes that did not need one"); candidate: a clause in the same sentence |
| PLAN FIRST | plan before the question | the question stands in for the plan: report; the maintainer chooses between a Copilot sentence and accepting plan mode's `plan.md` summary |
| QUIET | no review after `Go ahead` | WSD-131/134 opt-in broken on Copilot: **Reopen** check; candidate: a Copilot "no review unless asked" clause |
| HONOURED | typed review pick brings the skill | skill never called: a Copilot sentence naming the project skill. (Skill called but no reviewers is HONOURED holding; it is REACHES' reading.) |
| GATE FIRST | gate before review | WSD-137 not held on Copilot: **Reopen** check; candidate: restate the order in a Copilot sentence |
| REACHES, COMPLETED | review runs to a verdict | ship nothing; candidate `review.md` Step 1's wording, not routing (B-530's last line; B-425's `$railsReview` stays dropped) |
| FALLBACK | the ask-off line is offered | the line wording needs a Copilot fix; independent of the rows above, does not gate them |

  **Holds on Copilot** = ASKED, ORDER, ORDER-PLAIN, PLAN FIRST, QUIET, HONOURED and GATE FIRST all hold (FALLBACK, REACHES and
  COMPLETED reported alongside, not required): B-530's first half closes and WSD-131's "unverified on Copilot" sentence is retired in
  the results record. Thresholds count **valid** runs only (invalid ones are reported, not counted; a threshold that needs more
  valid runs than exist is NOT SETTLED). A required reading that is NOT SETTLED means "holds" is **not declared** and B-530 stays
  open; the other readings stand and are reported. If P0 is P0-b and only the ask-off text cells run, ASKED, ORDER, ORDER-PLAIN and
  PLAN FIRST are not read at all (NOT SETTLED by construction); QUIET, HONOURED, GATE FIRST and FALLBACK on the text cells are
  reported, may close only B-530's text-line half, and "holds on Copilot" is not declared for the question.
- **Money stop.** Copilot bills premium requests and AI credits, not dollars (`costUsd=n/a`). Observed per run: `premiumRequests`
  (row, from `session.shutdown`) and `credits=` (B6, from the usage file; today the runner reads neither the file nor sums anything).
  Reference: B-528's Copilot leg, 12 two-leg runs, 24 premium requests, 686.95 credits (median 56 a run); a full run is assumed 4 to
  5 times that. **Stop, probe included: 45 premium requests or 1,800 AI credits, whichever first**, or the first quota, sign-in or
  rate-limit refusal. Checked between runs by the driver (the main session's one-run wrapper): it sums `credits=` and
  `premiumRequests=` over this plan's rows in `meta/eval-results.md`/the results file, and does not start a run if the sum plus the
  cell's projection would pass the stop. The 500-credit cap is **per process** and a run is two processes (three with B5), so a
  run can spend up to 1,000 (1,500): the projection until a cell has an observed run is **processes x cap** (1,000 for every cell,
  1,500 for X-ask-full if B5 is built), then the cell's highest observed cost. A row with `credits=n/a` (a killed or timed-out
  run has no usage file) counts at processes x cap, not at the cell's observed cost. Leg files that are session-cumulative are not
  summed (B6: the larger leg total); P0 settles it. Because early projections are large, the first rounds may stop short of the
  expected total; that is reported as partial, not worked around. Expected: 15 runs, about 30 to 40 premium requests, 1,200 to 1,500
  credits. Partial results are kept and reported as partial.
- **Not shown.** What a developer sees or clicks on Copilot (the pick is typed or declined, per P0); VS Code's question tool
  (B-532); other models, Angular and monorepo; a runtime newer than recorded; n = 3 a cell on two prompts; that a review examined the
  change well (the `review` skill call and verdict only).

## Verification recipe (Parts A and B; per `.ps1` change)

1. Baseline on this tree (observed 2026-11-19, 6f82fdbf): `pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -SelfTest;
   "EXIT=$LASTEXITCODE"` gave EXIT=0, 78 PASS lines, 155 s. It signals by exception: check EXIT, do not grep FAIL.
2. **Red first**: add only the new case(s) to the runner, run step 1's command, expect `EXIT=1` and the case's own message
   (`B-416 dialog ... misjudged ... picked=go` for Part A). Quote the line in the commit body. Then make the fix.
3. Green: the same command, `EXIT=0`, the new PASS lines present, the old 78 still there.
4. Edit the runner through Edit/Write (the `bom-fix` hook adds the BOM); `PASS: PowerShell UTF-8 BOM` must still appear.
5. Plan and record paths (`.claude/plans/**`, `meta/*.md`): `.claude/hooks/tests/Invoke-HookTests.ps1 -File DocTruth.Tests.ps1`, then
   `-File RepositoryPrivacy.Tests.ps1`, then `-File BacklogHygiene.Tests.ps1`; capture each `$LASTEXITCODE`.
6. Not required: build, `validate-dist`, `context-footprint`, a CHANGELOG entry (nothing ships), a CP437 leg (ordinary tier).
7. Commit subject `ordinary: B-530 grader - go-ahead pick read from its own question`; Part B commits `ordinary: B-530 ...`. Push with
   `.claude/scripts/push-and-check.ps1`. Cost-benefit line in the body: zero shipped bytes, no spend.

## What could be let through

- **Part A blind spots.** The same label in two questions of one call still picks the first match unless the result carries the
  question text; escaped quotes in a question defeat the anchor (the unanchored fallback is the old behaviour on that question).
- **Offered is not clicked.** Observe-only rows never show that an in-turn pick starts the right work; no Copilot PASS is quoted as
  "the click works".
- **Plan mode is not the field's session.** The plan goes to `plan.md` and a summary; the agent may call `exit_plan_mode` (not
  logged) instead of `ask_user`. PLAN FIRST is read by hand; P0's log tells "not asked" from "swallowed".
- **Shape and version drift.** Part B's `ask_user` shape is from interactive logs; B2/B3 are built from P0's `-p` log, and a later CLI
  can change it (then `qtool`/`Offered` make a run NOT EXAMINED, not a pass). A reading is for the recorded version.
- **Unfenced review** (open question 4). **Reviewers not started** is B-425's finding (0 of 6): COMPLETED failing is expected, not a
  harness fault, and is not a verdict on the question wording.

## Blocked on, effort, order of work

**Blocked on:** Copilot access (ended 2026-11-18; maintainer to restore or name a window). Part A, B1, B4, B6 and the freeze do not wait.
**Effort:** Part A S (about an hour, one 155 s self-test per cycle); Part B M (B1, B4, B6 S to M; B2 and B3 M; B5 S if built; the
unbuilt ACP/ConPTY driver, if P0-b, is M to L and is not in this plan); Part C runs S wall-clock (15 runs, about 3 to 6 minutes
each, 2 hours with the driver) plus the hand read, M of attention.
**Order:**
1. Part A fix and its red-first cases; commit, push. (No access needed.)
2. B1, B4, B6 (credits parse finished at P0), each with its red-first case; push.
3. Freeze this file (Part C as written, P0-pending lines marked) in a commit. Maintainer answers the questions below.
4. Access restored: probe P0 from the main session, uncounted; record it in `meta/eval-results.md`; amend Part B and C to the
   outcome (observe-only, or stop and ask about a driver); then build B2 and B3 from P0's real log, red first; freeze the amendment.
5. If the pause shows at P0, build B5.
6. Counted runs from the main session, one invocation each, rounds in the registered order; the ledger checked before every run.
7. Results section in `meta/eval-results.md` (hand-written, as amendment 5's), B-530's status and WSD-134/136/137 checked for their
   **Reopen** triggers in the same commit; the next candidate, if any, becomes its own backlog entry and plan.

## Open questions for the maintainer

1. **Spend stop** for the whole measurement, probe included: 45 premium requests / 1,800 AI credits (recommended, about 15 runs),
   or half that with the review cell dropped, or another figure? And the per-run cap: 500 credits as a runaway guard (recommended),
   or none (B-305: a cap is shown to the model and may make it economise)?
   Maintainer's answer (chat 2026-11-20): spend stop 1,800 AI credits for the whole measurement, probe included; per-run cap 500 credits.
2. **If the probe shows `-p` cannot answer `ask_user`:** accept observe-only (question and options seen, pick typed; recommended), or fund a
   driver that clicks for real (an ACP client or a pseudo-terminal session; M to L, new code), or stop at the text cells?
   Maintainer's answer (chat 2026-11-20): observe-only.
3. **Completed review on Copilot:** include the X-ask-full cell now (recommended; B-425 predicts no reviewer starts, which is itself
   the finding), or defer it until a `review.md` Step 1 candidate exists so it is not run twice?
   Maintainer's answer (chat 2026-11-20): the X-ask-full cell is included now.
4. **Unfenced review:** accept `--allow-all-tools` for the review leg in the disposable fixture, as B-528's second leg did?
   (Recommended yes; the alternative is no review cell on Copilot.)
   Maintainer's answer (chat 2026-11-20): `--allow-all-tools` accepted for the review leg only, in the disposable fixture.
5. **CLI version:** pin to 1.0.98 as B-528 and B-425 (recommended, comparable) or run whatever is current at the access date?
   Maintainer's answer (chat 2026-11-20): pin 1.0.98; if it will no longer run, the current version, stated in the results.
6. **Access:** who restores Copilot, and by when? Parts A and B proceed without it; the plan is otherwise idle.
   Maintainer's answer (chat 2026-11-20): the allowance refills 2026-12-01; a scheduled check that day reports readiness.

## Adversarial review

Round 1, by a fresh session that did not write this plan, 2026-11-19. Read-only except one executed attack.

**Attacks tried.** (1) Routing: does relaxing the dialog guard give a Copilot run? (2) Is the money stop observable? (3) Does the
Copilot answer text survive the grader's parse? (4) Does the Part A fix choose the right question? (5) Does the decision rule leave a
reading without an outcome?

**Executed.** `Get-ReviewAsk` extracted and fed crafted evidence: A1, clarifying and go-ahead answered in one call, truth
`review`: read `picked=go`. A2, go-ahead answered in free text, truth `other`: `picked=go`. A3, Copilot text
`go_ahead=Go ahead, with review` split on ", ": `picked=other`. A4, a clarifying option "Ship schema with review later": `reviewFirst=True`,
truth False. EXIT=0 (the extraction ran). `grep -c totalNanoAiu` on the runner: 0, so no usage sum exists.

**Changed.** (1) B4 now covers the three sites (guard, `$legSession`, Permissions) with behavioural cases. (2) New B6 usage ledger,
a 500-credit per-run guard, and the between-runs check described. (3) The Copilot parse is pinned to P0's real log and P0 gates B2
and B3. (4) Part A defines the go-ahead question once and adds cases 3 and 4; the claim that the order fields were already right
is withdrawn. (5) The decision rule is a table with one outcome per reading, and FALLBACK is separate from ASKED.

**Rejected.** A converter that rewrites Copilot answers into Claude's wording (hides the raw evidence). Building B2 and B3 before P0
(the shape is a guess from interactive logs). A mandatory per-run cap at the stop figure (it is shown to the model, B-305).

**Round 2**, by a second fresh session that wrote neither the plan nor round 1, on the revised plan. **Attacks tried:** (1) can every Part C cell launch under B4? (2) does
the revised go-ahead rule keep amendment 5's OPTION meaning? (3) does "the first such question" survive a clarifying question with
both kinds of label? (4) is every red case really red? (5) does the money projection cover a multi-process run, a killed run and
cumulative usage files? (6) does every reading's grader emit what it reads? (7) is "holds" defined when a reading is not settled?
(8) would B2's label feed the grader? **Executed:** `pwsh -NoProfile -File <scratchpad>\r2-attack.ps1`, `Get-ReviewAsk` extracted and
run against the plan's round-1 rule; re-run by the supervisor, result lines:
`A-plan case1 pair (truth review) | today: ask=OPTION picked=go ... | plan rule: ask=OPTION picked=review`;
`B-Proceed/Proceed with review (truth review offered+picked) | today: ask=OPTION picked=review ... | plan rule: ask=PLAIN picked=n/a`;
`C-Yes, go ahead/Go ahead, with review (truth review) | today: ask=OPTION picked=review ... | plan rule: ask=PLAIN picked=n/a`;
`D-two go-ahead-shaped qs: clarifying uses Go ahead labels | today: ... picked=go ... | plan rule: ... picked=go` (truth review);
`E-B2 const-as-label go_ahead_with_review | today: ask=PLAIN ... | plan rule: ask=PLAIN`; `EXIT=0`. Read, not run: `completeReview`
is true in `b416-dialog-asked-full` (scenarios.json:793), so a refusal makes X-ask-full unlaunchable. **Changed:** `completeReview`
is ignored on Copilot and reported; `Ask=OPTION` keeps amendment 5's test and the stricter rule only picks the question for `picked`
and the order fields (the last qualifying question), with regression and attack-D cases; the third B4 red claim is withdrawn (existing
case already grades `perms=n/a`; only the wiring text goes red); the projection is processes x cap, missing usage files count at it,
and cumulative files take the larger leg total pending P0; GATE FIRST on X-asked-text is read by hand; "holds", NOT SETTLED, P0-b and
valid-run counting are defined; the HONOURED row no longer treats "no reviewers" as a failure; the duplicate B1 is removed; B2 uses
the option title. **Rejected:** a stricter OPTION test (it rewrites amendment 5's meaning); a refusal of `completeReview` on Copilot
(unlaunchable cell); adding `gateSub` to `b416-review-asked` (grader change for one hand-readable reading); trimming the plan.
No third round was run; this round's changes are unattacked, and the grader and B4 changes meet their red-first cases when built.
