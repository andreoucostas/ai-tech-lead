---
name: bootstrap
description: "One-time framework setup: evidence-select an Angular profile, run its analysis passes, then populate project setup artifacts and report bounded repository-knowledge discovery. Developer-initiated only."
disable-model-invocation: true
---

Read `.claude/commands/bootstrap.md` in this repository, then execute the bootstrap workflow defined there.

`.claude/commands/bootstrap.md` is the single source of truth. Follow it exactly: evidence-based profile and command discovery → Angular analysis passes (A1–A7) only when applicable → synthesis into priority tiers → clarify gate → generate artifacts (including the **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation** `AGENTS.md > Conventions > Verification Commands` inventory from observed evidence) → final report with diff summary.

Run the full pipeline. The only pauses are the ones the workflow defines (Phase 2b clarifying questions, Phase 3d-bis hazard confirmation) — do not add others. Remind the user at the end to verify the generated `AGENTS.md > Conventions` section — it drives everything else.

## Notes

The notes are the text after `/bootstrap`: anything specific about this codebase the bootstrap should know. Use them wherever `.claude/commands/bootstrap.md` says `$ARGUMENTS`; there may be none.
