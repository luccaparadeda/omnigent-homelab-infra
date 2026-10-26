output "control_public_ip" {
  description = "Temporary bootstrap IP. Do not expose Omnigent on it."
  value       = try(oci_core_instance.control[0].public_ip, null)
}

output "vault_public_ip" {
  description = "Temporary bootstrap IP. Do not expose Vault on it."
  value       = try(oci_core_instance.vault[0].public_ip, null)
}

output "kms_key" {
  description = "Values passed to the Vault Ansible role for OCI KMS auto-unseal."
  value = var.enable_create && var.create_kms_key ? {
    key_id              = oci_kms_key.auto_unseal[0].id
    crypto_endpoint     = oci_kms_vault.auto_unseal[0].crypto_endpoint
    management_endpoint = oci_kms_vault.auto_unseal[0].management_endpoint
  } : null
}

output "backup_bucket_name" {
  value = try(oci_objectstorage_bucket.backups[0].name, null)
}

output "free_tier_allocation" {
  value = {
    total_ocpus     = local.total_ocpus
    total_memory_gb = local.total_memory_gb
    total_boot_gb   = var.boot_volume_size_gb * 2
  }
}
