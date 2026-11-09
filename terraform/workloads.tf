data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "terraform_data" "workload_prerequisites" {
  count = var.enable_workload_resources ? 1 : 0
  input = true

  lifecycle {
    precondition {
      condition     = var.create_nat_gateways
      error_message = "Enable NAT or implement and validate the required private service endpoints before enabling workload resources."
    }
    precondition {
      condition     = var.acm_certificate_arn != null && var.rds_engine_version != null
      error_message = "Set a validated ACM certificate ARN and exact PostgreSQL engine version before enabling workload resources."
    }
  }
}

resource "aws_iam_role" "ec2" {
  count = var.enable_workload_resources ? 1 : 0
  name  = "${var.name_prefix}-ec2-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  count      = var.enable_workload_resources ? 1 : 0
  role       = aws_iam_role.ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  count      = var.enable_workload_resources ? 1 : 0
  role       = aws_iam_role.ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  count = var.enable_workload_resources ? 1 : 0
  name  = "${var.name_prefix}-ec2-instance-profile"
  role  = aws_iam_role.ec2[0].name
}

resource "aws_lb" "app" {
  count = var.enable_workload_resources ? 1 : 0

  name                       = "${var.name_prefix}-app-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = [aws_subnet.this["public_a"].id, aws_subnet.this["public_b"].id]
  enable_deletion_protection = true
  tags                       = merge(var.tags, { Name = "${var.name_prefix}-app-alb" })

  depends_on = [terraform_data.workload_prerequisites]
}

resource "aws_lb_target_group" "app" {
  count = var.enable_workload_resources ? 1 : 0

  name        = "${var.name_prefix}-app-tg"
  port        = var.app_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id

  health_check {
    enabled             = true
    path                = "/health/ready"
    protocol            = "HTTP"
    port                = "traffic-port"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-app-tg" })
}

resource "aws_lb_listener" "https" {
  count = var.enable_workload_resources ? 1 : 0

  load_balancer_arn = aws_lb.app[0].arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.acm_certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app[0].arn
  }
}

resource "aws_launch_template" "app" {
  count = var.enable_workload_resources ? 1 : 0

  name_prefix   = "${var.name_prefix}-app-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.app_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2[0].name
  }

  vpc_security_group_ids = [aws_security_group.app.id]
  user_data              = base64encode(templatefile("${path.module}/user_data.sh.tftpl", { app_port = var.app_port }))

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name_prefix}-app-node" })
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-app-launch-template" })

  depends_on = [
    aws_iam_role_policy_attachment.ssm_core,
    aws_iam_role_policy_attachment.cloudwatch_agent
  ]
}

resource "aws_autoscaling_group" "app" {
  count = var.enable_workload_resources ? 1 : 0

  name                      = "${var.name_prefix}-app-asg"
  min_size                  = var.app_asg_min_size
  desired_capacity          = var.app_asg_desired_capacity
  max_size                  = var.app_asg_max_size
  vpc_zone_identifier       = [aws_subnet.this["app_a"].id, aws_subnet.this["app_b"].id]
  target_group_arns         = [aws_lb_target_group.app[0].arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 300

  launch_template {
    id      = aws_launch_template.app[0].id
    version = aws_launch_template.app[0].latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-app-node"
    propagate_at_launch = true
  }
  depends_on = [aws_lb_listener.https]
}

resource "aws_db_subnet_group" "app" {
  count = var.enable_workload_resources ? 1 : 0

  name       = "${var.name_prefix}-db-subnet-group"
  subnet_ids = [aws_subnet.this["db_a"].id, aws_subnet.this["db_b"].id]
  tags       = merge(var.tags, { Name = "${var.name_prefix}-db-subnet-group" })
}

resource "aws_iam_role" "rds_monitoring" {
  count = var.enable_workload_resources ? 1 : 0
  name  = "${var.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "monitoring.rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.enable_workload_resources ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

resource "aws_db_instance" "app" {
  count = var.enable_workload_resources ? 1 : 0

  identifier                     = "${var.name_prefix}-postgres"
  engine                         = "postgres"
  engine_version                 = var.rds_engine_version
  instance_class                 = var.rds_instance_class
  allocated_storage              = var.rds_allocated_storage
  storage_type                   = "gp3"
  iops                           = var.rds_iops
  storage_throughput              = var.rds_storage_throughput
  username                       = var.db_master_username
  manage_master_user_password    = true
  db_subnet_group_name           = aws_db_subnet_group.app[0].name
  vpc_security_group_ids         = [aws_security_group.rds.id]
  multi_az                       = true
  publicly_accessible            = false
  storage_encrypted              = true
  backup_retention_period        = 7
  auto_minor_version_upgrade     = true
  deletion_protection            = true
  copy_tags_to_snapshot          = true
  performance_insights_enabled   = true
  monitoring_interval            = 60
  monitoring_role_arn            = aws_iam_role.rds_monitoring[0].arn
  apply_immediately              = false
  skip_final_snapshot            = false
  final_snapshot_identifier      = "${var.name_prefix}-postgres-final"
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(var.tags, { Name = "${var.name_prefix}-postgres" })
  depends_on = [aws_iam_role_policy_attachment.rds_monitoring]
}

resource "aws_efs_file_system" "app" {
  count = var.enable_workload_resources ? 1 : 0

  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  tags = merge(var.tags, { Name = "${var.name_prefix}-shared-files" })
}

resource "aws_efs_mount_target" "app" {
  for_each = var.enable_workload_resources ? { app_a = "app_a", app_b = "app_b" } : {}

  file_system_id  = aws_efs_file_system.app[0].id
  subnet_id       = aws_subnet.this[each.value].id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_vpc_security_group_egress_rule" "app_https" {
  count = var.enable_workload_resources ? 1 : 0

  security_group_id = aws_security_group.app.id
  description       = "HTTPS to AWS APIs and approved external dependencies through controlled egress."
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
