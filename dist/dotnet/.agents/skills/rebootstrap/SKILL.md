---
name: rebootstrap
description: "Re-align the framework after drift: refresh conventions, hazards, and bounded repository-knowledge discovery against the current codebase; respects declined-recipe history in LEARNINGS.md. Developer-initiated only."
disable-model-invocation: true
---

Read `AGENTS.md` and `.claude/commands/rebootstrap.md` in this repository, then execute the rebootstrap workflow defined there.

`.claude/commands/rebootstrap.md` is the single source of truth for this workflow. Follow it exactly: pre-flight check → baseline pre-step (stop when nothing changed) → re-analysis (A1–A8; each profile full or incremental) → delta synthesis → diff-aware merge with user confirmation per chunk → re-record the baseline → final report.

## Request

The request is the text after `/rebootstrap`, such as `full`. Use it wherever `.claude/commands/rebootstrap.md` says `$ARGUMENTS`; there may be none, and then the command's baseline pre-step decides what runs (`full` forces a full run).
