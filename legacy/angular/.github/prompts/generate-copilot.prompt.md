---
agent: agent
description: Regenerate the agent-facing derived files from CLAUDE.md — a slim ≤80-line copilot-instructions.md (inline completions) and the full AGENTS.md mirror (Copilot agent mode / Codex / Cursor) — then sync the skills mirror.
---

Read `CLAUDE.md` and `.claude/commands/generate-copilot.md` in this repository, then execute the workflow defined there.

`.claude/commands/generate-copilot.md` is the single source of truth. It regenerates **two** files from CLAUDE.md (which stays canonical):
- `.github/copilot-instructions.md` — slim ≤80-line ruleset for **inline editor completions**.
- `AGENTS.md` — full mirror of CLAUDE.md's portable rules for **AGENTS.md-native tools** (Copilot agent mode & CLI, Codex, Cursor, Gemini, Aider) — the real ruleset, not a pointer.

Then run `scripts/sync-agent-files.sh` (or `.ps1`) to mirror `.claude/skills/` → `.github/skills/`.

Hard rules for `copilot-instructions.md` (enforced by the canonical workflow):
- One imperative line per rule
- Total under 80 lines
- No Common Tasks, no Architecture Decisions, no Codebase Context, no rationale prose
- Conventions and Boy Scout (always-apply items only)

After writing, run `wc -l .github/copilot-instructions.md`. If over 80, condense further. Verify `AGENTS.md` starts with the `GENERATED FILE` banner and contains the Verification Rules / Leanness / Boy Scout / Agentic Workflow sections.
