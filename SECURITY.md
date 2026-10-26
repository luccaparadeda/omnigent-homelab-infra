# Security model

## Reporting a vulnerability

Do not open a public issue for vulnerabilities, exposed secrets, or plausible
exploit chains. Use GitHub's **Security > Report a vulnerability** form so the
maintainers can investigate privately. If private vulnerability reporting is
temporarily unavailable, open a content-free issue asking a maintainer for a
private channel; do not include technical details.

Security fixes are supported on the latest tagged release and the current
`main` branch. Infrastructure remains the operator's responsibility: review a
plan, backups, and local policy before applying any release.

## Trust boundaries

- The Oracle Omnigent server stores session history, artifacts, account state, and encrypted integration credentials.
- HashiCorp Vault Transit protects the encryption keys used by Omnigent. OCI KMS protects Vault's auto-unseal material.
- The home PC and laptop are execution hosts. Project files and native harness processes live on those machines.
- Managed MCP calls are routed through the server gateway so their upstream credentials do not need to be copied to workers.
- Native Claude/Codex subscription OAuth logins are host-local. This design
  deliberately uses the user's existing subscriptions and no paid model API
  keys.

## Prohibited repository content

Never commit:

- `.env` files or populated `tfvars`
- Oracle OCIDs that identify private resources when the repository is intended to become public
- SSH private keys, API signing keys, Vault tokens, recovery shares, or root tokens
- Provider API keys, MCP bearer tokens, OAuth refresh tokens, or database passwords
- OpenTofu state, VM disks, volume backups, database dumps, or decrypted backup archives

## Runtime rules

- Omnigent, Vault, PostgreSQL, and SSH must not be exposed directly to the public internet.
- Use a private VPN and keep Omnigent authentication enabled as a second boundary.
- Use separate revocable identities for the home PC and laptop.
- Store native subscription credentials only in a password-unlocked OS keyring
  on a full-disk-encrypted worker. Codex is configured to fail closed rather
  than fall back to a plaintext file.
- Do not grant the subscription-authenticated worker account membership in the
  rootful Docker group. Rootless containers require a separate compatibility
  test before use.
- A human must unlock the encrypted disk and credential keyring after a boot.
  The worker can run unattended while they remain unlocked; requiring a human
  password for every use is incompatible with unattended schedules.
- Use least-privilege accounts for server-managed MCP connections.
- Require approval for deployments, destructive commands, external messages, purchases, and credential changes.
- Backups containing session history or artifacts must be encrypted before leaving the server.

## Incident response

If a credential appears in a terminal transcript, Git history, image, or backup log, treat it as compromised: revoke it at the provider, issue a replacement, and verify the old credential is rejected before resuming unattended work.

If a worker is lost or suspected compromised, revoke its Omnigent host identity,
log out or revoke both native subscription sessions, rotate any Git identity,
and remove the device from the private network before reenrolling it.
