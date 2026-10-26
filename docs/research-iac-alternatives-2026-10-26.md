# Provisioning alternatives and recommended operating model

Date: 2026-10-26
Status: researched recommendation; no cloud resources have been created and the current OpenTofu code has not been replaced.

## Decision in one paragraph

OpenTofu should not be a prerequisite for this homelab. The recommended long-term split is **OCI Resource Manager with Terraform for Oracle resources**, **Ansible for machine and service configuration**, **minimal cloud-init for first boot**, and **Tailscale for the private network**. For the first installation, create the two Always Free instances manually in a dedicated OCI compartment, enroll them in Tailscale, and run Ansible. Once the layout is proven, keep an OCI Resource Manager stack as the rebuild and drift-management definition. This avoids a local state file and a long-lived OCI API signing key while retaining a reviewed plan, state locking, and repeatable disaster recovery.

## What each layer owns

| Layer | Recommended owner | Reason |
|---|---|---|
| OCI VCN, subnet, NSGs, instances, IAM, KMS, bucket and backup policy | OCI Resource Manager | Oracle-managed state and locking, reviewed plan/apply jobs, no dedicated charge |
| Initial SSH user, public key and Python | cloud-init | Smallest reliable bootstrap before configuration management |
| Ubuntu packages, hardening, Docker, Compose, Omnigent, PostgreSQL, Vault and worker service | Ansible | One idempotent configuration path for manually created OCI VMs, the home worker and the laptop |
| Private reachability | Tailscale | Handles NAT and roaming without exposing Omnigent, Vault or SSH publicly |
| Runtime application layout | Docker Compose plus systemd | Appropriate for two small VPS nodes; Kubernetes adds no useful capability here |
| Fast VPS recovery | OCI boot-volume backups | Point-in-time recovery after a validated release |
| Authoritative recovery | Git configuration plus encrypted logical backups | Images alone do not safely back up databases, Vault state or recovery material |
| Home-worker VM image, if the worker runs under KVM | Packer/QEMU, optional | Useful only when cloning a Linux VM; unnecessary for a native Linux installation |

## Why OCI Resource Manager is the best OpenTofu alternative here

OCI Resource Manager is Oracle's managed infrastructure-as-code service. It currently supports HashiCorp Terraform, not OpenTofu. Oracle documents Terraform 1.5.7 as the supported 1.5.x CLI, managed stack state, one-job-at-a-time state locking, plan/apply/destroy jobs, Git or zip configuration sources, and no dedicated Resource Manager charge.

For this project it has four material advantages over running OpenTofu locally:

1. The infrastructure state stays in OCI and is locked during jobs.
2. The Oracle provider is configured by the managed service; the laptop does not need to retain an OCI API private key merely to run plans.
3. A plan is visible before an apply, unlike a collection of imperative CLI scripts.
4. The stack remains available when the laptop is off.

The tradeoff is important: Resource Manager trails current Terraform/OpenTofu releases and is tied to Oracle. The configuration must therefore stay within Terraform 1.5-compatible HCL and avoid OpenTofu-only features. This is acceptable for a small OCI-only foundation.

## Alternatives evaluated

Scores are relative to this two-VPS/two-worker deployment, where 5 is best.

| Option | Simplicity | Safe lifecycle | Credential posture | Recovery | Fit |
|---|---:|---:|---:|---:|---|
| OCI Resource Manager + Ansible | 4 | 5 | 5 | 5 | **Recommended steady state** |
| Manual OCI Console + Ansible | 5 | 2 | 5 | 3 | **Recommended first deployment** |
| Ansible-only with `oracle.oci` | 4 | 3 | 4 | 4 | Good if one tool is the overriding goal |
| Local OpenTofu + Ansible | 3 | 5 | 3 | 5 | Good open-source/local option, but we own state and OCI authentication |
| Local Terraform + Ansible | 3 | 5 | 3 | 5 | Similar to OpenTofu with a different license and release path |
| Pulumi + Ansible | 2 | 4 | 3 | 4 | Adds a language runtime and another state system; its OCI package is based on the Terraform OCI provider |
| OCI CLI shell scripts | 3 | 2 | 3 | 2 | Useful for narrow operations, not as the system of record |
| Crossplane/Kubernetes | 1 | 4 | 3 | 4 | A control plane larger than the workload; rejected |
| NixOS for all nodes | 2 | 5 | 4 | 5 | Strong reproducibility, but a disruptive OS/package change with little benefit for this deployment |

