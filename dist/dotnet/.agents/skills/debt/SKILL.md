---
name: debt
description: "Tech-debt workflow: match TECH_DEBT.md entries for an area, confirm each still exists in code, fix or defer with rationale, update the register. Invoke for debt-cleanup requests."
argument-hint: "[area or DEBT-ID]"
---

Read `AGENTS.md`, `TECH_DEBT.md`, and `.claude/commands/debt.md`, then execute the debt workflow defined there for the area below.

`.claude/commands/debt.md` is the single source of truth. Follow it exactly: assess items in the area → for each, recommend "fix now", "defer" or "Dismiss as not debt" → fix selected items (run the applicable repository-evidenced verification after each) → update the register → Boy Scout → report.

If no area is given, summarise `TECH_DEBT.md` grouped by area and ask which to tackle.

## Area

The area is the text after `/debt`, or the area or `DEBT-ID` the developer asked about. Use it wherever `.claude/commands/debt.md` says `$ARGUMENTS`.
