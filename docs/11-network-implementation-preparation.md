# 11 — Network Implementation Preparation Pack

**ID:** CLI-AWS-NIP-011 | **Version:** 1.0 | **Status:** Prepared for implementation review — not deployed  
**Project:** Clafoke Investors Ltd (fictional portfolio case study)  
**Related:** [Network and security design](03-network-security-design.md), [Migration runbook](05-migration-runbook.md), [Migration readiness matrix](09-migration-readiness-matrix.md), [Technical architecture audit](10-technical-architecture-audit.md), [Network configuration specification](13-network-configuration-specification.md)

> This is an implementation-preparation artifact, not an approved change plan. CIDRs, ASNs and topology remain illustrative until reconciled with actual customer network facts and approved by accountable owners. No AWS resources, VPN tunnels, routes, security rules or connectivity tests have been created or executed.

## 1. Purpose and boundary

Translate the proposed network into a reviewable build specification and evidence plan:

1. Subnet/AZ and route-table associations.
2. Security-group and source-firewall rule inventory.
3. Customer Gateway, VGW, BGP and two-tunnel preparation.
4. Ordered build and validation sequence.
5. Read-only AWS CLI inspection commands.
6. Positive, negative, failover and recovery tests.
7. Evidence capture and go/no-go gates.

**Not included:** Terraform/CloudFormation deployment, AWS resource creation, route propagation changes, firewall changes, VPN configuration import, secret exchange, tunnel reset, failover execution or production traffic changes. These require a separately approved implementation change.

## 2. Inputs required before implementation

| Input | Current reference | Required confirmation / owner |
|---|---|---|
| AWS account / Region | Portfolio account / us-east-1 | Confirm intended account, Region and change owner |
| VPC CIDR | 10.30.0.0/16 | Confirm allocation and no overlap with connected networks |
| Source aggregate | 10.50.0.0/16 | Replace with actual routed source prefixes; customer Network Lead |
| Source app subnet | 10.50.10.0/24 | Confirm source VM addresses and MGN source scope |
| Source DB/NFS subnet | 10.50.20.0/24 | Confirm PostgreSQL/NFS addresses and host firewall |
| Customer Gateway | BGP-capable edge with static public outside IP | Confirm vendor/model/firmware, HA, NAT-T and configuration owner |
| Customer / VGW ASN | 65010 / 64512 | Confirm uniqueness, availability and BGP policy |
| AWS AZ placement | AZ-A / AZ-B labels | Resolve actual account-specific AZ IDs |
| Application listener | TCP 8080 provisional | Application Lead confirms listener and health-check port/path |
| DMS source/target | TCP 5432 | DBA confirms endpoint, TLS/authentication and host policy |
| MGN | TCP 1500 replication; TCP 443 service | Validate current regional MGN network requirements |
| DataSync | NFSv4 TCP 2049; NFSv3 TCP 111 + 2049 | Confirm NFS version, task mode, agent and endpoint type |
| DNS/NTP/egress | Not fully specified | Identify resolvers, time sources, proxy/inspection and service FQDN allow-lists |
| NACL posture | Default NACL baseline | Security Lead decides whether custom stateless controls are needed |
| Endpoint inventory | S3 Gateway; interface endpoints conditional | Confirm API dependencies, endpoint AZs, private DNS and policies |

Do not build from illustrative source CIDRs or ASNs until the customer Network Lead signs the overlap and routing review. Never commit real public IPs, pre-shared keys, BGP passwords, customer names or sensitive topology to this public repository.

## 3. Subnet and route-table association specification

### 3.1 Subnet inventory

AZ-A and AZ-B are logical labels. Implementation must record the actual AZ IDs for the selected AWS account.

