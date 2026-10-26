# Guarded bare-metal worker installation

This is the primary worker golden build: an Ubuntu 24.04 autoinstall seed
followed by the same Ansible `workers` role. It deliberately
keeps **storage interactive** so a generic seed cannot silently erase the wrong
disk on a home PC.

1. Copy `user-data.yaml.example` and `meta-data.yaml.example` outside Git.
2. Replace the operator public key and unique instance ID.
3. Serve or attach the two files with Ubuntu's NoCloud autoinstall method.
4. At the installer, review and explicitly select the target disk and choose
   full-disk encrypted LVM/LUKS with a strong passphrase. The passphrase is
   intentionally not present in this seed.
5. After first boot, connect as `ops`, enroll Tailscale, and run the worker
   Ansible playbook twice.
6. Complete `docs/runbooks/image-acceptance.md` before enrolling Omnigent.

The seed contains no passwords, tokens, private keys, Omnigent identity, or
automatic disk layout. Hardware-specific storage, GPU drivers, Secure Boot,
Wi-Fi and power-management settings remain decisions for the actual PC.
