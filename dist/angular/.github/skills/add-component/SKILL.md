---
name: add-component
description: >
  Use when the user wants to add a new Angular feature component (standalone or module-bound),
  including a custom form control or ControlValueAccessor.
  Covers component scaffold, routing, models, service wiring, state choice, and required test
  coverage.
  USE FOR: a component that does not exist yet — a new screen, dialog, or reusable presentational
  component.
  DO NOT USE FOR: changing an existing component's template, inputs, or behaviour (use `/feature`
  or `/refactor`); backfilling tests (use `add-tests`); a service with no template (use
  `add-service`); shared cross-component state (use `add-signal-store`).
---

# Add a new feature component

Match the conventions in CLAUDE.md > Conventions > Component Design before scaffolding. If the codebase uses a state pattern (signals, NgRx, NGXS), match it; do not introduce a new pattern.

## Custom form control branch

When the component must bind directly with `formControlName`, implement `ControlValueAccessor` and
use one forms integration route already established in the repo. A control that renders no
validation state of its own can provide `NG_VALUE_ACCESSOR`; a control that renders its own
error/required state can instead inject `NgControl` with `{ self: true }` and set
`ngControl.valueAccessor = this` by hand. Neither route is an anti-pattern. Do not combine injected
`NgControl` with a self-referencing provider (`NG_VALUE_ACCESSOR` plus
`useExisting: forwardRef(() => Self)`): the dependency path cycles from `NgControl` through the
provider and component back to `NgControl`. A separate accessor class does not create that cycle.

Implement value, touched, and disabled plumbing. Do not declare an `@Input() disabled`; it fights
`control.disable()` by colliding with `setDisabledState()`. Signal inputs are read-only, so the
control's value cannot be an `input()`; `input()` and `input.required()` remain suitable for
presentation inputs. Taking the control itself as an `@Input()` creates a legitimate wrapper, not a
bindable control, so `formControlName` cannot drive it. See Conventions > Forms for additional repo
detail when that section exists.

0. **Confirm the screen or UI responsibility does not already exist.** Search routes, selectors, templates, and component names by user-visible capability. Extend or compose an existing component through ordinary `/feature` work instead of creating a parallel screen.

1. Create component with `ng generate component` (standalone by default).
2. Add route in the feature's routing config (lazy-loaded).
3. Create interfaces/models for the feature's data shapes (no `any`).
4. Create or extend a service for backend communication (typed end-to-end).
5. Wire up state (signals, store, or service — match existing pattern).
6. Write component test + service test.

After scaffolding, follow the standard `/feature` flow: build/test/lint after each subtask, Boy Scout every touched file, self-review against CLAUDE.md > Conventions.
