# B-241 — independent review record and dispositions

**Reviewer:** Claude Opus 5 (`claude-opus-5`), Claude Code 2.1.260, fresh non-interactive session
(`claude -p`, `--allowedTools Read,Grep,Glob`, budget cap), cwd = worktree at `4e7167e5`, no
implementation participation, blind-first order enforced by the packet
(`.claude/plans/2026-09-16-b241-review-packet.md`). Elapsed 450 s. The reviewer executed no tests.
**Verdict returned:** REVISE. Every finding below was re-verified by the implementer before acting
(reviewer corrections are input, not verdict — Maintenance model #1).

## Reviewer's record (verbatim, findings section)

**1 · MEDIUM-HIGH — the prose class escalates only *additions* to an always-loaded carrier, not
deletions or rewordings.** `AGENTS.md:19`. Deleting or reweighting an existing binding clause in,
say, `src/core/CLAUDE.md` is at least as consequential as adding one, yet stays **prose**. This is the
same blind spot that justified retiring B-82's heading-mapping test. The fix is one line.

**2 · MEDIUM — the import canary's retarget introduces a confound, so `VERDICT: POSITIVE` no longer
isolates import resolution.** With `-ImportTarget AGENTS.md`, the fixture root contains `CLAUDE.md`
(carrying `@AGENTS.md`) **and** `AGENTS.md` (carrying the sentinel). `AGENTS.md` is itself a file
agent hosts may load as a project document independent of any `@` import. The missing negative
control is one run with the `@AGENTS.md` line removed from the fixture `CLAUDE.md`.

**3 · MEDIUM — every settings change with a live-workflow effect is gated as file content only, and
never observed being honoured.** The validator makes **no assertion at all about
`permissions.deny`**. `Edit(/dist/**)`'s anchoring is unverified; a rule that never matches is the
"syntactically inert assertion" shape from maintenance model #4.

**4 · LOW — lost binding clause: the Investigation/design workflow** ("write no code; weigh ≥2
approaches with trade-offs; record the outcome").

**5 · LOW — lost binding clause: the re-open cost test** ("Re-open only when the changed condition
could alter the outcome and the expected decision value exceeds the audit cost").

**6 · LOW — lost clause, mitigated: host-evidence proviso** ("Where a required host cannot execute,
that host has no evidence. A focused provider leg remains permitted under WSD-061 only when neither
required host can execute a shipped compatibility contract").

**7 · LOW — `autoMemoryEnabled -ne $false` accepts a typo'd value.** JSON `"false"` (string) and `0`
compare equal to `$false` and pass.

**8 · LOW/INFO — the delivery that introduces rule 1 breaks it.** `PowerShellTopology.Tests.ps1:52`
drops the `.claude/git-hooks` scan root — an adjacent cleanup.

**9 · INFO — 6 lines of headroom.** Findings 4–6 are three clauses already shed; the next amendment
should re-audit the ceiling rather than reflexively retire a rule.

**Not a defect (checked and cleared):** the Codex-cap assertion can never fire on current content; it
guards a future raise of `AgentsMaxBytes` and the fixture reaches it via a `$tight` clone.

**Receipts checked:** plant 1's failure text matches the assertion message; plant 2's `EXIT=2` is
explained by `B-241` under `## Status`; 18 `It` blocks counted; the `scripts/release.ps1` catch
confirmed fixed.

**Coverage gaps (reviewer's words):** "I executed no tests … My verification was by reading
assertions and matching their literal message strings and cardinalities to the quoted receipts.
Unverified by anyone: whether the host honours `plansDirectory`, `autoMemoryEnabled`, the four deny
patterns."

**Host observation surfaced by the reviewer's session start:** `Permission deny rule
(.claude\settings.json): Write(/dist/**) is not matched by file permission checks — only Edit(path)
rules are. Use Edit(/dist/**) instead (Edit rules cover all file-editing tools).`

## Dispositions (implementer, 2026-09-16; each re-verified)

| # | Disposition | Evidence |
|---|---|---|
| 1 | **Accepted.** Prose row now reads "no added, deleted or reworded clause in an always-loaded carrier (shipped `CLAUDE.md`/`AGENTS.md`, the framework-rules carrier)". | `AGENTS.md` prose row |
| 2 | **Accepted.** Added `-OmitImport` to the canary and ran the negative control: `sentinel echoed : False`, `NOT-IN-CONTEXT : True`, `file tool used : False`, `CONTROL VALID`, `EXIT=0`. The treatment positive is therefore attributable to `@import`. (The vendor docs also state Claude Code does not read `AGENTS.md` natively; that is now observed, not cited.) | `meta/host-certification.md` row |
| 3 | **Accepted in two parts.** (a) `Get-SettingsWiringViolations` now requires a non-empty deny list containing `Edit(/dist/**)`, `Bash(git push *)`, `PowerShell(git push *)` and refuses any `Write(...)` rule as inert; fixtures cover each. The inert `Write(/dist/**)` rule was removed. (b) Live observation: a fresh `-p` session with Edit allowed was refused — `Denied. Exact message: "File is in a directory that is denied by your permission settings."`; `dist/dotnet/README.md` byte-identical after. **Still unobserved:** the `plansDirectory` inbox write, which needs an interactive plan-mode session; it is now a named landing follow-up in the locked plan §6, owed by the first interactive session after landing. | `MetaHooks.Tests.ps1`; host-certification row; plan §6/§7 |
| 4 | **Accepted.** Restored in Conventions: "An investigation or design task writes no code, weighs at least two approaches with trade-offs, and records the outcome as a WSD." | `AGENTS.md` Conventions |
| 5 | **Accepted.** Restored in Maintenance model #1: "re-open only when the change could alter the outcome and the decision value exceeds the audit cost". | `AGENTS.md` rule 1 |
| 6 | **Accepted.** Restored in Definition of done: "A host that cannot execute has no evidence; one focused provider leg is permitted only under WSD-061, when neither required host can execute a shipped compatibility contract." | `AGENTS.md` DoD |
| 7 | **Accepted.** Check is now `-not ($v -is [bool]) -or $v`; fixture RED for `"autoMemoryEnabled":"false"` added. | `MetaHooks.Tests.ps1` |
| 8 | **Noted, kept.** The scan-root removal was in the locked design (§4.5 `DEVELOPING.md` refresh: "remove `.claude/git-hooks` references"), not an adjacent finding discovered during implementation; rule 1 governs the latter. | plan §4.5 |
| 9 | **Noted.** Restoring three clauses and widening the prose trigger cost +5 lines, offset by folding "Inherited disciplines" into a Conventions bullet: **196/200 lines, 16,554/19,500 bytes**. The line ceiling is deliberately the binding one (vendor adherence guidance); raising it is a WSD-089 amendment, not a reflex. | measured |
| — | Codex-cap assertion: agreed, not a defect. | — |

## Post-revision runs (implementer-observed)

| Check | Result |
|---|---|
| `check-ps1.ps1` on canary + MetaHooks | `BOM=True parseErrors=0` both |
| MetaHooks (pwsh / powershell.exe direct / CP437 leg) | `14 passed, 0 failed` ×3, `EXIT=0` |
| DocTruth (pwsh) after the `AGENTS.md` revision | `18 passed, 0 failed`, `EXIT=0` |
| Canary negative control | `CONTROL VALID`, `EXIT=0` |
| Deny-rule live probe | `Denied … denied by your permission settings.`; `dist/dotnet/README.md` unchanged; `git status --porcelain dist/` empty |
| Full meta suite, both hosts, after revision | recorded in the locked plan §7 |

## Independence and gaps

Reviewer: separate session, different model (Opus 5) from the implementer (Fable 5.1), same host and
toolchain, read-only; blind-first order enforced by the packet; no implementation participation.
Gaps: the reviewer ran no tests and re-observed no planted RED — the implementer supplied and re-ran
those; no second orthogonal vantage (not required: this is not a data-loss, security-bypass or
false-green change). This is a meta-only change with no release, so no ledger row is written; this
file is the record.
