---
description: "Full feature workflow: plan gate, ordered subtasks with build+test after each, Boy Scout on touched files, self-review against CLAUDE.md Conventions. Invoke for new multi-layer functionality when the inline feature rails are not enough."
argument-hint: "[feature description]"
---

Implement a new feature in this repository. Derive its applicable technologies, layers, and validation from repository evidence; do not infer Angular from this framework distribution. Every decision must comply with the conventions and patterns in CLAUDE.md.

## Input
$ARGUMENTS

## Execution

### Step 1 — Design check

**Check for a spec first.** If `specs/<slug>.md` exists for this work, read it and treat it as the contract — implement against its acceptance criteria, scope, and chosen approach, **working through its Tasks checklist and checking off each `- [ ]` → `- [x]` in the spec file as you complete it** (so progress survives across sessions), and flag any deviation. If the feature is non-trivial and no spec exists, recommend `/design` first (it writes one). For small changes, proceed without a spec.

Before writing any code, reason through:
- Which layers are affected (models, services, state, components, routing)?
- What existing patterns should be reused? Check Common Tasks in CLAUDE.md and the relevant skill in `.claude/skills/`.
- What are the failure modes?
- What tests will verify success?
- **Leanness check** (the framework rules (`.github/instructions/framework-rules.instructions.md` › Leanness; `AGENTS.md` › Leanness on AGENTS.md-native tools)): can this fit in existing files? Are you tempted to introduce a new interface / helper / pipe / directive — is there a second consumer in this change-set? If not, defer the abstraction.

If the feature touches a clear file or area, spawn the `debt-radar` subagent via `Task` to surface bundleable TECH_DEBT entries before you scope the work. Fold any "Yes — same blast radius" entries into the plan when the marginal effort is small.

State the plan: files to create/modify, order of operations, test strategy, debt being bundled (if any).

### Step 2 — Execute in subtasks
Decompose into ordered subtasks. Execute each fully before starting the next:

1. **Models/interfaces** — data shapes, DTOs, enums + type tests if complex
2. **Service/state layer** — HTTP services, stores/signals, business logic + unit tests
3. **Component layer** — smart and dumb components, templates, styles + component tests
4. **Integration/E2E** — end-to-end verification of the feature flow

Before the first subtask, derive exact **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation** commands from `CLAUDE.md`, committed CI, scripts, manifests, and configuration. After each subtask, run only commands applicable to the changed area. An Angular profile establishes only profile applicability; use any command, target, runner, browser, project, configuration, or flags only when that exact full form is explicitly recorded in the evidence. Record every category without a supported command as **not available**; fix applicable-command failures before the next subtask. Never leave the codebase in a broken state.

### Step 3 — Boy Scout
Apply the Boy Scout Rule (CLAUDE.md > Boy Scout Rule) to every file you modified. Mandatory.

### Step 4 — Wrap up
@.claude/workflow.md

### Step 5 — Present
Summarise what was implemented, what was tested, and any documentation drift to flag.
