#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

repo_name=${1:-omnigent-homelab-infra}

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  echo "FAIL: authenticate first with: gh auth login --hostname github.com --web" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "FAIL: commit the validated source before publishing" >&2
  exit 1
fi

owner=$(gh api user --jq .login)
target="$owner/$repo_name"

if gh repo view "$target" >/dev/null 2>&1; then
  echo "FAIL: $target already exists; refusing to attach or overwrite it" >&2
  exit 1
fi

if git remote get-url origin >/dev/null 2>&1; then
  echo "FAIL: origin already exists; refusing to replace it" >&2
  exit 1
fi

gh repo create "$target" \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description="Security-first IaC for an Omnigent Oracle Always Free control plane and local workers"

gh repo edit "$target" \
  --enable-issues \
  --enable-wiki=false \
  --add-topic=ansible \
  --add-topic=homelab \
  --add-topic=infrastructure-as-code \
  --add-topic=omnigent \
  --add-topic=opentofu \
  --add-topic=oracle-cloud \
  --add-topic=packer \
  --add-topic=tailscale \
  --add-topic=vault

gh api --method PUT "repos/$target/private-vulnerability-reporting"
gh api --method PUT "repos/$target/vulnerability-alerts"
gh api --method PUT "repos/$target/automated-security-fixes"
gh api --method PUT "repos/$target/immutable-releases"
gh api --method PUT "repos/$target/actions/permissions/workflow" \
  -f default_workflow_permissions=read \
  -F can_approve_pull_request_reviews=false

echo "PASS: published and hardened https://github.com/$target"
echo "NEXT: wait for CI, then run scripts/protect-main-branch.sh $target"
