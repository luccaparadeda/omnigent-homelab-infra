#!/usr/bin/env bash
set -euo pipefail

: "${OMNIGENT_VERSION:?OMNIGENT_VERSION is required}"
: "${UBUNTU_IMAGE_RELEASE:?UBUNTU_IMAGE_RELEASE is required}"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential \
  ca-certificates \
  curl \
  docker.io \
  docker-compose-v2 \
  git \
  jq \
  pipx \
  python3-dev \
  python3-venv \
  ripgrep \
  rsync \
  tmux \
  unattended-upgrades

sudo systemctl enable docker unattended-upgrades
sudo env PIPX_HOME=/opt/omnigent-pipx PIPX_BIN_DIR=/usr/local/bin \
  pipx install "omnigent==${OMNIGENT_VERSION}"

sudo install -d -m 0750 /var/lib/omnigent-worker/projects
sudo tee /etc/omnigent-image-release >/dev/null <<EOF
IMAGE_ROLE=worker
BASE_OS=ubuntu-24.04
UBUNTU_IMAGE_RELEASE=${UBUNTU_IMAGE_RELEASE}
OMNIGENT_VERSION=${OMNIGENT_VERSION}
BUILT_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

# Record the resolved package set so a built artifact is auditable even though
# Ubuntu security repositories intentionally advance between image releases.
sudo dpkg-query -W -f='${Package}\t${Version}\n' | sudo tee /etc/omnigent-image-packages.tsv >/dev/null

# The image remains credential-free. Ansible creates the runtime user and
# `omni login`/`omni host enable` enrolls a unique identity after first boot.
