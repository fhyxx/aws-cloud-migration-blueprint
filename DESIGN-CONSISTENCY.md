# Design Consistency Register

| Item | Canonical baseline |
|---|---|
| Region | `us-east-1` |
| VPC | `10.30.0.0/16` |
| Steady-state subnets | 2 AZs; 2 public, 2 app, 2 DB |
| Migration subnet | Dedicated private MGN staging subnet required in addition to steady-state six; subnet sizing/CIDR to be allocated |
| Application | 2 × 4 vCPU / 16 GiB; `t3.xlarge` is cost proxy only |
| Source DB | PostgreSQL VM, 8 vCPU / 32 GiB / 500 GB logical data |
| Target DB | RDS PostgreSQL Multi-AZ DB instance deployment; 500 GB provisioned-storage assumption per instance; primary + standby billed |
| Shared files | 1 TB Regional EFS; mount target in each app AZ |
| Archives | 500 GB S3 Standard via S3 Gateway Endpoint where appropriate |
| NAT | 2 NAT Gateways; same-AZ app egress |
| VPN | 1 standard Site-to-Site VPN / VGW design; exact product rate unpriced pending calculator |
| Entry | 1 public ALB, HTTPS 443; ACM certificate and Route 53 alias required implementation details |
| App port | TCP 8080 provisional; discovery required |
| Business objectives | 99.9% availability; RTO 4h; RPO 15m; not demonstrated |
| Deployment | Not deployed; no tests executed |
| Cost status | No approved total; earlier $2,214–$2,702/month worksheet is superseded |

The architecture diagram, README, design documents, runbook and cost model should use these same baseline quantities. Pricing rates marked pending must be validated in AWS Pricing Calculator. The MGN staging subnet is an additional migration-only subnet, not part of the six steady-state subnets. The 500 GB RDS provisioned-storage assumption is counted for both primary and standby for pricing.

## Review gates

- Architecture and migration flows: source reviewed; diagram visual rendering remains pending.
- Network/security: proposed controls and MGN staging requirements documented; no deployed validation.
- PostgreSQL: DMS prerequisites, schema/object migration, CDC, WAL/slot, constraints/triggers and sequence reconciliation documented; no source-version compatibility test.
- Pricing: exact class/configuration and exported AWS Pricing Calculator estimate outstanding.
- Operational validation: monitoring thresholds, ASG scaling policy, application SLO thresholds, recovery test and acceptance evidence outstanding.
