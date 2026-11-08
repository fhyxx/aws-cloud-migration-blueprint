# 10 — Technical Architecture Audit

**ID:** CLI-AWS-AUD-010 | **Version:** 1.0 | **Status:** In progress — design corrections published; operational and visual acceptance pending  
**Project:** Clafoke Investors Ltd (fictional, design-only)  
**Audit date:** 2026-11-08

## Executive assessment

The blueprint has a coherent two-AZ target pattern and a defensible separation between steady-state cost and migration-period cost. The review identified gaps in migration-service network placement and traffic paths. Those design gaps have been corrected in the canonical diagram and supporting network, architecture, runbook and readiness documents.

The design is **not yet approved for implementation**. Source compatibility, network routes, exact service configuration, workload benchmarks, backup policy, monitoring thresholds, recovery tests and visual diagram review remain open. No AWS resources or migration services have been deployed.

## Scope reviewed

- Discovery, target architecture, network/security, data migration, runbook, validation/rollback and cost documents.
- Canonical diagram `architecture/target-architecture.mmd`.
- `cost/pricing-assumptions.csv`, `README.md`, `DESIGN-CONSISTENCY.md` and migration readiness matrix.
- Current AWS service documentation for DMS VPC placement, MGN network requirements and DataSync network/EFS access.

## Findings and corrections

| ID | Finding | Correction / current disposition | Remaining evidence |
|---|---|---|---|
| AUD-01 | DMS was drawn outside the VPC and its replication subnet group/security boundary was not explicit. | Diagram now places DMS replication in the VPC, using private application subnets across two AZs and a dedicated DMS security group. Source and target TCP 5432 paths are documented. | Create/validate subnet group, routes, endpoint rules and source/target connectivity. |
| AUD-02 | DataSync's on-premises NFS agent and EFS task data-plane network interfaces were not shown. | Diagram and network/runbook now distinguish the on-premises agent, service endpoint and DataSync task ENI to EFS path. | Select task mode, endpoint type, agent host and EFS task-ENI subnet/SG; test transfer. |
| AUD-03 | Archive source location/type and therefore agent requirement were unknown. | Kept explicitly unresolved; no invented source quantity or network path. | Inventory archive source, eligible bytes, objects/files, permissions and source-specific connectivity. |
| AUD-04 | MGN staging server service egress was not explicit in the diagram. | Diagram and network design now show controlled TCP 443 egress from staging to the regional MGN service; source-to-staging TCP 1500 remains a separate VPN path. | Confirm AZ, route table, same-AZ NAT/private endpoint design and source CIDRs. |
| AUD-05 | Source logical database size and target RDS provisioned storage could be read as the same measured quantity. | README and architecture register now distinguish the 500 GB source logical-data assumption from the separate 500 GB target gp3 Calculator input. | Measure source used bytes, growth and required storage headroom. |
| AUD-06 | Monitoring, health-check, scaling and recovery targets lacked measurable acceptance criteria. | Provisional monitoring/health/scaling and timed recovery acceptance criteria are now specified in [Validation and Rollback](06-validation-rollback-strategy.md). | Confirm app readiness path, load-test thresholds, backup policy and execute recovery tests. |
| AUD-07 | Saved monthly estimate could be mistaken for a complete architecture cost. | README and cost guide explicitly call $1,930.76/month a partial calculator subtotal, not an approved budget. | Add/verify ALB, monitoring, DNS, data transfer, backup, endpoints and migration-period costs after inputs are known. |

## RDS calculator reconciliation

The saved calculator configuration is PostgreSQL `db.m6i.2xlarge`, Multi-AZ DB instance deployment, 500 GB gp3 storage input, 12,000 IOPS, 500 MiB/s throughput and Database Insights. The saved line items reconcile as follows:

| Component | Calculator input / arithmetic | Monthly |
|---|---:|---:|
| Multi-AZ compute | $1.424 per configured Multi-AZ DB-hour × 730 hours | $1,039.52 |
| gp3 provisioned storage | 500 GB × $0.23 per GB-month | $115.00 |
| Database Insights | 8 vCPU × 730 hours × $0.0125 per vCPU-hour | $73.00 |
| **RDS subtotal** | **Saved calculator result** | **$1,227.52** |

The Multi-AZ hourly/storage rates are the selected calculator rates; do not manually add a second copy on top of these rates. AWS documents that Multi-AZ DB instance deployments bill compute and provisioned storage for both primary and standby. The current $1,227.52 RDS line is internally consistent with the saved calculator breakdown. It remains a sizing proxy, not proof that the target class, storage, IOPS or throughput suits the workload.

The overall saved estimate remains **$1,930.76/month** and **$23,169.12 annualised**. It is a partial six-service subtotal; ALB, Route 53, CloudWatch, several usage meters, backups, interface endpoints and migration-period resources remain excluded or unpriced. Do not present it as a full monthly bill or first-year forecast.

## Operational baseline and acceptance

The proposed starting thresholds and recovery tests are documented in `docs/06-validation-rollback-strategy.md`. They are design proposals only. The app team must confirm the readiness endpoint and startup behaviour; representative load testing must validate CPU, memory, latency, connection and throughput thresholds. The Business Owner must approve backup retention and recovery objectives. RTO/RPO are not achieved until timed restore/failover tests and business transaction checks pass.

## Outstanding gates

1. Capture exact source OS/kernel/disk profiles for both MGN servers and validate against the current MGN support matrix.
2. Capture PostgreSQL source version/patch, choose exact RDS target version and DMS engine, then validate the live DMS compatibility matrix.
3. Approve DMS source permissions, WAL/slot/sender headroom, primary-key/replica-identity handling, schema/object migration method and benchmark.
4. Inventory NFS used bytes/file counts and archive source bytes/object counts; choose DataSync mode, agent and endpoint design.
5. Approve VPN CIDRs/routes, MGN staging AZ/egress, DMS routes/SGs, DataSync task-ENI subnet/SG, DNS ownership and API allowlists.
6. Confirm application readiness endpoint, health-check behaviour, EC2 family, ASG maximum/scaling, RDS performance, backup retention and log retention.
7. Execute load, AZ/failover, database restore, EFS restore, S3 recovery and end-to-end application tests; retain dated evidence.
8. Complete migration-period cost modelling from measured source profiles, benchmarks, network flows and approved dates.
9. Visually inspect the rendered Mermaid diagram and reconcile it with all architecture/network/runbook descriptions.

## AWS service references

- [Amazon RDS Multi-AZ DB instance billing](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_OnDemandDBInstances.html)
- [AWS DMS replication VPC and subnet-group requirements](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_ReplicationInstance.VPC.html)
- [AWS Application Migration Service network requirements](https://docs.aws.amazon.com/pdfs/mgn/latest/ug/user-guide.pdf)
- [AWS DataSync network requirements](https://docs.aws.amazon.com/datasync/latest/userguide/datasync-network.html)
- [AWS DataSync access to EFS and task network interfaces](https://docs.aws.amazon.com/datasync/latest/userguide/create-efs-location.html)

## Audit decision

**Conditionally coherent design; not implementation-ready.** Migration readiness rows remain Pending Validation. No production deployment, migration, cutover, rollback, performance test or recovery test is claimed.