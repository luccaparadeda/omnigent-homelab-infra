#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

workflow_dir=.github/workflows

if [[ ! -d "$workflow_dir" ]]; then
  echo "FAIL: workflow directory is missing" >&2
  exit 1
fi

if rg -n 'pull_request_target' "$workflow_dir"; then
  echo "FAIL: pull_request_target is prohibited" >&2
  exit 1
fi

unpinned=$(rg -n '^\s*uses:\s*[^./][^@[:space:]]+@' "$workflow_dir" | \
  grep -Ev '@[0-9a-f]{40}([[:space:]]|$)' || true)
if [[ -n "$unpinned" ]]; then
  echo "$unpinned" >&2
  echo "FAIL: every external GitHub Action must use a full commit SHA" >&2
  exit 1
fi

rg -q '^\s+tags:' .github/workflows/release.yml
rg -q 'actions/attest@[0-9a-f]{40}' .github/workflows/release.yml
rg -q 'spdx-json' .github/workflows/release.yml
rg -q 'SHA256SUMS' .github/workflows/release.yml
rg -q 'gh release create' .github/workflows/release.yml
rg -q '^permissions:$' .github/workflows/ci.yml
rg -q '^  contents: read$' .github/workflows/ci.yml

echo "PASS: GitHub Actions guards"
