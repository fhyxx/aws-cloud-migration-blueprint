# Target Architecture — Rendered Mermaid Diagram

This page renders the current target architecture in GitHub's Markdown viewer. The source file is [target-architecture.mmd](target-architecture.mmd). Keep this Mermaid block synchronised with the source file when the diagram changes.

```mermaid
flowchart TB
  USERS[Approved users] --> DNS[Public DNS<br/>Route 53 if authoritative]
  DNS --> ALB[Internet-facing ALB<br/>HTTPS 443 + ACM certificate]

  subgraph ONPREM["On-premises source environment"]
    APP_SRC[Two Linux application VMs<br/>MGN sources]
    PG_SRC[(Self-managed PostgreSQL source)]
    NFS_SRC[(NFS file server)]
    ARCH_SRC[Archive source<br/>location and type TBD]
    DS_AGENT["DataSync agent VM instances<br/>as required by source and task mode"]
    NFS_SRC -->|NFS TCP 2049 or 111 + 2049| DS_AGENT
    ARCH_SRC -.->|archive source/agent path TBD| DS_AGENT
  end

  MGN_SVC[AWS MGN regional service API]
  DS[AWS DataSync service]

  subgraph VPC["AWS VPC 10.30.0.0/16 — us-east-1 — two AZs"]
    IGW[Internet Gateway]
    VGW[Virtual Private Gateway]
    subgraph PUB["Public subnets A/B"]
      ALB[Internet-facing ALB nodes in public subnets A/B<br/>HTTPS 443 + ACM]
      NAT_A[NAT Gateway A]
      NAT_B[NAT Gateway B]
    end
    subgraph APP["Private application subnets A/B"]
      ASG[Application Auto Scaling Group<br/>desired capacity 2]
      EC2_A[EC2 app A<br/>4 vCPU / 16 GiB]
      EC2_B[EC2 app B<br/>4 vCPU / 16 GiB]
      ASG --> EC2_A
      ASG --> EC2_B
      DMS[DMS replication instance or Serverless<br/>replication subnet group spans both private app AZs<br/>dedicated DMS security group]
    end
    subgraph DB["Isolated DB subnets A/B"]
      RDS[(RDS PostgreSQL<br/>Multi-AZ DB instance deployment<br/>500 GB configured storage input)]
    end
    subgraph MGN_STAGING["Private MGN staging-area subnet<br/>additional migration-only subnet"]
      MGN_REPL[MGN replication servers]
      MGN_EGRESS[Controlled TCP 443 egress<br/>same-AZ NAT or validated private endpoint]
      MGN_REPL --> MGN_EGRESS
    end
    EFS[(Regional EFS<br/>1 TB assumption<br/>mount target in each app AZ)]
    DS_ENI[DataSync task ENI<br/>in same VPC and AZ as selected EFS mount target]
    S3EP[S3 Gateway Endpoint]
    S3[(S3 archive target<br/>500 GB capacity assumption)]
    CW[CloudWatch]
    OPS[Systems Manager / Secrets Manager]

    IGW --> ALB
    ALB --> EC2_A
    ALB --> EC2_B
    EC2_A --> RDS
    EC2_B --> RDS
    EC2_A --> EFS
    EC2_B --> EFS
    EC2_A --> S3EP
    EC2_B --> S3EP
    S3EP --> S3
    EC2_A --> CW
    EC2_B --> CW
    EC2_A --> OPS
    EC2_B --> OPS
    EC2_A --> NAT_A
    EC2_B --> NAT_B
    DMS -->|TCP 5432| RDS
    MGN_EGRESS -->|TCP 443| MGN_SVC
  end

  APP_SRC -->|MGN replication stream<br/>TCP 1500 over approved VPN route| MGN_REPL
  APP_SRC -->|MGN service access<br/>TCP 443 via approved egress| MGN_SVC
  PG_SRC -->|DMS source connection<br/>TCP 5432 over VPN| DMS
  DS_AGENT -->|DataSync service endpoint<br/>public or VPC endpoint| DS
  DS -->|Creates task data-plane ENI| DS_ENI
  DS_ENI -->|NFS TCP 2049| EFS
  DS -->|S3 service-side transfer| S3
  VGW ---|Approved source CIDRs for app/DMS paths| APP
  VGW ---|TCP 1500 source-to-staging route| MGN_STAGING
```

**Review status:** Diagram content updated for DMS placement, MGN staging egress and DataSync agent/task-ENI paths. Visual review and implementation validation remain pending.