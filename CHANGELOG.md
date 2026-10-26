# Changelog

All notable changes are documented here. This project follows Semantic
Versioning and publishes immutable release bundles from exact `vMAJOR.MINOR.PATCH`
tags.

## [Unreleased]

### Added

- Security-first Oracle Always Free control-plane and Vault topology.
- Bare-metal Ubuntu worker autoinstall, Ansible roles, and optional Packer test image.
- Subscription-authenticated Codex and Claude worker credential boundary.
- Reproducible validation, security scanning, SBOM, provenance, and release workflows.
- Non-root Vault bind-mount ownership and deployable reviewed policy files.
- Tokenless Omnigent-to-Vault authentication through Vault Proxy and OCI instance principals.
- Scheduled `age`-encrypted Vault Raft snapshots uploaded with an OCI instance principal.
- Loopback-only Omnigent binding published privately through persistent Tailscale Serve HTTPS.
