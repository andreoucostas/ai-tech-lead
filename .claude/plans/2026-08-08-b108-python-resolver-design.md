# B-108 — one sanctioned Python resolver grammar

**Status:** LOCKED after adversarial critique (`LOCK WITH AMENDMENTS`, amendments folded below).
**Independently re-reviewed by Claude Sonnet 5, separate session, 2026-08-08 — CLEARED TO
IMPLEMENT.** I came to this plan intending to flag exactly the gap the folded amendments already
fix: the original check counted only the literal `python3` token, while the sanctioned fragment
itself probes `python3`/`python`/`py` — a stray `command -v python` duplicate would have slipped
past a `python3`-only gate, reproducing the spelling-dependent miss that caused B-104 in the first
place. §3's probe-shaped-line definition and the `python`/`py`-only red-test in Executable evidence
§2 close that. Per Maintenance model rule #3 ("a reviewer's corrections are input, not verdict"), I
did not take the fix on faith: `grep` across every `src/core` and `src/stacks/*/files` hook plus
`framework-doctor.sh` confirms all 17 current call sites (10 distinct probe expressions counted per
the inventory table, several duplicated across stack siblings) use only the two lexical forms §3
defines (`command -v` and `for ... in ...`) — the inventory table's site count is not asserted, it
is verified against the actual tree at this commit. **One non-blocking forward-looking note, not
worth delaying implementation over:** the probe-shaped-line definition doesn't cover `which`,
`type -p`, or `hash`-style probes. No current site uses them, so this isn't a gap against today's
population, but if a future hook introduces one of those forms it would bypass check 12 the same
way `python3`-only detection would have. Worth a one-line mention in the check's own comment
so a future editor knows the boundary is deliberate, not accidental — does not need a plan
revision or a re-lock.

**Scope:** shipped Bash hooks/scripts plus the authoring validators and their meta tests

