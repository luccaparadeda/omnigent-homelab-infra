# Two-pass infrastructure-as-code review

Date: 2026-10-26
Scope: source and local validation only; no deployment, cloud mutation, or
credential enrollment was performed.

## Outcome

The architecture is appropriate for a low-cost Omnigent homelab after the
changes in this review, but it is **not ready for unattended production use**.
The recommended shape is:

1. Manually reserve the two Oracle Always Free A1 instances, then converge them
   with Ansible over Tailscale.
2. Run Omnigent/PostgreSQL on the 1 OCPU / 8 GB control VM and Vault alone on
   the 1 OCPU / 4 GB secrets VM.
3. Run the always-on home worker directly on its dedicated bare-metal PC using
   the guarded Ubuntu autoinstall plus Ansible. Treat the laptop as a separately
   enrolled, normally interactive worker. Keep Packer/QEMU optional for testing.
4. Move the proven OCI topology into OCI Resource Manager for managed state,
   locking, and reviewed plans. OpenTofu remains optional.

This is a recovery-oriented “golden source” design: Ubuntu + immutable source
identity + cloud-init/autoinstall + Ansible. A QCOW2 or OCI boot backup is a
tested recovery artifact, not the only source of truth.

## Pass 1 — architecture and security boundaries

| Severity | Finding | Resolution / gate |
|---|---|---|
| Critical | The worker cleanup did not remove cloned SSH host keys. | Fixed: host keys are removed before image shutdown and regenerated from unique clone cloud-init. |
| Critical | Packer's temporary account could retain a passwordless sudo grant. | Fixed: final shutdown removes cloud-init's sudoers entry, removes the account from `sudo`, and locks it. Acceptance now verifies all three conditions. |
| High | Docker group membership was granted to the Ansible operator on every node. Docker treats this as root-equivalent. | Fixed: the Docker role defaults to no users, and the subscription-authenticated worker also defaults to no Docker membership. Rootless compatibility is a deployment gate. |
| High | Native subscription credentials could silently fall back to a worker file and root-equivalent workloads could read them. | Fixed in configuration: Codex is forced to keyring-only storage, keyring packages are installed, and rootful Docker access is removed from the worker. Live Claude/keyring persistence still requires acceptance testing. |
| High | Omnigent admin credential state was not bind-mounted although upstream Docker guidance identifies it as persistent state. | Fixed: `/data/admin-credentials` is now a root-only persistent bind mount. |
| High | Vault lacked explicit swap/core-dump guards. | Partially fixed: Ansible refuses to start Vault with active swap and Compose sets core size to zero. Persistent swap configuration must still be inspected on the actual image. |
| High | Vault auditing is not automatically enabled. | Deployment gate: initialize with a short-lived root token, enable and monitor at least two audit devices, then revoke the root token. Automating this before selecting destinations would risk making Vault unavailable. |
| Medium | The docs implied the MCP registry/gateway was already configured. | Corrected: Omnigent 0.19.x has the feature, but this deployment still needs upstream configuration discovery and a live per-project/per-account acceptance test. |
| Medium | The OCI security list denies unsolicited ingress but still allows unrestricted egress, and no host firewall policy is encoded. | Deployment gate: observe the exact Tailscale, KMS, package, DNS and time endpoints first, then add tested host/OCI egress restrictions without breaking auto-unseal or upgrades. |
| Medium | One single-node Vault remains an availability bottleneck and a container is weaker isolation than a native dedicated service. | Accepted homelab tradeoff for the free two-node budget; record it explicitly and rely on tested Raft snapshots and rebuild automation. |

## Pass 2 — reproducibility, idempotency, backup, and operations

