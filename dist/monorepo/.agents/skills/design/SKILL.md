---
name: design
description: "Design-only workflow: produce a design with at least two approaches, a recommendation, and open questions; persist larger specs to specs/<slug>.md. Writes NO code. Invoke when the user wants to think through an approach before implementing."
argument-hint: "[change to design]"
---

Read `AGENTS.md` (Repository Structure, Conventions, Architecture Decisions) and `.claude/commands/design.md`, then execute the design workflow defined there for the requirement below.

`.claude/commands/design.md` is the single source of truth. Follow it exactly: understand requirement → analyse impact → consider at least two approaches → recommend → surface open questions → output in the structured format → persist the spec to `specs/<slug>.md` for non-trivial features.

**DO NOT WRITE ANY SOURCE CODE.** This workflow produces a design document only — persisting it as `specs/<slug>.md` is expected; implementation code is not.

## Requirement

The requirement is the text after `/design`, or the change the developer asked to design. Use it wherever `.claude/commands/design.md` says `$ARGUMENTS`. If there is none, ask what to design.
