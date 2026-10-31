# Tech Debt Register

> One block per item. Sort by severity then effort. Reference items by ID in commit messages and PRs.
> Run `/debt [area]` to find and fix items. Run `/docs-sync` to check for staleness.

**Categories**: Architecture, State Management, RxJS, Component Design, Testing, Types, Performance, Dependencies, Security
**Severity**: Critical / High / Medium / Low
**Effort**: S (< 1hr) / M (half day) / L (1-2 days) / XL (needs spike)

---

## DEBT-001: Angular 19 is outside the support window

- **Key**: dependencies::angular-out-of-support
- **Category**: Dependencies
- **Severity**: High
- **Effort**: L (1-2 days)
- **Files**: `package.json`

### Issue
`@angular/*` is pinned to `^19.0.0`, below the v21 floor and outside Angular's support window, so security fixes are no longer guaranteed.

### Recommended fix
Upgrade one major at a time with `ng update` (see the `dependency-audit` skill), running the spec suite after each step.

---

## DEBT-002: package.json lacks the toolchain its scripts and targets need

- **Key**: dependencies::missing-angular-toolchain
- **Category**: Dependencies
- **Severity**: High
- **Effort**: M (half day)
- **Files**: `package.json`, `angular.json`

### Issue
`npm test` runs `ng test` and `angular.json` uses `@angular-devkit/build-angular` (application and karma builders), but `package.json` declares no `@angular/cli`, `@angular-devkit/build-angular`, `@angular/compiler`, `@angular/compiler-cli`, `typescript`, `zone.js`, karma or jasmine packages. The recorded test command cannot be confirmed to run from a clean install, and there is no build script.

### Recommended fix
Declare the missing devDependencies at versions matching the Angular major, add `build` and `lint` scripts if wanted, and confirm `npm test` runs.

---

## DEBT-003: Test coverage limited to OrderListComponent

- **Key**: testing::untested-profile-form-and-user-service
- **Category**: Testing
- **Severity**: Medium
- **Effort**: S (<1hr)
- **Files**: `src/app/profile-form/profile-form.component.ts`, `src/app/user.service.ts`

### Issue
Only `order-list.component.spec.ts` exists. The profile form validators and `UserService.updateProfile` have no specs.

### Recommended fix
Use the `add-tests` skill: spec required-field and email validation rendered state, and the `PUT /api/profile` call via `HttpTestingController`.

---

## DEBT-004: Untyped profile form and profile request

- **Key**: types::untyped-profile-form
- **Category**: Types
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `src/app/profile-form/profile-form.component.ts:17`, `src/app/user.service.ts:9`

### Issue
The form is declared `FormGroup` (untyped values) and `updateProfile` returns `Observable<Object>`.

### Recommended fix
Drop the `FormGroup` annotation so the typed `FormBuilder` group is inferred; type the `put` response.

---

## DEBT-005: Unused UserService / form has no submit path

- **Key**: component-design::profile-form-not-wired
- **Category**: Component Design
- **Severity**: Low
- **Effort**: S (<1hr)
- **Files**: `src/app/user.service.ts`, `src/app/profile-form/profile-form.component.ts`

### Issue
Nothing injects `UserService` and the form has no submit handler or button, so profile edits are never sent.

### Recommended fix
Confirm with the team whether this is work in progress; wire it up or remove the service.

---

---

## Dismissed proposals — do not re-propose without materially changed evidence

> These are reviewed claims the team determined are not debt. Keep every row for auditability.
> A later scan may reopen one only by naming the concrete evidence delta in a new active item.

| Key | Affected paths / symbols | Evidence reviewed | Dismissed | Reason |
|-----|--------------------------|-------------------|-----------|--------|
| _(none)_ | _ | _ | _ | _ |

---

## Trojan Horse Opportunities

- **Profile**: DEBT-003, DEBT-004, DEBT-005
- **Build/toolchain**: DEBT-001, DEBT-002
