data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_a = data.aws_availability_zones.available.names[0]
  az_b = data.aws_availability_zones.available.names[1]

  subnets = {
    public_a = { cidr = "10.30.1.0/24",  az = local.az_a }
    public_b = { cidr = "10.30.2.0/24",  az = local.az_b }
    app_a    = { cidr = "10.30.11.0/24", az = local.az_a }
    app_b    = { cidr = "10.30.12.0/24", az = local.az_b }
    db_a     = { cidr = "10.30.21.0/24", az = local.az_a }
    db_b     = { cidr = "10.30.22.0/24", az = local.az_b }
    mgn      = { cidr = "10.30.31.0/24", az = local.az_a }
    dms_a    = { cidr = "10.30.41.0/24", az = local.az_a }
    dms_b    = { cidr = "10.30.42.0/24", az = local.az_b }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-igw" })
}

resource "aws_subnet" "this" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = startswith(each.key, "public_")

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${replace(each.key, "_", "-")}"
    Tier = startswith(each.key, "public_") ? "public" : contains(["app_a", "app_b"], each.key) ? "application" : contains(["db_a", "db_b"], each.key) ? "database" : "migration"
  })
}

resource "aws_eip" "nat" {
  for_each = var.create_nat_gateways ? toset(["a", "b"]) : toset([])
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.name_prefix}-nat-${each.key}-eip" })
}

resource "aws_nat_gateway" "this" {
  for_each = var.create_nat_gateways ? { a = "public_a", b = "public_b" } : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.this[each.value].id

  depends_on = [aws_internet_gateway.this]
  tags       = merge(var.tags, { Name = "${var.name_prefix}-nat-${each.key}" })
}

resource "aws_route_table" "this" {
  for_each = toset([
    "public_a", "public_b", "app_a", "app_b",
    "db_a", "db_b", "mgn", "dms_a", "dms_b"
  ])

  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.name_prefix}-rt-${replace(each.key, "_", "-")}" })
}

resource "aws_route_table_association" "this" {
  for_each = local.subnets

  subnet_id      = aws_subnet.this[each.key].id
  route_table_id = aws_route_table.this[each.key].id
}

resource "aws_route" "public_default" {
  for_each = toset(["public_a", "public_b"])

  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route" "app_nat_default" {
  for_each = var.create_nat_gateways ? { app_a = "a", app_b = "b" } : {}

  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.value].id
}

resource "aws_route" "migration_nat_default" {
  for_each = var.create_nat_gateways ? { mgn = "a", dms_a = "a", dms_b = "b" } : {}

  route_table_id         = aws_route_table.this[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.value].id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = [
    aws_route_table.this["app_a"].id,
    aws_route_table.this["app_b"].id
  ]

  tags = merge(var.tags, { Name = "${var.name_prefix}-s3-gateway-endpoint" })
}

resource "aws_vpn_gateway" "this" {
  count           = var.enable_site_to_site_vpn ? 1 : 0
  vpc_id          = aws_vpc.this.id
  amazon_side_asn = var.vgw_asn
  tags            = merge(var.tags, { Name = "${var.name_prefix}-vgw" })
}

resource "aws_customer_gateway" "this" {
  count      = var.enable_site_to_site_vpn ? 1 : 0
  bgp_asn    = var.customer_gateway_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"
  tags       = merge(var.tags, { Name = "${var.name_prefix}-customer-gateway" })

  lifecycle {
    precondition {
      condition     = var.customer_gateway_ip != null && can(cidrhost("${var.customer_gateway_ip}/32", 0))
      error_message = "Set customer_gateway_ip to the customer gateway's real public IPv4 address before enabling VPN."
    }
  }
}

resource "aws_vpn_connection" "this" {
  count               = var.enable_site_to_site_vpn ? 1 : 0
  vpn_gateway_id      = aws_vpn_gateway.this[0].id
  customer_gateway_id = aws_customer_gateway.this[0].id
  type                = "ipsec.1"
  static_routes_only  = false
  tags                = merge(var.tags, { Name = "${var.name_prefix}-s2s-vpn" })
}

resource "aws_vpn_gateway_route_propagation" "migration" {
  for_each = var.enable_site_to_site_vpn ? toset(["mgn", "dms_a", "dms_b"]) : toset([])

  vpn_gateway_id = aws_vpn_gateway.this[0].id
  route_table_id = aws_route_table.this[each.key].id
}

# Security group resources are declared without inline peer rules. Separate
# aws_security_group_rule resources avoid cyclic SG-to-SG dependencies.

resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "HTTPS ingress from clients; forwards to application targets."
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-alb-sg" })
}

resource "aws_security_group" "app" {
  name        = "${var.name_prefix}-app-sg"
  description = "Application ingress only from ALB."
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-app-sg" })
}

resource "aws_security_group" "rds" {
  name        = "${var.name_prefix}-rds-sg"
  description = "PostgreSQL accepts application and migration traffic only."
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-rds-sg" })
}

resource "aws_security_group" "efs" {
  name        = "${var.name_prefix}-efs-sg"
  description = "NFS only from application and DataSync task ENIs."
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-efs-sg" })
}

resource "aws_security_group" "dms" {
  name        = "${var.name_prefix}-dms-sg"
  description = "Dedicated DMS SG; all outbound follows AWS DMS network guidance."
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-dms-sg" })
}

resource "aws_security_group" "mgn_staging" {
  name        = "${var.name_prefix}-mgn-staging-sg"
  description = "MGN staging replication traffic from synthetic source application subnet."
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-mgn-staging-sg" })
}

resource "aws_security_group" "datasync_task" {
  name        = "${var.name_prefix}-datasync-task-sg"
  description = "DataSync task ENIs access EFS over NFS."
  vpc_id      = aws_vpc.this.id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-datasync-task-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_ingress" {
  security_group_id = aws_security_group.alb.id
  description       = "Public HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to application targets"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Application listener from ALB only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_to_rds" {
  security_group_id            = aws_security_group.app.id
  description                  = "Application to PostgreSQL"
  referenced_security_group_id = aws_security_group.rds.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_to_efs" {
  security_group_id            = aws_security_group.app.id
  description                  = "Application to EFS"
  referenced_security_group_id = aws_security_group.efs.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_app" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Application PostgreSQL"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_dms" {
  security_group_id            = aws_security_group.rds.id
  description                  = "Temporary DMS PostgreSQL target access"
  referenced_security_group_id = aws_security_group.dms.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "efs_from_app" {
  security_group_id            = aws_security_group.efs.id
  description                  = "Application NFS"
  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "efs_from_datasync" {
  security_group_id            = aws_security_group.efs.id
  description                  = "DataSync task ENI NFS"
  referenced_security_group_id = aws_security_group.datasync_task.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "dms_all_egress" {
  security_group_id = aws_security_group.dms.id
  description       = "AWS DMS documented all-outbound baseline; restrict peer ingress and subnet routing."
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "mgn_source_to_staging" {
  security_group_id = aws_security_group.mgn_staging.id
  description       = "MGN replication stream from synthetic source VMs"
  cidr_ipv4         = var.source_app_cidr
  from_port         = 1500
  to_port           = 1500
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "mgn_https_egress" {
  security_group_id = aws_security_group.mgn_staging.id
  description       = "MGN service HTTPS and documented service dependencies"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "datasync_task_to_efs" {
  security_group_id            = aws_security_group.datasync_task.id
  description                  = "DataSync task ENI to EFS mount target"
  referenced_security_group_id = aws_security_group.efs.id
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}
