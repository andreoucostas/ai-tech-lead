# B-490: the guard refuses writes that would switch the guard off (WSD-132)

Plan only; nothing implemented. Read: `AGENTS.md`, `meta/BACKLOG.md` B-490, WSD-132 and WSD-135 (last sentence), brief section B-490,
`src/core/.claude/hooks/guard.ps1`, `src/core/.github/hooks/hooks.json`, `src/stacks/*/files/.claude/settings.json`,
`src/core/tests/hooks/Guard.Tests.ps1`, `.claude/scripts/assert-red-first.ps1`, `DEVELOPING.md`, `adopt.md`, `docs/upgrade-checklist.md`.

## 0. The rule in plain words

An agent file write is refused in two cases. (1) It targets `.claude/hooks/*.ps1` or `.github/hooks/hooks.json`, at all.
(2) It targets `.claude/settings.json` and the file it would produce no longer registers `guard.ps1` as a PreToolUse hook that covers
Write and Edit (or turns hooks off, or is not valid JSON, or the guard cannot work the result out). Every other settings edit
(a permission, `model`, `env`, another hook) passes. The developer is told to make the change by hand.

## 0a. What this block does not stop (plain words)

The block covers the agent's **file-editing tools** only. A shell command that rewrites `.claude/settings.json`, a hook script or `.github/hooks/hooks.json` is **let through on both surfaces**.
- **Claude Code:** the guard is registered for the tools `Write`, `Edit` and `NotebookEdit` only (the `PreToolUse` matcher). A shell tool call (Bash or PowerShell) is never sent to the guard, and `MultiEdit` is not either.
- **Copilot:** the `preToolUse` entry has no matcher, so every tool event can be sent to the guard (whether a given Copilot host does so for its shell tool is not determined here). But the guard never
  reads a shell command: `guard.ps1` looks at file paths and file text, and the only `command` field it reads (lines 86, 379) is the text-editor tool's `create`/`str_replace`/`insert`. A shell event has neither a path nor text, so it exits 0.
- **Observed (this session, 2026-11-19, pwsh into `dist/dotnet/.claude/hooks/guard.ps1`):** Copilot shape `{"toolName":"powershell","toolArgs":{"command":"Set-Content -Path .claude/settings.json -Value '{\"hooks\":{}}'"}}` gives no output and `EXIT=0`;
  Claude shape `{"tool_name":"PowerShell","tool_input":{"command":"<same>"}}` gives `EXIT=0`. This plan changes neither result.
- Closing it would take: reading shell command text in the guard (a pattern for redirection, `Set-Content`, `Out-File`, `sed -i`, `git checkout`, `mv`, a script written then run, which can never be complete), plus, on Claude Code, adding Bash and PowerShell to the registered
  matcher, which changes a registered entry the installer recognises by digest (guarded installer work, step 4 for it) and sends every shell call through the guard (a `pwsh` start per command, and a stall if it fails). WSD-132 chose to let the shell through; this is question 4, not a scope change.

Added to scope 2026-11-19 (maintainer, in chat): the **shipped** guard's credential rule can be passed today with an 8.3 alias (reported by the round-2 attacker, then run 2026-11-19 on the dist/dotnet guard). A long `src\test+cfg.json` write
is refused (`EXIT=2`); the short `src\TEST_C~1.JSO` gets `EXIT=0`, because the alias turns `+` into `_` and matches the test-path exemption. Low impact: non-test names and their aliases are blocked. The short-name resolution this plan adds in 3.2 step 3 should also be applied to the credential rule's path, and fixed in this item.
Open question for the implementer: whether the credential rule can reuse the same resolution function or needs its own call before it classifies the path.

## 1. Tier and what guarded requires

Tier **guarded**: `guard.ps1` and `src/core/.claude/hooks/**` are on the list, and AGENTS.md step 4 names `guard.ps1`. Commit subject starts `guarded:`.
1. Commit body, at most 6 lines: what changed; observed harm (a `Write` of `{ "hooks": {} }` to `.claude/settings.json` exits 0, section 4);
   smaller fix rejected (block every write to `settings*.json`: stops `/adopt`'s and a team's own settings edits, WSD-132); what could be let through
   (shell writes, the unrouted tools in section 6).
2. `Red-first: src/core/tests/hooks/Guard.Tests.ps1::<exact case name>` trailer per new case, then
   `pwsh -NoProfile -File .claude/scripts/assert-red-first.ps1` and paste its `RED_FIRST PASS declared=n red_on_parent=n green_on_commit=n` line.
   It clones, runs the case on the parent, reads `[FAIL]`/`[ok]` marks, never an exit code. Case names must not contain `--` (the mark regex).
