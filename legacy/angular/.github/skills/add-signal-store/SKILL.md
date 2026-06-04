---
name: add-signal-store
description: Use when the user wants to add a new signal-based store/service for shared state in Angular 16+. Covers signal vs computed split, read-only exposure, mutation discipline, and state-transition tests.
---

# Add a new signal-based store

Match CLAUDE.md > Conventions > State Management. Do not introduce signals if the codebase consistently uses NgRx/NGXS — use the existing pattern unless the user explicitly asks to migrate.

1. Create a service with `signal()` for state and `computed()` for derived values.
2. Expose read-only signals publicly via `asReadonly()`.
3. Mutations only via explicit methods on the service — no external `.set()` calls; no leaky writable signals.
4. Write tests verifying signal state transitions: initial state, each mutation method, computed derivations.

Server-state slices: handle loading, error, and success explicitly; no optimistic assumptions.
