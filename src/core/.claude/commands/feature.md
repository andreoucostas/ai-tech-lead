---
description: "Full feature workflow: plan gate, ordered subtasks with build+test after each, Boy Scout on touched files, self-review against CLAUDE.md Conventions. Invoke for new multi-layer functionality when the inline feature rails are not enough."
argument-hint: "[feature description]"
---

<!-- @stack:intro -->

## Input
$ARGUMENTS

## Execution

### Step 1 — Design check

**Check for a spec first.** If `specs/<slug>.md` exists for this work, read it and treat it as the contract — implement against its acceptance criteria, scope, and chosen approach, **working through its Tasks checklist and checking off each `- [ ]` → `- [x]` in the spec file as you complete it** (so progress survives across sessions), and flag any deviation. If the feature is non-trivial and no spec exists, recommend `/design` first (it writes one). For small changes, proceed without a spec.

Before writing any code, reason through:
<!-- @stack:layers -->
- What existing patterns should be reused? Check Common Tasks in CLAUDE.md and the relevant skill in `.claude/skills/`.
- What are the failure modes?
- What tests will verify success?
<!-- @stack:leanness -->

If the feature touches a clear file or area, spawn the `debt-radar` subagent via `Task` to surface bundleable TECH_DEBT entries before you scope the work. Fold any "Yes — same blast radius" entries into the plan when the marginal effort is small.

State the plan: files to create/modify, order of operations, test strategy, debt being bundled (if any).

### Step 2 — Execute in subtasks
Decompose into ordered subtasks. Execute each fully before starting the next:

<!-- @stack:subtasks -->

<!-- @stack:verify -->

### Step 3 — Boy Scout
Apply the Boy Scout Rule (CLAUDE.md > Boy Scout Rule) to every file you modified. Mandatory.

### Step 4 — Wrap up
@.claude/workflow.md

### Step 5 — Present
Summarise what was implemented, what was tested, and any documentation drift to flag.
