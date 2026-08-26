# Bootstrap feedback: repeatability, preservation, routing, and Boy Scout — LOCKED

**Date:** 2026-08-26  
**Filed against:** v0.77.0  
**Status:** LOCKED after fresh-context Sol critique; required revisions folded below  
**Input:** senior-developer field feedback received 2026-08-25 and supplied by the maintainer

## Outcome sought

Make onboarding trustworthy on a mature repository without treating one model sample as project
truth, displacing authoritative documentation, resurrecting rejected debt, or turning always-loaded
Boy Scout guidance into a second issue tracker. Fix the directly reproduced routing false positive.
Keep broader router retirement and permanent Codex-evaluator work with their existing owners.

The report is issue intake, not proof of every proposed remedy. Statements below are labelled by
their evidence source: reproduced tree behaviour, attributed report, or experiment hypothesis.

## What the current tree establishes

1. **Bootstrap is one sample per analysis pass.** It has no repeated discovery, convergence, or
   independent verification stage. This proves the mechanism, not the reported variance magnitude.
2. **Dismissed debt has no durable memory.** Active items are deleted when resolved; neither
   bootstrap nor rebootstrap has a reviewed-false-positive resurrection guard.
3. **Adopt moves mature documentation.** It inventories `docs/architecture/**`, `docs/adr/**`, and
   `docs/decisions/**`, archives approved files, and reconstructs framework-shaped summaries. That
   can break original paths and links even though archived bytes remain recoverable.
4. **Bootstrap and rebootstrap derive Boy Scout priorities from current debt.** This duplicates
   finite work between `TECH_DEBT.md` and always-loaded guidance.
5. **The exact debt-question routing defect is deterministic.** Both hook twins route
   `Why is this tech debt?` as debt cleanup because the answer-only escape excludes `debt`.
6. **Exclusive-classifier retirement is already owned.** `meta/overlap-watch.md` rows 3 and 13
   duplicate the same B-44 rule; B-159 owns natural-language review fan-out, B-140 owns any permanent
   Codex executor, and B-177 owns completion gating.

## Decisions

### D1 — Three runs describe stability; they do not vote on truth

For the bootstrap repeatability baseline, run three fresh Sol sessions against independently
writable, byte-identical copies of one mature documented fixture. Normalise candidate identity with
a frozen rubric: same claimed problem, same consequence, and overlapping affected scope. If any
dimension is ambiguous, keep the candidates separate.

Build one blinded candidate pool from all three runs plus planted known-positive and known-negative
claims. A fresh verifier checks the pool against repository evidence. Publishable candidates are
those verified from evidence; `Observed: n/3` is descriptive stability metadata, never severity or
a truth threshold. Call the comparison **discovered-pool coverage**, not recall: an issue missed by
all runs is unknowable from this experiment.

Do not ship three discoveries per bootstrap by default merely because outputs vary. It earns its
cost only if the experiment finds materially correct candidates that one-shot repeatedly loses, or
material false positives that verification removes and cheaper controls cannot address.

### D2 — Add dismissed-proposal memory, not a four-state debt lifecycle

Keep current `DEBT-NNN` blocks active and keep resolved-item deletion. Add a compact
`Dismissed proposals — do not re-propose without changed evidence` section to `TECH_DEBT.md`. Each
record contains a stable readable key (`<area>::<claim-slug>`), affected paths/symbols, evidence
reviewed, dismissal date, and reason.

`/debt`, bootstrap, and rebootstrap must read this registry before proposing debt. A matching claim
is suppressed. If materially changed evidence contradicts the dismissal, the workflow may propose a
new active item only when it names that new evidence and preserves the old dismissal record. Reuse
the declined-recipe resurrection-guard semantics; do not introduce `Accepted` or retained `Resolved`
states until field evidence needs them.

Experiment this as a sequence, not a repeated clean bootstrap: bootstrap -> record one planted
dismissal -> rebootstrap unchanged -> change the cited evidence -> rebootstrap. Expected outcomes
are suppressed, suppressed, then explicitly reopened with the changed evidence named.

### D3 — Amend WSD-014 narrowly: screen clean mature architecture docs in place

Treat existing mature architecture documents as project-owned, in-place screen candidates. Run the
same provenance and adversarial-content checks used by adoption. Clean documents retain original
paths and bytes; adoption indexes/references them and reports only concrete gaps, contradictions,
dead references, or missing framework-required fields.

Path A remains intact for unsafe or ambiguous content: quarantine/archival and human-approved merge
proposals still apply. If several documents claim to be the authoritative index, require a human to
choose; do not invent a canonical winner. Existing framework ADR production continues to append to
`docs/architecture-decisions.md`; this increment does not redirect every ADR producer. The change is
only that clean pre-existing ADR/architecture trees are not moved or re-derived.

The fixture must include relative links, multiple clean ADRs, one flagged document, and an ambiguous
second index. Grade original paths, byte identity, link resolution, ownership, quarantine behaviour,
and the human-decision boundary.

### D4 — Boy Scout is the stable practice filter, not generated work

Remove the bootstrap/rebootstrap instructions that derive Boy Scout priorities from current debt.
Preserve the shipped stable, low-risk touched-file practices. Finite findings remain in
`TECH_DEBT.md` or the team's external tracker. Do not build Jira integration or a subjective practice
classifier for this fix.

