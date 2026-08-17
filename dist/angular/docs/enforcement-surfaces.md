# Enforcement surfaces — what's *guaranteed* vs *instructed*

This framework runs across three agent surfaces. They do **not** enforce the same way, and pretending otherwise is how a team ends up trusting a guarantee that isn't there. This page is the honest matrix. (Researched against the Claude Code, GitHub Copilot CLI, and VS Code agent-hooks docs, June–July 2026.)

Three delivery tiers:
- **Guaranteed (hook-enforced):** a deterministic hook runs and the harness *acts* on its output (blocks a write, injects context) regardless of what the model "feels like" doing.
- **Instructed (model-read):** a rule lives in the framework-rules carrier, `CLAUDE.md`, or `AGENTS.md` and the model is asked to follow it. Strong, but the model *can* skip it under a casual prompt or long context.
- **On-demand / discoverable:** supporting material such as `docs/defaults.md` is available for the model to open, but loading is task- and model-dependent, not guaranteed. One agent was observed opening such a file unaided on 2026-07-31; that single observation does not establish a routing improvement or delivery guarantee.

## Before any hook can be guaranteed

> **The hook interpreter must resolve in the shell your agent uses to launch hooks.** If it does
> not, every control that hook carries is dead: no write guard, build feedback, or audit trail. The
> agent host shows the developer watching the transcript a hook-error notice and the first line of
> stderr, but the model never sees that error and none of this framework's own checks sees it.

A configuration-only diagnostic can therefore report healthy wiring while the hooks are dead. Treat
the developer-visible hook-error notice as a signal to act, then run `pwsh
scripts/framework-doctor.ps1` or `bash scripts/framework-doctor.sh` to check the wiring. A bare
interpreter name remains `CANT-VERIFY`: the doctor cannot observe the `PATH` of a shell it does not
launch. The bare name is intentional portable team configuration: an absolute interpreter path from
one developer's machine would break teammates on another OS or user profile. Do not "fix" a bare
name by pinning a local absolute path. Use the doctor's `Hook liveness` row and the host canaries to
prove what the agent actually launches; rerunning the installer restores the portable bare-name
wiring if an old machine-specific path is present.

The two doctor entry points report only evidence they can actually observe. The PowerShell doctor
cannot see the runtime `PATH` an agent will later supply to a registered `guard.sh`, so its `Guard
JSON parser` row is `CANT-VERIFY`; the Bash doctor can test a parser only in **that Bash
environment**. Likewise, `Stack toolchain` and Copilot CLI command visibility describe **this doctor
process environment**, not the later agent-host process. The write-guard canary proves the actual
host's parser/enforcement path. For build feedback, make and immediately revert a harmless compile
or type error through the actual agent after the post-write throttle has elapsed; only hook output
starting `## dotnet build failed` or `## tsc --noEmit failed` proves that host path.

## Matrix

