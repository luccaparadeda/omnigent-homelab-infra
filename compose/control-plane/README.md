# Omnigent control plane

This Compose file is an operator-owned equivalent of the documented Omnigent server plus PostgreSQL topology. The example binds to loopback; the Ansible role selects the enrolled Tailscale IP.

## Important gates

- The official 0.19.1 image was verified to omit `hvac`. `Dockerfile` creates a small derived image with the official `vault` extra dependency (`hvac` 2.4.0) pinned by wheel hash.
- The upstream server currently defaults to root. The derived image creates and
  runs as UID/GID `10001`; Ansible owns only the artifact and admin-credential
  bind mounts by that identity.
- Re-verify the pinned multi-architecture image digests during each planned version upgrade.
- Do not publish port 8000 through an OCI public security-list rule.
- Let the Ansible role create storage paths and install the Vault CA before starting the stack.
- Complete the admin bootstrap while access remains private.

To parse the file without starting containers, run `make compose-config` at the repository root.
