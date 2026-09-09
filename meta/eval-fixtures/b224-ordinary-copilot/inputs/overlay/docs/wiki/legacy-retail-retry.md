---
name: legacy-retail-retry
description: Stale legacy retry advice
type: failed-approach
scope: src/Legacy/**
status: suspected
last-verified: 2026-01-01
---
A retired legacy service may have allowed three cancellation attempts.
**Confidence:** inferred
**Provenance:** stale note whose named source is absent.
**Evidence:** `src/Legacy/RetryPolicy.cs` (missing)
**Counterevidence / exceptions:** current retail policy is scoped elsewhere.
**Dependencies / unresolved:** missing legacy source.
**Verify by:** locate historical evidence before relying on this claim.
**Semantic refresh:** trigger: legacy scope is restored; result: unavailable.
**Draft status:** old suspected note; not current policy.
