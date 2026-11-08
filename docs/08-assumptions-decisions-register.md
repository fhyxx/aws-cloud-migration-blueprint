# 08 — Assumptions and Decisions Register

**ID:** CLI-AWS-ADR-008 | **Version:** 1.3 | **Status:** Open — workload validation required  
**Project:** Clafoke Investors Ltd (fictional portfolio case study)  
**Region:** `us-east-1` | **Currency:** USD | **Planning month:** 730 hours  
**Related:** [Discovery assessment](01-discovery-assessment.md), [Target architecture](02-target-architecture.md), [Network and security design](03-network-security-design.md), [Migration strategy](04-data-migration-strategy.md), [Migration runbook](05-migration-runbook.md), [Validation and rollback](06-validation-rollback-strategy.md), [Cost estimation and optimisation](07-cost-estimation-optimisation.md), [pricing assumptions](../cost/pricing-assumptions.csv), [target architecture diagram](../architecture/target-architecture.mmd)

## Executive summary

This register distinguishes repository statements from architectural deductions, illustrative planning scenarios and information still requiring validation. The project is fictional and design-only: no production measurements, AWS deployment, migration or load test has occurred. None of the illustrative usage scenarios below is an approved client requirement.

The existing saved AWS Pricing Calculator subtotal is **$1,930.76/month**, including two conventional NAT Gateways and the audited Site-to-Site VPN plus public IPv4 tunnel charges. This document does not change the calculator or convert that subtotal into a complete operating budget. The earlier $2,214–$2,702/month worksheet is withdrawn as a budget.

Route 53, CloudWatch and EFS price sensitivities have now been checked in AWS Pricing Calculator as unsaved scenarios; none is an approved client requirement or included in the saved estimate. EFS storage is the existing $300/month Calculator entry; usage scenarios exclude cross-AZ and migration-period charges. The saved subtotal is now $1,930.76/month. Priority decisions remain: (1) ALB traffic and LCU dimensions; (2) DNS authority, zone ownership and billable query mix; (3) CloudWatch metrics, alarms, log ingestion/retention and Flow Log scope/destination; (4) EFS capacity, throughput, lifecycle and cross-AZ use; (5) VPN traffic; and (6) migration source sizing, MGN/DMS/DataSync profiles, temporary network and overlap duration.

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
| Region and planning basis | `us-east-1`; USD; 730 hours/month | Documented |
| Application | Two Linux VMs, each 4 vCPU / 16 GiB; `t3.xlarge` is a pricing proxy; two-AZ ASG desired/minimum capacity 2 | Documented |
| Source database | PostgreSQL VM, 8 vCPU / 32 GiB; 500 GB source/logical-data assumption | Documented |
| Target database design | RDS PostgreSQL Multi-AZ DB instance deployment with one standby; exact version/class/storage performance open | Documented |
| Shared storage | Approximately 1 TB NFS source assumption; Regional EFS with mount targets in both app AZs | Documented |
| Archive storage | 500 GB S3 Standard planning assumption; private access through S3 Gateway Endpoint where appropriate | Documented |
| Network | VPC `10.30.0.0/16`, two AZs, two public/two app/two DB subnets, plus separate private MGN staging subnet | Documented |
| Network entry and egress | One internet-facing ALB, HTTPS 443, public subnets; two NAT Gateways with same-AZ application egress | Documented |
| Hybrid connectivity | One standard Site-to-Site VPN to VGW; transfer/routing/rate details open | Documented |
| Migration methods | MGN for Linux application servers; DMS full load plus CDC for PostgreSQL data; DataSync for NFS→EFS and archives→S3 | Documented |
| DNS and certificate | ACM certificate and Route 53 alias are implementation requirements; Route 53 zone ownership is conditional/unresolved | Documented |
| Business goals | 99.9% availability, RTO 4h, RPO 15m are targets only; not demonstrated | Documented |
| Calculator checkpoint | Current saved estimate subtotal $1,930.76/month, verified in calculator; includes NAT gateway-hours plus two NAT public IPv4 addresses ($73.00 NAT line) and separate VPN connection-hours plus two tunnel addresses ($43.80 VPN line) | Documented |
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
| A-005 | Route 53 authoritative DNS choice and public hosted-zone count | 1 / 1 / 2 zones are examples only; first 25 public zones price at $0.50 each/month; zone not entered in saved estimate pending hosting decision | Pending Validation | Business Owner; Infrastructure Lead validates delegation | Registrar/DNS-provider record, delegation plan, ownership confirmation, approved record inventory | Route 53 hosted-zone charge and DNS migration work | Determines if Route 53 is billable; ALB alias and certificate validation depend on domain control |
| A-006 | Monthly DNS query volume and routing features | 1 / 10 / 100 million per month as examples; if all are billable standard non-alias queries, sensitivity is $0.40 / $4 / $40; ALB A/AAAA alias queries are free | Pending Validation | Infrastructure Lead; Application Lead supplies demand profile | Existing DNS query reports or approved forecast; query types, routing policy and health checks | Route 53 query, health-check and routing-policy charges where applicable | Depends on A-005; DNS query type and alias target determine billable volume |
| A-007 | ACM public certificate domain validation and ALB association | One non-exportable public ACM certificate attached to ALB has no certificate fee; DNS validation can use existing DNS provider; domain and validation method unknown | Pending Validation | Infrastructure Lead; Business Owner confirms domain control | Domain ownership, validation method and ALB association plan | ACM charges where applicable; DNS validation record at authoritative provider; ALB HTTPS listener | Domain control is required; Route 53 hosting is not required for ACM validation |

