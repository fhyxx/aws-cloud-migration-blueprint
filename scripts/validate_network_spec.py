#!/usr/bin/env python3
"""Static assertions for the fictional Clafoke network/Terraform baseline."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "terraform" / "main.tf").read_text()
variables = (ROOT / "terraform" / "variables.tf").read_text()
provider = (ROOT / "terraform" / "versions.tf").read_text()
decisions = (ROOT / "docs" / "14-synthetic-case-study-decisions.md").read_text()
spec = (ROOT / "docs" / "13-network-configuration-specification.md").read_text()
workloads = (ROOT / "terraform" / "workloads.tf").read_text()
migration = (ROOT / "terraform" / "migration.tf").read_text()

required_subnets = [
    "public_a", "public_b", "app_a", "app_b", "db_a", "db_b",
    "mgn", "dms_a", "dms_b", "datasync_endpoint", "datasync_task",
]
for subnet in required_subnets:
    assert any(line.strip().startswith(subnet) and "=" in line for line in main.splitlines()), f"Missing subnet definition: {subnet}"

assert 'toset(["mgn", "dms_a", "dms_b", "datasync_endpoint", "datasync_task"])' in main, "VPN propagation scope drifted"
assert 'route_table_ids = [' in main and '"app_a"' in main and '"app_b"' in main and '"mgn"' in main, "S3 endpoint app/MGN associations missing"
assert 'create_nat_gateways' in variables and 'default     = false' in variables, "NAT must remain opt-in"
assert 'enable_site_to_site_vpn' in variables and 'default     = false' in variables, "VPN must remain opt-in"
assert 'ip_protocol       = "-1"' in main and 'cidr_ipv4         = "0.0.0.0/0"' in main, "DMS all-egress baseline missing"
assert 'referenced_security_group_id = aws_security_group.alb.id' in main, "App ingress must be ALB SG-only"
assert 'referenced_security_group_id = aws_security_group.dms.id' in main, "Temporary RDS ingress must be DMS SG-only"
assert 'cidr_ipv4         = var.source_app_cidr' in main, "MGN staging source scope missing"
assert "No public SSH" in decisions, "Synthetic security decisions missing"
assert "NCS-21" in spec, "Network acceptance catalogue missing"
assert "terraform apply" in decisions, "No-apply safety rule missing"


assert 'variable "enable_workload_resources"' in variables and 'default     = false' in variables, "Workload resources must be opt-in"
assert 'condition     = var.create_nat_gateways' in workloads, "Workloads must require NAT or private endpoints"
assert 'aws_lb_listener" "https"' in workloads and 'path                = "/health/ready"' in workloads, "HTTPS ALB health-check baseline missing"
assert any(line.strip().startswith('manage_master_user_password') and 'true' in line for line in workloads.splitlines()), "RDS managed password baseline missing"
assert any(line.strip().startswith('multi_az') and 'true' in line for line in workloads.splitlines()), "RDS Multi-AZ baseline missing"
assert 'resource "aws_efs_backup_policy" "app"' in workloads, "EFS backup policy missing"
assert 'resource "aws_autoscaling_policy" "app_cpu"' in workloads, "ASG target tracking policy missing"


assert "datasync_endpoint" in main and "datasync_task" in main and 'toset(["mgn", "dms_a", "dms_b", "datasync_endpoint", "datasync_task"])' in main, "DataSync endpoint/task subnet and propagation missing"
assert "var.datasync_agent_cidr" in main and "from_port         = 1024" in main and "to_port           = 1064" in main, "DataSync VPC endpoint control-plane scope missing"
assert "from_port         = 443" in main and "var.datasync_agent_cidr" in main, "DataSync task ENI agent path missing"


assert 'default     = ["us-east-1a", "us-east-1b"]' in variables, "Synthetic two-AZ defaults missing"
assert "skip_credentials_validation" in provider and "skip_requesting_account_id" in provider, "CI no-refresh provider switches missing"
assert "aws_availability_zones" not in main, "Plan should not require live AZ discovery"


assert 'variable "ami_id"' in variables and 'variable "aws_account_id"' in variables, "Offline full-plan inputs missing"
assert "aws_ami" not in workloads and "aws_caller_identity" not in (ROOT / "terraform" / "migration.tf").read_text(), "Terraform plan must not require live data sources"


assert 'dms.${var.aws_region}.amazonaws.com' in migration, "DMS secret role must use regional service principal"
assert 'var.source_secret_kms_key_arn' in migration and 'Resource = "*"' not in migration, "DMS KMS decrypt must be scoped to an optional exact key"
assert 'var.aws_account_id' in migration and 'aws:SourceAccount' in migration, "DMS service trust must be account-scoped"
assert 'arn:aws:datasync:${var.aws_region}:${var.aws_account_id}:*' in migration and 'aws:SourceArn' in migration, "DataSync role trust must be Region/account-scoped"


assert 'resource "aws_vpc_endpoint" "datasync"' in main, "Private DataSync interface endpoint resource missing"
assert 'service_name        = "com.amazonaws.${var.aws_region}.datasync"' in main, "DataSync endpoint service name mismatch"
assert 'vpc_endpoint_type   = "Interface"' in main and 'aws_security_group.datasync_endpoint.id' in main, "DataSync endpoint must use dedicated SG"

assert '"kms:ViaService"' in migration and '"kms:EncryptionContext:SecretARN"' in migration, "DMS CMK use must be Secrets Manager-only and secret-scoped"
assert 'subdirectory     = "archives"' in migration, "DataSync Basic-mode S3 prefix must not begin with slash"

assert 'datasync_agent_cidr must be one valid IPv4 /32 host address' in variables, "DataSync agent must be a single host"
assert 'source_db_secret_arn must be a Secrets Manager secret ARN' in variables, "DMS source secret ARN validation missing"
assert 'source_secret_kms_key_arn must be a customer-managed KMS key ARN' in variables, "DMS source CMK ARN validation missing"

mgn = (ROOT / "terraform" / "mgn.tf").read_text()
assert 'variable "enable_mgn_resources"' in variables and 'default     = false' in variables, "MGN feature flag must be disabled by default"
assert 'AWSApplicationMigrationReplicationServerRole' in mgn and 'AWSApplicationMigrationAgentRole' in mgn, "MGN service roles missing"
assert 'AWSApplicationMigrationAgentPolicy_v2' in mgn and 'sts:SetSourceIdentity' in mgn and 'sts:SourceIdentity' in mgn, "MGN agent trust/policy missing"
assert 'AWSApplicationMigrationFsxProxyRole' in mgn and 'AWSApplicationMigrationFsxProxyLinkRole' in mgn, "MGN FSx proxy roles missing from service initialization baseline"
assert 'path = "/service-role/"' in mgn, "MGN roles must use the AWS-required service-role path"

print("PASS: eleven subnets, scoped VPN propagation, S3 endpoint associations, opt-in NAT/VPN/workloads/migration services, DMS IAM hardening, DataSync Interface endpoint, SG boundaries and acceptance catalogue.")
