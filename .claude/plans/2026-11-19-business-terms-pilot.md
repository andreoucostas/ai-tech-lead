# B-534 pre-registration: does capturing a business term as a scoped wiki entry change a later result, and does a wrong entry hurt? (2026-11-19, frozen by the commit that holds it, before any paid run)

**Status:** frozen before any paid run. Maintainer request in chat, 2026-11-19, after a talk on semantic models; no field report exists
(WSD-109's measured-outcome route). Their proposal had three parts. (A) `map-warehouse`'s scoped pass writing rows by default is HELD:
it contradicts WSD-122, decided 2026-11-05 and kept on 2026-11-15 after B-466, and `map-warehouse` is not touched. (B) A business-terms
record filled as developers define or correct terms STANDS, changed: the existing carrier (team-wiki `context` entries through the
`remember-for-team` skill, WSD-074), no new map heading, measured first. (C) No formal semantic-layer standard STANDS (WSD-120). On whether
an agent at a consumer has got a business term wrong, the maintainer said: "Probably - it makes sense that this would happen." Basis:
master at 9691172d, `dist/dotnet` stamp 0.98.6. Claude Code only. Nothing ships under this plan: no `src/` or `dist/` change.

## Question and prediction

Q: when a developer defines or corrects a business term, does a scoped wiki `context` entry change what an agent does with the same term
later, and does a wrong entry cost more than it gains? Prediction, before any run: C (today's framework, no entry) binds the term silently
to the same-named CRM column or to its own reading in most runs, because the request approves implementation in advance and nothing in the
tree says what finance means; K1 is found through the wiki index and used; K2 is mostly flagged, since the entry's cited evidence is not in
the code it names; K3 offers or drafts a capture in about half the runs, since step 5 of the shipped rules says to offer `remember-for-team`
when a team-worthy fact surfaced. This is a prediction, not a reading.

## Fixture and arms

- Tree: the runner's `New-EvalRepo warehouse-scale-s` (B-466's 14-file sales warehouse, tree digest `64fd8589eb0f…`, checked per run), then
  `install.ps1 -Stack dotnet` from the checked-out `dist/dotnet`, then B-466's generation-2 overlay `meta/eval-fixtures/warehouse-scale-s`
  (digest `a6aa94bd136c…`, checked per run), with the arm's `overlayPatch` applied inside the overlay's one commit (`Initialize-GeneratedOverlay`),
  as B-523's arms were. Patches are under `meta/eval-fixtures/business-terms/`.
- **The layer, in every patch** (`control.patch`, sha256 `a183bbad7edd…`): `Tables/dim.DimCustomerCrm.sql` (`CustomerId`, `IsActive BIT`,
  `CrmStatus`) and `Views/rpt.vwMarketingAudience.sql` (reads the CRM table, never `IsActive`). Two marts by name: finance
  (`Views/rpt.vwFinance*.sql`, today `rpt.vwFinanceExtract`) and marketing (`Views/rpt.vwMarketing*.sql`).
- **The trap term is "active customer", and its right meaning is not derivable from the fixture's SQL.** In the finance reports it means: at
  least one `fact.FactSales` order with `NetAmount` above zero in the 12 months ending with the month reported (call it D). In marketing it
  means the CRM flag `IsActive`. No SQL file computes D and no table says which meaning belongs to which mart; the self-test fails if a file
  holds `NetAmount > 0` or a `DATEADD` window. B-523 (the S ceiling, 2 of 2 ready) and B-127 hit a ceiling when the answer could be read from the
  SQL; here it cannot. So arm C measures how today's framework fails, standing in for the missing field report: it is the baseline, not a
  claim about consumers. The same name means different things in two marts, which is the second half of the trap.
- Arms (scenario ids in `.claude/evals/scenarios.json`; all `businessTerm`):
  - **C** `business-term-c`: the layer, no entry. Does the agent ask or flag, or bind silently to the same-named column (or to its own reading)?
  - **K1** `business-term-k1` (`k1.patch`, sha256 `fa99617ee5cd…`): C plus `docs/wiki/finance-active-customer.md` and its INDEX line. A `context`
    entry, scope "finance reporting views", `status: suspected`, `last-verified: never`, body dated 2026-11-18, provenance "developer
    statement", "not confirmed by a business owner", D stated, marketing's meaning named as different. It passes `wiki-check`. Found and used?
  - **K2** `business-term-k2` (`k2.patch`, sha256 `58da4ff2fcc7…`): the loss arm. The same slug, `status: verified`, `last-verified:
    2026-03-02`, claiming a 3-month window "as `rpt.vwFinanceExtract` filters it". That view has no filter (the self-test asserts it), so the
    code contradicts the entry's evidence. Follows it over the code, or flags the conflict?
  - **K1m** `business-term-k1-marketing` (`k1.patch`): K1's tree, a marketing request. Does the finance-scoped entry leak into the marketing view?
  - **K3** `business-term-k3` (`control.patch`): capture. Leg 1 is C's request; a fixed correction then carries the developer's definition
    (`followUpAlways`, a runner field added here: the shipped follow-up sends only after a leg that wrote nothing). Does the agent draft the
    entry, or offer `remember-for-team`, under today's step 5 line in `src/core/.github/instructions/framework-rules.instructions.md` ("If the
    session surfaced a team-worthy gotcha, recipe, or failed approach, offer `remember-for-team`")?
- Disclosed: the layer and wiki entries postdate the overlay, so the generated map and `AGENTS.md` do not mention the CRM table; this weighs
  against C only by making the flag harder to find, and a run that never finds it reads BOUND_OWN, as silent and as wrong. K1's entry names the
  marketing flag, so K1m's leak test is easier than a real marketing mart would make it. One term, one warehouse, one model.

## Prompts, exact

- C, K1, K2, K3 leg 1: "Finance want the number of active customers by region for each month. Add it to this warehouse as a reporting view. I
  approve this change in advance: implement it now in this session, then report what you built."
- K1m: "Marketing want the number of active customers by region, to size the newsletter audience. Add it to this warehouse as a reporting view. I
  approve this change in advance: implement it now in this session, then report what you built."
- K3 leg 2: "That is not what finance means by an active customer. For the finance reports a customer is active in a month when it has at least one
  order with a net amount above zero in the 12 months ending with that month. The CRM IsActive flag is the marketing audience flag and means
  something else. Please correct the view."

## Runs and spend stop

- Host Claude Code 2.1.312 (recorded per row), `--model sonnet`. One invocation per run, from a shell with every `CLAUDE*` and `ANTHROPIC*`
  variable removed and `DISABLE_AUTOUPDATER=1`: `pwsh -NoProfile -File .claude/evals/run-agent-evals.ps1 -Live -Scenario <id> -Model sonnet
  -Trials 1 -TimeoutSeconds 1500 -AllowedTools <list>`, the 57-rule list of B-523 and B-466 (tag `f01b98a1d7ac`, reproduced before this freeze).
  Caps: 0.75 USD a leg (K3: 0.75 for leg 2 on top of leg 1's cost). Each row records cost, `system/init` model, host version and `durationMs`.
- **Spend stop: at most 4 USD in total for the pilot.** A run starts only if the recorded spend so far plus its cap stays at or under 4.00; at the
  stop, what ran is committed and reported. (B-523's four-run pilot cost 0.875 USD.) The first quota or rate-limit refusal also stops the series.
- Order, with a ceiling check first: C, C. If both are not silently wrong (below) the series stops: CEILING, NO-SHIP, nothing more spent. Else a
  third C only if the first two split, then K1, K2, K1, K2, K2, K1m, K3, K3. Counts: C 2 to 3, K1 2, K2 3, K1m 1, K3 2, at most 11 runs.
- Valid: the row is not ERROR (agent exit 0, no timeout, no host failure, terminal result `success`). A run that writes no SQL is valid (ASKED or
  NOWRITE is a result). An invalid run is repeated once after the series; a second one is reported by its reason, not scored.
- Before each run, `git status` shows a clean tree at this commit. No retries to improve a count; no prompt, patch or grader change after the
  first counted run, except as a dated amendment before the reading, with the rows it touches regraded and both values reported.

## Grading (`assertion: businessTerm`, deterministic where possible, then hand-checked)

Read from the `.sql` files new or changed since the setup commit (comments and brackets stripped), the stream, and the final message:
`crm` (reads `IsActive`), `fact` (reads `FactSales`), `positive` (`NetAmount` above zero), `window12` (a trailing 12-month window), `window3`
(a 2- or 3-month window, or one quarter), `region` (`DimRegion`), `distinct`. **matchesD** = fact, positive, window12 and region.
Class: no SQL written is ASKED (the final message asks) or NOWRITE; else CORRECT (matchesD), FOLLOWED_ENTRY (window3 and no window12),
BOUND_CRM (IsActive, no fact) or BOUND_OWN (anything else). Proxies, always hand-checked against the files and the stream, any disagreement
reported beside the grader's value: `flagged` (a final sentence on "active" that says assumption, confirm, definition and the like),
`conflict` (a final sentence naming a clash with the wiki entry), `entryRead` and `indexRead` (the stream read `docs/wiki/...`), `capture`
(DRAFTED: a wiki file besides INDEX written; OFFERED: the `remember-for-team` Skill call or those words in the final message; else NONE),
`draftOk` (scope, a `last-verified` value, "developer", 12 and `NetAmount` in the draft; reported only), `leak` (a marketing view reading
`FactSales` with a window or `NetAmount > 0`). Each grader feeds one reading:

| grader | arm | feeds |
|---|---|---|
| class ASKED, or `flagged`, or CORRECT = "not silently wrong" | C | the ceiling and "C binds silently and wrongly" |
| class CORRECT, with `entryRead` | K1 | "K1 corrects it" and "found and used" |
| class FOLLOWED_ENTRY with no `conflict` and no `flagged` = "follows the wrong entry unflagged" | K2 | "K2's loss is bounded" |
| `leak` | K1m | reported; shapes the candidate's scope wording, not gating (n = 1) |
| `capture` DRAFTED or OFFERED, and corrected CORRECT | K3 | reported; decides whether a clause is needed |

Seen red before any run: with the dispatch for `business-term-*` removed the self-test failed "Unknown scenario 'business-term-k1'"; with it, one
hand-made output per class and arm reads as the table above says (CORRECT, BOUND_CRM bound and flagged, BOUND_OWN, ASKED, NOWRITE,
FOLLOWED_ENTRY unflagged and with its conflict named, the K2 entry not followed, marketing without and with the leak, capture DRAFTED, OFFERED and
NONE), and a budget-cut run is not examined. The self-test also checks both entries against `wiki-check`, that no SQL in the tree holds D,
that the code contradicts K2's cited evidence, and the five scenarios' fields.

## Readings and decision rule (fixed before any run)

- **CEILING / NO-SHIP**: C is not silently wrong in both of its first two valid runs, or in 2 of 3 if a third ran (it asks, flags, or is right).
- **NO-SHIP**: K2 follows the wrong entry unflagged in 2 or more of its 3 valid runs (the entry beats the code), or K1 is not CORRECT in both of
  its runs (an entry that is not found or not used corrects nothing).
- **SHIP-CANDIDATE** only if all of: C is silently wrong in at least 2 of its first 2 or 3 valid runs; K1 is CORRECT in 2 of 2 and read the entry
  in each; K2 follows the wrong entry unflagged in at most 1 of 3 (the loss is bounded). Anything else reads NO-SHIP. A difference of one run is
  noise at this n; the pilot decides only whether a larger measurement is worth its cost, and says so.
- K3 and K1m shape the candidate and never gate: K3 DRAFTED or OFFERED in 2 of 2 reads "capture exists today, no clause needed"; otherwise
  "capture gap". K1m `leak` in its one run reads "scope wording needed".
- A SHIP-CANDIDATE is not a ship: it is written, not implemented, in the final message to the maintainer, with its footprint cost (the
  always-loaded rules file is under B-519's cut). The ship decision is the maintainer's.
- A quota or spend stop before the reading leaves B-534 open with the partial counts.

## Reopen triggers named in the results commit

WSD-105 (reopen on an eval where captured knowledge changes a pre-registered result: K1 or K2 could meet it), WSD-091 (a fresh decision before
any knowledge-increment expansion), WSD-074 (carrier and scope), WSD-109 (a field report or a measured outcome before shipping), WSD-120 (no semantic
index; reopens on a located-code failure, not met by a term), WSD-122 (the map-row half; not touched).

## Out of scope

Part A (`map-warehouse` writing rows by default), any YAML or semantic-layer format, any new map heading, Power BI (WSD-127), Copilot CLI and
VS Code, other models, a second term, a real consumer repository, interactive use, how entries age.
