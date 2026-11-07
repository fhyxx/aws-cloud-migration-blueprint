# 07 — AWS Cost Estimation and Optimisation

**ID:** CLI-AWS-COST-007 | **Version:** 1.0 | **Status:** Illustrative planning model  
**Region:** `us-east-1` | **Currency:** USD | **Month:** 730 hours

## Executive estimate

**Approximately $2,099–$2,587/month** or **$25,191–$31,047/year**. This is not a quote or actual bill. RDS compute and several allowances are provisional and must be priced in AWS Pricing Calculator before budget approval.

## Model aligned to architecture

| Service | Assumption | Monthly USD |
|---|---|---:|
| EC2 | 2 × t3.xlarge × $0.167/hr × 730 | 243.82 |
| EBS gp3 | 200 GB × $0.08/GB-month | 16.00 |
| RDS compute | 2 Multi-AZ instances × $0.80–$1.10/hr × 730 | 1,168–1,606 |
| RDS storage | 500 GB × planning $0.23/GB-month | 115.00 |
| RDS backup | Usage allowance | 20–50 |
| EFS Standard | 1,000 GB × $0.30/GB-month | 300.00 |
| S3 Standard | 500 GB × $0.023/GB-month | 11.50 |
| NAT hourly | 2 × $0.045/hr × 730 | 65.70 |
| NAT processing | 200 GB × $0.045/GB | 9.00 |
| ALB hourly | 730 × $0.0225/hr | 16.43 |
| ALB LCU | Low usage allowance | 6.00 |
| Site-to-Site VPN | 730 × $0.05/hr planning rate | 36.50 |
| VPN public IPv4 | 2 × $0.005/hr × 730 allowance | 7.30 |
| CloudWatch | Basic logs/metrics allowance | 25.00 |
| Interface endpoints | Small multi-AZ set allowance | 30–50 |
| Internet transfer | 100 GB × $0.09/GB allowance | 9.00 |
| Contingency | Usage allowance | 20.00 |
| **Total** | | **2,099–2,587** |

The detailed inputs and confidence labels are in `cost/pricing-assumptions.csv`.

## Confidence and limitations

EC2 T3 xlarge Linux us-east-1 proxy rate is based on public AWS instance pricing. NAT Gateway public example rate is $0.045/hour and $0.045/GB. ALB costs include base hourly and usage-dependent LCU. EFS/S3 storage rates are reference assumptions.

RDS $0.80–$1.10 per instance-hour is a planning range, not a verified quote for a selected RDS class. Confirm exact PostgreSQL version, instance class, Multi-AZ deployment, storage type/IOPS and backup usage. VPN/public IPv4 treatment, endpoint count, CloudWatch, LCU and transfer allowances must also be recalculated.

## Optimisation

1. EFS lifecycle: hot files in Standard; eligible cold files to IA/Archive after access and retrieval analysis.
2. Retain two NAT Gateways for production-oriented resilience; use S3 Gateway Endpoint and justified interface endpoints to reduce NAT processing. One NAT is cheaper but less resilient.
3. Benchmark EC2; T3 is burstable and may not suit sustained CPU.
4. Benchmark RDS; preserve Multi-AZ unless business explicitly accepts availability trade-off. Consider commitments only after stable use.
5. Select S3 storage classes by access and retention.
6. Set log retention and control ingestion.
7. AWS Budgets alerts at 50%, 80%, 100%; Cost Explorer and allocation tags.

## Exclusions

Taxes, support plan, engineering labour, customer gateway/internet, migration staging/overlap, DMS/MGN/DataSync execution, unknown transfer, optional security services, detailed backup, EFS throughput, S3 requests/retrieval, extra endpoints and unmodelled usage.

## Required decisions

Exact EC2 family; RDS version/class/storage/IOPS; EFS tier mix/throughput; archive retention; NAT GB; endpoint count/AZs; internet transfer; migration duration; support plan; budget approval.

**Recommendation:** Retain two-AZ design. Optimise storage and egress first; right-size compute after workload tests. Recalculate all line items in AWS Pricing Calculator before budget approval.

**Status:** Planning estimate only—not a quotation or actual bill.

## Public pricing references

Pricing pages are dynamic; confirm current rates and configuration in AWS Pricing Calculator before approval.

- [Amazon EC2 On-Demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/)
- [Amazon VPC pricing — NAT Gateway](https://aws.amazon.com/vpc/pricing/)
- [Elastic Load Balancing pricing](https://aws.amazon.com/elasticloadbalancing/pricing/)
- [Amazon EFS pricing](https://aws.amazon.com/efs/pricing/)
- [Amazon S3 pricing](https://aws.amazon.com/s3/pricing/)
- [AWS Site-to-Site VPN pricing](https://aws.amazon.com/vpn/pricing/)
- [AWS Pricing Calculator](https://calculator.aws/)

The published EC2 T3 xlarge reference lists 4 vCPU, 16 GiB and a Linux On-Demand rate of $0.167/hour in US East (N. Virginia). AWS VPC pricing examples show NAT Gateway at $0.045/hour and $0.045/GB in the cited example Region; validate the exact Region and current rate. The RDS, VPN, IPv4, CloudWatch and endpoint figures in this model remain provisional allowances until a precise calculator configuration is saved.
