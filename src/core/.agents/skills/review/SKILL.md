---
name: review
description: "Tech-lead quality gate on one frozen review bundle: dispatches applicable read-only auditors, derives and runs repository-evidenced verification, applies senior judgement, and returns APPROVE or REQUEST CHANGES. Invoke when completed work needs the full gate, not for a quick inline question."
argument-hint: "[files (uncommitted filter) | whole-files: files | A..B | A...B; empty = uncommitted changes]"
---

Read `AGENTS.md` and `.claude/commands/review.md`, then execute the review workflow defined there for the scope below. Plain files restrict `Uncommitted`; reserve `whole-files:` for explicitly labelled whole-file review, using the one JSON-array `-PathFile` shape. Create the required frozen `-ScopePath` only at a fresh absent temporary path; hand its manifest SHA-256 alongside that same path to every applicable reviewer, which must recompute `manifest.json` SHA-256 and reject mismatch as `CANNOT EXAMINE`. Immediately before the `-ScopePath` scanner call, the parent recomputes and compares that recorded manifest hash; the scanner validates artifacts against its manifest. Never recompute a diff or substitute a host/PR lookup. When concurrent agents are unavailable, run every applicable reviewer sequentially against that same bundle. Any invalid/unreadable scanner or bundle result is `CANNOT EXAMINE`, not an approval.

<!-- @stack:summary -->

Be direct. Do not praise code for meeting baseline expectations.

## Scope

The scope is the text after `/review`, or the change the developer asked to review: plain files restrict uncommitted changes; `whole-files:` files; an explicit `A..B` or `A...B`; none means the uncommitted changes. Use it wherever `.claude/commands/review.md` says `$ARGUMENTS`.
