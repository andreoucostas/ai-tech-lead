# B-158(b) — static-context ceiling review

**Date:** 2026-08-29
**Filed against:** v0.63.0; reviewed at v0.78.3
**Status:** LOCKED after premise audit and adversarial self-review

## Premise audit

B-158 had two separable obligations. Part (a) is already shipped: commit `c8aa1bc` made both
`context-footprint` twins print remaining headroom on every run, so authors no longer discover the
limit only when a release refuses. Part (b) remains unanswered: decide whether the hard Claude
static-context ceilings are still 40,000 bytes for a single stack and 48,000 for monorepo.

The question is still live, but the filed measurements are stale. The v0.78.3 baseline is:

| distribution | measured | ceiling | remaining |
|---|---:|---:|---:|
| dotnet | 39,582 | 40,000 | 418 (1.04%) |
| angular | 38,105 | 40,000 | 1,895 (4.74%) |
| monorepo | 47,098 | 48,000 | 902 (1.88%) |

WSD-017 introduced these ceilings when the corresponding totals were 34,605, 33,951, and 41,443.
The initial values therefore supplied roughly 16% growth room. That was an initial margin around a
judgment-based recurring-cost limit, not a contract to restore 16% free space whenever the framework
grows. B-110 later made the limits blocking precisely so growth would force an explicit trade.

## Decision

Retain 40,000/48,000. Treat them as maximum budgets for stable, always-loaded Claude context—not as
proxies for any current model's maximum context window and not as minimum-headroom targets.

Future static additions must normally be funded by a named retirement, consolidation, or smaller
replacement in the same distribution. A separate ceiling review may raise a limit only with new
decision-relevant evidence: for example, an observed material behavior benefit that cannot be kept
within the budget after reasonable displacement, or measured recurring-cost/salience evidence that
changes the original trade. The review and any payload that wants the space remain separate changes.
Nearness to the ceiling, framework age, or a larger host context window is not by itself that
evidence.

This resolves the decision dependency for B-96, B-99, B-133, and B-136. It does not grant them new
space: each must now name and validate its displacement or remain unimplemented.

## Alternatives weighed

1. **Raise now to restore roughly 16% headroom (about 47k/56k).** This would make additions easy and
   resemble the margin at inception. Rejected: it converts a one-time design margin into a ratchet,
   adds recurring prompt cost before any payload has shown benefit, and erases the prioritization
   signal at the exact moment the gate is doing its job.
2. **Retain 40k/48k and require displacement.** Selected. It keeps a stable cross-host governance
   boundary and forces new always-loaded material to outrank existing material. Its real cost is
   editorial work and the possibility that a useful addition cannot fit; that is the evidence a
   later independent review would need rather than an assumption made in advance.
3. **Replace absolute ceilings with percentages, growth deltas, or per-model limits.** Rejected.
   Model capacity and host configuration are moving dependencies, while the measured cost is paid
   repeatedly and the distributions must remain deterministic across hosts. A growth-only gate also
   blesses whatever accumulated before its baseline.
4. **Lower the ceilings or immediately compress enough to restore the original margin.** Rejected.
   No observed adherence or cost harm supports removing current rails, and WSD-017 deliberately
   preferred salience over byte minimization. Compression without a competing, evidenced payload is
   churn rather than prioritization.

## Adversarial review findings folded

- **“The models are larger now.”** Capacity is not the governed quantity. Larger windows do not make
  repeated input free, improve instruction salience, or prove that another permanent rule helps.
- **“Only hundreds of bytes remain, so releases will become emergencies.”** Part (a) removed the
  surprise: every authoring run now prints exact headroom. A refusal is an intended design decision,
  not an operational emergency.
- **“The original design intended 16% headroom.”** WSD-017 fixed absolute limits, not a percentage.
  Replenishing the margin after every addition would mean there was never a limit.
- **“Replacement pressure may shorten safety rails until they fail.”** Net-zero is a constraint, not
  permission for blind compression. A candidate must preserve the displaced rule's behavior or show
  that the old material is obsolete; otherwise it does not ship and can bring independent evidence
  to a later ceiling review.
- **“Current totals already vary and once exceeded these limits during v0.78.0.”** That event is
  positive evidence for retaining the gate: the refusal caused duplicated cross-cutting prose to be
  centralized without weakening the contract. Raising the ceiling would have hidden that defect.
- **“A judgment-based number is arbitrary.”** The exact values are conventional, but stability is
  part of their value. Changing a convention needs stronger evidence than consuming its remaining
  allowance; otherwise every hard budget becomes payload-controlled.

## Proportionality and verification

This is a governance decision over existing behavior. The smallest adequate implementation is a
decision record, a backlog closure, and correction of entries that called B-158 an unresolved gate.
No script, baseline, consumer artifact, test, version, or changelog changes. Verify the recorded
v0.78.3 values against `meta/context-footprint.json`, run both existing footprint twins in check
mode, run documentation/backlog hygiene, and require a clean diff. No live model evaluation can
answer a recurring-cost policy choice and none is authorized for this closure.
