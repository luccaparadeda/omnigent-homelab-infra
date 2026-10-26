# Repository instructions

- This repository defines infrastructure and machine images. Do not apply, deploy, push, create cloud resources, or create a GitHub remote without explicit approval.
- Never commit credentials, access tokens, private keys, recovery keys, `.env` files, state files, VM disks, database dumps, or decrypted backups.
- Keep version pins explicit. Image updates must be reviewed and followed by the validation and recovery drills documented under `docs/runbooks/`.
- Treat generated worker images as credential-free. Credentials are enrolled only after a machine is launched.
- Prefer small, reversible changes. Preserve the public interfaces documented in `README.md` and update the runbooks when behavior changes.
- Run `make validate` before handing off changes.
