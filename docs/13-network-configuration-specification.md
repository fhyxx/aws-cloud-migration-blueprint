# 13 — Network Configuration Specification

**ID:** CLI-AWS-NCS-013 | **Version:** 1.1 | **Status:** Proposed configuration baseline — customer inputs and approvals outstanding  
**Project:** Clafoke Investors Ltd (fictional portfolio case study)  
**Related:** [Network and security design](03-network-security-design.md), [Network implementation preparation](11-network-implementation-preparation.md), [Network implementation review](12-network-implementation-review.md), [Migration readiness matrix](09-migration-readiness-matrix.md), [Technical architecture audit](10-technical-architecture-audit.md)

> This specification consolidates the intended network configuration for design review. All CIDRs, AZ labels, ASNs and example workload ports are illustrative portfolio assumptions unless explicitly marked as an AWS service requirement. It is not a Terraform plan, approved change, customer network record or deployment instruction. No AWS resources or connectivity tests are claimed.

## 1. Purpose and decision status

This document is the configuration-level handoff between the architecture/preparation artifacts and a future implementation plan. It defines subnet and route-table intent, route propagation boundaries, security-group policy, service-specific network dependencies, endpoint decision criteria, and acceptance tests.

**Current decision: HOLD.** The reference configuration is coherent enough for technical review, but actual source prefixes, AWS account/AZ mapping, customer gateway details, application listener, migration service modes, endpoint dependencies and owner approvals remain unverified. Do not generate/apply Terraform or change AWS/customer firewalls until the input register and change gates are closed.

### Decision labels

- **Baseline proposal:** the portfolio design owner's recommended configuration, still subject to owner approval.
- **AWS service requirement/guidance:** a service-specific network behaviour to recheck against current documentation and the selected service mode/Region.
- **Customer input required:** cannot be truthfully fixed from the fictional case study.
- **Conditional:** apply only when the named workload/service dependency is confirmed.

## 2. Addressing and subnet configuration baseline

### 2.1 VPC and subnet inventory

| Logical subnet | Illustrative CIDR | AZ | Route table | Intended workload |
|---|---|---|---|---|
| Public-A | `10.30.1.0/24` | AZ-A | RT-PUBLIC-A | ALB node/NAT-A |
| Public-B | `10.30.2.0/24` | AZ-B | RT-PUBLIC-B | ALB node/NAT-B |
| App-A | `10.30.11.0/24` | AZ-A | RT-APP-A | Private application instances |
| App-B | `10.30.12.0/24` | AZ-B | RT-APP-B | Private application instances |
| DB-A | `10.30.21.0/24` | AZ-A | RT-DB-A | RDS subnet group |
| DB-B | `10.30.22.0/24` | AZ-B | RT-DB-B | RDS subnet group |
| MGN staging | `10.30.31.0/24` | AZ-A (provisional) | RT-MGN | MGN replication servers |
| DMS-A | `10.30.41.0/24` | AZ-A | RT-DMS-A | DMS replication subnet group |
| DMS-B | `10.30.42.0/24` | AZ-B | RT-DMS-B | DMS replication subnet group |
| DataSync endpoint | `10.30.51.0/24` | AZ-A | RT-DATASYNC-ENDPOINT | VPC service endpoint ENI |
| DataSync task | `10.30.52.0/24` | AZ-A | RT-DATASYNC-TASK | DataSync task ENIs; same AZ as EFS mount target A |

VPC: `10.30.0.0/16`, Region `us-east-1`, two logical AZs. Resolve AZ-A/AZ-B to account-specific AZ IDs before implementation. The six steady-state subnets and five migration-only subnets are separate network segments. Each /24 has 251 initially assignable IPv4 addresses before ENIs and service consumption; this is not a capacity guarantee. Recheck free IP headroom for ALB, NAT, DMS, MGN and interface endpoint ENIs.

### 2.2 Customer/on-premises network placeholders

| Prefix | Illustrative value | Intended use |
|---|---|---|
| Customer aggregate | `10.50.0.0/16` | BGP advertisement |
| Source application | `10.50.10.0/24` | MGN source VMs |
| Source PostgreSQL/NFS | `10.50.20.0/24` | DMS source and NFS source |

These values must be replaced or explicitly approved as synthetic lab assumptions. Obtain full overlap inventory for branches, offices, partners, VPNs, peering and other cloud networks. Do not publish customer public IPs, tunnel secrets or device configuration.

