# 03 — Network and Security Design

**ID:** CLI-AWS-NET-003 | **Version:** 1.0 | **Status:** Proposed baseline

## Network

VPC `clafoke-production-vpc`, CIDR `10.30.0.0/16`, `us-east-1`, two AZs, DNS support/hostnames enabled, IGW attached, IPv6 omitted.

| Subnet | CIDR | Purpose |
|---|---|---|
| Public A/B | `10.30.1.0/24`, `10.30.2.0/24` | ALB and NAT Gateways |
| App A/B | `10.30.11.0/24`, `10.30.12.0/24` | Private EC2 |
| DB A/B | `10.30.21.0/24`, `10.30.22.0/24` | Isolated RDS subnet group |

## Routing

- Public default route to IGW.
- App A to NAT A; App B to NAT B; on-prem routes to VGW as required.
- DB subnets local route only; no direct internet route.
- S3 prefix-list route through S3 Gateway Endpoint.
- Site-to-Site VPN via customer gateway + VGW; static/BGP choice pending source discovery.
- Interface endpoints in suitable private subnets; dedicated endpoint subnets optional.

## Security-group intent

| Group | Inbound | Outbound |
|---|---|---|
| ALB | TCP 443 from approved client ranges | App listener to app SG |
| App | TCP 8080 from ALB SG (provisional) | TCP 5432 to DB SG; TCP 2049 to EFS; approved HTTPS |
| DB | TCP 5432 from app SG and approved DBA path | Minimal required |
| EFS | TCP 2049 from app SG | Stateful responses |
| Interface endpoint | TCP 443 from approved private workloads | Stateful responses |

No public SSH or PostgreSQL. Confirm port 8080. Default NACLs initially; custom NACLs only where justified.

## Endpoints

Candidate endpoints: S3 Gateway; Systems Manager (`ssm`, `ssmmessages`, and `ec2messages` where applicable); CloudWatch Logs/Monitoring; Secrets Manager; ECR API/Docker only if image pulls require them. Interface endpoints incur hourly and data-processing costs; model actual count and AZ coverage.

## Identity and security

- Federated/IAM Identity Center human access with MFA.
- Separate least-privilege roles for EC2, SSM, MGN, DMS and DataSync.
- Secrets Manager for credentials; no long-lived keys in code.
- Encrypt EBS, RDS, EFS and S3 at rest.
- TLS for ALB and supported application/database paths.
- CloudTrail, CloudWatch and VPC Flow Logs where required.
- S3 Block Public Access and restrictive bucket policies.

## Validation

Confirm non-overlapping CIDRs, route tables, DB isolation, ALB-only public entry, restricted app/DB/EFS paths, VPN health, endpoint connectivity, encryption, IAM and audit logs.

## Open decisions

N01 AZ IDs; N02 source CIDRs; N03 static/BGP; N04 app port; N05 API allowlisting; N06 endpoint inventory; N07 egress inspection; N08 NACL requirements; N09 IAM boundaries; N10 retention.

**Status:** Proposed design; no AWS network/security resources deployed.
