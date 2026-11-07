# Design Consistency Register

| Item | Canonical baseline |
|---|---|
| Region | `us-east-1` |
| VPC | `10.30.0.0/16` |
| AZs/subnets | 2 AZs; 2 public, 2 app, 2 DB |
| Application | 2 × 4 vCPU / 16 GiB; `t3.xlarge` is cost proxy only |
| Source DB | PostgreSQL VM, 8 vCPU / 32 GiB / 500 GB |
| Target DB | RDS PostgreSQL Multi-AZ; 500 GB pricing assumption |
| Shared files | 1 TB Regional EFS Standard baseline |
| Archives | 500 GB S3 Standard baseline |
| NAT | 2 NAT Gateways; same-AZ app egress |
| VPN | 1 standard Site-to-Site VPN / VGW design; pricing provisional |
| Entry | 1 public ALB, HTTPS 443 |
| App port | TCP 8080 provisional; discovery required |
| Business objectives | 99.9% availability; RTO 4h; RPO 15m; not demonstrated |
| Deployment | Not deployed; no tests executed |
| Monthly estimate | USD $2,099–$2,587 planning range |

The architecture diagram, README, design documents, runbook and cost model use these same baseline quantities. Pricing rates marked provisional/placeholder must be validated in AWS Pricing Calculator.
