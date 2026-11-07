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

```mermaid
flowchart TB
 U[Approved users] --> DNS[Route 53]
 DNS --> ALB[Public ALB HTTPS 443<br/>ACM certificate]
 subgraph VPC["VPC 10.30.0.0/16 — us-east-1 — two AZs"]
  IGW[Internet Gateway]
  subgraph PUB["Public subnets A/B"]
   ALB
   N1[NAT Gateway A]
   N2[NAT Gateway B]
  end
  subgraph APP["Private application subnets A/B"]
   ASG[Application Auto Scaling Group<br/>desired capacity 2]
   A[EC2 app A<br/>4 vCPU / 16 GiB]
   B[EC2 app B<br/>4 vCPU / 16 GiB]
   ASG --> A
   ASG --> B
  end
  subgraph DB["Isolated DB subnets A/B"]
   R[(RDS PostgreSQL Multi-AZ DB instance<br/>primary + standby<br/>500 GB logical data)]
  end
  E[(Regional EFS<br/>1 TB; mount targets A/B)]
  S3EP[S3 Gateway Endpoint]
  S[(S3 archives<br/>500 GB)]
  C[CloudWatch]
  M[Systems Manager / Secrets Manager]
  subgraph MIG["Private migration-only subnet"]
   STG[MGN staging / replication servers]
  end
  IGW --> ALB
  ALB --> A
  ALB --> B
  A --> R
  B --> R
  A --> E
  B --> E
  A --> S3EP --> S
  B --> S3EP
  A --> C
  B --> C
  A --> M
  B --> M
  A --> N1
  B --> N2
 end
 O[On-premises source] <-->|Site-to-Site VPN / VGW| VPC
 MGN[AWS Application Migration Service] -. replication .-> STG
 DMS[AWS DMS full load + CDC] -.-> R
 DS[AWS DataSync] -. NFS .-> E
 DS -. archives .-> S
```

Migration services are temporary migration paths, not permanent runtime components. The MGN staging subnet is an additional migration-only subnet beyond the six steady-state subnets. S3 Gateway Endpoint is preferred where appropriate; interface endpoints are added only when justified.

## Deliverables

1. [Discovery assessment](docs/01-discovery-assessment.md)
2. [Target architecture](docs/02-target-architecture.md)
3. [Network and security design](docs/03-network-security-design.md)
4. [Data migration strategy](docs/04-data-migration-strategy.md)
5. [Migration runbook](docs/05-migration-runbook.md)
6. [Validation and rollback](docs/06-validation-rollback-strategy.md)
7. [Cost estimate and optimisation](docs/07-cost-estimation-optimisation.md)

Additional assets: `architecture/target-architecture.mmd`, `cost/pricing-assumptions.csv`, `evidence/README.md`, `DESIGN-CONSISTENCY.md`.

## Cost headline

Illustrative steady-state estimate: **USD $2,214–$2,702/month** (730 hours/month). This includes the Multi-AZ RDS primary and standby provisioned storage assumption. RDS compute and several allowances remain provisional. This is not an AWS quote; use AWS Pricing Calculator with exact instance classes, Region and configuration before budget approval.

## Important limitations

No AWS resources have been provisioned; no MGN replication, DMS migration, DataSync transfer, cutover, rollback, performance test or recovery test has occurred. RTO/RPO and availability are targets, not results. Cost excludes taxes, support plan, engineering labour and several usage-dependent charges, including migration-service execution and migration staging resources.

## Suggested review sequence

Read discovery and assumptions, compare architecture with network/security, review migration and runbook, review validation/rollback, then refresh the cost model. Do not describe this as an actual customer migration or deployed system.
