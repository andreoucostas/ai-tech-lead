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
