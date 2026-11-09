locals {
  mgn_service_role_definitions = {
    replication_server = {
      name      = "AWSApplicationMigrationReplicationServerRole"
      principal = "ec2.amazonaws.com"
    }
    conversion_server = {
      name      = "AWSApplicationMigrationConversionServerRole"
      principal = "ec2.amazonaws.com"
    }
    mgh = {
      name      = "AWSApplicationMigrationMGHRole"
      principal = "mgn.amazonaws.com"
    }
    launch_drs = {
      name      = "AWSApplicationMigrationLaunchInstanceWithDrsRole"
      principal = "ec2.amazonaws.com"
    }
    launch_ssm = {
      name      = "AWSApplicationMigrationLaunchInstanceWithSsmRole"
      principal = "ec2.amazonaws.com"
    }
    fsx_proxy = {
      name      = "AWSApplicationMigrationFsxProxyRole"
      principal = "mgn.amazonaws.com"
    }
    fsx_proxy_link = {
      name      = "AWSApplicationMigrationFsxProxyLinkRole"
      principal = "mgn.amazonaws.com"
    }
  }

  mgn_service_role_policy_attachments = {
    replication_server = {
      role_key   = "replication_server"
      policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationReplicationServerPolicy"
    }
    conversion_server = {
      role_key   = "conversion_server"
      policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationConversionServerPolicy"
    }
    mgh = {
      role_key   = "mgh"
      policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationMGHAccess"
    }
    launch_drs_ssm = {
      role_key   = "launch_drs"
      policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
    launch_drs_drs = {
      role_key   = "launch_drs"
      policy_arn = "arn:aws:iam::aws:policy/AWSElasticDisasterRecoveryEc2InstancePolicy"
    }
    launch_ssm = {
      role_key   = "launch_ssm"
      policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    }
    fsx_proxy = {
      role_key   = "fsx_proxy"
      policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationFSxProxyPolicy"
    }
    fsx_proxy_link = {
      role_key   = "fsx_proxy_link"
      policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationFSxProxyVPCPolicy"
    }
  }
}

resource "aws_iam_role" "mgn_service" {
  for_each = var.enable_mgn_resources ? local.mgn_service_role_definitions : {}

  name = each.value.name
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = each.value.principal }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.tags, { Purpose = "AWS-MGN-service-initialization" })
}

resource "aws_iam_role_policy_attachment" "mgn_service" {
  for_each = var.enable_mgn_resources ? local.mgn_service_role_policy_attachments : {}

  role       = aws_iam_role.mgn_service[each.value.role_key].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_role" "mgn_agent" {
  count = var.enable_mgn_resources ? 1 : 0

  name = "AWSApplicationMigrationAgentRole"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "mgn.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:SetSourceIdentity"]
      Condition = {
        StringLike   = { "sts:SourceIdentity" = "s-*" }
        StringEquals = { "aws:SourceAccount" = var.aws_account_id }
      }
    }]
  })

  tags = merge(var.tags, { Purpose = "AWS-MGN-agent-service-role" })
}

resource "aws_iam_role_policy_attachment" "mgn_agent" {
  count = var.enable_mgn_resources ? 1 : 0

  role       = aws_iam_role.mgn_agent[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationAgentPolicy_v2"
}

resource "terraform_data" "mgn_prerequisites" {
  count = var.enable_mgn_resources ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.aws_account_id != null
      error_message = "Set the 12-digit AWS account ID before enabling MGN service initialization roles."
    }

    precondition {
      condition     = var.enable_site_to_site_vpn && var.create_nat_gateways
      error_message = "MGN service initialization requires the VPN and NAT network paths in this synthetic design."
    }
  }
}

output "mgn_service_role_names" {
  description = "MGN service role names created for regional service initialization."
  value       = var.enable_mgn_resources ? concat([for role in aws_iam_role.mgn_service : role.name], [aws_iam_role.mgn_agent[0].name]) : []
}
