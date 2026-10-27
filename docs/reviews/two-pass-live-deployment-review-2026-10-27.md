# Two-pass live deployment review

Date: 2026-10-27

Scope: the two live Oracle E2 Micro nodes, Mac worker enrollment, and the
credential-free source changes prepared on `codex/e2-micro-live-deployment`.

This is an evidence review, not a declaration that the full deployment is
complete. Risky recovery drills and missing external inputs remain explicit
gates.

## Pass 1 — security and reliability

| Severity | Finding | Resolution or gate |
|---|---|---|
| High | A service-disabled Ansible convergence could render the live control-plane or Vault `.env` from empty defaults. | Fixed: both secret environment tasks now run only when their corresponding `*_start_services` flag is true, and static guards cover both conditions. Live check-mode runs confirm both tasks are skipped for non-secret convergence. |
| High | Codex subscription authentication works only if Omnibox can read `~/.codex/auth.json`; every contained process could then read the bearer credential. | Fail closed: the macOS profile does not grant that path. The worker may remain registered, but unattended Codex work is not approved until Omnigent provides a narrow subscription credential broker. |
| High | Public SSH is still accepted by the host policy even though Tailscale SSH works. | Open gate: restrict OCI and host ingress only after a tested console or other recovery path is recorded. The documentation no longer describes this as complete. |
| High | Neither Vault Raft nor Omnigent SQLite has a proven encrypted off-host backup and restore. | Open gate: supply an age public recipient and Oracle Object Storage destination, then exercise both restore runbooks before unattended use. |
| Medium | The dedicated home worker is not enrolled and the laptop worker cannot yet use subscription credentials without broadening its read boundary. | Open gate: enroll the bare-metal Ubuntu home PC when reachable; keep the Mac worker fail closed until credential brokerage is solved. |
| Medium | Single-node Vault requires manual unseal and is an availability bottleneck. | Accepted free-tier tradeoff, conditional on an operator-held recovery procedure, encrypted snapshots, and a successful reboot drill. |

## Pass 2 — reproducibility and publication

| Severity | Finding | Resolution or gate |
|---|---|---|
| High | A macOS workaround that patches two installed Omnigent files could partially apply after discovering a mismatch in the second file. | Fixed: the version/hash-pinned script now preflights every source and backup before changing either file. Each individual replacement is still atomic and reversible. |
| High | Live inventory contains node addresses and a private-key path. | Preserved outside publication: `ansible/inventory/production/` is ignored, and tracked-source scanning contains neither live address nor private-key path. |
| Medium | The initial A1/PostgreSQL design no longer matches the two live E2 Micro nodes. | Fixed: the live profile uses persistent SQLite on the control node and manual-unseal Raft Vault on the second node; architecture and runbooks identify A1 as optional rather than deployed. |
| Medium | Local Packer and OpenTofu validation cannot run when those binaries are absent. | Visible gate: local validation reports those checks as skipped. Hosted CI installs pinned versions and runs their validation; neither tool is used to apply the manual E2 deployment. |
| Medium | The branch was not yet reviewed through GitHub checks. | Open gate: commit only credential-free files, push the topic branch, open a pull request, and require the existing CI/security workflows before merge or release. |

## Verified evidence

- Omnigent `0.19.1` is healthy on the control node through private Tailscale
  HTTPS; its container and Vault Proxy report healthy.
- Vault `2.2.1` is initialized, unsealed, uses Raft, and is healthy on its
  Tailscale-only listener.
- Tailscale SSH reaches both nodes and the control service is not bound to a
  public application address.
- The persistent Mac daemon is running and its current tunnel log records a
  connection. The unauthenticated host-row status probe returns HTTP 401, so an
  authenticated UI/status check remains a gate. Contained Codex completes
  initialization and thread creation, then fails closed with the expected
  missing-authentication response rather than reading the user's subscription
  token.
- The Omnigent compatibility patch is bound to exact package version and full
  source hashes, creates reviewed backups, and supports explicit check, apply,
  and revert operations.
- `make validate`, `git diff --check`, Ansible syntax, ansible-lint, shellcheck,
  Compose validation, YAML parsing, actionlint, and repository policy guards
  pass locally. Packer and OpenTofu are explicitly reported as skipped locally
  when their binaries are unavailable.

## Required gates before claiming end-to-end completion

1. Restrict public SSH with a proven recovery path.
2. Configure encrypted off-host SQLite and Raft backups and prove restore.
3. Perform controlled reboot, Vault unseal, and service recovery drills.
4. Complete authenticated phone, WebSocket, and restart acceptance tests.
5. Enroll and test the dedicated home worker.
6. Resolve subscription credential brokerage without exposing worker tokens.
7. Prove per-project MCP account selection and isolation live.
8. Merge only after GitHub CI and security checks pass.
