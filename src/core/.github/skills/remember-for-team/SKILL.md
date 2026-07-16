---
name: remember-for-team
description: >
  USE FOR: drafting a durable team gotcha, context fact, recipe claim, or failed approach for PR review.
  DO NOT USE FOR: secrets, delivery debt, security findings, architecture decisions, repo-wide conventions, or risky-module hazards.
---

# Remember for the team

1. **Triage and redirect before writing.** Never store a secret. Put delivery debt in `TECH_DEBT.md`; security findings in `SECURITY_FINDINGS.md`; hard-to-reverse decisions through `create-adr`; propose a `CLAUDE.md` edit for a repo-wide convention; put a risky-module hazard in the `FRAMEWORK-CONTEXT.md` hazard table. Only anything else becomes a wiki entry.
2. **Deduplicate before creating.** Grep `docs/wiki/INDEX.md` and existing entries for key terms. Update a near-match instead of creating another entry. Bump `last-verified` only after executing that entry's own **Verify by** step and stating the observed result. Without re-verification, set `status: suspected` and do not bump the date.
3. **Draft from `docs/wiki/_template.md`.** Write factual claims only, with mandatory **Evidence** and **Verify by** lines. Do not use imperatives such as "always run X" in the body.
4. **Index it.** Insert `- [type] [slug](./slug.md) — description` at the correct sorted slug position in `docs/wiki/INDEX.md`. The check sorts by plain byte order (ASCII/ordinal), so `-` sorts before digits and letters — e.g. `a-c` comes before `ab`.
5. **Close honestly.** Say the entry is a draft until PR review; never claim it was "saved to team memory."
