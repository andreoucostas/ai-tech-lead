# B-216 — scoped solution recipes inside instance skills

> **EXECUTION AUTHORITY SUPERSEDED 2026-09-05 by WSD-074.** This document preserves the original
> problem, prior single-delivery choice, critiques and stopped calibration as historical evidence.
> Use `.claude/plans/2026-09-05-repository-knowledge-strategy.md` section 6 and the current B-216
> backlog entry to re-lock before implementation. No mirror/Bash branch, mandatory registry grammar,
> old budget, or substitute-provider efficacy contract below is current execution authority. No
> sidecar behavioral trial is claimed to have succeeded. The previous status text follows unchanged.

**Status:** PAUSED FOR B-217 — the pretrial NO-GO remains recorded, but the lifecycle below must be
re-locked around the single canonical skill tree after the mirror retirement ships.
**Filed against:** v0.81.0 (2026-09-03)
**Target:** v0.83.0 or later
**Review:** two read-only Claude CLI sessions using `claude-opus-5`, effort `xhigh`; both returned
REVISE. Their repository claims were rechecked locally before this contract was frozen.

**B-217 prerequisite amendment (2026-09-04):** v0.82.0 now owns retirement of the redundant
`.github/skills` tree and its sync/update machinery. Every later mirror propagation, mirrored
sidecar, and mirror-validation clause in this plan is superseded for execution and must be removed
in a fresh locked review before B-216 restarts. The recorded experiments and Unity problem remain
evidence; they are not rewritten as if the obsolete delivery design had run.

**Budget-instrument amendment (2026-09-04):** the first Copilot calibration attempt made no model
call because CLI 1.0.80 rejects limits below its 30-credit minimum. The user explicitly authorized
a free-tier retry at that minimum. This changes only the executable session guard: no outcome
threshold changed, no paid credits may be purchased or enabled, runs remain sequential, actual
usage is recorded after each run, and a quota refusal/exhaustion stops the experiment honestly.

**Free-tier routing amendment (2026-09-04, before any A/B trial):** Copilot Free permits only Auto
selection. A calibration exposed `claude-haiku-4.5` but the plan cannot pin it. The Free leg therefore
measures the sidecar effect only while Auto routing is observed stable: every run must emit exactly
one `session.auto_mode_resolved` event naming the calibration model. Any missing, duplicate, or
different event stops the whole leg with no replacement, retry, partial score, or recalibration.
An independent fail-closed review required the fixed counterbalanced order and exact-flag observer
calibration below; it returned REVISE until those controls were added.

**Observed outcome:** the exact-flag Copilot negative observer resolved `gpt-5-mini`, rather than
the calibration's `claude-haiku-4.5`. The contract stopped before any A/B trial, without a retry or
replacement. The sidecar premise remains unmeasured; only a newly scoped and reviewed plan may
restart it.

**Documentation-derived re-scope (2026-09-04):** GitHub's current Copilot CLI documentation states
that project skills may live under `.github/skills`, `.agents/skills`, or `.claude/skills`; a skill
may contain supplementary Markdown and other resources referenced by `SKILL.md`; invocation injects
the skill and makes the files in its directory available; and `.github/skills` has first-found
priority. The same documentation says Copilot Free permits only Auto model selection. Therefore
Claude Code supplies the controlled fixed-model efficacy comparison, while Copilot Free supplies a
treatment-only compatibility observation of the documented host contract. The latter is explicitly
an observation of the current Free-Auto experience, not a fixed-model causal estimate.

Authoritative sources:

- <https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-skills>
- <https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#skills-reference>
- <https://docs.github.com/en/copilot/how-tos/copilot-on-github/set-up-copilot/configure-access-to-ai-models>

## Observed problem and proportionality

The shipped `register-service` skill admits an equivalent existing DI pattern, then mandates
`IServiceCollection`, an `AddXxxServices` extension and MS.DI lifetime vocabulary. A reported
Unity repository instead documents registration through each project's
`IoCConfig.Configure(IUnityContainer)`, so following the concrete checklist would create an
unsupported parallel container. `add-endpoint`, `add-entity`, and `add-component` contain the same
class of repository-shape assumption; the remaining instance-shaped skills are more adaptive.

