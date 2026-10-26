#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

target=${1:-}
if [[ -z "$target" ]]; then
  target=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
fi

if [[ -z "$(gh run list --repo "$target" --workflow ci.yml --branch main \
  --status success --limit 1 --json databaseId --jq '.[0].databaseId')" ]]; then
  echo "FAIL: main has no successful CI workflow; branch protection was not changed" >&2
  exit 1
fi

payload=$(mktemp)
trap 'rm -f "$payload"' EXIT
printf '%s\n' '{
  "required_status_checks": {
    "strict": true,
    "contexts": ["Validate"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}' > "$payload"

gh api --method PUT "repos/$target/branches/main/protection" --input "$payload"
echo "PASS: protected $target main with required Validate status"
