resource "oci_kms_vault" "auto_unseal" {
  count          = var.enable_create && var.create_kms_key ? 1 : 0
  compartment_id = var.compartment_ocid
  display_name   = "${var.name_prefix}-vault-auto-unseal"
  vault_type     = "DEFAULT"
  freeform_tags  = var.freeform_tags
}

resource "oci_kms_key" "auto_unseal" {
  count               = var.enable_create && var.create_kms_key ? 1 : 0
  compartment_id      = var.compartment_ocid
  display_name        = "${var.name_prefix}-auto-unseal"
  management_endpoint = oci_kms_vault.auto_unseal[0].management_endpoint
  protection_mode     = "SOFTWARE"
  freeform_tags       = var.freeform_tags

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  lifecycle {
    prevent_destroy = true
  }
}
