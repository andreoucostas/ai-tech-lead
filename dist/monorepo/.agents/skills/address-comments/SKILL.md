---
name: address-comments
description: "Address the review comments / PR feedback on a pull request: read every open comment, check each claim against the code, propose Fix, Decline, Defer or Ask per claim, then make the fixes. Use for 'address the review comments', 'fix the PR comments'."
argument-hint: "[pull request, or the pasted comments]"
---

Read `AGENTS.md` and `.claude/commands/address-comments.md` in this repository, then execute the address-comments workflow defined there for the pull request below.

`.claude/commands/address-comments.md` is the single source of truth. Follow it exactly: get every open comment → check each claim against the code → post the triage table (Fix, Decline, Defer, Ask) → make the Fix rows → report one line per claim.

## Pull request

The pull request is the text after `/address-comments`, or the one the developer named or pasted. Use it wherever `.claude/commands/address-comments.md` says `$ARGUMENTS`. If there is none, use the current branch's pull request.
