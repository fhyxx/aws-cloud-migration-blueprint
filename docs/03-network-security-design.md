# 03 — Network and Security Design

**ID:** CLI-AWS-NET-003 | **Version:** 1.7 | **Status:** Synthetic portfolio baseline approved — live AWS execution gated

**Configuration baseline:** [Network Configuration Specification](13-network-configuration-specification.md) (approved synthetic baseline; live AWS apply remains gated).

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
| MGN staging | `10.30.31.0/24` | MGN replication servers; migration-only subnet, not in six-subnet steady-state count |
| DMS-A / DMS-B | `10.30.41.0/24`, `10.30.42.0/24` | Dedicated DMS replication subnets across two AZs; migration-only |
| DataSync endpoint | `10.30.51.0/24` | Dedicated VPC service-endpoint subnet; AZ-A; migration-only |
| DataSync task ENI | `10.30.52.0/24` | Dedicated task-ENI subnet; AZ-A to align with EFS mount target A; migration-only |

The MGN staging subnet, two DMS subnets and two DataSync subnets are five migration-only network segments in addition to the six steady-state subnets. For this fictional reference design, use `10.30.31.0/24` in AZ-A as the initial staging subnet. It is non-overlapping with the six steady-state subnets and the illustrative on-premises `10.50.0.0/16`. The single-AZ staging choice is a cost-conscious migration assumption, not a production availability recommendation; validate replication-server capacity and recovery objectives before deployment. Record its route table, controlled service egress, NACL and security-group rules.

## Subnet sizing and Availability Zone placement

The six steady-state subnet CIDRs are distinct, contained within `10.30.0.0/16`, and do not overlap one another. The five migration-only subnets (`10.30.31.0/24`, `10.30.41.0/24`, `10.30.42.0/24`, `10.30.51.0/24`, `10.30.52.0/24`) are also distinct and do not overlap the steady-state CIDRs or illustrative on-premises `10.50.0.0/16`.

| Subnet | CIDR | IPv4 addresses in block | AWS-reserved | Initially assignable |
|---|---|---:|---:|---:|
| Public A | `10.30.1.0/24` | 256 | 5 | 251 |
| Public B | `10.30.2.0/24` | 256 | 5 | 251 |
| App A | `10.30.11.0/24` | 256 | 5 | 251 |
| App B | `10.30.12.0/24` | 256 | 5 | 251 |
| DB A | `10.30.21.0/24` | 256 | 5 | 251 |
| DB B | `10.30.22.0/24` | 256 | 5 | 251 |

AWS reserves five IPv4 addresses in each ordinary subnet. The public /24 subnets exceed the ALB minimum of /27 and, at subnet creation, have substantially more than the required eight free IP addresses. Recheck free IP capacity before ALB deployment and during growth; NAT Gateway, ALB ENIs, endpoints and other ENIs consume addresses. Actual AZ IDs must be selected and recorded because AZ letters can map differently across AWS accounts.

The migration-only /24 subnets also have 251 initially assignable IPv4 addresses each, before ENIs and other resources consume addresses. This is a planning capacity check, not proof that the MGN replication fleet or DMS deployment will fit. Validate free IP headroom against MGN replication-server scaling, DMS ENIs, endpoint ENIs and selected AZs before migration.

The MGN staging subnet `10.30.31.0/24` in AZ-A is a separate migration-only subnet and is excluded from the six-row steady-state subnet sizing table. The CIDR is an illustrative planning assumption, not an approved customer allocation. Validate non-overlap against the actual customer address inventory, replication-server IP capacity, AZ mapping and egress design before deployment.

## Illustrative hybrid network and VPN assumptions

Clafoke is a fictional portfolio case study. The following source network and gateway details are design assumptions created to make the migration architecture testable; they are not facts discovered from a real customer.

