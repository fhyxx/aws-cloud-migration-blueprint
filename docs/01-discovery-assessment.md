# 01 — Discovery Assessment

**ID:** CLI-AWS-MIG-001 | **Version:** 1.0 | **Status:** Fictional discovery baseline

## Purpose

Assess a fictional on-premises order-management platform and identify information needed to plan migration to AWS. Clafoke Investors Ltd is fictional; no real systems or customer data are represented.

## Scenario assumptions

| Component | Assumed source |
|---|---|
| Business | Nigerian retail and distribution |
| Staff | ~80 |
| Application | 2 Linux VMs, each 4 vCPU / 16 GiB |
| Database | PostgreSQL VM, 8 vCPU / 32 GiB, 500 GB |
| Shared files | NFS, approximately 1 TB |
| Integrations | Payment and delivery APIs |
| Business targets | 99.9% availability; RTO 4h; RPO 15m |

These are assumptions, not measured values. Actual utilisation, growth, transactions, concurrency and data volumes are unknown.

## Requirements

- Protect committed order and financial records.
- Minimise planned interruption.
- Encrypt data in transit and at rest.
- Restrict staff, application and administrator access.
- Maintain monitoring, backups and recovery procedures.
- Document cutover and rollback decisions.

## Discovery inventory

| Area | Must establish |
|---|---|
| Linux servers | Distribution/version, packages, runtime, ports, disks, boot mode |
| PostgreSQL | Engine version, extensions, procedures, triggers, sequences, roles, logging, IOPS |
| NFS | Exports, paths, file counts, ownership, permissions, locking, active writers |
| Application | Sessions, cache, queues, jobs, DNS, time, email, licence dependencies |
| Integrations | API domains, allowlists, credentials, retry behaviour, vendor SLAs |
| Operations | Backup/restore, monitoring, maintenance windows, recovery ownership |

## Proposed AWS mapping

| Source | AWS target | Gate |
|---|---|---|
| Linux application VMs | EC2 via AWS MGN | OS/application compatibility |
| PostgreSQL | RDS PostgreSQL | Engine, extension and feature compatibility |
| Database replication | AWS DMS full load + CDC | Logging, permissions and DMS prerequisites |
| NFS | Regional EFS via DataSync | POSIX, locking and throughput validation |
| Archives | S3 via DataSync | Retention and retrieval requirements |
| Hybrid | Site-to-Site VPN / VGW | CIDRs and routing confirmed |

## Initial risks

- PostgreSQL incompatibility: complete compatibility assessment.
- Unknown writers: inventory all database/file writers and freeze at cutover.
- NFS differences: test permissions, locking and application behaviour.
- API allowlists: validate egress requirements.
- Unknown utilisation: collect representative metrics before final sizing.

## Discovery gaps

D01 Linux distributions; D02 app runtime/ports; D03 PostgreSQL version/extensions; D04 transaction/connection rates; D05 storage growth; D06 NFS semantics; D07 source/target CIDRs; D08 API allowlists; D09 tested backup/restore; D10 authentication; D11 sessions/queues/jobs; D12 maintenance window; D13 retention; D14 workload peaks.

**Acceptance:** Critical dependencies, database compatibility, data scope, network connectivity and recovery requirements have named owners and documented outcomes.

**Status:** Initial fictional discovery baseline only; no production discovery performed.