## 3. Route-table specification

All route tables include the VPC-local route. The table below lists additional intended routes.

| Route table | Association | Additional routes | Must not contain |
|---|---|---|---|
| RT-PUBLIC-A | Public-A | `0.0.0.0/0 → IGW` | VGW propagated source route |
| RT-PUBLIC-B | Public-B | `0.0.0.0/0 → IGW` | VGW propagated source route |
| RT-APP-A | App-A | `0.0.0.0/0 → NAT-A`; S3 prefix-list route → S3 Gateway Endpoint when endpoint is associated | `10.50.0.0/16 → VGW` |
| RT-APP-B | App-B | `0.0.0.0/0 → NAT-B`; S3 prefix-list route → S3 Gateway Endpoint when endpoint is associated | `10.50.0.0/16 → VGW` |
| RT-DB-A | DB-A | Local route only | Default internet route; VGW propagated route |
| RT-DB-B | DB-B | Local route only | Default internet route; VGW propagated route |
| RT-DMS-A | DMS-A | `10.50.0.0/16 → VGW` (BGP propagated); `0.0.0.0/0 → NAT-A`; conditional S3 prefix-list route if the selected DMS workflow requires S3 | Any route propagation beyond this dedicated migration table |
| RT-DMS-B | DMS-B | `10.50.0.0/16 → VGW` (BGP propagated); `0.0.0.0/0 → NAT-B`; conditional S3 prefix-list route if required | Any route propagation beyond this dedicated migration table |
| RT-MGN | MGN staging | `10.50.0.0/16 → VGW` (BGP propagated); `0.0.0.0/0 → NAT-A` for regional service HTTPS unless a validated private path is selected | Broad ingress or propagation into application/DB route tables |

**Propagation boundary:** enable VGW route propagation only on RT-DMS-A, RT-DMS-B, RT-MGN, RT-DATASYNC-ENDPOINT and RT-DATASYNC-TASK. Do not propagate the customer aggregate into public, application or DB route tables. The customer gateway advertises the agreed customer prefixes; the VGW advertises the VPC CIDR. Customer-side firewall policy must narrow actual reachability to the required migration flows.

**Important route semantics:**
- Route propagation makes a prefix available in a route table; it does not authorize traffic. Security groups, NACLs and customer firewalls remain separate controls.
- Verify the effective route table actually associated with each subnet. An unassociated route table has no effect.
- A propagated route remaining visible is not proof of healthy VPN/BGP connectivity. Monitor tunnel/BGP state and active end-to-end probes; test route withdrawal and recovery.
- VGW does not support ECMP. One VPN connection with two tunnels is tunnel redundancy/failover, not active-active bandwidth aggregation.
- NAT-A/NAT-B are same-AZ egress choices for the proposed DMS and app subnets. Confirm regional service endpoints and traffic paths before selecting NAT versus private endpoints.

## 4. Hybrid VPN and BGP configuration

| Parameter | Reference proposal | Validation gate |
|---|---|---|
| AWS attachment | VGW attached to VPC | Confirm no conflicting VGW/TGW design |
| Routing | Dynamic BGP | Confirm customer device and policy support |
| Customer ASN | `65010` | Customer Network Lead confirms uniqueness/ownership |
| VGW ASN | `64512` | Confirm actual VGW ASN |
| Customer prefixes | `10.50.0.0/16` | Replace with approved actual prefixes |
| VPN connection | One connection, two AWS tunnels | Business/Network owner approves resilience tier |
| Customer outside IP | Placeholder only | Exchange securely; never invent |
| Route propagation | DMS-A, DMS-B, MGN, DataSync endpoint and DataSync task only | Verify exact five route-table associations |

Configure both tunnels from AWS-generated configuration for the actual customer gateway vendor/firmware. Do not hard-code outside IPs, tunnel inside CIDRs, pre-shared keys or device commands in this document. Permit asymmetric routing where required by the VGW design and verify return paths.

A second VPN connection using a second customer gateway and diverse ISP/device paths is a separate resilience option. It is not included in the current one-connection cost baseline. Decide based on business recovery requirements; do not silently add it.

## 5. Security-group policy

