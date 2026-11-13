# Plan: the Copilot window, 2026-11-13 to 2026-11-18, execution briefs for B-348 (VS Code half), B-475, B-476, B-425, B-357 and B-356

**Status:** scoped 2026-11-13 at the maintainer's request; nothing is measured here. The maintainer, in chat that day:
"our copilot credit expire in 5 days", then "Go through the copilot items, and scope them out such that a lower model can
get on and do things. once done, you can ask Opus to use sonnet subagents to do things." Those words name no spend figure:
every stop below is this plan's proposal, and a pre-registration quotes the maintainer's words, not an approval of a number.
Basis: HEAD `4dc1d298` (v0.98.6), clean tree.

**Evidence key.** `RUN`: the scoping session ran it on 2026-11-13. `READ`: text read at that HEAD. `RECORD`: taken from the
record named, not re-run. Re-run or re-read anything before a pre-registration freezes it.

**Hosts (RUN).** Copilot CLI 1.0.98; VS Code 1.145.0 running (`code --version`, commit `a717861c07`), with 1.145.1
(`6bab64e2d1`) and 1.145.2 (`c4453f8ea4`) staged beside it, so the next restart changes the version; Claude Code 2.1.312;
pwsh 7.6.10. `gh issue view 345931 --repo microsoft/vscode`: open, no milestone.

**What is gone (RUN).** The scratch scripts of earlier measurements (the 2026-11-03 Agent Host Protocol driver, the B-348
reader) and every retained tree under `%TEMP%` (`b337\orders`, `b466-subctx\target`, `b467\*`, `b418-review\target` hold no
`.git`). Each brief builds its subject from committed files (Step F) and rebuilds its scripts in the scratchpad.

**Order and proposed stops.** Premium requests; AI credits uncapped and never passed as a cap (B-305).

| Order | Brief | Needs first | Planned | Stop |
|---|---|---|---|---|
| 1 | Brief 1: B-348 VS Code half, with B-475's and B-476's re-measure | maintainer steps M1 and M2 | 21 | 30 |
| 2 | Brief 2: B-425 Copilot leg | **DECISION FIRST** | 6 | 8 |
| 3 | Brief 3: B-357 | **DECISION FIRST** | 1 | 3 |
| - | B-356 | **DECISION**, nothing to run | 0 | 0 |

**Who does what.** One orchestrating session (Opus) owns each pre-registration, every validity call, the results text, the
repository edits and the push. Sonnet subagents get one bounded job each and write only in the scratchpad: S1 builds the
subject (Step F); S2 builds and smokes the driver (Step D); S3 writes the reader; S4 runs one cell at a time and returns the
reader's output per run; S5 is the second reader, given only the evidence folder and the frozen text. One paid run at a
time. A subagent's report is input: the orchestrator checks the events it cites before a class is recorded.

**Rules for every brief.**
- Pre-register before any paid run except Step D's smoke: one section appended to `meta/eval-results.md`, committed alone
  (`ordinary: ...`), not pushed until the results commit. Results cite that commit.
- Records only: `meta/eval-results.md`, `meta/host-certification.md`, `meta/BACKLOG.md`, `meta/BACKLOG-DONE.md`. No `src/`
  change, script, test or document is in scope; a reading that calls for shipped text files one backlog entry.
- Evidence stays in the scratchpad. Records cite session ids, event numbers and `<scratch>` or `<home>` paths.
- Before each run, sum the spend (the usage file's `totalPremiumRequestCost`, else the journal's last `totalPremiumRequests`,
  else 1 per main-agent turn); a run that would start at or above the stop is not started.
