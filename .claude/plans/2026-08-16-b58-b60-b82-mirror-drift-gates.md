# B-58 / B-60 / B-82 — three ungated structural-drift gates

**Status:** **LOCKED 2026-08-16**, after adversarial critique by codex `gpt-5.6-sol`
(`.claude/plans/2026-08-16-b58-b60-b82-sol-critique.md`) and independent re-verification of every
one of its blocking findings. Target release **v0.53.0** (current shipped: v0.52.1).

One cluster, three backlog entries, one shared defect class: **a structural property of a
Markdown artifact that a human re-verifies by hand, that no instrument re-verifies at all, and
whose breakage is invisible in the diff because every line is locally correct.**

## Critique disposition (all findings answered; nothing accepted on the reviewer's word alone)

| # | Finding | Verdict after re-verification | Where it landed |
|---|---|---|---|
| 1 | The zero-start file count was wrong ("5"); the block grammar is underspecified | **UPHELD.** Re-measured: 6 / 5 / 10, not 5. Fence handling was specified for reference extraction only, and 3 files per dist *do* carry column-0 `N. ` lines inside fences. | §2.2 rewritten; §2.4 records real inventories |
| 2 | The block-breaking rule is a regex pretending to be a Markdown parser (tables, blockquotes, nested lists) | **UPHELD as a defect, REJECTED as a reason to abandon contiguity.** The block rule is deleted entirely and replaced by a *run* rule that never looks at intervening content — measured 0 violations on all three dists, and it still catches the B-57 defect. codex's fallback (a finite procedure registry, or a CommonMark dependency) is not needed. | §2.2(a) |
| 3 | Reference extraction counts `### Step N` **declarations** as references, inflating coverage; `steps N–M` unhandled | **UPHELD.** The claimed "15 files carrying references" was 10 heading files + prose. Real prose-reference population: **6 / 3 / 6**. `steps N–M`: 0 occurrences today, so declared out of scope in writing rather than silently ignored. | §2.2(b), §2.4, §2.5 |
| 4 | Part B (code-span parity) is wrong at the **consumer** vantage point | **UPHELD — the most valuable finding.** Independently confirmed: `src/core/scripts/docs-sync-check.sh:138-141` runs `template-checks` in every consumer repo, and `generate-copilot.md:79` specifies Common Tasks as "the skills list" with no verbatim requirement, i.e. deliberate model-authored condensation. A shipped code-span gate would fail a consumer for obeying our own generator. | Part B **removed from the shipped gate**; re-sited authoring-only in §1.5 |
| 5 | Missing registry/reachability updates — a stale-enumeration defect class this repo has already filed | **UPHELD in full.** | §4.2, the complete list |
| 6 | Twin-parity hazards need fixture-level controls, not "same text" | **UPHELD.** | §5 |
| 7 | The scan cost is negligible; the *test* process-spawn cost is the real risk | **UPHELD** (measured 6.74 ms per dist pass). | §2.6 |
| 8 | DROP B-82 | **OVERRULED by the maintainer, with the objection recorded.** codex is right that the table measures heading *topology*, not mirror *truth* — it cannot see content deleted under an intact heading. But the event B-82 was filed for *is* a topology event, and §3.4 now states the limitation in the gate's own comment rather than leaving it implied. | §3, §3.4 |
| 9–13 | A1, A2, A4 correct; both A3 allowances substantively required; Part A's absent-both rule sound | Confirmed by my own measurement too. | — |

---

## 0. Proportionality case (Maintenance model #6 — restated after the critique moved two items)

