# Vault Transit node

This is a single-node Vault Community deployment using integrated Raft storage and OCI KMS auto-unseal. It is a key-separation and recoverability design, not a highly available Vault cluster.

Initialization is intentionally not automated. The first initialization creates recovery material that must be transferred directly to an offline password manager or other approved recovery store. Never write it into this repository or a shell-history file.

After initialization:

1. Enable the Transit engine at `transit/`.
2. Create `omnigent-credentials` with `derived=true`.
3. Apply `policies/omnigent-transit.hcl`.
4. Enable the OCI auth method and map the control VM's dynamic group to an
   `omnigent-control` role with only the `omnigent-transit` policy.
5. Map the Vault VM's dynamic group to an `omnigent-vault-backup` role with
   only the `vault-backup` policy.
6. Let the control-plane Vault Proxy authenticate with OCI instance identity;
   never place a static or root Vault token in the Omnigent environment.
7. Revoke the initialization root token after creating durable operator access.
8. Enable at least two independently monitored audit devices and configure encrypted log retention.
9. Enable, inspect, and restore-test the encrypted Raft snapshot timer while
   the OCI KMS key remains available.

Deleting the OCI auto-unseal key permanently makes the Vault data unrecoverable, including from backups. Protect the KMS key with restrictive IAM and a deletion-prevention process.
