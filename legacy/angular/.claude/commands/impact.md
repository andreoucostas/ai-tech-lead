---
description: "Automated before/after A/B impact report contrasting the previous AI setup with this framework; runs the tests/impact harness in git worktrees. Developer-initiated only."
disable-model-invocation: true
---

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
- **AI-readiness disclosure (capability, not a gate):** the scorecard JSON now carries a `readiness` block — CI present, measured coverage % (or `null` = *not measured*, distinct from 0%), strictness flags, tests present. Surface it as a short "what the agent can safely do here" note, e.g. *coverage low/unmeasured → the agent will characterize before touching legacy code (add-tests Characterization mode); no CI → a pipeline can't be trusted to catch regressions, so reviewer rigour matters more.* **Never block on it** — a weak substrate is exactly where teams most need help; readiness calibrates caution, it does not deny service.

### 3. Behavioral A/B (Tier 2 — run this; skip only if the runner proves the CLI is absent)
- **Do not pre-judge whether the agent is installed with a single `command -v copilot`.** The user runs Copilot in VS Code and the Copilot CLI is usually an npm-global install that shows up as `copilot.cmd` on Windows (under `%APPDATA%\npm`), which a bare PATH check frequently misses. The runner below already probes the `.cmd`/`.exe` shims and npm-global dirs for you.
- **Run the inline smoke pass directly:**
  - Windows: `pwsh scripts/impact-run.ps1 <pre_ref> <post_ref> --smoke`
  - macOS/Linux/git-bash: `bash scripts/impact-run.sh <pre_ref> <post_ref> --smoke`
- **Interpret the exit code:** exit `3` means the runner genuinely could not find the Copilot CLI after all probes — only then skip Tier 2, and say so explicitly in the report (you still have Tier 1). Any other completion means Tier 2 ran. (The full statistical run uses more trials and belongs in CI — see the Bitbucket pipeline step.)
- If you want to confirm the CLI's flags first, run `copilot --help` (try `copilot.cmd --help` on Windows). If the non-interactive/print flag differs from `agent_cmd` in `tests/impact/config.json`, update `agent_cmd` to match the installed version — the one adaptation to do automatically, no user input. The runner's worktrees are short-pathed and set `core.longpaths` to survive Windows' 260-char limit.
- Aggregate `docs/impact/runs/**/*.json`: per task and overall, contrast **pre vs post** on acceptance rate, build-pass rate, anti-patterns-introduced (sum), and net LOC. Report the spread across trials, not a single number.
- **Calibration (predicted vs actual):** where a trial's response *claims* success ("tests pass", "this works", "done"), contrast that claim against the *measured* build-pass / anti-pattern outcome for the same trial. Report the gap between **claimed** and **measured** success per arm — this is the direct read on the perception gap (confident-but-wrong), and the number the framework's "Verification & confidence" line exists to shrink over time.

### 4. Write the report
- Write `docs/impact/IMPACT.md`: capability diff + scorecard deltas + A/B contrast + a "How to read this" section containing the honesty rules below.
- Render HTML: `bash scripts/build-architecture-html.sh docs/impact/IMPACT.md docs/impact/impact.html "AI Tech Lead Framework — Impact"`.
- Print the headline contrast.

## Honesty rules (include these in the report)
- The **capability diff** is real now. The **scorecard delta** is ~0 at adoption (no work has happened under the new framework yet) — it accrues at later reviews; re-run `/impact` then. The **A/B** is the immediate behavioral evidence.
- Same **model / tool / base commit** across both A/B arms, or the comparison is invalid — state which model was used; if you cannot confirm it was identical, flag it.
- LLM runs are **stochastic**: trials are a distribution. The inline smoke (1 trial) is illustrative; the CI run (more trials) is the evidence.
- **Correlation ≠ causation** — the audit log shows which changes were AI-assisted, not that every improvement is the framework's doing.
- **Confidence is not correctness** — a trial (or a developer) reporting "done/passing" is a *claim*, not evidence. Trust the measured build-pass / anti-pattern columns over any self-report; a wide claimed-vs-measured gap is the signal to tighten the Verification & confidence discipline, not to celebrate.
