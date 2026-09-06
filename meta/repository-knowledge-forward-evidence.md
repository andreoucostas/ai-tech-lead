# Repository-knowledge forward evidence

Date: 2026-09-05

This is a narrow authoring-time observation of the PK-1 discovery workflow. It is not a target
Copilot CLI or VS Code invocation, an enterprise-repository sample, or evidence that a particular
consumer host will discover or apply the workflow. The temporary fixture and observed output were
not added as product fixtures and were not used as a substitute for B-224/B-225 host and value
observations.

Historical `.forward-eval/...` paths below identify their original workspace-relative locations.
After independent inspection, the complete untracked tree was moved outside the repository to
`%TEMP%\ai-tech-lead-forward-eval-adf0b0e-20260906-c9fa636e3ce74aa3a4965160948c0d87` and remains
excluded from the candidate and release. The B-227 report SHA-256 was rechecked after that move as
`80068E4E32F2D302165A44421A9D0C99E5E80CAC87742AE745E29DE590E2AE7E`.

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

## PK-2 capture observations

These were fresh-context `gpt-5.6-luna` authoring evaluations, not installed Copilot/VS Code runs.
Each evaluator received only the actual `remember-for-team` skill, monorepo bootstrap Phase 3a-bis,
an isolated raw fixture, and the same realistic request to preserve useful facts and repeatable
operations. Expected claims were withheld. The retained fixtures are under `.forward-eval/` for
independent inspection; they are not product fixtures or efficacy evidence.

The first run (`pk2-capture`, input commit `2d979b012751507b9b406490e6ff634fbe7309d8`)
created a grounded package-promotion skill/reference without changing tracked owner content. The
independent root reviewer read every raw file and output and confirmed the existing owner wiki and
skill hashes remained `3FD17A0304FE842758F13114695D126D921EEF27BE53BA0D4098B0238453B645`
and `C58AD59B02DF48F3D598ED07A69E61116A3B8A83C37588E076402AB96086AB4D`.
However, the SKILL did not link its reference and kept the explicit refresh trigger/result only in
the report. Its unmodified skill/reference/report hashes are respectively
`D9339BA0596DBF11D0689B12FBBDB45BF18AD25B00D64D1EE5663118FBE51CCF`,
`533A1FE113A95F2B3065F147DB38CD25847D349C6735A06645E9E8245D841690`, and
`1B76CC14696A68B66E37152AF2ADFE0AD18A8EABE98FA9DDE4E2EEC2807CFC3D`.

Two follow-ups expose instruction sensitivity rather than being silently discarded. Run 2
(`pk2-capture-2`, input commit `df298356fe1c0940eb0015a0c3c13c9ac95db34c`) drafted wiki facts and
an operation skill but again omitted the focused reference; its report also disclosed that an
over-tight evaluator write boundary prevented the required INDEX update. Run 3 (`pk2-capture-3`,
the same raw commit after the “both files” clarification) created two linked skill/reference pairs
with durable source rechecks and no tracked owner edits. It defensibly treated the lease wrapper as
a multi-step operation rather than a wiki fact. Its “success-only acknowledgement” wording is
broader than the exact source fact—`$LASTEXITCODE -eq 0` after an arbitrary ScriptBlock—and remains
a bounded interpretation defect despite the external/runtime caveats.

The final run (`pk2-capture-4`, input commit
`f53c3564b22d534e15a6c09ca15547032c6b2c79`) added an independent storage-topology predicate and
exercised both destinations: three wiki drafts plus one skill/reference pair. Only
`docs/wiki/INDEX.md` changed among tracked files; owner files were byte-unchanged relative to that
fixture's committed baseline. Direct PS7 execution of the promotion, lease, and topology fixture
predicates returned exit 0. The output hash is
`52762C9D9EFB2B545A52D06FB63B8A72597CB47FB2B392FFA27818738059135E`; generated INDEX, lease wiki,
promotion wiki, topology wiki, skill, and reference hashes are respectively
`223E18D99B0E6218B3352747D593A2D539A3DCD9165C7A6A1F3BFC83DA6B9DE5`,
`A35138BBF7CF4AEBDFF51548194704A9AC4F77EDB6B90E234EC9A561CE7BCF5A`,
`321E12C1B524A6C91E7E28254E0B9F9EE6BF81A6433D059369F6D669B3E2F176`,
`EC2C6F341350D6A8D07B62E6E166032E250AF3B3133C6E04E06CA1031E6B13E0`,
`4B5345C1EC2C6537271376A8D613DADE8A632FB0668F5BEF9E704E4C6029D5C8`, and
`3A3DC38C5B41144A158455B421A39A1342D8101B6A02B2309525810BD99E6CD8`.

The root reviewer independently ran the generated wiki/INDEX through the current wiki check under
native PS7 and PS5.1; both exited 0 with the existing advisory body-injection warning for the
storage draft's “overrides” vocabulary, so this was not warning-free. The reviewer also observed
the topology predicate pass, then fail with `Replica must not accept writes` after setting
`replicaAcceptsWrites` true, then pass again after restoration. That establishes the declared-source
oracle's red and green worlds, not a deployed topology.

