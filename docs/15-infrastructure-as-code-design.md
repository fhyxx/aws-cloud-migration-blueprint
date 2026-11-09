# 15 — Infrastructure as Code Design and Implementation Notes

**ID:** CLI-AWS-IAC-015 | **Version:** 1.0 | **Status:** Network foundation code drafted — local Terraform validation pending  
**Related:** [Synthetic case-study decisions](14-synthetic-case-study-decisions.md), [Network configuration specification](13-network-configuration-specification.md), [Terraform network foundation](../terraform/README.md)

## 1. Implementation scope

The Terraform layers codify the fictional network, workload and migration-service foundations:

- VPC, DNS support/hostnames and Internet Gateway.
- Eleven subnets across two account-resolved Availability Zones (six steady-state and five migration-only).
- Dedicated route tables and explicit subnet associations.
- Public IGW routes and optional private-subnet NAT routes.
- S3 Gateway Endpoint for the two application route tables.
- Dedicated DataSync VPC service-endpoint and task-ENI subnets, each with a BGP source return route and no default route.
- Optional VGW, Customer Gateway, dynamic BGP Site-to-Site VPN and restricted route propagation.
- ALB, application, RDS, EFS, DMS, MGN staging and DataSync task security groups.
- Optional HTTPS ALB, EC2 Auto Scaling Group, RDS PostgreSQL Multi-AZ, encrypted EFS and synthetic health/API service.
- Optional DMS provisioned replication instance, Secrets Manager-backed PostgreSQL endpoints and stopped full-load-and-CDC task.
- Optional DataSync NFSv4.1-to-EFS task, private S3 archive bucket/location and task logging.

It intentionally does not create compute, database, file-system, load-balancer, DMS, MGN or DataSync workload resources. Those belong in later layers after this network foundation is formatted, validated, reviewed and planned.

## 2. Cost and deployment safety

Potentially material network and workload resources are opt-in:

| Variable | Default | Effect when enabled |
|---|---:|---|
| `create_nat_gateways` | `false` | Creates two NAT Gateways and two Elastic IPs; hourly and data-processing charges apply |
| `enable_site_to_site_vpn` | `false` | Creates VGW, Customer Gateway and VPN connection; VPN hourly/tunnel/public IPv4 charges apply |
| `enable_workload_resources` | `false` | Creates ALB, EC2 ASG, RDS Multi-AZ and EFS; compute, database, load balancer and storage charges apply |

Even the default configuration creates real AWS resources if applied. Do not apply without explicit permission. This repository work has not applied Terraform or created resources.

## 3. Network invariants encoded

1. Exactly nine logical subnet keys: public A/B, app A/B, DB A/B, MGN staging and DMS A/B.
2. Application and DB route tables never receive VGW route propagation.
3. VPN propagation is limited to MGN, DMS-A and DMS-B route tables.
4. DMS uses a dedicated security group with all outbound permitted per the documented DMS network recommendation; source/target ingress remains scoped.
5. MGN staging TCP 1500 ingress is restricted to the synthetic source application CIDR.
6. RDS TCP 5432 ingress is SG-referenced from application and temporary DMS peers.
7. EFS TCP 2049 ingress is SG-referenced from application and DataSync task ENIs.
8. S3 Gateway Endpoint is associated only with application route tables in this first layer.
9. NAT and VPN are disabled by default.

## 4. Engineering review notes

- Security-group peer rules use the dedicated `aws_vpc_security_group_ingress_rule` and `aws_vpc_security_group_egress_rule` resources (rather than legacy inline rules or the older aggregate rule resource). This avoids cyclic dependencies between ALB/App, App/RDS, App/EFS and EFS/DataSync SGs and follows current AWS provider guidance.
- AZ names are resolved from the first two available AZs in the selected account. Confirm their AZ IDs and ensure they match the intended regional deployment before applying.
- The current route model sends DMS-A through NAT-A, DMS-B through NAT-B and MGN staging through NAT-A when NAT is enabled. DataSync endpoint and task ENI subnets have no default route; both receive the source BGP route to preserve return traffic to the on-premises agent. This is an illustrative same-AZ egress model; validate service endpoint reachability and cost.
- The DMS egress policy is intentionally broad outbound. It is not broad inbound. Security approval and selected DMS mode review remain mandatory.
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

CI has been added but has not yet been observed running successfully. Local Windows validation is still required to verify the exact provider lock, formatted HCL and a no-refresh plan against the intended provider version. The first plan should use `create_nat_gateways=false` and `enable_site_to_site_vpn=false`.

## 6. Next implementation layers

Proceed without waiting for synthetic customer input:

1. Complete local `terraform fmt`, `init -backend=false`, `validate` and static plan review.
2. Correct any HCL/provider issues revealed by CI or local validation.
3. Add ALB, ACM/DNS assumptions, launch template/ASG and application health-check contract.
4. Add RDS subnet group/parameter and option groups, encryption, backup/monitoring and deletion protection.
5. Add EFS, mount targets, encryption and backup policy.
6. Add DMS replication configuration only after source/target versions and migration-mode assumptions are explicitly represented.
7. Add MGN and DataSync service resources with endpoint-specific network paths.
8. Add test harnesses, security scanning, cost scenarios and operational runbooks.

**Current truth:** Terraform network, workload and migration-service layers and CI checks are drafted on a feature branch. They are not locally validated, not yet merged, and not deployed.