#### Route 53 pricing discovery record

The architecture requires a public DNS record to reach the ALB and a public ACM certificate for HTTPS. It does not decide which provider hosts the authoritative zone: architecture and network documents make the Route 53 alias conditional on Route 53 being authoritative. The Route 53 icon in the diagram is not a DNS-provider decision. ACM DNS validation can be performed by publishing ACM's CNAME at the current provider. A free non-exportable ACM public certificate for an ALB does not require Route 53. No Route 53 health checks, failover, Traffic Flow, latency/geo/IP routing, Resolver endpoints, private zones or DNS query logging are documented.

The Calculator displayed $0.50 per public hosted zone/month and $0.40 per million standard queries for the first billion. ALB A/AAAA aliases do not incur Route 53 query fees. Unsaved sensitivity calculations (all example query volumes conservatively treated as billable non-alias standard queries) are:

| Scenario | Zones | Queries/month | Zone + query total/month |
|---|---:|---:|---:|
| Conservative | 1 | 1 million | $0.90 |
| Baseline | 1 | 10 million | $4.50 |
| High | 2 | 100 million | $41.00 |

If those queries were only aliases to the ALB, query charges would be $0 and hypothetical one/two-zone totals would be $0.50/$1.00 per month. Do not add any Route 53 amount until the Business Owner confirms DNS authority/zone count and the Infrastructure Lead documents billable query mix. All these scenario prices remain **Pending Validation**, not Approved. See cost guide for official references and Calculator evidence.

### C. CloudWatch and VPC Flow Logs

Metric/log volumes below are illustrative planning bounds. Separate service-included metrics from custom metrics and keep Flow Logs distinct from application logs.

