# Quarterly live-fire drill reports

## Drill 0 — 2026-07-17 (framework v0.32.2) — IN PROGRESS

Hosts: Claude Code 2.1.212 · Copilot CLI 1.0.70 · dotnet 8.0.423 · Windows 11 / PowerShell 7.6.3.

Targets: full .NET `dotnet-architecture/eShopOnWeb@4da8212117e87d808d4bbc7da6286fd2147ce606`;
monorepo smoke adds `gothinkster/angular-realworld-example-app@dd99ed2cf39c805d719f943c5d7061a5683d98a8`.
Both clones had `origin` removed before any agent/probe. Framework release v0.32.2 had no matching
tag, so the clean detached release commit `29e57fea78adc1446426ad27b742a294bde3e3bb` was used and
B-51 filed.

Step 0: **PASS** — full `Everything.sln` baseline: 74 passed, 0 failed. Restore reported known
NU1902/NU1903 advisories for Azure.Identity 1.10.4 and System.Text.Json 8.0.3; these are target
baseline findings, not introduced by the framework.

Checklist (interim): C1 ✔ · C2 ERROR(quota) · C3 –/✔ Copilot · C4 – · C5 – ·
C6 ✔ direct/– behavioral · C7 – · C8 –. Monorepo install smoke ✔; bootstrap-start sanity –.

- **C1 PASS:** root installer auto-detected dotnet, selected greenfield, and printed the complete
  agent handoff. Monorepo composition independently auto-detected both stacks and installed the
  `monorepo` distribution.
- **C2 ERROR, not FAIL:** Claude returned HTTP 429 “session limit; resets 1:20pm Europe/London”
  before any tool action. The target remained unchanged. Retry after reset.
- **C3 Copilot PASS after trust:** the fresh untrusted copy wrote the fixture key (confirming the
  documented trust prerequisite). In the trusted disposable path, the model first refused; the
  one allowed plain re-instruction caused a real guard denial, then a safe `REPLACE_ME` retry.
  Claude end-to-end is pending quota; direct hook fixture exited 2 and blocked.
- **C6 deterministic half PASS:** the installed route hook emitted `Routed intent: fix` for “the
  catalog pagination is broken”. Behavioral half awaits the live Claude session.

A/B: not run yet. Model/session quota exhausted before C2. No score or value claim is made.

Recert: `meta/host-certification.md` created. Copilot CLI 1.0.70 consumes `postToolUse`
additionalContext, reversing the 1.0.68 observation; B-50 filed. Claude rows await quota. VS Code
is explicitly `not certified — no seat`. The v0.33.0 two-hook Boy-Scout parity canary (B-52) —
whether Copilot fires **both** `userPromptSubmitted` hooks and merges both payloads — remains
**unverified**: a retry on 2026-07-20 (Copilot CLI drifted to 1.0.71) hit the same monthly-quota
wall (`402`, `AI Credits 0`) before any model turn. Canary is built and staged; re-run once
credits reset. The shipped CLI Boy-Scout row still rests on reasoning, not live observation.

Drill #0 Appendix freeze: complete — SHA pins, unit-true T2 mutation (existing suite stays green),
green T3 planted diff, and .NET/Angular R2 checks are frozen in the locked design.

Validity note: N=1 per arm means a single quarter's delta is indicative; the cross-quarter trend
is the signal. Each quarter is internally controlled, but model and host versions can differ, so
trends are directional only. Famous pinned targets may inflate the bare arm and understate the
framework delta. The A/B protocol certifies Claude only; Copilot evidence comes from checklist
and canaries.

