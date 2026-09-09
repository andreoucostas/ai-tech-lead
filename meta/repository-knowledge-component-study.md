# Repository-knowledge component study — offline execution packet

**Series:** RK1. **Status:** execution authorized on 2026-09-09; preparation stopped at the required
native sandbox policy before any study setup, task arm or Copilot model calibration. The
[revision 1 campaign](../.claude/plans/2026-09-09-rk1-execution.md) supplies prospective arm,
selection, host and budget choices. The original offline protocol below is preserved; its earlier
absence-of-authority wording is superseded only by that named campaign. See the checkpoint below.
**Question:** on the same repository tasks, does the enhanced bounded discovery/capture/use
increment improve outcomes over the current released framework on the same observed Copilot host
and exact model?

**2026-09-06 prospective relationship:** the separately authorized
[CP1 campaign](../.claude/plans/2026-09-06-cp1-abp-copilot-campaign.md) compares native Copilot with
complete v0.84.0 first. RK1 remains preparation-only there: four held-out tasks across four areas,
independently reviewed immutable variants differing only in discovery/capture/use, and matching
unrelated repairs. Whole v0.83.0/v0.84.0 releases cannot isolate this treatment. Eight task runs,
potentially eight setups and calibration are not assumed to fit CP1's first subscription allowance.
CP1 stopped NOT READY before a task snapshot was selected; those four cards, variant review and
executable controls remain outstanding. See `meta/field-study-results.md`; never pool CP1 and RK1.

This is the B-225 component experiment, not FS2. FS2 compares the complete framework with a bare
agent and remains governed by `meta/field-study-kit.md`; never pool RK1 with FS1 or FS2. RK1 reuses
the field study's privacy, history-free snapshot, filesystem isolation and oracle-reachability
controls. It does not add a general eval harness. `.claude/evals/run-agent-evals.ps1` remains the
Claude-specific typed-evidence runner; do not call it a Copilot executor or alter its scenarios for
this protocol.

## Authority and stop boundary

This packet permits offline task-card preparation and synthetic control calibration only. Before a
live arm, obtain all of the following and record them below: an approved repository snapshot and
privacy boundary; independent task/domain oracle review; an installed Copilot CLI or VS Code seat;
an exact, stable model route; calibrated host-specific observers; and explicit time, model and
credit caps. Private code stays within its existing authorised provider/host boundary. Do not
contact a participant, export traces, query production, or spend provider credits without separate
authority. A missing prerequisite is `NOT RUN` or `NOT COMPARABLE`, never a loss for that arm.

## Freeze before discovery or task execution

The coordinator completes and hashes this private card before either setup arm can see it. Store the
card, accepted solutions and graders outside both setup/task scopes.

| Frozen field | Value required before live work |
|---|---|
| RK1 run id and protocol revision | |
| Repository snapshot/revision and allowed local dependencies | |
| CURRENT and ENHANCED framework commits plus artifact hashes | |
| Exact allowed discovery treatment delta; all other repairs identical | |
| Privacy/provider boundary and prohibited material | |
| Exact Copilot host/version and mode (CLI or VS Code) | |
| Exact model id and proof the route is stable | |
| Setup entrypoint/mode and equal per-arm setup/discovery cap | |
| Task-selection population/window, traversal order and exclusions | |
| Four or more held-out task ids and repository areas | |
| Arm-order counterbalancing schedule | |
| Equal per-task arm cap; setup/discovery/refresh cap; total cap | |
| Materiality thresholds for quality, severe errors, review time and intervention | |
| Observer positive/negative calibration and retained evidence fields | |
| Independent oracle reviewer and review boundary | |
| Explicit live time/model/credit authority | |

Select tasks objectively before discovery. Freeze a chronological or otherwise repository-
justified candidate window and traverse it by a declared order, recording a sanitised exclusion
reason for every earlier candidate. Each selected task must have discoverable pre-change evidence,
an observable requested change, independent acceptance, and at least one correctness-material
nonlocal decision. Its request, accepted solutions and grading key stay hidden from both discovery
setups. Do not select tasks because either arm is expected to win.

The set includes at least four different repository areas and, across them, a quiet unique rule, a
helper-derived rule, a reusable cross-component operation and conflicting legitimate scopes. These
are adversarial shapes, not a domain taxonomy. Reporting, ingestion and finance are optional
examples only. A task whose only “correct” answer depends on unavailable owner intent is ineligible;
if the uncertainty is repository-visible, asking or returning a bounded unresolved decision is a
valid outcome and must be in the frozen alternatives.

