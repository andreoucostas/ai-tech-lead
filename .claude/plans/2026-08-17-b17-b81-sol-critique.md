# Adversarial critique — B-17 and B-81

**VERDICT — B-17: REJECT as designed.** Do not ship a second test-policy carrier until a cheap,
hooks-off Copilot CLI A/B canary demonstrates a behavioural improvement over the already-delivered
broad carrier. If that canary is positive, redesign the glob and budget treatment before proceeding.

**VERDICT — B-81: PROCEED WITH CHANGES.** Ship attributable third-party licensing information, but
do not claim that a creatively named root licence is a generally effective compliance-scanner
instrument. Prefer a standard `LICENSES/` location plus an explicit notice, and define collision and
drift behaviour before implementation.

## BLOCKING findings

### 1. B-17's stated outcome is unmeasured, although a cheap relevant instrument is available

**Evidence.** The design itself concedes that the value claim is “raises test-integrity adherence”
but that no behavioural canary will be built (`.claude/plans/2026-08-17-b17-b81-consumer-value-design.md:120-127`).
The evidence it substitutes is Canary 3: an identical **fileless** prompt produced delivery for
`applyTo: "**"`, and `NOT-IN-CONTEXT` for `applyTo: "**/*.cs"` (`meta/BACKLOG.md:1558-1562`). That
experiment establishes conditional delivery only. It did not ask the model to write a test, did not
open a matching test file, and had no adherence outcome. Meanwhile, the existing carrier already
contains the red-test requirement and all test-leanness rules (`dist/dotnet/.github/instructions/framework-rules.instructions.md:20,45-50`;
Angular equivalents at `dist/angular/...:20,45-50`). The backlog's concrete B-17 entry claims only
“highest marginal salience” (`meta/BACKLOG.md:4997-5002`), not an observed failure or improvement.

**Why it matters.** The design is verbally honest about the evidence gap, but still proposes shipping
the behaviour intervention. Maintenance rule 4 requires a constructible success world, and rule 6
requires observed harm and proportionality (`CLAUDE.md:112-133`). “The extra file arrives” is not a
proxy for “the model follows it more often,” especially when the same rules already arrive through
the broad carrier. This is salience theatre until the marginal effect is measured.

**Recommendation.** Run a Copilot CLI paired canary before approving B-17: same small fixture, same
test-writing prompt, hooks disabled, arm A with the current carrier only, arm B with the candidate
scoped restatement. Plant a production defect and score (at minimum) whether the generated test is
first observed red, rejects a tautology/spy-only assertion, and fails when the defect is present.
Use multiple runs because this is stochastic behaviour, unlike Canary 3's deterministic delivery
question. A success world is explicitly: B beats A on predeclared adherence criteria without a rise
in refusal or irrelevant prose; a failure/no-effect world is no material difference. Copilot CLI
canaries are already feasible on this box: B-97 records CLI 1.0.77 Canary 2 and Canary 3
(`meta/BACKLOG.md:1548-1562`). Do not implement on delivery evidence alone.

### 2. A sharpened restatement creates a semantic contradiction surface, and the proposed drift gate cannot detect it

**Evidence.** The proposed gate checks only that cited rule numbers exist
(`...consumer-value-design.md:53-58`). Yet the proposed lines paraphrase five rules: red-check,
tautology, boundaries/mocking, framework tests, and behaviour versus implementation
(`...consumer-value-design.md:48-52`). The canonical wording contains material qualifications that
one-line examples can easily lose: “mock only true external boundaries,” owned collaborators, and
fake/in-memory preferences (`dist/dotnet/.github/instructions/framework-rules.instructions.md:48`),
and the red rule permits a stated defect when a red run is impractical (`...:20`). Existence of
numbers 11–16 says nothing about agreement. The carrier itself declares the canonical rails and says
they must not be contradicted (`src/core/.github/instructions/framework-rules.instructions.md:52-64`).

**Why it matters.** A shorter, differently worded imperative has higher local salience and can
therefore override the nuanced canonical rule. That is worse than byte duplication: byte duplicates
can be equality-gated, while semantic paraphrase drift is not deterministically checkable. The
claimed narrow citation gate is incapable of registering the defect it is said to prevent.

