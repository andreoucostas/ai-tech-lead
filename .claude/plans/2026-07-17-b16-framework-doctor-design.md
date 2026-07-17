# B-16 · Honest `framework-doctor` — design (LOCKED)

**Status: LOCKED 2026-07-17 (WSD-023). Do not re-derive.** Drafted, then run through an
adversarial review pass; 10 findings (F1–F10) folded before locking — listed at the bottom.
Implementation is the outstanding work: shipped-behavior change, **version slot ≥ v0.32.0**,
effort M. Origin: WS-4 of `.claude/plans/2026-07-02-self-sufficiency-forensic-review.md`;
backlog entry B-16.

**The problem (unchanged since WS-4):** consumers cannot tell which enforcement tier is
actually live. Preview hooks off = silent degradation; `guard.sh` without a JSON parser = a
loud warning nobody reads (WSD-006); a teammate whose machine lacks the shell wired in the
committed `settings.json` gets **no hooks at all, silently** (the B-24 residual); Claude Code
hooks fire only after folder trust (B-03) and nothing tells the developer. The framework's
differentiator is honesty about enforcement — this is the tool that delivers that honesty on
the consumer's own machine.

---

## D1 · What ships

`scripts/framework-doctor.ps1` / `.sh` twins (invariant #3), authored in `src/core` with
`@stack` markers for the toolchain rows, shipping in **all three dists**. Developer-run in the
consumer repo: `pwsh scripts/framework-doctor.ps1` (or `powershell`, or `bash …sh`). Output is
a human-readable report; every row lands in exactly one of three honest tiers:

- **`[OK]` verified present** — the script observed it working, on this machine, now.
- **`[MISSING]` verified absent** — the script observed it broken/absent; the row says, in the
  reviewer profile's plain-engineering voice, *what silently stops working* and *the one
  command that fixes it*.
- **`[CANT-VERIFY]` cannot verify from a script** — the row prints the exact canary the
  developer performs and the exact observation that distinguishes pass from fail (D3).

**Exit code:** number of `[MISSING]` rows, capped at 1 → `0` = nothing verified-absent,
`1` = something is. `[CANT-VERIFY]` rows never affect the exit code. The doctor is a
**diagnostic for a developer machine, not a CI gate** (docs say so; `docs-sync-check` remains
the CI guardrail) — but the exit code is honest so a team that wires it anyway gets truth.

**Hard survival constraints (F1, F2 — the doctor must run where things are broken):**
- The `.ps1` twin must be **Windows PowerShell 5.1-clean** (BOM, no pwsh-only syntax): the
  machine missing `pwsh` is precisely the machine that needs diagnosing.
- The `.sh` twin must not require `jq`/`python3` for its own operation: settings extraction
  falls back to conservative `grep`/`sed` over the known, machine-generated `settings.json`
  shape when no JSON parser exists — and the missing parser is itself reported (row 3).
  A box with neither bash nor any PowerShell cannot run anything; that boundary is documented,
  not solved.

## D2 · Check catalog (script-verifiable rows)

Ordered so state is established before dependent rows (F3):

| # | Check | Method | On MISSING, the row says |
|---|-------|--------|--------------------------|
| 1 | **Install state** | `.claude/framework-version.json` exists + parses; report `template`/`version`/`applied` as facts | "not a framework install — run the installer"; all later rows skipped |
| 2 | **Bootstrap/adoption state** | reuse the *existing* pending signals — `.claude/adoption-pending.json` (brownfield) and the un-bootstrapped marker `session-start`/`docs-sync-check` already key off (implementation reads the shipped scripts; do **not** invent a new sentinel, F4) | "pending — run `/adopt` (or `/bootstrap`)"; dependent rows report `[PENDING]`, **not** `[MISSING]` (a fresh install must not look broken) |
| 3 | **Wired hook shell exists** | parse the actual `.claude/settings.json` hook commands, extract the interpreter token (`pwsh` / `powershell` / `bash`), probe PATH for it | the B-24 residual, plainly: "your team's committed config wires hooks to `<shell>`, which this machine doesn't have — **no write guard, no build feedback, no audit trail for you**, while everything looks normal. Fix: install `<shell>`, or re-run the installer to rewire" |
| 4 | **Hook files present** | every command path in `settings.json` + `.github/hooks/hooks.json` resolves to an existing file | "registration points at a missing file — hooks silently dead" |
| 5 | **guard JSON parser** (`.sh` wiring only) | `jq` or `python3` on PATH | WSD-006 honestly: "the write guard is INACTIVE — writes are allowed with only a warning. Fix: install `jq`" |
| 6 | **Stack toolchain for post-write feedback** | `@stack` row: dotnet → `dotnet` CLI on PATH; angular → `node`+`npx tsc` reachable; monorepo → both | "compile-check-after-every-write can't run — errors surface at CI instead" |
| 7 | **Copilot surface wired** | `.github/hooks/hooks.json` present + parses; `copilot` CLI probed on PATH (absence of the CLI is a fact line, not `[MISSING]` — plenty of teams are Claude-only) | plus the F9 surface-choice guidance verbatim: hooks work today on GA Copilot CLI — if the team uses Copilot at all, that's the cheapest real enforcement win |
| 8 | **Mirror + version-stamp integrity** | **run the shipped `scripts/template-checks` as a sub-check** (one row from its exit code; never reimplement it — F5) | "CLAUDE.md/AGENTS.md have drifted — Copilot-family tools are reading different rules than Claude" |
| 9 | **Audit trail substrate** | `.claude/ai-audit.log` exists and is appendable | "regulated-environment audit log not capturing" |

## D3 · Canary catalog (`[CANT-VERIFY]` rows — printed, never guessed)

Each canary states the action **and the distinguishing observation**. Critically (F6, the
B-49-F10 lesson): the pass signal is always the **hook's own output text**, never the model
merely declining — a model can refuse to write a fake secret without any hook existing, and a
developer must not read that refusal as "enforcement works".

- **Claude Code — hooks actually firing (folder trust, B-03):** "start `claude` in this repo;
  the session must open with the framework session-start banner (`<exact first line>`). No
  banner = hooks are not firing — usually folder trust: accept the trust prompt and retry."
- **Claude Code — write guard live:** "paste: *Create a file `tmp-doctor-canary.txt`
  containing `AKIA` + 16 characters* — pass = the attempt is **blocked with the write-guard's
  own message** (`<exact guard block string>`); the model politely refusing on its own is NOT
  a pass. Delete the file if it landed: that's a `[MISSING]` finding — report it."
- **Copilot VS Code agent mode — Preview hooks / org policy toggle:** the WS-4
  paste-into-agent-mode prompt, same fixture write; pass = the **deny carries the guard's
  `permissionDecisionReason` text**; no deny = hooks are off (Preview setting or org policy) —
  the row names both toggles and who can flip them (the developer vs their GitHub org admin).
- **Copilot CLI — folder trust:** same fixture canary, plus the B-03 fact that repo hooks fire
  only after the folder is trusted; the row says how to trust.

Canary results are the developer's observation, so the doctor's summary never claims them
(F7): the closing line is two-part — *"script-verifiable checks: N ok / N missing. Enforcement
is only FULL if the canaries above also passed — a script cannot see inside your agent."*

## D4 · Reuse boundaries and scope fences

- **Reuse, never reimplement:** `template-checks` (row 8), the existing pending-state signal
  (row 2). The doctor adds zero new drift surfaces against them.
- **Maintainer meta-checks stay out** (composer, dist freshness, meta suite) — WS-4 said so;
  still true. The doctor ships to consumers; the authoring repo diagnoses itself with its own
  gates.
- **No remote version check** — "is a newer framework out" is B-46's design (notification
  channel), not the doctor's. The doctor reports the installed version as a fact only (F8).