| ID | Assumption / decision | Conservative / baseline / high scenario | Status | Responsible owner | Evidence required | Affected services / cost components | Dependencies |
|---|---|---|---|---|---|---|---|
| A-008 | Custom metric time series, excluding included service metrics | 10 / 50 / 200 time series; current Calculator sensitivity $3 / $15 / $60 per month at $0.30/time series first tier; dimensions/resolution TBD | Pending Validation | Operations Lead | Monitoring requirements matrix, metric names/dimensions/resolution and included-metric review | CloudWatch custom metrics, dashboards, alarm inputs | Derives from EC2, RDS, EFS, ALB, VPN, application and network monitoring needs; examples are not actual metrics or approval |
| A-009 | Application/system log ingestion and retention | 10 / 50 / 200 GB ingested/month; 30 / 90 / 365 days retained; app-log Calculator sensitivity at $0.50/GB is $5 / $25 / $100 before storage | Pending Validation | Operations Lead; Application Lead provides log-rate evidence | Sample or measured rate, source/filter inventory, destination, retention approval | CloudWatch Logs ingestion/storage, queries or metric filters where used | Depends on application, ALB/EC2/RDS logging and A-008 monitoring plan; rates are scenario-only |
| A-010 | Alarm count and evaluation policy | 10 / 25 / 100 standard-resolution alarm metrics; Calculator sensitivity $1 / $2.50 / $10 per month at $0.10/alarm metric; type/period/evaluation TBD | Pending Validation | Operations Lead | Alarm catalogue: resource, threshold, period, evaluations, missing-data treatment, notification path | CloudWatch alarms; SNS/notification costs if selected | Depends on A-008 metric inventory and A-001 workload/availability objectives; no alarm catalog is approved |
| A-011 | VPC Flow Logs scope, volume and retention | 5 / 50 / 500 GB/month as separate CloudWatch Vended Logs delivery examples; 30 / 90 / 365 days retention; Calculator delivery sensitivity $2.50 / $25 / $250 before storage | Pending Validation | Security Lead; Infrastructure Lead configures network scope | Approved VPC/subnet/interface scope, filters, destination, estimated log records and retention | CloudWatch Logs vended delivery and storage, or alternate destination ingestion/storage; queries/filters | Depends on VPC, VPN, NAT, endpoint, ALB and MGN staging design; coordinate with A-009 to prevent double count; CloudWatch destination is not approved |

#### CloudWatch Calculator sensitivity record

The following unsaved Calculator scenarios separately model application/system Standard Logs and VPC Flow Logs delivered to CloudWatch Logs as Standard Vended Logs. The register quantities remain illustrative. Flow Logs are not merged into app log input; the Calculator storage calculation does combine both volumes. Calculator one-month storage uses its displayed 15% compression factor. The scenarios exclude query/API use, dashboards, additional alarm forms, SNS, and other optional features.

| Scenario | Custom time series | Application logs GB/mo | Flow Logs GB/mo | Standard alarm metrics | Calculator total at 30 days |
|---|---:|---:|---:|---:|---:|
| Conservative | 10 | 10 | 5 | 10 | $11.57/mo |
| Baseline | 50 | 50 | 50 | 25 | $67.95/mo |
| High | 200 | 200 | 500 | 100 | $423.15/mo |

Independent retention extension for steady monthly ingestion and 15% compressed storage gives totals at 90 days of $11.70 / $68.85 / $429.45 and at 365 days of $12.32 / $72.98 / $458.33, respectively. This extension is an independent calculation, not an AWS Calculator result; the Calculator log model exposed only one-month retention. CloudWatch pricing sensitivity is not Approved. Keep these costs outside the saved $1,930.76/month subtotal until Operations and Security approve the sources, log destination, volume, retention, metric inventory/resolution, alarm design and notification path.

### D. EFS storage, throughput and transfer

The 1,000 GB EFS quantity is a documented planning assumption, not a measured used-capacity value. Two mount targets are documented topology. Do not add a separate mount-target charge without checking the current calculator model.