Run 4 still duplicated package promotion across a wiki recipe and skill, and its SKILL did not
actually link the created reference although the report claimed that it did. The creation
instruction was subsequently narrowed to require an explicit relative Markdown link and forbid a
wiki duplicate of the same operation. At the reviewer's direction, no further run was selected to
turn this into a favourable-only sample; a fifth run was interrupted and is not evidence. The
generic skill-creator `quick_validate.py` rejected the required product lifecycle key
`origin: discovered`; that frontmatter conflict is a validator limitation, not a reason to make the
draft invisible to the framework's deletion/decline lifecycle. None of these runs exercised a
confirmed semantic refresh of existing owner content, budget exhaustion, or target-host discovery
and application; those remain separate obligations.

## B-216 operation-authority observation

A single fresh collaboration evaluator received only the revised `register-service` skill (SHA-256
`691B60E696A5804034953A4BF9421531630248770775085E00E73DB222623DBD`), the raw maintainer Unity
composition-root fixture (SHA-256
`CF8F4053344B4C7E44A200CC45C861309452CB3C6C4E4FEC5AF477C6CEC660EF`), and a neutral request to
register `IEnemySpawner` backed by `WaveEnemySpawner`. It did not receive the expected result. The
retained unmodified report is `.forward-eval/r1-unity-register-service/evaluator-output.md`
(SHA-256 `8FB3C1F02856E87F242DC836FE0494BF7BC7BD5A9F318AC4AD6045617E6E446A`).

The report conditionally proposed the fixture's evidenced `RegisterType` mechanism and
`ContainerControlledLifetimeManager`, introduced no MS.DI mechanism, and withheld an edit pending
ownership, real composition-root, type/dependency, lifetime, consumption, and verification
evidence. The delivery lead and independent root reviewer read the supplied inputs and report. This
is a narrow authoring-agent observation: it proves no source edit, service integration, target
Copilot/VS Code behavior, or representative efficacy. It did not exercise conflicting or unreadable
project-pattern references, alternate Angular/.NET mechanisms, or lifecycle promotion.

An earlier retained attempt at `.forward-eval/r1-unity-20260905/evaluator-output.md` was blocked
before reading its inputs. Its setup also paired the Angular `add-service` instruction with a Unity
game fixture rather than the accepted .NET `register-service` case, so it supplies no semantic
evidence. Its claims about provider or billing activity remain evaluator self-report rather than an
independently observed absence.

The root reviewer also ran the generic skill-creator frontmatter check against all eight operation
skills and observed 7/8 valid before cleanup. Angular `add-service` failed because its pre-existing
description contained the literal navigation form `CLAUDE.md > Conventions`; the body was not the
failure. Rewording that description as “the CLAUDE.md conventions” preserved its meaning, and the
same narrow check then passed. This is frontmatter portability evidence, not behavioral proof.

## B-227 financial-verdict observation

One fresh-context `gpt-5.6-luna` collaboration evaluator received exactly the immutable .NET
`security-auditor` instruction, raw `FinancialCases.cs`, and neutral `owner-brief.md` from commit
`16eb5c08f9d848eb24e3ffc6c035834b254bba12`. It was asked: “Review every method in
FinancialCases.cs for financial correctness and security against the owner brief. Report
evidence-backed findings and unresolved limits; do not modify the code.” It was explicitly denied
the executable oracle, plan, backlog, history, working-tree variants, and prior outputs. Those read
limits were instructions to the collaboration agent, not an independently sandbox-enforced access
boundary. The run occurred in the framework authoring environment, not Copilot CLI, VS Code, SQL,
or an installed consumer.

The retained raw fixture, owner brief, and unmodified report hashes are respectively
`7BD8813958022897A20D435B7E8DDBB83BD5E781E4EF2AC50EB7968CE0490C1E`,
`272831076C3E8DBC8378CCBD8BC8E9656CEE8A805BA8C508DA77E5C69FBEC0E3`, and
`80068E4E32F2D302165A44421A9D0C99E5E80CAC87742AE745E29DE590E2AE7E`.
The output's original location was `.forward-eval/r4-financial-review/evaluator-output.md`; it is
not a shipped fixture. Root inspected those exact local bytes before the tree was archived at the
location recorded above, and the hashes above are the durable repository record.

The evaluator reported four method-specific findings supported by the supplied source and brief:
the barrier-coordinated lost update returns 90 rather than 80; per-term rounding returns 0 rather
than 0.008 within the declared tolerance; processing both repeated identifiers produces two effects
within the bounded invocation; and selecting all rows totals 150 rather than the current-only 100.
It did not impose `decimal`, a row lock, or a specific transaction mechanism. It retained the lack
of database, deployment, persistence, broader policy, and behavior beyond the supplied inputs as
uncertainty. Root independently read the frozen inputs and output and compared the four findings
with the separately executed valid/invalid oracle. This is one bounded semantic observation, not
financial-safety certification, a claim about other mechanisms, or product/host efficacy.
