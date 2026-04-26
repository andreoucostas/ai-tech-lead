---
mode: agent
description: Find and fix tech debt in a specific area of this .NET codebase.
---

Read `CLAUDE.md`, `TECH_DEBT.md`, and `.claude/commands/debt.md`, then execute the debt workflow defined there for the area below.

`.claude/commands/debt.md` is the single source of truth. Follow it exactly: assess items in the area → for each, recommend "fix now" or "defer" → fix selected items (build + test + format after each) → update the register → Boy Scout → report.

If no area is given, summarise `TECH_DEBT.md` grouped by area and ask which to tackle.

## Area

${input:area:Which area of tech debt to tackle, or leave blank for a summary}