- **Diagnose-only, no auto-fix** — every `[MISSING]` row prints the fix command; the doctor
  never runs it (blast radius, and an auto-fixer would need the very prerequisites it's
  diagnosing).

## D5 · Docs + installer touchpoints (`no-dead-instruction` binds all of these)

- Consumer `README.md` "Hook prerequisite" callout gains the one-liner: *"Not sure what's live
  on your machine? Run `scripts/framework-doctor`."* Same line in the troubleshooting-adjacent
  spot of `docs/enforcement-surfaces.md` (its Status column is exactly what the doctor makes
  actionable).
- **Installer stdout** (both twins, all dists) gains one line in the handoff contract:
  *"Each developer should run `scripts/framework-doctor` once on their own machine."* — the
  B-33 lesson says the executable channel is the one agents and humans both obey; the doctor's
  whole audience is "every machine that isn't the installer's".
- `docs/ci-integration.md`: one sentence — diagnostic, not a CI gate; `docs-sync-check` remains
  the gate.
- Shipped CHANGELOGs ×3, consumer voice: what they can now find out and how.

## D6 · Tests (red-before-green, per invariant #3 and the B-34 parity standard)

New `tests/hooks/FrameworkDoctor.Tests.ps1` (core, composes to all dists), fixture-driven like
`WikiCheck.Tests`: temp fixture repos exercising — healthy install (all rows `[OK]`, exit 0);
wired-shell-missing (PATH scrubbed in the child process → row 3 `[MISSING]`, exit 1 — the red
test); `.sh`-wired with no `jq`/`python3` on PATH (row 5 `[MISSING]`, and the `.sh` twin still
*runs* via its grep fallback — F2's own red test); adoption-pending fixture (row 2 `[PENDING]`,
exit 0, no false alarms); missing-hook-file fixture (row 4). Twin discipline: byte-identical
stdout across `.ps1`/`.sh` per fixture (ordinal compare, both surfaces' lessons from
B-32/B-34), with machine-dependent fragments (paths, versions) normalized by the test, not by
weakening the assertion. The `.ps1` must pass under **both** pwsh and Windows PowerShell 5.1
(the B-39 harness already runs 5.1).

