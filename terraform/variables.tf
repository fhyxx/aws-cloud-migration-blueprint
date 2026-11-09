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