Security groups are stateful. Prefer SG-to-SG references for VPC-local peers; use CIDRs only where the peer is on-premises or service endpoints do not support SG references. The DMS egress entry below intentionally follows the AWS DMS networking recommendation as the default proposal; it is not a claim that the security team has approved it.

| Rule ID | SG / direction | Source or destination | Protocol / port | Purpose and constraints | Owner / validation |
|---|---|---|---|---|---|
| SG-01 | ALB ingress | Approved client CIDRs | TCP 443 | Public HTTPS only; ACM certificate and listener confirmed | Security + App; verify TLS/listener |
| SG-02 | ALB ingress (conditional) | Approved client CIDRs | TCP 80 | Only if HTTP-to-HTTPS redirect is required | Security; otherwise omit |
| SG-03 | ALB egress | App SG | Actual target protocol/port (8080 provisional) | Listener and health-check target; confirm actual application contract | App; target health test |
| SG-04 | App ingress | ALB SG | Actual target protocol/port (8080 provisional) | No direct public or on-premises application ingress | App + Security |
| SG-05 | App egress | RDS SG | TCP 5432 | Application database access | DBA; connection test |
| SG-06 | App egress | EFS mount-target SG | TCP 2049 | Application shared-file access | Infrastructure; mount test |
| SG-07 | App egress | Approved service endpoints / destinations | TCP 443 | Only confirmed APIs and management dependencies; endpoint/NAT design unresolved | Operations + Security |
| SG-08 | RDS ingress | App SG | TCP 5432 | Steady-state application access | DBA |
| SG-09 | RDS ingress (temporary) | DMS SG | TCP 5432 | Migration-only DMS target endpoint; remove after DMS no longer requires it | DBA + Migration Lead |
| SG-10 | EFS ingress | App SG | TCP 2049 | Application NFS access | Infrastructure |
| SG-11 | EFS ingress | DataSync task-ENI SG | TCP 2049 | DataSync task ENI to EFS mount target | Infrastructure; same VPC and compatible AZ/mount-target placement |
| SG-12 | DMS ingress | None by default | None | No unsolicited inbound required; add only a documented service requirement | Security |
| SG-13 | DMS egress (baseline proposal) | All destinations | All protocols/ports | Follow current AWS DMS recommendation for replication-instance SG outbound; control exposure through dedicated subnet routes, no public ingress, tightly scoped source/target ingress, customer firewall and endpoint policies | Solutions Architect + Security + DBA; recheck selected DMS mode and current AWS docs |
| SG-14 | On-prem PostgreSQL ingress | DMS-A and DMS-B CIDRs only | TCP 5432 | Source DB accepts only DMS migration subnet sources, not all VPC/application subnets | Customer Network + DBA |
| SG-15 | MGN staging ingress | Source application VM CIDR only | TCP 1500 | Source-agent replication stream to staging replication servers | Customer Network + Infrastructure |
| SG-16 | MGN source egress | Regional MGN API endpoints | TCP 443 | Source agent control-plane access; no SSL interception/deep packet inspection on documented MGN paths | Security + Infrastructure |
| SG-17 | MGN staging egress | Regional MGN API and documented service dependencies | TCP 443 | Replication server service connectivity; confirm S3/other regional requirements | Security + Infrastructure |
| SG-18 | DataSync agent to NFS | NFS server | TCP 2049 (NFSv4.x); TCP 111 and 2049 (NFSv3) | Select ports from actual NFS version and server configuration | Infrastructure |
| SG-19 | DataSync agent to VPC service endpoint (conditional) | DataSync VPC endpoint | TCP 1024–1064 | VPC endpoint control-plane path | Infrastructure + Security |
| SG-20 | DataSync agent to task ENI (conditional) | DataSync task ENI | TCP 443 | VPC endpoint data-plane path | Infrastructure + Security |
| SG-21 | DataSync agent to public service endpoint (conditional) | Documented regional DataSync/activation endpoints | TCP 443 | Public endpoint path; Basic-mode bootstrap dependency must be checked | Infrastructure + Security |
| SG-22 | DataSync task ENI to EFS | EFS mount-target SG | TCP 2049 | Task data access; task ENI in same VPC and AZ compatible with EFS mount target | Infrastructure |
| SG-23 | Interface endpoint ingress (conditional) | Only workload SGs requiring endpoint | TCP 443 | Endpoint SG accepts HTTPS from approved clients only | Security + Operations |
| SG-24 | DNS (conditional) | Approved resolver | UDP/TCP 53 as required | Use actual VPC/on-prem resolver and forwarding architecture; do not invent resolver IPs | Network + Operations |
| SG-25 | NTP (conditional) | Approved time source | UDP 123 as required | Confirm source OS, resolver and time policy | Infrastructure |
| SG-26 | DataSync VPC endpoint ingress | Agent `10.50.20.50/32` | TCP 1024–1064 | Endpoint control plane; dedicated endpoint subnet/route table | Infrastructure + Security |
| SG-27 | DataSync task ENI ingress | Agent `10.50.20.50/32` | TCP 443 | VPC endpoint data plane; dedicated task subnet has VGW return route | Infrastructure + Security |