### Ansible-only OCI provisioning

Oracle maintains the `oracle.oci` collection, including compute, network, IAM, KMS, Object Storage, backup and dynamic-inventory modules. OCI Cloud Shell includes preauthenticated Oracle tooling, so the infrastructure playbook can be run there without keeping an API signing key on the laptop.

This is a valid simpler alternative, but it is not the primary recommendation because Ansible does not provide the same resource graph, saved plan, state locking or explicit destroy lifecycle as Resource Manager. Ansible is strongest at converging an operating system and service configuration; Resource Manager is stronger at owning cloud resource identity and lifecycle.

### Pulumi

Pulumi supports OCI in TypeScript, Python, Go, .NET, Java, YAML and HCL. Its OCI package is based on the OCI Terraform provider. It would replace HCL with an application language but still introduce a state backend, a language runtime and a separate update workflow. There is no compensating benefit for a fixed topology of two VMs.

### OCI CLI scripts

CLI commands are appropriate for operations such as taking a labelled boot-volume backup. They are a poor primary provisioning system because we would need to implement discovery, retries, idempotency, dependency ordering, change previews and deletion semantics ourselves.

## Recommended deployment sequence

### Phase 1: secure the scarce free resources

1. Create a dedicated compartment such as `omnigent-homelab` in the tenancy home region.
2. Create the control VM as `VM.Standard.A1.Flex`, 1 OCPU, 8 GB RAM, 50 GB boot volume.
3. Create the Vault VM as `VM.Standard.A1.Flex`, 1 OCPU, 4 GB RAM, 50 GB boot volume.
4. Confirm the **Always Free eligible** marker before creation. The documented aggregate is 2 OCPUs and 12 GB, and the two boot volumes consume 100 GB of the 200 GB free block-volume allowance.
5. Permit only temporary SSH from the operator's current `/32`, enroll each server manually with a one-off tagged Tailscale key, verify private access, and remove public SSH ingress.
6. Do not expose Omnigent, PostgreSQL, Vault or the Docker socket on the public interface.

Manual creation is intentional in this phase: Always Free A1 capacity can be unavailable in an availability domain, and the Console makes capacity and the free-eligibility label visible before creation.

### Phase 2: converge the machines

Run Ansible from a trusted administrator machine over Tailscale:

1. Apply the common hardening role.
2. Configure Vault first, using OCI KMS auto-unseal and the VM's instance principal.
3. Initialize Vault once, enable Transit, and create the Omnigent derived Transit key.
4. Issue Omnigent a policy/token restricted to the required Transit encrypt/decrypt operations.
5. Configure PostgreSQL and Omnigent on the control VM.
6. Create the first Omnigent administrator while the service is private.
7. Enroll the home PC and laptop independently with `omni login <server-url>` and `omni host <server-url>`; use `omni host enable` when a persistent per-user host service is wanted.

Ansible should remain push-based and operator-reviewed. A continuously running AWX/Semaphore controller is unnecessary for four machines and would consume resources without improving the security boundary.

### Phase 3: make the Oracle layer reproducible

After the manual layout and names are stable:

1. Convert the existing `infra/oci` configuration to Terraform 1.5.7-compatible syntax.
2. Remove local-only authentication arguments from the Resource Manager provider configuration; Resource Manager needs only the region in the provider block.
3. Upload the configuration as a zip for the first stack. A Git configuration source can be added only after the user chooses to create a remote repository.
4. Either import the known resources carefully or use Resource Manager's resource-discovery workflow in the dedicated compartment, review the generated configuration, and reconcile it with the repository.
5. Run a plan and require a human review before every apply.
6. Keep the free-tier OCPU, RAM, boot-volume and backup limits as validation conditions in the Terraform configuration.