| ID | Assumption / decision | Conservative / baseline / high scenario | Status | Responsible owner | Evidence required | Affected services / cost components | Dependencies |
|---|---|---|---|---|---|---|---|
| A-012 | EFS capacity, growth and lifecycle distribution | 1,000 GB target planning quantity is documented; actual use/growth/tier mix unknown | Pending Validation | Infrastructure Lead; Application Lead validates scope | NFS inventory: used bytes, file count, growth, exclusions, access-age distribution, lifecycle/retrieval policy | EFS Regional Standard and lifecycle-tier storage, retrieval/transition charges | Determines storage and lifecycle cost; aligns DataSync scope A-019 |
| A-013 | EFS read/write throughput and throughput mode | Read/write volume: 100/25, 500/100, 2,000/500 GB/month; illustrative peak throughput 5/25/100 MiB/s | Pending Validation | Application Lead; Infrastructure Lead selects mode | NFS telemetry/benchmark: bytes read/written, sustained/peak rate, concurrency and access pattern; compare eligible throughput modes | EFS throughput charges and performance configuration | Depends on data profile A-012 and app concurrency; selected performance metrics should appear in A-008 |
| A-014 | EFS cross-AZ access and transfer | No volume approved; measure same-AZ versus cross-AZ traffic; two mount targets do not imply zero cross-AZ transfer | Pending Validation | Infrastructure Lead; Application Lead supplies placement/access evidence | ASG AZ placement and EFS client bytes by AZ | Cross-AZ data transfer and EFS client traffic | Depends on app placement and mount-target use; Flow Logs A-011 may help quantify |

#### EFS pricing evidence and scenario calculations

**Status remains Pending Validation for A-012, A-013 and A-014.** The existing 1,000 GB Regional file system quantity and one mount target per application AZ are documented; neither the usage scenarios nor the Calculator results approve a production workload. The saved estimate was not changed.

| Scenario | Standard storage | Read / write | Elastic read / write charges | Lifecycle / retrieval | Cross-AZ transfer | EFS steady-state modeled subtotal |
|---|---:|---:|---:|---|---|---:|
| Conservative (A-013 illustrative) | 1,000 GB = $300.00 | 100 / 25 GB/month | 100×$0.03 + 25×$0.06 = $4.50 | $0 in all-Standard/no-lifecycle scenario; actual unknown | Unpriced; A-014 bytes not measured | **$304.50/month** |
| Baseline (A-013 illustrative) | 1,000 GB = $300.00 | 500 / 100 GB/month | 500×$0.03 + 100×$0.06 = $21.00 | $0 in all-Standard/no-lifecycle scenario; actual unknown | Unpriced; A-014 bytes not measured | **$321.00/month** |
| High (A-013 illustrative) | 1,000 GB = $300.00 | 2,000 / 500 GB/month | 2,000×$0.03 + 500×$0.06 = $90.00 | $0 in all-Standard/no-lifecycle scenario; actual unknown | Unpriced; A-014 bytes not measured | **$390.00/month** |

These are unsaved AWS Pricing Calculator scenario results in us-east-1, not independent production forecasts. Totals exclude cross-AZ transfer, lifecycle/retrieval, backup and taxes. The $300 storage amount matches the existing EFS calculator line. AWS states Regional Standard storage has baseline throughput of 50 KB/s per GB; 1,000 GB therefore provides 50 MB/s. In the unsaved Provisioned Throughput comparison, 5/25 MB/s requested with 1,000 GB Standard produced $0 added throughput and $300 total; 100 MB/s produced 50 billable MB/s × $6 = $300, or $600 total with storage. This comparison does not imply peak rates must be provisioned. At 730 hours, average monthly read-plus-write rates from the illustrative volumes are approximately 0.0487 / 0.2336 / 0.9740 MiB/s; the separate 5 / 25 / 100 MiB/s peaks remain hypothetical.

