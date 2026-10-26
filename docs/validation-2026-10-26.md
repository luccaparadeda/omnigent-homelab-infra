# Local validation evidence — 2026-10-26

Current post-review validation, run without contacting Oracle, starting services,
creating credentials, or building the worker disk.

| Check | Result |
|---|---|
| `make validate` | Passed: staged/unstaged whitespace, secret-pattern scan, ShellCheck, both Compose parses, all YAML, actionlint, static cost/credential/workflow guards, Ansible syntax, and ansible-lint |
| Hash-locked validation environment | Passed: `pip --require-hashes` accepted every package in `requirements-dev.lock` under Python 3.14 |
| Release-script integration test | Passed in a temporary local clone: tag/version/main ancestry check, tagged `.tar.gz` and `.zip` archives, SPDX placeholder checksum inclusion, archive integrity, and SHA-256 verification |
| Initial hosted CI run | Exposed that GitHub's Ubuntu 24.04 image does not include ripgrep by default; fixed by installing it explicitly before repository validation |
| Backup script dry run and `bash -n` | Passed for the timestamp-matched encrypted database/application objects |
| OpenTofu 1.13.0 formatting/validation | Passed with the checksum-verified temporary binary and signed OCI provider 9.11.0; no plan/apply was run |
| Packer 1.16.2 formatting/syntax | Passed with the checksum-verified temporary binary; the worker disk was not built |
| ansible-lint 26.10.1 | Passed with zero failures and zero warnings; the tool reported that the production profile also passed |

Not yet verified because they need deployment-specific inputs or hardware:

- OCI `plan`/`apply`, Always Free capacity, IAM propagation, instance-principal KMS access
- Vault initialization, Transit round-trip, recovery-share custody, and restore
- dedicated home-PC autoinstall, second-pass Ansible idempotency, and hardware smoke tests
- optional worker QCOW2 build/boot if that test path is retained
- Omnigent worker registration and live MCP gateway request
- encrypted backup upload and restore drill
- OCI plan/apply remains intentionally unperformed
- hosted GitHub workflow runs and repository security settings; publication is
  blocked until the owner renews the expired GitHub CLI authentication
