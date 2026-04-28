---
mode: agent
description: Cross-check all documentation against the codebase and between instruction files. Reports drift.
---

Read `CLAUDE.md` and `.claude/commands/docs-sync.md`, then execute the docs-sync workflow defined there.

`.claude/commands/docs-sync.md` is the single source of truth. Follow it exactly: check `CLAUDE.md` against the codebase → check `copilot-instructions.md` against `CLAUDE.md` → check `LEARNINGS.md` → check `TECH_DEBT.md` against the codebase → present a structured drift report.

Do NOT apply changes automatically. Present the report and let the developer decide.

## Scope

${input:scope:Optional — narrow the sync to a specific section or area}
