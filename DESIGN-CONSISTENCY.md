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
| VPN | 1 standard Site-to-Site VPN / VGW design; saved connection-hours $36.50 plus two tunnel public IPv4 addresses $7.30 = $43.80/month; VPN transfer remains unpriced |
| Entry | 1 public ALB, HTTPS 443; public DNS record and ACM certificate are required; Route 53 alias is conditional on Route 53 being the authoritative DNS host |
| App port | TCP 8080 provisional; discovery required |
| Business objectives | 99.9% availability; RTO 4h; RPO 15m; not demonstrated |
| Deployment | Not deployed; no tests executed |
| Cost status | Partial calculator subtotal $1,923.46/month ($23,081.52 annualised), including audited VPN public IPv4; no approved total; earlier $2,214–$2,702/month worksheet is superseded |

The architecture diagram, README, design documents, runbook and cost model should use these same baseline quantities. DNS provider/delegation and Route 53 zone count remain undecided; do not infer Route 53 authority from the diagram's icon. Unsaved Route 53 ($0.90 / $4.50 / $41.00) and CloudWatch ($11.57 / $67.95 / $423.15 at 30-day retention) pricing scenarios are illustrative, pending validation and excluded from the saved subtotal. 90/365-day CloudWatch retention extensions are independent calculations, not Calculator results. A partial AWS Pricing Calculator baseline of $1,923.46/month ($23,081.52 annualised) is saved; it is not a complete or approved budget. Remaining usage and migration inputs must be validated in AWS Pricing Calculator. The MGN staging subnet is an additional migration-only subnet, not part of the six steady-state subnets. The 500 GB RDS provisioned-storage assumption is counted for both primary and standby for pricing.

## Review gates

- Architecture and migration flows: source reviewed; diagram visual rendering remains pending.
- Network/security: proposed controls and MGN staging requirements documented; no deployed validation.
- PostgreSQL: DMS prerequisites, schema/object migration, CDC, WAL/slot, constraints/triggers and sequence reconciliation documented; no source-version compatibility test.
- Pricing: partial AWS Pricing Calculator baseline is saved at $1,923.46/month ($23,081.52 annualised); production suitability validation, unresolved workload inputs, migration costs and final export/reconciliation remain outstanding.
- Operational validation: monitoring thresholds, ASG scaling policy, application SLO thresholds, recovery test and acceptance evidence outstanding.
