# Decision revalidation and value-evidence design — LOCKED 2026-08-29

## Trigger and objective

The maintainer clarified that historical decisions are evidence, not doctrine: when models, tools,
costs, hosts, or observed outcomes change, the framework should challenge an old proxy if doing so
is likely to add more value. Reopening a question is not authority to rewrite an inconvenient
result. The old evidence stays visible; any changed method starts prospectively with its own series.

Two current decisions were re-audited because they directly constrain the next work:

1. Maintenance model rule 2 says a review at or below the implementer's model tier did not happen.
2. WSD-053 sends the next independent participant through a bounded historical-fix comparison whose
   only valid run returned no detectable difference.

## Evidence and adversarial findings

The review ledger falsifies a categorical tier rule. Separate peer-tier sessions at v0.50.0 and
v0.58.0 found material defects; the v0.58.0 reviewer independently applied four mutations and found
two blocking Bash-only failures. B-184's later Codex review of a Codex-produced release found P0,
P1, and P2 defects. Higher-tier successes are confounded with fresh context, different hosts/tools,
independent threat models, and direct hostile execution. `release.ps1` cannot inspect tier or review
quality; it records a supplied evidence string or makes absence visible.

RERUN-02 remains a valid, narrow FS1 observation: acceptable byte-identical outputs, FRAMEWORK
10/10 versus BARE 9/10, below the frozen 2/10 threshold, with greater framework wall time and spend.
Its one-line bounded fix left fabrication, leanness, and most convention behavior little room to
vary. A1 did not require triviality, but it imposed no minimum mechanism-exposure or architectural-
decision gate. Compressing three convention checks into two points also hides which decision failed;
for feature work, the fix-specific R3 row can be inapplicable while the total still appears `/10`.

## Decision A — historic decisions are rebuttable

A dated decision remains the default while its premises hold. A material change in model capability,
host behavior, tools, cost, or evidence authorizes a premise re-audit. Reversal requires a concrete
comparison or task-shaped evidence, not the assertion that newer models are generally better.
Re-open only when the changed condition could alter the outcome and expected decision value exceeds
audit cost. Preserve the original record and result; amend or supersede it explicitly, and start a
new result series whenever the measurement contract changes.

## Decision B — independent review is evidence-bound and risk-scaled

A qualifying reviewer uses a separate session, did not participate in implementation, and begins
with the frozen contract and immutable commit range before reading the implementer's narrative. It
forms an independent
adversarial threat model and records its model/agent, environment, at least one release-specific
hostile case or applied mutation observed red, a clean rerun, and coverage gaps. Model rank alone
neither qualifies nor disqualifies the review. Prefer different model families, hosts, and toolchains
where available because they add orthogonal failure modes.

Changes capable of data loss, security bypass, or false-green release/enforcement behavior require
a second orthogonal reviewer or execution vantage. If unavailable, record the incomplete coverage
and file review debt rather than treating one correlated pass as sufficient. The release gate still
enforces only presence versus explicit absence; it cannot machine-judge this evidence quality and
must say so honestly.

This prospectively permits clean-context same-frontier review to discharge ordinary debt when the
evidence contract is met. B-189 is ordinary documentation/host exposure and can use one qualifying
review. B-188 (consumer-data preservation) and B-190 (false-green completion enforcement) retain an
orthogonal-vantage requirement.

## Decision C — FS2 convention-rich independent comparison

RERUN-02 and FS1 remain unchanged and are never aggregated with FS2. The next independent paired
comparison becomes FS2 and uses the first chronologically eligible accepted historical change in a
predeclared window whose source population and endpoints are chosen only from availability and
recency constraints, not expected framework fit. Traverse accepted mainline changes newest-to-oldest
and record sanitised exclusions. The change:

- touches 3–8 hand-authored files across at least two architectural areas;
- requires three independent non-local repository decisions, including one integration or ownership
  decision; none of their outcomes is stated in the prompt, each acceptable outcome is justified
  from pre-change evidence or a pre-existing immutable acceptance contract rather than hindsight
  from the accepted solution, and every supported alternative passes executable acceptance plus all
  applicable D1–D3 checks or an immutable pre-change contract proves there are none;
- has executable private acceptance, a green pre-change baseline that is reconfirmed after FRAMEWORK
  setup in both prepared arms, history-free snapshots, and an enforced filesystem boundary for both
  setup and task agents;
- fits a participant-set time and cost cap; and
- exposes no solution through history or framework-generated setup artifacts.

Both task arms use equal per-arm time/cost caps. Personal, memory, and organisation instructions are
identical and contain no framework-derived or answer-bearing task guidance; otherwise the control is
not BARE.

Before either arm runs, prove the complete primary oracle stack—executable acceptance plus applicable
D1–D3—passes the main valid implementation and every supported alternative, or freeze the immutable
pre-change no-alternative contract. Separately prove executable acceptance rejects a plausible
invalid/pre-change world and reject a targeted plausible violation for each decision. Run one
FRAMEWORK/BARE pair with the same current frontier exact model, exact prompt, calendar day,
host/toolchain, fresh sessions, random
arm order, and setup/task-agent filesystems that cannot address the other arm/results, accepted
source history, or the private card/oracle. Before setup, freeze the exact allowed-path set and any
generated/cache ignored exclusions; reject any other byte/name-status delta rather than repairing
the candidate into eligibility. Keep onboarding separate.
Primary outcomes are task acceptability, executable correctness, and the named three-decision vector;
any predeclared hard convention failure is material. Retain R1–R5 only as descriptive continuity
data, not a composite primary score. Do not aggregate FS1 and FS2.

Reject the candidate before task agents and choose the next chronological one if history or
setup/task filesystem isolation, allowed-path containment, baseline, supported-alternative or
decision-specific oracle reachability, or the three independent decisions cannot be demonstrated,
or setup gives away the change. `cannot examine` is unordered,
never a win or loss; void only when it makes acceptability or arm comparability unjudgeable. Stop on
the participant's privacy/time/cost cap and retain onboarding harm. After the pair, preserve the
first valid result: a hard correctness/convention difference is preliminary directional evidence;
equal valid outcomes are honestly no detectable difference, with no tuning or retry.

## Proportionality and rejected alternatives

The review change removes an unsupported rank proxy while strengthening concrete evidence and high-
risk coverage. It adds no reviewer count to ordinary work. FS2 still uses two task runs, not four;
its extra burden is task selection, one executable red/green oracle, three decision-specific red
worlds, and an isolation proof, justified by higher information gain.

Rejected: keeping tier rank as a qualification despite counterexamples; accepting any same-session
review; treating a different model name as sufficient without hostile evidence; removing orthogonal
coverage from destructive or false-green surfaces; rerunning more one-line fixes; retroactively
rescoring RERUN-02; simply increasing R2 after seeing the null; selecting a task because the framework
is expected to win; or combining FS1 and FS2 into one headline.

## Verification and RCA boundary

This is maintainer governance and study design, not shipped consumer behavior. Update root
`CLAUDE.md` and its condensed `AGENTS.md` mirror, the review-ledger/release wording, WSD/decision
index, `DEVELOPING.md` release guidance, B-42's current status, and the field-study
packet/response/rubric prospectively. No `src/`,
`dist/`, version, changelog, composition, or release change is justified.

Verify root mirror meaning, PowerShell parse/BOM, focused release/doc/backlog tests, and diff scope.
The RCA must record why scattered peer-tier counterexamples and the first valid null did not update
the governing proxies sooner, and sweep other standing decisions for the same proxy-rot class.
