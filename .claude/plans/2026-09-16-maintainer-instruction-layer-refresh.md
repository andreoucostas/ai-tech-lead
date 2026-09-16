# B-241 — Maintainer instruction layer refresh (locked design + delivery record)

**Class:** mechanism (edits root rules, `.ps1` tests, `settings.json`). **Filed against:** v0.86.7.
**Decision:** WSD-089. **Baseline:** master `b30d2073` (B-239 committed, `0.87.0 — Unreleased`).
**Branch:** `worktree-b241-maintainer-layer`. Meta-only: no product version bump, no release.
**User decisions (2026-09-16):** invert the root mirror; disable auto-memory; skills wanted, pruned
after critique; primary goal is turnaround time ("impossible to do anything quickly… adding random
tests"); critique the proportionality ladder too.

## 1. Premise re-validation (observed 2026-09-16)

- Root `CLAUDE.md` 330 lines / 25,547 bytes, ~40% incident narrative; hand-condensed `AGENTS.md`
  178 lines gated only by heading topology (`DocTruth.Tests.ps1`, B-82 — its header admits body
  deletions stay green). 35 `CLAUDE.md` commits since 2026-07-01, 32 with a matching `AGENTS.md` edit.
- Host vendor docs (memory, settings, permissions; fetched 2026-09-16): target under 200 lines;
  procedures → skills, path-local → rules; Claude Code reads `CLAUDE.md`, not `AGENTS.md`; documented
  pattern for repos serving both: `CLAUDE.md` = `@AGENTS.md` + Claude-specific section. Keys
  `plansDirectory`, `autoMemoryEnabled`, `attribution`, `defaultShell`, per-hook `shell`/`timeout`,
  and rules `Edit(/dist/**)`, `Bash(git push *)`, `PowerShell(git push *)` confirmed.
- Codex docs (fetched 2026-09-16): `AGENTS.override.md`/`AGENTS.md` concatenated root → cwd,
  `project_doc_max_bytes` 32 KiB with a silent stop; skills from `.agents/skills` (agentskills.io).
  WSD-054 rejects permanent Codex integration → no Codex-side artefacts.
- Process weight from git and `meta/`: 93 tags in ~10 weeks; local gates 11–16 min + CI ≈ 9 min per
  shipped change; last-10 ledger cells ≈ 1,700 chars; closed items 85 S / 34 M / 4 L; 25 meta test
  files added in August; three of the last four "Effort: S" items touched installer/hook/gate policy.
- Environment: all agent hosts (`pwsh`, `powershell`, `claude`, `codex`, `gh`, `node`) resolve by bare
  name; `DEVELOPING.md`'s corrupted-`PATH` section (self-flagged "not re-verified since 2026-07") no
  longer described the machine. `rg` is not on `PATH`.
- Plan mode wrote to the user-level plans directory (no `plansDirectory`); auto-memory on by default
  against the file's self-sufficiency claim (memory directory empty, so no loss).

## 2. Adversarial critique dispositions (two passes, corrections re-verified)

Whole-plan pass: import from a root `CLAUDE.md` uncertified on 2.1.260 → **canary first** (done,
POSITIVE); `plansDirectory` into a tracked dir would be swept by `release.ps1`'s `git add -A` →
**gitignored `inbox`**; `.claude/rules` conflicts with WSD-045/032 and is Codex-invisible → **dropped**;
narrative belongs in `LEARNINGS.md`, rules stay in full with numbering → **accepted**; 24,000-byte
ceiling was false arithmetic → **measured ×1.2**; SessionStart hook uncertified, no harm → **dropped**;
`gates`/`red-test` skills as third carriers → **kept `meta-gates` thin as a convenience, dropped
`red-test`**; deny rules are speed bumps (`& git push` bypasses) → **shipped, disclosed as such**;
validators must be pure fixture functions distinguishing "could not examine" → **accepted**.

Ladder pass: cited skills that did not exist → **Required columns cite existing commands only**;
S/M/L collided with backlog *effort* letters → **records / prose / mechanism / critical**; class was
self-reported → **derived from changed paths, stated in the commit subject, raise-only**; line count
was the wrong axis (`$protected`, retirements, path-wide `ALLOW` are one-line levers) → **artifact
kind, no line count**; "cite the existing gate as red" was rule-4's costume → **"no behavioural
instrument for prose"**; "new test needs a past defect" blocked red-first tests → **case vs file
rule with manifest diff + `TIMING`**; retirement rule unverifiable → **the DocTruth line ceiling is
the displacement mechanism**; docs-only subset omitted `RepositoryPrivacy`/`ClaimTruth` → **added**;
root rule edits are not records → **mechanism**; `BACKLOG.md` common delivery contract would
coexist → **superseded for records/prose in WSD-089**; batching + WSD-057 → **explicit amendment with
a disclosed non-review cell**; consumers clone master → **B-244 filed**; B-237 window → **rule 4**.

## 3. What changed (files)

- `AGENTS.md` — canonical, banner first, change-class table, 7 invariants + 7 rules with numbering
  kept, 194 lines / 16,043 LF bytes at adoption.
- `CLAUDE.md` — banner, `@AGENTS.md`, Claude Code specifics; 23 lines.
- `.claude/settings.json` — `plansDirectory: .claude/plans/inbox`, `autoMemoryEnabled: false`,
  `permissions.deny` ×4, hook `timeout: 30`, explanatory comments. `.gitignore` — inbox, local files.
  `.claude/plans/inbox/.gitkeep`.
- `.claude/skills/meta-review-handoff|meta-release|meta-gates/SKILL.md` — conveniences.
- `.claude/hooks/tests/DocTruth.Tests.ps1` — heading-mapping test removed (natural RED recorded on
  the new files: `'Claude Code specifics' has no mapping`); `Get-RootInstructionTopologyViolations`
  + live and fixture cases; `Get-RootDeliveryFactViolations` retargeted to `AGENTS.md` alone.
- `.claude/hooks/tests/MetaHooks.Tests.ps1` — `Get-SettingsWiringViolations`,
  `Get-SkillFileViolations` + live and fixture cases. `PowerShellTopology.Tests.ps1` — dropped the
  retired `.claude/git-hooks` scan root.
- `.claude/scripts/canary-import-resolution.ps1` — `-ImportTarget` parameter.
- `DEVELOPING.md` — stale `PATH` section replaced (PSModulePath/CP437 recipe kept), `rg` fixed,
  implementer/reviewer practice rewritten, repo-map rows for inbox and skills, pointer updates.
- `README.md`, `meta/review-ledger.md`, `meta/BACKLOG.md` header — pointer updates. `meta/BACKLOG.md`
  B-241 + stubs B-242..B-246. `meta/workspace-decisions.md` WSD-089. `meta/decisions-index.md` two
  lines. `meta/LEARNINGS.md` one entry. `meta/host-certification.md` canary row.
  `meta/eval-session-handoff.md` historical banner.

## 4. Evidence (observed by the implementer; independent re-observation owed — see §6)

- Canary: `canary-import-resolution.ps1 -ImportTarget AGENTS.md -Model haiku` → `sentinel echoed :
  True`, `file tool used : False`, `VERDICT: POSITIVE`, `EXIT=0` (Claude Code 2.1.260, PS 7.6.6).
- Old DocTruth against the new root files (RED before the gate change): `14 passed, 3 failed` —
  heading mapping (`'Claude Code specifics' has no mapping`), delivery facts (`CLAUDE.md omits its
  Status section` ×5 pointers), and a real catch: `AGENTS.md:46: scripts/release.ps1` (fixed to
  `.claude/scripts/release.ps1`).
- MetaHooks under `pwsh`: `14 passed, 0 failed` including the fixture REDs inside the helper cases.
- Remaining runs are appended below as observed.

## 5. Not done here (filed)

B-242 `release.ps1` refusal/preamble wording · B-243 path-kind refusal in the outgoing guard ·
B-244 README clone-at-tag vs pre-release master · B-245 `release.ps1` fast path · B-246 `AgentEvals`
outside CI. Rejected: `.claude/rules`, SessionStart hook, `red-test` skill, Codex-side skills,
reviewer subagent.

## 6. Landing conditions

Full meta suite under `pwsh` and `powershell.exe` with equal non-zero `CASE_COUNT`; one independent
fresh-session review re-observing the planted REDs (mechanism class); merge to `master` only when
master CI is green and no `watch-ci` is pending; push via `.claude/scripts/push-and-check.ps1`; first
CI run green on all eight contexts plus parity; then B-241 moves to `BACKLOG-DONE.md` with its RCA.

## 7. Run log (implementer-observed, 2026-09-16, worktree `worktree-b241-maintainer-layer`)

| Step | Command | Observed |
|---|---|---|
| Canary | `canary-import-resolution.ps1 -ImportTarget AGENTS.md -Model haiku` (nesting variable blanked) | `sentinel echoed : True` · `file tool used : False` · `VERDICT: POSITIVE` · `EXIT=0` |
| Edited `.ps1` files | `check-ps1.ps1` on canary, `PowerShellTopology.Tests.ps1`, `MetaHooks.Tests.ps1`, `DocTruth.Tests.ps1` | all `BOM=True parseErrors=0` |
| Measure | LF-normalised UTF-8 | `AGENTS.md` 194 lines / 16,043 B · `CLAUDE.md` 23 lines / 1,525 B · parent stub 1,003 B · `DEVELOPING.md` 470 lines |
| Natural RED (old DocTruth, new files) | `DocTruth.Tests.ps1` before the gate change | `14 passed, 3 failed`: heading mapping (`'Claude Code specifics' has no mapping`), delivery facts (`CLAUDE.md omits its Status section` + 4 pointers), **and** `AGENTS.md:46: scripts/release.ps1` (real defect; fixed to `.claude/scripts/release.ps1`) |
| New DocTruth | `pwsh` / `powershell.exe` direct / `cmd.exe /d /c "set PSModulePath=&& chcp 437 …"` | `18 passed, 0 failed` on all three legs, `EXIT=0` |
| Live plant 1 | `@AGENTS.md` line in `CLAUDE.md` wrapped in backticks | `[FAIL] … exactly one live '@AGENTS.md' import line outside code; found 0` · `17 passed, 1 failed` · `EXIT=1` · restored byte-identical `True` |
| Live plant 2 | `AGENTS.md` + 10 padding lines | `[FAIL] … root AGENTS.md is 204 lines; ceiling 200` and `AGENTS.md retains a numeric status summary` (padding carried `B-241` under Status) · `EXIT=2` · restored byte-identical `True` |
| MetaHooks | `pwsh` / `powershell.exe` direct / CP437 leg | `14 passed, 0 failed` on all three, `EXIT=0` (fixture REDs exercised inside the helper cases) |
| Adjacent suites (`pwsh`) | BacklogHygiene 10/0 · RepositoryPrivacy 7/0 · ClaimTruth 3/0 · WorkspaceBom 4/0 · PowerShellTopology 3/0 | all `EXIT=0` |
| Full meta suite | `Invoke-HookTests.ps1 -CaseCountPath …` under `pwsh`, then under `powershell.exe` | `0 failure(s) across 36 file(s)` both; 288 s / 220 s; manifests `TOTAL 407` both, byte-identical `True` |
| Not observed in this session | `plansDirectory` inbox write, deny-rule refusals, `/context` memory list | settings load at session start; to be observed in the next fresh session in the repo and recorded here |
