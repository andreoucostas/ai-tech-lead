---
name: feature
description: "Full feature workflow: plan gate, ordered subtasks with build+test after each, Boy Scout on touched files, self-review against AGENTS.md Conventions. Invoke for new multi-layer functionality when the inline feature rails are not enough."
argument-hint: "[feature description]"
---

Read `AGENTS.md` and `.claude/commands/feature.md` in this repository, then execute the feature workflow defined there for the request below.

`.claude/commands/feature.md` is the single source of truth for this workflow. Follow it exactly: design check → repository-appropriate ordered subtasks → derive and run only evidence-supported **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation** commands between each (report unsupported categories as **not available**) → Boy Scout on touched files → self-review against `AGENTS.md` conventions → present.

## Request

The request is the text after `/feature`, or the feature the developer asked for. Use it wherever `.claude/commands/feature.md` says `$ARGUMENTS`. If there is none, ask what to implement.