| Severity | Finding | Resolution / gate |
|---|---|---|
| High | The Packer build used Ubuntu's mutable `/current/` URL. | Fixed: a versioned release URL, release identifier, and SHA-256 are mandatory and recorded in the image. |
| High | OCI provisioning could silently select the newest platform image. | Fixed: creation now requires an explicit immutable image OCID. |
| High | Logical backup documentation promised application data, but the job only dumped PostgreSQL. | Fixed: the job produces timestamp-matched, separately age-encrypted database and application-state objects containing artifacts and persistent admin credential state. |
| High | No automated off-node Vault Raft snapshot exists. | Deployment gate: design a scoped snapshot token, grant only the Vault instance principal object-write access, encrypt off-node, and prove restore before 24/7 use. |
| Medium | `creates:` prevented Omnigent and OCI CLI version changes from converging. | Fixed: installed versions are inspected and pinned packages are force-reconciled only when mismatched. |
| Medium | Ansible linting was absent from the validation path. | Fixed: `ansible-lint==26.10.1` is pinned, installed in the ignored development environment, and runs from `make validate`. |
| Medium | The repository research recommends Resource Manager while the implemented OCI directory is still OpenTofu-oriented. | Not hidden: manual OCI + Ansible is the first-deployment path; Resource Manager conversion/import is a separate reviewed milestone after topology proof. |

## Required evidence before deployment

- The pinned OpenTofu 1.13.0 format/validate and Packer 1.16.2 format/syntax
  checks now pass, along with Compose, shellcheck, Ansible syntax, YAML,
  static-guard, and ansible-lint checks. The future Resource Manager/Terraform
  conversion still needs its own validation in Oracle's supported runtime.
- Confirm the home PC CPU architecture, disk/RAM layout, Secure Boot
  requirements, GPU needs, and intended target disk.
- Perform a guarded bare-metal installation and complete every golden-image
  acceptance check, including unique machine/SSH identity. Exercise the Packer
  privilege-removal checks only when the optional QCOW2 path is used.
- Install the worker with encrypted LVM/LUKS, unlock its keyring interactively,
  and prove a reboot blocks native subscription use until manual unlock. Verify
  Codex creates no `~/.codex/auth.json`, Claude uses secure storage, and the
  worker user is absent from the rootful Docker group.
- Verify Tailscale grants with default deny. Expose no Omnigent, PostgreSQL,
  Vault, SSH, or Docker socket port publicly after bootstrap.
- Initialize Vault, configure two audit devices with rotation/monitoring, issue
  a short-lived least-privilege Omnigent token, and revoke the initial root token.
- Verify the exact current Omnigent MCP registry configuration and prove two
  projects can select different server-held accounts while workers receive no
  upstream MCP credential material.
- Restore PostgreSQL, artifacts, Vault Raft state, and ciphertext together in
  an isolated environment. Record RPO/RTO and retain the prior known-good image.

## Primary practice references

- Ansible playbooks and desired state: <https://docs.ansible.com/projects/ansible-core/devel/playbook_guide/playbooks_intro.html>
- Ansible check/diff mode: <https://docs.ansible.com/projects/ansible-core/stable-2.21/playbook_guide/playbooks_checkmode.html>
- Ansible secret masking: <https://docs.ansible.com/projects/ansible-core/devel/playbook_guide/playbooks_secret_masking.html>
- ansible-lint installation: <https://docs.ansible.com/projects/lint/installing/>
- Docker group privilege warning: <https://docs.docker.com/engine/install/linux-postinstall/>
- Docker rootless mode: <https://docs.docker.com/engine/security/rootless/>
- Vault production hardening: <https://developer.hashicorp.com/vault/docs/concepts/production-hardening>
- Vault audit availability guidance: <https://developer.hashicorp.com/vault/docs/audit>
- Packer QEMU builder: <https://developer.hashicorp.com/packer/integrations/hashicorp/qemu/latest/components/builder/qemu>
- Ubuntu autoinstall schema: <https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html>
- Ubuntu NoCloud autoinstall delivery: <https://canonical-subiquity.readthedocs-hosted.com/en/latest/tutorial/providing-autoinstall.html>
- Omnigent shared-server deployment: <https://omnigent.ai/docs/deploy/overview>
- Omnigent Docker deployment files: <https://github.com/omnigent-ai/omnigent/tree/main/deploy/docker>
- Omnigent model credentials: <https://omnigent.ai/docs/build/models>
- Codex keyring credential storage: <https://github.com/openai/codex/blob/main/codex-rs/login/src/auth/storage.rs>
- Claude Code setup: <https://docs.anthropic.com/en/docs/claude-code/getting-started>
