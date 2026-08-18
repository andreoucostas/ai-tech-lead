# B-59 — the guard's checks can go inert, and the harness cannot see it

**Status:** **REV 2 — RE-LOCKED after critique. Implementation authorised.**
**Priority:** P2 · **Invariants:** #3 #5 · shipped change ⇒ release · needs a WSD record.
**Critique:** `.claude/plans/2026-08-18-b59-sol-critique.md` — REQUEST CHANGES, **four blocking
findings, all four verified by the reviewer and all four accepted.** Rev 1's §3a helper, §3b policy
and §3e replacement were each wrong in a different way; the corrections are folded in below and the
superseded text is struck rather than deleted.

> **The one that would have caused a regression.** Rev 1 said case-insensitivity "can only ever
> over-block on invalid code". **That is false for file names.** `guard.ps1` routes on
> `$fp -match '\.cs$'` and `$fp -match '\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$'`; under a blanket
> `-cmatch` sweep `src/Foo.CS` and `src/app.TS` stop being inspected **at all**. Verified:
> `'src/Foo.CS' -match '\.cs$'` → True, `-cmatch` → **False**. So rev 1 would have turned a
> harmless over-block into a genuine loss of inspection in the shipped write-guard.
>
> **And the same probe found a live defect this entry did not know about.** The bash twin routes with
> `case "$fp" in *.cs)`, which is case-**sensitive**: verified, `src/Foo.CS` does **not** match today.
> So on a case-insensitive Windows tree a file named `Foo.CS` is inspected by `guard.ps1` and **not**
> by `guard.sh` right now — an asymmetry in the floor, live on the current release, and the opposite
> direction from the one this entry was filed about. Rev 2 fixes the bash side rather than
> "harmonising" by making both blind.

---

## 1. Premise, re-validated on the current tree (2026-08-18)

B-59 was filed at v0.37.0; we are at v0.59.0, so per B-83 the numbers were re-counted, not trusted:

| claim | filed | measured today |
|---|---|---|
| `grep -Eq … && …` fail-open sites in `guard.sh` | "20 sites" | **20 `grep -Eq` invocations**, in two distinct shapes |
| `guard.ps1` case-insensitive `-match` | 18 vs 1 `-cmatch` | **22 `-match` vs 1 `-cmatch`** |
| fixtures are one-line snippets | yes | **32 cases, every one a single-line `c='…'`** |

The two fail-open shapes are worth separating, because they need the same helper but read differently:

- **Test-defeat block (11 invocations)** — `printf '%s' "$content" | grep -Eq '…' \` continued onto
  `&& reasons+=(…)`.
- **Secret block (7 invocations)** — `[ -z "$secret" ] && printf … | grep -Eq '…' && secret="…"`.

In both, `grep` exit **2** (invalid regex, unsupported construct, unreadable input) is indistinguishable
from exit **1** (no match): the `&&` chain simply stops, no reason is appended, and **the write is
allowed**. A first-draft B-57 pattern did exactly this — `[\](,]` is invalid POSIX ERE — which would
have shipped a check that blocks on `.ps1` and silently does nothing on `.sh`. No CI leg would have
failed, because no fixture exercised the erroring twin.

## 2. Proportionality (Maintenance model #6 — before the design locks)

**Honest severity:** there is **no live exploit today**. Every current regex is valid ERE, so no site
is presently inert; and on the case-sensitivity axis the divergent inputs (`#PRAGMA WARNING DISABLE`,
`[FACT(Skip="x")]`) are invalid code that `.ps1` merely over-blocks. This is a **near-miss and an
armed trap**, not an incident — weaker than B-147's observed harm, and the design must not pretend
otherwise.

**Why it is still worth doing, and bounded:** the subject is the shipped write-guard, which
`docs/enforcement-surfaces.md` presents as the deterministic floor — the product's central
enforcement claim. The failure mode is *silent*: a guard that stops blocking looks exactly like a
guard with nothing to block. And the fix is mechanical and bounded — one helper, 20 call sites, a
stated policy, and fixtures.