**Recommendation.** Do not restate the five rules. If the behavioural canary justifies a scoped
file, make it a very short routing pointer that identifies the canonical carrier and exact headings,
with at most one non-normative reminder. Better still, generate any repeated normative lines from a
single source and equality-gate them. Drop the arbitrary `<=20 lines`: five qualified rules plus
frontmatter, ownership notice, examples, and a pointer cannot honestly fit in 20 lines without
discarding qualifications; the existing five relevant canonical rules alone occupy six dense lines
in each composed carrier (`dist/monorepo/.github/instructions/framework-rules.instructions.md:45-50`).

### 3. The proposed .NET glob silently excludes valid tests; no exact narrow filename glob can solve that

**Evidence.** The repository contains no comma-separated `applyTo`; the targeted command
`Select-String -Pattern 'applyTo:.*,'` found none. It does contain a brace-pattern example,
`applyTo: "**/*.{ts,html}"` (`src/stacks/dotnet/files/README.md:257`), but that is documentation,
not a host canary. Canary 3 tested only `"**/*.cs"` (`.claude/scripts/canary-applyto-scope.ps1:11`).
The design acknowledges that `**/*Tests.cs` misses `*Test.cs`, `*Spec.cs`, and directory-convention
tests (`...consumer-value-design.md:76-79`). xUnit imposes no filename convention, so no suffix-only
glob can cover freely named test sources.

**Why it matters.** Conditional instructions have no delivery telemetry. A developer sees the file
installed but cannot distinguish “policy delivered” from “filename missed.” Partial silent coverage
is actively harmful if represented as test-file delivery: it creates false assurance and biases the
framework toward conventional layouts.

**Recommendation.** If finding 1 produces a positive result, ship one independently canaried file per
language with `applyTo: "**/*.cs"` for .NET and `applyTo: "**/*.ts"` for Angular; use those same two
files in monorepo. These are the exact broadest single patterns supported by local evidence (the
`.cs` form by Canary 3; `.ts` still needs its own positive matching-file canary). They trade some
precision for complete language coverage. Do **not** claim they mean “test files”; call them
language-scoped test-policy reminders. If production-file context cost or dilution makes these
unacceptable, that is further evidence to DROP B-17 rather than ship a knowingly incomplete suffix
set. Do not use comma or brace syntax until a matching-file and non-matching-file canary proves the
chosen host interpretation.

### 4. Canary 3 is about fileless delivery, not matching-file cost; “on-demand” currently hides an ungated real cost

**Evidence.** Canary 3 deliberately used a fileless prompt even though a real `Program.cs` existed
(`meta/BACKLOG.md:1558-1561`). It proves that merely having a matching file in the repository does not
load a narrow instruction. It says nothing about the state B-17 targets: a developer actively editing
a matching file, when the instruction body is in model context. The meter hard-codes the carrier into
both static groups (`scripts/context-footprint.ps1:245-251`; bash twin
`scripts/context-footprint.sh:70-72`) and does not enumerate other instruction files at all. Its
baseline explicitly says B-17 should join `static.copilot`, and that `ondemand-info` is never
policy-gated (`meta/context-footprint.json:1363-1364`).

Executed command and observed output:

```text
pwsh -NoProfile -File scripts/context-footprint.ps1 -Check
OK: context footprint matches meta/context-footprint.json.

dotnet   static.claude=39501  static.copilot=43561  ondemand=195951
angular  static.claude=38180  static.copilot=44352  ondemand=147968
monorepo static.claude=47858  static.copilot=52437  ondemand=228887
```

The totals were computed from the checked baseline by summing each dist's `ondemand-info[].chars`.
The only declared character ceilings are single-stack `static.claude=40000` and monorepo
`static.claude=48000` (`meta/context-footprint.json:5-8`). Thus headroom is 499/1,820/142 characters
for dotnet/angular/monorepo respectively. There is **no static.copilot ceiling and no on-demand
ceiling**, so those columns cannot be reported “against their ceilings” except honestly as
**UNBOUNDED**.

**Why it matters.** Conditional is a delivery mode, not zero cost. Calling matching-file content
on-demand is semantically reasonable, but putting it in an advisory-only bucket makes the cost
invisible to policy. The current on-demand totals are already 3–5 times static context; adding more
without a ceiling is ungoverned context. Generalising discovery alone fixes omission, not governance.

**Recommendation.** If B-17 survives its behavioural canary, add a distinct
`conditional.copilot` bucket that enumerates every `.github/instructions/*.instructions.md` except
the broad `applyTo: "**"` carrier, reports per-file bodies and a worst-case simultaneously matching
sum, and has an explicit reviewed ceiling. Keep the broad carrier in `static.copilot`. Do not fold
instruction bodies into the existing all-skills `ondemand-info` aggregate: those have different
activation and worst-case semantics. Red-test both twins with (1) a planted new instruction that
must change the baseline/fail `-Check`, (2) a ceiling breach that must fail, (3) a clean candidate
under the ceiling that must pass—the constructible success state Maintenance rule 4 demands.

