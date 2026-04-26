---
mode: agent
description: Reason through the design of a change before writing any code. Produces a design document only.
---

Read `CLAUDE.md` (Repository Structure, Conventions, Architecture Decisions) and `.claude/commands/design.md`, then execute the design workflow defined there for the requirement below.

`.claude/commands/design.md` is the single source of truth. Follow it exactly: understand requirement → analyse impact → consider at least two approaches → recommend → surface open questions → output in the structured format.

**DO NOT WRITE ANY CODE.** This command produces a design document only.

## Requirement

${input:requirement:What are you trying to design?}
