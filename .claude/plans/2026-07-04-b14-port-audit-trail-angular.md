# B-14 — Port `audit-trail` hook to Angular (dual-repo lockstep)

**Version target:** v0.25.3 (patch — closes a parity gap; leaves 0.26.0 free for B-27).
**Invariants in play:** #1 (lockstep), #2 (CLAUDE↔AGENTS mirror), #3 (.ps1/.sh twins), #5 (hook
output semantics per surface), #7 (version + CHANGELOG + release.ps1).
**Effort:** S–M. **Author of plan:** Opus. **Delivery:** Sonnet.

---

## Goal

Angular ships neither the `audit-trail` hook files nor any registration; dotnet does. An AI
audit log is stack-agnostic, and this asymmetry is a declared exception in `check-lockstep.ps1`.
Port the hook faithfully to Angular, wire it into both Angular hook registries, seed the log
file, document it in Angular's CLAUDE.md/AGENTS.md, add shared behavior tests, then **remove the
three check-lockstep exceptions** so the gate enforces parity going forward.

## Established facts (verified during planning — do not re-derive)

- dotnet source of truth: `.claude/hooks/audit-trail.ps1` (71 lines, has UTF-8 BOM) and
  `.claude/hooks/audit-trail.sh` (82 lines). `.sh` carries two extra doc lines the `.ps1` lacks:
  the "Satisfies SR 11-7 / DORA traceability…" line and "(object)" on the toolArgs comment.
- The **only** stack-specific element is the build-artifact skip:
  - `.ps1`: `if ($filePath -match 'ai-audit\.log|[\\/]obj[\\/]|[\\/]bin[\\/]') { exit 0 }`
  - `.sh`:  `case "$file_path" in *ai-audit.log|*/obj/*|*/bin/*) exit 0 ;; esac`
  `obj/` and `bin/` are .NET build dirs. **Angular equivalent:** skip `node_modules`, `dist`,
  `.angular`, `coverage` (plus the log itself). Everything else in the hook is stack-agnostic
  and must be copied byte-for-byte (path extraction, self-filter, env fallback, branch, ISO-UTC
  timestamp, repo-relative normalization, append to `.claude/ai-audit.log`).
- Registrations dotnet has that Angular lacks:
  1. `.claude/settings.json` → `PostToolUse` matcher `Write|Edit` → second hook entry
     `pwsh -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/audit-trail.ps1`.
  2. `.github/hooks/hooks.json` → `postToolUse` array → second entry
     `{ bash: .claude/hooks/audit-trail.sh, powershell: .claude\hooks\audit-trail.ps1, timeoutSec: 10 }`.
     (post-write uses `timeoutSec: 120`; audit-trail uses **10** — match dotnet.)
- dotnet ships a tracked seed `.claude/ai-audit.log` — 5 header comment lines + trailing newline
  (no data rows). Angular lacks it. Seed Angular's byte-identical.
- CLAUDE.md "Registers" line: NOT one of the verbatim-gated mirror sections (gated = Verification
  Rules, Leanness, SOLID, Boy Scout, Agentic Workflow §1). dotnet's ends with the ai-audit
  sentence; angular's ends with "Security findings come from `/security-review`…". For Angular:
  **append** the ai-audit sentence, keep the existing security-findings sentence.
  - CLAUDE.md link style: `[.claude/ai-audit.log](./.claude/ai-audit.log)`.
  - AGENTS.md mirror style (from dotnet): flattened to backticks `` `.claude/ai-audit.log` `` (no link).
- `check-lockstep.ps1` exceptions to REMOVE (three spots):
  1. Lines ~23-26 `$onlyInDotnet`: delete the two `.claude/hooks/audit-trail.ps1|.sh` entries
     (keep `scripts/ci/ArchitectureTests.sample.cs`). Delete the trailing
     `# merge-plan D3 unifies this` comment on that line.
  2. §4 comment (~lines 148-149): drop "audit-trail is the one declared dotnet-only reg (until
     B-14 ports it to angular)"; reword to state postToolUse regs are now fully identical.
  3. §4 loop: line ~165 `if ($x -notmatch 'audit-trail') { $hookBad += … }` → unconditional
     `$hookBad += "dotnet-only: $x"`; and the FAIL/OK messages (~167-168) drop the audit-trail
     wording.
