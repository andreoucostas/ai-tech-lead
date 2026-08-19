# B-55 — vendor-behaviour facts have no single source

**Status:** **REV 2 — RE-LOCKED after critique. Implementation authorised.**
**Priority:** P2 · **Invariants:** #5 #6 · **meta-only after rev 2 — no release.**
**Critique:** `.claude/plans/2026-08-18-b55-sol-critique.md` — REQUEST CHANGES, four blocking
findings. Three accepted outright; the fourth (no concrete regexes) is answered by §4b below.

> **Two corrections that change the shape of the work.**
>
> **1. `validate-dist` is the wrong home, and this is the same boundary B-131 just enforced.**
> `template-checks` and the shipped validator run **in consumer repositories**. A vendor-fact
> denylist is *maintainer bookkeeping*: a consumer may accurately document an older Copilot
> version, quote a superseded claim in their own changelog, or describe a different hook
> arrangement on purpose. Failing their build over our vocabulary is exactly what B-131 forbids for
> changelog grammar, one file over. **The denylist moves to the meta suite, scanning composed
> `dist/*`** — where it is maintainer knowledge that need not ship at all. This makes the item
> meta-only and drops the release.
>
> **2. I chose the minority spelling.** Measured: `≥` appears **18** times, ASCII `>=` **4**. Rev 1
> proposed normalising *to* `>=`, i.e. rewriting 18 dominant instances to adopt 4 minority ones —
> backwards. Worse, the premise was wrong: normalisation is **not** a prerequisite for gating,
> because one regex can accept `(?:>=|≥)` with an optional `v`. No parser, test or assertion
> anywhere consumes this typography (searched). **The migration is dropped entirely** — it was
> churn justified by a constraint that does not exist.

---

## 1. Problem, and it keeps recurring

Claims about what Copilot/Claude actually *do* are duplicated across `docs/enforcement-surfaces.md`,
the `hooks.json` `_comment`, three stack `README.md` hook tables, six `boy-scout-check` headers, and
`docs/presentation/framework-technical.html`. The record of what that costs:

- when Copilot shipped `agentStop`, **five** surfaces still asserted "Copilot has no equivalent event";
- a README asserted "Copilot does not consume hook stdout for this event" while
  `enforcement-surfaces.md` said the opposite **in the same commit**;
- a factually wrong claim (a Stop hook's `decision:"block"` reason "is shown only to the user" — it
  is shown to Claude) survived in **six** hook headers for months;
- **2026-08-18, this session:** the B-147 correction had to land in the matrix, the `_comment`, and
  the narrative simultaneously. That is this entry's thesis demonstrated again, twelve versions on.

`DocTruth` covers internal repo facts (paths, version stamps). Nothing tests prose about *external*
behaviour.

## 2. Measured surface (2026-08-18)

`grep` over `src/` for Copilot CLI version claims returns **43 occurrences** — and in **four
different spellings**: `CLI ≥ v1.0.65` (12), `CLI ≥ 1.0.72` (5), `CLI >= v1.0.65`, `CLI >= v1.0.72`.
The spelling drift is not cosmetic: it is direct evidence that these were written independently
rather than derived from one place, and it is why no gate can currently check them.

## 3. Proportionality (Maintenance model #6)

Harm is **observed and repeated** — four incidents, the most recent today. So *whether* to act is
not in question.

**The smallest fix that removes most of the harm is B-55's own "cheap first step": a denylist gate
for superseded claims.** It is reactive — it catches a claim we have already learned is wrong — but
that is exactly the failure mode with a record: every one of the four incidents was a claim that
*became* false when the vendor changed, and stayed shipped. A denylist turns the next vendor change
from "six files quietly become wrong" into "the build fails".

**Rejected for now, and why:** a full canonical-source refactor (every surface replaced by a pointer
into `enforcement-surfaces.md`) is the tidier end state, but it is a large prose migration across
~11 shipped files whose benefit over the denylist is *preventing* duplication rather than *catching*
staleness — and duplication is not itself what hurt us; stale duplication is. Do the cheap thing,
observe whether the class recurs, and revisit. **Also rejected:** a machine-readable registry that
every surface is generated from — same reasoning, larger, and it would need a composer change.

**In scope because it is nearly free:** normalise the four spellings to one. No gate over these
claims is possible while the same fact is written four ways, so this is a prerequisite rather than
tidying.

## 4. Design

**(a) ~~Normalise the spelling.~~ DROPPED — see the correction above.** `≥` is dominant 18:4, one
regex can accept `(?:>=|≥)` with an optional `v`, and nothing parses the typography. Rewriting 18
files to adopt the minority form would be churn justified by a constraint that does not exist.

**(b) A superseded-claims denylist**, `scripts/vendor-claims-denylist.txt`, one file read by both
twins so it cannot drift (the same construction `meta-denylist.txt` already uses for invariant #6).
Each entry: a regex, and the reason it is superseded, with the date and the observation that
superseded it. Seeded with the four known-dead claims:

| superseded claim | killed by |
|---|---|
| "Copilot has no equivalent event" (and variants) | `agentStop`, CLI 1.0.72 |
| "does not consume hook stdout" for `userPromptSubmitted` | CLI 1.0.65 |
| a Stop `reason` "is shown only to the user" | it is shown to Claude; the confusion was with `stopReason` |
| any claim that `route-prompt` injection reaches the model **while more than one** `userPromptSubmitted` hook is registered | B-147, CLI 1.0.80 |

**(c) The gate lives in the META SUITE**, `.claude/hooks/tests/VendorClaims.Tests.ps1`, scanning the
composed `dist/*` trees. PowerShell-only (WSD-005), so no twin. It fails when a composed file
matches a denylist entry, reporting the file, the matched text, and *the reason it is superseded* —
the reason is the point; a bare "forbidden string" finding teaches nothing and gets suppressed.

**Neither the denylist file nor the check ships.** That is the ownership fix: consumers never
inherit our vendor-fact vocabulary, and a consumer who accurately documents an older Copilot
version is not our build's business.

**Each regex must be proved twice before it is added** — the critique's fourth finding, and B-59's
inert-check class applied here: (i) it **matches the real superseded text** as it was actually
written, not as we remember writing it; (ii) it does **not** match the corrected prose that replaced
it, or any legitimate current sentence. A denylist entry that matches nothing is inert; one that
over-matches blocks correct writing. Both failure modes are silent.

**(d) A dated provenance line** in `enforcement-surfaces.md` naming it as the canonical home for
vendor-capability claims, so the next person adding a claim knows where it belongs. Prose, not a
gate — and labelled as such rather than implied to be enforced.

## 5. Tests

Red-test each denylist entry: plant the superseded claim into a scratch dist and show the check
fails with the reason attached; show a clean dist passes. Vacuity guards: zero shipped files
scanned, or a denylist that parses to zero entries, must **fail** rather than pass silently. Both
twins, both PowerShell hosts.

## 6. Not

Do not add a claim to the denylist that is merely *narrower* than the truth — the list is for
statements that are now **false**, not for imprecise ones, or it will accumulate style opinions and
stop being trusted. Do not gate prose we have never verified: an unverified claim is B-143's
problem, not this one.