| Capability | Claude Code | Copilot CLI | Copilot in VS Code (agent mode) |
|---|---|---|---|
| **Framework-rules delivery on update** | **Delivered** after the one-time `CLAUDE.md` import migration; an un-migrated consumer receives only a `session-start` discovery pointer, not proven precedence over stale inline rules | **Delivered automatically** through `.github/instructions/framework-rules.instructions.md`; `AGENTS.md` remains the mirror for AGENTS.md-native tools | **Delivered automatically** through the same native instruction file, independent of Preview hooks |
| **Routing** (classify NL → run the workflow) | Instructed (framework-rules carrier §1) + per-prompt salience nudge (`route-prompt`) | Instructed (`AGENTS.md` §1 + carrier) + per-prompt injection (`route-prompt` JSON `additionalContext`, **CLI ≥ v1.0.65**; ignored by older versions) | Instructed (`AGENTS.md` §1 + carrier) + per-prompt injection **only if Preview agent-hooks are enabled** (off by default, org-gated); otherwise instructed only |
| **Plan-gate** (plan + clarify before code) | Guaranteed-ish: injected per-prompt by `route-prompt` + Instructed (`§2`) | Injected per-prompt (CLI ≥ v1.0.65) + Instructed | Injected per-prompt if Preview hooks enabled; otherwise instructed only |
| **Security pass** (auth/money/secrets → `/security-review`) | Injected per-prompt by `route-prompt` + Instructed (`§1`) | Injected per-prompt (CLI ≥ v1.0.65) + Instructed | Injected per-prompt if Preview hooks enabled; otherwise instructed only |
| **Write hard-blocks** (secrets, test-defeats, suppressions) — **editor/file-write tools only** (see caveat below) | **Guaranteed** — `guard.*` PreToolUse, `exit 2` | **Guaranteed** — `guard.*` preToolUse, `permissionDecision` JSON deny | **Guaranteed *only if* Preview agent-hooks are enabled** (off by default, org-gated) — `guard.*` emits the VS Code `permissionDecision` shape; otherwise **instructed only** |
| **Build / type-check feedback** (`post-write` surfaces a failed `dotnet build` / `tsc --noEmit` to the model) | **Guaranteed** — `post-write` PostToolUse, `exit 2` + stderr on failure | **Version-dependent** — CLI 1.0.68 fired the hook but discarded `additionalContext`; CLI 1.0.70 consumed the canary shape. Verify the installed CLI before relying on model-visible feedback. | **Unverified** — postToolUse model-consumption not tested on VS Code agent mode; assume not-surfaced until a canary confirms otherwise |
| **Boy Scout nudge** (`boy-scout-check` flags cleanup candidates) | **Guaranteed (soft)** — registered on the `Stop` event (`.claude/settings.json`); `additionalContext` reaches the model next turn. **Dedup semantics:** the sorted finding set is hashed to `.claude/.state/last-boy-scout-hash`; an *unchanged* set is silenced on later fires — so silence means "already flagged", **not** "resolved" — and any change to the set (one new or one fixed finding) re-surfaces the **full** current set. The state files are per-machine (git-ignored). | **Guaranteed (soft), CLI ≥ 1.0.72** — scanned at `agentStop` when a write turn ends, then delivered at the next prompt through model-consumed `userPromptSubmitted` `additionalContext` (CLI ≥ 1.0.65). It no longer runs on read-only/question prompts. Dedup matches Claude: silence means "already flagged", not "resolved"; the per-machine state files are git-ignored. The queue is cleared on delivery, so a finding set is announced once per write-turn. | **Unverified** — the same registration is present, but consumption requires Preview agent-hooks and VS Code documents the end-of-turn event as `Stop`, not `agentStop`. Treat the scan-and-deliver timing as unverified until a local canary confirms it. |
| **Audit trail** (`audit-trail` appends AI file-changes to `.claude/ai-audit.log`; both stacks since v0.25.3) | **Guaranteed side-effect** — PostToolUse; a file append, independent of model consumption | **Guaranteed side-effect** — postToolUse hooks *do* fire (folder-trusted); the log append happens whether or not the model reads anything | **Guaranteed side-effect *only if* Preview agent-hooks are enabled** — same file append when the hook runs |

> **Scope caveat — the write floor only sees editor/file-write tools.** `guard.*` is registered on the `Write`/`Edit` tool calls (Claude Code) and on Copilot tool calls carrying a file path + content — nothing else. A write routed through a **terminal/shell tool** — Claude Code's `Bash`/PowerShell tool running `sed -i`, `echo >>`, a heredoc, `Set-Content`, etc. — carries no `Write`/`Edit` payload, so the secrets / test-defeat / suppression floor **does not fire on it at all**. The floor is a strong backstop on the editor path the agents use by default; it is **not** an all-writes guarantee. Wherever an agent can run shell commands, the `CLAUDE.md`/`AGENTS.md` rules (secrets, no test-defeats, no suppressions) are the binding control for that path — treat them as such.