### 5. B-81 has not established that `LICENSE-ai-tech-lead` clears the claimed scanner/compliance blocker

**Evidence.** The observed repository fact is real: B-81 records that consumers receive dist
contents without licence text (`meta/BACKLOG.md:1060-1071`). But the design supplies no named scanner,
fixture, or result for its assertion that a root namespaced file is “what a compliance scanner
actually finds” (`...consumer-value-design.md:143-149`). GitHub's documented repository licence
detection compares the repository's `LICENSE` file and does not account for dependency licences or
documentation references: <https://docs.github.com/en/rest/licenses/licenses#about-licenses>.
That makes a second, namespaced root file the wrong instrument for at least this concrete scanner.
Deep scanners such as ScanCode inspect licence text and SPDX declarations, but that supports a
standard third-party-attribution layout, not the design's untested filename claim.

**Why it matters.** This item may place a legally useful text in the tree while leaving the alleged
automated adoption blocker unchanged. It also risks presenting the framework's MIT licence as the
licence of the consumer repository if a tool treats a root licence-like file as project-level.
SPDX headers on every shipped file would be discoverable but are grossly disproportionate, increase
context/noise, complicate generated/JSON/shell formats, and still require attribution metadata.
A bare `NOTICE` without the MIT grant is also insufficient.

**Recommendation.** First name the actual compliance acceptance criterion and run its scanner on an
installed fixture before and after. Default design: ship
`LICENSES/ai-tech-lead-MIT.txt` containing the verbatim MIT text plus a small root
`NOTICE-ai-tech-lead.md` identifying the framework, upstream URL/version, governed paths, and licence
path. This distinguishes third-party material from the consumer's own root licence and follows the
standard SPDX/REUSE direction of keeping licence texts in `LICENSES/`. If the actual customer scanner
accepts a single full-text `LICENSE-ai-tech-lead`, the smaller one-file option wins—but record that
observed result, not a generic scanner claim. Gate the shipped licence text byte-for-byte (allowing
only defined newline normalization) against root `LICENSE`; do not maintain two hand-edited copies.

### 6. Installer collision semantics for B-81 are unsafe as designed

**Evidence.** Both installers recursively overwrite every non-meta root entry in greenfield,
brownfield, and update modes (`src/core/scripts/install.ps1:92-110`;
`src/core/scripts/install.sh:88-112`). Brownfield archives only `$protected` plus the existing carrier
(`install.ps1:28-32,57-71`; `install.sh:27-30,56-69`). Update snapshots/restores only `$protected`
(`install.ps1:74-85,120-126`; `install.sh:72-81,118-121`). Therefore a pre-existing consumer
`LICENSE-ai-tech-lead`, `NOTICE-ai-tech-lead.md`, or `LICENSES/ai-tech-lead-MIT.txt` would be silently
overwritten in brownfield and update. Greenfield can also contain arbitrary non-AI files because
mode detection is about AI tooling, not directory emptiness (`install.ps1:34-48`).

**Why it matters.** “Namespaced” lowers collision probability; it does not make collision impossible.
Not protecting the file asserts framework ownership before provenance has been established. Adding it
to `$protected` forever is also wrong: then a framework-owned legal notice can go stale and cease to
travel on update.

**Recommendation.** Do not add the licence/notice to `$protected`. Instead add explicit ownership
logic to both installers: copy when absent; overwrite only when the existing file equals a known
prior framework version (or bears an unambiguous framework-owned marker for the notice); otherwise
stop with a collision error or preserve/archive and report it. Brownfield must not feed licence text
to `/adopt` as mergeable AI guidance. Add greenfield, brownfield-collision, clean-update, and
consumer-modified-update targeted installer tests. The installers need no positive file enumeration
to copy ordinary new files, but they absolutely need this collision policy.

### 7. The touchpoint inventory is incomplete; several stale-enumeration surfaces would remain green

**Evidence.** Repository search found these independent hard-coded surfaces:

- Context classification: `scripts/context-footprint.ps1:246-252` and
  `scripts/context-footprint.sh:70-75`.
