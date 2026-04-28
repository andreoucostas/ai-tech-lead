# Shared workflow tail

> Inlined by `/feature`, `/fix`, `/refactor`, `/test`, and `/debt` via `@.claude/workflow.md`.
> Defines Self-review + Flag-drift — the steps that are identical across those commands.
> Boy Scout scope and stack-specific build/test/lint commands live in the calling command (because they vary: `/fix` scopes Boy Scout to blast radius, etc.).

## Self-review
Before presenting work as complete:
- Review all changes against CLAUDE.md > Conventions.
- Verify build, tests, and lint pass.
- New pattern introduced? → flag that CLAUDE.md may need updating.
- TECH_DEBT.md item resolved? → flag the entry for removal.
- Convention contradicted? → ask whether to update the convention or change the implementation.

## Flag drift
At the end of your response, note if:
- A new pattern was introduced that should be documented in CLAUDE.md.
- A TECH_DEBT.md entry was resolved or a new one discovered.
- `.github/copilot-instructions.md` needs regeneration (run `/generate-copilot`).
