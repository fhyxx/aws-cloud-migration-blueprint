# 08 — Assumptions and Decisions Register

**ID:** CLI-AWS-ADR-008 | **Version:** 1.0 | **Status:** Open — workload validation required  
**Project:** Clafoke Investors Ltd (fictional portfolio case study)  
**Region:** \`us-east-1\` | **Currency:** USD | **Planning month:** 730 hours  
**Related:** [Discovery assessment](01-discovery-assessment.md), [Target architecture](02-target-architecture.md), [Network and security design](03-network-security-design.md), [Migration strategy](04-data-migration-strategy.md), [Migration runbook](05-migration-runbook.md), [Validation and rollback](06-validation-rollback-strategy.md), [Cost estimation and optimisation](07-cost-estimation-optimisation.md), [pricing assumptions](../cost/pricing-assumptions.csv), [target architecture diagram](../architecture/target-architecture.mmd)

## Executive summary

This register distinguishes repository statements from architectural deductions, illustrative planning scenarios and information still requiring validation. The project is fictional and design-only: no production measurements, AWS deployment, migration or load test has occurred. None of the illustrative usage scenarios below is an approved client requirement.

The existing saved AWS Pricing Calculator subtotal is **$1,916.16/month**, including two conventional NAT Gateways. This document does not change the calculator or convert that subtotal into a complete operating budget. The earlier $2,214–$2,702/month worksheet is withdrawn as a budget.

Priority decisions are: (1) ALB traffic and LCU dimensions; (2) Route 53 zone ownership and query volume; (3) CloudWatch metrics, alarms, log ingestion/retention and Flow Logs; (4) EFS capacity, throughput, lifecycle and cross-AZ use; (5) VPN traffic and tunnel/public IPv4 treatment; and (6) migration source sizing, MGN/DMS/DataSync profiles, temporary network and overlap duration.

## Status definitions

- **Documented:** explicitly stated in a project artifact. A documented figure is still a design assumption unless identified as measured.
- **Derived:** follows from a documented architecture decision but is not a workload measurement.
- **Provisional:** illustrative engineering scenario for sensitivity analysis only; not a client requirement and not approved for calculator entry.
- **Pending Validation:** information, evidence or a technical/business decision remains missing.
- **Approved:** explicitly approved by the accountable project authority with evidence recorded. No open usage scenario is Approved in this revision.

Owners are roles from the project runbook, not named people. Technical owners supply evidence/recommendations; the Business Owner or Migration Lead records applicable formal approvals.

## Documented architecture baseline

| Baseline item | Repository statement | Status |
|---|---|---|
| Project context | Fictional Nigerian retail/distribution business and order-management platform; design-only | Documented |
| Region and planning basis | \`us-east-1\`; USD; 730 hours/month | Documented |
| Application | Two Linux VMs, each 4 vCPU / 16 GiB; \`t3.xlarge\` is a pricing proxy; two-AZ ASG desired/minimum capacity 2 | Documented |
| Source database | PostgreSQL VM, 8 vCPU / 32 GiB; 500 GB source/logical-data assumption | Documented |
| Target database design | RDS PostgreSQL Multi-AZ DB instance deployment with one standby; exact version/class/storage performance open | Documented |
| Shared storage | Approximately 1 TB NFS source assumption; Regional EFS with mount targets in both app AZs | Documented |
| Archive storage | 500 GB S3 Standard planning assumption; private access through S3 Gateway Endpoint where appropriate | Documented |
| Network | VPC \`10.30.0.0/16\`, two AZs, two public/two app/two DB subnets, plus separate private MGN staging subnet | Documented |
| Network entry and egress | One internet-facing ALB, HTTPS 443, public subnets; two NAT Gateways with same-AZ application egress | Documented |
| Hybrid connectivity | One standard Site-to-Site VPN to VGW; transfer/routing/rate details open | Documented |
| Migration methods | MGN for Linux application servers; DMS full load plus CDC for PostgreSQL data; DataSync for NFS→EFS and archives→S3 | Documented |
| DNS and certificate | ACM certificate and Route 53 alias are implementation requirements; Route 53 zone ownership is conditional/unresolved | Documented |
| Business goals | 99.9% availability, RTO 4h, RPO 15m are targets only; not demonstrated | Documented |
| Calculator checkpoint | Existing saved estimate subtotal $1,916.16/month, verified in calculator; includes two conventional NAT Gateways | Documented |
| Known cost gaps | ALB LCU, DNS usage, monitoring usage, EFS workload/transfer, VPN transfer, and migration-period costs/overlap are not fully priced | Documented |

## Assumptions and decisions register

Scenario ranges below are planning examples only. They are not measured values, client requirements, approvals or calculator inputs. An owner must validate or explicitly propose a selected scenario before pricing it.

### A. Application Load Balancer

The LCU estimates below use the largest applicable dimension as an approximate peak LCU and multiply by 730 hours for sensitivity comparison. Real billing depends on the hourly workload profile and current calculator model.

| ID | Assumption / decision | Conservative / baseline / high scenario | Status | Responsible owner | Evidence required | Affected services / cost components | Dependencies |
|---|---|---|---|---|---|---|---|
| A-001 | New connections, active connections and request rate per ALB | 0.5 / 2 / 10 new connections/s; 100 / 500 / 3,000 active connections; 5 / 20 / 100 requests/s | Pending Validation | Application Lead; Business Owner accepts workload envelope | Representative ALB/application telemetry or reviewed load-test profile; average, peak and seasonal window | ALB connection/request LCU; application EC2 sizing | Establishes ALB capacity and informs ASG scaling and CloudWatch metric selection |
| A-002 | Processed bytes and target type | 0.5 / 2 / 10 GB per hour; architecture currently shows EC2 targets | Pending Validation | Application Lead | ALB byte metrics/access logs, payload-size distribution, target-type confirmation | ALB processed-byte LCU; Internet transfer; network traffic accounting | Depends on A-001 and final target design |
| A-003 | Rule evaluations per request and listener/rule count | 5 / 15 / 25 evaluations/request as examples; actual rules unknown | Pending Validation | Application Lead | Listener/rule inventory and request-path distribution; validate with service metrics/test | ALB rule-evaluation LCU | Depends on final listener/rule design and A-001 request rate |
| A-004 | Approximate monthly LCU-hours for sensitivity analysis | 0.5 / 2 / 10 peak LCUs × 730 h = 365 / 1,460 / 7,300 LCU-hours | Provisional | Solutions Architect calculates; Business Owner approves planning use if needed | Validated A-001–A-003 or written approval to use scenario as provisional planning envelope | ALB LCU charges plus fixed ALB hours | Must be recalculated from validated/approved hourly dimensions; not a measured forecast |

### B. Route 53 and certificate

| ID | Assumption / decision | Conservative / baseline / high scenario | Status | Responsible owner | Evidence required | Affected services / cost components | Dependencies |
|---|---|---|---|---|---|---|---|
| A-005 | Route 53 authoritative DNS choice and public hosted-zone count | 1 / 1 / 2 zones as examples; do not price zones until hosting decision is confirmed | Pending Validation | Business Owner; Infrastructure Lead validates delegation | Registrar/DNS-provider record, delegation plan, ownership confirmation, approved record inventory | Route 53 hosted-zone charge and DNS migration work | Determines if Route 53 is billable; ALB alias and certificate validation depend on domain control |
| A-006 | Monthly DNS query volume and routing features | 1 million / 10 million / 100 million queries/month as scenarios only | Pending Validation | Infrastructure Lead; Application Lead supplies demand profile | Existing DNS query reports or approved forecast; query types, routing policy and health checks | Route 53 query, health-check and routing-policy charges where applicable | Depends on A-005 |
| A-007 | ACM public certificate domain validation and ALB association | One public certificate appears in the design; domain and validation method unknown | Pending Validation | Infrastructure Lead; Business Owner confirms domain control | Domain ownership, validation method and ALB association plan | ACM charges where applicable; Route 53 validation records; ALB HTTPS listener | Depends on A-005 |

### C. CloudWatch and VPC Flow Logs

Metric/log volumes below are illustrative planning bounds. Separate service-included metrics from custom metrics and keep Flow Logs distinct from application logs.

| ID | Assumption / decision | Conservative / baseline / high scenario | Status | Responsible owner | Evidence required | Affected services / cost components | Dependencies |
|---|---|---|---|---|---|---|---|
| A-008 | Custom metric time series, excluding included service metrics | 10 / 50 / 200 time series; dimensions/resolution TBD | Pending Validation | Operations Lead | Monitoring requirements matrix, metric names/dimensions/resolution and included-metric review | CloudWatch custom metrics, dashboards, alarm inputs | Derives from EC2, RDS, EFS, ALB, VPN, application and network monitoring needs |
| A-009 | Application/system log ingestion and retention | 10 / 50 / 200 GB ingested/month; 30 / 90 / 365 days retained | Pending Validation | Operations Lead; Application Lead provides log-rate evidence | Sample or measured rate, source/filter inventory, destination, retention approval | CloudWatch Logs ingestion/storage, queries or metric filters where used | Depends on application, ALB/EC2/RDS logging and A-008 monitoring plan |
| A-010 | Alarm count and evaluation policy | 10 / 25 / 100 standard alarms; alarm type/period/frequency TBD | Pending Validation | Operations Lead | Alarm catalogue: resource, threshold, period, evaluations, missing-data treatment, notification path | CloudWatch alarms; SNS/notification costs if selected | Depends on A-008 metric inventory and A-001 workload/availability objectives |
| A-011 | VPC Flow Logs scope, volume and retention | 5 / 50 / 500 GB/month as separate Flow Log ingestion examples; 30 / 90 / 365 days retention examples | Pending Validation | Security Lead; Infrastructure Lead configures network scope | Approved VPC/subnet/interface scope, filters, destination, estimated log records and retention | CloudWatch Logs or alternate destination ingestion/storage; queries/filters | Depends on VPC, VPN, NAT, endpoint, ALB and MGN staging design; coordinate with A-009 to prevent double count |

### D. EFS storage, throughput and transfer

The 1,000 GB EFS quantity is a documented planning assumption, not a measured used-capacity value. Two mount targets are documented topology. Do not add a separate mount-target charge without checking the current calculator model.

| ID | Assumption / decision | Conservative / baseline / high scenario | Status | Responsible owner | Evidence required | Affected services / cost components | Dependencies |
|---|---|---|---|---|---|---|---|
| A-012 | EFS capacity, growth and lifecycle distribution | 1,000 GB target planning quantity is documented; actual use/growth/tier mix unknown | Pending Validation | Infrastructure Lead; Application Lead validates scope | NFS inventory: used bytes, file count, growth, exclusions, access-age distribution, lifecycle/retrieval policy | EFS Regional Standard and lifecycle-tier storage, retrieval/transition charges | Determines storage and lifecycle cost; aligns DataSync scope A-019 |
| A-013 | EFS read/write throughput and throughput mode | Read/write volume: 100/25, 500/100, 2,000/500 GB/month; illustrative peak throughput 5/25/100 MiB/s | Pending Validation | Application Lead; Infrastructure Lead selects mode | NFS telemetry/benchmark: bytes read/written, sustained/peak rate, concurrency and access pattern; compare eligible throughput modes | EFS throughput charges and performance configuration | Depends on data profile A-012 and app concurrency; selected performance metrics should appear in A-008 |
| A-014 | EFS cross-AZ access and transfer | No volume approved; measure same-AZ versus cross-AZ traffic; two mount targets do not imply zero cross-AZ transfer | Pending Validation | Infrastructure Lead; Application Lead supplies placement/access evidence | ASG AZ placement and EFS client bytes by AZ | Cross-AZ data transfer and EFS client traffic | Depends on app placement and mount-target use; Flow Logs A-011 may help quantify |

### E. VPN and steady-state network

| ID | Assumption / decision | Conservative / baseline / high scenario | Status | Responsible owner | Evidence required | Affected services / cost components | Dependencies |
|---|---|---|---|---|---|---|---|
| A-015 | Monthly VPN data transfer, direction and destination | 100 GB / 1 TB / 10 TB per month as sensitivity examples | Pending Validation | Infrastructure Lead; Application Lead identifies workload flows | Source utilization or traffic model by direction, destination and flow type | VPN data transfer, applicable AWS data transfer; on-premises circuit cost is outside calculator | Depends on routes/source CIDRs and migration traffic A-017–A-023; informs Flow Log estimate A-011 |
| A-016 | VPN routing, tunnel design and public IPv4 price treatment | One standard VGW VPN documented; static/BGP and tunnel/address treatment unresolved | Pending Validation | Infrastructure Lead | Approved Customer Gateway/VGW configuration, regional calculator product selection and current pricing review | VPN connection-hours, public IPv4 address-hours if applicable, transfer | Needed to validate VPN subtotal; relates to migration network A-020–A-022 |

### F. Migration services, temporary network and overlap

Keep all migration costs in a separate migration-period group. Duration examples are scenarios only. Do not size DMS or MGN from source CPU/RAM alone.

| ID | Assumption / decision | Conservative / baseline / high scenario | Status | Responsible owner | Evidence required | Affected services / cost components | Dependencies |
|---|---|---|---|---|---|---|---|
| A-017 | MGN source scope, replication and staging profile | Two Linux application sources align with discovery; 2 weeks / 1 month / 3 months are illustrative durations. Disks, change rate and staging size unknown | Pending Validation | Infrastructure Lead | OS/kernel/disk inventory, used bytes/change rate, MGN compatibility, replication settings, staging recommendation, expected dates and test-launch evidence when executed | MGN replication servers, EBS, transfer and temporary network | Depends on staging network A-020/A-022 and calendar A-023; strategy covers app VMs, not PostgreSQL |
| A-018 | DMS mode, capacity and runtime | Full load + CDC is documented; source change rate and DMS capacity/runtime are unknown; no class or Serverless capacity selected | Pending Validation | DBA; Solutions Architect reviews | PostgreSQL version/size/extensions/schema, WAL/logical replication readiness, write rate, keys/replica identity, CDC latency objective, compatibility and sizing results | DMS replication instance or Serverless capacity/runtime, storage and transfer; source remains in use during migration | Depends on network/VPN A-015/A-016/A-020–A-022, RDS target decisions, and schedule A-023 |
| A-019 | DataSync quantity, task count and transfer schedule | 1.5 TB initial data is derived from 1 TB EFS + 500 GB S3 target assumptions, not verified source data; final-delta examples 1% / 5% / 20% of 1.5 TB | Derived | Application Lead inventories sources; Infrastructure Lead sizes task | Source byte/file counts for NFS and archives, filters, change rate, task schedule, bandwidth and final-sync plan | DataSync processed data/task runtime/transfer; EFS/S3 destination and network | Depends on EFS A-012, VPN/transfer A-015 and calendar A-023 |
| A-020 | Migration staging subnet size, AZ, route and egress choice | Additional private subnet is documented; CIDR, IP capacity, AZ, NAT/private-endpoint choice and endpoint count are open | Pending Validation | Infrastructure Lead; Security Lead reviews | Non-overlap address plan, source CIDRs, AZ/route design, MGN endpoint guidance, required flows, SG/NACL and endpoint inventory | Temporary subnet connectivity, NAT hours/processing, interface endpoint hours/data, transfer and logs | Required by MGN A-017; impacts Flow Logs A-011 and must not silently reuse steady-state assumptions |
| A-021 | Temporary migration transfer/network quantities | No amount approved; include only evidence-backed VPN, NAT, endpoints, transfer and other temporary resources | Pending Validation | Infrastructure Lead; Security Lead approves flows | Flow matrix listing source, destination, direction, GB, path, AZ and duration | VPN, NAT processing, cross-AZ/Internet transfer, endpoint hours/processing, public IPv4 where applicable | Depends on A-015/A-016, A-019, A-020/A-022 and calendar A-023 |
| A-022 | MGN subnet CIDR/capacity and network path | Separate private subnet required in addition to six steady-state subnets; CIDR, capacity, AZ and routes open | Pending Validation | Infrastructure Lead; Security Lead approves | Address plan/overlap check, IP capacity, route table/AZ, required service/source-to-staging flows and security review | Temporary staging network, routes, NAT/endpoints, transfer and logging | Required for A-017; coordinate with A-020/A-021 and VPN routing A-016 |
| A-023 | Migration calendar, parallel running, cutover, rollback and source retirement | 1 week / 1 month / 3 months parallel-operation scenarios; five business days stabilisation is a runbook planning assumption, not approved duration | Pending Validation | Migration Lead coordinates; Business Owner approves calendar and retirement | Approved schedule for MGN, DMS, DataSync, cutover/rollback/stabilisation and source retirement; identify which systems remain billable | Temporary migration group and overlapping source/target infrastructure; first-year cost | Depends on A-017–A-022 and validation gates; drives migration-period and first-year total |

## Decision dependency map

~~~mermaid
flowchart TD
  traffic[Application profile A-001/A-002] --> alb[ALB LCU A-003/A-004]
  rules[Listener rules A-003] --> alb
  dns[DNS authority and queries A-005/A-006] --> cert[Certificate and ALB DNS A-007]
  alb --> cw[Metrics and alarms A-008/A-010]
  appLogs[App logs and retention A-009] --> cw
  vpc[VPC, AZ, NAT, VPN, endpoints] --> flow[Flow Logs A-011]
  efsData[EFS inventory A-012] --> efsPerf[EFS throughput/mode A-013]
  placement[App AZ placement] --> efsCross[EFS cross-AZ A-014]
  efsData --> ds[DataSync A-019]
  vpn[VPN traffic/routing A-015/A-016] --> net[Temporary network A-020/A-021/A-022]
  net --> mgn[MGN A-017]
  net --> dms[DMS A-018]
  ds --> calendar[Overlap/calendar A-023]
  mgn --> calendar
  dms --> calendar
~~~

## Prioritised decisions before calculator completion

1. **ALB/application workload (A-001–A-004):** obtain connection, request, byte and rule-evaluation profile; approve a peak/average scenario if measured data is unavailable.
2. **DNS and certificate prerequisites (A-005–A-007):** confirm DNS authority, hosted-zone count, queries and domain control.
3. **Monitoring scope (A-008–A-011):** define custom metrics, alarms, log GB/retention and Flow Log destination/scope, keeping Flow Logs separate from application logs.
4. **EFS workload profile (A-012–A-014):** validate used storage/growth, throughput mode, read/write workload, lifecycle and cross-AZ share.
5. **VPN and network inputs (A-015/A-016, A-020–A-022):** quantify traffic/direction, verify selected VPN/tunnel pricing and settle migration subnet routes/endpoints/NAT.
6. **Migration sizing and schedule (A-017–A-023):** inventory MGN sources, complete DBA/DMS sizing, inventory DataSync data, and approve overlap/retirement dates.
7. **Record decisions and price:** assign evidence and status, then enter approved or clearly provisional scenario inputs and reconcile each service. Keep migration-period totals separate from steady-state monthly costs.

A partial calculator subtotal must not be described as a complete operating budget or customer commitment. Scenario selection does not make usage measured; any adopted scenario remains Provisional unless formally approved as a planning assumption.

## Proposed evidence checklist for portfolio review

Evidence should be dated, attributed to an owner and labelled measured, derived or illustrative. Redact credentials, account IDs, public IPs and non-public data.

### Workload and service sizing

- [ ] ALB listener/rule inventory, target type and representative metrics/load-test profile for connections, requests, bytes and evaluations.
- [ ] LCU calculation showing dimensions, hourly profile, period and scenario caveats.
- [ ] DNS provider/delegation evidence, zone count, record/routing design and query-volume source.
- [ ] Domain control, certificate validation method and ALB association.
- [ ] Monitoring requirements matrix for application, EC2, RDS, EFS, ALB, VPN and network.
- [ ] Custom metric list with dimensions/resolution and review of included metrics.
- [ ] Alarm catalogue with thresholds, periods, evaluation policy and notification owners.
- [ ] Log source/sample or ingestion rate, filters, destination and retention approval.
- [ ] Flow Log scope/filter/destination, estimated or measured volume, retention and security rationale.
- [ ] NFS/EFS inventory: used bytes, file count, growth, access age, lifecycle policy, read/write and peak-throughput evidence.
- [ ] App/EFS AZ placement and cross-AZ transfer estimate.
- [ ] VPN route/tunnel design and monthly traffic by direction; current product and public IPv4 price validation.

### Migration and temporary network

- [ ] Linux source inventory: OS/kernel, boot mode, disks/used bytes, change rate and MGN compatibility.
- [ ] MGN staging design, sizing basis, replication network path and start/stop plan; test-launch evidence only after execution.
- [ ] PostgreSQL version/extensions/schema, size, write profile, WAL/logical replication readiness, keys/replica identity, DMS sizing and compatibility decision.
- [ ] Approved schema/object migration method, separate from DMS data replication.
- [ ] DataSync source bytes/file counts, filters, task schedule, final-delta basis and transfer plan.
- [ ] Migration flow matrix: source, destination, direction, GB, path, AZ and duration for VPN/NAT/endpoints/transfer.
- [ ] Staging subnet CIDR/IP capacity, AZ, route, security controls, source-CIDR overlap check and endpoint/NAT decision.
- [ ] Approved migration calendar covering replication, full load/CDC, DataSync, cutover, rollback, stabilisation, parallel running and source retirement.
- [ ] Business Owner approval of maintenance window, cutover/rollback authority and retirement criteria.

### Pricing audit trail

- [ ] Owner, evidence link, date, status and approval record for every register item.
- [ ] AWS Pricing Calculator configuration capture per service, with units, Region, 730-hour basis and scenario label.
- [ ] Service totals reconciled against saved calculator and export; no manual duplication of calculator-embedded Multi-AZ billing.
- [ ] Separate steady-state and migration-period groups with temporary duration/overlap shown independently.
- [ ] Explicit list of unpriced items, zero placeholders and exclusions; distinguish a zero placeholder from validated zero cost.
- [ ] Dated calculator CSV/PDF or equivalent export and share URL if approved for portfolio publication.
- [ ] Statement that estimates exclude taxes and do not imply deployed infrastructure or executed migration.

## Governance and change history

No open scenario is Approved in this revision. This document records decisions and evidence needs; it does not approve workload quantities, amend architecture, update the calculator or claim production measurements. Future changes should update the relevant ID, owner, evidence, status, dependencies and calculator references together.

The historical $2,214–$2,702/month worksheet is withdrawn as a budget and must not be reused.