The smaller correction is to make every generic body derive before prescribing. That removes the
immediate unsafe default. The larger, user-selected mechanism earns its cost only if a scoped
project recipe materially improves the same task over that smaller control on both supported CLI
surfaces. The A/B below therefore runs before the registry/checker/workflow subsystem is built. If
it misses any threshold, B-216 stops with no v0.82.0 release and returns to design; thresholds are
not tuned after seeing the result.

## Frozen inventory and behavior

The mechanism applies to exactly eight skills:

- .NET/warehouse: `add-endpoint`, `add-entity`, `register-service`, `add-warehouse-load`.
- Angular: `add-component`, `add-service`, `add-lazy-route`, `add-signal-store`.
- Monorepo: their union.

Process and enforcement skills stay outside it. `add-entity` remains EF-specific and
`add-signal-store` Signals-specific. Existing task-defining safety rules remain unconditional;
only repository-dependent structure is derived.

Each framework `SKILL.md` remains update-owned. Its body must:

1. resolve each target project independently;
2. read the sibling `references/project-pattern.md` when present;
3. choose the longest path-boundary matching scope (`@root` is least specific);
4. otherwise inspect the nearest same-kind clean live exemplar and current Conventions;
5. stop on conflict, stale/malformed/missing evidence, or inability to examine it; and
6. ask before choosing architecture/container/framework for a genuinely greenfield surface.

The body names `references/project-pattern.md` only in inline code, never as a rendered link. A
valid sidecar and the standardized legacy in-skill exemplar line together mean migration is
incomplete and execution stops for `/rebootstrap`.

## Consumer-owned format

The reserved, unshipped path is
`.claude/skills/<slug>/references/project-pattern.md`; `/generate-copilot` recursively mirrors it
to `.github/skills/`. Each sidecar uses this grammar:

```markdown
<!-- project-pattern:v1 -->
<!-- project-pattern-skill:<slug> -->

<!-- project-pattern-record:begin -->
<!-- project-pattern-scope:<@root-or-repository-relative-directory> -->
<!-- project-pattern-evidence:<exact-repository-relative-file> -->
## Pattern for `<scope>`

### Authoritative conventions
### Procedure and touchpoints
### Constraints
### Verification
<!-- project-pattern-record:end -->
```

Records contain full recipes, not deltas. Scopes are unique after normalization and carry one or
more clean exact evidence files. Paths use forward slashes and ordinal case-sensitive segments;
reject leading/trailing slash, empty segments, drive/UNC/URL paths, globs, `.`/`..`, and repository
escape.

Lifecycle state is on-demand, not in static `CLAUDE.md` or generated `AGENTS.md`:

```text
project-pattern-registry/v1
profile <dotnet|angular|monorepo>
skill <slug> <adapted|dormant|disabled>
```

`.claude/project-patterns.registry` is ASCII/LF, ordinal-sorted, matches the `template` field in
`.claude/framework-version.json`, and enumerates only this mechanism's frozen inventory once (4
.NET, 4 Angular, or their 8-skill monorepo union; not every shipped skill).
`adapted` requires an active valid sidecar; `dormant` means the relevant surface is absent and has
no sidecar; `disabled` follows the disabled-skill tree. Unresolved evidence is never persisted as
a completed registry.

The registry, active/mirrored sidecars, and all of `.claude/disabled-skills/**` are protected from
`/adopt` inventory and bootstrap/A8 evidence mining. They cannot validate themselves and are not
added to the shipped exact-path ownership manifest.

## Lifecycle and checks

Bootstrap/rebootstrap add an adaptation pass distinct from A8. It uses only observed clean code
plus documented current conventions, creates separate records for legitimate scoped variants,
never selects by majority/default, and never canonizes Tier-1/2 debt.

Registry changes, every sidecar change, Common Tasks repinning, legacy-evidence removal, and
AGENTS/skill-mirror regeneration form one additional Phase-3 proposal. Reject changes nothing;
Edit re-enters full validation before any write. Rebootstrap removes legacy evidence only when the
same accepted proposal contains its verified replacement. Installers retain WSD-033 legacy-exemplar
carry-forward unchanged. Update/disable/reenable reconciliation also carries the exact reserved
sidecar bytes forward and derives the final active GitHub mirror from that preserved Claude-side
source; these dynamic consumer files never enter the static ownership manifest.

