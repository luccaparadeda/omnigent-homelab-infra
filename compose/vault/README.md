# Vault Transit node

This is a single-node Vault Community deployment using integrated Raft storage and OCI KMS auto-unseal. It is a key-separation and recoverability design, not a highly available Vault cluster.

Initialization is intentionally not automated. The first initialization creates recovery material that must be transferred directly to an offline password manager or other approved recovery store. Never write it into this repository or a shell-history file.

After initialization:

1. Enable the Transit engine at `transit/`.
2. Create `omnigent-credentials` with `derived=true`.
3. Apply `policies/omnigent-transit.hcl`.
4. Issue Omnigent a narrow token under that policy; do not use the root token.
5. Revoke the initialization root token after creating durable operator access.
6. Enable at least two independently monitored audit devices and configure encrypted log retention.
7. Back up Raft storage and test restoration while the OCI KMS key remains available.

Deleting the OCI auto-unseal key permanently makes the Vault data unrecoverable, including from backups. Protect the KMS key with restrictive IAM and a deletion-prevention process.