**DMS egress decision:** use the AWS-documented all-outbound replication-SG recommendation as the reference baseline rather than publishing the earlier 5432/443/DNS-only list as implementation-ready. This is a design recommendation pending Security/DBA approval. Compensating boundaries are dedicated DMS-A/B subnets, route propagation only on DMS-A/B, no public inbound, source PostgreSQL ingress only from the DMS subnet CIDRs, RDS ingress only from the DMS SG for the migration window, and customer firewall policy. If Security requires narrower egress, that becomes an explicit exception: document the exact supported flow inventory for selected mode/endpoints, verify AWS supportability, and pass endpoint/connectivity tests before replacing this baseline. A generic narrow list is not sufficient evidence.

**MGN inspection control:** do not apply SSL interception/deep packet inspection to documented MGN API/replication paths. Confirm Region-specific endpoints and any S3 dependency before source-agent installation.

**NACL baseline:** retain default NACLs unless a specific subnet-level stateless control is required. If custom NACLs are introduced, document request and ephemeral return-port rules in both directions and test them. Do not infer NACL behaviour from stateful SG rules.

## 6. Migration-service endpoint and topology decisions

### 6.1 AWS DMS

- Use the dedicated DMS-A/DMS-B subnets as the replication subnet group, across two distinct AZs in the same VPC.
- DMS initiates TCP 5432 to the self-managed PostgreSQL source over the VPN and to the RDS target over VPC-local routing.
- Source firewall allows TCP 5432 only from DMS-A/B CIDRs. RDS temporarily allows TCP 5432 from the DMS SG.
- Use the all-outbound SG baseline in section 5 pending mode-specific AWS review and Security approval. Do not open source/target ingress broadly.
- Confirm provisioned versus Serverless mode, endpoint type, Secrets Manager/logging/DNS dependencies, S3 use and exact AWS network guidance before deployment.
- Validate DMS subnet-group membership, AZ IDs, ENI capacity, source/target endpoint tests and cleanup of temporary RDS ingress.

### 6.2 AWS Application Migration Service (MGN)

- Source agents need regional MGN API TCP 443 and source-to-staging TCP 1500.
- Staging replication servers need regional MGN service TCP 443 and any current Region-specific service dependencies, including S3 where required.
- Use the dedicated MGN staging subnet `10.30.31.0/24` as a single-AZ cost-conscious planning assumption only. Do not claim staging infrastructure HA.
- Before implementation, decide whether single-AZ staging meets migration recovery and capacity requirements. Any multi-AZ alternative requires validated service support, IP/capacity planning and revised pricing.
- Record explicit TLS inspection exclusions for documented MGN paths and verify endpoint allow-lists.

### 6.3 AWS DataSync

An agent can use only one service-endpoint type. Select one per agent after confirming task mode, source location, routing and security policy. If workflows need different endpoint types, plan separate agents.

| Option | Agent-to-service path | Task data path | Select when | Open checks |
|---|---|---|---|---|
| Public / FIPS public endpoint | HTTPS TCP 443 to current documented endpoint/activation dependencies | Service-mediated task path; validate current task-specific requirements | Agent has approved outbound HTTPS and public service endpoint is acceptable | Regional endpoint allow-list, Basic-mode CloudFront bootstrap, proxy/TLS inspection, data path and mode |
| VPC / FIPS VPC endpoint | TCP 1024–1064 from agent to VPC service endpoint | TCP 443 from agent to task ENI | Private service access is required and VPN/VPC routing can reach endpoint ENIs | Endpoint subnet/AZ, routes, SGs, DNS, task ENI placement, source agent path and task mode |

