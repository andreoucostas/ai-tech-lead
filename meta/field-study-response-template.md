# Framework field study response

Return this sanitised form only. Do not include repository/client names, URLs, ticket ids, paths,
code, prompts, transcripts, command output, credentials, personal data, or business vocabulary.
Use `not captured` rather than guessing.

## Study identity and boundary

| Field | Response |
|---|---|
| Study id | |
| Protocol series | `FS2` |
| Date | |
| Evidence source | `maintainer` / `independent` |
| Participant framework familiarity before study | `none` / `some use` / `regular use` |
| Stack | `.NET` / `Angular` / `monorepo` |
| Repository state | `greenfield` / `brownfield` |
| Approximate source-size band | `<50` / `50–199` / `200–499` / `500+` files |
| Existing applicable test harness | `yes` / `no` |
| Framework tag | |
| Agent host and version | |
| Exact model id | |
| OS/toolchain summary | |
| Personal/memory/organisation instructions present | `yes` / `no` |
| Both arms identical and free of framework-derived/task-answer guidance | `yes required` / `no — pair void` |
| Raw artifacts stayed local | `yes` / `no — explain without disclosing content` |
| Both study roots had no remotes before agent use | `yes` / `no` |

## Onboarding observation

Complete this only when the participant performed first-time framework setup.

| Measure | Response |
|---|---|
| Minutes: instruction opened → installer finished | |
| Setup command printed by installer | `/bootstrap` / `/adopt` / other |
| Setup host/model | |
| Setup model constraint, or `none` | |
| Setup agent used the same restricted, canary-proven scope | `yes required` / `no — pair void` |
| Post-setup byte/name-status diff, including task-relevant ignored paths, stayed inside frozen allowed paths/exclusions | `yes required` / `no — pair void`; unexpected count |
| Minutes: installer finished → setup command finished | |
| Minutes: setup command finished → first green `docs-sync-check` | |
| Human interventions/clarifications | |
| First blocking point, or `none` | |
| First confusing instruction, or `none` | |
| Anything manually repaired | |
| Outcome | `completed` / `partial` / `stopped` / `not applicable` |

## Module A — controlled convention-rich historical-change replay

### Fixture reachability

| Check | Response |
|---|---|
| Sanitised task shape | e.g. `cross-layer endpoint with ownership conventions` |
| Candidate window and newest-to-oldest position frozen first | `yes` / `no` |
| Earlier candidates excluded | `<count>; sanitised criterion codes` |
| Observable pre-change state demonstrated | `yes` / `no` |
| Base contains no framework, or exact pre-install snapshot used | `yes` / `no` |
| Both arms use history-free snapshots with no solution-bearing commit/ref | `yes` / `no` |
| Both prepared baselines green immediately before A5 (after FRAMEWORK setup) | `yes` / `no` |
| Hand-authored files / architectural areas | `<3–8>` / `<at least 2>` |
| Executable private acceptance applicable | `yes` / `no` |
| Executable acceptance passed a valid world and failed an invalid/pre-change world | `yes` / `no` |
| Three independent decisions frozen | `yes` / `no` |
| Decision vector (sanitised pre-change basis, acceptable outcomes; hard/soft) | `D1 ...; D2 ...; D3 ...` |
| Every supported alternative passed executable acceptance + applicable D1–D3, or pre-change contract proved none | `yes` / `no` |
| Oracle accepted a valid world and rejected targeted D1, D2, and D3 violations | `yes` / `no — identify inert decision` |
| Enforced scope/canaries excluded other arm, source history, card/oracle, coordinator store, prior result | `yes` / `no` |
| FRAMEWORK setup artifact gave away the requested change | `yes — candidate ineligible; no task pair` / `no` |
| Equal per-arm time/cost limits; setup/selection total cap | |
| Randomisation result | `FRAMEWORK first` / `BARE first` |
| Same current-frontier exact model/prompt/host/toolchain/day; fresh sessions | `yes required` / `no — pair void` |
| Result validity | `valid` / `void — explain`; any required-control `no` is `void` |

### Raw arm observations

