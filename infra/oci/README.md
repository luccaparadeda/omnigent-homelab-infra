# OCI OpenTofu layer

This layer optionally creates the Oracle resources. It is deliberately inert by default: `enable_create = false`.

It targets two `VM.Standard.A1.Flex` instances in the tenancy home region:

- control plane: 1 OCPU / 8 GB RAM / 50 GB boot
- Vault: 1 OCPU / 4 GB RAM / 50 GB boot

That consumes the current Always Free Ampere total of 2 OCPUs and 12 GB RAM. No public application ports are opened. Optional bootstrap SSH must be a restricted CIDR and should be removed after private-overlay enrollment.

## Validate without creating anything

```bash
cp terraform.tfvars.example terraform.tfvars
tofu init
tofu fmt -check -recursive
tofu validate
tofu plan
```

The copied `terraform.tfvars` and local state are ignored by Git. `tofu apply` is intentionally not exposed through the repository Makefile.

## Manual Oracle path

If Always Free capacity is easier to obtain in the Console, create the same two Ubuntu 24.04 ARM64 shapes there, install your public SSH key, and skip this directory. Put the private Tailscale names or IPs in `ansible/inventory/production/hosts.yml`; Ansible owns everything above the base VM.

## Cost and safety gates

- Create only in the tenancy home region.
- Confirm every selected resource is marked **Always Free eligible** in the Console.
- Keep total A1 allocation at or below 2 OCPUs / 12 GB.
- Keep aggregate boot/block storage and backups within current free allowances.
- Review the plan and the Oracle cost estimator before apply.
- Protect the KMS key from deletion. Losing an auto-unseal key can make Vault backups unrecoverable.
