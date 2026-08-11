# B-135 — minimise operational secret-incident metadata in committed security records

**Status:** REVISED AFTER FRESH-CONTEXT CODEX REVIEW — awaiting Claude Opus review

**Scope:** shipped security-review workflow, auditor output contract, security register, and the
same-class committed audit-log surface across dotnet, angular, and monorepo distributions

**Effort:** M under Maintenance model rules 1 and 6

## Evidence and boundary

A field report states that a newly committed findings table reproduced an active service-account
name, a concrete secret-bearing file path, host information, and the fact that the credential was
echoed into an AI transcript. The password itself was absent, but the row broadened incident
metadata to every clone and pull-request reader. The affected consumer repository is unavailable,
so these incident facts remain attributed to the report.

The framework-side enabling contract is observed locally. `src/core/SECURITY_FINDINGS.md` requires
`File:line` and free-form `Description`; dotnet and monorepo `/security-review` automatically append
critical/high findings; auditor and parent output request concrete locations; and no surface defines
a minimisation boundary. Angular does not append despite frontmatter claiming that it does. Update
mode preserves the consumer's existing register, so a new template alone cannot migrate it.

This item changes model-visible and committed records. It does not rotate credentials, delete or
access-review transcripts, remove secret files, rewrite Git history, or replace the organisation's
restricted incident process.

## Alternatives and decision

1. **Warning only:** add “do not record secrets” while retaining the schema and append behavior.
   Rejected: it misses non-secret operational metadata and still solicits the sensitive location.
2. **Minimised active-incident stub:** keep a Git row with broad area, severity, dates, owner, and an
   opaque or placeholder reference. Rejected after fresh-context review: the stub still discloses
   incident existence and correlation metadata, while a placeholder has no coordination value.
3. **No committed security findings:** move every finding external. Rejected as the universal
   default: it removes useful local remediation tracking for ordinary safe code findings and assumes
   an incident platform every consumer may not have.
4. **Hybrid — selected:** keep minimised Git rows for ordinary repository-safe code findings. For
   active or suspected credential exposure, produce a minimised restricted-handling response and
   make **no automatic Git mutation**. After containment, a human may explicitly authorise a minimal
   historical row with an organisation-approved opaque reference. No model infers containment,
   invents a reference, or creates a placeholder row.

Both chat output and Git are potentially durable; neither is a restricted incident system. A safe
repository-relative `file:line` remains allowed for an ordinary vulnerability only when the locator
and what it points to are safe for every repository reader. Raw auditor tables, tool output, or
conversation narrative are never pasted into the register.

## Protected-detail principle

For credential incidents, minimise by category and disclosure effect rather than relying only on a
token denylist. Do not echo credential material or derivatives; operational/service identities;
infrastructure, tenant, environment, customer, host, IP, user, or home identifiers; vault/key/secret
store names; concrete filesystem or secret locators; transcript/session/log/CI artifacts; disclosure
channel narrative; or unapproved correlation references and URLs. Dates, severity, owner/team, and
affected area are also omitted when they create linkage risk. The response states only the minimum
action class and that restricted human handling is required.

## Candidate implementation

1. Rewrite canonical `src/core/SECURITY_FINDINGS.md`: use `Affected area (redacted when sensitive)`
   and `Repository-safe summary`; make owner role/team and internal reference optional; permit an
   opaque reference only for human-authorised contained-incident history; apply minimisation to
   active, accepted-risk, resolved, and archive tables. Make “do not delete rows” subordinate to an
   explicit human-led security redaction/containment exception. State that Git is not the active
   credential-incident system of record.
2. Update all three stack whole-file Claude commands and agents. Dotnet and monorepo append only
   ordinary repository-safe critical/high findings. Credential incidents never mutate Git
   automatically. Angular keeps no-auto-append behavior; correct its false frontmatter instead of
   adding persistence during a confidentiality fix. A legacy header makes append fail closed and
   emits a non-sensitive human migration instruction.
