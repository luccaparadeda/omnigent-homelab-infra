#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

echo "Checking whitespace and patch integrity"
git diff --check
git diff --cached --check

echo "Checking for private-key material"
if rg -n --hidden --glob '!.git/**' --glob '!scripts/validate.sh' \
  'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|ghp_[A-Za-z0-9]{30,}|sk-[A-Za-z0-9]{20,}' .; then
  echo "FAIL: possible secret material found" >&2
  exit 1
fi

if command -v shellcheck >/dev/null 2>&1; then
  find scripts images -type f -name '*.sh' -print0 | sort -z | xargs -0 shellcheck
  echo "PASS: shellcheck"
else
  echo "SKIP: shellcheck is not installed"
fi

"$repo_root/scripts/compose-config.sh"
"$repo_root/tests/test-free-tier-guards.sh"
"$repo_root/tests/test-github-actions.sh"

if command -v ruby >/dev/null 2>&1; then
  find .github ansible compose images -type f \( -name '*.yml' -o -name '*.yaml' -o -name '*.yaml.example' \) -print0 | \
    xargs -0 ruby -ryaml -e 'ARGV.each { |path| YAML.parse_file(path); puts "PASS: YAML #{path}" }'
else
  echo "SKIP: ruby is not installed; generic YAML parse not run"
fi

if command -v actionlint >/dev/null 2>&1; then
  actionlint
  echo "PASS: actionlint"
else
  echo "SKIP: actionlint is not installed"
fi

if command -v packer >/dev/null 2>&1; then
  packer fmt -check -recursive images
  packer validate -syntax-only images/worker/worker.pkr.hcl
  echo "PASS: Packer formatting and syntax"
else
  echo "SKIP: packer is not installed"
fi

if command -v tofu >/dev/null 2>&1; then
  tofu -chdir=infra/oci fmt -check -recursive
  if [[ -d infra/oci/.terraform ]]; then
    tofu -chdir=infra/oci validate
  else
    echo "SKIP: tofu providers are not initialized; formatting passed"
  fi
else
  echo "SKIP: tofu is not installed"
fi

ansible_playbook=""
if command -v ansible-playbook >/dev/null 2>&1; then
  ansible_playbook=$(command -v ansible-playbook)
elif [[ -x "$repo_root/.venv/bin/ansible-playbook" ]]; then
  ansible_playbook="$repo_root/.venv/bin/ansible-playbook"
fi

if [[ -n "$ansible_playbook" ]]; then
  mkdir -p "$repo_root/.ansible/tmp"
  ANSIBLE_CONFIG="$repo_root/ansible/ansible.cfg" \
    ANSIBLE_LOCAL_TEMP="$repo_root/.ansible/tmp" \
    "$ansible_playbook" --syntax-check "$repo_root/ansible/playbooks/site.yml"
  echo "PASS: Ansible syntax"
else
  echo "SKIP: ansible-playbook is not installed"
fi

ansible_lint=""
if command -v ansible-lint >/dev/null 2>&1; then
  ansible_lint=$(command -v ansible-lint)
elif [[ -x "$repo_root/.venv/bin/ansible-lint" ]]; then
  ansible_lint="$repo_root/.venv/bin/ansible-lint"
fi

if [[ -n "$ansible_lint" ]]; then
  ANSIBLE_CONFIG="$repo_root/ansible/ansible.cfg" \
    ANSIBLE_LOCAL_TEMP="$repo_root/.ansible/tmp" \
    XDG_CACHE_HOME="$repo_root/.cache" \
    "$ansible_lint" ansible
  echo "PASS: ansible-lint"
else
  echo "SKIP: ansible-lint is not installed"
fi

echo "All available local checks passed."
