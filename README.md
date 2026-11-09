# Clafoke Investors Ltd — AWS Cloud Migration Blueprint

> Fictional portfolio case study. Design-only. Not deployed.

A cloud migration blueprint for a fictional Nigerian retail/distribution company and its order-management platform. All company details, workload figures, targets and capacities are illustrative assumptions—not measured production facts.

## Baseline

| Item | Design assumption |
|---|---|
| Region | `us-east-1` |
| VPC | `10.30.0.0/16`, two AZs |
| Steady-state subnets | 2 public, 2 private app, 2 isolated DB |
| Migration subnets | MGN staging `10.30.31.0/24`, DMS-A/B `10.30.41.0/24` and `10.30.42.0/24`, DataSync endpoint/task `10.30.51.0/24` and `10.30.52.0/24`; five migration-only subnets |
| Application | 2 Linux servers, 4 vCPU / 16 GiB each, EC2 in a two-AZ Auto Scaling Group |
| Database | PostgreSQL to RDS PostgreSQL Multi-AZ DB instance deployment; 500 GB source logical-data assumption and separate 500 GB target gp3 provisioned-storage input; primary and standby billed under Multi-AZ pricing |
| Shared files | 1 TB Regional EFS, mount target in each application AZ |
| Archives | 500 GB S3 Standard via Gateway Endpoint where appropriate |
| Hybrid | 1 dynamic-BGP Site-to-Site VPN to VGW; fictional source `10.50.0.0/16`; ASN 65010/64512; two redundant tunnels (no VGW ECMP). Route propagation is limited to DMS-A/DMS-B, MGN staging and the two DataSync migration route tables. S3 Gateway Endpoint routes are associated with app A/B and MGN staging for private service access. |
| Entry | Public ALB, HTTPS 443; ACM certificate and DNS required |
| Business targets | 99.9% availability; RTO 4h; RPO 15m—not demonstrated |

## Architecture

The canonical master Mermaid source is [architecture/target-architecture.mmd](architecture/target-architecture.mmd), with its [rendered master view](architecture/target-architecture.md). The focused [runtime/network view](architecture/runtime-network-view.md) documents subnet CIDRs, AZ placement, route intent and security-group boundaries; the [migration data-flow view](architecture/migration-data-flow.md) separates MGN, DMS and DataSync paths. Editable Mermaid sources sit beside each rendered page. CI checks source synchronisation and key subnet/route assertions. All three diagrams have been visually reviewed in GitHub, including the latest DataSync endpoint/task subnet revision. This confirms documentation rendering only—not deployed resources or live connectivity. VGW route propagation is limited to five migration-only route tables: DMS-A, DMS-B, MGN staging, DataSync endpoint and DataSync task. Public, application and DB route tables do not receive the on-premises route.
## Deliverables

1. [Discovery assessment](docs/01-discovery-assessment.md)
2. [Target architecture](docs/02-target-architecture.md)
3. [Network and security design](docs/03-network-security-design.md)
4. [Data migration strategy](docs/04-data-migration-strategy.md)
5. [Migration runbook](docs/05-migration-runbook.md)
6. [Validation and rollback](docs/06-validation-rollback-strategy.md)
7. [Cost estimate and optimisation](docs/07-cost-estimation-optimisation.md)
8. [Assumptions and decisions register](docs/08-assumptions-decisions-register.md)
9. [Migration readiness matrix](docs/09-migration-readiness-matrix.md)
10. [Technical architecture audit](docs/10-technical-architecture-audit.md)
11. [Network implementation preparation pack](docs/11-network-implementation-preparation.md)
12. [Network implementation review and input validation register](docs/12-network-implementation-review.md)
13. [Network configuration specification](docs/13-network-configuration-specification.md)
14. [Synthetic case-study decisions](docs/14-synthetic-case-study-decisions.md)
15. [Infrastructure as Code design](docs/15-infrastructure-as-code-design.md)
16. [Migration service configuration and activation](docs/16-migration-service-configuration.md)
17. [Migration-period cost model and pricing gates](docs/17-migration-cost-model.md)
18. [Project 03 technical sign-off](docs/18-project-03-technical-signoff.md)
Additional assets: [Terraform network and workload foundation](terraform/README.md), [synthetic case-study decisions](docs/14-synthetic-case-study-decisions.md), [IaC design notes](docs/15-infrastructure-as-code-design.md), [network implementation preparation pack](docs/11-network-implementation-preparation.md), [network implementation review/input validation register](docs/12-network-implementation-review.md), [network configuration specification](docs/13-network-configuration-specification.md) (route-table associations, SG rule inventory, BGP/VPN preparation, read-only CLI inspection, test catalogue and evidence register); master architecture source/rendered page; [runtime/network source](architecture/runtime-network-view.mmd) and [rendered view](architecture/runtime-network-view.md); [migration-flow source](architecture/migration-data-flow.mmd) and [rendered view](architecture/migration-data-flow.md); `cost/pricing-assumptions.csv`, [migration-period cost model](docs/17-migration-cost-model.md), [calculator export evidence](evidence/aws-pricing-calculator-2026-11-09.md), `evidence/README.md`, `DESIGN-CONSISTENCY.md`, and the [technical sign-off](docs/18-project-03-technical-signoff.md).

## Cost review status

