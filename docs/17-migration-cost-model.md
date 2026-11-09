# 17 — Migration-period cost model and pricing gates

**ID:** CLI-AWS-COST-017 | **Version:** 1.0 | **Status:** Formula model complete; source quantities and service sizing pending  
**Project:** Clafoke Investors Ltd (fictional, design-only) | **Region:** `us-east-1` | **Currency:** USD

## Purpose and boundary

This document turns the migration cost discussion into a repeatable calculation model. It is deliberately **not a migration quote, approved budget, or total-cost forecast**. Source inventory, benchmark results, network traffic and the migration calendar do not exist for this fictional case. Unknown quantities remain unpriced; illustrative anchors are labelled and never promoted to Calculator inputs.

The saved steady-state estimate remains **$1,930.76/month ($23,169.12 annualised)**. It is a six-entry partial subtotal. Do not add the migration formulas below to that baseline as though they were verified costs.

## Executive model

| Cost component | Calculation model | Current status |
|---|---|---|
| MGN service fee | Per source: `max(0, active replication hours − 2,160) × current per-server-hour rate` | 90-day service-fee allowance confirmed by AWS. $0.042/server-hour is a published AWS reference, but must be revalidated against the current us-east-1 Price List before estimate entry. |
| MGN replication infrastructure | Replication EC2 hours + staging EBS provisioned GB-month + incremental snapshot GB-month + test/cutover EC2/EBS hours | Unpriced: source disk count/capacity, change rate, server class, storage profile, snapshots and test duration unknown. |
| DMS provisioned | Selected class hourly rate × billable instance hours + any separately billed storage/logs | Unpriced: source compatibility, class, AZ mode, storage and task runtime not benchmarked. |
| DMS Serverless | Observed DCU-hours × current us-east-1 DCU-hour rate, with selected Single-AZ/Multi-AZ mode | Unpriced: no representative workload or min/max DCU range. |
| DataSync Basic | Measured GB copied × $0.0125/GB for current NFS-to-EFS task | Conditional NFS arithmetic only; actual used bytes and final delta unknown. |
| DataSync Enhanced | Eligible transfer GB × $0.015/GB + $0.55 per task execution | Not applicable to NFS-to-EFS. Only evaluate for a supported future archive path such as NFS/SMB-to-S3 with a compatible Enhanced-mode agent. |
| DataSync interface endpoint | $0.01 per endpoint-AZ-hour + $0.01/GB control-plane data processed (first tier) | One endpoint ENI in one AZ would be $7.30 for 730 hours; deployment duration and control traffic unknown. DataSync file payload is not charged as PrivateLink endpoint traffic. |
| VPN/NAT/network | Existing fixed VPN/NAT hours are already in the steady-state subtotal if reused; add only measured transfer-out, NAT processed bytes, endpoint hours/GB, cross-AZ and new resources | Direction, bytes, path and duration unconfirmed. Never double count baseline fixed hours. |
| Parallel operation | Incremental source/target operating cost × approved overlap duration, plus temporary test/cutover/rollback resources | Unpriced until service start/stop dates, retirement date and source/target responsibilities are approved. |

## Bounded arithmetic — not a project total

These examples show only the arithmetic supported by currently documented reference quantities. They do not establish actual transfer volumes or runtime.

### MGN service fee only

AWS confirms 2,160 hours (90 continuous days) without an MGN service fee per source server. Replication EC2, staging EBS and snapshots are chargeable from the first hour. AWS's public pricing page currently describes post-allowance hourly billing but does not expose the numeric rate in its page text. The $0.042/server-hour figure is a published AWS pricing reference; the current us-east-1 offer rate must be rechecked before Calculator entry.

For the two documented application sources, using that reference rate:

| Continuous active duration | Hours per source | Paid hours per source after allowance | Conditional MGN service fee for two sources |
|---|---:|---:|---:|
| 1 week | 168 | 0 | $0.00 |
| 1 × 730-hour month | 730 | 0 | $0.00 |
| 3 × 730-hour months | 2,190 | 30 | $2.52 |

Formula: `2 sources × max(0, active hours − 2,160) × $0.042`. This is the **service fee only**, not MGN's infrastructure cost. A 3-month scenario does not imply that a migration should take 90 days; the duration is a sensitivity case.

### DataSync NFS-to-EFS only

The current Terraform task is Basic mode because Enhanced mode is not supported for NFS-to-EFS. AWS's Basic-mode reference is $0.0125 per GB copied.

| Conditional source quantity | Basic-mode DataSync service fee |
|---|---:|
| 1,000 decimal GB | $12.50 |
| 1,024 GiB | $12.80 |

Discovery's approximately 1 TB NFS value is an unverified planning anchor, not measured used bytes. The 500 GB S3 value is destination capacity and must not be treated as archive source volume. Archive source bytes, file/object counts, storage class, request costs and final delta remain unpriced.

A future eligible NFS/SMB-to-S3 Enhanced task would use $0.015/GB plus $0.55 per execution. Do not apply that rate to the current NFS-to-EFS task.

### Optional DataSync endpoint and EFS write meters

- One DataSync interface endpoint ENI in one AZ for 730 hours: `730 × $0.01 = $7.30`. This is an endpoint-hour illustration, not a selected endpoint duration.
- If 1,000 GB is actually written to EFS using the documented provisional Elastic write rate of $0.06/GB, the separate write-throughput component would be $60.00. Both the bytes and throughput mode remain unverified.
- Therefore, the simple arithmetic `$12.50 DataSync + $7.30 one endpoint-AZ-month = $19.80` is only a conditional NFS/endpoint example, **excluding** EFS write throughput, archive transfer, S3 requests/storage, network processing, MGN infrastructure, DMS, test/cutover, overlap and all other unresolved items. It is not a migration estimate.

