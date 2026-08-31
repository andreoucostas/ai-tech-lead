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
| **Framework-rules file arrival on update** | The carrier file arrives, but host consumption requires the one-time `CLAUDE.md` import migration; an un-migrated consumer receives only a `session-start` discovery pointer | The installer writes `.github/instructions/framework-rules.instructions.md`; `AGENTS.md` remains the mirror for AGENTS.md-native tools | The installer writes the same instruction file independently of Preview hooks |
| **Framework-rules host consumption** | **Observed 2026-08-05** through a subject/control `@import` canary with zero tool use; the Claude Code host version was not recorded, so this is historical evidence rather than a current version certificate | **Observed on CLI 1.0.77, 2026-08-05** in a three-way subject/positive/negative-control canary with zero tool use | **Observed once manually on VS Code 1.128 / Copilot Chat 0.56.0, 2026-08-05**; no transcript or tool-use check was captured, so treat it as narrow historical evidence, not blanket current certification |
| **Routing** (classify NL → run the workflow) | Instructed (framework-rules carrier §1) + per-prompt salience nudge (`route-prompt`) | Instructed (`AGENTS.md` §1 + carrier) + per-prompt injection through the single `userPromptSubmitted` entry (`route-prompt` JSON `additionalContext`, **CLI ≥ v1.0.65**; single-entry delivery observed on **CLI 1.0.80, 2026-08-18**; ignored by older versions) | Instructed (`AGENTS.md` §1 + carrier) + a registered Preview-hook injection shaped per the vendor docs; **live VS Code `userPromptSubmitted` consumption is unverified**. With Preview hooks disabled, instructed only |
| **Plan-gate** (plan + clarify before code) | Guaranteed-ish: injected per-prompt by `route-prompt` + Instructed (`§2`) | Injected per-prompt through the single composed entry (CLI ≥ v1.0.65; observed CLI 1.0.80, 2026-08-18) + Instructed | Preview-hook injection is registered but live consumption is unverified; otherwise instructed only |
| **Security pass** (auth/money/secrets → `/security-review`) | Injected per-prompt by `route-prompt` + Instructed (`§1`) | Injected per-prompt through the single composed entry (CLI ≥ v1.0.65; observed CLI 1.0.80, 2026-08-18) + Instructed | Preview-hook injection is registered but live consumption is unverified; otherwise instructed only |
| **Write hard-blocks** (secrets, test-defeats, suppressions) — **editor/file-write tools only** (see caveat below) | **Guaranteed** — `guard.*` PreToolUse, `exit 2` | **Guaranteed** — `guard.*` preToolUse, `permissionDecision` JSON deny | **Historically observed, not currently certified** — a Preview-hook `guard.*` deny was honoured end-to-end on **2026-06-25**, but the host and extension versions were not recorded. Preview hooks remain off by default and org-gated; verify the current host before relying on this path, otherwise it is **instructed only** |
| **Build / type-check feedback** (`post-write` surfaces a failed `dotnet build` / `tsc --noEmit` to the model) | **Guaranteed** — `post-write` PostToolUse, `exit 2` + stderr on failure | **Version-dependent** — CLI 1.0.68 fired the hook but discarded `additionalContext`; CLI 1.0.70 consumed the canary shape. Verify the installed CLI before relying on model-visible feedback. | **Unverified** — postToolUse model-consumption not tested on VS Code agent mode; assume not-surfaced until a canary confirms otherwise |
| **Boy Scout nudge** (`boy-scout-check` flags cleanup candidates) | **Guaranteed (soft)** — registered on the `Stop` event (`.claude/settings.json`); `additionalContext` reaches the model next turn. **Dedup semantics:** the sorted finding set is hashed to `.claude/.state/last-boy-scout-hash`; an *unchanged* set is silenced on later fires — so silence means "already flagged", **not** "resolved" — and any change to the set (one new or one fixed finding) re-surfaces the **full** current set. The state files are per-machine (git-ignored). | **Registered; lifecycle unverified** — `.github/hooks/hooks.json` registers the vendor-documented `agentStop` event (CLI ≥ 1.0.72), but live firing and the resulting queue write have not been observed. The next-prompt `userPromptSubmitted` delivery leg is separately observed on **CLI 1.0.80, 2026-08-18**; that does not prove the preceding turn-end leg. If the scan fires, the documented queue/dedup design remains advisory and per-machine. | **Unverified** — the current config registers `agentStop`, while VS Code documents the end-of-turn event as `Stop`. Preview-hook firing, event spelling, and scan-and-deliver timing all require a current local canary. |
| **Local write telemetry** (`audit-trail` may append one line for a supported editor/file-write event to `.claude/ai-audit.log`) | **Hook-dependent side-effect** — PostToolUse, only when the registered hook and interpreter run | **Hook-dependent side-effect** — postToolUse in a trusted folder, only when the registered hook and interpreter run | **Preview-hook-dependent side-effect** — only when Preview agent-hooks are enabled and the registered hook/interpreter run |

> **Scope caveat — write hooks only see supported editor/file-write events.** `guard.*` and
> `audit-trail.*` are registered on `Write`/`Edit` tool calls (Claude Code) and on Copilot tool calls
> carrying a file path + content — nothing else. A write routed through a **terminal/shell tool** —
> Claude Code's Bash/PowerShell tool running `sed -i`, `echo >>`, a heredoc, `Set-Content`, etc. —
> carries no `Write`/`Edit` payload, so neither the secrets/test-defeat/suppression floor nor the
> local telemetry hook fires on it. Externally written content is outside the same boundary.
> `.claude/ai-audit.log` is mutable and incomplete; it is diagnostic telemetry, not correctness,
> retention, regulatory, or compliance evidence. Wherever an agent can run shell commands, the
> `CLAUDE.md`/`AGENTS.md` rules remain the binding instruction for that path.

