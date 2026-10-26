#!/usr/bin/env bash
set -euo pipefail

execute=false
instance_id=""
display_name=""

while (($#)); do
  case "$1" in
    --execute) execute=true; shift ;;
    --instance-id) instance_id=${2:?missing instance OCID}; shift 2 ;;
    --display-name) display_name=${2:?missing display name}; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

: "${instance_id:?--instance-id is required}"
: "${display_name:?--display-name is required}"

if [[ "$execute" != true ]]; then
  echo "DRY RUN: locate the boot volume attached to ${instance_id} and create backup ${display_name}"
  exit 0
fi

command -v oci >/dev/null
boot_volume_id=$(oci compute boot-volume-attachment list \
  --instance-id "$instance_id" \
  --query 'data[0]."boot-volume-id"' \
  --raw-output)

if [[ -z "$boot_volume_id" || "$boot_volume_id" == null ]]; then
  echo "No boot volume attachment found for ${instance_id}" >&2
  exit 1
fi

oci bv boot-volume-backup create \
  --boot-volume-id "$boot_volume_id" \
  --display-name "$display_name" \
  --type FULL
