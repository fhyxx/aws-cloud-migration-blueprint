# Clafoke Investors Ltd — AWS Cloud Migration Blueprint

> Fictional portfolio case study. Design-only. Not deployed.

A cloud migration blueprint for a fictional Nigerian retail/distribution company and its order-management platform. All company details, workload figures, targets and capacities are illustrative assumptions—not measured production facts.

## Baseline

| Item | Design assumption |
|---|---|
| Region | `us-east-1` |
| VPC | `10.30.0.0/16`, two AZs |
| Steady-state subnets | 2 public, 2 private app, 2 isolated DB |
| Migration subnet | Additional private MGN staging subnet; migration-only |
| Application | 2 Linux servers, 4 vCPU / 16 GiB each, EC2 in a two-AZ Auto Scaling Group |
| Database | PostgreSQL to RDS PostgreSQL Multi-AZ DB instance deployment; 500 GB logical data assumption; primary and standby storage billed |
| Shared files | 1 TB Regional EFS, mount target in each application AZ |
| Archives | 500 GB S3 Standard via Gateway Endpoint where appropriate |
| Hybrid | 1 Site-to-Site VPN using VGW design |
| Entry | Public ALB, HTTPS 443; ACM certificate and DNS required |
| Business targets | 99.9% availability; RTO 4h; RPO 15m—not demonstrated |

## Architecture

The canonical source diagram is [architecture/target-architecture.mmd](architecture/target-architecture.mmd). It shows the steady-state VPC, MGN staging area, hybrid VPN path, and distinct MGN, DMS and DataSync flows. GitHub renders Mermaid diagrams when embedded in Markdown; the source diagram still requires final visual review before design sign-off.

## Deliverables

1. [Discovery assessment](docs/01-discovery-assessment.md)
2. [Target architecture](docs/02-target-architecture.md)
3. [Network and security design](docs/03-network-security-design.md)
4. [Data migration strategy](docs/04-data-migration-strategy.md)
5. [Migration runbook](docs/05-migration-runbook.md)
6. [Validation and rollback](docs/06-validation-rollback-strategy.md)
7. [Cost estimate and optimisation](docs/07-cost-estimation-optimisation.md)
8. [Assumptions and decisions register](docs/08-assumptions-decisions-register.md)

Additional assets: `architecture/target-architecture.mmd`, `cost/pricing-assumptions.csv`, `evidence/README.md`, `DESIGN-CONSISTENCY.md`.

## Cost review status

**Partial calculator subtotal: $1,930.76/month ($23,169.12 annualised); no approved budget.** The saved estimate includes EC2 ($274.94), RDS PostgreSQL ($1,227.52), EFS ($300.00), S3 ($11.50), two conventional NAT Gateways plus two NAT public IPv4 addresses ($73.00) and Site-to-Site VPN plus tunnel public IPv4 ($43.80). The subtotal excludes unresolved ALB LCU, DNS, CloudWatch, EFS metered throughput/cross-AZ transfer and lifecycle usage, VPN transfer, NAT processed data, applicable interface endpoint costs, backups and all migration-period costs. The NAT audit confirmed its former $65.70 represented two gateway-hours only and its Public IPv4 feature was off. Two NAT public IPv4 addresses were added at $7.30/month; the NAT entry now totals $73.00 and the saved subtotal $1,930.76. VPN tunnel addresses remain separate in the VPN entry. NAT processing remains a zero placeholder; traffic scenarios are excluded. Unsaved EFS Calculator sensitivities using illustrative A-013 throughput volumes total $304.50/$321.00/$390.00 per month for all-Standard conservative/baseline/high cases; lifecycle sensitivity is $57.55 monthly with no new tiering and $83.05 with 150/800 GB monthly transitions. These are provisional scenarios, not client requirements and not added to the saved subtotal. Derived DataSync initial 1,500 GB costs $18.75 one-time at current Basic pricing, before destination-service and network charges. Route 53 ownership is unconfirmed, so its verified $0.90/$4.50/$41.00 illustrative sensitivity cases and CloudWatch's $11.57/$67.95/$423.15 at 30-day retention are unsaved, provisional calculator scenarios and are not added. ALB DNS alias queries are free in Route 53; authoritative hosted-zone ownership is a separate decision. The monitoring scenarios are not measured client requirements. Independent network sensitivity arithmetic shows A-015 all-outbound VPN data-transfer charges of $0/$83.16/$912.60 with the 100 GB free allowance available (100 GB/1 TB/10 TB), or $9/$92.16/$921.60 if already used; direction remains unknown, so none is included. The S3 Gateway Endpoint has no hourly/data-processing fee; interface endpoint count remains unresolved. The separate migration-period group remains unpriced except for derived DataSync Basic sensitivity ($18.75 one-time initial 1,500 GB, before destination and network charges). The calculator and price register document the configuration and open decisions; $2,214–$2,702/month is a withdrawn historical worksheet, not a budget.

## Important limitations

No AWS resources have been provisioned; no MGN replication, DMS migration, DataSync transfer, cutover, rollback, performance test or recovery test has occurred. RTO/RPO and availability are targets, not results. Cost excludes taxes, support plan, engineering labour and several usage-dependent charges, including migration-service execution and migration staging resources.

## Suggested review sequence

Read discovery and assumptions, compare architecture with network/security, review migration and runbook, review validation/rollback and the assumptions/decisions register, then resolve network direction, routes, NAT public IPv4 treatment and endpoint dependencies; complete evidence-based migration-period sizing and overlap; and only then complete the AWS Pricing Calculator estimate. Do not describe this as an actual customer migration or deployed system.
