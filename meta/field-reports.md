# Field reports

Evidence from people using the framework on real work, as opposed to maintainer introspection.
Created 2026-07-31 for **B-42**, which asks that field findings be recorded here and used to
re-order the backlog.

> **Confidentiality rule — binding.** Reports arrive from client repositories. Record the
> *technical shape only*: stack, repo shape, what the model did, which framework surface was
> involved. Never record client names, repository names, file paths, domain vocabulary, or code.
> The eval fixtures derived from these reports are synthetic for the same reason.
>
> **Do not invent fields.** Anything the reporter did not say is recorded as **not captured** — an
> empty field is evidence about our intake, and guessing would turn one observation into a fake
> dataset. Most fields below are empty; that is the honest state, and it is itself a finding
> (see "Intake gaps").

## Numbering note

B-42 records the Angular report below as "field report #1", and B-66 calls it "the first field
report the framework has ever received". **Both are wrong.** The NUnit report that drove B-57 →
v0.36.0/v0.37.0 is also a field report from a real install, and it landed earlier in the shipping
record (`meta/BACKLOG.md:894`). It is recorded here as #1. The numbering in B-42/B-66 is left
as-is rather than rewritten, so the discrepancy stays visible; this file is the ledger.

---

## Report #1 — .NET brownfield, test framework assumed

| | |
|---|---|
| **Date received** | not captured (before v0.36.0, shipped 2026-07-31) |
| **Stack / repo shape** | .NET, brownfield, existing NUnit suite |
| **Framework installed** | yes — a real install |
| **What misfired** | The framework kept steering toward xUnit instead of following the test suite already in the repo. Six shipped surfaces stated xUnit as fact. |
| **What fired** | not captured |
| **What got ignored** | Verification Rule #10 and `bootstrap.md`'s Phase 3a synthesis guard both already forbade exactly this, and neither prevented it. |
| **Hook noise** | not captured |
| **Token pain** | not captured |
| **Reporter** | a reviewer on the receiving team (not the framework author) |

**Outcome:** B-57, shipped as **v0.36.0** (guidance: evidence-keyed Testing block, `add-tests` Step-1
evidence gate, `enforce-standards` branching across xUnit/MSTest/NUnit) and **v0.37.0**
(enforcement: the write guard blocked only `[Fact(Skip=…)]`, so NUnit and MSTest repos had a weaker
floor than xUnit ones). WSD-025.

**What this report taught that the defect itself did not:** a rule can be written down correctly and
still lose to a parenthetical. `add-tests` read "following project patterns **(xUnit +
`WebApplicationFactory`)**" — a sentence that argues with itself. See `meta/LEARNINGS.md`.

---

## Report #2 — Angular, custom form control

| | |
|---|---|
| **Date received** | 2026-07-31 |
| **Stack / repo shape** | Angular, brownfield (client repository) |
| **Framework installed** | not captured |
| **What misfired** | On a custom form control, the model used `@Input()` properties rather than making the component participate in the Angular forms API (injecting `NgControl` / implementing a value accessor). |
| **What fired** | not captured |
| **What got ignored** | Nothing — and that is the point. Unlike report #1, no framework surface said anything for the model to ignore. |
| **Hook noise** | not captured |
| **Token pain** | not captured |
| **Reporter** | an Angular developer (not the framework author) |

**Root cause:** the Angular stack ships **no forms guidance at all**. A case-sensitive grep for
`ControlValueAccessor`, `NgControl`, `FormControl`, `FormGroup`, `FormBuilder`, `Validators`,
`ngModel`, `NG_VALUE_ACCESSOR`, `formControlName` and `ReactiveFormsModule` returns zero hits across
`src/stacks/angular/`, `src/core/` **and** `dist/angular/`. The model was not disobeying the
framework; the framework was silent, so it fell back on training priors.

**Corroborated independently** (2026-07-31, commit `0598c6d`): in an `angular-form-control` eval run
against a synthetic fixture with the angular dist installed, the agent grepped for an existing
`ControlValueAccessor`/`NgControl` pattern to follow and reported finding none — because none ships.
The field report and the harness agree, from different directions.

**Outcome:** B-66.

---

## Intake gaps (a finding in its own right)

Both reports arrived as a single sentence about one defect. Neither captured what *worked*, hook
noise, token cost, or the surrounding session — the things B-42 says the pilot needs, and the things
that would tell us whether the framework is a net gain rather than merely wrong in one spot.

Consequences worth acting on:

1. **We only hear about defects.** Every report to date is a complaint. Nothing in the intake path
   asks "what did it get right", so the ledger structurally cannot show value — only failure. Any
   future adoption argument built on this file would be reading a biased sample.
2. **Arrival dates are not recorded at intake.** Report #1's date is already unrecoverable.
3. **Both reports name a *convention* defect, not a workflow one.** Two data points is not a trend,
   but if it holds, it says the framework's weak spot is the breadth of what it knows about a stack
   rather than how it drives a task.

If a third report arrives, capture the table fields **at intake**, before the defect is diagnosed —
by then attention has moved to the fix and the context is lost.
