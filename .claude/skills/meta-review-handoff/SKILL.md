---
name: meta-review-handoff
description: Assemble the independent-review packet for a maintainer change — frozen contract SHA256, immutable commit range, computed change class, blind-first reviewer prompt, and the -ReviewEvidence skeleton — and save it under .claude/plans/. Use before handing a change to a fresh reviewer session (Claude Code, Codex, or ChatGPT).
argument-hint: <contract-path> <base>..<head>
allowed-tools: PowerShell(Get-FileHash *) PowerShell(git *) Read Write
---

# Independent-review packet

You are assembling the packet a **separate** reviewer session works from. Maintenance model #2
(root `AGENTS.md`) requires the reviewer to start from the frozen contract and immutable range
*before* reading any implementation narrative. This skill produces that starting point and nothing
else: it never invokes `codex`, never launches a reviewer, and never runs tests (WSD-054).

Arguments: `$ARGUMENTS` = `<contract-path> <base>..<head>`. If either is missing, stop and ask.

## Steps

1. **Resolve the inputs.** Fail loudly on any of these; do not guess.
   - The contract file exists; compute `Get-FileHash -Algorithm SHA256 <contract-path>`.
   - `git rev-parse <base>` and `git rev-parse <head>` resolve; record the full SHAs.
   - `git diff --stat <base>..<head>` is non-empty.
2. **Compute the change class** from the changed paths (`git diff --name-only <base>..<head>`) using
   the table in root `AGENTS.md` ("Change classes"). The class is the highest kind any path matches.
   Record `class <name>: <paths>`.
3. **Write the packet** to `.claude/plans/<yyyy-MM-dd>-<slug>-review-packet.md` where `<slug>` is
   taken from the contract file name. Contents, in this order:
   - **Header**: contract path + SHA256; range as full SHAs; computed class; implementer identity
     (as supplied by the user, or "not supplied").
   - **Scope statement**: the exact file list in the range. Anything outside it is out of scope for
     this review (B-226: every participant gets the same explicit scope).
   - **Reviewer prompt** (blind-first order, to be pasted verbatim into the fresh session):
     1. Read the contract at the recorded SHA256. Do not read any plan, report, or narrative yet.
     2. Write your adversarial threat model for this change *before* opening the diff.
     3. Run `git diff <base>..<head>` and inspect the changed files at `<head>`.
     4. Only now, if needed, read the implementer's narrative.
     5. Record: your model/agent and version; environment (OS, PowerShell 7 and 5.1 versions);
        one release-specific hostile case or applied mutation you observed **RED**, with the exact
        command and exit code; the clean rerun with `EXIT=0`; coverage gaps; a scope check (is
        every changed function required by the contract? justify or flag extra surface);
        verdict `ACCEPT` / `REVISE` / `REJECT` with findings ranked by severity.
     6. Nothing enters your record as observed unless you observed it (Maintenance model #3).
   - **`-ReviewEvidence` skeleton**, exactly this grammar (from `.claude/scripts/release.ps1`):
     `contract <path> SHA256 <hash>; range <base-sha>..<head-sha>; reviewer <agent/model>; independence <no implementation participation; blind-first>; hostile <case> RED; clean <command> EXIT=0; environment/gaps <facts>; implementer <who>`
4. **Report** the packet path and how to hand it over: paste the reviewer prompt into a fresh
   session (Claude Code in a separate terminal, Codex, or ChatGPT). Do not start that session
   yourself.

## Constraints

- Prose class (see root `AGENTS.md`) does not require this packet; say so if the computed class is
  `prose` or `records`, and stop unless the user still wants one.
- Never include the implementer's narrative inside the packet; link it after the prompt if asked.
- Never invoke `codex` or `claude` from this skill.
