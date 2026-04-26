---
mode: agent
description: Adopt this .NET repo into the AI Tech Lead Framework — discovers existing AI artifacts (Cursor, Copilot, Aider, Continue, generic docs) and merges them into our canonical structure without losing work.
---

Read `.claude/commands/adopt.md` in this repository, then execute the adoption workflow defined there.

`.claude/commands/adopt.md` is the single source of truth. Follow it exactly: pre-flight (clean git, branch recommendation) → discovery (scan for `.cursorrules`, `.cursor/rules/*`, `AGENTS.md`, `GEMINI.md`, `.windsurfrules`, Aider/Continue config, generic `ARCHITECTURE.md`/`CODEMAP.md`/`docs/adr/*`/`TODO.md`/`TECH_DEBT.md`, etc.) → present plan → archive originals to `docs/pre-adoption/` → interactive merge into `CLAUDE.md` and `TECH_DEBT.md` → optionally adopt custom commands → run `/bootstrap` to fill gaps → final report.

**Critical**: never delete content. Always archive originals first. Show each merge to the user before applying.

Use this when the repo already has *some* AI tooling or documentation. If the repo has nothing AI-related yet, run `/bootstrap` directly instead.

## Notes

${input:notes:Optional — anything specific about the existing setup the adoption should know}
