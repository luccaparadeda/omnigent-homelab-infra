SHELL := /bin/sh

.PHONY: help validate status compose-config packer-format packer-validate tofu-format tofu-validate ansible-syntax test-guards test-workflows release-package

help:
	@echo "Targets:"
	@echo "  validate         Run every available local validation"
	@echo "  status           Show required tooling and repository state"
	@echo "  compose-config   Parse Compose files with example values"
	@echo "  packer-format    Format Packer templates when Packer is installed"
	@echo "  packer-validate  Validate Packer templates when Packer is installed"
	@echo "  tofu-format      Check OpenTofu formatting when OpenTofu is installed"
	@echo "  tofu-validate    Validate OpenTofu when providers are initialized"
	@echo "  ansible-syntax   Syntax-check Ansible when installed"
	@echo "  test-guards      Verify static cost and exposure guards"
	@echo "  test-workflows   Verify GitHub Actions security policy"
	@echo "  release-package  Package the exact tag matching VERSION"

validate:
	@./scripts/validate.sh

status:
	@./scripts/status.sh

compose-config:
	@./scripts/compose-config.sh

packer-format:
	@if command -v packer >/dev/null 2>&1; then packer fmt -check -recursive images; else echo "SKIP: packer is not installed"; fi

packer-validate:
	@if command -v packer >/dev/null 2>&1; then packer validate -syntax-only images/worker/worker.pkr.hcl; else echo "SKIP: packer is not installed"; fi

tofu-format:
	@if command -v tofu >/dev/null 2>&1; then tofu -chdir=infra/oci fmt -check -recursive; else echo "SKIP: tofu is not installed"; fi

tofu-validate:
	@if command -v tofu >/dev/null 2>&1 && test -d infra/oci/.terraform; then tofu -chdir=infra/oci validate; else echo "SKIP: tofu is not installed or providers are not initialized"; fi

ansible-syntax:
	@if command -v ansible-playbook >/dev/null 2>&1; then ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook --syntax-check ansible/playbooks/site.yml; else echo "SKIP: ansible-playbook is not installed"; fi

test-guards:
	@./tests/test-free-tier-guards.sh

test-workflows:
	@./tests/test-github-actions.sh

release-package:
	@./scripts/verify-release-tag.sh
	@./scripts/package-release.sh
