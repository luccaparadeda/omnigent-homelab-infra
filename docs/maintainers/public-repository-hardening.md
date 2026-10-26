# Public repository hardening

The repository should be created only after `make validate` succeeds. These
settings are repository controls, not infrastructure deployment.

## Automated settings

After the first push, enable:

- private vulnerability reporting;
- dependency graph, vulnerability alerts, and automated security updates;
- immutable releases;
- read-only default GitHub Actions token permissions;
- a protected `main` branch requiring the stable `Validate` status check,
  linear history, and no force pushes or deletion.

## Account-dependent settings

The owner must confirm these in GitHub because they affect the whole account or
can make a single-maintainer repository unusable:

- two-factor authentication and passkeys;
- signed commits/tags or vigilant mode;
- whether an independent reviewer is available for required approvals;
- recovery contacts and organization ownership, if the project moves to an organization.

Do not require one approving review on a sole-maintainer personal repository;
the author cannot approve their own pull request. Add that requirement only
after a second trusted maintainer joins.
