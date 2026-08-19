# B-55 adversarial critique — vendor-behaviour facts

## Verdict: REQUEST CHANGES

The cheap-denylist premise survives proportionality review, but this design is not implementable as
written. The four regexes do not exist in the design, the proposed `validate-dist` home crosses the
framework/consumer ownership boundary, and the spelling migration chooses the minority spelling
without evidence that normalisation is a prerequisite for a denylist. Those are blocking design
defects, not implementation details.

## Findings

### BLOCKING — there are no proposed regexes to verify

Section 4(b) supplies English descriptions of four claims, not regex entries. Therefore the required
proof — that each proposed regex matches the real former shipped text and does not match legitimate
prose — is impossible. This is the same vacuity class the design says it intends to guard: a later
implementation could choose a pattern that never matched the historical spelling and still claim to
have implemented the table.

Command:

```text
rg -n -i "Copilot has no equivalent|no equivalent event|does not consume hook stdout|shown only to the user|stopReason|userPromptSubmitted|route-prompt" src meta .claude/plans CHANGELOG.md
```

Observed: the live backlog/design contain the three quoted dead phrases, live shipped guidance
contains the corrected claims, and historical changelogs contain old statements and discussions.
No denylist regex syntax or concrete regex entry exists in the design.

Required change: freeze the exact four patterns and an explicit scan scope in the design, then test
each against (1) its exact historical shipped line, (2) corrected live prose, and (3) legitimate
historical narration. In particular, CHANGELOG files must be excluded: they legitimately record
claims that were once shipped and later corrected.

### BLOCKING — `validate-dist` is the wrong ownership surface

`template-checks` and consumer-invoked validation operate in consumer repositories. A vendor-fact
denylist is framework maintainer bookkeeping: a consumer may accurately document an older Copilot
version, quote a superseded framework claim in its own changelog, or intentionally describe a
different hook arrangement. Failing that consumer's build would impose our current vendor-fact
vocabulary on product-owned prose, just as B-131 forbids imposing our changelog grammar.

Command:

```text
rg -n "Runs in BOTH contexts|consumer repo|validate-dist" src/core/scripts/template-checks.ps1 CLAUDE.md
```

Observed: `template-checks.ps1` says it runs in both the template and consumer contexts, and the root
guide defines `validate-dist` as a shipped-dist gate. The B-55 design contains no `.template-repo`
ownership branch.

Required change: put this in the meta suite over composed `dist/*` (or make a selected
`validate-dist` check provably marker-gated and absent/no-op after installation). A meta test is the
cleaner home because the denylist itself is maintainer knowledge and need not ship. Consumer builds
must not fail over it.

### BLOCKING — all four seed facts are dead, but regex safety is unproved

The facts themselves check out:

1. **“Copilot has no equivalent event.”** Dead. Commit `3ea42f8` replaced the prompt-start workaround
   with `agentStop`; current `enforcement-surfaces.md` records `agentStop` from CLI 1.0.72. A narrow
   case-insensitive pattern over `Copilot.{0,80}no equivalent event` would match the former claim,
   but the design supplies no such pattern. A bare `no equivalent event` would over-match discussion
   of some unrelated event.
2. **“does not consume hook stdout” for `userPromptSubmitted`.** Dead only with the event/channel
   qualifier. Current guidance records `userPromptSubmitted` `additionalContext` injection since
   1.0.65. A pattern for `does not consume hook stdout` alone would wrongly catch correct claims
   about other events such as `postToolUse`; the pattern must bind the phrase to
   `userPromptSubmitted` within a deliberately specified span or line.
3. **Stop `reason` “is shown only to the user.”** Dead. Commit `3ea42f8` removed this wording and the
   current record distinguishes model-visible `reason` from `stopReason`. A phrase-only pattern
   would match a legitimate explanation such as “the old claim ‘shown only to the user’ was
   incorrect”; it must be scoped away from changelogs/history and bind to Stop `reason`.
4. **`route-prompt` reaches the model with multiple `userPromptSubmitted` entries.** Dead for the
   observed CLI 1.0.80 configuration. Commits `ab68b82` and `f71c5d4`, the B-147 record, and current
   `enforcement-surfaces.md` all say only the last entry is delivered and the framework now composes
   into one. This is not one stable sentence: a regex must encode both the multiple-entry condition
   and a positive delivery assertion. A broad `route-prompt.*reaches the model` would reject the
   correct single-entry claim.

Commands and observed output:

```text
git log --oneline --all -S'Copilot has no equivalent event' -- src
git log --oneline --all -S'does not consume hook stdout' -- src
git log --oneline --all -S'shown only to the user' -- src
```

Each first reported `3ea42f8 v0.35.0: Copilot Boy Scout nudge fires at turn end (agentStop)`.

```text
git log --oneline --all -S'only the last' -- src CHANGELOG.md meta
```

Observed relevant records: `ab68b82 B-52 answered by live canary: Copilot CLI delivers ONLY the
last userPromptSubmitted hook` and `f71c5d4 B-147: one composed Copilot userPromptSubmitted entry,
restoring routing salience`.

### Non-blocking limit — a denylist is reactive and can be green while current prose is false

A fifth vendor change can make a currently correct sentence false in wording absent from the four
patterns. A consumer can then read stale guidance while the gate is green. The gate proves only
“none of the already-enumerated superseded phrasings remain”; it does not prove vendor facts are
current, mutually consistent, or sourced. That is acceptable for a deliberately cheap first step
only if the check and its OK message state this narrow claim. Calling it vendor-fact validation or
calling `enforcement-surfaces.md` canonical without testing restatements would create false
confidence.

The proportionality call is otherwise sound. The observed harm is stale duplication, and replacing
load-bearing local text with pointers would cost context and usability across several surfaces.
A full canonical-source or generated-registry refactor is not justified before the cheap reactive
measure is tried. The design should not claim the denylist turns the *next* vendor change into a
failure; it turns only a newly added known-dead pattern into a failure.

### BLOCKING — spelling normalisation is unsupported and chooses the minority form

Command:

```text
scan every file under src with explicit UTF-8; count literal `CLI >=` and `CLI ≥`; enumerate
`CLI (>=|≥) v?1.0.NN`
```

Observed:

```text
ASCII_GE=4 UNICODE_GE=18
CLI >= v1.0.65=3
CLI >= v1.0.72=1
CLI ≥ 1.0.65=1
CLI ≥ 1.0.72=5
CLI ≥ v1.0.65=12
```

So `≥` is dominant, not `>=`. The normalization is not a prerequisite for regex gating: one regex
can use `(?:>=|≥)` and optional `v`. No parser was found that consumes this typography; searches of
PowerShell, shell, JSON, and YAML assertions found no exact `CLI ≥`/`CLI >=` test assertion. That
means either spelling is mechanically safe, but it does not justify touching 18 dominant instances
to adopt four minority ones. Drop the migration unless a consumer-facing style reason is stated; if
normalisation remains desired, prefer the dominant `CLI ≥ v1.0.NN` and red-test any exact-text
assertions before changing it.

## Required revision

Keep the cheap-denylist approach, but (1) specify and fixture-test exact patterns, including safe
negative examples; (2) exclude historical changelogs; (3) run it only at the maintainer/template
ownership layer, preferably the meta suite; (4) state its reactive completeness limit in the check's
success wording; and (5) drop or separately justify spelling normalization. No B-55 code was written.