| Subnet | CIDR | AZ | Route table | Role |
|---|---|---|---|---|
| Public-A | 10.30.1.0/24 | AZ-A | RT-PUBLIC-A | ALB node / NAT-A |
| Public-B | 10.30.2.0/24 | AZ-B | RT-PUBLIC-B | ALB node / NAT-B |
| App-A | 10.30.11.0/24 | AZ-A | RT-APP-A | Private application EC2 |
| App-B | 10.30.12.0/24 | AZ-B | RT-APP-B | Private application EC2 |
| DB-A | 10.30.21.0/24 | AZ-A | RT-DB-A | RDS subnet group |
| DB-B | 10.30.22.0/24 | AZ-B | RT-DB-B | RDS subnet group |
| MGN-STAGING | 10.30.31.0/24 | AZ-A provisional | RT-MGN-STAGING | MGN replication servers |
| DMS-A | 10.30.41.0/24 | AZ-A | RT-DMS-A | DMS replication ENIs |
| DMS-B | 10.30.42.0/24 | AZ-B | RT-DMS-B | DMS replication ENIs |
| DataSync endpoint | 10.30.51.0/24 | AZ-A | RT-DATASYNC-ENDPOINT | DataSync VPC service endpoint ENI |
| DataSync task | 10.30.52.0/24 | AZ-A | RT-DATASYNC-TASK | DataSync task ENIs; same AZ as EFS mount target A |

A /24 has 251 initially assignable IPv4 addresses after AWS reserves five. This is not a capacity guarantee. The scenario now has six steady-state subnets and five migration-only subnets. Capture available IP counts before and during deployment, especially in public, DMS and MGN staging subnets.

### 3.2 Route-table routes and associations

| Route table | Associated subnet | Required routes | VGW propagation |
|---|---|---|---|
| RT-PUBLIC-A | Public-A | VPC local; 0.0.0.0/0 → IGW | Disabled |
| RT-PUBLIC-B | Public-B | VPC local; 0.0.0.0/0 → IGW | Disabled |
| RT-APP-A | App-A | VPC local; 0.0.0.0/0 → NAT-A; S3 regional prefix list → S3 Gateway Endpoint | Disabled |
| RT-APP-B | App-B | VPC local; 0.0.0.0/0 → NAT-B; S3 regional prefix list → S3 Gateway Endpoint | Disabled |
| RT-DB-A | DB-A | VPC local only | Disabled |
| RT-DB-B | DB-B | VPC local only | Disabled |
| RT-DMS-A | DMS-A | VPC local; propagated 10.50.0.0/16 → VGW; 0.0.0.0/0 → NAT-A; S3 prefix list only if required | Enabled |
| RT-DMS-B | DMS-B | VPC local; propagated 10.50.0.0/16 → VGW; 0.0.0.0/0 → NAT-B; S3 prefix list only if required | Enabled |
| RT-MGN-STAGING | MGN-STAGING | VPC local; propagated 10.50.0.0/16 → VGW; 0.0.0.0/0 → NAT-A | Enabled |
| RT-DATASYNC-ENDPOINT | DataSync endpoint | VPC local; propagated 10.50.0.0/16 → VGW; no default route | Enabled |
| RT-DATASYNC-TASK | DataSync task | VPC local; propagated 10.50.0.0/16 → VGW; no default route | Enabled |

**Isolation invariant:** only RT-DMS-A, RT-DMS-B, RT-MGN-STAGING, RT-DATASYNC-ENDPOINT and RT-DATASYNC-TASK receive the source aggregate route. App, public and DB route tables must not receive 10.50.0.0/16. Do not enable propagation on the main route table as a shortcut. If the real source has multiple prefixes, document and approve each prefix and its route scope.

S3 Gateway Endpoint routes are prefix-list routes attached to selected route tables. They are not interface endpoints and have no security-group attachment. Apply endpoint, IAM, bucket and KMS policies independently.

### 3.3 Route validation criteria

