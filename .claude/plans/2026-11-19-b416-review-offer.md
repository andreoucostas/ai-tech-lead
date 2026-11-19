# B-416 pre-registration: does a closing plan line offer a review, and does the developer's reply decide whether it runs? (2026-11-19, frozen by the commit that holds it, before any paid run)

**Status:** frozen before any paid run. Decided by the maintainer in chat 2026-11-19: the review is offered in the plan and runs only
when the reply asks for it (a plain go-ahead means no review); measure on Claude Code alone, since Copilot access ended 2026-11-18; the
results go to the maintainer before anything ships; the Copilot leg is its own backlog entry (B-530). Stop at 12 USD. Basis: master at
dac7a912 plus this commit, on branch `worktree-b416-review-offer` in its own worktree (another session holds the main checkout;
maintainer, in chat), `dist/dotnet` stamp 0.98.6, root CHANGELOG head 0.99.0 Unreleased. The runs install from this worktree's `dist/dotnet`.

## Question

Field report #14 (`meta/field-reports.md`): no session loaded the `review` skill in 39 that changed files, while every one of the 29
plans got a developer reply before code. Plan v2 §5 item 5 deferred an always-loaded sentence that starts the review automatically
(`.claude/plans/2026-10-17-delivery-architecture.md`). The maintainer chose an opt-in instead. Three things must hold for it to ship:
the plan carries the offer, a reply that asks for the review gets it, and a reply that does not ask gets none.

## Candidate (T)

One bullet added to carrier §2, after "For larger features, persist the plan as a spec", verbatim:

> - Close the plan with the line `Review: none planned. Reply "with review" to get this repository's review gate on the finished change.` When the reply asks for it, invoke the `review` skill once the change is complete and verified, before presenting it (Copilot: the project skill, not the CLI's built-in code review), and report its verdict. A go-ahead that does not ask for it means no review.

396 bytes on a 15,633-byte carrier. `-TargetPatch meta/eval-fixtures/target-patches/b416-review-offer.patch` (sha256 `55664fd5d5c1…`,
1,949 bytes, one hunk, LF; cut from `git show dac7a912:dist/dotnet/.github/instructions/framework-rules.instructions.md` (blob `254d52a`) with
`core.autocrlf=false`), applied after the overlay. Nothing under `src/` or `dist/` changes for the measurement.

## Fixture and prompts

B-528's, unchanged: `New-EvalRepo orders-v2`, `install.ps1 -Stack dotnet` from this tree's `dist/dotnet`, the `b514-orders` overlay as
`/bootstrap` left it. Leg 1 is prompt K (B-406 S1's, byte-identical to `risk-design-k`'s). K is a risk change on a payments surface, so
the plan also owes the Done-when lines, Option A and Option B, and the run owes the security pass: the side checks below, each at
6 of 6 on this fixture two days ago ("B-528 results, Claude Code leg").

- `b416-review-go`, leg 2: B-410's fixed answer, then " Go ahead." (`b528-options`' reply, byte-identical).
- `b416-review-asked`, leg 2: B-410's fixed answer, then " Go ahead, with review.", the words the candidate line names.
- Pre-flight, run 2026-11-19 through `dist/dotnet/.claude/hooks/route-prompt.ps1` as a Claude event (`EXIT=0` each; the self-test
  re-runs it): both replies route no intent and carry the security overlay alone, so no review rail reaches leg 2 in either cell.

## Cells and runs

| cell | carrier | scenario | n |
|---|---|---|---|
| C-go | as shipped | `b416-review-go` | 6 |
| T-go | candidate | `b416-review-go` | 6 |
| T-asked | candidate | `b416-review-asked` | 6 |

18 valid runs, in rounds of C-go, T-go, T-asked. No C-asked cell: whether the shipped product runs a review on an unprompted "with
review" is not needed for the decision (Not shown). **Pilot:** round 1 counts as slot 1 of each cell if it is valid and nothing in this
file, the runner, the scenarios or the patch changes after it; otherwise it is reported apart. The series pauses after the pilot only
if a run is invalid, the grader and the hand read disagree, or the projected total passes 12 USD.

**Valid:** B-528's rules: not ERROR, a successful SessionStart and first UserPromptSubmit response, `rails1=plan-gate`,
`overlay1=True`, `legs=2` with `rails2` `overlay` or `none`, `session2=same`; and `bullet=True` in T, `False` in C. A run whose first
leg wrote is invalid here (the reply never reached the agent). An invalid run is repeated once at the end of the series; a second
invalid one is reported by its reason, not scored.

