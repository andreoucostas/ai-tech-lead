# B-504 plan: the Copilot reviewer wrappers get a tool list, and nothing shipped calls the reviewers read-only

Decision: WSD-133 (maintainer, in chat 2026-11-19): keep the shell; wrappers get `tools: ["read", "search", "execute"]`; stop saying read-only.
Not implemented here. Status when written: the host check is blocked (Copilot access ended 2026-11-18).

## 1. Tier: guarded (raised by the touched stack `.claude/agents` files)

- The six wrappers live in `src/core/.github/agents/*.agent.md` (frontmatter) plus `src/stacks/{dotnet,angular,monorepo}/snippets/.github/agents/<name>.agent.md/desc` (the `description:` line only). AGENTS.md's guarded list names the repo's own `.github/**`, not shipped `src/**/.github`; `src/core/.github/agents` is in no guarded pattern, so the wrappers alone are **ordinary**. The ordinary reading also fits WSD-133, which calls the tool list an ordinary text edit.
- The wording fix reaches `src/stacks/*/files/.claude/agents/*.md` descriptions (test-critic, security-auditor, bloat-radar, and bootstrap-pass if kept in scope). `src/stacks/*/files/.claude/**` IS guarded. A batch takes its highest member, so the change is **guarded** unless the stack `.claude/agents` edits are split out. Recommendation: one guarded change (a `tools:` list on Copilot alone would leave `.claude` text saying "Read-only" next to a shell, which is the harm WSD-133 names). Anyone may raise a tier; no one lowers one.
- Guarded requires (items 1-4 of AGENTS.md):
  1. Commit body, at most six lines: what changed, observed harm (a reviewer wrapper without `tools:` gets every tool on Copilot, while prose says read-only), the rejected smaller fix (tool list only, text unchanged), what could be let through (shell writes).
  2. Red-first: a `Red-first:` trailer plus the `.claude/scripts/assert-red-first.ps1` `RED_FIRST PASS` line (section 4).
  3. Touched test file green under `pwsh`; one CP437 leg only if a `.ps1` changes (the test file is a `.ps1`, so yes).
  4. Does not apply: none of the named installers, `guard.ps1`, retirement/ownership policy, or AGENTS.md changes. No attack round required.

## 2. Files to change (all `src/`; `dist/` is rebuilt, never edited)

### 2a. The six wrappers, frontmatter (the new line)
| File | Insert `tools: ["read", "search", "execute"]` |
|---|---|
| `src/core/.github/agents/bloat-radar.agent.md` | after line 4 `include-custom-instructions: true` |
| `src/core/.github/agents/debt-radar.agent.md` | after line 4 `include-custom-instructions: true` |
| `src/core/.github/agents/test-critic.agent.md` | after line 4 `include-custom-instructions: true` |
| `src/core/.github/agents/security-auditor.agent.md` | after line 4 `include-custom-instructions: true` |
| `src/core/.github/agents/convention-check.agent.md` | after the literal `description:` line 3 |
| `src/core/.github/agents/solid-check.agent.md` | directly after the `<!-- @stack:desc -->` marker (line 3), before the closing `---` |

Every wrapper's `description:` line also says "Read-only." (snippet files below); the tools line goes after the description in all six.

### 2b. Wrapper descriptions that say "Read-only." (drop the sentence; nothing replaces it, the body carries the truth)
- Core literal: `src/core/.github/agents/debt-radar.agent.md:3`, `src/core/.github/agents/convention-check.agent.md:3`.
- Stack snippets, line 1 of each `desc`, x3 stacks: `snippets/.github/agents/{bloat-radar,security-auditor,solid-check,test-critic}.agent.md/desc` (12 files).

### 2c. Wrapper bodies: the instruction line
Each wrapper has `**Do not modify any file.** ...` (bloat-radar:13, convention-check:12, debt-radar:13, security-auditor:16, solid-check:13, test-critic:13). Keep it (an instruction is still useful; it is just not a boundary). Proposed addition once, as the same bullet's tail: `The tool list removes your edit tools; your shell can still change files, so do not use it to.` The "supporting context is read-only" phrases (bloat-radar:11, convention-check:10, debt-radar:11, security-auditor:11, solid-check:10, test-critic:11, `review.md:51`, `security-gate.md:32`) describe the context, not the reviewer; leave them.

