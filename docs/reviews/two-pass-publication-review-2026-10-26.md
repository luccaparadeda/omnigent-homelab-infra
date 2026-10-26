# Two-pass publication and release review

Date: 2026-10-26
Scope: GitHub workflows, release scripts, and public-project governance. No
infrastructure was deployed and no credential was enrolled.

## Pass 1 — CI trust and pull-request safety

| Severity | Finding | Resolution |
|---|---|---|
| High | Mutable action tags allow an upstream tag change to alter privileged CI. | Every external action is pinned to a 40-character commit SHA; a repository test rejects mutable refs. |
| High | A deployment credential in CI would turn a source compromise into an OCI or worker compromise. | No deployment workflow or cloud credential is defined. CI only reads source and validates configuration. |
| High | `pull_request_target` can execute attacker-controlled changes with target-repository privileges. | The trigger is prohibited by a static workflow guard. Pull requests use the read-only `pull_request` event. |
| Medium | Default token permissions can drift to write access. | Workflows declare read-only permissions globally and elevate only the release, CodeQL, and Scorecard jobs for documented outputs. Repository publication sets the GitHub default to read-only. |
| Medium | Workflow syntax was validated locally but actionlint was not installed by hosted CI. | CI and release jobs install pinned actionlint 1.7.10 before `make validate`. |
| Medium | Dependency or IaC regressions could pass ordinary syntax checks. | Dependency Review, Trivy configuration scanning, CodeQL for Actions, and OpenSSF Scorecard workflows are separate required signals. |

## Pass 2 — release integrity and recoverability

| Severity | Finding | Resolution / gate |
|---|---|---|
| High | A tag on an unreviewed commit could publish a valid-looking release. | The release script requires exact semantic versioning, equality with `VERSION`, a tag at `HEAD`, and ancestry from `origin/main`. |
| High | Packaging the workspace could include ignored secrets or generated state. | Archives are built with `git archive` from the exact tag, never from the working tree. |
| High | Consumers lacked a way to inspect or verify a release. | Each release includes SHA-256 checksums, an SPDX JSON SBOM, and GitHub provenance/SBOM attestations. |
| Medium | Generating an SBOM after archives existed could make the source SBOM describe its own derived bundles. | SBOM generation now occurs before archive creation; all outputs are checksummed afterward. |
| Medium | Tags alone do not stop release assets from being replaced. | The publication script enables GitHub immutable releases. This remains an external gate until GitHub authentication is valid. |
| Medium | Branch protection configured before a successful status exists can lock out a maintainer. | The protection script refuses to run until `main` has a successful `ci.yml` run, then requires the stable `Validate` context. |

## Review evidence

- `make validate` passes locally, including shellcheck, actionlint, Compose,
  static policy guards, YAML parsing, Ansible syntax, and ansible-lint.
- The validation environment installs successfully from
  `requirements-dev.lock` with `pip --require-hashes`.
- Packer and OpenTofu are initialized and validated in hosted CI at their pinned
  versions; neither workflow has an apply or deploy step.
- Publication is intentionally blocked if the GitHub CLI is unauthenticated, the
  tree is dirty, the target repository already exists, or `origin` is present.