For lifecycle sensitivity only, 5% Standard / 15% IA / 80% Archive storage at 1,000 GB costs $23.80 monthly ($15.00 + $2.40 + $6.40). Baseline read/write throughput remains $21.00; 75 GB IA reads cost $0.75 and 400 GB Archive reads cost $12.00. With no new tiering input, this totals **$57.55/month**. With 150 GB/month tiered to IA ($1.50) and 800 GB/month tiered to Archive ($24.00), total is **$83.05/month**. The tier distribution, reads and monthly tiering are illustrative only. A one-time transition of 150/800 GB is $25.50 at the calculator rates; do not annualize one-time transition fees. Lifecycle access modes/minimum storage constraints and file age/size distribution require evidence.

Regional EFS client access to a mount target in a different AZ can incur $0.01/GB transferred into the AZ and $0.01/GB out, while same-AZ access avoids the cross-AZ rate. Two mount targets allow an AZ-local endpoint but do not prove clients use it. A-014 has no approved quantity, so the cross-AZ cost remains unpriced in each scenario. Measure application placement and EFS bytes by client AZ/mount-target AZ.

A-019's initial 1,500 GB derived quantity at current DataSync Basic $0.0125/GB is **$18.75 one-time** (not monthly operating cost). Its 1% / 5% / 20% delta examples (15 / 75 / 300 GB) cost **$0.19 / $0.94 / $3.75 one-time**. EFS destination writes may separately invoke Elastic write-throughput charges: if 1,000 GB initial NFS data and 15/75/300 GB delta are written to EFS, the illustrative write charges are $60.00 and $0.90/$4.50/$18.00, respectively. These are migration-period service charges distinct from the DataSync per-GB fee and ongoing application EFS read/write. S3 request costs for the 500 GB archive portion, and actual transfer paths over VPN/NAT/endpoints remain unpriced. The DataSync source inventory is still unverified.

### E. VPN and steady-state network

| ID | Assumption / decision | Conservative / baseline / high scenario | Status | Responsible owner | Evidence required | Affected services / cost components | Dependencies |
|---|---|---|---|---|---|---|---|
| A-015 | Monthly VPN data transfer, direction and destination | 100 GB / 1 TB / 10 TB per month as sensitivity examples | Pending Validation | Infrastructure Lead; Application Lead identifies workload flows | Source utilization or traffic model by direction, destination and flow type | VPN data transfer, applicable AWS data transfer; on-premises circuit cost is outside calculator | Depends on routes/source CIDRs and migration traffic A-017–A-023; informs Flow Log estimate A-011 |
| A-016 | VPN routing, tunnel design and public IPv4 price treatment | One standard VGW VPN documented; static/BGP and tunnel/address treatment unresolved | Pending Validation | Infrastructure Lead | Approved Customer Gateway/VGW configuration, regional calculator product selection and current pricing review | VPN connection-hours, public IPv4 address-hours if applicable, transfer | Needed to validate VPN subtotal; relates to migration network A-020–A-022 |

#### Network pricing audit notes for A-015 / A-016 / A-020–A-022

No traffic quantity or endpoint inventory has been promoted to an approved requirement. The A-015 100 GB / 1 TB / 10 TB points can be used as sensitivity inputs only. At the AWS $0.09/GB first outbound data tier and 1 TB = 1,024 GB, an all-inbound VPN scenario has $0 AWS data-transfer-out cost; an all-outbound scenario is $0 / $83.16 / $912.60 if the account-wide 100 GB monthly allowance remains, or $9 / $92.16 / $921.60 if it has been used. These are independent price calculations, not Calculator results. Mixed-direction traffic is priced only for its measured AWS egress. VPN's existing $36.50 connection and $7.30 tunnel IPv4 charges are already in its $43.80 saved entry.

The separate saved NAT Calculator line is $65.70/month, equal to 2 × 730 hours × $0.045/hour; its config summary shows two conventional NAT Gateways and no NAT public IPv4 quantity. AWS currently charges $0.005/address-hour; two NAT EIPs would add $7.30/month if not counted elsewhere. Mark this a **likely omission pending detailed Calculator reconciliation**, not an approved subtotal correction. Do not confuse its $0.045/GB data-processing meter with VPN bytes: if the A-015 100/1,024/10,240 GB points were independently used as NAT processed-volume arithmetic, charges are $4.50/$46.08/$460.80, but no NAT quantity is established. Internet data-out may additionally apply.