3. Touched test files green under `pwsh`: `pwsh -NoProfile -File src/core/tests/hooks/Guard.Tests.ps1` and `Guard2.Tests.ps1` (the harness suites run
   standalone; `Invoke-HookTests.ps1` there takes no `-File`), plus `.claude/hooks/tests/Invoke-HookTests.ps1 -File GuardPatternErrors.Tests.ps1`
   (it mutates `guard.ps1` patterns). One CP437 leg because a `.ps1` changed, from `DEVELOPING.md` line 255, aimed at the new test file:
   `cmd.exe /d /c "chcp 437 >nul && pwsh -NoProfile -File src\core\tests\hooks\Guard.Tests.ps1"`. CI runs the rest on every host.
4. Step 4: the maintainer reads the diff and says so in their own words, OR a fresh session that did not implement it attacks the diff and reports one
   executed attack (one round, ~30 min, on the diff and its stated risk; a second round if it found a defect). No agent records the maintainer's approval.
   Recommendation: the fresh-session attack, aimed at section 6's list plus path spelling (section 3).

## 2. Files to change

Under `src/` (author once; `dist/` is rebuilt, never hand-edited):
- `src/core/.claude/hooks/guard.ps1`: the rule (section 3). Reaches `dist/{dotnet,angular,monorepo}/.claude/hooks/guard.ps1` via `scripts/build.ps1`. No stack snippet
  or `src/stacks/monorepo/` sibling exists for `guard.ps1` (checked: `grep guard.ps1 src/stacks/*/snippets` is empty).
- `src/core/tests/hooks/Guard.Tests.ps1`: new cases after the allowlist block (~line 552-600, same `New-AllowlistedRoot`/`Copy-HookInto` temp-root pattern).
  `Guard2.Tests.ps1` only if the Copilot leg is split there. Both reach `dist/*/tests/hooks/`.
- `src/core/docs/enforcement-surfaces.md`: one line in the scope caveat (~line 161-178) and the guard-allowlist paragraph (~295): the guard refuses these writes; the shell
  and unrouted tools are still not read. Core file, so it reaches all three dists (no monorepo docs sibling; `src/stacks/monorepo/snippets/docs/` has
  getting-started/playbook/reference only; not touched).
- `src/core/docs/upgrade-checklist.md` step 6 / uninstall step 3: one clause "an agent cannot edit the hook registrations; do it by hand".
- Root `CHANGELOG.md` and `src/stacks/{dotnet,angular,monorepo}/files/CHANGELOG.md`: `## 0.99.0 — Unreleased` heads already exist; add one bullet each (section 7).

NOT changed: `src/stacks/*/files/.claude/settings.json` and `src/core/.github/hooks/hooks.json`. Both surfaces already register the guard:
Claude Code `PreToolUse` matcher `Write|Edit|NotebookEdit` (settings.json lines ~25-30), Copilot `preToolUse` with **no matcher** (the file's `_comment`: names vary,
`guard.ps1` self-filters). Changing a registered entry changes the digests the installer matches shipped entries by (`install.ps1` `SjShippedEntries`, ~line 2816+),
which drags in guarded installer work and step 4 for it. Cost of not changing: `MultiEdit`, Bash and PowerShell are never routed on Claude Code (section 6).
`src/core/scripts/framework-doctor.ps1` unchanged. No `framework-ownership.json` change (no new file).

## 3. Exact behaviour

### 3.1 Where it sits
`guard.ps1` already has, at lines ~719-723, `foreach ($target in $targets) { if (Test-AllowlistTarget ...) { Exit-Blocked ... } }`, before the
`if ($writes.Count -eq 0) { exit 0 }` at ~724. Insert the new check **between those two**, so it runs for every write-shaped event, including one whose text is empty
(an emptying Write has `$writes.Count -eq 0` and would otherwise exit 0). `Exit-Blocked` (251-263) already gives the two surfaces: exit 2 + stderr for tool names
Write/Edit/NotebookEdit/MultiEdit/empty; otherwise stdout JSON `permissionDecision: deny` (top level and in `hookSpecificOutput`), exit 0. No new surface code.
`$targets` is `$pathFields` for a write-shaped event (every `file_path|filePath|path|notebook_path` of `tool_input`/`toolArgs`, plus each MultiEdit/replacements item path)
and every patch section path including `Move to:` targets, so renames onto a protected path are seen for free.

