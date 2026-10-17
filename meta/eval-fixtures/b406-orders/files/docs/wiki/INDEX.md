# Team Wiki Index

Scoped claims that agents and people should verify against the code before relying on them. Newly
created discovery entries are drafts pending PR review; their body states that status explicitly.

| | `LEARNINGS.md` | `docs/wiki/` (here) |
|---|---|---|
| Shape | append-only chronological log + declined-recipe registry | current, scoped, individually-verifiable claims, indexed |
| Promote | — | durable entries move here via `remember-for-team` |

- [gotcha] [scheduled-jobs-not-wired](./scheduled-jobs-not-wired.md) — IScheduledJob classes and JobSchedule.Cron are defined in Orders.Application but nothing in src/ registers or runs them
