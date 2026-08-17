# B-17 + B-81 — scoped test-integrity delivery, and a licence that travels

**Status:** **B-17 REJECTED 2026-08-17** after adversarial critique
(`.claude/plans/2026-08-17-b17-b81-sol-critique.md`), every decisive claim re-verified independently.
**B-81 PROCEEDS with the critique's changes.** Target release v0.54.0.

## B-17 — rejected, and why the rejection is right

The design's premise was that a narrow `applyTo` buys "highest marginal salience". Three verified
facts kill it:

1. **The rules already arrive.** The broad carrier is `applyTo: "**"` and already contains both the
   red-test rule and "No tautological assertions" (verified in
   `dist/dotnet/.github/instructions/framework-rules.instructions.md`). Canary 3 proved `"**"`
   delivers. B-17 therefore adds locality, not coverage.
2. **"Test files" is not expressible as a glob.** xUnit imposes no filename convention, so
   `**/*Tests.cs` silently misses `*Test.cs`, `*Spec.cs` and directory-convention layouts — and a
   miss is indistinguishable from delivery, because scoped instructions have no telemetry. Widening
   to `**/*.cs` restores coverage and destroys the salience premise in the same move.
3. **The value claim was unmeasured, and the design said so and shipped anyway.** That is precisely
   the "on faith" move this repo refuses. Delivery evidence is not adherence evidence.

Two further findings worth keeping: a *sharpened restatement* of canonical rules creates a semantic
contradiction surface that a numeric-citation gate cannot detect (byte duplicates can be
equality-gated; paraphrase drift cannot), and classifying the file as "on-demand" would have hidden
a real cost in a bucket that is **reported but never policy-gated** — on-demand context is already
3-5x static (dotnet 195,951 / angular 147,968 / monorepo 228,887 chars) with no ceiling at all.

**What would revive it:** a paired hooks-off Copilot CLI canary — arm A carrier only, arm B carrier
plus the candidate file, same test-writing prompt against a planted defect, scored on whether the
generated test is observed red and rejects a tautological/spy-only assertion, over enough runs to
survive stochasticity. If B beats A on pre-declared criteria, redesign the glob and the budget
treatment and revisit. Not before.

---

## 2. B-81 — the licence must travel with what consumers copy

### 2.1 The problem

MIT sits at the repo root, which makes *this repository* legally consumable. The unit of consumption
is `dist/<stack>/`, whose contents the installer copies into the consumer's own tree — and those
copied files carry no licence text. A compliance scan of the consumer's repo finds unlicensed
third-party files. Confirmed: `dist/dotnet/LICENSE` does not exist.

### 2.2 The hazard that made root-only the original decision

A plain `LICENSE` at the dist root would be copied to the consumer's repo root and **would collide
with, or overwrite, the consumer's own LICENSE** — a far worse outcome than the problem it solves.
`install.ps1:30` keeps a `$protected` list for exactly this class, and `LICENSE` is not on it.

### 2.3 Decision (revised after critique)

Ship, composed into every dist from a single source:

| path in the consumer's repo | content |
|---|---|
| `LICENSES/ai-tech-lead-MIT.txt` | the verbatim MIT text |
| `NOTICE-ai-tech-lead.md` | what the framework is, upstream URL, version, which paths it governs, and where its licence text lives |

**Why not a bare `LICENSE-ai-tech-lead` at the root, which was the first decision.** The claim that a
namespaced root file is "what a compliance scanner actually finds" was **unevidenced, and I am not
going to evidence it** — GitHub's own licence detection reads the repository's `LICENSE` and does not
model third-party or dependency licences at all, so for that one concrete scanner a second root file
changes nothing. Worse, a licence-like file at a consumer's root risks a tool reading *our* MIT as
*their* project licence. `LICENSES/` + a NOTICE is the standard SPDX/REUSE direction for
third-party material, keeps our text clearly attributable to us, and does not squat on their root.

**Honest limit, to be written into the backlog entry rather than the marketing:** this is
standards-aligned, not scanner-verified. No scanner has been run against an installed fixture here.
If a real customer names their compliance tool, run it before and after and record the result — that
observation, not a generic claim, is what would justify a different layout.

**Drift:** the shipped text must be byte-identical (LF-normalised) to the root `LICENSE`. Two
hand-maintained copies of a legal text is exactly the class this repo gates elsewhere. Either copy it
at build time from the root file, or add an equality gate. Prefer the gate — the composer does not
currently reach outside `src/`.

### 2.4 Installer collision policy — the part that makes this safe

The first design said "namespaced, so it cannot collide". That is false, and the installers make it
false in three modes: both recursively overwrite every non-meta root entry, brownfield archives only
`$protected` plus the carrier, and update snapshots/restores only `$protected`
(`install.ps1:28-32,74-85,92-110`; `install.sh:27-30,72-81,88-112`). A pre-existing consumer file at
either path would be silently overwritten.

Both `$protected` and not-`$protected` are wrong here: adding it makes a framework-owned legal notice
go stale and stop travelling on update; omitting it asserts ownership over a path whose provenance we
have not established.

**Policy:** copy when absent. Overwrite when the existing file carries the framework-owned marker (or
byte-matches a known prior framework version). Otherwise **stop and report the collision** rather
than overwrite or silently skip. Brownfield must not hand licence text to `/adopt` as mergeable AI
guidance.

**Tests required:** greenfield creates both files; brownfield with a pre-existing conflicting file at
each path reports rather than clobbers; clean update replaces a stale framework-owned copy;
consumer-modified update does not silently overwrite. Both twins, both installers.

---

## 3. Definition of done

1. Every new assertion observed failing first — the collision policy especially, since its whole
   purpose is a refusal.
2. `build` ×3 → `git status --porcelain dist/` empty [#1]; monorepo sibling reviewed (WSD-015).
3. `validate-dist` ×3 on **both** twins; three dist hook suites; meta suite.
4. Root `LICENSE` ↔ shipped copy equality gate, red-tested by perturbing one byte.
5. Installer smoke: greenfield + brownfield into temp dirs, all three dists, both twins.
6. Root `CHANGELOG.md` + `## 0.54.0 — Unreleased` with content in all three
   `src/stacks/*/files/CHANGELOG.md` **before** `release.ps1` runs [#7]; consumer entries in the
   consumer's voice.
7. Backlog: B-81 to Done stating the standards-aligned-not-scanner-verified limit; B-17 to Done as
   REJECTED with the critique's reasoning attached; B-143 filed (already done).
8. **CI green on both legs before this is called done.** v0.53.0 shipped a linux-only regression no
   Windows run could see, twice.

## 4. Division of labour

codex (`gpt-5.6-sol`) implements from this locked spec; Claude reviews, re-runs every red-test
independently, owns git and the release. Codex's self-report is not evidence.