### 3.2 Path classification (new function `Get-WiringKind([string]$Path)`)
Order matters (round 2: resolving before stripping misses; `GetFullPath("…\CLAUDE~1\SETTIN~1.JSO::$DATA")` gives `…\.claude\SETTIN~1.JSO::$DATA`, the file name not expanded, and
`GetFullPath("\\?\…\CLAUDE~1\SETTIN~1.JSO")` returns it unexpanded while `ReadAllText` through it reads the real file; both seen by the supervisor, not re-run by me).
Step 1, **strip before anything resolves**: `/` to `\`; drop a `\\?\` or `\\.\` prefix (a `\\?\UNC\` or `\\server\share` stays a UNC path, never opened: no UNC host is touched, 21 s waits); cut an NTFS stream
from the last segment (`:` anywhere after a drive letter, `::$DATA`, `:name:$DATA`); trim a trailing dot from **every** segment (a trailing dot on a directory segment opens the same directory; a trailing *space* on a directory
segment does not open, so it is not an attack and is not claimed as one; trimming it too is harmless over-blocking); collapse `.`, `..` and empty segments. Do not change `Get-CheckedFileName`: the allowlist uses it.
Step 2, **classify the stripped long-name path** by suffix, ordinal-ignore-case (below). A match refuses.
Step 3, **8.3 aliases**. For a stripped path with any segment matching `~[0-9]` and a local drive path, take `[IO.Path]::GetFullPath` of it (this expands existing short names through the file system, as
`Test-AllowlistResolvedTarget`, guard.ps1 ~700-716, does) and classify that too. Then **fail closed on any `~` still in the file segment or its two parent segments after resolving, if alias-shaped for a protected name**,
because a name the file system did not expand cannot be shown to be somewhere else: a directory segment `^[^/~]{1,6}~[0-9]+$` whose stem is a prefix of `claude` (the dot is dropped), `github` or `hooks`; a file segment
`stem~N.<ext>` with extension `JSO`/`JSON`/`PS1` (an extension is cut to three characters) whose stem is a prefix of `settings`, `hooks`, or any name when its parent is `hooks` or an alias of it; shipped examples `SETTIN~1.JSO`
(settings.json), `SETTIN~2.JSO` (settings.local.json), `HOOKS~1.JSO`, `SESSIO~1.PS1`. A UNC, other-drive, drive-relative, leading-`~` or unresolvable path skips `GetFullPath` and is judged by the alias shape alone. Any error refuses.
Other `~` paths pass (`REPORT~1.TXT`, `C:\Users\COSTAS~1\AppData\Local\Temp\x.txt`): refusing every `~` path would block ordinary temp-dir writes, since `%TEMP%` is often a short name.
The supervisor proposed refusing any raw `~`, `\\?\`, UNC or stream path unless provably outside the project's `.claude`/`.github`. Taken in part: strip-first, and refuse what the file system did not expand. Not taken whole: a blanket `~` refusal.
Step 4, the suffix tests (on the stripped and the resolved path):
- `hooks-script`: ends in `.claude/hooks/<name>.ps1` (one segment, so `tests/` subfolders are not covered, as WSD-132 says `*.ps1`), or `<name>` is `.ps1`-alias-shaped under that folder.
- `hooks-json`: ends in `.github/hooks/hooks.json`.
- `settings`: ends in `.claude/settings.json`. `settings-local`: ends in `.claude/settings.local.json`.
Suffix match, not repository-root match, on purpose: a relative path with no usable `cwd` (`Get-WaiverRelativePath` returns `$null`), an absolute path outside `$repoRoot` and a nested sub-project all still match;
the cost is that an agent writing `other-project/.claude/hooks/x.ps1` is refused too (accepted: such a file is that project's guard wiring). Symlinks: the guard reads text only, so a link
`x.ps1 -> .claude/hooks/guard.ps1` is not seen (section 6). The disk read for an Edit (3.4) uses the same stripped, resolved path, never the raw spelling.

### 3.3 Decision per kind
- `hooks-script`, `hooks-json`: refuse every write-shaped event naming it, whatever it does (Write, Edit, MultiEdit, create, str_replace, insert, a patch Add/Update/Delete/Move
  touching it, an empty write, a deletion section). Same as the allowlist block. Reading is unaffected (a `view` has no write fields and is not write-shaped).
- `settings`: compute the **result** and refuse unless it registers the guard (3.4).
- `settings-local`: refuse only if the result is unparsable or sets `"disableAllHooks": true` at top level. Claude Code merges hook arrays from settings files, so a local file
  can add hooks but not remove the shared guard entry; `disableAllHooks` is the one local key that switches the guard off. (I believe this key exists in Claude Code; the
  implementer must confirm it against the current settings reference before relying on it. See open question 3.) It is gitignored (`src/core/.claude/.gitignore:6`).

### 3.4 Computing the result (new function `Get-SettingsResult`), one per write unit naming a `settings` path
| Event | Result computed as |
|---|---|
| Write (`content`), Copilot `create` (`file_text`/`content`) | the text itself (whole file). Empty text: result is empty, unparsable, refused. |
| Edit (`old_string`,`new_string`,`replace_all`), Copilot `str_replace`/`edit` (`old_str`/`oldString`) | read the file on disk, **normalise CRLF to LF in the file text, `old` and `new`** (the shipped `.gitattributes` forces LF only on `*.ps1`, so a CRLF `settings.json` would otherwise never match and falsely block a permission add), replace the **first** occurrence (all if `replace_all` is true), ordinal. |
| MultiEdit / `replacements` / `edits` items | same, each item applied in order to the running text, for items whose own path (or the event's) is settings. |
| `insert` (`new_str` + line) | cannot place it cheaply: refuse (3.5). |
| apply_patch Add | the section's added lines joined by `\n`. |
| apply_patch Update | new function `Get-PatchHunks([string]$Patch, [string]$Path)` re-reads the raw patch text: each `@@` hunk as an ordered list of context (` `), removed (`-`) and added (`+`) lines. `Get-PatchSections` (294-334) drops context and `@@` anchors and pools removed lines, and `audit-trail.ps1`/`post-write.ps1` load it from this file, so **it is not changed**. Apply each hunk by finding its context+removed lines as one contiguous block in the LF-normalised disk file (trailing-whitespace-trimmed line compare) and substituting context+added; any hunk not found, or an ambiguous second match: refuse. Cost if this function were dropped for plain fail-closed: every `apply_patch` Update to `settings.json` on Copilot (the GPT-model tool) would be refused, including a permission add; `/adopt` itself writes none (section 6), so the cost is a team's own settings edits. Plan builds the function; fallback is fail closed. |
| apply_patch Delete, or Move to/from settings | refuse (the file is gone or its content is another file's). |
| NotebookEdit | not applicable (notebook paths); the path rule still applies to a `.ps1` named there. |
Disk read: a new small `Get-SettingsDiskText` that, unlike `Get-ExistingText` (returns `''` for missing/unreadable, indistinguishable from an empty file), returns `$null` when the
file cannot be read. Relative paths resolve against `$eventCwd` (absolute only); with no usable `cwd`, resolve against `$repoRoot`. Limit 2 MB like `$maxExistingBytes`.
Edit with old text not found, file missing, or unreadable: **refuse** with the "cannot work out the result" message (3.5). The tool itself would fail in most of those cases so
a real developer rarely sees it, but Claude Code matches old text more loosely than ordinal (quote normalisation), so allowing would let a mismatch pass unread.
This is WSD-135's "fails closed only for a write-shaped event it cannot parse", applied to a write-shaped event whose result the guard cannot compute.

### 3.5 "Registers guard.ps1" (new function `Test-RegistersGuard`): the entry must be the shipped entry
Round-2 change: a substring or regex test on `command` is too weak (`pwsh -File .claude/hooks/guard.ps1 ; exit 0`, `return ; pwsh ...`, `Set-Location $env:TEMP ; pwsh ...` all pass it, and `async`, `if`
or a shorter `timeout` fields are ignored). So "registers" means **the entry equals the shipped entry**, not "mentions the script".
1. **Strict parse first.** `ConvertFrom-Json -AsHashtable` alone is too lenient (it accepts trailing commas, single quotes, `//` comments, and parses keys that differ only in case; the round-1 text
   claiming it throws on those was wrong). Validate with `[System.Text.Json.JsonDocument]::Parse($text)` using default options (comments and trailing commas are errors), then walk every object and
   refuse a repeated property name (ordinal, and ignoring case); only then convert with `ConvertFrom-Json -AsHashtable` for the comparison. Any failure is refusal (3.6 "cannot work out"). Why strict: the installer
   already treats such a file as unreadable ("strict JSON", upgrade checklist step 6), and if Claude Code's own parser rejects it the hooks are dropped (**not verified**; the implementer checks against current Claude Code). Cost: an
   agent edit that leaves a commented settings file is refused, with a message telling a teammate to do it.
