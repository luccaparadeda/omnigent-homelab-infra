resource "oci_core_instance" "control" {
  count               = var.enable_create ? 1 : 0
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "${var.name_prefix}-control"
  shape               = "VM.Standard.A1.Flex"
  freeform_tags       = merge(var.freeform_tags, { role = "control-plane" })

  shape_config {
    ocpus         = var.control_ocpus
    memory_in_gbs = var.control_memory_gb
  }

  create_vnic_details {
    assign_public_ip = true
    display_name     = "${var.name_prefix}-control"
    hostname_label   = "control"
    subnet_id        = oci_core_subnet.public[0].id
  }

  source_details {
    source_type             = "image"
    source_id               = local.image_id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/../../images/vps/cloud-init/user-data.yaml.tftpl", {
      role           = "control-plane"
      ssh_public_key = var.ssh_public_key
    }))
  }

  depends_on = [terraform_data.free_tier_guard]
}

resource "oci_core_instance" "vault" {
  count               = var.enable_create ? 1 : 0
  availability_domain = local.availability_domain
  compartment_id      = var.compartment_ocid
  display_name        = "${var.name_prefix}-vault"
  shape               = "VM.Standard.A1.Flex"
  freeform_tags       = merge(var.freeform_tags, { role = "vault" })

  shape_config {
    ocpus         = var.vault_ocpus
    memory_in_gbs = var.vault_memory_gb
  }

  create_vnic_details {
    assign_public_ip = true
    display_name     = "${var.name_prefix}-vault"
    hostname_label   = "vault"
    subnet_id        = oci_core_subnet.public[0].id
  }

  source_details {
    source_type             = "image"
    source_id               = local.image_id
    boot_volume_size_in_gbs = var.boot_volume_size_gb
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/../../images/vps/cloud-init/user-data.yaml.tftpl", {
      role           = "vault"
      ssh_public_key = var.ssh_public_key
    }))
  }

  depends_on = [terraform_data.free_tier_guard]
}

resource "oci_identity_dynamic_group" "vault" {
  count          = var.enable_create && var.create_kms_key ? 1 : 0
  compartment_id = var.tenancy_ocid
  description    = "Only the Omnigent Vault instance can use the auto-unseal KMS key."
  matching_rule  = "instance.id = '${oci_core_instance.vault[0].id}'"
  name           = "${replace(var.name_prefix, "-", "_")}_vault"
}

resource "oci_identity_policy" "vault_kms" {
  count          = var.enable_create && var.create_kms_key ? 1 : 0
  compartment_id = var.compartment_ocid
  description    = "Least-privilege KMS use for Vault auto-unseal."
  name           = "${replace(var.name_prefix, "-", "_")}_vault_kms"
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.vault[0].name} to use keys in compartment id ${var.compartment_ocid} where target.key.id = '${oci_kms_key.auto_unseal[0].id}'"
  ]
}

resource "oci_identity_dynamic_group" "control" {
  count          = var.enable_create && var.create_backup_bucket ? 1 : 0
  compartment_id = var.tenancy_ocid
  description    = "Only the Omnigent control instance can write logical backups."
  matching_rule  = "instance.id = '${oci_core_instance.control[0].id}'"
  name           = "${replace(var.name_prefix, "-", "_")}_control"
}

resource "oci_identity_policy" "control_backups" {
  count          = var.enable_create && var.create_backup_bucket ? 1 : 0
  compartment_id = var.compartment_ocid
  description    = "Object-only access for encrypted Omnigent logical backups."
  name           = "${replace(var.name_prefix, "-", "_")}_control_backups"
  statements = [
    "Allow dynamic-group ${oci_identity_dynamic_group.control[0].name} to manage objects in compartment id ${var.compartment_ocid} where target.bucket.name = '${oci_objectstorage_bucket.backups[0].name}'"
  ]
}