| Component | Illustrative design value | Rationale |
|---|---|---|
| On-premises aggregate | `10.50.0.0/16` | Private, non-overlapping with AWS VPC `10.30.0.0/16` |
| Application/source VM subnet | `10.50.10.0/24` | Contains the two illustrative Linux MGN source VMs |
| Database/NFS subnet | `10.50.20.0/24` | Contains self-managed PostgreSQL and NFS source services |
| Customer Gateway | BGP-capable edge router or firewall with a static public outside IP | Represents a conventional enterprise VPN edge; vendor/model intentionally unspecified |
| Customer Gateway BGP ASN | `65010` | Private ASN, distinct from the AWS side |
| Virtual Private Gateway ASN | `64512` | AWS default ASN for the VGW in this reference design |
| Routing mode | Dynamic BGP | Selected because the illustrative gateway supports BGP and dynamic route withdrawal assists tunnel failover |
| VPN tunnel count | Two tunnels in one Site-to-Site VPN connection | Both configured and monitored for redundancy; do not assume ECMP/load sharing on a VGW |

The selected source aggregate `10.50.0.0/16` does not overlap the AWS VPC `10.30.0.0/16`. The more-specific source subnets are planning subdivisions, not separate BGP advertisements in this design. The customer gateway advertises `10.50.0.0/16` to the VGW. The VGW advertises the attached VPC CIDR to the customer gateway; on-premises firewall policy limits which AWS workloads can actually be reached.

### BGP and route propagation

- Create one Customer Gateway resource with the illustrative public outside IP represented as a placeholder (never invent or publish a real address) and customer ASN `65010`.
- Create and attach a VGW using AWS ASN `64512`, then create one dynamic-routing Site-to-Site VPN connection. AWS supplies two independent IPsec tunnel definitions and tunnel inside addressing/BGP peer details.
- Configure both customer-side tunnel interfaces and BGP peers from the generated AWS VPN configuration. Do not hard-code tunnel outside IPs, inside CIDRs, pre-shared keys or device commands in this portfolio document.
- Enable VGW route propagation only on the DMS-A, DMS-B, MGN-staging, DataSync-endpoint and DataSync-task route tables. Do not enable propagation on public, application or DB route tables. This confines source-network route availability to migration workloads.
- The customer gateway advertises `10.50.0.0/16`; AWS propagates that route only to the DMS-A, DMS-B, MGN-staging, DataSync-endpoint and DataSync-task route tables. The VGW advertises the VPC CIDR to the customer gateway; customer-side firewall/ACL policy must restrict access to the DMS migration subnet CIDRs for PostgreSQL and the MGN staging CIDR for replication.
- The database subnets retain only the VPC-local route. RDS is reached from DMS inside the VPC, not directly from the on-premises VPN. This prevents the VPN design from becoming a general database access path.
- Configure both tunnels for high availability and monitor BGP state, tunnel state and packet metrics. A VGW does not support ECMP; AWS selects a tunnel for egress. Permit asymmetric routing and test failover in both directions. Do not describe this as active-active bandwidth aggregation.
- Static routing is the documented alternative if the customer gateway cannot speak BGP. It requires explicit on-premises prefixes in the VPN configuration and matching VPC route-table entries; it is not the selected reference design.
- Do not treat a propagated route's continued presence as proof that a tunnel is healthy. AWS documents that if connectivity is interrupted while the VPN connection status remains UP, propagated routes might not be automatically removed. Monitor both tunnel/BGP state and active end-to-end probes; test failover and recovery rather than relying on route-table presence alone.

## Routing

- Public default route to IGW.
- App A to NAT A; App B to NAT B; no VGW route propagation on application route tables.
- MGN staging `10.30.31.0/24` has `10.50.0.0/16 → VGW` and a controlled same-AZ NAT default route for regional MGN service HTTPS unless a separately validated private service path is selected. Dedicated DMS subnets `10.30.41.0/24` and `10.30.42.0/24` each have `10.50.0.0/16 → VGW` plus same-AZ NAT default egress for required DMS service/logging APIs.
- DB subnets local route only; no direct internet route and no VGW route propagation.
- DataSync endpoint subnet `10.30.51.0/24` and task-ENI subnet `10.30.52.0/24` each receive the source BGP route only; neither receives a default internet route. The task subnet is in AZ-A to align with the EFS mount target in that AZ.
- S3 prefix-list route through S3 Gateway Endpoint.
- Site-to-Site VPN uses dynamic BGP with customer ASN `65010`, VGW ASN `64512` and two redundant tunnels; both are configured, but VGW ECMP is not supported.

