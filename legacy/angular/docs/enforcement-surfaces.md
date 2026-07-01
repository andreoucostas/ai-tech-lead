# Enforcement surfaces — what's *guaranteed* vs *instructed*

This framework runs across three agent surfaces. They do **not** enforce the same way, and pretending otherwise is how a team ends up trusting a guarantee that isn't there. This page is the honest matrix. (Researched against the Claude Code, GitHub Copilot CLI, and VS Code agent-hooks docs, June 2026.)

Two kinds of control:
- **Guaranteed (hook-enforced):** a deterministic hook runs and the harness *acts* on its output (blocks a write, injects context) regardless of what the model "feels like" doing.
- **Instructed (model-read):** a rule lives in `CLAUDE.md` / `AGENTS.md` and the model is asked to follow it. Strong, but the model *can* skip it under a casual prompt or long context.

## Matrix

| Capability | Claude Code | Copilot CLI | Copilot in VS Code (agent mode) |
|---|---|---|---|
| **Routing** (classify NL → run the workflow) | Instructed (`CLAUDE.md §1`) + per-prompt salience nudge (`route-prompt`) | **Instructed only** (`AGENTS.md §1`) — `userPromptSubmitted` stdout is discarded | **Instructed only** (`AGENTS.md §1`) — no consumed prompt event |
| **Plan-gate** (plan + clarify before code) | Guaranteed-ish: injected per-prompt by `route-prompt` + Instructed (`§2`) | Instructed only | Instructed only |
| **Security pass** (auth/money/secrets → `/security-review`) | Injected per-prompt by `route-prompt` + Instructed (`§1`) | Instructed only | Instructed only |
| **Write hard-blocks** (secrets, test-defeats, suppressions) | **Guaranteed** — `guard.*` PreToolUse, `exit 2` | **Guaranteed** — `guard.*` preToolUse, `permissionDecision` JSON deny | **Guaranteed *only if* Preview agent-hooks are enabled** (off by default, org-gated) — `guard.*` emits the VS Code `permissionDecision` shape; otherwise **instructed only** |

## Why the differences (the load-bearing facts)
- **Claude Code** consumes `UserPromptSubmit` stdout and honours `PreToolUse` `exit 2`. It is the only surface where routing/plan-gate/security get a deterministic per-prompt nudge.
- **Copilot CLI** discards `sessionStart`/`userPromptSubmitted` stdout (log-only), so **no hook can inject routing or plan-gate context** there — those rest entirely on `AGENTS.md`. But `preToolUse` JSON *is* honoured, so the write hard-blocks work.
- **Copilot in VS Code (agent mode)** is the framework's primary target (Bitbucket Data Center ⇒ no cloud agent). Its agent-hooks are **Preview, off by default, and may be disabled by your org admin.** When enabled, `guard.*` blocks via the `permissionDecision` JSON shape; when not, **every control on this surface is instruction-only.** There is no per-prompt injection on VS Code regardless.
- The **cloud coding agent** and github.com repo-aware context are unavailable on Bitbucket Data Center (they need github.com-hosted repos), so they are out of scope here.

## What this means for you
- Treat the `AGENTS.md`/`CLAUDE.md` workflow rails as **binding**, not advisory — on Copilot they are usually the *only* thing standing between a casual prompt and an unreviewed change.
- If you want the deterministic write floor in VS Code, **enable Preview agent-hooks** (and confirm your org allows them). Until then, the guard is a Claude-Code + Copilot-CLI guarantee only.
- **`guard.sh` needs a JSON parser** (`jq`, with `python3` as fallback). On a box with neither it cannot inspect writes: it allows everything and prints a `write-guard INACTIVE` warning to stderr. If that warning appears in hook logs, install `jq` — until then the write floor on that machine is instruction-only. (`guard.ps1` has no such dependency; PowerShell parses JSON natively.)
- The framework will not claim a control fires where it doesn't. If you find a doc or comment that implies otherwise, that's a bug — file it.

> Status note: the VS Code `permissionDecision` path is implemented in `guard.*` and **verified end-to-end** against VS Code agent mode — with Preview agent-hooks enabled, a blocked write (e.g. a `create` carrying a secret) is denied at runtime and the reason is surfaced to the model. The captured payload uses the Anthropic text-editor tool schema (`create` → `path` + `file_text`; `str_replace`/`insert` → `new_str`), which `guard.*` reads. If your environment cannot enable Preview hooks, the VS Code column degrades to "instructed only" — by design, not by omission.
