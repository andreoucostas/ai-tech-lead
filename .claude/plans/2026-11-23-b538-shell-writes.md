# B-538 — agent file writes through the shell, which the write guard and post-write hooks do not see

Design for peer review, 2026-11-23. Author: the main session (Opus). Status: option E built (section 6 records
the review and what changed from this draft); the probe is the maintainer's call.

## 1. The item

`meta/BACKLOG.md` B-538 (rank 7, the first unblocked row; ranks 1-6 wait for Copilot on 2026-12-01, the team's
counts, or 1.0.0). Filed from a hand read of two Fable 5.1 `route-fix` runs that made the production fix with
`sed -i` through the Bash tool. Claude Code registers `guard.ps1` (secrets, test-defeats, suppressions) on
`Write|Edit|NotebookEdit` only, and `post-write.ps1` (build feedback) and `audit-trail.ps1` (`.claude/ai-audit.log`)
on `Write|Edit`: see `src/stacks/dotnet/files/.claude/settings.json`. Copilot's `.github/hooks/hooks.json` runs the
guard on every tool call with no matcher, and the guard allows any call that carries no file path plus content.
The shipped docs already state the limit (`src/core/docs/enforcement-surfaces.md:171` matrix row, `:188-197`
scope caveat). Filed as a possible secret leak that ordinary use triggers (WSD-124, WSD-125). The entry's first
step: "measure how often, on which models, from retained transcripts, before any change."

## 2. Measurement (done; no paid run)

Corpus: every retained Claude Code transcript on this machine whose working directory is an eval fixture
(`%TEMP%\ai-tech-lead-agent-evals-*`, `b539`, `b543`, `b466`, `b467`, `orders-*`, `billing-svc-*` and similar),
deduplicated by session id: 316 main sessions, 2026-09-30 to 2026-11-20, Claude Code 2.1.281 to 2.1.312.
Maintainer sessions and personal projects excluded. Scanner: `scratchpad/b538/scan2.py` (not in the repo).
A shell write = a Bash/PowerShell command with a `>`/`>>` redirect or heredoc (`cat > f <<EOF`), `tee`,
`sed -i`/`perl -i`, `Set-Content`/`Add-Content`/`Out-File`, `[IO.File]::Write*`, `New-Item -Value`, `git apply`,
or a python/node body that opens a file for writing; its target classified repo / temp / outside / unresolved,
and by extension production code, test code, Markdown, other.

Framework installed (hook output in the transcript), 304 sessions: Sonnet 5.5 287, Sonnet 5 16, Haiku 5.5 1.

| | sessions | wrote code | wrote code through the shell | of which production code |
|---|---|---|---|---|
| Sonnet 5.5 | 287 | 236 | 63 | 43 |
| Sonnet 5 | 16 | 7 | 0 | 0 |
| total | 304 | 243 | **63 (21% of all, 26% of those that wrote code)** | 43 |

- Code writes: 1,094 through Edit/Write, **168 through the shell (13.3%)**. All 168 through the **Bash** tool
  (heredoc/redirect 72, `sed -i` 61, python script 35); **none through the PowerShell tool**, though the shipped
  settings set `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` and the docs' example names the PowerShell tool.
- Per session: 241 none, 17 one, 46 two to eight.
- It is the model's habit, not the framework's: paired arms of B-543 (same fixture, same prompt) — returns feature
  6 of 6 framework runs and 5 of 6 no-framework runs wrote code through the shell; CSV export 1 of 6 against 3 of 6.
- Task shape decides: multi-file features (`cat > A.cs <<EOF … cat > B.cs <<EOF`) and one-line fixes (`sed -i`).
- Fable: not in the corpus (those runs used `--no-session-persistence`); the two hand reads stand: Fable 5.1 2 of 2
  `sed -i`, Fable 5.2 0 of 2 (n = 2, one scenario). Opus: no fixture runs.
