# Contributing

Thank you for helping improve this project. Infrastructure changes can affect
real machines, credentials, and cloud bills, so contributions must preserve the
safe defaults.

## Development

1. Fork the repository and create a focused branch.
2. Do not add secrets, account identifiers, state files, VM disks, or backups.
3. Keep tool, provider, container, and GitHub Action versions explicit.
4. Update the relevant decision record or runbook when behavior changes.
5. Run `make validate` and include the result in the pull request.

Pull requests must not deploy infrastructure. Maintainers perform deployments
separately after reviewing a plan and the documented gates.

## Release changes

Change `VERSION` and `CHANGELOG.md` in a reviewed pull request. A maintainer then
creates an annotated or signed tag matching `v$(cat VERSION)`. Only that tag can
trigger the release workflow.

By participating, you agree to follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
