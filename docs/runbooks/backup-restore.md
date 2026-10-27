# Backup and restore

Use two independent recovery layers:

- **Logical backup:** daily PostgreSQL dump plus an artifacts/admin-state archive streamed into separate `age`-encrypted files, then uploaded to a private OCI Object Storage bucket using the control VM's instance principal.
- **Machine recovery point:** labelled OCI boot-volume backups only after image acceptance.

The age private identity remains offline and outside Oracle. A backup that Oracle can decrypt with the same compromised runtime identity is not an independent recovery copy.

## Enable logical backups

Set these in the encrypted production inventory:

```yaml
omnigent_backup_enabled: true
omnigent_backup_bucket: omnigent-homelab-backups
omnigent_backup_age_recipient: age1PUBLIC_RECIPIENT
```

After applying the control-plane role, test the timer and verify that both a
`logical/*.dump.age` object and its matching `application/*.tar.age` object exist.
Never log or retain an unencrypted dump/archive.

## Enable encrypted Vault Raft snapshots

First apply `compose/vault/policies/vault-backup.hcl` and create the
`omnigent-vault-backup` OCI auth role as described in the provisioning
runbook. Grant the Vault VM's instance principal permission to upload objects
only to the backup bucket. Then set:

```yaml
vault_backup_enabled: true
vault_backup_bucket: omnigent-homelab-backups
vault_backup_age_recipient: age1PUBLIC_RECIPIENT
```

Apply the Vault role, start a supervised run, and confirm an encrypted object
appears under `vault-raft/`:

```bash
sudo systemctl start omnigent-vault-backup.service
sudo systemctl status omnigent-vault-backup.service
sudo systemctl list-timers omnigent-vault-backup.timer
```

The job authenticates with the Vault VM's OCI instance principal, creates the
snapshot in a container tmpfs, copies it into `/dev/shm`, encrypts it with the
offline `age` recipient, uploads it, and removes local plaintext on exit. A
host crash or container restart discards both memory-backed plaintext paths;
unique names and an execution lock prevent overlapping jobs from sharing a
snapshot. The systemd service waits for Vault readiness and retries transient
startup failures.

## Create a reviewed boot backup

The helper is dry-run by default:

```bash
./scripts/oci-boot-backup.sh \
  --instance-id ocid1.instance.oc1..example \
  --display-name omnigent-control-known-good-YYYYMMDD
```

Add `--execute` only after checking current backup count and free-tier usage.

## Restore drill

1. Restore into an isolated VCN or disconnected test host.
2. Recover Vault first. For the current manual profile, unseal it with the
   offline recovery material; for an optional KMS profile, verify auto-unseal.
3. Restore the selected database tier (SQLite in the live E2 profile) and
   artifacts without exposing application ports publicly.
4. Validate login, session/artifact integrity, MCP registry metadata, and a test decrypt.
5. Enroll a temporary worker and execute a harmless task.
6. Record RPO/RTO and securely remove the test environment.

Do not call the deployment recoverable until an encrypted off-node Raft
snapshot and restore have both been tested.

An optional auto-unseal deployment depends on its OCI KMS key. Do not delete or
schedule deletion of that key without an explicit seal-migration and restore
plan. The current manual profile instead depends on protected recovery keys.