- MGN source agents must reach the regional MGN service API over TCP 443 and the staging-area replication servers over TCP 1500. Replication servers in the staging subnet must reach the regional MGN service API over TCP 443. Implement only these documented flows plus required DNS/time and management dependencies; do not expose the staging subnet broadly.
- If private connectivity is not implemented for MGN service access, the staging subnet needs a controlled outbound path (for example, same-AZ NAT) to the regional service endpoint. Confirm current MGN service endpoint and network guidance before deployment. The source-to-replication TCP 1500 path must be routable over the selected VPN or other approved connectivity.
- Interface endpoints in suitable private subnets; dedicated endpoint subnets optional.

## Migration-service network paths

- **DMS placement:** create a DMS replication subnet group using dedicated private migration subnets `10.30.41.0/24` and `10.30.42.0/24` in AZ-A and AZ-B. Associate dedicated route tables with the BGP-propagated `10.50.0.0/16 → VGW` route and same-AZ NAT default egress. The replication instance/Serverless ENIs use a dedicated DMS security group. Application subnets do not receive on-premises route propagation. DMS initiates TCP 5432 connections to the self-managed PostgreSQL source over the VPN and to the RDS PostgreSQL target. The on-premises source firewall must allow TCP 5432 only from `10.30.41.0/24` and `10.30.42.0/24` to the PostgreSQL source; the RDS DB security group must allow TCP 5432 from the DMS security group during migration. Keep application-to-database access separate. Remove the temporary DMS ingress rule after migration only when DMS is no longer needed.
- **MGN:** the source agent requires TCP 1500 to the replication servers in the MGN staging subnet and TCP 443 to the regional MGN API. Staging replication servers require TCP 443 to the regional MGN API. Route source-to-staging traffic over the approved VPN path; provide controlled staging-subnet egress (for example, same-AZ NAT) or a separately validated private endpoint design.
- **DataSync NFS:** the synthetic on-premises agent is `10.50.20.50/32` in the DB/NFS source subnet. The VPC service endpoint is placed in `10.30.51.0/24` and the task ENI in `10.30.52.0/24` (AZ-A, same AZ as the EFS mount target). Propagate the source BGP route into both dedicated DataSync route tables so agent-to-endpoint TCP 1024–1064 and agent-to-task-ENI TCP 443 have a return path. Endpoint SG allows TCP 1024–1064 only from the agent /32; task-ENI SG allows TCP 443 only from that /32 and TCP 2049 to the EFS mount-target SG. Place a Basic or Enhanced mode agent (as appropriate to the selected task mode) close to the on-premises NFS server. Agent-to-NFS TCP ports are 2049 for NFSv4.x and 111 plus 2049 for NFSv3. Agent-to-service and data-plane paths depend on public versus VPC service endpoint selection. For an EFS location, DataSync creates task network interfaces in a selected subnet in the same VPC and an AZ with an EFS mount target; use a dedicated task-ENI security group and allow TCP 2049 from it to the EFS mount-target security group. DataSync accesses S3 on the bucket's behalf. For a public service endpoint, the agent uses HTTPS TCP 443 to the documented activation/control/data-plane endpoints. For a VPC service endpoint, the agent uses TCP 1024–1064 for control-plane traffic and TCP 443 to task data-plane ENIs; add TCP 22 only if the Basic-mode support channel is intentionally enabled. Do not assume the public-endpoint port model applies.
- **Archive source:** source type and location are unknown. Confirm whether an agent is required and document its actual source-to-agent/service path before approving the archive transfer.

## Route-table design baseline

Use separate route tables where isolation or failure-domain control matters. The following is the selected illustrative route set; route-table IDs and subnet associations are not deployed. The source CIDR and BGP route-propagation scope are portfolio assumptions, not measured client facts.