For NFS, use TCP 2049 for NFSv4.x or TCP 111 plus 2049 for NFSv3. Confirm the exact NFS version, exports, permissions and source firewall. For EFS, DataSync task ENIs must be in the same VPC and an AZ with an EFS mount target; permit TCP 2049 from task-ENI SG to EFS mount-target SG. For S3, validate bucket policy, IAM role, encryption/KMS and task permissions. TCP 22 is an optional support channel, not a normal transfer prerequisite; enable only if explicitly approved.

**Endpoint selection remains OPEN.** Do not assume a public endpoint or VPC endpoint is selected merely because it appears in this comparison. Archive source type/location is also unknown; determine whether it needs a separate agent and endpoint topology.

## 7. DNS, time, endpoints and egress dependencies

| Dependency | Current decision | Required resolution |
|---|---|---|
| VPC DNS support/hostnames | Enabled in reference design | Confirm resolver and private DNS behaviour in target account |
| On-prem DNS forwarding | Unknown | Identify resolvers, conditional forwarders, private zones and reachability |
| NTP/time | Unknown | Identify approved time sources and OS dependencies |
| Proxy/TLS inspection | Unknown | Record proxy path and exclusions for MGN; validate DataSync endpoint behaviour |
| S3 Gateway Endpoint | Candidate for app subnets; conditional DMS association | Approve route-table associations, endpoint policy, bucket policy and IAM |
| Interface endpoints | Not selected | Inventory actual API callers; choose endpoints, AZ coverage, private DNS, endpoint SGs and cost |
| NAT | NAT-A/B for private subnet service egress in reference baseline | Validate regional service dependencies, traffic volumes, AZ failure behaviour and processing cost |
| ECR/ECS endpoints | Not implied by current app design | Add only if the deployment model actually requires ECR/ECS API access |
| SSM endpoints | Conditional | Determine agent version/Region and whether SSM, ssmmessages and legacy ec2messages are needed |
| Secrets Manager/CloudWatch/KMS/STS | Conditional | Map actual workload and migration-service API calls before endpoint count is fixed |

Do not create interface endpoints by checklist alone. Every endpoint must have a named caller, required service, endpoint policy, SG source, DNS plan, AZ coverage and cost owner.

## 8. Validation and acceptance catalogue

All tests below are **not run**. Execute only in an approved non-production/test environment or under an approved change, and retain sanitized evidence with timestamp, source, destination, owner and result.

| Test ID | Test | Expected result / acceptance |
|---|---|---|
| NCS-01 | CIDR overlap review | AWS VPC/subnets and customer/connected networks do not overlap; IPAM evidence attached |
| NCS-02 | AZ and subnet capacity | Account-specific AZ IDs recorded; free IP headroom validated for DMS, MGN, ALB, NAT and endpoints |
| NCS-03 | Route-table association audit | Every subnet is associated with its intended route table |
| NCS-04 | VGW propagation boundary | Customer prefix is propagated only to RT-DMS-A, RT-DMS-B and RT-MGN |
| NCS-05 | Negative route isolation | Public, App-A/B and DB-A/B route tables do not contain customer propagated route |
| NCS-06 | VPN/BGP health | Both tunnels and BGP peers configured; state and active probes healthy |
| NCS-07 | VPN failure/recovery | Controlled tunnel failure and recovery meet approved interruption threshold; route presence alone is not accepted as health |
| NCS-08 | DMS source path | DMS-originated TCP 5432 reaches PostgreSQL source from DMS-A/B only |
| NCS-09 | DMS target path | DMS reaches RDS TCP 5432; temporary RDS ingress is scoped to DMS SG |
| NCS-10 | DMS egress policy | Selected mode and AWS guidance reviewed; approved SG egress and all endpoint/service dependencies tested |
| NCS-11 | MGN API path | Source and staging regional API TCP 443 paths work without prohibited TLS inspection |
| NCS-12 | MGN replication path | Source-to-staging TCP 1500 works only from approved source VM addresses |
| NCS-13 | MGN capacity/AZ decision | Staging free IPs, replication-server capacity and single-AZ acceptance or approved alternative documented |
| NCS-14 | DataSync NFS path | Version-specific NFS ports and permissions validated from agent to source |
| NCS-15 | DataSync endpoint path | Selected endpoint type and its required control/data-plane ports validated; one endpoint type per agent |
| NCS-16 | DataSync EFS path | Task ENI to EFS TCP 2049 works; VPC/AZ/mount-target relationship verified |
| NCS-17 | DNS/NTP/proxy | Name resolution, time sync, proxy and TLS inspection behaviour meet service requirements |
| NCS-18 | Negative application path | App subnets cannot reach on-premises source prefixes through propagated routes |
| NCS-19 | Negative database/public path | DB/public subnets have no customer route; no public SSH/PostgreSQL ingress |
| NCS-20 | Temporary access removal | DMS temporary RDS ingress and other migration-only rules removed after approved migration completion |
| NCS-21 | Evidence and change closure | Change record, approvers, rollback outcome, sanitized evidence and cost changes attached |

