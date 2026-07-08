---
agent: agent
description: Generate the before/after impact report (capability diff + deterministic scorecard + Copilot-CLI behavioral A/B). Fully automated; no input required.
---

Read `.claude/commands/impact.md` in this repository and execute it exactly. It is the single source of truth for the impact workflow: capability diff (Tier 1) → deterministic scorecard (Tier 1) → behavioral A/B via the headless agent if available (Tier 2) → write `docs/impact/IMPACT.md` + `docs/impact/impact.html`.

No input is required — it discovers the pre-adoption ref, the archived old config, and the task suite itself. If Copilot CLI is not on PATH, it still produces the Tier-1 report and notes that the behavioral A/B was skipped.
