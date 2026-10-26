#!/usr/bin/env bash
set -euo pipefail

: "${VAULT_COMPOSE_ROOT:=/opt/omnigent-vault}"
: "${VAULT_BACKUP_BUCKET:?Set VAULT_BACKUP_BUCKET}"
: "${VAULT_BACKUP_AGE_RECIPIENT:?Set VAULT_BACKUP_AGE_RECIPIENT}"
: "${VAULT_BACKUP_ROLE:=omnigent-vault-backup}"

for required_command in age docker oci; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "Missing required command: $required_command" >&2
    exit 1
  fi
done

umask 077
backup_tmp=$(mktemp -d)
snapshot_name="vault-raft-$(date -u +%Y%m%dT%H%M%SZ).snap"
snapshot_path="$backup_tmp/$snapshot_name"
encrypted_path="$snapshot_path.age"

cleanup() {
  docker compose --project-directory "$VAULT_COMPOSE_ROOT" \
    exec -T vault rm -f /tmp/omnigent-vault.snap >/dev/null 2>&1 || true
  rm -rf -- "$backup_tmp"
}
trap cleanup EXIT

docker compose --project-directory "$VAULT_COMPOSE_ROOT" \
  exec -T -e VAULT_BACKUP_ROLE="$VAULT_BACKUP_ROLE" vault sh -ec '
    VAULT_TOKEN=$(vault login -method=oci -token-only auth_type=instance role="$VAULT_BACKUP_ROLE")
    export VAULT_TOKEN
    vault operator raft snapshot save /tmp/omnigent-vault.snap
  '

vault_container=$(docker compose --project-directory "$VAULT_COMPOSE_ROOT" ps -q vault)
if [[ -z "$vault_container" ]]; then
  echo "Vault container is not running" >&2
  exit 1
fi

docker cp "$vault_container:/tmp/omnigent-vault.snap" "$snapshot_path"
age --recipient "$VAULT_BACKUP_AGE_RECIPIENT" --output "$encrypted_path" "$snapshot_path"
rm -f -- "$snapshot_path"

oci --auth instance_principal os object put \
  --bucket-name "$VAULT_BACKUP_BUCKET" \
  --name "vault-raft/$snapshot_name.age" \
  --file "$encrypted_path" \
  --force

echo "Uploaded encrypted Vault Raft snapshot: vault-raft/$snapshot_name.age"