- Section-citation scanning includes only `CLAUDE.md`, `AGENTS.md`, and the carrier:
  `scripts/validate-dist.ps1:278`; bash twin `scripts/validate-dist.sh:267`. A scoped file citing
  `Leanness > Test leanness #11-16` would not be scanned by the existing citation gate.
- Carrier import/ownership validation is singular: `scripts/validate-dist.ps1:343-345` and
  `scripts/validate-dist.sh:321-326`.
- Installer delivery regression tests hard-code `$carrierRel`:
  `.claude/hooks/tests/UpdateDelivery.Tests.ps1:21-22`.
- The installer collision registries are singular (`install.ps1:30-32`; `install.sh:29-30`).
- The shipped README describes `.github/instructions/*.instructions.md` generically and the
  monorepo per-stack model (`src/stacks/monorepo/files/README.md:269,276`), while architecture file
  inventories mention only `copilot-instructions.md` (`src/stacks/monorepo/files/docs/ARCHITECTURE.md:63`).
- B-68 is specifically the already-filed class “hard-codes the Instructed file list”
  (`meta/BACKLOG.md:588-596`); merely changing a different hard-coded list does not close it.

**Why it matters.** The proposed template-check addition could validate syntax while the broader
validator ignores the new file's citation, the update-delivery test proves only the old carrier, and
documentation inventories become stale. This repository has repeatedly classified silent stale
enumerations as defects; adding another local list compounds that class.

**Recommendation.** If B-17 is revived, derive one sorted instruction inventory in each relevant
twin and reuse it for frontmatter, non-empty `applyTo`, context classification, and citation scans.
Make zero files a failure only where the framework contract requires at least one. Extend
`UpdateDelivery.Tests.ps1` to enumerate all framework-owned instruction files and prove update
replacement plus collision behaviour. Update the architecture/README ownership tables only where
they promise an inventory. Keep the existing broad-carrier import check singular because only that
file is Claude-imported; do not pretend scoped Copilot files need imports. B-81 additionally needs a
root-LICENSE equality/copy gate and installer smoke assertions; neither appears in the design's
gate list.

## NON-BLOCKING findings

### 8. The proposed monorepo whole-file override is needlessly complex

**Evidence.** The design proposes a core file plus a `src/stacks/monorepo/files/` two-file override
(`...consumer-value-design.md:91-96`). The core composer already supports stack markers, while two
monorepo-only whole files create deletion/negative-composition questions in the single-stack dists.
No existing multi-pattern `applyTo` canary resolves that complexity.

**Why it matters.** It increases composition paths and WSD-015 review burden for a tiny salience aid.

**Recommendation.** If revived, author explicit stack-only instruction files under
`src/stacks/dotnet/files/` and `src/stacks/angular/files/`, with corresponding monorepo siblings
reviewed in the same task, or extend the composer only if a red fixture proves existing composition
cannot express the required absence. Do not force a nominally shared core file where filename,
frontmatter, and examples are stack-specific.

### 9. B-81's notice should identify scope, not imply ownership of the consumer repository

**Evidence.** Installers deliberately exclude the dist's own `README.md` and `CHANGELOG.md`
(`install.ps1:25-26,92-94`; `install.sh:91-95`), so the consumer currently receives no nearby root
metadata explaining which files came from this framework. B-81's backlog asks only whether a licence
copy travels (`meta/BACKLOG.md:1067-1071`).

**Why it matters.** Full MIT text without attribution/scope answers “under what terms?” but poorly
answers “what component does this cover?” A consumer-root file can be mistaken for a project-wide
licensing declaration.

**Recommendation.** The notice should say explicitly that it covers AI Tech Lead Framework files
installed into the repository, name the upstream project/version, and state that it does not license
the consumer's own code. Keep it prose-only; do not invent a brittle exhaustive path manifest unless
the named scanner requires one.

## PROPORTIONALITY decision

### 10. B-17 lacks concrete observed harm on the surface it proposes to change — DROP

**Evidence.** B-17's entry contains no field report, failing eval, or Copilot transcript
(`meta/BACKLOG.md:4997-5002`). The carrier already reaches Copilot without Preview hooks (Canaries 2
and 4, `meta/BACKLOG.md:1548-1557,1574-1599`) and already carries the rules. By contrast B-66 shows
what observed harm looks like: an Angular field report (`meta/BACKLOG.md:533-541`), and it still
refused to ship prescriptive guidance when its probe passed unfixed (`meta/BACKLOG.md:562-569`).

**Why it matters.** B-17 asks for new duplicated context, two gate twins, context-meter changes,
composition complexity, and ongoing drift risk to address an unobserved marginal-salience theory.