| Route table / association | Required routes | Explicit exclusions / validation |
|---|---|---|
| Public-A — public subnet `10.30.1.0/24` | `10.30.0.0/16 → local`; `0.0.0.0/0 → IGW` | Hosts ALB-A node and NAT-A. NAT-A requires an allocated Elastic IP. |
| Public-B — public subnet `10.30.2.0/24` | `10.30.0.0/16 → local`; `0.0.0.0/0 → IGW` | Hosts ALB-B node and NAT-B. NAT-B requires an allocated Elastic IP. |
| App-A — private app subnet `10.30.11.0/24` | `10.30.0.0/16 → local`; `0.0.0.0/0 → NAT-A`; S3 regional prefix list `→ S3 Gateway Endpoint` | No VGW route propagation; application instances do not need direct on-premises reachability. |
| App-B — private app subnet `10.30.12.0/24` | `10.30.0.0/16 → local`; `0.0.0.0/0 → NAT-B`; S3 regional prefix list `→ S3 Gateway Endpoint` | No VGW route propagation; application instances do not need direct on-premises reachability. |
| DMS-A / DMS-B — private migration subnets `10.30.41.0/24`, `10.30.42.0/24` | `10.30.0.0/16 → local`; propagated `10.50.0.0/16 → VGW`; `0.0.0.0/0 → same-AZ NAT`; required S3 prefix-list route only if DMS task design needs S3 | Dedicated two-AZ DMS replication subnet group; only these route tables receive source-network route propagation for PostgreSQL TCP 5432. Validate AZ placement, IP capacity, egress and subnet group membership. |
| DB-A / DB-B — isolated DB subnets `10.30.21.0/24`, `10.30.22.0/24` | `10.30.0.0/16 → local` | No default route to IGW or NAT. No VGW route is proposed for RDS subnets in this baseline; DMS-to-RDS traffic is VPC-local. Add a specific route only for an approved operational use case. |
| MGN staging — `10.30.31.0/24`, AZ-A (illustrative) | `10.30.0.0/16 → local`; propagated `10.50.0.0/16 → VGW`; `0.0.0.0/0 → NAT-A` for regional MGN service HTTPS | Enable VGW route propagation. NAT-A is the selected reference egress path; private endpoint alternative requires separate validation. Single-AZ staging is a planning simplification, not an HA claim. |
| DataSync endpoint — `10.30.51.0/24`, AZ-A | `10.30.0.0/16 → local`; propagated `10.50.0.0/16 → VGW` | No default route. Hosts the VPC service endpoint; agent control-plane TCP 1024–1064 returns over VGW. |
| DataSync task ENI — `10.30.52.0/24`, AZ-A | `10.30.0.0/16 → local`; propagated `10.50.0.0/16 → VGW` | No default route. Same AZ as EFS mount target A; agent data-plane TCP 443 returns over VGW and task ENI reaches EFS TCP 2049 locally. |
| S3 Gateway Endpoint association | S3 prefix-list route automatically added to App-A, App-B and MGN-staging route tables; DMS route tables only if the selected DMS task requires S3 | Endpoint policy, IAM and bucket policy must restrict access. Same-Region S3 traffic uses the endpoint route rather than NAT. |

**VPN route control:** For this fictional design, the customer gateway advertises `10.50.0.0/16` using BGP ASN `65010`; the VGW uses ASN `64512` and advertises the attached VPC CIDR. Enable route propagation only in DMS-A, DMS-B, MGN-staging, DataSync-endpoint and DataSync-task route tables. Do not propagate the on-premises route into ordinary application, public or DB route tables. The customer-side router/firewall must accept the AWS VPC route but permit TCP 5432 only from `10.30.41.0/24` and `10.30.42.0/24` to PostgreSQL, TCP 1500 only from MGN source VMs to `10.30.31.0/24`, and DataSync agent `10.50.20.50/32` only to the DataSync endpoint subnet on TCP 1024–1064 and task-ENI subnet on TCP 443. Configure both tunnels, permit asymmetric routing and test tunnel failure/recovery. A VGW does not support ECMP, so this is redundant tunnel design, not aggregate active-active throughput. Static routing remains the alternative for a non-BGP customer gateway.

