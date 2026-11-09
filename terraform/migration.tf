resource "terraform_data" "dms_prerequisites" {
  count = var.enable_dms_resources ? 1 : 0
  input = true

  lifecycle {
    precondition {
      condition     = var.enable_workload_resources && var.create_nat_gateways && var.enable_site_to_site_vpn
      error_message = "DMS requires the workload target, NAT service egress and the synthetic Site-to-Site VPN path to be enabled."
    }
    precondition {
      condition     = var.source_db_secret_arn != null && var.dms_replication_instance_class != null && var.aws_account_id != null
      error_message = "Set the source PostgreSQL Secrets Manager ARN, benchmark-selected DMS replication class and 12-digit AWS account ID."
    }
  }
}

resource "aws_iam_role" "dms_vpc" {
  count = var.enable_dms_resources ? 1 : 0
  name  = "dms-vpc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dms.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = var.aws_account_id } }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "dms_vpc" {
  count      = var.enable_dms_resources ? 1 : 0
  role       = aws_iam_role.dms_vpc[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
}

resource "aws_iam_role" "dms_cloudwatch" {
  count = var.enable_dms_resources ? 1 : 0
  name  = "dms-cloudwatch-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dms.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = var.aws_account_id } }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "dms_cloudwatch" {
  count      = var.enable_dms_resources ? 1 : 0
  role       = aws_iam_role.dms_cloudwatch[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSCloudWatchLogsRole"
}

resource "aws_iam_role" "dms_endpoint_access" {
  count = var.enable_dms_resources ? 1 : 0
  name  = "${var.name_prefix}-dms-endpoint-secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dms.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = var.aws_account_id } }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "dms_endpoint_secrets" {
  count = var.enable_dms_resources ? 1 : 0
  name  = "${var.name_prefix}-dms-endpoint-secrets"
  role  = aws_iam_role.dms_endpoint_access[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [
          var.source_db_secret_arn,
          aws_db_instance.app[0].master_user_secret[0].secret_arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_dms_replication_subnet_group" "this" {
  count = var.enable_dms_resources ? 1 : 0

  replication_subnet_group_id          = "${var.name_prefix}-dms-subnets"
  replication_subnet_group_description = "Dedicated two-AZ migration subnet group."
  subnet_ids                           = [aws_subnet.this["dms_a"].id, aws_subnet.this["dms_b"].id]

  tags = merge(var.tags, { Name = "${var.name_prefix}-dms-subnets" })

  depends_on = [aws_iam_role_policy_attachment.dms_vpc]
}

resource "aws_dms_replication_instance" "this" {
  count = var.enable_dms_resources ? 1 : 0

  replication_instance_id     = "${var.name_prefix}-dms-replication"
  replication_instance_class  = var.dms_replication_instance_class
  allocated_storage           = var.dms_allocated_storage
  publicly_accessible         = false
  multi_az                    = false
  auto_minor_version_upgrade  = true
  apply_immediately           = false
  replication_subnet_group_id = aws_dms_replication_subnet_group.this[0].id
  vpc_security_group_ids      = [aws_security_group.dms.id]

  tags = merge(var.tags, { Name = "${var.name_prefix}-dms-replication" })

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc,
    aws_iam_role_policy_attachment.dms_cloudwatch
  ]
}

resource "aws_dms_endpoint" "source_postgres" {
  count = var.enable_dms_resources ? 1 : 0

  endpoint_id                     = "${var.name_prefix}-postgres-source"
  endpoint_type                   = "source"
  engine_name                     = "postgres"
  database_name                   = var.database_name
  port                            = 5432
  ssl_mode                        = "require"
  secrets_manager_arn             = var.source_db_secret_arn
  secrets_manager_access_role_arn = aws_iam_role.dms_endpoint_access[0].arn

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres-source" })

  depends_on = [aws_iam_role_policy.dms_endpoint_secrets]
}

resource "aws_dms_endpoint" "target_postgres" {
  count = var.enable_dms_resources ? 1 : 0

  endpoint_id                     = "${var.name_prefix}-postgres-target"
  endpoint_type                   = "target"
  engine_name                     = "postgres"
  database_name                   = var.database_name
  port                            = 5432
  ssl_mode                        = "require"
  secrets_manager_arn             = aws_db_instance.app[0].master_user_secret[0].secret_arn
  secrets_manager_access_role_arn = aws_iam_role.dms_endpoint_access[0].arn

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres-target" })

  depends_on = [aws_iam_role_policy.dms_endpoint_secrets]
}

resource "aws_dms_replication_task" "postgres_full_load_cdc" {
  count = var.enable_dms_resources ? 1 : 0

  replication_task_id      = "${var.name_prefix}-postgres-full-load-cdc"
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.this[0].replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source_postgres[0].endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_postgres[0].endpoint_arn
  start_replication_task   = false
  table_mappings = jsonencode({
    rules = [
      {
        "rule-type" = "selection"
        "rule-id"   = "1"
        "rule-name" = "include-business-schemas"
        "object-locator" = {
          "schema-name" = "%"
          "table-name"  = "%"
        }
        "rule-action" = "include"
      }
    ]
  })
  replication_task_settings = jsonencode({
    Logging = {
      EnableLogging = true
    }
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres-full-load-cdc" })
}

resource "terraform_data" "datasync_prerequisites" {
  count = var.enable_datasync_resources ? 1 : 0
  input = true

  lifecycle {
    precondition {
      condition     = var.enable_workload_resources && var.enable_site_to_site_vpn
      error_message = "The synthetic private DataSync path requires the workload EFS target and approved hybrid connectivity."
    }
    precondition {
      condition     = var.datasync_agent_arn != null && var.nfs_source_hostname != null && var.nfs_source_subdirectory != null && var.aws_account_id != null
      error_message = "Supply an activated VPC-endpoint DataSync agent ARN, NFS source host/export and 12-digit AWS account ID."
    }
  }
}

resource "aws_cloudwatch_log_group" "datasync" {
  count = var.enable_datasync_resources ? 1 : 0

  name              = "/aws/datasync/${var.name_prefix}-nfs-to-efs"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_datasync_location_nfs" "source" {
  count = var.enable_datasync_resources ? 1 : 0

  server_hostname = var.nfs_source_hostname
  subdirectory    = var.nfs_source_subdirectory

  on_prem_config {
    agent_arns = [var.datasync_agent_arn]
  }

  mount_options {
    version = "NFS4_1"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-nfs-source" })

  depends_on = [terraform_data.datasync_prerequisites]
}

resource "aws_datasync_location_efs" "destination" {
  count = var.enable_datasync_resources ? 1 : 0

  efs_file_system_arn = aws_efs_file_system.app[0].arn
  subdirectory        = "/"

  ec2_config {
    subnet_arn          = aws_subnet.this["datasync_task"].arn
    security_group_arns = [aws_security_group.datasync_task.arn]
  }

  in_transit_encryption = "TLS1_2"
  tags                  = merge(var.tags, { Name = "${var.name_prefix}-efs-destination" })

  depends_on = [aws_efs_mount_target.app]
}

resource "aws_datasync_task" "nfs_to_efs" {
  count = var.enable_datasync_resources ? 1 : 0

  name                     = "${var.name_prefix}-nfs-to-efs"
  source_location_arn      = aws_datasync_location_nfs.source[0].arn
  destination_location_arn = aws_datasync_location_efs.destination[0].arn
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.datasync[0].arn

  options {
    atime                  = "BEST_EFFORT"
    mtime                  = "PRESERVE"
    uid                    = "INT_VALUE"
    gid                    = "INT_VALUE"
    preserve_deleted_files = "PRESERVE"
    preserve_devices       = "NONE"
    posix_permissions      = "PRESERVE"
    verify_mode            = "ONLY_FILES_TRANSFERRED"
    overwrite_mode         = "ALWAYS"
    task_queueing          = "ENABLED"
    transfer_mode          = "CHANGED"
    log_level              = "BASIC"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-nfs-to-efs" })
}

resource "aws_s3_bucket" "archive" {
  count = var.enable_datasync_resources ? 1 : 0

  bucket_prefix = "${var.name_prefix}-archive-"
  force_destroy = false
  tags          = merge(var.tags, { Name = "${var.name_prefix}-archive" })
}

resource "aws_s3_bucket_public_access_block" "archive" {
  count = var.enable_datasync_resources ? 1 : 0

  bucket                  = aws_s3_bucket.archive[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "archive" {
  count = var.enable_datasync_resources ? 1 : 0

  bucket = aws_s3_bucket.archive[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "archive" {
  count = var.enable_datasync_resources ? 1 : 0

  bucket = aws_s3_bucket.archive[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "datasync_s3" {
  count = var.enable_datasync_resources ? 1 : 0
  name  = "${var.name_prefix}-datasync-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "datasync.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = var.aws_account_id } }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "datasync_s3" {
  count = var.enable_datasync_resources ? 1 : 0
  name  = "${var.name_prefix}-datasync-s3-access"
  role  = aws_iam_role.datasync_s3[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = [aws_s3_bucket.archive[0].arn]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:ListMultipartUploadParts",
          "s3:PutObject"
        ]
        Resource = ["${aws_s3_bucket.archive[0].arn}/archives/*"]
      }
    ]
  })
}

resource "aws_datasync_location_s3" "archive" {
  count = var.enable_datasync_resources ? 1 : 0

  s3_bucket_arn    = aws_s3_bucket.archive[0].arn
  subdirectory     = "/archives"
  s3_storage_class = "STANDARD"

  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_s3[0].arn
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-archive-location" })

  depends_on = [
    aws_s3_bucket_public_access_block.archive,
    aws_s3_bucket_server_side_encryption_configuration.archive,
    aws_iam_role_policy.datasync_s3
  ]
}
