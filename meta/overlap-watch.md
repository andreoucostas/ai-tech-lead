# Host-native overlap watch

> **What this file is for.** The framework's value is the **delta over host-native behaviour**, and
> that delta shrinks every time a host ships. Without a written retirement policy the framework's
> fate is to become scaffolding that costs consumers context while duplicating what the host now does
> better — which is exactly the cost `context-footprint` exists to measure. This table names, per
> mechanism, what would obsolete it, the signal that it has happened, and what we would do about it.
>
> **Reviewed as part of every host-recertification cycle (B-43), in the same sitting.** A row whose
> detection signal has fired is a backlog entry, not a discussion.
>
> **A row is not a plan to retire.** Most rows should sit at "keep" for a long time. The point is that
> the *reason* to keep is written down and re-read, so "we still ship this" stays a decision rather
> than an omission.

## How to fill a row honestly

- **Detection signal** must be something you could observe on a Tuesday — "host X ships Y", "doc Z
  announces", a changelog line — not "when it feels redundant".
- **Retirement action** is one of: **drop**, **thin** (keep as configuration of the native feature),
  or **keep** (with the justification written out).
- Where the honest answer is "we have never measured whether our version is better", say that. An
  unmeasured advantage is a claim, and this repo does not ship those.

| # | Framework mechanism | Host-native feature that would obsolete it | Detection signal | Action if it fires | Current |
|---|---|---|---|---|---|
| 1 | `docs/wiki/` team memory + `remember-for-team` | Claude Code auto-memory / native project memory | Host memory becomes **shared and reviewable in-repo** rather than per-developer and opaque | **Thin** — the wiki's value is that entries are diffable, PR-reviewable and scoped; native memory is per-developer. If it becomes a tracked repo artifact, keep only the `remember-for-team` drafting recipe | keep |
| 2 | `/review` agent fan-out (`convention-check`, `solid-check`, `test-critic`, `security-auditor`, `bloat-radar`, `debt-radar`) | Host-native code review (Claude Code `/code-review`) | Native review accepts **repo-specific convention input** and reports per-convention findings | **Thin to configuration** — the agents' delta is that they are grounded in *this repo's* conventions. A native reviewer that reads `CLAUDE.md` conventions removes most of it | keep |
| 3 | `route-prompt` hook (keyword intent classification) | Native intent handling / the model simply doing the right workflow unprompted | A bare-model arm reaches the same workflow at the same rate — **this is measurable today** and is the one row we could settle rather than watch | **Drop** if a bare arm matches. Accepted-debt already flags this as brittle by design (B-26) | keep — **unmeasured** |
| 4 | `post-write` build/type-check feedback | Host-native diagnostics surfaced to the model after a write | The host surfaces compiler/tsc errors to the model without a hook, on the surfaces we support | **Drop** — this is pure duplication once native. Note the surface asymmetry: it is already version-dependent on Copilot CLI | keep |
| 5 | `.claude/skills/` recipes | First-class host skills | Hosts converge on a shared skill format and discovery **that Copilot also honours** | **Keep** — the format is already host-native; the *content* (repo-grounded recipes) is the product. This row exists to prevent the mistake of retiring content because its carrier became standard | keep |
| 6 | Plan-first rails (§1 workflow, `/design`) | Host plan mode | Plan mode becomes default-on and covers non-interactive/agent surfaces | **Thin** — keep the rails as the *content* of what a plan must contain; drop the ceremony that duplicates the host affordance | keep |
| 7 | `guard.*` write hard-blocks | Host-native permission rules / deny lists | A host ships content-aware deny rules (secrets, test-defeat) rather than tool/path allowlists | **Keep unless content-aware** — path-based permissions do not overlap this at all; the guard blocks on *what is being written* | keep |
| 8 | `session-start` version awareness | Host update notifications for installed repo tooling | The host tells the developer their repo template is behind | **Drop** | keep |
| 9 | `framework-doctor` | Host `/doctor` | Native doctor inspects **repo-level** framework installation, not just host config | **Keep** — different subject; recorded so nobody assumes overlap from the shared name | keep |
| 10 | `context-footprint` ceiling | Host-native context budgeting visible to the maintainer | The host reports per-file static-context cost for a repo | **Thin** to a threshold over the host's number | keep |
| 11 | `audit-trail` hook | Host-native session transcript / change log | The host persists an in-repo, greppable record of AI-authored file changes | **Drop** | keep |
| 13 | `route-prompt` keyword-grep intent classification (folded in from B-26, 2026-08-20) | the model simply classifying intent correctly unaided | a bare-model arm reaches the same workflow at the same rate | **Drop** if a bare arm matches. Accepted as brittle-by-design 2026-07-01; the original watch said "revisit only with evidence of misrouting", which waits for a symptom nobody is instrumented to notice. Stated here as an experiment instead | keep — **unmeasured** |
| 12 | `AGENTS.md` mirror | Universal adoption of one instruction file by every host we target | Copilot/Codex/Cursor/Gemini all read `CLAUDE.md`, or all read `AGENTS.md`, so the mirror is redundant | **Drop the mirror, keep one file** — this is the highest-probability row on the table and would remove an entire invariant (#2) and its gate | keep |

## Notes

- **Row 3 is the one to act on first.** It is the only row whose signal is measurable *now* with the
  instrument we already have (the B-41 harness), rather than waiting on a vendor. A bare-model arm
  against a routed arm on the same prompts would settle whether `route-prompt` earns its context.
- **Row 12 would be the largest simplification available** — invariant #2, the mirror-parity gate,
  the `/generate-copilot` command and the `sync-agent-files` script all exist to serve it.
- Rows 5 and 9 exist to prevent the *opposite* error from the one this file is about: retiring
  something because its name or carrier resembles a host feature, when the value was never the
  carrier.
