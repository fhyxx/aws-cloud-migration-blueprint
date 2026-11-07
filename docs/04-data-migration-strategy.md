# 04 — Data Migration Strategy and Execution Plan

**ID:** CLI-AWS-DATA-004 | **Version:** 1.1 | **Status:** Proposed baseline

## Strategy

- Rehost Linux application VMs to EC2 using AWS Application Migration Service (MGN), subject to compatibility.
- Replatform PostgreSQL to RDS PostgreSQL using AWS DMS full load + CDC, subject to version/feature compatibility and CDC prerequisites.
- Move NFS files to Regional EFS using DataSync.
- Move archives to S3 using DataSync.
- Use Site-to-Site VPN / VGW for hybrid connectivity.
- Avoid application rewrite during initial migration.

## Pre-migration discovery

Confirm Linux distribution/kernel/boot/disk support; PostgreSQL version/extensions/roles/procedures/triggers/sequences/LOBs/partitions/logging; database size/transactions; NFS exports/permissions/locking/writers; application sessions/jobs/queues/APIs; backups and restore; CIDRs/firewalls/API allowlists.

## PostgreSQL to RDS

1. Complete compatibility review and select the exact RDS PostgreSQL version/class.
2. Decide schema/object migration method. DMS is primarily a data replication service; use a reviewed schema migration path (for example, native `pg_dump`/`pg_restore` or an approved schema conversion workflow) and explicitly inventory extensions, roles, grants, functions, procedures, triggers, views, materialized views and sequences.
3. Prepare encrypted RDS Multi-AZ DB instance deployment and DB subnet group across both AZs; configure parameter groups, backups and monitoring.
4. Validate source WAL/logical replication prerequisites, DMS permissions, network path, supported table keys and transaction profile. CDC requires logical replication configuration; tables without primary keys need explicit handling and testing because UPDATE/DELETE capture can be incomplete.
5. Configure DMS source/target endpoints and replication task. Run full load; review table statistics, validation results and errors.
6. Enable/monitor CDC latency and replication slot/WAL retention. Avoid unbounded WAL growth and long-running transactions; define alerts and stop criteria.
7. Reconcile schema, row counts, critical orders/financial records, sequences and permissions. DMS does not automatically leave every PostgreSQL object operationally ready; sequence values in particular require final reconciliation.
8. Freeze source writes at cutover; wait for CDC catch-up and confirm no outstanding errors/latency.
9. Promote RDS as sole production write authority after DBA and Business Owner approval.

DMS full-load table ordering and referential-integrity behaviour must be tested. Foreign-key/trigger handling during load needs an explicit DBA-approved approach; do not disable constraints casually or without a tested re-enable/validation plan.

## NFS to EFS

Inventory exports, paths, file counts, ownership and locking. Configure encrypted Regional EFS and mount targets in both AZs. Allow NFS TCP 2049 from the application security group to the EFS mount-target security group. Run initial DataSync transfer; review errors/skips; reconcile counts/sizes; test permissions and application behaviour. Pause all writers before final sync, reconcile and obtain approval.

## Archives to S3

Confirm scope/retention/retrieval. Configure private bucket, Block Public Access and encryption. Transfer with DataSync, validate object inventory/content and errors. Apply lifecycle policies only after approval. Route application access through an S3 Gateway Endpoint where appropriate.

## Application servers

Verify MGN OS compatibility, allocate a dedicated staging-area subnet for replication servers, configure replication settings and required security/routing, install agents, monitor replication, configure private launch settings, test launch in isolation, validate boot/services/dependencies and obtain approval. Staging subnet sizing and replication traffic are migration-specific design inputs.

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
