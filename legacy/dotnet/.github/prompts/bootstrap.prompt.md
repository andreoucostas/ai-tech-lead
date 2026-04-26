---
mode: agent
description: One-time bootstrap — analyse this .NET codebase and populate CLAUDE.md, TECH_DEBT.md, AGENTS.md, and copilot-instructions.md.
---

Read `.claude/commands/bootstrap.md` in this repository, then execute the bootstrap workflow defined there.

`.claude/commands/bootstrap.md` is the single source of truth. Follow it exactly: pre-flight checks → six analysis passes (A1–A6) → synthesis into priority tiers → generate artifacts (`CLAUDE.md`, `TECH_DEBT.md`, `AGENTS.md`, `.github/copilot-instructions.md`) → final report with diff summary.

Run the full pipeline. Do not ask for confirmation between phases. Remind the user at the end to review the generated `CLAUDE.md` before using any other commands — it drives everything else.

## Notes

${input:notes:Optional — anything specific about this codebase the bootstrap should know}
