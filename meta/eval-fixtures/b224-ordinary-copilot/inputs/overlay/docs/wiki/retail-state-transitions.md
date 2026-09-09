---
name: retail-state-transitions
description: Retail shipment release and cancellation eligibility
type: context
scope: src/Dispatch/Retail*
status: verified
last-verified: 2026-09-09
---
Retail cancellation is accepted only when `RetailTransitionPolicy.CanCancel` accepts the shipment.
The retail boundary is strict: attempts equal to the configured maximum are rejected. A rejected
transition preserves the shipment state. Admin and premium rules do not widen this scope.
**Confidence:** observed
**Provenance:** `src/Dispatch/RetailTransitionPolicy.cs`, verified against current source
**Evidence:** `RetailTransitionPolicy.CanCancel` and `RetailShipmentService.TryRelease`
**Counterevidence / exceptions:** `AdminTransitionPolicy.CanCancel` deliberately permits a reserved
shipment and uses an inclusive attempt boundary, but applies only to the admin channel.
**Dependencies / unresolved:** `RetailCancellationOptions.MaximumAttempts`
**Verify by:** reread the retail predicate and run the repository's executable application checks.
**Semantic refresh:** trigger: either retail predicate or options binding changes; result: current
predicate reread on 2026-09-09.
**Draft status:** reviewed fixture claim; not generated during this task.
