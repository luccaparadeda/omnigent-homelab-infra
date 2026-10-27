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
                           Tailscale by default

  phone / browser ────────────── Omnigent control plane (OCI E2 Micro)
                                      │
                                      ├── persistent SQLite + artifacts
                                      ├── MCP registry / gateway
                                      └── encrypted credential records
                                                   │
                                             Vault Transit
                                        (second OCI E2 Micro,
                                           manual unseal)

                         encrypted runner tunnels
                               │             │
                        home PC worker   laptop worker
                        scheduled work   interactive work
                        subscription     subscription
                        CLI keyring      CLI keyring
```

Omnigent and Vault stay on separate Oracle VMs. The live deployment uses two
AMD64 `VM.Standard.E2.1.Micro` instances, each with 1 OCPU, 1 GB RAM, and a
45 GB boot disk. The unavailable Ampere A1 design is retained only as research,
not described as deployed capacity.

The VMs were created manually in the Oracle Console and are configured through
their private Tailscale addresses. OpenTofu remains an optional, disabled-by-
default path for a future reproducible VM lifecycle; Ansible is authoritative
for the current host configuration.

## Golden build model

The word *image* means a reproducible, credential-free build:

- `images/worker/autoinstall/`: primary credential-free Ubuntu installer seed for the dedicated bare-metal home worker.
- `images/worker/worker.pkr.hcl`: optional QEMU/KVM image for testing or a future virtual worker.
- `images/vps/`: architecture-neutral cloud-init baseline for Oracle Ubuntu
  instances.
- `compose/control-plane/`: pinned Omnigent application layer with a low-memory
  SQLite profile and an optional PostgreSQL profile.
- `compose/vault/`: Vault Transit service with the current manual-unseal profile
  and an optional future OCI KMS profile.
- `infra/oci/`: reviewed OpenTofu inputs and topology skeleton. It is not applied automatically.

OCI recovery then adds a boot-volume backup after the baseline passes validation. Secrets are enrolled after imaging and are never baked into an image.

Model execution uses the user's existing Codex and Claude subscription logins,
not paid model API keys. Those native CLI sessions remain worker-local in a
password-unlocked OS keyring; managed MCP credentials remain server-side.

## Repository status

| Area | Status | Important boundary |
|---|---|---|
| Source repository | MIT-licensed GitHub repository with validation and tag-release workflows | CI holds no deployment credentials and cannot deploy infrastructure |
| Bare-metal home worker | Guarded autoinstall seed + Ansible role validated | Not installed; storage selection remains deliberately interactive |
| Worker QEMU definition | Packer 1.16.2 format/syntax passed | Image not built; versioned source checksum, QEMU, and ephemeral build key are required |
| Oracle VMs | Two E2 Micro nodes created manually in São Paulo | Public SSH closure is still a completion gate |
| Omnigent control plane | Version 0.19.1 healthy over private Tailscale HTTPS with persistent SQLite | Full restart and restore drill remains pending |
| Vault credential plane | Transit and restricted AppRole path active; Vault currently unsealed | Manual unseal is required after reboot; recovery drill remains pending |
| Laptop worker | Persistent daemon runs and its tunnel log records a connection; the unauthenticated CLI status probe receives HTTP 401 | Codex startup workaround verified, but secure subscription credential delivery is blocked on macOS 0.19.1 |
| OCI OpenTofu | Provider/schema validated | `enable_create=false`; it did not create the manual live VMs |
| Backup/restore | Encrypted backup jobs defined | Age recipient, off-host bucket, and restore evidence are not configured |

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

## Remaining rollout gates

1. Close public SSH only after private Tailscale SSH and a recovery path have
   both been re-verified.
2. Configure an age recipient and off-host backup destination, then complete
   SQLite and Vault Raft restore drills.
3. Reboot both Oracle nodes, manually unseal Vault, and verify Omnigent health,
   private HTTPS, and credential operations after recovery.
4. Install the dedicated worker with full-disk encryption from the guarded
   autoinstall seed, apply Ansible twice, and verify that it contains no
   credential material or rootful Docker access for the worker user.
5. After boot, unlock the Linux worker keyring interactively and enroll Codex
   and Claude subscription sessions locally.
6. Resolve the documented macOS Omnigent/Codex credential-broker gate before
   allowing unattended Codex work on the laptop.
7. Run a real agent session on each approved worker before enabling schedules.

See [architecture.md](docs/architecture.md) and the runbooks under [docs/runbooks](docs/runbooks/).

## License

Released under the [MIT License](LICENSE).
