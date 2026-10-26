# Subscription CLI credential decision

Date: 2026-10-26
Status: accepted design; live worker behavior still requires acceptance testing

## Decision

Workers authenticate the native Codex and Claude CLIs with the user's existing
subscriptions. The design does not buy or configure model API keys.

The OAuth/session credentials live on the worker because the native CLI runs
there. Managed MCP account credentials remain on the Omnigent control plane and
are encrypted with Vault Transit.

## Worker controls

- Install the worker on a full-disk-encrypted Ubuntu system.
- Store subscription credentials in the worker user's password-unlocked OS
  keyring, never in the image or repository.
- Enforce `cli_auth_credentials_store = "keyring"` for Codex through the
  root-owned `/etc/codex/requirements.toml`. Do not use `auto`, because it can
  fall back to file storage when the keyring is unavailable.
- Do not put the subscription-authenticated account in the rootful Docker
  group. Rootless containers are allowed only after the actual agent, build,
  and Omnigent-host workflows pass compatibility tests.
- Unlock the encrypted disk and keyring interactively after each reboot. The
  worker can operate unattended until the machine or keyring is locked again.
- Use a distinct Omnigent host identity, private-network identity, Git identity,
  and keyring on each worker.

## Limit that cannot be engineered away

Once the keyring is unlocked, a process running with the same user identity can
ask the native CLI or credential service to use the session. Disk encryption
and a password protect credentials at rest and across reboot, but they cannot
make an already unlocked execution account immune to malicious code.

Requiring a human password for every model request would prevent 24/7
unattended work. This design chooses a manual unlock after boot, then unattended
operation while the worker stays unlocked.

## Future stronger separation

Codex and Claude can be evaluated under separate Unix users and separate
Omnigent host daemons. That would reduce same-user cross-access, but it is not
part of the current baseline until multi-host scheduling, keyring startup, and
project ownership are tested together.

## Acceptance gates

- Reboot the worker and prove that scheduled execution cannot use either
  subscription before an interactive keyring unlock.
- Unlock once and prove both CLIs and the persistent Omnigent host work across
  login-session disconnects without a stored unlock password.
- Verify Codex refuses login/session persistence when the keyring is
  unavailable and does not create `~/.codex/auth.json`.
- Verify Claude reports healthy secure credential storage on the installed
  Ubuntu release.
- Confirm the worker account is absent from the `docker` group.
- Revoke both subscription sessions and the Omnigent host identity during a
  recovery drill.

## Primary references

- Omnigent model credentials: <https://omnigent.ai/docs/build/models>
- Codex credential-store implementation: <https://github.com/openai/codex/blob/main/codex-rs/login/src/auth/storage.rs>
- Codex system requirements loader: <https://github.com/openai/codex/blob/main/codex-rs/config/src/loader/mod.rs>
- Claude Code setup and secure credential storage: <https://docs.anthropic.com/en/docs/claude-code/getting-started>
- Docker group privilege warning: <https://docs.docker.com/engine/install/linux-postinstall/>
