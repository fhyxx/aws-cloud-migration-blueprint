# 07 — AWS Cost Estimation and Optimisation

**ID:** CLI-AWS-COST-007 | **Version:** 1.8 | **Status:** Partial calculator baseline saved — usage scenario review open  
**Region:** `us-east-1` | **Currency:** USD | **Planning month:** 730 hours

## Executive decision

The earlier **$2,214–$2,702/month** range is retained only as a historical, illustrative worksheet result. **Do not use it as a budget, quotation, expected bill or customer commitment.** The earlier worksheet used unverified RDS compute/storage rates and a VPN hourly example from a different Region and connection design. Those values do not support a defensible current total.

A partial estimate is saved in AWS Pricing Calculator. Its currently verified subtotal is **$1,930.76/month** and **$23,169.12 annualised**. This is a calculator result for the entered configurations, not a complete operating budget, approved budget or proof of production workload suitability. Material usage-dependent items and migration costs remain unpriced. The saved RDS configuration is a sizing proxy pending PostgreSQL version, workload and compatibility validation. See [the Assumptions and Decisions Register](08-assumptions-decisions-register.md).

## Architecture quantities to price

| Service | Current design input | Pricing status / required decision |
|---|---|---|
| EC2 (including attached EBS in the saved EC2 estimate) | 2 × Linux `t3.xlarge`, 730 h/month; 2 × 100 GB gp3 | **$274.94/month, calculator result.** Benchmark sustained CPU and compare a non-burstable family; confirm the gp3 sizing assumptions. |
| EBS | 2 × 100 GB gp3 (200 GB total), represented in the saved EC2 estimate | Included in the $274.94/month EC2 calculator entry; do not add it again. Validate workload performance needs. |
| RDS PostgreSQL | `db.m6i.2xlarge`, Multi-AZ DB instance deployment, 500 GB gp3 input, 12,000 IOPS, 500 MiB/s throughput | **$1,227.52/month, calculator result.** The current entry uses one configured logical DB with Multi-AZ selected. PostgreSQL version, compatibility and workload suitability remain unresolved; backup usage remains unpriced. |
| RDS backups | Usage-dependent | Calculate retention, changed-data volume and snapshot needs; avoid a flat unsupported allowance. |
| EFS | 1,000 GB Regional Standard; two app-AZ mount targets; Elastic throughput provisional | **$300.00/month, calculator result** for Standard storage only. Unsaved Calculator scenarios using A-013 read/write quantities produce $304.50 / $321.00 / $390.00 per month (conservative / baseline / high), excluding cross-AZ transfer and unvalidated lifecycle activity. |
| S3 | Standard, 500 GB | **$11.50/month, calculator result.** Requests, retrieval and transfer remain zero placeholders; validate lifecycle and retention requirements. |
| NAT Gateway | 2 conventional public gateways, same-AZ app egress, 730 hours each, 2 public IPv4 addresses | **$73.00/month, calculator result** ($65.70 gateway hours + $7.30 IPv4). Processed data remains a zero placeholder; internet egress and cross-AZ transfer are not included. |
| ALB | 1 internet-facing ALB, HTTPS 443 | Not included in the saved calculator subtotal. Unsaved AWS Pricing Calculator scenario results from the register are $19.35 / $28.11 / $74.83 per month (conservative / baseline / high), including 730 ALB hours and scenario LCU use. These are illustrative, not measured or approved client requirements, and are excluded from the saved subtotal; validate workload before adopting. |
| Site-to-Site VPN | 1 standard connection to VGW, public IPv4 tunnel endpoints | **$43.80/month combined in the saved VPC entry:** $36.50 connection-hours plus $7.30 for two in-use public IPv4 address-hours. VPN transfer is unpriced. The 22 working days/month summary field belongs to the unselected Client VPN section; it does not affect the Site-to-Site calculation (1 × 730 h × $0.05/h = $36.50). |
| Interface endpoints | Count and AZ coverage not final | Inventory each endpoint and AZ; price endpoint-hours and data processing. S3 Gateway Endpoint has no hourly endpoint charge. |
| CloudWatch | Logs, metrics, alarms and Flow Logs | Unsaved illustrative Calculator sensitivities: **$11.57 / $67.95 / $423.15 per month** at 30-day retention (conservative / baseline / high). At 90-day retention, independent storage-adjusted totals are $11.70 / $68.85 / $429.45; at 365 days, $12.32 / $72.98 / $458.33. Inputs remain provisional and are excluded from saved subtotal. |
| Internet/data transfer | 100 GB was a placeholder | Replace with direction, destination, monthly volume and applicable free tiers. |
| ACM / Route 53 | Public ALB certificate and DNS record | **Route 53 excluded from saved subtotal pending DNS authority decision.** Unsaved Route 53 sensitivities for the register’s 1/1/2 zones and 1/10/100 million standard-query examples are $0.90 / $4.50 / $41.00 monthly, if every query is billable non-alias traffic. A Route 53 ALB alias has no query charge; an authoritative public zone remains $0.50/month per zone. DNS owner, actual billable query volume and certificate validation method remain unresolved. |
| MGN / DMS / DataSync | Temporary migration-period use | Model separately as one-time/overlap costs, including staging EC2/EBS, replication duration, DMS compute, DataSync transfer and temporary network resources. |

## VPN pricing audit

The saved VPC calculator entry was audited without changing its Site-to-Site connection quantity or duration. The calculation details show **1 connection × 730 hours × $0.05/connection-hour = $36.50/month** in `us-east-1`. The entry description's 24 hours/day converts to 730 hours/month using the calculator's standard planning month. The configuration summary's separate **22 working days/month** value is a default in the Client VPN section; Client VPN is not selected, so this field is unrelated to the Site-to-Site charge.

