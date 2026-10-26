# Omnigent homelab infrastructure

[![CI](https://github.com/luccaparadeda/omnigent-homelab-infra/actions/workflows/ci.yml/badge.svg)](https://github.com/luccaparadeda/omnigent-homelab-infra/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/luccaparadeda/omnigent-homelab-infra/badge)](https://securityscorecards.dev/viewer/?uri=github.com/luccaparadeda/omnigent-homelab-infra)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Reproducible infrastructure and credential-free golden configurations for an Omnigent control plane on Oracle Cloud and two execution workers: an always-on dedicated home PC and a portable laptop.

This is an independent community project and is not affiliated with or endorsed
by Omnigent, Oracle, HashiCorp, OpenAI, Anthropic, or Tailscale. It contains no
credentials and does not deploy from CI.

## Target architecture

```text
                                  private VPN
                        Tailscale or native WireGuard

  phone / browser ────────────── Omnigent control plane (OCI)
                                      │
                                      ├── PostgreSQL + artifacts
                                      ├── MCP registry / gateway
                                      └── encrypted credential records
                                                   │
                                             Vault Transit
                                                   │
                                           OCI KMS auto-unseal

                         encrypted runner tunnels
                               │             │
                        home PC worker   laptop worker
                        scheduled work   interactive work
                        subscription     subscription
                        CLI keyring      CLI keyring
```

Omnigent and Vault stay on separate Oracle VMs. The current Always Free allocation is exactly 2 OCPUs / 12 GB across both Ampere A1 instances: 1 OCPU / 8 GB for the control plane and 1 OCPU / 4 GB for Vault.

For the first deployment, create the scarce Always Free instances in the Oracle Console and give Ansible their private Tailscale addresses. The current OpenTofu skeleton remains an optional local path. The researched steady-state target is an OCI Resource Manager Terraform stack after the manual topology has been proven; everything above the base VM remains the same.

## Golden build model

The word *image* means a reproducible, credential-free build:

- `images/worker/autoinstall/`: primary credential-free Ubuntu installer seed for the dedicated bare-metal home worker.
- `images/worker/worker.pkr.hcl`: optional QEMU/KVM image for testing or a future virtual worker.
- `images/vps/`: cloud-init baseline applied to Oracle Ubuntu ARM64 instances.
- `compose/control-plane/`: pinned Omnigent/PostgreSQL application layer.
- `compose/vault/`: Vault Transit service, auto-unsealed by OCI KMS.
- `infra/oci/`: reviewed OpenTofu inputs and topology skeleton. It is not applied automatically.

OCI recovery then adds a boot-volume backup after the baseline passes validation. Secrets are enrolled after imaging and are never baked into an image.

Model execution uses the user's existing Codex and Claude subscription logins,
not paid model API keys. Those native CLI sessions remain worker-local in a
password-unlocked OS keyring; managed MCP credentials remain server-side.

## Repository status

| Area | Status | Important boundary |
|---|---|---|
| Source repository | MIT-licensed and prepared for public GitHub hosting | No infrastructure deployment workflow exists |
| Bare-metal home worker | Guarded autoinstall seed + Ansible role validated | Not installed; storage selection remains deliberately interactive |
| Worker QEMU definition | Packer 1.16.2 format/syntax passed | Image not built; versioned source checksum, QEMU, and ephemeral build key are required |
| VPS cloud-init baseline | OpenTofu 1.13.0 schema validated | No VM launched |
| Omnigent Compose stack | Compose parsed; ARM64 Vault-enabled image built and import-smoked | No service started |
| Vault Compose stack | Compose parsed | Not initialized; no recovery material exists |
| OCI OpenTofu | Provider/schema validated | `enable_create=false` by default; no plan/apply performed |
| Ansible roles | Syntax validated with Core 2.21.5 | No host contacted |
| Backup/restore | Encrypted PostgreSQL + application-state job defined | No bucket or backup created; Vault Raft snapshot automation remains a deployment gate |

## Quick start for repository development

```bash
make validate
make status
```

`make validate` runs local, non-mutating checks. When Packer or OpenTofu is not installed, their checks are reported as skipped rather than silently treated as passed.

See [the dated research](docs/research-2026-10-26.md), [the open-source project comparison](docs/research-open-source-projects-2026-10-26.md), [the two-pass IaC review](docs/reviews/two-pass-iac-review-2026-10-26.md), [the two-pass publication review](docs/reviews/two-pass-publication-review-2026-10-26.md), [the subscription credential decision](docs/decisions/subscription-cli-credentials.md), [toolchain pins](TOOLCHAIN.md), and [provisioning runbook](docs/runbooks/provision.md) before choosing the manual or managed-IaC route.

## CI and releases

CI validates Ansible, OpenTofu, Packer, Compose, YAML, shell, free-tier guards,
and GitHub workflow policy without contacting deployment targets. Separate
workflows run CodeQL, Trivy configuration scanning, dependency review, and the
OpenSSF Scorecard. External actions are pinned to immutable commit SHAs and the
Python validation environment is hash locked.

A release is created only by an exact `vMAJOR.MINOR.PATCH` tag that matches
`VERSION`. The release workflow reruns validation and publishes source archives,
SHA-256 checksums, an SPDX JSON SBOM, and GitHub artifact attestations. It has no
OCI, Vault, Tailscale, or worker credentials. See
[the release guide](docs/maintainers/releases.md).

## Before any deployment

1. Confirm the CPU architecture and operating system of the home PC and laptop.
2. Confirm the Oracle tenancy home region, availability domain, and Always Free capacity.
3. Re-verify the pinned multi-architecture container digests for the planned release.
4. Decide between Tailscale and native WireGuard.
5. Create or select an OCI compartment, then review IAM, KMS, Object Storage, and backup retention.
6. Install the dedicated worker with full-disk encryption from the guarded
   autoinstall seed, apply Ansible twice, and verify that it contains no
   credential material or rootful Docker access for the worker user.
7. After boot, unlock the OS keyring interactively and enroll Codex and Claude
   subscription sessions locally. Deploy the control plane privately, then
   enroll managed MCP credentials through the Omnigent UI.
8. Complete the backup and restore drill before enabling unattended schedules.

See [architecture.md](docs/architecture.md) and the runbooks under [docs/runbooks](docs/runbooks/).

## License

Released under the [MIT License](LICENSE).