For every task freeze this private card:

```text
Task id and repository area:
Selection position and sanitised prior exclusions:
Exact request (hidden from setup):
Observable pre-change state:
Baseline and targeted verification commands:
Required nonlocal decisions and pre-change evidence:
Supported correct alternatives, including ask/unresolved where applicable:
Executable acceptance valid-world construction:
Executable acceptance invalid/pre-change-world construction:
Targeted invalid construction for each required nonlocal decision:
Severe-error definitions:
Knowledge entry/source that could be discovered (never supplied to the task prompt):
Independent oracle review result:
```

Before task agents run, execute the complete oracle against one valid implementation and every
supported alternative, then against the pre-change/invalid world and one targeted violation per
nonlocal decision. A zero exit without the expected probe/test count is `CANNOT EXAMINE`. If the
measure cannot register both success and failure, the task is ineligible; do not repair the oracle
after observing an arm.

## Prepare the paired component arms

Create history-free snapshots from the same approved repository revision, following
`meta/field-study-kit.md > A3` for neutral one-commit Git roots, no remotes, restricted scopes and
outside-root canaries. The arms are:

- **CURRENT:** the exact current released framework and its ordinary setup/discovery behavior.
- **ENHANCED:** the exact candidate release containing only the reviewed discovery increment being
  measured.

Freeze both framework commits, immutable artifact hashes and the exact allowed treatment delta. If
the later candidate release also contains B-216, B-226, B-227 or another repair, either apply that
same repair to both arms or prepare and independently review a component-only ENHANCED artifact.
Never attribute the outcome of an entire changed release to discovery.

Use the same setup host and exact model in both arms, with equal setup/discovery caps. Run the
ordinary requested bootstrap/rebootstrap discovery; never name a held-out task, expected rule,
fixture answer or grading key. Preserve every generated claim/skill/coverage artifact exactly as
produced. Record setup reads, elapsed time, active human time, interventions and observable usage
separately from task cost. Do not “improve” CURRENT by hand or repair ENHANCED into eligibility.

After setup, freeze each arm's generated artifact manifest and bytes. The task agent for one arm
must not be able to address the other arm, the source repository/history, private cards/oracles,
accepted solutions, coordinator storage, global memory containing task knowledge, or prior task
sessions/results. Materialise one arm at a time when the host cannot enforce sibling isolation.
Credentials and personal/organisation instructions must be absent or identical and non-answer-
bearing. Run the baseline in both prepared arms; setup breakage makes the pair void and remains a
setup outcome.

## Offline controls that must be observed before a live arm

These are targeted controls, not a new general checker. Record commands/artifacts and exact
results; a narrative claim is insufficient.

| ID | Constructible valid world | Targeted invalid world that must be rejected |
|---|---|---|
| RK1-C1 selection freeze | Card hash and task order exist before either setup starts | Change a task/order field after the setup timestamp; the recorded hash differs |
| RK1-C2 no answer-bearing setup | Setup-visible tree lacks task request, solution and grader tokens | Plant one unique grader/request token in a setup-visible file; preflight finds it and refuses the task |
| RK1-C3 history isolation | One neutral commit, no remotes/other refs, identical pre-install tree ids | Add a later solution-bearing commit/ref; preflight refuses the arm |
| RK1-C4 filesystem isolation | Probe reads its own random canary and cannot address the other arm, cards, originals or prior results | Expose one excluded canary; the arm is refused, not merely warned |
| RK1-C5 arm purity | CURRENT manifest contains only released-current setup output; ENHANCED has its own frozen output | Copy one ENHANCED knowledge artifact into CURRENT; manifest/byte comparison refuses the pair |
| RK1-C6 oracle reachability | Valid implementation and all frozen alternatives pass; pre-change and targeted violations fail | An inert oracle accepts one targeted violation or rejects a supported valid alternative; task is refused |
| RK1-C7 observer calibration | Known host actions produce inspectable discovery/read/tool-execution observations; independent oracle inspection separately judges semantic application | A final-text keyword echo with no underlying read/action is no host observation, and no event alone is called correct application |
| RK1-C8 stable route | Both paired executions record the same exact host/model route under frozen caps | Route/model changes, is hidden, or Auto resolves differently; pair is `NOT COMPARABLE` |
| RK1-C9 finite execution | Each arm stops at its declared cap and retains partial state as an outcome | A timeout/retry crosses the cap; execution is stopped and not silently rerun |
| RK1-C10 absent evidence | Agent asks or returns the frozen unresolved outcome when necessary evidence is inaccessible | Grader rewards an invented policy or treats `CANNOT EXAMINE` as a pass/fail win |

