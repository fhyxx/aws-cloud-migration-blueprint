# 15 — Infrastructure as Code Design and Implementation Notes

**ID:** CLI-AWS-IAC-015 | **Version:** 1.3 | **Status:** Network, workload and migration Terraform validated in CI — live account validation and deployment not performed  
**Related:** [Synthetic case-study decisions](14-synthetic-case-study-decisions.md), [Network configuration specification](13-network-configuration-specification.md), [Terraform network foundation](../terraform/README.md)

## 1. Implementation scope

The Terraform layers codify the fictional network, workload and migration-service foundations:

- VPC, DNS support/hostnames and Internet Gateway.
- Eleven subnets across two explicitly configured AZ name aliases (six steady-state and five migration-only). The synthetic defaults are `us-east-1a` and `us-east-1b`; resolve physical AZ IDs before real deployment.
- Dedicated route tables and explicit subnet associations.
- Public IGW routes and optional private-subnet NAT routes.
- S3 Gateway Endpoint for App-A, App-B and MGN staging route tables.
- Dedicated DataSync VPC service-endpoint and task-ENI subnets, each with a BGP source return route and no default route; an opt-in AWS DataSync Interface VPC endpoint is created in the endpoint subnet.
- Optional VGW, Customer Gateway, dynamic BGP Site-to-Site VPN and restricted route propagation.
- ALB, application, RDS, EFS, DMS, MGN staging and DataSync task security groups.
- Optional HTTPS ALB, EC2 Auto Scaling Group, RDS PostgreSQL Multi-AZ, encrypted EFS and synthetic health/API service.
- Optional DMS provisioned replication instance, Secrets Manager-backed PostgreSQL endpoints and stopped full-load-and-CDC task.
- Optional DataSync NFSv4.1-to-EFS task, private S3 archive bucket/location and task logging.

The opt-in workload layer creates the ALB, EC2 ASG, RDS and EFS when enabled. The opt-in migration layer creates DMS replication/endpoints/task, the DataSync Interface VPC endpoint, DataSync locations/task and private S3 archive destination when enabled. It does not activate the DataSync appliance, install MGN source agents, register source servers, start migration tasks or perform cutover.

## 2. Cost and deployment safety

Potentially material network and workload resources are opt-in:

| Variable | Default | Effect when enabled |
|---|---:|---|
| `create_nat_gateways` | `false` | Creates two NAT Gateways and two Elastic IPs; hourly and data-processing charges apply |
| `enable_site_to_site_vpn` | `false` | Creates VGW, Customer Gateway and VPN connection; VPN hourly/tunnel/public IPv4 charges apply |
| `enable_workload_resources` | `false` | Creates ALB, EC2 ASG, RDS Multi-AZ and EFS; compute, database, load balancer and storage charges apply |
| `enable_dms_resources` | `false` | Creates DMS replication instance, endpoints and stopped task; DMS instance/storage charges apply |
| `enable_datasync_resources` | `false` | Creates DataSync locations/task, log group and private S3 archive bucket; transfer/storage/log charges apply |

Even the default configuration creates real AWS resources if applied. Do not apply without explicit permission. This repository work has not applied Terraform or created resources.

## 3. Network invariants encoded

1. Exactly eleven logical subnet keys: public A/B, app A/B, DB A/B, MGN staging, DMS A/B and dedicated DataSync endpoint/task subnets.
2. Application and DB route tables never receive VGW route propagation.
3. VPN propagation is limited to MGN, DMS-A/B and the dedicated DataSync endpoint/task route tables.
4. DMS uses a dedicated security group with all outbound permitted per the documented DMS network recommendation; source/target ingress remains scoped.
5. MGN staging TCP 1500 ingress is restricted to the synthetic source application CIDR.
6. RDS TCP 5432 ingress is SG-referenced from application and temporary DMS peers.
7. EFS TCP 2049 ingress is SG-referenced from application and DataSync task ENIs.
8. S3 Gateway Endpoint is associated with App-A, App-B and MGN staging route tables.
9. NAT and VPN are disabled by default.

## 4. Engineering review notes