- Every subnet has the intended route-table association; no unintended main-table fallback.
- All route tables contain the VPC local route.
- Only the five migration route tables have VGW propagation enabled.
- The source route is present in those five tables and absent from App, DB and Public tables.
- App default routes use their same-AZ NAT; DMS-A uses NAT-A; DMS-B uses NAT-B; MGN staging uses NAT-A; DataSync endpoint and task subnets have no default route.
- DB route tables have no default route, IGW, NAT or VGW route.
- S3 prefix-list routes exist only where approved.
- Customer-side routing has a return path to the VPC CIDR.
- Check route state (active/blackhole) and tunnel/BGP state. A propagated route alone is not a health signal.

## 4. Security-group and source-firewall rule inventory

These are rule intents, not deployed rules. Use security-group references for same-VPC peers where supported. Use CIDRs only for on-premises peers and approved client ranges. SGs are stateful; response traffic does not need a duplicate reverse SG rule.

| SG | Direction | Protocol / port | Peer | Purpose / note |
|---|---|---|---|---|
| SG-ALB | Inbound | TCP 443 | Approved client CIDRs TBD | Public HTTPS listener; exposure scope requires approval |
| SG-ALB | Inbound | TCP 80 | Approved client CIDRs TBD | Optional redirect only |
| SG-ALB | Outbound | TCP 8080 provisional | SG-APP | Target listener/health check; confirm actual port |
| SG-APP | Inbound | TCP 8080 provisional | SG-ALB | ALB-only application ingress |
| SG-APP | Outbound | TCP 5432 | SG-RDS | Application PostgreSQL |
| SG-APP | Outbound | TCP 2049 | SG-EFS | Application NFS |
| SG-APP | Outbound | TCP 443 | Approved endpoint SGs / documented services | Restrict to actual dependencies |
| SG-RDS | Inbound | TCP 5432 | SG-APP | Application database access |
| SG-RDS | Inbound | TCP 5432 | SG-DMS | Temporary migration-only rule; remove after DMS retirement |
| SG-EFS | Inbound | TCP 2049 | SG-APP | Application NFS |
| SG-EFS | Inbound | TCP 2049 | SG-DATASYNC-TASK-ENI | DataSync task ENI to EFS |
| SG-DMS | Outbound | TCP 5432 | 10.50.20.0/24 illustrative | DMS-initiated source PostgreSQL connection over VPN |
| SG-DMS | Outbound | TCP 5432 | SG-RDS | DMS-initiated target connection |
| SG-DMS | Outbound | TCP 443 | Required DMS service/logging endpoints | Confirm service dependencies and egress path |
| SG-DMS | Outbound | DNS TCP/UDP 53 | Approved resolver(s) | Only if required by resolver design |
| SG-MGN-STAGING | Inbound | TCP 1500 | 10.50.10.0/24 illustrative | MGN replication stream from approved source VMs only |
| SG-MGN-STAGING | Outbound | TCP 443 | Regional MGN service path and required AWS dependencies (including S3 where current service guidance requires) | Controlled NAT/private path; no SSL interception on documented MGN API paths |
| SG-DATASYNC-ENDPOINT | Inbound | TCP 1024–1064 | 10.50.20.50/32 | VPC service endpoint control-plane from the single synthetic DataSync agent |
| SG-DATASYNC-TASK-ENI | Inbound | TCP 443 | 10.50.20.50/32 | DataSync agent data-plane to task ENI |
| SG-DATASYNC-TASK-ENI | Outbound | TCP 2049 | SG-EFS | DataSync task data-plane to EFS |
| SG-ENDPOINT | Inbound | TCP 443 | Only workload SGs needing that endpoint | Define per interface endpoint |

Implementation notes:

