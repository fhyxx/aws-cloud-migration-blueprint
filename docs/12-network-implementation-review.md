# 12 — Network Implementation Review and Input Validation Register

**ID:** CLI-AWS-NIV-012 | **Version:** 1.2 | **Status:** Synthetic baseline approved for continued engineering — live AWS execution separately gated  
**Project:** Clafoke Investors Ltd (fictional portfolio case study)  
**Related:** [Network and security design](03-network-security-design.md), [Network implementation preparation](11-network-implementation-preparation.md), [Migration readiness matrix](09-migration-readiness-matrix.md), [Technical architecture audit](10-technical-architecture-audit.md), [Network configuration specification](13-network-configuration-specification.md)

> This register separates documented design assumptions from facts that must be supplied by a real customer or confirmed in the intended AWS account. The case study is synthetic. Fictional network details are deliberately specified in document 14 and Terraform variables. They are not customer-discovered facts. Real account-specific IDs, an activated DataSync agent and source credentials remain runtime inputs, not blockers to repository engineering. No network implementation or live connectivity test is claimed.

## 1. Review decision

**Decision: synthetic portfolio baseline is approved for continued Terraform design and validation. Live AWS deployment remains separately gated.**

The reference network is internally structured for a fictional migration: VPC `10.30.0.0/16`, six steady-state subnets, dedicated DMS-A/DMS-B subnets, a separate MGN staging subnet, selective VGW route propagation, and explicit migration traffic paths. These are portfolio design values, not customer-discovered facts.

The review found one material implementation caveat: the current least-privilege DMS outbound SG proposal is narrower than the current AWS DMS networking guidance, which recommends allowing all outbound traffic from the replication-instance security group. The proposed narrow rule set must therefore be treated as **unverified**, not an approved DMS configuration. See finding NVR-08.

## 2. Input validation register

