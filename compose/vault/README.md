# Vault Transit node

This is a single-node Vault Community deployment using integrated Raft
storage. The live E2 Micro profile uses `compose.manual.yaml` and Shamir manual
unseal to avoid a paid KMS dependency. `compose.yaml` retains optional OCI KMS
auto-unseal for a future reviewed deployment. Neither profile is a highly
available Vault cluster.

Initialization is intentionally not automated. The first initialization creates recovery material that must be transferred directly to an offline password manager or other approved recovery store. Never write it into this repository or a shell-history file.

After initialization:

1. Enable the Transit engine at `transit/`.
2. Create `omnigent-credentials` with `derived=true`.
3. Apply `policies/omnigent-transit.hcl`.
4. For the manual E2 profile, create a least-privilege AppRole for the control
   plane and store its role ID and secret ID only in root-readable runtime
   files. The Vault Proxy exchanges them for short-lived tokens.
5. Create a separate restricted backup identity with only the `vault-backup`
   policy.
6. Never place a static or root Vault token in the Omnigent environment.
7. Revoke the initialization root token after creating durable operator access.
8. Enable at least two independently monitored audit devices and configure encrypted log retention.
9. Enable, inspect, and restore-test the encrypted Raft snapshot timer. For the
   current profile, confirm recovery keys can unseal the restored node.

If the optional OCI auto-unseal profile is adopted, deleting its KMS key can
make Vault data unrecoverable even from backups. Protect that key with
restrictive IAM and deletion prevention.