- ALB target and health-check port/path must match the application. TCP 8080 and /health/ready remain provisional.
- SG-RDS must temporarily allow SG-DMS only during the migration window. Record its removal and verify afterward.
- DMS initiates connections to both PostgreSQL endpoints; no unsolicited DMS inbound is required.
- On-premises and host firewalls must allow TCP 5432 only from 10.30.41.0/24 and 10.30.42.0/24 to the actual PostgreSQL source.
- On-premises firewall must allow TCP 1500 only from approved MGN source VM addresses to the staging replication servers.
- Document DNS, NTP, proxy, certificate, SSM, logging and service dependencies from actual workload requirements. Do not add broad 0.0.0.0/0 egress as a substitute. Security groups cannot express FQDN-based egress allow-lists; where service destinations are dynamic, use an approved proxy, AWS Network Firewall or other egress-control design and document its routing, policy and cost. Interface endpoint SG references apply only to traffic using those endpoints.
- Custom NACLs are stateless and require explicit request and return paths. Retain default NACLs unless a documented requirement justifies custom rules.

See [Network Implementation Review](12-network-implementation-review.md) for the DMS egress, MGN TLS-inspection and DataSync endpoint findings that must be resolved before implementation.\n\n## 5. Customer Gateway, VGW and BGP preparation

### 5.1 Reference topology

| Parameter | Reference |
|---|---|
| Region / VPC | us-east-1 / 10.30.0.0/16 |
| VGW ASN | 64512 |
| Customer ASN | 65010 |
| Customer advertised prefix | 10.50.0.0/16 |
| AWS advertised prefix | 10.30.0.0/16 |
| VPN | One Site-to-Site VPN connection; two independent IPsec tunnels |
| Routing | Dynamic BGP |
| Intent | Redundancy/failover, not VGW ECMP or aggregate active-active throughput |

### 5.2 Customer network team inputs

- Customer Gateway vendor/model, firmware and validated AWS configuration template.
- Static public outside IP (exchange privately, never commit).
- Customer BGP ASN and confirmation it does not conflict with other connected networks.
- Source prefixes to advertise and prefixes accepted from AWS.
- BGP route filters, maximum-prefix guardrails and route preference policy.
- Supported IPsec/IKE capabilities and approved cryptographic settings.
- NAT-T and upstream firewall/ISP requirements.
- NAT placement, redundant pair/multiple WAN topology and ownership.
- Approved maintenance window, escalation contacts and rollback method.
- Confirmation of required firewall allow-lists and asymmetric return routing behaviour.

### 5.3 AWS-side preparation sequence

1. Confirm VPC, Region, account and AZ plan.
2. Confirm actual source CIDRs and no overlap with VPC or connected networks.
3. Select VGW ASN 64512 only after ASN review; attach VGW to the intended VPC.
4. Create the Customer Gateway from the customer-provided outside IP and approved ASN.
5. Create one dynamic-routing Site-to-Site VPN connection.
6. Retrieve the AWS-generated vendor configuration for the exact device/software version.
7. Exchange it securely. Never commit tunnel outside IPs, inside tunnel CIDRs, pre-shared keys or device secrets.
8. Configure both tunnels and BGP peers; confirm both established and only approved prefixes exchanged.
9. Enable route propagation only on RT-DMS-A, RT-DMS-B and RT-MGN-STAGING.
10. Confirm the customer device learns the VPC route and AWS migration route tables learn the approved source prefix.
11. Validate firewall allow-lists and end-to-end probes independently of route presence.

AWS VGW does not support ECMP. Two tunnels provide redundancy/failover, not combined active-active bandwidth. A VPN reporting UP or a propagated route remaining visible does not by itself prove end-to-end reachability. **Resilience limitation:** both tunnels in one VPN connection still terminate on one logical customer gateway/device path. This reference is a basic dual-tunnel design, not proof of site/ISP/device-level redundancy. For production-grade resilience, assess a second VPN connection terminating on a separate customer device and diverse ISP path; this changes routing, cost and operational scope and is not included in the current one-connection calculator assumption.

### 5.4 Tunnel failover test

Only execute in a separately approved non-production test window with both network teams present.

