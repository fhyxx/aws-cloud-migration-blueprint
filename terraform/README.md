# Terraform — Network, Workload and Migration Foundation

This directory contains the Terraform implementation for the fictional Clafoke Investors Ltd migration case study. It is a synthetic portfolio environment, not a deployed customer environment.

## Implemented resource layers

### Network foundation

- VPC `10.30.0.0/16`, DNS support/hostnames and Internet Gateway.
- Eleven subnets: public A/B, application A/B, database A/B, MGN staging, DMS A/B, DataSync endpoint and DataSync task ENI.
- Dedicated route tables and explicit subnet associations.
- Public IGW routes; optional two-AZ NAT Gateways.
- S3 Gateway Endpoint associated with App-A, App-B and MGN staging.
- Optional VGW, Customer Gateway, dynamic BGP VPN and route propagation limited to MGN, DMS-A/B and the DataSync endpoint/task route tables.
- Dedicated ALB, app, RDS, EFS, DMS, MGN staging, DataSync endpoint and DataSync task security groups.

### Workload layer

When `enable_workload_resources=true`, Terraform creates an HTTPS ALB, EC2 launch template and two-AZ Auto Scaling Group, PostgreSQL RDS Multi-AZ DB instance, encrypted EFS file system, mount targets, backup policy and synthetic health/API service.

### Migration layer

When `enable_dms_resources=true`, Terraform creates DMS service roles, the dedicated two-AZ replication subnet group, private replication instance, Secrets Manager-backed PostgreSQL source/target endpoints and a stopped full-load-and-CDC task. Source credentials remain outside Git and Terraform variable files.

When `enable_datasync_resources=true`, Terraform creates the regional DataSync Interface VPC endpoint in `10.30.51.0/24`, NFSv4.1 and EFS locations, a stopped NFS-to-EFS task, task log group and a private S3 archive bucket/location. The VPC endpoint ID, endpoint ENI IDs, endpoint subnet ARN and endpoint security-group ARN are outputs for agent activation. Agent activation remains a separate operator step because activation keys must not be stored in Terraform state or Git. No archive transfer task is created until a source archive system is specified.

MGN replication-template creation is handled by the guarded PowerShell script `scripts/configure-mgn-replication-template.ps1`. It is dry-run by default and creates only the template when explicitly executed; it does not install agents, register source servers, start replication or cut over.

## Cost and safety controls

The following feature flags default to false:

- `create_nat_gateways`
- `enable_site_to_site_vpn`
- `enable_workload_resources`
- `enable_dms_resources`
- `enable_datasync_resources`

The default Terraform configuration still creates real resources if applied: VPC, subnets, route tables, IGW, S3 Gateway Endpoint and security groups. Do not apply without explicit permission. Enabling NAT, VPN, workload, DMS or DataSync adds chargeable resources. The 61-resource default plan and 122-resource full synthetic plan are graph-validation outputs, not cost estimates or deployment approvals. The DataSync interface endpoint also incurs hourly and data-processing charges when enabled.

Never commit AWS credentials, database passwords, Secrets Manager values, VPN tunnel secrets, DataSync activation keys or generated Terraform state/plan files. Keep source secrets in Secrets Manager and use a controlled remote state backend with encryption, versioning and locking before team use.

## Synthetic defaults and runtime inputs

- Region: `us-east-1`.
- VPC: `10.30.0.0/16`.
- Source aggregate: `10.50.0.0/16`.
- AZ name aliases: `us-east-1a`, `us-east-1b`; these do not guarantee the same physical AZ IDs across accounts.
- NAT/VPN/workload/DMS/DataSync features are disabled by default.
- Workload enablement requires an account-valid ACM certificate ARN, exact RDS engine version and Amazon Linux 2023 AMI ID.
- VPN enablement requires the intended customer gateway outside IPv4 address.
- DMS enablement requires account ID, source secret ARN and benchmark-selected DMS replication class.
- DataSync enablement requires account ID, an activated VPC-endpoint agent ARN and NFS source hostname/export.

## CI validation

GitHub Actions runs:

1. `terraform fmt -check -recursive`
2. `terraform init -backend=false`
3. `terraform validate`
4. Python static assertions for subnet count, route propagation, security-group boundaries, DMS IAM trust and DataSync endpoint configuration.
5. Safe-default no-refresh plan with chargeable feature flags disabled.
6. Full synthetic no-refresh plan with NAT, VPN, workload, DMS and DataSync enabled, using dummy credentials and reserved/example identifiers.

The no-refresh plans do not call AWS APIs. They validate Terraform graph structure and provider schema, not actual resource availability, IAM acceptance, quota, pricing, endpoint activation, network connectivity or application behaviour.

## Local validation — Windows PowerShell

From the repository root:

```powershell
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false
terraform -chdir=terraform validate
python scripts/validate_network_spec.py
terraform -chdir=terraform plan -refresh=false -input=false
```

For a real account plan, first confirm AWS identity and Region, supply account-valid AMI/certificate/engine/source-secret/agent inputs, and review all feature flags. Do not run `terraform apply` or start migration tasks without explicit approval.

## Known boundaries

- MGN staging is a single-AZ synthetic subnet; this is not an HA claim.
- MGN replication-template creation is a guarded CLI workflow; source-server onboarding and agent installation remain separate.
- DataSync VPC endpoint creation is automated; agent activation key retrieval and `create-agent` remain operator-controlled.
- DMS all-outbound SG egress follows current AWS DMS networking guidance; peer ingress remains tightly scoped. Review selected service mode and dependencies before deployment.
- Customer-side firewall, DNS, NTP, proxy and device configuration are not provisioned by this Terraform.
- No AWS apply, service activation, live connectivity test, source data transfer or cutover is claimed.
