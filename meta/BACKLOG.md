# Framework backlog

Open work only, at most 40 entries (`AGENTS.md`, "Records"). Take the first unblocked row of the
pick-up order, one item per fresh session; the tier is read off the changed paths at work time. An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names. An empty backlog says "No open entries." on its
own line under Open entries; the hygiene tests refuse that line beside an entry. A session that
finds an adjacent defect outside AGENTS.md's four guarded harms, which no field report raised,
closes it per WSD-106 with one CLOSED line in `meta/BACKLOG-DONE.md` instead of filing it here.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — ranked 2026-09-30 (WSD-105 probe); re-ranked 2026-10-01 (WSD-107, field replies); idle queue added 2026-09-30 (WSD-106); every earlier entry closed 2026-09-29 (WSD-105)

| Rank | Item | Why here |
|---|---|---|
| 1 | B-326 | False-green class: the host steers `/security-review` to its built-in agent; both reporting teams use Copilot (2026-10-01) |
| 2 | B-337 | Field-triggered: both reporting teams use VS Code Copilot or Copilot CLI, and setup text sends them to Claude Code |
| 3 | B-327 | Idle queue. Guarded; on-demand `/bootstrap` text, though what it writes lands in the consumer's `AGENTS.md` |
| 4 | B-328 | Idle queue. Small and ordinary; the PR review step the Bitbucket Data Center target lacks |
| 5 | B-329 | Idle queue. Guarded; measure first, and stop if a template check cannot fit post-write's 45 s budget |
| 6 | B-330 | Idle queue. Before the next `-Arm none` run; it needs a baseline rerun |
| 7 | B-336 | Idle queue. Measure first; WSD-107's measured sentence did not help even where a project record exists |
| Held | B-331 | Report #6's team replied with its host only (2026-10-01); held for whether `register-service` followed its Unity root |

## Open entries

### B-326 · Observe Copilot CLI interactive /review and /security-review precedence against the project's command files
**Filed against:** v0.91.0 (2026-09-30)
**Priority:** P2 · **Effort:** S to observe, M if text changes · **Invariants:** #1 #7
**Status:** Open; false-green risk: the host's delegation text steers `/security-review` to its built-in agent, and `-p` could not examine
precedence (`meta/host-certification.md`). Bears on the carrier's `security-pass` snippet, WSD-095's unbounded index line and the READMEs'
"deterministic routing" (:23/:25, :206/:209). Method: `copilot -i` in a real TTY, `--no-auto-update`, a benign marker, a sibling control.

### B-337 · Tell Copilot-only teams how to run /bootstrap and /adopt, after observing it on Copilot
**Filed against:** v0.91.0 (2026-10-01)
**Priority:** P2 · **Effort:** S to observe, M to change · **Invariants:** #1 #7
**Status:** Open; field-triggered: report #6's and #8's teams use VS Code Copilot or Copilot CLI (`meta/field-reports.md`), yet the installer
handoff and each README's step-3 rows say `/bootstrap` and `/adopt` need a Claude Code session, while both ship as `.github/prompts`. Observe one
Copilot `/bootstrap` on a scratch install and record a dated row first; then the guarded installer text (requirement 4) and the READMEs.

### B-327 · Teach /bootstrap to detect zoneless Angular, @defer, OpenTelemetry, Hangfire or Quartz, and minimal APIs
**Filed against:** v0.91.0 (2026-09-30)
**Priority:** P3 · **Effort:** M · **Invariants:** #1 #7
**Status:** Open; guarded, monorepo sibling included. Extend the existing lines: Angular "Signals adoption" (zoneless change detection,
`@defer`); .NET "Entry points" (minimal APIs versus controllers; Hangfire or Quartz beside hosted services) and "Logging" (OpenTelemetry).
The command is on-demand, but the conventions it writes grow the consumer's always-loaded `AGENTS.md`.

### B-328 · Add a one-line Bitbucket Data Center PR-branch review recipe
**Filed against:** v0.91.0 (2026-09-30)
**Priority:** P3 · **Effort:** S · **Invariants:** #1 #7
**Status:** Open. Each stack's `README.md` ("Running on Bitbucket Data Center") and `docs/ci-integration.md` gain one line: fetch the PR's
source ref into a local branch (Bitbucket DC publishes `refs/pull-requests/<id>/from`; confirm on an instance), then run
`/review origin/<target>...<branch>`, a range form `/review` accepts. No file under `src/` shows `/review` on a PR branch today.

### B-329 · Give Angular template (.html) writes build feedback in post-write
**Filed against:** v0.91.0 (2026-09-30)
**Priority:** P3 · **Effort:** S to measure, M to ship · **Invariants:** #1 #3 #5 #7
**Status:** Open; guarded, within WSD-102. Angular `post-write.ps1` runs only for a `.ts` under `src/` or a `tsconfig*.json` (:113-117), and
`tsc --noEmit` does not type-check templates (not run here), so a broken binding goes unreported; monorepo's hook has the same gap. Measure
a template check's wall time on a real-size workspace against the 45 s budget; ship only if it fits, with a red case per host.

### B-330 · Isolate the eval runner's bare arm from the maintainer's user-level configuration
**Filed against:** v0.91.0 (2026-09-30)
**Priority:** P3 · **Effort:** S, plus a baseline rerun · **Invariants:** #4
**Status:** Open. `Invoke-ClaudeProcess` passes no setting-source restriction (`run-agent-evals.ps1:1149`), so both arms load the
maintainer's user-level configuration; Copilot runs read `~/.copilot`. Restrict both (confirm `--setting-sources project,local` drops
user `CLAUDE.md`, skills, hooks), show a user canary absent, rerun a baseline. Take `tokensOut=` from `modelUsage`, not `result.usage`.

### B-331 · Add a Unity register-service eval scenario for field report #6
**Filed against:** v0.91.0 (2026-09-30)
**Priority:** P3 · **Effort:** M, about 3 USD live · **Invariants:** #4 #6
**Status:** Held until report #6's team replies (WSD-106 amends WSD-105 for this row). A synthetic .NET fixture registering through each
project's `IoCConfig.Configure(IUnityContainer)`, with an exemplar; pass = the registration lands there and no `IServiceCollection` or
`AddXxxServices` appears. B-216, closed by WSD-105, is unobserved since.

### B-336 · Measure whether agents work out a request premise the code contradicts when no project record names it
**Filed against:** v0.91.0 (2026-10-01)
**Priority:** P3 · **Effort:** S to measure, M if the rules change · **Invariants:** #1 #7
**Status:** Open; idle queue, measure first. An eval-measured consumer gap, not an attack finding: with no project record, A3 and A4
of the 2026-10-01 run (`meta/eval-results.md`) were 6/6 MISLEADING each, 11 of 12 having read `usp_LoadFactSales.sql`, which fills
`LoadRunId` from `BatchId` (probe: 12/12). WSD-107's reverted sentence did not help with a record; any candidate wording is measured first.

## Archived

B-219 and B-221 — see `meta/BACKLOG-DONE.md`.
B-225 and B-254 — see `meta/BACKLOG-DONE.md`.
