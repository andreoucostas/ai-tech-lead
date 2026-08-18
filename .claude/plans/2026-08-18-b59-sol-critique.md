# B-59 adversarial critique — guard fail-open design

Scope: Phase 1 critique only. I wrote no B-59 guard code. I read root `CLAUDE.md`,
`meta/decisions-index.md`, the design, B-59, both guard twins, the shared fixtures, and both shipped
`enforce-standards` copies before reaching this verdict.

## Findings

### BLOCKING — the proposed `matches()` helper breaks the first SECRET pattern

The helper spells `grep -Eq "$1"`, but the private-key ERE begins with `-----`. Without `--`, GNU
grep parses it as an option and returns 2. The existing site correctly uses `grep -Eq --`.

Command (Git Bash on this host):

```text
grep (GNU grep) 3.0
helper-without-double-dash=2
helper-with-double-dash=1
```

The input was `x`, so the second result is the expected no-match. Change the helper to
`grep -Eq -- "$1"` (and make the case-folded form use `grep -Eiq --`). This is independently
blocking regardless of the fail-open policy.

### BLOCKING — do not fail open for every pattern error

The guard is advertised and documented as a deterministic floor. A regex compilation error is not
an ambiguous content classification; it proves a named part of that floor is unavailable. Stderr is
not a sufficient runtime control: hook stderr may live only in logs, and the defect persists for
every subsequent write until the framework is repaired. A test-suite failure protects a future
release, not a consumer already running the broken pattern.

Recommendation: use a typed helper and **fail closed for the seven high-confidence SECRET
patterns, warn/allow for test-defeat and suppression patterns**. This is the proportionate third
option. Secret patterns are deliberately high-confidence, any-file rules and the current header
already says they fail closed once content is extracted; silently disabling one contradicts that
contract. The less certain test-defeat rules follow B-48's trust judgment: our bad regex should not
brick an ordinary refactor. Both paths must emit the pattern/category diagnostic, and the planted
invalid-regex test must exercise both policies. Record this split in the WSD.

The same review must include the generic credential pipeline. It is outside the counted 20 sites,
suppresses grep stderr, and command substitution cannot distinguish no match from grep failure. The
design may deliberately leave that heuristic fail-open, but it must say so; otherwise “all grep
errors are loud” is false.

### BLOCKING — blanket `-match` → `-cmatch` is not a safe 22-site sweep

I enumerated all 22 `-match` operators in `src/core/.claude/hooks/guard.ps1` (command:
`rg -uu -n -- '-c?match' src/core/.claude/hooks/guard.ps1`). These are the decision changes on
realistic input:

| Site(s) | Realistic changed input | Judgment |
|---|---|---|
| `$fp -match '\.cs$'` | `Foo.CS` | **Incorrect loss of inspection.** Uppercase/mixed-case extensions are legal and occur on case-insensitive Windows trees. File classification should deliberately fold in both twins. |
| `$fp -match '\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$'` | `app.TS`, `worker.JS` | **Incorrect loss of inspection.** Same reason; deliberately fold in both twins. |
| `$fp -match '(?i)\.spec…$'` | `app.SPEC.TS` | No change because `(?i)` remains inline; correct folding, but bash currently lacks it and must be brought into parity. |
| pragma; Fact/Theory/Skip; both Assert patterns; eslint-disable; ts-ignore/nocheck; both focused patterns; both skipped patterns; both expect patterns | differently-cased language identifiers/directives such as `ASSERT.True`, `// ESLINT-DISABLE`, `FIT(` | Decision changes, but the changed inputs are invalid or different identifiers in the relevant languages. Case-sensitive is correct. |
| seven high-confidence secret patterns | lower/upper-cased token prefixes | Decision changes, but token formats are case-sensitive. Case-sensitive is correct. |

Thus 19 content patterns should become case-sensitive, while all three file-routing predicates need
deliberate folding. The design's statement that case-insensitivity “can only ever over-block on
invalid code” is false for file names. Do not preserve current bash behavior merely for parity;
that would make both twins consistently blind. Add uppercase/mixed-case filename fixtures and fold
the bash `case` routing too.

