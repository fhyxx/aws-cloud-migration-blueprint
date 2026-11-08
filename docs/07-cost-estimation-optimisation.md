# 07 — AWS Cost Estimation and Optimisation

**ID:** CLI-AWS-COST-007 | **Version:** 1.4 | **Status:** Partial calculator baseline saved — pricing review open  
**Region:** `us-east-1` | **Currency:** USD | **Planning month:** 730 hours

## Executive decision

The earlier **$2,214–$2,702/month** range is retained only as a historical, illustrative worksheet result. **Do not use it as a budget, quotation, expected bill or customer commitment.** The earlier worksheet used unverified RDS compute/storage rates and a VPN hourly example from a different Region and connection design. Those values do not support a defensible current total.

A partial estimate is saved in AWS Pricing Calculator. Its currently verified subtotal is **$1,923.46/month** and **$23,081.52 annualised**. This is a calculator result for the entered configurations, not a complete operating budget, approved budget or proof of production workload suitability. Material usage-dependent items and migration costs remain unpriced. The saved RDS configuration is a sizing proxy pending PostgreSQL version, workload and compatibility validation. See [the Assumptions and Decisions Register](08-assumptions-decisions-register.md).

## Architecture quantities to price

| Service | Current design input | Pricing status / required decision |
|---|---|---|
| EC2 (including attached EBS in the saved EC2 estimate) | 2 × Linux `t3.xlarge`, 730 h/month; 2 × 100 GB gp3 | **$274.94/month, calculator result.** Benchmark sustained CPU and compare a non-burstable family; confirm the gp3 sizing assumptions. |
| EBS | 2 × 100 GB gp3 (200 GB total), represented in the saved EC2 estimate | Included in the $274.94/month EC2 calculator entry; do not add it again. Validate workload performance needs. |
| RDS PostgreSQL | `db.m6i.2xlarge`, Multi-AZ DB instance deployment, 500 GB gp3 input, 12,000 IOPS, 500 MiB/s throughput | **$1,227.52/month, calculator result.** The current entry uses one configured logical DB with Multi-AZ selected. PostgreSQL version, compatibility and workload suitability remain unresolved; backup usage remains unpriced. |
| RDS backups | Usage-dependent | Calculate retention, changed-data volume and snapshot needs; avoid a flat unsupported allowance. |
| EFS | Regional Standard, 1,000 GB, mount targets in both app AZs; Elastic throughput is provisional | **$300.00/month, calculator result.** Throughput mode and metered read/write workload remain provisional/unresolved; current metered throughput input is zero. |
| S3 | Standard, 500 GB | **$11.50/month, calculator result.** Requests, retrieval and transfer remain zero placeholders; validate lifecycle and retention requirements. |
| NAT Gateway | 2 conventional gateways, same-AZ app egress, 730 hours each | **$65.70/month, calculator result.** Processed data remains a zero placeholder; replace with workload evidence. Cross-AZ transfer, if any, is not included. |
| ALB | 1 internet-facing ALB, HTTPS 443 | Not included in the saved calculator subtotal. Unsaved AWS Pricing Calculator scenario results from the register are $19.35 / $28.11 / $74.83 per month (conservative / baseline / high), including 730 ALB hours and scenario LCU use. These are illustrative, not measured or approved client requirements, and are excluded from the saved subtotal; validate workload before adopting. |
| Site-to-Site VPN | 1 standard connection to VGW, public IPv4 tunnel endpoints | **$43.80/month combined in the saved VPC entry:** $36.50 connection-hours plus $7.30 for two in-use public IPv4 address-hours. VPN transfer is unpriced. The 22 working days/month summary field belongs to the unselected Client VPN section; it does not affect the Site-to-Site calculation (1 × 730 h × $0.05/h = $36.50). |
| Interface endpoints | Count and AZ coverage not final | Inventory each endpoint and AZ; price endpoint-hours and data processing. S3 Gateway Endpoint has no hourly endpoint charge. |
| CloudWatch | Logs, metrics, alarms and Flow Logs | Estimate ingestion GB, retention, custom metrics, alarms and Flow Log destinations. |
| Internet/data transfer | 100 GB was a placeholder | Replace with direction, destination, monthly volume and applicable free tiers. |
| ACM / Route 53 | Public ALB certificate and DNS alias | Confirm public hosted-zone ownership, query volume and certificate validation prerequisites; model Route 53 charges where applicable. |
| MGN / DMS / DataSync | Temporary migration-period use | Model separately as one-time/overlap costs, including staging EC2/EBS, replication duration, DMS compute, DataSync transfer and temporary network resources. |

## VPN pricing audit

The saved VPC calculator entry was audited without changing its Site-to-Site connection quantity or duration. The calculation details show **1 connection × 730 hours × $0.05/connection-hour = $36.50/month** in `us-east-1`. The entry description's 24 hours/day converts to 730 hours/month using the calculator's standard planning month. The configuration summary's separate **22 working days/month** value is a default in the Client VPN section; Client VPN is not selected, so this field is unrelated to the Site-to-Site charge.

