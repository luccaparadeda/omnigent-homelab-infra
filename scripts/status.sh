#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

printf '%-20s %s\n' "Repository" "$repo_root"
printf '%-20s %s\n' "Git branch" "$(git branch --show-current 2>/dev/null || echo not-initialized)"

for tool in git docker shellcheck tofu ansible-playbook ansible-lint packer qemu-system-x86_64; do
  if command -v "$tool" >/dev/null 2>&1; then
    version=$($tool --version 2>&1 | head -n 1)
    printf '%-20s %s\n' "$tool" "$version"
  else
    printf '%-20s %s\n' "$tool" "NOT INSTALLED"
  fi
done

printf '\nSafety defaults\n'
printf '%-20s %s\n' "OCI creation" "disabled (enable_create=false)"
printf '%-20s %s\n' "Services" "disabled in example inventory"
printf '%-20s %s\n' "Git remote" "$(git remote -v 2>/dev/null | head -n 1 || true)"
