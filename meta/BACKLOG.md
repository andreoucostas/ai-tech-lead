# Framework backlog

Open work only, at most 40 entries (`AGENTS.md`, "Records"). Take the first unblocked row of the
pick-up order, one item per fresh session; the tier is read off the changed paths at work time. An
entry is its heading, filed-against line, priority line and at most three lines of status; the
evidence lives in the plans and decisions it names. An empty backlog says "No open entries." on its
own line under Open entries; the hygiene tests refuse that line beside an entry. A session that
finds an adjacent defect outside AGENTS.md's four guarded harms, which no field report raised,
closes it per WSD-106 with one CLOSED line in `meta/BACKLOG-DONE.md` instead of filing it here.
Full pre-reset text: `git show 36babcaf:meta/BACKLOG.md`.

## Pick-up order — ranked 2026-09-30 (WSD-105 probe); re-ranked 2026-10-01 (WSD-107, field replies); B-331 to the idle queue 2026-10-02 (WSD-109); B-346 filed and done the same day; B-330 done and B-336 closed by measurement 2026-10-03; idle queue added 2026-09-30 (WSD-106); every earlier entry closed 2026-09-29 (WSD-105)

| Rank | Item | Why here |
|---|---|---|
| 1 | B-326 | False-green class: the host steers `/security-review` to its built-in agent; both reporting teams use Copilot (2026-10-01) |
| 2 | B-337 | Field-triggered: both reporting teams use VS Code Copilot or Copilot CLI, and setup text sends them to Claude Code |
| 3 | B-327 | Idle queue. Guarded; on-demand `/bootstrap` text, though what it writes lands in the consumer's `AGENTS.md` |
| 4 | B-328 | Idle queue. Small and ordinary; the PR review step the Bitbucket Data Center target lacks |
| 5 | B-329 | Idle queue. Guarded; measure first, and stop if a template check cannot fit post-write's 45 s budget |
| 6 | B-331 | Idle queue. Measures WSD-109's retirement on Claude Code, about 3 USD live; report #6's `register-service` question is moot |

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

### B-331 · Measure WSD-109's recipe retirement: a Unity fixture through /bootstrap, and a feature-placement knockout
**Filed against:** v0.91.0 (2026-09-30); retargeted 2026-10-02 (WSD-109)
**Priority:** P3 · **Effort:** M, about 3 USD live plus three knockout trials · **Invariants:** #4 #6
**Status:** Open; report #6's reply no longer gates it. Three projects registering via `IoCConfig.Configure(IUnityContainer)`: does
`/bootstrap` draft a skill, and does a new service then land there without `IServiceCollection`? Plus three angular-feature-placement
trials without the seven (expected unchanged; `usedSkill=add-service` now always reads False).


## Archived

B-219 and B-221 — see `meta/BACKLOG-DONE.md`.
B-225 and B-254 — see `meta/BACKLOG-DONE.md`.
