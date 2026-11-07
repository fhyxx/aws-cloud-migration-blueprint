# Clafoke Investors Ltd — AWS Cloud Migration Blueprint

> Fictional portfolio case study. Design-only. Not deployed.

A cloud migration blueprint for a fictional Nigerian retail/distribution company and its order-management platform. All company details, workload figures, targets and capacities are illustrative assumptions—not measured production facts.

## Baseline

| Item | Design assumption |
|---|---|
| Region | `us-east-1` |
| VPC | `10.30.0.0/16`, two AZs |
| Subnets | 2 public, 2 private app, 2 isolated DB |
| Application | 2 Linux servers, 4 vCPU / 16 GiB each, EC2 |
| Database | PostgreSQL to RDS Multi-AZ; 500 GB planning storage |
| Shared files | 1 TB Regional EFS |
| Archives | 500 GB S3 Standard |
| Hybrid | 1 Site-to-Site VPN using VGW design |
| Entry | Public ALB, HTTPS 443 |
| Business targets | 99.9% availability; RTO 4h; RPO 15m—not demonstrated |

## Architecture

```mermaid
flowchart TB
 U[Approved users] --> DNS[Route 53]
 DNS --> ALB[Public ALB HTTPS 443]
 subgraph VPC["VPC 10.30.0.0/16 — two AZs"]
  subgraph PUB["Public subnets"]
   ALB
   N1[NAT Gateway A]
   N2[NAT Gateway B]
  end
  subgraph APP["Private app subnets"]
   A[EC2 app A<br/>4 vCPU / 16 GiB]
   B[EC2 app B<br/>4 vCPU / 16 GiB]
  end
  subgraph DB["Isolated DB subnets"]
   R[(RDS PostgreSQL Multi-AZ<br/>500 GB planning assumption)]
  end
  E[(Regional EFS<br/>1 TB)]
  S[(S3 archives<br/>500 GB)]
  C[CloudWatch]
  M[Systems Manager / Secrets Manager]
  ALB --> A
  ALB --> B
  A --> R
  B --> R
  A --> E
  B --> E
  A --> S
  B --> S
  A --> C
  B --> C
  A --> M
  B --> M
  A --> N1
  B --> N2
 end
 O[On-premises source] <-->|Site-to-Site VPN / VGW| VPC
 MGN[AWS MGN] -. replication .-> APP
 DMS[AWS DMS full load + CDC] -.-> R
 DS[AWS DataSync] -. NFS .-> E
 DS -. archives .-> S
```

Migration services are temporary migration paths, not permanent runtime components. S3 Gateway Endpoint is preferred where appropriate; interface endpoints are added only when justified.

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

Illustrative steady-state estimate: **USD $2,099–$2,587/month** (730 hours/month). RDS Multi-AZ compute and backup allowances are provisional. This is not an AWS quote; use AWS Pricing Calculator with exact instance classes, Region and configuration before budget approval.

## Important limitations

No AWS resources have been provisioned; no MGN replication, DMS migration, DataSync transfer, cutover, rollback, performance test or recovery test has occurred. RTO/RPO and availability are targets, not results. Cost excludes taxes, support plan, engineering labour and several usage-dependent charges.

## Suggested review sequence

Read discovery and assumptions, compare architecture with network/security, review migration and runbook, review validation/rollback, then refresh the cost model. Do not describe this as an actual customer migration or deployed system.