An S3 Gateway Endpoint has no endpoint hourly or processing fee. Interface endpoints are not selected. Current us-east-1 reference rates are $0.01 per endpoint ENI-AZ-hour and $0.01/GB processed; one service endpoint in both AZs would be $14.60/month fixed, before processing, as a unit illustration only. Determine service endpoint necessity and AZ coverage from actual private subnet flows/service dependencies; do not infer a required count from SSM or migration tool names alone. Same-AZ NAT routing is documented; validate route tables and actual flow bytes. Network cost decisions depend on A-014 EFS cross-AZ use, A-011 Flow Log scope/destination, A-015 VPN direction, A-016 tunnel/routing decisions, and temporary migration routes A-020–A-022.

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

#### Migration-period pricing status

All entries remain in the separate migration group and **Pending Validation** except A-019's data quantity, which remains **Derived** and unverified. DataSync Basic at $0.0125/GB gives $18.75 for the derived 1,500 GB initial quantity and $0.19/$0.94/$3.75 one-time for 15/75/300 GB illustrative final deltas. This is the DataSync service fee only; destination EFS/S3 activity, network and duration are separate.

AWS MGN's service charge is free for 2,160 continuous hours per source server. MGN-provisioned replication infrastructure and launched test/cutover compute/storage are chargeable during that window. Two source servers are in scope from the strategy; disks, used bytes, change rate, replication resources, schedules and test/cutover hours are not. A-017's three-month scenario defined as 3 × 730 hours is 2,190 hours—30 hours past the MGN free period—but no service rate or resource amount is included here. DMS is documented as PostgreSQL full load plus CDC; DBA profiling must determine provisioned instance class or Serverless DCU, storage and runtime. The current AWS DMS pricing model charges for chosen hourly capacity; no class/DCU or arbitrary runtime is entered. A-023's 1-week / 1-month / 3-month and parallel-running scenarios remain provisional; calculate source/target overlap, test launches, temporary routes and eventual source retirement on the approved calendar. Network traffic A-015/A-021 is not DataSync transfer volume, and migration costs are not steady-state application EFS traffic.


### Network reconciliation supplement — 8 November 2026

The verified calculator baseline is **$1,930.76/month ($23,169.12 annualised)**. The NAT line is $73.00: two gateways × 730 hours × $0.045 = $65.70, plus two public IPv4 addresses × 730 hours × $0.005 = $7.30. The separate VPN line remains $43.80 and includes its own two tunnel addresses. NAT processed bytes remain a zero placeholder. NAT processing sensitivities are $4.50/$46.08/$460.80 for 100/1,024/10,240 GB, independent and excluded. VPN all-outbound sensitivities remain $0/$83.16/$912.60 with account-wide 100 GB allowance available, or $9/$92.16/$921.60 if already consumed. None of these traffic scenarios is approved.

