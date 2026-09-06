# CP1 Windows container substitution — independent critique

**Scope:** prospective substitution of a Hyper-V-isolated Windows container for the manually
provisioned CP1 Windows guest. This does not review or certify a selected ABP task, acceptance
oracle, actual container, egress policy, Copilot adoption or paid-run readiness.

**Reviewer:** `/root/cp1_container_sol_review`, separate session, `gpt-5.6-sol`, high effort,
no implementation participation. User explicitly requested Sol or lower models for appropriate
work. A separate `gpt-5.6-luna` session researched vendor compatibility; root independently checked
the SDK image digest/Dockerfile, package metadata and downloaded archive identities. Neither
review is an orthogonal Windows execution vantage.

## Initial review — REVISE

Sol verified the initial contract SHA256
`86E0604499CBEC3F2CF5716F740F1E401F230B1F40B7A00365638D88DFDC0D4B`
against authoring baseline `441a3c28f448716dcdf9c04b35674b7b1126bebc`, and accepted the
proportionality of assessing containers. It required these corrections before proceeding:

- Respect Docker terms and all-users installation; avoid implicit `--accept-license`.
- Use native UAC, inspect feature state and enable Hyper-V/Containers with `-NoRestart`; preserve
  the exact restart/resume boundary without a credential workaround.
- Disclose the privileged service and host-administrator-equivalent Docker group; keep the task
  identity away from the daemon.
- Make egress concrete: default Hyper-V NAT permits outbound traffic, and permitted Copilot
  transport can also carry server-side retrieval. Include direct-IP/DNS/proxy-bypass controls.
- Define copying and profile lifecycle, with no host bind mounts, broad input or sealed credentials.
- Require ContainerUser; incompatibility is NOT READY rather than an administrator fallback.
- Pin component versions/digests/update state and observe effective isolation/resources.
- Bound container engineering within the original remaining preparation allowance.
- Prospectively amend WSD-076 while preserving the original stop.

## Root verification and revision

The revised contract SHA256 is
`FAD75F2892B287D8E357136A749CCC24CACF881240AA6CADD6310EAD104B25DA`.
Root adopted the concrete privilege, lifecycle, identity, pinning and two-active-hour checkpoint
conditions. Microsoft's network-security documentation supports Sol's NAT concern; it lists VFP
for Hyper-V/L2Bridge as a candidate, not proof of an executable policy on this host.

Root narrowed two proposed preconditions. The user already authorized Docker setup; any required
terms acceptance stays in Docker's native interface, without a redundant hypothetical licensing
question. Trusted dependency-image preparation and a generic `--network none` smoke run do not
require a completed selective egress policy. Live setup still requires independent review of the
concrete policy, observed permitted/denied operations and disabled/probed server-side retrieval.
No network-isolation claim is made from an image build or offline smoke.

The external fixed-feature helper has no installer or reboot invocation. Root observed zero parse
errors under PS7 and direct native PS5.1, plus exit 740 from its unelevated guard on both hosts.
This is guard/parser evidence only; feature enablement and container execution remain separate.

**Final revised-contract disposition:** Sol returned **ACCEPT WITH CONDITIONS** for host
installation and generic offline feasibility at the revised hash above. Actual feature state,
8 GB feasibility, Server Core/Copilot compatibility and runtime were not certified. The committed
contract adds the disposition annotation and says "detected" pending restart to reflect the
bounded signal assessment; its reviewed snapshot is preserved externally.

## Helper review and observed boundary

The initial helper SHA256 was
`CD0C73EF5EF9579DD5897961A08B507F72D97AD63ACCD065B15B86483ACF7FA5`.
Root launched it through native UAC at 09:04:44 UTC before Sol's helper-specific feedback arrived.
Its 09:04:49 UTC record shows both top-level features Disabled before and Enabled after, with
`RestartRequired=true` and no recorded error. No Docker installation or reboot followed.

Sol returned **REVISE** for that helper's evidence: a partial enablement failure would skip
post-state capture, and `-All` dependency changes were not included in the two-root snapshots.
The actual run did not report a partial failure, but its dependency delta is **not captured**.
Preserve that gap and the review timing; do not reconstruct a pre-state from a later inspection.

The separate resume helper SHA256 is
`2BD745561DB6DD68186CB79897C4C672AB7347B979DBE67F8BA67C362C79D6AC`.
It captures all optional-feature states before and in `finally`, including partial failure;
records the observed delta and bounded restart signals; distinguishes unavailable evidence; and
offers an inspection-only path. Sol verified its hash/full source/PS7 parse and returned
**ACCEPT for the bounded resume role**. Root observed zero parse errors and the non-administrator
exit 740 directly under PS7 and PS5.1. The revised helper was not run elevated in this session.
No positive feature-enablement or partial-failure recovery evidence is claimed for it.

The original helper/logs and the revised helper stay outside authoring Git. Sol performed no
elevated execution or host mutation. A manual reboot and current-state inspection precede Docker
installation; image/toolchain/application/isolation/Copilot execution remains NOT RUN.

## Source references checked 2026-09-06

- [Docker Windows installation](https://docs.docker.com/desktop/setup/install/windows-install/)
- [Docker Windows privilege model](https://docs.docker.com/desktop/setup/install/windows-permission-requirements/)
- [Windows container security](https://learn.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/container-security)
- [Windows container network security](https://learn.microsoft.com/en-us/virtualization/windowscontainers/container-networking/network-isolation-security)
- [Container storage](https://learn.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/container-storage)
- [Windows optional features / NoRestart](https://learn.microsoft.com/en-us/powershell/module/dism/enable-windowsoptionalfeature?view=windowsserver2025-ps)
