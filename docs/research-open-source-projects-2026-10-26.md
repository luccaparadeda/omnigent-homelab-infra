# Related-project research (2026-10-26)

This review looked for maintained projects that combine a small control plane,
home execution workers, reproducible host configuration, private networking,
and open-source release hygiene. None of the reviewed projects provides the
same subscription-authenticated Omnigent topology end to end, so this repository
borrows narrow patterns rather than importing another platform wholesale.

## Projects reviewed

| Project | Relevant idea | Decision here |
|---|---|---|
| [Omnigent](https://github.com/omnigent-ai/omnigent) | Upstream server/host separation and Docker deployment examples | Preserve the control-plane/worker split, but keep host enrollment and credentials outside images and CI. |
| [khuedoan/homelab](https://github.com/khuedoan/homelab) | Rebuildable homelab using Terraform, Ansible, GitOps, tests, and documentation | Adopt reproducibility and reviewable automation; avoid its Kubernetes-scale operating burden for two workers. |
| [onedr0p/home-ops](https://github.com/onedr0p/home-ops) and [cluster-template](https://github.com/onedr0p/cluster-template) | Mature GitOps, Renovate, policy, and recovery conventions | Adopt dependency automation and policy-as-code ideas; do not add Flux or Kubernetes to this small topology. |
| [Chef Bento](https://github.com/chef/bento) | Packer templates with repeatable build and test conventions | Keep Packer limited to credential-free optional image testing and retain bare-metal autoinstall as the home-PC path. |
| [Pocket Lab](https://github.com/Ellebam/Pocket-Lab) | Ansible-driven self-hosted AI services | Reuse the small-host, idempotent configuration approach while keeping Omnigent's execution model. |
| [Quest](https://github.com/electric-capital/quest) | Self-hosted AI workbench with security-oriented OAuth boundaries | Treat interactive subscription login and managed integration credentials as separate trust boundaries. |
| [BenSuskins/homelab](https://github.com/BenSuskins/homelab) | Ansible, Terraform, Docker, Tailscale, and Renovate in a compact homelab | Confirm the practical split between provisioning, configuration, containers, and private networking. |

## Supply-chain conclusions

GitHub's secure-use guidance recommends least-privilege workflow tokens and
pinning third-party actions to full commit SHAs. Public repositories can also
use artifact attestations, dependency review, CodeQL, and private vulnerability
reporting without placing deployment credentials in a release workflow.

Accordingly, this repository uses:

- read-only workflow permissions by default and explicit permissions per job;
- immutable SHA pins for every external action;
- hash-locked Python validation dependencies;
- static secret, workflow, shell, Ansible, OpenTofu, Packer, Compose, and IaC security checks;
- exact semantic-version tags, checksums, SPDX SBOMs, and provenance attestations;
- no CI deployment identity and no workflow that can apply infrastructure.

## Sources

- [GitHub Actions secure use](https://docs.github.com/en/actions/reference/security/secure-use)
- [GitHub artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)
- [GitHub immutable releases](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/prevent-release-changes)
- [GitHub private vulnerability reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/configure-vulnerability-reporting/configure-for-a-repository)
- [OWASP DevSecOps release guidance](https://owasp.github.io/DevSecOpsGuideline/2-Process/2-5-Release/2-5-1-Release/)