- Security-group peer rules use the dedicated `aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule` resources (rather than legacy inline rules or the older aggregate rule resource). This avoids cyclic dependencies between ALB/App, App/RDS, App/EFS and EFS/DataSync SGs and follows current AWS provider guidance.
- The synthetic defaults use the AZ name aliases `us-east-1a` and `us-east-1b`. AZ names map to different physical AZ IDs across accounts; resolve and confirm the intended AZ IDs before applying in a real account.
- The current route model sends DMS-A through NAT-A, DMS-B through NAT-B and MGN staging through NAT-A when NAT is enabled. DataSync endpoint and task ENI subnets have no default route; both receive the source BGP route to preserve return traffic to the on-premises agent. This is an illustrative same-AZ egress model; validate service endpoint reachability and cost.
- The DMS endpoint secret role uses the regional DMS service principal with SourceAccount/SourceArn conditions, exact secret ARNs and optional exact source CMK decrypt. The DMS egress policy is intentionally broad outbound. It is not broad inbound. Security approval and selected DMS mode review remain mandatory.
- The MGN SG allows TCP 443 egress to regional service dependencies and TCP 1500 ingress from source app CIDR. Validate the current regional service requirements before agent installation.
- DataSync task and endpoint SGs express agent-to-endpoint TCP 1024–1064, agent-to-task-ENI TCP 443 and task-ENI-to-EFS TCP 2049. The DataSync appliance must be activated separately with the Terraform endpoint subnet and SG outputs; its activation key is not stored in Terraform.
- Customer-side firewall rules are not created by Terraform; they require separate network-owner configuration and testing.
- The synthetic PostgreSQL source prefix is documented as an input but cannot be enforced by an AWS SG on a remote network. Enforce it on the customer firewall and test over the VPN.
- Terraform provider lock file must be generated by `terraform init` in the controlled local/CI environment and committed after provider selection is reviewed.

## 5. Validation workflow

The GitHub Actions workflow runs on Terraform-related pull requests and main-branch changes:

1. Terraform formatting check.
2. Terraform initialization with backend disabled.
3. Terraform validation.
4. Python static assertions for subnet count, route propagation scope, opt-in cost controls and security-group boundaries.
5. A safe-default no-refresh Terraform plan with all chargeable flags disabled.
6. A full synthetic no-refresh plan with NAT, VPN, workload, DMS and DataSync enabled using dummy credentials and reserved/example identifiers. Neither plan calls AWS or applies resources.

CI runs formatting, init, validate, static assertions, a default no-refresh plan with all cost-bearing flags disabled (61 resources), and a full synthetic feature plan with NAT, VPN, ALB/ASG, RDS/EFS, DMS and DataSync enabled (123 resources). Both use dummy credentials, synthetic AMI/certificate/secret/agent identifiers and no refresh, so they validate the Terraform resource graph without calling AWS. They do not validate service-side existence, account quotas, actual pricing or live connectivity. Local Windows validation is still required to verify the exact provider lock, formatted HCL and a no-refresh plan against the intended provider version. The first plan should use `create_nat_gateways=false` and `enable_site_to_site_vpn=false`.

## 6. Remaining engineering work

1. The AWS provider is pinned to `5.100.0`; `terraform/.terraform.lock.hcl` is committed with Linux/Windows checksums and CI uses `-lockfile=readonly`.
2. Run local Windows `fmt`, `init -backend=false`, `validate`, Python static checks and a no-refresh plan; compare provider version with CI.
3. MGN service IAM roles and policy attachments are now opt-in Terraform; the guarded CLI workflow initializes MGN and creates both templates. Verify initialization and template creation in an approved lab, then test source-agent onboarding separately.
4. Review whether the single-AZ MGN staging subnet is sufficient for the synthetic recovery objectives; document a deliberate multi-AZ/HA option and its cost/operational trade-off.
5. Add automated security scanning (Terraform static analysis, secret scanning, dependency review) and complete the migration-period cost model, including the DataSync endpoint and traffic.
6. Obtain a fresh visual check of all three Mermaid renderings after the DataSync endpoint/subnet updates.
7. Complete approved lab connectivity tests for DMS, MGN and DataSync; do not describe static plans as live service validation.

**Current truth:** the network, workload and migration Terraform layers, including the actual DataSync Interface VPC endpoint and hardened DMS/DataSync IAM trust policies, are merged to `main`. CI passed Terraform fmt, init, validate, static assertions, the 61-resource safe-default plan and the 123-resource full synthetic plan. No AWS resources have been applied, no DataSync agent has been activated, and no migration has run.
