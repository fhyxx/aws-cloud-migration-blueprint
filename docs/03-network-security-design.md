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

## Migration-service network paths

- **DMS placement:** create a DMS replication subnet group using the private application subnets in AZ-A and AZ-B. The replication instance/Serverless ENIs use a dedicated DMS security group. DMS initiates TCP 5432 connections to the self-managed PostgreSQL source over the VPN and to the RDS PostgreSQL target. The on-premises source firewall must allow the DMS-originating VPC CIDR/path; the RDS DB security group must allow TCP 5432 from the DMS security group during migration. Keep application-to-database access separate. Remove the temporary DMS ingress rule after migration only when DMS is no longer needed.
- **MGN:** the source agent requires TCP 1500 to the replication servers in the MGN staging subnet and TCP 443 to the regional MGN API. Staging replication servers require TCP 443 to the regional MGN API. Route source-to-staging traffic over the approved VPN path; provide controlled staging-subnet egress (for example, same-AZ NAT) or a separately validated private endpoint design.
- **DataSync NFS:** place a Basic or Enhanced mode agent (as appropriate to the selected task mode) close to the on-premises NFS server. Agent-to-NFS TCP ports are 2049 for NFSv4.x and 111 plus 2049 for NFSv3. Agent-to-service and data-plane paths depend on public versus VPC service endpoint selection. DataSync service-to-EFS uses TCP 2049; DataSync accesses S3 on the bucket's behalf. For a public service endpoint, the agent uses HTTPS TCP 443 to the documented activation/control/data-plane endpoints. For a VPC service endpoint, the agent uses TCP 1024–1064 for control-plane traffic and TCP 443 to task data-plane ENIs; add TCP 22 only if the Basic-mode support channel is intentionally enabled. Do not assume the public-endpoint port model applies.
- **Archive source:** source type and location are unknown. Confirm whether an agent is required and document its actual source-to-agent/service path before approving the archive transfer.

## Security-group intent

| Group | Inbound | Outbound |
|---|---|---|
| ALB | TCP 443 from approved client ranges | App listener to app SG |
| App | TCP 8080 from ALB SG (provisional) | TCP 5432 to DB SG; TCP 2049 to EFS mount-target SG; approved HTTPS |
| DB | TCP 5432 from app SG and approved DBA path | Minimal required |
| EFS mount target | TCP 2049 from app SG and the dedicated DataSync task-ENI SG | Stateful responses |\n| DMS replication | No unsolicited inbound required; outbound TCP 5432 to approved source CIDR and RDS DB SG, plus documented service/logging dependencies | Stateful responses |
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

Confirm non-overlapping CIDRs, route tables, DB isolation, ALB-only public entry, restricted app/DB/EFS paths, VPN health, DMS subnet-group placement across two AZs and TCP 5432 reachability to source/target, MGN agent-to-service TCP 443, source-to-replication TCP 1500, replication-server-to-service TCP 443, DataSync agent-to-NFS ports and selected service-endpoint paths, encryption, IAM and audit logs.

## Open decisions

N01 AZ IDs; N02 source CIDRs; N03 static/BGP; N04 app port; N05 API allowlisting; N06 endpoint inventory; N07 egress inspection; N08 NACL requirements; N09 IAM boundaries; N10 retention; N11 MGN staging CIDR and network path; N12 DNS zone/certificate ownership.

**Status:** Proposed design; no AWS network/security resources deployed.


## AWS service network references

- [AWS DMS replication instance VPC and subnet-group requirements](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_ReplicationInstance.VPC.html)
- [AWS MGN network requirements](https://docs.aws.amazon.com/pdfs/mgn/latest/ug/user-guide.pdf)
- [AWS DataSync network requirements](https://docs.aws.amazon.com/datasync/latest/userguide/datasync-network.html)
- [AWS DataSync network architecture and traffic flows](https://docs.aws.amazon.com/datasync/latest/userguide/networking-datasync.html)
- [AWS DataSync access to EFS, mount-target subnet and security-group rules](https://docs.aws.amazon.com/datasync/latest/userguide/create-efs-location.html)