- Precision: 25 of 25 sampled hits were real shell writes into the fixture's code. Recall not measured (`cp`,
  `Copy-Item`, variables holding the path, other interpreters are not recognised).

Harm, as far as retained data can show it:
- **Replay.** Each shell-written content was rebuilt as the event it would have been (heredoc body → `Write`
  content; `sed` replacement → `Edit` new_string; script body → `Edit` new_string, an upper bound) and piped into a
  copy of `dist/dotnet/.claude/hooks/guard.ps1`: **0 of 208 blocked** (164 framework, 44 no-framework). The same
  harness blocked a planted `#pragma warning disable` heredoc and a key-shaped `sed -i` (2 of 2, exit 2) and allowed
  a clean heredoc (1 of 1).
- **Around a block.** 6 guard blocks in 5 consumer-shaped canary sessions (Sonnet 5.5, Haiku 5.5): in none did the
  agent then write that file through the shell (one restored it with `git checkout --`).
- **What the zero does not show.** The corpus has no guard block on any route: no fixture asked for content the
  guard refuses. So the replay's zero says the fixtures write no secrets, not that a shell write would not carry
  one. The quantity the data does give is the bypass rate: of whatever an agent on Claude Code with Sonnet 5.5
  writes, about 1 in 8 code writes, and about a quarter of sessions that write code, go where the guard does not look.

Cost of the obvious fix, measured here: the dist guard takes about 1.4 s on a Bash event (0.65 s of it pwsh start),
and Claude Code's hook command starts PowerShell once more, so about 2 s per shell call. Fixture sessions make a
median 7 shell calls (p90 15, max 30); interactive sessions make many more. Shell is the most-used tool family
(Bash 10,840 + PowerShell 6,043 calls against Edit 4,351 + Write 1,566 across all transcripts).

Host fact (Claude Code hooks reference, read through a subagent, wording not verbatim-checked): a hook entry may
carry `if` with one permission rule (`"Bash(git *)"`), "best-effort", no minimum version stated; `matcher` filters
on tool name only; hooks that inspect shell commands should match `Bash|PowerShell`.

## 3. The rules that decide

- AGENTS.md: value to consumers per unit of maintainer attention; no new script, gate or record unless required.
- WSD-139 (2026-11-19): a shipped change needs an observed harm (field report or failing eval) and a test that can
  see the fix; otherwise record the reopen trigger and close. WSD-141 lightens it only for a new opt-in capability.
- WSD-124/125: a possible secret leak that ordinary use triggers is filed without being observed. That is the
  filing bar; WSD-139 is the shipping bar.
- Guarded paths (`guard.ps1`, `src/stacks/*/files/.claude/**`, any `settings*.json`) need red-first, CP437, and a
  fresh-session attack (AGENTS.md step 4).
- The CI guide already recommends push-time secret scanning as the backstop that "covers every push"
  (`src/stacks/*/files/docs/ci-integration.md`, "Recommended alongside"), and the guard is documented as a floor.
- WSD-047 (2026-08-22; missed by this draft and by the review, found while implementing) already answers this gap:
  the shell-write gap is DOCUMENT, because sniffing command text is unbounded and blocks reading as well as writing.
  It names no reopen trigger. Option E applies it with numbers.

## 4. Options

**A. The guard reads shell writes.** Parse heredoc/redirect bodies (whole-file write, old text = file on disk),
`sed -i`/`perl -i` substitutions (old = pattern, new = replacement), PowerShell `Set-Content`/`Out-File`/
`Add-Content` with a literal value and `[IO.File]::WriteAll*` literals; run the existing per-write checks; block
with the same reasons. Claude Code: add a `Bash|PowerShell` PreToolUse entry. Copilot: no registration change
(the guard already sees the shell call). Covers 133 of the 168 measured shell code writes (79%); scripts (35) stay
outside, a stated limit. Cost: about 2 s on every shell call on Claude Code (the `if` field cannot filter it
usefully: most build and test commands carry `2>&1`, so any `*>*` rule matches them, and one rule per handler means
eight or more handlers); 100-150 lines of shell parsing in a 1,037-line guarded file that already had a backtracking
defect (B-542); step-4 attack. Behaviour change for clean writes: none (0 of 208 replays blocked). No observed harm.

