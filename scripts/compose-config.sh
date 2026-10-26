#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if ! command -v docker >/dev/null 2>&1; then
  echo "SKIP: docker is not installed"
  exit 0
fi

docker compose \
  --env-file "$repo_root/compose/control-plane/.env.example" \
  -f "$repo_root/compose/control-plane/compose.yaml" \
  config --quiet
echo "PASS: control-plane Compose configuration"

docker compose \
  --env-file "$repo_root/compose/vault/.env.example" \
  -f "$repo_root/compose/vault/compose.yaml" \
  config --quiet
echo "PASS: Vault Compose configuration"