**Route precedence:** More-specific routes for on-premises CIDRs and the S3 prefix list should override the private-subnet default route to NAT. Confirm effective routes on every subnet association; a route in an unassociated route table has no effect.

## Security-group intent

Security groups are stateful and should reference peer security groups wherever possible instead of broad subnet CIDRs. The following is a least-privilege starting matrix, not an applied ruleset.

| Security group | Inbound rules | Outbound rules |
|---|---|---|
| ALB SG | TCP 443 from approved client CIDRs; HTTP 80 only if explicitly required for redirect | Application listener and health-check protocol/port (provisional TCP 8080) to App SG |
| App SG | Provisional TCP 8080 from ALB SG only; no public or on-premises direct ingress | TCP 5432 to RDS SG; TCP 2049 to EFS mount-target SG; TCP 443 to approved external/service destinations or required interface endpoint SGs; required DNS/time dependencies |
| RDS SG | TCP 5432 from App SG; temporary TCP 5432 from DMS SG during migration; DBA access only through a separately approved controlled path | Stateful responses; no broad outbound access without a documented database requirement |
| EFS mount-target SG | TCP 2049 from App SG and dedicated DataSync task-ENI SG | Stateful responses |
| DMS SG | No unsolicited inbound required | All outbound per current AWS DMS networking guidance; use dedicated DMS subnets, restricted source/target ingress and route controls as compensating boundaries |
| DataSync endpoint SG | TCP 1024–1064 from DataSync agent `10.50.20.50/32` only | Stateful responses |
| DataSync task-ENI SG | TCP 443 from DataSync agent `10.50.20.50/32` only | TCP 2049 to EFS mount-target SG |
| MGN staging SG | TCP 1500 from illustrative MGN source subnet `10.50.10.0/24` only; no public inbound | TCP 443 to regional MGN service and only documented dependencies |
| Interface endpoint SG | TCP 443 from only the private workload SGs that need the endpoint | Stateful responses |

The ALB health-check port and application listener port must match the actual target-group configuration; TCP 8080 and `/health/ready` are the fixed synthetic application contract; runtime readiness still requires testing. If database administration is required, prefer a controlled SSM-based or approved private DBA path rather than exposing PostgreSQL publicly. Remove the temporary DMS-to-RDS rule after migration when DMS no longer needs it.

Security groups are stateful: response traffic for an allowed flow is automatically permitted. Network ACLs are stateless; if custom NACLs are introduced, explicitly allow both request and return traffic, including the correct ephemeral port ranges for initiating clients and AWS-managed services. Retain default NACLs until a specific subnet-level deny/guardrail requirement justifies custom rules. Do not copy a generic ephemeral range without validating the client OS and service behaviour.

### Service-specific egress and endpoint review gates\n\n- **DMS egress:** the narrow outbound matrix above is a design proposal, not a confirmed universal DMS rule set. Current AWS DMS networking guidance recommends allowing all outbound traffic from the replication-instance security group so it can reach source/target endpoints and required services. Before deployment, confirm the selected provisioned/Serverless mode, endpoint types, Secrets Manager/logging/DNS dependencies and current AWS guidance. Either adopt the documented service guidance with compensating ingress, routing and endpoint controls, or retain narrower egress only with a validated, supported flow inventory and successful endpoint tests. Do not claim the TCP 5432/443/DNS-only proposal is implementation-ready.\n- **MGN:** source agents require TCP 443 to the regional MGN API as well as TCP 1500 to staging; staging replication servers require TCP 443 to MGN service endpoints and may require S3 access according to the current regional requirements. Do not apply SSL interception/deep packet inspection to the documented source/replication-server MGN API paths. Confirm the current endpoint allow-list for the chosen Region.\n- **DataSync:** an agent uses one service-endpoint type. Public/FIPS and VPC/FIPS endpoints have different port and routing requirements; for a VPC endpoint, validate agent-to-service TCP 1024–1064 and agent-to-task-ENI TCP 443. For public endpoints, validate the current endpoint-specific TCP 443 allow-list and Basic-mode bootstrap dependencies. TCP 22 is an optional support channel, not a normal transfer requirement. If workflows require different endpoint types, plan separate agents.\n\nNo public SSH or PostgreSQL.
## Migration traffic and security validation matrix

