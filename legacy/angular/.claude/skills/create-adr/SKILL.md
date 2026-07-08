---
name: create-adr
description: >
  Use when the user makes (or wants to record) a significant, hard-to-reverse architecture or
  design decision — choosing a state-management approach, a library, a module boundary, a routing
  strategy, a trade-off. Appends the full ADR to docs/architecture-decisions.md and adds a one-line
  index entry to CLAUDE.md.
  USE FOR: "record this decision", "write an ADR", capturing why an approach was chosen over
  alternatives, documenting an accidental decision that has become convention.
  DO NOT USE FOR: routine implementation choices with no lasting consequence, or feature specs
  (those go to specs/<slug>.md via /design).
---

# Record an architecture decision

Full ADRs live in **`docs/architecture-decisions.md`** (append-only, loaded on demand). `CLAUDE.md > Architecture Decisions` holds only a **one-line index** that points into it.

**Why split:** `CLAUDE.md` loads on nearly every agent turn and anchors the prompt-cache prefix. Pasting full ADRs into it would grow the always-loaded base *and* bust the cache on every write. Keeping the detail in a separate file keeps CLAUDE.md small and the cache warm. (When `/adopt` ingests external ADR files, it can land them here too.)

1. Confirm the decision is **significant**: it constrains future work, is costly to reverse, or resolves a recurring debate. If it's a routine choice, don't write an ADR — note it in the PR and move on (Leanness: no ceremony).

2. Append the full ADR to `docs/architecture-decisions.md` (create the file with an `# Architecture Decisions` heading if it doesn't exist). Use the next free `ADR-NNN`:

   ```markdown
   ## ADR-NNN: <short decision title>
   - **Date**: <YYYY-MM-DD>
   - **Status**: Accepted | Superseded by ADR-MMM
   - **Decision**: what we will do, stated as a directive.
   - **Context**: the forces and constraints that made this necessary.
   - **Alternatives considered**: each option + why it was rejected (1 line each).
   - **Consequences**: what this makes easier, what it makes harder, what to watch for.
   ```

3. Add a **one-line index entry** to `CLAUDE.md > Architecture Decisions` (do **not** paste the full ADR there):

   ```markdown
   - ADR-NNN — <short title> — <YYYY-MM-DD> ([details](./docs/architecture-decisions.md))
   ```

4. If this decision **supersedes** an earlier one, set the old ADR's `Status: Superseded by ADR-NNN` in `docs/architecture-decisions.md` and leave its index line (history is the point) — do not delete.

5. If it introduces or changes a coding convention, also update `CLAUDE.md > Conventions` and flag that `/generate-copilot` should be re-run to refresh `copilot-instructions.md` and `AGENTS.md`.