1. Capture baseline tunnel/BGP state, learned/advertised prefixes, route tables, packet counters and end-to-end TCP probes.
2. Confirm application subnets have no source route and DB subnets remain isolated.
3. Run low-impact TCP probes from approved DMS test source to PostgreSQL test listener and MGN source to staging TCP 1500.
4. With the customer Network Lead, deliberately disable/isolate one tunnel using the agreed device-specific method. Do not delete the VPN or alter both tunnels.
5. Observe BGP state, route selection, packet loss, recovery time and traffic on the surviving tunnel.
6. Restore the tunnel using the approved method; wait for BGP reconvergence and stable probes.
7. Repeat for the other tunnel only if the change plan explicitly authorises it.
8. Verify steady state and capture timestamps and VPN metrics.
9. Stop if the surviving tunnel, route policy or rollback path is unhealthy.

Set the acceptable interruption/recovery threshold with the customer before the test; measure actual results rather than claiming a universal failover time.

## 6. Ordered implementation sequence and gates

| Step | Work | Prerequisite | Exit evidence |
|---|---|---|---|
| 0 | Change record, owners, maintenance and rollback | Business Owner, Migration Lead, Security Lead | Approved change ID, scope and rollback authority |
| 1 | CIDR, ASN, AZ ID, account and Region validation | Customer Network Lead | Signed input sheet and overlap check |
| 2 | VPC/subnet build and IP review | Approved address plan | Subnet/AZ IDs and free-IP counts |
| 3 | Route tables and associations | Approved route matrix | Route export and propagation-scope proof |
| 4 | IGW/NAT/S3 Gateway Endpoint | Egress and cost approval | NAT AZ/EIPs, endpoint associations and policy |
| 5 | VGW/Customer Gateway/VPN | Network change approval | Both tunnel configs securely exchanged; BGP/prefix evidence |
| 6 | Security groups and source firewall | Security Lead and firewall owner | Rule inventory and no broad exposure |
| 7 | DMS subnet group/connectivity | DBA compatibility and source gates | DMS-A/B membership and source/target tests |
| 8 | MGN staging connectivity | MGN OS compatibility | TCP 1500/443 and staging capacity evidence |
| 9 | DataSync agent/task network | NFS version, endpoint mode and archive source known | Agent/service and task-ENI/EFS tests |
| 10 | Positive/negative security tests | Security test approval | NET-03 evidence package |
| 11 | VPN failover/recovery | Separate change approval and both teams | Measured test report and rollback confirmation |
| 12 | Independent review/handover | Required owners | Signed network readiness gate |

Stop if CIDRs overlap, ASN/device support is unresolved, route propagation leaks to non-migration route tables, customer return route is absent, or a rule requires broad access to make a test pass.

## 7. Read-only AWS CLI inspection commands (PowerShell)

For a later approved implementation session. These inspect state and do not create or modify resources. Confirm profile and Region first.

```powershell
$env:AWS_PROFILE = "portfolio"
$env:AWS_DEFAULT_REGION = "us-east-1"

aws sts get-caller-identity
aws configure get region --profile $env:AWS_PROFILE
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=clafoke-production-vpc" --output table
```

After confirming the intended VPC, set its ID locally:

```powershell
$VPC_ID = "<confirmed-vpc-id>"

aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].{SubnetId:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,AZId:AvailabilityZoneId,AvailableIPs:AvailableIpAddressCount,State:State}" --output table

aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[].{RouteTableId:RouteTableId,Associations:Associations[].SubnetId,PropagatingVGWs:PropagatingVgws[].GatewayId,Routes:Routes[].{Destination:DestinationCidrBlock,PrefixList:DestinationPrefixListId,Target:GatewayId,NAT:NatGatewayId,Endpoint:VpcEndpointId,State:State}}" --output json

aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName,Ingress:IpPermissions,Egress:IpPermissionsEgress}" --output json

aws ec2 describe-network-acls --filters "Name=vpc-id,Values=$VPC_ID" --output json

aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" --query "VpcEndpoints[].{Id:VpcEndpointId,Service:ServiceName,Type:VpcEndpointType,State:State,RouteTables:RouteTableIds,Subnets:SubnetIds,PrivateDNS:PrivateDnsEnabled}" --output json
```

