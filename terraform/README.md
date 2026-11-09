# Terraform — Network Foundation

This directory contains the first IaC implementation layer for the fictional Clafoke migration blueprint.

## Scope

- VPC and eleven subnet layout across two AZs (two public, two application, two database, one MGN staging, two DMS).
- Dedicated route tables and subnet associations.
- Internet Gateway and public routes.
- Optional two-AZ NAT Gateways.
- S3 Gateway Endpoint for application route tables.
- Optional VGW, Customer Gateway, dynamic BGP VPN and route propagation restricted to MGN, DMS-A/B and the two DataSync migration route tables.
- ALB, application, RDS, EFS, DMS, MGN staging and DataSync task security groups.

It also includes an opt-in workload layer (`enable_workload_resources=false` by default) for an HTTPS ALB, two-AZ EC2 Auto Scaling Group, managed PostgreSQL Multi-AZ, encrypted EFS and a synthetic health-check/API service. It does not create DMS replication instances, MGN replication servers, DataSync agents/tasks or customer firewall configuration.

## Cost and safety defaults

Both chargeable network features are opt-in:

- `create_nat_gateways = false`
- `enable_site_to_site_vpn = false`

The default plan still creates a VPC, subnets, route tables, IGW, S3 Gateway Endpoint and security groups if applied; these are real AWS resources and may incur ancillary costs. **Do not apply without explicit approval.** NAT Gateways, Elastic IPs and Site-to-Site VPN resources incur additional charges when enabled.

The VPN requires `customer_gateway_ip` to be supplied at runtime. Never commit a real customer public IP, tunnel pre-shared key or AWS credential.

## Local validation (Windows PowerShell)

From the repository root:

```powershell
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate
terraform -chdir=terraform plan -refresh=false -out=tfplan
```

Review the plan and confirm the selected AWS account/Region before any apply. Remove local `terraform.tfstate*`, `.terraform/`, `tfplan`, crash logs and credentials from Git; these are ignored by the repository `.gitignore`.

## Design notes

- AZs are resolved from the first two available AZ names in the selected account; verify the resolved IDs before deployment.
- The VPC CIDR and subnet CIDRs are synthetic inputs from [decision record 14](../docs/14-synthetic-case-study-decisions.md).
- VGW route propagation is attached only to `mgn`, `dms_a` and `dms_b` route tables.
- DMS SG egress uses the all-outbound baseline from AWS DMS networking guidance. Source/target ingress and subnet routing remain restricted.
- The RDS SG includes a temporary DMS rule. Remove it after migration and before steady-state sign-off.
- The MGN staging subnet is single-AZ in this portfolio scenario; it is not an HA claim.
- No AWS apply, live connectivity test or cost-bearing resource creation has been performed by this repository change.
