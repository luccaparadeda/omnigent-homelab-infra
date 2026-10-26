#!/usr/bin/env bash
set -euo pipefail

execute=false
compose_dir=""
data_dir=""
bucket=""
age_recipient=""

while (($#)); do
  case "$1" in
    --execute) execute=true; shift ;;
    --compose-dir) compose_dir=${2:?missing compose directory}; shift 2 ;;
    --data-dir) data_dir=${2:?missing data directory}; shift 2 ;;
    --bucket) bucket=${2:?missing bucket}; shift 2 ;;
    --age-recipient) age_recipient=${2:?missing age recipient}; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

: "${compose_dir:?--compose-dir is required}"
: "${data_dir:?--data-dir is required}"
: "${bucket:?--bucket is required}"
: "${age_recipient:?--age-recipient is required}"

timestamp=$(date -u +%Y%m%dT%H%M%SZ)
database_object="logical/omnigent-${timestamp}.dump.age"
application_object="application/omnigent-${timestamp}.tar.age"

if [[ "$execute" != true ]]; then
  echo "DRY RUN: encrypt PostgreSQL from ${compose_dir} and application state from ${data_dir}"
  echo "DRY RUN: upload to oci://${bucket}/${database_object} and oci://${bucket}/${application_object}"
  exit 0
fi

command -v age >/dev/null
command -v docker >/dev/null
command -v oci >/dev/null
test -f "${compose_dir}/compose.yaml"
test -f "${compose_dir}/.env"
test -d "${data_dir}/artifacts"
test -d "${data_dir}/admin-credentials"

database_file=$(mktemp -t omnigent-database.XXXXXX.age)
application_file=$(mktemp -t omnigent-application.XXXXXX.age)
trap 'rm -f "$database_file" "$application_file"' EXIT

docker compose --project-directory "$compose_dir" \
  --env-file "${compose_dir}/.env" \
  -f "${compose_dir}/compose.yaml" exec -T postgres \
  pg_dump -U omnigent -d omnigent -Fc | age -r "$age_recipient" -o "$database_file"

tar --numeric-owner -C "$data_dir" -cf - artifacts admin-credentials | \
  age -r "$age_recipient" -o "$application_file"

oci --auth instance_principal os object put \
  --bucket-name "$bucket" \
  --name "$database_object" \
  --file "$database_file" \
  --force

oci --auth instance_principal os object put \
  --bucket-name "$bucket" \
  --name "$application_object" \
  --file "$application_file" \
  --force

echo "Uploaded encrypted database: oci://${bucket}/${database_object}"
echo "Uploaded encrypted application state: oci://${bucket}/${application_object}"
