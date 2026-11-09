# Project 03 — Technical Sign-off

**Project:** Clafoke Investors Ltd — fictional AWS Cloud Migration Blueprint  
**Sign-off date:** 9 November 2026  
**Repository baseline:** `main` at `93a2280e8188f67f87ccccf33c3c7e3096944ce3` (superseded by the sign-off documentation commit when merged)  
**Decision:** **Portfolio design deliverable signed off; live implementation remains not approved.**

## 1. Sign-off scope

This sign-off covers the completeness and internal consistency of the fictional architecture, network design, Terraform baseline, migration-service configuration, cost model, documentation, evidence register and synthetic CI controls. It does not authorise or claim an AWS deployment.

## 2. Technical areas reviewed

| Area | Sign-off result | Boundary / remaining condition |
|---|---|---|
| Target architecture | Pass for portfolio design | Two-AZ target pattern and migration flows are documented; production workload fit remains unmeasured. |
| Network foundation | Pass for design and static consistency | Eleven-subnet layout; dedicated route tables; BGP propagation limited to five migration-only route tables. Live routing, VPN and firewall tests remain outstanding. |
| Terraform | Pass for synthetic validation baseline | Opt-in workload and migration layers default off; synthetic no-refresh plans and Terraform validation are CI evidence, not live AWS plans or applies. |
| MGN | Pass for guarded design | IAM/bootstrap and replication-template workflow is opt-in, resumable and private by design; source compatibility and replication tests remain outstanding. |
| DMS | Pass for guarded design | Dedicated two-AZ subnet group, private non-Multi-AZ provisioned replication instance, TLS-required PostgreSQL endpoints and stopped full-load/CDC task. Version compatibility, sizing and data reconciliation remain outstanding. |
| DataSync | Pass for guarded design | Dedicated endpoint/task subnets; NFSv4.1-to-EFS task uses BASIC mode; Enhanced mode is not supported for this NFS-to-EFS path. Agent activation and transfer tests remain outstanding. |
| Security | Conditional design pass | Trust scoping, secret handling, encryption and traffic boundaries are documented. The public HTTPS ALB ingress baseline and proposed DMS egress policy require environment-specific security approval before deployment. |
| Cost model | Pass for arithmetic controls; estimate incomplete | Six-service steady-state calculator subtotal is $1,930.76/month ($23,169.12 annualised). Migration-period costs and several usage meters remain unpriced; this is not a complete bill or approved budget. |
| Evidence and diagrams | Pass for repository evidence | Three Mermaid views match their editable sources; user visually confirmed GitHub rendering of the runtime/network view. Evidence clearly distinguishes repository/synthetic checks from live implementation evidence. |

## 3. Canonical network baseline

- VPC: `10.30.0.0/16`, Region `us-east-1`.
- Six steady-state subnets across two AZs: public, application and database tiers.
- Five additional migration-only subnets: MGN staging `10.30.31.0/24`; DMS-A/B `10.30.41.0/24` and `10.30.42.0/24`; DataSync endpoint/task `10.30.51.0/24` and `10.30.52.0/24`.
- VGW BGP propagation is restricted to the five migration route tables. Public, application and database route tables do not receive the on-premises route.
- DMS uses a two-AZ subnet group, but the configured replication instance is explicitly non-Multi-AZ. The two-AZ subnet group must not be described as Multi-AZ replication-instance resilience.

## 4. Cost sign-off boundary

The saved Pricing Calculator subtotal is $1,930.76/month, comprising the six documented steady-state service entries. The migration group is empty because MGN infrastructure, DMS sizing/runtime, DataSync source/archive bytes, temporary network usage and overlap dates are not yet sufficiently measured. Empty or zero placeholders must not be represented as zero migration cost. The saved share URL is public to anyone who receives it; do not place confidential information in the estimate.

## 5. CI and repository evidence

The latest verified main-branch network-foundation workflow is [run #104](https://github.com/fhyxx/aws-cloud-migration-blueprint/actions/runs/42644692954), completed successfully against commit `93a2280e8188f67f87ccccf33c3c7e3096944ce3`. The preceding PR checks for the evidence/route-scope and runbook/network-review changes also passed (runs #101 and #103). CI validates repository code and synthetic assumptions; it does not call AWS APIs or prove account-specific permissions, quotas, service availability, live connectivity or service pricing.

## 6. Explicit exclusions — not performed

- No AWS infrastructure was deployed or modified.
- No migration service was activated.
- No source-to-target data transfer, full load, CDC, file transfer or archive migration was run.
- No performance/load, cutover, rollback, backup restore, failover or disaster-recovery test was executed.
- No measured RTO/RPO, production capacity, customer approval or production cost baseline is claimed.

## 7. Gates before any real implementation

1. Replace fictional CIDRs, AZs, BGP values, source inventory and credentials with approved environment facts.
2. Resolve security review items, including public ALB ingress, DMS egress, endpoint policies, NACLs, DNS and customer firewall rules.
3. Validate current AWS service prerequisites, quotas, regional availability, IAM trust/policies and Terraform provider/resource behaviour in the target account.
4. Capture an account-authenticated Terraform plan and obtain explicit change approval before any apply or chargeable resource creation.
5. Benchmark DMS and application sizing; validate PostgreSQL compatibility and reconciliation; inventory NFS/archive bytes and permissions.
6. Price migration infrastructure, transfer/network usage, parallel running and decommissioning using measured quantities and an approved calendar.
7. Execute and retain approved connectivity, transfer, cutover, rollback, restore, resilience and business acceptance evidence.

## 8. Final decision

**Project 03 is technically signed off as a fictional, design-led portfolio case study with internally consistent architecture, guarded Terraform definitions, cost guardrails, documented evidence and passing synthetic CI. It is not signed off for live implementation, and it is not a completed cloud migration.**

The next real-world step is not an AWS apply. It is environment-specific discovery and review against the gates above, followed by a separately authorised implementation plan.
