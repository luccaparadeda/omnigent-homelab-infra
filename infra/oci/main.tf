data "oci_identity_availability_domains" "available" {
  count          = var.enable_create ? 1 : 0
  compartment_id = var.tenancy_ocid
}

data "oci_objectstorage_namespace" "current" {
  count          = var.enable_create && var.create_backup_bucket ? 1 : 0
  compartment_id = var.compartment_ocid
}

locals {
  availability_domain = var.enable_create ? (
    var.availability_domain != "" ? var.availability_domain : data.oci_identity_availability_domains.available[0].availability_domains[0].name
  ) : ""

  image_id = var.enable_create ? var.ubuntu_image_ocid : ""

  total_ocpus     = var.control_ocpus + var.vault_ocpus
  total_memory_gb = var.control_memory_gb + var.vault_memory_gb
}

resource "terraform_data" "free_tier_guard" {
  count = var.enable_create ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.total_ocpus <= 2
      error_message = "The two Ampere A1 VMs exceed the Always Free total of 2 OCPUs."
    }

    precondition {
      condition     = local.total_memory_gb <= 12
      error_message = "The two Ampere A1 VMs exceed the Always Free total of 12 GB RAM."
    }

    precondition {
      condition     = var.tenancy_ocid != "" && var.compartment_ocid != "" && var.ssh_public_key != "" && var.ubuntu_image_ocid != ""
      error_message = "tenancy_ocid, compartment_ocid, ssh_public_key, and an immutable ubuntu_image_ocid are required when enable_create=true."
    }
  }
}