`template-checks` gains `-RequireProjectPatternRegistry` / `--require-project-pattern-registry`.
Bootstrap and rebootstrap call strict mode directly after applying the grouped proposal, then run
ordinary `docs-sync-check`; doctor and CI stay ordinary callers. Ordinary mode permits a completely
markerless legacy repo, but a registry or reserved sidecar activates full v1 validation.

Exit `3` means invalid/missing/duplicate content; exit `2` means a present resource could not be
examined and prints ASCII `CANT-VERIFY`; exit `0` is clean. WSD-063 is re-audited because this makes
exit 2 consumer-reachable: `docs-sync-check` keeps its public 0/1 status but preserves the child
diagnostic and ends with a `CANT-VERIFY` summary rather than calling it an artifact defect.

No registry bytes enter static context. Any changed frontmatter or rules-carrier prose must be
shorter. Composed `static.claude` totals may not exceed the current 39,936 / 38,459 / 47,452
characters; no ceiling increase or waiver is allowed.

## Re-scoped pre-registered go/no-go

Use a fresh temporary sanitized mixed-scope repository for every run. Control A has the neutral
derive-first body, Common Tasks and live evidence but no sidecar. Treatment B differs only by the
explicit scoped sidecar. Prompts are byte-identical within each comparison.

**Claude efficacy leg.** Run `n=3` per arm in the fixed sequence `ABBAAB`, using `sonnet`/high and
recording its returned canonical model. Do not replace or reorder a run. Treatment must read the
exact sidecar 3/3, produce at least 2/3 correct scoped outcomes, improve correct completion over
control by at least 1/3, and create zero forbidden parallel-container artifacts. Cap the leg at USD
15. One malformed/stale treatment must stop with the correct missing-versus-cannot-examine
diagnosis.

**Copilot documented-host leg.** First use the non-model CLI skill-list/info surface to confirm the
fixture discovers the project skill from `.github/skills` and exposes its directory. Then run three
fresh treatment-only fixtures on Copilot Free with `--model auto`, no effort flag, and the minimum
accepted `--max-ai-credits 30` soft session limit. Record every resolved model and actual usage, but
do not select, discard, replace, or stratify runs by model. All three must read the exact sidecar;
at least 2/3 must produce the correct scoped Unity outcome; none may create an MS.DI/parallel-
container artifact. One malformed/stale treatment must stop with the correct diagnosis. This leg
tests current documented-host compatibility, not treatment effect. Use only the existing free-tier
quota; do not purchase or enable paid credits. Quota refusal/exhaustion or unknown usage is NO-GO.

Calibrate each read observer under its exact trial flags: Claude stream-JSON read events and Copilot
JSONL tool events, with a fixture-only `preToolUse` logger as the deterministic fallback. A
sentinel-read positive and a no-read negative must both register correctly. A missing or ambiguous
event is `CANT-VERIFY`, not evidence of no read; if neither Copilot instrument distinguishes the
controls, stop.

## Verification and delivery

Extend existing suites rather than adding a harness. Use one table-driven `ScriptTwinParity` case
for the registry mutations, extend existing installer/convergence fixtures, and cover grouped
Accept/Reject/Edit plus `/adopt`/A8 exclusions. Three-run before/after median growth is capped at
30 seconds for the meta suite and 5 seconds for dist gates; exceedance requires fixture/process
consolidation, not a ceiling change.

After a passing A/B, run one contrary-pattern case per skill on Claude and Copilot, separating
routing, skill read, sidecar read, and artifact correctness. Use old-red/candidate-green pairs for
Unity registration and endpoint layering; label the other six preventive unless an old-tree failure
is actually observed. The Unity fixture is synthetic and is not a reproduction of the confidential
reporter repository. Live evals remain advisory under WSD-016.

Complete compose/validate for all dists, installer greenfield/update tests for both twins, all
hook/meta suites, footprint twins, eval self-test, and an immutable-range independent review with a
release-specific hostile mutation observed red and clean. Record field report #6, B-216, WSD-072,
the decisions index, LEARNINGS and RCA; add all four v0.82.0 changelog heads; release with review
evidence, then commit and push `master`.

## Honest limits

The checker proves format, path safety, preservation and consistency, not semantic freshness or
model obedience. Rebootstrap is the refresh point; no content hash is introduced. Point-in-time
Claude/Copilot results do not certify future host versions. Only Unity registration is reported
consumer harm; the other seven skills are preventive coverage explicitly selected by the user.
