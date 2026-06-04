Produce a before/after **impact report** contrasting the previous AI setup with this framework. Fully automated — needs no input from the user.

## When this runs
- Automatically at the end of `/adopt` (which first tagged the pre-adoption commit and captured a metrics baseline **before** any changes).
- Standalone, any time, to refresh the report.

## What it finds itself (no prompts)
- **Pre-adoption ref**: read `.claude/impact-baseline.ref` (written by `/adopt`). Fallback: a `pre-adoption` git tag; else the commit immediately before the adoption commit.
- **Old config**: `docs/pre-adoption/` (archived by `/adopt`).
- **Current**: `HEAD`.

## Steps

### 1. Capability diff (Tier 1 — always)
Compare the old setup (`docs/pre-adoption/` + the pre-adoption ref) with the installed framework. Emit a Before-vs-After matrix that **names the OLD setup's specific gaps**, across: source of truth, verification rules, determinism/hooks, drift control, security review, SOLID/Leanness, AI-change traceability (audit log), tool coverage.

### 2. Deterministic scorecard (Tier 1 — always)
- **Baseline**: if `docs/impact/baseline.json` exists (captured by `/adopt`), use it. Else compute it from the pre-adoption ref via a throwaway worktree: `git worktree add --detach <wt> <pre_ref>` → `bash scripts/metrics.sh` inside `<wt>` → `git worktree remove --force <wt>`.
- **Now**: `bash scripts/metrics.sh` on `HEAD`.
- Table each metric **Before → Now (Δ)**. Add the `TECH_DEBT.md` item count and the `.claude/ai-audit.log` line count (AI-change traceability).

### 3. Behavioral A/B (Tier 2 — if a headless agent is available)
- Read `tests/impact/config.json` → `agent_cmd` (default `copilot`). If the agent binary is **not** on PATH, **skip Tier 2** and say so in the report (you still have Tier 1).
- Make it run unattended: run `<agent> --help`; if the non-interactive/print flag differs from the configured one, update `agent_cmd` to match the installed CLI version. This is the one adaptation to do automatically — no user input.
- Run the inline smoke pass: `bash scripts/impact-run.sh <pre_ref> <post_ref> --smoke`. (The full statistical run uses more trials and belongs in CI — see the Bitbucket pipeline step.)
- Aggregate `docs/impact/runs/**/*.json`: per task and overall, contrast **pre vs post** on acceptance rate, build-pass rate, anti-patterns-introduced (sum), and net LOC. Report the spread across trials, not a single number.

### 4. Write the report
- Write `docs/impact/IMPACT.md`: capability diff + scorecard deltas + A/B contrast + a "How to read this" section containing the honesty rules below.
- Render HTML: `bash scripts/build-architecture-html.sh docs/impact/IMPACT.md docs/impact/impact.html "AI Tech Lead Framework — Impact"`.
- Print the headline contrast.

## Honesty rules (include these in the report)
- The **capability diff** is real now. The **scorecard delta** is ~0 at adoption (no work has happened under the new framework yet) — it accrues at later reviews; re-run `/impact` then. The **A/B** is the immediate behavioral evidence.
- Same **model / tool / base commit** across both A/B arms, or the comparison is invalid — state which model was used; if you cannot confirm it was identical, flag it.
- LLM runs are **stochastic**: trials are a distribution. The inline smoke (1 trial) is illustrative; the CI run (more trials) is the evidence.
- **Correlation ≠ causation** — the audit log shows which changes were AI-assisted, not that every improvement is the framework's doing.
