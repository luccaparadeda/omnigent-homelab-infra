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
2. Recover Vault first and verify OCI KMS auto-unseal still works.
3. Restore PostgreSQL and artifacts without exposing application ports publicly.
4. Validate login, session/artifact integrity, MCP registry metadata, and a test decrypt.
5. Enroll a temporary worker and execute a harmless task.
6. Record RPO/RTO and securely remove the test environment.

Vault Raft snapshots are a separate required recovery stream. They are not yet
automated by this repository because the snapshot job needs a narrowly scoped
Vault token and bucket access for the Vault instance principal. Do not call the
deployment recoverable until an encrypted off-node Raft snapshot and restore
have both been tested.

Vault recovery depends on the OCI KMS key. Do not delete or schedule deletion of that key without an explicit seal-migration and restore plan.