### D5 — Fix the debt-question escape; keep router retirement host-correct

Extend the answer-only carve-out to `debt` in both hook twins and add the reporter's exact question
as a red-then-green regression on Claude- and Copilot-shaped events. Preserve the security overlay
and Copilot Boy Scout queue composition.

Do not use Sol to retire Claude/Copilot hook classification: Codex does not execute that hook, so it
cannot measure the routed consumer surface. Reconcile duplicate overlap-watch rows as bookkeeping.
The broader ablation remains B-44/B-159 work on a supported host using typed events where ordering or
fan-out is the outcome. The retirement unit is keyword workflow-classification output, not the
single composed hook that still delivers security and queued Boy Scout context.

## Execution sequence and ownership

1. Record the attributed field report and four new scoped backlog entries.
2. Run the current three-trial Sol bootstrap baseline before changing discovery output. This is an
   explicitly carrier-level final-artifact experiment; it cannot certify Claude/Copilot dispatch or
   close B-177's supported-host observation by itself.
3. Ship the focused D5 routing correction and D4 Boy Scout correction with red proof.
4. Implement D2 against the dismissal sequence fixture.
5. Implement D3 against the mature-doc adoption fixture and append the narrow WSD-014 amendment.
6. Complete B-177's deterministic completion gating in its existing scope. Sol may exercise final
   artifacts programmatically; any unobserved supported-host leg is reported, never inferred.
7. Repeat only the experiment whose mechanism changed. Ship multi-sample discovery only if D1's
   proportionality threshold is met.

| Scope | Owner |
|---|---|
| bootstrap/generate completion gating | existing B-177 |
| permanent Codex executor | existing B-140 follow-on; not authorized here |
| review prompt without “review” | existing B-159 typed-event experiment |
| router retirement | B-44 / overlap watch; supported-host experiment |
| debt-question escape | new scoped item |
| dismissed-proposal memory | new scoped item |
| mature-doc screen-in-place | new scoped item + narrow WSD-014 amendment |
| debt-derived Boy Scout removal | new scoped item |

## Pre-registered measures

### Repeatability fixture

| Measure | Recording / decision use |
|---|---|
| final docs-sync | `PASS`, `ARTIFACT-FAILED`, or `CANT-EXAMINE`; never infer from agent prose |
| verified precision | verifier-accepted / published candidates |
| discovered-pool coverage | verified pool candidates represented per run and by the three-run union |
| stability | per-candidate `n/3`, descriptive only |
| candidate identity | frozen three-part rubric; ambiguity stays separate |
| time and usage | wall time plus available host usage; `cost unavailable` is valid |
| execution outcome | distinguish `RUN-FAILED`, `TIMEOUT`, `MODEL/HOST-MISMATCH`, `ARTIFACT-FAILED`, `CANT-EXAMINE` |

The verifier receives a planted positive, planted negative, and inaccessible-evidence case before
its counts are accepted. Raw outcomes remain visible; no majority vote hides one run.

### Dismissal fixture

- unchanged dismissed claim re-proposed: target zero;
- changed-evidence reopening without naming the delta: target zero;
- changed-evidence reopening with exact delta: target one.

### Mature-doc fixture

- clean document moves or byte changes: target zero;
- clean relative-link breakage: target zero;
- flagged document allowed into canonical guidance: target zero;
- ambiguous authority auto-selected: target zero;
- concrete gap report: required.

## Proportionality

The direct defects have small adequate fixes: one answer-only escape, removal of two debt-derived
Boy Scout instructions, a narrow dismissal registry, and screen-in-place handling for mature docs.
They do not require permanent multi-agent orchestration. Three full discoveries plus a verifier can
multiply the product's most expensive workflow, so it remains an experiment until it demonstrates
material correctness value beyond those controls.

## Safety and evidence boundaries

- Raw consumer repositories, paths, domain vocabulary, and transcripts remain outside this repo.
- Trials use byte-identical, remote-less copies with no answer-bearing history.
- No trial may deploy, migrate, publish, or contact a consumer system.
- “Sol ran it” is not completion evidence; deterministic checks and artifact graders decide.
- Three runs describe variance, not statistical significance.
- Router and supported-host claims cannot be generalized from a Codex carrier.

## Critique findings folded

Fresh-context `gpt-5.6-sol` critique on 2026-08-26 returned **REVISE**. This revision removes the
unauthorized Codex executor, splits three previously unreachable measures into separate fixtures,
renames the false recall metric, defines candidate identity and failure states, preserves hook
composition, narrows debt state to dismissed-proposal memory, explicitly amends WSD-014, and reduces
Boy Scout work to deletion of debt-derived augmentation. The critic reproduced the debt-question
failure on both twins. Same-tier critique satisfies the fresh-context design challenge but is not a
qualifying independent release review.

## Definition of done

- Feedback is recorded with attribution and epistemic status.
- Each new scope has one owner; B-140, B-159, B-177, and B-44 are not duplicated.
- Hook changes have observed red and green results on PowerShell and bash twins.
- Workflow changes are composed to all distributions and pass validators plus install smoke.
- Live experiment results record every run and distinguish artifact failure from inability to run.
- A qualifying independent release review occurs, or the mandated post-ship review is filed without
  mislabelling same-tier Sol critique as independent approval.
