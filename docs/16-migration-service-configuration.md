# 16 — Migration Service Configuration and Activation Runbook

**ID:** CLI-AWS-MSA-016 | **Version:** 1.3 | **Status:** Prepared for synthetic portfolio execution — no service activation or migration run  
**Related:** [Terraform network/workload/migration foundation](../terraform/README.md), [Migration strategy](04-data-migration-strategy.md), [Migration runbook](05-migration-runbook.md), [Network configuration](13-network-configuration-specification.md), [Synthetic decisions](14-synthetic-case-study-decisions.md)

## 1. Purpose

This runbook closes the gap between Terraform-managed network resources and migration services that require appliance activation, secret material or explicit task lifecycle control.

Terraform now models optional DMS and DataSync resources, including the actual DataSync Interface VPC service endpoint. MGN replication-template creation is handled by a guarded AWS CLI PowerShell script because source-server onboarding and agent activation remain a separate MGN service workflow.

**Safety:** all migration Terraform flags default to false. No source secret, DataSync activation key, DataSync agent activation, MGN agent install, task start, replication start or AWS apply has been executed.

## 2. Migration service Terraform flags

| Flag | Default | What it creates when enabled | External prerequisites |
|---|---:|---|---|
| `enable_dms_resources` | false | DMS VPC/CloudWatch roles, endpoint secret role, two-AZ replication subnet group, private replication instance, PostgreSQL source/target endpoints and stopped full-load-and-CDC task | Workload/RDS target enabled; NAT and VPN enabled; source Secrets Manager ARN; benchmark-selected DMS class |
| `enable_datasync_resources` | false | NFSv4.1 source location, EFS destination, stopped NFS-to-EFS task, CloudWatch log group, private S3 archive bucket/location and S3 access role | Workload/EFS enabled; VPN enabled; activated VPC-endpoint DataSync agent ARN; NFS hostname/export |
| MGN template | external script | Replication configuration template only | Terraform-created MGN staging subnet and SG IDs; selected replication server type; valid AWS profile |

Do not enable these flags merely to make a plan look complete. Each creates chargeable resources or migration configuration. The DMS replication task is created stopped; the DataSync task is created but not started.

## 3. DMS endpoint secret contract

The source PostgreSQL secret must be stored in AWS Secrets Manager outside this repository and contain the DMS connection fields expected by the selected PostgreSQL endpoint, with the four required endpoint-authentication fields: lowercase `username`, `password`, `port` and `host`. Set the database name separately through the DMS endpoint configuration. Do not put credentials in `.tfvars`, command-line arguments, shell history or Git.

The target endpoint references the RDS-managed master-user secret created by the RDS instance. The endpoint access role is limited to the source and target secret ARNs and uses the regional DMS service principal with SourceAccount/SourceArn conditions. A customer-managed source-secret KMS key can be granted explicitly through `source_secret_kms_key_arn`; the optional decrypt permission is restricted to calls via the regional Secrets Manager service and the source secret ARN encryption context. The default AWS-managed Secrets Manager key needs no extra KMS permission. The DMS service roles use the exact required names `dms-vpc-role` and `dms-cloudwatch-logs-role`, with an `aws:SourceAccount` trust condition. The identity that creates endpoints also needs `iam:GetRole`, `iam:PassRole` and `secretsmanager:DescribeSecret` for the selected secret/role.

Before enabling DMS:

1. Capture exact source PostgreSQL version/patch and validate the target RDS major/minor version against the current DMS compatibility matrix.
2. Validate logical replication permissions, `wal_level=logical`, slots/senders, WAL retention and disk headroom.
3. Inventory primary keys/replica identity and schema/object migration approach.
4. Benchmark full load and CDC; choose `dms_replication_instance_class` from evidence, not the source VM size.
5. Confirm source secret JSON and target RDS managed secret availability.
6. Run endpoint connection tests and review DMS logs before starting the task.
7. Keep `start_replication_task=false` until the approved migration window.

## 4. DataSync VPC endpoint and agent activation

The synthetic private DataSync topology is:

- Agent host: `10.50.20.50/32`, close to the NFSv4.1 source.
- VPC service endpoint subnet: `10.30.51.0/24`, AZ-A, route table with BGP source return route.
- DataSync task ENI subnet: `10.30.52.0/24`, AZ-A, route table with BGP source return route.
- Endpoint SG: inbound TCP 1024–1064 from agent /32 only.
- Task ENI SG: inbound TCP 443 from agent /32; outbound TCP 2049 to EFS mount-target SG.
- EFS mount target A is in AZ-A; the task ENI subnet is also AZ-A.

Terraform creates `aws_vpc_endpoint.datasync` in the dedicated endpoint subnet with the dedicated endpoint SG when `enable_datasync_resources=true`. Its service name is `com.amazonaws.<region>.datasync`; private DNS is disabled because the agent is explicitly associated to the endpoint ID. The outputs `datasync_vpc_endpoint_id`, `datasync_vpc_endpoint_network_interface_ids`, `datasync_endpoint_subnet_arn` and `datasync_endpoint_security_group_arn` supply the activation details. The `datasync_endpoint_subnet_id`, `datasync_endpoint_security_group_id` and `datasync_task_subnet_id` outputs are also available for inspection. Activation key and agent credentials are not stored in Terraform.