VPN inspection after resources exist:

```powershell
aws ec2 describe-customer-gateways --output json
aws ec2 describe-vpn-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --output json
aws ec2 describe-vpn-connections --filters "Name=vpn-gateway-id,Values=<confirmed-vgw-id>" --output json
```

VPN output is sensitive: it may reveal public tunnel endpoints, customer topology and configuration metadata. Do not upload unredacted output to GitHub. Exact tunnel/BGP state also requires the approved AWS VPN monitoring view and customer device's read-only operational commands; syntax is vendor-specific.

**Command safety:** no create, modify, delete, route replacement, VGW propagation change, VPN reset or device-configuration command is included. Do not run implementation commands until the change record and explicit approval exist.

## 8. Validation test catalogue

| ID | Test | Expected result | Evidence |
|---|---|---|---|
| NET-P01 | Subnet CIDR/AZ/free-IP inspection | No overlap; approved AZ placement and headroom | Sanitised subnet inventory |
| NET-P02 | Subnet-to-route-table association | Each subnet uses its named table | Association export |
| NET-P03 | VGW propagation scope | Enabled only on DMS-A, DMS-B and MGN staging | Route and propagation export |
| NET-P04 | Source route presence | Source route only in migration tables; absent from App/Public/DB | Effective route exports |
| NET-P05 | DB isolation | Local route only; no NAT/IGW/VGW/default route | DB route export |
| NET-P06 | NAT and S3 routes | Correct same-AZ NAT; S3 prefix list only where approved | Route/endpoint export |
| NET-P07 | DMS to source PostgreSQL | DMS TCP 5432 succeeds; non-DMS source denied | DMS endpoint test and firewall log |
| NET-P08 | DMS to target RDS | TCP 5432 from DMS SG succeeds; other unapproved peers denied | Endpoint test and SG review |
| NET-P09 | App to RDS/EFS | Approved DB/NFS paths work; unrelated ingress denied | Connection tests and SG export |
| NET-P10 | App subnet to on-premises | No route and no successful direct source-network path | Route export and denied probe |
| NET-P11 | MGN source to staging | TCP 1500 only from approved source VM addresses | Probe, logs and MGN status |
| NET-P12 | MGN service access | Regional TCP 443 works via approved path | DNS/HTTPS test and egress logs |
| NET-P13 | DataSync agent to NFS | Correct NFS-version ports work; unrelated access denied | Agent/task logs and firewall evidence |
| NET-P14 | DataSync task ENI to EFS | TCP 2049 to selected same-AZ mount target | ENI subnet/AZ and EFS SG evidence |
| NET-P15 | VPN baseline | Both tunnels/BGP peers established; only approved prefixes exchanged | Sanitised VPN/BGP snapshot |
| NET-P16 | VPN failure/recovery | Surviving tunnel carries traffic; recovery meets agreed threshold | Timestamped probes and test report |
| NET-P17 | Temporary DMS ingress removal | SG-RDS no longer permits SG-DMS after retirement approval | Post-migration SG export |

Run negative tests only from authorised hosts and within an approved window. Pair a denied probe with route, SG, NACL and firewall evidence to identify the enforcing control.

## 9. Evidence register and redaction

