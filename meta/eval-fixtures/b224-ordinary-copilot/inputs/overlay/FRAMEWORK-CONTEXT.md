# Framework Context

## Repository knowledge coverage

- Shipment state transitions have channel-specific project knowledge indexed in
  `docs/wiki/INDEX.md`.
- The index is navigation only; decisive policy source must be reread before a change.
- Premium and legacy behavior include unresolved or stale evidence and cannot be generalized.

## Known Hazard Areas

| Area / file(s) | Hazard | Status | Reviewed |
|---|---|---|---|
| `src/Dispatch/*TransitionPolicy.cs` | Similar names carry deliberately different channel scopes. | [VERIFIED] | 2026-09-09 |
