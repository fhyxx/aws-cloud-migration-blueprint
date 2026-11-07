# 07 — AWS Cost Estimation and Optimisation

**ID:** CLI-AWS-COST-007 | **Version:** 1.2 | **Status:** Pricing review open — no approved total  
**Region:** `us-east-1` | **Currency:** USD | **Planning month:** 730 hours

## Executive decision

The earlier **$2,214–$2,702/month** range is retained only as a historical, illustrative worksheet result. **Do not use it as a budget, quotation, expected bill or customer commitment.** The earlier worksheet used unverified RDS compute/storage rates and a VPN hourly example from a different Region and connection design. Those values do not support a defensible current total.

A final AWS Pricing Calculator estimate has not been produced. This document deliberately does not invent one. The exact RDS class/storage/IOPS and VPN product configuration must be selected and entered into AWS Pricing Calculator; the saved estimate URL and exported CSV/PDF should then be committed alongside this document.

## Architecture quantities to price

| Service | Current design input | Pricing status / required decision |
|---|---|---|
| EC2 | 2 × Linux `t3.xlarge`, 730 h/month | Reference rate exists for us-east-1; retain as sizing proxy only. Benchmark sustained CPU and compare a non-burstable family. |
| EBS | 2 × 100 GB gp3 | Confirm provisioned IOPS/throughput and current regional rates. |
| RDS PostgreSQL | Multi-AZ DB instance deployment, one standby; 500 GB logical/provisioned-storage assumption | **Not priced.** Select PostgreSQL major version, exact class, gp3/io2, provisioned IOPS/throughput and backup retention. Calculator must include primary and standby instance-hours and provisioned storage. |
| RDS backups | Usage-dependent | Calculate retention, changed-data volume and snapshot needs; avoid a flat unsupported allowance. |
| EFS | Regional Standard, 1,000 GB, mount targets in both app AZs | Confirm regional storage rate, lifecycle mix, throughput mode and metered throughput. |
| S3 | Standard, 500 GB | Confirm storage, requests, retrieval, lifecycle and replication requirements. |
| NAT Gateway | 2 gateways, same-AZ app egress | Confirm us-east-1 gateway-hour and data-processing rates plus realistic processed GB; include cross-AZ transfer if any. |
| ALB | 1 internet-facing ALB | Price hours and estimated LCU dimensions (new connections, active connections, processed bytes, rule evaluations). |
| Site-to-Site VPN | 1 standard connection to VGW | **Not priced.** Select standard connection type and verify exact us-east-1 connection-hour rate, tunnel public IPv4 addresses and transfer. Do not reuse the earlier $0.05/hour example: it was a US East (Ohio) example for a different connection scenario. |
| Interface endpoints | Count and AZ coverage not final | Inventory each endpoint and AZ; price endpoint-hours and data processing. S3 Gateway Endpoint has no hourly endpoint charge. |
| CloudWatch | Logs, metrics, alarms and Flow Logs | Estimate ingestion GB, retention, custom metrics, alarms and Flow Log destinations. |
| Internet/data transfer | 100 GB was a placeholder | Replace with direction, destination, monthly volume and applicable free tiers. |
| ACM / Route 53 | Public ALB certificate and DNS alias | Confirm public hosted-zone ownership, query volume and certificate validation prerequisites; model Route 53 charges where applicable. |
| MGN / DMS / DataSync | Temporary migration-period use | Model separately as one-time/overlap costs, including staging EC2/EBS, replication duration, DMS compute, DataSync transfer and temporary network resources. |

## RDS billing treatment

The design is specifically a **Multi-AZ DB instance deployment with one standby**, not a Multi-AZ DB cluster with two readable standbys. AWS documents that both primary and standby instance-hours are billed, and storage is charged for the provisioned storage on both instances. The 500 GB logical/provisioned storage assumption must therefore be costed for both copies in the calculator. The final rate must come from the calculator for the chosen DB class, engine version, storage type and Region.

AWS references:
- [RDS for PostgreSQL pricing and deployment options](https://aws.amazon.com/rds/postgresql/pricing/)
- [RDS Multi-AZ DB instance billing details](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_OnDemandDBInstances.html)

## Pricing method and acceptance

1. Open [AWS Pricing Calculator](https://calculator.aws/).
2. Create a named estimate for `Clafoke Investors Ltd — us-east-1 — steady state`.
3. Add EC2, EBS, RDS for PostgreSQL, EFS, S3, VPC/NAT, ALB, Site-to-Site VPN, CloudWatch and Route 53 as applicable.
4. Use 730 hours/month and the architecture quantities above. Record all selections, including exact DB class, PostgreSQL version, storage type, provisioned IOPS/throughput, backup retention, NAT processed GB, ALB LCU inputs, VPN connection type, endpoint count/AZs, logs and transfer.
5. Create a separate migration-period group for MGN staging, DMS, DataSync, temporary instances, transfer and overlap duration.
6. Export the estimate as CSV and PDF and retain the public share URL. Record the estimate date and pricing assumptions.
7. Reconcile the exported service totals with this document and `cost/pricing-assumptions.csv`. Do not approve a budget until missing inputs are resolved.

AWS explains that the calculator uses service configuration and Region inputs, can export CSV/PDF and can generate a shareable estimate link. Its estimate excludes taxes and only includes the information entered.

## Optimisation decisions

1. Keep two NAT Gateways in the production-oriented baseline; compare a one-NAT cost option only with an explicit availability/cross-AZ trade-off.
2. Use the S3 Gateway Endpoint for eligible S3 traffic and avoid routing that traffic through NAT.
3. Select interface endpoints from an actual service dependency inventory; do not add endpoints speculatively.
4. Benchmark EC2 and RDS using representative CPU, memory, IOPS, throughput, connection and latency measurements before right-sizing.
5. Use EFS lifecycle policies only after file access patterns and retrieval requirements are known.
6. Apply S3 lifecycle and retention policies based on approved archive requirements.
7. Set AWS Budgets alerts and Cost Explorer allocation tags after the cost baseline is approved.

## Exclusions / separate estimates

Taxes, support plan, engineering labour, customer gateway and on-premises internet costs, migration staging/overlap, MGN/DMS/DataSync execution, unknown transfer, optional security services, detailed backup, EFS throughput, S3 requests/retrieval and unmodelled usage require separate inputs or estimates.

## Public pricing references

- [AWS Pricing Calculator](https://calculator.aws/)
- [Amazon EC2 On-Demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [Amazon VPC pricing — NAT Gateway and public IPv4](https://aws.amazon.com/vpc/pricing/)
- [Elastic Load Balancing pricing](https://aws.amazon.com/elasticloadbalancing/pricing/)
- [Amazon RDS for PostgreSQL pricing](https://aws.amazon.com/rds/postgresql/pricing/)
- [Amazon EFS pricing](https://aws.amazon.com/efs/pricing/)
- [Amazon S3 pricing](https://aws.amazon.com/s3/pricing/)
- [AWS Site-to-Site VPN pricing](https://aws.amazon.com/vpn/pricing/)
- [AWS Pricing Calculator guide: export estimate](https://docs.aws.amazon.com/pricing-calculator/latest/userguide/export-estimate.html)
- [AWS Pricing Calculator guide: share estimate](https://docs.aws.amazon.com/pricing-calculator/latest/userguide/save-share-estimate.html)

**Status:** Architecture quantities and cost drivers reviewed. Final numerical estimate is **blocked pending exact configuration and an exported AWS Pricing Calculator result**. No AWS resources have been deployed.
