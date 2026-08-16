# Backlog heading audit

Summary: 42 GENUINELY OPEN / 16 STALE HEADING / 13 UNCLEAR (71 claimed-open headings audited).

## STALE HEADING (b)

| ID | Concrete evidence |
|---|---|
| B-61 | `meta/BACKLOG.md:5804-5807` records it shipped in v0.41.0; `src/core/tests/hooks/ScriptTwinParity.Tests.ps1:27-90` runs the shipped-script twin comparisons. |
| B-62 | `meta/BACKLOG.md:5699-5713` records v0.44.0 check 8; `scripts/validate-dist.ps1` and `scripts/validate-dist.sh` contain the `hook-registration` check. |
| B-78 | `meta/BACKLOG.md:776-778` says DONE in v0.51.0; `src/core/tests/hooks/WarehouseMapCheck.Tests.ps1:3-12` exercises both `warehouse-map-check` twins. |
| B-80 | `meta/BACKLOG.md:5736-5760` is its Done record; `.claude/hooks/tests/ReleaseStagingGuard.Tests.ps1:3,121-135` names and tests the gitlink refusal and non-bypassable guard. |
| B-103 | `meta/BACKLOG.md:2330-2356` records the independent review performed on 2026-08-05 and its nine dispositioned findings. |
| B-104 | `CHANGELOG.md:369-376` records the v0.46.0 route-prompt fix; `src/core/tests/hooks/RoutePrompt.Tests.ps1:97-112` covers Store-stub fallback and working-`python` JSON output. |
| B-105 | `CHANGELOG.md:377-381` records the v0.46.0 doctor fix; `src/core/tests/hooks/FrameworkDoctor.Tests.ps1:327-371` covers working-interpreter, no-parser, and name-only-stub worlds. |
| B-107 | `CHANGELOG.md:387` explicitly records the contradictory comments fixed; current comments at `src/core/.claude/hooks/audit-trail.sh:73` and `src/core/.claude/hooks/guard.sh:13` describe working-parser capability. |
| B-110 | `meta/BACKLOG.md:2554-2583` records the completed limit decision and red test; `scripts/context-footprint.ps1:325` and `scripts/context-footprint.sh:112` implement hard-failing limits. |
| B-113 | `CHANGELOG.md:248-257` records the observed eight-job CI run and structural fixture fix; `meta/review-ledger.md:17` records the same red/green evidence. |
| B-115 | `meta/BACKLOG.md:2963-2964` says DONE in v0.51.0; `install.ps1:33-34,71` and `install.sh:41-43,76` implement the shared-signal pure-SQL fallback. |
| B-116 | `meta/BACKLOG.md:2995-3007` records DONE with no code after the write-side baseline routed correctly; `meta/eval-results.md:639-648,662` records the skill channel and zero `reachedAddEntity` results. |
| B-118 | `meta/BACKLOG.md:3039-3040` says DONE in v0.51.0; `CHANGELOG.md:100` records that instance recipes now check for an existing owner (for example `src/stacks/dotnet/files/.claude/skills/add-entity/SKILL.md:20`). |
| B-119 | `meta/eval-results.md:833-861` is the completed post-change arm: two clean mixed runs, `regionOnFact` 0/2, and an explicit closure statement. |
| B-120 | `meta/BACKLOG.md:3103-3104` says DONE in v0.51.0; `.claude/evals/run-agent-evals.ps1:1621-1624,2667-2676` emits `n/a` and tests engaged/no-output transcripts. |
| B-121 | `meta/review-ledger.md:19` explicitly marks the v0.51.0 review discharged and records the independent gates, red test, rebuild, and suites. |

## UNCLEAR (c)

| ID | Ambiguity / check needed |
|---|---|
| B-50 | `src/core/docs/enforcement-surfaces.md:44` now records CLI 1.0.70 consuming the canary, but `:53` still calls `postToolUse` unreliable. Confirm whether the requested isolated rerun and every matrix/comment update were completed. |
| B-64 | Many diagnostics now have planted-defect tests, but the entry requires one for *each* gate and diagnostic. Build a current inventory and map every item to an executable mutation before closing. |
| B-65 | The entry records the discovery premise as superseded by measurement, but also leaves Angular behavioral runs pending. Run/check those trials and record the final reachability decision. |
| B-66 | Delivery shipped in v0.40.0, but the entry explicitly leaves the prescriptive forms-guidance half open. Resolve the transcript/evidence gate before closing. |
| B-70 | CI-leg coverage was improved and the body says the per-leg job check narrows the exposure, but the requested Definition-of-done requirement is absent from `CLAUDE.md`/`DEVELOPING.md`. Decide whether the shipped mechanics supersede that prose deliverable. |
| B-72 | Some grader defects were fixed, while the no-guidance form-control scenario remained saturated and the provider-vs-interface/field-report reproduction work is not clearly complete. Re-run the named scenario against the current grader and check every `Do` arm. |
| B-96 | v0.49.0 implemented the schema/edge/rules design (`CHANGELOG.md:181-234`), but `CHANGELOG.md:243-246` says both pre-registered behavioral arms were still owed. Verify whether those exact live arms later ran and met the entry's ship gates. |
| B-97 | The unprotected carrier and update contract shipped (`CHANGELOG.md:398-448`), but `CHANGELOG.md:411-413` explicitly says B-97 does not fully close for un-migrated Claude consumers. Resolve that remaining delivery/precedence question. |
| B-98 | Steps 1 and 3 and a v0.51.0 no-router decision are recorded, but `meta/BACKLOG.md:1733-1750` adds later non-reach evidence and another check before step-2 design. Decide whether that is residual B-98 work or a successor item. |
| B-101 | Timing signals and major speedups shipped, but `meta/BACKLOG.md:2210-2214` explicitly leaves the PowerShell hotspot and structural coverage/cost decision open. Determine whether later gate-budget work supersedes the remaining scope. |
| B-102 | Five hooks shipped the resolver, but its own correction (`meta/BACKLOG.md:2251-2257`) says route-prompt, doctor, and tests were omitted and split into later items. Confirm whether closure via B-104/B-105/B-106 is intended to close the original umbrella. |
| B-112 | The scenario sweep is done (`meta/BACKLOG.md:2718-2735`), but the later `Do` at `:2782` still requires fixes/rechecks and a recorded reachability/stability result. Check those four named follow-ups. |
| B-117 | One skill pair is explicitly closed (`meta/BACKLOG.md:3013-3014`), but the same note says the wider roster class remains evidence-gated under B-98. Close only after deciding whether the wider class belongs here or has been formally transferred. |

Initially considered done, then downgraded under the conservative rule: B-50, B-66, B-96, B-97, B-98, B-101, B-102, B-112, B-117.

GENUINELY OPEN ids: B-42, B-43, B-49, B-52, B-55, B-44, B-46, B-48, B-59, B-60, B-58, B-68, B-76, B-77, B-79, B-75, B-83, B-84, B-85, B-87, B-81, B-82, B-91, B-94, B-99, B-100, B-111, B-123, B-129, B-132, B-133, B-134, B-130, B-131, B-136, B-138, B-140, B-15, B-17, B-18, B-20, B-26.
