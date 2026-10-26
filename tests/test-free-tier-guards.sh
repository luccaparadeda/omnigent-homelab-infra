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
control_defaults="$repo_root/ansible/roles/control_plane/defaults/main.yml"
control_env="$repo_root/ansible/roles/control_plane/templates/env.j2"
vault_tasks="$repo_root/ansible/roles/vault_node/tasks/main.yml"
vault_defaults="$repo_root/ansible/roles/vault_node/defaults/main.yml"
vault_compose="$repo_root/compose/vault/compose.yaml"
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
rg -q '^omnigent_bind_ip: "127.0.0.1"$' "$control_defaults"
rg -q '^omnigent_tailscale_serve_enabled: true$' "$control_defaults"
rg -F -q 'tailscale serve --bg {{ omnigent_tailscale_serve_target }}' "$control_tasks"
rg -q '^omnigent_vault_proxy_addr: http://vault-proxy:8100$' "$control_defaults"
rg -q '^VAULT_ADDR=\{\{ omnigent_vault_proxy_addr \}\}$' "$control_env"
if rg -q '^VAULT_TOKEN=' "$control_env"; then
  echo "FAIL: static Vault token must not be rendered into the control-plane environment" >&2
  exit 1
fi
rg -F -q 'vault_runtime_uid: "100"' "$vault_defaults"
rg -F -q 'vault_runtime_gid: "1000"' "$vault_defaults"
rg -F -q 'owner: "{{ vault_runtime_uid }}"' "$vault_tasks"
rg -F -q 'source: ./policies' "$vault_compose"
rg -F -q 'vault-backup.hcl' "$vault_tasks"
rg -q '^docker_users: \[\]$' "$docker_defaults"
rg -q '^omnigent_worker_allow_rootful_docker: false$' "$worker_defaults"
rg -F -q 'cli_auth_credentials_store = "keyring"' "$worker_tasks"

echo "PASS: static cost, exposure, image-identity, credential, and persistence guards are present"
