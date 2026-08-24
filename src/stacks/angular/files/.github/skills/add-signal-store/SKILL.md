---
name: add-signal-store
description: >
  Use when the user wants to add a new signal-based store/service for shared state in Angular 16+.
  Covers signal vs computed split, read-only exposure, mutation discipline, and harness-evidenced
  state-transition tests.
  USE FOR: a store that does not exist yet — a new feature's state slice, a new server-state cache
  shared across components.
  DO NOT USE FOR: a signal for local UI state inside one component (ordinary component work); a
  stateless HTTP service (use `add-service`); migrating an existing NgRx/NGXS store to signals (use
  `/design`, then `/refactor`); backfilling tests (use `add-tests`).
---

# Add a new signal-based store

Match CLAUDE.md > Conventions > State Management. Do not introduce signals if the codebase consistently uses NgRx/NGXS — use the existing pattern unless the user explicitly asks to migrate.

**Applicability gate:** confirm a repository-evidenced Angular workspace and that the target
belongs to it. Also confirm an existing signal-state pattern, or an explicit developer decision to
use one after comparing the repository's state-management evidence. If either condition is absent,
report this skill as **not applicable**; the selected distribution and template defaults do not
establish a signal-store choice.

0. **Confirm the state is not already owned elsewhere.** Search existing stores, services, selectors, and signals by domain concept. Extend the established owner through ordinary `/feature` work instead of creating two writable sources of truth.

1. Create a service with `signal()` for state and `computed()` for derived values.
2. Expose read-only signals publicly via `asReadonly()`.
3. Mutations only via explicit methods on the service — no external `.set()` calls; no leaky writable signals.
4. When an applicable test harness is evidenced, add the smallest behavior-focused tests for
   relevant signal state transitions: initial state, mutation methods, and computed derivations.
   Do not create a runner or test configuration incidentally; otherwise report the test category
   as **not available**.

Server-state slices: handle loading, error, and success explicitly; no optimistic assumptions.

Derive build, test, format, lint, migration/deploy, and data-validation commands from CLAUDE.md >
Conventions > Verification Commands, committed CI, scripts, manifests, and configuration. Run only
exact evidenced commands and report every unavailable category as **not available**.
