# 02 — Target Architecture and Design Decisions

**ID:** CLI-AWS-ARC-002 | **Version:** 1.2 | **Status:** Proposed, not deployed

## Architecture diagrams

- [Canonical master architecture](../architecture/target-architecture.md)
- [Focused runtime and network view](../architecture/runtime-network-view.md)
- [Focused migration data-flow view](../architecture/migration-data-flow.md)

The focused diagrams are review companions; this document remains the decision record for the proposed design.

## Objectives

Design a two-AZ AWS target with public entry, private application tier, isolated database tier, shared file storage, archives, hybrid migration connectivity and monitoring.

## Region and VPC

- Region: `us-east-1`.
- VPC: `10.30.0.0/16`; DNS support and hostnames enabled.
- Two AZs; actual AZ IDs selected at deployment.
- Internet Gateway attached.
- Site-to-Site VPN via VGW; Transit Gateway is not assumed.
- Six steady-state subnets as listed below. AWS Application Migration Service (MGN) also requires a staging-area subnet for replication servers. Allocate a separate private migration-only subnet/CIDR (or explicitly reserve a suitable dedicated subnet); it is additional to the six steady-state subnets and must be included in final IP, routing and cost design.

| Tier | AZ-A | AZ-B |
|---|---|---|
| Public | `10.30.1.0/24` | `10.30.2.0/24` |
| App | `10.30.11.0/24` | `10.30.12.0/24` |
| DB | `10.30.21.0/24` | `10.30.22.0/24` |

VPC endpoints may reside in appropriate private subnets; dedicated endpoint subnets are optional and are not part of the six-subnet baseline.

## Migration-service placement

- **MGN:** use the dedicated private staging-area subnet in the selected AZ. Source agents send replication traffic to staging replication servers over TCP 1500; source agents and staging servers also require their documented regional MGN service connectivity over TCP 443. Give the staging subnet a controlled same-AZ egress path (for example, its same-AZ NAT Gateway) unless a validated private endpoint design is selected. The MGN staging subnet is not an application subnet or a DMS subnet.
- **DMS:** place the replication instance or Serverless replication in this VPC, using a replication subnet group that spans private subnets in at least two AZs. The current baseline uses the two private application subnets for that subnet group, with a dedicated DMS security group and explicit database-port rules. This reuses existing CIDRs; it does not create an eighth subnet. Confirm that the selected subnet/route design and DMS endpoint connectivity pass before migration.
- **DataSync:** for the on-premises NFS source, deploy a supported DataSync agent VM close to the source storage. The agent mounts NFS using the required NFS ports and connects to a selected public or VPC service endpoint. DataSync service-side connectivity to EFS uses TCP 2049; S3 access is service-side. For EFS, DataSync creates task network interfaces in a selected subnet in the same VPC and an AZ containing an EFS mount target; use a dedicated task-ENI security group with TCP 2049 access to the mount-target security group. The archive source location/type remains unknown, so its agent requirement and flow must be confirmed separately.

## Compute and application

Two EC2 application instances, one per AZ, are managed by an Auto Scaling Group spanning both private app subnets (initial desired/minimum capacity 2; scaling policy and maximum capacity set after workload discovery). `t3.xlarge` is a pricing proxy, not a final production recommendation; T3 is burstable and sustained CPU may require another family. Instances are private. Public entry is through an internet-facing ALB in at least two public subnets on HTTPS 443. Provision an ACM certificate and Route 53 alias (if Route 53 hosts the zone); DNS and certificate are implementation requirements omitted from the cost baseline. App listener TCP 8080 is provisional and must be discovered. Configure ALB health checks against an application readiness endpoint; do not rely solely on EC2 instance status. No public SSH; use Systems Manager where supported.

## Database and storage

- RDS for PostgreSQL, Multi-AZ DB instance deployment with one standby (not a Multi-AZ DB cluster). The source discovery assumption is 500 GB logical data; the current Calculator entry separately uses 500 GB of target gp3 provisioned storage. Validate actual used bytes, growth and headroom before finalising target storage.
- Source DB sizing assumption is 8 vCPU / 32 GiB; target class remains subject to benchmark and compatibility.
- RDS DB subnet group spans both isolated DB subnets.
- Cost model includes primary and standby instance-hours and provisioned storage copies.
- Regional EFS for 1 TB shared-file assumption, with a mount target in each application AZ. EFS mount target SG permits inbound TCP 2049 from the application SG.
- S3 Standard for 500 GB archive pricing assumption, accessed privately through an S3 Gateway Endpoint where appropriate.
- EFS throughput, lifecycle tiers and S3 retention/storage class require discovery.

## Routing and egress

- Public subnets: default route to IGW.
- App subnets: same-AZ NAT Gateway default route.
- DB subnets: local routes only, plus explicitly required private endpoints.
- S3 Gateway Endpoint for appropriate S3 access.
- Interface endpoints only where justified.
- External APIs over HTTPS; security groups are not general FQDN filters.

## Availability and trade-offs

Two application instances managed by an Auto Scaling Group, ALB, Multi-AZ RDS, Regional EFS and two NAT Gateways form the production-oriented two-AZ baseline. They do not prove 99.9% end-to-end availability; application failover, dependencies and recovery must be tested.

Two NAT Gateways cost more but avoid a single-AZ NAT dependency and reduce cross-AZ egress. Retain two in the baseline; a one-NAT alternative requires explicit acceptance of reduced resilience.

## Open decisions

Confirm app port/OS, EC2 family and ASG scaling thresholds, RDS version/class/storage/IOPS, NFS semantics/EFS throughput, MGN staging subnet CIDR/route/security, source CIDRs/VPN routing, API allowlists, Route 53 ownership, certificate domain validation, retention and workload thresholds.

**Status:** Proposed architecture; no infrastructure deployed or load-tested.