Host-specific observer calibration happens only after an actual host/seat is selected. Copilot CLI
and VS Code are separate observations. CLI evidence does not fill the VS Code row; skill
registration is not invocation, invocation is not content reading, and content reading is not
correct application. An absent event is meaningful only after RK1-C7 proves that host/version can
emit the corresponding positive observation. Inline completion is outside this agent-task study.

## Counterbalanced task execution

Use fresh sessions and the same exact prompt, host, model, toolchain and calendar window for each
paired task. Counterbalance arm order using the frozen schedule. Reconfirm isolation before the
second arm. Do not show either result to the other, steer toward a known rule, or repair an arm
before scoring. Stop at the frozen cap and score what exists.

For each arm retain locally:

- independent task acceptance and every severe error;
- each required nonlocal decision (`pass`, `fail`, or `cannot examine`);
- typed/inspectable knowledge entry discovery, content/reference read, scoped application and task
  verification as four separate observations;
- active human prompting/review/repair time, intervention count and final acceptability;
- wall time and observable model/agent usage; and
- final diff/artifacts plus targeted/baseline verification output proving the expected checks ran.

`Cannot examine` is unordered and never a win/loss against pass or fail. Valid alternative
implementations pass. Grade against the frozen pre-change evidence and oracle, not similarity to a
historical patch or generated discovery artifact. Record setup and refresh cost separately from
task execution.

## Result record and decision

Complete one row per task before comparing arms. Preserve nulls, regressions and timeouts.

| Task | Arm | Acceptability | Severe errors | Decision vector | Entry found | Body/reference read | Applied correctly | Verification ran | Active review/repair | Interventions | Elapsed | Usage | Gaps |
|---|---|---:|---:|---|---|---|---|---|---:|---:|---:|---|---|
| | CURRENT | | | | | | | | | | | | |
| | ENHANCED | | | | | | | | | | | | |

After recording raw tasks, apply only the materiality thresholds frozen before discovery. Classify
the series as a bounded observation—benefit, harm, mixed, no detectable difference, or void/not
comparable—without a general productivity claim. State every unrun host/model arm.

- Grounded useful artifacts but missed access/application: repair the delivery route before adding
  discovery machinery.
- Correct application without material task improvement: do not expand extraction machinery.
- False rules or excessive review cost: narrow capture or deepen evidence rather than generating
  more.
- Material improvement: expand only the observed discovery/refresh bottleneck; do not infer a
  platform, universal banking benefit, or framework-versus-bare result.

Live results require a separate reviewed run record. They never become a general release gate.

## Offline protocol review

Root reviewed this packet after Sol authored it and returned **ACCEPT WITH CLARIFICATIONS**. The
review required immutable hashes for both framework treatments, an exact allowed discovery delta,
identical handling of unrelated repairs, a frozen setup entrypoint/mode/cap, and separation of
host-observable actions from independent semantic judgment. Those corrections are incorporated
above. The review accepted the scope, privacy, preservation, supported-alternative and null-result
boundaries. It did not execute RK1-C1–C10, authorize a live arm, certify a target host/model, or
establish product value.

## Authorized execution checkpoint — 2026-09-09 — blocked before study dispatch

The user requested execution, allowing Claude CLI review/implementation where useful. Revision 1
compares released v0.86.0 with a prospective, separately committed experimental ablation on the
same foundation. CONTROL retains manual wiki/navigation, project-pattern knowledge and unrelated
repairs. The question is marginal value above that residual; CONTROL is not a released artifact.
Exact source/installed-byte purity review and construction remain unrun.

