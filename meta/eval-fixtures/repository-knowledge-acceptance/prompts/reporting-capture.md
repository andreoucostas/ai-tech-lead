You are the coordinator for this capture request and you complete it in this one session. Read
shared A8 in `.claude/commands/bootstrap.md`, its Phase 3a-bis, and
`.claude/skills/remember-for-team/SKILL.md`.

Run the discovery yourself: use shared A8's sequential fallback rather than dispatching a
separate Agent tool or sub-worker, and do not start full bootstrap. Execute only these two
components against this repository. This is a routine capture request; no separate approval step
is required.

1. Shared A8's bounded discovery (read-only): inventory the repository, then semantically
   inspect the first-party report sources under `reporting/` and the sources they depend on,
   within the normal read and dependency-hop limits. Return the current shared-A8 report shape,
   and report total content reads and the eligible first-party subset.
2. Parent Phase 3a-bis capture of the discovery findings that qualify, in this same session,
   using only that capture component.

The complete allowed-delta list is:

- new eligible `docs/wiki/<slug>.md` scoped-fact drafts built from `docs/wiki/_template.md`;
- correctly sorted new `docs/wiki/INDEX.md` entries, without changing any existing entry.

Every other pre-existing byte is owner content and must remain unchanged, including
`docs/wiki/release-ownership.md` and `docs/wiki/INDEX.md`'s existing line. Report any incomplete
exploration in the returned shared-A8 report's unresolved/continuation sections, not as a
separate discovery-notes file. Do not create both a wiki procedure and a project skill for the
same fact, do not mark any draft as team-approved policy, and do not use generated or test
material as independent corroboration. Record unresolved or unavailable evidence as unresolved,
not as an empty or zero result. Do not execute any SQL.

A separate calibration step performs one ordinary allowed write; it is not part of this
capture's allowed deltas and does not affect the owner-preservation checks above.