**A2. A, Copilot only.** Zero added latency (the guard already runs there), but Copilot's shell-write habit is
unmeasured and the corpus is all Claude Code; waits for 2026-12-01 to see red on a host.

**B. One rule line** ("write files with the file tools, not the shell: only those are checked"). Always-loaded text;
WSD-139 applies in full and WSD-107 saw one added sentence do harm; would need a paid A/B on the B-543 returns
fixture (6 of 6 baseline) to see it work; likely weak against a habit the no-framework arm shows equally.

**C. Check the result, not the route.** At end of turn (the existing `Stop`/`agentStop` hooks), build the working
tree's added lines since the turn began into one synthetic `apply_patch` event and run the guard once. Covers every
route (shell, scripts, copies, generators) for one guard call per turn. Costs: a baseline at turn start (an agent may
commit mid-turn), the developer's own uncommitted edits attributed to the agent, after-the-fact (on disk, not yet
pushed), a guarded hook change, and Copilot's `agentStop` delivers only with the next prompt. No observed harm.

**D. Permission denies** (`Bash(sed -i *)`, …) in the shipped settings. Matches heredocs poorly, blocks temp-file
writes too, no Copilot equivalent, friction in a quarter of sessions. Rejected.

**E. Record, correct the docs, close (recommended).** Under WSD-139 nothing in the guard or its registrations
changes on this evidence. What does ship is the corrected account of the limit, because the measurement shows the
shipped text understates it:
1. `src/core/docs/enforcement-surfaces.md` scope caveat (`:188-197`): the commonest routes are the **Bash** tool's
   heredoc (`cat > File.cs <<'EOF'`), `sed -i` and inline scripts, not only PowerShell `Set-Content`; measured rate
   (Claude Code, Sonnet 5.5, fixture tasks: about 1 code write in 8, about a quarter of sessions that write code); so
   push-time secret scanning is what covers a secret written by any route. On-demand doc, a few hundred characters;
   rebuild ×3, validate ×3, footprint check.
