# 05 — Migration Runbook

**ID:** CLI-AWS-RUN-005 | **Version:** 1.1 | **Status:** Proposed, not executed

## Roles

Migration Lead (coordination/go-no-go); AWS Solutions Architect (architecture/network/IAM); Infrastructure Lead (servers/MGN/VPN); DBA (PostgreSQL/DMS/reconciliation); Application Lead (application/integrations); Security Lead (controls); Operations Lead (monitoring/handover); Business Owner (maintenance and acceptance).

## Phase 0 — Governance

Appoint owners, approve scope/change/maintenance window, communications, escalation and rollback authority. Exit: approvals recorded.

## Phase 1 — Source readiness

Inventory OS, packages, runtime, ports, services, jobs, database version/extensions/logging/backups, NFS paths/permissions/locking and API/session/queue dependencies. Confirm PostgreSQL WAL/logical replication prerequisites, table primary keys/replica identity, source DMS permissions and acceptable WAL retention. Exit: critical gaps have owners. Stop if recovery or dependencies are unknown.

## Phase 2 — AWS readiness

Validate VPC `10.30.0.0/16`, six steady-state subnets/two AZs, additional private MGN staging subnet, IGW, two NAT Gateways, VGW VPN, ALB, ACM certificate, DNS, private EC2, isolated RDS, EFS mount targets in both app AZs, S3 Gateway Endpoint, IAM, Secrets Manager, Systems Manager, endpoints, encryption and CloudWatch. Exit: infrastructure/security approval.

## Phase 3 — MGN

Check source OS/kernel/disk compatibility; create/identify dedicated staging-area subnet; configure MGN replication settings, IAM and network/security paths; install agents; monitor replication lag and staging capacity; configure private launch settings; test launch in isolation; validate boot, services, app dependencies and admin access. Exit: both test launches approved. Confirm staging resources and temporary costs are understood.

## Phase 4 — DMS

Complete schema/object migration separately using an approved method; prepare encrypted Multi-AZ RDS; configure PostgreSQL logical replication and DMS endpoint permissions; configure DMS endpoints/task; full load; review errors, validation and referential integrity; enable CDC; monitor lag, replication slots and WAL retention; reconcile schema, critical rows, sequences, grants and permissions. DBA signs off on trigger/foreign-key handling and final sequence state. Exit: DBA sign-off.

## Phase 5 — DataSync

Configure EFS/S3 destinations; initial NFS and archive transfers; inspect errors/skips; compare counts/sizes; validate permissions/locking/application access. Prepare final sync.

## Phase 6 — Integrated tests

Test login, order creation/retrieval/update, payment/delivery test APIs, DB connectivity, EFS access, ALB target health, logs, monitoring and admin access. Exit: critical tests pass.

## Phase 7 — Cutover

1. Announce approved maintenance.
2. Stop source order creation and background writers.
3. Confirm source DB and file writes stopped.
4. Final DataSync transfer.
5. DMS CDC catch-up; verify lag is zero/within agreed threshold and no task errors.
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

Monitor EC2/RDS/EFS/ALB/CloudWatch/security; validate backups; reconcile transactions; resolve incidents; hand over operations. Five business days is a planning assumption. Source retirement is a separate approval.

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

**Status:** Proposed runbook; no execution occurred.
