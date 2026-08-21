# Handoff — live-eval session (cheap-model arm)

**Goal:** run the live agent evals on a cheaper model to unblock work that has stalled on spend,
and to prove the harness runs end to end. Remote access enabled so the run survives without a
babysitter.

## Start here

```
pwsh -NoProfile -WorkingDirectory 'C:\TEMP\AIdrivenDev\ai-tech-lead' `
  -File '.claude\evals\run-agent-evals.ps1' -Model haiku ...
```

`-Model` defaults to `sonnet` and is passed through as `claude -p … --model <id>` together with
`--max-budget-usd <budget>`. No code change is needed to switch tiers.

**Pin the working directory explicitly.** A `cd` in one shell tool persists across both shell tools
in a session; an unpinned run resolved every repo-relative path from the wrong directory and got far
enough to delete 516 `dist/` files before refusing. `-WorkingDirectory` prevents it.

## What this arm can and cannot answer

**Can:** that the harness runs end to end; that graders fire and results land; a robustness floor
(guidance that survives a weaker model does not depend on the model being clever); negative controls
and contrast-shaped comparisons.

**Cannot:** anything that transfers to what a consumer on a stronger tier experiences. Record the
**model tier alongside the host** on every result. B-134's Phase 0 pre-registers per-host reporting
so a dead surface is not averaged away; averaging across tiers would defeat the same safeguard.

## Standing constraints — read before designing anything

- `meta/decisions-index.md` **first**. A buried constraint has already cost one wasted design cycle.
- **WSD-042** — the harness is locked to Claude Code, the one host that loads skills. Record
  "carrier unreachable" as a **distinct outcome**, never as a failure.
- **B-140** — codex is explicitly *out of scope* for B-129. Do not use it to "speed up" this work.
- Pre-register the threshold **before** the run. A number that cannot produce a decision is B-112's
  trap, and it is why B-160 puts the free static audit ahead of any live spend.

## Failure modes already paid for

- **Account monthly spend cap** voided B-129 twice (2026-08-15 and again 2026-08-16). It is
  **billing-cycle gated, not a rolling window** — a short-timer retry will not clear it. If trials
  come back ERROR, check whether the cap is the cause before diagnosing anything else.
- **A per-trial harness budget cap is a distinct failure** from the account cap. Check each trial's
  cost and turn count; do not lump all ERROR trials into one bucket.
- **Do not run anything else in PowerShell while a codex round is live** — codex has
  `Stop-Process`-ed PIDs it never started, killing an unrelated CI watch and its own session.

## Backlog items this unblocks

- **B-129** — warehouse reporting consumption layer. Harness built and self-tested green; only the
  live run is outstanding.
- **B-160** — skill routing measured four times, all warehouse-shaped, ~12 skills never measured and
  no threshold defined. Do the **free static vocabulary audit first** and validate it against the
  four known results; spend live budget only on skills the audit cannot call.
- **B-159** — whether the always-loaded rails trigger the `/review` fan-out unprompted. One scenario:
  a diff-shaped prompt that never says "review", scored on a typed tool event, not transcript prose.
- **B-134 Phase 0** — the product-intent work. Ten scenario classes, three independent runs per host,
  pre-registered stop rules. **A cheap-model arm cannot close this**, but it can de-risk the harness
  before the real spend.
