#cloud-config
users:
  - name: packer
    gecos: Ephemeral image builder
    groups: [adm, sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - ${build_ssh_public_key}

ssh_pwauth: false
disable_root: true
package_update: true
packages:
  - qemu-guest-agent
  - python3
  - python3-apt

runcmd:
  - [systemctl, enable, --now, qemu-guest-agent]

final_message: "Packer SSH baseline ready."