| Item | Already-observed harm (not hypothetical) | Smallest fix that removes most of it | Verdict |
|---|---|---|---|
| B-58 Part A | `dist/angular`'s `add-tests` line **today** tells Claude "TestBed + `HttpTestingController`" and Copilot "Jasmine/Karma or Jest spec + HTTP mocks". B-57 fixed the dotnet pair by hand and missed this one. | Two set comparisons over one section, in a script that already opens both files. | **Proceed.** And note what makes Part A a *legitimate consumer invariant* where Part B is not: `/generate-copilot` promises Common Tasks is "the skills list", so the skill **inventory** is contractual on both surfaces while the **prose** is explicitly the generator's to condense. |
| B-58 Part B | The same live line — but see Finding 4. | An authoring-only meta-suite assertion over the three stock dists. | **Proceed, re-sited.** Zero consumer surface, ~15 lines, catches the exact recurrence. This *is* the materially smaller fix the proportionality rule demands. |
| B-60 | A B-57 implementer renamed step 1 to 0, leaving `0,2,3,4,5,6,7`, which Markdown renders `0,1,2,3,4,5,6` — silently repointing every `step N` cross-reference in all three stacks. Caught by a human reading it. | A run-boundary rule over the numeric label sequence + a resolvability scan. No Markdown parser, no dependency. | **Proceed.** With the honest limit in §2.5 written into the check's own comment: it is a *resolvability* check, not a *correctness* check. |
| B-82 | Adding "Maintenance model" to root `CLAUDE.md` required a hand edit to `AGENTS.md` with nothing checking the second edit happened. No live divergence (verified: 10 `##` → 6, mapping exact). | A table + two loops in a suite that already reads these four files. | **Proceed — maintainer decision, over the critique's DROP.** §3.4 records what it does *not* measure. |

**Deliberately NOT built:** anchored step ids (`{#step-4}`); a curated technology-token vocabulary
(a maintained word list is a second thing that rots — the code-span rule needs none); a verbatim
section diff for either mirror (B-58's own recorded lesson — both mirrors are *deliberately*
condensed); a CommonMark parser or a finite procedure registry for B-60 (§2.2(a) removes the need);
`steps N–M` range support (§2.5).

---

## 1. B-58 — `## Common Tasks` skill-list parity

### 1.1 Where

`src/core/scripts/template-checks.{ps1,sh}` → new **check 8**. Ships into every dist and runs in
every consumer repo via `docs-sync-check` step 6b — **which is exactly why only Part A goes here.**

**Do NOT add `## Common Tasks` to check 2's verbatim mirror list.** `AGENTS.md`'s copy is
intentionally condensed — a verbatim gate goes red in all three dists and forces rewriting a
section that is *supposed* to differ. This is B-58's own recorded lesson.

### 1.2 Part A — slug-inventory parity (the shipped check)

From the `## Common Tasks` section of each file (section = from the exact line `## Common Tasks`
to the next line matching `^## `), extract every line matching:

```
^- `<slug>` — <description>
```

`<slug>` = `[a-z0-9][a-z0-9-]*`. The separator is an em dash; **accept an em dash or a plain
hyphen** so a consumer whose editor normalised the dash is not failed for punctuation.

Assertions, in this order (order matters — a set comparison alone hides duplicates, per
`meta/LEARNINGS.md:619-620`):

1. **Duplicates first.** A slug listed twice within one file → FAIL, naming file and slug.
2. **Inventory equality.** Ordinal, **case-sensitive** comparison. Present on one side only →
   FAIL, naming the slug and the side it is missing from. Report both directions in one message.
3. **Vacuous-pass guard.** The section exists in at least one file but yields **zero** slugs →
   FAIL ("the list grammar changed and this check is now blind"). Count with `@(...).Count` — a
   bare pipeline `.Count` returns `$null` for a single match under 5.1 (the v0.41.0 RCA).
4. **Presence.** Absent from **both** files → emit an explicit `OK:` line saying the section is
   absent on both sides and the check did not run. **Not silence** — a skip that prints nothing is
   indistinguishable from a pass, and the fixture must be able to prove which branch ran (critique
   finding 13). Absent from exactly **one** → FAIL.

### 1.3 The live defect — fix it in `src/`, not `dist/` [#1]

`src/stacks/angular/files/AGENTS.md:100` reads:

```
- `add-tests` — add tests following project patterns (Jasmine/Karma or Jest spec + HTTP mocks)
```

