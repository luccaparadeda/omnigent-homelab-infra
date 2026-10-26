packer {
  required_version = ">= 1.16.2, < 2.0.0"

  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "= 1.1.7"
    }
  }
}

variable "ubuntu_image_url" {
  description = "Versioned official Ubuntu 24.04 amd64 cloud image URL; do not use the mutable /current/ alias."
  type        = string

  validation {
    condition     = can(regex("^https://cloud-images\\.ubuntu\\.com/noble/[0-9]{8}/noble-server-cloudimg-amd64\\.img$", var.ubuntu_image_url))
    error_message = "Use a versioned official noble/YYYYMMDD cloud-image URL."
  }
}

variable "ubuntu_image_release" {
  description = "Ubuntu image release identifier recorded in the image manifest, for example 20261001."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{8}$", var.ubuntu_image_release))
    error_message = "The ubuntu_image_release must be an eight-digit release identifier."
  }
}

variable "ubuntu_image_checksum" {
  description = "Required sha256 checksum from Ubuntu SHA256SUMS."
  type        = string

  validation {
    condition     = can(regex("^sha256:[0-9a-fA-F]{64}$", var.ubuntu_image_checksum))
    error_message = "The ubuntu_image_checksum must use sha256:<64 hex characters>."
  }
}

variable "build_ssh_public_key" {
  description = "Ephemeral public key for the Packer build user."
  type        = string
  sensitive   = true
}

variable "build_ssh_private_key_file" {
  description = "Path to the matching ephemeral private key; never commit it."
  type        = string
  sensitive   = true
}

variable "accelerator" {
  description = "QEMU accelerator: kvm on Linux, hvf on macOS, or tcg for emulation."
  type        = string
  default     = "kvm"

  validation {
    condition     = contains(["kvm", "hvf", "tcg"], var.accelerator)
    error_message = "The accelerator must be kvm, hvf, or tcg."
  }
}

variable "omnigent_version" {
  type    = string
  default = "0.19.1"
}

locals {
  cloud_init = templatefile("${path.root}/cloud-init/user-data.pkrtpl.hcl", {
    build_ssh_public_key = var.build_ssh_public_key
  })
}

source "qemu" "ubuntu_worker" {
  accelerator               = var.accelerator
  disk_compression          = true
  disk_image                = true
  disk_size                 = "120G"
  format                    = "qcow2"
  headless                  = true
  iso_checksum              = var.ubuntu_image_checksum
  iso_url                   = var.ubuntu_image_url
  output_directory          = "${path.root}/output-worker"
  shutdown_command          = "sudo /bin/bash -c 'rm -f /etc/sudoers.d/90-cloud-init-users; gpasswd -d packer sudo >/dev/null 2>&1 || true; passwd -l packer; /sbin/shutdown -P now'"
  ssh_clear_authorized_keys = true
  ssh_private_key_file      = var.build_ssh_private_key_file
  ssh_timeout               = "20m"
  ssh_username              = "packer"
  vm_name                   = "omnigent-worker-ubuntu-24.04-${var.ubuntu_image_release}-amd64.qcow2"

  cd_label = "cidata"
  cd_content = {
    "meta-data" = "instance-id: omnigent-worker-build\nlocal-hostname: omnigent-worker-build\n"
    "user-data" = local.cloud_init
  }

  qemuargs = [
    ["-m", "4096M"],
    ["-smp", "4"]
  ]
}

build {
  name    = "omnigent-worker"
  sources = ["source.qemu.ubuntu_worker"]

  provisioner "shell" {
    environment_vars = [
      "OMNIGENT_VERSION=${var.omnigent_version}",
      "UBUNTU_IMAGE_RELEASE=${var.ubuntu_image_release}"
    ]
    scripts = ["${path.root}/scripts/provision-worker.sh"]
  }

  provisioner "shell" {
    scripts = ["${path.root}/scripts/clean-image.sh"]
  }
}
