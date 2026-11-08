# 03 — Network and Security Design

**ID:** CLI-AWS-NET-003 | **Version:** 1.2 | **Status:** Proposed baseline

## Architecture diagrams

- [Focused runtime and network view](../architecture/runtime-network-view.md)
- [Focused migration data-flow view](../architecture/migration-data-flow.md)
- [Canonical master architecture](../architecture/target-architecture.md)

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
- **DataSync NFS:** place a Basic or Enhanced mode agent (as appropriate to the selected task mode) close to the on-premises NFS server. Agent-to-NFS TCP ports are 2049 for NFSv4.x and 111 plus 2049 for NFSv3. Agent-to-service and data-plane paths depend on public versus VPC service endpoint selection. For an EFS location, DataSync creates task network interfaces in a selected subnet in the same VPC and an AZ with an EFS mount target; use a dedicated task-ENI security group and allow TCP 2049 from it to the EFS mount-target security group. DataSync accesses S3 on the bucket's behalf. For a public service endpoint, the agent uses HTTPS TCP 443 to the documented activation/control/data-plane endpoints. For a VPC service endpoint, the agent uses TCP 1024–1064 for control-plane traffic and TCP 443 to task data-plane ENIs; add TCP 22 only if the Basic-mode support channel is intentionally enabled. Do not assume the public-endpoint port model applies.
- **Archive source:** source type and location are unknown. Confirm whether an agent is required and document its actual source-to-agent/service path before approving the archive transfer.

## Route-table design baseline

Use separate route tables where isolation or failure-domain control matters. The following is the intended route set; route-table IDs, subnet associations, source CIDRs and route-propagation mode are not yet deployed or approved.

| Route table / association | Required routes | Explicit exclusions / validation |
|---|---|---|
| Public-A — public subnet `10.30.1.0/24` | `10.30.0.0/16 → local`; `0.0.0.0/0 → IGW` | Hosts ALB-A node and NAT-A. NAT-A requires an allocated Elastic IP. |
| Public-B — public subnet `10.30.2.0/24` | `10.30.0.0/16 → local`; `0.0.0.0/0 → IGW` | Hosts ALB-B node and NAT-B. NAT-B requires an allocated Elastic IP. |
| App-A — private app subnet `10.30.11.0/24` | `10.30.0.0/16 → local`; `0.0.0.0/0 → NAT-A`; approved on-prem source CIDRs `→ VGW`; S3 regional prefix list `→ S3 Gateway Endpoint` | More-specific on-prem and S3 routes take precedence over the default NAT route. Validate route propagation or explicit route maintenance. |
| App-B — private app subnet `10.30.12.0/24` | `10.30.0.0/16 → local`; `0.0.0.0/0 → NAT-B`; approved on-prem source CIDRs `→ VGW`; S3 regional prefix list `→ S3 Gateway Endpoint` | Same intent as App-A; DMS replication subnet group reuses these private subnets. |
| DB-A / DB-B — isolated DB subnets `10.30.21.0/24`, `10.30.22.0/24` | `10.30.0.0/16 → local` | No default route to IGW or NAT. No VGW route is proposed for RDS subnets in this baseline; DMS-to-RDS traffic is VPC-local. Add a specific route only for an approved operational use case. |
| MGN staging — additional private subnet, CIDR/AZ TBD | `10.30.0.0/16 → local`; approved source CIDRs `→ VGW`; `0.0.0.0/0 → same-AZ NAT` only if public service egress is selected | Migration-only. Select and validate either controlled NAT egress or a supported private endpoint design; do not configure both by assumption. |
| S3 Gateway Endpoint association | S3 prefix-list route automatically added to selected app route tables (and other route tables only if needed) | Endpoint policy, IAM and bucket policy must restrict access. Same-Region S3 traffic uses the endpoint route rather than NAT. |

**VPN route control:** The customer gateway must route approved VPC prefixes back through the VPN. Choose BGP propagation when the customer gateway supports BGP; otherwise configure static VPN routes and matching VPC subnet route-table entries. Do not advertise or install broader address ranges than required. Keep both VPN tunnels and failover behaviour in the operational test plan. Exact on-premises CIDRs, customer-gateway capability and route mode remain open.

**Route precedence:** More-specific routes for on-premises CIDRs and the S3 prefix list should override the private-subnet default route to NAT. Confirm effective routes on every subnet association; a route in an unassociated route table has no effect.

## Security-group intent

Security groups are stateful and should reference peer security groups wherever possible instead of broad subnet CIDRs. The following is a least-privilege starting matrix, not an applied ruleset.

| Security group | Inbound rules | Outbound rules |
|---|---|---|
| ALB SG | TCP 443 from approved client CIDRs; HTTP 80 only if explicitly required for redirect | Application listener and health-check protocol/port (provisional TCP 8080) to App SG |
| App SG | Provisional TCP 8080 from ALB SG only; no public or on-premises direct ingress | TCP 5432 to RDS SG; TCP 2049 to EFS mount-target SG; TCP 443 to approved external/service destinations or required interface endpoint SGs; required DNS/time dependencies |
| RDS SG | TCP 5432 from App SG; temporary TCP 5432 from DMS SG during migration; DBA access only through a separately approved controlled path | Stateful responses; no broad outbound access without a documented database requirement |
| EFS mount-target SG | TCP 2049 from App SG and dedicated DataSync task-ENI SG | Stateful responses |
| DMS SG | No unsolicited inbound required | TCP 5432 to approved PostgreSQL source CIDR/path and RDS SG; required DMS service/logging dependencies |
| DataSync task-ENI SG | No unsolicited inbound required | TCP 2049 to EFS mount-target SG; required DataSync task data-plane dependencies |
| MGN staging SG | TCP 1500 from explicitly approved source-server CIDRs; no public inbound | TCP 443 to regional MGN service and only documented dependencies |
| Interface endpoint SG | TCP 443 from only the private workload SGs that need the endpoint | Stateful responses |

The ALB health-check port and application listener port must match the actual target-group configuration; TCP 8080 is still provisional. If database administration is required, prefer a controlled SSM-based or approved private DBA path rather than exposing PostgreSQL publicly. Remove the temporary DMS-to-RDS rule after migration when DMS no longer needs it.

Security groups are stateful: response traffic for an allowed flow is automatically permitted. Network ACLs are stateless; if custom NACLs are introduced, explicitly allow both request and return traffic, including the correct ephemeral port ranges for initiating clients and AWS-managed services. Retain default NACLs until a specific subnet-level deny/guardrail requirement justifies custom rules. Do not copy a generic ephemeral range without validating the client OS and service behaviour.

No public SSH or PostgreSQL.
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
