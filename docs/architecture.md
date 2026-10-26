# Architecture

## Roles

### Omnigent control plane

The control plane runs on Oracle Ubuntu ARM64 and contains:

- Omnigent server and web application
- PostgreSQL
- Session artifacts
- MCP registry/gateway integration target (upstream feature; deployment configuration still requires a live acceptance test)
- Encrypted credential records
- Backup and health-check jobs

The container port is bound only to loopback. Tailscale Serve terminates trusted
HTTPS and publishes the UI inside the tailnet for desktop, browser, and mobile
clients; no OCI public ingress rule exposes it.

### Secrets plane

HashiCorp Vault runs as a separate logical service and exposes only the Transit operations needed by Omnigent. Its Transit key must be created with `derived=true`. Vault uses OCI KMS auto-unseal with an instance principal; no OCI API private key is baked into the VM.

The Omnigent database holds ciphertext. Vault holds the encryption key. During a legitimate request, the Omnigent server can ask Vault to decrypt a credential for its owning workspace, user, provider, and account context. Vault therefore improves key separation and encryption at rest, but it does not make a live, fully compromised Omnigent server harmless.

A Vault Proxy sidecar on the control node authenticates through Vault's OCI
auth method using the VM's automatically rotated instance principal. It
renews the short-lived Vault token and forces that token onto requests sent by
Omnigent. No static Vault token or OCI API private key is stored in the
Omnigent container, Compose environment, or Ansible inventory.

### Execution workers

The home PC and laptop register independently as Omnigent hosts:

- `home-worker`: preferred target for schedules and long-running tasks.
- `laptop-worker`: selected manually for interactive and portable work.

Each worker has its own checkout. Git branches and random worktrees coordinate
changes; filesystems are not shared between machines. The home PC is dedicated
exclusively to agent workloads, so the physical machine itself is the
containment boundary. Its subscription-authenticated worker account is not a
member of the rootful Docker group: that privilege would allow an agent to
become root and bypass user/keyring isolation. Personal files, daily-use
accounts, and unrelated credentials must not be placed there.

## Credential classes

| Class | Storage | Delivery |
|---|---|---|
| MCP OAuth/bearer credentials | Omnigent credential store encrypted by Vault Transit | MCP calls stay behind the server gateway |
| Model authentication | Existing Codex and Claude subscriptions; no paid model API keys | Native CLI reads the worker OS keyring |
| Native CLI subscription login | Password-unlocked OS keyring on an encrypted worker disk | Human unlock after boot; available to that worker user while unlocked |
| Git device identity | Worker OS credential store or future broker | Separate per-device key/token |
| Backup encryption identity | Offline recovery store plus server-side recipient configuration | Only encrypted archives leave the server |

## Availability model

The Oracle control plane can remain online while workers disconnect. A scheduled task pinned to a disconnected host fails; it does not transparently migrate to another machine. The laptop is therefore not an automatic failover target.

Oracle Always Free resources may be reclaimed and provide no high-availability guarantee. Recovery automation and tested backups are part of the design, not optional enhancements.

## Image lifecycle

1. Update version pins and provisioning code.
2. Run `make validate`.
3. Build a credential-free worker image or reprovision an Oracle test instance.
4. Run the acceptance tests in `docs/runbooks/image-acceptance.md`.
5. Enroll the machine with a unique host identity.
6. For OCI, create a labelled boot-volume backup only after acceptance succeeds.
7. Keep the previous known-good image or backup until the new version passes a restore drill.