## Host and launch

Claude Code 2.1.312, `-Model sonnet` (`system/init`'s model recorded per row), acceptEdits with B-528's 39-rule `-AllowedTools` list
(tag `dc735db5da74`, recomputed with `Get-AllowedToolsTag` before the first run). Every run, one per invocation, from a shell with
every `CLAUDE*` and `ANTHROPIC*` variable removed and `DISABLE_AUTOUPDATER=1`: `pwsh -NoProfile -File
.claude/evals/run-agent-evals.ps1 -Live -Scenario <id> -Trials 1 -Model sonnet -TimeoutSeconds 1500 -AllowedTools <the list>`, T adding
the `-TargetPatch` above. Caps: leg 1 1.00 USD; leg 2 2.50 USD plus leg 1's cost.

## Grading (`Test-ScenarioEvidence` cases `b416-review-go` and `b416-review-asked`, `Get-ReviewOffer`; main agent only)

- **offer**, over main-agent text before the first main-agent write, both legs: `LINE` when a line opens with "Review" and names the
  reply "with review" (`$b416Offer`); `LOOSE` when "with review" appears on no such line; else `NONE`.
- **review**: main-agent `Skill` calls of `review`; `reviewWhen` places the first against the first write. `builtin`: a host
  `code-review` skill or agent. `reviewers`: main-agent calls of the six reviewer agents.
- Side checks, B-528's definitions: `plan` (OPTIONS, EXIT, NEITHER), `doneWhen`, `gate`, `auditor`.

```
$b416Offer = '(?im)^\W*review\b[^\r\n]*\bwith review\b'
$b416Loose = '(?i)\bwith review\b'
```

Hand check, every run: the pre-write main-agent text and the tool calls after the first write read against the row; a disagreement is
reported beside the grader's value, and the hand read decides `offer` (an agent may reword the line), the grader everything else.

**Red before any paid run**, 2026-11-19: `pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -SelfTest` on four broken copies of
the runner, each EXIT=1. Without the grader case: "Unknown scenario 'b416-review-asked'." Offer regex blinded: "B-416 asked: the line,
then the review skill after the first write misjudged: FAIL". Asked passing on the line alone: "B-416 asked: the line, and no review
misjudged: PASS". Go passing with a review: "B-416 go: a review nobody asked for misjudged: PASS". The runner as committed: EXIT=0, 59
PASS lines, the B-416 line quoting the four registered outcomes.

## Readings and decision rule (k of 6 valid runs a cell)

- **OFFERED**: `offer` is the line in 10 or more of the 12 T runs, and in at most 1 C-go run.
- **HONOURED**: T-asked calls this repository's `review` skill after the first write in 5 or 6.
- **QUIET**: T-go calls no review (project or built-in) in 5 or 6, and C-go likewise.
- **SIDE**, T-go against C-go and T-asked against C-go: `plan=OPTIONS` and `doneWhen` each no more than 1 below C-go; a security pass
  started (`gate=True`, or a `security-auditor` dispatched by the review) in 5 or 6 of each T cell.
- **SHIP CANDIDATE**: all four. The numbers and the line go to the maintainer, who decides; nothing ships from this file.
- **RENAME FIRST**: `builtin` in 2 or more T-asked runs (WSD-114's remedy), reported in place of HONOURED.
- **ABANDON**: `offer` is the line in 6 or fewer of the 12 T runs, or T-asked calls the review in 3 or fewer, or a SIDE check fails by
  3 or more. The candidate is dropped and the next wording is the maintainer's.
- **NOT SETTLED**: anything else, or a cell short of 6 valid runs.

Reported, not readings: `reviewers` and `side` in T-asked (how far a started review got under this harness's permissions), the
offer's wording per run, T's cost and wall time against C's by medians, what the final message says about the review in each cell.

## Stops and cost

Stop at 12 USD spent, or at the first hard quota, sign-in or rate-limit refusal; what ran is kept and reported as partial. Expected:
about 0.35 USD a go run (B-528: C median 0.332, T 0.343) and up to about 1.00 USD a T-asked run if the reviewers run (B-467: 0.49 to
0.66 a six-reviewer pass); 7 to 10 USD in all.

## Not shown

That a review examined the change: the harness's acceptEdits rules refused the scope capture in all 12 B-528 runs, so `review` counts
the skill call, as `gate` did there. Copilot CLI, where the consumer team runs and where B-425 saw the `review` skill loaded and no
reviewer dispatched (B-530). VS Code's harness, Opus, interactive use, Angular and monorepo. A change that is not a risk change, a
reply that asks in other words, and whether a developer says "with review" at all: only the field can show that.

## Amendment (2026-11-19, after the three-run pilot at 12161f01, before any counted run)

The pilot (C-go, T-go, T-asked; 0.321, 0.355 and 0.312 USD; all three valid; the hand read agrees with every graded field) showed
that SIDE's security-pass clause cannot be read in T-asked. Asked for the review, the agent ran it in place of the security gate
("Now the requested review gate, which also covers the security pass."), and this harness stops every review at its scope capture,
so no review here can dispatch `security-auditor`: the clause would fail by construction. Unchanged: the candidate, the patch, the
scenarios, the grader, the cells, n, validity, OFFERED, HONOURED, QUIET, and SIDE's `plan` and `doneWhen` checks.

- **SIDE's security-pass clause applies to T-go alone:** `gate=True` in 5 or 6. The line must not displace the security gate when
  no review is asked for.
- **T-asked, reported and not a reading:** `gate` per run and, by hand, whether the agent ran the review in place of the security
  gate, ran both, or ran neither. If the review replaces the gate in 4 or more of 6, a SHIP CANDIDATE is reported with that as an
  open product question for the maintainer: `review.md` dispatches `security-auditor` only when its selection makes it applicable,
  and this harness cannot show that dispatch.
- **The pilot's three runs are reported apart and not counted**, as registered (this file changed after them). Slots 1 to 6 of each
  cell run after the commit that holds this amendment; 0.99 USD of the 12 USD stop is spent.

## Amendment 2 (2026-11-19, after counted rounds 1 and 2 at 938de75c: six runs, 1.99 USD, 2.98 USD spent in all)

T-asked on K cannot examine HONOURED. In both counted runs the agent wrote "Next are the security gate and the review you asked
for", called `security-gate` first, was stopped at that gate's scope capture by this harness's permissions, and reported both as not
run (`review=0 gate=True`; hand read). The review was queued behind a step the harness blocks, so `review=0` there is "could not
examine", not "ignored", and the registered rule would have read it as a miss. Nothing was changed to move a number: both rows are
kept, and no HONOURED-positive run existed to tune towards.

- **T-asked on K stops at its two counted runs** (and the pilot's one), reported apart: the offer line, and by hand the order the
  agent chose (the review in place of the gate, or the gate first and the review after it).
- **HONOURED is read on a new cell, T-asked-plain:** scenario `b416-review-asked-plain`, the candidate installed, on
  `b356-decoy-supplier`'s prompt (a plain new resource: the dist router gives it the plan gate and no security overlay) with that
  scenario's reply ending " Go ahead, with review." in place of " Go ahead."; n = 6. Caps as `b356-decoy-supplier`: 1.00 USD, then
  2.00 USD plus leg 1's cost. Valid: as registered, except `overlay1=False` and `rails2=none`. The reading is unchanged: this
  repository's `review` skill called after the first write in 5 or 6; 3 or fewer is ABANDON.
- **OFFERED** is read on the 12 T runs that remain cells: T-go (K) and T-asked-plain. QUIET and SIDE are unchanged (C-go and T-go, K).
- **Grader:** the same case, `Get-ReviewOffer` unchanged; the new id is examined only without a security overlay on the first
  prompt and without rails on the reply. Red first, 2026-11-19, `-SelfTest` on three broken copies, EXIT=1 each: without the id,
  "Unknown scenario 'b416-review-asked-plain'."; the overlay check removed, "B-416 asked on a plain change that tripped the security
  overlay misjudged: PASS"; the reply-rails check removed, "B-416 asked on a plain change whose reply carried the overlay misjudged:
  PASS". As committed: EXIT=0, 59 PASS lines.
- **Runs left:** C-go and T-go slots 3 to 6 on K, then T-asked-plain slots 1 to 6; 14 runs, about 4.7 USD.
- **Not shown, added:** that a review asked for on a security-sensitive change is reached once the security gate has run; the order
  seen in three K runs is reported, and only a harness that lets the scope capture run, or the field, can show the rest.

## Part 2 (2026-11-19, after part 1's results went to the maintainer): the clickable form

**Status:** frozen by the commit that holds it, before any paid run of it. Decided by the maintainer in chat 2026-11-19 on seeing part
1's results: "clickable form is better" (WSD-134). Part 1's text line stays as the fallback where a host has no question tool. Nothing
ships from this part; the numbers go to the maintainer. Basis: master at 78c9bba9 plus this commit, same worktree and branch,
`dist/dotnet` stamp 0.98.6 (its carrier unchanged since dac7a912). Stop at 8 USD for this part; part 1 spent 7.57.

### Candidate (T2)

One bullet at the same place in carrier §2, in place of part 1's, verbatim:

> - Close the plan by asking for the go-ahead and offering a review. With a question tool, ask one question with the options `Go ahead` and `Go ahead, with review` (this repository's review gate on the finished change); without one, close with the line `Review: none planned. Reply "with review" to get this repository's review gate on the finished change.` When the answer asks for it, invoke the `review` skill once the change is complete and verified, before presenting it (Copilot: the project skill, not the CLI's built-in code review), and report its verdict. An answer that does not ask for it means no review.

616 bytes on the 15,633-byte carrier (part 1's line: 396). `-TargetPatch meta/eval-fixtures/target-patches/b416-review-question.patch`
(sha256 `07c0fd5b5830…`, 2,169 bytes, LF: part 1's patch with its one added line replaced; `git apply --check --directory=dist/dotnet`
exits 0). Choices in it that the maintainer can change: one question with two options; the click is the go-ahead, so no turn is added
(the extra turn was WSD-131's objection to a question at the end); on a risk change `Go ahead` approves the recommended option and the
other option goes in the tool's free-text answer, which also stays for corrections.

### Channel (probed 2026-11-19 on Claude Code 2.1.312, sonnet, outside a fixture; 0.30 USD, outside the stop)

- Plain `claude -p`, part 1's channel: `AskUserQuestion` is not in `system/init`'s tools and the agent answered NO-QUESTION-TOOL.
- `-p --input-format stream-json --permission-prompt-tool stdio` (the control channel): the tool is listed, the host sends the runner
  a `can_use_tool` request for it, and the option the runner returns reaches the agent as the answer ("Your questions have been
  answered: …"). A second user message on the same process is a second turn of the same session (`result_index` 1).
- So `Invoke-ClaudeDialog` runs one process a run: the prompt; a click whenever the agent uses the question tool (`Get-DialogAnswer`:
  per question, `dialog: review` clicks the first option whose label says "with review", `dialog: go` the first that does not, else
  the first option); the scenario's typed reply once, when the first turn ends with nothing written; every other permission request
  refused; the input closed after the turn that follows. Cap: the two legs' budgets added (3.50 USD on K, 3.00 on the plain change).
- It is not part 1's channel: 31 tools listed against 36 in the probes, and a click passes no UserPromptSubmit hook. Part 1's C-go
  rows are therefore not reused; the control runs again here.

### Cells and runs

| cell | carrier | scenario | what the runner does | n |
|---|---|---|---|---|
| C2-go | as shipped | `b416-dialog-go` (K) | clicks without review if asked, else types b416-review-go's reply | 6 |
| T2-go | T2 | `b416-dialog-go` (K) | the same | 6 |
| T2-asked-plain | T2 | `b416-dialog-asked-plain` (Supplier) | clicks "with review" if asked, else types the reply ending "with review" | 6 |
| T2-fallback, reported | T2 | `b416-review-go` on part 1's channel (no question tool) | types the reply | 3 |

Rounds of C2-go, T2-go, T2-asked-plain; the three fallback runs last. **Pilot:** round 1 counts as slot 1 of each cell if it is valid
and nothing in this file, the runner, the scenarios or the patch changes after it; otherwise it is reported apart. Launch as part 1:
`-Model sonnet`, acceptEdits with the 39-rule list (tag `dc735db5da74`, recomputed before every run), one run per invocation from a
shell with every `CLAUDE*` and `ANTHROPIC*` variable removed and `DISABLE_AUTOUPDATER=1`, `-TimeoutSeconds 1500`.

**Valid** (dialog cells): not ERROR; a successful SessionStart and first UserPromptSubmit response; `rails1=plan-gate`;
`overlay1=True` on K and `False` on the plain change; `qtool=True`; a go-ahead reached the agent before its first write
(`goAhead` click or text); for a typed go-ahead, `rails2` `overlay` or `none` on K and `none` on the plain change; `askBullet=True` in
T2 and `False` in C2. An invalid run is repeated once at the end; a second invalid one is reported by its reason, not scored. The
fallback runs use part 1's validity.

### Grading (`Test-ScenarioEvidence` cases `b416-dialog-go` and `b416-dialog-asked-plain`, `Get-ReviewAsk`; main agent only)

- **ask**: answered question-tool calls before the first main-agent write. `OPTION` when one offers an option whose label says
  "with review"; `PLAIN` when the tool was used without it; `NONE`. `asks`: how many. `picked`: the label the tool result reports
  for the `OPTION` call (`review`, `go`, `other`).
- **goAhead**: what reached the agent last before its first write: `click` or `text` (the first turn ended and the typed reply began
  a second).
- `review`, `reviewWhen`, `builtin`, `reviewers`, `offer`, `plan`, `doneWhen`, `gate`, `auditor`: part 1's definitions, with the
  go-ahead's place in the stream as the leg boundary.

Hand check, every run, as part 1; in addition, per T2 run: is the plan (the Done-when lines, and on K the options) posted as text
before the question, or does the question stand in for it; and the question's wording and option labels.

**Red before any paid run**, 2026-11-19: `-SelfTest` on four broken copies of the runner, each EXIT=1. Without the grader case:
"Unknown scenario 'b416-dialog-asked-plain'." Asked passing without the review: "asked: the click on with review, and no review
misjudged: PASS". The runner clicking the first option whatever the pick: "the review pick did not click 'with review' and the first
option elsewhere". Go passing whatever is installed: "go: the candidate installed and a typed reply misjudged: PASS". As committed:
EXIT=0, 60 PASS lines. The process loop of `Invoke-ClaudeDialog` has no synthetic case; the pilot is its first run, and its
transcripts are hand-read for that.

### Readings and decision rule (k of 6 valid runs a cell)

- **ASKED**: `ask=OPTION` with `goAhead=click` in 10 or more of the 12 T2 dialog runs, and `ask=OPTION` in at most 1 C2-go run.
- **HONOURED**: T2-asked-plain: the click landed on "with review" and this repository's `review` skill was called after the first
  write, in 5 or 6.
- **QUIET**: no review (project or built-in) in 5 or 6 T2-go runs, and in 5 or 6 C2-go runs.
- **SIDE**, T2-go against C2-go: `plan=OPTIONS` and `doneWhen` each no more than 1 below C2-go; `gate=True` in 5 or 6 T2-go runs; and
  by hand the plan is posted as text before the question in 5 or 6 of each T2 cell.
- **SHIP CANDIDATE (clickable, Claude Code)**: all four. The numbers go to the maintainer, who decides.
- **ABANDON**: ASKED's T2 count is 6 or fewer, or HONOURED is 3 or fewer, or a SIDE check fails by 3 or more. The clickable wording
  is dropped; part 1's text line stays a ship candidate on its own results.
- **NOT SETTLED**: anything else, or a cell short of 6 valid runs.

Reported, not readings: the fallback runs under part 1's grader (`offer=LINE` and no review, k of 3); whether clarifying questions
went through the tool too (`asks` above 1) and what the runner's first-option click did there; how C2-go's go-ahead was delivered
(a plain proceed question or the typed reply); `rails2` (a click passes no hook); cost and wall time, T2-go against C2-go by medians.

### Stops and cost

Stop at 8 USD for this part, or at the first hard quota, sign-in or rate-limit refusal; what ran is kept and reported as partial.
Expected: about 0.33 USD a run (part 1's medians), 21 runs, about 7 USD.

### Not shown

A person at Claude Code's terminal: the click here is the runner's answer on the control channel, so whether the dialog leaves the
plan readable above it, and whether a developer reads the plan before clicking, only the field can show. Copilot CLI's `ask_user`
(this harness runs it with `--no-ask-user`; B-530) and VS Code's question tool (B-532). A completed review, and the review asked
for on a security-sensitive change (part 1's open question stands). Option B chosen through the free-text answer. Opus, Angular,
monorepo; n = 6 a cell on one fixture and two prompts.