To locate the endpoint private IP, use `aws ec2 describe-network-interfaces --network-interface-ids <eni-id> --query 'NetworkInterfaces[0].PrivateIpAddress' --output text` for an ID from `datasync_vpc_endpoint_network_interface_ids`. Obtain the agent activation key from the agent local console or the documented HTTP activation-key flow, then create the agent using the AWS Console or `aws datasync create-agent` with the endpoint ID, subnet ARN and SG ARN. Do not commit the activation key, place it in `.tfvars`, or paste it into shell history. After activation, supply the returned agent ARN as `datasync_agent_arn`, and the synthetic/actual NFS host and export as `nfs_source_hostname` and `nfs_source_subdirectory`. The task is Basic-mode by default and uses NFSv4.1/TLS 1.2 to EFS. The separate S3 location uses the `archives` prefix without a leading slash to comply with Basic-mode S3 prefix restrictions. Confirm the selected task mode and agent compatibility in the current Region before enabling it.

The archive bucket and S3 location are provisioned only when DataSync resources are enabled. The S3 location prefix is `archives` (no leading slash), which is compatible with DataSync Basic-mode prefix restrictions. No archive transfer task is created because the archive source type/location is not part of the synthetic discovery baseline.

## 5. MGN replication configuration template

The script [configure-mgn-replication-template.ps1](../scripts/configure-mgn-replication-template.ps1) creates a replication configuration template only. It does not install MGN agents, register source servers, launch test instances, start replication or cut over.

Default script behaviour is dry-run. It requires explicit `-Execute` to call AWS and uses PowerShell `ShouldProcess` confirmation. It configures:

- Staging subnet and custom replication-server security group.
- Private-IP data-plane routing and no public IP.
- EBS encryption using the account default key.
- GP3 large staging disk.
- No dedicated replication server by default.
- An operator-supplied replication server instance type and bandwidth throttle.

Example dry-run after Terraform network outputs exist:

```powershell
.\scripts\configure-mgn-replication-template.ps1 `
  -StagingSubnetId "subnet-REPLACE_WITH_OUTPUT" `
  -ReplicationSecurityGroupId "sg-REPLACE_WITH_OUTPUT" `
  -ReplicationServerInstanceType "REPLACE_AFTER_SOURCE_PROFILE" `
  -Profile "portfolio" `
  -Region "us-east-1"
```

Only after reviewing the displayed account, Region, subnet, SG and instance type should an operator use `-Execute`. The script will then request PowerShell confirmation. Choose the replication server instance type after source disk/change-rate profiling; no class is asserted as production-sized.

## 6. Ordered migration validation

1. Confirm VPC route tables and VPN/BGP state; source routes must reach only DMS, MGN and DataSync migration subnets.
2. Confirm MGN source TCP 443, source-to-staging TCP 1500, staging service TCP 443 and required S3 access; ensure no SSL interception on documented MGN paths.
3. Activate DataSync VPC endpoint agent; test TCP 1024–1064 to endpoint, TCP 443 to task ENI, NFSv4.1 TCP 2049 to source and task ENI TCP 2049 to EFS.
4. Verify DataSync task report, file counts, bytes, metadata and final delta; do not equate task creation with transfer success.
5. Create DMS endpoints; run endpoint tests; verify source/target SSL and secret access.
6. Run DMS full-load/CDC only in an approved migration window; measure full-load duration, CDC latency and WAL headroom.
7. Reconcile PostgreSQL schema objects and sequences after CDC stops; DMS does not continuously synchronize sequence state.
8. Keep all tasks stopped until the migration plan, rollback, data owner and business go/no-go are approved.

## 7. References

- [AWS DMS IAM roles and confused-deputy guidance](https://docs.aws.amazon.com/dms/latest/userguide/security-iam.html)
- [AWS DMS Secrets Manager endpoint authentication](https://docs.aws.amazon.com/dms/latest/userguide/security_iam_secretsmanager.html)
- [AWS DMS network setup](https://docs.aws.amazon.com/dms/latest/userguide/CHAP_ReplicationInstance.VPC.html)
- [AWS DataSync network requirements](https://docs.aws.amazon.com/datasync/latest/userguide/datasync-network.html)
- [AWS DataSync service endpoint selection](https://docs.aws.amazon.com/datasync/latest/userguide/choose-service-endpoint.html)
- [AWS DataSync cross-service confused deputy prevention](https://docs.aws.amazon.com/datasync/latest/userguide/cross-service-confused-deputy-prevention.html)
- [AWS MGN replication configuration template CLI](https://docs.aws.amazon.com/cli/latest/reference/mgn/create-replication-configuration-template.html)
- [AWS MGN network requirements](https://docs.aws.amazon.com/mgn/latest/ug/preparing-environments.html)

**Execution status:** code and activation instructions are prepared. No migration service has been activated, no task has been started and no source data has moved.