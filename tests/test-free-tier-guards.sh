#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
variables="$repo_root/infra/oci/variables.tf"
main="$repo_root/infra/oci/main.tf"
worker_image="$repo_root/images/worker/worker.pkr.hcl"
worker_cleanup="$repo_root/images/worker/scripts/clean-image.sh"
control_compose="$repo_root/compose/control-plane/compose.yaml"
control_dockerfile="$repo_root/compose/control-plane/Dockerfile"
control_tasks="$repo_root/ansible/roles/control_plane/tasks/main.yml"
docker_defaults="$repo_root/ansible/roles/docker_engine/defaults/main.yml"
worker_defaults="$repo_root/ansible/roles/worker/defaults/main.yml"
worker_tasks="$repo_root/ansible/roles/worker/tasks/main.yml"

rg -q 'default\s+= false' "$variables"
rg -q 'local.total_ocpus <= 2' "$main"
rg -q 'local.total_memory_gb <= 12' "$main"
rg -q 'var.bootstrap_ssh_cidr != "0.0.0.0/0"' "$variables"
rg -q 'var.ubuntu_image_ocid != ""' "$main"
rg -F -q 'cloud-images\\.ubuntu\\.com/noble/[0-9]{8}' "$worker_image"
rg -F -q 'ssh_host_*' "$worker_cleanup"
rg -q 'OMNIGENT_ADMIN_CREDENTIALS_PATH: /data/admin-credentials' "$control_compose"
rg -q '^\s+user: "10001:10001"$' "$control_compose"
rg -q '^USER 10001:10001$' "$control_dockerfile"
rg -F -q 'owner: "10001"' "$control_tasks"
rg -q '^docker_users: \[\]$' "$docker_defaults"
rg -q '^omnigent_worker_allow_rootful_docker: false$' "$worker_defaults"
rg -F -q 'cli_auth_credentials_store = "keyring"' "$worker_tasks"

echo "PASS: static cost, exposure, image-identity, credential, and persistence guards are present"