while `dist/angular/CLAUDE.md:72` (authored in `src/core`) names TestBed + `HttpTestingController`.
`CLAUDE.md` is canonical [#2]. Rewrite the AGENTS line so it names the **same** technologies, in
the condensed voice `AGENTS.md` uses, then rebuild. Do not "fix" it by editing `dist/`.

### 1.4 Part A red-test

```bash
S=$(mktemp -d)/dc; mkdir -p "$S"; cp -r dist/dotnet "$S/"
# (i) one-sided slug
sed -i 's|^- `create-adr`|- `zz-planted` — planted\n- `create-adr`|' "$S/dotnet/CLAUDE.md"
# (ii) duplicate slug on one side
# (iii) mangle the list grammar so extraction yields zero -> vacuous-pass guard
```
Run both twins from inside the scratch dist; **same exit code and same message text**.

### 1.5 Part B — per-slug code-span parity, **authoring-only** (re-sited by finding 4)

New meta-suite test `.claude/hooks/tests/SkillListParity.Tests.ps1` (does not ship, PS-only [#3],
auto-discovered by the meta runner). For each of the three **stock** dists, for each slug present
in both `CLAUDE.md` and `AGENTS.md`, the set of backtick-quoted code spans in its description must
be equal.

This is sound here and unsound in a consumer repo for one reason: **the three stock dists are ours
and are hand-authored in lockstep; a consumer's are model-regenerated.** The test must say so in
its header comment, or someone will later "helpfully" promote it into `template-checks`.

Measured on the current tree: **1 hit (angular `add-tests`), 0 false positives across the other 37
slug lines.** That hit is the natural red — capture it *before* the §1.3 fix, then show green
after. Better evidence than a planted defect, and it must be recorded in the backlog entry.

Stated limitation, in the test's own comment: it does **not** catch `Jasmine/Karma` (plain prose on
the AGENTS side) or `NUnit` vs `xUnit` around an identical code span. Catching those needs the
curated vocabulary this design rejects.

---

## 2. B-60 — ordered-list contiguity + `step N` resolvability (shipped gate)

### 2.1 Where and what it scans

`scripts/validate-dist.{ps1,sh}` → new check named **`step-references`**.
Scope: `.claude/skills/**/*.md`, `.claude/commands/*.md`, `.claude/agents/*.md` inside the dist.
`.github/skills` is byte-identical to `.claude/skills` by template-checks check 7 — scanning it
again buys nothing and doubles the cost.

**Read each file exactly once** and run both assertions over the same in-memory line array
(critique finding 7).

**Fenced code is blanked before BOTH assertions** — not just references. Measured: `docs-sync.md`,
`security-review.md` and `bloat-radar.md` in every dist contain column-0 `N. ` lines inside fences,
so a label scan that ignores fences is wrong on shipped content today. Fence = a line beginning
```` ``` ```` or `~~~`; toggle, and blank every line inside including the delimiters.

### 2.2 The two assertions

**(a) Contiguity — run-based, content-blind.** Collect the labels of every top-level ordered-list
item (`^(\d+)\. `) in **document order** into one sequence per file. Walk it: a **new run** begins
whenever a label is not exactly `previous + 1`. **Every run must begin at 0 or 1.**

That is the whole rule. It never inspects what sits *between* items, so tables, blockquotes,
headings, HTML blocks, thematic breaks and indented continuation paragraphs are all irrelevant —
which is precisely the class of false positive that killed the first formulation. And it is
strictly stronger against the observed defect: `0,2,3,4,5,6,7` opens a run at `2` → FAIL, no
matter what lines separate the items.

**Measured: 0 violations across all three dists** (33 / 31 / 37 files).

Out of scope, stated in the check's comment: **nested** ordered lists (indented `   1.`) are not
scanned, and a genuine second procedure that was renumbered to start at 1 is accepted. Both are
real gaps; neither is the defect this exists to catch.

**(b) Resolvability.** Every `step N` / `Step N` / `step **N**` occurrence **on a non-heading line**
must resolve to either an ordered-list label `N` anywhere in the same file, or a `#{1,6} Step N`
heading in the same file.

- **Heading lines are excluded from extraction** (`^#{1,6}\s`). A `### Step 3 — Boy Scout` line is a
  *definition*, not a reference; counting it inflated the claimed coverage by ~2.5x (finding 3).
- **File-scoped, not run-scoped**, because `add-tests` legitimately references "step 4 above" from
  inside its *second* list. The honest consequence — a reference can resolve against the wrong list
  and still pass — goes in §2.5 and in the check's comment.

**Vacuous-pass guard.** Report coverage the way check 7 does — files scanned, ordered-list labels
found, prose references found — and **FAIL on zero files scanned or zero prose references found**.

### 2.3 Registration and selector scope

`step-references` joins `$ValidChecks` (`.ps1`) and `VALID_CHECKS` (`.sh`) as check **12**.
**Decision: it IS part of the `--content-only` group** alongside `no-meta-leak`,
`no-dead-instruction` and `hook-registration` — it is a pure content scan with no re-parse cost,
and the group's meaning ("checks 1–5 skipped") is unchanged. Update the `--content-only` `case`
in both twins, the NOTE text if it enumerates, and `DEVELOPING.md:101`.

### 2.4 Measured inventories (the numbers the tests assert against)

| dist | files scanned | files opening a list at `0.` | files carrying a prose `step N` reference |
|---|---|---|---|
| dotnet | 33 | 6 | 6 |
| angular | 31 | 5 | 3 |
| monorepo | 37 | 10 | 6 |

Both allowances are load-bearing: without the `0.` allowance, 6/5/10 shipped files fail; without
the `#+ Step N` heading allowance, `feature.md`, `docs-sync.md`, `security-review.md` and
`perf/SKILL.md` produce false dead references.

### 2.5 Declared out of scope (write these into the check's comment, do not leave them implied)

- `steps N–M` / `steps N to M` **ranges are not matched.** Measured: **0 occurrences** in any dist
  today. If one is authored later the check is silent about it — an honest gap, not a claim.
- `the preceding step`, `a later step` — unnumbered, unresolvable by construction.
- A reference resolving against the **wrong** list in a multi-list file (§2.2(b)).
- Nested ordered lists (§2.2(a)).

### 2.6 Cost

Measured 6.74 ms per dist pass over 33 files — far below timing noise against the 700 s
`dist-gates` ceiling and the validator's own 25 s per-check warning. The real cost is in
`ValidateDist.Tests.ps1`: **batch the grammar edge cases through one scratch dist per leg**, not one
full validator spawn per case. Process creation, not scanning, is this suite's bound
(`meta/gate-budget.json`). Do not raise any ceiling for this change.

### 2.7 Red-test

```bash
S=$(mktemp -d)/dc; mkdir -p "$S"; cp -r dist/dotnet "$S/"
# (a) reproduce the exact B-57 defect: renumber item 1 to 0 -> run opens at 2
sed -i '0,/^1\. \*\*Evidence gate/s//0. **Evidence gate/' "$S/dotnet/.claude/skills/add-tests/SKILL.md"
pwsh -NoProfile -File scripts/validate-dist.ps1 dotnet "$S" -Check step-references; echo "exit=$?"  # MUST be 1
bash scripts/validate-dist.sh dotnet "$S" -Check step-references; echo "exit=$?"                    # MUST be 1, same text
# (b) point a prose reference at a nonexistent step
# (c) delete every scanned file -> zero-files guard
# (d) strip every prose reference -> zero-references guard
```
Note the bash twin takes `-Check`, not `--check`.

---

## 3. B-82 — root `CLAUDE.md` ↔ `AGENTS.md` heading-mapping parity (meta gate, does not ship)

### 3.1 Where

`.claude/hooks/tests/DocTruth.Tests.ps1` → a new `It` block. PowerShell only — `.claude/` meta
scripts are PS-only by decision [#3] — and this file already treats the four root docs as a set.

### 3.2 The mapping table (verified exact 2026-08-16, by me and independently by the critique)

| root `CLAUDE.md` `##` heading | root `AGENTS.md` `##` heading |
|---|---|
| What this repo is | What this repo is |
| Meta-invariants (canonical list — referenced everywhere, restated nowhere) | Meta-invariants (canonical definitions live in CLAUDE.md — same numbering) |
| How to approach a change (meta-workflows) | Workflows, done-ness, verification |
| Maintenance model (who implements, who reviews, what "green" means) | Maintenance model |
| Definition of done per artifact type | Workflows, done-ness, verification |
| Verification (evidence-based — name the command, show the result) | Workflows, done-ness, verification |
| Inherited disciplines (they apply to meta-work too) | Workflows, done-ness, verification |
| Commit & push policy (stated in full — not by reference) | Conventions |
| Conventions | Conventions |
| Status | Status |

### 3.3 Assertions

1. Table **non-empty** (`@($table).Count -gt 0`) — the vacuous-pass guard B-82 names.
2. Every `##` heading in `CLAUDE.md` is a **key**. Message must read "decide its mirror target and
   add it to the table", not "unknown heading" — the gate's purpose is to force the decision.
3. Every mapped target exists as a `##` heading in `AGENTS.md`.
4. Every `##` heading in `AGENTS.md` is a **value** — catches `AGENTS.md` growing a section
   `CLAUDE.md` never got.
5. Both files yield `> 0` `##` headings (grammar-change blindness guard).

Exact-string matching is deliberate: rewording a heading is precisely when the mirror decision
should be re-made, and a fuzzy match would pass through the rewrite that breaks the mirror.

### 3.4 What this gate does NOT measure — put this in the test's header comment

Answering the critique rather than burying it: this asserts **heading topology**, not mirror
**truth**. Delete the whole of Maintenance model rule 6 from `AGENTS.md` and leave the heading
standing and this test stays green. Four `CLAUDE.md` sections collapse into one `AGENTS.md`
heading, so that target may carry one of the four concepts and still pass. It catches exactly one
thing: *a section appeared on one side and the mirror decision for it was never made* — which is
the event B-82 was filed for. Anyone extending this should measure the missing concept, not add
more topology.

### 3.5 Red-test

Add `## Planted` to root `CLAUDE.md` only → run the meta suite → observe the named failure →
remove. Then the reverse: `## Planted` in `AGENTS.md` only.

---

## 4. Definition of done

### 4.1 Evidence

Per root `CLAUDE.md` → "Definition of done per artifact type" (composer/gate ⇒ **red-test it**) and
Maintenance model #4 (**green counts only from an instrument seen to go red**):

1. Every new check observed **red on the unfixed tree** and green after, recorded with the literal
   command and its output. B-58 Part B gets its natural red from the live angular defect.
2. Both twins [#3] agree on every red case — same exit code, same message text.
3. `scripts/build.ps1` ×3, then `git status --porcelain dist/` empty [#1].
4. `validate-dist` ×3 green on **both** twins (`.sh` leg needs the pwsh PATH prepend — DEVELOPING).
5. All three dist hook suites + the meta suite green, with `ATL_TEST_PYTHON`/`ATL_TEST_JQ` set so
   the no-parser cases are real coverage, not invariant-guarding skips.
6. `src/stacks/angular/files/AGENTS.md:100` fixed; the fix visible in `dist/angular/AGENTS.md`.
7. Root `CHANGELOG.md` entry + `## 0.53.0 — Unreleased` head **with content** in all three
   `src/stacks/*/files/CHANGELOG.md` **before** `release.ps1` runs — it requires all four heads to
   already carry the target version [#7]; it does not create them.
8. Backlog: B-58, B-60, B-82 → Done with the shipping version; RCA per Maintenance model #5 (§6).
9. `meta/gate-budget.json` re-checked after the release timing run. No ceiling change expected; if
   a stage lands near its ceiling, **record the measurement** rather than quietly raising anything.

### 4.2 Every registry that must be updated (critique finding 5 — a stale enumeration is itself a filed defect class here)

**For `step-references`:**
- `scripts/validate-dist.ps1` — header comment count ("Eleven checks" → twelve) **and** the
  numbered list; `$ValidChecks`; the `--content-only` group; the `--content-only` rationale comment
  (`:113-119`).
- `scripts/validate-dist.sh` — the same four places (`:4`, `VALID_CHECKS`, `check_selected`, `:107`).
- `DEVELOPING.md` — the "Validate the dists (…)" heading list at `:35`, the `--content-only` row at
  `:101`, and a red-test recipe subsection.
- `.claude/hooks/tests/ValidateDist.Tests.ps1` — red / green / zero-files / zero-references /
  fenced-code / heading-not-a-reference / run-boundary cases, **both legs**, batched per §2.6; and
  the case-name registry (`Get-RegisteredCaseNames`) that the dispatcher validates against.
- Root `CLAUDE.md` `## Verification` bullet, which enumerates the validate-dist checks (`:207`).

**For template-checks check 8:**
- `src/core/scripts/template-checks.ps1` / `.sh` header comments ("Checks: …").
- `src/core/tests/hooks/ScriptTwinParity.Tests.ps1` — **`$ExpectedChecks` at `:22`**, plus a
  `TemplateFixture` that actually contains a `## Common Tasks` section on both sides. Without
  this the flagship twin fixture agrees *vacuously* about the new check — the exact prior failure
  recorded at `meta/LEARNINGS.md:596-600`.
- `meta/ci-handover.md:54`, root `CLAUDE.md:63`, `DEVELOPING.md:35`.

**Do not rewrite historical changelog entries** that describe what `template-checks` did at the
time. They are a dated record, not live guidance.

## 5. Twin-parity controls (critique finding 6 — every family below has bitten this repo before)

Specify in the implementation, not just "the twins must agree":

- **Ordinal, case-sensitive** slug comparison. PowerShell `-contains` and hashtable keys are
  case-**in**sensitive by default; bash is case-sensitive. Use `-ccontains` / ordinal comparers.
- **Do not sort for correctness.** `Sort-Object` uses culture collation, `sort` uses the locale
  (`meta/LEARNINGS.md:283-287`). Sort only for diagnostic display, under `LC_ALL=C`.
- **Normalize CRLF and strip a BOM before parsing** (`meta/LEARNINGS.md:47-55` — a CRLF-only
  difference already produced a false mirror failure).
- **No non-ASCII inside `sed`/`grep` bracket expressions.** An em dash in a bracket expression
  corrupted UTF-8 and split the composer twins (`meta/LEARNINGS.md:120-128`). The skill lines
  contain `—` and `→`.
- **Fixtures must include** an em dash *and* a plain hyphen separator, a `→`, CRLF line endings, a
  single-slug list (the 5.1 `.Count -eq $null` trap), a duplicate slug, and a case variant.
- Re-run at least one suite under a **hostile code page** and under **both PowerShell hosts**
  (5.1 and 7) — a 5.1-vs-7 divergence hid a harness defect for an unknown number of releases.

## 6. Division of labour

Implementation by codex (`gpt-5.6-sol`), **one item per round, with a WIP commit between rounds** —
a later round has previously destroyed an earlier round's only on-disk copy. The brief must forbid
reformatting ("edit in place, do not collapse lines, do not restructure").

Codex's self-reported before/after is **not** evidence. Every red-test in §4.1 is re-run by the
reviewer in the real environment; a sandbox `PATH` has produced a false pass here twice. Grep every
diff touching `src/` for `C:\|/home/|/Users/` — `no-meta-leak` does not catch machine-local paths.

## 7. RCA seed (Maintenance model #5 — written now, confirmed at ship)

*Why did no gate catch these?* All three are **structural properties of Markdown that the existing
gates deliberately do not model.** The mirror gate models *verbatim identity* and was pointed at
four sections chosen in v0.8.0; anything condensed on purpose was out of its reach **by
construction** — and `## Common Tasks`, the section that changes most often because it changes every
time a skill is added, sat in that blind spot for 44 versions. `validate-dist` models *files and
paths* — does this script exist, does this link resolve — and never *document internals*.

*What else is exposed to the same class?* Partially answered already: the shipped docs carry a
**second** cross-reference grammar — `Verification Rule #N`, `Test leanness #N`, `Leanness #N`,
`Agentic Workflow §N` — which points into numbered lists in a **different** file
(`.github/instructions/framework-rules.instructions.md`) and is checked by nothing. I verified the
current targets all resolve (Verification Rules 1–11, Leanness 1–16, and every citation lands
inside those ranges), so there is **no live defect** — but it is the same blind spot one file over,
and the numbered lists it points into are edited by us regularly. File it as its own entry with its
own proportionality case; do **not** bolt it onto this cluster on the assumption that more gate is
better.
