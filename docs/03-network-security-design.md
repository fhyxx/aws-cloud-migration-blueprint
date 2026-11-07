# 03 — Network and Security Design

**ID:** CLI-AWS-NET-003 | **Version:** 1.2 | **Status:** Proposed baseline

## Network

VPC `clafoke-production-vpc`, CIDR `10.30.0.0/16`, `us-east-1`, two AZs, DNS support/hostnames enabled, IGW attached, IPv6 omitted.

| Subnet | CIDR | Purpose |
|---|---|---|
| Public A/B | `10.30.1.0/24`, `10.30.2.0/24` | Internet-facing ALB and NAT Gateways |
| App A/B | `10.30.11.0/24`, `10.30.12.0/24` | Private EC2 |
| DB A/B | `10.30.21.0/24`, `10.30.22.0/24` | Isolated RDS subnet group |
| MGN staging | Additional private CIDR to allocate | MGN replication servers; migration-only subnet, not in six-subnet steady-state count |

The MGN staging subnet is a seventh, migration-only network segment in addition to the six steady-state subnets. Allocate its CIDR after confirming source/VPC CIDR non-overlap and required IP capacity. Record the AZ placement, route table, NAT or VPC endpoint strategy, NACL and security-group rules before enabling replication.

## Routing

- Public default route to IGW.
- App A to NAT A; App B to NAT B; on-prem routes to VGW as required.
- DB subnets local route only; no direct internet route.
- S3 prefix-list route through S3 Gateway Endpoint.
- Site-to-Site VPN via customer gateway + VGW; static/BGP choice pending source discovery.
- MGN source agents must reach the regional MGN service API over TCP 443 and the staging-area replication servers over TCP 1500. Replication servers in the staging subnet must reach the regional MGN service API over TCP 443. Implement only these documented flows plus required DNS/time and management dependencies; do not expose the staging subnet broadly.
- If private connectivity is not implemented for MGN service access, the staging subnet needs a controlled outbound path (for example, same-AZ NAT) to the regional service endpoint. Confirm current MGN service endpoint and network guidance before deployment. The source-to-replication TCP 1500 path must be routable over the selected VPN or other approved connectivity.
- Interface endpoints in suitable private subnets; dedicated endpoint subnets optional.

## Security-group intent

| Group | Inbound | Outbound |
|---|---|---|
| ALB | TCP 443 from approved client ranges | App listener to app SG |
| App | TCP 8080 from ALB SG (provisional) | TCP 5432 to DB SG; TCP 2049 to EFS mount-target SG; approved HTTPS |
| DB | TCP 5432 from app SG and approved DBA path | Minimal required |
| EFS mount target | TCP 2049 from app SG | Stateful responses |
| Interface endpoint | TCP 443 from approved private workloads | Stateful responses |
| MGN staging/replication | TCP 1500 from explicitly approved source-server CIDRs/security groups where supported; no public inbound | TCP 443 to regional MGN API and only required replication/service paths |

No public SSH or PostgreSQL. Confirm port 8080. Default NACLs initially; custom NACLs only where justified. EFS requires TCP 2049 from EC2 client SG to mount-target SG. MGN port requirements must be checked against the current AWS documentation for the selected Region and connectivity design before rules are applied.

## Endpoints and certificates

Candidate endpoints: S3 Gateway; Systems Manager (`ssm`, `ssmmessages`, and `ec2messages` where applicable); CloudWatch Logs/Monitoring; Secrets Manager; ECR API/Docker only if image pulls require them. Interface endpoints incur hourly and data-processing costs; model actual count and AZ coverage. Provision an ACM certificate for ALB HTTPS and Route 53 alias/DNS records if Route 53 is authoritative; certificate/DNS costs and prerequisites must be checked separately.

## Identity and security

- Federated/IAM Identity Center human access with MFA.
- Separate least-privilege roles for EC2, SSM, MGN, DMS and DataSync.
- Secrets Manager for credentials; no long-lived keys in code.
- Encrypt EBS, RDS, EFS and S3 at rest.
- TLS for ALB and supported application/database paths.
- CloudTrail, CloudWatch and VPC Flow Logs where required.
- S3 Block Public Access and restrictive bucket policies.

## Validation

Confirm non-overlapping CIDRs, route tables, DB isolation, ALB-only public entry, restricted app/DB/EFS paths, VPN health, endpoint connectivity, MGN agent-to-service TCP 443, source-to-replication TCP 1500, replication-server-to-service TCP 443, encryption, IAM and audit logs.

## Open decisions

N01 AZ IDs; N02 source CIDRs; N03 static/BGP; N04 app port; N05 API allowlisting; N06 endpoint inventory; N07 egress inspection; N08 NACL requirements; N09 IAM boundaries; N10 retention; N11 MGN staging CIDR and network path; N12 DNS zone/certificate ownership.

**Status:** Proposed design; no AWS network/security resources deployed.