- `tests/hooks/` is IDENTICAL machinery — anything added there must be **byte-identical** in both
  repos (EOL/BOM-normalized). `TwinParity.Tests.ps1` already auto-discovers every `.ps1`+`.sh`
  twin under `.claude/hooks` and runs empty/malformed-stdin robustness parity — so once Angular
  has the twins, that coverage is automatic in Angular (it already exists for dotnet).
- Repos: both on `master`, clean, `origin` = github.com/andreoucostas/ai-tech-lead-{dotnet,angular}.
- Release path is `.claude/scripts/release.ps1 -Version 0.25.3 -Summary "…"`: it requires the
  `## 0.25.3` CHANGELOG head in BOTH repos first, stamps CLAUDE.md + framework-version.json,
  runs template-checks ×2 + hook suites ×2 + check-lockstep + meta-hook suite, then commits +
  pushes both. It does NOT run docs-sync-check or regen AGENTS.md — do those before releasing.

## Deliverables (ordered)

1. **`ai-tech-lead-angular/.claude/hooks/audit-trail.ps1`** — copy dotnet's, change ONLY the skip
   regex to Angular artifacts. **Must have a UTF-8 BOM** [#4] (dotnet's does; the `bom-fix` hook
   or manual). Keep the header comment block; the `.ps1` has no SR 11-7 line (match dotnet .ps1).
   - Skip line becomes: `if ($filePath -match 'ai-audit\.log|[\\/]node_modules[\\/]|[\\/]dist[\\/]|[\\/]\.angular[\\/]|[\\/]coverage[\\/]') { exit 0 }`
2. **`ai-tech-lead-angular/.claude/hooks/audit-trail.sh`** — copy dotnet's, change ONLY the skip
   case. Keep the SR 11-7 line and "(object)" note (stack-agnostic).
   - Skip case becomes: `*ai-audit.log|*/node_modules/*|*/dist/*|*/.angular/*|*/coverage/*) exit 0 ;;`
3. **`ai-tech-lead-angular/.claude/ai-audit.log`** — byte-identical seed (5 comment lines + `\n`).
4. **`ai-tech-lead-angular/.claude/settings.json`** — add the audit-trail.ps1 command as the 2nd
   hook under the `Write|Edit` PostToolUse matcher (after post-write.ps1). Match dotnet's exact
   command string and JSON shape.
5. **`ai-tech-lead-angular/.github/hooks/hooks.json`** — add the audit-trail entry as the 2nd
   `postToolUse` hook (timeoutSec 10). Match dotnet byte-for-byte for that block.
6. **`ai-tech-lead-angular/CLAUDE.md`** Registers line — append:
   ` AI-assisted file changes are appended to [.claude/ai-audit.log](./.claude/ai-audit.log) automatically by the PostToolUse hook.`
7. **`ai-tech-lead-angular/AGENTS.md`** Registers line — mirror it (backtick style, no link),
   preferably by regenerating via `/generate-copilot`; if regenerating by hand, follow
   `.claude/commands/generate-copilot.md` and append the same sentence in dotnet's AGENTS style.
   Then confirm `scripts/docs-sync-check.ps1` and `scripts/template-checks.ps1` pass.