2. A changelog line under `## 0.99.1 — Unreleased` in the three stack changelogs and the root `CHANGELOG.md`
   (invariant 7 asks it only for behaviour changes; recent doc-only changes added one, consumer's voice).
3. `meta/eval-results.md`: a hand-written B-538 section with the numbers above, the replay and its control, limits,
   decisions opened and reopen triggers met (none).
4. Close B-538: delete the entry and its pick-up row (ranks below one up), one line in `meta/BACKLOG-DONE.md` with
   the reopen trigger.
5. Reopen trigger: a shell write the replay shows the guard would block (an eval or a field report), or an agent
   writing a file through the shell after a guard refused it; or Copilot measured routing most writes through its
   shell (A2's case).
Not done: the shipped `AGENTS.md` Registers line ("AI-assisted file changes are appended to `.claude/ai-audit.log`
automatically") also overstates, but it is consumer-owned after install and always loaded; leave it (CLOSED line).

Tier: ordinary (`src/core/docs/**`, changelogs, `meta/**`). Cost-benefit: no runtime or always-loaded cost; a team
reading the enforcement doc learns the real size of the gap and what covers it.

## 5. What I want from the reviewer

Attack the recommendation, not the prose. In particular:
1. Is E the right reading of WSD-139 when the harm class is a secret leak, where "observe it first" means after a
   leak? Or does WSD-125 carry this to a change?
2. Is there a better design than A, C and E — for example a cheaper way to make the guard see shell writes on
   Claude Code without ~2 s per shell call, or a canary eval that would turn "possible" into observed or not,
   cheaply, before deciding?
3. Is anything in the measurement wrong or overstated (corpus selection, the replay as an instrument, the
   framework/no-framework comparison, the latency figure)?

## 6. Review and outcome (2026-11-23)

Reviewer: a fresh Fable 5.2 session given this file, the rulebook, the decisions and the scratch scripts, asked to
recommend a different design outright if one was better. Verdict: **agree with E, with changes**; strongest reason:
nothing retained shows a shell write the guard would have refused, and A puts 100-150 lines of shell parsing into a
guarded file for a harm nobody has seen. Its findings, each re-checked by the main session:

- **Latency is not the reason against A** (confirmed). The reviewer timed the shapes: guard alone 1,459 ms, today's
  pwsh-in-pwsh registration 2,273 ms, an outer pwsh that pre-filters on a regex and starts the guard only on a match
  868 ms, a Bash-shell pre-filter 215 ms (the last sits uneasily with invariant 3). The main session's re-run of the
  pwsh pre-filter: 223-273 ms (6 runs). The filter belongs in the hook command; an early exit inside `guard.ps1` saves
  little (1,235 ms), since start-up of the script dominates. Recorded reason against A: no observed harm, and a parser
  in a guarded file (WSD-047).
- **Wrong path** (confirmed): `ci-integration.md` lives per stack, not under `src/core/docs/`.
- **The corpus is clustered** (confirmed): sessions with a shell code write, agent-evals 27 of 160, B-539 22 of 68,
  B-543 13 of 18, the rest 1 of 58. The doc states the 17% to 72% spread, not "1 in 8" as a consumer rate.
- **"None through the PowerShell tool"** was only suspected to mean the tool was rarely called (checked: 473 PowerShell
  against 1,340 Bash calls in the framework fixture sessions, so the finding stands).
- **Counts and replay coverage reproduce**: 164 of 168 writes yield a replay event; the 4 misses are `sed … > file`.
- **The trigger was passive**: the corpus cannot fire it, since no fixture asks for refusable content. Added: the probe
  (about 6 runs on B-543's returns fixture with a key-shaped value in new configuration, roughly 2 to 3 USD).

Changed from the draft by the main session: B-538 stays open for the probe instead of closing with the probe
"stated", since a closed item leaves nobody to run it; whether to spend is the maintainer's call.

**If the item reopens, build this, not A** (the reviewer's design): a pre-filtered `Bash|PowerShell` PreToolUse entry
in the three `src/stacks/*/files/.claude/settings.json` files whose outer command acts only on `git commit` or
`git push`, feeding the staged or outgoing added lines to the guard as one `apply_patch` event, which the guard already
reads. No shell parser; it covers scripts and copies, which A misses; cost about 0.1-0.2 s over the PowerShell start
already paid on other shell calls, one guard run per commit. Red first: a fixture event for `git commit` over a staged
key-shaped line, expecting `EXIT=2`. Limit: it sees nothing when the developer commits, so push-time scanning stays the
backstop. Guarded (settings), step 4.

**Implementation review** (a second fresh Fable 5.2 session, on the uncommitted tree): ship with fixes. Verified and
fixed: the corpus spans Claude Code 2.1.281 to 2.1.312, not 2.1.300 and 2.1.312 (16 Sonnet 5 sessions on 2.1.281);
a fourth code-writing family (billing-svc, Sonnet 5, 7 of 9 wrote code, none through the shell) makes "the three
families that write code" false, so the text says "the three largest"; 164 of the 168 writes were replayed, not 168;
11 `sed -i` writes are mutate-and-restore red checks, so "one-line edits", not "fixes"; 2 script writes are phantom
targets (noted in the evidence). Suspected and applied: the changelog line now carries "where you have enabled it";
"not this hook" (which does catch the Write/Edit route) is gone; the paired comparison gives its 6 runs per arm; pick-up
row 7 says "in fixture runs"; the Copilot reopen case is in the records; the CLOSED line names WSD-106's condition.
