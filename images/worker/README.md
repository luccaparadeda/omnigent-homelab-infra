# Worker golden configuration

The primary golden path for the dedicated home PC is the guarded Ubuntu 24.04
autoinstall seed under `autoinstall/`, followed by the Ansible `workers` role.
The physical PC itself is the agent containment boundary, so no VM layer is
required.

The QEMU template remains as an optional credential-free testing or virtual
worker artifact. Packer is pinned to 1.16.2 and the QEMU plugin to 1.1.7. Do not
flash its QCOW2 virtual disk onto the physical PC.

## Optional QEMU build outline

1. Choose a versioned Ubuntu release directory, download its `SHA256SUMS` over HTTPS, and verify the signature. Do not use the mutable `/current/` image URL.
2. Generate a throwaway SSH key outside the repository.
3. Copy `worker.pkrvars.hcl.example` to `worker.pkrvars.hcl` and fill the checksum/key paths.
4. Run `packer init images/worker` and `packer build -var-file=images/worker/worker.pkrvars.hcl images/worker/worker.pkr.hcl`.
5. Run the image acceptance checklist before enrollment.

The generated disk, Packer variables, machine ID, logs, SSH host keys, build SSH authorization, Omnigent login, and host identity are excluded from Git or removed before shutdown. The Packer account is locked and loses its sudo grant during final shutdown.

At clone boot, attach the `cloud-init/clone-user-data.yaml.example` and a unique
NoCloud `meta-data` file. Replace the SSH-key placeholder outside Git. This
creates the real operator account and regenerates host keys; credentials are
enrolled only after Ansible convergence and image acceptance.
