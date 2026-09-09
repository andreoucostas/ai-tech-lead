---
name: admin-state-transitions
description: Administrative shipment cancellation eligibility
type: context
scope: src/Admin/**
status: verified
last-verified: 2026-09-09
---
Administrative cancellation accepts queued or reserved shipments through an inclusive attempt
boundary. This is not a retail rule.
**Confidence:** observed
**Provenance:** `src/Dispatch/AdminTransitionPolicy.cs`
**Evidence:** `AdminTransitionPolicy.CanCancel`
**Counterevidence / exceptions:** retail uses a strict boundary and queued-only scope.
**Dependencies / unresolved:** none.
**Verify by:** reread `AdminTransitionPolicy.CanCancel`.
**Semantic refresh:** trigger: admin predicate changes; result: predicate reread on 2026-09-09.
**Draft status:** reviewed fixture claim; not generated during this task.
