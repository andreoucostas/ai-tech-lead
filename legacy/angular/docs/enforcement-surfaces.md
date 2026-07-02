# Enforcement surfaces — what's *guaranteed* vs *instructed*

This framework runs across three agent surfaces. They do **not** enforce the same way, and pretending otherwise is how a team ends up trusting a guarantee that isn't there. This page is the honest matrix. (Researched against the Claude Code, GitHub Copilot CLI, and VS Code agent-hooks docs, June–July 2026.)

Two kinds of control:
- **Guaranteed (hook-enforced):** a deterministic hook runs and the harness *acts* on its output (blocks a write, injects context) regardless of what the model "feels like" doing.
- **Instructed (model-read):** a rule lives in `CLAUDE.md` / `AGENTS.md` and the model is asked to follow it. Strong, but the model *can* skip it under a casual prompt or long context.

## Matrix

| Capability | Claude Code | Copilot CLI | Copilot in VS Code (agent mode) |
|---|---|---|---|
| **Routing** (classify NL → run the workflow) | Instructed (`CLAUDE.md §1`) + per-prompt salience nudge (`route-prompt`) | Instructed (`AGENTS.md §1`) + per-prompt injection (`route-prompt` JSON `additionalContext`, **CLI ≥ v1.0.65**; ignored by older versions) | Instructed (`AGENTS.md §1`) + per-prompt injection **only if Preview agent-hooks are enabled** (off by default, org-gated); otherwise instructed only |
| **Plan-gate** (plan + clarify before code) | Guaranteed-ish: injected per-prompt by `route-prompt` + Instructed (`§2`) | Injected per-prompt (CLI ≥ v1.0.65) + Instructed | Injected per-prompt if Preview hooks enabled; otherwise instructed only |
| **Security pass** (auth/money/secrets → `/security-review`) | Injected per-prompt by `route-prompt` + Instructed (`§1`) | Injected per-prompt (CLI ≥ v1.0.65) + Instructed | Injected per-prompt if Preview hooks enabled; otherwise instructed only |
| **Write hard-blocks** (secrets, test-defeats, suppressions) | **Guaranteed** — `guard.*` PreToolUse, `exit 2` | **Guaranteed** — `guard.*` preToolUse, `permissionDecision` JSON deny | **Guaranteed *only if* Preview agent-hooks are enabled** (off by default, org-gated) — `guard.*` emits the VS Code `permissionDecision` shape; otherwise **instructed only** |

## Why the differences (the load-bearing facts)
- **Claude Code** consumes `UserPromptSubmit` stdout and honours `PreToolUse` `exit 2`. `route-prompt` detects this surface (Claude events carry `hook_event_name`) and emits plain stdout there.
- **Copilot CLI** historically discarded `sessionStart`/`userPromptSubmitted` stdout; since **v1.0.65** it injects the hook's JSON `additionalContext` into the model-facing prompt, and `route-prompt`/`session-start` emit that shape for non-Claude surfaces (registered in `.github/hooks/hooks.json` since v0.25.0). On older CLI versions the JSON is ignored — a harmless no-op, and routing rests entirely on `AGENTS.md`. `preToolUse` JSON is honoured, so the write hard-blocks work regardless.
- **Copilot in VS Code (agent mode)** is the framework's primary target (Bitbucket Data Center ⇒ no cloud agent). Its agent-hooks are **Preview, off by default, and may be disabled by your org admin.** When enabled, `guard.*` blocks via the `permissionDecision` JSON shape and `route-prompt`/`session-start` inject `additionalContext` per the VS Code agent-hooks docs; when not, **every control on this surface is instruction-only.**
- The **cloud coding agent** and github.com repo-aware context are unavailable on Bitbucket Data Center (they need github.com-hosted repos), so they are out of scope here.

## What this means for you
- Treat the `AGENTS.md`/`CLAUDE.md` workflow rails as **binding**, not advisory — wherever hooks are off (Preview disabled, older CLI), they are the *only* thing standing between a casual prompt and an unreviewed change.
- If you want the deterministic write floor **and** the per-prompt salience injection in VS Code, **enable Preview agent-hooks** (and confirm your org allows them).
- **`guard.sh`, `route-prompt.sh`, and `session-start.sh` need a JSON parser** (`jq`, with `python3` as fallback) to emit/inspect JSON. Without one, `guard.sh` allows everything and prints a `write-guard INACTIVE` warning to stderr; the injection hooks silently fall back to plain stdout (which Copilot drops — the pre-v0.25.0 behavior). The `.ps1` twins have no such dependency; PowerShell parses JSON natively.
- The framework will not claim a control fires where it doesn't. If you find a doc or comment that implies otherwise, that's a bug — file it.

> Status notes. **Write hard-blocks:** the VS Code `permissionDecision` path is implemented in `guard.*` and **verified end-to-end** against VS Code agent mode — with Preview agent-hooks enabled, a blocked write (e.g. a `create` carrying a secret) is denied at runtime and the reason is surfaced to the model. The captured payload uses the Anthropic text-editor tool schema (`create` → `path` + `file_text`; `str_replace`/`insert` → `new_str`), which `guard.*` reads. **Prompt injection (v0.25.0):** the `additionalContext` output shapes are fixture-tested on both twins, and consumption is documented by the official VS Code agent-hooks docs and the Copilot CLI changelog (≥ v1.0.65) — but this path has **not yet been live-verified end-to-end** by the maintainer (the github.com hooks-reference page still lags with "output processed: No"). Verify on your install: submit "fix the broken date formatting" in agent mode and check whether the response opens by classifying the intent against the injected rails. If it does not, you are on the instructed-only tier for routing — the rails in `AGENTS.md §1` still bind.
