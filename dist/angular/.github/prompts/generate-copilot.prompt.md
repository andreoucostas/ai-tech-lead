---
agent: agent
description: Regenerate the derived .github/copilot-instructions.md — a slim ≤80-line rule digest — from AGENTS.md.
---

Read `AGENTS.md` and `.claude/commands/generate-copilot.md` in this repository, then execute the workflow defined there.

`.claude/commands/generate-copilot.md` is the single source of truth. It regenerates **one** file from `AGENTS.md` plus the framework-generated `.github/instructions/framework-rules.instructions.md` carrier; never hand-edit the carrier:
- `.github/copilot-instructions.md` — slim ≤80-line ruleset for **inline editor completions**.

Hard rules for `copilot-instructions.md` (enforced by the canonical workflow):
- One imperative line per rule
- Total under 80 lines
- No Common Tasks, no Architecture Decisions, no Codebase Context, no rationale prose
- Conventions and Boy Scout (including the framework-owned bug-fix scope)

After writing, run `wc -l .github/copilot-instructions.md`. If over 80, condense further.
