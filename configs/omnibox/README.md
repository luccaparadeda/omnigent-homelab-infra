# Omnibox worker profiles

`coding-agent/config.yaml` is the portable worker baseline. Omnigent resolves
`sandbox.type: auto` to Bubblewrap plus seccomp on Linux and Seatbelt on macOS.
The working tree is writable, hidden files are recursively masked except for
`.git` and `.venv`, and known secret paths are masked explicitly.

Run it from a project checkout with the Omnigent 0.19.1 CLI:

```bash
omni run /etc/omnigent-worker/omnibox-base.yaml \
  --server https://YOUR_PRIVATE_OMNIGENT_NAME
```

On macOS, use `coding-agent-macos/config.yaml`. It grants read access only to
the installed Codex launcher and its resolved standalone package tree. Verify
`readlink ~/.local/bin/codex` before reusing the profile on another Mac. Keep
the profile in a worker project root outside macOS privacy-protected folders
such as `~/Documents`, unless the background process has explicit Files &
Folders permission. The default Ansible destination above is for Linux.

### Omnigent 0.19.1 macOS compatibility gate

Omnigent 0.19.1 symlinks Codex's shared `memories_1.sqlite` into every private
`CODEX_HOME`. Codex 0.154.0 cannot initialize that external SQLite state
through the generated Seatbelt profile. Its macOS configuration loader also
needs two narrowly scoped preference domains and the separate Seatbelt
`system-socket` operation when full networking is already enabled. The
version- and hash-pinned helper below applies only those compatibility changes
and keeps session memory local:

```bash
python3 scripts/patch-omnigent-0.19.1-macos.py check
python3 scripts/patch-omnigent-0.19.1-macos.py apply
# Revert before changing versions, if needed:
python3 scripts/patch-omnigent-0.19.1-macos.py revert
```

This is a reviewed compatibility workaround, not an upstream fix. It is
removed by an Omnigent reinstall or upgrade and must never be applied when the
package version or source hash differs.

Set `HARNESS_CODEX_MINIMAL_CONFIG=1` in the persistent worker environment and
include only that name in `OMNIGENT_RUNNER_ENV_PASSTHROUGH`. Omnigent filters
the host environment before starting a runner, so both settings are required.
This prevents a session from inheriting unrelated desktop plugins, MCP
declarations, and external catalog paths. The macOS profile grants read access
to the non-secret Codex model-catalog and text-encoding files needed during
startup. It still does not grant `auth.json`.

The workaround fixes startup but does not solve subscription credential
delivery. In this release, Codex sees the logged-in account only when the
Seatbelt profile can read the source `auth.json`. Adding that path would make
the credential readable to agent-created subprocesses too. The checked-in
profile therefore does not grant it and must not be described as an
unattended, subscription-authenticated Codex worker until Omnigent brokers the
credential or an equivalent upstream boundary is verified.

## Network hardening gate

The checked-in baseline deliberately uses `allow_network: true` so native
Codex subscription authentication can be accepted and observed without a
guessed, brittle hostname list. That is filesystem isolation, not an
exfiltration-safe network policy.

Before using unattended or untrusted repositories, add `egress_rules` for the
exact hosts and paths the chosen harness and project need. Once
`egress_rules` exists, Omnigent's HTTP(S) proxy is default-deny. Keep
`egress_allow_private_destinations` unset or `false`; the agent does not need
direct access to the Omnigent or Vault private addresses because the trusted
supervisor owns those connections.

Do not guess subscription-login domains in a public golden image. Record them
during a supervised acceptance session, review them, and keep the resulting
allow-list beside that project. Use `credential_proxy` for supported HTTP
tokens and repository-scoped `git_ssh` bindings for Git instead of exposing
the underlying secret to the sandbox.

## Security boundary

Omnibox applies to `sys_os_*` operations and terminals that inherit or repeat
the sandbox policy. The Omnigent supervisor and MCP server subprocesses run
outside this OS sandbox. Every MCP server therefore needs its own command,
filesystem, network, and credential restrictions; prefer the server-managed
MCP registry/gateway where possible.
