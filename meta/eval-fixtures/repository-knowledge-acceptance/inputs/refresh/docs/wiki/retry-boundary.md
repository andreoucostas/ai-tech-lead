---
name: retry-boundary
description: Configured intake retry boundary
type: context
scope: src/intake/RetryPolicy.cs and config/retry.json
status: verified
last-verified: 2026-09-01
---
Intake retries are allowed only while the zero-based attempt is less than the configured
`maxAttempts` value, which was 3 when this claim was checked.
**Confidence:** observed
**Provenance:** synthetic owner-authored claim at the recorded fixture base revision
**Evidence:** src/intake/RetryPolicy.cs `RetryPolicy.CanRetry` and `RetryBoundary.Allows`; config/retry.json `maxAttempts`
**Counterevidence / exceptions:** generated/retry-reference.cs is ignored generated output and is not authority.
**Dependencies / unresolved:** the caller, helper predicate, and configuration must all remain available.
**Verify by:** reread the caller-to-helper binding, the `<` predicate, and the configured maximum.
**Semantic refresh:** compare those exact sources after any relevant change; 2026-09-01 recheck found `< 3`.
**Draft status:** owner-authored fixture claim; changes require explicit owner confirmation.

