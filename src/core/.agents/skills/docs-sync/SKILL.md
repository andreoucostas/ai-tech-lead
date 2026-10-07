---
name: docs-sync
description: "Documentation drift check: cross-checks AGENTS.md, FRAMEWORK-CONTEXT.md, registers, and skills against the codebase and each other; reports drift, contradictions, and stale entries with proposed fixes. Read-mostly; safe to run anytime."
---

Read `AGENTS.md` and `.claude/commands/docs-sync.md`, then execute the docs-sync workflow defined there.

`.claude/commands/docs-sync.md` is the single source of truth. Follow it exactly — all six steps: check `AGENTS.md` against the codebase → check the `route-prompt` rails against the framework rules → check `LEARNINGS.md` → check `FRAMEWORK-CONTEXT.md` for drift → check `TECH_DEBT.md` against the codebase → present a structured drift report.

Do NOT apply changes automatically. Present the report and let the developer decide.

## Scope

Any text after `/docs-sync` narrows the sync to a specific section or area; with none, the sync covers everything. Use it wherever `.claude/commands/docs-sync.md` says `$ARGUMENTS`.