| ID | Decision | Status | Owner | Evidence | Cost/dependency |
|---|---|---|---|---|---|
| A-024 | NAT processed GB and destination split | Pending Validation | Application Lead; Infrastructure verifies routes | NAT metrics/Flow Logs or workload egress inventory by destination and route | NAT processing, standard egress, possible cross-AZ; depends on S3 endpoint routes and A-011 |
| A-025 | Interface endpoint services, count, AZ coverage and egress policy | Pending Validation | Security and Infrastructure Leads; workload owners confirm calls | App/staging service dependency matrix, allowed egress policy, resilience/AZ decision | PrivateLink hours/GB and NAT bytes avoided/remaining; depends on SSM, CloudWatch, Secrets Manager, MGN/DataSync and A-020/A-022 |
| A-026 | App-to-EFS cross-AZ selection and volume | Pending Validation | Application Lead; Infrastructure verifies | Per-AZ mount/DNS configuration and traffic telemetry or representative test | EC2 cross-AZ transfer; depends on EFS A-012–A-014 and app placement |
| A-027 | App-to-RDS writer AZ traffic/failover profile | Pending Validation | DBA and Infrastructure Lead | RDS writer AZ history, app AZ distribution, DB flow bytes by AZ and failover evidence | EC2-side cross-AZ transfer; Multi-AZ replication included; depends on writer placement |
| A-028 | Temporary migration paths, bytes, AZs and duration | Pending Validation | Migration Lead; Infrastructure/Security/DBA/storage owners | Flow matrix for MGN TCP1500/source to staging and service endpoints, DMS source→replication→RDS, DataSync agent/service/storage; direction, GB, route, AZ, duration | Migration-only NAT, PrivateLink, VPN/data-out, cross-AZ, staging and S3 requests; depends on A-015–A-023 |
| A-029 | Active MGN replication and target/source overlap calendar | Pending Validation | Migration Lead; Business Owner approves | Signed start/stop, test, cutover, rollback, stabilisation and retirement schedule per wave | 2,160 MGN free active hours per source; chargeable staging resources; DMS runtime; network; incremental overlap; depends on A-017–A-023 |

Endpoint inventory remains conditional, not an approved endpoint count. Documented S3 Gateway Endpoint is no-fee. Steady-state interface candidates are SSM if private management is selected, CloudWatch Logs/Monitoring if configured publishers need private service paths, and Secrets Manager if runtime API access must be private. Same-AZ NAT is already a public HTTPS alternative. Migration private MGN may use MGN, EC2 and S3 interface endpoints plus S3 Gateway Endpoint; DataSync may use its VPC service endpoint over VPN. Each interface endpoint costs $0.01 per endpoint-AZ-hour plus $0.01/GB first tier; one in both app AZs is $14.60/month fixed. Endpoint security groups restrict client ingress (commonly TCP443; DataSync control path uses service-specific TCP1024–1064) alongside IAM/endpoint/bucket policies. No endpoint cost was added.

Cross-AZ paths: same-AZ app→EFS mount and app→NAT are design intent, not measured routes/bytes; ALB↔EC2 private-IP traffic in one VPC is free; app→RDS traffic can be cross-AZ when the writer AZ differs, while standby replication is included. On-prem→AWS VPN traffic is inbound; AWS responses may count as egress. MGN/DMS/DataSync paths are migration-only. These are billing exposure classifications, not traffic measurements. See A-011, A-014–A-029.

## Decision dependency map

~~~mermaid
flowchart TD
  traffic[Application profile A-001/A-002] --> alb[ALB LCU A-003/A-004]
  rules[Listener rules A-003] --> alb
  dns[DNS authority and queries A-005/A-006] --> cert[Certificate and ALB DNS A-007]
  alb --> cw[Metrics and alarms A-008/A-010]
  appLogs[App logs and retention A-009] --> cw
  vpc[VPC, AZ, NAT, VPN, endpoints] --> flow[Flow Logs A-011]\n  natBytes[NAT processed GB A-024] --> net[egress and cost]\n  endpoints[Endpoint choice A-025] --> net\n  efsPlacement[EFS cross-AZ A-026] --> efsData\n  dbWriter[Writer AZ traffic A-027] --> net\n  migrationPaths[Migration paths A-028] --> net
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
5. **VPN and network inputs (A-015/A-016, A-020–A-022, A-024–A-028):** quantify traffic/direction, verify selected VPN/tunnel pricing and settle migration subnet routes/endpoints/NAT.
6. **Migration sizing and schedule (A-017–A-023, A-028–A-029):** inventory MGN sources, complete DBA/DMS sizing, inventory DataSync data, and approve overlap/retirement dates.
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