Read-only Opus 5 xhigh critique returned REVISE, then a fresh revision check ACCEPT for preparation.
Corrections made the contrast, sample stop, readiness predicates, unrelated-ablation red control
and full four-pair budget explicit. The reviewed proposal hashes were
`F2BDE3B2AAA9DBCA612B43A4366A4ABA2C9E426A85C859F287D313F838328CEB` and
`2FDA9BB009A9D4FEC9F0A5ADC3369C6BE087B51F7DDFC61856260FE12382F49A`.
Reviewers read supplied packets, without host or application execution; they did not certify
CONTROL purity or task eligibility. The calls reported USD 0.9840065 combined list-price cost.

**Selection.** Missing public history was reacquired. A separate selector screened the frozen
prefix using RK1's one-nonlocal-decision criterion and retained four provisional source cards
across four areas plus all earlier exclusions. Root independently matched the 238-entry population
order and each candidate's parent/path set. Coverage and executable eligibility still need review;
no restore, build or oracle ran. One Angular candidate's apparent test configuration omits its
relevant specs, so a working test route remains an explicit obligation. Population/card SHA-256:
`68B50AFA2A587D376C6B9E97CAE58B97C807B0D942A184331EB7EABD3100C801` and
`76AB3F2D78C6587CC835F3D844DA7CBBDB8A178D58B53847535A7FB24777D6D8`.
Source, identities, prompts, proposed oracles and exclusions remain coordinator-only under
`C:/TEMP/rk1-20260909/tasks`; actors must not receive that directory.

**Host blocker.** Root's direct native PS7 7.6.5 observations on Windows build 26200.9278 returned
sandbox API capability mask 7 and installed Copilot 1.0.83 platform support true. Thus a published
build table cannot establish missing capability here. However, the host auditor's two actual
offline CLI sessions, using minimal and expanded Windows environments, refused the required
policy before the allowed own-canary command ran. Root separately reproduced the refusal through
the installed SDK `LocalSession` shell entrypoint: success false, empty command output, exit 3.
The diagnostic says that the policy cannot be guaranteed with BaseContainer and suggests removing
denied paths or updating Windows. This is an execution-route refusal, not an application failure
or proof that every Windows configuration is unusable.

Saved settings disabled bypass/dev-tool grants, supplied no read-only paths and denied five
excluded storage classes. The emitted policy added system-volume read access. Removing the
denials would expose coordinator, other-arm, history, oracle and prior-state canaries, so that
workaround was not used. Emitted network policy denied ingress, egress and host loopback; a
conflicting UI label does not establish a network leak. Picker filtering accepted the own canary
and excluded the others, but only proves suggestion filtering. Native file access, shell
containment, model transport and full observer calibration remain unproved; RK1-C4 did not pass.
The retained Hyper-V/no-mount container is network-none. Read-only npm and GitHub release checks
also identified 1.0.83 as latest. No ready connected alternative was established.

Raw host records: `C:/TEMP/rk1-host-20260909/observed-results.md` and `receipt-hashes.json`.
Root replay stdout SHA-256:
`D6A670DABEC6A2EC32C5736FE12D281AEF9A86DF5F27EF7CC4932F8F85D39172`.
The two Opus streams under `C:/TEMP/rk1-20260909` have SHA-256
`820ADFBBD3D3BB03C845956377475BE27516373F950B74DDF6D25FAD289BC753` and
`0ABC1DEF1544D2FA1892FC6317BA0AB03B03F3317EDF41496AB85F756DEF8D96`.

**Disposition / RCA.** Preparation stopped before its deadline. No Copilot model call, application
setup/task, variant construction, paired result or efficacy claim followed. No host setting,
ACL, subscription or shipped product changed. Release parsers and platform/version detection
cannot establish execution of a particular containment policy. The same exposure applies to
native file-tool filtering, online transport and zero-test discovery: inspect actual policy and
execution/counts at the claimed surface. Existing RK1 controls caught this before provider task
spend; no new generic gate is justified. Resume with one configuration proving permitted model
transport plus allowed/excluded access, then finish the retained variant/oracle/coverage/observer
obligations. Preserve selection and consumed review cost; check time/credit bounds prospectively.
This is a retained blocker, not B-225 retirement or permission to revive CP2.

**Record verification.** Root matched all nine retained host receipt hashes and the population,
task-card and review-stream hashes above. Direct native PS7 and PS5.1 runs at code page 437 each
observed BacklogHygiene's broken-index control exit 1, then 10/0 clean; DocTruth reported 16/0
including its own restored scratch mutation, and the repository privacy scan passed. These
checks verify this meta-only record, not a working study execution route. No `src/` or `dist/`
changes were present.

