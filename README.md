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

Additional assets: `architecture/target-architecture.mmd`, `cost/pricing-assumptions.csv`, `evidence/README.md`, `DESIGN-CONSISTENCY.md`.

## Cost review status

**No approved monthly total.** The previous USD $2,214–$2,702/month worksheet range is superseded and must not be used for budgeting. Exact RDS class/storage/IOPS, VPN connection configuration, NAT, EFS, ALB, endpoint, monitoring and transfer inputs must be entered into AWS Pricing Calculator. The cost document records the outstanding decisions and the required calculator export.

## Important limitations

No AWS resources have been provisioned; no MGN replication, DMS migration, DataSync transfer, cutover, rollback, performance test or recovery test has occurred. RTO/RPO and availability are targets, not results. Cost excludes taxes, support plan, engineering labour and several usage-dependent charges, including migration-service execution and migration staging resources.

## Suggested review sequence

Read discovery and assumptions, compare architecture with network/security, review migration and runbook, review validation/rollback, then complete the AWS Pricing Calculator estimate. Do not describe this as an actual customer migration or deployed system.