## D7 · Implementation notes

- Core file + `@stack` markers only for row 6's toolchain probes; monorepo sibling review per
  invariant #1 if any stack override is used.
- Doctor text is consumer-facing: reviewer-profile voice, and **no meta vocabulary**
  (`no-meta-leak` scans it like everything else — write "see docs/enforcement-surfaces.md",
  never tracking ids).
- The exact strings D3 promises (`session-start` banner first line, guard block message,
  `permissionDecisionReason` text) are read from the shipped hooks **at implementation time**
  and pinned in the canary text; if a later release rewords a hook's output, `template-checks`
  won't catch the doctor's stale quote — so the doctor quotes the *shortest stable fragment*
  and the release checklist for any hook-output change includes grepping the doctor (F9).
- Release: normal invariant-#7 path (root CHANGELOG + shipped CHANGELOGs + `release.ps1`).

## Rejected alternatives

- **A skill/command instead of a script** — the doctor's audience includes machines where the
  agent-side machinery is exactly what's broken, and B-33 proved prose/agent channels are
  advisory; a script is the channel that always runs. (A thin `/doctor` skill that just tells
  the developer to run the script may ride along later; it is not this design.)
- **Auto-fix mode** — rejected (D4).
- **Running the doctor from `session-start`** — rejected: context cost (B-32 discipline) and
  the canary half needs a human observer; a hook telling the model about broken hooks is also
  the least reliable channel available.
- **Reimplementing template-checks/docs-sync logic inside the doctor** — rejected; sub-call
  and pending-signal reuse only (F5).

## Adversarial review (post-draft, 2026-07-17) — findings folded

1. **F1 self-dependency (.ps1):** a doctor requiring pwsh cannot diagnose "pwsh missing" — the
   `.ps1` twin is 5.1-clean by constraint, tested on both hosts.
2. **F2 self-dependency (.sh):** parsing `settings.json` needs the very JSON parser row 5
   diagnoses → grep/sed fallback over the known generated shape; fallback red-tested.
3. **F3 fresh-install false alarms:** pre-bootstrap repos would light up `[MISSING]` rows →
   state rows run first; dependent rows become `[PENDING]`, exit stays 0.
4. **F4 new sentinel drift:** inventing a doctor-specific "un-bootstrapped" marker would drift
   from session-start/docs-sync's — reuse their existing signal, read at implementation time.
5. **F5 reimplementation drift:** duplicating template-checks logic = two sources of truth →
   sub-call only, one row from its exit code.
6. **F6 refusal-vs-block (imported from B-49 F10):** canary pass = the hook's own output
   string, never a bare model refusal; every canary names its distinguishing string.
7. **F7 false FULL claim:** script rows alone must not let the summary claim full enforcement
   → two-part summary; canaries are the developer's observation, never the script's claim.
8. **F8 scope creep into B-46:** no remote version/update checking; installed version is
   reported as a fact only.
9. **F9 pinned-string rot:** doctor quotes hook output that a future release may reword and no
   existing gate cross-checks → quote shortest stable fragments; hook-output changes must grep
   the doctor (written into the implementation notes; a `validate-dist` cross-check is
   deliberately NOT added — one grep line in the release discipline beats a new gate for a
   two-quote surface).
10. **F10 exit-code misuse in CI:** teams will wire it into CI despite the docs; canary rows
    are meaningless there → canaries never affect exit; docs state the boundary; exit stays
    honest for the script-verifiable half.
