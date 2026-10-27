# Worker enrollment

Each machine gets a distinct Omnigent host identity. Managed MCP credentials
remain server-side where the gateway supports them. Native Codex and Claude
subscription sessions are deliberately worker-local because those CLIs execute
on the worker; this design uses no paid model API keys.

Omnibox is the OS-level boundary around each agent process; `omni host` is the
worker daemon that receives sessions. They are complementary, not substitutes.
Linux workers use Bubblewrap plus seccomp and macOS workers use Seatbelt. An
explicit sandbox request fails closed when its platform backend is unavailable.

The `omnigent-worker` account must not be a member of the rootful Docker group.
Docker documents that this is root-equivalent access, which would let an agent
bypass user and keyring isolation. Rootless Docker remains a compatibility
gate. Until it passes, workflows that require containers need an explicitly
approved isolated build path. Do not put personal files, browser profiles,
daily-use accounts, or unrelated credentials on the worker.

After Ansible finishes, open an interactive login session as
`omnigent-worker`, start or unlock that user's Secret Service without saving
the unlock password in a script, and authenticate the native CLIs:

```bash
codex login
claude auth login
```

Codex is configured system-wide to use only the OS keyring. Confirm that it did
not create `~/.codex/auth.json`, and verify Claude's secure credential storage
is healthy on the installed Ubuntu release.

Then enroll the Omnigent host:

```bash
omni --version
omni login https://YOUR_PRIVATE_OMNIGENT_NAME
omni host https://YOUR_PRIVATE_OMNIGENT_NAME
# After the foreground smoke test succeeds, stop it and install the user service:
omni host enable
```

Verify the persistent service rather than assuming installation succeeded:

```bash
omni host status
```

For an authenticated remote server, first authenticate the management CLI with
`omni login PRIVATE_SERVER_URL`; otherwise the process check can be online while
the host-row probe returns HTTP 401 and `host=unknown`. A 401 is inconclusive,
not proof that the tunnel is offline. With an authenticated probe, require both
`process=online` and `host=online`; otherwise verify the connection in the
authenticated UI and the current host-daemon log. On macOS the service
definition is a per-user LaunchAgent; on Linux it is a per-user systemd service,
so the worker user must have login lingering configured if it must run without
an interactive session.

## Run agents through Omnibox

Ansible installs the credential-free baseline at
`/etc/omnigent-worker/omnibox-base.yaml` on Linux. The source profile is
`configs/omnibox/coding-agent/config.yaml`; copy it to a user-owned path on a
macOS laptop. For a Mac whose Codex launcher resolves into
`~/.codex/packages/standalone/current`, start with
`configs/omnibox/coding-agent-macos/config.yaml`. Verify the resolved binary
path first and keep laptop worker checkouts outside macOS privacy-protected
folders such as `~/Documents`, unless the background process has explicit
Files & Folders access.

For Omnigent 0.19.1 with Codex 0.154.0 on macOS, first read the compatibility
gate in `configs/omnibox/README.md`. The pinned helper can keep the shared Codex
memory database out of a private Seatbelt session, but the current release
still has no safe broker for the ChatGPT subscription credential. Do not add
`~/.codex/auth.json` to `read_paths` merely to make a smoke test pass: every
process in that sandbox would receive the same read access. A registered and
online Mac host is therefore not yet evidence of a safely usable unattended
Codex worker.

The Mac host service must set both values below. The second one explicitly
allows only the first setting through Omnigent's runner environment filter:

```text
HARNESS_CODEX_MINIMAL_CONFIG=1
OMNIGENT_RUNNER_ENV_PASSTHROUGH=HARNESS_CODEX_MINIMAL_CONFIG
```

Restart the per-user LaunchAgent after changing it and verify the same host ID
is connected using the authenticated status/UI procedure above.

From the target project checkout:

```bash
omni run /etc/omnigent-worker/omnibox-base.yaml \
  --server https://YOUR_PRIVATE_OMNIGENT_NAME
```

The baseline recursively masks hidden files except `.git` and `.venv`, masks
common explicit secret paths, and grants writes only to the project working
directory. It starts with unrestricted network access solely for supervised
native-subscription compatibility. Before unattended work, replace that with
reviewed per-project `egress_rules`; their presence makes HTTP(S) default-deny.
Do not enable private destinations for ordinary coding work.

Omnibox does not contain MCP subprocesses: Omnigent starts those outside the
OS sandbox. Treat every MCP declaration as a separate trust boundary and
constrain it at its own configuration site. Prefer server-managed MCP
connections so their upstream credentials do not need to exist on the worker.

Then confirm in Omnigent:

- the host appears once with the intended name;
- a no-op task can be explicitly targeted to it;
- disconnect/reconnect does not create a duplicate host;
- revoking the host prevents new execution;
- an MCP tool selected through the registry works without an upstream credential file on the worker.

For native subscription harnesses, also prove that a real model turn succeeds
without making a token file readable to a shell spawned inside the same
sandbox. If the harness needs that read permission, stop at the compatibility
gate rather than weakening the profile.

Reboot once and prove that neither native subscription can be used before the
encrypted disk/keyring is unlocked. Unlock it once, disconnect the interactive
session, and prove the persistent Omnigent host can still run both CLIs. This is
the required 24/7 behavior: unattended between reboots, human unlock after a
reboot or power loss.

`/etc/omnigent-worker.conf` records the non-secret endpoint for operations and
inventory. Omnigent's own CLI configuration remains authoritative for login and
the persistent host service.

Use `home-worker` for scheduled/long-running work. Treat `laptop-worker` as
interactive capacity unless it is deliberately kept awake and powered.

See the [subscription credential decision](../decisions/subscription-cli-credentials.md)
for the security boundary and acceptance gates.