**Smaller alternatives considered:**
- *Fix only the exit-code handling, skip the case policy.* Rejected: the case divergence is the half
  that will bite next, because it bit B-57 already (`Ignore` colliding with the legitimate identifier
  `ignore` in `Handle(evt, ignore, ctx)` needed `-cmatch`), and there is still no written rule for
  whoever adds pattern #23.
- *Do nothing and document the bypass.* Rejected: B-48 is the entry for disclosing bypasses we choose
  to keep; this one is cheap to close, so disclosure would be a worse trade.
- *Rewrite the guard's matching engine.* Rejected as disproportionate — nothing here needs a new
  engine, only an error-checked call and a stated policy.

**The part that is not optional** is §3d: an instrument that cannot detect an inert check is the
actual subject of this entry. Delivering (a)–(c) without (d) would leave the entry's thesis unmet.

## 3. Design

### 3a. Make `grep` errors loud — one helper, all 20 sites

Add a single shell function to `guard.sh` and route every site through it:

```sh
# 0 = matched, 1 = no match, 2+ = grep could not answer (bad regex, unreadable input).
# The third case must never be silently folded into "no match": that is a check that has stopped
# working while reporting that it found nothing.
# `--` is LOAD-BEARING: the private-key pattern begins with `-----`, and without it grep parses the
# pattern as an option and returns 2. Verified: without `--` exit=2 ("grep: unknown option"),
# with `--` exit=1. The existing site already spells `grep -Eq --`; the rev-1 helper dropped it and
# would have made the first secret rule permanently "erroring", i.e. inert.
matches() {          # case-sensitive (default policy, see 3b)
  printf '%s' "$content" | grep -Eq -- "$1"
  case $? in
    0) return 0 ;;
    1) return 1 ;;
    *) guard_pattern_error "$1"; return 2 ;;
  esac
}
matches_i() { … same, with grep -Eiq -- … }   # deliberate folding only
```

**Error policy — SPLIT, not uniform. Rev 1's "never block" was wrong.** The critique's argument is
accepted: a regex compilation error is not an ambiguous content classification, it is proof that a
named part of the advertised floor is unavailable; stderr may live only in a log; and a test-suite
failure protects a *future release*, not the consumer already running the broken pattern.

| pattern class | on pattern error | why |
|---|---|---|
| the **7 secret** patterns | **FAIL CLOSED** (block the write) | high-confidence, any-file rules; the shipped header already promises they fail closed once content is extracted, so silently disabling one contradicts the stated contract |
| **test-defeat / suppression** patterns | **warn, allow** | lower-confidence rules where our bad regex must not brick an ordinary refactor — B-48's trust judgment |

Both paths emit the pattern and its category. The planted-invalid-regex test (§3d) must exercise
**both** policies, not just one. Record the split in the WSD.

**Also in scope, or explicitly out — say which:** the generic credential pipeline sits outside the
counted 20 sites, suppresses grep stderr, and uses command substitution that cannot distinguish "no
match" from "grep failed". Either route it through the helper or state in the WSD that it remains
deliberately fail-open. What is not acceptable is the claim "all grep errors are now loud" while it
stands — that would be a fresh false claim in an entry about false confidence.

### 3b. Case-sensitivity policy — decide it, write it down, sweep it

The policy has **two halves**, and rev 1 collapsed them into one. That collapse is the blocking error.

**CONTENT patterns (19 sites) — CASE-SENSITIVE.** C#, ESLint directives and TS pragmas are all
case-sensitive languages, and the seven secret token formats are case-sensitive by specification, so
folding can only over-block on input that is invalid anyway. These become `-cmatch`, matching the
bash twin's existing `grep -E`.

**FILE-ROUTING predicates (3 sites) — DELIBERATELY CASE-INSENSITIVE, IN BOTH TWINS.** `\.cs$`,
`\.(ts|tsx|js|jsx|mts|cts|mjs|cjs)$` and the `.spec` predicate decide *whether the file is inspected
at all*. Verified: `'src/Foo.CS' -match '\.cs$'` → True but `-cmatch` → **False**, and `'src/app.TS'`
likewise. A blanket sweep would silently stop guarding mixed-case extensions, which are legal and
occur on case-insensitive Windows trees. Folding here is spelled **inline** — `(?i)` in PowerShell,
`grep -Eiq --` / a case-folded `case` in bash — so it is visible at the call site and mirrorable,
never implicit in the operator.