The following paths are the intended allow-list for the fictional reference design. A route only establishes network reachability; security groups, on-premises firewall policy and host firewalls must independently permit the flow. Return traffic must be routable in both directions.

| Initiator | Destination | Protocol / port | Intended path | Required control / evidence |
|---|---|---|---|---|
| DMS ENI in 10.30.41.0/24 or 10.30.42.0/24 | PostgreSQL source 10.50.20.0/24 | TCP 5432 | DMS route table → VGW → VPN → customer gateway | DMS SG egress to source TCP 5432; customer firewall permits only the two DMS subnet CIDRs; source host firewall permits PostgreSQL; on-premises return route to VPC via VPN; successful connection test from DMS endpoint |
| DMS ENI | RDS PostgreSQL target | TCP 5432 | VPC-local route | RDS SG inbound from DMS SG only during migration; target endpoint test; remove temporary rule after migration |
| Source MGN agents 10.50.10.0/24 | MGN replication servers 10.30.31.0/24 | TCP 1500 | Customer gateway → VPN → VGW → MGN staging | MGN staging SG inbound only from source app subnet; on-premises firewall permits only staging destination/port; return route; agent replication status |
| Source MGN agents | Regional MGN service API | TCP 443 | Approved source-side internet or private service path | Source egress firewall/DNS allow-list; validate documented regional endpoint; do not assume this API flow traverses the VPN |
| MGN replication servers | Regional MGN service API | TCP 443 | Staging route table → same-AZ NAT-A or separately validated private endpoint | Staging SG egress and NAT/endpoint policy; DNS and service connectivity test |
| DataSync agent | On-premises NFS server | TCP 2049 (NFSv4.x); TCP 111 and 2049 (NFSv3) | Local source network | Agent host firewall and NFS export ACL; validate selected NFS version and mount/read test |
| DataSync agent | DataSync service | TCP 443 public endpoint, or VPC-endpoint-specific ports | Public endpoint or approved VPN-to-VPC service endpoint | Use the correct endpoint model and its documented port requirements; activation/control/data transfer test |
| DataSync task ENI | EFS mount target | TCP 2049 | VPC-local, same VPC/AZ as selected mount target | Task-ENI SG egress to EFS mount-target SG; EFS SG inbound from task-ENI SG; mount and file verification |
| Application EC2 | RDS / EFS | TCP 5432 / TCP 2049 | VPC-local | App SG egress to RDS/EFS SG; target SG inbound from App SG; application health and file/database operation tests |

### Required negative and failover tests

- From an application EC2 instance, verify that no route to 10.50.0.0/16 is present in its effective route table and that direct PostgreSQL/NFS source access is denied.
- From DMS migration subnets, verify PostgreSQL TCP 5432 succeeds; from application subnets and unrelated VPC sources, verify the on-premises firewall does not permit the same connection.
- From MGN source agents, verify TCP 1500 reaches only the staging subnet and is denied to unrelated AWS subnets.
- Verify the database subnet route tables contain no VGW propagation and no internet/NAT default route.
- Disable one VPN tunnel only in an approved test window; confirm the other tunnel carries traffic, BGP/session state converges, and application/migration flows recover within the agreed objective. Restore both tunnels and capture sanitized metrics.
- Confirm a failed/withdrawn BGP route does not leave an unintended static or broad fallback path. Review effective route tables after recovery.
- Capture source/destination/port, timestamp, test origin, expected/actual result, route-table export, SG/NACL/firewall evidence and responsible approver. Never record pre-shared keys or credentials.

## VPC endpoint inventory and private service access

Do not create every possible endpoint by default. First decide whether each private workload uses a VPC interface/gateway endpoint or the existing controlled same-AZ NAT egress path. The following is a workload-driven candidate inventory for `us-east-1`; none of these endpoints is deployed or approved yet.

