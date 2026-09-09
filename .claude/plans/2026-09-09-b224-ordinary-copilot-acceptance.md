# B-224 ordinary Copilot CLI acceptance

> **Post-execution status (2026-09-09):** executed, then narrowed by independent review. The
> retained AFTER wiki fails the installed checker with 37 errors, so the unchanged fixture is
> retired as a conforming acceptance instrument. This notice does not amend the frozen contract;
> see `meta/b224-copilot-ordinary-acceptance.md` for the adjudication and guidance.

**Frozen:** 2026-09-09 against product source `425b53b2478690c3993a260aef2d3b5f343bf23d` and
released distribution v0.86.0. **Series:** B224-CLI-01. **Status:** authorized execution.

## Question and claim boundary

Can the installed GitHub Copilot CLI route, on one ordinary feature request that names no framework
workflow, skill, knowledge entry, implementation rule, path, test, or grader, discover the applicable
scoped project knowledge, read its body and decisive source, apply it correctly, and run repository-
evidenced verification?

This is a delivery/application observation for B-224. It is not B-225's paired outcome comparison,
not evidence of productivity, not an enterprise-repository sample, and not VS Code evidence. One
synthetic pass or miss cannot establish general efficacy or causation.

## Proportionality and alternatives

The concrete harm is the 2026-09-07 Copilot task's observed zero direct reads of
`FRAMEWORK-CONTEXT.md`, `docs/wiki/INDEX.md`, or an applicable project skill despite a large custom-
instruction payload. Another broad discovery implementation or a full RK1 comparison would be
disproportionate before the delivery route is shown to work at all. The smaller test is one current-
framework task plus host-observer controls. A static carrier inspection cannot answer model use;
another Claude-only run cannot answer Copilot delivery.

## Frozen route, privacy, and caps

- Synthetic repository only; no private consumer code, production data, remotes, or external
  participant. Provider processing is limited to the committed synthetic fixture materialized in a
  disposable root.
- GitHub Copilot CLI 1.0.83, model route `gpt-5.4`, medium reasoning, prompt mode, fresh UUID sessions,
  memory off, remote control/export off, built-in MCP disabled, and auto-update off.
- Main task: at most 100 AI credits and 45 elapsed minutes across its plan/implementation turns.
- Controls: at most 30 AI credits each for BEFORE-context, AFTER-context, and positive-read sessions.
  CLI 1.0.83 rejected the initially frozen 5-credit value before model execution because its host
  minimum is 30; the revised ceiling is a host constraint, not permission for extra turns. Each
  control remains exactly one request.
  Stop on a route/model mismatch, timeout, cap refusal, authentication failure, unavailable typed
  stream, or a result that cannot be separated from observer failure. Never retry a semantic miss.
- Built-in path checks remain enabled. All tools may be approved inside the disposable root, while
  `git push`, `gh`, remote export and built-in MCP are disabled. The fixture has no secrets or remotes.
  Any inability to enforce that boundary is recorded before task execution.

## Fixture and task

Materialize `meta/eval-fixtures/b224-ordinary-copilot/inputs/base` into two neutral one-commit Git
roots. Install `dist/dotnet`, then overlay the fixture's already-bootstrapped consumer-owned files.
Remove Copilot hooks before the neutral commit so task-time knowledge access cannot depend on hook
output. The AFTER root has 31 indexed entries, above session-start's 30-entry inline threshold; the
BEFORE root retains the installed empty index. Both roots otherwise have the same application,
framework version and always-loaded carriers.

The AFTER root contains a verified retail state-transition claim, an opposing admin-scoped claim,
an unresolved premium-retail draft, a stale legacy claim whose evidence is missing, and unrelated
entries. Decisive application evidence remains in `RetailTransitionPolicy`; generated knowledge is
navigation, not independent truth.

Exact first prompt:

> Add `TryCancel` support for retail shipments. Return whether cancellation was accepted and update
> the shipment state when it is. Keep the change focused and verify it.

If the first turn stops after the required plan, the only continuation is:

> Go ahead with that plan.

Do not add hints after a semantic miss. If the first turn already implements, do not send the
continuation.

## Frozen measures and controls

1. **Context cost:** send the identical no-tool prompt to BEFORE and AFTER roots. Record typed model
   route, tool count, usage, and any host-reported custom-instruction/context attribution. Static
   byte/token estimates are secondary. Desired state is equal or lower always-loaded context for
   AFTER; absent attribution is CANNOT-EXAMINE, not equality.
2. **Observer negative:** the two context prompts must complete with no file-read tool event; final
   text alone must not count as access.
3. **Observer positive:** in AFTER, explicitly request the sentinel from
   `calibration/read-control.md`. The typed stream must contain a successful content read of that
   exact path and return the sentinel. Otherwise task access observations are CANNOT-EXAMINE.
4. **Entry discovery:** main-task typed events contain a successful read/search revealing
   `docs/wiki/INDEX.md`; automatic instruction payload is recorded separately.
5. **Body/reference reading:** typed events contain a successful content read of
   `docs/wiki/retail-state-transitions.md` and the decisive `src/Dispatch/RetailTransitionPolicy.cs`.
   Reads of admin, premium or stale entries are recorded but do not substitute.
6. **Scoped application:** independent hidden tests pass: queued attempts 0/1 cancel and mutate;
   queued attempt 2, reserved, draft and already-cancelled shipments reject without mutation. The
   existing release behavior remains green. Static review rejects use of the admin policy or an
   inlined conflicting threshold.
7. **Task verification:** typed events show the repository-evidenced `dotnet run --project
   tests/Dispatch.Tests/Dispatch.Tests.csproj` (or a stronger applicable repository command) and a
   successful result. Final prose without execution is not verification.
8. **Scope:** inspect actual bytes/diff. Framework and knowledge files, unrelated source, and owner
   artifacts remain unchanged. A plan-only terminal result is incomplete, not a product failure.

Before the actor sees the task, the hidden grader must be observed red on the baseline, green on the
frozen valid patch, red for the off-by-one boundary mutation, and red for the wrong-scope mutation.
Each run must report the nonzero expected case count. Hash the portable fixture, prompts, actor
streams, usage, final diff and grader outputs. Bulky streams and dynamic roots remain outside Git.

## Result and review handoff

Record the adjudicated result in `meta/b224-copilot-ordinary-acceptance.md`, update B-224 and append
the meta learning/RCA. No product source, distribution, changelog or version changes follow unless
the evidence identifies a missing or contradictory product instruction and a separately reviewed
proportionate correction is authorized.

After root adjudication, give an Astra xhigh reviewer a blind-first packet containing this frozen
contract, raw-result hashes and dispositions, then the recent v0.84-v0.86 evidence for B-222/B-223,
B-216/B-226, B-230 and B-231. Ask it to distinguish product gaps, model-compliance misses,
instrument/route failures and unobserved claims; challenge the measurements; and recommend proceed,
narrow, repair, measure, retire, or wait. Recheck its factual claims against repository evidence
before recording guidance.
