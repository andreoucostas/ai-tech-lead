---
name: add-component
description: >
  Use when the user wants to add a new Angular feature component (standalone or module-bound),
  including a custom form control or ControlValueAccessor.
  Covers component scaffold, routing, models, service wiring, state choice, and harness-evidenced
  test coverage.
  USE FOR: a component that does not exist yet — a new screen, dialog, or reusable presentational
  component.
  DO NOT USE FOR: changing an existing component's template, inputs, or behaviour (use `/feature`
  or `/refactor`); backfilling tests (use `add-tests`); a service with no template (use
  `add-service`); shared cross-component state (use `add-signal-store`).
---

# Add a new feature component

Match the conventions in CLAUDE.md > Conventions > Component Design before scaffolding. If the codebase uses a state pattern (signals, NgRx, NGXS), match it; do not introduce a new pattern.

**Applicability gate:** confirm a repository-evidenced Angular workspace and that the target belongs
to it. If either is absent, report this skill as **not applicable**; the selected distribution and
template defaults do not establish an Angular project.

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

1. Use a generator only when its exact invocation is evidenced by CLAUDE.md > Conventions >
   Verification Commands, committed scripts, manifests, or workspace configuration. Otherwise
   create the files manually by mirroring an existing component; do not infer `ng generate`.
2. Add route in the feature's routing config (lazy-loaded).
3. Create interfaces/models for the feature's data shapes (no `any`).
4. Create or extend a service for backend communication (typed end-to-end).
5. Wire up state (signals, store, or service — match existing pattern).
6. When an applicable test harness is evidenced, add the smallest behavior-focused test(s) that
   follow its conventions. Do not create spec files, a runner, test configuration, or HTTP testing
   infrastructure incidentally; otherwise report the test category as **not available**.

After scaffolding, derive build, test, format, lint, migration/deploy, and data-validation commands
from CLAUDE.md > Conventions > Verification Commands, committed CI, scripts, manifests, and
configuration. Run only exact evidenced commands and report every unavailable category as **not
available**. Boy Scout every touched file and self-review against CLAUDE.md > Conventions.
