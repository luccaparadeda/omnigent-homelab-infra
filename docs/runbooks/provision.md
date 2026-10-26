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

Enable MagicDNS and HTTPS certificates in the Tailscale admin console before
starting the control plane. The role keeps Omnigent on `127.0.0.1:8000` and
persists a private Tailscale Serve route. Install Tailscale on the phone, join
the same tailnet, and enter the resulting
`https://omnigent-control.TAILNET.ts.net` URL in the Omnigent mobile app.

For native WireGuard instead, set `omnigent_tailscale_serve_enabled: false`,
set `omnigent_bind_ip` to the control node's WireGuard address, and configure a
trusted HTTPS reverse proxy on that private interface. Do not expose port 8000
directly or use an HTTP URL for the mobile app.

## Configure OCI identities for Vault

Create two narrowly matched dynamic groups:

- `omnigent-vault-node`: only the Vault instance OCID.
- `omnigent-control-node`: only the control instance OCID.

The Vault-node dynamic group needs permission to use only the selected OCI KMS
key. Vault's OCI auth plugin also needs the documented tenancy-level
`AUTHENTICATION_INSPECT` and `GROUP_MEMBERSHIP_INSPECT` permissions. The
control-node group exists so Vault can bind its OCID to the `omnigent-control`
role; it receives no KMS permission.

After Vault initialization, run these from the Vault node with a temporary
initialization token in the environment. Read it without echoing, preserve it
only across `sudo`, and replace both placeholder OCIDs:

```bash
cd /opt/omnigent-vault
read -rsp "Temporary Vault initialization token: " VAULT_TOKEN
export VAULT_TOKEN
sudo --preserve-env=VAULT_TOKEN docker compose exec -T -e VAULT_TOKEN vault vault secrets enable transit
sudo --preserve-env=VAULT_TOKEN docker compose exec -T -e VAULT_TOKEN vault vault write transit/keys/omnigent-credentials derived=true
sudo --preserve-env=VAULT_TOKEN docker compose exec -T -e VAULT_TOKEN vault vault policy write omnigent-transit /vault/policies/omnigent-transit.hcl
sudo --preserve-env=VAULT_TOKEN docker compose exec -T -e VAULT_TOKEN vault vault policy write vault-backup /vault/policies/vault-backup.hcl
sudo --preserve-env=VAULT_TOKEN docker compose exec -T -e VAULT_TOKEN vault vault auth enable oci
sudo --preserve-env=VAULT_TOKEN docker compose exec -T -e VAULT_TOKEN vault vault write auth/oci/config home_tenancy_id="TENANCY_OCID"
sudo --preserve-env=VAULT_TOKEN docker compose exec -T -e VAULT_TOKEN vault vault write auth/oci/role/omnigent-control \
  token_policies="omnigent-transit" token_no_default_policy=true token_ttl="1h" \
  ocid_list="CONTROL_DYNAMIC_GROUP_OCID"
sudo --preserve-env=VAULT_TOKEN docker compose exec -T -e VAULT_TOKEN vault vault write auth/oci/role/omnigent-vault-backup \
  token_policies="vault-backup" token_no_default_policy=true token_ttl="15m" \
  ocid_list="VAULT_DYNAMIC_GROUP_OCID"
unset VAULT_TOKEN
```

Do not put the initialization token on the command line or in shell history.
Export it only for the supervised bootstrap session, create durable operator
access, then revoke it.

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
