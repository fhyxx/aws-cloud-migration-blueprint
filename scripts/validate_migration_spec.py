#!/usr/bin/env python3
"""Static safety assertions for Clafoke's optional migration-service layer.

These checks validate repository intent only. They do not call AWS APIs,
prove IAM acceptance, activate agents, test connectivity, or run migrations.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
variables = (ROOT / "terraform" / "variables.tf").read_text()
main = (ROOT / "terraform" / "main.tf").read_text()
migration = (ROOT / "terraform" / "migration.tf").read_text()
mgn = (ROOT / "terraform" / "mgn.tf").read_text()
mgn_script = (ROOT / "scripts" / "configure-mgn-replication-template.ps1").read_text()


def assert_flag_off(name: str) -> None:
    match = re.search(
        rf'variable\s+"{re.escape(name)}"\s*\{{(.*?)\n\}}',
        variables,
        re.DOTALL,
    )
    assert match, f"Missing feature flag: {name}"
    assert re.search(r"default\s*=\s*false\b", match.group(1)), (
        f"{name} must default to false"
    )


for flag in (
    "enable_dms_resources",
    "enable_datasync_resources",
    "enable_mgn_resources",
):
    assert_flag_off(flag)

# DMS: explicit prerequisites, private two-AZ placement, secret-backed TLS
# endpoints, and a task that is created but never auto-started.
assert (
    "var.enable_workload_resources && var.create_nat_gateways "
    "&& var.enable_site_to_site_vpn"
) in migration, "DMS prerequisites must require workload, NAT and VPN"
assert (
    'subnet_ids                           = '
    '[aws_subnet.this["dms_a"].id, aws_subnet.this["dms_b"].id]'
) in migration, "DMS must use the dedicated two-AZ subnet group"
assert "publicly_accessible         = false" in migration, (
    "DMS replication instance must remain private"
)
assert "start_replication_task   = false" in migration, (
    "DMS task must remain stopped after creation"
)
assert 'migration_type           = "full-load-and-cdc"' in migration
assert migration.count('ssl_mode                        = "require"') == 2, (
    "Both PostgreSQL DMS endpoints must require TLS"
)
assert "secrets_manager_arn" in migration
assert "secrets_manager_access_role_arn" in migration
assert '"secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"' in migration
assert "aws:SourceAccount" in migration and "aws:SourceArn" in migration
assert 'dms.${' + 'var.aws_region}.amazonaws.com' in migration, (
    "DMS endpoint secret role must use the regional service principal"
)
assert '"kms:ViaService"' in migration
assert '"kms:EncryptionContext:SecretARN"' in migration
assert "Resource = var.source_secret_kms_key_arn" in migration, (
    "Optional source-secret CMK decrypt must target the exact key ARN"
)

# DataSync: private endpoint, explicit agent/source inputs, protected S3 target,
# scoped archive prefix, NFSv4.1, and encrypted EFS transport.
assert 'resource "aws_vpc_endpoint" "datasync"' in main
assert 'vpc_endpoint_type   = "Interface"' in main
assert "private_dns_enabled = false" in main
assert "var.datasync_agent_cidr" in main
assert "var.datasync_agent_arn != null" in migration
assert 'version = "NFS4_1"' in migration
assert 'in_transit_encryption = "TLS1_2"' in migration
assert 'preserve_deleted_files = "PRESERVE"' in migration
assert 'verify_mode            = "ONLY_FILES_TRANSFERRED"' in migration
assert 'transfer_mode          = "CHANGED"' in migration
assert "force_destroy = false" in migration
for setting in (
    "block_public_acls       = true",
    "block_public_policy     = true",
    "ignore_public_acls      = true",
    "restrict_public_buckets = true",
):
    assert setting in migration, f"Archive bucket missing control: {setting}"
assert 'sse_algorithm = "AES256"' in migration
assert 'status = "Enabled"' in migration
assert 'subdirectory     = "archives"' in migration, (
    "Basic-mode S3 destination prefix must be the relative archives prefix"
)
assert '"${' + 'aws_s3_bucket.archive[0].arn}/archives/*"' in migration, (
    "DataSync object permissions must be restricted to the archive prefix"
)
assert "aws:SourceAccount" in migration and "aws:SourceArn" in migration

# MGN: service roles remain opt-in and bootstrap is operator-confirmed,
# identity-checked, resumable, and configured without public IP assignment.
assert 'path = "/service-role/"' in mgn
assert "AWSApplicationMigrationAgentPolicy_v2" in mgn
assert "sts:SetSourceIdentity" in mgn and "sts:SourceIdentity" in mgn
assert "SupportsShouldProcess = $true" in mgn_script
assert "[switch]$Execute" in mgn_script
assert "if (-not $Execute)" in mgn_script
assert "aws sts get-caller-identity" in mgn_script
assert "ShouldProcess(" in mgn_script
assert 'dataPlaneRouting                    = "PRIVATE_IP"' in mgn_script
assert "createPublicIP                      = $false" in mgn_script
assert 'launchDisposition                   = "STOPPED"' in mgn_script
assert "associatePublicIpAddress             = $false" in mgn_script
assert "describe-replication-configuration-templates" in mgn_script
assert "describe-launch-configuration-templates" in mgn_script
assert "Existing templates are never overwritten" in mgn_script


# Architecture views: the editable Mermaid sources must match their rendered
# Markdown blocks, and network labels must match the Terraform subnet/route
# implementation rather than an obsolete pre-migration design.
architecture_dir = ROOT / "architecture"
runtime_source = (architecture_dir / "runtime-network-view.mmd").read_text().strip()
runtime_view = (architecture_dir / "runtime-network-view.md").read_text()
target_source = (architecture_dir / "target-architecture.mmd").read_text().strip()
target_view = (architecture_dir / "target-architecture.md").read_text()
migration_source = (architecture_dir / "migration-data-flow.mmd").read_text().strip()
migration_view = (architecture_dir / "migration-data-flow.md").read_text()
network_spec = (ROOT / "docs" / "13-network-configuration-specification.md").read_text()


def embedded_mermaid(markdown: str) -> str:
    match = re.search(r"```mermaid\s*(.*?)```", markdown, re.DOTALL)
    assert match, "Rendered Markdown page must contain a Mermaid block"
    return match.group(1).strip()


assert embedded_mermaid(runtime_view) == runtime_source, (
    "Runtime/network rendered diagram drifted from its editable Mermaid source"
)
assert embedded_mermaid(target_view) == target_source, (
    "Target architecture rendered diagram drifted from its editable Mermaid source"
)
assert embedded_mermaid(migration_view) == migration_source, (
    "Migration data-flow rendered diagram drifted from its editable Mermaid source"
)
for cidr in (
    "10.30.31.0/24",
    "10.30.41.0/24",
    "10.30.42.0/24",
    "10.30.51.0/24",
    "10.30.52.0/24",
):
    assert cidr in runtime_source, f"Runtime view missing migration subnet {cidr}"
assert "No VGW propagation" in runtime_source, (
    "Application route tables must not receive the on-premises BGP aggregate"
)
assert "dedicated DMS-A/B subnets in two AZs" in migration_view, (
    "Migration view must identify the dedicated DMS subnet group"
)
assert "DMS reuses the two private application subnets" not in runtime_view + migration_view, (
    "Obsolete DMS/application subnet statement remains in runtime view"
)
assert "current Terraform baseline; non-Multi-AZ" in target_source
assert "non-Multi-AZ" in migration_source
assert "Provisioned DMS replication instance" in target_source
assert "Provisioned AWS DMS replication instance" in migration_source
assert "`0.0.0.0/0` (public HTTPS baseline)" in network_spec, (
    "Network specification must disclose the public ALB ingress baseline"
)
assert "instance or Serverless" not in target_source + migration_source, (
    "Diagrams must distinguish the provisioned Terraform baseline from an unimplemented Serverless alternative"
)

print(
    "PASS: migration flags default off; DMS is private, TLS/Secrets-Manager "
    "backed and stopped; DataSync endpoint, EFS transport and archive prefix "
    "are constrained; MGN bootstrap is guarded, resumable and private; "
    "all three architecture diagrams match their sources and route boundaries."
)