## Outer-container follow-up — 2026-09-09

The user challenged treating the native refusal as the end of the route search and requested
Sonnet for the implementation/diagnostic work. Claude CLI initialization recorded
`claude-sonnet-5`. Its 15-minute, USD 3-ceiling diagnostic completed offline and existing-NAT
probes, then timed out before its final proposed report/script write executed. No final cost
receipt was emitted; USD 3 is an allocation, not an observed charge. This follow-up did not reset
the campaign's sample, credit budget or preparation deadline.

Sonnet observed synthetic file write/read and PowerShell execution as ContainerUser inside a
Hyper-V-isolated, network-none container. Root inspected the running container: pinned toolchain
image, no mounts, and coordinator task storage absent from its namespace. Sonnet then reached the
provider public endpoint over the existing NAT network: DNS, TCP 443 and unauthenticated HTTPS
HEAD 404. Root reproduced the connectivity in a fresh ContainerUser/Hyper-V/no-mount container
and separately propagated the execution canary's expected exit 7. All newly created probe
containers were removed; existing images/networks were retained. No credentials or study input
entered the containers, and no Copilot model call occurred.

These are usable offline execution and public-endpoint reachability observations, not a connected
isolation pass. The diagnostic scripts are collectors, not rejecting gates. Bounded image scans
do not establish universal absence of answer material or credentials, and a single reachable
endpoint does not establish universal NAT reachability. Native file-tool/observer calibration,
selective egress and authenticated model transport remain unrun.

Root rejected the unexecuted network-probe draft: unchecked native exits and unconditional
name-based cleanup could delete a pre-existing object after failed creation. It also lacks fixed
subnet/identity preflight, bounded matched connectivity controls and a justified path-sensitive
transport policy. Next is one corrected, reviewed, credential-free private/internal-network
probe using owned IDs and the demonstrated NAT positive control, then selective transport if that
passes. The native sandbox refusal does not retire RK1 or establish that this alternative fails.

Raw records and root adjudication: `C:/TEMP/rk1-container-20260909/root-review.md`. Sonnet stream
SHA-256 `3E5E6276CFC93CD14D9A906A10787E19B64C886894C39DDFC3979D43F3674D77`;
root review SHA-256 `005FE762C069337E1CE41C508226CC3A50D89B1D0F4883939607FEC2B35D8E65`.
RCA: the initial stop bounded one mechanism, not the alternative search. Independent execution
found a working outer-container route; review caught the next draft's lifecycle/false-green
hazards before any new network was created. No new generic gate or shipped change follows.

Record checks: direct PS7 and PS5.1 at code page 437 each observed BacklogHygiene's broken-index
control exit 1 then 10/0 clean, DocTruth 16/0 with its restored mutation, and clean privacy scans.
These verify the meta record, not a selectively connected study environment.

## Private network and fixed-request relay — 2026-09-09

The user authorized the corrected network checkpoint after the original preparation deadline.
The prospective `.claude/plans/2026-09-09-rk1-private-network.md` caps mechanism work at 30 minutes
from 09:47 London; it does not reset the sample, prior spend, original six-hour envelope or study
prerequisites. Root used individually checked Docker commands and captured owned IDs, avoiding
the rejected draft's automatic name-based cleanup. Opus critiqued the initial contract (REVISE,
corrections adopted; reported USD 0.0946025) and accepted the separate relay contract (USD 0.089496).

**Network observation A.** A private-only Hyper-V/ContainerUser actor read the exact synthetic
nonce from a peer. Its direct TCP attempt to the frozen provider IPv4:443 timed out; a NAT control
connected to that same literal before and after. The closed peer port also timed out instead of
the required refusal, while the peer's loopback closed port refused. The full original conjunction
is therefore **unmet**, not silently reclassified green. These finite facts do not establish
universal blocked egress, and the actor still had a configured IPv4 default route/DNS server.

**Distinct relay observation B.** A fresh proxy accepted both NAT and private endpoints before
first start; a fresh actor had only the private network. Both used the pinned toolchain image,
Hyper-V isolation, ContainerUser and no mounts. A small synthetic listener allowed only one fixed,
unauthenticated provider-root HEAD request, never a caller-supplied URL, header or body. Redirects,
cookies, default credentials and ambient proxy use were disabled in that client. HEAD returned the
expected nonce plus HTTP 404; OTHER returned DENY. Actor direct TCP to the same frozen provider
literal timed out, bracketed by successful proxy direct connections. Native PS7 and PS5.1 clients
each observed the allowed and denied responses. Four logged request IDs bind two outbound events
to the HEAD requests and none to the denied requests. Guest forwarding flags were measured
disabled before/after; those flags alone do not prove absence of every possible bypass.

