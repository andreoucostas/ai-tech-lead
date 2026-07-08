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
- **Close with a Verification & confidence line** (calibration): in one or two lines, separate what you *actually verified by running it* (build / tests / lint — name which you ran) from what you are *asserting without having run it*, and call out anything you could not verify. "Looks correct" is not verification; a test you ran and watched pass is. This is deliberate — it counters the well-documented tendency to feel more done than the work is.

## Flag drift
At the end of your response, note if:
- A new pattern was introduced that should be documented in CLAUDE.md.
- A TECH_DEBT.md entry was resolved or a new one discovered.
- `.github/copilot-instructions.md` needs regeneration (run `/generate-copilot`).
