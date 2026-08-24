---
agent: agent
description: Implement a new feature in this repository end-to-end, deriving its technologies and layers from repository evidence.
---

Read `CLAUDE.md` and `.claude/commands/feature.md` in this repository, then execute the feature workflow defined there for the request below.

`.claude/commands/feature.md` is the single source of truth for this workflow. Follow it exactly: design check → repository-appropriate ordered subtasks for the technologies actually present → derive and run only evidence-supported **build**, **test**, **format**, **lint**, **migration/deploy**, and **data-validation** commands between each (report unsupported categories as **not available**) → Boy Scout on touched files → self-review against `CLAUDE.md` conventions → present.

## Request

${input:request:Describe the feature you want implemented}
