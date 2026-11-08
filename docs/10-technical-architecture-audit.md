# 10 — Technical Architecture Audit

**ID:** CLI-AWS-AUD-010 | **Version:** 1.3 | **Status:** In progress — endpoint decision inventory documented; implementation validation pending  
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
| AUD-08 | The first focused runtime diagram placed the ALB node outside the VPC boundary, which could imply incorrect network placement. | Corrected the rendered and source Mermaid so the ALB is inside the VPC and explicitly attached to both public subnets. Both focused diagrams were visually confirmed rendering in GitHub. | Recheck the corrected runtime rendering; implementation subnet associations, routes and security groups remain untested. |
| AUD-09 | Route-table intent was described narratively but not specified per subnet, and the master diagram implied a VGW route to isolated DB subnets. | Added a route-table baseline for public, app, DB, MGN staging and S3 endpoint associations; removed the unsupported baseline VGW-to-DB route; clarified specific on-premises routes and return routing. | Confirm actual subnet associations, on-premises CIDRs, route propagation/static route mode, customer-gateway return routes and MGN staging CIDR/AZ. |
| AUD-10 | Security-group direction and subnet-level return-path controls were too broad to validate consistently. | Added source/destination SG intent, health-check dependency, DMS temporary ingress, DataSync task-ENI/EFS path and stateful SG versus stateless NACL guidance. | Validate exact app/health-check port, DBA access path, egress dependencies and any custom NACL ephemeral-port rules. |
| AUD-11 | Private service access was listed as a generic endpoint candidate set without a workload-by-workload decision, risking unnecessary endpoints and missing endpoint dependencies. | Added a conditional VPC endpoint inventory separating S3 Gateway, SSM/ssmmessages, Secrets Manager, CloudWatch Logs/Monitoring and future ECR/KMS/STS use cases. Clarified endpoint AZ coverage, SG, private DNS, policy and pricing requirements. | Confirm workload API calls, SSM Agent version, NAT-vs-PrivateLink decision, endpoint subnet/AZ count, endpoint policies, DNS resolution and reachability; update cost model only after scope is approved. |

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
5. Approve VPN CIDRs/routes, MGN staging AZ/egress, DMS routes/SGs, DataSync task-ENI subnet/SG, workload-driven VPC endpoint inventory, DNS ownership and API allowlists.
6. Confirm application readiness endpoint, health-check behaviour, EC2 family, ASG maximum/scaling, RDS performance, backup retention and log retention.
7. Execute load, AZ/failover, database restore, EFS restore, S3 recovery and end-to-end application tests; retain dated evidence.
8. Complete migration-period cost modelling from measured source profiles, benchmarks, network flows and approved dates.
9. GitHub rendering of the master and both focused diagrams has been visually confirmed from user screenshots. The runtime view now depicts ALB nodes in both public subnets. Review the updated diagram rendering after the latest subnet-node change.
10. Validate route-table associations, source/return VPN routes, SG rule directions, NACL return traffic, S3 endpoint association and IP capacity before implementation.

## AWS service references

- [Amazon RDS Multi-AZ DB instance billing](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_OnDemandDBInstances.html)
- [AWS DMS replication VPC and subnet-group requirements](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_ReplicationInstance.VPC.html)
- [AWS Application Migration Service network requirements](https://docs.aws.amazon.com/pdfs/mgn/latest/ug/user-guide.pdf)
- [AWS DataSync network requirements](https://docs.aws.amazon.com/datasync/latest/userguide/datasync-network.html)
- [AWS DataSync access to EFS and task network interfaces](https://docs.aws.amazon.com/datasync/latest/userguide/create-efs-location.html)
- [VPC subnet sizing](https://docs.aws.amazon.com/vpc/latest/userguide/subnet-sizing.html)
- [Application Load Balancer subnet requirements](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/application-load-balancers.html)
- [VPC route tables](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
- [Site-to-Site VPN routing](https://docs.aws.amazon.com/vpn/latest/s2svpn/SetUpVPNConnections.html)
- [Security groups](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html)
- [Network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html)
- [S3 Gateway Endpoint routing](https://docs.aws.amazon.com/vpc/latest/privatelink/gateway-endpoints.html)
- [Systems Manager endpoint and agent messaging requirements](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up-messageAPIs.html)
- [Systems Manager VPC endpoint troubleshooting](https://docs.aws.amazon.com/systems-manager/latest/userguide/troubleshooting-ssm-agent.html)
- [Secrets Manager VPC endpoint](https://docs.aws.amazon.com/secretsmanager/latest/userguide/vpc-endpoint-overview.html)
- [CloudWatch Monitoring VPC endpoint](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch-and-interface-VPC.html)
- [CloudWatch Logs VPC endpoint](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/cloudwatch-logs-and-interface-VPC.html)
- [ECR VPC endpoints and S3 image-layer access](https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html)

## Audit decision

**Conditionally coherent design; not implementation-ready.** Migration readiness rows remain Pending Validation. No production deployment, migration, cutover, rollback, performance test or recovery test is claimed.