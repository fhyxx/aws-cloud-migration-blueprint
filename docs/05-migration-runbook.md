# 05 — Migration Runbook

**ID:** CLI-AWS-RUN-005 | **Version:** 1.3 | **Status:** Proposed, not executed — readiness evidence pending

## Roles

Migration Lead (coordination/go-no-go); AWS Solutions Architect (architecture/network/IAM); Infrastructure Lead (servers/MGN/VPN); DBA (PostgreSQL/DMS/reconciliation); Application Lead (application/integrations); Security Lead (controls); Operations Lead (monitoring/handover); Business Owner (maintenance and acceptance).

## Phase 0 — Governance

Appoint owners, approve scope/change/maintenance window, communications, escalation and rollback authority. Exit: approvals recorded.

## Phase 1 — Source readiness

Inventory OS, packages, runtime, ports, services, jobs, database version/extensions/logging/backups, NFS paths/permissions/locking and API/session/queue dependencies. For PostgreSQL, capture SELECT version() and SHOW server_version, identify the intended RDS target major/minor and DMS engine version, then verify the current AWS DMS source/target support matrix. Confirm replication permissions, wal_level=logical, max_replication_slots, max_wal_senders, WAL generation/retention and disk headroom, long-running transactions, primary keys/replica identity, extension/object inventory and acceptable CDC latency. Exit: critical gaps have owners and the DBA has documented source readiness; stop if compatibility, recovery or dependencies are unknown.

## Phase 2 — AWS readiness

Validate VPC `10.30.0.0/16`, six steady-state subnets/two AZs, additional private MGN staging subnet, dedicated DMS migration subnets `10.30.41.0/24` and `10.30.42.0/24` across two AZs with route propagation limited to those subnets and MGN staging, IGW, two NAT Gateways, VGW VPN, ALB, ACM certificate, DNS, private EC2, isolated RDS, EFS mount targets in both app AZs, S3 Gateway Endpoint, IAM, Secrets Manager, Systems Manager, endpoints, encryption and CloudWatch. Confirm DMS source/target TCP 5432 paths and the DataSync agent/service/EFS paths. Exit: infrastructure/security approval.

## Phase 3 — MGN

Check source OS/kernel/disk compatibility; create/identify dedicated staging-area subnet; configure MGN replication settings, IAM and network/security paths; install agents; monitor replication lag and staging capacity; configure private launch settings; test launch in isolation; validate boot, services, app dependencies and admin access. Exit: both test launches approved. Confirm staging resources and temporary costs are understood.

## Phase 4 — DMS

Before creating a task, satisfy the DMS gates in [Data Migration Strategy](04-data-migration-strategy.md) and [Migration Readiness Matrix](09-migration-readiness-matrix.md): exact source/target/DMS version compatibility, approved schema/object method, source permissions and logical-WAL readiness, key/replica-identity review, and a benchmark-supported capacity/runtime plan. Create/validate the DMS replication subnet group using only dedicated DMS-A/DMS-B migration subnets and dedicated DMS security group; propagate the on-premises source route only into those DMS route tables; permit on-premises TCP 5432 only from the DMS subnet CIDRs, and target TCP 5432 only from the DMS security group; prepare encrypted Multi-AZ RDS; configure endpoints and task; run full load; review errors, validation and referential integrity; enable CDC; monitor lag, replication slots and WAL retention; reconcile schema, critical rows, grants and permissions. After CDC stops, reconcile PostgreSQL sequence values because DMS does not synchronize sequence state during ongoing replication. DBA signs off on trigger/foreign-key handling and final sequence state. Exit: DBA sign-off.

## Phase 5 — DataSync

Before execution, deploy/activate the selected DataSync agent near the on-premises NFS source, validate agent-to-NFS ports and agent-to-service endpoint connectivity, and test the DataSync task ENI-to-EFS TCP 2049 path using a dedicated task-ENI security group and a subnet/AZ compatible with an EFS mount target. Confirm the archive source type and whether it needs a separate agent. Obtain measured NFS used bytes/file counts and archive eligible bytes/object counts. The discovery's approximately 1 TB NFS is a planning assumption; 500 GB S3 describes target storage, not archive source volume. Record exclusions, access/ownership, open writers, change rate, task mode/agent count, route, bandwidth window and expected run time. Execute initial NFS and archive transfers early; retain task reports, bytes/files transferred/skipped/failed and verification outcome; reconcile source and destination, permissions/locking and application access. Set the final-sync trigger to confirmed writer/job freeze. Run and validate the final sync under the approved maintenance window; exact runtime and final delta are currently unknown.

## Phase 6 — Integrated tests

Test login, order creation/retrieval/update, payment/delivery test APIs, DB connectivity, EFS access, ALB target health, logs, monitoring and admin access. Exit: critical tests pass.

## Phase 7 — Cutover

1. Announce approved maintenance.
2. Stop source order creation and background writers.
3. Confirm source DB and file writes stopped.
4. Start final DataSync transfer after writers/jobs stop; verify completion, exceptions, counts and destination data.
5. Complete DMS CDC catch-up; verify agreed lag and no task errors. DataSync and DMS are independent gates; maintenance-window plan must assign sequencing/concurrency and allow both to finish before approval.
6. Reconcile critical orders and financial records; reconcile sequences and grants.
7. Configure target app with RDS/EFS/secrets.
8. Smoke test.
9. Migration Lead and Business Owner go/no-go.
10. Switch traffic to ALB.
11. Monitor application/database/ALB/logs/business transactions.
12. Obtain business acceptance.

GO only when data, application, security, monitoring and approvals pass. Otherwise NO-GO.

## Phase 8 — Rollback

Before AWS writes: isolate target, verify source consistency, restore source route/services, resume writers in controlled order and validate. After AWS writes: freeze writes, preserve logs, establish transaction set, assess reverse replication/reconciliation, obtain DBA and Business Owner approval. Do not use DNS reversal alone.

## Phase 9 — Stabilisation

Monitor EC2/RDS/EFS/ALB/CloudWatch/security; validate backups; reconcile transactions; resolve incidents; hand over operations. Five business days is a stabilisation planning assumption, not a DataSync duration or approved migration calendar. Initial DataSync, final sync, DBA catch-up, cutover, rollback and source retirement dates/hours need explicit approval. Source retirement is a separate approval.

## Evidence register

RUN-001 change approval; 002 source inventory; 003 AWS readiness; 004 VPN; 005 MGN replication; 006 test launch; 007 DMS full load; 008 CDC; 009 DB reconciliation; 010 initial DataSync; 011 final EFS sync; 012 S3 validation; 013 application tests; 014 security; 015 go/no-go; 016 traffic switch; 017 monitoring; 018 business acceptance; 019 recovery; 020 closure.

Illustrative commands only:

```bash
aws sts get-caller-identity
aws mgn describe-source-servers --region <AWS_REGION>
aws dms describe-replication-tasks --region <AWS_REGION>
aws rds describe-db-instances --region <AWS_REGION>
```

Replace placeholders, verify account/Region, never put secrets in shell history. No destructive action without separate approval.

**Status:** Proposed runbook; no execution occurred. Migration readiness evidence is tracked in [Migration Readiness Matrix](09-migration-readiness-matrix.md); all MGN, DMS, DataSync, temporary network and schedule gates remain Pending Validation until evidence and approvals are recorded.