**Effort:** M (the backlog's S–M range is treated as M under Maintenance model #1)

## Premise, re-observed

The backlog's named sites are incomplete, but its defect class is real. Re-observed on
`origin/master` at `55370e4`, each composed distribution contains ten executable resolver probes
across seven files:

| File | probe/use sites |
|---|---:|
| `.claude/hooks/guard.sh` | 1 |
| `.claude/hooks/route-prompt.sh` | 1 |
| `.claude/hooks/session-start.sh` | 1 |
| `.claude/hooks/audit-trail.sh` | 2 |
| `.claude/hooks/post-write.sh` | 2 |
| `.claude/hooks/boy-scout-check.sh` | 2 |
| `scripts/framework-doctor.sh` | 1 memoised resolver used repeatedly |

There are three spellings: readable loops, dense command substitutions, and a memoised function.
The earlier five-site audit was false because its search did not cover stack snippets/files and
`framework-doctor.sh`. Implementation must derive the inventory from the composed dist, not from a
hand-maintained filename list.

## Decision

1. Add `src/core/scripts/python-resolver.txt`, a non-executable canonical fragment containing one
   POSIX-sh `resolve_pybin` definition. It composes to `dist/*/scripts/python-resolver.txt`, owns
   `_pybin_resolved` and `_pybin`, probes `python3`, `python`, then `py` by execution, and accepts
   only an interpreter that round-trips `{}` through Python's JSON parser. A `.txt` fragment avoids
   falsely presenting it as a runnable script and therefore does not create a `.ps1/.sh` twin
   obligation. Both validators read this authored source fragment; the composed copy is checked by
   normal freshness and validates that the canonical grammar itself reaches every distribution.
2. Embed that fragment byte-for-byte once in every standalone shipped `.sh` that needs Python.
   Standalone scripts remain standalone; none sources an authoring-repo file. Every use calls
   `resolve_pybin` and reads `_pybin`. `audit-trail`, `post-write`, and `boy-scout-check` reuse their
   one memoised result rather than probing twice.
3. Add `python-resolver` as validator check 12, preserving checks 1–11 and their stable references,
   to both `validate-dist` twins. It enumerates every shipped `.sh`
   recursively—never a static hook list—and:
   - defines a **probe-shaped line** lexically as a non-blank line whose first non-whitespace
     character is not `#` and which contains either (a) `command -v` plus any candidate token
     `python3`, `python`, or `py`, or (b) a `for ... in ...` candidate list containing any of those
     tokens. Inline comments and quoted text are deliberately still scanned: hiding a second probe
     in either must require an explicit design change, not bypass the check. CRLF is normalized to
     LF before all comparisons; continued/multiline and quoted variants get explicit fixtures;
   - requires every file with a probe-shaped line to contain exactly one EOL-normalized canonical
     fragment and exactly one sanctioned probe-shaped line from that fragment;
   - rejects every additional probe-shaped line, including dense command substitutions and
     `python`/`py`-only variants, so removing the literal `python3` cannot bypass the invariant;
   - reports file-relative findings, scanned `.sh` count, resolver-file count, and sanctioned-probe
     count; zero `.sh`, zero resolver files, or zero sanctioned probes is fatal, not green;
   - is included in `--content-only` alongside checks 6–8, because it validates composed content;
   - reads the same `src/core/scripts/python-resolver.txt` in both twins so their sanctioned grammar
     cannot drift. A missing canonical fragment is FATAL, but the initial old-tree red test first
     adds the fragment without normalizing hooks, so diagnostics still name dense resolver sites.
4. Comments and prose may name Python candidates; the gate judges only the precisely defined
   probe-shaped lines. Python heredoc/body text is out of scope unless it matches that lexical shape.
   The fragment comparison is the structural proof that the one allowed line is inside
   `resolve_pybin`, rather than a regex pretending to parse the whole shell language.
5. All stack whole-file overrides for `post-write.sh` and `boy-scout-check.sh` are explicit scope:
   `src/stacks/{dotnet,angular,monorepo}/files/.claude/hooks/`. This is six source files, including
   monorepo siblings, in addition to the core hooks and doctor. The composed inventory—not this
   list—is the validator's population authority.

## Executable evidence

Extend `.claude/hooks/tests/ValidateDist.Tests.ps1` using scratch copies of the real dotnet dist and
both validator legs:

1. **Existing-tree red:** before source normalization, the new check must fail and name at least one
   dense resolver site. This is the defect observation.
2. **Bare-probe red:** append `command -v python3` to a scratch shipped `.sh`; repeat with a
   `python`/`py`-only candidate probe. Both twins exit nonzero and name the file.
3. **Malformed-sanction red:** deform one line inside an embedded canonical fragment; both twins exit
   nonzero. This proves the validator is not merely counting the candidate loop.
4. **Lexical boundary:** fixtures cover full-line comments (ignored), inline comments (scanned),
   quoted probe text (scanned), CRLF canonical blocks (accepted after normalization), and a
   continued/multiline probe variant (rejected).
5. **Vacuity red:** remove all `.sh` inputs (or all canonical resolvers) in scratch; both twins exit
   nonzero with the zero-population diagnostic.
6. **Reachable green:** the normalized real dist contains exactly seven resolver files and ten
   former call sites served by those resolvers; both twins report positive counts and exit zero.

The test helper that creates an isolated validator repo must copy `python-resolver.txt`. The test
dispatcher already guards zero-case execution; keep the new cases auto-discovered.

## Implementation and verification

1. Add the shared `src/core` fragment and validator checks first; compose the fragment without
   normalizing hooks and observe the old resolver population red.
2. Normalize all source sites, including stack snippets/files found by the composed inventory.
   Review monorepo siblings before rebuilding.
3. Build all three dists with `build.ps1`; require `git status --porcelain dist/` to show only the
   expected generated changes, then rebuild once with `build.sh` and prove identical output.
4. Run `bash -n` on every changed source/dist shell file.
5. Run focused ValidateDist cases, `validate-dist.ps1` ×3, `validate-dist.sh` ×3, shipped hook suites
   ×3, and the full meta suite. Set the documented host PATH/tool overrides so skips do not erase the
   Python-fallback coverage.
6. Exercise at least one no-`jq` behavioral fixture for each affected hook family and the doctor,
   confirming resolver reuse did not change output/exit semantics.
7. Update validator documentation/counts where numbered checks are listed. Because the normalized
   resolver changes shipped behavior machinery, release with root and consumer-facing changelog
   entries and a version bump through `release.ps1` after independent review.
8. Correct B-108's stale inventory in `meta/BACKLOG.md`, move it to Done, and file the required RCA:
   the prior grep was spelling-dependent; every other duplicated capability probe remains exposed
   until its gate derives the population from shipped artifacts.

## Rejected alternatives

- **A regex allowing several spellings:** preserves the defect class and makes the gate a catalog of
  duplication.
- **Source a shared runtime helper:** breaks standalone hooks and adds a new registration/install
  dependency.
- **Scan only `.claude/hooks/`:** misses `framework-doctor.sh`, already omitted once.
- **Ban the word `python3`:** rejects accurate comments and documentation without proving runtime
  grammar.
- **Validate only `src/`:** consumers receive `dist/`; the gate must judge what ships.