### Optional pre-commit convenience net

Pass `-GitHooks` to `install.ps1`, or `--git-hooks` to `install.sh`, to install an opt-in
pre-commit hook. It sends only staged added lines through the shipped guard, so inherited matching
content in a touched file is not reported and the guard's pattern list is not duplicated. Setup
refuses to write when `core.hooksPath`, an existing `.git/hooks/pre-commit`, or `.husky/` indicates
another hook owner.

This hook is a **bypassable convenience net, not enforcement**. `git commit --no-verify` skips it,
and clients or workflows that do not run local hooks remain outside its reach. Do not treat a
successful commit as a protection, guarantee, or gate supplied by this option.

## Why the differences (the load-bearing facts)
- **Claude Code** consumes `UserPromptSubmit` stdout and honours `PreToolUse` `exit 2`. `route-prompt` detects this surface (Claude events carry `hook_event_name`) and emits plain stdout there.
- **Copilot CLI** added `userPromptSubmitted` `additionalContext` injection in **v1.0.65** and hardened it in **v1.0.76**. On **CLI 1.0.80 (observed 2026-08-18)** only the last `userPromptSubmitted` entry is delivered, so the framework registers one `route-prompt` entry and composes routing, plan-gate, security-pass, and queued Boy Scout text inside it; `session-start` emits the same model-facing shape on its separate event. Older versions ignore it as a harmless no-op, so routing then rests entirely on `AGENTS.md`. The vendor documents `agentStop` from **v1.0.72** and the framework registers it, but its live firing has not been observed here. `preToolUse` deny was honoured on **CLI 1.0.70, 2026-07-17**.
- **`postToolUse` additionalContext is version-dependent, and it now works.** On **CLI 1.0.68** the hook fired but the value was captured and never forwarded to the model. On **CLI 1.0.80 (observed 2026-08-20)** it is delivered: after a real file write, an out-of-band token injected only by `postToolUse` came back verbatim. Check your installed CLI before relying on model-visible post-write feedback — and note that no part of the Boy Scout scan-and-deliver design depends on this channel either way, so that design is unaffected by which version you run.
- **Copilot in VS Code (agent mode)** is the framework's primary target (Bitbucket Data Center ⇒ no cloud agent). Its agent-hooks are **Preview, off by default, and may be disabled by your org admin.** One **2026-06-25** Preview-hook spike observed a `guard.*` deny end-to-end, but its host and extension versions were not recorded, so it is historical evidence rather than current certification. The vendor docs specify the `permissionDecision` and `additionalContext` shapes; live VS Code `userPromptSubmitted`, `postToolUse`, and `Stop` consumption remain unverified. Native `.github/instructions/` delivery is a separate mechanism and does not prove any Preview-hook lifecycle. With Preview hooks disabled, **every hook control on this surface is instruction-only.**
- The **cloud coding agent** and github.com repo-aware context are unavailable on Bitbucket Data Center (they need github.com-hosted repos), so they are out of scope here.

## What this means for you
- Run `pwsh scripts/framework-doctor.ps1` or `bash scripts/framework-doctor.sh` once on each developer machine to see which script-verifiable controls are live and which agent canaries still need a human observation.
- Treat the `AGENTS.md`/`CLAUDE.md` workflow rails as **binding**, not advisory — wherever hooks are off (Preview disabled, older CLI), they are the *only* thing standing between a casual prompt and an unreviewed change.
- If you want the deterministic write floor **and** the per-prompt salience injection in VS Code, **enable Preview agent-hooks**, confirm your org allows them, and canary each capability on the current host before relying on it.
- **`guard.sh`, `route-prompt.sh`, `session-start.sh`, `audit-trail.sh`, `post-write.sh`, and `boy-scout-check.sh` need a JSON parser** (`jq`, falling back to any working Python — `python3`, `python`, or the `py` launcher, each probed by actually running it, because a Windows install provides `python.exe` rather than `python3.exe` and the Microsoft Store alias resolves without being an interpreter) to emit/inspect JSON. Without one, `guard.sh` allows everything and prints a `write-guard INACTIVE` warning to stderr; the injection hooks silently fall back to plain stdout (which Copilot drops — the pre-v0.25.0 behavior). The `.ps1` twins have no such dependency; PowerShell parses JSON natively.
- The framework will not claim a control fires where it doesn't. If you find a doc or comment that implies otherwise, that's a bug — file it.

Cross-host behavioral scores are not directly comparable when the host chooses the model. Copilot
CLI `auto` mode has resolved comparable runs to different vendor models (`claude-haiku-4.5` and
`gpt-5-mini`), so a threshold difference against Claude Code would confound host behavior with model
behavior. Record the resolved model in any live-fire evidence and compare hosts only when the model
can be held constant or the results can be stratified by model.

> Status notes. Evidence is capability-specific: a dated host version on one row does not certify a
> sibling event. **Copilot CLI:** single-entry `userPromptSubmitted` delivery was observed on 1.0.80
> (2026-08-18), `preToolUse` deny on 1.0.70 (2026-07-17), and `postToolUse` model visibility on
> 1.0.80 (2026-08-20); `agentStop` firing and its queue write remain unverified. **VS Code Preview
> hooks:** the 2026-06-25 guard deny is a narrow historical observation with unrecorded versions,
> not current certification; prompt, post-tool, and Stop lifecycles remain unverified. **Folder trust
> is a prerequisite:** repository hooks do not run until the workspace folder is trusted. A hook
> process running or a direct fixture emitting valid output proves neither host consumption nor model
> visibility.