3. Keep detailed behavior canonical in the Claude definitions. Update the core GitHub agent wrapper
   and every stack snippet, including dotnet's append-specific `findings-note`; update the core
   GitHub prompt plus three summaries with only the compact last-mile no-echo rule. Do not reauthor a
   competing output schema in wrappers.
4. Define two response shapes: ordinary code findings may identify a safe repository-relative
   location; credential incidents say only that restricted handling is required and name the minimum
   immediate action class. The read-only auditor must withhold protected detail, not hand it to a
   parent assumed to be non-durable.
5. Migration is human-only. Never ask an agent to ingest and restate legacy active, accepted-risk,
   resolved, or `docs/security-archive.md` rows. A human with incident authority reviews/redacts or
   removes unsafe metadata under the containment exception, then adopts the new header. This is
   surfaced by the installed command because update preserves `SECURITY_FINDINGS.md` and excludes
   consumer `CHANGELOG.md`.
6. Before design lock, disposition `.claude/ai-audit.log`. Its hook twins currently fall back to the
   original path when relative normalisation fails, another automatic committed operational-metadata
   surface. Include the smallest containment correction in B-135 or file a linked P1; do not close
   the same-class sweep as “none”.
7. Ship synthetic fixtures only. Segment fabricated account, host, path, transcript, and derivative
   sentinels so docs/tests never resemble live credentials. Cover benign repository locations and
   application component names to constrain over-redaction.
8. Compose all distributions, prove source-to-dist wording, run `validate-dist` x3 and install
   smokes, update version/changelogs/learnings, and close with the required backlog RCA plus the
   same-class durable-free-text sweep.

## Verification contract

Freeze separate reachable worlds:

- **Dotnet credential case:** unfixed behavior reproduces at least one seeded operational sentinel
  in a candidate register row. Fixed behavior makes no register mutation and returns a minimised
  restricted-handling response containing none of the sentinels.
- **Ordinary code case:** fixed behavior appends a minimised row retaining a safe repository-relative
  injection location.
- **Angular:** the red world is the false append claim and unsafe output contract, not a persisted
  row. Fixed behavior retains no append and gains safe output/instructions.
- **Monorepo/Copilot:** current live evals cannot establish these behaviors: the harness installs
  only dotnet/angular and invokes Claude CLI. Treat rendered/mirror checks as structural delivery
  evidence unless a supported runtime exercise is first added.
- **Legacy register:** both appending stacks refuse mutation and provide the human migration route.
- **Historical tables:** accepted/resolved/archive handling cannot reintroduce seeded detail.

A deterministic sentinel grader proves only exact seeded-token handling, not paraphrase safety or
general DLP. Parse the intended row/state, normalise safe encodings/case, plant unsafe rows, include
benign near-matches, and label live model runs probabilistic. Red-test every deterministic checker
with an unsafe planted row before calling it green.

## Proportionality

The reported harm is a concrete disclosure expansion caused by a durable framework-shaped record.
No automatic active-incident Git row plus a bounded schema/output/migration correction removes most
of it. A general DLP classifier, mandatory incident-product integration, repository-history rewrite,
or automatic transcript remediation would be larger, less portable, and unable to guarantee the
operational response.

## Fresh-context adversarial review (Codex, 2026-08-11)

**Verdict: reject selected approach, not premise.** The reviewer identified the omitted hybrid,
proved update preserves the legacy register, showed the original all-stack red baseline was
unreachable, found Angular's false append claim and no-append behavior, bounded the Claude-only eval
harness, and found `.claude/ai-audit.log` as a concrete same-class surface. These repository claims
were independently checked and accepted. The revision adopts no active-incident Git mutation,
human-only migration, stack-specific evidence, safe chat output, explicit source ownership, and the
audit-log pre-lock disposition. This review does **not** satisfy the Claude Opus gate.

## Opus review request

Ask Claude Opus to attack the hybrid premise, protected-detail principle, immediate-response versus
Git boundary, ordinary-location exception, human-only migration, Angular no-append choice, source
ownership, audit-log disposition, oracle reachability, and proportionality. Opus may require no Git
security persistence at all. This candidate authorises no implementation until Opus corrections are
resolved and the decision is locked in `meta/workspace-decisions.md`.
