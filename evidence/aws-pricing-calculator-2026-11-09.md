# AWS Pricing Calculator evidence — 9 November 2026

## Share link

The owner-authorized public-server acknowledgement was accepted and AWS Pricing Calculator generated this public link. Anyone with the link can view the estimate. AWS states the link expires after one year.

[Open the saved Clafoke estimate](https://calculator.aws/#/estimate?utm_source=chatgpt.com&id=125cca5d8540af810df5d1490607092f33c3b34b)

Estimate name: **Clafoke Investors Ltd — us-east-1 — steady-state estimate (incomplete)**  
Region: `us-east-1` · Currency: USD · Estimate date: 9 November 2026  
Saved subtotal: **$1,930.76/month** · 12-month annualisation: **$23,169.12**  
Saved steady-state services: **6**. The separate migration-period group is present and empty (0 services).

## Reconciliation

| Calculator service | Monthly total |
|---|---:|
| EC2 (2 Linux `t3.xlarge`, 730 hours; 200 GB gp3 in the EC2 entry) | $274.94 |
| RDS for PostgreSQL (`db.m6i.2xlarge`, Multi-AZ DB instance, 500 GB gp3, 12,000 IOPS, 500 MiB/s) | $1,227.52 |
| EFS (1,000 GB Regional Standard) | $300.00 |
| S3 Standard (500 GB) | $11.50 |
| Site-to-Site VPN connection and two tunnel public IPv4 address-hours | $43.80 |
| Two conventional NAT Gateways and two NAT public IPv4 address-hours | $73.00 |
| **Total** | **$1,930.76** |

The exported CSV reports $1,930.76 monthly and $23,169.12 for 12 months. Its detailed component rows sum to $1,930.764 at underlying precision, which rounds to the calculator display of $1,930.76. The PDF shows the same two totals. The CSV contains component rows (including separate VPN/NAT public IPv4 lines); those are included within the six parent service entries above, not additional services.

### Configuration and adjustments

- The saved EC2 summary shows two shared Linux `t3.xlarge` instances at 730 On-Demand hours/month and 200 GB total EBS storage.
- The RDS summary shows `db.m6i.2xlarge`, one configured DB with **Multi-AZ** deployment, 500 GB gp3, 12,000 IOPS and 500 MiB/s throughput. The $1,227.52 is the calculator result for this input; do not manually double the calculator result. PostgreSQL version, target-class suitability and workload fit remain unresolved. There is no RDS Proxy service entry. Extended Support applicability cannot be confirmed until the PostgreSQL major version is selected.
- The VPN row description was corrected and saved to explain the 730-hour Site-to-Site connection, two priced tunnel IPv4 addresses, separate NAT entry, and the dormant 22-working-days Client VPN field. The calculator total remains $43.80 ($36.50 connection-hours + $7.30 IPv4).
- The NAT row description was corrected and saved. Its $73.00 is $65.70 conventional gateway-hours plus $7.30 for two NAT IPv4 addresses. The calculator displays residual Regional NAT inputs (5 gateways / 3 AZs), but the expanded Regional NAT calculation is $0.00/month and contributes nothing to the total. The calculator rejects a Regional NAT count below 1, so the residual input could not be cleared; no Regional NAT price is included.
- No numeric service configuration or subtotal changed in this evidence pass; only the existing VPN and NAT descriptions were corrected. No services were added or removed.
- NAT processed GB, VPN transfer, ALB, Route 53, CloudWatch, EFS metered throughput/cross-AZ activity and migration costs remain unpriced or excluded pending validated assumptions. Zero calculator placeholders are not evidence of zero usage. The estimate is partial and not an approved budget.

## Export files

Both files were freshly exported from the saved calculator on 9 November 2026 and downloaded.

| File | Size | SHA-256 | Verification |
|---|---:|---|---|
| [PDF export](aws-pricing-calculator-2026-11-09.pdf) | 20,466 bytes | `23E450F2F0F881131AD6A7D6434E3F67F995039E843B2314CA85614875B49AC2` | PDF 1.7 signature and EOF verified; two page objects; decompressed text streams contain the estimate name, $1,930.76 and $23,169.12. |
| [CSV export](aws-pricing-calculator-2026-11-09.csv) | 6,744 bytes | `10EB952D1EDAEF65657E11C01AF4C331C03BD73B8EA16B86A3E385EE026DD9F5` | Parsed as CSV; summary totals match the saved estimate; detailed monthly components sum to $1,930.764 and round to $1,930.76. |

The files document an estimate only. They do not represent deployed resources, measured client workload, or migration execution. No credentials or AWS account identifiers are included.
