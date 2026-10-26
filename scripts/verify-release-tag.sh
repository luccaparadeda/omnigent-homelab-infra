#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

release_tag=${RELEASE_TAG:-}
version=$(tr -d '[:space:]' < VERSION)

if [[ ! "$release_tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "FAIL: release tag must be an exact vMAJOR.MINOR.PATCH value" >&2
  exit 1
fi

if [[ "$release_tag" != "v$version" ]]; then
  echo "FAIL: tag $release_tag does not match VERSION $version" >&2
  exit 1
fi

if [[ "$(git tag --points-at HEAD | grep -Fx "$release_tag" || true)" != "$release_tag" ]]; then
  echo "FAIL: checked-out commit is not tagged $release_tag" >&2
  exit 1
fi

if git remote get-url origin >/dev/null 2>&1; then
  git fetch --quiet --no-tags origin main
  if ! git merge-base --is-ancestor HEAD origin/main; then
    echo "FAIL: release commit is not reachable from origin/main" >&2
    exit 1
  fi
fi

echo "PASS: release tag $release_tag matches VERSION and HEAD"
