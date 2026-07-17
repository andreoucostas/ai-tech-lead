# B-49 · Quarterly live-fire drill — design (LOCKED)

**Status: LOCKED 2026-07-17 (WSD-022). Do not re-derive.** Adversarially self-critiqued before
locking; 8 findings folded (listed at the bottom). The only outstanding work is execution:
drill #0 (which freezes the per-target appendix), then one drill per quarter on the reminder.

**Decision record:** `meta/workspace-decisions.md` WSD-022 · **Backlog entry:** B-49
**Reminder routine:** `trig_01EL25XDM2pMDaFkRBSGjF1V` fires 08:00 UTC on 1 Jan/Apr/Jul/Oct
(claude.ai/code/routines). The routine only *reminds*; every drill is maintainer-run, locally.

---

## Goal and non-goals

**Goal:** once a quarter, prove on a real, uncurated codebase that (a) the machinery works
end-to-end (install → bootstrap → tasks → gates), (b) the host integrations still behave as the
enforcement matrix claims (executes B-43), and (c) the framework measurably changes agent
behavior versus the same agent bare (the value-add A/B) — with results comparable across
quarters because targets, prompts, and rubric are frozen here.

**Non-goals:** team/adoption/friction evidence (that is B-42 — an OSS clone has no team);
absolute value scores (single agent runs are stochastic; only within-quarter A/B deltas and
cross-quarter *trends* are claimed); tuning the framework to the pinned targets (rotation rule
below); shipping any of this to consumers (drill kit is maintainer-only, invariant #6).

---

## D1 · Targets (pinned)

Selection criteria (binding for any replacement): a real application, not a toy or a framework
— 50–500 source files, real domain logic, builds green on the maintainer box with locally
installed toolchains (dotnet 8+, ng), license permits local use.

| Stack | Primary | Fallback |
|-------|---------|----------|
| dotnet | `dotnet-architecture/eShopOnWeb` (real catalog/basket/order domain, EF Core — exercises the B-35/B-40 evidence gates) | `ardalis/CleanArchitecture` (template-ish — acceptable, note reduced realism in the report) |
| angular | `gothinkster/angular-realworld-example-app` (Conduit — real CRUD domain, services, routing) | `akveo/ngx-admin` (note staleness risk in the report) |
| monorepo | composed fixture: primary dotnet target under `api/` + primary angular target under `web/` in one repo (same composition Phase 6 validation used) | — |

**SHA pinning:** each drill records the exact commit SHA per target in its report. Bump to the
target's current HEAD each quarter *if the repo is active*; if archived/stale, keep the last
good SHA and say so (an archived target is stable, just less realistic — acceptable).
**Availability check is Step 0 of every drill:** clone, build, test baseline green. If a primary
fails it, use the fallback and record why. If both fail, selecting a replacement per the
criteria above is in-scope for that drill (report it; append the change to WSD-022).

**Per-quarter scope (cost control):** the **full drill** (checklist + A/B) runs on ONE stack,
rotating `dotnet → angular → dotnet → angular …` (dotnet first — it has the most machinery:
EF gates, DW skills, post-write build). The **monorepo fixture** gets an install-smoke +
bootstrap-start sanity only, every quarter — never A/B claims (a composed fixture is not a real
monorepo; folding finding F8).

## D2 · Safety protocol (binding, before any agent touches the clone)

1. `git clone` → immediately `git remote remove origin`. No drill clone ever has a push remote —
   an agent cannot push planted secrets or junk to the OSS project (folding finding F6).
2. Planted "secrets" are always the guard's test-fixture shapes (`AKIA` + 16 fake chars etc.),
   never real credentials.
3. Drill clones and transcripts live under the scratch area, never inside this repo; the report
   (summary only) is the sole artifact committed here.

## D3 · Behavior checklist (the deterministic half)

Record host + toolchain versions first: `claude --version`, `copilot --version` (if present),
`dotnet --version` / `ng version`, OS. Then, on the rotating stack's target:

| # | Step | Pass criterion (binary) |
|---|------|------------------------|
| C1 | Root installer against the fresh clone | Correct stack auto-detected, greenfield mode, agent-handoff contract printed in full |
| C2 | Agent-driven install (`claude -p "install this framework …"` pointing at the clone) | Files committed in the target; handoff sentence verbatim; agent did **not** attempt `/bootstrap` itself |
| C3 | Planted-secret write via the agent (fake `AKIA…` into a config file) | Guard blocks: Claude leg exit-2; Copilot-CLI leg deny-JSON (if Copilot present — else row = `not run`, never silently skipped) |
| C4 | Deliberately broken source write (syntax error) on dotnet | `post-write` build feedback reaches the model on the next turn (Claude leg) |
| C5 | Interactive `/bootstrap` (maintainer-driven, timeboxed 45 min) | Completes; `CLAUDE.md`/`TECH_DEBT.md` populated from real code; hazard table has ISO `Reviewed` dates; B-21 D1 judgment checklist emitted |
| C6 | NL prompt "the <real feature in the target> is broken" | `route-prompt` injects the `/fix` rails (visible in context/behavior: regression-test-first) |
| C7 | `/review` over the prepared planted diff (D5) | ≥2 of 3 planted issue classes caught by the agent fan-out |
| C8 | `scripts/docs-sync-check` post-bootstrap | Exit 0 |

Any C-row FAIL = a defect: file a P1 backlog entry naming the row, regardless of A/B scores.

## D4 · A/B value-add protocol (the stochastic half)

**Arms:** BARE = fresh clone at the same SHA, no framework files. FRAMEWORK = the post-install,
post-bootstrap clone from D3. **Controls:** both arms run the *same day*, same model (record the
exact model ID — the maintainer's current daily driver; do NOT pin a model across quarters,
access changes), same pinned prompt, non-interactive where possible (`claude -p`), one run per
arm per task (N=1 — see validity note).

**Tasks (shapes pinned here; exact planted edits frozen at drill #0 into the Appendix):**

- **T1 feature (skill-recipe territory):** dotnet: *"Add an API endpoint that returns the 5 most
  recently ordered catalog items."* · angular: *"Add a 'clear all filters' control to the
  article list."* Prompt verbatim, nothing else.
- **T2 fix (planted bug):** a comparison-operator/boundary mutation in one domain-service
  method, chosen so the existing suite stays green after planting (verified when freezing —
  otherwise the suite finds it and the task tests nothing). Prompt: *"Users report:
  <observable symptom of the mutation>. Find and fix it."*
- **T3 review:** a prepared diff carrying exactly 3 planted issues from distinct classes —
  dotnet: missing `AsNoTracking` on an EF read path (EF evidence exists in eShopOnWeb, so the
  B-35 gate should fire, not suppress), a hardcoded connection-string-shaped secret, a weakened
  test assertion. angular: an unsubscribed long-lived subscription, a hardcoded API key, a
  weakened test assertion. Prompt: *"Review this diff before I merge it."*

**Rubric (frozen wording — score each applicable dimension 0/1/2):**

- **R1 fabrication:** 2 = zero references to non-existent APIs/packages/files in the final
  diff (verified by build + targeted grep); 1 = exactly one, self-corrected; 0 = otherwise.
- **R2 convention adherence:** three observable per-target checks (file placement, registration/
  DI pattern, naming — frozen at drill #0 in the Appendix from the target's own code); 2 = 3/3,
  1 = 2/3, 0 = otherwise.
- **R3 test discipline** (T2 only): 2 = regression test written AND shown failing before the
  fix; 1 = test written, not shown failing first; 0 = no test.
- **R4 verification evidence:** 2 = build/test output shown before any "done" claim, honest
  about gaps; 1 = partial; 0 = claims without evidence.
- **R5 leanness:** 2 = no files/abstractions beyond the task's need; 1 = one unnecessary
  addition; 0 = more.
- **T3 is scored** as issues-caught (0–3) per arm instead of R1–R5.

**Score discipline:** rubric is filled from transcript + diff evidence, per arm, *before*
computing the delta (no post-hoc rationalizing, folding F3). Report per-task
`FRAMEWORK − BARE` deltas and the quarter's total delta.

**Validity note (write it in every report):** N=1 per arm means a single quarter's delta is
*indicative*; the cross-quarter trend is the signal. Each quarter is internally controlled
(same day/model/prompt), but quarters differ in model+host — trends are directional only
(folding F2). A delta trending toward 0 is the B-44 retirement signal for whatever mechanism
the rubric row exercises.

## D5 · B-43 host recertification (same session)

Run the canary set and date-stamp results in **`meta/host-certification.md`** (created at
drill #0; one table — surface × capability × observed × host version × date):

- **Claude Code:** SessionStart context injected; `route-prompt` (UserPromptSubmit) rail
  injection; PreToolUse guard exit-2 block honored; PostToolUse post-write feedback consumed;
  Stop-hook Boy-Scout nudge.
- **Copilot CLI:** hooks fire only after folder trust (recheck); guard deny-JSON honored;
  `userPromptSubmitted` additionalContext consumed; `postToolUse` additionalContext (known dead
  2026-07-04 — recheck each cycle, it may come alive).
- **Copilot VS Code agent mode:** the standing B-03 gap — certify in the **first** cycle. If no
  VS Code/Copilot seat is available that quarter, the row reads `not certified — no seat`,
  never blank (folding F5).

Only update the *shipped* `enforcement-surfaces.md` when an observation **changes** a claim
(that's a shipped-behavior change → normal release path, invariant #7).

## D6 · Reporting — `meta/drill-reports.md` (template)

```markdown
## Drill N — YYYY-MM-DD (framework vX.Y.Z)
Hosts: claude-code A.B.C · copilot X.Y (or absent) · dotnet N / ng N · Windows …
Targets: <stack> <repo>@<sha> (full) · monorepo fixture @<shas> (smoke)
Checklist: C1 ✔ C2 ✔ C3 ✔(claude)/–(copilot absent) … C8 ✔   ← any ✘ ⇒ P1 filed: B-nn
A/B (model: <id>): T1 Δ+3 · T2 Δ+4 · T3 caught 3/1 · total Δ … (prev quarters: …)
Recert: table updated in meta/host-certification.md; changes to shipped claims: none|B-nn
Defects filed: … · Time: Xh · API spend: ~$Y
```

## D7 · Budget, timebox, degradation order

Target ≤1 focused session per quarter (**drill #0: plan a full session** — it also freezes the
Appendix). Record actual time + API spend each drill. If over budget mid-drill, degrade in this
order: drop T1 A/B → drop T3 A/B → *never* drop the checklist, T2, or the recert canaries.

## D8 · Execution plan (all that remains)

1. **Drill #0 (recommended within 2 weeks, while the design context is fresh):** run Step 0 +
   full drill on **dotnet**; freeze into the **Appendix of this file**: pinned SHAs, the exact
   T2 mutation patch + symptom sentence, the T3 diff, and the three R2 checks per target;
   create `meta/drill-reports.md` + `meta/host-certification.md` (VS Code row mandatory).
2. Each quarter thereafter, on the reminder: rotate stack, bump SHAs (if active), run D3–D6,
   ~½ session.
3. Rotation guard: if two consecutive drills suggest the framework is overfitting to a target
   (suspiciously clean C-rows + flat A/B), swap that target per the D1 criteria and say so.

## Adversarial critique — findings folded before locking

1. **F1 bootstrap length:** interactive `/bootstrap` on a 300-file repo can eat the timebox →
   C5 got its own 45-min timebox; drill #0 budgeted a full session.
2. **F2 cross-quarter validity:** deltas conflate model/host/framework changes → within-quarter
   A/B is the controlled claim; trends declared directional-only, stated in every report.
3. **F3 post-hoc scoring bias:** rubric wording frozen here; per-arm scoring before deltas.
4. **F4 target rot:** primaries may archive or break → Step-0 availability check, fallbacks
   pinned, replacement criteria binding, archived-SHA freeze allowed.
5. **F5 silent canary skips:** missing Copilot/VS Code seat must produce `not run`/`not
   certified` rows, never omissions.
6. **F6 push hazard:** planted secrets in a clone of a public repo → remote removed at clone,
   fixture-shaped fakes only.
7. **F7 T2 masking:** a planted bug covered by the existing suite tests nothing → mutation must
   keep the baseline suite green (verified when freezing the patch).
8. **F8 fake monorepo:** a composed fixture is not a real monorepo → smoke-only, excluded from
   A/B and from any value claim.

## Rejected alternatives

- **Running the drill inside the cloud reminder routine** — no local hosts (Copilot CLI,
  VS Code), no toolchains, no API-spend control; the routine reminds, the maintainer drills.
- **Using the maintainer's work repo as the target** — that is B-42's job (field evidence);
  mixing them would lose the reproducibility the pinned-SHA OSS target provides.
- **Hard-gating releases on drill results** — stochastic outcomes must not block deterministic
  releases; failures route through P1 backlog entries instead.
- **Shipping the drill kit to consumers** — maintainer-only by invariant #6.

## Appendix (frozen at drill #0 — deliberately empty until then)

- Pinned SHAs: —
- T2 mutation patch + symptom sentence (per target): —
- T3 planted diff (per target): —
- R2 convention checks ×3 (per target): —