| Service / endpoint | Type | Decision | Workload and condition | Network / security requirements |
|---|---|---|---|---|
| S3 — `com.amazonaws.us-east-1.s3` | Gateway | **Baseline candidate** | App access to the S3 archive bucket; also required for private ECR image-layer downloads if ECR is later used | Associate only the route tables that need S3 access (initially App-A/App-B); restrict endpoint policy, bucket policy and IAM. No endpoint SG or per-AZ interface endpoint charge. |
| Systems Manager — `com.amazonaws.us-east-1.ssm` | Interface | **Required if using private SSM without NAT** | EC2 managed-node registration and Systems Manager API operations | Private DNS; endpoint SG inbound TCP 443 from App SG; IAM instance profile and agent must also be correct. |
| Systems Manager Messages — `com.amazonaws.us-east-1.ssmmessages` | Interface | **Required for Session Manager / SSM messaging when using private endpoint path** | SSM Agent control/data channels and Session Manager | Private DNS; endpoint SG inbound TCP 443 from App SG. |
| EC2 Messages — `com.amazonaws.us-east-1.ec2messages` | Interface | **Conditional legacy compatibility only** | Older SSM Agent / legacy regional behaviour; current SSM Agent uses `ssmmessages` when available | Do not add automatically. Confirm SSM Agent version and current regional support; AWS documents `ec2messages` as unsupported in Regions launched in 2024 or later. |
| Secrets Manager — `com.amazonaws.us-east-1.secretsmanager` | Interface | **Required if application/rotation function retrieves secrets privately without NAT** | Runtime DB credentials and other secrets | Private DNS; endpoint SG inbound TCP 443 from only the App SG or rotation-function SG; narrow endpoint policy and IAM permissions. |
| CloudWatch Logs — `com.amazonaws.us-east-1.logs` | Interface | **Conditional** | Required if instances send application/system logs to CloudWatch Logs without NAT | Private DNS; endpoint SG inbound TCP 443 from log-publishing workloads; scope IAM and log-group permissions. |
| CloudWatch Monitoring — `com.amazonaws.us-east-1.monitoring` | Interface | **Conditional** | Required if workloads publish metrics through the CloudWatch monitoring API without NAT | Private DNS; endpoint SG inbound TCP 443 from publishing workloads. This is distinct from the Logs endpoint. |
| ECR API — `com.amazonaws.us-east-1.ecr.api` | Interface | **Future / conditional** | Required for private ECR API calls such as image metadata and authorization when pulling ECR images privately | Private DNS; endpoint SG inbound TCP 443 from container hosts. Not justified by the current EC2 application design alone. |
| ECR Docker — `com.amazonaws.us-east-1.ecr.dkr` | Interface | **Future / conditional** | Required for Docker Registry pull operations from private ECR | Private DNS; endpoint SG inbound TCP 443 from container hosts. Pair with ECR API and the S3 Gateway Endpoint for image layers. |
| KMS — `com.amazonaws.us-east-1.kms` | Interface | **Conditional** | Only if application code or an agent directly calls KMS APIs from private subnets | Private DNS; endpoint SG inbound TCP 443 from callers. EBS/RDS/EFS/S3 service-side encryption alone does not establish a need for an application KMS endpoint. |
| STS — `com.amazonaws.us-east-1.sts` | Interface | **Conditional** | Only if workload SDKs/agents call regional STS APIs from private subnets and NAT is not used | Private DNS; regional STS endpoint configuration and TCP 443; verify SDK endpoint behaviour. |

### Endpoint placement and controls

- For each interface endpoint selected for high availability, enable endpoint network interfaces in both application AZs (or in dedicated endpoint subnets in both AZs). A single-AZ endpoint creates an AZ dependency and can introduce cross-AZ traffic.
- Endpoint security groups should allow inbound TCP 443 only from the workload security groups that need each service. Workload security groups must allow outbound TCP 443 to the endpoint ENIs.
- Enable private DNS only after confirming VPC DNS support/hostnames and that no conflicting private hosted zone or custom DNS forwarding rule intercepts the service name.
- Endpoint policies are an additional resource-policy boundary; they do not replace IAM identity policies, bucket policies, KMS key policies or Secrets Manager resource policies.
- Keep S3 Gateway Endpoint separate from interface endpoints: it uses route-table prefix-list entries, not endpoint ENIs/security groups.
- Do not add ECS endpoints or ECR endpoints merely because the wider portfolio has a container project. Add them only if this Clafoke workload actually deploys/pulls images from ECR.
- Price interface endpoints using the actual endpoint count × enabled AZs × hours, plus data processing. Compare this with NAT fixed-hour and data-processing costs before choosing the private-endpoint strategy. The current calculator subtotal does not include this endpoint inventory.