**Recommendation.** **DROP B-17 now.** The materially smaller action is to retain the broad carrier
and add only the cheap A/B canary if/when a real hooks-off Copilot test-integrity failure is observed.
A positive canary can re-open a smaller pointer-only design. This applies rule 6 rather than turning
the critique into implementation preparation.

### 11. B-81 has an observed distribution gap, but the alleged adoption blocker is not yet observed

**Evidence.** `dist/dotnet/LICENSE` is absent (the design and B-81 both record it; direct
`Test-Path dist/dotnet/LICENSE` is false), and installer copy semantics prove licence text does not
travel. However, neither B-81 (`meta/BACKLOG.md:1060-1071`) nor the design names a scanner failure,
customer rejection, or adoption transcript. The phrase “compliance blocker that stalls adoption
reviews” (`...consumer-value-design.md:8-11`) is therefore stronger than the recorded evidence.

**Why it matters.** The legal/distribution hygiene problem is concrete; the business-severity claim
is attribution-free. Scope should match the observed harm.

**Recommendation.** Proceed as a small distribution-hygiene fix, not as a measured adoption unblock.
Use the smallest scanner-verified artifact: one namespaced full-text file if the actual scanner
accepts it; otherwise the two-file `LICENSES/` + notice layout. Do not add per-file SPDX headers
without a concrete scanner requirement. Record the absence of a field-observed compliance failure
in the closure rather than upgrading it after the fact.

## CHECKED AND FOUND CORRECT

### 12. Canary 3 does prove narrow `applyTo` gates delivery on a fileless prompt

**Evidence.** The recorded three arms are internally relevant and include positive and negative
controls: `"**"` delivered, `"**/*.cs"` did not, and no frontmatter delivered
(`meta/BACKLOG.md:1558-1565`). The canary script describes the same narrow arm
(`.claude/scripts/canary-applyto-scope.ps1:11`).

**Why it matters.** This correctly supports “conditional delivery exists”; it simply cannot carry
the stronger behaviour or cost conclusions.

**Recommendation.** Preserve this claim and its narrow wording.

### 13. The design correctly identifies the current meter's omission and twin requirement

**Evidence.** PowerShell hard-codes the carrier at `scripts/context-footprint.ps1:246-251`; bash does
the same at `scripts/context-footprint.sh:70-72`. Both would ignore a new scoped instruction. B-68
already records the broader hard-coded-list defect and requires twin edits (`meta/BACKLOG.md:588-596`).

**Why it matters.** Shipping context invisible to the meter would be a lying gate.

**Recommendation.** Keep enumeration work if B-17 is revived, but classify and policy-gate it as in
finding 4; do not describe this narrow fix as closing all of B-68.

### 14. Two single-glob monorepo files are safer than an unverified comma expression

**Evidence.** Targeted repository search found no comma-separated `applyTo`; local Canary 3 used one
glob only. Therefore the design is right not to gamble on comma syntax
(`...consumer-value-design.md:67-74`).

**Why it matters.** Unsupported frontmatter would fail silently in precisely the way the framework
tries to prevent.

**Recommendation.** Retain separate files if B-17 is revived, but use the coverage decision in
finding 3 and canary each chosen pattern.

### 15. A plain consumer-root `LICENSE` must not be shipped

**Evidence.** The consumer's root `LICENSE` is not protected (`install.ps1:30-31`;
`install.sh:29`), and normal copy overwrites root entries (`install.ps1:92-94`;
`install.sh:88-96`). The design correctly rejects this collision (`...consumer-value-design.md:136-141`).

**Why it matters.** Overwriting the consumer's project licence would be materially worse than the
current missing third-party notice.

**Recommendation.** Preserve this prohibition. Use explicit namespaced third-party attribution and
the collision policy in finding 6.

### 16. The design correctly requires version/changelog, composition, and real red observations

**Evidence.** Shipped behaviour requires all four changelog heads and release tooling
(`CLAUDE.md:60-72`); single-source composition and twin parity are mandatory (`CLAUDE.md:31-49`).
The definition of done names all three dists, both twins, changelogs, CI legs, and red tests
(`...consumer-value-design.md:158-176`). B-72 demonstrates why a nominally green or defeatable probe
does not count (`meta/BACKLOG.md:671-704`).

**Why it matters.** Those process requirements are proportionate if an item survives the premise
and instrument findings above.

**Recommendation.** Keep them, adding the specific red/success worlds from findings 1, 4, 5, and 6.