Resource discovery is not permission to accept generated code blindly. In particular, verify lifecycle flags on KMS keys, boot volumes and buckets before the first managed apply.

## Networking decision

Use Tailscale unless avoiding a third-party coordination service is a hard requirement.

- The Personal plan is currently free for personal/non-commercial use and is more than sufficient for four nodes.
- Tag the two VPS nodes as infrastructure resources; keep the laptop and operator workstation user-authenticated.
- Use Tailscale grants with default-deny rules. Only the control VM needs to reach Vault TCP 8200; workers need the Omnigent endpoint; administrator devices need SSH.
- Use one-off, pre-approved, tagged auth keys for server enrollment. Do not place reusable auth keys in cloud-init, Ansible variables, shell history or an image.
- Prefer Tailscale SSH with reauthentication for administration, or conventional SSH restricted to the Tailscale interface.

Raw WireGuard remains a viable zero-service alternative, but we would own peer distribution, endpoint changes, NAT traversal and revocation. That is unnecessary operational work for this topology.

## Omnigent and credential findings

Omnigent 0.19.1 is the current security patch release found during this research. Its architecture matches the requested topology:

- The server persists sessions, artifacts, catalog entries, policies and accounts.
- A registered host starts per-session runners on the home PC or laptop.
- The UI talks to the server; it does not connect directly to the runners.
- A server without an online runner remains reachable but cannot perform worker execution.

For managed MCP connections, Omnigent 0.19 added an MCP registry and server gateway. Accounts can be connected centrally and selected for agents; calls go through the server gateway and policy checks. The credential store binds ciphertext to workspace, user, provider and account identity. This supports different credentials across projects/agents without permanently binding every project to one credential.

On OCI, Omnigent's documented at-rest cipher choice is HashiCorp Vault Transit. The Transit key must have `derived=true`. Omnigent currently documents `VAULT_ADDR`, `VAULT_TOKEN`, the mount and the key name, so the control VM still needs a bootstrap credential. That token must be narrowly scoped, stored root-only, audited and rotated; a separate Vault VM does not remove this bootstrap requirement.

Not every credential moves to the server. The accepted model-authentication
decision is subscription-only: use the user's existing Codex and Claude
subscriptions and do not configure paid model API keys.

- Managed MCP credentials can live in Omnigent's encrypted server-side store.
- Native Claude and Codex subscription logins remain in the password-unlocked
  OS keyring used by the execution host.
- Hermes brings its own file-based authentication under `HERMES_HOME`; Omnigent documents that it does not store or inject the Hermes credential.

Therefore a home or laptop runner still carries device-local harness
credentials. Full-disk encryption and a password-unlocked keyring protect them
at rest, but the same unlocked worker user can invoke them at runtime. Rootful
Docker access is prohibited for that account. The worker requires one human
unlock after reboot, then can run unattended while it remains unlocked. See the
[subscription credential decision](decisions/subscription-cli-credentials.md).

## Golden images and backups

A golden image and a backup solve different problems.

### Oracle VPS nodes

Use the current Ubuntu 24.04 ARM64 platform image plus minimal cloud-init and Ansible as the reproducible build. After validation, take a labelled OCI boot-volume backup for fast rollback. Oracle currently includes five boot/block-volume backups in the Always Free allowance, while custom-image storage is billed. A boot backup is crash-consistent, not an application-consistent replacement for database backups.

Recommended five-backup allocation:

- two most recent validated control-plane boot backups;
- two most recent validated Vault boot backups;
- one temporary slot used during an upgrade or restore drill.

### Home PC and laptop

- The home PC is dedicated exclusively to agents. Use the guarded Ubuntu autoinstall seed plus the same Ansible role; the physical machine is the security boundary and a VM layer adds no required isolation from personal workloads.
- Retain the Packer/QEMU image only for disposable testing or a future virtual worker; a QCOW2 image is not useful for this bare-metal installation.
- Treat the laptop as an enrolled endpoint, not as a restorable server image. Back up its project data normally and rebuild its worker tooling with Ansible.

