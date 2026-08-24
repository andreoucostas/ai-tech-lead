---
agent: agent
description: One-time bootstrap — analyse this repository, selecting the Angular profile only when repository evidence supports it, then populate CLAUDE.md, TECH_DEBT.md, AGENTS.md, and copilot-instructions.md.
---

Read `.claude/commands/bootstrap.md` in this repository, then execute the bootstrap workflow defined there.

`.claude/commands/bootstrap.md` is the single source of truth. Follow it exactly: evidence-based profile and command discovery → Angular analysis passes (A1–A7) only when applicable → synthesis into priority tiers → clarify gate → generate artifacts (including the **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation** `CLAUDE.md > Conventions > Verification Commands` inventory from observed evidence) → final report with diff summary.

Run the full pipeline. The only pauses are the ones the workflow defines (Phase 2b clarifying questions, Phase 3d-bis hazard confirmation) — do not add others. Remind the user at the end to verify the generated `CLAUDE.md > Conventions` section — it drives everything else.

## Notes

${input:notes:Optional — anything specific about this codebase the bootstrap should know}