All five containers and both networks created in this checkpoint were removed after exact ID/label
verification. Final captured network/container identities, adapter fields, IPv4/IPv6 addresses and
routes, and firewall-rule fields matched the initial baseline. The expected temporary switch
extension adapter was distinguished from a new host-addressed interface; Docker/HNS host-state
creation is acknowledged. No credentials, task source, answers, model calls or shipped changes
were involved. This establishes **credential-free relay feasibility**, not native Copilot
authentication/model transport, complete network isolation, RK1-C1–C10 readiness or efficacy.

Raw scripts/receipts and review streams remain under `C:/TEMP/rk1-private-20260909`. The frozen
evidence manifest SHA-256 is
`822EF467C9711B327E13B2DDA7C495FE853E58F97144E7F8B573584BD6D5E314`.
Next is a reviewed native model/auth transport route and its full access/observer controls; the
fixed HEAD relay cannot be used as an RK1 model executor. Preserve the selected task cards and
remaining CONTROL/oracle obligations.

**RCA.** Platform refusal and an over-specific closed-port expectation bounded observations, not
all implementation alternatives. Small actual probes separated working peer/relay paths from
unproven security claims. The cleanup hazard was removed by explicit owned-ID operations; no
general network runner or release gate was needed. A streaming self-hash attempt hit a file-sharing
error; the retained manifest was rebuilt from an explicit collected list excluding itself. This
was a cannot-examine bookkeeping error, not an artifact or network failure.

**Post-review.** An explicit Opus 5 read-only code/receipt review returned ACCEPT NARROW
CODE/RECEIPTS (reported USD 0.1296895). Root retains its limitations: the service log does not
identify the client's PowerShell host; those identities come from root's invocations. The frozen
direct-probe IP and relay hostname need not be the same server address. Bracketing controls reduce,
not eliminate, transient/path uncertainty. A preceding broad review exhausted its requested USD
0.50 flag without a verdict and reported USD 0.710734; its usage included Opus 4.8 after Opus 5
initialization. It is not accepted review evidence or proof of a hard cost ceiling. The fresh
completion prospectively reserved USD 0.30 within the existing campaign USD 10 allocation. Total
reported checkpoint review cost is USD 1.024522, separate from prior costs and not an invoice.

**Verification.** The four external probe/relay scripts have UTF-8 BOMs and parse under direct
PS7 and PS5.1; the relay service ran under PS7 only, with both client hosts observed. Root verified
the frozen evidence hashes. Direct authoring checks on both hosts at code page 437 observed the
BacklogHygiene broken-index rejection then 10/0 clean, DocTruth 16/0 with restored mutation, and
clean privacy scans. `src/` and `dist/` remained unchanged. These are separate evidence layers,
not a claim that parser or CI gates establish network security.

## Native HTTP transport checkpoint — 2026-09-09

Renewed user authority bounded mechanism work to 10:32–11:17 London inside the original envelope;
see `.claude/plans/2026-09-09-rk1-native-transport.md`. The initial preparation deadline, selected
cards and consumed budgets were not reset. This checkpoint did not authorize study dispatch.

**Failed candidates retained.** Sonnet timed out at 180 seconds without writing the requested
relay file or a final usage receipt; root implemented the bounded external scripts. Direct API-
token lookup required `COPILOT_ENABLE_ALT_PROVIDERS=true`; authenticated status then coexisted
with an empty native model list and the CLI's "No supported model available" refusal. No upstream
POST followed that candidate. Installed CLI validation also rejected `--max-ai-credits 5`
(minimum 30), while omitted/empty tool allowlists retained defaults. Actual unpaid preflights
exposed these conditions; none was repaired by fabricating a model list or switching to BYOK.