2. Top level is an object and `disableAllHooks` is not `$true`.
3. `hooks.PreToolUse` is an array holding a group whose keys are only `matcher` and `hooks`, and whose `hooks` array holds an entry that equals the shipped guard entry: the same set of keys
   (`type`, `command`, `shell`, `onFailure`, `cwd`; so an added `async`, `if`, `timeout` or other key refuses) with equal values, where `command` is compared after collapsing whitespace runs to one space, `\` to `/`,
   ignoring case. The shipped string is the one in `src/stacks/*/files/.claude/settings.json` (identical in all three stacks, checked: `diff` of dotnet against monorepo and angular is empty):
   `if ($env:CLAUDE_PROJECT_DIR) { Set-Location -LiteralPath $env:CLAUDE_PROJECT_DIR } ; pwsh -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/guard.ps1 ; if ($null -eq $LASTEXITCODE) { exit 2 } ; exit $LASTEXITCODE`,
   `"shell": "powershell"`, `"onFailure": "block"`, `"cwd": "."`, `type` `command`, no `timeout`. It is held as one constant in `guard.ps1`, and one new test case reads `src/stacks/dotnet/files/.claude/settings.json`
   and fails when the constant and the shipped entry differ, so a future change to the shipped command cannot silently make every shipped file "unregistered".
4. That group's `matcher` (absent, `""` or `*` means all) matches `Write`, `Edit` and `NotebookEdit` when anchored as `^(?:matcher)$`. Today's `Write|Edit|NotebookEdit` passes; narrowing or `Nothing` is refused;
   widening (adding `MultiEdit`) passes. A regex error refuses.
**PreToolUse only**, not every event: `guard.ps1` is registered on `PreToolUse` alone in settings.json (and `preToolUse` in hooks.json); only that event blocks a write. Registering it under `PostToolUse` blocks nothing.
Copilot reads `.claude/settings.json` too (guard.ps1 line ~274), so this single check serves both surfaces; `hooks.json` is protected wholesale, so no registration parse is needed there.
**What a team that customises the guard command loses** (a different timeout, `cwd`, a wrapper, a copy of the script): an agent can no longer edit their `settings.json` at all (every edit is refused, whatever key it touches),
because the entry no longer equals the shipped one; the person edits it by hand. The same holds for a team on an older release whose shipped guard string differs from the current one until the update (installer) refreshes the file.
Residual, let through: anything the shipped entry's own text can do is the framework's; the rule does not judge `shell`, the `pwsh` on `PATH`, or the script's contents (those are protected by the hooks-file rule and the doctor).
Rejected: keeping the regex and adding a "nothing before/after" tail rule (every new shell form is another hole: `return ;`, `Set-Location ;`, `&&`), and an unchanged-from-disk allowance for customised entries (it would let a
file already broken by hand stay editable by the agent; offered as question 6).

### 3.6 Messages (verbatim drafts; both surfaces carry the same text; tests assert the quoted phrase)
- hooks files: `Blocked write to <path>: it changes a write-guard hook file (.claude/hooks/*.ps1 or .github/hooks/hooks.json), the scripts and registrations that make the guard run. An agent may not write, edit or delete them; a teammate makes the change by hand and it is reviewed in a pull request.`
- settings, guard dropped: `Blocked write to <path>: the file it would leave no longer registers .claude/hooks/guard.ps1 as a PreToolUse hook for Write and Edit (or turns hooks off), so the write guard would stop running. Other settings changes are fine. Keep the guard entry and resend, or have a teammate make this change by hand.`
- settings, unreadable: `Blocked write to <path>: the write guard cannot work out the file this write would leave (it is not valid JSON, the text to replace was not found, or the file could not be read), so it cannot confirm the guard stays registered. Resend a whole-file Write of valid JSON that keeps the guard hook, or have a teammate make the change by hand.`

## 4. Observed current behaviour (read-only probe of `dist/dotnet/.claude/hooks/guard.ps1`, pwsh, stdin fixture)
Fixture files in scratchpad. Command shape and results (this session, 2026-11-19):
- `Get-Content -Raw a.json | pwsh -NoProfile -File dist/dotnet/.claude/hooks/guard.ps1` with
  `{"tool_name":"Write","tool_input":{"file_path":"C:\\proj\\.claude\\settings.json","content":"{ \"hooks\": {} }"}}` → no output, **`EXIT=0`**.
- same with `file_path` `C:\proj\.claude\hooks\guard.ps1`, content `exit 0` → **`EXIT=0`**.
- Copilot `{"toolName":"create","toolArgs":{"path":".github/hooks/hooks.json","file_text":"{\"version\":1,\"hooks\":{}}"}}` → no stdout, **`EXIT=0`** (no deny JSON).
All three are the unprotected state B-489 round 2 reported. The implementer re-runs them after the change and expects `EXIT=2` + stderr (Claude) / deny JSON (Copilot).

## 5. Red-first cases (all in `src/core/tests/hooks/Guard.Tests.ps1`; helpers `New-ClaudeEvent`, `New-ClaudeEditEvent`, `New-CopilotEvent`, `New-PatchEvent`, `Assert-Decision`)
Each runs in a temp root made like `New-AllowlistedRoot`, with a settings.json written to disk that contains today's shipped hooks (copy `dist/dotnet/.claude/settings.json` text).
Fails on the unfixed tree because that guard allows each (section 4); passes after.
1. `guard: a write that leaves settings.json without the guard is refused` : Claude Write `{ "hooks": {} }` BLOCK; Copilot create DENY; an Edit with old = the `PreToolUse` group, new = `""`, replace_all false BLOCK; Edit that renames `guard.ps1` to `guard2.ps1` BLOCK; matcher narrowed to `Nothing` BLOCK; `PostToolUse`-only registration BLOCK; `{"disableAllHooks":true,...}` BLOCK; invalid JSON BLOCK; empty Write BLOCK. Also BLOCK: the shipped command with `; exit 0` appended; `return ; pwsh ...`; `Set-Location $env:TEMP ; pwsh ...`; `... guard.ps1.off`; the shipped entry plus `"async": true`, plus `"if": "..."`, or with a `timeout`; a settings text with a trailing comma, a `//` comment, single-quoted keys, or two keys differing only in case. One extra case: the guard's embedded shipped-entry constant equals the entry in `src/stacks/dotnet/files/.claude/settings.json` (fails if either drifts). Negative: the unmodified shipped file plus a permission, and the matcher widened with `|MultiEdit`, ALLOW. Assert stderr/stdout contains `no longer registers`.
2. `guard: an agent cannot write the guard hook files` : Write and Edit to `<root>\.claude\hooks\guard.ps1` and `session-start.ps1`, relative `.claude/hooks/guard.ps1`, `.CLAUDE\Hooks\GUARD.PS1`, `.claude\hooks\SESSIO~1.PS1`, `.claude/hooks/guard.ps1::$DATA`, **the 8.3 spellings `<root>\CLAUDE~1\SETTIN~1.JSO` (Claude Write of `{"hooks":{}}`), `<root>/GITHUB~1/hooks/HOOKS~1.JSO` (Copilot edit) and `<root>\CLAUDE~1\HOOKS~1\SESSIO~1.PS1`, run in a temp root where the folders exist so the short names are real (skip with a stated reason if the volume has 8.3 off, `fsutil 8dot3name query`), plus an alias-shaped path whose folders do not exist yet, which fails closed**, `.claude.\settings.json` (trailing dot on a non-last segment), `\\?\<root>\CLAUDE~1\SETTIN~1.JSO`, `<root>\CLAUDE~1\SETTIN~1.JSO::$DATA` and `<root>\.claude\settings.json::$DATA` (the round-2 spellings), a UNC spelling (alias-shaped, judged without opening it), apply_patch Update/Delete/Move onto it, Copilot create `.github/hooks/hooks.json`, a delete section. All BLOCK/DENY, message contains `write-guard hook file`.
3. **Negatives (must still pass; these pass before and after, so they are guards on the rule not red cases):** (a) Edit that adds one entry to `permissions.allow` ALLOW (the `/adopt`-style edit); (b) Write of the full shipped settings plus `"model": "x"` ALLOW; (c) Edit adding a second hook under `PostToolUse` ALLOW; (c2) the same permission-add Edit against a **CRLF** settings.json on disk ALLOW; (c3) an apply_patch Update adding a permission ALLOW; (c4) an alias-shaped path for an unprotected name (`REPORT~1.TXT`) ALLOW; (d) Write to `.claude/hooks/tests/x.ps1` ALLOW (outside `*.ps1` direct children, as decided); (e) Write to `docs/hooks/guard.ps1.md` ALLOW; (f) settings.local.json with `{"permissions":{}}` ALLOW; (g) a Write to `.claude/guard-allowlist.txt` still gives the allowlist message (precedence unchanged); (h) the key-shaped Write still gets the secret message.
Declared `Red-first:` trailers: cases 1 and 2 only. Whether `assert-red-first.ps1` needs the new case names without `--`: yes.

## 6. What is let through, closed, or blocked wrongly

Let through (accepted unless noted):
- **Shell writes** (Bash, PowerShell `Set-Content`, `Out-File`, `>`, `sed -i`, `git checkout <old> -- .claude/settings.json`, a script written then run): WSD-132 "Let through: the shell". Also, Claude Code's matcher does not route Bash/PowerShell to the guard at all. Would close: a command-text rule in the guard plus matcher changes (installer digests); not proposed.
- **`MultiEdit` on Claude Code**: matcher `Write|Edit|NotebookEdit` does not route it, so the guard never sees it there; the guard's own MultiEdit parsing helps Copilot only. Closing: add `MultiEdit` to the matcher, which is the installer-digest change above. Not determined here whether current Claude Code still ships MultiEdit; the maintainer's call (question 4).
- **Symlink/junction/hard link** to a hook file: path text only. Accepted: needs the shell to create.
- **Edits through other tools** (IDE edits by the human, an MCP tool that writes files, `Copy-Item` through shell): not agent file-write events.
- **User-level `~/.claude/settings.json`** and enterprise-managed settings: outside the repository; the suffix rule refuses a write to `…/.claude/settings.json` anywhere, but the user-level file can only add guards, and `disableAllHooks` there is refused by the same check (if routed).
- **`.vscode/settings.json`, other `.github/hooks/*.json`**: Copilot loads extra hook files additively; they cannot remove the guard entry. Not protected. A different Copilot setting that turns hooks off is unknown (not determined).
- **Registered but dead**: the entry can stay while the guard script does not run (a PATH change, `onFailure` removed). The doctor's `Wired hook shell` row covers the interpreter; wrapper edits are accepted (3.5).
- **Race**: two events in one tool call each pass alone but the second Edit's disk base is stale; the check reads disk per event, and Claude Code runs one tool call at a time. Accepted.
- Rename/delete of `.claude/settings.json` by a patch is caught (Delete/Move refused); a Write to a *different* path then a shell `mv`: shell, accepted.

Legitimate actions that could be blocked:
- `/adopt` (`adopt.md` line 104): only *reads* `.claude/settings.json` ("preserve"); it writes none. No block. A team hook inside the settings file stays editable if the guard entry is kept.
- Upgrade checklist step 6: the **installer** reconciles settings (a PowerShell process, not an agent write); step 6 asks the developer to commit it. Not blocked. Uninstall step 3 (remove every hook entry naming `.claude/hooks/`): an agent doing it would be refused, which is right (it removes the guard); the developer does it by hand. Say so in the checklist.
- A team adding their own hook script to `.claude/hooks/`: refused for the agent (any `*.ps1` there), the person writes it. The team-owned-hooks case is the main legitimate cost; WSD-132 chose it. Reopen trigger already in WSD-132.
- A framework hook that itself writes there: none found (no command, skill or agent under `src/core/.claude` names a write to `.claude/hooks/*.ps1` or `hooks.json`).
- The authoring repo itself: checked, `.claude/settings.json` here has no `guard.ps1` registration (`grep -c` = 0), so maintainers' agents are not refused. Editing `src/core/.claude/hooks/guard.ps1` is also not affected (the path ends `src/core/.claude/hooks/guard.ps1`, and no guard runs here). Only a consumer or a session that installs `dist/` is affected. Still a trap for the tests: they must use temp roots, never the real tree.

## 7. Verification recipe (by changed path; show command and result line; capture `$LASTEXITCODE` before piping)
1. `src/core/.claude/hooks/guard.ps1`, tests: `pwsh -NoProfile -File src/core/tests/hooks/Guard.Tests.ps1`, then `Guard2.Tests.ps1`, then the CP437 leg (section 1.3). Red evidence: `.claude/scripts/assert-red-first.ps1` after committing (the script reads the commit).
2. `scripts/build.ps1 dotnet`, `angular`, `monorepo` (x3); stage the `dist/` change in the same commit.
3. `scripts/validate-dist.ps1 dotnet|angular|monorepo` (x3), including `no-meta-leak`: message and docs text must not name `WSD-`/`B-` ids.
4. `scripts/context-footprint.ps1 -Check`: expected unchanged (the guard emits nothing into context); if it reports a baseline change, review then `-Update`; a ceiling breach is the maintainer's.
5. Hook dist copy, both surfaces, by piping fixtures into `dist/dotnet/.claude/hooks/guard.ps1` (and angular, monorepo): the three section 4 events plus negative 3a, asserting `EXIT=2` + stderr text (Claude) and `EXIT=0` + `"permissionDecision":"deny"` stdout (Copilot create / apply_patch string in `toolArgs`).
6. Records: root `CHANGELOG.md` and three stack changelogs; `.claude/hooks/tests/Invoke-HookTests.ps1 -File DocTruth.Tests.ps1`, `-File RepositoryPrivacy.Tests.ps1`, `-File BacklogHygiene.Tests.ps1` (BACKLOG B-490 deleted, one line to `meta/BACKLOG-DONE.md`; WSD-132 "Not yet built" sentence updated; B-490 depends on nothing; commit says `B-490 done`).
7. Commit to `master`; push with `.claude/scripts/push-and-check.ps1`. No release (batched, maintainer asks). One cost-benefit line in the body: ~120 lines in the guard, one extra disk read of a settings file per settings write, ~0 for other writes.

## 8. Changelog drafts (consumer voice; no ids)
Add as bullet under `## 0.99.0 — Unreleased` in all three `src/stacks/*/files/CHANGELOG.md`; the root `CHANGELOG.md` gets the same plus `B-490`/`WSD-132`.
- **The write guard now refuses an agent's change that would switch the guard off.** An agent can no longer write or edit the scripts in `.claude/hooks/` or `.github/hooks/hooks.json`, or change `.claude/settings.json` so that it stops registering `guard.ps1` (or turns hooks off). Other settings edits, such as a permission, still go through. If you want to change a hook or its registration, make the edit yourself and review it in a pull request. The shell is still not read by the guard.

Footprint: none expected (section 7 step 4). Blocked-on: nothing external; questions 1-3 before building. Effort: M (about a day: guard function ~120 lines, 8-10 cases, docs, changelogs; plus the step-4 attack round of ~30 min).
Order: (1) answer questions 1-3; (2) write cases, run them on the unfixed tree to see `[FAIL]`; (3) implement `Get-WiringKind`, the hooks refusal, then `Get-SettingsResult`/`Test-RegistersGuard`; (4) docs, changelogs, records; (5) build x3, validate x3, footprint, CP437; (6) commit with `Red-first:` trailers, run `assert-red-first.ps1`; (7) step 4 reader; (8) push.

## 9. Open questions for the maintainer (plain words)
1. The rule matches the path ending (`.../.claude/hooks/x.ps1`), not the repository root, so it also refuses a write in a nested sub-project or with no usable working directory. Choose: (a) suffix match (recommended, harder to dodge); (b) match only paths proven to sit under this repository's root (fewer false blocks, but a relative path with no working directory slips through).
2. A team adding its own hook script to `.claude/hooks/` is refused for the agent. Choose: (a) accept (WSD-132 as written); (b) refuse only `guard.ps1` and the framework's shipped hook scripts, and let team-named scripts through (smaller cost to teams, wider list to maintain).
3. Also refuse `.claude/settings.local.json` when it sets `disableAllHooks: true`? That key can turn the guard off without touching the shared file. Choose: (a) yes (recommended, small); (b) no, keep strictly to settings.json.
4. A shell command that rewrites the settings file, a hook script or `hooks.json` is let through on both surfaces (section 0a), and `MultiEdit` is not routed on Claude Code. Choose: (a) accept, as WSD-132 decided, and say so in the docs (recommended); (b) also add `MultiEdit` to the matcher only (needs the installer's known-entry list updated: guarded, step 4 for the installer too); (c) close the shell as well: matcher plus a shell-text rule, incomplete by nature, a `pwsh` start on every shell call, and a larger step 4.
6. "Registers" means the guard entry equals the shipped one (section 3.5). A team that changes the guard's command (timeout, working folder, a wrapper), or is on an older release until it updates, can then no longer have an agent edit `settings.json` at all. Choose: (a) accept; they edit it by hand or update (recommended, simple, hard to dodge); (b) also let an agent edit when the guard entry is unchanged from what is on disk (fewer blocks, but a file already broken by hand stays editable by the agent).
5. Who does step 4: you read the diff, or a fresh session attacks it (recommended, the rule has many path spellings)?

## Adversarial review

Round 1, by a fresh session (reported through the supervisor; I re-checked none of it myself except where marked).
- **Attacks tried:** (1) 8.3 short names reach the protected files past the suffix rule; (2) an Edit against a CRLF `settings.json` never matches ordinally; (3) apply_patch Update cannot be
  computed from `Get-PatchSections`; (4) "registers" as a substring test passes `exit 0; pwsh -File .claude/hooks/guard.ps1` and `guard.ps1.off`; (5) trailing dot/space trim covers only the last segment.
- **Executed attack (finding 1):** a Claude `Write` of `{"hooks":{}}` to `<dist>\CLAUDE~1\SETTIN~1.JSO`, piped into the dist/dotnet guard: `Claude 8.3 EXIT=0 OUT=`. Copilot edit to
  `GITHUB~1/hooks/HOOKS~1.JSO`: `EXIT=0`. The supervisor's `cmd /c "dir /x dist\dotnet"` lists `CLAUDE~1 .claude` and `GITHUB~1 .github`. Attributed, not re-run by me.
- **Changed in the plan:** 3.2 resolves any `~` segment with `GetFullPath` before classifying, fails closed on an unresolvable alias-shaped path for a protected name, and trims dot/space on every
  segment (new function, `Get-CheckedFileName` untouched); 3.4 normalises CRLF and names `Get-PatchHunks` for patch Updates (fail closed on no match, `Get-PatchSections` untouched); 3.5 requires an
  interpreter `-File` invocation ending at a delimiter with no earlier `exit`, residual stated; section 5 adds the 8.3, trailing-dot, CRLF, patch and `exit 0;` cases.
- **Rejected:** blocking every path containing `~` (false blocks on ordinary long-name files); dropping apply_patch Update support for plain fail-closed (kept only as fallback, it blocks Copilot users' permission edits);
  a full shell parser for "registers" (cannot be finished, the residual is stated as let-through).
Round 2, by a fresh session on the revised core rule (through the supervisor, who re-ran the path probes; I re-ran none).
- **Attacks tried:** (1) "registers" regex accepts a guard that cannot block; (2) resolve-then-cut order lets `…\CLAUDE~1\SETTIN~1.JSO::$DATA` through; (3) `\\?\` prefix: `GetFullPath` does not expand, `ReadAllText` still reads the file;
  (4) `ConvertFrom-Json -AsHashtable` is lenient (trailing commas, single quotes, comments, case-only duplicate keys), contrary to what 3.5 claimed; (5) nit: a trailing space on a directory segment does not open.
- **Executed attacks:** A: `pwsh -NoProfile -File <scratchpad>\r2b-regex.ps1` printed `PASS  <= pwsh -NoProfile -File .claude/hooks/guard.ps1 ; exit 0` under the round-1 regex verbatim (also `return ; pwsh ...`,
  `Set-Location $env:TEMP ; pwsh ...`). B: `GetFullPath` on the stream and `\\?\` spellings returned the unexpanded names, as quoted in 3.2. A was the attacker's run; the supervisor re-ran both and saw the
  same lines (A: `PASS  <= pwsh -NoProfile -File .claude/hooks/guard.ps1 ; exit 0`, `EXIT=0`).
- **Changed:** 3.5 now requires the entry to equal the shipped entry (same keys, equal values, command compared modulo whitespace, separators and case), with a drift test; strict JSON via `System.Text.Json` with a
  duplicate-key walk; matcher must cover Write, Edit and NotebookEdit; the cost to customising teams stated and put as question 6. 3.2 strips prefix, stream and trailing dots first, then resolves, then fails closed on an
  unexpanded alias-shaped name; the trailing-space claim is corrected; tests extended in section 5.
- **Rejected:** a blanket refusal of every `~` path (blocks `%TEMP%` writes); patching the regex with tail rules (endless shell forms); an unchanged-from-disk allowance (kept only as question 6b); opening UNC or `\\?\` paths to resolve them (slow, unsafe).
- No third round was run. Round 2 found core-rule defects and this revision answers them unattacked, so the path handling in 3.2 and the shipped-entry comparison in 3.5 are the first targets of the step-4 attack on the implementation.
