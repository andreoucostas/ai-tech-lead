# B-195 — Bash session-start advisory reader parity

**Date:** 2026-08-30  
**Filed against:** v0.78.3  
**Planned:** v0.78.4  
**Status:** IMPLEMENTED CANDIDATE — local verification complete; first Windows/Linux CI pending

## Value decision

Do B-195 now and keep it P2. On the current shipped bytes, an overdue security row or stale hazard
row whose last byte is its closing `|` is consumed by PowerShell but skipped by Bash. Both hooks
exit 0: the security path loses its red SLA-breach severity and falls back to a generic open-finding
line; the hazard path emits nothing. This loses time-sensitive guidance but does not bypass a hard
gate, so P1 would overstate the consequence.

Adversarial review found two more reachable failures in the same hazard reader. A normal CRLF file
leaves a carriage return on the Bash heading, and horizontal whitespace already accepted by the
PowerShell twin and `hazard-check.sh` is rejected by session start's exact string comparison. Both
silently suppress the nudge. Conversely, making the final row reachable without checking its frame
would let Bash count a four-cell row with no closing pipe that PowerShell skips. These belong in
B-195 because they are the same small reader, grammar, and warning consequence; leaving them behind
would make the EOF correction partial or create a new false warning.

Do not turn this into a repository-wide `read` sweep, a Markdown parser, a PowerShell rewrite, or a
status/date semantics cleanup. A separate adversarial finding—GNU-only `date -d` makes this advisory
unreachable under BSD/macOS `date`—is B-200 because it is a different provider and this host cannot
produce the required native BSD/macOS evidence. Do not claim B-195 proves macOS or exact Bash 3.2.

## Behavioral contract

1. The Bash security and hazard scans consume a non-empty final physical record even when it has no
   newline. Each scan owns a distinct, explicitly empty variable so EOF state cannot leak between
   readers.
2. Security severity, due-date extraction, counts, messages, exit behavior, and the PowerShell twin
   remain unchanged. A final overdue row must produce the exact red one-finding SLA warning.
3. The hazard parsing stream removes exactly one terminal CR from each physical line. It recognizes
   the case-sensitive `## Known Hazard Areas` heading with zero or more trailing horizontal spaces
   or tabs, matching the grammar already enforced by `hazard-check.sh`; it does not broaden casing,
   leading whitespace, or heading level.
4. A candidate hazard table row must contain at least five `|` delimiters, equivalent to
   PowerShell's minimum six split cells, before Bash extracts area, hazard, status, or date. Reuse
   `hazard-check.sh`'s Bash-3.2-safe parameter-expansion count (`${line//[^|]/}` plus `${#pipes}`),
   not another tool or a newer shell feature. A final malformed four-cell row remains without a
   hazard advisory rather than becoming a false warning.
5. Existing 90-day thresholds, status tokens, date parsing, pending/placeholder exclusions, output
   surfaces, advisory exit 0, and protected consumer bytes remain unchanged.
6. Use only constructs available in Bash 3.2: initialized scalar variables, the established
   `read ... || [ -n "$var" ]` idiom, ANSI-C CR quoting, `[[ =~ ]]`, and shell patterns. Exact runtime
   evidence remains B-198/B-200 work, not a claim of this Windows/Linux verification.

## Value-bounded oracle

Strengthen existing suites rather than creating a suite or fixture file.

- Keep the no-open and future-open security controls in `TwinParity.Tests.ps1`, and add one matrix
  result for the distinct overdue-severity branch. Its fixture ends exactly at `|` (byte 124), both
  twins are captured before assertions, both must exit 0 with empty stderr, and both must emit the
  exact red one-finding SLA warning under an explicit Claude `SessionStart` event. One new `It` is
  justified because neither existing result reaches that product branch; using the optional
  Copilot encoder here or adding a generic fresh-EOF case would add no discrimination and is
  rejected.
- Strengthen the existing single `twins agree on stale and fresh verdicts` hazard result. Within
  that result, exercise isolated EOF-stale, terminated-CRLF-stale, trailing-horizontal-whitespace-
  heading-stale, and malformed-EOF-stale worlds. Collect every world's failure before one aggregate
  assertion so an early failure cannot hide a later arm. Assert the hostile input bytes, both exits
  and stderr streams, the exact one-area nudge for the three valid stale worlds, and absence of any
  `**Hazard areas:**` advisory for the malformed world. The ordinary terminated per-twin stale/fresh
  results already control the unchanged threshold; an EOF-fresh duplicate is rejected. Add no
  hazard result.
- Do not add blank-record permutations, every EOL spelling, duplicate Copilot-surface cases,
  per-distribution clones, or a broad syntax grep. They do not distinguish another decision.

Use staged red-first product evidence instead of duplicating it with ceremonial post-green
mutations. Against the unchanged Bash hook, the new security result must be red and the strengthened
hazard result must report the EOF, CRLF, and horizontal-heading worlds red while every PowerShell
arm is a positive control. Next apply the two EOF readers, CR normalization, and heading grammar but
deliberately withhold the minimum-frame guard: the valid worlds must turn green while the malformed
EOF world turns red because Bash now emits a false advisory. Add the frame guard last and require
the complete green. These independently failing implementation stages exercise all five decisions
(security EOF, hazard EOF, terminal CR, heading grammar, and row frame) without replaying equivalent
mutations after the evidence already exists.

## Bounded implementation and completion

Change only the two reader loops in authored `src/core/.claude/hooks/session-start.sh`, then compose
all three distributions. Initialize `security_line` and `hazard_line` separately; consume failed
`read` when the assigned record is non-empty. In the hazard loop strip one terminal CR, use the
established anchored horizontal-whitespace heading regex, count pipe delimiters with the shipped
parameter-expansion idiom, and require at least five before field extraction. Do not edit the
PowerShell twin.

Run the focused red and green suites, Bash syntax, composer parity, all three validators, source/dist
hash parity, test AST/BOM, relevant doc/backlog gates, and an independent immutable-candidate review.
Because tests change, B-195 remains an implemented candidate until the exact candidate's first
Windows/Linux CI is green. Git Bash is not Linux evidence. Fold this implementation into the
existing linear v0.78.4 Unreleased head; never create a future Unreleased heading above it.