| Evidence ID | Artifact | Minimum contents | Redaction |
|---|---|---|---|
| NIP-001 | Approved network input sheet | CIDRs, ASNs, AZ IDs, device model, owners, approval | Replace customer prefixes/IPs in public copy |
| NIP-002 | Subnet inventory | CIDR, AZ ID, free IP count, subnet IDs | Mask account/resource identifiers |
| NIP-003 | Route-table inventory | Associations, routes, VGW propagation | Mask IDs; retain destination/target class |
| NIP-004 | SG inventory | Rule direction, protocol/port and peer scope | Mask customer CIDRs/IDs as needed |
| NIP-005 | Customer firewall approval | PostgreSQL/MGN allow-lists and return routes | No customer names, public IPs or secrets |
| NIP-006 | VPN handoff record | Device version, config version and secure exchange date | Never include PSKs or generated config |
| NIP-007 | BGP/tunnel baseline | Tunnel/BGP states and advertised/learned prefixes | Mask public tunnel endpoints and customer details |
| NIP-008 | Positive/negative tests | Test ID, endpoint class, time, result and logs | Remove payloads, credentials and personal data |
| NIP-009 | Failover/recovery report | Approved window, tunnel event and measured recovery | Mask endpoint/customer identifiers |
| NIP-010 | Post-migration cleanup | Temporary DMS rule removed; temporary routes/resources reviewed | Mask IDs/account metadata |

Keep raw operational evidence in an approved private location. Commit only sanitised diagrams, summaries and evidence metadata to the public repository. Never commit credentials, CLI cache, .env files, VPN configuration, PSKs, private keys, customer public IPs, account IDs or raw security logs.

## 10. Network readiness go/no-go

Network implementation is not ready to start until all are true:

- [ ] Customer source CIDRs and connected-network overlaps are verified.
- [ ] Customer ASN, AWS ASN, device model/firmware and BGP/IPsec capabilities are confirmed.
- [ ] AWS account, Region and AZ IDs are confirmed.
- [ ] Subnet CIDRs, IP headroom and route-table associations are approved.
- [ ] Route propagation is limited to DMS-A, DMS-B and MGN staging.
- [ ] Customer return routes and firewall policies are approved.
- [ ] SG peers, app port, health-check path and service egress are confirmed.
- [ ] NACL posture and DNS/NTP/proxy dependencies are documented.
- [ ] DMS source/target compatibility and source-readiness gates pass before DMS connectivity work.
- [ ] MGN OS compatibility and service endpoint requirements pass before agent installation.
- [ ] DataSync source type, NFS version, task mode and endpoint design are confirmed.
- [ ] Cost/change approvals include NAT, VPN, migration and temporary resources.
- [ ] Positive/negative tests, failover threshold, rollback and evidence storage are approved.

All items are planning gates, not completed checkboxes. The reference design is specified for review and input collection, but remains **not approved for implementation** until missing customer facts and owner approvals are supplied.

## 11. AWS references

- [VPC route tables](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
- [Site-to-Site VPN routing options](https://docs.aws.amazon.com/vpn/latest/s2svpn/VPNRoutingTypes.html)
- [Site-to-Site VPN dynamic and static routing](https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-static-dynamic.html)
- [Site-to-Site VPN route priority and VGW ECMP limitation](https://docs.aws.amazon.com/vpn/latest/s2svpn/vpn-route-priority.html)
- [Site-to-Site VPN tunnel architecture](https://docs.aws.amazon.com/vpn/latest/s2svpn/how_it_works.html)
- [AWS networking best practices for hybrid connectivity](https://aws.github.io/aws-networking-best-practices/connectivity/hybrid-multicloud/)
- [Customer Gateway options](https://docs.aws.amazon.com/vpn/latest/s2svpn/cgw-options.html)
- [Security groups](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)
- [Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
- [DMS replication VPC and subnet-group requirements](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_ReplicationInstance.VPC.html)
- [MGN network requirements](https://docs.aws.amazon.com/pdfs/mgn/latest/ug/user-guide.pdf)
- [DataSync network requirements](https://docs.aws.amazon.com/datasync/latest/userguide/datasync-network.html)
- [DataSync EFS location and task network interfaces](https://docs.aws.amazon.com/datasync/latest/userguide/create-efs-location.html)

**Preparation decision:** network implementation package drafted; customer-specific inputs, approvals and live validation remain outstanding. No deployment or connectivity success is claimed.
