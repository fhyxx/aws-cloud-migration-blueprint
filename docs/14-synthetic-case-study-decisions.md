# 14 — Synthetic Case-Study Decisions

**ID:** CLI-AWS-SCD-014 | **Version:** 1.0 | **Status:** Approved portfolio assumptions for reproducible design and testing  
**Project:** Clafoke Investors Ltd (fictional portfolio case study)

> This document deliberately closes fictional discovery gaps so engineering work can proceed. These values are synthetic scenario decisions, not claims about a real company, AWS account or customer environment. They may be used consistently in diagrams, Terraform variables, tests and cost scenarios. They must never be presented as production-discovered facts.

## 1. Operating rule

For this portfolio, the Solutions Architect may choose reasonable synthetic inputs without waiting for a fictional customer. Each decision has an explicit rationale and a boundary. If a future real customer replaces this scenario, re-run discovery and validation rather than reusing these values as facts.

## 2. Approved synthetic scenario

| Domain | Synthetic decision | Rationale / boundary |
|---|---|---|
| AWS Region | `us-east-1` | Existing calculator and architecture baseline |
| VPC | `10.30.0.0/16` | Non-overlapping with synthetic source network |
| AZs | First two available AZs in account; resolve names at deploy time | Avoid hard-coding account-specific AZ IDs |
| Source network | `10.50.0.0/16` | Fictional private on-premises aggregate |
| Source app subnet | `10.50.10.0/24` | Two illustrative Linux MGN source VMs |
| Source DB/NFS subnet | `10.50.20.0/24` | Self-managed PostgreSQL and NFS source; DataSync agent at `10.50.20.50/32` |
| Customer gateway | Generic BGP-capable edge appliance; public IP supplied only at deployment | Do not invent a real public IP or vendor configuration |
| BGP | Customer ASN `65010`; VGW ASN `64512` | Private ASNs, distinct |
| VPN | One VPN connection, two tunnels, BGP | Portfolio-grade tunnel redundancy; not device/ISP redundancy or ECMP |
| MGN staging | `10.30.31.0/24` in AZ-A | Cost-conscious migration-only assumption; not HA |
| DataSync VPC endpoint subnet | `10.30.51.0/24` in AZ-A | Dedicated endpoint ENI subnet with source BGP return route |
| DataSync task ENI subnet | `10.30.52.0/24` in AZ-A | Dedicated task ENI subnet aligned with EFS mount target A and source BGP return route |
| DMS | Provisioned replication instance initially; dedicated two-AZ subnet group | Simpler reproducible baseline; class remains a later benchmark decision |
| DMS egress | All outbound from DMS SG | Aligns with AWS DMS network guidance; control exposure through dedicated routes and strict peer ingress |
| PostgreSQL | TCP 5432; app and DMS source paths only | Synthetic listener contract |
| Application | TCP 8080 behind ALB HTTPS 443 | Provisional but now fixed for the fictional application |
| Health endpoint | `/health/ready` returns HTTP 200 when dependencies are ready | Synthetic application contract; implement/test in app later |
| NFS | NFSv4.1 over TCP 2049 | Simplifies synthetic DataSync source |
| DataSync | VPC service endpoint for private-agent exercise; separate agent if public endpoint later required | Demonstrates endpoint-specific network design; task mode/agent capacity still subject to service validation |
| DataSync EFS | Agent TCP 1024–1064 to VPC endpoint; agent TCP 443 to task ENI; task ENI TCP 2049 to EFS mount target | Dedicated endpoint/task subnets; route propagation to both for hybrid return traffic; same AZ as EFS mount target |
| DNS | VPC-provided Route 53 Resolver; no custom DNS forwarding in base scenario | Add resolver endpoints only if a synthetic hybrid DNS requirement is introduced |
| NTP | AWS-supported time sync for EC2; source-side time service is customer-managed | No invented resolver IPs |
| NACL | Default NACLs | SGs provide workload policy; avoid unnecessary stateless complexity |
| S3 | Gateway endpoint for app subnets; conditional association for migration subnets | No hourly endpoint charge; policy still required |
| Interface endpoints | Not in base build; add only for named API callers | Avoid speculative per-AZ hourly costs |
| NAT | Two NAT Gateways for steady-state app egress; migration subnets use same-AZ NAT paths | Cost-bearing resources; Terraform flag defaults off |
| Resilience | Two-AZ ALB/app/DB; MGN staging single-AZ; one VPN connection/two tunnels | Explicitly distinguish service-layer AZ design from migration staging and customer edge resilience |
| Recovery targets | RTO 4h / RPO 15m | Acceptance targets only; not proven until timed recovery tests |

## 3. Security policy decisions

1. No public SSH or PostgreSQL ingress.
2. ALB accepts HTTPS 443; HTTP 80 is omitted from the base security group unless a redirect listener is deliberately added.
3. Application ingress is TCP 8080 from ALB SG only.
4. Application egress to RDS is TCP 5432; EFS is TCP 2049; other outbound paths are explicitly named or routed through controlled egress.
5. RDS ingress is TCP 5432 from App SG and temporary DMS SG only.
6. DMS has no unsolicited inbound requirement. DMS outbound follows the documented all-outbound recommendation; source DB ingress remains TCP 5432 from DMS subnet CIDRs only, and target RDS ingress is SG-referenced.
7. MGN staging accepts TCP 1500 only from synthetic source app subnet; source/staging service HTTPS paths use regional AWS endpoints without SSL interception.
8. DataSync agent uses VPC endpoint control-plane TCP 1024–1064 and task data-plane TCP 443; NFSv4.1 uses TCP 2049; task ENI to EFS uses TCP 2049.
9. Default NACLs remain. Security groups are stateful; no blanket public ingress is introduced.

## 4. Implementation flags and cost safety

Terraform must be safe to inspect and validate without creating chargeable resources. Therefore:

- `create_nat_gateways = false` by default. Enabling it creates two NAT Gateways and Elastic IPs and incurs hourly and data-processing charges.
- `enable_site_to_site_vpn = false` by default. Enabling it creates a Customer Gateway, VGW and VPN connection; the real customer gateway public IP must be supplied by the operator.
- No `terraform apply` is part of this repository work. Plan output must be reviewed; apply requires explicit user permission.
- No secrets, pre-shared keys, real public IPs, AWS account IDs or customer data belong in Git.
- RDS, EC2, DMS, MGN, DataSync tasks/agents, ALB, EFS and S3 workload resources are separate application/migration layers and are not silently created by the network foundation.

## 5. Terraform implementation

The network and workload layers are codified in [Terraform](../terraform/README.md). The migration-services layer is being added with DMS and DataSync resources; MGN replication-template onboarding remains a separate activation/configuration step. No apply is authorized.

## 6. Remaining engineering work

These are implementation/test tasks, not reasons to stop documenting the fictional scenario:

1. Validate Terraform network, workload and migration layers in CI and locally.
2. Add static checks for subnet CIDRs, route propagation scope, SG policy and opt-in cost-bearing resources.
3. Complete DMS, DataSync and MGN onboarding configuration and service-specific test plans.
4. Update cost assumptions for migration resources and measured transfer profiles.

**Decision:** synthetic assumptions are approved for the fictional portfolio scenario. They do not lift the separate prohibition on deploying chargeable AWS resources without explicit permission.