| ID | Input / decision | Current value | Validation status | Required evidence / decision owner |
|---|---|---|---|---|
| NVR-01 | Customer source network CIDRs | Illustrative `10.50.0.0/16`; app `10.50.10.0/24`; DB/NFS `10.50.20.0/24` | Not supplied | Actual IPAM export or network diagram; full overlap check against AWS, VPN, office, branch, partner and cloud networks. Customer Network Lead |
| NVR-02 | AWS VPC allocation | Illustrative `10.30.0.0/16` | Not confirmed in target account | Confirm account/Region, VPC CIDR allocation, existing peering/TGW/VPN routes and IPAM reservation. AWS Account Owner |
| NVR-03 | AZ mapping and subnet capacity | Logical AZ-A/AZ-B; eleven proposed /24s | Not confirmed | Resolve account-specific AZ IDs, subnet IDs and free IP counts; validate ALB, NAT, DMS ENI, endpoint ENI and MGN replication capacity. AWS Infrastructure Lead |
| NVR-04 | Customer Gateway device | BGP-capable edge; model unknown | Not supplied | Vendor, model, firmware, HA mode, supported IKE/IPsec algorithms, BGP support, interface/route limits and AWS configuration template. Customer Network Lead |
| NVR-05 | Customer Gateway outside connectivity | Static public outside IP assumed | Not supplied | Public IP exchanged securely, upstream ISP/firewall, NAT-T, UDP 500/4500 and ESP handling as applicable, device initiation/DPD behaviour. Customer Network Lead |
| NVR-06 | BGP ASNs and policy | Customer 65010 / VGW 64512 | Illustrative only | Confirm ASN ownership/uniqueness, private ASN policy, advertised prefixes, accepted prefixes, filters, maximum-prefix limits, route preference and return path. Customer Network Lead |
| NVR-07 | VPN resilience tier | One VPN connection with two tunnels | Decision not approved | Confirm whether tunnel-level redundancy is sufficient or whether independent customer devices and diverse ISP paths are required. Business Owner, Network Lead, Security Lead |
| NVR-08 | DMS replication SG egress | Proposed narrow egress for TCP 5432, TCP 443 and DNS | AWS guidance review required | AWS DMS networking guidance recommends all-port outbound from the replication SG. Validate required flows for the selected DMS mode, endpoints, logging, Secrets Manager/VPC endpoints and routing. Approve explicit egress policy and compensating controls; retain documented rationale and successful connection tests. Solutions Architect, Security Lead, DBA |
| NVR-09 | DMS subnet group and source/target access | DMS-A/B dedicated /24s; DataSync endpoint/task subnets `10.30.51.0/24` and `10.30.52.0/24`; PostgreSQL TCP 5432 | Not deployed/tested | Confirm same VPC, at least two subnets in separate AZs, dedicated SG association, route propagation only on DMS-A/B, MGN staging and the two dedicated DataSync subnets, source firewall allow-list from DMS subnet CIDRs and target RDS ingress from DMS SG. DBA, Infrastructure Lead |
| NVR-10 | MGN service access | TCP 443 to MGN API; TCP 1500 source-to-staging; staging TCP 443 | Not validated | Confirm current Region-specific MGN endpoints and required S3/EC2 service access, DNS, firewall/proxy policy, no SSL interception/DPI on documented MGN API/replication paths, and source-to-staging route. Infrastructure Lead, Security Lead |
| NVR-11 | MGN staging availability and scale | `10.30.31.0/24`, AZ-A | Single-AZ planning assumption | Confirm replication-server count, expected IP/throughput use, staging subnet free IPs, AZ failure implications, recovery expectations and whether a multi-AZ staging design is required. Infrastructure Lead, Migration Lead |
| NVR-12 | Application listener and health check | TCP 8080 and `/health/ready` are provisional | Not supplied | Application owner confirms bind address, listener, protocol, health path, expected status/body, dependencies, startup time and ALB health-check thresholds. Application Lead |
| NVR-13 | DataSync NFS source | NFSv4.1 over TCP 2049 | Not supplied | Confirm NFS 3.x/4.0/4.1/4.2, exports, server IPs, mount options, source firewall, permissions, locking/writer behaviour and measured used bytes. Infrastructure Lead, Application Lead |
| NVR-14 | DataSync service endpoint type | VPC endpoint selected; endpoint subnet `10.30.51.0/24`, task subnet `10.30.52.0/24`; agent `10.50.20.50/32` | Synthetic decision recorded | Choose endpoint type per agent. An agent uses one endpoint type; if separate tasks require different endpoint types, plan separate agents. Validate public endpoint allow-list or VPC endpoint TCP 1024–1064 control-plane and TCP 443 task data-plane paths; dedicated endpoint subnet `10.30.51.0/24`, task subnet `10.30.52.0/24`, route propagation to both, and endpoint/task SG ingress limited to synthetic agent `10.50.20.50/32`. Infrastructure Lead, Security Lead |
| NVR-15 | DataSync agent mode and support channel | Basic-mode VPC-endpoint agent; TCP 22 disabled | Synthetic decision recorded | Select supported agent/mode for task type. TCP 22 is a support channel, not a normal transfer prerequisite; enable only if deliberately approved. For Basic public-endpoint agents, validate pre-activation CloudFront bootstrap requirement. Infrastructure Lead |
| NVR-16 | Archive source | Unknown; 500 GB S3 is target capacity only | Not supplied | Identify actual source platform/location, eligible bytes/objects, access method, agent requirement, encryption and retention. Data Owner, Application Lead |
| NVR-17 | DNS, NTP, proxy and TLS inspection | Not specified | Not supplied | Identify resolvers, forwarding, private DNS zones, NTP, outbound proxy, certificate inspection and exception policy for MGN/DataSync endpoints. Security Lead, Infrastructure Lead |
| NVR-18 | NACL posture | Default NACLs proposed | Not approved | Confirm default NACL retention or document exact subnet-level deny requirement, ephemeral return-port policy and test evidence. Security Lead |
| NVR-19 | VPC endpoint and NAT strategy | S3 Gateway Endpoint candidate; interface endpoints conditional | Not decided | Map actual API calls per workload; decide NAT versus interface endpoints, AZ coverage, private DNS, endpoint SG/policy and cost. Operations Lead, Security Lead, Solutions Architect |
| NVR-20 | VPN and endpoint cost scope | Existing partial baseline includes one VPN connection/tunnel public IPv4; endpoint costs unresolved | Not a final cost | Re-price if a second VPN connection/customer gateway, additional endpoint AZs, inspection/proxy/firewall or different NAT architecture is approved. FinOps, Solutions Architect |
| NVR-21 | Change, rollback and evidence governance | No implementation window approved | Not supplied | Change ID, maintenance window, approvers, device owners, rollback authority, escalation contacts, evidence retention location and sanitisation rules. Migration Lead, Business Owner |

## 3. Technical review findings requiring resolution

### NVR-08 — DMS security-group egress requires a deliberate decision

