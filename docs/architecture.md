# Architecture

## Roles

### Omnigent control plane

The current control plane runs on an Oracle Ubuntu AMD64 E2 Micro and contains:

- Omnigent server and web application
- persistent SQLite for the 1 GB live profile; PostgreSQL remains an optional
  larger-host profile
- Session artifacts
- MCP registry/gateway integration target (upstream feature; deployment configuration still requires a live acceptance test)
- Encrypted credential records
- Backup and health-check jobs

The container port is bound only to loopback. Tailscale Serve terminates trusted
HTTPS and publishes the UI inside the tailnet for desktop, browser, and mobile
clients; no OCI public ingress rule exposes it.

Native WireGuard remains supported as an operator-managed alternative. Set
`omnigent_tailscale_serve_enabled: false`, bind `omnigent_bind_ip` to the
WireGuard interface address, and place a trusted HTTPS reverse proxy on that
private address. The Omnigent mobile app requires an `https://` URL; binding to
loopback without Tailscale Serve or another proxy is intentionally unreachable.

### Secrets plane

HashiCorp Vault runs on the second AMD64 E2 Micro and exposes only the Transit
operations needed by Omnigent. Its Transit key is created with `derived=true`.
The free live profile uses integrated Raft storage and manual Shamir unseal, so
it has no paid KMS dependency and needs an operator after a Vault-node reboot.
OCI KMS auto-unseal remains an optional future profile; no OCI API private key
is baked into either VM.

The Omnigent database holds ciphertext. Vault holds the encryption key. During a legitimate request, the Omnigent server can ask Vault to decrypt a credential for its owning workspace, user, provider, and account context. Vault therefore improves key separation and encryption at rest, but it does not make a live, fully compromised Omnigent server harmless.

A Vault Proxy sidecar on the control node authenticates with a least-privilege
AppRole whose role ID and secret ID are held in root-readable runtime files. It
renews the short-lived Vault token and forces that token onto requests sent by
Omnigent. No long-lived Vault token is stored in the Omnigent container,
Compose environment, or Ansible inventory.

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

`omni host` is the persistent worker daemon. Omnibox is the separate hard
boundary applied to agent OS tools and declared terminals: Bubblewrap plus
seccomp on Linux and Seatbelt on macOS. The checked-in baseline grants writes
only to the project tree, recursively masks hidden files, and fails closed if
the requested backend is unavailable. Its initial unrestricted network mode is
an explicit compatibility phase for native subscription CLIs; unattended
projects require a reviewed default-deny `egress_rules` profile.

The Omnigent supervisor and MCP server subprocesses are outside Omnibox.
Server-managed MCP credentials avoid copying upstream secrets to workers, but
each MCP process still needs its own filesystem, command, network, and policy
constraints.

On Omnigent 0.19.1 for macOS, the laptop has two separately verified gates.
Keeping Codex's shared SQLite memory database session-local fixes app-server
startup under Seatbelt. Subscription authentication still requires host
`auth.json` read access, which would extend to agent-created subprocesses. The
Mac may remain an enrolled interactive host, but it is not an approved
unattended Codex worker until credential brokering or an equivalent upstream
boundary passes the acceptance test.

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