**Partial calculator subtotal: $1,930.76/month ($23,169.12 annualised); no approved budget.** The saved estimate includes EC2 ($274.94), RDS PostgreSQL ($1,227.52), EFS ($300.00), S3 ($11.50), two conventional NAT Gateways plus two NAT public IPv4 addresses ($73.00) and Site-to-Site VPN plus tunnel public IPv4 ($43.80). The subtotal excludes unresolved ALB LCU, DNS, CloudWatch, EFS metered throughput/cross-AZ transfer and lifecycle usage, VPN transfer, NAT processed data, applicable interface endpoint costs, backups and all migration-period costs. The NAT audit confirmed its former $65.70 represented two gateway-hours only and its Public IPv4 feature was off. Two NAT public IPv4 addresses were added at $7.30/month; the NAT entry now totals $73.00 and the saved subtotal $1,930.76. VPN tunnel addresses remain separate in the VPN entry. NAT processing remains a zero placeholder; traffic scenarios are excluded. Unsaved EFS Calculator sensitivities using illustrative A-013 throughput volumes total $304.50/$321.00/$390.00 per month for all-Standard conservative/baseline/high cases; lifecycle sensitivity is $57.55 monthly with no new tiering and $83.05 with 150/800 GB monthly transitions. These are provisional scenarios, not client requirements and not added to the saved subtotal. DataSync source quantities remain unverified: discovery describes NFS as approximately 1 TB, while the 500 GB S3 value is target storage rather than archive source volume. The former 1,500 GB/$18.75 arithmetic is withdrawn. At $0.0125/GB, 1,000 decimal GB or 1,024 GiB of NFS alone would conditionally cost $12.50 or $12.80; archive, final delta, S3 requests and network remain unpriced. Route 53 ownership is unconfirmed, so its verified $0.90/$4.50/$41.00 illustrative sensitivity cases and CloudWatch's $11.57/$67.95/$423.15 at 30-day retention are unsaved, provisional calculator scenarios and are not added. ALB DNS alias queries are free in Route 53; authoritative hosted-zone ownership is a separate decision. The monitoring scenarios are not measured client requirements. Independent network sensitivity arithmetic shows A-015 all-outbound VPN data-transfer charges of $0/$83.16/$912.60 with the 100 GB free allowance available (100 GB/1 TB/10 TB), or $9/$92.16/$921.60 if already used; direction remains unknown, so none is included. The S3 Gateway Endpoint has no hourly/data-processing fee; interface endpoint count remains unresolved. The saved estimate was refreshed and saved on 2026-11-09. Fresh calculator-generated PDF and CSV exports reconcile to six steady-state entries totaling $1,930.76/month ($23,169.12 annualised); the CSV's detailed components total $1,930.764 before display rounding. The older PDF at $1,850.46/month is stale and is not current evidence. The VPN and NAT descriptions have been corrected. Regional NAT inputs (5 gateways/3 AZs) remain displayed as residual fields, but the expanded Regional NAT calculation is $0.00/month; the calculator will not accept a quantity below one, so these inputs were preserved without adding a charge. The owner-authorized public share link and both export files, with SHA-256 evidence, are recorded in [the calculator export evidence](evidence/aws-pricing-calculator-2026-11-09.md). This remains a partial estimate: unpriced usage and migration gates are unchanged. The migration-period calculator group remains empty. The former 1,500 GB DataSync/$18.75 example is withdrawn because target capacities do not establish source bytes. The documented approximately 1 TB NFS anchor supports only conditional $12.50/$12.80 arithmetic and archive source bytes remain unknown. MGN service-fee sensitivity for two sources is $0/$0/$2.52 over illustrative 1-week/1-month/3-month continuous replication cases, using a published $0.042 per paid source-hour reference that still requires current us-east-1 rate validation; replication EC2/EBS/snapshots are billable from the start and remain unpriced. DMS remains unpriced: PostgreSQL version/objects/WAL/write profile, full-load window and CDC objective are unknown, so neither a provisioned class nor Serverless DCU range has a defensible basis. DMS sizing scenarios are formula-only (168/730/2,190 duration hours), not Calculator results. Schema/object migration and PostgreSQL sequence reconciliation are separate from DMS data movement. Temporary network, test/cutover and overlap costs remain pending. The calculator and price register document the configuration and open decisions; $2,214–$2,702/month is a withdrawn historical worksheet, not a budget.

## Project status

**Design and synthetic validation: signed off. Live implementation: planned and coming soon as a separate phase.** The next phase will use a controlled AWS environment, explicit cost limits and approval before any resource creation. The fictional architecture is not represented as a customer deployment or completed migration.

See the [technical sign-off](docs/18-project-03-technical-signoff.md) and [evidence register](evidence/README.md) for the exact scope and remaining live-validation gates.

## Important limitations

No AWS resources have been provisioned; no MGN replication, DMS migration, DataSync transfer, cutover, rollback, performance test or recovery test has occurred. RTO/RPO and availability are targets, not results. Cost excludes taxes, support plan, engineering labour and several usage-dependent charges, including migration-service execution and migration staging resources.

## Suggested review sequence

Read discovery and assumptions, compare architecture with network/security, review migration and runbook, review validation/rollback, the assumptions/decisions register and migration readiness matrix, then resolve network direction, routes, NAT public IPv4 treatment and endpoint dependencies; complete evidence-based migration-period sizing and overlap; and only then complete the AWS Pricing Calculator estimate. Do not describe this as an actual customer migration or deployed system.