The preparation pack currently proposes narrow outbound rules from SG-DMS. Current AWS DMS networking guidance states that the replication-instance VPC security group should allow all traffic on all ports to leave the VPC so the replication instance can communicate with source and target endpoints when their ingress controls are correctly configured.

This is a difference between a generic least-privilege design preference and the service's published network guidance. Do not silently claim that TCP 5432/443/DNS-only egress is a supported universal DMS configuration.

Before implementation:

1. Confirm whether the selected migration uses a provisioned replication instance or DMS Serverless.
2. Confirm endpoint type, Secrets Manager use, logging, DNS, service access and any VPC endpoint configuration.
3. Review current DMS guidance for the selected mode and Region.
4. Decide whether to follow the documented broad egress recommendation, or use a narrower tested design with explicit AWS support/compatibility evidence.
5. Keep source/target ingress tightly restricted: source PostgreSQL permits TCP 5432 only from DMS-A/B address space; target RDS permits TCP 5432 from SG-DMS during the migration window.
6. Record the security exception/rationale and test evidence before closing the gate.

A broad DMS SG egress rule does not mean opening the source database or RDS inbound to the internet. Ingress, routing, endpoint policies and on-premises firewall rules remain separate controls.

### NVR-10 — MGN paths and inspection controls

The source agent requires continuous TCP 443 connectivity to the regional MGN API and TCP 1500 to replication servers in the staging subnet. Replication servers also require TCP 443 to the MGN service. The current AWS guidance also identifies service dependencies such as S3 access. Do not treat TCP 1500 as the only migration path.

AWS warns against SSL interception for communication between replication servers and the MGN API endpoint and between source servers and the MGN API endpoint. Confirm the actual firewall/proxy inspection policy before agent installation. Record endpoint-specific allow-lists for the chosen Region.

### NVR-14/NVR-15 — DataSync endpoint and agent model

DataSync public/FIPS and VPC/FIPS VPC service endpoints have different network paths. For VPC service endpoints, AWS documents agent-to-service-endpoint TCP 1024–1064 for control-plane traffic and agent-to-task-ENI TCP 443 for data-plane traffic. For public endpoints, the agent needs the relevant AWS HTTPS endpoints; Basic mode agents also have a CloudFront bootstrap dependency before activation. NFS uses TCP 2049 for NFSv4.x and TCP 111 plus 2049 for NFSv3.

An agent can use only one endpoint type. If the final NFS and archive workflows require different endpoint types, the agent topology and cost model must account for separate agents. TCP 22 is an optional support channel, not a normal data-transfer requirement.

### NVR-07 — VPN tunnel redundancy is not site/ISP/device redundancy

A single Site-to-Site VPN connection supplies two AWS tunnel endpoints. This protects against an individual tunnel endpoint failure but does not by itself protect against failure of the single customer gateway device or its ISP path. AWS documents a second VPN connection using a second customer gateway device as the pattern for customer-device failure protection. The required resilience tier is a business/network decision; it changes design, operations and cost.

### NVR-11 — MGN staging subnet is single-AZ by design

The current `10.30.31.0/24` MGN staging subnet is in AZ-A only. This is a cost-conscious planning simplification, not a claim of multi-AZ replication infrastructure resilience. Confirm whether that is acceptable for the migration's recovery objectives and replication-server capacity. Do not add a second staging subnet without validating the MGN service's current staging-subnet/AZ requirements and cost impact.

## 4. Inputs that can be decided internally versus customer-owned

| Decision category | Can the portfolio design owner decide? | Requires customer/account owner |
|---|---|---|
| Proposed subnet segmentation and isolation intent | Yes, as a reference architecture | Actual address allocation and account-specific AZ IDs |
| Illustrative BGP pattern and route propagation scope | Yes, as a design proposal | Actual ASN, device, advertised prefixes, route policy and customer firewall |
| Application port and health endpoint | No, not without application evidence | Application Lead |
| DMS mode and endpoint design | Can shortlist options | DBA/source compatibility, security approval and measured benchmark |
| MGN staging subnet/AZ count | Can propose options | Source profile, migration schedule, recovery needs and approved cost |
| DataSync mode/endpoint/agent count | Can shortlist options | NFS version, archive source, data inventory and network topology |
| Endpoint versus NAT trade-off | Can model scenarios | Actual API dependencies, security policy, egress architecture and FinOps approval |
| VPN resilience tier | Can explain trade-offs | Business risk appetite, customer network topology and budget |
| NACL policy and TLS inspection exceptions | Can propose baseline | Security policy owner and network operations |

