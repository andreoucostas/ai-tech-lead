# B-66 prescriptive Angular forms guidance — implementation report

Date: 2026-08-17

## Scope delivered

- Added evidence-keyed, greenfield-only forms defaults to the Angular and monorepo
  `docs/defaults.md` source siblings while retaining the existing detect-only comments.
- Added the custom-form-control trade-off table without naming either integration route an
  anti-pattern.
- Extended both byte-identical `add-component` skill surfaces with a self-contained custom-form-
  control branch and selection terms for “custom form control” and “ControlValueAccessor”.
- Preserved the existing Component Design carve-out for components bindable with
  `formControlName`.
- Made no claim that this guidance has changed agent behaviour. Its behavioural effect remains
  unmeasured; this change ships on the field report recorded in B-66.

## Verification evidence

### Composition

Literal commands:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 dotnet
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 angular
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/build.ps1 monorepo
git status --porcelain dist/
```

Observed output:

```text
composed dist/dotnet (166 files)
composed dist/angular (162 files)
composed dist/monorepo (176 files)
BUILD_EXIT_CODES=dotnet:0 angular:0 monorepo:0
 M dist/angular/.claude/skills/add-component/SKILL.md
 M dist/angular/.github/skills/add-component/SKILL.md
 M dist/angular/docs/defaults.md
 M dist/monorepo/.claude/skills/add-component/SKILL.md
 M dist/monorepo/.github/skills/add-component/SKILL.md
 M dist/monorepo/docs/defaults.md
```

The status shows that the Forms change reached both affected distributions and that the dotnet
distribution did not change.

### Targeted `step-references` validation — both twins

Literal commands:

```powershell
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/validate-dist.ps1 angular -Check step-references
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/validate-dist.ps1 monorepo -Check step-references
& 'C:\Program Files\Git\bin\bash.exe' scripts/validate-dist.sh angular -Check step-references
& 'C:\Program Files\Git\bin\bash.exe' scripts/validate-dist.sh monorepo -Check step-references
```

Observed output:

```text
OK:   ordered-list runs are contiguous and prose step references resolve (31 files scanned; 149 labels found; 3 prose references found).
All dist validation checks passed for dist\angular.
EXIT validate-dist.ps1 angular=0

OK:   ordered-list runs are contiguous and prose step references resolve (37 files scanned; 208 labels found; 15 prose references found).
All dist validation checks passed for dist\monorepo.
EXIT validate-dist.ps1 monorepo=0

OK:   ordered-list runs are contiguous and prose step references resolve (31 files scanned; 149 labels found; 3 prose references found).
All dist validation checks passed for dist/angular.
EXIT validate-dist.sh angular=0

OK:   ordered-list runs are contiguous and prose step references resolve (37 files scanned; 208 labels found; 15 prose references found).
All dist validation checks passed for dist/monorepo.
EXIT validate-dist.sh monorepo=0
```

### Template checks from each affected distribution — both twins

Literal commands:

```powershell
Set-Location dist/angular
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/template-checks.ps1
& 'C:\Program Files\Git\bin\bash.exe' scripts/template-checks.sh
Set-Location ../monorepo
& 'C:\Program Files\PowerShell\7\pwsh.exe' -NoProfile -File scripts/template-checks.ps1
& 'C:\Program Files\Git\bin\bash.exe' scripts/template-checks.sh
```

Observed output common to all four runs included:

```text
OK:   .claude/skills and .github/skills are in sync.
OK:   Common Tasks skill inventory matches between CLAUDE.md and AGENTS.md.
All deterministic framework checks passed.
```

Observed exit codes:

```text
EXIT template-checks.ps1 angular=0
EXIT template-checks.sh angular=0
EXIT template-checks.ps1 monorepo=0
EXIT template-checks.sh monorepo=0
```

## Precision traps honoured

1. Circular DI is qualified to the self-referencing provider mechanism, and the separate-accessor
   exception is explicit:

   > “Do not combine injected `NgControl` with a self-referencing provider (`NG_VALUE_ACCESSOR`
   > plus `useExisting: forwardRef(() => Self)`): the dependency path cycles from `NgControl`
   > through the provider and component back to `NgControl`. A separate accessor class does not
   > create that cycle.”

2. Disabled state is described as a collision with forms plumbing, with no claim that Angular
   emits a warning:

   > “Do not declare an `@Input() disabled`; it fights `control.disable()` by colliding with
   > `setDisabledState()`.”

3. Signal inputs are identified as read-only, so the CVA value is excluded while presentation
   inputs remain allowed:

   > “Signal inputs are read-only, so the control's value cannot be an `input()`; `input()` and
   > `input.required()` remain suitable for presentation inputs.”

The adjacent wrapper distinction is also explicit:

> “Taking the control itself as an `@Input()` creates a legitimate wrapper, not a bindable control,
> so `formControlName` cannot drive it.”

## Uncertainty

None about the implemented scope or the targeted gate results. The guidance's effect on model
behaviour is deliberately unmeasured and is not presented as verified.