8. **`.claude/scripts/check-lockstep.ps1`** (meta) — remove the three exceptions above.
9. **Shared behavior test `tests/hooks/AuditTrail.Tests.ps1`** — added byte-identically to BOTH
   repos. Tests stack-AGNOSTIC behavior only (the byte-identical constraint forbids asserting the
   stack-specific skip — same accepted limitation as PostWrite build-routing, per B-09). Cover,
   using the `_HookHarness.ps1` + fixtures pattern (see `PostWrite.Tests.ps1`), run from a
   throwaway CWD so the real repo's log is never touched:
   - a Claude `Write` event with a normal path (e.g. `src/x.txt`) + content → exactly one line
     appended to `.claude/ai-audit.log`, tab-delimited, 3 fields, 3rd = the path.
   - an event whose path is `.claude/ai-audit.log` → NO new line (self-skip; identical in both).
   - a Copilot `create` event (toolArgs.filePath) → one line appended (surface parity).
   - `.ps1` vs `.sh` agree on the above (twin parity) — guard with `Get-BashPath`/Skip when no bash.
   - **Red-before-green [#9]:** briefly break the skip (or path extraction) and confirm the test
     goes red for the right reason; state the evidence. If running red is impractical for a
     branch, state the specific defect it catches.
   - If, after drafting, this test cannot be made byte-identical AND meaningful across both stacks,
     fall back to relying on TwinParity's auto-coverage + a manual fixture demonstration in the
     verification write-up, and record why (don't ship a vacuous test — Verification Rule #9/#15).
10. **CHANGELOG.md** in BOTH repos — new `## 0.25.3 — 2026-07-04 (…)` head entry. Angular entry
    is an **Added** (the hook + wiring + log). dotnet entry notes the lockstep bump + the
    check-lockstep exception removal (no dotnet behavior change). Reference `(B-14)`.

## Verification (evidence-based — show command + observed output) [DoD: hook + installer + parity]

- **PS parse** both new `.ps1` via `[System.Management.Automation.Language.Parser]::ParseFile`.
- **`bash -n`** the new `.sh`.
- **BOM check** on `audit-trail.ps1` (Angular) — first bytes `EF BB BF`.
- **Hook behavior, both surfaces [#5]:** pipe a crafted Claude event and a Copilot event to the
  Angular `.ps1` and `.sh` from a temp CWD; assert a line lands in `.claude/ai-audit.log` with
  `EXIT=0`; pipe an `ai-audit.log`-path event and assert NO line. Show the log contents.
- **Angular artifact skip works:** pipe a `dist/…`/`node_modules/…` path event → NO line
  (this is the stack-specific bit the shared test can't cover — demonstrate it manually here).
- **Hook suites:** `tests/hooks/Invoke-HookTests.ps1` in BOTH repos → 0 failures (Angular count
  should rise: new AuditTrail test + TwinParity now covers audit-trail).
- **Meta suite:** `.claude/hooks/tests/Invoke-HookTests.ps1` → 7/7 (or current).
- **Parity gates:** `scripts/template-checks.ps1` ×2 (exit 0), `.claude/scripts/check-lockstep.ps1`
  (exit 0 — proves the removed exceptions don't break: audit-trail now name-set-matched, hooks.json
  regs identical), `scripts/docs-sync-check.ps1` ×2.
- **Install smoke:** `scripts/install.sh` (greenfield temp dir) for Angular → confirm
  `.claude/hooks/audit-trail.{ps1,sh}`, the settings/hooks.json wiring, and the seed
  `.claude/ai-audit.log` all land in the consumer copy.
- **Release:** `.claude/scripts/release.ps1 -Version 0.25.3 -Summary "…"` (it re-runs all gates
  and refuses on any failure), which commits + pushes both repos. If push is undesirable in the
  delivery environment, use `-NoPush` and report — but the standing policy is commit + push both.

## Watch-outs (cost real time historically)

- `tests/hooks` files must be **byte-identical** across repos (LEARNINGS: EOL-normalize;
  `[IO.File]::ReadAllText` needs absolute paths — process CWD ≠ `Set-Location`).
- Don't add a `matcher` to the hooks.json audit-trail entry (VS Code camelCase write tools) —
  the hook self-filters; mirror dotnet exactly.
- `.ps1` BOM is mandatory [#4] or PS 5.1 mis-parses.
- The Angular `.sh` KEEPS the SR 11-7 line — it's stack-agnostic; only the skip case changes.
- Grep from workspace root silently skips repo internals (.gitignore) — search inside repo paths.
```
