# Golden worker acceptance checklist

Before calling a bare-metal worker installation, optional VM disk, or Oracle
boot-volume backup golden:

1. For bare metal, perform a fresh guarded installation on the explicitly selected target disk. For an image, boot a clone—never the only copy.
2. Confirm a unique machine ID and host SSH keys are generated.
3. On the optional Packer path, confirm the `packer` account is locked, is not in `sudo`, and has no entry in `/etc/sudoers.d`. The bare-metal path never creates this account.
4. Confirm there are no Omnigent sessions, subscription sessions, host
   identities, shell histories, API tokens, `.env` files, private keys, or
   project checkouts.
5. Run `cloud-init status --wait` and the worker Ansible playbook twice; the second run should be idempotent.
6. Confirm the bare-metal worker disk is encrypted and the worker user's Codex
   policy requires keyring storage. Confirm the user is not in the rootful
   Docker group.
7. Run `omni --version`, DNS, outbound HTTPS, and Tailscale connectivity. Test
   rootless containers only if they are enabled as a separate compatibility
   milestone.
8. Enroll a temporary host and execute a harmless test session.
9. Revoke that temporary host identity and confirm it can no longer execute.
10. Scan the disk/configuration for secret patterns before publishing or backing up.
11. Record Ubuntu source URL/checksum/release, autoinstall/Ansible revision, architecture, and test evidence. Also record Packer/QEMU versions when using the optional VM path.
12. Retain the prior known-good image until a restore drill passes.

An installed disk or OCI boot-volume backup is a recovery artifact, not the build recipe. The repository plus Ubuntu installer/platform image plus Ansible is the reproducible golden source.
