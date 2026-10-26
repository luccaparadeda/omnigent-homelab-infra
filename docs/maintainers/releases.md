# Release guide

Releases are source/configuration bundles, not VM images and not deployments.
The release workflow contains no OCI, Vault, Tailscale, Omnigent, Codex, Claude,
or MCP credential.

## Prepare

1. Merge a reviewed pull request that updates `VERSION` and `CHANGELOG.md`.
2. Confirm `make validate` passes on the final commit.
3. Confirm the `Validate`, `Trivy configuration scan`, and CodeQL checks pass.
4. Create a signed tag when local signing is configured; otherwise create an
   annotated tag and verify the GitHub release provenance after publication.

```bash
version=$(tr -d '[:space:]' < VERSION)
git tag -s "v$version" -m "Release v$version"
git push origin "v$version"
```

The tag must exactly match `vMAJOR.MINOR.PATCH` and `VERSION`. Moving or reusing
a release tag is prohibited.

## Verify

The tag-only workflow validates the source and publishes:

- `.tar.gz` and `.zip` source archives;
- `SHA256SUMS`;
- an SPDX JSON software bill of materials;
- GitHub provenance and SBOM attestations.

Download the release assets in a clean directory and verify the checksums:

```bash
sha256sum --check SHA256SUMS
gh attestation verify ./omnigent-homelab-infra-v*.tar.gz \
  --repo luccaparadeda/omnigent-homelab-infra
```

On macOS, use `shasum -a 256 -c SHA256SUMS` for the checksum step.
