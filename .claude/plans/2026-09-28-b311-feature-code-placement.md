# Place new feature code by responsibility, not in the nearest existing class (B-311)

Field report #8 (`meta/field-reports.md`), relayed by the maintainer on 2026-09-28 from an Angular
consumer: a senior lead rejected an Opus 5.5 implementation of a new feature because the agent
extended an existing class. The lead's rule, as relayed (spelling normalised): "If a new feature
requires new code (rather than modifying existing methods), the primary approach is to create a new
feature service and inject its dependencies. A fallback approach is to extend the existing class
only if you need to call its private methods and the user explicitly doesn't want you to refactor."
Reported behaviour: the agent extends the existing class every time. The maintainer asked for this
design, a second opinion from Fable (reviewed below), and a backlog entry for the session working
the backlog.

## Why the agent does it: our text tells it to

Angular wording; the carriers and where they load:

| Carrier (source) | Text today | Loaded |
|---|---|---|
| Leanness #1 (`lean-1-2`) | "Edit existing files; do not create new ones unless required. … If a method fits an existing service or component, put it there." | Every turn (CLAUDE.md import; Copilot `applyTo: "**"`) |
| Feature rail (`workflow-bullets`), declared "canonical and binding" | "…otherwise add no service/abstraction without a second consumer or correctness need." | Every turn |
| When you must add structure (`lean-structure`) | "If a change genuinely requires a new abstraction, component, service, or pipe, state the second consumer…" | Every turn |
| `src/core/.claude/hooks/route-prompt.ps1:41`, feature rails | "Prefer editing existing files over creating new ones." | Every prompt routed as a feature, on Claude Code and Copilot |
| `route-prompt.ps1:55`, refactor rails | "inline single-use abstractions" (a later `/refactor` can fold a one-consumer service back) | Every prompt routed as a refactor |
| `/feature` Step 1 (`feature.md/leanness`) | "can this fit in existing files?" | When `/feature` runs |
| `add-service` step 0 (`src/stacks/angular/files/.claude/skills/add-service/SKILL.md:27`); the .NET twin is `register-service:22` | "Confirm no existing service already owns the backend resource or responsibility … Extend an existing service through ordinary `/feature` work…" | When the skill fires, which is the moment a new service is being considered |
| Angular defaults (`docs/defaults.md:83`, monorepo `:200`) | "One service per backend resource" (reads as: services exist per resource only) | Before `/bootstrap` |

A new feature service nearly always has one consumer, its feature component. The rail and
`lean-structure` therefore forbid it, #1 points at the nearest existing service, and the skill a
model reaches for sends it back there at step 0, using the field report's own verb. SOLID says it
governs structure ("SOLID governs structure; Leanness governs ceremony beyond that structure"), but
its concrete SRP triggers (more than ~5 injected collaborators, a name needing "And"/"Manager")
fire only after a service has already grown. The second-consumer test was written for speculative
abstractions (interfaces, abstract bases, tokens, helpers, pipes, directives, wrappers); it is being
applied to concrete classes that own a responsibility.

Per stack: the Angular and monorepo rails say "service"; the .NET rail says "interface/abstraction".
All three carry #1 and both hook lines; the .NET and monorepo `lean-structure` lists say "file". The
.NET SOLID #2, "extend by adding a type, not editing a stable one", reads in C# as a licence to
subclass. The model already leans the same way (earlier Claude Code system prompts told it to prefer
editing an existing file to creating one), so deleting our sentence is not enough: the replacement
has to say where new code goes.

Resolved by the maintainer on 2026-09-28: the agent added members to the existing class and made no
subclass. No diff or transcript exists. The eval still gates on both: the fix pushes models off the
bolt-on path, and a subclass is the next-nearest shortcut.

## Decision

Adopt the lead's rule, sharpened in four ways:

1. **Responsibility decides placement, not "new code" or proximity.** Changed behaviour is edited
   where it lives. New code joins an existing class only if the class's name still describes it; an
   API service or client holds calls on its resource and nothing more. Otherwise the code gets its
   own service, even with one consumer. The name test ships in the rule text itself, because a model
   left to judge "responsibility" will decide that draft storage belongs with "profile".
2. **Never subclass a concrete service to reuse it.** A TypeScript subclass cannot call `private`
   members (TS2341), so subclassing to reach them forces widening them to `protected`, which edits
   the existing class anyway. With `providedIn: 'root'` on both, base and subclass are two instances
   with separate state. C# `private` is equally invisible to a subclass. "Extend" in the fallback
   means adding members to the existing class.