**Fix the bash twin's routing too — it is a live defect, not a parity concession.** `guard.sh` routes
with `case "$fp" in *.cs)`, which is case-sensitive: verified, `src/Foo.CS` does **not** match today.
So `Foo.CS` is currently inspected by `guard.ps1` and **not** by `guard.sh`. Do not "harmonise" by
making the PowerShell side equally blind; bring bash up to the correct behaviour. Add
**uppercase/mixed-case filename fixtures** (`Foo.CS`, `app.TS`, `app.SPEC.TS`) — today no fixture
differs only by case, which is why `TwinParity` cannot see any of this.

The generic credential detector already folds explicitly (`(?i)` / `grep -Ei`). Preserve that.

### 3c. Fixtures that resemble the input

The hook receives **whole file contents**; all 32 fixtures are one-line snippets, so any failure that
only manifests across lines is untestable by construction. Convert several cases to realistic
multi-line file bodies — at minimum one C# test class, one TS spec, and one file whose offending
construct sits mid-file rather than at line 1. Keep the existing one-liners; add, don't replace.

### 3d. Prove the harness can see an inert check — the entry's actual thesis

Add a self-test that **plants a deliberately invalid regex in each twin and asserts the suite goes
red.** Use `_MutationHelper.ps1` (B-84) so the mutation is recorded as executable text and is asserted
to have applied. Without this, everything above is unverified belief: the whole point of B-59 is that
an inert check and a check that legitimately did not match are indistinguishable *from the outside*.

### 3e. Same portability class, swept together

`enforce-standards` step 2 ships `grep -rn --include=*.cs '^\s*\[.*\bIgnore\b' tests/` in the dotnet
and monorepo skills (both `.claude` and `.github` mirrors). `\s` and `\b` are GNU extensions and are
**literal** on BSD/macOS grep, so the recipe is non-portable — the exact trap this entry is about.

> **The replacement B-59 calls "verified equivalent" is NOT equivalent, and this design repeated the
> claim without running it.** `'^[[:space:]]*\[.*[^A-Za-z]Ignore[^A-Za-z]'` **misses the canonical
> bare `[Ignore]`**, because after `\[` it demands another non-letter before `Ignore`. Measured, GNU
> grep 3.0: `[Ignore]` old=0 **new=1** (i.e. no longer matched), while `[Test, Ignore("x")]`,
> `[TestCase(1,Ignore="x")]` and the near-misses `[JsonIgnore]` / `[IgnoreAttribute]` /
> `var Ignore = 1;` all agree. So adopting it as written would silently stop flagging the commonest
> form of the very thing it exists to catch. The false "verified" label came from the backlog entry
> itself and was propagated here unchecked — a worked example that was never run, which is the same
> failure recorded in B-146.

**Do:** derive a form that admits *either* the opening bracket or a later separator before `Ignore`,
and prove it against the full table — bare `[Ignore]`, comma-separated NUnit forms, `[TestCase(…
Ignore = …)]`, the near-misses above, and beginning/end boundaries — before claiming equivalence.
BSD/macOS grep could not be reached on this host, so portability of the *replacement* stays
**asserted, not observed**, and must be labelled that way wherever it lands.

## 4. Verification

Both twins parse (`bash -n`, PS AST) → `Guard.Tests` + `TwinParity.Tests` green on all three dists →
the 3d self-test observed **red** with each planted invalid regex and green after → adversarially-cased
fixtures shown to fail before 3b and pass after → both PowerShell hosts → `validate-dist` ×3 → meta
suite → BOM + machine-path sweeps → both CI legs → release.

## 5. Not

Do not add a 21st `grep -Eq … &&` while fixing the first 20. Do not make the guard fail closed on a
pattern error without recording that decision as a WSD — it changes who pays for our bug. Do not
replace the one existing `-cmatch` with `-match` for consistency; it is the correct one.
