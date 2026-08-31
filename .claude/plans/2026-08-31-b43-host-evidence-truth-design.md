# B-43 host-evidence truth repair — locked design

**Locked:** 2026-08-31, after reading `meta/decisions-index.md`, WSD-062, the active claims,
host ledger, persisted canaries, legacy release evidence, and adversarial premise/design critique.

## Proportionality and outcome

The observed harm is a current consumer assurance that attributes the complete Copilot Boy Scout
chain to a live-tested `agentStop` path even though that event has never been observed firing here,
plus generic compatibility wording that lets dated evidence for one capability imply evidence for
others. The smallest repair is prose and evidence-ledger reconciliation. It does not spend provider
credits, add a canary, add a test result, or retain a calendar obligation whose B-49 execution
vehicle is invalid under WSD-062.

The frozen outcome is:

> A host-dependent lifecycle is described as observed only at the capability and dated host/version
> actually observed. Direct fixtures prove output shape, not host consumption. Re-certification is
> evidence-triggered: it precedes any stronger claim and follows contrary evidence or a host-facing
> mechanism change when the result could change a decision.

## Frozen authored scope

1. `src/core/docs/enforcement-surfaces.md`
   - retain the dated Copilot CLI `userPromptSubmitted`, `preToolUse`, and `postToolUse` observations;
   - downgrade the unobserved `agentStop -> queue -> next userPromptSubmitted` chain from guaranteed
     to registered/vendor-documented mechanics whose end-to-end turn-end firing is unverified;
   - retain the narrow historical 2026-06-25 VS Code Preview-hook `PreToolUse` denial observation,
     explicitly with host/extension versions unrecorded and therefore not current certification;
   - keep native `.github/instructions/` delivery separate from Preview-hook lifecycle evidence;
   - describe every other VS Code Preview-hook lifecycle as unverified.
2. The three authored stack READMEs: reconcile each UserPromptSubmit, Stop/agentStop, and generic
   hook-compatibility statement. A generic CLI date must not blanket-certify the Stop path, and the
   historical VS Code guard observation must not blanket-certify its lifecycle.
3. `src/core/.github/hooks/hooks.json`: keep the registration and advisory queue design, but stop
   stating unobserved `agentStop` firing as an observed fact.
4. `meta/host-certification.md`: add capability-specific rows for the historical VS Code guard
   observation, unverified VS Code prompt/post-tool/Stop paths, and unverified Copilot CLI
   `agentStop`/queue firing. State the evidence boundary and three-arm standard.
5. `meta/canaries/agent-stop-delivery/README.md`: retain UNRUN, mark the current kit non-certifying,
   and record that environment-only token secrecy is not a valid no-leak control for a tool-enabled
   model.
6. `meta/canaries/b52-copilot-two-hook/README.md`: correct the status to the four dated
   CLI 1.0.79/1.0.80 runs and the observed last-entry-only result; retain old instructions only as
   historical design, not pending work.
7. `.claude/hooks/tests/VendorClaims.Tests.ps1`: reconcile only stale claim/provenance literals; do
   not invent a prose-inference gate.
8. Replace B-43's quarterly cadence with a standing evidence-triggered decision, index it, correct
   B-49's claim that it executes B-43, close B-43 with an RCA, and add normal root/three consumer
   changelog entries. Generate `dist/` only through composition.

## Explicit exclusions

No live provider run, new or rewritten canary, `DEVELOPING.md` checklist, hook behavior change,
new gate, new recurring backlog item, blanket host downgrade, or rewrite of historical release
evidence. B-49 remains open only for a freshly re-locked live-fire objective. B-97's native
instruction observation proves no Preview-hook lifecycle.

## Success and review contract

- Current claims can be mapped one-to-one to capability-specific evidence rows or say unverified.
- The 2026-06-25 VS Code guard observation remains dated and narrow; unknown versions remain unknown.
- No current text calls the Copilot Boy Scout chain guaranteed.
- The three READMEs remain semantically aligned without asserting identical evidence across surfaces.
- This change has its own immutable commit/range and artifact-by-artifact scope review, separate from
  B-174. Static Claude context must not grow; WSD-055 needs no displacement because no always-loaded
  rule is added.

## RCA boundary

Existing gates compare mirrors, schemas, and a small denylist of claims that became false. None binds
each assurance phrase to a capability-specific dated live-host row, so repetition preserved the
unsupported inference consistently. The exposed class is every host-dependent claim copied among
the enforcement matrix, READMEs, hook comments, host ledger, and persisted canary status.