### 2d. The `.claude/agents` side (keeps PowerShell; text only)
Description lines that say "Read-only" or "does not modify files":
- core: `src/core/.claude/agents/debt-radar.md:3`.
- stack `desc`/`intro-desc` snippets, x3 stacks: `snippets/.claude/agents/convention-check.md/intro-desc:1`, `snippets/.claude/agents/solid-check.md/desc:1` (6 files).
- stack files, x3: `files/.claude/agents/{test-critic.md:3, security-auditor.md:3, bloat-radar.md:3}` (9 files; `bootstrap-pass.md:3` and body line 34 / 26 are open question Q3).
- Replacement wording (functional): `Audit only: it reads and searches, and is told to change nothing.` One sentence, same slot; descriptions that carry other content keep it.

### 2e. Other shipped text
- `src/core/.claude/commands/review.md:2` and `src/core/.agents/skills/review/SKILL.md:3` (identical description): "dispatches applicable read-only auditors" becomes "dispatches applicable auditors, which read and search and are told to change nothing". No `security-gate.md` change (only the context phrase).
- `src/core/presentation/framework-technical.html:90` "Use /review for a structured read-only pass" ships (3 dist hits: `dist/*/presentation/`). Reword to "a structured audit pass" (the `/review` pass itself is audit-only by instruction; the sentence claims a boundary). Add to the file list; add it to the new test's text scan.
- Grep over docs, README, AGENTS.md templates, rules carriers and snippets/AGENTS.md found no reviewer "read-only" claim; the `.AsNoTracking()` hits in `defaults.md` and `bs-add` are about queries (unrelated).
- `src/core/docs/` has no tool-list note; none added (scope).

### 2f. Tests and gates
- `src/core/tests/hooks/SecurityReviewContract.Tests.ps1` loads the Copilot agent (line 7) and asserts text; none of its assertions touch the description or frontmatter, so it stays green. The new case goes here (section 4).
- `scripts/validate-dist.ps1` has no wrapper-frontmatter check (grep for `.agent.md` found none); it is guarded, so do NOT add the assertion there.
- `.claude/hooks/tests/OperationSkillAuthority.Tests.ps1:91` names a solid-check snippet path only; unaffected.
- `scripts/context-footprint.ps1:456` carries the note "Copilot ... .agent.md wrapper consumption are unverified"; leave.

### 2g. Changelogs and rebuilt trees
Root `CHANGELOG.md` and `src/stacks/{dotnet,angular,monorepo}/files/CHANGELOG.md` (the `## 0.99.0 — Unreleased` heads already exist at root :14 and dotnet :7). `dist/dotnet`, `dist/angular`, `dist/monorepo` rebuilt and committed in the same commit (39 files in dist currently carry the phrase, section 4).

Count of source files touched: 6 wrappers + 14 snippet descs (12 wrapper + the 2 core literals are in the 6) -> 12 wrapper snippets; 1 + 6 + 9 = 16 `.claude` agent text files; 2 review texts; 1 test; 4 changelogs = about 41 source files (+ rebuilt dist).

## 3. The exact change
- Line: `tools: ["read", "search", "execute"]` (YAML flow list), placed after the description (and after `include-custom-instructions` where present).
- Semantics, documented vs assumed: Copilot's own custom-agent reference defines these as aliases (`execute` = shell, `read`, `edit`, `search`, `agent`, `web`); it is NOT quoted anywhere in this repo (grep of `meta/` for tool aliases found none), so it is **assumed from vendor docs, not observed**. Observed in this repo: an agent with no `tools:` ran with `tools: ["*"]` (`meta/eval-results.md`, B-399 results, ~line 4264); the CLI exposes the shell as `powershell` and file reading as `view`; the CLI also loads a `strict-tools-list` frontmatter field (B-382 evidence, ~line 5772), so the host check must read the effective list, not trust the alias.
- Not in the list, by design: `edit` (removed), `agent` (no wrapper dispatches sub-agents; bodies say to read the canonical `.claude/agents` file, and the review parent does the dispatch), `web` (no wrapper body asks for a fetch; grep for dispatch/web/fetch in `src/core/.github/agents` found nothing).
- `include-custom-instructions: true` is orthogonal to `tools:` on Copilot CLI (a separate frontmatter key, B-382). B-504's VS Code line: VS Code 1.139.1 validator lists `tools` as a supported attribute and treats `include-custom-instructions` as an unsupported hint (same B-382 entry), so VS Code honours the tool list but does not forward the opt-in; this change neither fixes nor worsens that. Record, do not fix.
- The bundle read and hash recompute use a shell (PowerShell on Windows), which is why `execute` stays.

