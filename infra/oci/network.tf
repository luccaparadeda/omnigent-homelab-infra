resource "oci_core_vcn" "main" {
  count          = var.enable_create ? 1 : 0
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.42.0.0/16"]
  display_name   = "${var.name_prefix}-vcn"
  dns_label      = "omnigent"
  freeform_tags  = var.freeform_tags
}

resource "oci_core_internet_gateway" "main" {
  count          = var.enable_create ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main[0].id
  display_name   = "${var.name_prefix}-internet"
  enabled        = true
  freeform_tags  = var.freeform_tags
}

resource "oci_core_route_table" "public" {
  count          = var.enable_create ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main[0].id
  display_name   = "${var.name_prefix}-public-routes"
  freeform_tags  = var.freeform_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main[0].id
  }
}

resource "oci_core_security_list" "public" {
  count          = var.enable_create ? 1 : 0
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main[0].id
  display_name   = "${var.name_prefix}-public-security"
  freeform_tags  = var.freeform_tags

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  dynamic "ingress_security_rules" {
    for_each = var.bootstrap_ssh_cidr == null ? [] : [var.bootstrap_ssh_cidr]
    content {
      description = "Temporary operator SSH for private-overlay enrollment"
      protocol    = "6"
      source      = ingress_security_rules.value
      tcp_options {
        min = 22
        max = 22
      }
    }
  }
}

resource "oci_core_subnet" "public" {
  count                      = var.enable_create ? 1 : 0
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main[0].id
  cidr_block                 = "10.42.10.0/24"
  display_name               = "${var.name_prefix}-public"
  dns_label                  = "services"
  route_table_id             = oci_core_route_table.public[0].id
  security_list_ids          = [oci_core_security_list.public[0].id]
  prohibit_public_ip_on_vnic = false
  freeform_tags              = var.freeform_tags
}
