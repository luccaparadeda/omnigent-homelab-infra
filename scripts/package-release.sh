#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

version=$(tr -d '[:space:]' < VERSION)
release_tag=${RELEASE_TAG:-v$version}
bundle="omnigent-homelab-infra-$release_tag"

if [[ "$release_tag" != "v$version" ]]; then
  echo "FAIL: RELEASE_TAG does not match VERSION" >&2
  exit 1
fi

if ! git rev-parse --verify --quiet "refs/tags/$release_tag" >/dev/null; then
  echo "FAIL: tag $release_tag does not exist" >&2
  exit 1
fi

mkdir -p dist
git archive --format=tar.gz --prefix="$bundle/" \
  --output="dist/$bundle.tar.gz" "$release_tag"
git archive --format=zip --prefix="$bundle/" \
  --output="dist/$bundle.zip" "$release_tag"

echo "PASS: packaged $release_tag"
