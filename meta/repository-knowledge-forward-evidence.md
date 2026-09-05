# Repository-knowledge forward evidence

Date: 2026-09-05

This is a narrow authoring-time observation of the PK-1 discovery workflow. It is not a target
Copilot CLI or VS Code invocation, an enterprise-repository sample, or evidence that a particular
consumer host will discover or apply the workflow. The temporary fixture and observed output were
not added as product fixtures and were not used as a substitute for B-224/B-225 host and value
observations.

## Frozen inputs

- Workflow: `src/stacks/monorepo/files/.claude/agents/bootstrap-pass.md` at SHA-256
  `6B26BACE5098D8B40CD6802A6F852F415D0C516C650E4862C47749B9097D217A`.
- Raw mixed-domain fixture: isolated nested Git commit
  `04f325db880b121be1d2898484bff383d110f61a`, containing 15 tracked C#, TypeScript,
  PowerShell, test, project, documentation, and manifest files plus one ignored generated-source
  decoy (SHA-256 `3DF2764CEE70B06352661F58C03057BE374F4B5888903BF71DEF1F1BD2F57351`).
- Request: “Before another engineer changes order intake and prepares a release, discover the
  repository knowledge that would materially reduce mistakes across this codebase. Cover facts and
  operations, state conflicts and uncertainty, and give a bounded coverage account.” SHA-256
  `C50924EE5BC754AF8D19CE1C9FA79936B20329AB6DB601CF0EA2E1054AD15B80`.
- Evaluator: a fresh-context `gpt-5.6-luna` worker given only the request, raw fixture path, and the
  workflow entrypoint. Its write scope was the fixture output. The agent runner still operated from
  the framework authoring workspace, so isolation from repository-level instructions was not
  equivalent to an installed consumer or target-host run.
- Unmodified observed output SHA-256:
  `B009943DE219E3441BB57832854890B6589611C04837E8ED42DA29A1D7A0D9F6`.

The expected findings were withheld from the evaluator. The delivery lead and the independent root
reviewer then read the raw files and the output rather than relying on the evaluator's self-report.
The nested fixture Git object and output were ephemeral and were removed after that inspection.
They are not retained or replayable from this repository: these hashes identify the bytes the
delivery lead observed, and the root reviewer independently checked the semantics before removal
but could not re-hash them afterward. The workflow hash is the original PK-1 input; later PK-2 edits
legitimately change the working-tree hash and do not retroactively alter this observation.

## Observed result

Six finding sections were grounded in the raw source: the quiet retry-helper boundary, tombstone
timestamp-equality suppression, distinct admin and self-service intake gates, the cross-component
release sequence, an unresolved external partner-contract dependency, and the rule that the ignored
generated decoy was not authoritative. The report also named actual reads, bounded dependency hops,
counterevidence, unresolved sources, and continuation work.

The output was not wholly correct: its heading claimed seven findings although it contained six.
The original output was not edited to conceal that defect. The run also did not exercise exhaustion
of the 40-file budget. Several proposed “meaningful rechecks” required restored projects or new tests
even where rereading the exact source predicate would be the smaller semantic recheck; PK-2 must
distinguish a minimal source recheck from runtime or business-behaviour proof. A redundant numeric
finding count should be omitted rather than supported by a new counting mechanism.
