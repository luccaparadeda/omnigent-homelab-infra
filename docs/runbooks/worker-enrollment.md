# Worker enrollment

Each machine gets a distinct Omnigent host identity. Managed MCP credentials
remain server-side where the gateway supports them. Native Codex and Claude
subscription sessions are deliberately worker-local because those CLIs execute
on the worker; this design uses no paid model API keys.

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

Then confirm in Omnigent:

- the host appears once with the intended name;
- a no-op task can be explicitly targeted to it;
- disconnect/reconnect does not create a duplicate host;
- revoking the host prevents new execution;
- an MCP tool selected through the registry works without an upstream credential file on the worker.

Reboot once and prove that neither native subscription can be used before the
encrypted disk/keyring is unlocked. Unlock it once, disconnect the interactive
session, and prove the persistent Omnigent host can still run both CLIs. This is
the required 24/7 behavior: unattended between reboots, human unlock after a
reboot or power loss.

`/etc/omnigent-worker.conf` records the non-secret endpoint for operations and
inventory. Omnigent's own CLI configuration remains authoritative for login and
the persistent host service.

Use `home-worker` for scheduled/long-running work. Treat `laptop-worker` as interactive capacity unless it is deliberately kept awake and powered.

See the [subscription credential decision](../decisions/subscription-cli-credentials.md)
for the security boundary and acceptance gates.
