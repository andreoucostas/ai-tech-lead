---
name: add-component
description: Use when the user wants to add a new Angular feature component (standalone or module-bound). Covers component scaffold, routing, models, service wiring, state choice, and required test coverage.
---

# Add a new feature component

Match the conventions in CLAUDE.md > Conventions > Component Design before scaffolding. If the codebase uses a state pattern (signals, NgRx, NGXS), match it; do not introduce a new pattern.

1. Create component with `ng generate component` (standalone by default).
2. Add route in the feature's routing config (lazy-loaded).
3. Create interfaces/models for the feature's data shapes (no `any`).
4. Create or extend a service for backend communication (typed end-to-end).
5. Wire up state (signals, store, or service — match existing pattern).
6. Write component test + service test.

After scaffolding, follow the standard `/feature` flow: build/test/lint after each subtask, Boy Scout every touched file, self-review against CLAUDE.md > Conventions.