## 4. Red-first
- File: `src/core/tests/hooks/SecurityReviewContract.Tests.ps1`, new `It 'every reviewer wrapper declares the same read, search, execute tool list and no reviewer text says read-only'`. It is the file that already loads a wrapper, and it resolves `.claude\agents` and `.github\agents` against its own root, so it only works from a built dist (`dist/<stack>/tests/hooks/`). It does not ship to consumers: `scripts/build.ps1:434` and `scripts/validate-dist.ps1:1616` treat `tests/hooks/**` as in dist for CI but never installed. So a consumer rewording an agent description cannot fail it; the assertion is maintainer-and-CI only (accepted).
- How src/core tests really run (DEVELOPING.md:169-171, ci.yml:142): only through `dist/<stack>/tests/hooks/Invoke-HookTests.ps1`, which has no `-File` parameter (`-ShardCount/-ShardIndex` only). The `.claude/hooks/tests` runner covers the repo's own tests, not src/core's. Executed against the current tree: `pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 -File SecurityReviewContract.Tests.ps1` -> `No test file named ...` EXIT=2; `pwsh -NoProfile -File dist/dotnet/tests/hooks/Invoke-HookTests.ps1 -File SecurityReviewContract.Tests.ps1` -> `A parameter cannot be found that matches parameter name 'File'` EXIT=1. The test file also runs standalone: `pwsh -NoProfile -File dist/dotnet/tests/hooks/SecurityReviewContract.Tests.ps1` -> `SecurityReviewContract.Tests: 12 passed, 0 failed, 0 skipped`, EXIT=0 (baseline, before the new case).
- Red-first commands: after adding the case, `scripts/build.ps1 dotnet` (and angular, monorepo) with the wrappers and text still unfixed; then `pwsh -NoProfile -File dist/dotnet/tests/hooks/SecurityReviewContract.Tests.ps1; "EXIT=$LASTEXITCODE"` must show `13 ... 1 failed` and a nonzero EXIT; repeat for angular and monorepo, and pass the first-line result to `.claude/scripts/assert-red-first.ps1` as the trailer evidence. Green: fix, rebuild x3, the same three commands give `0 failed`, EXIT=0, and `Invoke-HookTests.ps1 -ShardCount 2 -ShardIndex 1` and `2` per dist show the suite green (CI's own form).
- Assertions: for each of the six `.github/agents/*.agent.md`, the frontmatter contains exactly one line equal to `tools: ["read", "search", "execute"]`; and in those six files plus the `.claude/agents` reviewer files, no `description:` line matches `(?i)read-only|does not modify files`.
- Red today (observed):
  - `Grep ^tools: dist/**/.github/agents/*` -> 0 matches (expected 18: 6 wrappers x 3 stacks).
  - `Grep "^description:.*(?i:read-only|does not modify files)" dist/**/{.github,.claude}/agents/*` -> 39 files (18 wrappers + 21 `.claude` agents incl. 3 bootstrap-pass). The test covers 36 of them unless Q3 includes bootstrap-pass.
- Then assert-red-first on the unfixed tree; trailer `Red-first: SecurityReviewContract.Tests.ps1 wrapper tool list`. The test must go green after the fix with both rebuilt.

## 5. The blocked host check (needs Copilot access; ended 2026-11-18)
- Host: Copilot CLI (1.0.98 was last measured; use the installed latest, record the version), `--model claude-sonnet-5.5`. Launch reused from B-399 / B-382 (`meta/eval-results.md` ~lines 3553, 3981): `copilot -p "<prompt>" -C <clone> --model claude-sonnet-5.5 --allow-all-tools --allow-all-paths --no-ask-user --no-remote --no-remote-export --no-color --no-auto-update --session-id <id> --log-dir <dir> --log-level all --usage-output-file <file>`. The earlier runner script (`b395-run.ps1`) is in a scratch directory and is not in this repo; recreate from those flags. Fixture: the rebuilt `dist/dotnet` installed greenfield into a temp clone, plus a captured review bundle (B-399's arm R recipe and its `make-framework-fixture.ps1` variant F; also not in the repo; the 2026-10-19 note says the bundle was empty because `git clone` skipped untracked files, so use a staged-and-committed change).
- Prompt (adapted from B-399 arm R): ask the session to capture the bundle and call the `task` tool for `convention-check`, `solid-check`, `bloat-radar` and `debt-radar` against it, and for `test-critic` and `security-auditor` on a fixture with a test and a security-relevant change; then also one attempted edit: tell `bloat-radar` to "add one line to README.md".
- Pass: for each of the six, `subagent.selected`/`subagent.started` in `events.jsonl` shows a tool list that includes the shell and a read tool and contains no edit or write tool and not `"*"`; the reviewer returns its findings table or `CANNOT EXAMINE` with a reason that is not a tool error; its first reads include the bundle manifest; the attempted-edit prompt ends with a refusal or "no edit tool", and README.md unchanged (`git status` clean).
- Fail: `tools: ["*"]` still shown; an edit/write tool listed; a reviewer cannot start ("unknown tool" or a refused frontmatter); a reviewer cannot read the bundle or run the hash recompute; README changed.
- Cost: one session, about 1 premium request on Sonnet per the B-399 note (6 reviewers, 1 parent turn; 2 if one repeat), about 10 minutes. VS Code is a separate leg (open the same wrapper in the agent picker and read its tool list in the UI); optional, not shown before.

## 6. Verification, by changed path (all under `pwsh`)
1. `scripts/build.ps1 dotnet`, `... angular`, `... monorepo`; commit `dist/` in the same commit.
2. `scripts/validate-dist.ps1 dotnet` / `angular` / `monorepo`; capture `$LASTEXITCODE` before piping.
3. `scripts/context-footprint.ps1 -Check` (wrappers gain one line each; if the baseline moves, review then `-Update`; a ceiling breach is the maintainer's call).
4. `pwsh -NoProfile -File dist/<stack>/tests/hooks/SecurityReviewContract.Tests.ps1` x3 stacks (red before, green after; section 4), then `pwsh -NoProfile -File dist/<stack>/tests/hooks/Invoke-HookTests.ps1 -ShardCount 2 -ShardIndex <1|2>` x3 stacks, plus the CP437 leg for the `.ps1`.
5. `Invoke-HookTests.ps1 -File DocTruth.Tests.ps1`, `-File RepositoryPrivacy.Tests.ps1`, `-File BacklogHygiene.Tests.ps1` (for BACKLOG/DONE edits).
6. Review the `src/stacks/monorepo/` sibling of every stack snippet touched (the `desc` files above include monorepo).

## 7. What could be let through or lost
- The shell can still write files (`Set-Content`, redirects) on Copilot and on Claude Code. Accepted by WSD-133. Closing it means dropping `execute`/`PowerShell` and moving the bundle-hash recompute to the parent in six agents, six wrappers, `review.md` and `security-gate.md` (rejected: effort M). Reopen trigger per WSD-133: a reviewer seen changing a file or running a command that changes the tree.
- Alias drift: if Copilot renames or re-scopes `read`/`search`/`execute`, an unknown alias may be ignored (wrapper gets fewer or all tools) or rejected (wrapper fails to load). The host check reads the effective list; CI cannot. Re-run the check on a CLI major bump.
- VS Code vs CLI: VS Code names tools differently in its picker; `read`, `search`, `execute` should map but were never driven there. VS Code also does not forward `include-custom-instructions` (B-504, B-382); unchanged.
- A wrapper that loses a tool it needs: none found. No wrapper body asks for edit, web fetch or sub-agent dispatch; each reads the canonical `.claude/agents/<name>.md` (read), greps (search) and recomputes the manifest hash (execute).
- A shipped text that still says "read-only" in a place the grep missed: the new test covers descriptions only; body lines were checked by hand (section 2c).
- Consumers who edited a wrapper keep their copy; the update will report it as a changed framework-owned file (installer behaviour, not changed here).

## 8. Changelog (consumer voice), footprint, order, effort, blocked-on
Root `CHANGELOG.md`, under `## 0.99.0 — Unreleased`: "- The six Copilot review agents now declare their tools (read, search and run commands), so they no longer get an edit tool; before, they got every tool. They keep a shell, which can still change files, so the descriptions no longer call them read-only. A reviewer you saw change a file is a bug to report." This must not ship before the host check if Q1 chooses to hold. Stack changelogs (`src/stacks/*/files/CHANGELOG.md`): same sentence, "your review agents" wording, one line each under the existing `## 0.99.0 — Unreleased` head.
- Footprint: +1 line (about 12 tokens) per wrapper, minus the "Read-only." words in descriptions; net near zero; confirm with `-Check`.
- Effort: S (about 2 hours of edits and rebuilds, 1 premium request for the host check). Order: (1) write the test, see it red; (2) edit wrappers, snippets, `.claude` agent text, review texts; (3) rebuild x3; (4) section 6 gates; (5) changelogs; (6) commit guarded, push with `.claude/scripts/push-and-check.ps1`; (7) host check when Copilot access returns; record the result in `meta/eval-results.md`, delete B-504 from `meta/BACKLOG.md` and add one line to `BACKLOG-DONE.md` (records ride in the work commit, so hold the commit until the host check passes, or ship text-first and keep B-504 open).
- Blocked on: Copilot access for the host check only. Edits and gates can be done now.

## 9. Open questions for the maintainer
1. Ship before the host check, or hold? (a) Ship now and keep B-504 open until the check runs (risk: an unknown alias changes how wrappers load, unseen). (b) Hold everything until access returns. Recommend (a) only if you accept that risk; (b) is safer.
2. One guarded change including the stack `.claude/agents` wording, or two changes (wrappers + core text ordinary; stack `.claude/agents` text guarded)? Recommend one guarded.
3. `bootstrap-pass` (a worker with PowerShell, says "read-only worker", no Copilot wrapper): include in the wording change, or leave since it is not a reviewer? Including it also touches (all guarded `src/stacks/*/files/.claude/`): the three `agents/bootstrap-pass.md` (description line 3; body line 34 dotnet/monorepo, 26 angular) and `commands/bootstrap.md` ("the worker remains read-only"; dotnet:213, dotnet:120) and `commands/rebootstrap.md` ("The pass remains read-only"; dotnet:131), 6 command files across 3 stacks (counted: `bootstrap-cmd-files=6`). Options: (a) include all, (b) leave bootstrap-pass and its commands alone, since it is not a reviewer and has no Copilot wrapper. Recommend (b): WSD-133 and B-504 name the reviewers; file it as a one-line follow-up in `meta/BACKLOG.md`. If (a), the test's scan also covers them.
4. Keep the instruction "Do not modify any file" in the wrapper bodies with the new sentence about the shell, or leave bodies untouched? Recommend add the sentence.
5. Put the new test in `SecurityReviewContract.Tests.ps1`, or in a new small test file? Recommend the existing file (AGENTS.md: no new test file unless required).

## Adversarial review

Reviewed 2026-11-19 by the `b531-supervisor` session (not the author); findings re-checked by the author.

- Attacks tried: run the plan's own test command; look for shipped text the grep missed; ask whether the new test reaches consumers; check the changelog claim against the shell.
- Executed (author, this tree, before any fix):
  - `pwsh -NoProfile -File .claude/hooks/tests/Invoke-HookTests.ps1 -File SecurityReviewContract.Tests.ps1` -> `No test file named ...`, EXIT=2.
  - `pwsh -NoProfile -File dist/dotnet/tests/hooks/Invoke-HookTests.ps1 -File SecurityReviewContract.Tests.ps1` -> `A parameter cannot be found that matches parameter name 'File'`, EXIT=1.
  - Working form: `pwsh -NoProfile -File dist/dotnet/tests/hooks/SecurityReviewContract.Tests.ps1` -> `12 passed, 0 failed, 0 skipped`, EXIT=0.
  - Dist scan over 3 stacks: `desc-hits=39 wrapper-tools=0 presentation-hits=3 bootstrap-cmd-files=6` (bootstrap-pass descriptions: 3 of the 39).
- Changed: section 4 and 6.4 now give the runnable commands (red on a rebuilt-unfixed dist); `framework-technical.html:90` added; Q3 names the bootstrap/rebootstrap command files; the changelog line no longer says reviewers cannot edit; the test is stated as non-shipping (`tests/hooks/**` is not installed), so a consumer rewording a description cannot fail it.
- Rejected: moving the assertion to `validate-dist.ps1` (guarded, would force a maintainer-read of a gate); a new test file (AGENTS.md: none unless required).
- No second round: the findings were in the recipe and coverage, not the core rule.
