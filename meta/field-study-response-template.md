# Framework field study response

Return this sanitised form only. Do not include repository/client names, URLs, ticket ids, paths,
code, prompts, transcripts, command output, credentials, personal data, or business vocabulary.
Use `not captured` rather than guessing.

## Study identity and boundary

| Field | Response |
|---|---|
| Study id | |
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
| Personal/organisation host instructions present | `yes` / `no` / `unknown` |
| Raw artifacts stayed local | `yes` / `no — explain without disclosing content` |
| Both study clones had no remotes before agent use | `yes` / `no` |

## Onboarding observation

Complete this only when the participant performed first-time framework setup.

| Measure | Response |
|---|---|
| Minutes: instruction opened → installer finished | |
| Setup command printed by installer | `/bootstrap` / `/adopt` / other |
| Setup host/model | |
| Setup model constraint, or `none` | |
| Minutes: installer finished → setup command finished | |
| Minutes: setup command finished → first green `docs-sync-check` | |
| Human interventions/clarifications | |
| First blocking point, or `none` | |
| First confusing instruction, or `none` | |
| Anything manually repaired | |
| Outcome | `completed` / `partial` / `stopped` / `not applicable` |

## Module A — controlled historical-fix replay

### Fixture reachability

| Check | Response |
|---|---|
| Sanitised task shape | e.g. `boundary bug in an application service` |
| Pre-fix wrong result demonstrated | `yes` / `no` |
| Base contains no framework, or exact pre-install snapshot used | `yes` / `no` |
| Both arms use history-free snapshots with no solution-bearing commit/ref | `yes` / `no` |
| Both baseline arms green | `yes` / `no` |
| Existing test harness applicable | `yes` / `no` |
| Three convention checks frozen and independent of R3/R5 | `yes` / `no` |
| FRAMEWORK setup artifact named the task diagnosis/fix | `yes` / `no` |
| Time/cost limit | |
| Randomisation result | `FRAMEWORK first` / `BARE first` |
| Same prompt/host/model/day | `yes` / `no — explain` |
| Result validity | `valid` / `void — explain` |

### Raw arm observations

| Measure | FRAMEWORK | BARE | Delta or note |
|---|---:|---:|---|
| Task acceptability (0–2) | | | |
| R1 fabrication (0–2) | | | |
| R2 convention adherence (0–2) | | | |
| R3 test discipline (0–2) | | | |
| R4 verification evidence (0–2) | | | |
| R5 leanness (0–2) | | | |
| Rubric total (0–10) | | | |
| Wall-clock minutes | | | |
| Participant active minutes | | | |
| Human interventions after initial prompt | | | |
| Agent/API cost | | | descriptive; not a material threshold |
| Targeted verifier executed expected probe | `yes` / `no` / `inconclusive` | `yes` / `no` / `inconclusive` | |
| Small human edits required | | | describe only the technical shape |
| Timed/cost-stopped | `yes` / `no` | `yes` / `no` | |

### Interpretation

| Field | Response |
|---|---|
| Material measures won by FRAMEWORK | |
| Material measures won by BARE | |
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

Profile: <stack>; <greenfield|brownfield>; <size band>; <host/model>; framework <tag>.

Onboarding: <completed/partial/stopped/not applicable>; <total minutes or not captured>;
<interventions>; primary friction: <sanitised shape or none>.

Replay: <valid/void>; direction <benefit/harm/mixed/no detectable difference/void>;
acceptability F/B <n>/<n>; rubric F/B <n>/<n>; active minutes F/B <n>/<n>;
interventions F/B <n>/<n>; agent/API cost F/B <amount/not captured>/<amount/not captured>.

Observed mechanisms: helped <... or none>; harmed/noisy <... or none>; no visible effect or not
observable <... or none>.

Live diary: <n>/3 tasks; outcomes <accepted/small edits/not accepted/stopped counts>;
benefit <...>; harm <...>; no-effect/not-observable <...>.

Keep installed: <yes/no/unsure>. Confidence: <high/medium/low>. Limitation: <one sentence>.
Follow-up: <backlog id, protocol defect, or none>.
```