## Why the differences (the load-bearing facts)
- **Claude Code** consumes `UserPromptSubmit` stdout and honours `PreToolUse` `exit 2`. `route-prompt` detects this surface (Claude events carry `hook_event_name`) and emits plain stdout there.
- **Copilot CLI** added `userPromptSubmitted` `additionalContext` injection in **v1.0.65** and hardened it in **v1.0.76**. `route-prompt`/`session-start` emit that model-facing shape for non-Claude surfaces; older versions ignore it as a harmless no-op, so routing then rests entirely on `AGENTS.md`. The `agentStop` event arrived in **v1.0.72**, enabling the Boy Scout scan after a turn. `preToolUse` JSON is honoured, so the write hard-blocks work regardless.
- **`postToolUse` additionalContext is unreliable**: a known CLI bug captures the value but does not forward it to the model. No part of the Boy Scout scan-and-deliver design depends on that channel.
- **Copilot in VS Code (agent mode)** is the framework's primary target (Bitbucket Data Center ⇒ no cloud agent). Its agent-hooks are **Preview, off by default, and may be disabled by your org admin.** When enabled, `guard.*` blocks via the `permissionDecision` JSON shape and `route-prompt`/`session-start` inject `additionalContext` per the VS Code agent-hooks docs; when not, **every control on this surface is instruction-only.**
- The **cloud coding agent** and github.com repo-aware context are unavailable on Bitbucket Data Center (they need github.com-hosted repos), so they are out of scope here.

## What this means for you
- Run `pwsh scripts/framework-doctor.ps1` or `bash scripts/framework-doctor.sh` once on each developer machine to see which script-verifiable controls are live and which agent canaries still need a human observation.
- Treat the `AGENTS.md`/`CLAUDE.md` workflow rails as **binding**, not advisory — wherever hooks are off (Preview disabled, older CLI), they are the *only* thing standing between a casual prompt and an unreviewed change.
- If you want the deterministic write floor **and** the per-prompt salience injection in VS Code, **enable Preview agent-hooks** (and confirm your org allows them).
- **`guard.sh`, `route-prompt.sh`, `session-start.sh`, `audit-trail.sh`, `post-write.sh`, and `boy-scout-check.sh` need a JSON parser** (`jq`, falling back to any working Python — `python3`, `python`, or the `py` launcher, each probed by actually running it, because a Windows install provides `python.exe` rather than `python3.exe` and the Microsoft Store alias resolves without being an interpreter) to emit/inspect JSON. Without one, `guard.sh` allows everything and prints a `write-guard INACTIVE` warning to stderr; the injection hooks silently fall back to plain stdout (which Copilot drops — the pre-v0.25.0 behavior). The `.ps1` twins have no such dependency; PowerShell parses JSON natively.
- The framework will not claim a control fires where it doesn't. If you find a doc or comment that implies otherwise, that's a bug — file it.

Cross-host behavioral scores are not directly comparable when the host chooses the model. Copilot
CLI `auto` mode has resolved comparable runs to different vendor models (`claude-haiku-4.5` and
`gpt-5-mini`), so a threshold difference against Claude Code would confound host behavior with model
behavior. Record the resolved model in any live-fire evidence and compare hosts only when the model
can be held constant or the results can be stratified by model.

> Status notes. **Write hard-blocks:** VS Code agent mode with Preview agent-hooks has been verified end-to-end with the `permissionDecision` shape emitted by `guard.*`. **Boy Scout timing:** Copilot CLI ≥ 1.0.72 can scan at `agentStop`, then CLI ≥ 1.0.65 can deliver the queued nudge through `userPromptSubmitted`; injection was hardened in 1.0.76. The VS Code `Stop` spelling and scan-and-deliver path remain unverified because agent-hooks are Preview and off by default. **Folder trust is a prerequisite:** repository hooks do not run until the workspace folder is trusted, and non-interactive mode cannot grant that trust. **Post-tool feedback is unreliable:** a known CLI bug captures `postToolUse` `additionalContext` without forwarding it, so do not rely on model visibility merely because that hook process ran.
