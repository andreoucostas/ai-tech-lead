# B-59 — the guard's checks can go inert, and the harness cannot see it

**Status:** DESIGN, awaiting adversarial critique (Maintenance model #1). No implementation until
the critique returns, each finding is verified, and this is re-locked.
**Priority:** P2 · **Invariants:** #3 #5 · shipped change ⇒ release · needs a WSD record.

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
matches() {
  printf '%s' "$content" | grep -Eq "$1"
  case $? in
    0) return 0 ;;
    1) return 1 ;;
    *) guard_pattern_error "$1"; return 1 ;;
  esac
}
```

`guard_pattern_error` writes a diagnostic to **stderr** and sets a flag. **What the flag does is the
one real design decision here, and it must be made deliberately:** the guard is a PreToolUse hook, so
failing closed means blocking a developer's write because *our* regex is broken. Recommended:
**do not block on a pattern error, but make it impossible to miss** — emit a loud stderr line naming
the pattern, and have the test suite treat any pattern error as a failure. Rationale: a false block
costs more trust than the gap (B-48's stated principle), and the error is a *maintainer* defect that
should be caught by our gate, not by the consumer's editor. State this in the WSD either way.

### 3b. Case-sensitivity policy — decide it, write it down, sweep it

**Policy: guard patterns are CASE-SENSITIVE by default**, matching both `grep -E` and the languages
being matched (C#, ESLint directives, and TS pragmas are all case-sensitive, so a case-insensitive
match can only ever over-block on invalid code). Deliberate case-insensitivity is spelled **inline**
as `(?i)` in the PowerShell pattern and `grep -Ei` in the twin, so it is visible at the call site and
mirrorable, never implicit in the operator.

Sweep `guard.ps1`'s **22** `-match` → `-cmatch`, except where a pattern genuinely needs folding —
check each; do not bulk-replace and assume. Then add **adversarially-cased fixture cases** so
`TwinParity` can actually see a divergence: today it cannot, because no fixture differs only by case.

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

`enforce-standards` step 2 ships a NUnit CI grep using GNU-only `\s`/`\b`, which are **literal** on
BSD/macOS grep. It works on typical Linux CI and is the exact trap this entry is about. The entry
records a verified POSIX-safe equivalent: `'^[[:space:]]*\[.*[^A-Za-z]Ignore[^A-Za-z]'`.

## 4. Verification

Both twins parse (`bash -n`, PS AST) → `Guard.Tests` + `TwinParity.Tests` green on all three dists →
the 3d self-test observed **red** with each planted invalid regex and green after → adversarially-cased
fixtures shown to fail before 3b and pass after → both PowerShell hosts → `validate-dist` ×3 → meta
suite → BOM + machine-path sweeps → both CI legs → release.

## 5. Not

Do not add a 21st `grep -Eq … &&` while fixing the first 20. Do not make the guard fail closed on a
pattern error without recording that decision as a WSD — it changes who pays for our bug. Do not
replace the one existing `-cmatch` with `-match` for consistency; it is the correct one.
