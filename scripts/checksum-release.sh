#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

if ! compgen -G 'dist/*.tar.gz' >/dev/null || \
   ! compgen -G 'dist/*.zip' >/dev/null || \
   ! compgen -G 'dist/*.spdx.json' >/dev/null; then
  echo "FAIL: release bundles and SBOM must exist before checksumming" >&2
  exit 1
fi

cd dist
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum ./*.tar.gz ./*.zip ./*.spdx.json > SHA256SUMS
else
  shasum -a 256 ./*.tar.gz ./*.zip ./*.spdx.json > SHA256SUMS
fi

echo "PASS: wrote dist/SHA256SUMS"