### TLS certificate and DNS

Provision an ACM certificate for ALB HTTPS and a DNS alias/record in the authoritative DNS provider. Route 53 is not assumed to be authoritative; confirm domain ownership, DNS hosting and certificate validation method. Record certificate region (same Region as the ALB for a regional ALB certificate), renewal/validation ownership and DNS cutover plan. DNS and ALB charges remain outside the current partial subtotal.

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

N01 AZ IDs; N02 source CIDR implementation and overlap validation (reference `10.50.0.0/16`); N03 BGP implementation, both tunnel sessions and failover evidence (reference ASNs 65010/64512); N04 app port; N05 API allowlisting; N06 endpoint inventory; N07 egress inspection; N08 NACL requirements; N09 IAM boundaries; N10 retention; N11 MGN staging IP-capacity and AZ validation (reference `10.30.31.0/24` in AZ-A); N12 DNS zone/certificate ownership. Values are fictional planning assumptions until implementation.

**Status:** Proposed design; no AWS network/security resources deployed.


## AWS service network references

- [AWS DMS replication instance VPC and subnet-group requirements](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_ReplicationInstance.VPC.html)\n- [AWS MGN current network requirements](https://docs.aws.amazon.com/mgn/latest/ug/preparing-environments.html)\n- [AWS DataSync endpoint selection](https://docs.aws.amazon.com/datasync/latest/userguide/choose-service-endpoint.html)
- [AWS MGN network requirements](https://docs.aws.amazon.com/pdfs/mgn/latest/ug/user-guide.pdf)
- [AWS DataSync network requirements](https://docs.aws.amazon.com/datasync/latest/userguide/datasync-network.html)
- [AWS DataSync network architecture and traffic flows](https://docs.aws.amazon.com/datasync/latest/userguide/networking-datasync.html)
- [AWS DataSync access to EFS, mount-target subnet and security-group rules](https://docs.aws.amazon.com/datasync/latest/userguide/create-efs-location.html)
- [AWS VPC subnet sizing and five reserved IPv4 addresses](https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html)
- [Application Load Balancer subnet and free-IP requirements](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html)
- [VPC route tables and route selection](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
- [Site-to-Site VPN route propagation and static routes](https://docs.aws.amazon.com/vpn/latest/s2svpn/SetUpVPNConnections.html)
- [Site-to-Site VPN static versus dynamic BGP routing](https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-static-dynamic.html)
- [Site-to-Site VPN route priority and VGW ECMP limitation](https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-route-priority.html)
- [Site-to-Site VPN two-tunnel architecture](https://docs.aws.amazon.com/vpn/latest/s2svpn/how_it_works.html)
- [Customer Gateway ASN requirements](https://docs.aws.amazon.com/vpn/latest/s2svpn/cgw-options.html)
- [Security-group statefulness](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)
- [Network ACL statelessness and ephemeral ports](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
- [S3 Gateway Endpoint route-table association](https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html)
- [Systems Manager message endpoint behaviour and SSM Agent versions](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up-messageAPIs.html)
- [Systems Manager private endpoint troubleshooting](https://docs.aws.amazon.com/systems-manager/latest/userguide/troubleshooting-ssm-agent.html)
- [Secrets Manager interface VPC endpoint](https://docs.aws.amazon.com/secretsmanager/latest/userguide/vpc-endpoint-overview.html)
- [CloudWatch Monitoring interface VPC endpoint](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch-and-interface-VPC.html)
- [CloudWatch Logs interface VPC endpoint](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/cloudwatch-logs-and-interface-VPC.html)
- [ECR interface endpoints and S3 image-layer access](https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html)