The calculator entry did not previously include public IPv4. AWS documents two tunnels per Site-to-Site VPN connection, each with a unique public IPv4 endpoint, and separately states that public IPv4 addresses assigned to Site-to-Site tunnel endpoints incur the standard in-use IPv4 charge. The calculator's public IPv4 feature at two in-use addresses showed **2 × 730 × $0.005 = $7.30/month**. This is now included in the existing VPC estimate entry; combined VPN-related total is **$43.80/month**. The estimate total changed from **$1,916.16 to $1,923.46/month**, and annualised total from **$22,993.92 to $23,081.52**. The 22-day Client VPN field remains visible in the configuration summary but is not a selected pricing dimension. VPN transfer remains unpriced.

AWS references:
- [AWS Site-to-Site VPN pricing — tunnel public IPv4 charges](https://aws.amazon.com/vpn/pricing/)
- [Amazon VPC pricing — in-use public IPv4 at $0.005/address-hour](https://aws.amazon.com/vpc/pricing/)
- [AWS Site-to-Site VPN tunnel options — two tunnels and unique public IPs](https://docs.aws.amazon.com/vpn/latest/s2svpn/VPNTunnels.html)

## ALB workload sensitivity (independent calculation)

The assumptions register's conservative, baseline and high cases are illustrative scenarios, not measured traffic or approved client requirements. They were entered separately in the AWS Pricing Calculator's `us-east-1` ELB form and each displayed calculation was verified; the draft was canceled without saving an ALB entry. These are calculator scenario results, not independent calculations, and are excluded from the $1,923.46 saved subtotal.

AWS's ELB pricing page describes the hourly ALB charge ($0.0225/hour) and LCU charge ($0.008/LCU-hour) in `us-east-1`. For EC2 targets, one LCU covers up to 25 new connections/second, 3,000 active connections/minute, 1 GB processed/hour, or 1,000 rule evaluations/second after the first 10 rules per request. Applying the register's scenarios and taking the largest dimension gives:

| Scenario | Register workload inputs | Dominant LCU dimension | Approx. LCU-hours/month | Independent ALB estimate/month |
|---|---|---|---:|---:|
| Conservative | 0.5 new connections/s; 100 active; 5 requests/s; 0.5 GB/h; 5 rules/request | Processed bytes (0.5 LCU) | 365 | $19.35 |
| Baseline | 2 new connections/s; 500 active; 20 requests/s; 2 GB/h; 15 rules/request | Processed bytes (2 LCU) | 1,460 | $28.11 |
| High | 10 new connections/s; 3,000 active; 100 requests/s; 10 GB/h; 25 rules/request | Processed bytes (10 LCU) | 7,300 | $74.83 |

Calculation: 730 × $0.0225 ALB-hour base + (scenario LCU-hours × $0.008). Rounded to cents. The workload dimensions above were entered as representative values across the 730-hour month solely for sensitivity analysis. The calculator's displayed dominant LCU dimension was processed bytes for each case. Real LCU billing uses the highest dimension in each hour and actual hourly pattern, so these figures are not forecasts. ALB capacity and charges remain a pricing gate pending workload evidence and a saved calculator entry.

AWS reference: [Elastic Load Balancing pricing — ALB LCU dimensions and `us-east-1` examples](https://aws.amazon.com/elasticloadbalancing/pricing/).

## RDS billing treatment

The design is specifically a **Multi-AZ DB instance deployment with one standby**, not a Multi-AZ DB cluster. AWS bills primary and standby instance-hours and provisioned storage for both copies. In the current saved calculator entry, the UI shows one configured logical DB, Multi-AZ selected, and 500 GB gp3 input; the resulting line item is $1,227.52/month. Its displayed calculation is $1,039.52 compute ($1.424/hour × 730), $115.00 storage (500 GB × $0.23/GB-month at the calculator's displayed Multi-AZ rate), and $73.00 Database Insights. The calculator entry applies its Multi-AZ rates to the configured quantity; **do not manually double the 500 GB input or the $1,227.52 result**. This verifies only what the calculator currently calculates. It is not independent proof that `db.m6i.2xlarge`, the PostgreSQL version, IOPS/throughput or performance is suitable for production. Confirm those through version/compatibility review and workload measurement.

AWS references:
- [RDS for PostgreSQL pricing and deployment options](https://aws.amazon.com/rds/postgresql/pricing/)
- [RDS Multi-AZ DB instance billing details](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_OnDemandDBInstances.html)

## Pricing method and acceptance

1. Open the existing saved estimate in [AWS Pricing Calculator](https://calculator.aws/); preserve its current service configurations.
2. Treat the current subtotal as partial and keep usage-dependent or unresolved components clearly excluded.
3. Add EC2, EBS, RDS for PostgreSQL, EFS, S3, VPC/NAT, ALB, Site-to-Site VPN, CloudWatch and Route 53 as applicable.
4. Use 730 hours/month. Record selected calculator configurations and remaining decisions, including PostgreSQL version/workload validation, backup retention, NAT processed GB, ALB LCU inputs, VPN transfer, endpoint count/AZs, logs and transfer.
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

**Status:** A partial AWS Pricing Calculator estimate is saved and verified at $1,923.46/month ($23,081.52 annualised). It is **not complete or approved**: ALB usage remains unresolved (scenario sensitivity only; no ALB calculator entry saved); DNS, CloudWatch, EFS metered throughput/transfer, VPN transfer, applicable endpoint costs, backups, and migration-period sizing/duration/overlap remain unresolved or unpriced. Keep the migration-period group separate. No AWS resources have been deployed.
