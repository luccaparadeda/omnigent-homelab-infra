resource "oci_objectstorage_bucket" "backups" {
  count          = var.enable_create && var.create_backup_bucket ? 1 : 0
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.current[0].namespace
  name           = "${var.name_prefix}-backups"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Enabled"
  freeform_tags  = var.freeform_tags
}