| Measure | FRAMEWORK | BARE | Delta or note |
|---|---:|---:|---|
| Task acceptability (0–2) | | | |
| Executable acceptance | `pass` / `fail` / `cannot examine` | | |
| Decision 1 | `pass` / `fail` / `cannot examine` | | |
| Decision 2 | `pass` / `fail` / `cannot examine` | | |
| Decision 3 | `pass` / `fail` / `cannot examine` | | |
| Any predeclared hard decision failed | `yes` / `no` / `cannot examine` | | |
| R1 fabrication (descriptive 0–2) | | | |
| R2 convention adherence (descriptive 0–2) | | | compressed continuity measure only |
| R3 test discipline (descriptive 0–2 / not applicable) | | | |
| R4 verification evidence (descriptive 0–2) | | | |
| R5 leanness (descriptive 0–2) | | | |
| Wall-clock minutes | | | |
| Participant active minutes | | | |
| Human interventions after initial prompt | | | |
| Agent/API cost | | | descriptive; not a material threshold |
| Targeted verifier executed expected probe | `yes` / `no` / `inconclusive` | `yes` / `no` / `inconclusive` | |
| Small human edits required | | | describe only the technical shape |
| Timed/cost-stopped | `yes` / `no` | `yes` / `no` | |

`cannot examine` is unordered: it never counts as a win or loss against `pass` or `fail`. If it
makes acceptability or arm comparability unjudgeable, mark the pair `void`; otherwise retain it as a
limitation and classify only the observable measures.

### Interpretation

| Field | Response |
|---|---|
| Material quality/burden measures won by FRAMEWORK | |
| Material quality/burden measures won by BARE | |
| Direction | `benefit` / `harm` / `mixed` / `no detectable difference` / `void` |
| Framework surfaces demonstrably reached | |
| Helpful mechanism, or `none observed` | |
| Harmful/noisy mechanism, or `none observed` | |
| What could not be observed | |
| Confidence | `high` / `medium` / `low` |
| Main limitation | |

## Module B — consecutive live-task diary

Use the next three eligible tasks. `Surface effect` may contain multiple entries such as
`fix rail: helped; post-write: not observable`.

| | Task 1 | Task 2 | Task 3 |
|---|---|---|---|
| Sanitised task shape | | | |
| Outcome | `accepted` / `small edits` / `not accepted` / `stopped` | | |
| Participant active minutes | | | |
| Human interventions | | | |
| Review/rework after completion claim | | | |
| Surface effect | | | |
| Helpful catch | | | |
| Harm/noise/ignored guidance | | | |
| Confidence and why | | | |

| Diary boundary | Response |
|---|---|
| Eligible tasks skipped for safety/sensitivity | |
| Diary completion | `3/3` / `2/3` / `1/3` / `not run` |
| Overall observed benefit | |
| Overall observed harm | |
| Overall no-effect/not-observable surfaces | |

## Participant wrap-up

| Question | Response |
|---|---|
| Would you keep the framework installed for the next task? | `yes` / `no` / `unsure` |
| Most valuable observed behavior | |
| Largest friction cost | |
| One thing to remove or simplify | |
| One thing missing | |
| Anything else, including positive feedback | |

## Sanitised summary for the maintainer ledger

Copy only this block into `meta/field-study-results.md` after checking it contains no identifying or
repository-specific material.

```markdown
## <study-id> — <date> — <maintainer|independent>

Profile: FS2; <stack>; <greenfield|brownfield>; <size band>; <host/model>; framework <tag>.

Onboarding: <completed/partial/stopped/not applicable>; <total minutes or not captured>;
<interventions>; primary friction: <sanitised shape or none>.

Replay: <valid/void>; direction <benefit/harm/mixed/no detectable difference/void>;
acceptability F/B <n>/<n>; executable acceptance F/B <result>/<result>; convention vector F/B
<D1,D2,D3>/<D1,D2,D3>; active minutes F/B <n>/<n>; interventions F/B <n>/<n>; agent/API cost F/B
<amount/not captured>/<amount/not captured>. R1–R5 descriptive only; no FS2 composite total.

Observed mechanisms: helped <... or none>; harmed/noisy <... or none>; no visible effect or not
observable <... or none>.

Live diary: <n>/3 tasks; outcomes <accepted/small edits/not accepted/stopped counts>;
benefit <...>; harm <...>; no-effect/not-observable <...>.

Keep installed: <yes/no/unsure>. Confidence: <high/medium/low>. Limitation: <one sentence>.
Follow-up: <backlog id, protocol defect, or none>.
```
