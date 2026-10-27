# Live deployment plan: Oracle E2 Micro pair

This runbook tracks the first live deployment to the two Oracle instances that
were created manually in `sa-saopaulo-1` on 2026-10-26.

## Fixed facts

| Role | Hostname | Shape | Architecture | Memory | Boot disk |
|---|---|---|---|---:|---:|
| Omnigent control plane | `omnigent-server` | `VM.Standard.E2.1.Micro` | `amd64` | 1 GB | 45 GB |
| Private network and credential plane | `omnigent-vpn` | `VM.Standard.E2.1.Micro` | `amd64` | 1 GB | 45 GB |

The original A1 plan is not used for this deployment. A single 1 GB control
node cannot safely run Omnigent, PostgreSQL, and Vault together. The live
profile therefore uses Omnigent's supported persistent SQLite tier on the
control node and a single Vault Transit node on the second VM.

## Security and availability decisions

- Tailscale is the only application ingress path. Omnigent remains bound to
  loopback and is published with private Tailscale HTTPS.
- Public SSH is intended to be bootstrap-only. Tailscale SSH is proven, but
  host policy still accepts TCP/22 on all interfaces. Restricting OCI and host
  ingress remains a deployment gate and must retain a tested recovery path.
- Vault listens only on its Tailscale address. The tailnet provides encrypted
  transport; Vault still encrypts credential records with a derived Transit
  key.
- Vault uses integrated Raft storage and manual Shamir unseal for the initial
  free deployment. This avoids a paid KMS dependency. After a Vault-node
  reboot, an operator must unseal it before managed credentials work.
- Omnigent authenticates to Vault through a local Vault Proxy using AppRole.
  The role ID and secret ID are root-readable files on the control VM; no
  long-lived Vault token is written into the Omnigent environment.
- Initial Vault recovery material and the Omnigent administrator password must
  be transferred to the operator's password manager. They are never committed
  or baked into an image.
- Agent model logins remain on execution workers. The servers receive no Codex
  or Claude subscription credentials.

## Execution stages

1. **Repository reconciliation**
   - Add an E2 Micro deployment profile.
   - Make SQLite and AppRole/Vault Proxy first-class supported options.
   - Add firewall, low-memory, health, and recovery checks.
   - Run the complete local validation suite.
2. **Non-secret server bootstrap**
   - Apply the common, Docker, control-plane, and Vault roles with services
     disabled.
   - Install Tailscale, Docker, unattended upgrades, and hardened SSH config.
   - Re-run Ansible to prove idempotence.
3. **Private network enrollment**
   - Enroll both VMs in the operator's tailnet.
   - Enable MagicDNS and HTTPS in the Tailscale administration console.
   - Verify SSH over Tailscale from the operator machine.
4. **Credential plane activation**
   - Start Vault on its private address.
   - Initialize and unseal Vault without printing recovery material.
   - Enable Transit, create the derived credential key, policy, and AppRole.
   - Start the control-node Vault Proxy and verify a restricted encrypt/decrypt
     round trip.
5. **Control plane activation**
   - Generate a root-only server environment with persistent SQLite.
   - Start the pinned Omnigent image and publish it with Tailscale Serve.
   - Create the first administrator interactively and verify authenticated
     browser, mobile, API, restart, and WebSocket behavior.
6. **Worker enrollment**
   - Enroll the current laptop as `laptop-worker` after its local subscription
     CLIs and keyring have been verified.
   - Apply the credential-free worker role to the dedicated Linux home PC and
     enroll it as `home-worker` when that machine is reachable.
   - Run a real agent job on each worker and capture completion evidence.
7. **Recovery and publication**
   - Configure encrypted off-host backups after an age recipient and Oracle
     Object Storage bucket are supplied.
   - Test SQLite and Vault snapshot restores.
   - Reboot both servers, unseal Vault, and confirm recovery.
   - Update architecture/status documentation, run two final reviews, and
     publish only credential-free changes.

## Status recorded on 2026-10-27

| Stage | State | Evidence or remaining gate |
|---|---|---|
| Repository reconciliation | Complete locally | E2 Micro profiles, SQLite, AppRole/Vault Proxy, macOS worker compatibility, and static guards are present; `make validate` passes. |
| Non-secret server bootstrap | Complete | Both E2 Micro nodes run Docker, Tailscale, automatic security updates, and the intended services. |
| Private network enrollment | Complete | Both nodes and the Mac are in the tailnet; Tailscale SSH and private MagicDNS addresses work. |
| Credential plane activation | Complete, single-node | Vault is initialized, unsealed, healthy, uses Raft, and is reachable only on its Tailscale address. Manual unseal is still required after reboot. |
| Control plane activation | Partially complete | Omnigent 0.19.1 is healthy through private Tailscale HTTPS. Authenticated phone, WebSocket, and reboot acceptance tests remain. |
| Worker enrollment | Blocked at credential boundary | The Mac daemon runs and its tunnel log records a connection. The unauthenticated CLI status probe receives HTTP 401, and Omnigent 0.19.1 cannot safely broker the ChatGPT subscription credential. The home PC is not yet reachable. |
| Recovery and publication | In progress | Encrypted off-host backups, restore drills, reboot drills, public-SSH restriction, commit, and pull request remain. |

## Completion evidence

Deployment is complete only when all of the following are recorded:

- both nodes converge on a second Ansible run;
- public application ports are unreachable and private HTTPS works;
- Vault is initialized, unsealed, policy-scoped, and survives restart;
- Omnigent reports healthy after restart and credentials decrypt only through
  the expected workspace/user/provider/account context;
- the phone UI can reach the server through the tailnet;
- one real session completes on each enrolled worker;
- encrypted backup and restore drills pass;
- `make validate` passes and the public repository contains no secrets.
