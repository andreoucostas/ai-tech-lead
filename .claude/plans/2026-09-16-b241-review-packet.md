# B-241 — independent-review packet

Produced 2026-09-16 in the shape `/meta-review-handoff` specifies (assembled by hand this once, as
the skill was created in the same change).

## Header

- **Contract:** `.claude/plans/2026-09-16-maintainer-instruction-layer-refresh.md` at the head commit;
  SHA256 `D81B6041BD6229D7D79D5BDA6832343A23F6062806D0736D45DD1434137187B1`.
- **Range:** `b30d2073` (master, B-239 green) → `4e7167e5a90c1e148ec19b3e5db8e9d38059b256`
  (branch `worktree-b241-maintainer-layer`). Immutable; the diff is saved as
  `.claude/plans/inbox/b241-range-b30d2073-4e7167e5.diff` (1,967 lines) for a read-only reviewer.
- **Class:** mechanism — `.ps1` test files, `.claude/settings.json`, root `AGENTS.md`/`CLAUDE.md` rules,
  new maintainer skills. Nothing under `src/` or `dist/`; no shipped behaviour changes.
- **Implementer:** Claude Code (Fable 5.1) session, 2026-09-16, worktree isolated from master.

## Scope statement (B-226: every participant gets the same scope)

Exactly these 22 files; anything outside them is out of scope for this review:
`.claude/hooks/tests/DocTruth.Tests.ps1`, `.claude/hooks/tests/MetaHooks.Tests.ps1`,
`.claude/hooks/tests/PowerShellTopology.Tests.ps1`,
`.claude/plans/2026-09-16-maintainer-instruction-layer-refresh.md`, `.claude/plans/inbox/.gitkeep`,
`.claude/scripts/canary-import-resolution.ps1`, `.claude/settings.json`,
`.claude/skills/meta-gates/SKILL.md`, `.claude/skills/meta-release/SKILL.md`,
`.claude/skills/meta-review-handoff/SKILL.md`, `.gitignore`, `AGENTS.md`, `CLAUDE.md`, `DEVELOPING.md`,
`README.md`, `meta/BACKLOG.md`, `meta/LEARNINGS.md`, `meta/decisions-index.md`,
`meta/eval-session-handoff.md`, `meta/host-certification.md`, `meta/review-ledger.md`,
`meta/workspace-decisions.md`.

## Reviewer prompt (paste verbatim into a fresh session; blind-first order)

You are the independent reviewer for a maintainer-layer change in the ai-tech-lead framework
authoring repository. You did not participate in the implementation. Work in this order and do not
skip ahead:

1. Read the contract `.claude/plans/2026-09-16-maintainer-instruction-layer-refresh.md` sections 1–3
   and 6 only. Do not read section 4, section 7, or any other narrative yet.
2. Write your adversarial threat model for this change before opening the diff: what could this
   change break for a maintainer session (Claude Code or Codex), for CI (PowerShell 7 and native
   Windows PowerShell 5.1), or for the repository's own gates? Name at least three concrete failure
   modes and, for each, the file and assertion that should catch it.
3. Read the diff `.claude/plans/inbox/b241-range-b30d2073-4e7167e5.diff` and the changed files at
   the head commit as needed. Pay particular attention to: (a) the new pure functions
   `Get-RootInstructionTopologyViolations`, `Get-SettingsWiringViolations`, `Get-SkillFileViolations`
   — can any of them return zero violations for an input that is wrong or unexaminable? Is any
   syntax PowerShell-7-only (the suite must run under Windows PowerShell 5.1)? (b) whether any
   binding clause from the previous root `CLAUDE.md` (the `-` side of the diff) was dropped rather
   than restated in the new `AGENTS.md` — list every clause you believe is missing; (c) whether the
   change-class table in `AGENTS.md` classifies these one-line levers as **critical**: `install.ps1`
   ownership/protected/retirement blocks, `scripts/build.ps1`, `release.ps1`,
   `check-outgoing-commits.ps1`, `ci.yml`, a narrowed `DENY` or path-wide `ALLOW`; (d) whether
   anything in the new instructions contradicts a standing decision in `meta/decisions-index.md`
   other than the amendments WSD-089 names explicitly; (e) whether the settings deny rules or the
   `plansDirectory` value could break the maintainer's own workflow (release script staging, the push
   wrapper, worktrees).
4. Only now read contract sections 4 and 7 (the implementer's evidence and run log) and check each
   receipt against the assertion it claims to exercise.
5. Record: your model/agent and version; environment; for each threat you named, whether the diff
   defends it and how you verified that (quote the assertion); every binding clause you believe was
   lost; every finding ranked by severity with file and line; coverage gaps (you executed no tests —
   say so); and a verdict `ACCEPT` / `REVISE` / `REJECT`. Nothing enters your record as observed
   unless you observed it.

## Implementer receipts (read only after step 3)

| Receipt | Observation |
|---|---|
| Import canary | `-ImportTarget AGENTS.md -Model haiku`: `sentinel echoed : True`, `file tool used : False`, `VERDICT: POSITIVE`, `EXIT=0`, Claude Code 2.1.260 |
| Old DocTruth vs new files | `14 passed, 3 failed`: mapping test RED, delivery-facts RED, and `AGENTS.md:46: scripts/release.ps1` RED (real defect, fixed) |
| New DocTruth | `18 passed, 0 failed` under pwsh, powershell.exe direct, and the CP437 leg |
| Live plant 1 | backticked import → `found 0` RED, `EXIT=1`, restored byte-identical |
| Live plant 2 | +10 lines → `204 lines; ceiling 200` RED and numeric-status RED, `EXIT=2`, restored byte-identical |
| MetaHooks | `14 passed, 0 failed` under pwsh, powershell.exe direct, CP437 |
| Full meta suite | `0 failure(s) across 36 file(s)` under both hosts; `TOTAL 407` both; manifests byte-identical |

## `-ReviewEvidence` skeleton (meta-only change: no release, no ledger row; kept for the record)

`contract .claude/plans/2026-09-16-maintainer-instruction-layer-refresh.md SHA256 D81B6041BD6229D7D79D5BDA6832343A23F6062806D0736D45DD1434137187B1; range b30d2073..4e7167e5a90c1e148ec19b3e5db8e9d38059b256; reviewer <agent/model>; independence <no implementation participation; blind-first>; hostile <case> RED; clean <command> EXIT=0; environment/gaps <facts>; implementer Claude Code Fable 5.1 session`
