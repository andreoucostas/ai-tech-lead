# Enforcement surfaces — what's *guaranteed* vs *instructed*

This framework runs across three agent surfaces, and VS Code runs Copilot in two harnesses that treat hooks differently. They do **not** enforce the same way, and pretending otherwise is how a team ends up trusting a guarantee that isn't there. This page is the honest matrix. (Researched against the Claude Code, GitHub Copilot CLI, and VS Code agent-hooks docs, June–July 2026; VS Code's two harnesses re-checked on 2026-10-12 against its hooks page approved 2026-10-07, its 1.141 release notes, and GitHub's Copilot hooks reference.)

**Supported execution is Windows only.** Claude Code 2.1.141 or newer is required for its PowerShell tool and hook-shell settings. PowerShell 7 (`pwsh`) is primary and native Windows PowerShell 5.1 is the Claude Code fallback. Git Bash, WSL, native Linux, macOS/BSD, and Copilot coding-agent cloud hook execution are unsupported. Local Windows Copilot hooks explicitly invoke `pwsh`.

Three delivery tiers:
- **Guaranteed (hook-enforced):** a deterministic hook runs and the harness *acts* on its output (blocks a write, injects context) regardless of what the model "feels like" doing.
- **Instructed (model-read):** a rule lives in the framework-rules carrier or `AGENTS.md` and the model is asked to follow it. Strong, but the model *can* skip it under a casual prompt or long context.
- **On-demand / discoverable:** supporting material such as `docs/defaults.md` is available for the model to open, but loading is task- and model-dependent, not guaranteed. One agent was observed opening such a file unaided on 2026-07-31; that single observation does not establish a routing improvement or delivery guarantee.

## Before any hook can be guaranteed

> **The registered PowerShell interpreter must resolve in the Windows agent host.** If it does
> not, every control that hook carries is dead: no write guard, build feedback, or audit trail. The
> host may show a launch-error notice, but the model may not receive it.
>
> **On Copilot a missing `pwsh` stops the agent.** `.github/hooks/hooks.json` runs every hook with
> `pwsh` (PowerShell 7). Without it the guard's `preToolUse` hook errors, and Copilot refuses every
> tool call ("Denied by preToolUse hook … (hook errored)"), so the agent cannot change anything
> (observed on Copilot CLI 1.0.89, 2026-10-05, and on the runtime behind VS Code 1.139.1's Copilot
> harness, 2026-10-12). VS Code's Local harness documents a warning instead and carries on, with
> every hook control dead. Install PowerShell 7 on every machine that runs Copilot; the doctor's
> `Copilot surface` row reports it when run under `powershell.exe`.

A configuration-only diagnostic can report healthy wiring while hooks are dead. Run
`pwsh -NoProfile -File scripts/framework-doctor.ps1` on each Windows developer machine, or use
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/framework-doctor.ps1` when PowerShell
7 is unavailable. A bare executable name remains `CANT-VERIFY`: the doctor cannot observe the
later agent-host process. The bare name is intentional team configuration across Windows machines;
do not pin one developer's absolute path. Use the doctor's `Hook liveness` row and actual-host
canaries. Stack-toolchain and Copilot CLI visibility likewise describe the doctor process, not the
later agent-host process. The write-guard canary proves the actual host's enforcement path: after its
summary the doctor prints it for each host (ask the agent to create `tmp-doctor-canary.txt` containing
`AKIA` plus 16 uppercase letters or digits; pass = the hook answers "Blocked write to"; a polite refusal
is not a pass; delete the file if it lands). For build feedback, make and immediately revert a harmless compile
or type error in a .NET source file or an Angular application source file through the actual agent after the
post-write throttle has elapsed; only hook output
starting `## dotnet build failed`, `## tsc --noEmit failed` or, after an Angular template write,
`## ngc --noEmit failed` proves that host path. The hook gives
the build or type-check 45 seconds (`ATL_POSTWRITE_BUDGET_SEC`, 1-600, overrides it); a run that
exceeds the budget is stopped and reports nothing, and the next one waits five minutes. A .NET build that
could not run because the packages were never restored (NETSDK1004/1005) reports "Build not verified" and
asks for one `dotnet restore`, then waits the same five minutes. An Angular workspace with no
`tsconfig.app.json` whose `tsconfig.json` is solution-style (`"files": []` plus `"references"`, the CLI's
layout since v20), such as a library-only workspace, reports "Type-check not verified" instead of checking,
then waits the same five minutes.

