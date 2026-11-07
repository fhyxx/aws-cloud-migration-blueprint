# 04 — Data Migration Strategy and Execution Plan

**ID:** CLI-AWS-DATA-004 | **Version:** 1.0 | **Status:** Proposed baseline

## Strategy

- Rehost Linux application VMs to EC2 using AWS MGN, subject to compatibility.
- Replatform PostgreSQL to RDS PostgreSQL using AWS DMS full load + CDC, subject to compatibility.
- Move NFS files to Regional EFS using DataSync.
- Move archives to S3 using DataSync.
- Use Site-to-Site VPN / VGW for hybrid connectivity.
- Avoid application rewrite during initial migration.

## Pre-migration discovery

Confirm Linux distribution/kernel/boot/disk support; PostgreSQL version/extensions/roles/procedures/triggers/sequences/LOBs/partitions/logging; database size/transactions; NFS exports/permissions/locking/writers; application sessions/jobs/queues/APIs; backups and restore; CIDRs/firewalls/API allowlists.

## PostgreSQL to RDS

1. Complete compatibility review.
2. Prepare encrypted RDS target and DB subnet group across both AZs.
3. Configure backup, monitoring, parameter settings and access.
4. Configure DMS source/target endpoints and replication.
5. Run full load; review table statistics and errors.
6. Enable CDC and monitor latency.
7. Reconcile schema, row counts, critical orders/financial records, sequences and permissions.
8. Freeze source writes at cutover; wait for CDC catch-up.
9. Promote RDS as sole production write authority after approval.

Do not assume DMS supports every object or feature; document conversion/remediation.

## NFS to EFS

Inventory exports, paths, file counts, ownership and locking. Configure encrypted Regional EFS and mount targets in both AZs. Run initial DataSync transfer; review errors/skips; reconcile counts/sizes; test permissions and application behaviour. Pause all writers before final sync, reconcile and obtain approval.

## Archives to S3

Confirm scope/retention/retrieval. Configure private bucket, Block Public Access and encryption. Transfer with DataSync, validate object inventory/content and errors. Apply lifecycle policies only after approval.

## Application servers

Verify MGN OS compatibility, install agents, monitor replication, configure private launch settings, test launch in isolation, validate boot/services/dependencies and obtain approval.

## Cutover sequence

1. Maintenance window; stop new orders and source writers.
2. Pause jobs/queues/integrations writing source data.
3. Final DataSync sync.
4. DMS CDC catch-up and critical record reconciliation.
5. Configure target app with RDS/EFS/secrets.
6. Smoke tests and formal go/no-go.
7. Switch DNS/traffic to ALB.
8. Monitor and obtain business acceptance.

## Rollback

Before target writes, return to source only after source readiness and consistency checks. After target writes, freeze writes, preserve logs and reconcile/reverse-migrate under DBA and Business Owner approval. DNS reversal alone is unsafe; reverse replication is not assumed.

**Status:** Proposed migration plan; no data migrated.
