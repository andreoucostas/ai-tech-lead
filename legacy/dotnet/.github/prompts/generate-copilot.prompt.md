---
mode: agent
description: Regenerate .github/copilot-instructions.md from CLAUDE.md as a slim ≤80-line ruleset for Copilot inline completions.
---

Read `CLAUDE.md` and `.claude/commands/generate-copilot.md` in this repository, then execute the workflow defined there.

`.claude/commands/generate-copilot.md` is the single source of truth. The output is **not** a duplicate of CLAUDE.md — Copilot's coding agent reads CLAUDE.md directly. This file is scoped to **inline editor completions only**, where context budget is tight.

Hard rules (enforced by the canonical workflow):
- One imperative line per rule
- Total under 80 lines
- No Common Tasks, no Architecture Decisions, no Codebase Context, no rationale prose
- Conventions and Boy Scout (always-apply items only)

After writing, run `wc -l .github/copilot-instructions.md`. If over 80, condense further.
