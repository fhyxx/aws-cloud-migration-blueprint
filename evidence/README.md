# Evidence Register

**Project:** Clafoke Investors Ltd — fictional AWS Cloud Migration Blueprint  
**Evidence status:** Design and synthetic validation evidence only  
**Last updated:** 9 November 2026

## Scope and evidence rules

This is a fictional, design-only portfolio case study. No AWS infrastructure has been deployed, no migration service has been activated, and no source-to-target data movement, performance test, cutover, rollback or recovery test has been executed.

Evidence must distinguish:
- **Repository evidence:** committed architecture, Terraform, documentation and pricing files.
- **Synthetic validation:** CI checks, Terraform schema validation and no-refresh plans using dummy identifiers/credentials. These do not call AWS APIs or prove live resource compatibility, availability, connectivity, cost or permissions.
- **Live implementation evidence:** screenshots, AWS CLI output, task reports, metrics and test results captured only after an approved real deployment. None exists yet.

Never fabricate console screenshots, CLI output, customer measurements, successful tests or approvals. Redact account IDs, public IPs, credentials, customer data and other sensitive values before committing any future live evidence.

## Evidence available now

| Evidence | Repository artifact | What it establishes | What it does not establish |
|---|---|---|---|
| Canonical architecture | [Master diagram source](../architecture/target-architecture.mmd) and [rendered page](../architecture/target-architecture.md) | Current intended target architecture | Deployed resources or live connectivity |
| Runtime/network architecture | [Runtime source](../architecture/runtime-network-view.mmd) and [rendered page](../architecture/runtime-network-view.md) | Eleven-subnet layout, AZ placement, route intent and SG boundaries | Live route tables, SGs, VPN/BGP or traffic tests |
| Migration data flow | [Migration source](../architecture/migration-data-flow.mmd) and [rendered page](../architecture/migration-data-flow.md) | Separate MGN, DMS and DataSync flows and protocols | Activated MGN/DMS/DataSync services or data movement |
| Terraform baseline | [Terraform directory](../terraform/) and [IaC design](../docs/15-infrastructure-as-code-design.md) | Opt-in infrastructure definitions and safe defaults | Any AWS resource creation or account-specific plan |
| CI validation | [latest main validation run #104](https://github.com/fhyxx/aws-cloud-migration-blueprint/actions/runs/42644692954) | Terraform fmt/init/validate, safe-default and full synthetic no-refresh plans, network/migration assertions and cost-model checks passed | Live AWS API calls, deployment, service quotas, permissions, prices or connectivity |
| Migration-period cost model | [Cost model](../docs/17-migration-cost-model.md) and [pricing assumptions](../cost/pricing-assumptions.csv) | Reproducible formulas, conditional sensitivities and explicit unpriced gates | Approved quantities, benchmark results or a migration total |
| Saved Pricing Calculator estimate | [Evidence record](aws-pricing-calculator-2026-11-09.md), [PDF](aws-pricing-calculator-2026-11-09.pdf), [CSV](aws-pricing-calculator-2026-11-09.csv) | Six-service partial steady-state subtotal of $1,930.76/month and $23,169.12 annualised, plus documented calculator inputs and open assumptions | Complete monthly bill, approved budget, actual usage or migration-period cost |

### Pricing Calculator visibility

The committed evidence record contains a public AWS Pricing Calculator share URL. Anyone who receives that URL can view the estimate; treat it as public information, not a private document. The saved estimate is partial, its separate migration-period group is empty, and zero-valued usage placeholders are not proof of zero consumption. The PDF/CSV exports are estimate evidence only.

## Visual rendering status

- The user previously confirmed that the master architecture and migration data-flow diagrams rendered correctly in GitHub.
- The user confirmed that the updated runtime/network diagram renders correctly in GitHub. Its Mermaid source is synchronised, and CI verifies the embedded Mermaid block exactly matches the source.
- Visual confirmation establishes that the diagram is readable and rendered; it does not validate deployed route tables, security groups, VPN/BGP or traffic.

## Live evidence still required for a real implementation

| Workstream | Evidence to capture after approval |
|---|---|
| Network foundation | Account-specific Terraform plan, deployed VPC/subnets/route-table associations, VPN tunnel/BGP status, route propagation, SG/NACL rules and positive/negative connectivity tests |
| MGN | Source OS/disk inventory, replication template, replication server/staging resource profile, replication lag, test-launch evidence and cleanup record |
| DMS | PostgreSQL source/target version compatibility, object/schema inventory, WAL/slot readiness, replication instance settings, task logs, full-load results, CDC lag and row-level reconciliation |
| DataSync | Agent activation and endpoint details, NFS export/ACL inventory, source bytes/file counts, task reports, final delta, EFS verification and archive source evidence |
| Application and data | ALB target health, application readiness/load tests, database connection and query tests, EFS mount/write tests, backup/restore evidence |
| Resilience | Timed AZ/failover, VPN tunnel failure/recovery, RDS PITR, EFS restore, S3 object recovery, measured RTO/RPO and business transaction reconciliation |
| Cost | Current calculator export after selected MGN/DMS/DataSync resources, measured transfer/network usage, approved overlap calendar and decommissioning dates |

## Current conclusion

The project has substantial architecture, IaC, pricing and synthetic CI evidence. It is **not deployment-ready and not a completed migration**. All live implementation and migration-readiness gates remain pending validation.
