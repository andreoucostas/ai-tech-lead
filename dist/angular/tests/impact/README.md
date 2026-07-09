# Impact harness

Measures the **before/after impact** of adopting this framework, fully automatically. Driven by the `/impact` workflow (run by `/adopt`, or standalone). The report lands in `docs/impact/IMPACT.md` (+ generated `impact.html`).

## Two tiers
- **Tier 1 — deterministic (always runs):** a capability diff (old setup in `docs/pre-adoption/` vs this framework) + a codebase scorecard (`scripts/metrics.*`), captured as a baseline at adoption and re-scanned later for the delta.
- **Tier 2 — behavioral A/B (needs a headless agent):** `scripts/impact-run.sh` runs each task in `tasks.json` through Copilot CLI **twice** — once in a git worktree at the pre-adoption commit (old framework), once post-adoption (this framework) — N trials each, capturing build / acceptance / anti-patterns per run. The only variable is the framework; model, tool, task, and base commit are held constant.

## Files
- `config.json` — `trials` (full/CI), `smoke_trials` (quick inline), `agent_cmd` (headless agent invocation; `/impact` adapts the flag to your installed CLI automatically).
- `tasks.json` — the fixed suite. Each task: a `prompt`, deterministic acceptance asserts (`asserts_match` / `asserts_no_match`), and an optional `build` gate. Tasks are additive/portable, so they run in any repo with no setup.

## Honesty
Stochastic — read trials as a distribution, not a single hero run. The capability diff is real at t=0; the scorecard delta accrues over time; the A/B is the immediate behavioral signal. **Same model in both arms or the result is meaningless.** See the generated `docs/impact/IMPACT.md`.

## Prereq
Copilot CLI installed and authenticated once. Without it, Tier 2 is skipped and you still get Tier 1.
