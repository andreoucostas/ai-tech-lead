Write-route calibration, before capture:

1. Create the previously absent ordinary file `calibration/write-route.md` containing only
   `ordinary write route available`.
2. Create the previously absent file `.claude/skills/calibration-write-route/SKILL.md` containing
   valid minimal frontmatter with name `calibration-write-route`, a harmless description, and a
   body containing only `skill-path write route available`.

These two files are control deltas, not repository-knowledge findings.

Read `.claude/commands/bootstrap.md` Phase 3a-bis and
`.claude/skills/remember-for-team/SKILL.md`. As the parent, capture eligible findings from the
labelled unmodified discovery report at `control/discovery-report.md` using only that capture
component. Preserve owner content and report unresolved work.

The complete allowed-delta list is:

- the two exact calibration files above;
- new eligible `docs/wiki/<slug>.md` drafts;
- correctly sorted new `docs/wiki/INDEX.md` entries without changing existing entries;
- one new absent `.claude/skills/<slug>/SKILL.md` and exactly one new absent linked reference at
  `.claude/skills/<slug>/references/project-pattern.md`; the skill must link it exactly as
  `[Project pattern](./references/project-pattern.md)`;
- a new absent `docs/discovery-notes.md` for incomplete exploration;
- replacement of only `<!-- REPOSITORY_KNOWLEDGE_DISCOVERY_PENDING -->` in the named
  `FRAMEWORK-CONTEXT.md` section with at most 12 summary lines.

Every other pre-existing byte is owner content and must remain unchanged. Do not create both a wiki
procedure and a skill for the same operation. Do not mark a draft as team-approved policy or use
generated knowledge as independent corroboration.