### Go/no-go

**No-go** if any of the following remains unresolved: CIDR overlap; incorrect route-table association/propagation; unapproved VPN resilience; DMS egress without service-specific review; MGN endpoint/TLS inspection uncertainty; unknown DataSync source/endpoint path; inadequate subnet capacity; missing owner approvals; or absent rollback/change authority.

**Go for implementation planning only** when NIV-001 through NIV-012 have evidence, the applicable NCS tests have an approved execution plan, and accountable owners sign the change. Passing documentation review does not itself authorize AWS changes.

## 9. Traceability to input validation register

| Specification area | Input register IDs | Evidence register |
|---|---|---|
| Addressing, VPC and AZs | NVR-01, NVR-02, NVR-03 | NIV-001, NIV-002, NIV-011 |
| VPN, BGP and resilience | NVR-04, NVR-05, NVR-06, NVR-07 | NIV-003, NIV-004, NIV-005 |
| DMS mode, placement and egress | NVR-08, NVR-09 | NIV-006 |
| MGN endpoints, inspection and staging | NVR-10, NVR-11 | NIV-007, NIV-011 |
| Application listener/health | NVR-12 | NIV-008 |
| DataSync source, agent and endpoint | NVR-13, NVR-14, NVR-15, NVR-16 | NIV-009 |
| DNS, NTP, proxy, NACL and endpoints | NVR-17, NVR-18, NVR-19 | NIV-010 |
| Cost and resilience | NVR-07, NVR-19, NVR-20 | NIV-005, NIV-011 |
| Change, rollback and evidence | NVR-21 | NIV-012 |

## 10. Implementation boundary and next actions

1. Review this configuration baseline with Network, Security, DBA, Infrastructure, Application and Migration owners.
2. Replace illustrative values only when supported by dated source evidence; otherwise retain them explicitly as synthetic portfolio assumptions.
3. Resolve NVR-08 DMS egress, NVR-10 MGN endpoints/inspection, NVR-11 staging AZ/capacity, NVR-14/15 DataSync endpoint/agent design and NVR-07 VPN resilience.
4. Update the readiness matrix and audit with owner decisions and evidence references.
5. Only after the HOLD is lifted, derive Terraform variables/modules and an approved implementation plan. Validate a plan output before any apply; AWS changes require explicit change approval.

## 11. AWS references

- [AWS DMS — Setting up a network for a replication instance](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_ReplicationInstance.VPC.html)
- [AWS MGN — Preparing source and target environments / network requirements](https://docs.aws.amazon.com/mgn/latest/ug/preparing-environments.html)
- [AWS DataSync — Network requirements](https://docs.aws.amazon.com/datasync/latest/userguide/datasync-network.html)
- [AWS DataSync — Choosing a service endpoint](https://docs.aws.amazon.com/datasync/latest/userguide/choose-service-endpoint.html)
- [AWS DataSync — Network traffic flows](https://docs.aws.amazon.com/datasync/latest/userguide/networking-datasync.html)
- [AWS DataSync — Creating an EFS location](https://docs.aws.amazon.com/datasync/latest/userguide/create-efs-location.html)
- [AWS Site-to-Site VPN — Redundant connections for failover](https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-redundant-connection.html)
- [AWS Site-to-Site VPN — Route priority and tunnel selection](https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-route-priority.html)
- [VPC route tables](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
- [Security groups](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)
- [Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)

**Specification decision:** proposed network configuration baseline published for review. Customer inputs, approvals, implementation and live validation remain outstanding.