---
agent: agent
description: One-time bootstrap — select evidenced .NET and/or warehouse-SQL profiles, analyse the repository, and populate AGENTS.md and TECH_DEBT.md.
---

Read `.claude/commands/bootstrap.md` in this repository, then execute the bootstrap workflow defined there.

`.claude/commands/bootstrap.md` is the single source of truth. Follow it exactly: Git-root pre-flight and evidenced profile selection (.NET and/or warehouse-SQL) → applicable parallel analysis passes → synthesis into priority tiers → clarify gate → generate artifacts (`AGENTS.md`, `TECH_DEBT.md`, `FRAMEWORK-CONTEXT.md` drafts) → final report with diff summary. Record **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation** commands only when repository evidence names them; otherwise record **not available**.

Run the full pipeline. The only pauses are the ones the workflow defines (Phase 2b clarifying questions, Phase 3d-bis hazard confirmation) — do not add others. Remind the user at the end to verify the generated `AGENTS.md > Conventions` section — it drives everything else.

## Notes

${input:notes:Optional — anything specific about this codebase the bootstrap should know}
