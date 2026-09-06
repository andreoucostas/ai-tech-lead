---
agent: agent
description: Review code as a senior tech lead. This is a quality gate, not a rubber stamp.
---

Read `CLAUDE.md` and `.claude/commands/review.md`, then execute the review workflow defined there for the scope below. Plain files restrict `Uncommitted`; reserve `whole-files:` for explicitly labelled whole-file review, using the one JSON-array `-PathFile` shape. Create the required frozen `-ScopePath` only at a fresh absent temporary path; hand its manifest SHA-256 alongside that same path to every applicable reviewer, which must recompute `manifest.json` SHA-256 and reject mismatch as `CANNOT EXAMINE`. Immediately before the `-ScopePath` scanner call, the parent recomputes and compares that recorded manifest hash; the scanner validates artifacts against its manifest. Never recompute a diff or substitute a host/PR lookup. When concurrent agents are unavailable, run every applicable reviewer sequentially against that same bundle. Any invalid/unreadable scanner or bundle result is `CANNOT EXAMINE`, not an approval.

<!-- @stack:summary -->

Be direct. Do not praise code for meeting baseline expectations.

## Scope

${input:scope:Files restrict uncommitted; whole-files: files; explicit A..B or A...B; or leave blank}
