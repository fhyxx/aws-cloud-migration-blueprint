variable "aws_region" {
  description = "AWS Region for the fictional portfolio environment."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to network resource names."
  type        = string
  default     = "clafoke"
}

variable "vpc_cidr" {
  description = "Synthetic VPC CIDR."
  type        = string
  default     = "10.30.0.0/16"
}

variable "source_cidr" {
  description = "Synthetic on-premises aggregate advertised over the VPN."
  type        = string
  default     = "10.50.0.0/16"
}

variable "source_app_cidr" {
  description = "Synthetic source application subnet permitted to reach MGN staging."
  type        = string
  default     = "10.50.10.0/24"
}

variable "source_db_cidr" {
  description = "Synthetic PostgreSQL/NFS source subnet."
  type        = string
  default     = "10.50.20.0/24"
}

variable "app_port" {
  description = "Synthetic application listener behind the ALB."
  type        = number
  default     = 8080
}

variable "create_nat_gateways" {
  description = "Opt in to two chargeable NAT Gateways and Elastic IPs. Keep false for safe plan review."
  type        = bool
  default     = false
}

variable "enable_site_to_site_vpn" {
  description = "Opt in to chargeable Site-to-Site VPN resources. Requires a real/synthetic lab customer gateway public IP."
  type        = bool
  default     = false
}

variable "customer_gateway_ip" {
  description = "Public outside IPv4 address of the customer gateway; required only when VPN is enabled."
  type        = string
  default     = null
  nullable    = true
}

variable "customer_gateway_asn" {
  description = "Synthetic customer-side private ASN."
  type        = number
  default     = 65010
}

variable "vgw_asn" {
  description = "VGW Amazon-side ASN."
  type        = number
  default     = 64512
}

variable "tags" {
  description = "Additional resource tags."
  type        = map(string)
  default     = {}
}

variable "enable_workload_resources" {
  description = "Opt in to ALB, application ASG, Multi-AZ RDS and EFS resources. Requires NAT, ACM certificate ARN and exact RDS engine version."
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "Validated ACM certificate ARN in the ALB Region; required when workload resources are enabled."
  type        = string
  default     = null
  nullable    = true
}

variable "rds_engine_version" {
  description = "Exact supported PostgreSQL engine version selected for the fictional target."
  type        = string
  default     = null
  nullable    = true
}

variable "app_instance_type" {
  description = "Application EC2 instance type; synthetic 4 vCPU / 16 GiB baseline."
  type        = string
  default     = "m6i.xlarge"
}

variable "app_asg_min_size" {
  description = "Minimum application ASG capacity."
  type        = number
  default     = 2
}

variable "app_asg_desired_capacity" {
  description = "Desired application ASG capacity."
  type        = number
  default     = 2
}

variable "app_asg_max_size" {
  description = "Maximum application ASG capacity."
  type        = number
  default     = 6
}

variable "rds_instance_class" {
  description = "Synthetic Multi-AZ PostgreSQL instance class."
  type        = string
  default     = "db.m6i.2xlarge"
}

variable "rds_allocated_storage" {
  description = "Initial PostgreSQL gp3 storage in GiB."
  type        = number
  default     = 500
}

variable "rds_iops" {
  description = "Synthetic PostgreSQL gp3 provisioned IOPS."
  type        = number
  default     = 12000
}

variable "rds_storage_throughput" {
  description = "Synthetic PostgreSQL gp3 throughput in MiB/s."
  type        = number
  default     = 500
}

variable "db_master_username" {
  description = "Non-secret PostgreSQL master username; password is managed by RDS Secrets Manager integration."
  type        = string
  default     = "clafoke_admin"
}

variable "app_cpu_target" {
  description = "Synthetic target average CPU utilization for ASG target tracking."
  type        = number
  default     = 60
}

variable "enable_dms_resources" {
  description = "Opt in to DMS replication instance, endpoints and stopped full-load-and-CDC task. Requires NAT, VPN, workload target and source secret."
  type        = bool
  default     = false
}

variable "dms_replication_instance_class" {
  description = "DMS class selected after source profiling and benchmark; required when DMS is enabled."
  type        = string
  default     = null
  nullable    = true
}

variable "dms_allocated_storage" {
  description = "DMS replication instance storage in GiB."
  type        = number
  default     = 100
}

variable "source_db_secret_arn" {
  description = "Secrets Manager ARN containing PostgreSQL source endpoint connection details; never store credentials in Terraform variables or state."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.source_db_secret_arn == null || can(regex("^arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:.+$", var.source_db_secret_arn))
    error_message = "source_db_secret_arn must be a Secrets Manager secret ARN."
  }
}

variable "database_name" {
  description = "Synthetic PostgreSQL database name for DMS source and target endpoints."
  type        = string
  default     = "clafoke_orders"
}

variable "enable_datasync_resources" {
  description = "Opt in to NFS-to-EFS DataSync task and private S3 archive destination. Requires an activated VPC-endpoint agent."
  type        = bool
  default     = false
}

variable "datasync_agent_arn" {
  description = "ARN of an already activated DataSync agent configured for a VPC service endpoint."
  type        = string
  default     = null
  nullable    = true
}

variable "nfs_source_hostname" {
  description = "Synthetic NFSv4.1 source hostname or IP reachable over approved hybrid connectivity."
  type        = string
  default     = null
  nullable    = true
}

variable "nfs_source_subdirectory" {
  description = "Exported NFS source subdirectory, for example /exports/orders."
  type        = string
  default     = null
  nullable    = true
}

variable "datasync_agent_cidr" {
  description = "Single synthetic on-premises DataSync agent address; only this host may reach the VPC endpoint and task ENI."
  type        = string
  default     = "10.50.20.50/32"

  validation {
    condition     = can(cidrhost(var.datasync_agent_cidr, 0)) && can(regex("/32$", var.datasync_agent_cidr))
    error_message = "datasync_agent_cidr must be one valid IPv4 /32 host address."
  }
}

variable "availability_zone_names" {
  description = "Two synthetic AZ name aliases; override if either AZ is unavailable in the target account."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.availability_zone_names) == 2 && var.availability_zone_names[0] != var.availability_zone_names[1]
    error_message = "Provide exactly two distinct Availability Zone names."
  }
}

variable "skip_credentials_validation" {
  description = "Provider test switch only. Keep false outside the isolated no-refresh CI plan."
  type        = bool
  default     = false
}

variable "skip_requesting_account_id" {
  description = "Provider test switch only. Keep false for real AWS operations."
  type        = bool
  default     = false
}

variable "ami_id" {
  description = "Validated Amazon Linux 2023 AMI ID for the selected Region; required when workloads are enabled."
  type        = string
  default     = null
  nullable    = true
}

variable "aws_account_id" {
  description = "12-digit AWS account ID used in service-role trust conditions; required when DMS or DataSync is enabled."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.aws_account_id == null || can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit account ID."
  }
}

variable "source_secret_kms_key_arn" {
  description = "Optional customer-managed KMS key ARN for the source DMS secret. Leave null when the AWS-managed Secrets Manager key is used."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.source_secret_kms_key_arn == null || can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/[0-9a-fA-F-]+$", var.source_secret_kms_key_arn))
    error_message = "source_secret_kms_key_arn must be a customer-managed KMS key ARN."
  }
}

variable "enable_mgn_resources" {
  description = "Create the AWS-managed IAM roles and policy attachments required to initialize MGN in this account and Region."
  type        = bool
  default     = false
}
