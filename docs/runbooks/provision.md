# Provisioning runbook

Nothing in this repository applies infrastructure automatically. Choose one Oracle path, then converge both nodes with the same Ansible roles.

## Path A — create Oracle nodes manually

The live path uses the capacity that was available in the tenancy; the
preferred A1 shape was unavailable.

1. In the tenancy home region, create two Ubuntu 24.04 AMD64
   `VM.Standard.E2.1.Micro` instances.
2. Assign one to Omnigent and one to Vault. Each live node has 1 OCPU, 1 GB RAM,
   and a 45 GB boot disk.
3. Confirm **Always Free eligible** in the Console before creating each VM.
4. Add only your public SSH key. Never paste a private key or service credential into cloud-init.
5. Permit SSH temporarily from your current public `/32`; do not open 8000, 8200, or 8201.
6. SSH to each host, wait for `cloud-init status --wait`, install/enroll Tailscale, and verify SSH via the Tailscale address.
7. Remove public SSH ingress from the OCI security list.

Enable MagicDNS and HTTPS certificates in the Tailscale admin console before
starting the control plane. The role keeps Omnigent on `127.0.0.1:8000` and
persists a private Tailscale Serve route. Install Tailscale on the phone, join
the same tailnet, and enter the resulting
`https://omnigent-control.TAILNET.ts.net` URL in the Omnigent mobile app.

For native WireGuard instead, set `omnigent_tailscale_serve_enabled: false`,
set `omnigent_bind_ip` to the control node's WireGuard address, and configure a
trusted HTTPS reverse proxy on that private interface. Do not expose port 8000
directly or use an HTTP URL for the mobile app.

## Configure Vault identity

The current E2 Micro profile uses manual Shamir unseal and a least-privilege
AppRole. It does not require OCI dynamic groups or KMS. Follow
`docs/runbooks/live-deployment-plan.md`, render the manual Vault profile, and
place the control-plane AppRole ID and secret ID only in root-readable runtime
files. The local Vault Proxy exchanges them for renewable short-lived tokens.

During initialization, transfer recovery keys directly to the approved offline
password manager and revoke the initial root token after durable operator
access exists. Never put either value on a command line, in shell history, in
Ansible inventory, or in this repository.

The optional OCI KMS profile remains available for a future deployment. If it
is selected, separately review dynamic groups, narrowly scoped IAM, KMS cost,
key deletion protection, and seal migration before changing the live node.

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
python -m pip install --require-hashes -r requirements-dev.lock
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