The generic credential detector genuinely needs folding and already spells it explicitly:
PowerShell uses `(?i)` and bash uses `grep -Ei`/`-Eiv`. Preserve that policy.

### BLOCKING — the proposed POSIX NUnit grep is not equivalent

The grep does ship in both the dotnet and monorepo `enforce-standards` skills (both `.claude` and
`.github` mirrors). Command:

```text
rg -uu -n -C 4 '\\s|\\b' src
```

It found the shipped command `grep -rn --include=*.cs '^\s*\[.*\bIgnore\b' tests/`.

I compared the old and proposed EREs on representative lines with GNU grep 3.0. Real output:

```text
old=0 new=1 | [Ignore]
old=0 new=0 |   [Test, Ignore("x")]
old=0 new=0 | [TestCase(1,Ignore="x")]
old=1 new=1 | [JsonIgnore]
old=1 new=1 | [IgnoreAttribute]
old=1 new=1 | var Ignore = 1;
old=1 new=1 | [Test, ignore("x")]
```

GNU grep treats the old escapes as extensions, but the proposed form misses the canonical bare
`[Ignore]`: after `\[` it requires another non-letter before `Ignore`. Use a form that admits either
the opening bracket or a later separator, and test bare `[Ignore]`, comma-separated NUnit forms,
near misses, beginning/end boundaries, and BSD grep before declaring equivalence. I could not run
BSD/macOS grep on this host; WSL was unavailable.

### non-blocking — `grep -Eq` exit mapping is observed on only one reachable grader

Command and real GNU grep 3.0 output:

```text
invalid-bracket=2
b57-pattern=2
match=0
nomatch=1
```

So 0/1/2 behaves as assumed on the reachable Git-for-Windows GNU grep. I could not observe BSD grep
or a macOS grader. The helper's `case $?` is valid shell syntax, and the explicit default arm is
better than assuming every operational failure is exactly 2.

Routing SECRET checks through one helper preserves the valid-pattern first-match short circuit only
if the call remains `[ -z "$secret" ] && matches ... && secret=...`. On an error, `matches` returns
1 and later patterns still run; that is reasonable for warn/allow categories, but for the recommended
SECRET fail-closed policy the helper must terminate/block immediately rather than return ordinary
“no match.” Otherwise it still conflates error with absence at the caller boundary.

### non-blocking — multi-line fixtures are safe only if they preserve each pattern's grammar

Current fixtures are indeed 32 one-line `c='…'` values (`Get-Content
src/core/tests/hooks/fixtures/guard-cases.ps1`). The anchored checks are line-oriented in both twins:
PowerShell uses `(?m)^` and grep processes input by line. Actual GNU grep results on mid-file bodies:

```text
ignore-midfile=0
fit-midfile=0
```

Therefore adding whole-file bodies with the offending construct intact on one line should not break
existing assertions. Do not turn this fixture work into coverage of split attribute lists: e.g.
`[Fact(` on one line and `Skip=...` on another can match PowerShell's `[^)]*` across a newline while
line-oriented grep cannot. That is B-48's disclosed multi-line bypass and would create a different
expected decision/parity question. Add new cases rather than rewriting existing one-line anchors,
as the design already says.

### non-blocking — keep the item, but shrink and sharpen it

There is no live exploit, so a broad “portability sweep” is not justified merely by adjacency. The
observed harm is real: B-57 produced an invalid ERE draft, current parity fixtures cannot distinguish
an inert rule, and the current NUnit recipe is demonstrably non-portable in syntax (though its
replacement is not yet correct). Keep: the error-aware helper, split error policy, explicit
case-policy with filename coverage, realistic fixtures, and planted invalid-regex red tests. Drop
any claim that all grep failures are solved unless the generic credential pipeline is explicitly
handled; do not expand beyond guard plus the one shipped NUnit command.

## Verdict

**REQUEST CHANGES**