3. **Extract first when private logic is needed; that is also the default.** The shared logic goes
   into something both classes use: an injectable, or a pure function (which is not injected). The
   plan gate (Agentic Workflow §2) asks the developer. Pre-approved prompts skip that gate, and the
   text makes extraction the default when nobody answers. Only if the developer declines does the
   new code go into the existing class, and the report says so.
4. **Do not over-correct.** A would-be service that only forwards calls is not a responsibility
   (Leanness #4; bloat-radar's pass-through-service rule), and UI state used by one component stays
   in that component.

The second-consumer test stays, scoped to abstractions, wrappers, helpers, pipes and directives.
Leanness #3 (no abstract base with one subclass) and #8 (no helper without two call sites) already
cover what "do not create new files" guarded against.

## Changes

Author under `src/`; `dist/` is rebuilt. `…/` below means `src/stacks/<stack>/snippets/`, and
`FR` means `.github/instructions/framework-rules.instructions.md`.

### 1. Leanness #1 — `…/FR/lean-1-2`, first line only

Line 2 (#2) stays: it carries the "project evidence" phrase `OperationSkillAuthority.Tests.ps1`
requires in this carrier.

Angular:

> 1. **Place code by responsibility, not proximity.** Edit changed behaviour where it lives. New code joins an existing service only if that service's name still describes it (an API service: calls on its resource, nothing more); otherwise it gets its own service that injects its dependencies, even with one consumer — never bolted onto the nearest service, never a subclass of one. Need another class's private logic? Extract it for both to share; add to that class only if the developer declines. UI state used by one component stays in it.

.NET (stack-neutral composition; the .NET distribution does not presume a DI container):

> 1. **Place code by responsibility, not proximity.** Edit changed behaviour where it lives. New code joins an existing class only if that class's name still describes it (a repository or client: operations on its resource, nothing more); otherwise it gets its own class, composed the way the project already composes services, even with one consumer — never bolted onto the nearest class, never a subclass of one. Need another class's private logic? Extract it for both to share; add to that class only if the developer declines.

Monorepo: the .NET text plus " UI state used by one component stays in it."

### 2. Feature rail — `…/FR/workflow-bullets`

Keep "Preserve a project-evidenced service seam" (the same test pins it).

- Angular: "otherwise add no service/abstraction without a second consumer or correctness need." →
  "otherwise add no abstraction without a second consumer or correctness need, and place new feature
  logic per Leanness #1."
- Monorepo: "add no interface/service/abstraction" → "add no interface/abstraction", same tail.
- .NET: unchanged. Its rail does not forbid a service, and its static budget is the tightest.

### 3. When you must add structure — `…/FR/lean-structure`

- Angular: "a new abstraction, component, service, or pipe," → "a new abstraction, wrapper, helper,
  pipe, or directive,"
- .NET: "a new abstraction, file, or wrapper," → "a new abstraction, helper, or wrapper,". Dropping
  "file" is the important part.
- Monorepo: "a new abstraction, file, component, service, or pipe," → "a new abstraction, wrapper,
  helper, pipe, or directive,"

### 4. SOLID #2 — `…/FR/solid-1-5`, line 2

- Angular and monorepo: "extend by adding a type/strategy, not editing a stable one." → "extend by
  adding a type/strategy behind a seam, not by editing a stable class or subclassing a concrete
  service."
- .NET: "extend by adding a type, not editing a stable one." → "extend by adding a type behind a seam,
  not by editing a stable class or subclassing a concrete service."
- Why "a concrete service" and not "a concrete class": subclassing framework base types, such as a
  `DbContext` or an exception, stays legitimate.
- Why keep this change although the field case made no subclass: change 1 steers models away from
  editing the existing class. SOLID #2 as written ("not editing a stable one") would then read as
  pointing at a subclass instead.

### 5. Prompt hook — `src/core/.claude/hooks/route-prompt.ps1`, all stacks, both surfaces

- Feature rails, line 41: "- Prefer editing existing files over creating new ones." → "- Place code
  by responsibility (Leanness #1): a new responsibility gets its own service or class even with one
  consumer; never bolt it onto the nearest service or subclass one."
- Refactor rails, line 55: "inline single-use abstractions" → "inline single-use interfaces,
  abstract bases, wrappers and helpers".

### 6. `/feature` Step 1 — `…/.claude/commands/feature.md/leanness`

"can this fit in existing files?" → "does this change an existing responsibility (edit its owner) or
add one (its own service or class, even with one consumer — Leanness #1)?" The rest of the line is
unchanged.

### 7. Skill step 0 — `src/stacks/angular/files/.claude/skills/add-service/SKILL.md:27` and `src/stacks/dotnet/files/.claude/skills/register-service/SKILL.md:22`

The monorepo dist ships byte-identical copies of both.

- add-service: "Extend an existing service through ordinary `/feature` work instead of creating a
  second client for the same resource." → "Add to an existing service only what its name covers,
  through ordinary `/feature` work, instead of creating a second client for the same resource; a new
  responsibility still gets its own service (Leanness #1)."
- register-service: "Extend or replace an existing owner through ordinary `/feature` or `/refactor`
  work instead of creating overlapping ownership." → "Add to an existing owner only what its name
  covers, or replace it, through ordinary `/feature` or `/refactor` work, instead of creating
  overlapping ownership; a new responsibility still gets its own class (Leanness #1)."

### 8. Angular defaults — `src/stacks/angular/files/docs/defaults.md:83`, monorepo `:200`

"One service per backend resource" → "One HTTP client service per backend resource".

### 9. Review backstop — `…/.claude/agents/solid-check.md/principles`, the S line

Append to the `medium` findings: "a member the class's name no longer covers (e.g. storage or draft
logic added to an HTTP client service); a subclass of a concrete service made to reuse it." The D
line keeps "first-party", which the same test requires in this carrier. The Copilot
`solid-check.agent.md` delegates to this file (`:9`), so it needs no edit.

### Considered, not changed

- **`add-signal-store` step 0** (`:28`) and **`add-component` step 0** (`:46`): these prevent two
  writable sources of truth and parallel screens. That is a correctness rule about ownership of
  state, not about where logic goes.
- **`bloat-radar.md:26`**, "one new service per resource is enough": this sits under a shallow-HTTP-
  wrapper finding, so its context already limits it to HTTP clients.
- **Adjacent, separate:** Leanness #4 calls a thin `HttpClient` wrapper bloat, while the defaults say
  one client service per backend resource. Not this item.

## Budget

Changes 1–4 are static context; the framework rules file is imported by `CLAUDE.md`. Measured
against the committed baseline (`meta/context-footprint.json`, unchanged from 70bbf7b5 through
3285e9d5) with UTF-8 byte counts:

| Dist | static.claude now | Delta | After | Ceiling | Headroom after |
|---|---|---|---|---|---|
| angular | 37,504 | +471 | 37,975 | 40,000 | 2,025 |
| dotnet | 39,072 | +431 | 39,503 | 40,000 | 497 |
| monorepo | 46,276 | +489 | 46,765 | 48,000 | 1,235 |

Change 5 grows the feature and refactor rows under `prompt` in the baseline. It does not move
`prompt.max`: the Angular feature row is 2,436 chars against a worst case of 3,206 (fix-security).
Changes 6–9 are bodies loaded on demand. Run `scripts/context-footprint.ps1 -Check`, review the
diff, then `-Update`.

## Tier and verification

Guarded: changes 5 and 7 are under `src/core/.claude/hooks/**` and `src/stacks/*/files/.claude/**`.
Following root `AGENTS.md`:

1. **Commit body, at most five lines.** It covers the harm, the smaller fix rejected, and what could
   be lost, and it also has to carry the escaped-defect sentences. Draft:
   - *Harm:* shipped rules forbid a one-consumer service, so agents bolt new feature logic onto
     existing classes; a consumer's senior lead rejected the result (field report #8).
   - *Rejected:* a consumer Conventions line, or a new rule beside the old one, which leaves the
     contradiction in place.
   - *Could be lost:* over-correction into one-method services, held back by the name test, the UI
     state clause and Leanness #4.
   - *Cause:* the second-consumer test was applied to concrete services.
   - *Why no gate caught it, and the check added:* no eval checked where feature code goes;
     `angular-feature-placement` does now.
2. **Red-first.** The hook and skill edits are message strings, so they have no behaviour of their
   own to show red; say so. The behavioural instrument is the eval below, seen red on the unfixed
   base.
3. **Tests on both hosts.**
   - Run `src/core/tests/hooks/RoutePrompt.Tests.ps1` under `pwsh` and under `powershell.exe` as
     separate runs, plus the CP437 leg. Its feature case asserts only "never add a harness
     incidentally" (`:43-46`), so change 5 is safe.
   - Run `.claude/hooks/tests/OperationSkillAuthority.Tests.ps1` the same way. Its `:108-109` checks
     the carrier phrases, and Fable verified none of the new text trips its forbidden pattern.
   - For the dist hook, pipe a Claude Code `UserPromptSubmit` fixture and a Copilot
     `userPromptSubmitted` fixture, each carrying a feature prompt and a refactor prompt, into
     `dist/<stack>/.claude/hooks/route-prompt.ps1`. Assert `EXIT=0` and the new lines in the output.
4. **Not an item-4 path:** no installer, guard, ownership or retirement policy, and not root
   `AGENTS.md`.

Then `scripts/build.ps1` ×3, commit `dist/` in the same commit, `scripts/validate-dist.ps1` ×3, and
`context-footprint.ps1 -Check`. Add a root `CHANGELOG.md` entry and an entry under the
`## 0.90.0 — Unreleased` head of each of the three stack changelogs (or whichever head is open then),
in the consumer's voice. For example: "When a feature adds a new responsibility, the agent now puts it
in its own service that injects its dependencies, instead of adding it to the nearest existing
service or subclassing one. Code that belongs to an existing service's job still goes there." Record
a WSD on implementation: this reverses the "prefer editing over creating" leanness convention.

## Eval: `angular-feature-placement` (the case that would have caught it)

Harness: `.claude/evals/run-agent-evals.ps1`, maintainer-only and `-Live`; it never runs in CI. Run
`-SelfTest` after the runner change and before any `-Live` run (`DEVELOPING.md:326-328`).

- **Precondition (blocking).** `-Live` refuses when the dist stamp differs from the root CHANGELOG
  head (`run-agent-evals.ps1:4133-4135`). Today that is 0.89.2 against `## 0.90.0 — Unreleased`. Run
  both arms from one base where the check holds:
  - a worktree at the `v0.89.2` tag carrying only the scenario and the grader, which is also the text
    consumers have; or
  - the released 0.90.0, before a new Unreleased head opens.

  Build the `-TargetPatch` against that base's `dist/angular`. Some carriers changed after v0.89.2:
  `route-prompt.ps1`, `add-service` and the `feature.md/leanness` snippets.
- **Fixture:** the existing `angular` fixture: `UserService` with `updateProfile` over HTTP, and
  `ProfileFormComponent`, which injects only `FormBuilder` (not `UserService`) and has no submit. No
  fixture change is needed.
- **Prompt**, pre-approved like `angular-form-control`: "Add a profile change history: after each
  successful profile update, record when it happened and which fields changed; keep the last five
  entries in memory for as long as the app is open, so they survive the form being re-created; and
  show them under the profile form. Follow this repository's conventions. No tests needed. I approve
  this change in advance: do not stop for a plan or ask for confirmation -- implement it now, then
  report what you built."
- **Reworked 2026-09-28 (Fable).** The first prompt, draft autosave, did not reproduce the failure: 3
  of 3 component-only on v0.89.2 with Opus 5.5 ($1.64). Autosave is UI state, which both the old and
  the new text keep in the component. The history must outlive the form, so its state sits above the
  component: in `UserService` under the old text, in its own service under the new #1. It routes as a feature
  (`\badd\b`, `route-prompt.ps1:146`). The prompt deliberately drops "in this session" from the
  harness's usual pre-approval wording: that phrase's `session` token trips the Angular security
  overlay (`sensitive-regex`), as it does today for `angular-form-control`.
- **Why this feature:** it has one consumer, a tempting owner (`UserService`, "profile"), no HTTP of
  its own, and state that must outlive the component.
- **Grader.** The scenario entry needs `stack: angular` and a branch in `Test-ScenarioEvidence`.
  - It gates only on the field failure: PASS = not `boltOn` and not `subclass`.
    - `boltOn`: the set of member names declared in `src/app/user.service.ts` grows compared with the
      root commit, or the file gains an `inject(`, a `tap(`, or a `history`, `storage` or `draft` token
      (case-insensitive). Compare member sets,
      not diff lines: a Boy Scout return-type edit on `updateProfile` must not count, and a
      `tap(() => clearDraft())` inside it must.
    - `subclass`: any changed or added file declares `class \w+ extends UserService`.
  - Reported in Detail, not gating:
    - `newInjectable`, scanning changed files as well as added ones, since a second `@Injectable` can
      sit in the component file;
    - `featureInComponent` (the feature's tokens in a component);
    - `featureInOtherInjectable` (the feature's tokens in an `@Injectable` other than `UserService`),
      because a thin service with the logic left in the component also passes the gate;
    - `injectsUserService`;
    - `usedSkill=add-service`.

    A component-only answer is a legitimate third outcome, not the field failure, so it must not
    decide red.
  - INCONCLUSIVE when no `src/app` TypeScript file changed.
  - SelfTest cases:
    - PASS: `ProfileDraftService`;
    - PASS: component-only, reported as such;
    - PASS: a return-type edit on `updateProfile`;
    - FAIL: draft methods on `UserService`;
    - FAIL: `tap(() => clearDraft())` in `updateProfile`;
    - FAIL: `tap(() => recordChange(profile))` in `updateProfile`, with no feature token (caught by `tap(`);
    - FAIL: `extends UserService`.
- **Runs.** Use `-Model opus`: the report concerns Opus 5.5, and the harness defaults to Sonnet
  (`:10`). Set `budgetUsd` to about 1.5; Fable estimates that 1.0 truncates Opus runs to
  INCONCLUSIVE, which is not verified.
  - Unfixed base, `-Trials 3`: red means `boltOn` or `subclass` in at least 2 of 3.
  - Same base with `-TargetPatch` carrying changes 1–9: expected PASS in 3 of 3.
  - If the unfixed base does not go red, the probe does not reproduce the field failure. No diff or
    transcript exists to fall back on, so rework the probe instead, for example with a feature closer
    to `UserService`'s own domain, before building on it.
  - An `-Arm none` control is optional. It needs `bareArm: true`, an update of the self-test pin
    (`:2405-2406`, which lists exactly route-fix, guard-retry, warehouse-route-p1 and
    warehouse-bind-sql), a review of the arm-neutral outcome, and at least 3 trials. The bare target
    has no `AGENTS.md`.
- **Optional second scenario** for the fallback branch. Whether the field case needed another class's
  private logic was not captured. It needs a fixture service with a `private` helper and a prompt
  that forbids changing that service. PASS: the new code is added to that service, with no `extends` and no `private` widened to
  `protected`.

## Decisions — maintainer, 2026-09-28

1. **Field case.** No diff or transcript can be obtained. The agent added members to the existing
   class and made no subclass. The eval's `boltOn` conjunct is the reproduction target; `subclass`
   guards against the fix displacing the failure.
2. **Scope: all three stacks.** The same sentences ship in each.

## Review — Fable, 2026-09-28, and disposition

Fable's verdict: the diagnosis is correct and every carrier quote checks out, but the first draft's #1
left the loophole open, the hook line over-corrected, carriers were missed, and the eval had a
blocking precondition and a gating flaw. Each point below was re-checked against the tree before it
was adopted.

Adopted:

- **Class-name test in #1, extract-by-default, the UI-state clause, and "pure functions are not
  injected".** Adopted (changes 1 and 6; decision points 1, 3 and 4).
- **The hook line becomes a pointer to #1 rather than an absolute.** Adopted (change 5).
- **Missed carriers.** Adopted: `add-service:27`, `register-service:22`, refactor rail `:55`, and
  defaults `:83`/`:200` (verified). Not adopted: `add-signal-store:28`, `add-component:46` and
  `bloat-radar:26` (see "Considered, not changed").
- **.NET SOLID #2 licenses subclassing.** Adopted as change 4 for all three stacks, worded "concrete
  service" to keep framework base types legitimate.
- **"Change 4 moves `prompt.max`" was wrong.** Verified: feature row 2,436 against fix-security
  3,206, so only the rows move. Corrected.
- **Eval.** Adopted after verification:
  - the version precondition (`:4133-4135`);
  - gating on bolt-on and subclass only, with the other outcomes reported;
  - the member-set diff;
  - scanning changed files as well as added ones;
  - the `bareArm` pin (`:2405-2406`);
  - `-Model opus` (default `sonnet`, `:10`).
- **Test paths.** `RoutePrompt.Tests.ps1` lives under `src/core/tests/hooks/`. Verified and
  corrected.
- **The field report was not in `meta/field-reports.md`.** Recorded as report #8.

Not adopted:

- **"Haiku needs a cue" for `solid-check`.** The cue is adopted (change 9), but `solid-check` runs on
  `model: inherit`, not Haiku; `bloat-radar` is the Haiku agent.
- **"No security-overlay word in the prompt."** Wrong. The harness's pre-approval wording, "in this
  session", matches the overlay's `session` token (`sensitive-regex`, `route-prompt.ps1:158`).
  Corrected in the prompt above.

## Outcome — 2026-09-28

Implemented as changes 1-9 in all three stacks (WSD-104). The eval ran from a v0.89.2 clone carrying the scenario and
grader: the history probe bolted onto `UserService` 3/3 unfixed and gave the history its own `ProfileHistoryService`
3/3 with `b311-feature-placement.patch` (`meta/eval-results.md`, 4.09 USD in all, the draft probe included). Dropped as
Fable advised: the `-Arm none` control, the second scenario and any wording iteration.
