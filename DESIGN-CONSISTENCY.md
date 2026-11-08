# Design Consistency Register

| Item | Canonical baseline |
|---|---|
| Region | `us-east-1` |
| VPC | `10.30.0.0/16` |
| Steady-state subnets | 2 AZs; 2 public, 2 app, 2 DB |
| Migration subnets | Dedicated private MGN staging subnet required in addition to steady-state six; DMS replication subnet group uses private app subnets in two AZs with a dedicated DMS SG; no additional DMS subnet CIDR assumed |
| DataSync agent | On-premises agent near NFS source; archive source type/agent requirement remains unknown |
| Application | 2 × 4 vCPU / 16 GiB; `t3.xlarge` is cost proxy only |
| Source DB | PostgreSQL VM, 8 vCPU / 32 GiB / 500 GB logical data |
| Target DB | RDS PostgreSQL Multi-AZ DB instance deployment; 500 GB configured gp3 storage input in the Calculator (distinct from source logical-data measurement); Multi-AZ primary + standby pricing applies |
| Shared files | 1 TB Regional EFS; mount target in each app AZ |
| Archives | 500 GB S3 Standard via S3 Gateway Endpoint where appropriate |
| NAT | 2 NAT Gateways; same-AZ app egress |
| VPN | 1 standard Site-to-Site VPN / VGW design; saved connection-hours $36.50 plus two tunnel public IPv4 addresses $7.30 = $43.80/month; VPN transfer remains unpriced |
| Entry | 1 public ALB, HTTPS 443; public DNS record and ACM certificate are required; Route 53 alias is conditional on Route 53 being the authoritative DNS host |
| App port | TCP 8080 provisional; discovery required |
| Business objectives | 99.9% availability; RTO 4h; RPO 15m; not demonstrated |
| Deployment | Not deployed; no tests executed |
| Cost status | Partial calculator subtotal $1,930.76/month ($23,169.12 annualised), including audited NAT and VPN public IPv4; no approved total; earlier $2,214–$2,702/month worksheet is superseded |

The [canonical master diagram](architecture/target-architecture.md), focused [runtime/network view](architecture/runtime-network-view.md), focused [migration data-flow view](architecture/migration-data-flow.md), README, design documents, runbook, cost model and [Migration Readiness Matrix](docs/09-migration-readiness-matrix.md) should use these same baseline quantities. DNS provider/delegation and Route 53 zone count remain undecided; do not infer Route 53 authority from the diagram's icon. Unsaved Route 53 ($0.90 / $4.50 / $41.00) and CloudWatch ($11.57 / $67.95 / $423.15 at 30-day retention) pricing scenarios are illustrative, pending validation and excluded from the saved subtotal. 90/365-day CloudWatch retention extensions are independent calculations, not Calculator results. A partial AWS Pricing Calculator baseline of $1,930.76/month ($23,169.12 annualised) is saved; it is not a complete or approved budget. Remaining usage and migration inputs must be validated in AWS Pricing Calculator. The $23,169.12 annualised baseline is not a full first-year projection; use actual service start/stop, cutover and overlap dates and avoid duplicating the steady-state rows. The MGN staging subnet is an additional migration-only subnet, not part of the six steady-state subnets. The 500 GB RDS provisioned-storage assumption is counted for both primary and standby for pricing.

## Current pricing audit notes

The saved subtotal is **$1,930.76/month ($23,169.12 annualised)** after the NAT IPv4 correction described below. EFS remains 1,000 GB Regional Standard with mount targets in both application AZs. Unsaved us-east-1 Calculator scenarios using illustrative A-013 read/write values are $304.50/$321.00/$390.00 per month for all-Standard conservative/baseline/high; lifecycle sensitivities are $57.55/month without new tiering and $83.05/month with illustrative 150/800 GB monthly transitions. Cross-AZ EFS bytes and lifecycle policy remain unknown.

The current VPN entry includes its two tunnel public IPv4 addresses. The separate NAT line was audited: its Public IPv4 feature was off and $65.70 represented two gateway-hours. Two required NAT EIPs were added at $7.30/month; NAT now totals $73.00. VPN tunnel addresses remain in the separate $43.80 line, with no overlap. A-015 all-outbound VPN data-transfer sensitivities are $0/$83.16/$912.60 with account-wide 100 GB allowance available, or $9/$92.16/$921.60 if already consumed; traffic direction remains unconfirmed. S3 Gateway Endpoint is no-charge; interface endpoint count/traffic remains unknown. These calculations are scenario-only and excluded from the saved subtotal.

The migration group remains empty in the calculator. MGN fee sensitivity for two Linux sources is $0/$0/$2.52 for illustrative 1-week/1-month/3-month continuous cases, using a published $0.042 per paid source-hour reference; confirm the current us-east-1 rate before entry. The first 2,160 active service hours per source are free of MGN service fee only—replication EC2/EBS/snapshots and test/cutover resources are billable throughout and remain unpriced. The prior DataSync $18.75 / 1,500 GB figure is withdrawn: 1 TB NFS is only an approximate source assumption and 500 GB S3 is target capacity, not archive source bytes. Conditional NFS-only arithmetic is $12.50 per 1,000 decimal GB or $12.80 per 1,024 GiB at $0.0125/GB. DataSync deltas, archive quantity, EFS writes and S3 requests remain unpriced. DMS remains unpriced: source/target version compatibility, schema/object inventory, WAL/write profile and CDC/full-load objectives are pending. No provisioned class or Serverless DCU selection is supportable; 168/730/2,190-hour values are duration formulas only, not DMS prices or Calculator results. Schema/object migration and sequence reconciliation are separate. Temporary network and overlap remain pending. No calculator migration scenario was added.

## Migration readiness control

The [Migration Readiness Matrix](docs/09-migration-readiness-matrix.md) is the consolidated evidence register for MGN source compatibility and staging/test sizing, PostgreSQL DMS compatibility and benchmark gates, DataSync NFS/archive inventories and final delta, temporary network flows, and the approved migration/overlap calendar. All gates remain Pending Validation; no migration service has been run and no capacity or schedule is approved.

## Review gates

- Architecture and migration flows: master diagram retained; focused runtime/network and migration data-flow views added with editable Mermaid sources. GitHub rendering of the new views and visual consistency review remain pending; no implementation validation.
- Network/security: proposed controls now include DMS two-AZ subnet group/TCP 5432 paths and DataSync agent/service/EFS flows; no deployed validation.
- PostgreSQL: DMS prerequisites, schema/object migration, CDC, WAL/slot, constraints/triggers and sequence reconciliation documented; no exact source/target version compatibility test; DMS capacity and runtime remain unpriced pending DBA profiling/benchmark.
- Pricing: partial AWS Pricing Calculator baseline is saved at $1,930.76/month ($23,169.12 annualised); production suitability validation, unresolved workload inputs, migration costs and final export/reconciliation remain outstanding.
- Operational validation: monitoring thresholds, ASG scaling policy, application SLO thresholds, recovery test and acceptance evidence outstanding.
