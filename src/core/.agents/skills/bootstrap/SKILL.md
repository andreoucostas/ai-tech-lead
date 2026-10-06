---
name: bootstrap
<!-- @stack:desc -->
disable-model-invocation: true
---

Read `.claude/commands/bootstrap.md` in this repository, then execute the bootstrap workflow defined there.

<!-- @stack:summary -->

Run the full pipeline. The only pauses are the ones the workflow defines (Phase 2b clarifying questions, Phase 3d-bis hazard confirmation) — do not add others. Remind the user at the end to verify the generated `AGENTS.md > Conventions` section — it drives everything else.

## Notes

The notes are the text after `/bootstrap`: anything specific about this codebase the bootstrap should know. Use them wherever `.claude/commands/bootstrap.md` says `$ARGUMENTS`; there may be none.