**Observed route.** A separately critiqued GitHub-token-shaped bootstrap used explicit GitHub API
and CAPI URL overrides, with a nonsecret actor placeholder and the real credential injected only
by the trusted relay. Native metadata requests to fixed `/copilot_internal/user` and `/models`
returned successfully. The relay also allowed fixed `GET /user`, but it was not needed in the
observed path; do not mistake this candidate policy for the minimal final study allowlist. Token
exchange, repository/history routes, arbitrary authorities, redirects and CONNECT were not
forwarded. Some additional native startup requests were denied without blocking the final reply.

The final native preflight reported CLI 1.0.83, `gpt-5.4`, medium, HTTP `/responses`, non-BYOK and
non-Auto. An explicit nonmatching tool whitelist produced zero tools. The relay parsed that exact
shape and denied it while its trusted permit flag was absent. Root then recorded the method,
path, model, effort, tools and proposed output bound before creating the proxy-local permit.
At 10:00:38.615 UTC one upstream POST returned HTTP 200 and the complete fresh nonce; native
exit was 0, with no tool requests or file changes. The relay added `max_output_tokens: 256` and
recorded pre/post byte lengths and hashes. This proves **one relay-mediated, no-tools, native
CAPI HTTP-fallback calibration response**, not unmodified/default-auth/WebSocket or ordinary
study-tool fidelity. No custom model executor or tool bridge was substituted.

**Controls and gaps.** Final-code PS7 and PS5.1 clients each observed ten hostile request rejects
and metadata HTTP 200. Actual native model enumeration supplies complete-body evidence beyond
the simple status-only positive helper. Actor direct TCP to the frozen provider literal timed
out, bracketed by proxy success. These finite probes do not prove universal blocked egress.
The post-paid second-request probe was attempted after the five-minute service expired: PS7
printed cannot-examine and exited 1; PS5.1 was not reached. No stdout receipt was created by
that stderr-only failure. It is **not** an observed second-request rejection, and no relay
restart regained a slot. Comprehensive transport/access/observer readiness remains unmet.

Both created containers and their private network were removed after exact ID/label checks.
Captured final network/container identities, adapter/address/route and firewall-rule fields
matched baseline. Eight external PS scripts parsed with UTF-8 BOM under direct host PS7 and
PS5.1; the service itself ran PS7 only. The evidence-directory literal-credential comparison
found zero matches in 82 then-existing files; this is not universal secret-leak certification.

**Review and usage.** Opus design critiques reported USD 0.078257 and USD 0.089203; root adopted
bounded corrections and rejected unsupported predictions as observed facts. Fresh code/receipt
review returned ACCEPT NARROW — RECEIPTS, reporting USD 0.214111. Root retains its gaps and does
not adopt universal "false-green ruled out" or credential-boundary conclusions. The reviewer
could read the code but not independently execute/recompute its hash; root matched the running
proxy hash before dispatch. Review reports total USD 0.381571 plus Sonnet's full USD 0.70 timeout
reservation: conservative campaign total USD 7.0900995 of USD 10, not an invoice. Native usage
reported one premium request and `totalNanoAiu=1016500000`; rounded shared-account quota changed
6,487.8 to 6,486.7, with overage false. Keep the operative 30-credit reservation within the
original 160-credit calibration allocation until reconciled; no purchase/settings change occurred.

Frozen external packet: `C:/TEMP/rk1-transport-20260909`, manifest SHA-256
`CADA6760F9B9E3A7B4BA7EC23DBF2E018E5CC75D9CD85F64D09F2C91386A4C08`.
The root adjudication preserves the stderr-only late-control observation and review disposition.
CONTROL construction/review, task baselines/oracles, ordinary native file/shell/observer controls,
and all eight setup/task arms remain unrun. No framework efficacy result follows.

**RCA.** Environment names, authentication status, empty tool lists and a CLI budget flag did
not mean what the proposed experiment assumed; actual native requests separated those conditions
before spend. The late control demonstrates the same lifecycle problem on the measuring side:
an expired instrument cannot register the required successful rejection. Integrate follow-up
controls into the bounded lifetime next time, without resetting a spent slot or backfilling green.
No new general proxy platform, release gate or shipped behavior change follows.

**Record verification.** Direct PS7 and PS5.1 at code page 437 each observed BacklogHygiene's
broken-index exit 1 then 10/0 clean, DocTruth 16/0 with its applied/restored mutation, and a clean
repository privacy scan. Root recomputed all 83 frozen manifest entries without mismatch.
`src/` and `dist/` remained unchanged. These authoring checks do not close the runtime gaps above.