The calculator entry did not previously include public IPv4. AWS documents two tunnels per Site-to-Site VPN connection, each with a unique public IPv4 endpoint, and separately states that public IPv4 addresses assigned to Site-to-Site tunnel endpoints incur the standard in-use IPv4 charge. The calculator's public IPv4 feature at two in-use addresses showed **2 × 730 × $0.005 = $7.30/month**. This is now included in the existing VPC estimate entry; combined VPN-related total is **$43.80/month**. The estimate total changed from **$1,916.16 to $1,923.46/month**, and annualised total from **$22,993.92 to $23,081.52**. The 22-day Client VPN field remains visible in the configuration summary but is not a selected pricing dimension. VPN transfer remains unpriced.

AWS references:
- [AWS Site-to-Site VPN pricing — tunnel public IPv4 charges](https://aws.amazon.com/vpn/pricing/)
- [Amazon VPC pricing — in-use public IPv4 at $0.005/address-hour](https://aws.amazon.com/vpc/pricing/)
- [AWS Site-to-Site VPN tunnel options — two tunnels and unique public IPs](https://docs.aws.amazon.com/vpn/latest/s2svpn/VPNTunnels.html)

## ALB workload sensitivity (independent calculation)

The assumptions register's conservative, baseline and high cases are illustrative scenarios, not measured traffic or approved client requirements. They were entered separately in the AWS Pricing Calculator's `us-east-1` ELB form and each displayed calculation was verified; the draft was canceled without saving an ALB entry. These are calculator scenario results, not independent calculations, and are excluded from the $1,930.76 saved subtotal.

AWS's ELB pricing page describes the hourly ALB charge ($0.0225/hour) and LCU charge ($0.008/LCU-hour) in `us-east-1`. For EC2 targets, one LCU covers up to 25 new connections/second, 3,000 active connections/minute, 1 GB processed/hour, or 1,000 rule evaluations/second after the first 10 rules per request. Applying the register's scenarios and taking the largest dimension gives:

| Scenario | Register workload inputs | Dominant LCU dimension | Approx. LCU-hours/month | Independent ALB estimate/month |
|---|---|---|---:|---:|
| Conservative | 0.5 new connections/s; 100 active; 5 requests/s; 0.5 GB/h; 5 rules/request | Processed bytes (0.5 LCU) | 365 | $19.35 |
| Baseline | 2 new connections/s; 500 active; 20 requests/s; 2 GB/h; 15 rules/request | Processed bytes (2 LCU) | 1,460 | $28.11 |
| High | 10 new connections/s; 3,000 active; 100 requests/s; 10 GB/h; 25 rules/request | Processed bytes (10 LCU) | 7,300 | $74.83 |

Calculation: 730 × $0.0225 ALB-hour base + (scenario LCU-hours × $0.008). Rounded to cents. The workload dimensions above were entered as representative values across the 730-hour month solely for sensitivity analysis. The calculator's displayed dominant LCU dimension was processed bytes for each case. Real LCU billing uses the highest dimension in each hour and actual hourly pattern, so these figures are not forecasts. ALB capacity and charges remain a pricing gate pending workload evidence and a saved calculator entry.

AWS reference: [Elastic Load Balancing pricing — ALB LCU dimensions and `us-east-1` examples](https://aws.amazon.com/elasticloadbalancing/pricing/).

## Route 53 and DNS pricing discovery

The architecture requires a public DNS name to reach the internet-facing ALB and an ACM public certificate for HTTPS. It does **not** assign authoritative DNS hosting to Route 53: the target architecture and network design state “if Route 53 hosts the zone” / “if Route 53 is authoritative.” The diagram's Route 53 icon does not override that explicit conditional language. The DNS provider, registrar/delegation owner and hosted-zone quantity therefore remain unresolved. Do not assume a domain transfer or Route 53 hosted zone.

Authoritative zone hosting and an ALB alias are separate things:

- If Route 53 hosts the public zone, AWS currently prices the first 25 hosted zones at **$0.50/zone/month**. The Pricing Calculator showed this same global-service rate.
- An A/AAAA Route 53 alias query to an Elastic Load Balancer is **not charged per query**. The DNS query itself can therefore be $0 even at high volumes, but the hosted-zone fee still applies if Route 53 hosts the zone.
- Non-alias public DNS queries are charged. The current AWS Regions standard rate is **$0.40 per million queries** for the first 1 billion monthly queries; Route 53's service is global, so us-east-1 selection does not imply a different authoritative DNS rate.
- If DNS remains with another provider, adding or changing the record and ACM validation CNAMEs there does not create a Route 53 hosted-zone charge. ACM DNS validation does not require Route 53. A public, non-exportable ACM certificate attached to an integrated service such as ALB has no certificate fee.
- The design calls for no Route 53 health checks, DNS failover, Traffic Flow policy, latency/geolocation/IP routing, private hosted zone, Resolver endpoint, or DNS query logging. ALB target health checks are not Route 53 health checks. No optional Route 53 features were entered.

The register's existing values are scenario quantities, not observed or approved requirements: **1 / 1 / 2 public zones** and **1 million / 10 million / 100 million monthly queries**. Calculator scenarios were entered and the resulting draft was canceled without saving:

| Scenario | Hosted zones | Assumed billable standard non-alias queries/month | Hosted-zone cost | Query cost | Total sensitivity/month |
|---|---:|---:|---:|---:|---:|
| Conservative | 1 | 1 million | $0.50 | $0.40 | **$0.90** |
| Baseline | 1 | 10 million | $0.50 | $4.00 | **$4.50** |
| High | 2 | 100 million | $1.00 | $40.00 | **$41.00** |

The calculator displayed the same rates and totals for these hypothetical inputs. They assume all example queries are billable standard non-alias queries, making them sensitivity bounds rather than an actual DNS bill. If the workload consists only of A/AAAA aliases to this ALB, the query component is $0; the one-zone Route 53 hosting case would be **$0.50/month**, and two zones would be **$1.00/month**. The architecture does not document query distribution between ALB aliases and other DNS record types, so actual query pricing is unknown. Route 53 DNS query logging, if later required, has no Route 53 logging fee but would incur CloudWatch destination ingestion/storage costs.

**Decision:** Do not add a Route 53 item to the saved estimate now. First confirm whether the business's authoritative zone stays with its current provider or is delegated to Route 53, the number of public zones, who controls registrar/delegation, record inventory and query evidence. If the owner confirms one Route 53 hosted zone and only ALB alias records, a provisional calculator line of **one public hosted zone, no billable query volume, $0.50/month** is justified; label it conditional pending formal approval. If ownership remains external, leave Route 53 at **$0 in this AWS estimate**, while retaining the external DNS provider cost as out of scope / unknown. No DNS option is Approved.

AWS references: [Route 53 pricing](https://aws.amazon.com/route53/pricing/), [Route 53 alias records and ELB query pricing](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html), [ACM DNS validation with a non-Route 53 provider](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html), and [ACM public certificate pricing for integrated services](https://aws.amazon.com/certificate-manager/pricing/).

## CloudWatch monitoring and Flow Logs pricing discovery

CloudWatch metrics, logs, alarms and VPC Flow Logs are documented monitoring functions, but the counts, log rates, retention periods, alarm policy and Flow Log destination are still pending validation. The register's **10/50/200 custom metric time series**, **10/50/200 GB/month application/system log ingestion**, **10/25/100 standard alarm metrics**, and **5/50/500 GB/month Flow Log volume** are illustrative sensitivity inputs only.

The three draft scenarios used the current Pricing Calculator in us-east-1. Application/system logs were entered as Standard Logs data ingested; VPC Flow Logs were entered separately as Standard Vended Logs delivered to CloudWatch Logs. The draft was canceled without saving. No log-query scanning, API requests, dashboards, composite/high-resolution/Metric Insights alarms, notifications, or additional observability features were invented or entered.

| Scenario | Custom time series | App/system logs | VPC Flow Logs to CloudWatch | Standard alarms | Calculator total at 30-day retention |
|---|---:|---:|---:|---:|---:|
| Conservative | 10 | 10 GB/mo | 5 GB/mo | 10 | **$11.57/mo** |
| Baseline | 50 | 50 GB/mo | 50 GB/mo | 25 | **$67.95/mo** |
| High | 200 | 200 GB/mo | 500 GB/mo | 100 | **$423.15/mo** |

The Calculator's displayed components were respectively $0.30 per custom metric (the first tier), $0.50/GB for Standard Logs ingestion, $0.50/GB for VPC/Vended Logs delivered to CloudWatch Logs, $0.03/GB-month for archived storage, and $0.10 per standard-resolution alarm metric. It estimated stored log volume at **15% of combined monthly ingestion** and exposed a one-month retention storage assumption. Calculator details:
- Conservative: metrics $3.00; app logs $5.00; Flow Logs $2.50; storage $0.0675; alarms $1.00 = $11.5675, displayed **$11.57**.
- Baseline: metrics $15.00; app logs $25.00; Flow Logs $25.00; storage $0.45; alarms $2.50 = **$67.95**.
- High: metrics $60.00; app logs $100.00; Flow Logs $250.00; storage $3.15; alarms $10.00 = **$423.15**.

The Calculator exposes only its one-month storage/archival assumption for this log model. To show the register's 90- and 365-day retention cases, storage was independently extended with a steady monthly ingestion assumption: combined log GB/month × 15% compression factor × $0.03/GB-month × retention days/30. This storage extension is **an independent scenario calculation, not a Calculator result** and should be replaced once retention and log lifecycle requirements are approved.

| Scenario | 30 days (Calculator) | 90 days (independent storage extension) | 365 days (independent storage extension) |
|---|---:|---:|---:|
| Conservative | $11.57 | $11.70 | $12.32 |
| Baseline | $67.95 | $68.85 | $72.98 |
| High | $423.15 | $429.45 | $458.33 |

These totals exclude possible account free-tier benefits, dashboards, alarm queries, log queries/scanned bytes, metric API requests, data protection, SNS/notification charges, traces, Database Insights additions, third-party tooling and any cost for another destination. The scenario count for metrics is interpreted as time series, not metric datapoints. Default AWS service metrics may be included, but detailed monitoring and custom dimensions can add billable time series; confirm what is included before adoption. Flow Logs are priced separately from application/system ingestion to avoid double counting; their service delivery rate applies only if CloudWatch Logs is selected as destination. An S3 destination has different charges and has not been priced. The us-east-1 calculator and AWS pricing examples support the rates above; actual monthly usage and applicable free tier depend on account configuration.

**Decision:** Keep CloudWatch out of the saved subtotal until Operations/Security approve the metric inventory, log sources/volume, Flow Log scope and destination, retention, alarms, resolution and notification plan. Use the baseline scenario only as an explicitly **Provisional** portfolio sensitivity if a labeled scenario estimate is required; it is not an approved planning value. Exports from the Calculator must preserve the separate line components and identify every remaining excluded usage feature.

AWS references: [CloudWatch pricing (including N. Virginia rates, logs, metrics and alarms)](https://aws.amazon.com/cloudwatch/pricing/), [VPC Flow Logs destinations and vended-log charging](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html).

## EFS storage, throughput, lifecycle and transfer audit

The documented design remains **1,000 GB Regional EFS Standard** with one mount target in each application Availability Zone. The saved estimate's $300.00/month EFS line is the calculator result for 1,000 GB Standard storage in us-east-1; it does not include the presently zero throughput, lifecycle, retrieval or client-transfer quantities. Regional Standard storage is billed by average stored GB-month. AWS pricing currently shows $0.30/GB-month in this Calculator entry. The two mount targets are topology, not two separately priced file systems; no mount-target line item appeared in the Calculator.

### Elastic and Provisioned Throughput

The current AWS EFS pricing page recommends Elastic Throughput for most workloads. Elastic charges the read and write bytes transferred, at the Calculator's current us-east-1 rates of $0.03/GB read and $0.06/GB write. Provisioned Throughput charges $6 per MB/s-month above the Standard-storage included baseline (50 KB/s per GB; 1,000 GB therefore supplies 50 MB/s baseline). The calculator validation showed requested provisioned rates of 5 and 25 MB/s incur $0 additional throughput charge, while 100 MB/s incurs $300/month (50 billable MB/s × $6); with Standard storage, those scenario totals are $300 / $300 / $600 monthly. This is a capacity-price comparison, not evidence that the workload needs provisioned throughput. Peak and sustained measurements are required.

### A-013 Elastic Throughput scenarios (unsaved Calculator validation)

| Scenario | Read / write GB-month | Storage | Elastic throughput | Cross-AZ transfer | Lifecycle / retrieval | Priced monthly scenario total |
|---|---:|---:|---:|---|---|---:|
| Conservative | 100 / 25 | $300.00 | $3.00 + $1.50 = $4.50 | Unpriced; measured share unknown | $0 in this all-Standard/no-lifecycle model; actual unknown | **$304.50** |
| Baseline | 500 / 100 | $300.00 | $15.00 + $6.00 = $21.00 | Unpriced; measured share unknown | $0 in this all-Standard/no-lifecycle model; actual unknown | **$321.00** |
| High | 2,000 / 500 | $300.00 | $60.00 + $30.00 = $90.00 | Unpriced; measured share unknown | $0 in this all-Standard/no-lifecycle model; actual unknown | **$390.00** |

The totals are **modeled EFS service subtotals**, not actual client bills, and exclude cross-AZ data transfer, lifecycle transitions/retrieval, backup, taxes and other unmodeled features. The traffic quantities are illustrative A-013 values, not measurements or approved requirements. They do not change the saved estimate or its $1,930.76/month subtotal. At 730 hours and 1,024 MiB/GB, the read-plus-write sustained averages implied by these monthly totals are about 0.0487 / 0.2336 / 0.9740 MiB/s; A-013's 5 / 25 / 100 MiB/s figures are separate illustrative peaks, not sustained billing quantities.

AWS bills applicable cross-AZ EFS access at the EC2 cross-AZ transfer rates: $0.01/GB transferred into an AZ and $0.01/GB out of an AZ. Same-AZ access to a mount target is not charged that cross-AZ rate. Consequently two AZ mount targets support local access but do not prove all clients resolve/use their same-AZ target. No A-014 quantity is approved, so cross-AZ charges are excluded and remain unpriced; price with client/mount-target AZ telemetry and the actual bytes in each direction.

### Lifecycle sensitivity (not a client requirement)

For an additional Calculator sensitivity only, the Calculator's industry-average hint was entered as 5% Standard / 15% IA / 80% Archive on 1,000 GB: storage is $15.00 + $2.40 + $6.40 = **$23.80/month**. Applying baseline EFS Elastic Throughput (500 GB read, 100 GB write = $21.00), 75 GB/month of IA reads ($0.75) and 400 GB/month of Archive reads ($12.00), with **no new monthly tiering volume**, gives access/retrieval of $12.75 and **$57.55/month total**. These percentages and retrieval quantities are provisional sensitivity inputs; Archive is available only with Regional Elastic Throughput in the configured Calculator path.

If 150 GB/month transitions to IA and 800 GB/month transitions to Archive, the Calculator adds $1.50 and $24.00 transition charges. With the same storage, reads and throughput, the result is **$83.05/month**. That is a recurring monthly transition scenario, not a one-time migration amount. A single one-time transition of those same quantities would total $25.50 under the displayed rates; actual transition volumes, IA/Archive minimum-duration and minimum-size effects, retrieval profile and lifecycle policy must be established from file inventory. Do not use the calculator's suggested 5/15/80 mix as a business requirement.

### DataSync migration is separate

AWS DataSync Basic pricing is currently $0.0125 per GB copied. The register's derived initial transfer of 1,500 GB (1,000 GB EFS target + 500 GB S3 archive target, still unverified) yields **$18.75 one-time DataSync service usage**. Final-delta examples of 15 / 75 / 300 GB (1% / 5% / 20% of 1,500 GB) cost **$0.19 / $0.94 / $3.75 one-time** when rounded to cents. DataSync pricing excludes destination storage/request/transfer charges. DataSync copying to EFS can additionally create destination EFS write-throughput activity; at $0.06/GB, the 1,000 GB EFS portion would be $60.00 and the delta examples would be $0.90 / $4.50 / $18.00 **if** those bytes are written to EFS under Elastic Throughput. This is a migration-period destination-service sensitivity, not recurring application access. The 500 GB archive portion's S3 PUT/request costs remain unpriced because object counts and request patterns are unknown. VPN/NAT/endpoint/transfer path costs are separate and remain unresolved.

The Calculator service scenarios above were configured unsaved and canceled; no estimate item was added. Sources: [AWS EFS pricing](https://aws.amazon.com/efs/pricing/), [EFS performance and throughput guidance](https://docs.aws.amazon.com/efs/latest/ug/performance.html), [how EFS mount targets work](https://docs.aws.amazon.com/efs/latest/ug/how-it-works.html), [EFS lifecycle management](https://docs.aws.amazon.com/efs/latest/ug/enable-lifecycle-management.html), [EFS FAQ on class minimums](https://aws.amazon.com/efs/faq/), and [AWS DataSync pricing](https://aws.amazon.com/datasync/pricing/).

## RDS billing treatment

The design is specifically a **Multi-AZ DB instance deployment with one standby**, not a Multi-AZ DB cluster. AWS bills primary and standby instance-hours and provisioned storage for both copies. In the current saved calculator entry, the UI shows one configured logical DB, Multi-AZ selected, and 500 GB gp3 input; the resulting line item is $1,227.52/month. Its displayed calculation is $1,039.52 compute ($1.424/hour × 730), $115.00 storage (500 GB × $0.23/GB-month at the calculator's displayed Multi-AZ rate), and $73.00 Database Insights. The calculator entry applies its Multi-AZ rates to the configured quantity; **do not manually double the 500 GB input or the $1,227.52 result**. This verifies only what the calculator currently calculates. It is not independent proof that `db.m6i.2xlarge`, the PostgreSQL version, IOPS/throughput or performance is suitable for production. Confirm those through version/compatibility review and workload measurement.

AWS references:
- [RDS for PostgreSQL pricing and deployment options](https://aws.amazon.com/rds/postgresql/pricing/)
- [RDS Multi-AZ DB instance billing details](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_OnDemandDBInstances.html)

## Network traffic and temporary migration pricing audit

### Steady-state VPN direction matters

The saved VPN line remains $43.80/month: $36.50 for one standard connection at 730 hours plus $7.30 for two in-use public IPv4 tunnel endpoints. The saved entry continues to have no approved data transfer quantity. AWS Site-to-Site VPN has no separate per-GB service fee, but standard AWS data transfer out charges apply to data sent from AWS through the connection. Inbound traffic is not charged as AWS data transfer out. The A-015 100 GB / 1 TB / 10 TB values are illustrative monthly traffic points, not a directional requirement.

At us-east-1's $0.09/GB first outbound tier and 1 TB = 1,024 GB, illustrative all-outbound charges are:

| Monthly transfer scenario (A-015) | If all traffic is inbound | If all is outbound, 100 GB account-wide free allowance available | If all is outbound, allowance already used |
|---|---:|---:|---:|
| 100 GB | $0.00 | $0.00 | $9.00 |
| 1 TB = 1,024 GB | $0.00 | $83.16 (924 × $0.09) | $92.16 |
| 10 TB = 10,240 GB | $0.00 | $912.60 (10,140 × $0.09) | $921.60 |

These are independent calculations against AWS pricing, not Calculator results, and assume the entire quantity traverses the VPN; mixed traffic should price only its AWS-to-on-premises/outbound component, applying the account-wide 100 GB allowance only if still available. Actual monthly direction and destination are unknown. Do not add these amounts to the subtotal.

### NAT Gateways and VPC endpoints

The NAT public IPv4 audit subsequently confirmed the Public IPv4 feature was disabled in the saved NAT entry; $65.70 represented two gateway-hours only. The entry now includes exactly two in-use NAT public IPv4 addresses and totals $73.00/month. The separate VPN entry's two tunnel IPv4 addresses remain included in its $43.80 total. NAT processed data is still a 0 GB placeholder.

NAT data processing is separately $0.045/GB. There is no documented NAT-processed quantity. If (for arithmetic only, not as an assumption that VPN bytes also traverse NAT) the existing A-015 volume points were processed through NAT, the processing charges would be $4.50 / $46.08 / $460.80 for 100 / 1,024 / 10,240 GB. Add standard internet data-out charges where applicable; the NAT fee is not a substitute for egress billing. Same-AZ NAT routing is documented and should avoid inter-AZ traffic to NAT; validate actual route tables and bytes.

The S3 Gateway Endpoint in the architecture has no hourly or data-processing charge; S3 requests, storage and applicable data transfer still apply. No interface endpoints are currently assumed. In us-east-1, interface endpoints are $0.01 per endpoint ENI-AZ-hour and $0.01/GB processed in the first tier. Thus one endpoint enabled in both app AZs would be $14.60/month fixed (2 × 730 × $0.01), before data processing; this is only a unit illustration, not an endpoint-count assumption. Endpoint cost is quantity × enabled AZs × 730 × hourly rate, plus actual bytes × processing rate. Add endpoints only after a service-by-service dependency/route decision; the use of same-AZ NAT means private AWS service access does not by itself prove that an endpoint is required.


## Network cost reconciliation — NAT, VPN, endpoints and AZ paths

### NAT public IPv4 and processing

Inspection confirmed the saved VPC calculator entry had two conventional NAT Gateways, 0 GB processed, Public IPv4 Address disabled, and $65.70 total—the exact 2 × 730 × $0.045 gateway-hour amount. Public NAT requires an Elastic IP. At AWS's $0.005/address-hour rate, two NAT IPv4 addresses add 2 × 730 × $0.005 = $7.30/month. I enabled the calculator Public IPv4 feature for exactly two in-use addresses. The NAT entry now verifies at $73.00/month; the estimate changed from $1,923.46 to $1,930.76/month ($23,169.12 annualised). The VPN entry separately retains its own two tunnel addresses ($7.30); they are distinct and are not duplicated. NAT processed GB remains a zero placeholder. [VPC pricing](https://aws.amazon.com/vpc/pricing/), [public NAT requirements](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-nat-gateway.html), [AWS two-NAT pricing example](https://aws.amazon.com/blogs/networking-and-content-delivery/identify-and-optimize-public-ipv4-address-usage-on-aws/).

The us-east-1 NAT data-processing rate is $0.045/GB. Independent sensitivity only (not saved): 100 × $0.045 = $4.50; 1,024 × $0.045 = $46.08; 10,240 × $0.045 = $460.80/month. These conservative/baseline/high traffic points are illustrative, not observed or approved. NAT processing is separate from standard internet data-out and cross-AZ transfer. S3 routed through its Gateway Endpoint avoids NAT processing for that path. [Amazon VPC pricing](https://aws.amazon.com/vpc/pricing/).

### VPN transfer direction

On-premises-to-AWS replication/application requests are inbound and do not incur standard AWS transfer-out charges. AWS-to-on-premises DB responses, file reads and app responses may count as AWS transfer-out. The first 100 GB/month free allowance is account-wide across eligible services and Regions; it is not reserved for VPN. Use it only after checking aggregate account egress. A-015 directional sensitivities remain illustrative, outside the estimate. VPN connection and tunnel IPv4 remain $43.80/month. [EC2 transfer pricing](https://aws.amazon.com/ec2/pricing/on-demand/), [VPN pricing](https://aws.amazon.com/vpn/pricing/).

### Endpoint inventory

The app subnets already have same-AZ NAT routes; the S3 Gateway Endpoint is documented. Interface endpoints are conditional choices, not defaults. First-tier PrivateLink price is $0.01 per endpoint ENI-AZ-hour plus $0.01/GB; 730 hours is $7.30 per endpoint per AZ-month or $14.60 for one service in both app AZs, before data processing. S3 Gateway Endpoint is $0 hourly and $0 processing. No interface endpoint has been added to the estimate. [PrivateLink pricing](https://aws.amazon.com/privatelink/pricing/), [VPC endpoint guidance](https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-access-aws-services.html).

| Endpoint | Type, purpose and need | AZ/hourly basis | Processing | SG / policy | NAT alternative and phase |
|---|---|---|---|---|---|
| S3 | Gateway; documented app archives; may be associated with staging route table | Both app route tables; $0 | $0 endpoint processing; S3 requests/storage still apply | No SG; route table, endpoint/bucket policies and IAM | Avoids NAT for S3; steady state and reusable in migration |
| Systems Manager (ssm, ssmmessages, ec2messages if needed) | Interface; conditional on selected SSM management features and private egress | Each service × AZ × $7.30/month | $0.01/GB | TCP 443 from app/staging SG; IAM/policies | NAT HTTPS alternative; steady state/staging only if required |
| CloudWatch Logs and Monitoring | Interface; conditional on private log/metric API path | Each selected service × AZ × $7.30/month | $0.01/GB | TCP 443 from approved client SG; IAM | NAT alternative; only if private path selected |
| Secrets Manager | Interface; secret service documented, endpoint only if runtime API must remain private or NAT prohibited | Each AZ × $7.30/month | $0.01/GB | TCP 443 from app SG; least-privilege IAM | NAT alternative; conditional steady state |
| MGN | Interface, migration-only private control plane for agents/staging | Chosen staging/source reachability AZs × $7.30/AZ-month | $0.01/GB | TCP 443 from approved source/staging paths; endpoint policy | NAT/public endpoint alternative; private topology only |
| EC2 API | Interface, migration-only; included in AWS restricted MGN guidance for staging calls | Chosen staging AZs × $7.30/AZ-month | $0.01/GB | TCP 443 from staging SG; endpoint policy/IAM | NAT/public alternative |
| S3 for MGN agents | Interface, migration-only private installer/service bucket access; distinct from S3 Gateway | Actual source/staging AZ path × $7.30/AZ-month | $0.01/GB | TCP 443 from approved source CIDRs; S3/endpoint policy | Avoids public S3 path for that flow |
| DataSync | Interface, migration-only optional VPC service endpoint for an on-prem agent over VPN | AWS supports one endpoint across agents/subnets; chosen AZs × $7.30 | $0.01/GB | DataSync control TCP 1024–1064; task ENI path TCP 443; restrict SGs | Avoids public service path |
| DMS customer API | None proposed; current data-plane flow does not justify customer interface endpoint | None | None | N/A | Do not add without an evidenced dependency |

MGN private-network guidance lists MGN/EC2 interface endpoints and S3 interface plus gateway endpoints for restricted designs; DataSync supports public or VPC service endpoints. SSM/CloudWatch/Secrets Manager endpoints depend on workload APIs and egress policy. Endpoint counts and AZs remain unresolved. Restrict interface SG ingress to approved clients (usually TCP 443; DataSync control ports differ), and also scope IAM, endpoint and bucket policies. [MGN private guidance](https://docs.aws.amazon.com/prescriptive-guidance/latest/rehost-servers-over-private-networks-mgn/configuration.html), [MGN network requirements](https://docs.aws.amazon.com/mgn/latest/ug/preparing-environments.html), [DataSync endpoint choices](https://docs.aws.amazon.com/datasync/latest/userguide/choose-service-endpoint.html), [SSM PrivateLink](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-getting-started-privatelink.html).

### Cross-AZ paths

| Path | Documented design and potential charge |
|---|---|
| EC2–EFS | App nodes and Regional mount targets exist in both AZs. Same-AZ access is free; access to another AZ mount target incurs $0.01/GB for transfer in and out of the AZ. Actual DNS/mount target use and GB unknown. |
| App–NAT | App A→NAT A and B→B are documented. Same-AZ path avoids cross-AZ NAT; route drift to another AZ can add cross-AZ transfer, alongside NAT processing and possible internet egress. |
| ALB–EC2 | ALB and targets span two AZs. EC2↔ALB private-IP transfer in the same VPC is free; processed bytes still affect ALB LCU. |
| App–RDS | Same-AZ EC2-RDS transfer is free; app traffic reaching a writer in another AZ incurs EC2-side cross-AZ transfer. Multi-AZ replication itself is free. Placement and traffic unknown. |
| VPN | On-prem→AWS is inbound; AWS→on-prem responses may be transfer-out. VPN traffic is not automatically NAT traffic. |
| Migration | MGN, DMS and DataSync paths are temporary; direction, AZ placement and bytes can affect transfer-out, NAT processing and cross-AZ costs. All remain unpriced. |

These rules are exposure, not usage estimates. [EFS pricing](https://aws.amazon.com/efs/pricing/), [EC2 transfer](https://aws.amazon.com/ec2/pricing/on-demand/), [RDS transfer](https://aws.amazon.com/rds/pricing/).

### Migration-period pricing model

No migration-period calculator entries have been added. Populate only after evidence and calendar approval. The steady-state total is the target platform's separate monthly run cost; do not duplicate it within incremental migration charges. On-premises source costs are outside AWS pricing unless source resources are AWS-hosted.

| Duration case | Time | MGN free service-hours per each of two sources | MGN staging EC2/EBS | DMS | DataSync Basic | Temporary network / overlap |
|---|---:|---|---|---|---:|---|
| Short (illustrative 1 week) | 168 h | Below 2,160 active hours | Unpriced: disks, changed blocks, staging profile/resource hours, snapshots and test hours unknown | Unpriced: class/DCU, storage, AZ mode and runtime unknown | $18.75 derived initial 1,500 GB; $0.19/$0.94/$3.75 illustrative 1%/5%/20% deltas, one-time | Unpriced: routes, endpoints/NAT/VPN/transfer and overlap unknown |
| Medium (illustrative 1 month) | 730 h | Below 2,160 active hours | Same evidence gaps; use actual resource hours | Same evidence gaps; use measured full-load/CDC profile | Same arithmetic only if bytes validated | Actual temporary hours and bytes only |
| Long (illustrative 3 months) | 2,190 h | 30 h beyond 2,160 per source if continuously replicating; stopped time excluded | Same gaps; test/cutover EC2/EBS extra | Same gaps; CDC may extend through parallel run | Same arithmetic; each actual copied byte is charged | Signed schedule and evidenced paths only |

DataSync arithmetic: 1,500 GB × $0.0125/GB = $18.75 one-time. Deltas 15/75/300 GB cost $0.1875/$0.9375/$3.75 (rounded $0.19/$0.94/$3.75). If the 1,000 GB initial EFS portion and those deltas are written under EFS Elastic Throughput at $0.06/GB, conditional write activity is $60 initial and $0.90/$4.50/$18 for deltas. These are separate from DataSync fee, S3 requests, destination storage and ongoing app EFS access. MGN is free for 2,160 active replication hours per source; replication EC2/EBS and test/cutover resources are chargeable during that period. DMS is documented full load + CDC but capacity and runtime need DBA sizing. Do not invent any remaining input. [MGN pricing](https://aws.amazon.com/application-migration-service/pricing/), [MGN cost planning](https://docs.aws.amazon.com/mgn/latest/ug/migration_at_scale.html), [DMS pricing](https://aws.amazon.com/dms/pricing/), [DataSync pricing](https://aws.amazon.com/datasync/pricing/).

Evidence to complete this separate group: source disks/used bytes/change rates; MGN staging recommendations and active/paused/test/cutover hours; PostgreSQL version/size/write/WAL profile and DMS sizing; NFS/S3 bytes/file/object inventory and sync deltas; migration path matrix (source, destination, direction, GB, AZ, route and duration); subnet/endpoint-versus-NAT decision; signed cutover, rollback, parallel-running and source-retirement schedule. Model one-time, hourly-during-window and recurring charges separately.



The saved estimate still has a separate empty **Migration period — temporary** group; no migration costs were added. A-019's derived 1,500 GB initial transfer at DataSync Basic's current $0.0125/GB is **$18.75 one-time**; the 15 / 75 / 300 GB final-delta scenarios cost $0.19 / $0.94 / $3.75 one-time. This prices only DataSync's volume fee, not the source inventory, file-operation request charges, EFS/S3 destination activity or temporary network path. Conditional EFS destination write activity is separately documented in the EFS section.

AWS MGN's service charge has a 2,160-hour (90-continuous-day) free period per source server. Replication infrastructure (including MGN-provisioned compute/storage) is billable even during that period; test/cutover EC2 and EBS are also billed. A-017's two source servers and 2-week / 1-month / 3-month duration examples do not establish disk size, change rate or staging configuration. A 3 × 730-hour planning interval is 2,190 hours, which exceeds the service free window by 30 hours, but no post-free amount or staging-resource quantity is entered here. DMS full load + CDC remains documented, but replication mode/class, storage, CDC runtime and overlap are unresolved; AWS bills selected on-demand instance capacity or Serverless DCU-hours. No arbitrary DMS class was priced. DataSync initial and final delta, MGN replication, DMS, temporary VPN/NAT/endpoint/transfer, test/cutover compute and parallel-running duration must remain separately labelled migration-period costs. Migration calendar A-023, source data/change measurements A-017–A-019, and route/endpoint flow evidence A-020–A-022 are prerequisites to a responsible complete migration estimate.

## Pricing method and acceptance

1. Open the existing saved estimate in [AWS Pricing Calculator](https://calculator.aws/); preserve its current service configurations.
2. Treat the current subtotal as partial and keep usage-dependent or unresolved components clearly excluded.
3. Add EC2, EBS, RDS for PostgreSQL, EFS, S3, VPC/NAT, ALB, Site-to-Site VPN, CloudWatch and Route 53 as applicable.
4. Use 730 hours/month. Record selected calculator configurations and remaining decisions, including PostgreSQL version/workload validation, backup retention, NAT processed GB, ALB LCU inputs, VPN transfer, endpoint count/AZs, logs and transfer.
5. Create a separate migration-period group for MGN staging, DMS, DataSync, temporary instances, transfer and overlap duration.
6. Export the estimate as CSV and PDF and retain the public share URL. Record the estimate date and pricing assumptions.
7. Reconcile the exported service totals with this document and `cost/pricing-assumptions.csv`. Do not approve a budget until missing inputs are resolved.

AWS explains that the calculator uses service configuration and Region inputs, can export CSV/PDF and can generate a shareable estimate link. Its estimate excludes taxes and only includes the information entered.

## Optimisation decisions

1. Keep two NAT Gateways in the production-oriented baseline; compare a one-NAT cost option only with an explicit availability/cross-AZ trade-off.
2. Use the S3 Gateway Endpoint for eligible S3 traffic and avoid routing that traffic through NAT.
3. Select interface endpoints from an actual service dependency inventory; do not add endpoints speculatively.
4. Benchmark EC2 and RDS using representative CPU, memory, IOPS, throughput, connection and latency measurements before right-sizing.
5. Use EFS lifecycle policies only after file access patterns and retrieval requirements are known.
6. Apply S3 lifecycle and retention policies based on approved archive requirements.
7. Set AWS Budgets alerts and Cost Explorer allocation tags after the cost baseline is approved.

## Exclusions / separate estimates

Taxes, support plan, engineering labour, customer gateway and on-premises internet costs, migration staging/overlap, MGN/DMS/DataSync execution, unknown transfer, optional security services, detailed backup, EFS cross-AZ transfer and workload-confirmed lifecycle/throughput, NAT public IPv4 charges (now included; processed GB remains unknown), VPN/NAT traffic, endpoint inventory, S3 requests/retrieval and unmodelled usage require separate inputs or estimates.

## Public pricing references

- [AWS Pricing Calculator](https://calculator.aws/)
- [Amazon EC2 On-Demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [Amazon VPC pricing — NAT Gateway and public IPv4](https://aws.amazon.com/vpc/pricing/)
- [Elastic Load Balancing pricing](https://aws.amazon.com/elasticloadbalancing/pricing/)
- [Amazon RDS for PostgreSQL pricing](https://aws.amazon.com/rds/postgresql/pricing/)
- [Amazon EFS pricing](https://aws.amazon.com/efs/pricing/)
- [Amazon S3 pricing](https://aws.amazon.com/s3/pricing/)
- [AWS Site-to-Site VPN pricing](https://aws.amazon.com/vpn/pricing/)
- [Amazon Route 53 pricing](https://aws.amazon.com/route53/pricing/)
- [Amazon CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/)\n- [AWS PrivateLink pricing](https://aws.amazon.com/privatelink/pricing/)\n- [AWS Transform MGN pricing](https://aws.amazon.com/application-migration-service/pricing/)\n- [AWS DMS pricing](https://aws.amazon.com/dms/pricing/)
- [AWS Certificate Manager pricing](https://aws.amazon.com/certificate-manager/pricing/)
- [AWS Pricing Calculator guide: export estimate](https://docs.aws.amazon.com/pricing-calculator/latest/userguide/export-estimate.html)
- [AWS Pricing Calculator guide: share estimate](https://docs.aws.amazon.com/pricing-calculator/latest/userguide/save-share-estimate.html)

**Status:** A partial AWS Pricing Calculator estimate is saved and verified at $1,930.76/month ($23,169.12 annualised). It is **not complete or approved**: ALB usage remains unresolved (scenario sensitivity only; no ALB calculator entry saved); DNS authority and billable query use plus monitoring workload remain unresolved; Route 53 and CloudWatch sensitivity scenarios were verified in the calculator but canceled unsaved and remain excluded. EFS read/write, lifecycle/retrieval and cross-AZ volumes remain unresolved; unsaved EFS Calculator all-Standard scenarios are $304.50/$321.00/$390.00 monthly and excluded. VPN egress depends on direction. The saved NAT entry is $73.00/month: $65.70 for two conventional gateway-hours plus $7.30 for two public IPv4 address-hours. The NAT public IPv4 setting was verified absent, added as quantity 2, and the VPC line recalculated; two VPN tunnel addresses remain in the separate $43.80 entry. Endpoint inventory/data volumes, backups, migration MGN staging/DMS runtime/network/duration/overlap remain unresolved. DataSync service sensitivity is $18.75 one-time for derived 1,500 GB, before destination and network costs. Keep migration-period group separate. No AWS resources have been deployed.
