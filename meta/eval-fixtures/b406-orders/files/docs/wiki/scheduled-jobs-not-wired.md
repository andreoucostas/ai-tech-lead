---
name: scheduled-jobs-not-wired
description: IScheduledJob classes and JobSchedule.Cron are defined in Orders.Application but nothing in src/ registers or runs them
type: gotcha
scope: src/Orders.Application/Jobs/**
status: unverified
last-verified: never
---
`NightlyReconciliationJob` and `PurgeStaleCartsJob` implement `IScheduledJob` with empty bodies. `JobSchedule.Cron` maps them to cron strings. A search of `src/` found no reference to `IScheduledJob` or `JobSchedule` outside the `Jobs/` folder, and `Program.cs` registers no scheduler or job.
**Confidence:** observed (absence in `src/` at HEAD `06a55f3`)
**Provenance:** requested `/bootstrap` discovery, 2026-10-17
**Evidence:** `src/Orders.Application/Jobs/JobSchedule.cs`, `src/Orders.Api/Program.cs`
**Counterevidence / exceptions:** a scheduler could live outside this repo and load the types by reflection; `LockName` suggests a distributed-lock consumer that is not present here.
**Dependencies / unresolved:** who runs the cron table, if anyone. Next useful source: deployment or host configuration outside this repo.
**Verify by:** `grep -rn "IScheduledJob\|JobSchedule" src` and expect only hits under `src/Orders.Application/Jobs`.
**Semantic refresh:** trigger: any new reference to these types; result: grep over `src/` on 2026-10-17 only, no runtime check, so the date stays `never`.
**Draft status:** draft pending PR review; not team-approved policy
