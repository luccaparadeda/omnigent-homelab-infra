#!/usr/bin/env bash
set -euo pipefail

: "${VAULT_COMPOSE_ROOT:=/opt/omnigent-vault}"
: "${VAULT_BACKUP_BUCKET:?Set VAULT_BACKUP_BUCKET}"
: "${VAULT_BACKUP_AGE_RECIPIENT:?Set VAULT_BACKUP_AGE_RECIPIENT}"
: "${VAULT_BACKUP_ROLE:=omnigent-vault-backup}"

for required_command in age docker flock oci; do
  if ! command -v "$required_command" >/dev/null 2>&1; then
    echo "Missing required command: $required_command" >&2
    exit 1
  fi
done

umask 077
exec 9>/run/lock/omnigent-vault-backup.lock
if ! flock -n 9; then
  echo "Another Vault snapshot job is already running; skipping this invocation."
  exit 0
fi

if [[ ! -d /dev/shm ]]; then
  echo "/dev/shm is required so plaintext snapshots remain memory-backed" >&2
  exit 1
fi

backup_tmp=$(mktemp -d /dev/shm/omnigent-vault-backup.XXXXXX)
run_suffix=${backup_tmp##*.}
snapshot_name="vault-raft-$(date -u +%Y%m%dT%H%M%SZ)-$run_suffix.snap"
container_snapshot="/vault/snapshots/$snapshot_name"
snapshot_path="$backup_tmp/$snapshot_name"
encrypted_path="$snapshot_path.age"

cleanup() {
  docker compose --project-directory "$VAULT_COMPOSE_ROOT" \
    exec -T -e VAULT_SNAPSHOT_PATH="$container_snapshot" \
    vault sh -ec 'rm -f -- "$VAULT_SNAPSHOT_PATH"' >/dev/null 2>&1 || true
  rm -rf -- "$backup_tmp"
}
trap cleanup EXIT

vault_ready=false
for attempt in $(seq 1 30); do
  if docker compose --project-directory "$VAULT_COMPOSE_ROOT" \
    exec -T vault vault status >/dev/null 2>&1; then
    vault_ready=true
    break
  fi
  if [[ "$attempt" -lt 30 ]]; then
    sleep 10
  fi
done

if [[ "$vault_ready" != true ]]; then
  echo "Vault did not become ready within five minutes" >&2
  exit 1
fi

docker compose --project-directory "$VAULT_COMPOSE_ROOT" \
  exec -T vault find /vault/snapshots -type f -name 'vault-raft-*.snap' -mmin +60 -delete

docker compose --project-directory "$VAULT_COMPOSE_ROOT" \
  exec -T -e VAULT_BACKUP_ROLE="$VAULT_BACKUP_ROLE" \
  -e VAULT_SNAPSHOT_PATH="$container_snapshot" vault sh -ec '
    VAULT_TOKEN=$(vault login -method=oci -token-only auth_type=instance role="$VAULT_BACKUP_ROLE")
    export VAULT_TOKEN
    vault operator raft snapshot save "$VAULT_SNAPSHOT_PATH"
  '

vault_container=$(docker compose --project-directory "$VAULT_COMPOSE_ROOT" ps -q vault)
if [[ -z "$vault_container" ]]; then
  echo "Vault container is not running" >&2
  exit 1
fi

docker cp "$vault_container:$container_snapshot" "$snapshot_path"
age --recipient "$VAULT_BACKUP_AGE_RECIPIENT" --output "$encrypted_path" "$snapshot_path"
rm -f -- "$snapshot_path"

oci --auth instance_principal os object put \
  --bucket-name "$VAULT_BACKUP_BUCKET" \
  --name "vault-raft/$snapshot_name.age" \
  --file "$encrypted_path" \
  --force

echo "Uploaded encrypted Vault Raft snapshot: vault-raft/$snapshot_name.age"