## 5. Review evidence required to close the input register

| Evidence ID | Evidence | Minimum acceptance condition |
|---|---|---|
| NIV-001 | Source and connected-network CIDR inventory | Actual prefixes, owners and no overlap documented |
| NIV-002 | AWS account/VPC/AZ inventory | Correct account/Region, VPC allocation and AZ IDs confirmed |
| NIV-003 | Customer gateway capability sheet | Vendor/model/firmware, BGP, IKE/IPsec, NAT-T and HA documented |
| NIV-004 | BGP route policy | ASNs, advertised/accepted prefixes, filters and return routing approved |
| NIV-005 | VPN resilience decision | One connection/two tunnels or multiple connections/devices/ISPs formally selected |
| NIV-006 | DMS network/security decision | DMS mode and egress design reconciled with current AWS guidance; ingress remains restricted |
| NIV-007 | MGN connectivity matrix | Regional endpoints, TCP 443/1500, S3 dependencies and TLS-inspection exclusions approved |
| NIV-008 | Application listener/health contract | Actual listener, protocol, path and readiness semantics confirmed |
| NIV-009 | DataSync source/agent worksheet | NFS version, archive source, endpoint type, task mode and agent count confirmed |
| NIV-010 | DNS/NTP/proxy/NACL/endpoint decisions | Dependencies and policy owners recorded |
| NIV-011 | Capacity and cost decision | Subnet IP headroom, staging AZ design, NAT/VPN/endpoint costs reviewed |
| NIV-012 | Change and rollback approval | Change ID, window, approvers, rollback and evidence location recorded |

No evidence ID is considered complete merely because a value is filled into this document. Attach or reference the source evidence, date, owner and approval.

## 6. Readiness decision

**Current outcome: APPROVED TO CONTINUE PORTFOLIO ENGINEERING; LIVE AWS APPLY REMAINS GATED.**

The fictional design has a usable reference baseline. The following are required only before live AWS execution, not before continuing code, static tests or documentation:

1. For live execution, replace synthetic source CIDRs with an actual IPAM inventory and verify overlap.
2. Resolve account-specific VPC/AZ IDs and the customer gateway's real public outside IP/device configuration.
3. Use the approved synthetic VPN tier for portfolio validation; obtain a real change window only if this becomes a customer deployment.
4. Retain DMS all-outbound SG egress with tightly scoped peer ingress, or document and test a supported exception.
5. Validate current MGN regional endpoints and preserve the no-SSL-inspection requirement.
6. Supply the external ACM certificate ARN, exact RDS engine version, DMS source secret and benchmark-selected DMS class when enabling those layers.
7. Activate the DataSync appliance with the dedicated endpoint subnet/SG outputs and supply its ARN, NFS hostname and export.
8. Identify archive source only if an archive transfer task is to be configured; the private S3 target is already modelled.
9. Keep DNS/NTP/NACL defaults for the synthetic case unless a named dependency requires an extension.

Use the synthetic values for Terraform validation, plan review and portfolio testing. If the case study is ever converted into a real customer engagement, replace the fictional values with evidence. Any live AWS apply still requires explicit user permission and a verified account/region.

## 7. AWS references reviewed

- [AWS DMS — Setting up a network for a replication instance](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_ReplicationInstance.VPC.html)
- [AWS MGN — Network requirements](https://docs.aws.amazon.com/mgn/latest/ug/preparing-environments.html)
- [AWS DataSync — Network requirements](https://docs.aws.amazon.com/datasync/latest/userguide/datasync-network.html)
- [AWS DataSync — Choosing a service endpoint](https://docs.aws.amazon.com/datasync/latest/userguide/choose-service-endpoint.html)
- [AWS DataSync — Network traffic flows](https://docs.aws.amazon.com/datasync/latest/userguide/networking-datasync.html)
- [AWS Site-to-Site VPN — Redundant connections for failover](https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-redundant-connection.html)
- [AWS Networking Best Practices — Hybrid and multi-cloud connectivity](https://aws.github.io/aws-networking-best-practices/connectivity/hybrid-multicloud/)
- [AWS Site-to-Site VPN — Route priority and tunnel selection](https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-route-priority.html)

**Review record:** synthetic values are approved for repository engineering, CI validation and portfolio demonstration. Actual customer inputs are not blockers in this fictional case. Live AWS execution still requires account-specific IDs, agent/source credentials, approved change scope and explicit user permission. No AWS resource deployment or network validation is claimed.
