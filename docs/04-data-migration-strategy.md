# 04 — Data Migration Strategy and Execution Plan

**ID:** CLI-AWS-DATA-004 | **Version:** 1.2 | **Status:** Proposed baseline — source evidence and migration readiness pending

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

## DMS compatibility and readiness gates

DMS compatibility is **unverified** until the exact PostgreSQL source version/patch, chosen RDS PostgreSQL target version and DMS replication engine version have been checked together against the current AWS DMS source/target support matrix. AWS documents self-managed PostgreSQL sources from 9.4, subject to engine-version support. In the version matrix reviewed for this project, PostgreSQL 17 and 18 require DMS 3.5.4 or later; this is a dated reference point, not a substitute for rechecking the live matrix. These are compatibility reference points, not confirmation that this source is supported. Capture `SELECT version();`, `SHOW server_version;`, OS/package details and the selected DMS engine version before approval. Recheck the live matrix at implementation time.

Before full load plus CDC, the DBA must validate:

- Replication account permissions and required source privileges for the selected DMS version and deployment model.
- `wal_level = logical`, sufficient `max_replication_slots` and `max_wal_senders`, and any other current DMS prerequisites.
- WAL generation, retention, disk headroom and monitoring. DMS replication slots can retain WAL until changes are decoded; stalled tasks or long-running transactions can cause WAL growth and source-storage pressure.
- Primary keys or suitable replica identity for every table. Tables without primary keys require explicit review and testing; UPDATE/DELETE capture may be incomplete without an appropriate replica-identity strategy.
- Network reachability, source stability, encryption, endpoint permissions and task logging.
- Full-load window, transaction/write rate, CDC latency objective, and tested recovery/stop criteria.

DMS data replication is not a substitute for a complete schema/object migration. Inventory schemas, tables, types, constraints, indexes, sequences, views/materialized views, functions, procedures, triggers, extensions, roles, grants, ownership and large objects. Select and rehearse a separate schema deployment/conversion method. DMS PostgreSQL target behavior does not keep sequence values synchronized during ongoing replication; after CDC stops, reconcile sequence values (including `NEXTVAL` state) before application writes are enabled. Foreign-key and trigger handling during full load must be explicitly tested and approved; do not disable constraints without a documented restoration and validation plan.

Do not size DMS from the source VM's 8 vCPU / 32 GiB or the 500 GB logical-data planning assumption. Those figures do not establish DMS capacity. Compare provisioned replication instance classes against Serverless using the same representative full-load and CDC workload. Record CPU, memory, storage/IOPS, task throughput, CDC latency, errors and observed capacity. Provisioned pricing depends on class, Single-AZ/Multi-AZ mode, running hours and included/additional storage; Serverless pricing depends on observed DCU-hours and configured minimum/maximum capacity. No class, DCU range, AZ mode, storage amount or runtime is selected until a DBA-supported benchmark exists.

DMS exit evidence: source/target/DMS version compatibility; object and extension assessment; approved schema method; WAL/slot/permission readiness; table key/replica-identity report; representative full-load plus CDC benchmark; acceptable lag and full-load completion; validation/reconciliation results; and approved cutover/rollback criteria.

[DMS PostgreSQL source requirements](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Source.PostgreSQL.html) · [DMS source-version matrix](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Introduction.Sources.html) · [DMS PostgreSQL target limitations](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.PostgreSQL.html) · [DMS replication-instance sizing](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_BestPractices.SizingReplicationInstance.html) · [DMS Serverless settings](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Serverless.html)

## NFS to EFS

Discovery estimates shared NFS at approximately 1 TB; this is an unverified planning assumption, not measured used bytes. Do not treat it as a confirmed DataSync transfer quantity or cost. Before sizing, inventory exports/paths, allocated and used bytes, file counts/size distribution, ownership/ACLs, symlinks, locking/open files, active writers, exclusions and change rate. Configure encrypted Regional EFS and mount targets in both AZs. Allow NFS TCP 2049 from the application security group to the EFS mount-target security group. Run initial DataSync early enough to review task reports, errors/skips and verification; reconcile counts/sizes and test permissions/application behaviour. Pause all writers before final sync, capture the final delta and approve reconciliation.

**Task-mode baseline:** the current Terraform NFS-to-EFS task explicitly uses DataSync `BASIC` mode so its behavior and pricing assumptions are deterministic. Basic mode has file/object-count quotas and sequential prepare/transfer/verify behavior; it remains provisional until the source file count and throughput are benchmarked. Enhanced mode may be evaluated if the dataset or performance target exceeds Basic-mode suitability; it has a different per-GB and per-execution price, may require a compatible Enhanced-mode agent, and task mode cannot be changed after creation. If Enhanced is selected, create a replacement task and update the runbook and estimate. The Terraform archive bucket/S3 location is only a destination; no archive source location or transfer task is created until discovery identifies the actual archive source type and path. [DataSync task-mode guidance](https://docs.aws.amazon.com/datasync/latest/userguide/choosing-task-mode.html) · [DataSync pricing](https://aws.amazon.com/datasync/pricing/).

## Archives to S3

The 500 GB S3 figure is target storage, not source archive quantity. The previous 1,500 GB combined DataSync assumption and $18.75 calculation are withdrawn; archive source bytes and object counts remain unknown. Inventory eligible archive bytes, object/file counts and sizes, source storage class/restore state, scope/exclusions, retention and destination prefix. Configure private bucket, Block Public Access and encryption. Transfer with DataSync, validate object inventory/content and errors. Apply lifecycle policies only after approval. Route application access through an S3 Gateway Endpoint where appropriate.

## Application servers

Verify MGN OS compatibility, allocate a dedicated staging-area subnet for replication servers, configure replication settings and required security/routing, install agents, monitor replication, configure private launch settings, test launch in isolation, validate boot/services/dependencies and obtain approval. Staging subnet sizing and replication traffic are migration-specific design inputs.

## Cutover sequence

1. Maintenance window; stop new orders and source writers.
2. Pause jobs/queues/integrations writing source data.
3. Run final DataSync sync after all file writers/jobs are paused and reconcile its completion and verification evidence.
4. Complete DMS CDC catch-up and critical-record reconciliation. Both the independent file-transfer gate and database gate must pass before go/no-go; exact concurrency/order and wait time are set in the approved maintenance plan.
5. Configure target app with RDS/EFS/secrets.
6. Smoke tests and formal go/no-go.
7. Switch DNS/traffic to ALB.
8. Monitor and obtain business acceptance.

## Rollback

Before target writes, return to source only after source readiness and consistency checks. After target writes, freeze writes, preserve logs and reconcile/reverse-migrate under DBA and Business Owner approval. DNS reversal alone is unsafe; reverse replication is not assumed.

**Status:** Proposed migration plan; no data migrated. MGN source compatibility, DMS source/target compatibility and sizing, DataSync source quantities, and the migration calendar remain Pending Validation. See [Migration Readiness Matrix](09-migration-readiness-matrix.md).