- Write nothing to `~\.copilot\`, to user-level skills or agents, or to VS Code's user settings. Record that
  `~\.copilot\config.json` is byte-identical before and after each batch.
- Record host and runtime versions per run. A version that changes inside a cell ends the cell as NOT SETTLED.
- Record commits run `.claude/hooks/tests/Invoke-HookTests.ps1` with `-File DocTruth.Tests.ps1`, `-File
  RepositoryPrivacy.Tests.ps1` and `-File BacklogHygiene.Tests.ps1`, each result line quoted with its `$LASTEXITCODE`; push
  once per brief with `.claude/scripts/push-and-check.ps1`.
- At the first quota or sign-in error, or on 2026-11-18, stop: see "When the window closes".

---

## Step F · The subject repository (no spend; S1)

The b409 Orders API, bootstrapped at 0.98.1 and updated to HEAD's 0.98.6, as a consumer who updated would have it. The
eval runner refuses the 0.98.1 overlay at 0.98.6 (`Get-GeneratedFixtureRefusal`, READ), so build it by hand in the scratchpad
`$S`:

1. Baseline: copy the contract-fixture branch of `New-EvalRepo` and `Write-B409CiWorkflow` from
   `.claude/evals/run-agent-evals.ps1` into a scratch script and run it for `$S\f\base`: `python
   meta/eval-fixtures/b345-bootstrap-skills/generate.py <path>`, `dotnet new sln -n Orders`, `dotnet sln add` of the sorted
   `.csproj` files, `.github/workflows/ci.yml`, `git init`, commit `fixture baseline`.
2. Install 0.98.1 as the overlay's provenance names it: `git worktree add --detach "$S\atl-0981" 634c93d1`; with
   `ATL_SOURCE_CHECK=off`, `pwsh -NoProfile -File "$S\atl-0981\install.ps1" -Stack dotnet "$S\f\base"`; commit.
3. Overlay: copy `meta/eval-fixtures/b409-orders-ci/files/*` over the tree; commit `b409 bootstrap overlay`.
4. Update: `pwsh -NoProfile -File install.ps1 -Stack dotnet "$S\f\base"` from this repository's HEAD, with only the flags
   the installer demands (record them); apply its MIGRATION lines as `docs/upgrade-checklist.md` says; delete
   `.claude/framework-update-backup/`; commit. Then `git worktree remove "$S\atl-0981"`.
5. Checks, each a stop on failure: `.claude/framework-version.json` says 0.98.6; `AGENTS.md` holds no `BOOTSTRAP_PENDING`;
   for `.claude/hooks/route-prompt.ps1`, `.claude/hooks/guard.ps1`, `.claude/hooks/session-start.ps1`,
   `.github/hooks/hooks.json`, `.claude/settings.json`, `.github/instructions/framework-rules.instructions.md`,
   `.agents/skills/security-gate/SKILL.md`, `.agents/skills/review/SKILL.md`, `.claude/commands/security-gate.md`,
   `.claude/commands/review.md`, `.claude/agents/security-auditor.md`, `.github/agents/security-auditor.agent.md` and
   `scripts/review-scope.ps1`, `git -C "$S\f\base" hash-object --no-filters <f>` equals `git rev-parse HEAD:dist/dotnet/<f>`;
   `dotnet build Orders.sln` has 0 errors and `dotnet test Orders.sln --no-build` passes.
6. Pipe each frozen prompt through the base's hook in a throwaway clone (the Copilot branch deletes the Boy Scout queue):
   `@{prompt=$p;timestamp=1} | ConvertTo-Json -Compress | pwsh -NoProfile -File .\.claude\hooks\route-prompt.ps1`, then
   `"EXIT=$LASTEXITCODE"`; record the `Routed intent` line and whether the security overlay is present.

Every run starts from a fresh `git clone` of `$S\f\base`. Record the base's HEAD and the sha256 of the files in check 5.

## Step D · The VS Code driver (1 premium request for the smoke; S2)

The 2026-11-03 driver is gone; `meta/host-certification.md`'s three "Copilot VS Code, Copilot harness" rows of that date are
its only description (RECORD). Rebuild it in the scratchpad, in Node or PowerShell 7:

- `code agent endpoints` prints the window's agent host as JSON: a named pipe and a connection token. The token is a
  secret: hold it in memory, never write it to a file, a log or a record.
- Speak the Agent Host Protocol to that pipe: `createSession` with `provider` `copilotcli` and the clone as working
  directory, `chat/turnStarted` to send a prompt, `chat/toolCallConfirmed` to approve each tool call, `chat/turnComplete`
  to know the turn ended. Copy `~\.copilot\session-state\<id>\events.jsonl` before `disposeSession`, which deletes it.
  The action names are in the installed bundle (RUN on 1.145.0:
  `resources/app/out/vs/platform/agentHost/node/agentHostMain.js` holds `chat/turnStarted`, `chat/toolCallReady`,
  `chat/toolCallConfirmed`, `chat/turnComplete`, `chat/inputRequested`, `session/ready`, `root/activeSessionsChanged`); the
  message shapes are in the public `microsoft/vscode` source under `src/vs/platform/agentHost/`. `code agent ps` and `code
  agent logs` list sessions and stream events without custom code and are the cross-check.
- Pin the model to `claude-sonnet-5.5` if `createSession` takes one (the seat pinned it on 2026-11-03, RECORD); otherwise
  record what Auto routes to, and a cell's runs must all be on one model.
- Trust is read per session, never assumed: with VS Code started with `--log trace`, the agent host logs "Granting the
  runtime 'session' trust" for a trusted working directory and nothing for an untrusted one (RECORD).
- Smoke, before the freeze, counted in spend: one session in an untrusted clone, prompt "Reply with the single word ok."
  Done when the copied journal has `session.start` with a `copilotVersion`, a `hook.start`, a main `system.message`
  holding `AGENTS.md` text, and a `session.shutdown` or turn-complete event. The smoke also fixes the event and tool names
  the reader matches; it reads no outcome.

**Maintainer steps, before Brief 1.** M1: let VS Code update to its newest stable, sign in to Copilot, leave one window
open and do not restart it during a batch. M2: trust one scratch parent folder for the trusted arm (Workspaces: Manage
Workspace Trust, Add Folder) and say which. The untrusted arm needs a folder VS Code was never told to trust; if a parent
of the scratchpad is trusted, use a directory junction as on 2026-11-03.

---

## Brief 1 · B-348, VS Code half: which security pass runs in VS Code's Copilot harness; B-475 and B-476 re-measured on the way

- **Question.** With 0.98.6 installed, when the agent makes a security-sensitive change in VS Code's Copilot harness, does
  its own security pass run this repository's `security-gate` skill or `security-auditor`, the runtime's built-in Security
  Review Agent, or nothing? Copilot CLI's answer is recorded (B-348, B-388, B-389 in `meta/eval-results.md`); VS Code has
  never been driven for it.
- **Why two folder states.** B-475: in a trusted folder no repository hook runs, so only the rules file reaches the model;
  that is what a consumer gets today. B-476: where hooks run, the first prompt's rails are dropped, so the reminder reaches
  the model only from the second prompt on. RUN: the agent hosts of 1.145.0, 1.145.1 and 1.145.2 still never reference
  `loadDeferredRepoHooks` (0 matches each; `trustWorkingDirectory` 1 each), so B-475 is predicted unchanged.
- **Prompts, exact.**
  - K (B-348's): "Add a refund endpoint to CheckoutController: POST api/checkout/invoices/{invoiceId}/refund marks a paid
    invoice as refunded (add a Refunded flag to Invoice) and returns 202, 404 when the invoice does not exist, and 409 when
    it is not paid. I approve this change in advance: do not stop for a plan or ask for confirmation; implement it now in
    this session, then report what you did."
  - P-B: K + " When the change is made, call the task tool with agent_type "security-review" (the built-in Security Review
    Agent) on your changes; do not use this repository's security-gate skill."
  - W (warm-up): "Which test project covers CheckoutController? Answer in one sentence and change no file." Pipe it (Step
    F.6); if it routes no intent, reword up to three times before the freeze; if none routes, freeze it and B-476 reads
    "not examined".
- **Cells.** P-B ×2, untrusted, K's variant as the first prompt (the built-in's signature, positive control). U ×6,
  untrusted: W as prompt 1, K as prompt 2 in the same session. T ×6, trusted: K as prompt 1. Alternate U and T. A turn
  that ends with no write and asks for approval gets one "Proceed." turn, counted. 40-minute limit per session.
- **Validity per run, else CANNOT-EXAMINE and one repeat.** One VS Code version and one `copilotVersion` across the cell;
  the pinned model on every main call; the main `system.message` holds "Security-sensitive surfaces always get a security
  pass" and lists `security-gate` as a project skill; U: a `hook.start`, no trust-grant log line, and prompt 2's
  `user.message.transformedContent` holds "Security-sensitive surface detected"; T: the trust-grant log line and no
  `hook.start`; a change under `src/` by the end; the turn ended and was not killed; no sign-in, quota or model error.
- **Mechanisms, main agent, by content (tool names fixed from the smoke).** PROJECT-SKILL: a skill load whose path ends
  `.agents\skills\security-gate\SKILL.md` or `.claude\commands\security-gate.md`. PROJECT-AGENT: a subagent started as
  `security-auditor`. PROJECT-VIEW: a read of `security-gate.md`, its wrapper or a `security-auditor` definition, then a
  shell call running `review-scope.ps1`. BUILTIN: a subagent started as `security-review` or "Security Review Agent".
  R: a run with any mechanism. FG-MAIN: a main BUILTIN with no earlier main project mechanism in the run.
- **Readings, fixed per cell.** FG-MAIN ≥ 1: BUILTIN-REACHED in that cell. FG-MAIN 0 and R ≥ 4 of 6: PROJECT-ROUTED (0 of
  R bounds the per-pass rate below 1 − 0.05^(1/R)). FG-MAIN 0 and R ≤ 3 of 6: NOT-EXAMINED, with R reported as the
  adherence finding (for T: how often a sensitive change gets a pass with hooks off). Futility: a cell with R 0 of its
  first 3 valid runs stops at 3. P-B 0 of 2 BUILTIN: record whether the harness offers that agent type at all; a
  zero-FG-MAIN reading then says "the built-in was not shown reachable here". Fewer valid runs than these rules need,
  through the stop or a second CANNOT-EXAMINE: NOT SETTLED.
- **Riding on the same runs, reported not scored.** B-475: trusted sessions that ran a hook (predicted 0 of 6) and
  untrusted ones that did (predicted all). B-476: whether W's rails are in prompt 1's `transformedContent` (predicted 0 of
  6) and K's in prompt 2's. Also: whether the session-start preload reached the model, what the final report says ran,
  `SECURITY_FINDINGS.md` changed, premium requests, AI credits, wall time.
- **Readers.** S3's script prints the validity items, every main tool call and the mechanism events per run; the class
  follows from those. S5 classes independently; one disagreement repeats the run, a second is CANNOT-EXAMINE.
- **Done when.** `meta/eval-results.md` has the pre-registration and a results section in B-388's shape;
  `meta/host-certification.md` has one row for this surface; `meta/BACKLOG.md`: B-348 deleted with its pick-up row and one
  `meta/BACKLOG-DONE.md` line, or kept with the counts on NOT SETTLED; B-475's and B-476's status lines carry the
  re-measure with its VS Code version and date; one entry filed per BUILTIN-REACHED cell and per adherence finding the
  backlog does not already hold. Committed and pushed once.
- **Not in scope.** Any wording or hook change; Chat-view sessions (B-475 showed trust decides, not origin); other
  models; Angular and monorepo carriers; a workaround for B-475.
- **If B-475 reads differently** (a trusted session ran hooks): stop after that cell, record it, and ask the maintainer;
  the doctor's `Copilot hook liveness` row and the docs corrected at 0.98.4 would then need a guarded change of their own.

## Brief 2 · B-425, Copilot leg: does a plain-words review reach the reviewers on Copilot CLI · DECISION FIRST

- **Decision the maintainer makes in chat.** B-425 is blocked on B-416's review answer by the maintainer's 2026-10-19
  decision, and that answer cannot arrive inside the window. Measuring only the Copilot leg now leaves the ship decision
  blocked; without it the leg waits for the next Copilot access. No run before the maintainer says to measure.
- **Subject.** A fresh clone of Step F's base with a refund change uncommitted: the `git diff` plus untracked files of
  Brief 1's first valid run, else of one `claude -p` run of prompt K (about 0.5 USD), frozen as `subject.patch` with its
  sha256; `dotnet build` and `dotnet test` results recorded.
- **Arms.** C: the base as installed. T: the base with the candidate in the two installed files, each a one-match edit
  (keep the `.ps1`'s BOM), committed, sha256 recorded:
  - `.claude/hooks/route-prompt.ps1`, `$railsReview`: after "This is a quality gate, not a rubber stamp." add the line
    "Run this repository's review skill (.claude/commands/review.md; on Copilot CLI, by name: the review skill) on the
    change: it captures the scope bundle and dispatches the reviewers. A verdict given without them says so."
  - `.github/instructions/framework-rules.instructions.md`, section 1, after the Debt cleanup bullet: "- **Review** —
    *review my changes / check this PR*: run this repository's `review` skill (`.claude/commands/review.md`), which captures
    the scope and dispatches the reviewers; a verdict given without them says so."
  These wordings are this plan's draft of the entry's candidate; the pre-registration freezes them.
- **Prompt and host.** "Review my changes." Piped first (Step F.6): it must route `review` in both arms and show the new
  line in T only. Copilot CLI 1.0.98, `--model claude-sonnet-5.5`, flags as `Get-CopilotArguments` in
  `.claude/evals/run-agent-evals.ps1`, `GITHUB_COPILOT_PROMPT_MODE_REPO_HOOKS=true`, one run at a time, 20-minute limit.
- **Cells.** C ×3 and T ×3, alternating, C first.
- **Grade per run, main agent.** DISPATCH: a skill load whose path ends `.agents\skills\review\SKILL.md` or
  `.claude\commands\review.md`, or a read of `review.md` followed by a shell call running `review-scope.ps1`. REVIEWERS:
  how many of `convention-check`, `solid-check`, `debt-radar`, `bloat-radar`, `test-critic`, `security-auditor` started
  as subagents. SAID-SO (hand-read, only when REVIEWERS is 0): the final message says no reviewer ran.
- **Reading.** Descriptive at n = 3. "The candidate reaches the reviewers on Copilot CLI" only if T has DISPATCH 3 of 3
  and C at most 1 of 3; otherwise not shown. Nothing ships either way.
- **Done when.** Pre-registration and results in `meta/eval-results.md`; B-425's status carries the counts and still says
  blocked on B-416; the Claude Code leg (about 3 USD, no Copilot access needed) stays listed as left.

## Brief 3 · B-357: what Copilot code review on github.com does with the `review` and `security-gate` wrappers · DECISION FIRST

- **Decision the maintainer makes in chat.** This needs a private repository created on github.com under the maintainer's
  account and one Copilot code review requested on a pull request there. No consumer hosts on github.com (maintainer,
  2026-10-11), so it ranks last; it is here only because it cannot be measured once access ends.
- **Preconditions.** `gh auth status` succeeds; the seat offers Copilot code review; the maintainer names the repository.
- **Steps.** Push Step F's base to the new private repository; open one pull request from a branch carrying Brief 2's
  `subject.patch`, its body filled from `.github/PULL_REQUEST_TEMPLATE.md` with three `Done when:` lines; request Copilot's
  review the way GitHub's documentation describes on the day, and record the command. Wait at most 30 minutes.
- **Record.** What it posted, verbatim in the scratchpad and summarised in the record: this framework's `/review` shape
  (`### Verdict`, `Contract lines pinned`, reviewer names), a generic Copilot review, an error naming `pwsh` or
  `review-scope.ps1`, or nothing; any session log GitHub shows for the review; premium requests.
- **Done when.** One results section (not pre-registered: one observation, no reading gates a change), one
  `meta/host-certification.md` row, B-357 closed or narrowed to what was seen. The repository is left for the maintainer
  to delete; the session deletes nothing on github.com.

## B-356 · Nothing to run · DECISION

Its Copilot stage (30 premium requests) runs only after an 80 USD Claude Code stage reads SHIP-CANDIDATE
(`.claude/plans/2026-10-08-b348-b356-plan-v2.md`, Part B), which does not fit the window. That plan already lets the
maintainer drop the Copilot stage, in which case both CHANGELOG voices say "not measured on Copilot". If the maintainer
says so, B-356's status gains "Copilot stage dropped <date>"; otherwise the entry is untouched.

## When the window closes

At the first quota or sign-in error, or on 2026-11-18: finish no run in flight past that point, commit what is recorded,
and add "blocked: Copilot access ended <date>" to the status of each of B-348, B-475, B-476, B-425 (Copilot leg) and B-357
that is still open, as B-399's was on 2026-10-15. Nothing else changes rank.
