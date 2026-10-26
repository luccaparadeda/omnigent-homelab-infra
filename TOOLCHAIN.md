# Toolchain decisions (2026-10-26)

| Layer | Pin | Why it owns this layer |
|---|---:|---|
| OCI Resource Manager / Terraform | 1.5.7 target | Recommended managed state, locking, and reviewed OCI plans after the first manual deployment |
| OpenTofu | 1.13.x optional skeleton | Local/open-source OCI lifecycle path; not a prerequisite and not the current first-deployment recommendation |
| OCI provider | 9.11.0 | Signed version resolved from the registry during local validation |
| Ansible Core | 2.21.5 | Idempotent operating-system and service configuration on cloud or manually created hosts |
| ansible-lint | 26.10.1 | Static Ansible quality checks; direct tool versions are pinned in `requirements-dev.txt` |
| Packer | 1.16.2 | Credential-free QEMU/KVM worker disk image only |
| QEMU plugin | 1.1.7 | Current Packer QEMU builder |
| cloud-init | Ubuntu 24.04 platform version | Minimal first-boot user/Python baseline before Ansible |
| Docker Compose | v2 from Ubuntu | Small application layer for Omnigent/PostgreSQL and Vault |
| Vault Community | 2.2.1 | Transit encryption and OCI KMS auto-unseal |
| GitHub Actions | Full commit SHAs | Prevent mutable action tags from changing executed CI code |
| Python validation dependencies | `requirements-dev.lock` hashes | Reproducible CI installation with `pip --require-hashes` |
| actionlint | 1.7.10 | Parse and statically validate GitHub Actions workflows in local and hosted CI |

Terraform/OpenTofu does not configure the guest OS. Ansible does not create Oracle resources unless we later add the OCI collection for a specific need. Packer does not contain deployment credentials. This division keeps manual Oracle Console creation and managed IaC recovery paths usable without making OpenTofu mandatory.

Version updates are reviewable changes. Container tags should be converted to verified multi-architecture digests before live deployment.
