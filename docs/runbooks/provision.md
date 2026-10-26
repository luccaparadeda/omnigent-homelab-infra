# Provisioning runbook

Nothing in this repository applies infrastructure automatically. Choose one Oracle path, then converge both nodes with the same Ansible roles.

## Path A — create Oracle nodes manually

1. In the tenancy **home region**, create two Ubuntu 24.04 ARM64 `VM.Standard.A1.Flex` instances.
2. Allocate control as 1 OCPU / 8 GB and Vault as 1 OCPU / 4 GB.
3. Use a 50 GB boot disk on each and confirm **Always Free eligible** in the Console.
4. Add only your public SSH key. Never paste a private key or service credential into cloud-init.
5. Permit SSH temporarily from your current public `/32`; do not open 8000, 8200, or 8201.
6. SSH to each host, wait for `cloud-init status --wait`, install/enroll Tailscale, and verify SSH via the Tailscale address.
7. Remove public SSH ingress from the OCI security list.

## Path B — create Oracle nodes with OpenTofu

```bash
cd infra/oci
cp terraform.tfvars.example terraform.tfvars
# Fill OCIDs, region, public key, and a temporary restricted bootstrap CIDR.
tofu init
tofu fmt -check -recursive
tofu validate
tofu plan -out reviewed.plan
```

Review the plan and Oracle cost estimator before any apply. Applying is a separate operator-approved step.

## Configure either path with Ansible

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
ansible-galaxy collection install -r ansible/requirements.yml

cp -R ansible/inventory/example ansible/inventory/production
# Replace example addresses with Tailscale DNS names or IPs.

ANSIBLE_CONFIG=ansible/ansible.cfg \
  ansible-playbook -i ansible/inventory/production/hosts.yml \
  ansible/playbooks/site.yml --check --diff
```

The first real run installs software and renders inert configuration because both service-start flags default to false. Complete the secrets runbook, encrypt the private inventory, then explicitly enable services and run the narrow playbooks.

## Home PC and laptop

- Dedicated home PC: use `images/worker/autoinstall/`, explicitly select the target disk, add its Tailscale address to `workers`, and run `worker.yml` twice. This is the primary worker golden path.
- Optional KVM test worker: build/import the Packer QCOW2, boot a credential-free clone, then run `worker.yml`.
- Laptop: use the same worker role, but do not schedule mandatory unattended jobs there unless sleep/power behavior is acceptable.
