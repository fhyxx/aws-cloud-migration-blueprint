#!/usr/bin/env python3
"""Static assertions for the fictional Clafoke network/Terraform baseline."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
main = (ROOT / "terraform" / "main.tf").read_text()
variables = (ROOT / "terraform" / "variables.tf").read_text()
decisions = (ROOT / "docs" / "14-synthetic-case-study-decisions.md").read_text()
spec = (ROOT / "docs" / "13-network-configuration-specification.md").read_text()

required_subnets = [
    "public_a", "public_b", "app_a", "app_b", "db_a", "db_b",
    "mgn", "dms_a", "dms_b",
]
for subnet in required_subnets:
    assert any(line.strip().startswith(subnet) and "=" in line for line in main.splitlines()), f"Missing subnet definition: {subnet}"

assert 'toset(["mgn", "dms_a", "dms_b"])' in main, "VPN propagation scope drifted"
assert 'route_table_ids = [' in main and '"app_a"' in main and '"app_b"' in main, "S3 endpoint app associations missing"
assert 'create_nat_gateways' in variables and 'default     = false' in variables, "NAT must remain opt-in"
assert 'enable_site_to_site_vpn' in variables and 'default     = false' in variables, "VPN must remain opt-in"
assert 'ip_protocol       = "-1"' in main and 'cidr_ipv4         = "0.0.0.0/0"' in main, "DMS all-egress baseline missing"
assert 'referenced_security_group_id = aws_security_group.alb.id' in main, "App ingress must be ALB SG-only"
assert 'referenced_security_group_id = aws_security_group.dms.id' in main, "Temporary RDS ingress must be DMS SG-only"
assert 'cidr_ipv4         = var.source_app_cidr' in main, "MGN staging source scope missing"
assert "No public SSH" in decisions, "Synthetic security decisions missing"
assert "NCS-21" in spec, "Network acceptance catalogue missing"
assert "terraform apply" in decisions, "No-apply safety rule missing"

print("PASS: nine subnets, scoped VPN propagation, S3 endpoint associations, opt-in NAT/VPN, DMS egress, SG boundaries, MGN source scope and acceptance catalogue.")
