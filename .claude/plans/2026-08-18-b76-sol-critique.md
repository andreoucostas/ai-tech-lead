# B-76 `doc-claims` design — adversarial critique

Reviewed against the live v0.58.0 distributions on 2026-08-18. No product or validator code was
changed for this review.

## Findings

### 1. BLOCKING — Shape A's subject extractor is not the grammar its examples require

I applied the proposed rule to every Markdown line in `dist/dotnet` matching
`\bby\s+`?/<command>`?`, using a case-insensitive regex and taking the last quoted/backticked token
before each attribution. Command:

```powershell
$files = Get-ChildItem dist/dotnet -Recurse -Filter *.md -File -Force
# For each matching line: Match("\bby\s+`?/(?<cmd>[a-z][a-z0-9-]*)`?", IgnoreCase),
# then Matches(prefix, '"[^"]+"|`[^`]+`') and select the last match.
```

Observed output began:

```text
COUNT=52 EXTRACTED=21 SKIPPED=31
AGENTS.md:79 cmd=review subject=`solid-check`
CHANGELOG.md:980 cmd=generate-copilot subject=`.github/copilot-instructions.md`
CHANGELOG.md:1032 cmd=review subject=`.github/agents/test-critic.agent.md`
README.md:141 cmd=bootstrap subject=`FRAMEWORK-CONTEXT.md`
README.md:142 cmd=generate-copilot subject=`AGENTS.md`
SECURITY_FINDINGS.md:3 cmd=security-review subject=<SKIP>
```

This differs from the design's “58 raw mentions” (52 matching lines under its stated grammar), and
the extracted subjects are frequently objects belonging to another clause, not the maintained
subject. For example, `AGENTS.md:79` says that the `solid-check` agent is run by `/review`; requiring
the review command body to contain `solid-check` happens to be reasonable, but that is not a quoted
subject preceding an attribution verb. More decisively, `README.md:141` contains three attributions
on one line. The first match is `/bootstrap`, for which the nearest token is
`` `FRAMEWORK-CONTEXT.md` ``; subsequent matches require a global/multi-match loop that the design
does not specify. A single-match implementation silently misses `/docs-sync` and `/rebootstrap`.

The claimed `` `SECURITY_FINDINGS.md` … Managed by `/security-review` `` anchor is not covered at
all: its subject precedes `Managed by`, but the only backticked token on the real line is the command
after `by`, so the rule skips it. Conversely, historical prose in `CHANGELOG.md` is extracted and
can block a current command edit. Fenced-code blanking does not remove changelog history.

Recommendation: do not generalise Shape A from token proximity. If the observed regression is worth
a gate, use a small declarative registry of exact `(claim file, command file, required body phrase)`
triples. That is deterministic, reviewable, and covers the three intended contracts without
pretending arbitrary prose has a parseable subject.

### 2. BLOCKING — Shape B has no deterministic specification and its candidate rule is unusable

The stopword list is an input to the algorithm, but the design does not define it. Therefore two
conforming implementations can disagree before PowerShell/bash differences are considered. Prefix
matching the first five characters also creates false matches (`tests`/`testing`, unrelated words
sharing five characters) while failing ordinary morphology shorter than that threshold.

I nevertheless estimated the rule against the real corpus. I parsed frontmatter, excluded the
frontmatter from the searched body, removed the file's own name and tokens shorter than four, used
case-insensitive first-five-character body matching, and supplied a generous explicit 38-word
stoplist (including structural words such as `command`, `skill`, `workflow`, `files`, `agent`,
`structured`, and `findings`). Command shape:

```powershell
$targets = commands/*.md + agents/*.md + skills/**/SKILL.md
# Parse description scalar; tokenise [A-Za-z0-9]+; remove name, length < 4, and explicit stoplist;
# report tokens whose first min(5,length) characters do not occur after the closing frontmatter.
```

Observed output:

```text
DIST=dotnet FILES=33 WITH_MISSING=30 FINDINGS=264
DIST=angular FILES=31 WITH_MISSING=30 FINDINGS=228
DIST=monorepo FILES=37 WITH_MISSING=35 FINDINGS=333
```

Examples include legitimate routing vocabulary absent verbatim from procedural bodies:
`commands/docs-sync.md :: fixes, mostly, safe, anytime`,
`skills/add-endpoint/SKILL.md :: user, wants, solution, shape, adding, brand, ...`, and
`agents/bootstrap-pass.md :: invoked, parallel, phase, invoke`. Even treating every finding as a
candidate rather than a failure leaves 95 of 101 files needing exemptions or prose churn. The
observed false-positive candidate rate is therefore at least 94% of files under this deliberately
generous calibration; it is not close to enforceable.

Recommendation: drop Shape B as a generic deterministic gate. Preserve the known `rebootstrap`
contract through an exact registry entry if desired. A description/body semantic-agreement check
belongs in a review/eval instrument, not a blocking lexical gate.

### 3. BLOCKING — the twins are underspecified and will differ

PowerShell `-match`, `[regex]` with `IgnoreCase`, and common `Select-String` usage can be
case-insensitive; POSIX `grep -E` is case-sensitive unless `-i` is supplied. The design requires
case-insensitive subject/body matching but does not require case-insensitive extraction or command
resolution in both twins. This recreates B-59's known divergence. PowerShell's `\s` is Unicode-aware
and includes more characters than POSIX `grep -E`'s portable character classes; `grep -E` does not
portably support `\s` or named capture groups. PowerShell regex/string operations are Unicode;
`grep`, `tr`, and shell character classes depend on locale. YAML folded block scalars also require
indentation/folding rules that neither proposed regex defines.

Evidence command:

```powershell
rg -n 'VALID_CHECKS|ValidChecks|grep' scripts/validate-dist.ps1 scripts/validate-dist.sh
```

Observed output showed separate native implementations (`$ValidChecks` in PowerShell,
`VALID_CHECKS` and many `grep` pipelines in shell), not a shared parser. The Shape A run above also
demonstrated that global versus first-match iteration changes which real claims are seen.

Recommendation: any retained registry check should define ASCII case folding explicitly and avoid
free-form extraction. If prose scanning remains, specify `[[:space:]]`, `grep -Ei`, locale, multiple
matches per line, YAML folding, punctuation, and error propagation before implementation.

### 4. non-blocking by itself, but supports rejection — Shape C has exactly one live instance

Command:

```powershell
$files = Get-ChildItem dist/dotnet -Recurse -Filter *.md -File -Force
# Count files containing both `(one|...|ten|\d+) steps` and `.claude/commands/*.md`.
# Also: rg -n '^\d+\. ' dist/dotnet/.github/prompts --glob '*.prompt.md'
```

Observed output:

```text
FILES_WITH_BOTH=1
.github\prompts\docs-sync.prompt.md
PROMPT_ORDERED_LINES=0
PROMPT_FILES=14
```

The plan's factual claim is correct. A general extractor, two implementations, vacuity guard, and
four twin tests are disproportionate to one fixed, low-churn contract. Add that exact count
assertion to an existing authoring truth test, or put it in the same small registry proposed for
Shape A. Do not require a nonzero generic Shape C corpus: deleting the sole claim could be a valid
documentation simplification and should not make the validator declare itself blind.

### 5. non-blocking — semantics do not duplicate checks 7, 10, or 12, but machinery does

Evidence command:

```powershell
rg -n 'no-dead-instruction|section-path|step-references' scripts/validate-dist.ps1 scripts/validate-dist.sh
```

Observed locations were check 7 at PowerShell line 528, section-path at 274, and step-references at
717 (with corresponding shell sections). Reading those blocks showed: check 7 resolves script/link
targets, check 10 resolves cited headings, and check 12 validates in-file numbered prose references.
None compares a command description with its body, and changing `all six steps` to `all four steps`
in the prompt is outside check 12 because the prompt has no ordered-list run. Thus the intended
findings are not duplicates. Shape C would, however, duplicate check 12's step-label parser, and
Shape A would rescan references already partially discovered by check 7. That duplicated parser and
scan cost matters even though the final predicates differ.

### 6. BLOCKING — cost is probably within 25 seconds only under an implementation the design does not constrain

Commands and observed output on this host:

```text
pwsh ... validate-dist.ps1 dotnet -Check step-references  -> exit 0, 1315 ms wall time
bash ... validate-dist.sh dotnet -Check step-references  -> exit 0, 1065 ms wall time
PowerShell read all 91 dotnet Markdown files once         -> 66 ms
find ... -exec cat {} + over the same files               -> 126 ms
```

The raw input size is harmless: `MARKDOWN_FILES=91` for dotnet and `ALL_DIST_MD=277`. But this does
not measure unimplemented check 13, so I do **not** claim its runtime as observed. B-101 records the
failure mode: the prior bash check spawned `sed` plus `grep` per line/citation/heading and did not
finish after 10 minutes. Shape B's token-by-token body search can repeat exactly that mistake. The
design says “read once” but does not cap subprocesses or require a single-pass implementation, and
POSIX shell has no arrays/maps suitable for caching this corpus without temp files or an allowed
stream processor.

Recommendation: if a registry check is retained, require O(files + registry entries) reads and no
subprocess inside a line/token loop, then measure each twin with the existing timing ceiling. Do not
approve a free-form shell token matcher on an estimate from raw file reads.

## Verdict

**REJECT PREMISE.** The observed historical harm is real, but a three-shape deterministic lexical
gate is not the smallest reliable remedy. Shape B cannot distinguish legitimate summaries from
false promises, Shape A does not parse the real lines it claims to cover, and Shape C is one exact
contract. Replace check 13 with a small explicit contract registry checked by existing meta tests or
a much narrower twin validator check; leave semantic description/body agreement to adversarial
review or evals.
