# CP1 — Windows container substitution

**Authority:** on 2026-09-06 the user approved assessing Windows Docker containers as the
alternative to a manually provisioned VM, with Sol or lower models used for suitable work.
**Baseline:** `441a3c28f448716dcdf9c04b35674b7b1126bebc`.
**Status:** ACCEPT WITH CONDITIONS by Sol for host installation and generic offline feasibility;
live setup/paid execution remains outside this approval. See the companion critique for hashes,
review provenance and the observed restart stop. The reviewed snapshot is retained externally;
this status annotation records its disposition.
The original CP1 contract and its observed preparation stop remain historical records.

## Bounded change and proportionality

Permit a **Hyper-V-isolated Windows container** as CP1's disposable native Windows execution
boundary. Keep the original guest option available; do not substitute Linux, WSL execution or
process isolation for the tested framework platform. The observed obstacle is the absence of a
usable guest and runtime. A repeatable image may remove manual Windows media/guest provisioning
and allow fresh task environments with prepared dependencies; it does not remove Windows feature
installation, hardware virtualization or privilege requirements.

Compare three options: a full VM offers a familiar desktop but needs guest provisioning; Windows
Sandbox offers a disposable desktop but less convenient reusable dependency state; a Windows
container image fits repeated CLI runs and is the selected bounded feasibility assessment. Do not
build a general runner, new release gate, shipped API or orchestration platform.

## Execution contract

1. Install Docker Desktop for all users with Windows-container support on the Windows 11 Pro host.
   Inspect existing installation/features first; use official signed distribution and verify its
   identity. Enable only the required Hyper-V/Containers features. Do not disable existing security
   controls or remove user applications. Native administrator approval may be needed. Do not reboot
   automatically; retain an exact operator restart/resume handoff if required. Inspect features
   before and after `Enable-WindowsOptionalFeature -NoRestart`; any detected pending restart stops the
   installer stage. Use native UAC, without a credential workaround. Do not pass `--accept-license`;
   any required Docker terms acceptance remains in the native installer/first-start interface.
   All-users Windows support installs privileged `com.docker.service`; `docker-users` membership
   confers host-administrator-equivalent access. Only the trusted coordinator may receive it.
2. Prepare a pinned Windows Server Core .NET 10 SDK image, with direct PowerShell 7 and Windows
   PowerShell 5.1, Git and the exact Copilot CLI/runtime prerequisites. Source version choices from
   official metadata, retain URLs/hashes/digest and inspect platform compatibility. No credentials,
   host profile, ABP history, task answers or grading material enter the reusable image or build
   context. Raw materials and context stay outside authoring Git. Record component versions and
   archive/lock hashes; freeze automatic updates before comparison and record actual state.
   Build dependency downloads run only as trusted preparation, with no study input or Copilot auth.
3. First prove **toolchain feasibility** using a fresh disposable container: Docker reports Windows
   and Hyper-V isolation; commands report OS, both PowerShell hosts, .NET SDK, Git and Copilot
   version/help. Run a harmless local .NET build/test with a nonzero executed count to check the
   image, explicitly distinguished from ABP acceptance. No Copilot prompt or paid call is permitted
   by this feasibility step. The offline smoke container uses `--network none`; this does not
   demonstrate the later selective transport policy. Image build failure, an unavailable host or zero executed tests is not
   a framework/task result. Do not claim Server Core support solely from a package's Windows label.
4. Provision each running trial with **8 GB RAM / 100 GB writable disk capacity** initially; verify
   actual container resource/storage settings and measured free space/performance. Images and
   dependency caches consume additional host disk. Do not assume a CLI flag enforces a resource
   boundary or that virtual disk capacity equals free disk.
5. A fresh container/session/profile receives only its assigned history-free repository and, for
   setup, the exact framework release. Preserve native ABP instructions/skills. Use an unprivileged
   task identity (`ContainerUser`); incompatibility is NOT READY and does not authorize an admin
   fallback. Never expose Docker's daemon socket/named pipe, host drives,
   broad coordinator mounts or host credentials to the task. Keep originals, grading, the other arm
   and previous sessions outside the container; do not store them in image layers. Collect results
   from the coordinator after execution, preserving them before container removal. No bind mounts:
   copy only the exact manifest of assigned input files into the fresh container and copy the
   declared repository diff/transcript/evidence outputs out. Verify Docker's mount list and actual
   forbidden-path absence. Preserve setup output in coordinator storage; strip profile/auth/history
   before copying the reviewed prepared repository into a new task container with a new profile.
6. Containers alone do not establish the required network boundary. Before a paid session, enforce
   and test the original blocked public-code/issue/PR/search/remote-MCP retrieval conditions while
   permitting the observed Copilot transport. Controls must be outside the task user's authority.
   Test both a permitted operation and a targeted forbidden operation for every required storage/
   retrieval class under the actual task identity. Default Hyper-V NAT is not that boundary:
   Microsoft's documented default is ALLOW ALL, with no default port-ACL reconfiguration for
   Hyper-V NAT/Transparent modes. The candidate for later review is L2Bridge/VFP with deny-by-default
   egress allowing only a coordinator-controlled external proxy; the proxy permits exact observed
   Copilot transport endpoints. This candidate is **not implemented or certified compatible**.
   Probe direct-IP access, alternate DNS, proxy bypass, public code/issue/PR/search and remote MCP.
   Disable and separately probe server-side Copilot GitHub/web/MCP retrieval because allowed model
   transport may carry it. If that boundary cannot be established within the cap, stop NOT READY.
   A concrete executable network policy requires renewed review before live setup. It is not a
   prerequisite for installing the host or running the generic offline feasibility container.
7. The first ABP baseline/acceptance and setup runs must execute in the selected container boundary,
   using checkout source, nonzero test counts and observed valid/targeted-invalid controls. A generic
   .NET smoke test, installer dry run, image build, version command or local host test cannot replace
   that evidence. A concrete independent task/oracle review remains required.

## Unchanged boundaries and reporting

All CP1 selection, hidden reference facts, full-v0.84.0/native treatment, developer-started headless
adoption and human proposal application, marker/docs-sync/application baselines, scoring, model/
worker routing, observer calibration, credit ceilings and stopping rules remain. Pre-purchase
offline readiness precedes purchase; paid calibration and onboarding follow purchase before tasks.
RK1 remains preparation-only, VS Code remains deferred and B-42 still requires independent FS2.

One preparation hour was previously charged; seven remain. Charge subsequent work cumulatively.
Bound this additional container-feasibility attempt to **two active hours**, including research,
review, downloads, installation/image work and records. Stop earlier at an unresolved administrator
or restart boundary; retain a concrete resume packet. That checkpoint is not permission to consume
the full remaining campaign budget engineering a container platform.
The first 100 integrations remain the entire allowable candidate inventory; this change does not
authorize candidate 101, repeat the search, or loosen eligibility. No task or purchase is authorized
past a missing prerequisite. Report installation, image feasibility, application readiness, isolation
and paid-run readiness separately, preserving cannot-examine and NOT RUN.

Require Sol to critique the frozen substitution independently before installation/image authoring,
including resource practicality, boundary leakage, actual runtime support and whether a smaller
approach would suffice. Record source-backed corrections and remaining execution gaps; design
acceptance never certifies a working container or fair campaign.
