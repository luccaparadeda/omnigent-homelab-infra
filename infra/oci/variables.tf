variable "enable_create" {
  description = "Hard safety switch. Nothing is created while false."
  type        = bool
  default     = false
}

variable "tenancy_ocid" {
  description = "OCI tenancy OCID."
  type        = string
  default     = ""
}

variable "compartment_ocid" {
  description = "Existing compartment for the homelab resources."
  type        = string
  default     = ""
}

variable "region" {
  description = "OCI home region where Always Free resources are eligible."
  type        = string
  default     = "sa-saopaulo-1"
}

variable "availability_domain" {
  description = "Optional AD name. Empty selects the first available AD."
  type        = string
  default     = ""
}

variable "oci_auth" {
  description = "OCI provider authentication method. SecurityToken is suited to an operator workstation."
  type        = string
  default     = "SecurityToken"

  validation {
    condition     = contains(["ApiKey", "SecurityToken", "InstancePrincipal", "ResourcePrincipal"], var.oci_auth)
    error_message = "oci_auth must be ApiKey, SecurityToken, InstancePrincipal, or ResourcePrincipal."
  }
}

variable "oci_config_profile" {
  description = "Profile in ~/.oci/config used by the OCI provider."
  type        = string
  default     = "DEFAULT"
}

variable "name_prefix" {
  description = "Prefix for created resources."
  type        = string
  default     = "omnigent-homelab"
}

variable "ssh_public_key" {
  description = "Public SSH key installed for the ops user. Never provide a private key."
  type        = string
  default     = ""
}

variable "bootstrap_ssh_cidr" {
  description = "Temporary single-IP CIDR allowed to SSH during Tailscale enrollment, e.g. 203.0.113.10/32. Null opens no SSH ingress."
  type        = string
  default     = null

  validation {
    condition     = var.bootstrap_ssh_cidr == null || (can(cidrhost(var.bootstrap_ssh_cidr, 0)) && var.bootstrap_ssh_cidr != "0.0.0.0/0")
    error_message = "bootstrap_ssh_cidr must be null or a restricted CIDR; 0.0.0.0/0 is forbidden."
  }
}

variable "ubuntu_image_ocid" {
  description = "Required immutable Ubuntu 24.04 ARM64 platform-image OCID when creation is enabled."
  type        = string
  default     = ""
}

variable "control_ocpus" {
  description = "OCPUs for the control-plane VM."
  type        = number
  default     = 1
}

variable "control_memory_gb" {
  description = "RAM in GB for the control-plane VM."
  type        = number
  default     = 8
}

variable "vault_ocpus" {
  description = "OCPUs for the Vault VM."
  type        = number
  default     = 1
}

variable "vault_memory_gb" {
  description = "RAM in GB for the Vault VM."
  type        = number
  default     = 4
}

variable "boot_volume_size_gb" {
  description = "Boot volume size for each VM. Two 50 GB volumes remain within the 200 GB Always Free aggregate allowance."
  type        = number
  default     = 50

  validation {
    condition     = var.boot_volume_size_gb >= 50 && var.boot_volume_size_gb <= 100
    error_message = "Use 50-100 GB per VM to stay within this repository's free-tier storage budget."
  }
}

variable "create_kms_key" {
  description = "Create an OCI KMS vault/key for Vault auto-unseal. Disable only when supplying existing KMS values to Ansible."
  type        = bool
  default     = true
}

variable "create_backup_bucket" {
  description = "Create a private Object Storage bucket for encrypted logical backups."
  type        = bool
  default     = true
}

variable "freeform_tags" {
  description = "Tags applied to resources."
  type        = map(string)
  default = {
    managed-by = "opentofu"
    stack      = "omnigent-homelab"
  }
}