## Organization policies that switch these controls off

Your organization can switch this framework's Copilot controls off centrally, outside this repository, and nothing
here can see it: the doctor reads only this repository and its own process, so it keeps reporting the hooks wired.
The write-guard canary above stays the proof, run on each surface with the model your team uses. "Blocked write to"
shows that the guard ran there; a file that lands shows only that the guard did not block that write (a policy
below, folder trust not given, or a write tool outside the guard's scope, see the scope caveat under the matrix);
a refusal shows nothing. Ask your administrator which of these your organization sets. Checked on 2026-10-12
against VS Code's enterprise AI-settings page and policy reference (approved 2026-10-07), GitHub's
enterprise-managed settings reference, hooks reference and changelog, and the code that VS Code 1.139.1 and Copilot
CLI 1.0.95 install; "not established" means none of these settles it and it was not observed.

- **`ChatHooks` set to false** (VS Code device policy, 1.109 and later) turns off every hook in VS Code's Local
  harness. VS Code says it does not apply to the Copilot harness.
- **`ChatAllowManagedHooksOnly`** (VS Code device policy, 1.132 and later) and **`allowManagedHooksOnly`** (Copilot
  managed setting) let only the hooks your enterprise manages, and those of plugins its policy force-enables, run.
  This framework's six hooks are repository hooks, so none runs: no write guard, build feedback, per-prompt rails,
  session preload, Boy Scout nudge or audit line. VS Code 1.139.1 applies either form to the hooks it loads itself,
  which covers the Local harness, and Copilot CLI 1.0.95's settings schema says that under it "User,
  workspace/project, and otherwise user-enabled plugin hooks are blocked". VS Code's Copilot harness is not
  established: the runtime VS Code 1.139.1 bundles carries the same lockdown, but VS Code's Agent Host starts every
  Copilot session with repository hook files on and passes the runtime none of these settings.
- **`ChatStrictPluginOnlyCustomization`** (VS Code device policy, 1.132 and later) and
  **`strictPluginOnlyCustomization`** (Copilot managed setting) block standalone user and workspace customizations
  and keep only what plugins provide. In VS Code that covers skills, custom agents, hooks, instruction files and MCP
  servers, and VS Code 1.139.1 skips `AGENTS.md` and `CLAUDE.md` too, so in the Local harness none of this
  framework's rules, skills, agents or hooks load. In Copilot CLI 1.0.95's schema it covers skills, custom agents,
  hooks and MCP servers, or only those it lists; instruction files are not among them, so `AGENTS.md` and the
  framework-rules file should still load there (not observed). VS Code's Copilot harness is not established, as
  above. GitHub's enterprise-managed settings reference lists neither Copilot key; the CLI's schema defines both.
- **Managed permission rules** (`permissions.deny`, `ask` and `allow`; generally available on 2026-09-09 in Copilot
  CLI, the Copilot app and VS Code's Copilot harness) block, or require approval for, the agent's own operations:
  shell commands, file reads and edits, and network domains. Hooks and customization files are not among them, so
  these rules switch none of this framework's controls off. A deny rule that matches a command a framework workflow
  asks the agent to run, such as `/review`'s `scripts/review-scope.ps1`, blocks that step like any other command.
- **Managed sandboxing** (`sandbox`; local sandboxing generally available on 2026-10-07 in Copilot CLI, the Copilot
  app and VS Code's Copilot harness, where GitHub lists the managed setting from 1.138 and VS Code calls its
  enforcement Preview and its Windows support experimental) lets your organization require the sandbox. GitHub's
  hooks reference says that in a sandboxed Copilot CLI session repository hooks run inside the sandbox with the
  agent's shell access, that a hook failing there gets one warning per hook and session, and that a failing
  `preToolUse` hook denies the tool call while one that times out lets it through (the guard's limit is 10 seconds).
  Observed once, on Copilot CLI 1.0.95 with its own `--sandbox` and default policy (2026-10-12): every hook that
  fired ended successfully, and the guard still blocked a key-shaped write, taking up to 3.9 seconds a call against
  up to 1.9 outside the sandbox; but the session preload arrived as its heading alone, and no audit line or hook
  state was written to the repository, all of which the same hooks produce outside the sandbox. Why is not
  established, nor whether VS Code's Copilot harness runs hooks inside its sandbox.

To see which apply on a machine: in VS Code, **Developer: Policy Diagnostics** lists the policies applied there and
their sources, including enterprise-managed settings that map to a VS Code policy. `/sandbox` in Copilot CLI, and
`/sandbox policy` in a session on VS Code's Copilot harness, show whether sandboxing is on and what your
organization enforces.

## Matrix

| Capability | Claude Code | Copilot CLI | VS Code: Copilot harness | VS Code: Local harness |
|---|---|---|---|---|
| **Framework-rules file arrival on update** | The carrier file arrives; Claude Code consumes it through the `CLAUDE.md` stub's import, which the installer's one-time instruction-file migration writes. A consumer left to merge by hand receives only a `session-start` discovery pointer until its `CLAUDE.md` has that import | The installer writes `.github/instructions/framework-rules.instructions.md`; `AGENTS.md`'s header points AGENTS.md-only tools at it | The installer writes the same instruction file; no hook is involved | The installer writes the same instruction file independently of Preview hooks |
| **Framework-rules host consumption** | **Observed 2026-08-05** through a subject/control `@import` canary with zero tool use; the Claude Code host version was not recorded, so this is historical evidence rather than a current version certificate | **Observed on CLI 1.0.77, 2026-08-05** in a three-way subject/positive/negative-control canary with zero tool use | **Not observed** on this harness | **Observed once manually on VS Code 1.128 / Copilot Chat 0.56.0, 2026-08-05**; no transcript or tool-use check was captured, so treat it as narrow historical evidence, not blanket current certification |
| **Routing** (classify NL → run the workflow) | Instructed (framework-rules carrier §1) + per-prompt salience nudge (`route-prompt`) | Instructed (framework-rules carrier §1) + per-prompt injection through the single `userPromptSubmitted` entry (`route-prompt` JSON `additionalContext`, **CLI ≥ v1.0.65**; single-entry delivery observed on **CLI 1.0.80, 2026-08-18**; ignored by older versions) | Instructed (framework-rules carrier §1) + the same single `userPromptSubmitted` entry as the CLI, run from both hook files; **on the harness's runtime (VS Code 1.139.1's, run without VS Code's window, 2026-10-12) the routed rails reached the prompt once**, 2 of 2 runs; not yet observed in VS Code itself | Instructed (framework-rules carrier §1) + a registered Preview-hook injection shaped per the vendor docs; **live VS Code `userPromptSubmitted` consumption is unverified**. With Preview hooks disabled, instructed only |
| **Plan-gate** (plan + clarify before code) | Guaranteed-ish: injected per-prompt by `route-prompt` + Instructed (`§2`) | Injected per-prompt through the single composed entry (CLI ≥ v1.0.65; observed CLI 1.0.80, 2026-08-18) + Instructed | Injected per-prompt through the same entry (seen in the harness runtime's prompt, as above) + Instructed | Preview-hook injection is registered but live consumption is unverified; otherwise instructed only |
| **Security pass** (auth/money/secrets → the `security-gate` skill or `security-auditor`) | Injected per-prompt by `route-prompt` + Instructed (`§1`) | Injected per-prompt through the single composed entry (CLI ≥ v1.0.65; observed CLI 1.0.80, 2026-08-18) + Instructed. **Observed on CLI 1.0.95, 2026-10-11** (one .NET repository, non-interactive `-p`, the change approved in advance): when the reminder fired, the agent ran a pass every time, but in 3 of 6 runs it was the CLI's built-in Security Review Agent, not this framework's review (with 0.93.0's wording, 4 of 6), while this framework's skill was still named `security-review`, like the CLI's agent; renamed `security-gate` in 0.95.0, the same change ran this framework's review in 6 of 6 runs and the built-in in none; on a sensitive change the reminder's keywords missed (an API-key check), no pass ran in 6 of 6. Once 0.95.0's keywords made the reminder fire on that change, a pass ran in 4 of 4, and without the advance approval the always-loaded rule alone got one in 4 of 4: an approval given in advance suppressed the rule, not the reminder; asked for this framework's skill by its name, the agent ran it in 2 of 3 | Injected per-prompt through the same entry + Instructed; which review the agent's own pass runs on this harness is unmeasured | Preview-hook injection is registered but live consumption is unverified; otherwise instructed only |
| **Write hard-blocks** (secrets, test-defeats, suppressions) — **editor/file-write tools only** (see caveat below) | **Guaranteed** — `guard.ps1` PreToolUse, `exit 2`; **observed end-to-end on Claude Code 2.1.281, 2026-09-30**: a key-shaped `Write` was blocked and the agent retried safely, while the same task without the framework left the key on disk. This covers the `Write` tool, not shell writes or split edits (caveats below) | **Guaranteed** — `guard.ps1` preToolUse, `permissionDecision` JSON deny, for the `create`, `edit` and `apply_patch` file tools. **Not so before 0.96.0 for `apply_patch`**, the tool GPT models write with: the guard did not read its patch, so every such write passed unchecked, and on CLI 1.0.95 gpt-6.1-sol wrote the doctor's key-shaped canary 2 of 2. **Observed on CLI 1.0.95**: claude-sonnet-5's key-shaped `create` denied each of the 2 times it was attempted (2026-10-12), and with 0.96.0 gpt-6.1-sol's key-shaped `apply_patch` denied 3 of 3 (2026-10-14) | **Documented, not yet observed** — the harness uses Copilot CLI's hook implementation, so `guard.ps1`'s `permissionDecision` deny applies; on its runtime (2026-10-12) a test `preToolUse` hook registered in both hook files the way the framework registers `guard.ps1` ran from each on a file creation, and a deny from either blocks the write. With this framework installed the runs never reached a key-shaped write: the model declined the canary request first, 2 of 2. GPT models write through `apply_patch`, which the guard reads from 0.96.0: on the same runtime, gpt-6.1-sol's key-shaped `apply_patch` was denied 1 of 1 (2026-10-14) | **Historically observed, not currently certified** — a Preview-hook `guard.ps1` deny was honoured end-to-end on **2026-06-25**, but the host and extension versions were not recorded. Preview hooks are on by default in a trusted workspace (`chat.useHooks`) and your organization can turn them off; verify the current host before relying on this path, otherwise it is **instructed only**. Its `apply_patch` tool passes the patch as `tool_input.input`, which the guard reads from 0.96.0 (per the extension's source; not observed) |
| **Build / type-check feedback** (`post-write` surfaces a failed `dotnet build` / `tsc --noEmit`, or `ngc --noEmit` after an Angular template write, to the model; throttled, see caveat below) | **Guaranteed** — `post-write` PostToolUse, `exit 2` + stderr on failure | **Version-dependent** — CLI 1.0.68 fired the hook but discarded `additionalContext`; CLI 1.0.70 consumed the canary shape. Verify the installed CLI before relying on model-visible feedback. | **Unverified** — `postToolUse` context reached the model on CLI 1.0.80, not yet on this harness. On its runtime (2026-10-12) a test `postToolUse` hook registered in both hook files the way the framework registers `post-write` ran from each on a file creation, so `post-write` can build or type-check twice for one write | **Unverified** — postToolUse model-consumption not tested on VS Code agent mode; assume not-surfaced until a canary confirms otherwise |
| **Boy Scout nudge** (`boy-scout-check` flags cleanup candidates) | **Guaranteed (soft)** — registered on the `Stop` event (`.claude/settings.json`); Claude Code continues the turn once with the candidates as context (observed on Claude Code 2.1.281, 2026-09-28), so each new finding set costs one more model response. **Dedup semantics:** the sorted finding set is hashed to `.claude/.state/last-boy-scout-hash`; an *unchanged* set is silenced on later fires — so silence means "already flagged", **not** "resolved" — and any change to the set (one new or one fixed finding) re-surfaces the **full** current set. The state files are per-machine (git-ignored). | **Registered; lifecycle unverified** — `.github/hooks/hooks.json` registers the vendor-documented `agentStop` event (CLI ≥ 1.0.72), but live firing and the resulting queue write have not been observed. The next-prompt `userPromptSubmitted` delivery leg is separately observed on **CLI 1.0.80, 2026-08-18**; that does not prove the preceding turn-end leg. If the scan fires, the documented queue/dedup design remains advisory and per-machine. | **Queued on the harness's runtime, 2026-10-12** — `agentStop` fired at the end of the turn and `hooks.json`'s scan queued the candidate for the next prompt, 2 of 2 runs; that delivery was not observed there. Both hook files' end-of-turn entries run, `hooks.json`'s first (the order GitHub's hooks reference lists them in); the queue relies on that order: run first, the `.claude/settings.json` copy would mark the findings as already flagged without queueing them | **Unverified** — the current config registers `agentStop`, while VS Code documents the end-of-turn event as `Stop`. Preview-hook firing, event spelling, and scan-and-deliver timing all require a current local canary. |
| **Local write telemetry** (`audit-trail` may append one line for a supported editor/file-write event to `.claude/ai-audit.log`) | **Hook-dependent side-effect** — PostToolUse, only when the registered hook and interpreter run | **Hook-dependent side-effect** — postToolUse in a trusted folder, only when the registered hook and interpreter run | **Hook-dependent side-effect** — `postToolUse`; a test hook registered in both hook files the way the framework registers `audit-trail` ran from each on a file creation on its runtime (2026-10-12), so one write can log two lines | **Preview-hook-dependent side-effect** — only when Preview agent-hooks are enabled and the registered hook/interpreter run |

> **Scope caveat — write hooks only see supported editor/file-write events.** `guard.ps1` is
> registered on `Write`/`Edit` tool calls (Claude Code) and on Copilot tool calls that carry a file
> path + content or an `apply_patch` patch (the patch only from 0.96.0; before, every `apply_patch`
> write passed unchecked) — nothing else. `audit-trail.ps1` and `post-write` see only the file path +
> content calls, so an `apply_patch` write gets no audit line and no build or type-check feedback. A write routed through a **terminal/shell tool** —
> Claude Code's PowerShell tool running `Set-Content`, `Add-Content`, or redirection —
> carries no `Write`/`Edit` payload, so neither the secrets/test-defeat/suppression floor nor the
> local telemetry hook fires on it. Externally written content is outside the same boundary.
> `.claude/ai-audit.log` is mutable and incomplete; it is diagnostic telemetry, not correctness,
> retention, regulatory, or compliance evidence. Wherever an agent can run shell commands, the
> framework-rules carrier and `AGENTS.md` rules remain the binding instruction for that path.

> **Scope caveat — build feedback is throttled, and no hook runs your tests.** `post-write` sees the
> same editor/file-write events as the guard, and skips `dotnet build` for 60 s after starting one
> (`tsc`, and separately the Angular template check, for 5 s) as well as during the five-minute wait
> above, so a turn can end with its last edit unbuilt. Only a template file's own write runs the template
> check: a `.ts` edit that breaks a template binding, or an inline `template:`, gets `tsc`, which does not
> read templates. The Angular checks compile the application's `tsconfig.app.json`, so a spec or library
> file it does not include is not checked, and its write passes silently. No framework hook runs your test suite or your `Verification Commands` rows; the agent
> runs them under your permissions, as the framework rules require.

> **Scope caveat — on an edit, the guard reads the replacement text, not the resulting file.** A
> whole-file write carries the finished content, so the secrets floor sees all of it. An **edit**
> carries only the new text, and `guard.ps1` never reads the file that edit produces. Two misses
> follow, both reproduced against the shipped hook on **2026-09-20**: a credential whose key sits in
> the surrounding line, with only the value replaced, is not matched; and a key split across two
> edits passes both times, because neither fragment matches on its own. An `apply_patch` patch is
> read the same way: the lines it adds to each file, checked against that file's path (and its new
> path when the patch moves it), never its context or removed lines; a patch with more than 200 file
> sections, or an `apply_patch` call the guard cannot read, is blocked. **This is a stated limit,
> not a control.** Scanning the pre-edit file together with the new text is not the fix — that
> refuses the edit which *removes* a leaked key, and a scanner that blocks the cleanup is worse than
> the gap it closes. Reconstructing the post-edit file is sound, but it needs each host's edit
> semantics, and this hook deliberately accepts file-write tools it cannot enumerate (the "file path
> + content" rule above). So the floor catches a secret written as one payload; `/security-gate`,
> code review, and your own platform's secret scanning remain the net for the rest.

> **What the secrets floor matches.** In any file: a private-key block, an AWS access key id
> (`AKIA…`), a GitHub token (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`, `github_pat_`), a Slack token
> (`xox…`), an `sk-` API key where a key starts (OpenAI, Anthropic and others), a Google API key
> (`AIza…`), an Azure storage account key, and an Azure SAS signature. Outside test, spec, mock,
> fixture, example, sample and `Development` paths, also a quoted value of 8 or more characters
> assigned to a name ending in password, secret, API key, access key or client secret, and a
> connection string with a password of 4 or more characters or a `user:password@` address, whether
> under a `connectionString` key or in a quoted `"ConnectionStrings": { … }` object such as
> `appsettings.json`'s. Every match, and every password inside a matched connection string, is
> checked. A placeholder word such as `<from-vault>`, `changeme`, `example` or `${VAR}` anywhere in
> the matched text excuses it; a release-pipeline token such as `#{X}#`, `__X__` or `$(X)` excuses
> only a password that is exactly the token. **Not matched:** an unquoted generic value (an `.env`
> line or a YAML scalar) unless it has one of the key formats above; a name that does not end in one
> of those words (`SecretKey`); an `appSettings` `<add key="DbPassword" value="…" />`; flat
> `ConnectionStrings:Main` or `ConnectionStrings__Main` keys (user secrets, `launchSettings.json`,
> docker-compose); other key formats, such as Stripe's `sk_live_`; ConnectionStrings entries after a
> brace in a JSON comment or after a nested object; and anything the edit and shell caveats above
> exclude.

## Why the differences (the load-bearing facts)
- **Claude Code** consumes `UserPromptSubmit` stdout and honours `PreToolUse` `exit 2`. `route-prompt` detects this surface (Claude events carry `hook_event_name`) and emits plain stdout there.
- **Copilot CLI** added `userPromptSubmitted` `additionalContext` injection in **v1.0.65** and hardened it in **v1.0.76**. On **CLI 1.0.80 (observed 2026-08-18)** only the last `userPromptSubmitted` entry is delivered, so the framework registers one `route-prompt` entry and composes routing, plan-gate, security-pass, and queued Boy Scout text inside it; `session-start` emits the same model-facing shape on its separate event. Older versions ignore it as a harmless no-op, so routing then rests entirely on the instructed framework rules. The vendor documents `agentStop` from **v1.0.72** and the framework registers it, but its live firing has not been observed here. `preToolUse` deny was honoured on **CLI 1.0.70, 2026-07-17**.
- **`postToolUse` additionalContext is version-dependent, and it now works.** On **CLI 1.0.68** the hook fired but the value was captured and never forwarded to the model. On **CLI 1.0.80 (observed 2026-08-20)** it is delivered: after a real file write, an out-of-band token injected only by `postToolUse` came back verbatim. Check your installed CLI before relying on model-visible post-write feedback — and note that no part of the Boy Scout scan-and-deliver design depends on this channel either way, so that design is unaffected by which version you run.
- **Copilot in VS Code** is the framework's primary target (Bitbucket Data Center ⇒ no cloud agent). Each session runs in one of two harnesses, which treat hooks differently:
  - **Copilot harness.** VS Code 1.140 and 1.141 say it may already be your default selection, and 1.141 that it is gradually becoming the default for enterprise users with VS Code experiments enabled (release notes, 2026-09-30 and 2026-10-07). It runs on the Copilot SDK in VS Code's Agent Host and uses Copilot CLI's hook implementation, which VS Code's hooks page (approved 2026-10-07) calls generally available; `chat.useHooks`, `chat.hookFilesLocations` and `chat.useClaudeHooks` do not configure it. GitHub's hooks reference says that implementation reads `.claude/settings.json` as well as `.github/hooks/hooks.json` and runs every entry from both, so each framework hook can run twice per event, once per file, and that a `preToolUse` command hook that errors denies the call. On the runtime VS Code 1.139.1 bundles, driven without VS Code's window on 2026-10-12: a test hook registered in both files the way the framework registers its own ran from each on all five events, `hooks.json`'s first each time and about half a second apart; with this framework installed, the session and prompt context reached the model once, from the JSON copy; and with `pwsh` missing every tool call was denied. The guard's deny, `postToolUse` delivery and the queued nudge's delivery have not been observed on this harness, and nothing has been observed in VS Code's own window.
  - **Local harness.** VS Code's extension-host agent. Its agent hooks are **Preview, on by default in a trusted workspace (`chat.useHooks`), and your organization can turn them off**, so treat every hook control there as unverified: plan on instruction-only until a canary on your host confirms each one. It reads the framework's `.github/hooks/hooks.json`; it reads the Claude-format `.claude/settings.json` only with `chat.useClaudeHooks`, which is off by default, and then ignores its matchers and runs every command for the event. A hook command that exits with a code other than 0 or 2 gives a warning and the agent carries on (VS Code's Local hooks reference), so a missing `pwsh` leaves every hook control dead instead of stopping the agent. One **2026-06-25** Preview-hook spike observed a `guard.ps1` deny end-to-end, but its host and extension versions were not recorded, so it is historical evidence rather than current certification. The vendor docs specify the `permissionDecision` and `additionalContext` shapes; live `userPromptSubmitted`, `postToolUse`, and `Stop` consumption remain unverified. Native `.github/instructions/` delivery is a separate mechanism and does not prove any Preview-hook lifecycle. With Preview hooks disabled, **every hook control on this surface is instruction-only.**
- **Copilot coding-agent cloud hook execution is unsupported.** The supported hook surface is local Windows Copilot with explicit `pwsh` commands.

## What this means for you
- Run `pwsh -NoProfile -File scripts/framework-doctor.ps1` (or the native Windows PowerShell 5.1 fallback above) once on each Windows developer machine to see which script-verifiable controls are live and which agent canaries still need a human observation.
- Treat the framework-rules workflow rails as **binding**, not advisory — wherever hooks are off (Preview disabled, older CLI), they are the *only* thing standing between a casual prompt and an unreviewed change.
- If you want the deterministic write floor **and** the per-prompt salience injection in VS Code: in the Local harness, **keep agent hooks on** (`chat.useHooks`, the default); the Copilot harness ignores that setting and runs both hook files. In either, confirm your organization allows hooks (see "Organization policies that switch these controls off" above) and canary each capability on the current host before relying on it.
- PowerShell parses hook JSON natively; no separate Bash JSON-parser dependency is part of the supported contract.
- The framework will not claim a control fires where it doesn't. If you find a doc or comment that implies otherwise, that's a bug — file it.

Cross-host behavioral scores are not directly comparable when the host chooses the model. Copilot
CLI `auto` mode has resolved comparable runs to different vendor models (`claude-haiku-4.5` and
`gpt-5-mini`), so a threshold difference against Claude Code would confound host behavior with model
behavior. Record the resolved model in any live-fire evidence and compare hosts only when the model
can be held constant or the results can be stratified by model.

> Status notes. Evidence is capability-specific: a dated host version on one row does not certify a
> sibling event. **Copilot CLI:** single-entry `userPromptSubmitted` delivery was observed on 1.0.80
> (2026-08-18), `preToolUse` deny on 1.0.70 (2026-07-17), and `postToolUse` model visibility on
> 1.0.80 (2026-08-20); `agentStop` firing and its queue write remain unverified. **VS Code Copilot
> harness:** observed only on the runtime VS Code 1.139.1 bundles, driven without VS Code's window
> (2026-10-12): a test hook in both hook files ran from each on every event, the session and prompt
> context arrived once, the end-of-turn scan queued its finding, and an erroring `preToolUse` denied
> every tool call; the guard's deny and post-tool and next-prompt delivery were not observed there.
> **VS Code Local harness
> (Preview hooks):** the 2026-06-25 guard deny is a narrow historical observation with unrecorded
> versions, not current certification; prompt, post-tool, and Stop lifecycles remain unverified.
> **Folder trust is a prerequisite** on Copilot CLI and in VS Code's Local harness: repository hooks do
> not run until the workspace folder is trusted. A hook process running or a direct fixture emitting
> valid output proves neither host consumption nor model visibility.
