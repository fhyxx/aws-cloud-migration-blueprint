# 02 — Target Architecture and Design Decisions

**ID:** CLI-AWS-ARC-002 | **Version:** 1.0 | **Status:** Proposed, not deployed

## Objectives

Design a two-AZ AWS target with public entry, private application tier, isolated database tier, shared file storage, archives, hybrid migration connectivity and monitoring.

## Region and VPC

- Region: `us-east-1`.
- VPC: `10.30.0.0/16`; DNS support and hostnames enabled.
- Two AZs; actual AZ IDs selected at deployment.
- Internet Gateway attached.
- Site-to-Site VPN via VGW; Transit Gateway is not assumed.

| Tier | AZ-A | AZ-B |
|---|---|---|
| Public | `10.30.1.0/24` | `10.30.2.0/24` |
| App | `10.30.11.0/24` | `10.30.12.0/24` |
| DB | `10.30.21.0/24` | `10.30.22.0/24` |

VPC endpoints may reside in appropriate private subnets; dedicated endpoint subnets are optional and are not part of the six-subnet baseline.

## Compute and application

Two EC2 application instances, one per AZ, each initially assumed 4 vCPU / 16 GiB. `t3.xlarge` is a pricing proxy, not a final production recommendation; T3 is burstable and sustained CPU may require another family. Instances are private. Public entry is through an ALB on HTTPS 443. App listener TCP 8080 is provisional and must be discovered. No public SSH; use Systems Manager where supported.

## Database and storage

- RDS for PostgreSQL, Multi-AZ, with a 500 GB planning storage assumption.
- Source DB sizing assumption is 8 vCPU / 32 GiB; target class remains subject to benchmark and compatibility.
- RDS DB subnet group spans both isolated DB subnets.
- Regional EFS for 1 TB shared-file assumption.
- S3 Standard for 500 GB archive pricing assumption.
- EFS throughput, lifecycle tiers and S3 retention/storage class require discovery.

## Routing and egress

- Public subnets: default route to IGW.
- App subnets: same-AZ NAT Gateway default route.
- DB subnets: local routes only, plus explicitly required private endpoints.
- S3 Gateway Endpoint for appropriate S3 access.
- Interface endpoints only where justified.
- External APIs over HTTPS; security groups are not general FQDN filters.

## Availability and trade-offs

Two application instances, ALB, Multi-AZ RDS, Regional EFS and two NAT Gateways form the production-oriented two-AZ baseline. They do not prove 99.9% end-to-end availability; application failover, dependencies and recovery must be tested.

Two NAT Gateways cost more but avoid a single-AZ NAT dependency and reduce cross-AZ egress. Retain two in the baseline; a one-NAT alternative requires explicit acceptance of reduced resilience.

## Open decisions

Confirm app port/OS, EC2 family, RDS version/class/storage/IOPS, NFS semantics/EFS throughput, source CIDRs/VPN routing, API allowlists, retention and workload thresholds.

**Status:** Proposed architecture; no infrastructure deployed or load-tested.