## DMS sizing gate

The 500 GB logical database assumption and the saved RDS `db.m6i.2xlarge` configuration do not determine DMS capacity. Before pricing, collect:

1. Exact PostgreSQL source major/minor/patch, OS/kernel, target RDS version and candidate DMS engine version; validate the current AWS compatibility matrix.
2. Database count, provisioned and used bytes, table/object counts, largest tables, LOB distribution, primary-key/replica-identity coverage and extension inventory.
3. Source CPU, memory, IOPS, free disk, transaction rate, write bytes/second, WAL generation, slot retention and long-transaction profile.
4. Full-load completion window, CDC lag objective, validation duration, maintenance window and expected task runtime.
5. A representative rehearsal comparing provisioned Single-AZ/Multi-AZ replication instances with DMS Serverless under the same workload. Record CPU/memory/storage/IOPS, throughput, DCU-hours, latency, failures and retries.

Only after this evidence exists should the model be populated with a selected provisioned class or observed Serverless DCU-hours and the live us-east-1 price. DMS charges are distinct from RDS target runtime and backups. AWS documents no DMS data-transfer charge for traffic in/out of the DMS node itself and no charge for DMS-to-RDS traffic in the same AZ; validate any cross-AZ or other network meters separately.

## Network and overlap controls

- If migration traffic reuses the already-priced Site-to-Site VPN and NAT Gateways, do not repeat their $36.50 VPN connection-hours or $65.70 NAT gateway-hours in the migration group. Their separately priced public IPv4 address components are also already in the baseline.
- Add only measured VPN outbound transfer, NAT processed GB, interface endpoint ENI-hours/processed control GB, cross-AZ transfer, or genuinely new temporary resources.
- On-premises-to-AWS transfer direction is not the same as AWS-to-on-premises transfer. Capture bytes by direction and route; do not assume all source replication bytes are billable internet egress.
- For source/target overlap, record each resource's actual billable start and stop, not a generic number of days. Distinguish source-retained cost, target steady-state cost, temporary replication/test resources, rollback reserve and decommissioning.
- Finalise/disconnect MGN source servers after approved cutover/rollback closure; remove temporary test resources and verify snapshots/endpoints/log groups before declaring migration charges ended.

## Required inputs and owners

| Input | Responsible role | Evidence required before pricing |
|---|---|---|
| Source OS, disks, used/provisioned capacity, write rate | Infrastructure Lead | Server inventory, disk layout, OS/kernel/boot evidence, replication benchmark |
| MGN replication server and staging profile | Solutions Architect / Infrastructure Lead | Replication settings, EC2/EBS price selection, snapshot growth/retention, test launch schedule |
| PostgreSQL compatibility and DMS sizing | DBA / Solutions Architect | Version matrix, object inventory, WAL profile, full-load/CDC benchmark and task logs |
| NFS/archive source quantities and final delta | Storage Lead / Application Lead | Used bytes, file/object counts, exclusions, storage classes, change-rate samples and DataSync reports |
| VPN/NAT/endpoint path and traffic | Network Lead / Security Lead | Approved flow matrix, route/AZ map, traffic direction and bytes, endpoint inventory |
| Maintenance, overlap, rollback and retirement dates | Migration Lead / Business Owner | Approved dated runbook and change window |
| DNS, monitoring and target operating assumptions | Operations Lead / Business Owner | Ownership, logging/retention, service start/stop and acceptance decisions |

## Exit criteria

Migration-period pricing is ready for Calculator entry only when MGN source/staging/test resources are sized; DMS compatibility and capacity are benchmarked; DataSync source and delta quantities are inventoried; network flows and endpoint choices are approved; and the migration/overlap/retirement calendar is signed off. Until then, keep the migration Calculator group empty and report the cost as **unpriced**, not zero.

## Sources

- [AWS Transform MGN pricing](https://aws.amazon.com/application-migration-service/pricing/) — service pricing and additional infrastructure charges.
- [AWS Transform MGN FAQs](https://aws.amazon.com/application-migration-service/faqs/) — 2,160-hour / 90-day per-source service-fee period and infrastructure charges during the free period.
- [AWS MGN cost-planning guidance](https://docs.aws.amazon.com/mgn/latest/ug/migration_at_scale.html) — replication and migration infrastructure cost drivers.
- [AWS-hosted MGN pricing deck](https://pages.awscloud.com/rs/112-TZM-766/images/2022_0804-MIG_Slide-Deck.pdf) — published $0.042 per source-server-hour reference after the initial 90 days; verify current offer rate before use.
- [AWS DMS pricing](https://aws.amazon.com/dms/pricing/) — provisioned and Serverless billing models, included storage notes and transfer treatment.
- [AWS DataSync pricing](https://aws.amazon.com/datasync/pricing/) — Basic/Enhanced per-GB rates, execution charge, PrivateLink control traffic and destination request/storage charges.
- [DataSync task-mode guidance](https://docs.aws.amazon.com/datasync/latest/userguide/choosing-task-mode.html) — supported transfer types and Basic-mode quotas.
- [AWS Price List bulk API guidance](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/using-the-aws-price-list-bulk-api-fetching-price-list-files-manually.html) — authoritative way to retrieve current service offer files.

**Execution status:** no AWS resources deployed; no MGN agent installed; no replication started; no DMS task run; no DataSync transfer executed; no migration or cutover performed.