### Data recovery

Maintain three independent recovery streams:

1. PostgreSQL logical dump plus Omnigent artifacts, encrypted before upload to OCI Object Storage.
2. Vault Raft snapshots, encrypted and copied off the Vault node, with recovery material stored offline.
3. OCI boot-volume backups after known-good releases.

Test restoration. A successful backup command is not evidence that Omnigent sessions, MCP ciphertext and Vault keys can be recovered together.

## 24/7 execution boundary

The free Oracle allocation keeps the **control plane** online. It does not guarantee 24/7 execution if both workers are asleep or disconnected. With the proposed 1-OCPU control VM and 1-OCPU Vault VM, the control VM can serve as an emergency low-intensity runner, but substantial agent work will contend with Omnigent and PostgreSQL.

For genuinely continuous execution, the home PC must remain powered, connected and registered as a service. The laptop is an additional interactive worker, not automatic failover. A future paid or separately hosted worker can be added without changing the control-plane design.

## What changes in this repository if the recommendation is accepted

1. Keep `ansible/`, `compose/`, `scripts/` and the optional worker image.
2. Make the manual-OCI-plus-Ansible runbook the primary quick start.
3. Replace the current OpenTofu-specific version constraint with an OCI Resource Manager-compatible Terraform 1.5.7 stack under `infra/oci-resource-manager/`.
4. Add `oracle.oci` only if we choose dynamic inventory or Ansible-driven OCI operations; do not add it merely because it exists.
5. Keep local OpenTofu code in a clearly labelled optional archive until the Resource Manager plan has been validated, then remove it in a separate reviewed change.
6. Add a restore test that proves PostgreSQL, artifacts and Vault Transit ciphertext can be restored as one system.

## Primary sources

- Oracle Resource Manager overview and state management: <https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/resourcemanager.htm>
- Oracle Resource Manager supported IaC tools: <https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/iac-tools.htm>
- Oracle Resource Manager supported Terraform versions: <https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Reference/terraformversions.htm>
- Oracle Resource Manager pricing FAQ: <https://www.oracle.com/uk/cloud/cloud-native/resource-manager/faq/>
- Terraform configurations for Resource Manager: <https://docs.oracle.com/en-us/iaas/Content/ResourceManager/Concepts/terraformconfigresourcemanager.htm>
- Oracle Always Free resources: <https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm>
- OCI Ansible collection getting started: <https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/ansiblegetstarted.htm>
- OCI Ansible inventory plugin: <https://docs.oracle.com/en-us/iaas/tools/oci-ansible-collection/5.5.0/inventory_plugin/index.html>
- OCI instance-principal authentication: <https://docs.oracle.com/en-us/iaas/Content/API/Concepts/sdk_authentication_methods.htm>
- OCI boot-volume backups: <https://docs.oracle.com/en-us/iaas/Content/Block/Concepts/bootvolumebackups.htm>
- OCI custom images: <https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/managingcustomimages.htm>
- Pulumi OCI provider: <https://www.pulumi.com/registry/packages/oci/installation-configuration/>
- OpenTofu migration and compatibility: <https://opentofu.org/docs/intro/migration/>
- Tailscale Personal plan: <https://tailscale.com/pricing>
- Tailscale auth-key guidance: <https://tailscale.com/docs/features/access-control/auth-keys>
- Tailscale access control: <https://tailscale.com/docs/features/access-control>
- Omnigent shared-server architecture: <https://omnigent.ai/docs/deploy/overview>
- Omnigent credential store: <https://omnigent.ai/docs/deploy/credential-store>
- Omnigent 0.19.1 release: <https://omnigent.ai/releases>
- Omnigent models and credentials: <https://omnigent.ai/docs/build/models>
- Vault OCI KMS auto-unseal: <https://developer.hashicorp.com/vault/docs/configuration/seal/ocikms>
- Vault integrated storage: <https://developer.hashicorp.com/vault/docs/configuration/storage/raft>
